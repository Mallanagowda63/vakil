import { Router } from 'express';
import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { roles } from './auth.js';
import { serialize } from '../services/consultations.js';

export const chatsRouter = Router();

// One chat as the signed-in side sees it: the other person (name/photo and
// presence only, never their phone), the last message and the unread count.
async function summarize(chat, role) {
  const db = getDb(); const otherId = role === 'lawyer' ? chat.userId : chat.lawyerId;
  const [lastMessage] = await db.collection('messages').find({ requestId: chat._id }).sort({ createdAt: -1, _id: -1 }).limit(1).toArray();
  const unread = await db.collection('messages').countDocuments({ requestId: chat._id, senderRole: { $ne: role }, status: { $ne: 'read' } });
  const other = await db.collection(role === 'lawyer' ? 'users' : 'lawyers').findOne({ _id: otherId });
  const request = serialize(chat);
  return {
    requestId: request.id, status: chat.status, isTrial: Boolean(chat.isTrial), remainingSeconds: request.remainingSeconds, elapsedSeconds: request.elapsedSeconds, rating: (role === 'lawyer' ? chat.lawyerRating : chat.rating) ?? null,
    ratePerMinute: chat.ratePerMinute ?? null, billedMinutes: chat.billedMinutes || 0, totalAmount: chat.totalAmount || 0, secondsToNextCharge: request.secondsToNextCharge ?? null, endReason: chat.endReason ?? null,
    category: chat.category, endedBy: chat.endedBy ?? null,
    other: { id: otherId.toString(), role: role === 'lawyer' ? 'user' : 'lawyer', name: other?.profile?.fullName || (role === 'lawyer' ? request.userName : request.lawyerName), photoUrl: other?.profile?.photoUrl || null, online: Boolean(other?.connected), lastSeenAt: other?.lastSeenAt || null },
    lastMessage: lastMessage ? { id: lastMessage._id.toString(), type: lastMessage.type || 'text', text: lastMessage.text, senderRole: lastMessage.senderRole, status: lastMessage.status || 'sent', createdAt: lastMessage.createdAt } : null,
    unread, lastActivityAt: lastMessage?.createdAt || chat.updatedAt,
  };
}
const mine = (req) => req.auth.role === 'lawyer' ? { lawyerId: req.user._id } : { userId: req.user._id };

// Chat list: ongoing chats first, then by latest activity.
chatsRouter.get('/', ...roles('user', 'lawyer'), async (req, res) => {
  const chats = await getDb().collection('consultation_requests').find({ ...mine(req), status: { $in: ['ONGOING', 'COMPLETED'] } }).sort({ updatedAt: -1 }).limit(100).toArray();
  const items = await Promise.all(chats.map((chat) => summarize(chat, req.auth.role)));
  items.sort((a, b) => ((b.status === 'ONGOING') - (a.status === 'ONGOING')) || (new Date(b.lastActivityAt) - new Date(a.lastActivityAt)));
  res.json({ items });
});

chatsRouter.get('/:requestId', ...roles('user', 'lawyer'), async (req, res) => {
  const _id = ObjectId.isValid(req.params.requestId) ? new ObjectId(req.params.requestId) : null;
  const chat = _id && await getDb().collection('consultation_requests').findOne({ _id, ...mine(req) });
  if (!chat) return res.status(404).json({ error: 'Chat not found' });
  res.json({ chat: await summarize(chat, req.auth.role) });
});
