import { Router } from 'express';
import { roles } from './auth.js';
import { cancelRecharge, createRechargeOrder, handleCashfreeWebhook, verifyRecharge, walletSummary } from '../services/wallet.js';

// The signed-in user's wallet. Recharge: /order (server fixes the amount),
// then Cashfree checkout in the app, then /verify (the server checks the order with Cashfree).
export const walletRouter = Router();
const run = (fn) => async (req, res) => {
  try { res.json(await fn(req)); }
  catch (e) { if (!e.status) throw e; res.status(e.status).json({ error: e.message }); }
};

walletRouter.get('/', ...roles('user'), run((req) => walletSummary(req.user._id)));
walletRouter.post('/order', ...roles('user'), run((req) => createRechargeOrder({ user: req.user, amount: Number(req.body.amount) })));
walletRouter.post('/verify', ...roles('user'), run((req) => verifyRecharge({ user: req.user, orderId: req.body.orderId })));
walletRouter.post('/cancel', ...roles('user'), run((req) => cancelRecharge({ user: req.user, orderId: req.body.orderId, reason: req.body.reason })));
// Cashfree payment notices (no sign-in; the order is re-checked with Cashfree).
walletRouter.post('/cashfree/webhook', run((req) => handleCashfreeWebhook(req.body)));
