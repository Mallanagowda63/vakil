import admin from 'firebase-admin';
import { getDb } from './db.js';

function firebase() {
  if (admin.apps.length) return admin;
  if (!process.env.FIREBASE_SERVICE_ACCOUNT) return null;
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  return admin;
}

// Called at startup so a bad or missing key shows in the log right away.
export function initPush() {
  try {
    const sdk = firebase();
    console.log(sdk ? `Firebase Admin initialized (project ${sdk.app().options.credential.projectId})` : 'Firebase Admin not configured: pushes disabled (set FIREBASE_SERVICE_ACCOUNT)');
  } catch (error) {
    console.error('Firebase Admin failed to initialize:', error.message);
  }
}

// Android sound channels in the Partner App; the User App uses default notifications.
const channelSounds = { chat_requests: 'request_ring', chat_messages: 'message' };

export async function notify({ recipientId, recipientRole, title, body, data = {}, channel = null }) {
  const db = getDb();
  await db.collection('notifications').insertOne({ recipientId, recipientRole, title, body, data, read: false, createdAt: new Date() });
  const sdk = firebase();
  if (!sdk) return;
  const collection = recipientRole === 'lawyer' ? 'lawyers' : 'users';
  const recipient = await db.collection(collection).findOne({ _id: recipientId });
  if (!recipient?.fcmTokens?.length) return;
  const android = { priority: 'high', ...(channel ? { notification: { channelId: channel, sound: channelSounds[channel] } } : {}) };
  await sdk.messaging().sendEachForMulticast({ tokens: recipient.fcmTokens, notification: { title, body }, android, data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) });
}

// High-priority data-only message (no visible notification). The app wakes up
// and shows its own full-screen incoming-call UI (flutter_callkit_incoming).
export async function pushData({ recipientId, recipientRole, data, ttlSeconds = 30 }) {
  const sdk = firebase();
  if (!sdk) return;
  const recipient = await getDb().collection(recipientRole === 'lawyer' ? 'lawyers' : 'users').findOne({ _id: recipientId });
  if (!recipient?.fcmTokens?.length) return;
  await sdk.messaging().sendEachForMulticast({ tokens: recipient.fcmTokens, android: { priority: 'high', ttl: ttlSeconds * 1000 }, data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v ?? '')])) });
}
