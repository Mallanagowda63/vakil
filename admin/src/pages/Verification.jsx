import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { BadgeCheck, Clock3, FileText, ShieldX, UserX, ExternalLink } from 'lucide-react';
import { api, fileUrl } from '../api.js';
import { Badge, Card, Drawer, ErrorNote, Note, PageHead, Person, Stat, Stats, Table, ago, dateOnly, dateTime, useLiveData } from '../ui.jsx';

// Lawyer Verification: every Partner App registration with its details and
// documents. Verify approves the lawyer; their app leaves the waiting screen
// and opens by itself. Reject sends the reason to the lawyer to fix and resend.

const tabs = [['under_review', 'Waiting for review'], ['pending', 'Not submitted'], ['rejected', 'Rejected'], ['approved', 'Verified'], ['', 'All']];
const statusText = { under_review: 'Waiting for review', pending: 'Not submitted', rejected: 'Rejected', approved: 'Verified', suspended: 'Suspended' };

export default function Verification() {
  const [params, setParams] = useSearchParams();
  const { data, error, refresh } = useLiveData(() => api('/api/admin/verifications'));
  const tab = params.get('status') ?? 'under_review'; const selected = params.get('id');
  const set = (key, value) => { const next = new URLSearchParams(params); value === null ? next.delete(key) : next.set(key, value); setParams(next); };
  const rows = data?.items.filter((l) => !tab || l.status === tab);
  const lawyer = data?.items.find((l) => l.id === selected);
  const s = data?.stats;

  return <>
    <PageHead title="Lawyer Verification" desc="Check each lawyer's Partner App registration and documents, then verify or reject it. A verified lawyer's app opens immediately." />
    <ErrorNote error={error} />
    <Stats>
      <Stat label="Waiting for review" value={s?.underReview ?? '—'} icon={Clock3} tone="amber" sub="Submitted, not checked yet" />
      <Stat label="Not submitted" value={s?.notSubmitted ?? '—'} icon={UserX} sub="Signed up, form not sent" />
      <Stat label="Rejected" value={s?.rejected ?? '—'} icon={ShieldX} tone="red" sub="Waiting for corrections" />
      <Stat label="Verified" value={s?.approved ?? '—'} icon={BadgeCheck} tone="green" sub="Taking consultations" />
    </Stats>
    <Card title="Registrations" desc="Open a registration to see all details and documents.">
      <div className="ld-chips">{tabs.map(([key, name]) => <button key={key} className={tab === key ? 'on' : ''} onClick={() => set('status', key)}><Badge tone={tab === key ? undefined : 'plain'}>{name}</Badge></button>)}</div>
      {!data && !error ? <div className="no-results">Loading…</div> : <Table rows={rows || []} onRow={(l) => set('id', l.id)} empty={tab === 'under_review' ? 'No registrations are waiting. New ones appear here as soon as a lawyer submits the form.' : 'Nothing here.'} columns={[
        { label: 'Lawyer', render: (l) => <Person name={l.name} photo={l.photoUrl} sub={l.email || l.phone || ''} /> },
        { label: 'Practice area', render: (l) => l.advocate.practiceArea || '—' },
        { label: 'Bar Council No.', render: (l) => l.advocate.barCouncilRegNo || '—' },
        { label: 'Documents', render: (l) => <DocBadges docs={l.documents} /> },
        { label: 'Submitted', render: (l) => l.submittedAt ? ago(l.submittedAt) : '—' },
        { label: 'Status', render: (l) => <Badge>{statusText[l.status] || l.status}</Badge> },
      ]} />}
    </Card>
    {lawyer && <Review lawyer={lawyer} onClose={() => set('id', null)} onChanged={refresh} />}
  </>;
}

const DocBadges = ({ docs }) => <span className="ld-actions">
  <Badge tone={docs.face ? 'good' : 'plain'}>{docs.face ? 'Face photo' : 'No face photo'}</Badge>
  <Badge tone={docs.license ? 'good' : 'plain'}>{docs.license ? 'Licence' : 'No licence'}</Badge>
</span>;

function Review({ lawyer: l, onClose, onChanged }) {
  const [busy, setBusy] = useState(false);
  async function decide(body, done) {
    setBusy(true);
    try { await api(`/api/admin/lawyers/${l.id}`, { method: 'PATCH', body: JSON.stringify(body) }); await onChanged(); alert(done); } catch (e) { alert(e.message); } finally { setBusy(false); }
  }
  const verify = () => window.confirm(`Verify ${l.name}? Their Partner App opens and they can start taking consultations.`) && decide({ verificationStatus: 'approved' }, `${l.name} is verified. Their app is open now.`);
  const reject = () => {
    const reason = window.prompt(`Why is ${l.name}'s registration rejected? The lawyer sees this in the app and can fix it.`, 'The advocate licence is not clear. Please upload a clear photo or PDF.');
    if (reason !== null) decide({ verificationStatus: 'rejected', rejectionReason: reason }, `${l.name}'s registration was rejected. They will see your reason.`);
  };
  const p = l.personal; const a = l.advocate;
  const checklist = [['Registration form submitted', Boolean(l.submittedAt)], ['Face verification photo', Boolean(l.documents.face)], ['Bar Council registration number', Boolean(a.barCouncilRegNo)], ['Advocate licence file', Boolean(l.documents.license)], ['Bank or UPI for payouts', Boolean(l.bank)]];
  const rows = (items) => <dl>{items.map(([k, v]) => <React.Fragment key={k}><dt>{k}</dt><dd>{v || '—'}</dd></React.Fragment>)}</dl>;

  return <Drawer title={l.name} sub={`${statusText[l.status] || l.status}${l.submittedAt ? ` · submitted ${dateTime(l.submittedAt)}` : ''}`} onClose={onClose} actions={<>
    {l.status !== 'approved' && l.status !== 'suspended' && <button className="ld-btn good" disabled={busy || !l.submittedAt} onClick={verify}><BadgeCheck size={13} /> Verify</button>}
    {['under_review', 'pending'].includes(l.status) && <button className="ld-btn bad" disabled={busy} onClick={reject}>Reject</button>}
  </>}>
    {!l.submittedAt && <Note>This lawyer signed up but has not sent the registration form from the Partner App yet, so there is nothing to verify.</Note>}
    {l.status === 'rejected' && <Note tone="bad">Rejected{l.rejectionReason ? `: ${l.rejectionReason}` : ''}. The lawyer can fix the registration and send it again.</Note>}
    {l.status === 'approved' && <Note>Verified{l.approvedAt ? ` on ${dateOnly(l.approvedAt)}` : ''}{l.approvedBy ? ` by ${l.approvedBy}` : ''}.</Note>}
    <div className="ld-box"><h4>Verification checklist</h4>{checklist.map(([k, ok]) => <div className="ld-check" key={k}><span>{k}</span><Badge tone={ok ? 'good' : 'plain'}>{ok ? 'Provided' : 'Missing'}</Badge></div>)}</div>
    <div className="ld-two">
      <div className="ld-box"><h4>Documents</h4>
        <Document lawyerId={l.id} kind="face" title="Face verification photo" meta={l.documents.face} />
        <Document lawyerId={l.id} kind="license" title="Advocate licence" meta={l.documents.license} fallbackName={a.licenseFileName} />
      </div>
      <div>
        <div className="ld-box"><h4>Personal details</h4>{rows([['Full name', p.fullName], ['Email', l.email], ['Mobile', l.phone], ['Date of birth', p.dateOfBirth], ['Gender', p.gender]])}</div>
        <div className="ld-box"><h4>Advocate details</h4>{rows([['Bar Council No.', a.barCouncilRegNo], ['Practice area', a.practiceArea], ['Primary court', a.court], ['City', a.city], ['Languages', a.languages]])}</div>
        <div className="ld-box"><h4>Bank &amp; UPI</h4>{l.bank ? rows([['Account holder', l.bank.holderName], ['Account', l.bank.account], ['IFSC', l.bank.ifsc], ['UPI', l.bank.upi]]) : <p className="ld-muted">No bank or UPI details.</p>}</div>
      </div>
    </div>
  </Drawer>;
}

// Shows an image document inline; a PDF opens in a new tab (the file needs the admin token, so it is fetched first).
function Document({ lawyerId, kind, title, meta, fallbackName }) {
  const [url, setUrl] = useState(null); const [error, setError] = useState('');
  useEffect(() => {
    if (!meta) return undefined;
    let made = null; setUrl(null); setError('');
    fileUrl(`/api/admin/lawyers/${lawyerId}/documents/${kind}`).then((u) => { made = u; setUrl(u); }).catch((e) => setError(e.message));
    return () => { if (made) URL.revokeObjectURL(made); };
  }, [lawyerId, kind, meta?.uploadedAt]);
  const isPdf = meta?.contentType === 'application/pdf';
  return <div className="ld-doc" style={{ marginBottom: 14 }}>
    <div className="ld-box-head"><b style={{ fontSize: 11 }}>{title}</b>{meta && <small className="ld-muted">{meta.fileName} · {Math.ceil(meta.size / 1024)} KB · {ago(meta.uploadedAt)}</small>}</div>
    {!meta ? <p className="ld-muted">{fallbackName ? `"${fallbackName}" was chosen in the app but not uploaded (older app version). Ask the lawyer to send the registration again from the updated app.` : 'Not uploaded.'}</p>
      : error ? <p className="ld-muted">Could not load: {error}</p>
        : !url ? <p className="ld-muted">Loading…</p>
          : isPdf ? <div><iframe title={title} src={url} style={{ width: '100%', height: 360, border: '1px solid var(--line)', borderRadius: 6 }} /><a className="secondary" href={url} target="_blank" rel="noreferrer"><ExternalLink size={12} /> Open PDF</a></div>
            : <a href={url} target="_blank" rel="noreferrer"><img src={url} alt={title} style={{ width: '100%', maxHeight: 360, objectFit: 'contain', background: '#f4f6fa', borderRadius: 6, marginTop: 6 }} /></a>}
    {meta && !isPdf && url && <small className="ld-muted"><FileText size={11} /> Click the image to open it full size.</small>}
  </div>;
}
