import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Users, Wallet, IndianRupee, ShieldAlert, Search } from 'lucide-react';
import { api } from '../api.js';
import { Badge, Card, ErrorNote, PageHead, Person, Stat, Stats, Table, ago, dateOnly, money, number, useLiveData } from '../ui.jsx';
import { CustomerWallet } from './Transactions.jsx';

export default function Customers() {
  const { data, error, refresh } = useLiveData(() => api('/api/admin/users'));
  const [q, setQ] = useState(''); const [risk, setRisk] = useState(''); const [state, setState] = useState(''); const [walletOf, setWalletOf] = useState(null);
  const all = data?.items;
  const rows = all?.filter((u) => (!risk || u.riskLevel === risk) && (!state || (state === 'blocked' ? u.blocked : !u.blocked)) && `${u.name} ${u.phone} ${u.email || ''} ${u.id}`.toLowerCase().includes(q.toLowerCase()));
  const spent = all?.reduce((n, u) => n + u.totalSpent, 0) || 0;
  async function update(u, body, confirmText) {
    if (confirmText && !window.confirm(confirmText)) return;
    try { await api(`/api/admin/users/${u.id}`, { method: 'PATCH', body: JSON.stringify(body) }); refresh(); } catch (e) { alert(e.message); }
  }
  return <>
    <PageHead title="Customer Management" desc="Customers, wallet balances, consultation activity and risk controls in INR.">
      <select value={risk} onChange={(e) => setRisk(e.target.value)}><option value="">Filter risk status</option><option value="low">Low</option><option value="medium">Medium</option><option value="high">High</option></select>
    </PageHead>
    <ErrorNote error={error} />
    <Stats>
      <Stat label="Total Customers" value={number(all?.length)} icon={Users} sub={`${number(all?.filter((u) => u.online).length)} online now`} />
      <Stat label="Total Wallet Balance" value={money(all?.reduce((n, u) => n + u.walletBalance, 0))} icon={Wallet} tone="green" sub="from the wallet ledger" />
      <Stat label="Avg. Spend per Customer" value={money(all?.length ? spent / all.length : 0)} icon={IndianRupee} tone="violet" sub={`${money(spent)} total`} />
      <Stat label="System Risk Flags" value={`${number(all?.filter((u) => u.riskLevel === 'high').length)} Flagged`} icon={ShieldAlert} tone="red" sub={`${number(all?.filter((u) => u.blocked).length)} blocked`} />
    </Stats>
    <Card title="Customer Directory & Ledger" actions={<div className="ld-filters"><label className="ld-search"><Search size={13} /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Name, phone, email or ID" /></label><select value={state} onChange={(e) => setState(e.target.value)}><option value="">All statuses</option><option value="active">Active</option><option value="blocked">Blocked</option></select></div>}>
      <Table rows={rows} empty="No customers match." columns={[
        { label: 'Customer', render: (u) => <Person name={`${u.name} • …${u.id.slice(-5)}`} sub={[u.phone, u.email, `joined ${dateOnly(u.createdAt)}`].filter(Boolean).join(' · ')} /> },
        { label: 'Status', render: (u) => <><Badge>{u.blocked ? 'blocked' : 'active'}</Badge><small>{u.online ? 'online now' : `seen ${ago(u.lastSeenAt)}`}</small></> },
        { label: 'Free trial', render: (u) => u.trialUsed ? 'Used' : <Badge tone="good">Available</Badge> },
        { label: 'Wallet Balance', render: (u) => <><b>{money(u.walletBalance)}</b><small><button className="view" onClick={() => setWalletOf(u.id)}>History ({u.walletEntries || 0})</button></small></> },
        { label: 'Total Spent', render: (u) => money(u.totalSpent) },
        { label: 'Consultations', render: (u) => <><Link to={`/history?userId=${u.id}`}>{u.chats} chats</Link><small><Link to={`/calls?accountId=${u.id}`}>{u.calls} calls</Link> · {u.requests} requests</small></> },
        { label: 'Risk Level', render: (u) => <select className={`ld-risk ${u.riskLevel}`} value={u.riskLevel} onChange={(e) => update(u, { riskLevel: e.target.value })}><option value="low">Low</option><option value="medium">Medium</option><option value="high">High</option></select> },
        { label: 'Manage', render: (u) => <button className={`view ${u.blocked ? '' : 'danger'}`} onClick={() => update(u, { blocked: !u.blocked }, u.blocked ? null : `Block ${u.name}? They are signed out at once and cannot sign in again.`)}>{u.blocked ? 'Unblock' : 'Block'}</button> },
      ]} />
    </Card>
    {walletOf && <CustomerWallet userId={walletOf} onClose={() => setWalletOf(null)} />}
  </>;
}
