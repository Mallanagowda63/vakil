const tabs = [...document.querySelectorAll('.tab')];
const forms = { signin: document.querySelector('#signinForm'), register: document.querySelector('#registerForm') };
const title = document.querySelector('#pageTitle');
const subtitle = document.querySelector('#pageSubtitle');
const toast = document.querySelector('#toast');

function switchPanel(panel) {
  tabs.forEach(tab => {
    const active = tab.dataset.panel === panel;
    tab.classList.toggle('active', active);
    tab.setAttribute('aria-selected', active);
  });
  Object.entries(forms).forEach(([key, form]) => form.classList.toggle('active', key === panel));
  title.textContent = panel === 'signin' ? 'Admin Access' : 'Admin Registration';
  subtitle.textContent = panel === 'signin' ? 'Sign in to manage your platform resources.' : 'Create your administrator identity credential.';
  history.replaceState(null, '', panel === 'register' ? '#register' : '#signin');
}

tabs.forEach(tab => tab.addEventListener('click', () => switchPanel(tab.dataset.panel)));
document.querySelector('[data-go-signin]').addEventListener('click', () => switchPanel('signin'));

document.querySelectorAll('.reveal').forEach(button => button.addEventListener('click', () => {
  const input = button.previousElementSibling;
  input.type = input.type === 'password' ? 'text' : 'password';
  button.textContent = input.type === 'password' ? '◉' : '⊘';
  button.setAttribute('aria-label', input.type === 'password' ? 'Show password' : 'Hide password');
}));

const otpInputs = [...document.querySelectorAll('.otp-row input')];
otpInputs.forEach((input, index) => {
  input.addEventListener('input', () => {
    input.value = input.value.replace(/\D/g, '').slice(0, 1);
    if (input.value && otpInputs[index + 1]) otpInputs[index + 1].focus();
  });
  input.addEventListener('keydown', event => {
    if (event.key === 'Backspace' && !input.value && otpInputs[index - 1]) otpInputs[index - 1].focus();
  });
  input.addEventListener('paste', event => {
    event.preventDefault();
    const digits = event.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    digits.split('').forEach((digit, i) => { if (otpInputs[index + i]) otpInputs[index + i].value = digit; });
    otpInputs[Math.min(index + digits.length, 5)].focus();
  });
});

document.querySelectorAll('.role').forEach(role => role.addEventListener('click', () => {
  document.querySelectorAll('.role').forEach(item => item.classList.remove('selected'));
  role.classList.add('selected');
}));

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove('show'), 3000);
}

forms.signin.addEventListener('submit', event => {
  event.preventDefault();
  const error = document.querySelector('#signinError');
  const code = otpInputs.map(input => input.value).join('');
  if (!forms.signin.checkValidity()) { error.textContent = 'Enter a valid email address and password.'; return; }
  if (!/^\d{6}$/.test(code)) { error.textContent = 'Enter the complete 6-digit authentication code.'; return; }
  error.textContent = '';
  showToast('Identity verified. Signing you in securely…');
  localStorage.setItem('vakilAdminSession', JSON.stringify({ email: document.querySelector('#loginEmail').value, signedInAt: Date.now() }));
  setTimeout(() => { window.location.href = 'app.html'; }, 700);
});

forms.register.addEventListener('submit', event => {
  event.preventDefault();
  const data = new FormData(forms.register);
  const error = document.querySelector('#registerError');
  if (!forms.register.checkValidity()) { error.textContent = 'Complete all fields and accept mandatory audit logging.'; return; }
  if (data.get('password') !== data.get('confirm')) { error.textContent = 'Passwords do not match.'; return; }
  error.textContent = '';
  showToast(`Admin account created for ${data.get('name')}. Signing you in…`);
  localStorage.setItem('vakilAdminSession', JSON.stringify({ email: data.get('email'), name: data.get('name'), signedInAt: Date.now() }));
  setTimeout(() => { window.location.href = 'app.html'; }, 900);
});

document.querySelector('#backupBtn').addEventListener('click', () => showToast('Backup code entry enabled. Enter your 10-character recovery code.'));
document.querySelector('#historyBtn').addEventListener('click', () => showToast('Login history is up to date.'));
document.querySelector('#forgotLink').addEventListener('click', event => { event.preventDefault(); showToast('Password recovery instructions sent to your work email.'); });

switchPanel(location.hash === '#register' ? 'register' : 'signin');
