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
  if (resendKey()) return sendViaResend(mail);
  await transporter().sendMail(mail);
}
