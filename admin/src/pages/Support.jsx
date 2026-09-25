import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Inbox, AlertCircle, Loader, ArrowUpCircle, CheckCircle2, RotateCcw, Hourglass, IndianRupee, XCircle, MessageSquareText, Star, Clock, Flag, Search, Plus } from 'lucide-react';
import { api } from '../api.js';
import { Badge, Bars, Card, Drawer, ErrorNote, PageHead, Stat, Stats, Table, Toggle, dateOnly, dateTime, label, money, number, useLiveData } from '../ui.jsx';
import { SaveBar, useSetting } from './Pricing.jsx';

// ---------------------------------------------------------------- complaints

export function Complaints() {
  const { data, error, refresh } = useLiveData(() => api('/api/admin/complaints'));
  const [q, setQ] = useState(''); const [status, setStatus] = useState(''); const [open, setOpen] = useState(null);
  const s = data?.stats;
  const rows = data?.items.filter((c) => (!status || c.status === status) && `${c.ticket} ${c.customer} ${c.lawyer} ${c.description}`.toLowerCase().includes(q.toLowerCase()));
  const current = open && data?.items.find((c) => c.id === open);
  async function update(body) { try { await api(`/api/admin/complaints/${open}`, { method: 'PATCH', body: JSON.stringify(body) }); refresh(); } catch (e) { alert(e.message); } }
  return <>
    <PageHead title="Complaints & Dispute Management" desc="Track tickets, resolve complaints, assign cases and escalate disputes. Log a complaint from any consultation's detail view."><Link className="primary" to="/history"><Plus size={14} /> Log from a consultation</Link></PageHead>
    <ErrorNote error={error} />
    <Stats cols={5}>
      <Stat label="Total Complaints" value={number(s?.total)} icon={Inbox} />
      <Stat label="Open" value={number(s?.open)} icon={AlertCircle} tone="red" />
      <Stat label="In Progress" value={number(s?.in_progress)} icon={Loader} tone="amber" />
      <Stat label="Escalated" value={number(s?.escalated)} icon={ArrowUpCircle} tone="red" />
      <Stat label="Resolved" value={number(s?.resolved)} icon={CheckCircle2} tone="green" />
    </Stats>
    <Card title="Complaint tickets" desc="Search by customer, lawyer or ticket ID." actions={<div className="ld-filters"><label className="ld-search"><Search size={13} /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search complaints" /></label><select value={status} onChange={(e) => setStatus(e.target.value)}><option value="">All statuses</option>{['open', 'in_progress', 'escalated', 'resolved'].map((x) => <option key={x} value={x}>{label(x)}</option>)}</select></div>}>
      <Table rows={rows} empty="No complaints logged." onRow={(c) => setOpen(c.id)} columns={[
        { label: 'Ticket ID', render: (c) => <span className="ld-link">{c.ticket}</span> }, { label: 'Date Filed', render: (c) => dateOnly(c.createdAt) }, { label: 'Customer', key: 'customer' }, { label: 'Against Lawyer', key: 'lawyer' },
        { label: 'Category', key: 'category' }, { label: 'Priority', render: (c) => <Badge>{c.priority}</Badge> }, { label: 'Status', render: (c) => <Badge>{c.status}</Badge> }, { label: 'Assigned to', render: (c) => c.assignee || '—' },
      ]} />
    </Card>
    {current && <Drawer title={`${current.ticket} · ${current.category}`} sub={`${current.customer} against ${current.lawyer} · filed ${dateTime(current.createdAt)}`} onClose={() => setOpen(null)} actions={<Link className="secondary" to={`/history?open=${current.requestId}`}>Open consultation</Link>}>
      <p className="ld-description">{current.description}</p>
      <div className="ld-form-row">
        <label>Status<select value={current.status} onChange={(e) => update({ status: e.target.value })}>{['open', 'in_progress', 'escalated', 'resolved'].map((x) => <option key={x} value={x}>{label(x)}</option>)}</select></label>
        <label>Priority<select value={current.priority} onChange={(e) => update({ priority: e.target.value })}>{['low', 'medium', 'high'].map((x) => <option key={x} value={x}>{label(x)}</option>)}</select></label>
        <label>Assigned to<input defaultValue={current.assignee} onBlur={(e) => e.target.value !== current.assignee && update({ assignee: e.target.value })} placeholder="Team member" /></label>
      </div>
      <h4 className="ld-h4">Case notes</h4>
      {current.notes.length ? current.notes.map((n, i) => <div className="ld-audit" key={i}><b>{n.text}</b><small>{dateTime(n.at)} · {n.by}</small></div>) : <div className="no-results">No notes yet.</div>}
      <form className="ld-note-form" onSubmit={(e) => { e.preventDefault(); const text = e.target.note.value.trim(); if (text) update({ note: text }).then(() => { e.target.reset(); }); }}><input name="note" placeholder="Add a note (call with customer, lawyer response…)" /><button className="primary">Add note</button></form>
    </Drawer>}
  </>;
}

// ---------------------------------------------------------------- refunds

export function Refunds() {
  const { data, error, refresh } = useLiveData(() => api('/api/admin/refunds'));
  const rules = useSetting('refundRules'); const s = data?.stats;
  const setRule = (id, patch) => rules.setForm((f) => ({ ...f, rules: f.rules.map((r) => r.id === id ? { ...r, ...patch } : r) }));
  async function decide(r, status) {
    if (!window.confirm(`${status === 'approved' ? 'Approve' : 'Reject'} the ${money(r.amount)} refund for ${r.customer}?`)) return;
    try { await api(`/api/admin/refunds/${r.id}`, { method: 'PATCH', body: JSON.stringify({ status }) }); refresh(); } catch (e) { alert(e.message); }
  }
  return <>
    <PageHead title="Refund & Cancellation Rules" desc="Which situations are refunded and how, plus every refund request with its decision." />
    <ErrorNote error={error || rules.error} />
    <Stats>
      <Stat label="Total Refund Requests" value={number(s?.total)} icon={RotateCcw} />
      <Stat label="Pending Decision" value={number(s?.pending)} icon={Hourglass} tone="amber" />
      <Stat label="Total Refunded" value={money(s?.approvedAmount)} icon={IndianRupee} tone="green" />
      <Stat label="Rejected" value={number(s?.rejected)} icon={XCircle} tone="red" />
    </Stats>
    <Card title="Refund Scenarios" desc="Automatic rules apply without review; the others create a request for an admin to decide.">
      <Table rows={rules.form?.rules} rowKey={(r) => r.id} columns={[
        { label: 'Scenario', render: (r) => <b>{r.scenario}</b> }, { label: 'Description', key: 'description' },
        { label: 'Refund Action', render: (r) => r.locked ? r.action : <input className="ld-cell-input" value={r.action} onChange={(e) => setRule(r.id, { action: e.target.value })} /> },
        { label: 'Mode', render: (r) => r.locked ? 'Automatic' : <select value={r.automatic ? 'auto' : 'review'} onChange={(e) => setRule(r.id, { automatic: e.target.value === 'auto' })}><option value="auto">Automatic</option><option value="review">Admin review</option></select> },
        { label: 'Status', render: (r) => <Toggle checked={r.enabled} disabled={r.locked} onChange={(v) => setRule(r.id, { enabled: v })} /> },
      ]} />
      <SaveBar s={rules} label="Save rules" />
    </Card>
    <Card title="Refund requests" desc="Approved wallet refunds are credited to the customer wallet ledger at once.">
      <Table rows={data?.items} empty="No refund requests. Create one from a consultation or payment." columns={[
        { label: 'Refund', render: (r) => `…${r.id.slice(-6)}` }, { label: 'Customer', render: (r) => <><b>{r.customer}</b><small>{r.phone}</small></> }, { label: 'Consultation', render: (r) => <Link to={`/history?open=${r.requestId}`}>…{r.requestId?.slice(-6)}</Link> },
        { label: 'Amount', render: (r) => <b>{money(r.amount)}</b> }, { label: 'Reason', key: 'reason' }, { label: 'Refund to', render: (r) => r.mode === 'wallet' ? 'Wallet' : 'Original method' },
        { label: 'Status', render: (r) => <Badge>{r.status}</Badge> }, { label: 'Raised', render: (r) => dateTime(r.createdAt) },
        { label: 'Decision', render: (r) => r.status === 'pending' ? <span className="ld-actions"><button className="view" onClick={() => decide(r, 'approved')}>Approve</button><button className="view danger" onClick={() => decide(r, 'rejected')}>Reject</button></span> : dateTime(r.decidedAt) },
      ]} />
    </Card>
  </>;
}

// ---------------------------------------------------------------- reviews

export function Reviews() {
  const [filters, setFilters] = useState({ rating: '', state: '', by: '' });
  const { data, error, refresh } = useLiveData(() => api(`/api/admin/reviews?rating=${filters.rating}&state=${filters.state}&by=${filters.by}`), [filters.rating, filters.state, filters.by]);
  const s = data?.stats;
  async function moderate(r, body) { try { await api(`/api/admin/reviews/${r.id}`, { method: 'PATCH', body: JSON.stringify(body) }); refresh(); } catch (e) { alert(e.message); } }
  return <>
    <PageHead title="Ratings & Reviews Moderation" desc="Feedback from both sides after each chat or voice call: customers rate lawyers, lawyers rate customers. Flag violations and hide reviews from lawyer ratings." />
    <ErrorNote error={error} />
    <Stats>
      <Stat label="Total Feedback" value={number(s?.total)} icon={MessageSquareText} sub={`${number(s?.fromCustomers)} from customers · ${number(s?.fromLawyers)} from lawyers`} />
      <Stat label="Average Rating" value={s?.average ? `${s.average} / 5.0` : '—'} icon={Star} tone="amber" sub="hidden reviews excluded" />
      <Stat label="Low Ratings (1–2 ★)" value={number(s?.lowRatings)} icon={Clock} tone="red" sub="worth a follow-up" />
      <Stat label="Flagged for Action" value={number(s?.flagged)} icon={Flag} tone="red" sub={`${number(s?.hidden)} hidden`} />
    </Stats>
    <div className="ld-grid-main">
      <Card title="Recent Feedback & Ratings" actions={<div className="ld-filters"><select value={filters.by} onChange={(e) => setFilters((f) => ({ ...f, by: e.target.value }))}><option value="">From everyone</option><option value="customer">Customer → Lawyer</option><option value="lawyer">Lawyer → Customer</option></select><select value={filters.rating} onChange={(e) => setFilters((f) => ({ ...f, rating: e.target.value }))}><option value="">All ratings</option>{[5, 4, 3, 2, 1].map((n) => <option key={n} value={n}>{n} ★</option>)}</select><select value={filters.state} onChange={(e) => setFilters((f) => ({ ...f, state: e.target.value }))}><option value="">All reviews</option><option value="published">Published</option><option value="flagged">Flagged</option><option value="hidden">Hidden</option></select></div>}>
        <Table rows={data?.items} empty="No reviews match." columns={[
          { label: 'From', render: (r) => <Badge>{r.by === 'lawyer' ? 'lawyer → customer' : 'customer → lawyer'}</Badge> },
          { label: 'Customer', key: 'customer' }, { label: 'Lawyer', key: 'lawyer' }, { label: 'Type', render: (r) => r.consultationType === 'call' ? 'Voice call' : 'Chat' }, { label: 'Rating', render: (r) => <span className="ld-stars">{'★'.repeat(r.rating)}<i>{'★'.repeat(5 - r.rating)}</i></span> },
          { label: 'Review Message', render: (r) => r.comment || <span className="ld-muted">No comment</span> }, { label: 'Date', render: (r) => dateOnly(r.createdAt) },
          { label: 'Status', render: (r) => <Badge>{r.hidden ? 'hidden' : r.flagged ? 'flagged' : 'published'}</Badge> },
          { label: 'Actions', render: (r) => <span className="ld-actions"><button className="view" onClick={() => moderate(r, { flagged: !r.flagged })}>{r.flagged ? 'Unflag' : 'Flag'}</button><button className={`view ${r.hidden ? '' : 'danger'}`} onClick={() => moderate(r, { hidden: !r.hidden })}>{r.hidden ? 'Publish' : 'Hide'}</button></span> },
        ]} />
      </Card>
      <Card title="6-Month Rating Trend" desc="Average rating per month">
        {data && <Bars data={data.trend} value={(m) => m.average || 0} format={(v) => v ? `${v} ★` : 'no reviews'} height={170} />}
      </Card>
    </div>
  </>;
}
