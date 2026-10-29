import nodemailer from 'nodemailer';

// Sign-in codes go out through Resend's HTTPS API (RESEND_API_KEY + MAIL_FROM on a
// verified domain) — Render's free plan blocks SMTP ports. Otherwise any SMTP service
// (Brevo, Gmail, …) via SMTP_HOST / SMTP_PORT / SMTP_USER / SMTP_PASS / MAIL_FROM.
let transport;

const resendKey = () => process.env.RESEND_API_KEY;
export const mailConfigured = () => Boolean(resendKey() || (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS));

async function sendViaResend(mail) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendKey()}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(mail),
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}: ${await res.text()}`);
}

function transporter() {
  const port = Number(process.env.SMTP_PORT || 587);
  transport ??= nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: process.env.SMTP_SECURE ? process.env.SMTP_SECURE === 'true' : port === 465,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  return transport;
}

const deliver = async (mail) => { if (resendKey()) return sendViaResend(mail); await transporter().sendMail(mail); };
const escapeHtml = (v) => String(v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

/** Partner onboarding: confirms the Bar Council registration number with a 6-digit code. */
export async function sendBarVerificationEmail(to, code, barCouncilRegNo) {
  const app = 'Legally Talk Partner'; const number = escapeHtml(barCouncilRegNo);
  await deliver({
    from: process.env.MAIL_FROM || `${app} <${process.env.SMTP_USER}>`,
    to,
    subject: `${code} – verify your Bar Council registration number`,
    text: `You entered Bar Council registration number ${barCouncilRegNo} in ${app}.\n\nYour verification code is ${code}. Enter it in the app to verify the number and continue your onboarding.\n\nThe code expires in 10 minutes. If you did not start registering with ${app}, you can ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:460px;margin:auto;padding:24px;color:#111">
  <h2 style="margin:0 0 12px">Verify your Bar Council number</h2>
  <p style="margin:0 0 8px">You entered this Bar Council registration number in ${app}:</p>
  <p style="font-size:18px;font-weight:700;margin:0 0 18px;padding:10px 14px;background:#f1f4fb;border-radius:8px;display:inline-block">${number}</p>
  <p style="margin:0 0 8px">Enter this code in the app to verify it and continue your onboarding:</p>
  <p style="font-size:32px;font-weight:700;letter-spacing:8px;margin:0 0 18px">${code}</p>
  <p style="color:#666;font-size:13px;margin:0 0 6px">The code expires in 10 minutes.</p>
  <p style="color:#666;font-size:13px;margin:0">If you did not start registering with ${app}, you can ignore this email. The Vakil team also checks every number against your licence before approving your account.</p>
</div>`,
  });
}

export async function sendOtpEmail(to, code, role) {
  const app = role === 'lawyer' ? 'Legally Talk Partner' : role === 'admin' ? 'Legally Talk Admin' : 'Legally Talk';
  const mail = {
    from: process.env.MAIL_FROM || `${app} <${process.env.SMTP_USER}>`,
    to,
    subject: `${code} is your ${app} sign-in code`,
    text: `Your ${app} sign-in code is ${code}.\n\nIt expires in 5 minutes. If you did not try to sign in, you can ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px;margin:auto;padding:24px;color:#111">
  <h2 style="margin:0 0 12px">${app} sign-in</h2>
  <p style="margin:0 0 16px">Use this code to sign in:</p>
  <p style="font-size:32px;font-weight:700;letter-spacing:8px;margin:0 0 16px">${code}</p>
  <p style="color:#666;font-size:13px;margin:0">It expires in 5 minutes. If you did not try to sign in, you can ignore this email.</p>
</div>`,
  };
  await deliver(mail);
}
