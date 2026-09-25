import { Router } from 'express';
import { roles } from './auth.js';
import { cancelRecharge, createRechargeOrder, verifyRecharge, walletSummary } from '../services/wallet.js';

// The signed-in user's wallet. Recharge: /order (server fixes the amount),
// then /verify with Razorpay's result (signature checked on the server).
export const walletRouter = Router();
const run = (fn) => async (req, res) => {
  try { res.json(await fn(req)); }
  catch (e) { if (!e.status) throw e; res.status(e.status).json({ error: e.message }); }
};

walletRouter.get('/', ...roles('user'), run((req) => walletSummary(req.user._id)));
walletRouter.post('/order', ...roles('user'), run((req) => createRechargeOrder({ user: req.user, amount: Number(req.body.amount) })));
walletRouter.post('/verify', ...roles('user'), run((req) => verifyRecharge({ user: req.user, orderId: req.body.orderId, razorpayPaymentId: req.body.razorpayPaymentId, signature: req.body.signature })));
walletRouter.post('/cancel', ...roles('user'), run((req) => cancelRecharge({ user: req.user, orderId: req.body.orderId, reason: req.body.reason })));
