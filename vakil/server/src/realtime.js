import jwt from 'jsonwebtoken';
import { ObjectId } from 'mongodb';
import { Server } from 'socket.io';
import { getDb, isDbConnected } from './db.js';
import { secret } from './routes/auth.js';
import { chatFor, markMessages, sendChatMessage } from './services/messages.js';
import { isAvailable, lawyerStatus } from './services/consultations.js';

let io;
// Open sockets per identity ("user:<id>" / "lawyer:<id>"); presence is online while > 0.
const connections = new Map();
const identity = (role, id) => `${role}:${id}`;
export const chatRoom = (requestId) => `chat:${requestId}`;
export const isConnected = (role, id) => (connections.get(identity(role, id)) || 0) > 0;

async function authenticate(token) {
  for (const key of [secret(), ...(process.env.JWT_PREVIOUS_SECRETS || '').split(',').filter(Boolean)]) {
    try { return jwt.verify(token, key); } catch {}
  }
  const user = token && await getDb().collection('users').findOne({ token });
  if (user && !user.blocked) return { sub: user._id.toString(), role: 'user' };
  return null;
}

async function ongoingChats(role, id) {
  const field = role === 'lawyer' ? 'lawyerId' : 'userId';
  return getDb().collection('consultation_requests').find({ [field]: new ObjectId(id), status: 'ONGOING' }).project({ _id: 1 }).toArray();
}

async function setPresence(socket, online) {
  const { role, sub } = socket.auth; if (role === 'admin') return;
  const lastSeenAt = new Date();
  await getDb().collection(role === 'lawyer' ? 'lawyers' : 'users').updateOne({ _id: new ObjectId(sub) }, { $set: { connected: online, lastSeenAt } });
  const payload = { id: sub, role, online, lastSeenAt };
  for (const chat of await ongoingChats(role, sub)) io.to(chatRoom(chat._id)).emit(online ? 'user_online' : 'user_offline', payload);
  io.to('admin').emit(online ? 'user_online' : 'user_offline', payload);
  if (role === 'lawyer') await announceLawyer(sub);
}

// Tells every open User App (and the Admin Panel) which of chat / call a
// lawyer can take right now, so lawyer lists update live without refreshing.
// lawyer_presence is the older event, kept for app versions still installed.
export async function announceLawyer(lawyerId) {
  const lawyer = await getDb().collection('lawyers').findOne({ _id: new ObjectId(lawyerId) });
  if (!lawyer) return;
  const status = lawyerStatus(lawyer);
  io?.to('users').emit('lawyer_status_changed', status); io?.to('admin').emit('lawyer_status_changed', status);
  io?.to('users').emit('lawyer_presence', { id: status.id, online: isAvailable(lawyer), active: status.active });
}

// Wraps a socket handler: runs it with the socket's identity and answers the
// client's acknowledgement callback with { ok, ... } or { ok: false, error, status }.
const handle = (socket, fn) => async (data = {}, ack) => {
  const reply = typeof ack === 'function' ? ack : () => {};
  try { reply({ ok: true, ...(await fn({ ...data }, { id: socket.actorId, role: socket.auth.role })) }); }
  catch (error) { reply({ ok: false, error: error.status ? error.message : 'Something went wrong', status: error.status || 500 }); if (!error.status) console.error(error); }
};

export function initRealtime(server) {
  io = new Server(server, { cors: { origin: '*', methods: ['GET', 'POST', 'PATCH'] } });
  io.use(async (socket, next) => {
    // Still starting: refuse; the apps reconnect automatically a moment later.
    if (!isDbConnected()) return next(new Error('starting'));
    const claims = await authenticate(socket.handshake.auth?.token).catch(() => null);
    if (!claims) return next(new Error('unauthorized'));
    socket.auth = claims; socket.actorId = new ObjectId(claims.sub);
    next();
  });
  io.on('connection', async (socket) => {
    const { role, sub } = socket.auth; const key = identity(role, sub);
    socket.join(key);
    if (role === 'admin') { socket.join('admin'); return; }
    if (role === 'user') socket.join('users');
    // Listeners and the connection count are set up synchronously, before any
    // DB wait, so early events and quick disconnects are never missed.
    connections.set(key, (connections.get(key) || 0) + 1);
    const firstConnection = connections.get(key) === 1;

    // Opening any of your own chats (including finished ones) joins its room.
    socket.on('join_chat', handle(socket, async ({ requestId }, actor) => { const chat = await chatFor(requestId, actor); socket.join(chatRoom(chat._id)); return {}; }));
    socket.on('send_message', handle(socket, async ({ requestId, text, clientId }, actor) => ({ message: await sendChatMessage({ requestId, sender: actor, text, clientId }) })));
    socket.on('message_delivered', handle(socket, async ({ requestId, messageIds }, actor) => ({ messageIds: await markMessages({ requestId, reader: actor, status: 'delivered', messageIds }) })));
    socket.on('message_read', handle(socket, async ({ requestId, messageIds }, actor) => ({ messageIds: await markMessages({ requestId, reader: actor, status: 'read', messageIds }) })));
    for (const event of ['typing_start', 'typing_stop']) {
      socket.on(event, ({ requestId } = {}) => { const room = chatRoom(requestId); if (socket.rooms.has(room)) socket.to(room).emit(event, { requestId, id: sub, role }); });
    }
    socket.on('disconnect', () => {
      const left = (connections.get(key) || 1) - 1;
      if (left > 0) { connections.set(key, left); return; }
      connections.delete(key); setPresence(socket, false).catch(console.error);
    });
    for (const chat of await ongoingChats(role, sub).catch(() => [])) socket.join(chatRoom(chat._id));
    if (firstConnection && socket.connected) setPresence(socket, true).catch(console.error);
  });
  return io;
}

export const emitTo = (role, id, event, payload) => io?.to(identity(role, id)).emit(event, payload);
export const emitAdmin = (event, payload) => io?.to('admin').emit(event, payload);
export const emitToChat = (requestId, event, payload) => io?.to(chatRoom(requestId)).emit(event, payload);
// Puts every open socket of both participants into the chat room (called on accept).
export const joinChatRoom = (request) => {
  io?.in(identity('user', request.userId)).socketsJoin(chatRoom(request._id));
  io?.in(identity('lawyer', request.lawyerId)).socketsJoin(chatRoom(request._id));
};
// Signs a blocked account out: its open sockets close and do not reconnect with that token.
export const disconnectAccount = (role, id) => io?.in(identity(role, id)).disconnectSockets(true);

// A lawyer whose Partner App has been closed for a while (LAWYER_OFFLINE_AFTER_MINUTES,
// default 10) is switched off for chat and calls, so users only see lawyers
// who are really around. They switch back on in the app.
export async function turnOffAwayLawyers() {
  const cutoff = Date.now() - Number(process.env.LAWYER_OFFLINE_AFTER_MINUTES || 10) * 60000;
  const lawyers = await getDb().collection('lawyers').find({ connected: { $ne: true } }).toArray();
  const away = lawyers.filter((l) => (l.isChatOnline || l.isCallOnline || l.online) && !(l.lastSeenAt && new Date(l.lastSeenAt).getTime() > cutoff));
  for (const lawyer of away) {
    await getDb().collection('lawyers').updateOne({ _id: lawyer._id, connected: { $ne: true } }, { $set: { isChatOnline: false, isCallOnline: false, online: false } });
    await announceLawyer(lawyer._id);
  }
  return away.length;
}
