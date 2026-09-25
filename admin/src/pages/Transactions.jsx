import React, { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { ArrowDownLeft, ArrowUpRight, MessageSquare, PhoneCall, RotateCcw, X } from 'lucide-react';
import { api } from '../api.js';
import { Card, Drawer, ErrorNote, ExportButton, PageHead, Pager, Stat, Stats, Table, dateTime, label, money, qs, useLiveData } from '../ui.jsx';

const types = [['recharge', 'Recharges'], ['chat', 'Chat charges'], ['call', 'Call charges'], ['refund', 'Refunds'], ['debit', 'All deductions'], ['credit', 'All credits']];

// One wallet entry's columns, shared with the customer wallet drawer.
export const transactionColumns = (withCustomer = true) => [
  { label: 'Date', render: (t) => dateTime(t.createdAt) },
  ...(withCustomer ? [{ label: 'Customer', render: (t) => <><b>{t.customer}</b><small>{t.phone || '—'}</small></> }] : []),
  { label: 'Type', render: (t) => <span className="ld-tags"><span className={t.type === 'debit' ? 'off' : ''}>{label(t.reason || t.type)}</span></span> },
  { label: 'Details', render: (t) => t.note || (t.reason === 'recharge' ? 'Wallet recharge' : '—') },
  { label: 'Amount', render: (t) => <b className={t.type === 'debit' ? 'ld-red' : 'ld-green'}>{t.type === 'debit' ? '−' : '+'}{money(t.amount)}</b> },
  { label: 'Balance after', render: (t) => t.balanceAfter === null ? '—' : money(t.balanceAfter) },
  { label: 'Consultation', render: (t) => t.requestId ? <Link to={`/history?open=${t.requestId}`}>…{t.requestId.slice(-6)}</Link> : '—' },
];

/** All wallet recharges and per-minute deductions, filtered by date, user and type. */
export default function Transactions() {
  const [params, setParams] = useSearchParams();
  const filters = Object.fromEntries(['type', 'userId', 'from', 'to', 'page'].map((k) => [k, params.get(k) || '']));
  const [users, setUsers] = useState([]);
  const query = qs({ ...filters, limit: 25 });
  const { data, error } = useLiveData(() => api(`/api/admin/transactions?${query}`), [query]);
  useEffect(() => { api('/api/admin/users').then((d) => setUsers(d.items)).catch(() => {}); }, []);
  function set(key, value) { const next = new URLSearchParams(params); value ? next.set(key, value) : next.delete(key); if (key !== 'page') next.delete('page'); setParams(next); }
  const t = data?.totals;
  return <>
    <PageHead title="Wallet Transactions" desc="Every wallet recharge and every per-minute chat or call charge, with the balance after each entry.">
      <ExportButton path={`/api/admin/transactions.csv?${qs({ ...filters, page: '' })}`} name="vakil-wallet-transactions.csv" />
    </PageHead>
    <ErrorNote error={error} />
    <Stats cols={5}>
      <Stat label="Recharged" value={money(t?.recharged)} icon={ArrowDownLeft} tone="green" sub="in this filter" />
      <Stat label="Charged" value={money(t?.charged)} icon={ArrowUpRight} tone="red" sub="per-minute deductions" />
      <Stat label="Chat charges" value={money(t?.chatCharges)} icon={MessageSquare} />
      <Stat label="Call charges" value={money(t?.callCharges)} icon={PhoneCall} tone="violet" />
      <Stat label="Refunded" value={money(t?.refunded)} icon={RotateCcw} tone="amber" />
    </Stats>
    <Card title="Transactions" actions={<div className="ld-filters">
      <select value={filters.type} onChange={(e) => set('type', e.target.value)}><option value="">All types</option>{types.map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
      <select value={filters.userId} onChange={(e) => set('userId', e.target.value)}><option value="">All users</option>{users.map((u) => <option key={u.id} value={u.id}>{u.name}{u.phone ? ` · ${u.phone}` : ''}</option>)}</select>
      <label>From <input type="date" value={filters.from} onChange={(e) => set('from', e.target.value)} /></label>
      <label>To <input type="date" value={filters.to} onChange={(e) => set('to', e.target.value)} /></label>
      {[...params.keys()].length > 0 && <button className="secondary" onClick={() => setParams({})}><X size={12} /> Clear</button>}
    </div>}>
      <Table rows={data?.items} empty="No wallet transactions match." columns={transactionColumns()} />
      <Pager data={data} onPage={(p) => set('page', String(p))} />
    </Card>
  </>;
}

/** A customer's balance and full wallet history. */
export function CustomerWallet({ userId, onClose }) {
  const { data, error } = useLiveData(() => api(`/api/admin/users/${userId}/wallet`), [userId]);
  return <Drawer title={data ? `${data.user.name} · wallet` : 'Wallet'} sub={data?.user.phone} onClose={onClose} actions={<Link className="secondary" to={`/transactions?userId=${userId}`}>Open in Transactions</Link>}>
    <ErrorNote error={error} />
    {data && <>
      <Stats cols={3}>
        <Stat label="Balance" value={money(data.user.balance)} tone="green" />
        <Stat label="Recharged" value={money(data.items.filter((t) => t.reason === 'recharge').reduce((n, t) => n + t.amount, 0))} />
        <Stat label="Spent on chats & calls" value={money(data.items.filter((t) => t.type === 'debit').reduce((n, t) => n + t.amount, 0))} tone="red" sub={data.user.trialUsed ? 'free trial used' : 'free trial not used yet'} />
      </Stats>
      <Table rows={data.items} empty="No wallet activity yet." columns={transactionColumns(false)} />
    </>}
  </Drawer>;
}
