import { getDb } from '../db.js';
import { emitAdmin, emitTo } from '../realtime.js';
import { changeBalance, round2 } from './wallet.js';
import { completeSession } from './consultations.js';
import { creditLawyer } from './earnings.js';

// Chats with a package (chatMinutes) are prepaid (see payPackage/addTime below);
// this per-minute billing remains for chats created by older app versions.
// Per-minute billing for chats after the free trial. Each minute is paid at
// its start from the user's wallet (minute 1 when the lawyer accepts). The
// state lives on the request (billedMinutes, totalAmount, nextChargeAt), so a
// server restart resumes billing without skipping or repeating a minute.

// BILLING_MINUTE_SECONDS exists only so tests can use short minutes; keep the default (60).
export const MINUTE_MS = Number(process.env.BILLING_MINUTE_SECONDS || 60) * 1000;
const requests = () => getDb().collection('consultation_requests');
export const isPaidChat = (r) => Boolean(r && !r.isTrial && r.ratePerMinute > 0);
export const secondsToNextCharge = (r) => isPaidChat(r) && r.status === 'ONGOING' && r.nextChargeAt ? Math.max(0, Math.ceil((new Date(r.nextChargeAt) - Date.now()) / 1000)) : undefined;

// Called every second: charges each paid chat whose next minute has started.
export async function billOngoingChats() {
  const due = (await requests().find({ status: 'ONGOING', nextChargeAt: { $lte: new Date() } }).toArray()).filter(isPaidChat);
  await Promise.allSettled(due.map(chargeMinute));
  return due.length;
}

export async function chargeMinute(request) {
  const billed = request.billedMinutes || 0; const minute = billed + 1; const rate = request.ratePerMinute;
  const nextChargeAt = new Date(new Date(request.nextChargeAt || Date.now()).getTime() + MINUTE_MS);
  // Claim this minute first (compare-and-set on billedMinutes): never charged twice.
  const claimed = await requests().updateOne({ _id: request._id, status: 'ONGOING', billedMinutes: billed }, { $set: { billedMinutes: minute, nextChargeAt } });
  if (!claimed.matchedCount) return null;
  const reason = await callInProgress(request) ? 'call' : 'chat';
  let transaction;
  try {
    transaction = await changeBalance({ userId: request.userId, type: 'debit', amount: rate, reason, requestId: request._id, note: `Minute ${minute} · ${request.lawyerName || 'Lawyer'}` });
  } catch (error) {
    // Give the minute back; a busy wallet retries next second, an empty one ends the chat.
    await requests().updateOne({ _id: request._id, billedMinutes: minute }, { $set: { billedMinutes: billed, nextChargeAt: request.nextChargeAt } });
    if (error.status === 402) await endForBalance(request);
    else console.error('Billing failed:', error.message);
    return null;
  }
  const totalAmount = round2((request.totalAmount || 0) + rate);
  await requests().updateOne({ _id: request._id, billedMinutes: minute }, { $set: { totalAmount } });
  await creditLawyer(request, rate, { reason, note: `Minute ${minute}` }).catch((e) => console.error('Lawyer credit failed:', e.message));
  const secondsLeft = Math.max(0, Math.ceil((nextChargeAt - Date.now()) / 1000));
  const tick = { requestId: request._id.toString(), billedMinutes: minute, totalAmount, ratePerMinute: rate, secondsToNextCharge: secondsLeft };
  // The user also gets their balance; the lawyer never sees the client's wallet.
  emitTo('user', request.userId, 'chat_billing', { ...tick, balance: transaction.balanceAfter });
  emitTo('lawyer', request.lawyerId, 'chat_billing', tick); emitAdmin('chat_billing', tick);
  // Not enough for the next minute: warn both sides before it runs out.
  if (transaction.balanceAfter < rate) {
    emitTo('user', request.userId, 'low_balance', { ...tick, balance: transaction.balanceAfter, message: 'Low balance. Recharge to keep chatting.' });
    emitTo('lawyer', request.lawyerId, 'low_balance', { ...tick, message: "The client's balance is running out." });
  }
  return tick;
}

async function callInProgress(request) {
  if (!request.activeCallId) return false;
  const call = await getDb().collection('calls').findOne({ _id: request.activeCallId });
  return call?.status === 'answered';
}

// ------------------------------------------------------------ prepaid time
// The client buys minutes up front: the package is paid when the lawyer
// accepts and ends the chat (and any call) at endsAt. "Add time" buys more
// minutes and moves endsAt forward, for paid chats and the free trial alike.

export const PACKAGE_MINUTES = [5, 10, 15, 30];
export const MAX_MINUTES = 120;
export const validMinutes = (value) => Number.isInteger(value) && value >= 1 && value <= MAX_MINUTES;
const fail = (status, message) => Object.assign(new Error(message), { status });
const billedFilter = (request) => request.billedMinutes === undefined ? { $exists: false } : request.billedMinutes;

// Pays the package when the chat opens. Returns false if the wallet no longer covers it.
export async function payPackage(request) {
  const minutes = request.chatMinutes; const amount = round2(minutes * request.ratePerMinute);
  try {
    await changeBalance({ userId: request.userId, type: 'debit', amount, reason: 'chat', requestId: request._id, note: `${minutes} min · ${request.lawyerName || 'Lawyer'}` });
  } catch (error) {
    if (error.status !== 402) throw error;
    await endForBalance(request);
    return false;
  }
  await requests().updateOne({ _id: request._id }, { $set: { billedMinutes: minutes, totalAmount: amount } });
  await creditLawyer(request, amount, { note: `${minutes} min package` }).catch((e) => console.error('Lawyer credit failed:', e.message));
  const tick = { requestId: request._id.toString(), billedMinutes: minutes, totalAmount: amount, ratePerMinute: request.ratePerMinute };
  emitTo('user', request.userId, 'chat_billing', tick); emitTo('lawyer', request.lawyerId, 'chat_billing', tick); emitAdmin('chat_billing', tick);
  return true;
}

// "Add time": charges [minutes] at the lawyer's rate and extends the chat and its call.
export async function addTime({ requestId, userId, minutes, rate }) {
  if (!validMinutes(minutes)) throw fail(400, `Choose between 1 and ${MAX_MINUTES} minutes`);
  const request = await requests().findOne({ _id: requestId, userId });
  if (!request) throw fail(404, 'Chat not found');
  if (request.status !== 'ONGOING' || !request.endsAt) throw fail(409, 'This chat has ended');
  const amount = round2(minutes * rate);
  await changeBalance({ userId, type: 'debit', amount, reason: 'chat', requestId, note: `+${minutes} min · ${request.lawyerName || 'Lawyer'}` });
  // Compare-and-set on billedMinutes, so two purchases at once both count.
  for (let attempt = 0; attempt < 8; attempt++) {
    const current = await requests().findOne({ _id: requestId });
    if (current?.status !== 'ONGOING') break;
    const from = Math.max(Date.now(), new Date(current.endsAt).getTime());
    const endsAt = new Date(from + minutes * MINUTE_MS);
    const billedMinutes = (current.billedMinutes || 0) + minutes; const totalAmount = round2((current.totalAmount || 0) + amount);
    const done = await requests().updateOne({ _id: requestId, status: 'ONGOING', billedMinutes: billedFilter(current) }, { $set: { endsAt, billedMinutes, totalAmount, ratePerMinute: current.ratePerMinute ?? rate } });
    if (!done.matchedCount) continue;
    // The call ends with the chat, so it gets the same new end time.
    await getDb().collection('calls').updateMany({ requestId, status: { $in: ['ringing', 'answered'] } }, { $set: { endsAt } });
    const onCall = await getDb().collection('calls').findOne({ requestId, status: 'answered' });
    await creditLawyer(current, amount, { reason: onCall ? 'call' : 'chat', note: `+${minutes} min added` }).catch((e) => console.error('Lawyer credit failed:', e.message));
    const remainingSeconds = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000));
    const extended = { requestId: requestId.toString(), minutesAdded: minutes, endsAt, remainingSeconds, billedMinutes, totalAmount, ratePerMinute: current.ratePerMinute ?? rate };
    emitTo('user', current.userId, 'chat_extended', extended); emitTo('lawyer', current.lawyerId, 'chat_extended', extended); emitAdmin('chat_extended', extended);
    console.log(`[CHAT] time added id=${requestId} +${minutes}min amount=${amount} remaining=${remainingSeconds}s`);
    return extended;
  }
  // The chat ended while paying: give the money back.
  await changeBalance({ userId, type: 'credit', amount, reason: 'refund', requestId, note: 'Refund: chat ended before time was added' });
  throw fail(409, 'This chat has ended');
}

async function endForBalance(request) {
  try { await completeSession({ requestId: request._id.toString(), actorId: null, actorRole: 'system', reason: 'balance_over' }); }
  catch (error) { if (error.status !== 409) console.error('Could not end chat on empty balance:', error.message); }
}
