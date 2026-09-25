import { Router } from 'express';
import express from 'express';
import crypto from 'node:crypto';
import path from 'node:path';
import { mkdir, unlink, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { getDb } from '../db.js';
import { requireAuth } from './auth.js';

export const profileRouter = Router();

// Profile photos live on disk and are served at /uploads/avatars/<file>. The
// stored photoUrl is that path, so the apps can reach it at whatever address
// they found the server on.
export const uploadsDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../uploads');
const avatarsDir = path.join(uploadsDir, 'avatars');
const imageTypes = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };

const collectionOf = (req) => req.auth.role === 'lawyer' ? 'lawyers' : 'users';
const text = (v, max = 120) => String(v ?? '').trim().slice(0, max);

// What both apps show on their Profile / Settings screens: the details given at
// registration plus the photo. A lawyer's registration adds practice details.
export function profileView(account, role) {
  const p = account.profile || {}; const reg = account.registration || {};
  const base = { id: account._id.toString(), role, phone: account.phone || null, fullName: p.fullName || reg.personal?.fullName || '', email: p.email || reg.personal?.email || '', gender: p.gender || reg.personal?.gender || '', photoUrl: p.photoUrl || null };
  if (role !== 'lawyer') return { ...base, language: p.language || '', aadhaar: p.aadhaar || '', sosContact: p.sosContact || '' };
  const a = reg.advocate || {};
  return {
    ...base, dateOfBirth: reg.personal?.dateOfBirth || '', bio: p.bio || '',
    barCouncilRegNo: a.barCouncilRegNo || '', practiceArea: a.practiceArea || (account.categories || [])[0] || '', city: p.city || a.city || '', court: a.court || '', languages: p.languages || a.languages || '',
    categories: account.categories || [], verificationStatus: account.approved ? 'approved' : account.verificationStatus || 'not_submitted',
  };
}

// Consultations keep a copy of both names and photos (chat lists, requests,
// Admin Panel); keep them in step with the profile so both sides see the same.
async function syncConsultations(role, id, fields) {
  const prefix = role === 'lawyer' ? 'lawyer' : 'user';
  const set = {};
  if ('fullName' in fields) set[`${prefix}Name`] = fields.fullName;
  if ('photoUrl' in fields) set[`${prefix}PhotoUrl`] = fields.photoUrl;
  if (Object.keys(set).length) await getDb().collection('consultation_requests').updateMany({ [`${prefix}Id`]: id }, { $set: set });
}

// Sets fields inside `profile`, which is null until the first save.
async function setProfile(req, fields) {
  const col = getDb().collection(collectionOf(req));
  const current = (await col.findOne({ _id: req.user._id }))?.profile || {};
  const profile = { ...current, ...fields, updatedAt: new Date() };
  await col.updateOne({ _id: req.user._id }, { $set: { profile } });
  await syncConsultations(req.auth.role, req.user._id, fields);
  return col.findOne({ _id: req.user._id });
}

profileRouter.get('/', requireAuth, (req, res) => res.json({ profile: profileView(req.user, req.auth.role) }));

// POST /api/profile — the User App's "Create profile" step (all fields required).
profileRouter.post('/', requireAuth, async (req, res) => {
  const { fullName, language, gender, aadhaar, email, sosContact } = req.body;
  if (!fullName || !gender || !aadhaar || !email) return res.status(400).json({ error: 'Missing required profile fields' });
  const account = await setProfile(req, { fullName: text(fullName), language: text(language), gender: text(gender, 20), aadhaar: text(aadhaar, 20), email: text(email), sosContact: text(sosContact) });
  res.json({ profile: account.profile, view: profileView(account, req.auth.role) });
});

// PATCH /api/profile — edits from the Profile / Settings screens (either app).
// Only the fields sent change; the name can't be blanked.
const editable = { user: ['fullName', 'language', 'gender', 'aadhaar', 'email', 'sosContact'], lawyer: ['fullName', 'email', 'gender', 'bio', 'city', 'languages'] };
profileRouter.patch('/', requireAuth, async (req, res) => {
  const fields = {};
  for (const key of editable[req.auth.role] || []) if (key in req.body) fields[key] = text(req.body[key], key === 'bio' ? 1000 : 120);
  if ('fullName' in fields && !fields.fullName) return res.status(400).json({ error: 'Name cannot be empty' });
  if ('email' in fields && fields.email && !/^\S+@\S+\.\S+$/.test(fields.email)) return res.status(400).json({ error: 'Enter a valid email address' });
  if ('aadhaar' in fields && fields.aadhaar && fields.aadhaar.replace(/\s/g, '').length !== 12) return res.status(400).json({ error: 'Aadhaar number must have 12 digits' });
  const account = await setProfile(req, fields);
  // A lawyer's registration holds the name the Admin Panel verifies; keep it the same.
  if (req.auth.role === 'lawyer' && account.registration?.personal && ('fullName' in fields || 'email' in fields)) {
    const personal = { ...account.registration.personal, ...('fullName' in fields ? { fullName: fields.fullName } : {}), ...('email' in fields ? { email: fields.email } : {}) };
    await getDb().collection('lawyers').updateOne({ _id: account._id }, { $set: { registration: { ...account.registration, personal } } });
    account.registration.personal = personal;
  }
  res.json({ profile: profileView(account, req.auth.role) });
});

// POST /api/profile/photo { image: <base64>, contentType } — replaces the photo.
// DELETE /api/profile/photo removes it (initials are shown instead).
profileRouter.post('/photo', express.json({ limit: '8mb' }), requireAuth, async (req, res) => {
  const ext = imageTypes[req.body.contentType] || 'jpg';
  let bytes;
  try { bytes = Buffer.from(String(req.body.image || ''), 'base64'); } catch { bytes = Buffer.alloc(0); }
  if (bytes.length < 100) return res.status(400).json({ error: 'Choose a photo to upload' });
  if (bytes.length > 5 * 1024 * 1024) return res.status(413).json({ error: 'The photo is too large (5 MB at most)' });
  await mkdir(avatarsDir, { recursive: true });
  const file = `${req.auth.role}-${req.user._id}-${crypto.randomBytes(4).toString('hex')}.${ext}`;
  await writeFile(path.join(avatarsDir, file), bytes);
  const previous = req.user.profile?.photoUrl;
  const account = await setProfile(req, { photoUrl: `/uploads/avatars/${file}` });
  if (previous?.startsWith('/uploads/avatars/')) unlink(path.join(avatarsDir, path.basename(previous))).catch(() => {});
  res.json({ photoUrl: account.profile.photoUrl, profile: profileView(account, req.auth.role) });
});

profileRouter.delete('/photo', requireAuth, async (req, res) => {
  const previous = req.user.profile?.photoUrl;
  const account = await setProfile(req, { photoUrl: null });
  if (previous?.startsWith('/uploads/avatars/')) unlink(path.join(avatarsDir, path.basename(previous))).catch(() => {});
  res.json({ photoUrl: null, profile: profileView(account, req.auth.role) });
});
