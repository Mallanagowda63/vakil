import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { chatRoom, emitAdmin, emitToChat, isConnected } from '../realtime.js';
import { notify } from '../push.js';
import { serialize } from './consultations.js';

const fail = (status, message) => Object.assign(new Error(message), { status });
const toId = (value) => { try { return new ObjectId(value); } catch { return null; } };
export const counterpart = (request, role) => role === 'lawyer' ? { id: request.userId, role: 'user' } : { id: request.lawyerId, role: 'lawyer' };

// Loads a chat and checks that the actor belongs to it (admins see every chat).
export async function chatFor(requestId, actor) {
  const _id = toId(requestId); const request = _id && await getDb().collection('consultation_requests').findOne({ _id });
  const member = request && (actor.role === 'admin' || (actor.role === 'user' ? request.userId : request.lawyerId)?.equals(actor.id));
  if (!member) throw fail(404, 'Consultation not found');
  return request;
}

// Validates, stores, then delivers a message. The DB write always happens
// before anyone is told about the message. A repeated clientId (an offline
// message re-sent on reconnect) returns the stored copy instead of a duplicate.
export async function sendChatMessage({ requestId, sender, text, clientId }) {
  const request = await chatFor(requestId, sender);
  if (sender.role === 'admin') throw fail(403, 'Admins cannot send messages');
  if (request.status === 'COMPLETED') throw fail(403, 'This chat has ended');
  if (request.status !== 'ONGOING') throw fail(404, 'Active consultation not found');
  if (request.endsAt && new Date() >= new Date(request.endsAt)) throw fail(403, 'Chat time is over');
  const body = String(text || '').trim();
  if (!body || body.length > 4000) throw fail(400, 'Message must contain 1 to 4000 characters');
  const db = getDb(); const messages = db.collection('messages');
  const cleanClientId = clientId ? String(clientId).slice(0, 64) : null;
  if (cleanClientId) {
    const existing = await messages.findOne({ requestId: request._id, senderId: sender.id, clientId: cleanClientId });
    if (existing) return serialize(existing);
  }
  const recipient = counterpart(request, sender.role);
  const message = { requestId: request._id, senderId: sender.id, senderRole: sender.role, recipientId: recipient.id, recipientRole: recipient.role, type: 'text', text: body, clientId: cleanClientId, status: 'sent', createdAt: new Date(), deliveredAt: null, readAt: null };
  const { insertedId } = await messages.insertOne(message); message._id = insertedId;
  const payload = serialize(message);
  emitToChat(request._id, 'new_message', payload);
  emitAdmin('new_message', payload);
  if (!isConnected(recipient.role, recipient.id)) {
    const name = sender.role === 'lawyer' ? request.lawyerName : request.userName;
    await notify({ recipientId: recipient.id, recipientRole: recipient.role, title: name || 'New message', body: body.slice(0, 120), data: { type: 'new_message', requestId: request._id.toString() }, channel: recipient.role === 'lawyer' ? 'chat_messages' : null });
  }
  return payload;
}

// Moves the other side's messages forward to delivered or read and tells the sender.
export async function markMessages({ requestId, reader, status, messageIds }) {
  const request = await chatFor(requestId, reader);
  if (reader.role === 'admin') return [];
  const earlier = status === 'read' ? ['sent', 'delivered'] : ['sent'];
  const filter = { requestId: request._id, senderRole: { $ne: reader.role }, status: { $in: earlier } };
  const ids = (messageIds || []).map(toId).filter(Boolean);
  if (ids.length) filter._id = { $in: ids };
  const db = getDb(); const pending = await db.collection('messages').find(filter).project({ _id: 1, deliveredAt: 1 }).toArray();
  if (!pending.length) return [];
  const at = new Date();
  const set = status === 'read' ? { status: 'read', readAt: at } : { status: 'delivered', deliveredAt: at };
  await db.collection('messages').updateMany({ _id: { $in: pending.map((m) => m._id) } }, { $set: set });
  // A message read before its delivered receipt arrived still gets a delivered time.
  if (status === 'read') await db.collection('messages').updateMany({ _id: { $in: pending.map((m) => m._id) }, deliveredAt: null }, { $set: { deliveredAt: at } });
  const event = { requestId: request._id.toString(), messageIds: pending.map((m) => m._id.toString()), status, at };
  emitToChat(request._id, status === 'read' ? 'message_read' : 'message_delivered', event);
  emitAdmin(status === 'read' ? 'message_read' : 'message_delivered', event);
  return event.messageIds;
}

// A cursor is a message id (exact, tie-safe) or an ISO time. Messages written
// in the same millisecond are ordered by _id so none are skipped between pages.
async function cursorFilter(messages, requestId, cursor, direction) {
  const op = direction === 'before' ? '$lt' : '$gt';
  const id = toId(cursor); const anchor = id && await messages.findOne({ _id: id, requestId });
  if (anchor) return { $or: [{ createdAt: { [op]: anchor.createdAt } }, { createdAt: anchor.createdAt, _id: { [op]: anchor._id } }] };
  const time = new Date(cursor);
  if (Number.isNaN(time.getTime())) throw fail(400, `Invalid ${direction} cursor`);
  return { createdAt: { [op]: time } };
}

// Latest page of a chat (older pages with `before`), or everything after a
// message for catching up after a reconnect.
export async function listMessages({ requestId, actor, before, after, limit = 50 }) {
  const request = await chatFor(requestId, actor);
  if (actor.role !== 'admin' && !['ONGOING', 'COMPLETED'].includes(request.status)) throw fail(404, 'Consultation not found');
  const messages = getDb().collection('messages'); const size = Math.min(100, Math.max(1, Number(limit) || 50));
  let items; let hasMore = false;
  if (after) {
    items = await messages.find({ requestId: request._id, ...(await cursorFilter(messages, request._id, after, 'after')) }).sort({ createdAt: 1, _id: 1 }).limit(500).toArray();
  } else {
    const filter = { requestId: request._id, ...(before ? await cursorFilter(messages, request._id, before, 'before') : {}) };
    const page = await messages.find(filter).sort({ createdAt: -1, _id: -1 }).limit(size + 1).toArray();
    hasMore = page.length > size; items = page.slice(0, size).reverse();
  }
  if (request.status === 'ONGOING') await markMessages({ requestId, reader: actor, status: 'delivered' });
  return { items: items.map(serialize), hasMore, room: chatRoom(request._id) };
}
