import React, { useState } from 'react';
import { MessageSquare, CheckCircle2, PhoneCall, IndianRupee } from 'lucide-react';
import { api } from '../api.js';
import { Bars, Card, ErrorNote, ExportButton, PageHead, Progress, Stat, Stats, Table, money, number, useLiveData } from '../ui.jsx';

export default function Reports() {
  const [days, setDays] = useState(30); const [metric, setMetric] = useState('consultations');
  const { data, error } = useLiveData(() => api(`/api/admin/reports?days=${days}`), [days]);
  const t = data?.totals;
  const series = data?.series.map((d) => ({ ...d, label: new Date(d.date).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) }));
  return <>
    <PageHead title="Reports & Analytics Workspace" desc="Consultations, calls, revenue, categories and lawyer performance over time.">
      <div className="range-tabs">{[7, 30, 90].map((n) => <button key={n} className={days === n ? 'active' : ''} onClick={() => setDays(n)}>{n}D</button>)}</div>
      <ExportButton path="/api/admin/requests.csv" name="vakil-report.csv" label="Export CSV" />
    </PageHead>
    <ErrorNote error={error} />
    <Stats>
      <Stat label={`Consultations (${days}d)`} value={number(t?.consultations)} icon={MessageSquare} sub={`${number(t?.trial)} free trials`} />
      <Stat label="Completed" value={number(t?.completed)} icon={CheckCircle2} tone="green" sub={t?.consultations ? `${Math.round(t.completed / t.consultations * 100)}% of requests` : ''} />
      <Stat label="Voice Calls" value={number(t?.calls)} icon={PhoneCall} tone="violet" />
      <Stat label="Revenue" value={money(t?.revenue)} icon={IndianRupee} tone="amber" sub={`${money(t?.refunds)} refunded`} />
    </Stats>
    <Card title={`${days}-Day Trend`} desc="Hover a bar to inspect the day." actions={<div className="range-tabs">{[['consultations', 'Consultations'], ['calls', 'Calls'], ['revenue', 'Revenue']].map(([k, name]) => <button key={k} className={metric === k ? 'active' : ''} onClick={() => setMetric(k)}>{name}</button>)}</div>}>
      {series && <Bars data={series} value={(d) => d[metric]} format={metric === 'revenue' ? money : number} height={200} />}
    </Card>
    <div className="ld-grid-main">
      <Card title="Top Performing Advocates" desc="By completed consultations in this period.">
        <Table rows={data?.topLawyers} empty="No lawyers yet." columns={[
          { label: 'Advocate', key: 'name' }, { label: 'Consultations', key: 'consultations' }, { label: 'Acceptance', render: (l) => l.acceptance === null ? '—' : `${l.acceptance}%` },
          { label: 'Avg response', render: (l) => l.responseSeconds === null ? '—' : `${l.responseSeconds}s` }, { label: 'Rating', render: (l) => l.rating ? `${l.rating} ★` : '—' }, { label: 'Earnings', render: (l) => money(l.earnings) },
        ]} />
      </Card>
      <Card title="Category Demand" desc="Share of requests in this period.">
        {data?.categories.length ? <Progress items={data.categories} /> : <div className="no-results">No requests in this period.</div>}
      </Card>
    </div>
    <Card title="Consolidated Platform Financial Ledger" desc="Totals from payments, commission, payouts and refunds.">
      <Table rows={data?.ledger} rowKey={(r) => r.label} columns={[{ label: 'Financial Item', key: 'label' }, { label: 'Amount (INR)', render: (r) => <b>{money(r.amount)}</b> }]} />
    </Card>
  </>;
}
