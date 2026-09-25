import React, { useState } from 'react';
import { CreditCard, CheckCircle2, Hourglass, AlertTriangle, Wallet as WalletIcon, Clock, CalendarClock, ShieldAlert, Search, Send } from 'lucide-react';
import { api } from '../api.js';
import { Badge, Card, ErrorNote, ExportButton, Note, NotChargingNote, PageHead, Pager, Stat, Stats, Table, dateTime, label, money, number, qs, useLiveData } from '../ui.jsx';
import { SaveBar, useSetting } from './Pricing.jsx';

// ---------------------------------------------------------------- payments

export function Payments() {
  const [filters, setFilters] = useState({ status: '', method: '', q: '', page: 1 });
  const query = qs({ ...filters, limit: 20 });
  const { data, error } = useLiveData(() => api(`/api/admin/payments?${query}`), [query]);
  const set = (k) => (e) => setFilters((f) => ({ ...f, [k]: e.target.value, page: 1 }));
  const s = data?.stats;
  async function refund(p) {
    const reason = window.prompt(`Refund ${money(p.amount)} to ${p.customer}? Reason:`); if (reason === null) return;
    try { await api('/api/admin/refunds', { method: 'POST', body: JSON.stringify({ requestId: p.requestId, paymentId: p.id, amount: p.amount, reason, mode: 'original' }) }); alert('Refund request created. Approve it in Refund & Cancellation Rules.'); } catch (e) { alert(e.message); }
  }
  return <>
    <PageHead title="Payment Management" desc="Payment methods, successful and failed payments, refunds and reconciliation in one place."><ExportButton path={`/api/admin/payments.csv?${qs({ ...filters, page: '' })}`} name="vakil-payments.csv" label="Export Report" /></PageHead>
    <ErrorNote error={error} />
    {s && !data.total && !s.completed && <NotChargingNote />}
    <div className="ld-segmented">{['', 'UPI', 'Card', 'Net Banking', 'Wallet'].map((m) => <button key={m} className={filters.method === m ? 'active' : ''} onClick={() => setFilters((f) => ({ ...f, method: m, page: 1 }))}>{m || 'All Payments'}</button>)}</div>
    <Stats>
      <Stat label="Active Payment Methods" value={`${number(s?.methods.length)} Methods`} icon={CreditCard} sub={s?.methods.join(', ') || 'none used yet'} />
      <Stat label="Completed Payments" value={`${number(s?.completed)} Payments`} icon={CheckCircle2} tone="green" sub={`${money(s?.volume)} collected`} />
      <Stat label="Pending Payments" value={`${number(s?.pending)} Pending`} icon={Hourglass} tone="amber" sub="awaiting gateway confirmation" />
      <Stat label="Failed Payments & Refunds" value={`${number(s?.failed)} Failed`} icon={AlertTriangle} tone="red" sub={`${number(s?.refunded)} refunded`} />
    </Stats>
    <Card title="Transaction List" desc="Search by payment, consultation, customer or gateway reference." actions={<div className="ld-filters"><label className="ld-search"><Search size={13} /><input value={filters.q} onChange={set('q')} placeholder="Search payments" /></label><select value={filters.status} onChange={set('status')}><option value="">All statuses</option>{['successful', 'pending', 'failed', 'refunded'].map((x) => <option key={x} value={x}>{label(x)}</option>)}</select></div>}>
      <Table rows={data?.items} empty="No payments recorded yet." columns={[
        { label: 'Payment ID', render: (p) => <span className="ld-link">…{p.id.slice(-6)}</span> }, { label: 'Consultation', render: (p) => p.requestId ? `…${p.requestId.slice(-6)}` : '—' },
        { label: 'Customer', render: (p) => <><b>{p.customer}</b><small>{p.phone}</small></> }, { label: 'Amount', render: (p) => <b>{money(p.amount)}</b> }, { label: 'Payment Method', key: 'method' },
        { label: 'Status', render: (p) => <Badge>{p.status}</Badge> }, { label: 'Last Updated', render: (p) => dateTime(p.updatedAt) },
        { label: 'Actions', render: (p) => p.status === 'successful' ? <button className="view" onClick={() => refund(p)}>Refund</button> : '—' },
      ]} />
      <Pager data={data} onPage={(page) => setFilters((f) => ({ ...f, page }))} />
    </Card>
  </>;
}

// ---------------------------------------------------------------- wallets

const ledgerColumns = [
  { label: 'Entry', render: (t) => `…${t.id.slice(-6)}` }, { label: 'Account Holder', key: 'accountName' }, { label: 'Transaction Type', render: (t) => label(t.type) },
  { label: 'Amount', render: (t) => <b className={t.amount < 0 ? 'ld-red' : 'ld-green'}>{t.amount < 0 ? '−' : '+'}{money(Math.abs(t.amount))}</b> },
  { label: 'Status', render: (t) => <Badge>{t.status}</Badge> }, { label: 'Reference', key: 'reference' }, { label: 'Posted On', render: (t) => dateTime(t.createdAt) },
];

export function Wallets() {
  const { data, error } = useLiveData(() => api('/api/admin/wallets'));
  const c = data?.customer.totals; const lawyerAccounts = data?.lawyer.accounts || [];
  const L = (k) => lawyerAccounts.reduce((n, a) => n + a[k], 0);
  return <>
    <PageHead title="Wallet Management" desc="Customer and lawyer wallets as separate ledgers. Balances are computed from an immutable transaction ledger, never edited directly."><ExportButton path="/api/admin/wallets.csv" name="vakil-wallet-ledger.csv" label="Export Ledger" /></PageHead>
    <ErrorNote error={error} />
    <Note>Ledger-driven balances: every recharge, deduction, refund, commission and payout is a separate entry. Corrections are new reversing entries, so every rupee stays auditable.</Note>
    {data && !data.customer.items.length && !data.lawyer.items.length && <NotChargingNote />}
    <div className="ld-grid-2">
      <Card title="Customer Wallet" desc="Recharges, consultation deductions, promotional credits, refunds and failed payments.">
        <Stats cols={2}><Stat label="Current Balance" value={money(c?.balance)} sub="from all posted entries" /><Stat label="Failed Payments" value={money(c?.failed)} tone="red" sub="not credited" /></Stats>
      </Card>
      <Card title="Lawyer Wallet" desc="Gross earnings, platform commission, tax, penalties, net earnings and payouts.">
        <Stats cols={2}><Stat label="Gross Earnings" value={money(L('gross'))} sub="before deductions" /><Stat label="Net Earnings" value={money(L('net'))} tone="green" sub="after commission, tax and penalties" /></Stats>
      </Card>
    </div>
    <Card title="Customer Wallet Detail" desc="Balances rebuilt from recharge, deduction, credit, refund and failed-payment entries.">
      <Stats cols={4}>
        <Stat label="Recharge Transactions" value={money(c?.recharges)} /><Stat label="Consultation Deductions" value={money(c?.deductions)} tone="red" /><Stat label="Promotional Credits" value={money(c?.credits)} tone="violet" /><Stat label="Refunds" value={money(c?.refunds)} tone="green" />
      </Stats>
      <Table rows={data?.customer.items} empty="No customer wallet entries yet." columns={ledgerColumns} />
    </Card>
    <Card title="Lawyer Wallet Detail" desc="Earnings, deductions and payouts per lawyer.">
      <Stats cols={4}>
        <Stat label="Platform Commission" value={money(L('commission'))} tone="red" /><Stat label="GST / TDS" value={money(L('tax'))} tone="amber" /><Stat label="Penalties" value={money(L('penalties'))} tone="red" /><Stat label="Paid Amount" value={money(L('paid'))} tone="green" />
      </Stats>
      <Table rows={lawyerAccounts} empty="No lawyers yet." columns={[
        { label: 'Lawyer', render: (a) => <><b>{a.name}</b><small>{a.phone}</small></> }, { label: 'Gross', render: (a) => money(a.gross) }, { label: 'Commission', render: (a) => `${money(a.commission)} (${a.commissionPercent}%)` },
        { label: 'Net', render: (a) => money(a.net) }, { label: 'Pending balance', render: (a) => money(a.queued) }, { label: 'Withdrawable', render: (a) => <b className="ld-green">{money(a.withdrawable)}</b> }, { label: 'Paid out', render: (a) => money(a.paid) },
      ]} />
      <Table rows={data?.lawyer.items} empty="No lawyer ledger entries yet." columns={ledgerColumns} />
    </Card>
  </>;
}

// ---------------------------------------------------------------- payouts

const next = { pending: [['processing', 'Start transfer'], ['on_hold', 'Hold'], ['failed', 'Reject']], processing: [['paid', 'Mark paid'], ['failed', 'Failed'], ['on_hold', 'Hold']], on_hold: [['pending', 'Release'], ['failed', 'Reject']], failed: [['pending', 'Retry']], paid: [['reversed', 'Reverse']] };

export function Payouts() {
  const [status, setStatus] = useState('');
  const { data, error, refresh } = useLiveData(() => api(`/api/admin/payouts${status ? `?status=${status}` : ''}`), [status]);
  const rules = useSetting('payouts'); const s = data?.stats;
  async function move(p, to) {
    const reference = to === 'paid' ? window.prompt('Bank / UPI transfer reference (UTR):') : undefined; if (to === 'paid' && !reference) return;
    try { await api(`/api/admin/payouts/${p.id}`, { method: 'PATCH', body: JSON.stringify({ status: to, reference }) }); refresh(); } catch (e) { alert(e.message); }
  }
  async function runPayouts() {
    try { const r = await api('/api/admin/payouts/run', { method: 'POST' }); alert(r.created ? `${r.created} payout(s) queued.` : `No lawyer has at least ${money(data.rules.minimumWithdrawal)} withdrawable right now.`); refresh(); } catch (e) { alert(e.message); }
  }
  return <>
    <PageHead title="Lawyer Payout Management" desc="Review lawyer earnings, queue and release payouts, record transfer references and handle failures."><ExportButton path="/api/admin/wallets.csv" name="vakil-statements.csv" label="Download Statements" primary={false} /><button className="primary" onClick={runPayouts}><Send size={14} /> Process Weekly Payouts</button></PageHead>
    <ErrorNote error={error} />
    <Stats>
      <Stat label="Pending payout queue" value={money(s?.queued)} icon={Clock} sub={`${number(data?.items.filter((p) => ['pending', 'processing'].includes(p.status)).length)} payouts waiting`} />
      <Stat label="Automatic weekly payout" value={data?.rules.schedule || '—'} icon={CalendarClock} tone="green" sub={`${data?.rules.holdDays ?? '—'} day dispute hold`} />
      <Stat label="Minimum withdrawal" value={money(data?.rules.minimumWithdrawal)} icon={WalletIcon} tone="violet" sub="balances below wait for the next cycle" />
      <Stat label="Holds and failures" value={`${number(s?.onHold)} / ${number(s?.failed)}`} icon={ShieldAlert} tone="red" sub={`${number(s?.unverifiedBank)} lawyers without bank details`} />
    </Stats>
    <Card title="Settlement policy & payout controls" desc="Payouts are created only for lawyers whose withdrawable balance reaches the minimum.">
      {rules.form && <div className="ld-settings">
        <label className="ld-setting"><span>Minimum withdrawal amount</span><span className="ld-inline-input">₹<input type="number" min="0" {...rules.field('minimumWithdrawal')} /></span></label>
        <label className="ld-setting"><span>Automatic payout schedule</span><input {...rules.field('schedule')} /></label>
        <label className="ld-setting"><span>Dispute-hold period</span><span className="ld-inline-input"><input type="number" min="0" {...rules.field('holdDays')} /> days</span></label>
      </div>}
      <SaveBar s={rules} />
    </Card>
    <div className="ld-grid-main">
      <Card title="Payout requests" desc="Approve, hold, pay or reverse lawyer payouts." actions={<select value={status} onChange={(e) => setStatus(e.target.value)}><option value="">All statuses</option>{['pending', 'processing', 'on_hold', 'paid', 'failed', 'reversed'].map((x) => <option key={x} value={x}>{label(x)}</option>)}</select>}>
        <Table rows={data?.items} empty="No payouts yet. Use “Process Weekly Payouts” when lawyers have earnings." columns={[
          { label: 'Payout ID', render: (p) => `…${p.id.slice(-6)}` }, { label: 'Lawyer', key: 'lawyerName' }, { label: 'Amount', render: (p) => <b>{money(p.amount)}</b> }, { label: 'Method', key: 'method' },
          { label: 'Status', render: (p) => <Badge>{p.status}</Badge> }, { label: 'Account', render: (p) => p.bank ? <Badge tone="good">Verified</Badge> : <Badge tone="bad">No bank</Badge> }, { label: 'Reference', render: (p) => p.reference || '—' },
          { label: 'Actions', render: (p) => <span className="ld-actions">{(next[p.status] || []).map(([to, text]) => <button key={to} className={`view ${['failed', 'reversed'].includes(to) ? 'danger' : ''}`} onClick={() => move(p, to)}>{text}</button>)}</span> },
        ]} />
      </Card>
      <Card title="Account verification status" desc="Bank or UPI details from the Partner App registration.">
        {data?.accounts.map((a) => <div className="ld-row" key={a.id}><div><b>{a.name}</b><small>{a.bank ? `${a.bank.account || a.bank.upi} · ${a.bank.ifsc || 'UPI'}` : 'No bank details'}</small></div><Badge tone={a.bank ? 'good' : 'bad'}>{a.bank ? 'Verified' : 'Unverified'}</Badge></div>)}
      </Card>
    </div>
  </>;
}
