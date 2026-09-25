import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';
import { serialize } from './consultations.js';

// Shared by the admin routes: ids, dates, paging, joins and CSV.
export const toId = (value) => { try { return new ObjectId(value); } catch { return null; } };
export const idOf = (value) => value?.toString() ?? null;
export const seconds = (from, to) => from && to ? Math.max(0, Math.round((new Date(to) - new Date(from)) / 1000)) : null;
export const average = (values) => values.length ? Math.round(values.reduce((n, v) => n + v, 0) / values.length) : 0;
export const startOfToday = () => { const d = new Date(); d.setHours(0, 0, 0, 0); return d; };
export const nameOf = (account, fallback) => account?.profile?.fullName || fallback;
export const endedAtOf = (r) => r.completedAt || r.rejectedAt || r.expiredAt || r.cancelledAt || null;
export const activeCallStatuses = ['ringing', 'answered'];

// "2026-09-24" → local midnight; `to` includes the whole day.
export function dateRange(from, to) {
  const range = {};
  if (from && !Number.isNaN(Date.parse(from))) range.$gte = new Date(`${from}T00:00:00`);
  if (to && !Number.isNaN(Date.parse(to))) { const end = new Date(`${to}T00:00:00`); end.setDate(end.getDate() + 1); range.$lt = end; }
  return Object.keys(range).length ? range : null;
}

export function page(query, total) {
  const limit = Math.min(200, Math.max(1, Number(query.limit) || 25));
  const pages = Math.max(1, Math.ceil(total / limit));
  const current = Math.min(pages, Math.max(1, Number(query.page) || 1));
  return { limit, page: current, pages, skip: (current - 1) * limit };
}

export async function accountsById(collection, ids) {
  const unique = [...new Set(ids.filter(Boolean).map(String))].map(toId).filter(Boolean);
  const docs = unique.length ? await getDb().collection(collection).find({ _id: { $in: unique } }).toArray() : [];
  return new Map(docs.map((d) => [d._id.toString(), d]));
}

export async function countBy(collection, requestIds) {
  if (!requestIds.length) return new Map();
  const grouped = await getDb().collection(collection).aggregate([{ $match: { requestId: { $in: requestIds } } }, { $group: { _id: '$requestId', count: { $sum: 1 } } }]).toArray();
  return new Map(grouped.map((g) => [g._id.toString(), g.count]));
}

export const escapeRegex = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Requests matching the table's filters; `q` matches a user's or lawyer's name or phone.
export async function findRequests(query) {
  const db = getDb(); const filter = {};
  if (query.status) filter.status = String(query.status).toUpperCase();
  if (query.trial === 'yes') filter.isTrial = true;
  if (query.trial === 'no') filter.isTrial = { $ne: true };
  const created = dateRange(query.from, query.to); if (created) filter.createdAt = created;
  if (query.lawyerId && toId(query.lawyerId)) filter.lawyerId = toId(query.lawyerId);
  if (query.userId && toId(query.userId)) filter.userId = toId(query.userId);
  let rows = await db.collection('consultation_requests').find(filter).sort({ createdAt: -1 }).toArray();
  const [users, lawyers] = await Promise.all([accountsById('users', rows.map((r) => r.userId)), accountsById('lawyers', rows.map((r) => r.lawyerId))]);
  const q = String(query.q || '').trim();
  if (q) {
    const match = new RegExp(escapeRegex(q), 'i'); const digits = q.replace(/\D/g, '');
    const hit = (account, name) => match.test(name || '') || match.test(nameOf(account, '')) || (digits.length >= 3 && String(account?.phone || '').replace(/\D/g, '').includes(digits));
    rows = rows.filter((r) => hit(users.get(idOf(r.userId)), r.userName) || hit(lawyers.get(idOf(r.lawyerId)), r.lawyerName));
  }
  return { rows, users, lawyers };
}

export async function requestRows(rows, users, lawyers) {
  const ids = rows.map((r) => r._id);
  const [messages, calls] = await Promise.all([countBy('messages', ids), countBy('calls', ids)]);
  return rows.map((r) => {
    const view = serialize(r); const user = users.get(idOf(r.userId)); const lawyer = lawyers.get(idOf(r.lawyerId));
    return {
      id: view.id, userId: idOf(r.userId), lawyerId: idOf(r.lawyerId), userName: view.userName || nameOf(user, 'Client'), userPhone: user?.phone || null,
      lawyerName: view.lawyerName || nameOf(lawyer, 'Lawyer'), lawyerPhone: lawyer?.phone || null, category: r.category, isTrial: Boolean(r.isTrial), status: r.status,
      createdAt: r.createdAt, acceptedAt: r.acceptedAt || null, endedAt: endedAtOf(r), durationSeconds: r.durationSeconds ?? null, endedBy: r.endedBy || null,
      responseSeconds: seconds(r.createdAt, r.acceptedAt || r.rejectedAt), remainingSeconds: view.remainingSeconds ?? null, rating: r.rating ?? null,
      messageCount: messages.get(view.id) || 0, callCount: calls.get(view.id) || 0,
      ratePerMinute: r.ratePerMinute ?? null, billedMinutes: r.billedMinutes || 0, totalAmount: r.totalAmount ?? r.amount ?? 0, endReason: r.endReason || null,
    };
  });
}

export function sendCsv(res, filename, fields, rows) {
  const cell = (v) => `"${String(v instanceof Date ? v.toISOString() : v ?? '').replaceAll('"', '""')}"`;
  const csv = [fields.map(([label]) => cell(label)).join(','), ...rows.map((row) => fields.map(([, get]) => cell(get(row))).join(','))].join('\r\n');
  // BOM so Excel reads names in Indian scripts correctly.
  res.type('text/csv').attachment(filename).send(`﻿${csv}`);
}

export const requestCsvFields = [['Request ID', (r) => r.id], ['User', (r) => r.userName], ['User phone', (r) => r.userPhone], ['Lawyer', (r) => r.lawyerName], ['Lawyer phone', (r) => r.lawyerPhone], ['Category', (r) => r.category], ['Trial', (r) => r.isTrial ? 'yes' : 'no'], ['Status', (r) => r.status], ['Requested', (r) => r.createdAt], ['Accepted', (r) => r.acceptedAt], ['Ended', (r) => r.endedAt], ['Duration (s)', (r) => r.durationSeconds], ['Ended by', (r) => r.endedBy], ['Messages', (r) => r.messageCount], ['Calls', (r) => r.callCount], ['Rating', (r) => r.rating]];

