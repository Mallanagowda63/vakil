import { Router } from 'express';
import { getDb } from '../db.js';
import { roles } from './auth.js';
import { adminEndCall } from '../services/calls.js';
import { completeSession } from '../services/consultations.js';
import { changeBalance } from '../services/wallet.js';
import { accountsById, dateRange, idOf, nameOf, page, seconds, sendCsv, startOfToday, toId } from '../services/adminData.js';

// Admin Panel: settings, money, support and reports. Money collections
// (payments, wallet_transactions, payouts, refunds) hold real records only;
// they stay empty until the apps start charging, and the pages show that.
export const adminOpsRouter = Router();
adminOpsRouter.use(...roles('admin'));

const fail = (status, message) => Object.assign(new Error(message), { status });
const run = (fn) => async (req, res) => {
  try { res.json(await fn(req)); }
  catch (e) { if (!e.status) throw e; res.status(e.status).json({ error: e.message }); }
};
const sum = (rows, get) => rows.reduce((n, r) => n + (Number(get(r)) || 0), 0);
const round2 = (n) => Math.round(n * 100) / 100;
const adminOf = (req) => ({ id: req.user._id, phone: req.user.phone || null });
const col = (name) => getDb().collection(name);

// ---------------------------------------------------------------- settings

const refundRuleDefaults = [
  { id: 'lawyer_rejected', scenario: 'Lawyer rejects the request', description: 'The lawyer declines before any chat starts.', action: 'Full refund', automatic: true, enabled: true },
  { id: 'request_expired', scenario: 'Lawyer does not respond', description: 'No answer within 60 seconds; the request expires.', action: 'Full refund', automatic: true, enabled: true },
  { id: 'customer_cancelled', scenario: 'Customer cancels while waiting', description: 'The customer cancels before the lawyer accepts.', action: 'Full refund', automatic: true, enabled: true },
  { id: 'lost_connection', scenario: 'Connection lost early', description: 'The chat or call drops in the first 2 minutes and does not resume.', action: 'Refund billed minutes', automatic: false, enabled: true },
  { id: 'call_failed', scenario: 'Voice call fails to connect', description: 'The call ends as failed (no audio connection).', action: 'No charge for the call', automatic: true, enabled: true },
  { id: 'lawyer_ended_early', scenario: 'Lawyer ends the chat within 1 minute', description: 'The lawyer taps End Chat almost immediately.', action: 'Full refund after review', automatic: false, enabled: true },
  { id: 'free_trial', scenario: 'Free trial chat', description: "The customer's first 1-minute chat is always free.", action: 'Nothing to refund (₹0)', automatic: true, enabled: true, locked: true },
];

export const settingDefaults = {
  pricing: { minPerMinute: 10, maxPerMinute: 45, chatPerMinute: 10, callPerMinute: 40, nightPerMinute: 35, nightFrom: '21:00', nightTo: '06:00', promoDiscountPercent: 10, lawyerOverrides: true },
  commission: { defaultPercent: 20, overrideMinPercent: 15, overrideMaxPercent: 30, promoPercent: 15, promoUntil: '', taxNote: 'GST on platform fee as applicable', effectiveFrom: '' },
  billing: { intervalSeconds: 10, minimumCharge: 0, graceSeconds: 30, connectionTimeoutSeconds: 60, lowBalanceWarnings: 2, reconnectSeconds: 30, gstPercent: 18, customerCancelBeforeConnect: 'No charge', lawyerCancelAfterAccept: 'No charge to customer', lowBalanceEnd: 'Charge through the last billed interval' },
  payouts: { minimumWithdrawal: 2500, schedule: 'Every Friday', holdDays: 3 },
  refundRules: { rules: refundRuleDefaults },
};

export async function getSetting(key) {
  const doc = await col('settings').findOne({ key });
  return { ...settingDefaults[key], ...(doc?.value || {}) };
}

// Keeps only known fields, with the default's type (numbers stay numbers).
function cleanSetting(key, input) {
  const base = settingDefaults[key]; const out = {};
  for (const [field, fallback] of Object.entries(base)) {
    if (!(field in (input || {}))) continue;
    const value = input[field];
    if (typeof fallback === 'number') { const n = Number(value); if (!Number.isFinite(n) || n < 0) throw fail(400, `${field} must be a number of 0 or more`); out[field] = n; }
    else if (typeof fallback === 'boolean') out[field] = Boolean(value);
    else if (Array.isArray(fallback)) out[field] = fallback.map((rule) => { const given = (value || []).find((r) => r.id === rule.id) || {}; return rule.locked ? rule : { ...rule, action: String(given.action ?? rule.action).slice(0, 80), enabled: given.enabled ?? rule.enabled, automatic: given.automatic ?? rule.automatic }; });
    else out[field] = String(value ?? '').slice(0, 200);
  }
  if (key === 'pricing' && (out.minPerMinute ?? base.minPerMinute) > (out.maxPerMinute ?? base.maxPerMinute)) throw fail(400, 'The minimum rate cannot be above the maximum rate');
  return out;
}

adminOpsRouter.get('/settings/:key', run(async (req) => {
  const { key } = req.params; if (!settingDefaults[key]) throw fail(404, 'Unknown setting');
  const doc = await col('settings').findOne({ key });
  const audit = await col('settings_audit').find({ key }).sort({ createdAt: -1 }).limit(20).toArray();
  return { value: await getSetting(key), updatedAt: doc?.updatedAt || null, updatedBy: doc?.updatedBy || null, audit: audit.map((a) => ({ id: a._id.toString(), changes: a.changes, adminPhone: a.adminPhone, reason: a.reason || '', createdAt: a.createdAt })) };
}));

adminOpsRouter.put('/settings/:key', run(async (req) => {
  const { key } = req.params; if (!settingDefaults[key]) throw fail(404, 'Unknown setting');
  const before = await getSetting(key); const value = { ...before, ...cleanSetting(key, req.body.value) };
  const changes = Object.keys(value).filter((f) => JSON.stringify(value[f]) !== JSON.stringify(before[f])).map((f) => ({ field: f, from: before[f], to: value[f] }));
  if (!changes.length) return { value, changes: [] };
  const admin = adminOf(req); const now = new Date();
  await col('settings').updateOne({ key }, { $set: { key, value, updatedAt: now, updatedBy: admin.phone } }, { upsert: true });
  await col('settings_audit').insertOne({ key, changes, adminId: admin.id, adminPhone: admin.phone, reason: String(req.body.reason || '').slice(0, 300), createdAt: now });
  return { value, changes };
}));

// ---------------------------------------------------------------- money data

// Wallet balances from the ledger. Amounts are signed: + credit, − debit.
// User wallet rows keep a positive amount and a type (debit = money out); lawyer rows are signed.
export const signedAmount = (t) => t.type === 'debit' ? -Math.abs(t.amount) : t.amount;
function balances(transactions) {
  const kind = (t) => t.kind ?? t.type;
  const by = (type) => sum(transactions.filter((t) => kind(t) === type && t.status !== 'failed'), (t) => t.amount);
  return {
    balance: round2(sum(transactions.filter((t) => t.status !== 'failed'), (t) => kind(t) === 'debit' ? -Math.abs(t.amount) : t.amount)),
    recharges: sum(transactions.filter((t) => kind(t) === 'credit' && t.reason === 'recharge'), (t) => t.amount), deductions: Math.abs(by('debit')), credits: sum(transactions.filter((t) => kind(t) === 'credit' && t.reason !== 'recharge'), (t) => t.amount), refunds: by('refund'),
    failed: Math.abs(sum(transactions.filter((t) => t.status === 'failed'), (t) => t.amount)),
    earnings: by('earning'), commission: Math.abs(by('commission')), tax: Math.abs(by('tax')), penalties: Math.abs(by('penalty')), adjustments: by('adjustment'), paidOut: Math.abs(by('payout')),
  };
}

async function ledger(role) {
  const rows = await col('wallet_transactions').find({ accountRole: role }).sort({ createdAt: -1 }).toArray();
  const accounts = await accountsById(role === 'lawyer' ? 'lawyers' : 'users', rows.map((r) => r.accountId));
  return rows.map((t) => ({ id: t._id.toString(), accountId: idOf(t.accountId), accountName: nameOf(accounts.get(idOf(t.accountId)), role === 'lawyer' ? 'Lawyer' : 'Customer'), type: t.reason ? `${t.type} · ${t.reason}` : t.type, kind: t.type, reason: t.reason || null, amount: signedAmount(t), balanceAfter: t.balanceAfter ?? null, status: t.status || 'settled', reference: t.reference || '', requestId: idOf(t.requestId), createdAt: t.createdAt }));
}

async function lawyerMoney() {
  const [lawyers, requests, payouts, transactions, commission, payoutRules] = await Promise.all([
    col('lawyers').find({}).toArray(), col('consultation_requests').find({ status: 'COMPLETED' }).toArray(), col('payouts').find({}).toArray(), col('wallet_transactions').find({ accountRole: 'lawyer' }).toArray(), getSetting('commission'), getSetting('payouts'),
  ]);
  return lawyers.map((l) => {
    const id = l._id.toString(); const rate = l.commissionOverride ?? commission.defaultPercent;
    const gross = sum(requests.filter((r) => idOf(r.lawyerId) === id), (r) => r.amount);
    const fee = round2(gross * rate / 100); const ledgerRows = transactions.filter((t) => idOf(t.accountId) === id); const extra = balances(ledgerRows);
    const paid = sum(payouts.filter((p) => idOf(p.lawyerId) === id && p.status === 'paid'), (p) => p.amount);
    const queued = sum(payouts.filter((p) => idOf(p.lawyerId) === id && ['pending', 'processing', 'on_hold'].includes(p.status)), (p) => p.amount);
    const net = round2(gross - fee - extra.tax - extra.penalties + extra.adjustments);
    return { id, name: nameOf(l, 'Lawyer'), phone: l.phone || null, commissionPercent: rate, gross, commission: fee, tax: extra.tax, penalties: extra.penalties, adjustments: extra.adjustments, net, paid, queued, withdrawable: Math.max(0, round2(net - paid - queued)), minimumWithdrawal: payoutRules.minimumWithdrawal, bank: bankOf(l) };
  });
}

const bankOf = (l) => { const b = l.registration?.bank; if (!b) return null; const acc = String(b.accountNumber || ''); return { holderName: b.holderName || '', ifsc: b.ifsc || '', account: acc ? `•••• ${acc.slice(-4)}` : '', upi: b.upi || '' }; };

// ---------------------------------------------------------------- main dashboard

adminOpsRouter.get('/overview', run(async () => {
  const today = startOfToday(); const weekAgo = new Date(Date.now() - 7 * 86400000);
  const [users, lawyers, requests, calls, payments, payouts, complaints, refunds, reviews] = await Promise.all([
    col('users').find({ role: { $ne: 'admin' } }).project({ createdAt: 1 }).toArray(), col('lawyers').find({}).toArray(), col('consultation_requests').find({}).toArray(), col('calls').find({}).toArray(),
    col('payments').find({}).toArray(), col('payouts').find({}).toArray(), col('complaints').find({}).toArray(), col('refunds').find({}).toArray(), col('reviews').find({}).toArray(),
  ]);
  const commission = await getSetting('commission');
  const paidToday = payments.filter((p) => p.status === 'successful' && new Date(p.createdAt) >= today);
  const revenueToday = sum(paidToday, (p) => p.amount);
  const months = Array.from({ length: 7 }, (_, i) => { const d = new Date(); d.setDate(1); d.setHours(0, 0, 0, 0); d.setMonth(d.getMonth() - 6 + i); return d; });
  const inMonth = (date, m) => { const d = new Date(date); return d.getFullYear() === m.getFullYear() && d.getMonth() === m.getMonth(); };
  const categories = {}; for (const r of requests) categories[r.category || 'Other'] = (categories[r.category || 'Other'] || 0) + 1;
  const topCategories = Object.entries(categories).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([name, count]) => ({ name, count, percent: Math.round(count / requests.length * 100) }));
  const topLawyers = lawyers.map((l) => { const mine = requests.filter((r) => idOf(r.lawyerId) === l._id.toString() && r.status === 'COMPLETED'); return { id: l._id.toString(), name: nameOf(l, 'Lawyer'), category: l.categories?.[0] || '', consultations: mine.length, earnings: sum(mine, (r) => r.amount) }; }).sort((a, b) => b.consultations - a.consultations || b.earnings - a.earnings).slice(0, 5);
  const weekOld = (list) => list.filter((x) => new Date(x.createdAt) < weekAgo).length;
  return {
    registration: { customers: users.length, customersLastWeek: weekOld(users), lawyers: lawyers.length, lawyersLastWeek: weekOld(lawyers), pendingVerification: lawyers.filter((l) => !l.approved && !l.blocked && l.verificationStatus !== 'rejected').length, lawyersOnline: lawyers.filter((l) => l.connected).length },
    communication: { activeChats: requests.filter((r) => r.status === 'ONGOING').length, activeCalls: calls.filter((c) => ['ringing', 'answered'].includes(c.status)).length, consultationsToday: requests.filter((r) => new Date(r.createdAt) >= today).length, callsToday: calls.filter((c) => new Date(c.startedAt) >= today).length },
    finance: { customerPaymentsToday: revenueToday, platformCommissionToday: round2(revenueToday * commission.defaultPercent / 100), lawyerEarningsToday: round2(revenueToday * (100 - commission.defaultPercent) / 100), pendingPayouts: sum(payouts.filter((p) => ['pending', 'processing', 'on_hold'].includes(p.status)), (p) => p.amount), anyPayments: payments.length > 0 },
    alerts: { refundRequests: refunds.filter((r) => r.status === 'pending').length, openComplaints: complaints.filter((c) => c.status !== 'resolved').length, failedPayments: payments.filter((p) => p.status === 'failed').length, flaggedReviews: reviews.filter((r) => r.flagged).length },
    monthly: months.map((m) => ({ label: m.toLocaleString('en-IN', { month: 'short' }), consultations: requests.filter((r) => inMonth(r.createdAt, m)).length, revenue: sum(payments.filter((p) => p.status === 'successful' && inMonth(p.createdAt, m)), (p) => p.amount) })),
    topCategories, topLawyers,
  };
}));

// ---------------------------------------------------------------- lawyer workspace

adminOpsRouter.get('/lawyers/:id', run(async (req) => {
  const _id = toId(req.params.id); const lawyer = _id && await col('lawyers').findOne({ _id });
  if (!lawyer) throw fail(404, 'Lawyer not found');
  const [requests, reviews, complaints, pricing, commission, money] = await Promise.all([
    col('consultation_requests').find({ lawyerId: _id }).sort({ createdAt: -1 }).toArray(), col('reviews').find({ lawyerId: _id }).toArray(), col('complaints').find({ lawyerId: _id }).sort({ createdAt: -1 }).toArray(), getSetting('pricing'), getSetting('commission'), lawyerMoney(),
  ]);
  const users = await accountsById('users', requests.map((r) => r.userId));
  const visibleReviews = reviews.filter((r) => !r.hidden); const reg = lawyer.registration || {};
  return {
    lawyer: {
      id: lawyer._id.toString(), name: nameOf(lawyer, 'Lawyer'), phone: lawyer.phone || null, email: reg.personal?.email || lawyer.profile?.email || null, photoUrl: lawyer.profile?.photoUrl || null,
      categories: lawyer.categories || [], approved: Boolean(lawyer.approved), blocked: Boolean(lawyer.blocked), verificationStatus: verificationStatusOf(lawyer), verificationNotes: lawyer.verificationNotes || '', approvedAt: lawyer.approvedAt || null, approvedBy: lawyer.approvedBy || null,
      online: Boolean(lawyer.online), appConnected: Boolean(lawyer.connected), lastSeenAt: lawyer.lastSeenAt || null, createdAt: lawyer.createdAt || null,
      featured: Boolean(lawyer.featured), recommended: Boolean(lawyer.recommended), channels: { chat: lawyer.channels?.chat !== false, call: lawyer.channels?.call !== false },
      rateOverride: lawyer.ratePerMinute ?? null, commissionOverride: lawyer.commissionOverride ?? null, defaultRate: pricing.chatPerMinute, defaultCommission: commission.defaultPercent,
      registration: { submittedAt: reg.submittedAt || null, dateOfBirth: reg.personal?.dateOfBirth || null, gender: reg.personal?.gender || null, barCouncilRegNo: reg.advocate?.barCouncilRegNo || null, practiceArea: reg.advocate?.practiceArea || null, city: reg.advocate?.city || null, court: reg.advocate?.court || null, languages: reg.advocate?.languages || null, faceVerified: Boolean(reg.personal?.faceVerified), licenseUploaded: Boolean(reg.advocate?.licenseFileName) },
      bank: bankOf(lawyer), money: money.find((m) => m.id === lawyer._id.toString()),
    },
    stats: { consultations: requests.filter((r) => r.status === 'COMPLETED').length, requests: requests.length, ratingAverage: visibleReviews.length ? round2(sum(visibleReviews, (r) => r.rating) / visibleReviews.length) : null, ratingCount: visibleReviews.length, openComplaints: complaints.filter((c) => c.status !== 'resolved').length },
    recent: requests.slice(0, 10).map((r) => ({ id: r._id.toString(), userName: r.userName || nameOf(users.get(idOf(r.userId)), 'Client'), category: r.category, status: r.status, isTrial: Boolean(r.isTrial), createdAt: r.createdAt, durationSeconds: r.durationSeconds ?? null, rating: r.rating ?? null })),
    complaints: complaints.slice(0, 10).map(complaintView),
  };
}));

export const verificationStatusOf = (l) => l.blocked ? 'suspended' : l.approved ? 'approved' : l.verificationStatus === 'rejected' ? 'rejected' : l.registration?.submittedAt ? 'under_review' : 'pending';

// ---------------------------------------------------------------- live actions

adminOpsRouter.post('/requests/:id/end', run(async (req) => {
  const _id = toId(req.params.id); const request = _id && await col('consultation_requests').findOne({ _id });
  if (!request) throw fail(404, 'Request not found');
  if (request.status !== 'ONGOING') throw fail(409, 'This chat is not ongoing');
  await completeSession({ requestId: req.params.id, actorId: req.user._id, actorRole: 'admin' });
  return { ok: true };
}));

adminOpsRouter.post('/calls/:id/end', run(async (req) => ({ call: await adminEndCall(req.params.id) })));

adminOpsRouter.post('/requests/:id/flag', run(async (req) => {
  const _id = toId(req.params.id); const flagged = req.body.flagged !== false;
  const { matchedCount } = await col('consultation_requests').updateOne({ _id }, { $set: { flagged, flagNote: String(req.body.note || '').slice(0, 300), flaggedAt: flagged ? new Date() : null } });
  if (!matchedCount) throw fail(404, 'Request not found');
  return { ok: true };
}));

// ---------------------------------------------------------------- billing

adminOpsRouter.get('/billing', run(async (req) => {
  const today = startOfToday();
  const [requests, payments, refunds, billing, pricing] = await Promise.all([col('consultation_requests').find({ status: 'COMPLETED' }).sort({ completedAt: -1 }).toArray(), col('payments').find({}).toArray(), col('refunds').find({}).toArray(), getSetting('billing'), getSetting('pricing')]);
  const paidChats = requests.filter((r) => !r.isTrial);
  const todayChats = paidChats.filter((r) => new Date(r.completedAt || r.updatedAt) >= today);
  const p = page(req.query, requests.length); const users = await accountsById('users', requests.map((r) => r.userId));
  return {
    stats: { minutesToday: sum(todayChats, (r) => r.billedMinutes ?? Math.round((r.durationSeconds || 0) / 60)), trialMinutesToday: Math.round(sum(requests.filter((r) => r.isTrial && new Date(r.completedAt || r.updatedAt) >= today), (r) => r.durationSeconds) / 60), adjustmentsToday: refunds.filter((r) => new Date(r.createdAt) >= today).length, accruedToday: round2(sum(todayChats, (r) => r.totalAmount ?? r.amount ?? 0)), chargingEnabled: true },
    settings: billing, pricing,
    log: { items: requests.slice(p.skip, p.skip + p.limit).map((r) => ({ id: r._id.toString(), userName: r.userName || nameOf(users.get(idOf(r.userId)), 'Client'), lawyerName: r.lawyerName || 'Lawyer', isTrial: Boolean(r.isTrial), minutes: r.billedMinutes ?? Math.ceil((r.durationSeconds || 0) / 60), durationSeconds: r.durationSeconds || 0, amount: r.totalAmount ?? r.amount ?? 0, endedBy: r.endedBy || null, completedAt: r.completedAt || null, rule: r.isTrial ? 'Free trial' : (r.totalAmount ?? r.amount) ? (r.endReason === 'balance_over' ? 'Billed · balance ran out' : 'Billed') : 'Not charged' })), total: requests.length, page: p.page, pages: p.pages },
  };
}));

// ---------------------------------------------------------------- payments

async function paymentRows(query = {}) {
  const filter = {}; if (query.status) filter.status = query.status; if (query.method) filter.method = query.method;
  const created = dateRange(query.from, query.to); if (created) filter.createdAt = created;
  const rows = await col('payments').find(filter).sort({ createdAt: -1 }).toArray();
  const users = await accountsById('users', rows.map((r) => r.userId));
  const q = String(query.q || '').toLowerCase();
  return rows.map((r) => ({ id: r._id.toString(), requestId: idOf(r.requestId), userId: idOf(r.userId), customer: nameOf(users.get(idOf(r.userId)), 'Customer'), phone: users.get(idOf(r.userId))?.phone || null, amount: r.amount || 0, method: r.method || '—', status: r.status || 'pending', gatewayRef: r.gatewayRef || '', createdAt: r.createdAt, updatedAt: r.updatedAt || r.createdAt }))
    .filter((r) => !q || `${r.id} ${r.requestId} ${r.customer} ${r.phone} ${r.gatewayRef}`.toLowerCase().includes(q));
}

adminOpsRouter.get('/payments', run(async (req) => {
  const all = await paymentRows(); const rows = await paymentRows(req.query); const p = page(req.query, rows.length);
  return { stats: { methods: [...new Set(all.map((r) => r.method))].filter((m) => m !== '—'), completed: all.filter((r) => r.status === 'successful').length, pending: all.filter((r) => r.status === 'pending').length, failed: all.filter((r) => r.status === 'failed').length, refunded: all.filter((r) => r.status === 'refunded').length, volume: sum(all.filter((r) => r.status === 'successful'), (r) => r.amount) }, items: rows.slice(p.skip, p.skip + p.limit), total: rows.length, page: p.page, pages: p.pages };
}));

adminOpsRouter.get('/payments.csv', async (req, res) => {
  sendCsv(res, 'vakil-payments.csv', [['Payment ID', (r) => r.id], ['Request ID', (r) => r.requestId], ['Customer', (r) => r.customer], ['Phone', (r) => r.phone], ['Amount (INR)', (r) => r.amount], ['Method', (r) => r.method], ['Status', (r) => r.status], ['Gateway ref', (r) => r.gatewayRef], ['Created', (r) => r.createdAt]], await paymentRows(req.query));
});

// ---------------------------------------------------------------- wallets

adminOpsRouter.get('/wallets', run(async () => {
  const [customer, lawyer] = await Promise.all([ledger('user'), ledger('lawyer')]);
  const totals = (rows) => balances(rows.map((r) => ({ ...r, amount: r.amount })));
  return { customer: { totals: totals(customer), items: customer.slice(0, 200) }, lawyer: { totals: totals(lawyer), items: lawyer.slice(0, 200), accounts: await lawyerMoney() } };
}));

adminOpsRouter.get('/wallets.csv', async (req, res) => {
  const rows = [...await ledger('user'), ...await ledger('lawyer')];
  sendCsv(res, 'vakil-wallet-ledger.csv', [['Entry ID', (r) => r.id], ['Account', (r) => r.accountName], ['Type', (r) => r.type], ['Amount (INR)', (r) => r.amount], ['Status', (r) => r.status], ['Reference', (r) => r.reference], ['Posted', (r) => r.createdAt]], rows);
});

// ---------------------------------------------------------------- payouts

const payoutFlow = { pending: ['processing', 'on_hold', 'failed'], processing: ['paid', 'failed', 'on_hold'], on_hold: ['pending', 'failed'], failed: ['pending'], paid: ['reversed'] };

adminOpsRouter.get('/payouts', run(async (req) => {
  const [rows, accounts, rules] = await Promise.all([col('payouts').find(req.query.status ? { status: req.query.status } : {}).sort({ createdAt: -1 }).toArray(), lawyerMoney(), getSetting('payouts')]);
  const names = new Map(accounts.map((a) => [a.id, a]));
  const items = rows.map((p) => ({ id: p._id.toString(), lawyerId: idOf(p.lawyerId), lawyerName: names.get(idOf(p.lawyerId))?.name || 'Lawyer', amount: p.amount, method: p.method || 'Bank', status: p.status, reference: p.reference || '', note: p.note || '', createdAt: p.createdAt, updatedAt: p.updatedAt || p.createdAt, bank: names.get(idOf(p.lawyerId))?.bank || null }));
  return { rules, items, accounts, stats: { queued: sum(items.filter((p) => p.status === 'pending' || p.status === 'processing'), (p) => p.amount), onHold: items.filter((p) => p.status === 'on_hold').length, failed: items.filter((p) => p.status === 'failed').length, paid: sum(items.filter((p) => p.status === 'paid'), (p) => p.amount), unverifiedBank: accounts.filter((a) => !a.bank).length } };
}));

// "Process pending payouts": one payout per lawyer whose withdrawable balance reaches the minimum.
adminOpsRouter.post('/payouts/run', run(async (req) => {
  const accounts = await lawyerMoney(); const now = new Date();
  const due = accounts.filter((a) => a.withdrawable >= a.minimumWithdrawal && a.withdrawable > 0);
  for (const a of due) await col('payouts').insertOne({ lawyerId: toId(a.id), amount: a.withdrawable, method: a.bank?.upi ? 'UPI' : 'Bank', status: 'pending', createdAt: now, updatedAt: now, createdBy: adminOf(req).phone });
  return { created: due.length, skipped: accounts.length - due.length };
}));

adminOpsRouter.patch('/payouts/:id', run(async (req) => {
  const _id = toId(req.params.id); const payout = _id && await col('payouts').findOne({ _id });
  if (!payout) throw fail(404, 'Payout not found');
  const status = String(req.body.status || '');
  if (!payoutFlow[payout.status]?.includes(status)) throw fail(409, `A ${payout.status} payout cannot become ${status}`);
  const now = new Date(); const reference = String(req.body.reference || payout.reference || '').slice(0, 80);
  await col('payouts').updateOne({ _id, status: payout.status }, { $set: { status, reference, note: String(req.body.note || payout.note || '').slice(0, 300), updatedAt: now } });
  // Money leaves the lawyer's wallet when paid, and comes back if the transfer is reversed.
  if (status === 'paid') await col('wallet_transactions').insertOne({ accountId: payout.lawyerId, accountRole: 'lawyer', type: 'payout', amount: -payout.amount, status: 'settled', reference: reference || `PAYOUT-${_id}`, payoutId: _id, createdAt: now });
  if (status === 'reversed') await col('wallet_transactions').insertOne({ accountId: payout.lawyerId, accountRole: 'lawyer', type: 'adjustment', amount: payout.amount, status: 'settled', reference: `REVERSAL-${_id}`, payoutId: _id, createdAt: now });
  return { ok: true };
}));

// ---------------------------------------------------------------- refunds

adminOpsRouter.get('/refunds', run(async () => {
  const [rows, rules] = await Promise.all([col('refunds').find({}).sort({ createdAt: -1 }).toArray(), getSetting('refundRules')]);
  const users = await accountsById('users', rows.map((r) => r.userId));
  const items = rows.map((r) => ({ id: r._id.toString(), requestId: idOf(r.requestId), paymentId: idOf(r.paymentId), customer: nameOf(users.get(idOf(r.userId)), 'Customer'), phone: users.get(idOf(r.userId))?.phone || null, amount: r.amount || 0, reason: r.reason || '', rule: r.rule || '', status: r.status, mode: r.mode || 'wallet', note: r.note || '', createdAt: r.createdAt, decidedAt: r.decidedAt || null }));
  return { rules: rules.rules, items, stats: { total: items.length, pending: items.filter((r) => r.status === 'pending').length, approvedAmount: sum(items.filter((r) => r.status === 'approved'), (r) => r.amount), rejected: items.filter((r) => r.status === 'rejected').length } };
}));

adminOpsRouter.post('/refunds', run(async (req) => {
  const requestId = toId(req.body.requestId); const request = requestId && await col('consultation_requests').findOne({ _id: requestId });
  if (!request) throw fail(404, 'Request not found');
  const amount = Number(req.body.amount); if (!Number.isFinite(amount) || amount < 0) throw fail(400, 'Enter a valid amount');
  const doc = { requestId, userId: request.userId, paymentId: toId(req.body.paymentId), amount, reason: String(req.body.reason || '').slice(0, 300), rule: String(req.body.rule || ''), mode: req.body.mode === 'original' ? 'original' : 'wallet', status: 'pending', createdAt: new Date(), createdBy: adminOf(req).phone };
  const { insertedId } = await col('refunds').insertOne(doc);
  return { id: insertedId.toString() };
}));

adminOpsRouter.patch('/refunds/:id', run(async (req) => {
  const _id = toId(req.params.id); const refund = _id && await col('refunds').findOne({ _id });
  if (!refund) throw fail(404, 'Refund not found');
  if (refund.status !== 'pending') throw fail(409, 'This refund was already decided');
  const status = req.body.status === 'approved' ? 'approved' : req.body.status === 'rejected' ? 'rejected' : null; if (!status) throw fail(400, 'status must be approved or rejected');
  const now = new Date();
  const { matchedCount } = await col('refunds').updateOne({ _id, status: 'pending' }, { $set: { status, note: String(req.body.note || '').slice(0, 300), decidedAt: now, decidedBy: adminOf(req).phone } });
  if (!matchedCount) throw fail(409, 'This refund was already decided');
  if (status === 'approved') {
    if (refund.mode === 'wallet' && refund.amount > 0) await changeBalance({ userId: refund.userId, type: 'refund', amount: refund.amount, reason: 'refund', requestId: refund.requestId, note: `REFUND-${_id}` });
    if (refund.paymentId) await col('payments').updateOne({ _id: refund.paymentId }, { $set: { status: 'refunded', updatedAt: now } });
  }
  return { ok: true };
}));

// ---------------------------------------------------------------- complaints

const complaintView = (c) => ({ id: c._id.toString(), ticket: c.ticket, requestId: idOf(c.requestId), userId: idOf(c.userId), lawyerId: idOf(c.lawyerId), customer: c.customerName || 'Customer', lawyer: c.lawyerName || '—', category: c.category, description: c.description || '', priority: c.priority || 'medium', status: c.status, assignee: c.assignee || '', notes: c.notes || [], createdAt: c.createdAt, updatedAt: c.updatedAt || c.createdAt });
const complaintStatuses = ['open', 'in_progress', 'escalated', 'resolved'];

adminOpsRouter.get('/complaints', run(async (req) => {
  const all = (await col('complaints').find({}).sort({ createdAt: -1 }).toArray()).map(complaintView);
  const q = String(req.query.q || '').toLowerCase();
  const items = all.filter((c) => (!req.query.status || c.status === req.query.status) && (!req.query.category || c.category === req.query.category) && (!q || `${c.ticket} ${c.customer} ${c.lawyer} ${c.description}`.toLowerCase().includes(q)));
  return { items, stats: Object.fromEntries([['total', all.length], ...complaintStatuses.map((s) => [s, all.filter((c) => c.status === s).length])]) };
}));

// Support logs a complaint (from a phone call or email) against a chat.
adminOpsRouter.post('/complaints', run(async (req) => {
  const requestId = toId(req.body.requestId); const request = requestId && await col('consultation_requests').findOne({ _id: requestId });
  if (!request) throw fail(404, 'Pick the chat this complaint is about');
  const description = String(req.body.description || '').trim(); if (!description) throw fail(400, 'Describe the complaint');
  const count = await col('complaints').countDocuments({}); const now = new Date();
  const doc = { ticket: `CMP-${String(count + 1).padStart(4, '0')}`, requestId, userId: request.userId, lawyerId: request.lawyerId, customerName: request.userName, lawyerName: request.lawyerName, category: String(req.body.category || 'Service quality').slice(0, 60), description: description.slice(0, 2000), priority: ['low', 'medium', 'high'].includes(req.body.priority) ? req.body.priority : 'medium', status: 'open', notes: [], createdAt: now, updatedAt: now, createdBy: adminOf(req).phone };
  const { insertedId } = await col('complaints').insertOne(doc);
  return { complaint: complaintView({ ...doc, _id: insertedId }) };
}));

adminOpsRouter.patch('/complaints/:id', run(async (req) => {
  const _id = toId(req.params.id); const complaint = _id && await col('complaints').findOne({ _id });
  if (!complaint) throw fail(404, 'Complaint not found');
  const set = { updatedAt: new Date() };
  if (req.body.status) { if (!complaintStatuses.includes(req.body.status)) throw fail(400, 'Unknown status'); set.status = req.body.status; if (req.body.status === 'resolved') set.resolvedAt = new Date(); }
  if (req.body.priority) set.priority = ['low', 'medium', 'high'].includes(req.body.priority) ? req.body.priority : complaint.priority;
  if ('assignee' in req.body) set.assignee = String(req.body.assignee || '').slice(0, 80);
  const notes = [...(complaint.notes || [])]; if (req.body.note) notes.push({ text: String(req.body.note).slice(0, 1000), by: adminOf(req).phone, at: new Date() });
  await col('complaints').updateOne({ _id }, { $set: { ...set, notes } });
  return { complaint: complaintView(await col('complaints').findOne({ _id })) };
}));

// ---------------------------------------------------------------- reviews

// Client → lawyer ratings (`reviews`, the lawyers' public rating) and
// lawyer → client feedback (`lawyer_feedback`), both given after a chat or call.
adminOpsRouter.get('/reviews', run(async (req) => {
  const [clientRows, lawyerRows] = await Promise.all([col('reviews').find({}).toArray(), col('lawyer_feedback').find({}).toArray()]);
  const rows = [...clientRows.map((r) => ({ ...r, by: 'customer' })), ...lawyerRows.map((r) => ({ ...r, by: 'lawyer' }))].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  const [users, lawyers] = await Promise.all([accountsById('users', rows.map((r) => r.userId)), accountsById('lawyers', rows.map((r) => r.lawyerId))]);
  const all = rows.map((r) => ({ id: r._id.toString(), by: r.by, requestId: idOf(r.requestId), customer: nameOf(users.get(idOf(r.userId)), 'Customer'), lawyer: nameOf(lawyers.get(idOf(r.lawyerId)), 'Lawyer'), lawyerId: idOf(r.lawyerId), consultationType: r.consultationType || 'chat', rating: r.rating, comment: r.comment || '', hidden: Boolean(r.hidden), flagged: Boolean(r.flagged), createdAt: r.createdAt }));
  const items = all.filter((r) => (!req.query.by || r.by === req.query.by) && (!req.query.rating || String(r.rating) === String(req.query.rating)) && (!req.query.state || (req.query.state === 'flagged' ? r.flagged : req.query.state === 'hidden' ? r.hidden : !r.hidden && !r.flagged)));
  // Averages and the trend are the lawyers' rating: published client reviews only.
  const visible = all.filter((r) => !r.hidden && r.by === 'customer');
  const months = Array.from({ length: 6 }, (_, i) => { const d = new Date(); d.setDate(1); d.setMonth(d.getMonth() - 5 + i); return d; });
  return { items, stats: { total: all.length, fromCustomers: all.filter((r) => r.by === 'customer').length, fromLawyers: all.filter((r) => r.by === 'lawyer').length, average: visible.length ? round2(sum(visible, (r) => r.rating) / visible.length) : null, flagged: all.filter((r) => r.flagged).length, hidden: all.filter((r) => r.hidden).length, lowRatings: all.filter((r) => r.rating <= 2).length }, trend: months.map((m) => { const inMonth = visible.filter((r) => new Date(r.createdAt).getMonth() === m.getMonth() && new Date(r.createdAt).getFullYear() === m.getFullYear()); return { label: m.toLocaleString('en-IN', { month: 'short' }), average: inMonth.length ? round2(sum(inMonth, (r) => r.rating) / inMonth.length) : null, count: inMonth.length }; }) };
}));

adminOpsRouter.patch('/reviews/:id', run(async (req) => {
  const _id = toId(req.params.id); const set = {};
  if ('hidden' in req.body) set.hidden = Boolean(req.body.hidden); if ('flagged' in req.body) set.flagged = Boolean(req.body.flagged);
  const update = { $set: { ...set, moderatedAt: new Date(), moderatedBy: adminOf(req).phone } };
  const { matchedCount } = await col('reviews').updateOne({ _id }, update);
  if (!matchedCount && !(await col('lawyer_feedback').updateOne({ _id }, update)).matchedCount) throw fail(404, 'Review not found');
  return { ok: true };
}));

// ---------------------------------------------------------------- reports

adminOpsRouter.get('/reports', run(async (req) => {
  const days = Math.min(90, Math.max(7, Number(req.query.days) || 30));
  const from = startOfToday(); from.setDate(from.getDate() - days + 1);
  const [requests, calls, payments, refunds, reviews, lawyers, money] = await Promise.all([col('consultation_requests').find({}).toArray(), col('calls').find({}).toArray(), col('payments').find({}).toArray(), col('refunds').find({}).toArray(), col('reviews').find({}).toArray(), col('lawyers').find({}).toArray(), lawyerMoney()]);
  const dayKey = (d) => { const x = new Date(d); return `${x.getFullYear()}-${x.getMonth()}-${x.getDate()}`; };
  const series = Array.from({ length: days }, (_, i) => { const d = new Date(from); d.setDate(from.getDate() + i); const k = dayKey(d); return { date: d, consultations: requests.filter((r) => dayKey(r.createdAt) === k).length, calls: calls.filter((c) => dayKey(c.startedAt) === k).length, revenue: sum(payments.filter((p) => p.status === 'successful' && dayKey(p.createdAt) === k), (p) => p.amount) }; });
  const inRange = requests.filter((r) => new Date(r.createdAt) >= from);
  const categories = {}; for (const r of inRange) categories[r.category || 'Other'] = (categories[r.category || 'Other'] || 0) + 1;
  const successful = payments.filter((p) => p.status === 'successful' && new Date(p.createdAt) >= from); const gross = sum(successful, (p) => p.amount);
  const commissionEarned = sum(money, (m) => m.commission);
  return {
    days, series,
    totals: { consultations: inRange.length, completed: inRange.filter((r) => r.status === 'COMPLETED').length, trial: inRange.filter((r) => r.isTrial).length, calls: calls.filter((c) => new Date(c.startedAt) >= from).length, revenue: gross, refunds: sum(refunds.filter((r) => r.status === 'approved' && new Date(r.createdAt) >= from), (r) => r.amount) },
    categories: Object.entries(categories).sort((a, b) => b[1] - a[1]).map(([name, count]) => ({ name, count, percent: Math.round(count / inRange.length * 100) })),
    topLawyers: lawyers.map((l) => { const id = l._id.toString(); const mine = inRange.filter((r) => idOf(r.lawyerId) === id); const rated = reviews.filter((r) => idOf(r.lawyerId) === id && !r.hidden); const answered = mine.filter((r) => r.acceptedAt || r.rejectedAt); return { id, name: nameOf(l, 'Lawyer'), consultations: mine.filter((r) => r.status === 'COMPLETED').length, requests: mine.length, acceptance: answered.length ? Math.round(mine.filter((r) => r.acceptedAt).length / answered.length * 100) : null, rating: rated.length ? round2(sum(rated, (r) => r.rating) / rated.length) : null, responseSeconds: answered.length ? Math.round(sum(answered, (r) => seconds(r.createdAt, r.acceptedAt || r.rejectedAt)) / answered.length) : null, earnings: money.find((m) => m.id === id)?.gross || 0 }; }).sort((a, b) => b.consultations - a.consultations).slice(0, 10),
    ledger: [
      ['Customer payments received', gross], ['Platform commission (all time)', commissionEarned], ['Lawyer earnings (all time, net)', sum(money, (m) => m.net)], ['Payouts paid (all time)', sum(money, (m) => m.paid)], ['Refunds approved', sum(refunds.filter((r) => r.status === 'approved'), (r) => r.amount)], ['Pending payouts', sum(money, (m) => m.queued)],
    ].map(([label, amount]) => ({ label, amount })),
  };
}));

// ---------------------------------------------------------------- wallet transactions

// Every user wallet entry (recharges, per-minute chat/call charges, refunds),
// filtered by date, user and type.
async function transactionRows(query) {
  const filter = { accountRole: 'user' };
  if (query.userId && toId(query.userId)) filter.accountId = toId(query.userId);
  const created = dateRange(query.from, query.to); if (created) filter.createdAt = created;
  let rows = await col('wallet_transactions').find(filter).sort({ createdAt: -1 }).toArray();
  // type: recharge | chat | call | refund | debit | credit
  const t = String(query.type || '');
  if (t) rows = rows.filter((r) => ['credit', 'debit', 'refund'].includes(t) ? r.type === t : r.reason === t);
  const users = await accountsById('users', rows.map((r) => r.accountId));
  return rows.map((r) => {
    const user = users.get(idOf(r.accountId));
    return { id: r._id.toString(), userId: idOf(r.accountId), customer: nameOf(user, 'Customer'), phone: user?.phone || null, type: r.type, reason: r.reason || null, amount: r.amount, signedAmount: signedAmount(r), balanceAfter: r.balanceAfter ?? null, requestId: idOf(r.requestId), paymentId: idOf(r.paymentId), note: r.note || '', createdAt: r.createdAt };
  });
}

adminOpsRouter.get('/transactions', run(async (req) => {
  const rows = await transactionRows(req.query); const p = page(req.query, rows.length);
  const credits = rows.filter((r) => r.type !== 'debit'); const debits = rows.filter((r) => r.type === 'debit');
  return {
    items: rows.slice(p.skip, p.skip + p.limit), total: rows.length, page: p.page, pages: p.pages,
    totals: { recharged: round2(sum(rows.filter((r) => r.reason === 'recharge'), (r) => r.amount)), charged: round2(sum(debits, (r) => r.amount)), chatCharges: round2(sum(debits.filter((r) => r.reason === 'chat'), (r) => r.amount)), callCharges: round2(sum(debits.filter((r) => r.reason === 'call'), (r) => r.amount)), refunded: round2(sum(credits.filter((r) => r.type === 'refund'), (r) => r.amount)) },
  };
}));

adminOpsRouter.get('/transactions.csv', async (req, res) => {
  sendCsv(res, 'vakil-wallet-transactions.csv', [['Entry ID', (r) => r.id], ['Date', (r) => r.createdAt], ['Customer', (r) => r.customer], ['Phone', (r) => r.phone], ['Type', (r) => r.type], ['Reason', (r) => r.reason], ['Amount (INR)', (r) => r.signedAmount], ['Balance after (INR)', (r) => r.balanceAfter], ['Consultation', (r) => r.requestId], ['Payment', (r) => r.paymentId], ['Note', (r) => r.note]], await transactionRows(req.query));
});

adminOpsRouter.get('/users/:id/wallet', run(async (req) => {
  const _id = toId(req.params.id); const user = _id && await col('users').findOne({ _id });
  if (!user) throw fail(404, 'User not found');
  const items = await transactionRows({ userId: req.params.id });
  return { user: { id: user._id.toString(), name: nameOf(user, 'Customer'), phone: user.phone || null, balance: round2(user.walletBalance || 0), trialUsed: Boolean(user.trialUsed) }, items };
}));
