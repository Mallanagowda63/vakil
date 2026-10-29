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

// Cashfree (CASHFREE_APP_ID / CASHFREE_SECRET_KEY, CASHFREE_ENV=sandbox|production).
export const cashfreeConfig = () => {
  const appId = process.env.CASHFREE_APP_ID || ''; const secretKey = process.env.CASHFREE_SECRET_KEY || '';
  if (!appId || !secretKey) return null;
  const production = process.env.CASHFREE_ENV === 'production';
  return { appId, secretKey, environment: production ? 'PRODUCTION' : 'SANDBOX', baseUrl: production ? 'https://api.cashfree.com/pg' : 'https://sandbox.cashfree.com/pg' };
};
// Without Cashfree keys, a development server can use a stand-in "test recharge".
// It is off unless WALLET_TEST_RECHARGE=true and switches off once keys are set.
export const paymentMode = () => cashfreeConfig() ? 'cashfree' : process.env.WALLET_TEST_RECHARGE === 'true' ? 'test' : 'unavailable';

async function cashfree(method, path, body) {
  const { appId, secretKey, baseUrl } = cashfreeConfig();
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', 'x-api-version': '2023-08-01', 'x-client-id': appId, 'x-client-secret': secretKey },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(20000),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) { console.error(`Cashfree ${method} ${path} failed:`, response.status, data.message || ''); throw fail(502, 'Payment service is not reachable. Please try again.'); }
  return data;
}

// Cashfree needs a 10-digit phone; email-only accounts use a placeholder.
const checkoutPhone = (user) => { const digits = String(user.phone || user.profile?.phone || '').replace(/\D/g, '').slice(-10); return digits.length === 10 ? digits : '9999999999'; };

async function createCashfreeOrder({ orderId, amount, user }) {
  const publicUrl = (process.env.PUBLIC_URL || 'https://vakil-rivr.onrender.com').replace(/\/$/, '');
  const order = await cashfree('POST', '/orders', {
    order_id: orderId, order_amount: amount, order_currency: 'INR',
    customer_details: { customer_id: user._id.toString(), customer_phone: checkoutPhone(user), customer_email: user.email || user.profile?.email || undefined, customer_name: user.profile?.fullName || undefined },
    order_meta: { notify_url: `${publicUrl}/api/wallet/cashfree/webhook` },
    order_note: 'Legally Talk wallet recharge',
  });
  return order.payment_session_id;
}

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
  return { balance: await balanceOf(userId), currency: 'INR', paymentMode: mode, rechargeOptions: [100, 200, 500, 1000], minRecharge: MIN_RECHARGE, maxRecharge: MAX_RECHARGE, transactions: rows.map(transactionView) };
}

// ---------------------------------------------------------------- recharge

// Step 1: the server fixes the amount and creates the order.
export async function createRechargeOrder({ user, amount }) {
  amount = round2(amount);
  if (!Number.isFinite(amount) || amount < MIN_RECHARGE || amount > MAX_RECHARGE) throw fail(400, `Enter an amount between ₹${MIN_RECHARGE} and ₹${MAX_RECHARGE.toLocaleString('en-IN')}`);
  const mode = paymentMode();
  if (mode === 'unavailable') throw fail(503, 'Wallet recharge is not available yet');
  const payments = getDb().collection('payments'); const now = new Date(); const _id = new ObjectId();
  const gatewayOrderId = mode === 'cashfree' ? `wallet_${_id}` : `test_order_${_id}`;
  const paymentSessionId = mode === 'cashfree' ? await createCashfreeOrder({ orderId: gatewayOrderId, amount, user }) : null;
  await payments.insertOne({ _id, userId: user._id, amount, currency: 'INR', purpose: 'wallet_recharge', method: mode === 'cashfree' ? 'Cashfree' : 'Test recharge', gateway: mode, gatewayOrderId, status: 'pending', createdAt: now, updatedAt: now });
  return { orderId: gatewayOrderId, paymentId: _id.toString(), amount, currency: 'INR', mode, paymentSessionId, cashfreeEnvironment: mode === 'cashfree' ? cashfreeConfig().environment : null };
}

// Credits a pending payment exactly once: claim it first so a repeated
// verify (or the webhook arriving at the same time) cannot credit twice.
async function creditPayment(payment, gatewayRef) {
  const payments = getDb().collection('payments');
  const claimed = await payments.updateOne({ _id: payment._id, status: 'pending' }, { $set: { status: 'successful', gatewayRef, paidAt: new Date(), updatedAt: new Date() } });
  if (!claimed.matchedCount) return { balance: await balanceOf(payment.userId), amount: payment.amount, alreadyCredited: true };
  const transaction = await changeBalance({ userId: payment.userId, type: 'credit', amount: payment.amount, reason: 'recharge', paymentId: payment._id });
  return { balance: transaction.balanceAfter, amount: payment.amount, transaction };
}

// Asks Cashfree for the order's real status (the app's word is never enough).
async function settleCashfree(payment) {
  const path = `/orders/${encodeURIComponent(payment.gatewayOrderId)}`;
  const order = await cashfree('GET', path);
  if (order.order_status === 'PAID') {
    if (round2(order.order_amount) !== round2(payment.amount)) throw fail(400, 'Payment could not be verified');
    const attempts = await cashfree('GET', `${path}/payments`).catch(() => []);
    const paid = Array.isArray(attempts) ? attempts.find((p) => p.payment_status === 'SUCCESS') : null;
    return creditPayment(payment, String(paid?.cf_payment_id || order.cf_order_id || payment.gatewayOrderId));
  }
  if (order.order_status === 'ACTIVE') throw fail(409, 'The payment is not complete yet. If money was taken, it will be added in a few minutes.');
  await getDb().collection('payments').updateOne({ _id: payment._id, status: 'pending' }, { $set: { status: 'failed', failureReason: `Cashfree: ${order.order_status}`, updatedAt: new Date() } });
  throw fail(400, 'Payment failed. No money was added.');
}

// Step 2: after checkout the app asks the server to check the order with Cashfree.
export async function verifyRecharge({ user, orderId }) {
  const payment = await getDb().collection('payments').findOne({ gatewayOrderId: String(orderId || ''), userId: user._id });
  if (!payment) throw fail(404, 'Payment not found');
  if (payment.status === 'successful') return { balance: await balanceOf(user._id), amount: payment.amount, alreadyCredited: true };
  if (payment.status !== 'pending') throw fail(409, 'This payment was not completed');
  if (payment.gateway === 'cashfree') {
    if (!cashfreeConfig()) throw fail(503, 'Payment service is not configured');
    return settleCashfree(payment);
  }
  if (payment.gateway !== 'test' || paymentMode() !== 'test') throw fail(400, 'Payment could not be verified');
  return creditPayment(payment, `test_pay_${payment._id}`);
}

// Cashfree's server-to-server notice (also covers an app closed mid-payment).
// Only the order id is taken from it; the status is re-checked with Cashfree.
export async function handleCashfreeWebhook(body) {
  const orderId = String(body?.data?.order?.order_id || '');
  if (!orderId || !cashfreeConfig()) return { ok: true };
  const payment = await getDb().collection('payments').findOne({ gatewayOrderId: orderId, gateway: 'cashfree' });
  if (payment?.status === 'pending') await settleCashfree(payment).catch((e) => { if (!e.status) throw e; });
  return { ok: true };
}

// Every 10 minutes: recharges still pending after 30 minutes (checkout closed
// and no webhook) are asked about once more. Paid ones are credited, failed
// ones marked failed, and ones Cashfree still shows as open after a day expire.
export async function settleStalePayments() {
  const payments = getDb().collection('payments'); const now = Date.now();
  const stale = await payments.find({ status: 'pending', createdAt: { $lt: new Date(now - 30 * 60000) } }).limit(50).toArray();
  for (const payment of stale) {
    const old = new Date(payment.createdAt).getTime() < now - 24 * 3600000;
    if (payment.gateway === 'cashfree' && cashfreeConfig()) {
      try { await settleCashfree(payment); continue; }
      catch (e) { if (!e.status) { console.error('Payment re-check failed:', e.message); continue; } }
      // 409 = still open at Cashfree: give it a day before calling it expired.
      if (!old) continue;
    } else if (payment.gateway === 'cashfree' && !old) continue;
    await payments.updateOne({ _id: payment._id, status: 'pending' }, { $set: { status: 'failed', failureReason: 'Checkout not completed (expired)', updatedAt: new Date() } });
  }
  return stale.length;
}

// The user closed or failed the checkout. A Cashfree order is checked first,
// in case it was paid after all.
export async function cancelRecharge({ user, orderId, reason }) {
  const payments = getDb().collection('payments');
  const payment = await payments.findOne({ gatewayOrderId: String(orderId || ''), userId: user._id, status: 'pending' });
  if (!payment) return { ok: true };
  if (payment.gateway === 'cashfree' && cashfreeConfig()) {
    const result = await settleCashfree(payment).catch((e) => { if (!e.status) throw e; return null; });
    return result ? { ok: true, credited: true, ...result } : { ok: true };
  }
  await payments.updateOne({ _id: payment._id, status: 'pending' }, { $set: { status: 'failed', failureReason: String(reason || 'Cancelled').slice(0, 200), updatedAt: new Date() } });
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
