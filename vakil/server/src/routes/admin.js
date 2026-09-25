import { Router } from 'express';
import { getDb } from '../db.js';
import { roles } from './auth.js';
import { announceLawyer, disconnectAccount } from '../realtime.js';
import { getSetting, verificationStatusOf } from './adminOps.js';
import { callSwitchOn, chatSwitchOn, isAvailable, isCallAvailable } from '../services/consultations.js';
import { accountsById, activeCallStatuses, average, dateRange, findRequests, idOf, nameOf, page, requestCsvFields, requestRows, seconds, sendCsv, startOfToday, toId } from '../services/adminData.js';
import { serializeCall } from '../services/calls.js';

// Admin Panel API. Admins see everything, including phone numbers.
export const adminRouter = Router();
adminRouter.use(...roles('admin'));

// ---------------------------------------------------------------- dashboard

adminRouter.get('/dashboard', async (_req, res) => {
  const db = getDb(); const today = startOfToday();
  const [todayRequests, ongoingNow, todayCalls, activeCalls, trialUsers] = await Promise.all([
    db.collection('consultation_requests').find({ createdAt: { $gte: today } }).toArray(),
    db.collection('consultation_requests').countDocuments({ status: 'ONGOING' }),
    db.collection('calls').find({ startedAt: { $gte: today } }).toArray(),
    db.collection('calls').countDocuments({ status: { $in: activeCallStatuses } }),
    db.collection('users').find({ trialUsed: true, role: { $ne: 'admin' } }).project({ _id: 1 }).toArray(),
  ]);
  const byStatus = (status) => todayRequests.filter((r) => r.status === status).length;
  // Trial → normal: users who finished their free trial and then had a paid (non-trial) chat.
  const converted = trialUsers.length ? (await db.collection('consultation_requests').distinct('userId', { userId: { $in: trialUsers.map((u) => u._id) }, isTrial: { $ne: true }, status: { $in: ['ONGOING', 'COMPLETED'] } })).length : 0;
  const answeredCalls = todayCalls.filter((c) => c.status === 'ended' && c.durationSeconds > 0);
  res.json({
    totalToday: todayRequests.length, pending: byStatus('PENDING'), ongoingNow, completed: byStatus('COMPLETED'), rejected: byStatus('REJECTED'), expired: byStatus('EXPIRED'), cancelled: byStatus('CANCELLED'),
    trialChats: todayRequests.filter((r) => r.isTrial).length, trialUsers: trialUsers.length, convertedUsers: converted, conversionRate: trialUsers.length ? Math.round(converted / trialUsers.length * 100) : 0,
    averageResponseSeconds: average(todayRequests.map((r) => seconds(r.createdAt, r.acceptedAt || r.rejectedAt)).filter((s) => s !== null)),
    callsToday: todayCalls.length, missedCallsToday: todayCalls.filter((c) => c.status === 'missed').length, activeCalls, averageCallSeconds: average(answeredCalls.map((c) => c.durationSeconds)),
  });
});

// ---------------------------------------------------------------- requests

adminRouter.get('/requests', async (req, res) => {
  const { rows, users, lawyers } = await findRequests(req.query);
  const p = page(req.query, rows.length);
  res.json({ items: await requestRows(rows.slice(p.skip, p.skip + p.limit), users, lawyers), total: rows.length, page: p.page, pages: p.pages, limit: p.limit });
});

adminRouter.get('/requests.csv', async (req, res) => {
  const { rows, users, lawyers } = await findRequests(req.query);
  sendCsv(res, 'vakil-requests.csv', requestCsvFields, await requestRows(rows, users, lawyers));
});

// One request: summary, status timeline, full transcript (with call entries) and calls.
async function requestDetail(id) {
  const _id = toId(id); const db = getDb();
  const request = _id && await db.collection('consultation_requests').findOne({ _id });
  if (!request) return null;
  const [users, lawyers] = await Promise.all([accountsById('users', [request.userId]), accountsById('lawyers', [request.lawyerId])]);
  const [row] = await requestRows([request], users, lawyers);
  const [timeline, messages, calls] = await Promise.all([
    db.collection('request_status_logs').find({ requestId: _id }).sort({ createdAt: 1 }).toArray(),
    db.collection('messages').find({ requestId: _id }).sort({ createdAt: 1, _id: 1 }).toArray(),
    db.collection('calls').find({ requestId: _id }).sort({ startedAt: 1 }).toArray(),
  ]);
  return {
    request: { ...row, description: request.description || '' },
    billing: {
      paid: !request.isTrial && request.ratePerMinute > 0, ratePerMinute: request.ratePerMinute ?? null, billedMinutes: request.billedMinutes || 0, totalAmount: request.totalAmount ?? 0, endReason: request.endReason || null,
      deductions: (await db.collection('wallet_transactions').find({ requestId: _id, accountRole: 'user' }).sort({ createdAt: 1 }).toArray()).map((t) => ({ id: t._id.toString(), type: t.type, reason: t.reason, amount: t.amount, balanceAfter: t.balanceAfter, note: t.note || '', createdAt: t.createdAt })),
    },
    timeline: [...(timeline.some((l) => l.to === 'PENDING') ? [] : [{ id: 'created', from: null, to: 'PENDING', actorRole: 'user', createdAt: request.createdAt }]), ...timeline.map((l) => ({ id: l._id.toString(), from: l.from, to: l.to, actorRole: l.actorRole, createdAt: l.createdAt }))],
    messages: messages.map((m) => ({ id: m._id.toString(), type: m.type || 'text', senderRole: m.senderRole, senderName: m.senderRole === 'lawyer' ? row.lawyerName : row.userName, text: m.text, status: m.status || 'sent', createdAt: m.createdAt, deliveredAt: m.deliveredAt || null, readAt: m.readAt || null, callStatus: m.callStatus || null, durationSeconds: m.durationSeconds ?? null })),
    calls: calls.map(serializeCall),
  };
}

adminRouter.get('/requests/:id', async (req, res) => {
  const detail = await requestDetail(req.params.id);
  if (!detail) return res.status(404).json({ error: 'Request not found' });
  res.json(detail);
});

adminRouter.get('/requests/:id/transcript.csv', async (req, res) => {
  const detail = await requestDetail(req.params.id);
  if (!detail) return res.status(404).json({ error: 'Request not found' });
  sendCsv(res, `vakil-transcript-${detail.request.id}.csv`, [['Time', (m) => m.createdAt], ['Sender', (m) => m.senderName], ['Role', (m) => m.senderRole], ['Type', (m) => m.type], ['Message', (m) => m.text], ['Status', (m) => m.status], ['Delivered', (m) => m.deliveredAt], ['Read', (m) => m.readAt]], detail.messages);
});

// ---------------------------------------------------------------- calls

async function findCalls(query) {
  const filter = {};
  if (query.status) filter.status = String(query.status).toLowerCase();
  const started = dateRange(query.from, query.to); if (started) filter.startedAt = started;
  if (query.requestId && toId(query.requestId)) filter.requestId = toId(query.requestId);
  let calls = await getDb().collection('calls').find(filter).sort({ startedAt: -1 }).toArray();
  // One person's calls (user history), as caller or receiver.
  if (query.accountId) calls = calls.filter((c) => idOf(c.callerId) === query.accountId || idOf(c.receiverId) === query.accountId);
  const [users, lawyers] = await Promise.all([accountsById('users', calls.flatMap((c) => [c.callerRole === 'user' ? c.callerId : null, c.receiverRole === 'user' ? c.receiverId : null])), accountsById('lawyers', calls.flatMap((c) => [c.callerRole === 'lawyer' ? c.callerId : null, c.receiverRole === 'lawyer' ? c.receiverId : null]))]);
  const phoneOf = (id, role) => (role === 'lawyer' ? lawyers : users).get(idOf(id))?.phone || null;
  return calls.map((c) => ({ id: c._id.toString(), requestId: idOf(c.requestId), callerName: c.callerName, callerRole: c.callerRole, callerPhone: phoneOf(c.callerId, c.callerRole), receiverName: c.receiverName, receiverRole: c.receiverRole, receiverPhone: phoneOf(c.receiverId, c.receiverRole), status: c.status, isTrial: Boolean(c.isTrial), startedAt: c.startedAt, answeredAt: c.answeredAt || null, endedAt: c.endedAt || null, durationSeconds: c.durationSeconds || 0, endedBy: c.endedBy || null }));
}

adminRouter.get('/calls', async (req, res) => {
  const rows = await findCalls(req.query); const p = page(req.query, rows.length);
  res.json({ items: rows.slice(p.skip, p.skip + p.limit), total: rows.length, page: p.page, pages: p.pages, limit: p.limit });
});

adminRouter.get('/calls.csv', async (req, res) => {
  sendCsv(res, 'vakil-calls.csv', [['Call ID', (c) => c.id], ['Request ID', (c) => c.requestId], ['Caller', (c) => c.callerName], ['Caller role', (c) => c.callerRole], ['Caller phone', (c) => c.callerPhone], ['Receiver', (c) => c.receiverName], ['Receiver role', (c) => c.receiverRole], ['Receiver phone', (c) => c.receiverPhone], ['Status', (c) => c.status], ['Started', (c) => c.startedAt], ['Answered', (c) => c.answeredAt], ['Ended', (c) => c.endedAt], ['Duration (s)', (c) => c.durationSeconds], ['Ended by', (c) => c.endedBy]], await findCalls(req.query));
});

// ---------------------------------------------------------------- live

adminRouter.get('/live', async (_req, res) => {
  const { rows, users, lawyers } = await findRequests({ status: 'ONGOING' });
  const calls = await getDb().collection('calls').find({ status: { $in: activeCallStatuses } }).sort({ startedAt: -1 }).toArray();
  res.json({ chats: await requestRows(rows, users, lawyers), calls: calls.map(serializeCall) });
});

// ---------------------------------------------------------------- lawyers

adminRouter.get('/lawyers', async (_req, res) => {
  const db = getDb();
  const [lawyers, requests, reviews, complaints, pricing] = await Promise.all([db.collection('lawyers').find({}).sort({ createdAt: -1 }).toArray(), db.collection('consultation_requests').find({ lawyerId: { $ne: null } }).toArray(), db.collection('reviews').find({}).toArray(), db.collection('complaints').find({}).toArray(), getSetting('pricing')]);
  const items = lawyers.map((lawyer) => {
    const id = lawyer._id.toString();
    const mine = requests.filter((r) => idOf(r.lawyerId) === id);
    const answered = mine.filter((r) => r.acceptedAt || r.rejectedAt);
    const rated = reviews.filter((r) => idOf(r.lawyerId) === id && !r.hidden);
    return {
      id, name: nameOf(lawyer, 'Lawyer'), phone: lawyer.phone || null, photoUrl: lawyer.profile?.photoUrl || null, categories: lawyer.categories || [], city: lawyer.registration?.advocate?.city || null,
      approved: Boolean(lawyer.approved), blocked: Boolean(lawyer.blocked), verificationStatus: verificationStatusOf(lawyer), online: isAvailable(lawyer), appConnected: Boolean(lawyer.connected), lastSeenAt: lawyer.lastSeenAt || null, createdAt: lawyer.createdAt || null,
      featured: Boolean(lawyer.featured), channels: { chat: lawyer.channels?.chat !== false, call: lawyer.channels?.call !== false }, rate: lawyer.ratePerMinute ?? pricing.chatPerMinute, rateOverridden: lawyer.ratePerMinute != null, commissionOverride: lawyer.commissionOverride ?? null,
      totalRequests: mine.length, accepted: mine.filter((r) => r.acceptedAt).length, consultations: mine.filter((r) => r.status === 'COMPLETED').length,
      acceptanceRate: answered.length ? Math.round(mine.filter((r) => r.acceptedAt).length / answered.length * 100) : null,
      averageResponseSeconds: answered.length ? average(answered.map((r) => seconds(r.createdAt, r.acceptedAt || r.rejectedAt))) : null,
      ratingAverage: rated.length ? Math.round(rated.reduce((n, r) => n + r.rating, 0) / rated.length * 10) / 10 : null, ratingCount: rated.length,
      openComplaints: complaints.filter((c) => idOf(c.lawyerId) === id && c.status !== 'resolved').length,
      chatOnline: isAvailable(lawyer), callOnline: isCallAvailable(lawyer), chatSwitch: chatSwitchOn(lawyer), callSwitch: callSwitchOn(lawyer),
      earnings: Math.round(mine.filter((r) => r.status === 'COMPLETED').reduce((n, r) => n + (r.totalAmount ?? r.amount ?? 0), 0) * 100) / 100,
    };
  });
  res.json({ items });
});

// Approve / reject / suspend, visibility, channels and pricing overrides.
adminRouter.patch('/lawyers/:id', async (req, res) => {
  const _id = toId(req.params.id); if (!_id) return res.status(400).json({ error: 'Invalid id' });
  const b = req.body; const set = {}; const now = new Date(); const admin = req.user.phone || 'admin';
  const statuses = { approved: { approved: true, blocked: false, verificationStatus: 'approved', approvedAt: now, approvedBy: admin }, rejected: { approved: false, blocked: false, verificationStatus: 'rejected' }, suspended: { blocked: true, verificationStatus: 'suspended' }, pending: { approved: false, blocked: false, verificationStatus: 'pending' } };
  if (b.verificationStatus) { if (!statuses[b.verificationStatus]) return res.status(400).json({ error: 'Unknown status' }); Object.assign(set, statuses[b.verificationStatus]); }
  if ('approved' in b) Object.assign(set, b.approved ? statuses.approved : { approved: false, verificationStatus: 'pending' });
  if ('blocked' in b) Object.assign(set, b.blocked ? statuses.suspended : { blocked: false });
  for (const flag of ['featured', 'recommended']) if (flag in b) set[flag] = Boolean(b[flag]);
  if (b.channels) { if ('chat' in b.channels) set['channels.chat'] = Boolean(b.channels.chat); if ('call' in b.channels) set['channels.call'] = Boolean(b.channels.call); }
  // rateOverride (Admin Panel name) is stored as the lawyer's ratePerMinute, the price the User App shows.
  for (const field of ['rateOverride', 'commissionOverride']) {
    if (!(field in b)) continue;
    const key = field === 'rateOverride' ? 'ratePerMinute' : field;
    if (b[field] === null || b[field] === '') { set[key] = null; continue; }
    const n = Number(b[field]);
    if (!Number.isFinite(n) || n < 0 || (field === 'commissionOverride' && n > 100)) return res.status(400).json({ error: `Invalid ${field}` });
    set[key] = n;
  }
  if ('verificationNotes' in b) set.verificationNotes = String(b.verificationNotes || '').slice(0, 2000);
  if (!Object.keys(set).length) return res.status(400).json({ error: 'Nothing to change' });
  const { matchedCount } = await getDb().collection('lawyers').updateOne({ _id }, { $set: set });
  if (!matchedCount) return res.status(404).json({ error: 'Lawyer not found' });
  // A suspended lawyer stops taking requests and is signed out right away.
  if (set.blocked) { await getDb().collection('lawyers').updateOne({ _id }, { $set: { online: false } }); disconnectAccount('lawyer', _id); }
  await announceLawyer(_id);
  res.json({ ok: true });
});

// ---------------------------------------------------------------- users

adminRouter.get('/users', async (req, res) => {
  const db = getDb(); const q = String(req.query.q || '').trim().toLowerCase();
  const [users, requests, calls, payments, wallet] = await Promise.all([db.collection('users').find({ role: { $ne: 'admin' } }).sort({ createdAt: -1 }).toArray(), db.collection('consultation_requests').find({}).project({ userId: 1, status: 1 }).toArray(), db.collection('calls').find({}).project({ callerId: 1, receiverId: 1 }).toArray(), db.collection('payments').find({ status: 'successful' }).toArray(), db.collection('wallet_transactions').find({ accountRole: 'user' }).toArray()]);
  let items = users.map((u) => {
    const id = u._id.toString();
    return {
      id, name: nameOf(u, 'Client'), phone: u.phone || null, email: u.profile?.email || null, language: u.profile?.language || null, trialUsed: Boolean(u.trialUsed), blocked: Boolean(u.blocked), riskLevel: u.riskLevel || 'low', riskNote: u.riskNote || '', online: Boolean(u.connected), lastSeenAt: u.lastSeenAt || null, createdAt: u.createdAt || null,
      chats: requests.filter((r) => idOf(r.userId) === id && ['ONGOING', 'COMPLETED'].includes(r.status)).length, requests: requests.filter((r) => idOf(r.userId) === id).length,
      calls: calls.filter((c) => idOf(c.callerId) === id || idOf(c.receiverId) === id).length,
      walletBalance: Math.round((u.walletBalance || 0) * 100) / 100, walletEntries: wallet.filter((t) => idOf(t.accountId) === id).length,
      // Spent = per-minute chat/call charges (recharges are not spending).
      totalSpent: Math.round(wallet.filter((t) => idOf(t.accountId) === id && t.type === 'debit').reduce((n, t) => n + (t.amount || 0), 0) * 100) / 100,
      totalRecharged: Math.round(payments.filter((p) => idOf(p.userId) === id).reduce((n, p) => n + (p.amount || 0), 0) * 100) / 100,
    };
  });
  if (q) items = items.filter((u) => u.name.toLowerCase().includes(q) || String(u.email || '').toLowerCase().includes(q) || String(u.phone || '').includes(q.replace(/\D/g, '') || q));
  res.json({ items });
});

// Block / unblock and the admin's risk rating.
adminRouter.patch('/users/:id', async (req, res) => {
  const _id = toId(req.params.id); if (!_id) return res.status(400).json({ error: 'Invalid id' });
  const set = {};
  if ('blocked' in req.body) set.blocked = Boolean(req.body.blocked);
  if ('riskLevel' in req.body) { if (!['low', 'medium', 'high'].includes(req.body.riskLevel)) return res.status(400).json({ error: 'riskLevel must be low, medium or high' }); set.riskLevel = req.body.riskLevel; }
  if ('riskNote' in req.body) set.riskNote = String(req.body.riskNote || '').slice(0, 500);
  if (!Object.keys(set).length) return res.status(400).json({ error: 'Nothing to change' });
  const { matchedCount } = await getDb().collection('users').updateOne({ _id, role: { $ne: 'admin' } }, { $set: set });
  if (!matchedCount) return res.status(404).json({ error: 'User not found' });
  if (set.blocked) disconnectAccount('user', _id);
  res.json({ ok: true });
});
