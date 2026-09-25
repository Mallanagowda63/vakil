import crypto from 'node:crypto';
import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { emitTo } from '../realtime.js';

// User wallet in rupees (2 decimals, never negative). Every change is a
// wallet_transactions entry with the balance after it. Money is added only
// after the server has verified the payment; the app never sends amounts it
// could fake.

const fail = (status, message) => Object.assign(new Error(message), { status });
export const round2 = (n) => Math.round(Number(n) * 100) / 100;
const MIN_RECHARGE = 1;
const MAX_RECHARGE = 50000;

// ---------------------------------------------------------------- payment gateway

export const razorpayConfig = () => {
  const keyId = process.env.RAZORPAY_KEY_ID || ''; const keySecret = process.env.RAZORPAY_KEY_SECRET || '';
  return keyId && keySecret ? { keyId, keySecret } : null;
};
// Without Razorpay keys, a development server can use a stand-in "test recharge".
// It is off unless WALLET_TEST_RECHARGE=true and switches off once keys are set.
export const paymentMode = () => razorpayConfig() ? 'razorpay' : process.env.WALLET_TEST_RECHARGE === 'true' ? 'test' : 'unavailable';

async function createRazorpayOrder({ amount, receipt }) {
  const { keyId, keySecret } = razorpayConfig();
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString('base64')}` },
    body: JSON.stringify({ amount: Math.round(amount * 100), currency: 'INR', receipt }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) { console.error('Razorpay order failed:', data.error?.description || response.status); throw fail(502, 'Payment service is not reachable. Please try again.'); }
  return data.id;
}

const signatureValid = (orderId, paymentId, signature) => {
  const expected = crypto.createHmac('sha256', razorpayConfig().keySecret).update(`${orderId}|${paymentId}`).digest('hex');
  return typeof signature === 'string' && signature.length === expected.length && crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
};

// ---------------------------------------------------------------- balance

export async function balanceOf(userId) {
  const user = await getDb().collection('users').findOne({ _id: new ObjectId(userId) }, { projection: { walletBalance: 1 } });
  return round2(user?.walletBalance || 0);
}

/**
 * Changes the balance by +amount (credit/refund) or −amount (debit) and writes
 * the transaction. Compare-and-set on the old balance, so parallel changes
 * never overwrite each other; a debit larger than the balance fails with 402.
 */
export async function changeBalance({ userId, type, amount, reason, requestId = null, paymentId = null, note = '' }) {
  const _id = new ObjectId(userId); const users = getDb().collection('users');
  amount = round2(amount);
  if (!(amount > 0)) throw fail(400, 'Amount must be more than ₹0');
  for (let attempt = 0; attempt < 8; attempt++) {
    const user = await users.findOne({ _id });
    if (!user) throw fail(404, 'User not found');
    const before = round2(user.walletBalance || 0);
    const after = round2(type === 'debit' ? before - amount : before + amount);
    if (after < 0) throw fail(402, 'Insufficient balance');
    const matched = user.walletBalance === undefined
      ? (await users.updateOne({ _id, walletBalance: { $exists: false } }, { $set: { walletBalance: after } })).matchedCount
      : (await users.updateOne({ _id, walletBalance: user.walletBalance }, { $set: { walletBalance: after } })).matchedCount;
    if (!matched) continue;
    const entry = { userId: _id, accountId: _id, accountRole: 'user', type, amount, balanceAfter: after, reason, requestId: requestId ? new ObjectId(requestId) : null, paymentId: paymentId ? new ObjectId(paymentId) : null, note, status: 'settled', createdAt: new Date() };
    const { insertedId } = await getDb().collection('wallet_transactions').insertOne(entry);
    const view = transactionView({ ...entry, _id: insertedId });
    emitTo('user', _id, 'wallet_updated', { balance: after, transaction: view });
    return view;
  }
  throw fail(409, 'The wallet is busy. Please try again.');
}

export const transactionView = (t) => ({ id: t._id.toString(), type: t.type, amount: t.amount, balanceAfter: t.balanceAfter, reason: t.reason, requestId: t.requestId?.toString() || null, paymentId: t.paymentId?.toString() || null, note: t.note || '', createdAt: t.createdAt });

export async function walletSummary(userId, limit = 50) {
  const rows = await getDb().collection('wallet_transactions').find({ userId: new ObjectId(userId) }).sort({ createdAt: -1 }).limit(limit).toArray();
  const mode = paymentMode();
  return { balance: await balanceOf(userId), currency: 'INR', paymentMode: mode, razorpayKeyId: mode === 'razorpay' ? razorpayConfig().keyId : null, rechargeOptions: [100, 200, 500, 1000], minRecharge: MIN_RECHARGE, maxRecharge: MAX_RECHARGE, transactions: rows.map(transactionView) };
}

// ---------------------------------------------------------------- recharge

// Step 1: the server fixes the amount and creates the order.
export async function createRechargeOrder({ user, amount }) {
  amount = round2(amount);
  if (!Number.isFinite(amount) || amount < MIN_RECHARGE || amount > MAX_RECHARGE) throw fail(400, `Enter an amount between ₹${MIN_RECHARGE} and ₹${MAX_RECHARGE.toLocaleString('en-IN')}`);
  const mode = paymentMode();
  if (mode === 'unavailable') throw fail(503, 'Wallet recharge is not available yet');
  const payments = getDb().collection('payments'); const now = new Date(); const _id = new ObjectId();
  const gatewayOrderId = mode === 'razorpay' ? await createRazorpayOrder({ amount, receipt: `wallet_${_id}` }) : `test_order_${_id}`;
  await payments.insertOne({ _id, userId: user._id, amount, currency: 'INR', purpose: 'wallet_recharge', method: mode === 'razorpay' ? 'Razorpay' : 'Test recharge', gateway: mode, gatewayOrderId, status: 'pending', createdAt: now, updatedAt: now });
  return {
    orderId: gatewayOrderId, paymentId: _id.toString(), amount, amountPaise: Math.round(amount * 100), currency: 'INR', mode,
    razorpayKeyId: mode === 'razorpay' ? razorpayConfig().keyId : null,
    prefill: { contact: user.phone || '', email: user.profile?.email || '', name: user.profile?.fullName || '' },
  };
}

// Step 2: the app returns Razorpay's result; only a valid signature credits the wallet, exactly once.
export async function verifyRecharge({ user, orderId, razorpayPaymentId, signature }) {
  const payments = getDb().collection('payments');
  const payment = await payments.findOne({ gatewayOrderId: String(orderId || ''), userId: user._id });
  if (!payment) throw fail(404, 'Payment not found');
  if (payment.status === 'successful') return { balance: await balanceOf(user._id), amount: payment.amount, alreadyCredited: true };
  if (payment.status !== 'pending') throw fail(409, 'This payment was not completed');
  if (payment.gateway === 'razorpay') {
    if (!razorpayConfig() || !signatureValid(payment.gatewayOrderId, String(razorpayPaymentId || ''), signature)) {
      await payments.updateOne({ _id: payment._id, status: 'pending' }, { $set: { status: 'failed', failureReason: 'Signature check failed', updatedAt: new Date() } });
      throw fail(400, 'Payment could not be verified');
    }
  } else if (paymentMode() !== 'test') throw fail(400, 'Payment could not be verified');
  // Claim the payment first so a repeated verify cannot credit twice.
  const claimed = await payments.updateOne({ _id: payment._id, status: 'pending' }, { $set: { status: 'successful', gatewayRef: String(razorpayPaymentId || `test_pay_${payment._id}`), paidAt: new Date(), updatedAt: new Date() } });
  if (!claimed.matchedCount) return { balance: await balanceOf(user._id), amount: payment.amount, alreadyCredited: true };
  const transaction = await changeBalance({ userId: user._id, type: 'credit', amount: payment.amount, reason: 'recharge', paymentId: payment._id });
  return { balance: transaction.balanceAfter, amount: payment.amount, transaction };
}

// The user closed or failed the checkout.
export async function cancelRecharge({ user, orderId, reason }) {
  await getDb().collection('payments').updateOne({ gatewayOrderId: String(orderId || ''), userId: user._id, status: 'pending' }, { $set: { status: 'failed', failureReason: String(reason || 'Cancelled').slice(0, 200), updatedAt: new Date() } });
  return { ok: true };
}

// ---------------------------------------------------------------- lawyer rate

// A lawyer's per-minute price: their own rate, else the platform chat rate.
export async function rateOf(lawyer) {
  if (Number.isFinite(lawyer?.ratePerMinute)) return lawyer.ratePerMinute;
  const pricing = await getDb().collection('settings').findOne({ key: 'pricing' });
  return round2(pricing?.value?.chatPerMinute ?? 10);
}

// Voice calls have one platform price (Admin Panel → Pricing, "Call per minute").
export const DEFAULT_CALL_RATE = 40;
export async function callRateOf() {
  const pricing = await getDb().collection('settings').findOne({ key: 'pricing' });
  const rate = Number(pricing?.value?.callPerMinute);
  return round2(Number.isFinite(rate) && rate > 0 ? rate : DEFAULT_CALL_RATE);
}

// The price of a consultation of [type] ('chat' or 'call') with [lawyer].
export const consultationRateOf = (lawyer, type) => type === 'call' ? callRateOf() : rateOf(lawyer);
