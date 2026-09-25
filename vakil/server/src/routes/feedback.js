import { Router } from 'express';
import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { requireAuth, roles } from './auth.js';
import { emitAdmin, emitTo } from '../realtime.js';

export const feedbackRouter = Router();

// Feedback after a chat or voice call. The client rates the lawyer (`reviews`,
// which make up the lawyer's public rating) and the lawyer rates the client
// (`lawyer_feedback`). Both show in the Admin Panel and in each app.
const toId = (v) => { try { return new ObjectId(String(v)); } catch { return null; } };
export const collectionFor = (authorRole) => authorRole === 'lawyer' ? 'lawyer_feedback' : 'reviews';
const fail = (status, message) => Object.assign(new Error(message), { status });

export async function saveFeedback({ requestId, author, rating, comment }) {
  const _id = toId(requestId); const db = getDb();
  const own = author.role === 'lawyer' ? { lawyerId: author.id } : { userId: author.id };
  const request = _id && await db.collection('consultation_requests').findOne({ _id, ...own });
  if (!request) throw fail(404, 'Consultation not found');
  if (request.status !== 'COMPLETED') throw fail(409, 'Feedback can be given once the consultation has ended');
  const stars = Number(rating);
  if (!Number.isInteger(stars) || stars < 1 || stars > 5) throw fail(400, 'Choose a rating from 1 to 5 stars');
  const now = new Date();
  const doc = { requestId: _id, userId: request.userId, lawyerId: request.lawyerId, authorRole: author.role, rating: stars, comment: String(comment || '').trim().slice(0, 1000), consultationType: request.consultationType || 'chat', category: request.category || null, updatedAt: now };
  const col = db.collection(collectionFor(author.role));
  await col.updateOne({ requestId: _id }, { $set: doc, $setOnInsert: { createdAt: now } }, { upsert: true });
  // Each side sees its own rating on the chat list.
  await db.collection('consultation_requests').updateOne({ _id }, { $set: author.role === 'lawyer' ? { lawyerRating: stars } : { rating: stars } });
  const other = author.role === 'lawyer' ? { role: 'user', id: request.userId } : { role: 'lawyer', id: request.lawyerId };
  const saved = await col.findOne({ requestId: _id });
  emitTo(other.role, other.id, 'feedback_received', await feedbackView(saved, other.role));
  emitAdmin('feedback_updated', { requestId: _id.toString(), authorRole: author.role });
  return feedbackView(saved, author.role);
}

export const nameOf = (account, fallback) => account?.profile?.fullName || account?.registration?.personal?.fullName || fallback;

// One feedback row as [viewerRole] sees it: `other` is the person on the other side.
async function feedbackView(row, viewerRole, accounts) {
  const otherRole = viewerRole === 'lawyer' ? 'user' : 'lawyer';
  const otherId = otherRole === 'lawyer' ? row.lawyerId : row.userId;
  const other = accounts?.get(otherId?.toString()) ?? await getDb().collection(otherRole === 'lawyer' ? 'lawyers' : 'users').findOne({ _id: otherId });
  return {
    id: row._id.toString(), requestId: row.requestId?.toString(), authorRole: row.authorRole || 'user', rating: row.rating, comment: row.comment || '',
    consultationType: row.consultationType || 'chat', category: row.category || null, createdAt: row.createdAt, updatedAt: row.updatedAt,
    other: { id: otherId?.toString() || null, role: otherRole, name: nameOf(other, otherRole === 'lawyer' ? 'Lawyer' : 'Client'), photoUrl: other?.profile?.photoUrl || null },
  };
}

async function accountsFor(rows, role) {
  const ids = [...new Set(rows.map((r) => (role === 'lawyer' ? r.lawyerId : r.userId)?.toString()).filter(Boolean))];
  const list = await getDb().collection(role === 'lawyer' ? 'lawyers' : 'users').find({}).toArray();
  return new Map(list.filter((a) => ids.includes(a._id.toString())).map((a) => [a._id.toString(), a]));
}

const average = (rows) => rows.length ? Math.round(rows.reduce((n, r) => n + r.rating, 0) / rows.length * 10) / 10 : null;

// GET /api/feedback — what I gave and what I received, newest first.
feedbackRouter.get('/', ...roles('user', 'lawyer'), async (req, res) => {
  const role = req.auth.role; const me = role === 'lawyer' ? { lawyerId: req.user._id } : { userId: req.user._id };
  const db = getDb();
  const [givenRows, receivedRows] = await Promise.all([
    db.collection(collectionFor(role)).find(me).sort({ createdAt: -1 }).toArray(),
    db.collection(collectionFor(role === 'lawyer' ? 'user' : 'lawyer')).find(me).sort({ createdAt: -1 }).toArray(),
  ]);
  const others = await accountsFor([...givenRows, ...receivedRows], role === 'lawyer' ? 'user' : 'lawyer');
  const received = receivedRows.filter((r) => !r.hidden);
  res.json({
    given: await Promise.all(givenRows.map((r) => feedbackView(r, role, others))),
    received: await Promise.all(received.map((r) => feedbackView(r, role, others))),
    stats: { receivedAverage: average(received), receivedCount: received.length, givenCount: givenRows.length },
  });
});

// GET /api/feedback/consultation/:id — both sides' feedback for one consultation.
feedbackRouter.get('/consultation/:id', ...roles('user', 'lawyer'), async (req, res) => {
  const _id = toId(req.params.id); const role = req.auth.role;
  const own = role === 'lawyer' ? { lawyerId: req.user._id } : { userId: req.user._id };
  if (!_id || !await getDb().collection('consultation_requests').findOne({ _id, ...own })) return res.status(404).json({ error: 'Consultation not found' });
  const [mine, theirs] = await Promise.all([getDb().collection(collectionFor(role)).findOne({ requestId: _id }), getDb().collection(collectionFor(role === 'lawyer' ? 'user' : 'lawyer')).findOne({ requestId: _id })]);
  res.json({ mine: mine ? await feedbackView(mine, role) : null, theirs: theirs && !theirs.hidden ? await feedbackView(theirs, role) : null });
});

// GET /api/feedback/lawyers/:id — a lawyer's published client reviews (lawyer profile in the User App).
feedbackRouter.get('/lawyers/:id', requireAuth, async (req, res) => {
  const lawyerId = toId(req.params.id); if (!lawyerId) return res.status(404).json({ error: 'Lawyer not found' });
  const rows = (await getDb().collection('reviews').find({ lawyerId }).sort({ createdAt: -1 }).toArray()).filter((r) => !r.hidden);
  const users = await accountsFor(rows, 'user');
  // Clients appear by first name only.
  const items = rows.slice(0, 30).map((r) => {
    const client = users.get(r.userId?.toString());
    return { id: r._id.toString(), rating: r.rating, comment: r.comment || '', consultationType: r.consultationType || 'chat', createdAt: r.createdAt, clientName: nameOf(client, 'Client').split(/\s+/)[0], clientPhotoUrl: client?.profile?.photoUrl || null };
  });
  res.json({ items, stats: { average: average(rows), count: rows.length } });
});
