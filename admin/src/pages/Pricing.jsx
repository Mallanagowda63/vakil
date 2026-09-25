import React, { useEffect, useState } from 'react';
import { IndianRupee, Users, ArrowUpToLine, Percent } from 'lucide-react';
import { api } from '../api.js';
import { Card, ErrorNote, Note, PageHead, Stat, Stats, Table, Toggle, dateTime, money, useLiveData } from '../ui.jsx';

// Saves a settings group with an optional reason; returns the audit trail component too.
export function useSetting(key) {
  const state = useLiveData(() => api(`/api/admin/settings/${key}`), [key], { live: false });
  const [form, setForm] = useState(null); const [saving, setSaving] = useState(false);
  useEffect(() => { if (state.data) setForm(state.data.value); }, [state.data]);
  const dirty = form && state.data && JSON.stringify(form) !== JSON.stringify(state.data.value);
  async function save(reason = '') {
    setSaving(true);
    try { await api(`/api/admin/settings/${key}`, { method: 'PUT', body: JSON.stringify({ value: form, reason }) }); await state.refresh(); } catch (e) { alert(e.message); } finally { setSaving(false); }
  }
  const field = (name) => ({ value: form?.[name] ?? '', onChange: (e) => setForm((f) => ({ ...f, [name]: e.target.type === 'number' ? (e.target.value === '' ? '' : Number(e.target.value)) : e.target.value })) });
  return { ...state, form, setForm, field, dirty, saving, save, reset: () => setForm(state.data.value) };
}

export function SaveBar({ s, label = 'Save changes' }) {
  const [reason, setReason] = useState('');
  if (!s.dirty) return null;
  return <div className="ld-savebar"><span>Unsaved changes</span><input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Reason for the change (audit log)" /><button className="secondary" onClick={s.reset}>Discard</button><button className="primary" disabled={s.saving} onClick={() => s.save(reason).then(() => setReason(''))}>{s.saving ? 'Saving…' : label}</button></div>;
}

export function AuditLog({ s, title = 'Administrator audit record' }) {
  return <Card title={title} desc={s.data?.updatedAt ? `Last changed ${dateTime(s.data.updatedAt)} by ${s.data.updatedBy}` : 'No changes yet: platform defaults are in use.'}>
    {s.data?.audit.length ? s.data.audit.map((a) => <div className="ld-audit" key={a.id}><b>{a.changes.map((c) => `${c.field}: ${JSON.stringify(c.from)} → ${JSON.stringify(c.to)}`).join(' · ')}</b><small>{dateTime(a.createdAt)} · {a.adminPhone}{a.reason ? ` · “${a.reason}”` : ''}</small></div>) : <div className="no-results">No changes recorded.</div>}
  </Card>;
}

export default function Pricing() {
  const s = useSetting('pricing'); const commission = useLiveData(() => api('/api/admin/settings/commission'), [], { live: false });
  const lawyers = useLiveData(() => api('/api/admin/lawyers'), [], { live: false });
  const f = s.form; const fee = commission.data?.value.defaultPercent ?? 20;
  const overrides = lawyers.data?.items.filter((l) => l.rateOverridden) || [];
  const rows = f ? [
    { id: 'minPerMinute', name: 'Minimum per-minute rate', control: 'Floor rate for all lawyers', basis: 'Applies to all modes' },
    { id: 'maxPerMinute', name: 'Maximum per-minute rate', control: 'Cap for premium and specialist rates', basis: 'Applies to all modes' },
    { id: 'chatPerMinute', name: 'Chat rate per minute', control: 'Customer rate for text consultation', basis: `Customer pays ${money(f.chatPerMinute)}/min` },
    { id: 'callPerMinute', name: 'Voice-call rate per minute', control: 'Customer rate for voice consultation', basis: `Customer pays ${money(f.callPerMinute)}/min` },
    { id: 'nightPerMinute', name: 'Night-time rate', control: `Surge between ${f.nightFrom} and ${f.nightTo}`, basis: `Customer pays ${money(f.nightPerMinute)}/min` },
    { id: 'promoDiscountPercent', name: 'Promotional discount', control: 'Campaign discount on customer rate', basis: 'Customer side only', unit: '%' },
  ] : null;
  const example = (rate) => ({ rate, fee: Math.round(rate * fee) / 100, lawyer: Math.round(rate * (100 - fee)) / 100 });
  return <>
    <PageHead title="Lawyer Pricing Management" desc="Indian-rupee pricing rules, platform commission, promotional discounts and lawyer-specific overrides." />
    <ErrorNote error={s.error} />
    <Note>After the free trial, chats and calls are charged per minute from the user's wallet at the lawyer's own rate (Lawyer Management) or, if none is set, the chat rate below. The minimum and maximum limit the rates lawyers can set themselves.</Note>
    <Stats>
      <Stat label="Average Customer Rate" value={f ? `${money((f.chatPerMinute + f.callPerMinute) / 2)}/min` : '—'} icon={IndianRupee} sub="chat and voice" />
      <Stat label="Lawyer Rate Overrides" value={overrides.length} icon={Users} tone="amber" sub={f?.lawyerOverrides ? 'overrides allowed' : 'overrides switched off'} />
      <Stat label="Max Cap Authorized" value={f ? `${money(f.maxPerMinute)}/min` : '—'} icon={ArrowUpToLine} tone="violet" sub={f ? `floor ${money(f.minPerMinute)}/min` : ''} />
      <Stat label="Platform Commission" value={`${fee}%`} icon={Percent} tone="green" sub="auto deducted from lawyer earnings" />
    </Stats>
    <Card title="Indian Rate Configuration Matrix" desc="Minimum and maximum per-minute rates, consultation-type rates, night-time rate, promotional discount and lawyer-specific overrides.">
      <Table rows={rows} rowKey={(r) => r.id} columns={[
        { label: 'Rate Parameter', render: (r) => <b>{r.name}</b> }, { label: 'Admin Control', key: 'control' },
        { label: 'Current Setting', render: (r) => <span className="ld-inline-input">{r.unit ? '' : '₹'}<input type="number" min="0" {...s.field(r.id)} />{r.unit || '/min'}</span> },
        { label: 'Payout Basis', key: 'basis' },
      ]} />
      {f && <div className="ld-form-row">
        <label>Night rate starts<input type="time" {...s.field('nightFrom')} /></label>
        <label>Night rate ends<input type="time" {...s.field('nightTo')} /></label>
        <div className="ld-switch"><div><b>Lawyer-specific rates</b><small>Allow per-lawyer overrides (Lawyer Management)</small></div><Toggle checked={f.lawyerOverrides} onChange={(v) => s.setForm({ ...f, lawyerOverrides: v })} /></div>
      </div>}
      <SaveBar s={s} />
    </Card>
    <div className="ld-grid-2">
      <Card title="Commission Deduction Examples" desc={`Commission (${fee}%) is deducted from the lawyer's gross earnings before payout.`}>
        {f && <div className="ld-two">{[['Chat', f.chatPerMinute], ['Voice call', f.callPerMinute]].map(([name, rate]) => { const e = example(rate); return <div className="ld-box" key={name}><h4>{name}</h4><div className="ld-kv"><span>Customer rate</span><b>{money(e.rate)}/min</b></div><div className="ld-kv"><span>Commission {fee}%</span><b className="ld-red">−{money(e.fee)}/min</b></div><div className="ld-kv"><span>Lawyer receives</span><b className="ld-green">{money(e.lawyer)}/min</b></div></div>; })}</div>}
      </Card>
      <Card title="Lawyer-specific overrides" desc="Set on each lawyer in Lawyer Management.">
        <Table rows={overrides} empty="No lawyer has a custom rate." columns={[{ label: 'Lawyer', key: 'name' }, { label: 'Rate', render: (l) => `${money(l.rate)}/min` }, { label: 'Commission', render: (l) => l.commissionOverride === null ? `${fee}% (default)` : `${l.commissionOverride}%` }]} />
      </Card>
    </div>
    <AuditLog s={s} />
  </>;
}
