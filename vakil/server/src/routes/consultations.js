import { Router } from 'express';
import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { requireAuth, roles } from './auth.js';
import { emitAdmin, emitTo, joinChatRoom } from '../realtime.js';
import { notify } from '../push.js';
import { activeStatuses, completeSession, isAvailable, isCallAvailable, serialize, transition } from '../services/consultations.js';
import { listMessages, markMessages, sendChatMessage } from '../services/messages.js';
import { listCalls, startCall } from '../services/calls.js';
import { MINUTE_MS, addTime, chargeMinute, isPaidChat, payPackage, validMinutes } from '../services/billing.js';
import { consultationRateOf } from '../services/wallet.js';
import { saveFeedback } from './feedback.js';

export const consultationRouter = Router();
const objectId = (value) => { try { return new ObjectId(value); } catch { return null; } };
// First chat ever is a free 1-minute trial. Every later chat is prepaid: the
// client buys [minutes] at the lawyer's rate, locked when the request is made
// (requests without minutes, from older apps, are billed per minute).
const chatTerms = (user, rate, minutes) => !user.trialUsed ? { chatMinutes: 1, isTrial: true, ratePerMinute: rate }
  : { isTrial: false, ratePerMinute: rate, ...(minutes ? { chatMinutes: minutes } : {}) };
// Prepaid: the package is paid when the lawyer accepts and the chat ends at endsAt.
const isPrepaid = (request) => isPaidChat(request) && Boolean(request.chatMinutes);
const priceOf = (request) => isPrepaid(request) ? Math.round(request.chatMinutes * request.ratePerMinute * 100) / 100 : request.ratePerMinute;

// A user holds at most one PENDING/ONGOING request, claimed atomically on the
// user document so parallel requests cannot open two chats or two trials.
async function claimActiveSlot(db, userId, requestId) {
  const users = db.collection('users');
  if ((await users.updateOne({ _id: userId, activeRequestId: null }, { $set: { activeRequestId: requestId } })).matchedCount) return { ok: true };
  const held = (await users.findOne({ _id: userId }))?.activeRequestId;
  const heldRequest = held && await db.collection('consultation_requests').findOne({ _id: held });
  if (heldRequest && activeStatuses.includes(heldRequest.status)) return { ok: false, request: heldRequest };
  // The slot points at a finished or missing request; take it over only if nobody else did.
  const retaken = await users.updateOne({ _id: userId, activeRequestId: held ?? null }, { $set: { activeRequestId: requestId } });
  return { ok: Boolean(retaken.matchedCount) };
}
const ownFilter = (req) => req.auth.role === 'admin' ? {} : req.auth.role === 'lawyer' ? { lawyerId: req.user._id } : { userId: req.user._id };

consultationRouter.post('/', ...roles('user'), async (req, res) => {
  const { lawyerId, category, consultationType = 'chat', description = '' } = req.body;
  const minutes = req.body.minutes === undefined ? null : Number(req.body.minutes);
  if (!category || !['chat', 'call'].includes(consultationType)) return res.status(400).json({ error: 'category and a valid consultationType are required' });
  if (minutes !== null && !validMinutes(minutes)) return res.status(400).json({ error: 'Choose how many minutes to buy' });
  const db = getDb();
  let lawyer;
  if (lawyerId) {
    const selected = await db.collection('lawyers').findOne({ _id: objectId(lawyerId) });
    if (!selected?.approved || selected.blocked) return res.status(404).json({ error: 'Lawyer not found' });
    const free = consultationType === 'call' ? isCallAvailable(selected) : isAvailable(selected);
    if (!free) return res.status(409).json({ error: consultationType === 'call' ? 'This lawyer is not taking calls right now. Please choose another lawyer.' : 'This lawyer is offline right now. Please choose another lawyer.' });
    lawyer = selected;
  } else {
    const candidates = await db.collection('lawyers').find({}).toArray();
    lawyer = candidates.find((item) => (consultationType === 'call' ? isCallAvailable(item) : isAvailable(item)) && Array.isArray(item.categories) && item.categories.includes(category));
  }
  if (!lawyer) return res.status(404).json({ error: 'No available lawyer found' });
  const insertedId = new ObjectId();
  const user = await db.collection('users').findOne({ _id: req.user._id });
  // Paid chat: the wallet must cover the minutes bought (older apps: the first minute).
  const rate = await consultationRateOf(lawyer, consultationType); const balance = Math.round((user.walletBalance || 0) * 100) / 100;
  const required = Math.round(rate * (minutes || 1) * 100) / 100;
  if (user.trialUsed && balance < required) return res.status(402).json({ error: 'Insufficient balance', required, balance, ratePerMinute: rate });
  const now = new Date(); const timeout = Number(process.env.REQUEST_TIMEOUT_SECONDS || 60);
  const request = { _id: insertedId, userId: req.user._id, lawyerId: lawyer._id, userName: req.user.profile?.fullName || 'Client', lawyerName: lawyer.profile?.fullName || lawyer.registration?.personal?.fullName || 'Lawyer', userPhotoUrl: req.user.profile?.photoUrl || null, lawyerPhotoUrl: lawyer.profile?.photoUrl || null, category, consultationType, description: String(description).slice(0, 1000), ...chatTerms(user, rate, minutes), status: 'PENDING', createdAt: now, updatedAt: now, expiresAt: new Date(now.getTime() + timeout * 1000) };
  // Written before the slot is claimed so a claimed slot always points at an
  // existing request; a request that loses the claim is removed unannounced.
  await db.collection('consultation_requests').insertOne(request);
  const slot = await claimActiveSlot(db, req.user._id, insertedId);
  if (!slot.ok) {
    await db.collection('consultation_requests').deleteOne({ _id: insertedId });
    return res.status(409).json({ error: 'You already have an active request', ...(slot.request ? { request: serialize(slot.request) } : {}) });
  }
  await db.collection('request_status_logs').insertOne({ requestId: insertedId, from: null, to: 'PENDING', actorId: req.user._id, actorRole: 'user', createdAt: now });
  const payload = serialize(request); emitTo('lawyer', lawyer._id, 'new_request', payload); emitAdmin('status_updated', payload);
  await notify({ recipientId: lawyer._id, recipientRole: 'lawyer', title: 'New consultation request', body: `${request.userName}: ${category} (${consultationType})`, data: { type: 'new_request', requestId: insertedId }, channel: 'chat_requests' });
  res.status(201).json({ request: payload });
});

consultationRouter.get('/', requireAuth, async (req, res) => {
  const page = Math.max(1, Number(req.query.page) || 1); const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 20));
  const filter = ownFilter(req); if (req.query.status) filter.status = req.query.status; if (req.query.category) filter.category = req.query.category;
  const db = getDb(); const [items, total] = await Promise.all([db.collection('consultation_requests').find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit).toArray(), db.collection('consultation_requests').countDocuments(filter)]);
  res.json({ items: items.map(serialize), page, limit, total });
});

consultationRouter.get('/:id', requireAuth, async (req, res) => {
  const id = objectId(req.params.id); const request = id && await getDb().collection('consultation_requests').findOne({ _id: id, ...ownFilter(req) });
  if (!request) return res.status(404).json({ error: 'Request not found' });
  const timeline = await getDb().collection('request_status_logs').find({ requestId: id }).sort({ createdAt: 1 }).toArray();
  // The lawyer also sees what this consultation earned them (after commission).
  let earning;
  if (req.auth.role === 'lawyer') {
    const rows = await getDb().collection('wallet_transactions').find({ requestId: id, accountRole: 'lawyer', type: 'earning' }).toArray();
    const add = (pick) => Math.round(rows.reduce((n, r) => n + (Number(pick(r)) || 0), 0) * 100) / 100;
    earning = { amount: add((r) => r.amount), commission: add((r) => r.commission), commissionPercent: rows[0]?.commissionPercent ?? null };
  }
  res.json({ request: serialize(request), timeline: timeline.map(serialize), ...(earning ? { earning } : {}) });
});

const actorOf = (req) => ({ id: req.user._id, role: req.auth.role });
const sendError = (res, e) => res.status(e.status || 500).json({ error: e.status ? e.message : 'Something went wrong' });

// Latest 50 messages; ?before=<messageId> pages older ones, ?after=<messageId> catches up after a reconnect.
consultationRouter.get('/:id/messages', requireAuth, async (req, res) => {
  try { res.json(await listMessages({ requestId: req.params.id, actor: actorOf(req), before: req.query.before, after: req.query.after, limit: req.query.limit })); }
  catch (e) { if (!e.status) throw e; sendError(res, e); }
});

consultationRouter.post('/:id/messages/read', requireAuth, async (req, res) => {
  try { res.json({ messageIds: await markMessages({ requestId: req.params.id, reader: actorOf(req), status: 'read', messageIds: req.body.messageIds }) }); }
  catch (e) { if (!e.status) throw e; sendError(res, e); }
});

// Voice calls (no video). The response carries the caller's ZEGO room credentials.
consultationRouter.post('/:id/call/start', ...roles('user', 'lawyer'), async (req, res) => {
  try { res.status(201).json(await startCall({ requestId: req.params.id, caller: actorOf(req) })); }
  catch (e) { if (!e.status) throw e; sendError(res, e); }
});

consultationRouter.get('/:id/calls', requireAuth, async (req, res) => {
  try { res.json(await listCalls({ requestId: req.params.id, actor: actorOf(req) })); }
  catch (e) { if (!e.status) throw e; sendError(res, e); }
});

// REST fallback for sending (the apps normally use the send_message socket event).
consultationRouter.post('/:id/messages', ...roles('user', 'lawyer'), async (req, res) => {
  try { res.status(201).json({ message: await sendChatMessage({ requestId: req.params.id, sender: actorOf(req), text: req.body.text, clientId: req.body.clientId }) }); }
  catch (e) { if (!e.status) throw e; sendError(res, e); }
});

async function change(req, res, from, to, extra = {}) {
  const id = objectId(req.params.id); const request = id && await getDb().collection('consultation_requests').findOne({ _id: id, ...ownFilter(req) });
  if (!request) return res.status(404).json({ error: 'Request not found' });
  try { const updated = await transition({ requestId: req.params.id, from, to, actorId: req.user._id, actorRole: req.auth.role, extra }); res.json({ request: serialize(updated) }); }
  catch (e) { res.status(e.status || 500).json({ error: e.message }); }
}
// Accept opens the chat on both phones at once; the chat's countdown starts here.
consultationRouter.post('/:id/accept', ...roles('lawyer'), async (req, res) => {
  const id = objectId(req.params.id); const request = id && await getDb().collection('consultation_requests').findOne({ _id: id, ...ownFilter(req) });
  if (!request) return res.status(404).json({ error: 'Request not found' });
  const now = new Date();
  // Paid chat whose client can no longer pay (the package, or the first minute): cancel instead of opening it.
  if (isPaidChat(request) && request.status === 'PENDING') {
    const client = await getDb().collection('users').findOne({ _id: request.userId });
    if ((client?.walletBalance || 0) < priceOf(request)) {
      await transition({ requestId: req.params.id, from: 'PENDING', to: 'CANCELLED', actorId: null, actorRole: 'system', extra: { cancelReason: 'insufficient_balance' } }).catch(() => {});
      return res.status(409).json({ error: "The client doesn't have enough balance anymore. The request was cancelled." });
    }
  }
  try {
    const billing = isPrepaid(request) ? { billedMinutes: 0, totalAmount: 0, nextChargeAt: null } : isPaidChat(request) ? { billedMinutes: 0, totalAmount: 0, nextChargeAt: now } : { billedMinutes: 0 };
    const updated = await transition({ requestId: req.params.id, from: 'PENDING', to: 'ONGOING', actorId: req.user._id, actorRole: 'lawyer', extra: { acceptedAt: now, sessionStartedAt: now, ...billing, ...(request.chatMinutes ? { endsAt: new Date(now.getTime() + request.chatMinutes * MINUTE_MS) } : {}) } });
    // The package (older apps: minute 1) is paid the moment the chat opens.
    if (isPrepaid(updated)) await payPackage(updated);
    else if (isPaidChat(updated)) await chargeMinute(updated);
    await getDb().collection('sessions').updateOne({ requestId: id }, { $setOnInsert: { requestId: id, userId: request.userId, lawyerId: request.lawyerId, startedAt: now, createdAt: now } }, { upsert: true });
    joinChatRoom(updated);
    res.json({ request: serialize(updated) });
  } catch (e) { res.status(e.status || 500).json({ error: e.message }); }
});
// "Add time": the client buys more minutes for an ongoing timed chat (paid or trial).
consultationRouter.post('/:id/extend', ...roles('user'), async (req, res) => {
  const id = objectId(req.params.id); const request = id && await getDb().collection('consultation_requests').findOne({ _id: id, userId: req.user._id });
  if (!request) return res.status(404).json({ error: 'Chat not found' });
  try {
    const lawyer = await getDb().collection('lawyers').findOne({ _id: request.lawyerId });
    const rate = request.ratePerMinute ?? await consultationRateOf(lawyer, request.consultationType);
    res.json(await addTime({ requestId: id, userId: req.user._id, minutes: Number(req.body.minutes), rate }));
  } catch (e) { res.status(e.status || 500).json({ error: e.status ? e.message : 'Something went wrong' }); }
});
consultationRouter.post('/:id/reject', ...roles('lawyer'), (req, res) => change(req, res, 'PENDING', 'REJECTED'));
consultationRouter.post('/:id/cancel', ...roles('user'), (req, res) => change(req, res, 'PENDING', 'CANCELLED'));
// Either side of the chat can end it; the amount is what the server billed.
consultationRouter.post('/:id/complete', ...roles('user', 'lawyer'), async (req, res) => {
  const id = objectId(req.params.id); const request = id && await getDb().collection('consultation_requests').findOne({ _id: id, ...ownFilter(req) });
  if (!request) return res.status(404).json({ error: 'Request not found' });
  try { const updated = await completeSession({ requestId: req.params.id, actorId: req.user._id, actorRole: req.auth.role }); res.json({ request: serialize(updated) }); }
  catch (e) { res.status(e.status || 500).json({ error: e.message }); }
});

// Feedback once a chat or call has ended: the client rates the lawyer, the lawyer rates the client.
consultationRouter.post('/:id/review', ...roles('user', 'lawyer'), async (req, res) => {
  try { res.status(201).json({ ok: true, feedback: await saveFeedback({ requestId: req.params.id, author: actorOf(req), rating: req.body.rating, comment: req.body.comment }) }); }
  catch (e) { if (!e.status) throw e; sendError(res, e); }
});
