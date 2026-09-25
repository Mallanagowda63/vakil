import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { emitAdmin, emitTo, emitToChat } from '../realtime.js';
import { notify } from '../push.js';
import { endCallsForChat } from './calls.js';

// A lawyer can take a request only if available AND reachable right now:
// the app is connected, or the phone can be woken with a push notification.
export const isReachable = (lawyer) => Boolean(lawyer?.connected || lawyer?.fcmTokens?.length);
// The lawyer's own switches in the Partner App ("Chat available", "Call
// available"). Accounts from before the switches existed use the old `online`.
export const chatSwitchOn = (lawyer) => Boolean(lawyer?.isChatOnline ?? lawyer?.online);
export const callSwitchOn = (lawyer) => Boolean(lawyer?.isCallOnline ?? lawyer?.online);
const canWork = (lawyer) => Boolean(lawyer && lawyer.approved && !lawyer.blocked && isReachable(lawyer));
// Can take a chat request now: switch on, not turned off by the admin (channels.chat), reachable.
export const isAvailable = (lawyer) => canWork(lawyer) && lawyer.channels?.chat !== false && chatSwitchOn(lawyer);
// Can take a voice call now (same rules for calls).
export const isCallAvailable = (lawyer) => canWork(lawyer) && lawyer.channels?.call !== false && callSwitchOn(lawyer);
// What the User App shows: which of chat / call the lawyer can take right now.
export const lawyerStatus = (lawyer) => {
  const chat = isAvailable(lawyer); const call = isCallAvailable(lawyer);
  return { id: lawyer._id.toString(), isChatOnline: chat, isCallOnline: call, online: chat || call, active: Boolean(lawyer.connected), lastSeenAt: lawyer.lastSeenAt || null };
};
// Sort key: chat + call first, then chat or call only, then offline.
export const statusRank = (s) => (s.isChatOnline ? 1 : 0) + (s.isCallOnline ? 1 : 0);

export const statuses = ['PENDING', 'ONGOING', 'COMPLETED', 'REJECTED', 'EXPIRED', 'CANCELLED'];
export const activeStatuses = ['PENDING', 'ONGOING'];
const terminalStatuses = ['COMPLETED', 'REJECTED', 'EXPIRED', 'CANCELLED'];
// Accepting a request opens the chat directly: PENDING -> ONGOING.
const allowed = { PENDING: ['ONGOING', 'REJECTED', 'EXPIRED', 'CANCELLED'], ONGOING: ['COMPLETED'] };
const userEvents = { ONGOING: 'request_accepted' };
const userNotices = { ONGOING: 'Your lawyer accepted. Your chat is open.', REJECTED: 'The lawyer is unavailable. Please choose another lawyer.', EXPIRED: 'The lawyer did not respond. Please choose another lawyer.', COMPLETED: 'Your chat has ended.' };
const elapsedSeconds = (doc) => doc.status === 'ONGOING' && doc.sessionStartedAt ? Math.max(0, Math.floor((Date.now() - new Date(doc.sessionStartedAt)) / 1000)) : undefined;
// Paid chats: seconds until the next minute is charged.
const secondsToNextCharge = (doc) => doc.status === 'ONGOING' && !doc.isTrial && doc.nextChargeAt ? Math.max(0, Math.ceil((new Date(doc.nextChargeAt) - Date.now()) / 1000)) : undefined;
const remainingSeconds = (doc) => doc.status === 'ONGOING' && doc.endsAt ? Math.max(0, Math.ceil((new Date(doc.endsAt) - Date.now()) / 1000)) : undefined;
// Older requests stored the phone number as a fallback name; never send it to the other side.
const phoneLike = /^\+?\d[\d\s-]{6,}$/;
const displayName = (name, fallback) => !name || phoneLike.test(String(name)) ? fallback : name;
export const serialize = (doc) => doc && ({ ...doc, id: doc._id.toString(), _id: undefined, userId: doc.userId?.toString(), lawyerId: doc.lawyerId?.toString(), remainingSeconds: remainingSeconds(doc), elapsedSeconds: elapsedSeconds(doc), secondsToNextCharge: secondsToNextCharge(doc), ...('userName' in doc ? { userName: displayName(doc.userName, 'Client') } : {}), ...('lawyerName' in doc ? { lawyerName: displayName(doc.lawyerName, 'Lawyer') } : {}) });

export async function transition({ requestId, from, to, actorId, actorRole, extra = {} }) {
  if (!allowed[from]?.includes(to)) { const error = new Error(`Cannot change ${from} to ${to}`); error.status = 409; throw error; }
  const db = getDb(); const now = new Date();
  const result = await db.collection('consultation_requests').findOneAndUpdate({ _id: new ObjectId(requestId), status: from }, { $set: { status: to, updatedAt: now, [`${to.toLowerCase()}At`]: now, ...extra } }, { returnDocument: 'after' });
  if (!result) { const error = new Error('Request was already handled or does not exist'); error.status = 409; throw error; }
  await db.collection('request_status_logs').insertOne({ requestId: result._id, from, to, actorId, actorRole, createdAt: now });
  // Frees the user's single active-request slot (see POST /consultations).
  if (terminalStatuses.includes(to)) await db.collection('users').updateOne({ _id: result.userId, activeRequestId: result._id }, { $set: { activeRequestId: null } });
  const payload = serialize(result); emitAdmin('status_updated', payload);
  const event = userEvents[to] || `request_${to.toLowerCase()}`;
  if (result.userId) { emitTo('user', result.userId, event, payload); await notify({ recipientId: result.userId, recipientRole: 'user', title: 'Vakil', body: userNotices[to] || `Your consultation request is ${to.toLowerCase()}.`, data: { requestId } }); }
  if (result.lawyerId) emitTo('lawyer', result.lawyerId, 'status_updated', payload);
  return result;
}

export async function expirePending() {
  const rows = await getDb().collection('consultation_requests').find({ status: 'PENDING', expiresAt: { $lte: new Date() } }).project({ _id: 1 }).toArray();
  await Promise.allSettled(rows.map((r) => transition({ requestId: r._id.toString(), from: 'PENDING', to: 'EXPIRED', actorId: null, actorRole: 'system' })));
  return rows.length;
}

// Ends an ongoing chat (by the user, the lawyer, the trial timer or an empty
// wallet), records who ended it, why, how long it ran and what it cost, ends
// any active call, and consumes the free trial. The transition runs first, so
// when several callers end the same chat at once only one wins (others: 409).
// The amount is what the server billed per minute; lawyer earnings = totalAmount.
export async function completeSession({ requestId, actorId, actorRole, reason = null }) {
  const db = getDb(); const _id = new ObjectId(requestId); const endedAt = new Date();
  const current = await db.collection('consultation_requests').findOne({ _id });
  const started = current?.sessionStartedAt || current?.acceptedAt;
  const durationSeconds = started ? Math.max(0, Math.round((endedAt - new Date(started)) / 1000)) : 0;
  // What the client paid (a trial is free unless time was added); lawyer earnings = totalAmount.
  const totalAmount = Math.round((current?.totalAmount || 0) * 100) / 100;
  const endReason = reason || (actorRole === 'system' ? 'time_over' : `ended_by_${actorRole}`);
  const updated = await transition({ requestId, from: 'ONGOING', to: 'COMPLETED', actorId, actorRole, extra: { sessionEndedAt: endedAt, endedBy: actorRole, endReason, durationSeconds, amount: totalAmount, totalAmount, nextChargeAt: null } });
  await db.collection('sessions').updateOne({ requestId: _id }, { $set: { endedAt, endedBy: actorRole, endReason, durationSeconds, amount: totalAmount, totalAmount, billedMinutes: current?.billedMinutes || 0, ratePerMinute: current?.ratePerMinute ?? null, updatedAt: endedAt } }, { upsert: true });
  await endCallsForChat(requestId, actorRole, endReason);
  if (updated.isTrial) await db.collection('users').updateOne({ _id: updated.userId }, { $set: { trialUsed: true } });
  console.log(`[CHAT] end id=${requestId} endedBy=${actorRole} reason=${endReason} duration=${durationSeconds}s total=${totalAmount}`);
  const ended = { requestId, durationSeconds, endedBy: actorRole, reason: endReason, totalAmount, endedAt };
  emitToChat(_id, 'chat_ended', ended); emitAdmin('chat_ended', ended);
  return updated;
}

export async function endTimedOutChats() {
  // Only chats with a time limit (endsAt set) run out; older unlimited chats never match.
  const rows = (await getDb().collection('consultation_requests').find({ status: 'ONGOING', endsAt: { $lte: new Date() } }).project({ _id: 1, endsAt: 1 }).toArray()).filter((r) => r.endsAt);
  await Promise.allSettled(rows.map((r) => completeSession({ requestId: r._id.toString(), actorId: null, actorRole: 'system' })));
  return rows.length;
}
