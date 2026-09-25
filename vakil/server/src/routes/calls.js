import { Router } from 'express';
import { roles } from './auth.js';
import { answerCall, endCall, markRinging, rejectCall, renewCallToken } from '../services/calls.js';

export const callsRouter = Router();
const actorOf = (req) => ({ id: req.user._id, role: req.auth.role });
const run = (fn) => async (req, res) => {
  try { res.json(await fn(req)); }
  catch (e) { if (!e.status) throw e; res.status(e.status).json({ error: e.message, code: e.code }); }
};

callsRouter.post('/:callId/answer', ...roles('user', 'lawyer'), run((req) => answerCall({ callId: req.params.callId, actor: actorOf(req) })));
callsRouter.post('/:callId/ringing', ...roles('user', 'lawyer'), run((req) => markRinging({ callId: req.params.callId, actor: actorOf(req) })));
callsRouter.post('/:callId/reject', ...roles('user', 'lawyer'), run((req) => rejectCall({ callId: req.params.callId, actor: actorOf(req) })));
callsRouter.post('/:callId/end', ...roles('user', 'lawyer'), run((req) => endCall({ callId: req.params.callId, actor: actorOf(req), failed: req.body.failed === true ? (req.body.reason || true) : false })));
callsRouter.post('/:callId/token', ...roles('user', 'lawyer'), run((req) => renewCallToken({ callId: req.params.callId, actor: actorOf(req) })));
