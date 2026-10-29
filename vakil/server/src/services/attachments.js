import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { chatFor, sendChatMessage } from './messages.js';
import { emitAdmin, emitToChat } from '../realtime.js';

// Photos and files sent in a chat. They are kept in MongoDB, not on disk: the
// cloud server's disk is wiped on every restart. Only the two people in the
// chat (and admins) can download them, and only for a short while: they are
// deleted 5 minutes after the chat ends (the messages stay, marked deleted).

export const attachmentTypes = {
  'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp',
  'application/pdf': 'pdf', 'text/plain': 'txt',
  'application/msword': 'doc', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
};
export const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
// CHAT_FILES_KEEP_MINUTES changes the 5 minutes (tests use a few seconds).
const keepAfterEndMs = () => Number(process.env.CHAT_FILES_KEEP_MINUTES || 5) * 60 * 1000;

const fail = (status, message) => Object.assign(new Error(message), { status });
const col = () => getDb().collection('chat_attachments');

/** Checks and stores one file, then sends it as a message in the chat. */
export async function sendAttachment({ requestId, sender, file, contentType, fileName, clientId }) {
  if (!attachmentTypes[contentType]) throw fail(400, 'You can send photos (JPG, PNG), PDF, Word or text files');
  let bytes;
  try { bytes = Buffer.from(String(file || ''), 'base64'); } catch { bytes = Buffer.alloc(0); }
  if (!bytes.length) throw fail(400, 'Choose a file to send');
  if (bytes.length > MAX_ATTACHMENT_BYTES) throw fail(413, 'The file is too large (10 MB at most)');
  const type = contentType.startsWith('image/') ? 'image' : 'file';
  const name = String(fileName || `${type === 'image' ? 'photo' : 'file'}.${attachmentTypes[contentType]}`).replace(/[\r\n/\\]/g, ' ').trim().slice(0, 120);
  // The chat must still accept messages before the file is stored.
  await sendChatMessage({ requestId, sender, clientId, attachment: { check: true, fileName: name, type } });
  const request = await chatFor(requestId, sender);
  const _id = new ObjectId();
  await col().insertOne({ _id, requestId: request._id, senderId: sender.id, data: bytes, contentType, fileName: name, size: bytes.length, createdAt: new Date() });
  const meta = { id: _id.toString(), fileName: name, contentType, size: bytes.length };
  return sendChatMessage({ requestId, sender, clientId, attachment: { type, fileName: name, meta } });
}

/** One file of a chat, for a member of that chat. */
export async function findAttachment({ requestId, attachmentId, actor }) {
  const request = await chatFor(requestId, actor);
  const _id = ObjectId.isValid(attachmentId) ? new ObjectId(attachmentId) : null;
  const found = _id && await col().findOne({ _id, requestId: request._id });
  if (!found) throw fail(404, 'This file was deleted after the chat ended');
  return found;
}

/** Deletes the files of chats that ended more than 5 minutes ago (runs every 30 s). */
export async function deleteExpiredAttachments() {
  const db = getDb();
  const rows = await col().find({}).project({ requestId: 1 }).toArray();
  if (!rows.length) return 0;
  const ids = [...new Map(rows.map((r) => [r.requestId.toString(), r.requestId])).values()];
  const cutoff = Date.now() - keepAfterEndMs();
  const chats = await db.collection('consultation_requests').find({ _id: { $in: ids } }).toArray();
  const expired = chats.filter((c) => c.status !== 'ONGOING' && new Date(c.sessionEndedAt || c.completedAt || c.updatedAt).getTime() <= cutoff).map((c) => c._id);
  for (const requestId of expired) {
    await col().deleteMany({ requestId });
    await db.collection('messages').updateMany({ requestId, type: { $in: ['image', 'file'] } }, { $set: { 'attachment.deleted': true } });
    const event = { requestId: requestId.toString() };
    emitToChat(requestId, 'attachments_deleted', event);
    emitAdmin('attachments_deleted', event);
  }
  return expired.length;
}
