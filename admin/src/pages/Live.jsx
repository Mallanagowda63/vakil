import React, { useEffect, useRef, useState } from 'react';
import { MessageSquare, PhoneCall, Hourglass, Flag } from 'lucide-react';
import { api } from '../api.js';
import { Badge, Card, ErrorNote, PageHead, Stat, Stats, Table, duration, number, useLiveData } from '../ui.jsx';
import { RequestDetail, callColumns, requestColumns } from './History.jsx';

export default function Live() {
  const { data, error, refresh } = useLiveData(() => api('/api/admin/live'));
  const [openId, setOpenId] = useState(null);
  const [, tick] = useState(0);
  // Trial countdowns and call timers tick locally between server updates.
  const loadedAt = useRef(Date.now()); useEffect(() => { loadedAt.current = Date.now(); }, [data]);
  useEffect(() => { const t = setInterval(() => tick((n) => n + 1), 1000); return () => clearInterval(t); }, []);
  const passed = Math.floor((Date.now() - loadedAt.current) / 1000);
  const chats = data?.chats.map((c) => ({ ...c, remainingSeconds: c.remainingSeconds === null ? null : Math.max(0, c.remainingSeconds - passed) }));
  const calls = data?.calls.map((c) => ({ ...c, durationSeconds: c.answeredAt ? Math.round((Date.now() - new Date(c.answeredAt)) / 1000) : 0 }));
  async function post(path, body, confirmText) {
    if (confirmText && !window.confirm(confirmText)) return;
    try { await api(path, { method: 'POST', body: JSON.stringify(body || {}) }); refresh(); } catch (e) { alert(e.message); }
  }
  const actions = { label: 'Admin Actions', render: (r) => <span className="ld-actions" onClick={(e) => e.stopPropagation()}>
    <button className="view" onClick={() => { const note = window.prompt('Why flag this chat?'); if (note !== null) post(`/api/admin/requests/${r.id}/flag`, { note }); }}><Flag size={12} /> Flag</button>
    <button className="view danger" onClick={() => post(`/api/admin/requests/${r.id}/end`, null, `End ${r.userName}'s chat with ${r.lawyerName} now? Any call ends too.`)}>End chat</button></span> };
  return <>
    <PageHead title="Live Consultation Management" desc="Monitor active chats and voice calls in real time, open transcripts, and intervene when needed."><Badge tone="good">Live monitoring active</Badge><Badge tone="plain">{`${number(chats?.length)} active sessions`}</Badge></PageHead>
    <ErrorNote error={error} />
    <Stats cols={3}>
      <Stat label="Active Chat Sessions" value={number(chats?.length)} icon={MessageSquare} sub="ongoing consultations right now" />
      <Stat label="Active Voice Calls" value={number(calls?.length)} icon={PhoneCall} tone="green" sub={`${number(calls?.filter((c) => c.status === 'ringing').length)} ringing · ${number(calls?.filter((c) => c.status === 'answered').length)} connected`} />
      <Stat label="Trial Chats Running" value={number(chats?.filter((c) => c.isTrial).length)} icon={Hourglass} tone="amber" sub="free 1-minute chats" />
    </Stats>
    <Card title="Live consultation sessions" desc="Click a session to follow its transcript live.">
      <Table rows={chats} empty="No chats are ongoing right now." onRow={(r) => setOpenId(r.id)} columns={[...requestColumns(true).filter((c) => !['Category', 'Status'].includes(c.label)), actions]} />
    </Card>
    <Card title="Active voice calls" desc="Ringing and connected calls. Ending a call here stops it on both phones.">
      <Table rows={calls} empty="No calls right now." columns={callColumns(true, (c) => post(`/api/admin/calls/${c.id}/end`, null, `End the call between ${c.callerName} and ${c.receiverName}?`)).map((col) => col.label === 'Duration' ? { ...col, render: (c) => c.status === 'answered' ? duration(c.durationSeconds) : 'ringing…' } : col)} />
    </Card>
    {openId && <RequestDetail id={openId} onClose={() => setOpenId(null)} />}
  </>;
}
