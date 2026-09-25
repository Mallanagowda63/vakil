import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { emitAdmin, emitToChat } from '../realtime.js';
import { pushData } from '../push.js';
import { callSwitchOn, serialize } from './consultations.js';
import { chatFor, counterpart } from './messages.js';
import { generateToken04, zegoConfig } from './zego.js';

const fail = (status, message, code) => Object.assign(new Error(message), { status, code });
// One line per call event, so a test run shows start, answer and why each call ended.
const logCall = (event, call, extra = '') => console.log(`[CALL] ${event} id=${call._id} room=${call.roomId} ${call.callerRole}->${call.receiverRole} ${extra}`.trim());
const toId = (value) => { try { return new ObjectId(value); } catch { return null; } };
const ringSeconds = () => Number(process.env.CALL_RING_SECONDS || 30);
const activeCallStatuses = ['ringing', 'answered'];
const events = { answered: 'call_answered', rejected: 'call_rejected', missed: 'call_missed', ended: 'call_ended', failed: 'call_ended' };

// remainingSeconds is the chat time left (the call ends with the chat), from the server clock.
const remainingSeconds = (call) => call.endsAt && activeCallStatuses.includes(call.status) ? Math.max(0, Math.ceil((new Date(call.endsAt) - Date.now()) / 1000)) : undefined;
export const serializeCall = (call) => call && ({ ...call, id: call._id.toString(), _id: undefined, requestId: call.requestId.toString(), callerId: call.callerId.toString(), receiverId: call.receiverId.toString(), remainingSeconds: remainingSeconds(call) });
const isParticipant = (call, actor) => actor.role === 'admin' || [[call.callerId, call.callerRole], [call.receiverId, call.receiverRole]].some(([id, role]) => id.equals(actor.id) && role === actor.role);
const nameOf = (request, role) => { const view = serialize(request); return role === 'lawyer' ? view.lawyerName : view.userName; };

// Everything an app needs to join the call's audio room. The ZEGO user ID is
// the account ID and the display name is the person's name, never a phone number.
function credentials(call, actor, userName) {
  const zego = zegoConfig();
  if (!zego) throw fail(503, 'Voice calls are not configured yet');
  const userId = actor.id.toString();
  return { appId: zego.appId, token: generateToken04(zego.appId, userId, zego.secret, 3600), roomId: call.roomId, userId, userName };
}

async function loadCall(callId, actor) {
  const _id = toId(callId); const call = _id && await getDb().collection('calls').findOne({ _id });
  if (!call || !isParticipant(call, actor)) throw fail(404, 'Call not found');
  return call;
}

// Adds the call to the chat history, e.g. "Voice call • 3:25" or "Missed voice call".
async function addCallEntry(call) {
  const minutes = Math.floor(call.durationSeconds / 60); const seconds = String(call.durationSeconds % 60).padStart(2, '0');
  const text = call.status === 'ended' ? (call.durationSeconds ? `Voice call • ${minutes}:${seconds}` : 'Voice call')
    : call.status === 'failed' ? 'Voice call failed' : 'Missed voice call';
  const message = { requestId: call.requestId, senderId: call.callerId, senderRole: call.callerRole, recipientId: call.receiverId, recipientRole: call.receiverRole, type: 'call', text, callId: call._id, callStatus: call.status, durationSeconds: call.durationSeconds, status: 'sent', createdAt: call.endedAt, deliveredAt: null, readAt: null };
  const { insertedId } = await getDb().collection('messages').insertOne(message); message._id = insertedId;
  const payload = serialize(message);
  emitToChat(call.requestId, 'new_message', payload); emitAdmin('new_message', payload);
}

// Moves an active call to its final status exactly once, frees the chat's
// call slot, tells both sides and the admins, and writes the chat entry.
async function finishCall(call, status, endedBy, endReason) {
  const db = getDb(); const endedAt = new Date();
  const durationSeconds = status === 'ended' && call.answeredAt ? Math.max(0, Math.round((endedAt - new Date(call.answeredAt)) / 1000)) : 0;
  const updated = await db.collection('calls').findOneAndUpdate({ _id: call._id, status: { $in: activeCallStatuses } }, { $set: { status, endedAt, durationSeconds, endedBy, endReason } }, { returnDocument: 'after' });
  if (!updated) throw fail(409, 'This call has already ended');
  logCall('end', call, `status=${status} endedBy=${endedBy} reason=${endReason} duration=${durationSeconds}s`);
  await db.collection('consultation_requests').updateOne({ _id: call.requestId, activeCallId: call._id }, { $set: { activeCallId: null } });
  const payload = serializeCall(updated);
  emitToChat(call.requestId, events[status], payload); emitAdmin(events[status], payload);
  // Dismisses the full-screen incoming-call UI on a phone that was woken by push.
  if (call.status === 'ringing') pushData({ recipientId: call.receiverId, recipientRole: call.receiverRole, ttlSeconds: 60, data: { type: 'call_ended', callId: payload.id, requestId: payload.requestId, status } }).catch((error) => console.error('Call push failed:', error.message));
  await addCallEntry(updated);
  return payload;
}

export async function startCall({ requestId, caller }) {
  const request = await chatFor(requestId, caller);
  if (caller.role === 'admin') throw fail(403, 'Admins cannot place calls');
  if (request.status === 'COMPLETED') throw fail(403, 'This chat has ended');
  if (request.status !== 'ONGOING') throw fail(404, 'Active consultation not found');
  if (request.endsAt && new Date() >= new Date(request.endsAt)) throw fail(403, 'Chat time is over');
  if (!zegoConfig()) throw fail(503, 'Voice calls are not configured yet');
  // The admin can switch voice calls off for a lawyer (Lawyer Management → Communication channels).
  const lawyer = await getDb().collection('lawyers').findOne({ _id: request.lawyerId });
  if (lawyer?.channels?.call === false) throw fail(403, 'Voice calls are turned off for this lawyer');
  if (caller.role === 'user' && !callSwitchOn(lawyer)) throw fail(403, 'The lawyer is not taking calls right now');
  // Per-minute chat (older apps): a call needs at least one more minute in the wallet. Prepaid time already covers calls.
  if (!request.isTrial && request.ratePerMinute > 0 && !request.endsAt) {
    const client = await getDb().collection('users').findOne({ _id: request.userId });
    if ((client?.walletBalance || 0) < request.ratePerMinute) throw fail(402, 'Insufficient balance');
  }
  const db = getDb(); const requests = db.collection('consultation_requests'); const calls = db.collection('calls'); const callId = new ObjectId();
  const receiver = counterpart(request, caller.role); const now = new Date();
  const call = { _id: callId, requestId: request._id, callerId: caller.id, callerRole: caller.role, callerName: nameOf(request, caller.role), receiverId: receiver.id, receiverRole: receiver.role, receiverName: nameOf(request, receiver.role), roomId: `call_${callId}`, status: 'ringing', ringingAt: null, isTrial: Boolean(request.isTrial), endsAt: request.endsAt || null, startedAt: now, answeredAt: null, endedAt: null, durationSeconds: 0, endedBy: null, createdAt: now };
  // One active call per chat, claimed atomically on the chat. The call is
  // written first, so a claimed slot always points at an existing call and a
  // missing one really is stale; a losing call is removed unannounced.
  await calls.insertOne(call);
  let claimed = (await requests.updateOne({ _id: request._id, status: 'ONGOING', activeCallId: null }, { $set: { activeCallId: callId } })).matchedCount;
  if (!claimed) {
    const held = (await requests.findOne({ _id: request._id }))?.activeCallId;
    const heldCall = held && await calls.findOne({ _id: held });
    if (!(heldCall && activeCallStatuses.includes(heldCall.status))) claimed = (await requests.updateOne({ _id: request._id, status: 'ONGOING', activeCallId: held ?? null }, { $set: { activeCallId: callId } })).matchedCount;
  }
  if (!claimed) { await calls.deleteOne({ _id: callId }); throw fail(409, 'A call is already in progress'); }
  logCall('start', call, `appId=${zegoConfig().appId}`);
  const payload = serializeCall(call);
  emitToChat(request._id, 'incoming_call', payload); emitAdmin('incoming_call', payload);
  // Wakes the receiver's phone for a full-screen incoming call when the app is in the background or closed.
  const callerProfile = await db.collection(caller.role === 'lawyer' ? 'lawyers' : 'users').findOne({ _id: caller.id });
  await pushData({ recipientId: receiver.id, recipientRole: receiver.role, ttlSeconds: ringSeconds(), data: { type: 'incoming_call', callId: payload.id, requestId: payload.requestId, roomId: call.roomId, callerName: call.callerName, callerPhotoUrl: callerProfile?.profile?.photoUrl || '', isTrial: call.isTrial, endsAt: call.endsAt ? new Date(call.endsAt).toISOString() : '' } }).catch((error) => console.error('Call push failed:', error.message));
  return { call: payload, zego: credentials(call, caller, call.callerName) };
}

export async function answerCall({ callId, actor }) {
  const call = await loadCall(callId, actor);
  if (!call.receiverId.equals(actor.id)) throw fail(403, 'Only the person being called can answer');
  const updated = await getDb().collection('calls').findOneAndUpdate({ _id: call._id, status: 'ringing' }, { $set: { status: 'answered', answeredAt: new Date() } }, { returnDocument: 'after' });
  // A second answer from the same account (a duplicate screen) must not end the call.
  if (!updated && call.status === 'answered') { logCall('duplicate-answer', call); throw fail(409, 'This call was already answered', 'already_answered'); }
  if (!updated) throw fail(409, 'This call is no longer ringing');
  logCall('answered', updated, `by=${actor.role}`);
  const payload = serializeCall(updated);
  emitToChat(call.requestId, 'call_answered', payload); emitAdmin('call_answered', payload);
  return { call: payload, zego: credentials(updated, actor, updated.receiverName) };
}

// The receiver's phone is showing the call (sent once, even from a closed app
// woken by push); the caller's screen switches from "Calling…" to "Ringing…".
export async function markRinging({ callId, actor }) {
  const call = await loadCall(callId, actor);
  if (!call.receiverId.equals(actor.id)) throw fail(403, 'Only the person being called can report ringing');
  const updated = await getDb().collection('calls').findOneAndUpdate({ _id: call._id, status: 'ringing', ringingAt: null }, { $set: { ringingAt: new Date() } }, { returnDocument: 'after' });
  if (updated) emitToChat(call.requestId, 'call_ringing', serializeCall(updated));
  return { call: serializeCall(updated || call) };
}

export async function rejectCall({ callId, actor }) {
  const call = await loadCall(callId, actor);
  if (!call.receiverId.equals(actor.id)) throw fail(403, 'Only the person being called can decline');
  if (call.status !== 'ringing') throw fail(409, 'This call is no longer ringing');
  return { call: await finishCall(call, 'rejected', actor.role, 'declined') };
}

// Hanging up: an answered call ends; a caller cancelling while it rings is a
// missed call; `failed` records a connection failure reported by the app.
export async function endCall({ callId, actor, failed = false }) {
  const call = await loadCall(callId, actor);
  if (actor.role === 'admin') throw fail(403, 'Admins cannot end calls');
  if (!activeCallStatuses.includes(call.status)) throw fail(409, 'This call has already ended');
  const status = failed ? 'failed' : call.status === 'answered' ? 'ended' : call.receiverId.equals(actor.id) ? 'rejected' : 'missed';
  const reason = failed ? `audio_failed${typeof failed === 'string' ? `:${failed}` : ''}` : status === 'ended' ? 'hung_up' : status === 'rejected' ? 'declined' : 'cancelled';
  return { call: await finishCall(call, status, actor.role, reason) };
}

// Admin Panel: stop a live call (ringing → missed, answered → ended).
export async function adminEndCall(callId) {
  const _id = toId(callId); const call = _id && await getDb().collection('calls').findOne({ _id });
  if (!call) throw fail(404, 'Call not found');
  if (!activeCallStatuses.includes(call.status)) throw fail(409, 'This call has already ended');
  return finishCall(call, call.status === 'answered' ? 'ended' : 'missed', 'admin', 'admin');
}

// A fresh ZEGO token for a call in progress (the app asks before the old one expires).
export async function renewCallToken({ callId, actor }) {
  const call = await loadCall(callId, actor);
  if (call.status !== 'answered') throw fail(409, 'This call has already ended');
  logCall('token-renewed', call, `for=${actor.role}`);
  return { zego: credentials(call, actor, actor.id.equals(call.callerId) ? call.callerName : call.receiverName) };
}

export async function listCalls({ requestId, actor }) {
  const request = await chatFor(requestId, actor);
  const items = await getDb().collection('calls').find({ requestId: request._id }).sort({ startedAt: -1 }).toArray();
  return { items: items.map(serializeCall) };
}

// Ends whatever call is active when a chat ends (user, lawyer, or trial timer).
export async function endCallsForChat(requestId, endedBy, reason = 'chat_ended') {
  const active = await getDb().collection('calls').find({ requestId: new ObjectId(requestId), status: { $in: activeCallStatuses } }).toArray();
  await Promise.allSettled(active.map((call) => finishCall(call, call.status === 'answered' ? 'ended' : 'missed', endedBy, `chat_ended:${reason}`)));
}

// Calls nobody answered within the ring time become missed.
export async function missUnansweredCalls() {
  const cutoff = new Date(Date.now() - ringSeconds() * 1000);
  const ringing = await getDb().collection('calls').find({ status: 'ringing', startedAt: { $lte: cutoff } }).toArray();
  await Promise.allSettled(ringing.map((call) => finishCall(call, 'missed', 'system', 'no_answer')));
  return ringing.length;
}
