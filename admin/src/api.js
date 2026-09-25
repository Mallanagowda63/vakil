const baseUrl = import.meta.env.VITE_API_URL;
if (!baseUrl) console.error('VITE_API_URL is not set. Copy admin/.env.example to admin/.env.');
export const token = () => localStorage.getItem('vakilAdminToken');

// Development sign-in (no admin accounts yet). Parallel requests share one sign-in.
let signingIn = null;
function devSignIn() {
  signingIn ??= adminLogin('9999999999', '').finally(() => { signingIn = null; });
  return signingIn;
}

// A token from a reset database or an expired one gets 401/403: sign in again once and retry.
async function send(path, init) {
  if (!token()) await devSignIn();
  const request = () => fetch(`${baseUrl}${path}`, { ...init, headers: { ...init.headers, Authorization: `Bearer ${token()}` } });
  let response = await request();
  if (response.status === 401 || response.status === 403) {
    const body = await response.clone().json().catch(() => ({}));
    if (response.status === 401 || body.error === 'Account unavailable') {
      localStorage.removeItem('vakilAdminToken');
      await devSignIn();
      response = await request();
    }
  }
  return response;
}

export async function api(path, options = {}) {
  const response = await send(path, { ...options, headers: { 'Content-Type': 'application/json', ...options.headers } });
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || 'Request failed');
  return response.status === 204 ? null : response.json();
}

export async function adminLogin(phone, adminCode) {
  const response = await fetch(`${baseUrl}/api/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ phone, role: 'admin', adminCode }) });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || 'Admin sign-in failed');
  localStorage.setItem('vakilAdminToken', data.token); return data;
}
export { baseUrl };

// Downloads a CSV export (needs the admin token, so not a plain link).
export async function download(path, filename) {
  const response = await send(path, { headers: {} });
  if (!response.ok) throw new Error('Export failed');
  const url = URL.createObjectURL(await response.blob());
  const link = Object.assign(document.createElement('a'), { href: url, download: filename });
  link.click(); URL.revokeObjectURL(url);
}
