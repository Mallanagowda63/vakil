import { getDb } from '../db.js';
import { emitAdmin, emitTo } from '../realtime.js';
import { getSetting } from '../routes/adminOps.js';
import { startOfToday } from './adminData.js';
import { round2 } from './wallet.js';

// The lawyer's side of every charge: what the client paid for a chat or call,
// minus the platform commission (Admin → Commission, or the lawyer's own
// override), is written to the lawyer's ledger as an `earning` right away.
// Lawyer balance = earnings − payouts (the same ledger the Admin Panel reads).

const ledger = () => getDb().collection('wallet_transactions');
const sum = (rows, pick) => round2(rows.reduce((n, r) => n + (Number(pick(r)) || 0), 0));

export async function commissionPercentOf(lawyer) {
  if (Number.isFinite(lawyer?.commissionOverride)) return lawyer.commissionOverride;
  return Number((await getSetting('commission')).defaultPercent) || 0;
}

export async function creditLawyer(request, gross, { reason = 'chat', note = '' } = {}) {
  gross = round2(gross);
  if (!(gross > 0) || !request.lawyerId) return null;
  const lawyer = await getDb().collection('lawyers').findOne({ _id: request.lawyerId });
  const percent = await commissionPercentOf(lawyer);
  const commission = round2(gross * percent / 100); const amount = round2(gross - commission);
  const entry = { accountId: request.lawyerId, accountRole: 'lawyer', type: 'earning', reason, amount, gross, commission, commissionPercent: percent, requestId: request._id, clientName: request.userName || 'Client', note, status: 'settled', createdAt: new Date() };
  const { insertedId } = await ledger().insertOne(entry);
  console.log(`[EARN] lawyer=${request.lawyerId} request=${request._id} gross=${gross} commission=${commission} (${percent}%) earned=${amount}`);
  const view = { id: insertedId.toString(), requestId: request._id.toString(), amount, gross, commission, commissionPercent: percent };
  emitTo('lawyer', request.lawyerId, 'earnings_updated', view); emitAdmin('earnings_updated', view);
  return view;
}

// Partner App home and wallet: today's numbers, balance and recent entries.
export async function earningsSummary(lawyerId) {
  const db = getDb(); const since = startOfToday(); const isToday = (d) => d && new Date(d) >= since;
  const [rows, payouts, requests, missedCalls, lawyer, payoutRules] = await Promise.all([
    ledger().find({ accountId: lawyerId, accountRole: 'lawyer' }).sort({ createdAt: -1 }).toArray(),
    db.collection('payouts').find({ lawyerId }).toArray(),
    db.collection('consultation_requests').find({ lawyerId }).toArray(),
    db.collection('calls').find({ receiverId: lawyerId, receiverRole: 'lawyer', status: 'missed' }).toArray(),
    db.collection('lawyers').findOne({ _id: lawyerId }),
    getSetting('payouts'),
  ]);
  const settled = rows.filter((r) => r.status !== 'failed');
  const earnings = settled.filter((r) => r.type === 'earning');
  const balance = sum(settled, (r) => r.amount);
  const queued = sum(payouts.filter((p) => ['pending', 'processing', 'on_hold'].includes(p.status)), (p) => p.amount);
  const opened = requests.filter((r) => isToday(r.acceptedAt));
  const seconds = (r) => r.status === 'ONGOING' && r.sessionStartedAt ? (Date.now() - new Date(r.sessionStartedAt)) / 1000 : (r.durationSeconds || 0);
  return {
    today: {
      consultations: opened.length,
      earnings: sum(earnings.filter((r) => isToday(r.createdAt)), (r) => r.amount),
      minutes: Math.round(opened.reduce((n, r) => n + seconds(r), 0) / 60),
      // Calls not picked up and chat requests not answered in time.
      missed: missedCalls.filter((c) => isToday(c.startedAt)).length + requests.filter((r) => r.status === 'EXPIRED' && isToday(r.expiredAt || r.updatedAt)).length,
    },
    totalEarnings: sum(earnings, (r) => r.amount),
    paidOut: Math.abs(sum(settled.filter((r) => r.type === 'payout'), (r) => r.amount)),
    balance, pendingPayouts: queued, available: Math.max(0, round2(balance - queued)),
    commissionPercent: await commissionPercentOf(lawyer), minimumWithdrawal: payoutRules.minimumWithdrawal,
    transactions: rows.slice(0, 50).map((r) => ({ id: r._id.toString(), type: r.type, reason: r.reason || null, amount: r.amount, gross: r.gross ?? null, commission: r.commission ?? null, clientName: r.clientName || null, note: r.note || '', status: r.status || 'settled', requestId: r.requestId?.toString() || null, createdAt: r.createdAt })),
  };
}

// "Withdraw": queues everything available as one payout for the admin to pay.
export async function requestPayout(lawyerId) {
  const summary = await earningsSummary(lawyerId);
  const fail = (status, message) => Object.assign(new Error(message), { status });
  if (summary.available <= 0) throw fail(400, 'No available balance to withdraw right now.');
  if (summary.available < summary.minimumWithdrawal) throw fail(400, `The minimum withdrawal is ₹${summary.minimumWithdrawal}. You have ₹${summary.available}.`);
  const now = new Date(); const lawyer = await getDb().collection('lawyers').findOne({ _id: lawyerId });
  const payout = { lawyerId, amount: summary.available, method: lawyer?.registration?.bank?.upi ? 'UPI' : 'Bank', status: 'pending', createdAt: now, updatedAt: now, createdBy: 'lawyer' };
  const { insertedId } = await getDb().collection('payouts').insertOne(payout);
  emitAdmin('payout_requested', { id: insertedId.toString(), lawyerId: lawyerId.toString(), amount: payout.amount });
  return { payout: { id: insertedId.toString(), amount: payout.amount, status: 'pending', createdAt: now }, ...(await earningsSummary(lawyerId)) };
}
