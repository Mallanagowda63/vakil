import { Router } from 'express';
import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { ObjectId } from 'mongodb';
import { getDb } from '../db.js';

export const authRouter = Router();
export const secret = () => {
  if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET is not set (check server/.env)');
  return process.env.JWT_SECRET;
};
// Last 10 digits of an Indian mobile number, stored with its country code.
const localDigits = (phone) => String(phone || '').replace(/[^\d]/g, '').slice(-10);
const toE164 = (phone) => `+91${localDigits(phone)}`;
const publicUser = (user) => ({ id: user._id.toString(), phone: user.phone, role: user.role || 'user', profileComplete: Boolean(user.profile?.fullName), trialUsed: Boolean(user.trialUsed), walletBalance: Math.round((user.walletBalance || 0) * 100) / 100, profile: user.profile || null });
const otpHash = (phone, role, code) => crypto.createHmac('sha256', secret()).update(`${role}:${phone}:${code}`).digest('hex');

// Finds or creates the account for a verified phone number and issues a JWT.
async function signIn(rawPhone, role) {
  const phone = toE164(rawPhone); const now = new Date();
  const collection = getDb().collection(role === 'lawyer' ? 'lawyers' : 'users');
  // Accounts created before country codes were stored keep their history.
  await collection.updateOne({ phone: localDigits(rawPhone) }, { $set: { phone } }).catch(() => {});
  const devLawyer = role === 'lawyer' && process.env.DEV_AUTO_APPROVE_LAWYERS === 'true';
  await collection.updateOne({ phone }, { $set: { phone, role, lastLoginAt: now, ...(devLawyer ? { approved: true, online: true, categories: ['Corporate Law', 'Criminal Defense', 'Family Law', 'Employment Law', 'Real Estate Law', 'Property Law'] } : {}) }, $setOnInsert: { createdAt: now, trialUsed: false, profile: null, blocked: false, ...(role === 'user' ? { walletBalance: 0 } : {}) } }, { upsert: true });
  const user = await collection.findOne({ phone });
  if (user.blocked) throw Object.assign(new Error('This account has been blocked'), { status: 403 });
  return { token: jwt.sign({ sub: user._id.toString(), role }, secret(), { expiresIn: '30d' }), user: publicUser(user) };
}

// Step 1 of sign-in: send a 6-digit code. With OTP_DEV_MODE=true (no SMS
// provider yet) the code is printed in the server console and returned as devCode.
authRouter.post('/otp/request', async (req, res) => {
  const digits = localDigits(req.body.phone); const role = req.body.role === 'lawyer' ? 'lawyer' : 'user';
  if (!/^[6-9]\d{9}$/.test(digits)) return res.status(400).json({ error: 'Enter a valid 10-digit mobile number' });
  const devMode = process.env.OTP_DEV_MODE === 'true';
  if (!devMode) return res.status(503).json({ error: 'SMS verification is not available yet' });
  const phone = toE164(digits); const otps = getDb().collection('otps'); const now = new Date();
  if (await otps.findOne({ phone, role, createdAt: { $gt: new Date(now - 30000) } })) return res.status(429).json({ error: 'Please wait 30 seconds before requesting a new code' });
  // Testing: OTP_FIXED_CODE (e.g. 123456) is the code for every number, in both apps.
  const fixed = /^\d{6}$/.test(process.env.OTP_FIXED_CODE || '') ? process.env.OTP_FIXED_CODE : null;
  const code = fixed || String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  await otps.deleteMany({ phone, role });
  await otps.insertOne({ phone, role, codeHash: otpHash(phone, role, code), attempts: 0, createdAt: now, expiresAt: new Date(now.getTime() + 5 * 60000) });
  console.log(`[OTP] ${role} ${phone}: ${code}`);
  res.json({ ok: true, phone, expiresInSeconds: 300, resendInSeconds: 30, devCode: code });
});

// Step 2 of sign-in: check the code (5 attempts, 5 minutes) and log in.
authRouter.post('/otp/verify', async (req, res) => {
  const phone = toE164(req.body.phone); const role = req.body.role === 'lawyer' ? 'lawyer' : 'user';
  const code = String(req.body.code || '').trim(); const otps = getDb().collection('otps');
  const otp = await otps.findOne({ phone, role });
  if (!otp || new Date(otp.expiresAt) < new Date()) return res.status(400).json({ error: 'This code has expired. Please request a new one.' });
  if (otp.attempts >= 5) return res.status(429).json({ error: 'Too many attempts. Please request a new code.' });
  if (otpHash(phone, role, code) !== otp.codeHash) {
    await otps.updateOne({ _id: otp._id }, { $inc: { attempts: 1 } });
    return res.status(400).json({ error: 'Incorrect code. Please try again.' });
  }
  await otps.deleteOne({ _id: otp._id });
  try { res.json(await signIn(phone, role)); }
  catch (e) { if (!e.status) throw e; res.status(e.status).json({ error: e.message }); }
});

// Development-only login without OTP (test scripts, admin panel until Step 8).
authRouter.post('/login', async (req, res) => {
  if (process.env.ALLOW_DEV_LOGIN !== 'true') return res.status(404).json({ error: 'Not found' });
  const role = ['user', 'lawyer', 'admin'].includes(req.body.role) ? req.body.role : 'user';
  if (role === 'admin' && process.env.ADMIN_LOGIN_CODE && req.body.adminCode !== process.env.ADMIN_LOGIN_CODE) return res.status(403).json({ error: 'Invalid admin code' });
  if (localDigits(req.body.phone).length !== 10) return res.status(400).json({ error: 'Enter a valid 10-digit mobile number' });
  try { res.json(await signIn(req.body.phone, role)); }
  catch (e) { if (!e.status) throw e; res.status(e.status).json({ error: e.message }); }
});

export async function requireAuth(req, res, next) {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/, '');
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    const claims = jwt.verify(token, secret());
    const collection = claims.role === 'lawyer' ? 'lawyers' : 'users';
    const user = await getDb().collection(collection).findOne({ _id: new ObjectId(claims.sub) });
    if (!user || user.blocked) return res.status(403).json({ error: 'Account unavailable' });
    req.user = user; req.auth = claims; next();
  } catch {
    for (const previousSecret of (process.env.JWT_PREVIOUS_SECRETS || '').split(',').filter(Boolean)) {
      try {
        const claims = jwt.verify(token, previousSecret);
        const collection = claims.role === 'lawyer' ? 'lawyers' : 'users';
        const user = await getDb().collection(collection).findOne({ _id: new ObjectId(claims.sub) });
        if (!user || user.blocked) return res.status(403).json({ error: 'Account unavailable' });
        req.user = user;
        req.auth = { ...claims, legacy: true };
        return next();
      } catch {}
    }
    // One-time compatibility for sessions created before JWT migration.
    // The session endpoint returns a fresh JWT so updated clients replace it.
    const user = await getDb().collection('users').findOne({ token });
    if (user && !user.blocked) {
      req.user = user;
      req.auth = { sub: user._id.toString(), role: 'user', legacy: true };
      return next();
    }
    // Local-development-only migration for JWTs issued before the stable
    // secret was configured. Never enable this in production.
    const decoded = process.env.ALLOW_DEV_TOKEN_MIGRATION === 'true' ? jwt.decode(token) : null;
    if (decoded?.sub && ObjectId.isValid(decoded.sub) && decoded.role === 'user') {
      const _id = new ObjectId(decoded.sub);
      await getDb().collection('users').updateOne({ _id }, { $setOnInsert: { role: 'user', createdAt: new Date(), trialUsed: false, profile: null, blocked: false } }, { upsert: true });
      req.user = await getDb().collection('users').findOne({ _id });
      req.auth = { sub: decoded.sub, role: 'user', legacy: true };
      return next();
    }
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

export const roles = (...allowed) => [requireAuth, (req, res, next) => allowed.includes(req.auth.role) ? next() : res.status(403).json({ error: 'Forbidden' })];
authRouter.get('/session', requireAuth, (req, res) => {
  const replacementToken = req.auth.legacy ? jwt.sign({ sub: req.user._id.toString(), role: req.auth.role || 'user' }, secret(), { expiresIn: '30d' }) : undefined;
  res.json({ user: publicUser(req.user), ...(replacementToken ? { token: replacementToken } : {}) });
});
