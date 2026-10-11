const baseUrl = import.meta.env.VITE_API_URL;
if (!baseUrl) console.error('VITE_API_URL is not set. Copy admin/.env.example to admin/.env.');
export const token = () => localStorage.getItem('vakilAdminToken');

export const adminEmail = () => localStorage.getItem('vakilAdminEmail') || '';

// No token, or the server refused it (expired, or no longer an admin): back to the sign-in page.
function signOut() {
  localStorage.removeItem('vakilAdminToken'); localStorage.removeItem('vakilAdminEmail');
  if (!location.pathname.startsWith('/login')) location.assign('/login');
}

async function send(path, init) {
  if (!token()) { signOut(); throw new Error('Please sign in'); }
  const response = await fetch(`${baseUrl}${path}`, { ...init, headers: { ...init.headers, Authorization: `Bearer ${token()}` } });
  if (response.status === 401 || response.status === 403) {
    const body = await response.clone().json().catch(() => ({}));
    if (response.status === 401 || body.error === 'Account unavailable') { signOut(); throw new Error('Please sign in again'); }
  }
  return response;
}

export async function api(path, options = {}) {
  const response = await send(path, { ...options, headers: { 'Content-Type': 'application/json', ...options.headers } });
  // No JSON error: usually the server is restarting or waking up (free plan), or is an older version.
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || (response.status === 404 ? 'This feature is not on the server yet (it may still be deploying). Try again in a few minutes.' : `The server is not responding (${response.status}). It may be waking up; try again in a minute.`));
  return response.status === 204 ? null : response.json();
}

async function post(path, body) {
  const response = await fetch(`${baseUrl}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `The server is not responding (${response.status}). It may be waking up; try again in a minute.`);
  return data;
}

// Admin sign-in, step 1: email a 6-digit code (only emails in the server's ADMIN_EMAILS).
export const requestAdminCode = (email) => post('/api/auth/otp/request', { email, role: 'admin' });

// Step 2: check the code and keep the admin token.
export async function verifyAdminCode(email, code) {
  const data = await post('/api/auth/otp/verify', { email, code, role: 'admin' });
  localStorage.setItem('vakilAdminToken', data.token); localStorage.setItem('vakilAdminEmail', data.user.email || email);
  return data;
}
export function adminSignOut() { localStorage.removeItem('vakilAdminToken'); localStorage.removeItem('vakilAdminEmail'); }
export { baseUrl };

// Downloads a CSV export (needs the admin token, so not a plain link).
export async function download(path, filename) {
  const response = await send(path, { headers: {} });
  if (!response.ok) throw new Error('Export failed');
  const url = URL.createObjectURL(await response.blob());
  const link = Object.assign(document.createElement('a'), { href: url, download: filename });
  link.click(); URL.revokeObjectURL(url);
}

// A private file (e.g. a lawyer's verification document) as a temporary URL
// for <img>/<iframe>; the caller revokes it with URL.revokeObjectURL.
export async function fileUrl(path) {
  const response = await send(path, { headers: {} });
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || 'Could not load the file');
  return URL.createObjectURL(await response.blob());
}
