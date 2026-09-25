import React, { useState } from 'react';
import { Clock, RotateCcw, IndianRupee } from 'lucide-react';
import { api } from '../api.js';
import { Badge, Card, ErrorNote, NotChargingNote, PageHead, Pager, Stat, Stats, Table, dateTime, duration, money, number, useLiveData } from '../ui.jsx';
import { AuditLog, SaveBar, useSetting } from './Pricing.jsx';

// How a consultation turns into a charge; "live" steps already run in the apps today.
const flow = [
  ['Customer selects lawyer', 'A request is created for an available lawyer (60 seconds to answer).', true],
  ['Lawyer accepts the request', 'The chat opens on both phones and the server clock starts.', true],
  ['First chat is a free trial', 'The very first chat lasts 1 minute and is always ₹0.', true],
  ['Trial countdown on the server', 'The free minute counts down from the server time; at 0:00 the chat and any call end.', true],
  ['Charged per minute from the wallet', "Minute 1 on accept, then at the start of every minute, at the lawyer's rate.", true],
  ['Low-balance warnings', 'Both apps are warned when the wallet cannot cover the next minute.', true],
  ['Ends when the balance runs out', 'The chat and any call end automatically (reason: balance ran out).', true],
  ['Wallet ledger', 'Every recharge and minute is a wallet entry with the balance after it.', true],
];

export default function Billing() {
  const [pageNo, setPage] = useState(1);
  const { data, error } = useLiveData(() => api(`/api/admin/billing?page=${pageNo}&limit=15`), [pageNo]);
  const s = useSetting('billing'); const f = s.form;
  const num = (name, unit, hint) => <label className="ld-setting"><span>{hint}</span><span className="ld-inline-input">{unit === '₹' ? '₹' : ''}<input type="number" min="0" {...s.field(name)} />{unit !== '₹' ? unit : ''}</span></label>;
  const text = (name, hint) => <label className="ld-setting"><span>{hint}</span><input {...s.field(name)} /></label>;
  return <>
    <PageHead title="Per-Minute Billing System" desc="How consultations are timed and charged, the billing parameters, and the metering log of every finished session." />
    <ErrorNote error={error || s.error} />
    {data && !data.stats.chargingEnabled && <NotChargingNote />}
    <Stats cols={3}>
      <Stat label="Minutes Consulted (Today)" value={`${number(data?.stats.minutesToday)} mins`} icon={Clock} sub={`+ ${number(data?.stats.trialMinutesToday)} free trial mins`} />
      <Stat label="Adjustments & Claims" value={`${number(data?.stats.adjustmentsToday)} today`} icon={RotateCcw} tone="violet" sub="refund requests raised" />
      <Stat label="Live Accrued Billing" value={money(data?.stats.accruedToday)} icon={IndianRupee} tone="green" sub="charged in chats finished today" />
    </Stats>
    <Card title="Billing Flow Specification" desc="Charging, balance checks, commission and invoices run on the server." actions={<Badge tone="good">Server enforced</Badge>}>
      <div className="ld-flow">{flow.map(([title, text2, live], i) => <div key={title} className="ld-step"><span>{i + 1}</span><b>{title}</b><p>{text2}</p><Badge tone={live ? 'good' : 'plain'}>{live ? 'Live now' : 'When charging starts'}</Badge></div>)}</div>
    </Card>
    <Card title="Admin Billing Settings" desc="Saved with an audit record. Charging currently runs per whole minute; these settings are kept for finer billing later.">
      {f && <div className="ld-settings">
        {num('intervalSeconds', 's', 'Billing interval')}
        {num('minimumCharge', '₹', 'Minimum consultation charge')}
        {num('graceSeconds', 's', 'Grace period before billing')}
        {num('connectionTimeoutSeconds', 's', 'Connection timeout')}
        {num('lowBalanceWarnings', ' intervals', 'Low-balance warning before')}
        {num('reconnectSeconds', 's', 'Reconnection period')}
        {num('gstPercent', '%', 'GST on platform fee')}
        {text('customerCancelBeforeConnect', 'Customer cancels before connection')}
        {text('lawyerCancelAfterAccept', 'Lawyer cancels after accepting')}
        {text('lowBalanceEnd', 'Session ends on low balance')}
      </div>}
      <SaveBar s={s} />
    </Card>
    <Card title="Live Metering & Session Log" desc="Every finished consultation with billed minutes and charge.">
      <Table rows={data?.log.items} empty="No finished consultations yet." columns={[
        { label: 'Session', render: (r) => <span className="ld-link">…{r.id.slice(-6)}</span> }, { label: 'Customer', key: 'userName' }, { label: 'Lawyer', key: 'lawyerName' },
        { label: 'Duration', render: (r) => duration(r.durationSeconds) }, { label: 'Minutes charged', render: (r) => r.isTrial ? '0 (trial)' : r.minutes },
        { label: 'Total charge', render: (r) => <b>{money(r.amount)}</b> }, { label: 'Rule', render: (r) => <Badge tone={r.isTrial ? 'warn' : r.amount ? 'good' : 'plain'}>{r.rule}</Badge> },
        { label: 'Ended', render: (r) => <>{dateTime(r.completedAt)}<small>by {r.endedBy || '—'}</small></> },
      ]} />
      <Pager data={data && { ...data.log, items: data.log.items }} onPage={setPage} />
    </Card>
    <AuditLog s={s} />
  </>;
}
