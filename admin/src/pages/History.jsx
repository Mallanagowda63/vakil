import React, { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { History as HistoryIcon, CheckCircle2, RotateCcw, AlertTriangle, Phone, PhoneMissed, Check, CheckCheck, Search, X, PhoneCall, PhoneOff, Timer } from 'lucide-react';
import { api, download } from '../api.js';
import { Badge, Card, Drawer, ErrorNote, ExportButton, PageHead, Pager, Stat, Stats, Table, clock, dateTime, duration, money, number, qs, useLiveData } from '../ui.jsx';

const statuses = ['PENDING', 'ONGOING', 'COMPLETED', 'REJECTED', 'EXPIRED', 'CANCELLED'];

export const requestColumns = (live = false) => [
  { label: 'Consultation ID', render: (r) => <span className="ld-link">…{r.id.slice(-6)}</span> },
  { label: 'Customer', render: (r) => <><b>{r.userName}</b><small>{r.userPhone || '—'}</small></> },
  { label: 'Lawyer', render: (r) => <><b>{r.lawyerName}</b><small>{r.lawyerPhone || '—'}</small></> },
  { label: 'Type', render: (r) => r.isTrial ? <span className="badge warn">Free trial</span> : 'Chat' },
  { label: 'Category', key: 'category' },
  { label: 'Status', render: (r) => <Badge>{r.status}</Badge> },
  { label: 'Requested', render: (r) => <>{dateTime(r.createdAt)}{r.responseSeconds !== null && <small>answered in {r.responseSeconds}s</small>}</> },
  live ? { label: 'Time left', render: (r) => r.remainingSeconds !== null ? <b className={r.remainingSeconds <= 15 ? 'ld-red' : ''}>{duration(r.remainingSeconds)}</b> : 'No limit' } : { label: 'Ended', render: (r) => <>{dateTime(r.endedAt)}{r.endedBy && <small>by {r.endedBy}</small>}</> },
  { label: 'Duration', render: (r) => duration(r.durationSeconds) },
  { label: 'Charged', render: (r) => r.isTrial ? <span className="ld-muted">Free</span> : <><b>{money(r.totalAmount)}</b>{r.ratePerMinute ? <small>{r.billedMinutes} min × {money(r.ratePerMinute)}</small> : null}</> },
  { label: 'Msgs', key: 'messageCount' }, { label: 'Calls', key: 'callCount' },
];

export default function History() {
  const [params, setParams] = useSearchParams();
  const keys = ['q', 'status', 'trial', 'from', 'to', 'lawyerId', 'userId', 'page'];
  const filters = Object.fromEntries(keys.map((k) => [k, params.get(k) || '']));
  const [search, setSearch] = useState(filters.q);
  const [people, setPeople] = useState({ lawyers: [], users: [] });
  const query = qs({ ...filters, limit: 25 });
  const { data, error } = useLiveData(() => api(`/api/admin/requests?${query}`), [query]);
  const side = useLiveData(() => Promise.all([api('/api/admin/requests?limit=1'), api('/api/admin/requests?limit=1&status=COMPLETED'), api('/api/admin/refunds'), api('/api/admin/complaints')]).then(([all, done, refunds, complaints]) => ({ total: all.total, completed: done.total, refunded: refunds.stats.approvedAmount, refunds: refunds.stats.total, disputed: new Set(complaints.items.map((c) => c.requestId)).size })));
  useEffect(() => { Promise.all([api('/api/admin/lawyers'), api('/api/admin/users')]).then(([l, u]) => setPeople({ lawyers: l.items, users: u.items })).catch(() => {}); }, []);
  useEffect(() => { const t = setTimeout(() => { if (search !== filters.q) set('q', search); }, 350); return () => clearTimeout(t); }, [search]); // eslint-disable-line react-hooks/exhaustive-deps
  function set(key, value) { const next = new URLSearchParams(params); value ? next.set(key, value) : next.delete(key); if (key !== 'page' && key !== 'open') next.delete('page'); setParams(next); }
  const s = side.data;
  return <>
    <PageHead title="Consultation History" desc="Every chat request: status, timings, messages, calls, refunds and disputes. Click a row for its timeline and transcript."><ExportButton path={`/api/admin/requests.csv?${qs({ ...filters, page: '' })}`} name="vakil-consultations.csv" /></PageHead>
    <ErrorNote error={error} />
    <Stats>
      <Stat label="Total Consultations" value={number(s?.total)} icon={HistoryIcon} sub="all requests" />
      <Stat label="Completed Sessions" value={number(s?.completed)} icon={CheckCircle2} tone="green" sub={s?.total ? `${Math.round(s.completed / s.total * 100)}% completion rate` : ''} />
      <Stat label="Refunded Amount" value={money(s?.refunded)} icon={RotateCcw} tone="violet" sub={`${number(s?.refunds)} refund requests`} />
      <Stat label="Disputed Sessions" value={number(s?.disputed)} icon={AlertTriangle} tone="red" sub={<Link to="/complaints">with complaints</Link>} />
    </Stats>
    <Card title="Advanced Filters" desc="Narrow records by customer, lawyer, date, type and status." actions={[...params.keys()].filter((k) => k !== 'open').length > 0 && <button className="secondary" onClick={() => { setSearch(''); setParams({}); }}><X size={12} /> Clear all</button>}>
      <div className="ld-filter-grid">
        <label>Search<span className="ld-search"><Search size={13} /><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Name or phone number" /></span></label>
        <label>Customer<select value={filters.userId} onChange={(e) => set('userId', e.target.value)}><option value="">All customers</option>{people.users.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}</select></label>
        <label>Lawyer<select value={filters.lawyerId} onChange={(e) => set('lawyerId', e.target.value)}><option value="">All lawyers</option>{people.lawyers.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></label>
        <label>Consultation type<select value={filters.trial} onChange={(e) => set('trial', e.target.value)}><option value="">Trial and normal</option><option value="yes">Free trial</option><option value="no">Normal</option></select></label>
        <label>Status<select value={filters.status} onChange={(e) => set('status', e.target.value)}><option value="">All statuses</option>{statuses.map((x) => <option key={x}>{x}</option>)}</select></label>
        <label>Date from<input type="date" value={filters.from} onChange={(e) => set('from', e.target.value)} /></label>
        <label>Date to<input type="date" value={filters.to} onChange={(e) => set('to', e.target.value)} /></label>
      </div>
    </Card>
    <Card title="Consultation Records" desc={data ? `Showing ${data.items.length} of ${number(data.total)} records · updates live` : ''}>
      <Table rows={data?.items} empty="No consultations match these filters." onRow={(r) => set('open', r.id)} columns={requestColumns()} />
      <Pager data={data} onPage={(p) => set('page', String(p))} />
    </Card>
    {params.get('open') && <RequestDetail id={params.get('open')} onClose={() => set('open', '')} />}
  </>;
}

// Timeline, read-only transcript and calls for one request, plus admin actions.
export function RequestDetail({ id, onClose }) {
  const { data, error, refresh } = useLiveData(() => api(`/api/admin/requests/${id}`), [id]);
  const r = data?.request;
  async function act(path, body, confirmText) {
    if (confirmText && !window.confirm(confirmText)) return;
    try { await api(path, { method: 'POST', body: JSON.stringify(body || {}) }); refresh(); } catch (e) { alert(e.message); }
  }
  async function complaint() {
    const description = window.prompt('Complaint details (from the customer or lawyer):'); if (!description) return;
    act('/api/admin/complaints', { requestId: id, description, priority: 'medium' });
  }
  async function refund() {
    const amount = window.prompt('Refund amount in ₹ (goes to the customer wallet after approval):', '0'); if (amount === null) return;
    act('/api/admin/refunds', { requestId: id, amount: Number(amount), reason: window.prompt('Reason:') || '' });
  }
  return <Drawer title={r ? `${r.userName} ↔ ${r.lawyerName}` : 'Consultation'} sub={id} onClose={onClose} actions={r && <>
    {r.status === 'ONGOING' && <button className="ld-btn bad" onClick={() => act(`/api/admin/requests/${id}/end`, null, 'End this chat now for both people? Any call ends too.')}>End chat</button>}
    <button className="secondary" onClick={complaint}>Log complaint</button>
    <button className="secondary" onClick={refund}>Refund</button>
    <button className="secondary" onClick={() => download(`/api/admin/requests/${id}/transcript.csv`, `vakil-transcript-${id}.csv`).catch((e) => alert(e.message))}>Transcript CSV</button></>}>
    <ErrorNote error={error} />
    {!r ? <div className="no-results">Loading…</div> : <>
      <div className="ld-facts">{[['Status', <Badge key="s">{r.status}</Badge>], ['Type', r.isTrial ? 'Free trial (1 min)' : 'Chat'], ['Category', r.category || '—'], ['Customer', `${r.userName} · ${r.userPhone || '—'}`], ['Lawyer', `${r.lawyerName} · ${r.lawyerPhone || '—'}`], ['Duration', duration(r.durationSeconds)], ['Ended by', r.endedBy || '—'], ['Rating', r.rating ? `${r.rating} ★` : '—']].map(([k, v]) => <div key={k}><span>{k}</span><b>{v}</b></div>)}</div>
      {r.description && <p className="ld-description">{r.description}</p>}
      <h4 className="ld-h4">Billing</h4>
      {!data.billing.paid ? <p className="ld-muted">{r.isTrial ? 'Free 1-minute trial: nothing charged.' : 'Not a paid chat (started before per-minute billing).'}</p> : <>
        <div className="ld-facts">{[['Rate', `${money(data.billing.ratePerMinute)}/min`], ['Minutes charged', data.billing.billedMinutes], ['Total amount', money(data.billing.totalAmount)], ['End reason', data.billing.endReason === 'balance_over' ? 'Balance ran out' : (data.billing.endReason || '—').replace(/_/g, ' ')]].map(([k, v]) => <div key={k}><span>{k}</span><b>{v}</b></div>)}</div>
        <Table rows={data.billing.deductions} empty="No deductions yet." columns={[
          { label: 'Time', render: (t) => dateTime(t.createdAt) }, { label: 'Charge', render: (t) => t.note || t.reason }, { label: 'For', render: (t) => t.reason },
          { label: 'Amount', render: (t) => <b className={t.type === 'debit' ? 'ld-red' : 'ld-green'}>{t.type === 'debit' ? '−' : '+'}{money(t.amount)}</b> }, { label: 'Wallet after', render: (t) => money(t.balanceAfter) },
        ]} />
      </>}
      <h4 className="ld-h4">Status timeline</h4>
      <div className="timeline">{data.timeline.map((l) => <div key={l.id}><b>{l.from ? `${l.from} → ${l.to}` : l.to}</b><span>{dateTime(l.createdAt)} · by {l.actorRole}</span></div>)}</div>
      <h4 className="ld-h4">Transcript ({data.messages.length})</h4>
      <div className="ld-transcript">
        {!data.messages.length && <div className="no-results">No messages.</div>}
        {data.messages.map((m, i) => {
          const day = new Date(m.createdAt).toDateString(); const newDay = i === 0 || new Date(data.messages[i - 1].createdAt).toDateString() !== day;
          return <React.Fragment key={m.id}>
            {newDay && <div className="ld-day">{new Date(m.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' })}</div>}
            {m.type === 'call'
              ? <div className={`ld-call ${m.callStatus === 'ended' ? '' : 'missed'}`}>{m.callStatus === 'ended' ? <Phone size={12} /> : <PhoneMissed size={12} />} {m.text} · {clock(m.createdAt)} · started by {m.senderName}</div>
              : <div className={`ld-bubble ${m.senderRole}`}><small>{m.senderName}</small><p>{m.text}</p>
                  <span>{clock(m.createdAt)} {m.status === 'read' ? <CheckCheck size={12} className="read" /> : m.status === 'delivered' ? <CheckCheck size={12} /> : <Check size={12} />}</span>
                  <em>Delivered {m.deliveredAt ? clock(m.deliveredAt) : '—'} · Read {m.readAt ? clock(m.readAt) : '—'}</em></div>}
          </React.Fragment>;
        })}
      </div>
      <h4 className="ld-h4">Calls ({data.calls.length})</h4>
      <Table rows={data.calls} empty="No calls in this chat." columns={callColumns(true)} />
    </>}
  </Drawer>;
}

export const callColumns = (compact = false, onEnd) => [
  { label: 'Caller', render: (c) => <><b>{c.callerName}</b><small>{c.callerRole}{c.callerPhone ? ` · ${c.callerPhone}` : ''}</small></> },
  { label: 'Receiver', render: (c) => <><b>{c.receiverName}</b><small>{c.receiverRole}{c.receiverPhone ? ` · ${c.receiverPhone}` : ''}</small></> },
  { label: 'Status', render: (c) => <Badge>{c.status}</Badge> },
  { label: 'Started', render: (c) => dateTime(c.startedAt) }, { label: 'Answered', render: (c) => dateTime(c.answeredAt) }, { label: 'Ended', render: (c) => dateTime(c.endedAt) },
  { label: 'Duration', render: (c) => duration(c.durationSeconds) }, { label: 'Ended by', render: (c) => c.endedBy || '—' },
  ...(compact ? [] : [{ label: 'Chat', render: (c) => <Link className="view" to={`/history?open=${c.requestId}`}>Open</Link> }]),
  ...(onEnd ? [{ label: 'Action', render: (c) => <button className="view danger" onClick={(e) => { e.stopPropagation(); onEnd(c); }}><PhoneOff size={12} /> End</button> }] : []),
];

export function CallLogs() {
  const [params, setParams] = useSearchParams();
  const filters = Object.fromEntries(['status', 'from', 'to', 'accountId', 'page'].map((k) => [k, params.get(k) || '']));
  const query = qs({ ...filters, limit: 25 });
  const { data, error } = useLiveData(() => api(`/api/admin/calls?${query}`), [query]);
  function set(key, value) { const next = new URLSearchParams(params); value ? next.set(key, value) : next.delete(key); if (key !== 'page') next.delete('page'); setParams(next); }
  const items = data?.items || [];
  return <>
    <PageHead title="Call Logs" desc="Every voice call: who called whom, the result and how long it lasted."><ExportButton path={`/api/admin/calls.csv?${qs({ ...filters, page: '' })}`} name="vakil-calls.csv" /></PageHead>
    <ErrorNote error={error} />
    <Stats cols={3}>
      <Stat label="Calls (this filter)" value={number(data?.total)} icon={PhoneCall} />
      <Stat label="Missed / declined (this page)" value={number(items.filter((c) => ['missed', 'rejected'].includes(c.status)).length)} icon={PhoneMissed} tone="red" />
      <Stat label="Avg answered duration (this page)" value={duration(Math.round(items.filter((c) => c.durationSeconds).reduce((n, c, _, a) => n + c.durationSeconds / a.length, 0)))} icon={Timer} tone="green" />
    </Stats>
    <Card title="Voice calls" actions={<div className="ld-filters">
      <select value={filters.status} onChange={(e) => set('status', e.target.value)}><option value="">All statuses</option>{['ringing', 'answered', 'ended', 'rejected', 'missed', 'failed'].map((x) => <option key={x}>{x}</option>)}</select>
      <label>From <input type="date" value={filters.from} onChange={(e) => set('from', e.target.value)} /></label>
      <label>To <input type="date" value={filters.to} onChange={(e) => set('to', e.target.value)} /></label>
      {filters.accountId && <Badge tone="warn">One customer's calls</Badge>}
      {[...params.keys()].length > 0 && <button className="secondary" onClick={() => setParams({})}><X size={12} /> Clear</button>}</div>}>
      <Table rows={data?.items} empty="No calls match." columns={callColumns()} />
      <Pager data={data} onPage={(p) => set('page', String(p))} />
    </Card>
  </>;
}
