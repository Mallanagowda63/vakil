import crypto from 'node:crypto';
import { getDb } from '../db.js';
import { mailConfigured, sendBarVerificationEmail } from './mailer.js';

// Partner onboarding, Advocate Verification step: the lawyer taps "Verify" next
// to the Bar Council registration number and gets a 6-digit code by email
// (the email from the Personal Details step). Entering it marks that number as
// verified for that email; registration records whether it was. Works before
// sign-in, so it has the same limits as sign-in codes: 30 s between codes, 5
// tries, 10 minutes.

const fail = (status, message) => Object.assign(new Error(message), { status });
const col = () => getDb().collection('bar_verifications');
const isEmail = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
/** "dl-12345 / 2023" and "DL-12345/2023" are the same number. */
export const normalizeBarNumber = (v) => String(v || '').toUpperCase().replace(/\s+/g, '').slice(0, 60);
const hash = (email, number, code) => crypto.createHmac('sha256', process.env.JWT_SECRET).update(`bar:${email}:${number}:${code}`).digest('hex');

function clean(email, barCouncilRegNo) {
  const mail = String(email || '').trim().toLowerCase();
  const number = normalizeBarNumber(barCouncilRegNo);
  if (!isEmail(mail)) throw fail(400, 'Add your email in Personal Details first');
  if (number.length < 3) throw fail(400, 'Enter your Bar Council registration number');
  return { email: mail, number };
}

export async function sendBarCode({ email, barCouncilRegNo }) {
  const { email: mail, number } = clean(email, barCouncilRegNo);
  const devMode = process.env.OTP_DEV_MODE === 'true';
  if (!mailConfigured() && !devMode) throw fail(503, 'Email verification is not available right now');
  const now = new Date();
  if (await col().findOne({ email: mail, verifiedAt: null, createdAt: { $gt: new Date(now - 30000) } })) throw fail(429, 'Please wait 30 seconds before requesting a new code');
  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  await col().deleteMany({ email: mail, verifiedAt: null });
  await col().insertOne({ email: mail, number, codeHash: hash(mail, number, code), attempts: 0, verifiedAt: null, createdAt: now, expiresAt: new Date(now.getTime() + 10 * 60000) });
  if (mailConfigured()) {
    try { await sendBarVerificationEmail(mail, code, String(barCouncilRegNo).trim()); }
    catch (error) { console.error('Bar verification email failed:', error.message); await col().deleteMany({ email: mail, verifiedAt: null }); throw fail(502, 'Could not send the email. Check the address and try again.'); }
    return { ok: true, email: mail, expiresInSeconds: 600, resendInSeconds: 30 };
  }
  // Development without email: the code is printed here and returned to debug builds.
  console.log(`[BAR VERIFY] ${mail} ${number} code ${code}`);
  return { ok: true, email: mail, expiresInSeconds: 600, resendInSeconds: 30, devCode: code };
}

export async function checkBarCode({ email, barCouncilRegNo, code }) {
  const { email: mail, number } = clean(email, barCouncilRegNo);
  const pending = await col().findOne({ email: mail, number, verifiedAt: null });
  if (!pending || new Date(pending.expiresAt) < new Date()) throw fail(400, 'The code has expired. Tap Verify to get a new one.');
  if (pending.attempts >= 5) throw fail(429, 'Too many attempts. Tap Verify to get a new code.');
  if (hash(mail, number, String(code || '').trim()) !== pending.codeHash) {
    await col().updateOne({ _id: pending._id }, { $inc: { attempts: 1 } });
    throw fail(400, 'That code is not right. Check the email and try again.');
  }
  await col().updateOne({ _id: pending._id }, { $set: { verifiedAt: new Date() } });
  return { verified: true, barCouncilRegNo: number };
}

/** When this email verified this number (for the registration record), or null. */
export async function barVerifiedAt(email, barCouncilRegNo) {
  const found = await col().findOne({ email: String(email || '').toLowerCase(), number: normalizeBarNumber(barCouncilRegNo), verifiedAt: { $ne: null } });
  return found?.verifiedAt || null;
}
