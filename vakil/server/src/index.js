import 'dotenv/config';
import { initPush } from './push.js';
import cors from 'cors';
import express from 'express';
import http from 'node:http';
import os from 'node:os';
import Layer from 'express/lib/router/layer.js';
import { connectDb, isDbConnected } from './db.js';
import { authRouter } from './routes/auth.js';
import { profileRouter, uploadsDir } from './routes/profile.js';
import { trialRouter } from './routes/trial.js';
import { consultationRouter } from './routes/consultations.js';
import { platformRouter } from './routes/platform.js';
import { chatsRouter } from './routes/chats.js';
import { callsRouter } from './routes/calls.js';
import { walletRouter } from './routes/wallet.js';
import { adminRouter } from './routes/admin.js';
import { adminOpsRouter } from './routes/adminOps.js';
import { feedbackRouter } from './routes/feedback.js';
import { initRealtime, turnOffAwayLawyers } from './realtime.js';
import { endTimedOutChats, expirePending } from './services/consultations.js';
import { missUnansweredCalls } from './services/calls.js';
import { billOngoingChats } from './services/billing.js';

if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET is not set (check server/.env)');

// Express 4 ignores rejected promises from async handlers, and Node exits on
// unhandled rejections. Route them to the error middleware instead.
Layer.prototype.handle_request = function handle(req, res, next) {
  if (this.handle.length > 3) return next();
  try {
    const result = this.handle(req, res, next);
    if (result && typeof result.catch === 'function') result.catch(next);
  } catch (err) {
    next(err);
  }
};

const app = express();
app.use(cors({ origin: '*' }));
// Photo uploads bring their own, larger body limit (routes/profile.js).
const jsonBody = express.json();
app.use((req, res, next) => req.path === '/api/profile/photo' ? next() : jsonBody(req, res, next));
app.use('/uploads', express.static(uploadsDir, { maxAge: '7d', fallthrough: false }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));
// The apps remember `addresses` so they can still find this laptop over Wi-Fi after the USB cable is unplugged.
const lanAddresses = () => Object.values(os.networkInterfaces()).flat().filter((item) => item && item.family === 'IPv4' && !item.internal).map((item) => item.address);
app.get('/api/health', (_req, res) => res.json({ status: 'ok', service: 'vakil', addresses: lanAddresses() }));
app.get('/api/ready', (_req, res) => isDbConnected() ? res.json({ status: 'ready' }) : res.status(503).json({ status: 'starting' }));

app.use('/api', (req, res, next) => {
  if (!isDbConnected()) return res.status(503).json({ error: 'Server is starting, please try again in a moment' });
  next();
});

app.use('/api/auth', authRouter);
app.use('/api/profile', profileRouter);
app.use('/api/trial', trialRouter);
app.use('/api/consultations', consultationRouter);
app.use('/api/chats', chatsRouter);
app.use('/api/calls', callsRouter);
app.use('/api/wallet', walletRouter);
app.use('/api/admin', adminRouter);
app.use('/api/admin', adminOpsRouter);
app.use('/api/feedback', feedbackRouter);
app.use('/api', platformRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  if (res.headersSent) return;
  res.status(500).json({ error: 'Internal server error' });
});

process.on('unhandledRejection', (err) => console.error('Unhandled rejection:', err));

const port = process.env.PORT || 4000;
const server = http.createServer(app);
initRealtime(server);
initPush();

server.listen(port, '0.0.0.0', () => {
  console.log(`Vakil API listening on all network interfaces (port ${port})`);
  for (const address of lanAddresses()) console.log(`Server running at http://${address}:${port}`);
});

connectDb()
  .then(() => {
    console.log('MongoDB connected');
    setInterval(() => expirePending().catch(console.error), 1000).unref();
    setInterval(() => endTimedOutChats().catch(console.error), 1000).unref();
    setInterval(() => missUnansweredCalls().catch(console.error), 1000).unref();
    setInterval(() => billOngoingChats().catch(console.error), 1000).unref();
    setInterval(() => turnOffAwayLawyers().catch(console.error), 60000).unref();
  })
  .catch((err) => console.error('Failed to connect to MongoDB:', err.stack || err.message));
