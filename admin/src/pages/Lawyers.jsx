import React, { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { Briefcase, ShieldCheck, Wifi, Star, Search } from 'lucide-react';
import { api } from '../api.js';
import { Badge, Card, ErrorNote, Note, PageHead, Person, Stat, Stats, Table, Toggle, ago, dateOnly, dateTime, duration, money, number, useLiveData } from '../ui.jsx';

const statusNames = { approved: 'Approved', under_review: 'Under review', pending: 'Pending', rejected: 'Rejected', suspended: 'Suspended' };

export default function Lawyers() {
  const [params, setParams] = useSearchParams();
  const { data, error, refresh } = useLiveData(() => api('/api/admin/lawyers'));
  const [q, setQ] = useState(''); const [specialty, setSpecialty] = useState(''); const [presence, setPresence] = useState('');
  const status = params.get('status') || ''; const selected = params.get('id');
  const all = data?.items;
  const specialties = useMemo(() => [...new Set((all || []).flatMap((l) => l.categories))].sort(), [all]);
  const rows = all?.filter((l) => (!status || l.verificationStatus === status) && (!specialty || l.categories.includes(specialty)) && (!presence || (presence === 'online' ? l.online : !l.online)) && `${l.name} ${l.phone} ${l.city || ''}`.toLowerCase().includes(q.toLowerCase()));
  const count = (s) => all?.filter((l) => l.verificationStatus === s).length ?? 0;
  const rated = all?.filter((l) => l.ratingAverage !== null) || [];
  const avgRating = rated.length ? rated.reduce((n, l) => n + l.ratingAverage, 0) / rated.length : null;
  const set = (key, value) => { const next = new URLSearchParams(params); value ? next.set(key, value) : next.delete(key); setParams(next); };

  return <>
    <PageHead title="Lawyer Management" desc="Verify, approve and manage lawyers: registrations, pricing, communication settings, visibility, complaints and consultation history in one place." />
    <ErrorNote error={error} />
    <Stats>
      <Stat label="Total Lawyers" value={number(all?.length)} icon={Briefcase} sub={`${count('approved')} approved`} />
      <Stat label="Pending Verifications" value={number(count('under_review') + count('pending'))} icon={ShieldCheck} tone="amber" sub={`${count('under_review')} submitted documents`} />
      <Stat label="Active & Online" value={number(all?.filter((l) => l.online).length)} icon={Wifi} tone="green" sub="taking chats now" />
      <Stat label="Avg Rating Quality" value={avgRating === null ? '—' : `${Math.round(avgRating / 5 * 100)}%`} icon={Star} tone="violet" sub={avgRating === null ? 'no ratings yet' : `${avgRating.toFixed(1)} / 5 average`} />
    </Stats>
    <Card title="Lawyer Directory" desc="Search, filter, approve, suspend and inspect lawyer records.">
      <div className="ld-filters">
        <label className="ld-search"><Search size={13} /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search by name, mobile or city" /></label>
        <select value={specialty} onChange={(e) => setSpecialty(e.target.value)}><option value="">All specialities</option>{specialties.map((s) => <option key={s}>{s}</option>)}</select>
        <select value={status} onChange={(e) => set('status', e.target.value)}><option value="">All verification</option>{Object.entries(statusNames).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
        <select value={presence} onChange={(e) => setPresence(e.target.value)}><option value="">Online / Offline</option><option value="online">Online</option><option value="offline">Offline</option></select>
      </div>
      <div className="ld-chips">{Object.entries(statusNames).map(([k, v]) => <button key={k} className={status === k ? 'on' : ''} onClick={() => set('status', status === k ? '' : k)}><Badge>{k}</Badge> {count(k)}</button>)}</div>
      <Table rows={rows} empty="No lawyers match these filters." onRow={(l) => set('id', l.id)} columns={[
        { label: 'Lawyer', render: (l) => <Person name={l.name} photo={l.photoUrl} sub={[l.categories.slice(0, 2).join(', '), l.city].filter(Boolean).join(' · ')} /> },
        { label: 'Verification', render: (l) => <Badge>{l.verificationStatus}</Badge> },
        { label: 'Availability', render: (l) => <><b className={l.chatOnline || l.callOnline ? 'ld-green' : ''}>{l.chatOnline || l.callOnline ? 'Online' : 'Offline'}</b><small>{l.appConnected ? 'App open' : `Last active ${ago(l.lastSeenAt)}`}</small></> },
        { label: 'Taking now', render: (l) => <span className="ld-tags"><span className={l.chatOnline ? '' : 'off'} title={!l.channels.chat ? 'Chat turned off by admin' : l.chatSwitch ? '' : 'Lawyer switched chat off'}>Chat</span><span className={l.callOnline ? '' : 'off'} title={!l.channels.call ? 'Calls turned off by admin' : l.callSwitch ? '' : 'Lawyer switched calls off'}>Call</span></span> },
        { label: 'Pricing', render: (l) => <><b>{money(l.rate)}/min</b><small>{l.rateOverridden ? 'lawyer override' : 'platform rate'}{l.commissionOverride !== null ? ` · ${l.commissionOverride}% commission` : ''}</small></> },
        { label: 'Ratings', render: (l) => l.ratingAverage === null ? '—' : <b>{l.ratingAverage} ★ · {l.ratingCount}</b> },
        { label: 'Consultations', render: (l) => <><b>{number(l.consultations)}</b><small>{l.acceptanceRate === null ? 'no answers yet' : `${l.acceptanceRate}% accepted · ${l.averageResponseSeconds}s`}</small></> },
        { label: 'Earnings', render: (l) => <b>{money(l.earnings)}</b> },
        { label: 'Complaints', render: (l) => l.openComplaints ? <Badge tone="bad">{`${l.openComplaints} open`}</Badge> : '0 open' },
      ]} />
    </Card>
    {selected && <LawyerWorkspace id={selected} onChanged={refresh} onClose={() => set('id', '')} />}
  </>;
}

function LawyerWorkspace({ id, onChanged, onClose }) {
  const { data, error, refresh } = useLiveData(() => api(`/api/admin/lawyers/${id}`), [id], { live: false });
  const [rate, setRate] = useState(''); const [commission, setCommission] = useState(''); const [notes, setNotes] = useState(''); const [busy, setBusy] = useState(false);
  const l = data?.lawyer;
  useEffect(() => { if (l) { setRate(l.rateOverride ?? ''); setCommission(l.commissionOverride ?? ''); setNotes(l.verificationNotes); } }, [l]);
  async function save(body, confirmText) {
    if (confirmText && !window.confirm(confirmText)) return;
    setBusy(true);
    try { await api(`/api/admin/lawyers/${id}`, { method: 'PATCH', body: JSON.stringify(body) }); await refresh(); onChanged(); } catch (e) { alert(e.message); } finally { setBusy(false); }
  }
  if (!l) return <Card title="Lawyer Detail Workspace"><ErrorNote error={error} />{!error && <div className="no-results">Loading…</div>}</Card>;
  const r = l.registration;
  const checklist = [['Profile details', Boolean(r.submittedAt)], ['Bar Council registration', Boolean(r.barCouncilRegNo)], ['Advocate licence file', r.licenseUploaded], ['Face verification', r.faceVerified], ['Bank or UPI for payouts', Boolean(l.bank)]];
  return <Card className="ld-workspace" title="Lawyer Detail Workspace" desc="Verification, pricing, communication and moderation controls for the selected lawyer." actions={<>
    {l.verificationStatus !== 'approved' && <button className="ld-btn good" disabled={busy} onClick={() => save({ verificationStatus: 'approved' })}>Approve</button>}
    {l.verificationStatus !== 'suspended' && <button className="ld-btn warn" disabled={busy} onClick={() => save({ verificationStatus: 'suspended' }, `Suspend ${l.name}? They are signed out and stop receiving requests.`)}>Suspend</button>}
    {l.verificationStatus === 'suspended' && <button className="ld-btn good" disabled={busy} onClick={() => save({ blocked: false })}>Lift suspension</button>}
    {!['rejected', 'approved'].includes(l.verificationStatus) && <button className="ld-btn bad" disabled={busy} onClick={() => save({ verificationStatus: 'rejected' }, `Reject ${l.name}'s registration?`)}>Reject</button>}
    <button className="secondary" onClick={onClose}>Close</button></>}>
    <div className="ld-work">
      <div className="ld-work-side">
        <div className="ld-profile">
          <Person name={l.name} photo={l.photoUrl} sub={l.categories.slice(0, 3).join(', ') || 'No practice areas yet'} />
          <Badge>{l.verificationStatus}</Badge>
          <p>{l.appConnected ? 'App open now' : `Last active ${ago(l.lastSeenAt)}`}{l.approvedAt ? ` · approved ${dateOnly(l.approvedAt)} by ${l.approvedBy}` : ''}</p>
          <dl>{[['Mobile', l.phone], ['Email', l.email], ['Bar Council No.', r.barCouncilRegNo], ['Joined', dateOnly(l.createdAt)]].map(([k, v]) => <React.Fragment key={k}><dt>{k}</dt><dd>{v || '—'}</dd></React.Fragment>)}</dl>
        </div>
        <div className="ld-box"><h4>Verification Checklist</h4>{checklist.map(([k, ok]) => <div className="ld-check" key={k}><span>{k}</span><Badge tone={ok ? 'good' : 'plain'}>{ok ? 'Verified' : 'Not submitted'}</Badge></div>)}</div>
        <div className="ld-box"><h4>Bank &amp; Payouts</h4>{l.bank ? <dl>{[['Account holder', l.bank.holderName], ['Account', l.bank.account], ['IFSC', l.bank.ifsc], ['UPI', l.bank.upi]].map(([k, v]) => <React.Fragment key={k}><dt>{k}</dt><dd>{v || '—'}</dd></React.Fragment>)}</dl> : <p className="ld-muted">No bank or UPI details submitted.</p>}
          {l.money && <dl>{[['Gross earnings', money(l.money.gross)], ['Commission', money(l.money.commission)], ['Paid out', money(l.money.paid)], ['Withdrawable', money(l.money.withdrawable)]].map(([k, v]) => <React.Fragment key={k}><dt>{k}</dt><dd>{v}</dd></React.Fragment>)}</dl>}</div>
      </div>
      <div className="ld-work-main">
        <div className="ld-box"><h4>Practising Profile</h4>
          {r.submittedAt ? <dl className="wide">{[['Legal specialisation', r.practiceArea], ['Practising court', r.court], ['City', r.city], ['Languages', r.languages], ['Gender', r.gender], ['Date of birth', r.dateOfBirth], ['Registration submitted', dateTime(r.submittedAt)]].map(([k, v]) => <React.Fragment key={k}><dt>{k}</dt><dd>{v || '—'}</dd></React.Fragment>)}</dl>
            : <p className="ld-muted">This lawyer has not submitted the Partner App registration (advocate and bank details) yet.</p>}
        </div>
        <div className="ld-box"><h4>Consultation Pricing &amp; Commission</h4>
          <div className="ld-form-row">
            <label>Rate per minute (₹) – shown to users, charged per minute<input type="number" min="0" value={rate} placeholder={`${l.defaultRate} (platform)`} onChange={(e) => setRate(e.target.value)} /></label>
            <label>Platform commission (%)<input type="number" min="0" max="100" value={commission} placeholder={`${l.defaultCommission} (default)`} onChange={(e) => setCommission(e.target.value)} /></label>
          </div>
          <div className="ld-actions"><button className="primary" disabled={busy} onClick={() => save({ rateOverride: rate, commissionOverride: commission })}>Save pricing</button><span className="ld-muted">Leave empty to use the platform defaults from <Link to="/pricing">Pricing</Link> and <Link to="/commissions">Commission</Link>.</span></div>
        </div>
        <div className="ld-box"><h4>Communication Channels</h4>
          <div className="ld-two">{[['chat', 'Chat', 'Customers can request chats with this lawyer.'], ['call', 'Voice call', 'Voice calls are allowed inside this lawyer\'s chats.']].map(([k, name, text]) => <div className="ld-switch" key={k}><div><b>{name}</b><small>{text}</small></div><Toggle checked={l.channels[k]} disabled={busy} onChange={(v) => save({ channels: { [k]: v } })} /></div>)}</div>
        </div>
        <div className="ld-box"><h4>Visibility &amp; Moderation</h4>
          <div className="ld-two">{[['featured', 'Featured lawyer'], ['recommended', 'Recommended lawyer']].map(([k, name]) => <div className="ld-switch" key={k}><div><b>{name}</b><small>{l[k] ? 'Enabled' : 'Disabled'}</small></div><Toggle checked={l[k]} disabled={busy} onChange={(v) => save({ [k]: v })} /></div>)}</div>
          <label className="ld-textarea">Verification notes<textarea rows="3" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Documents checked, follow-ups…" /></label>
          <button className="primary" disabled={busy || notes === l.verificationNotes} onClick={() => save({ verificationNotes: notes })}>Save verification note</button>
        </div>
        <div className="ld-box"><h4>Consultation History &amp; Complaints</h4>
          <Stats cols={3}><Stat label="Total consultations" value={number(data.stats.consultations)} sub={`${number(data.stats.requests)} requests`} /><Stat label="Avg rating" value={data.stats.ratingAverage === null ? '—' : `${data.stats.ratingAverage} / 5`} sub={`${data.stats.ratingCount} reviews`} /><Stat label="Open complaints" value={number(data.stats.openComplaints)} /></Stats>
          <Table rows={data.recent} empty="No consultations yet." columns={[
            { label: 'Customer', key: 'userName' }, { label: 'Category', key: 'category' }, { label: 'Status', render: (x) => <Badge>{x.status}</Badge> },
            { label: 'Duration', render: (x) => duration(x.durationSeconds) }, { label: 'Rating', render: (x) => x.rating ? `${x.rating} ★` : '—' }, { label: 'Date', render: (x) => <Link to={`/history?open=${x.id}`}>{dateTime(x.createdAt)}</Link> },
          ]} />
          {data.complaints.length > 0 && <Table rows={data.complaints} columns={[{ label: 'Ticket', key: 'ticket' }, { label: 'Customer', key: 'customer' }, { label: 'Category', key: 'category' }, { label: 'Status', render: (c) => <Badge>{c.status}</Badge> }, { label: 'Filed', render: (c) => dateOnly(c.createdAt) }]} />}
        </div>
      </div>
    </div>
    {l.verificationStatus === 'suspended' && <Note tone="bad">Suspended: this lawyer is signed out, hidden from customers and cannot sign in.</Note>}
  </Card>;
}
