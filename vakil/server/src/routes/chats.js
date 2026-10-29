import { Router } from 'express';
import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { roles } from './auth.js';
import { serialize } from '../services/consultations.js';

export const chatsRouter = Router();

const otherIdOf = (chat, role) => role === 'lawyer' ? chat.userId : chat.lawyerId;

// One chat as the signed-in side sees it: the other person (name/photo and
// presence only, never their phone), the last message and the unread count.
function summarize(chat, role, { lastMessage, unread, other }) {
  const otherId = otherIdOf(chat, role); const request = serialize(chat);
  return {
    requestId: request.id, status: chat.status, isTrial: Boolean(chat.isTrial), remainingSeconds: request.remainingSeconds, elapsedSeconds: request.elapsedSeconds, rating: (role === 'lawyer' ? chat.lawyerRating : chat.rating) ?? null,
    ratePerMinute: chat.ratePerMinute ?? null, billedMinutes: chat.billedMinutes || 0, totalAmount: chat.totalAmount || 0, secondsToNextCharge: request.secondsToNextCharge ?? null, endReason: chat.endReason ?? null,
    category: chat.category, consultationType: chat.consultationType || 'chat', endedBy: chat.endedBy ?? null,
    other: { id: otherId.toString(), role: role === 'lawyer' ? 'user' : 'lawyer', name: other?.profile?.fullName || (role === 'lawyer' ? request.userName : request.lawyerName), photoUrl: other?.profile?.photoUrl || null, online: Boolean(other?.connected), lastSeenAt: other?.lastSeenAt || null },
    lastMessage: lastMessage ? { id: lastMessage._id.toString(), type: lastMessage.type || 'text', text: lastMessage.text, senderRole: lastMessage.senderRole, status: lastMessage.status || 'sent', createdAt: lastMessage.createdAt } : null,
    unread, lastActivityAt: lastMessage?.createdAt || chat.updatedAt,
  };
}

// Last message, unread count and the other person for many chats in three
// queries (not three per chat), so a long chat list still opens quickly.
async function summarizeAll(chats, role) {
  if (!chats.length) return [];
  const db = getDb(); const ids = chats.map((c) => c._id); const messages = db.collection('messages');
  const people = db.collection(role === 'lawyer' ? 'users' : 'lawyers').find({ _id: { $in: [...new Set(chats.map((c) => otherIdOf(c, role).toString()))].map((id) => new ObjectId(id)) } }).project({ profile: 1, connected: 1, lastSeenAt: 1 }).toArray();
  let last; let unread;
  try {
    [last, unread] = await Promise.all([
      messages.aggregate([{ $match: { requestId: { $in: ids } } }, { $sort: { createdAt: -1, _id: -1 } }, { $group: { _id: '$requestId', message: { $first: '$$ROOT' } } }]).toArray(),
      messages.aggregate([{ $match: { requestId: { $in: ids }, senderRole: { $ne: role }, status: { $ne: 'read' } } }, { $group: { _id: '$requestId', count: { $sum: 1 } } }]).toArray(),
    ]);
  } catch {
    // The offline mock database has no aggregate(): one lookup per chat.
    last = await Promise.all(ids.map(async (id) => ({ _id: id, message: (await messages.find({ requestId: id }).sort({ createdAt: -1, _id: -1 }).limit(1).toArray())[0] })));
    unread = await Promise.all(ids.map(async (id) => ({ _id: id, count: await messages.countDocuments({ requestId: id, senderRole: { $ne: role }, status: { $ne: 'read' } }) })));
  }
  const lastBy = new Map(last.map((r) => [r._id.toString(), r.message]));
  const unreadBy = new Map(unread.map((r) => [r._id.toString(), r.count]));
  const otherBy = new Map((await people).map((p) => [p._id.toString(), p]));
  return chats.map((chat) => summarize(chat, role, { lastMessage: lastBy.get(chat._id.toString()), unread: unreadBy.get(chat._id.toString()) || 0, other: otherBy.get(otherIdOf(chat, role).toString()) }));
}
const mine = (req) => req.auth.role === 'lawyer' ? { lawyerId: req.user._id } : { userId: req.user._id };

// Chat list: ongoing chats first, then by latest activity.
chatsRouter.get('/', ...roles('user', 'lawyer'), async (req, res) => {
  const chats = await getDb().collection('consultation_requests').find({ ...mine(req), status: { $in: ['ONGOING', 'COMPLETED'] } }).sort({ updatedAt: -1 }).limit(100).toArray();
  const items = await summarizeAll(chats, req.auth.role);
  items.sort((a, b) => ((b.status === 'ONGOING') - (a.status === 'ONGOING')) || (new Date(b.lastActivityAt) - new Date(a.lastActivityAt)));
  res.json({ items });
});

chatsRouter.get('/:requestId', ...roles('user', 'lawyer'), async (req, res) => {
  const _id = ObjectId.isValid(req.params.requestId) ? new ObjectId(req.params.requestId) : null;
  const chat = _id && await getDb().collection('consultation_requests').findOne({ _id, ...mine(req) });
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  res.json({ chat: (await summarizeAll([chat], req.auth.role))[0] });
});
