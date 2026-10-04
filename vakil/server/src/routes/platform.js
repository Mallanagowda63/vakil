import express, { Router } from 'express';
import { getDb } from '../db.js';
import { requireAuth, roles } from './auth.js';
import { lawyerStatus, statusRank } from '../services/consultations.js';
import { callRateOf, rateOf, round2 } from '../services/wallet.js';
import { announceLawyer, emitAdmin } from '../realtime.js';
import { earningsSummary, requestPayout } from '../services/earnings.js';
import { MAX_DOCUMENT_BYTES, documentKinds, documentTypes, saveDocument } from '../services/lawyerDocuments.js';

export const platformRouter = Router();

platformRouter.post('/devices', requireAuth, async (req, res) => {
  if (!req.body.token) return res.status(400).json({ error: 'token is required' });
  const collection = req.auth.role === 'lawyer' ? 'lawyers' : 'users';
  await getDb().collection(collection).updateOne({ _id: req.user._id }, { $addToSet: { fcmTokens: req.body.token } });
  res.status(204).end();
});

// The lawyer's "Chat available" / "Call available" switches (Partner App home).
// { online: false } (sign-out, old app versions) turns both off.
const switchesOf = (l) => ({ isChatOnline: Boolean(l.isChatOnline ?? l.online), isCallOnline: Boolean(l.isCallOnline ?? l.online) });
platformRouter.get('/lawyers/me/presence', ...roles('lawyer'), async (req, res) => {
  const lawyer = await getDb().collection('lawyers').findOne({ _id: req.user._id });
  res.json({ ...switchesOf(lawyer), channels: { chat: lawyer.channels?.chat !== false, call: lawyer.channels?.call !== false }, approved: Boolean(lawyer.approved) });
});

platformRouter.patch('/lawyers/me/presence', ...roles('lawyer'), async (req, res) => {
  const current = switchesOf(req.user); const b = req.body;
  const next = 'online' in b && !('isChatOnline' in b) && !('isCallOnline' in b)
    ? { isChatOnline: Boolean(b.online), isCallOnline: Boolean(b.online) }
    : { isChatOnline: 'isChatOnline' in b ? Boolean(b.isChatOnline) : current.isChatOnline, isCallOnline: 'isCallOnline' in b ? Boolean(b.isCallOnline) : current.isCallOnline };
  await getDb().collection('lawyers').updateOne({ _id: req.user._id }, { $set: { ...next, online: next.isChatOnline || next.isCallOnline, lastSeenAt: new Date() } });
  await announceLawyer(req.user._id);
  res.json({ ...next, online: next.isChatOnline || next.isCallOnline });
});

// Partner App home + wallet: today's consultations, earnings, minutes, missed; balance; recent entries.
platformRouter.get('/lawyers/me/earnings', ...roles('lawyer'), async (req, res) => res.json(await earningsSummary(req.user._id)));
// "Withdraw": queues the available balance as a payout for the admin.
platformRouter.post('/lawyers/me/payouts', ...roles('lawyer'), async (req, res) => {
  try { res.status(201).json(await requestPayout(req.user._id)); }
  catch (e) { if (!e.status) throw e; res.status(e.status).json({ error: e.message }); }
});

// Users see name, photo, price, rating, experience and availability only; never the lawyer's phone number.
export async function lawyerCards(lawyers) {
  const [callRate, ratings, done] = [await callRateOf(), await ratingsByLawyer(), await consultationsDone()];
  return Promise.all(lawyers.map(async (l) => ({ ...lawyerStatus(l), name: l.profile?.fullName || l.registration?.personal?.fullName || 'Lawyer', photoUrl: l.profile?.photoUrl || null, categories: l.categories || [], ratePerMinute: await rateOf(l), callRatePerMinute: callRate, bio: l.profile?.bio || '', city: l.profile?.city || l.registration?.advocate?.city || '', languages: l.profile?.languages || l.registration?.advocate?.languages || '', experienceYears: l.profile?.experienceYears ?? null, consultationsDone: done.get(l._id.toString()) || 0, ...(ratings.get(l._id.toString()) || { ratingAverage: null, ratingCount: 0 }) })));
}

export const listedLawyers = (filter = {}) => getDb().collection('lawyers').find({ approved: true, blocked: { $ne: true }, ...filter }).toArray();

platformRouter.get('/lawyers', requireAuth, async (req, res) => {
  let items = await lawyerCards(await listedLawyers(req.query.category ? { categories: req.query.category } : {}));
  if (req.query.online === 'true') items = items.filter((l) => l.online);
  // Chat + call first, then chat or call only, then offline.
  items.sort((a, b) => statusRank(b) - statusRank(a) || a.name.localeCompare(b.name));
  res.json({ items });
});


// POST /api/lawyers/me/documents { kind: 'face' | 'license', file: <base64>, contentType, fileName }
// The verification documents the Admin Panel checks before approving.
platformRouter.post('/lawyers/me/documents', express.json({ limit: '8mb' }), ...roles('lawyer'), async (req, res) => {
  const { kind, contentType } = req.body;
  if (!documentKinds[kind]) return res.status(400).json({ error: 'Unknown document' });
  if (!documentTypes[contentType]) return res.status(400).json({ error: 'Upload a JPG, PNG or PDF file' });
  let bytes;
  try { bytes = Buffer.from(String(req.body.file || ''), 'base64'); } catch { bytes = Buffer.alloc(0); }
  if (bytes.length < 100) return res.status(400).json({ error: 'Choose a file to upload' });
  if (bytes.length > MAX_DOCUMENT_BYTES) return res.status(413).json({ error: 'The file is too large (5 MB at most)' });
  const document = await saveDocument({ lawyerId: req.user._id, kind, bytes, contentType, fileName: req.body.fileName });
  emitAdmin('lawyer_status_changed', { id: req.user._id.toString() });
  res.status(201).json({ document });
});

// Partner App registration (Review & Submit): personal, advocate and bank
// details go to the Admin Panel for verification. Files are not uploaded yet;
// only whether a licence file was attached.
platformRouter.post('/lawyers/me/registration', ...roles('lawyer'), async (req, res) => {
  const text = (v, max = 120) => String(v ?? '').trim().slice(0, max);
  const { personal = {}, advocate = {}, bank = {} } = req.body;
  if (!text(personal.fullName) || !text(advocate.barCouncilRegNo)) return res.status(400).json({ error: 'Full name and Bar Council registration number are required' });
  // Filled in before sign-in on this phone: it must belong to the email that signed in.
  const email = text(personal.email).toLowerCase();
  if (email && req.user.email && email !== req.user.email) return res.status(409).json({ error: 'This registration was filled in for a different email address' });
  // The mobile number becomes the lawyer's contact number unless another account has it.
  const digits = String(personal.mobile || '').replace(/\D/g, '').slice(-10);
  const phone = /^[6-9]\d{9}$/.test(digits) && !req.user.phone && !(await getDb().collection('lawyers').findOne({ phone: `+91${digits}` })) ? `+91${digits}` : null;
  const registration = {
    personal: { fullName: text(personal.fullName), email: req.user.email || email, dateOfBirth: text(personal.dateOfBirth, 20), gender: text(personal.gender, 20), faceVerified: Boolean(personal.faceVerified) },
    advocate: { barCouncilRegNo: text(advocate.barCouncilRegNo, 60), practiceArea: text(advocate.practiceArea), city: text(advocate.city), court: text(advocate.court), languages: text(advocate.languages), licenseFileName: text(advocate.licenseFileName, 200) || null },
    bank: { holderName: text(bank.holderName), ifsc: text(bank.ifsc, 20).toUpperCase(), accountNumber: text(bank.accountNumber, 30).replace(/\s/g, ''), upi: text(bank.upi, 80) },
    submittedAt: new Date(),
  };
  // `profile` is null until the first save, so it is written whole.
  const lawyer = req.user; const set = { registration, ...(phone ? { phone } : {}), profile: { ...(lawyer.profile || {}), fullName: registration.personal.fullName, email: registration.personal.email, ...(registration.personal.gender ? { gender: registration.personal.gender } : {}), updatedAt: new Date() } };
  // A new or corrected registration goes (back) to the Admin Panel's verification queue.
  if (!lawyer.approved && !lawyer.blocked) Object.assign(set, { verificationStatus: 'under_review', rejectionReason: null });
  if (registration.advocate.practiceArea && !(lawyer.categories || []).includes(registration.advocate.practiceArea)) set.categories = [registration.advocate.practiceArea, ...(lawyer.categories || [])];
  await getDb().collection('lawyers').updateOne({ _id: lawyer._id }, { $set: set });
  await getDb().collection('consultation_requests').updateMany({ lawyerId: lawyer._id }, { $set: { lawyerName: registration.personal.fullName } });
  emitAdmin('lawyer_status_changed', { id: lawyer._id.toString() });
  res.json({ ok: true, verificationStatus: lawyer.approved ? 'approved' : 'under_review' });
});

// A lawyer sets their own per-minute price, within the admin's minimum and maximum (Pricing).
platformRouter.patch('/lawyers/me/rate', ...roles('lawyer'), async (req, res) => {
  const rate = round2(req.body.ratePerMinute);
  const pricing = (await getDb().collection('settings').findOne({ key: 'pricing' }))?.value || {};
  const min = pricing.minPerMinute ?? 10; const max = pricing.maxPerMinute ?? 45;
  if (!Number.isFinite(rate) || rate < min || rate > max) return res.status(400).json({ error: `Choose a rate between ₹${min} and ₹${max} per minute` });
  await getDb().collection('lawyers').updateOne({ _id: req.user._id }, { $set: { ratePerMinute: rate } });
  res.json({ ratePerMinute: rate });
});

// Average of the clients' published (not hidden) ratings, per lawyer id.
// Finished consultations per lawyer on Vakil.
async function consultationsDone() {
  const rows = await getDb().collection('consultation_requests').aggregate([{ $match: { status: 'COMPLETED' } }, { $group: { _id: '$lawyerId', count: { $sum: 1 } } }]).toArray();
  return new Map(rows.map((r) => [String(r._id), r.count]));
}

async function ratingsByLawyer() {
  const out = new Map();
  for (const r of await getDb().collection('reviews').find({}).toArray()) {
    if (r.hidden || !r.lawyerId) continue;
    const key = r.lawyerId.toString(); const row = out.get(key) || { total: 0, ratingCount: 0 };
    row.total += Number(r.rating) || 0; row.ratingCount += 1; out.set(key, row);
  }
  for (const [key, row] of out) out.set(key, { ratingAverage: Math.round(row.total / row.ratingCount * 10) / 10, ratingCount: row.ratingCount });
  return out;
}
