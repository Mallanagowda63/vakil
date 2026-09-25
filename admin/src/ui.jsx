import React, { useCallback, useEffect, useRef, useState } from 'react';
import { io } from 'socket.io-client';
import { Download, X, Info as InfoIcon } from 'lucide-react';
import { api, baseUrl, download, token } from './api.js';

// Shared pieces for every admin page (LegalDash design).

const liveEvents = ['status_updated', 'new_message', 'chat_ended', 'incoming_call', 'call_answered', 'call_rejected', 'call_missed', 'call_ended', 'user_online', 'user_offline', 'chat_billing', 'lawyer_status_changed'];

// Loads data, then reloads (debounced) whenever something changes on the server.
export function useLiveData(load, deps = [], { live = true } = {}) {
  const [data, setData] = useState(null); const [error, setError] = useState('');
  const loadRef = useRef(load); loadRef.current = load;
  const refresh = useCallback(() => loadRef.current().then((d) => { setData(d); setError(''); }).catch((e) => setError(e.message)), []);
  useEffect(() => { refresh(); }, deps); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (!live) return undefined;
    let socket; let timer; let alive = true;
    (token() ? Promise.resolve() : api('/api/admin/dashboard').catch(() => {})).then(() => {
      if (!alive) return;
      socket = io(baseUrl, { auth: { token: token() }, transports: ['websocket'] });
      const soon = () => { clearTimeout(timer); timer = setTimeout(() => loadRef.current().then(setData).catch(() => {}), 400); };
      liveEvents.forEach((e) => socket.on(e, soon));
    });
    return () => { alive = false; clearTimeout(timer); socket?.disconnect(); };
  }, [live]);
  return { data, error, refresh, setData };
}

// ---------------------------------------------------------------- formatting

export const money = (n) => `₹${Number(n || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
export const number = (n) => Number(n || 0).toLocaleString('en-IN');
export const dateTime = (v) => v ? new Date(v).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—';
export const dateOnly = (v) => v ? new Date(v).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
export const clock = (v) => v ? new Date(v).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : '';
export const duration = (s) => s === null || s === undefined ? '—' : `${Math.floor(s / 60)}m ${String(Math.round(s) % 60).padStart(2, '0')}s`;
export const ago = (v) => { if (!v) return 'never'; const s = Math.max(0, (Date.now() - new Date(v)) / 1000); return s < 60 ? 'just now' : s < 3600 ? `${Math.floor(s / 60)} min ago` : s < 86400 ? `${Math.floor(s / 3600)} h ago` : `${Math.floor(s / 86400)} d ago`; };
export const qs = (params) => new URLSearchParams(Object.entries(params).filter(([, v]) => v !== '' && v !== undefined && v !== null)).toString();
export const initials = (name = '') => name.split(' ').filter(Boolean).map((x) => x[0]).join('').slice(0, 2).toUpperCase() || '?';
export const label = (s = '') => String(s).replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase());

// ---------------------------------------------------------------- building blocks

const tones = { good: /^(completed|ongoing|approved|active|successful|paid|ended|answered|resolved|verified|enabled|online|settled|low|published|available)$/i, warn: /^(pending|ringing|under.review|processing|on.hold|in.progress|medium|awaiting|cancelled|review|credited)$/i, bad: /^(rejected|expired|failed|missed|suspended|blocked|high|escalated|open|flagged|hidden|reversed|disabled|refunded|offline)$/i };
export function Badge({ children, tone }) {
  const text = String(children ?? '');
  const t = tone || (tones.good.test(text) ? 'good' : tones.warn.test(text) ? 'warn' : tones.bad.test(text) ? 'bad' : 'plain');
  return <span className={`badge ${t}`}>{label(text)}</span>;
}

export function PageHead({ title, desc, children }) {
  return <div className="page-head"><div><h1>{title}</h1><p>{desc}</p></div>{children && <div className="ld-actions">{children}</div>}</div>;
}

export const SectionTitle = ({ children }) => <h2 className="ld-section">{children}</h2>;

export function Stat({ label: text, value, sub, icon: Icon, tone = 'blue', trend }) {
  return <article className="ld-stat"><div className="ld-stat-top"><span>{text}</span>{Icon && <i className={`ld-icon ${tone}`}><Icon size={14} /></i>}</div><strong>{value}</strong>{(sub || trend) && <small className={trend?.startsWith('↓') ? 'down' : trend ? 'up' : ''}>{trend ? `${trend} ` : ''}<em>{sub}</em></small>}</article>;
}
export const Stats = ({ children, cols = 4 }) => <div className={`ld-stats cols-${cols}`}>{children}</div>;

export function Card({ title, desc, actions, children, className = '' }) {
  return <section className={`card ${className}`}>{(title || actions) && <div className="card-head"><div>{title && <h3>{title}</h3>}{desc && <p>{desc}</p>}</div>{actions && <div className="ld-actions">{actions}</div>}</div>}{children}</section>;
}

export function Table({ columns, rows, empty = 'Nothing here yet.', onRow, rowKey = (r) => r.id }) {
  if (!rows) return <div className="no-results">Loading…</div>;
  if (!rows.length) return <div className="no-results">{empty}</div>;
  return <div className="table-wrap"><table><thead><tr>{columns.map((c) => <th key={c.key || c.label}>{c.label}</th>)}</tr></thead>
    <tbody>{rows.map((r, i) => <tr key={rowKey(r) ?? i} className={onRow ? 'ld-click' : ''} onClick={onRow ? () => onRow(r) : undefined}>{columns.map((c) => <td key={c.key || c.label}>{c.render ? c.render(r) : r[c.key] ?? '—'}</td>)}</tr>)}</tbody></table></div>;
}

export function Pager({ data, onPage }) {
  if (!data) return null;
  return <div className="ld-pager"><span>Showing {data.items?.length ?? 0} of {number(data.total)} results</span>{data.pages > 1 && <><button className="secondary" disabled={data.page <= 1} onClick={() => onPage(data.page - 1)}>Previous</button><button className="primary" disabled={data.page >= data.pages} onClick={() => onPage(data.page + 1)}>Next</button></>}</div>;
}

export const Note = ({ children, tone = 'info' }) => <div className={`ld-note ${tone}`}><InfoIcon size={14} /><div>{children}</div></div>;
export const ErrorNote = ({ error }) => error ? <Note tone="bad">Could not load data: {error}</Note> : null;

// Shown on money pages until the apps record payments.
export const NotChargingNote = () => <Note>No payments recorded yet. Money comes in when users recharge their wallets (Razorpay; a test recharge until the Razorpay keys are added) and is charged per minute during paid chats and calls. The figures below fill in by themselves.</Note>;

export const ExportButton = ({ path, name, label: text = 'Export CSV', primary = true }) => <button className={primary ? 'primary' : 'secondary'} onClick={() => download(path, name).catch((e) => alert(e.message))}><Download size={14} /> {text}</button>;

export function Drawer({ title, sub, onClose, actions, children }) {
  useEffect(() => { const esc = (e) => e.key === 'Escape' && onClose(); window.addEventListener('keydown', esc); return () => window.removeEventListener('keydown', esc); }, [onClose]);
  return <div className="ld-overlay" onClick={onClose}><aside className="ld-drawer" onClick={(e) => e.stopPropagation()}>
    <div className="card-head"><div><h3>{title}</h3>{sub && <p>{sub}</p>}</div><div className="ld-actions">{actions}<button className="secondary" onClick={onClose}><X size={13} /> Close</button></div></div>
    {children}
  </aside></div>;
}

export function Toggle({ checked, onChange, disabled }) {
  return <button type="button" role="switch" aria-checked={checked} disabled={disabled} className={`ld-toggle ${checked ? 'on' : ''}`} onClick={() => onChange(!checked)}><i /></button>;
}

export const Person = ({ name, sub, photo }) => <div className="person">{photo ? <img className="avatar" src={photo} alt="" /> : <span className="avatar light">{initials(name)}</span>}<span><b>{name}</b>{sub && <small>{sub}</small>}</span></div>;

export function Bars({ data, value, format = number, labelKey = 'label', height = 150 }) {
  const max = Math.max(1, ...data.map(value));
  const [active, setActive] = useState(null);
  return <div className="ld-bars" style={{ height }}>{data.map((d, i) => <div key={i} className={`ld-bar ${active === i ? 'on' : ''}`} onMouseEnter={() => setActive(i)} onMouseLeave={() => setActive(null)}>
    <span className="ld-tip">{d[labelKey]}<b>{format(value(d))}</b></span>
    <i style={{ height: `${Math.max(2, value(d) / max * 100)}%` }} /><small>{d[labelKey]}</small></div>)}</div>;
}

export function Progress({ items }) {
  return <div className="ld-progress">{items.map((x) => <div key={x.name}><span>{x.name}<b>{x.percent}%</b></span><i><b style={{ width: `${x.percent}%` }} /></i></div>)}</div>;
}

// Small form helpers for settings pages.
export function useForm(initial) {
  const [form, setForm] = useState(initial);
  useEffect(() => { setForm(initial); }, [initial]);
  return [form, (key) => (e) => setForm((f) => ({ ...f, [key]: e?.target ? (e.target.type === 'checkbox' ? e.target.checked : e.target.value) : e })), setForm];
}
