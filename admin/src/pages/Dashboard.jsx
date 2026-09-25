import React from 'react';
import { Link } from 'react-router-dom';
import { Users, Briefcase, ShieldCheck, Wifi, MessageSquare, PhoneCall, CalendarCheck, IndianRupee, TrendingUp, Wallet, Clock, RotateCcw, AlertCircle, XCircle, Flag } from 'lucide-react';
import { api } from '../api.js';
import { Bars, Card, ErrorNote, ExportButton, PageHead, Person, Progress, SectionTitle, Stat, Stats, money, number, useLiveData } from '../ui.jsx';

export default function Dashboard() {
  const { data: d, error } = useLiveData(() => api('/api/admin/overview'));
  const grew = (now, before) => now > before ? `↑ ${number(now - before)}` : null;
  return <>
    <PageHead title="Main Dashboard" desc="Live overview of registrations, chats, calls and money across Vakil."><ExportButton path="/api/admin/requests.csv" name="vakil-requests.csv" label="Export Report" /></PageHead>
    <ErrorNote error={error} />
    {!d ? !error && <div className="no-results">Loading…</div> : <>
      <SectionTitle>Registration Overview</SectionTitle>
      <Stats>
        <Stat label="Total Registered Customers" value={number(d.registration.customers)} icon={Users} trend={grew(d.registration.customers, d.registration.customersLastWeek)} sub={grew(d.registration.customers, d.registration.customersLastWeek) ? 'this week' : 'no new sign-ups this week'} />
        <Stat label="Total Registered Lawyers" value={number(d.registration.lawyers)} icon={Briefcase} tone="violet" trend={grew(d.registration.lawyers, d.registration.lawyersLastWeek)} sub={grew(d.registration.lawyers, d.registration.lawyersLastWeek) ? 'this week' : 'no new lawyers this week'} />
        <Stat label="Lawyers Pending Verification" value={number(d.registration.pendingVerification)} icon={ShieldCheck} tone="amber" sub={d.registration.pendingVerification ? <Link to="/lawyers?status=under_review">Review now</Link> : 'all reviewed'} />
        <Stat label="Lawyers Currently Online" value={number(d.registration.lawyersOnline)} icon={Wifi} tone="green" sub="Partner App open right now" />
      </Stats>

      <SectionTitle>Communication Activity</SectionTitle>
      <Stats cols={3}>
        <Stat label="Active Chats" value={number(d.communication.activeChats)} icon={MessageSquare} sub={<Link to="/live">Open live view</Link>} />
        <Stat label="Active Voice Calls" value={number(d.communication.activeCalls)} icon={PhoneCall} tone="green" sub={`${number(d.communication.callsToday)} calls today`} />
        <Stat label="Today's Consultations" value={number(d.communication.consultationsToday)} icon={CalendarCheck} tone="amber" sub="requests created today" />
      </Stats>

      <SectionTitle>Financial Performance</SectionTitle>
      <Stats>
        <Stat label="Today's Customer Payments" value={money(d.finance.customerPaymentsToday)} icon={IndianRupee} tone="green" sub={d.finance.anyPayments ? 'successful payments' : 'no payments recorded yet'} />
        <Stat label="Today's Platform Commission" value={money(d.finance.platformCommissionToday)} icon={TrendingUp} sub="from today's payments" />
        <Stat label="Lawyer Earnings (Today)" value={money(d.finance.lawyerEarningsToday)} icon={Wallet} tone="violet" sub="after commission" />
        <Stat label="Pending Payouts" value={money(d.finance.pendingPayouts)} icon={Clock} tone="amber" sub={<Link to="/payouts">Payout queue</Link>} />
      </Stats>

      <SectionTitle>Operational Alerts</SectionTitle>
      <Stats>
        <Stat label="Refund Requests" value={number(d.alerts.refundRequests)} icon={RotateCcw} tone="red" sub={<Link to="/refunds">awaiting decision</Link>} />
        <Stat label="Open Complaints" value={number(d.alerts.openComplaints)} icon={AlertCircle} tone="red" sub={<Link to="/complaints">not resolved</Link>} />
        <Stat label="Failed Payments" value={number(d.alerts.failedPayments)} icon={XCircle} tone="red" sub={<Link to="/payments">payment issues</Link>} />
        <Stat label="Flagged Reviews" value={number(d.alerts.flaggedReviews)} icon={Flag} tone="amber" sub={<Link to="/reviews">moderation</Link>} />
      </Stats>

      <div className="ld-grid-3">
        <Card title="Monthly Consultations" desc={`Requests per month · revenue ${money(d.monthly.reduce((n, m) => n + m.revenue, 0))} in this period`}>
          <Bars data={d.monthly} value={(m) => m.consultations} height={190} />
        </Card>
        <Card title="Popular Categories" desc="Share of all requests">
          {d.topCategories.length ? <Progress items={d.topCategories} /> : <div className="no-results">No requests yet.</div>}
        </Card>
        <Card title="Top Performing Lawyers" desc="By completed consultations">
          {d.topLawyers.length ? d.topLawyers.map((l) => <div className="ld-row" key={l.id}><Person name={l.name} sub={l.category} /><b className="ld-green">{number(l.consultations)} chats</b></div>) : <div className="no-results">No lawyers yet.</div>}
        </Card>
      </div>
    </>}
  </>;
}
