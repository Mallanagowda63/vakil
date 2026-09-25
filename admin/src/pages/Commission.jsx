import React, { useState } from 'react';
import { Percent, Users, Megaphone, CalendarCheck } from 'lucide-react';
import { api } from '../api.js';
import { Badge, Card, ErrorNote, PageHead, Stat, Stats, Table, dateOnly, money, useLiveData } from '../ui.jsx';
import { AuditLog, SaveBar, useSetting } from './Pricing.jsx';

export default function Commission() {
  const s = useSetting('commission'); const f = s.form;
  const lawyers = useLiveData(() => api('/api/admin/lawyers'), [], { live: false });
  const overrides = lawyers.data?.items.filter((l) => l.commissionOverride !== null) || [];
  const [sample, setSample] = useState(500);
  const promoActive = f?.promoUntil && new Date(f.promoUntil) >= new Date();
  const rate = promoActive ? f.promoPercent : f?.defaultPercent ?? 0;
  const gst = 18; const fee = sample * rate / 100; const tax = fee * gst / 100;
  const block = (title, badge, body, reason) => <div className="ld-box"><div className="ld-box-head"><h4>{title}</h4><Badge tone="plain">{badge}</Badge></div>{body}<p className="ld-muted">{reason}</p></div>;
  return <>
    <PageHead title="Commission Management" desc="Platform commission, lawyer-specific overrides, promotional rates, tax handling and effective dates, with an audit record for every change." />
    <ErrorNote error={s.error} />
    <Stats>
      <Stat label="Default Platform Commission" value={f ? `${f.defaultPercent}% Flat` : '—'} icon={Percent} sub="applied to standard consultations" />
      <Stat label="Lawyer Overrides" value={`${overrides.length} Overrides`} icon={Users} tone="violet" sub={f ? `allowed range ${f.overrideMinPercent}% – ${f.overrideMaxPercent}%` : ''} />
      <Stat label="Promotional Commission" value={f ? `${f.promoPercent}%` : '—'} icon={Megaphone} tone="amber" sub={promoActive ? `active until ${dateOnly(f.promoUntil)}` : 'no active campaign'} />
      <Stat label="Effective From" value={f?.effectiveFrom ? dateOnly(f.effectiveFrom) : 'Immediately'} icon={CalendarCheck} tone="green" sub="for new consultations" />
    </Stats>
    <div className="ld-grid-main">
      <Card title="Commission configuration" desc="Changes are logged with the administrator, time and reason.">
        {f && <div className="ld-two">
          {block('Default platform commission', 'Live', <span className="ld-inline-input big"><input type="number" min="0" max="100" {...s.field('defaultPercent')} />%</span>, 'Baseline commission deducted from the lawyer’s gross earnings.')}
          {block('Lawyer-specific commission', `${overrides.length} overrides`, <span className="ld-inline-input big"><input type="number" min="0" max="100" {...s.field('overrideMinPercent')} />% – <input type="number" min="0" max="100" {...s.field('overrideMaxPercent')} />%</span>, 'Allowed range for per-lawyer overrides set in Lawyer Management.')}
          {block('Promotional commission', promoActive ? 'Active' : 'Scheduled', <><span className="ld-inline-input big"><input type="number" min="0" max="100" {...s.field('promoPercent')} />%</span><label className="ld-setting"><span>Campaign ends</span><input type="date" {...s.field('promoUntil')} /></label></>, 'Temporary reduced rate, e.g. for onboarding new lawyers.')}
          {block('Tax on platform fees', 'Enabled', <input className="ld-wide" {...s.field('taxNote')} />, 'How GST applies to the platform fee.')}
          {block('Commission effective date', 'Scheduled', <input type="date" {...s.field('effectiveFrom')} />, 'New rates apply to consultations after this date.')}
        </div>}
        <SaveBar s={s} />
      </Card>
      <Card title="Payout calculation example" desc="Check the numbers before publishing a change.">
        <label className="ld-setting"><span>Customer payment</span><span className="ld-inline-input">₹<input type="number" min="0" value={sample} onChange={(e) => setSample(Number(e.target.value) || 0)} /></span></label>
        <div className="ld-kv"><span>Customer payment</span><b>{money(sample)}</b></div>
        <div className="ld-kv"><span>Platform commission {rate}%</span><b className="ld-red">−{money(fee)}</b></div>
        <div className="ld-kv"><span>GST {gst}% on commission (platform pays)</span><b>{money(tax)}</b></div>
        <div className="ld-kv total"><span>Lawyer payout</span><b className="ld-green">{money(sample - fee)}</b></div>
      </Card>
    </div>
    <Card title="Lawyer-specific overrides" desc="Set per lawyer in Lawyer Management → Consultation Pricing & Commission.">
      <Table rows={overrides} empty="No lawyer has a custom commission." columns={[{ label: 'Lawyer', key: 'name' }, { label: 'Commission', render: (l) => `${l.commissionOverride}%` }, { label: 'Rate', render: (l) => `${money(l.rate)}/min` }, { label: 'Consultations', key: 'consultations' }]} />
    </Card>
    <AuditLog s={s} />
  </>;
}
