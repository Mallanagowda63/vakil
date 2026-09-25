import crypto from 'node:crypto';

// ZEGOCLOUD "Token04" generator, following ZEGO's official server assistant.
// The server secret stays here; apps only receive short-lived tokens.
export function zegoConfig() {
  const appId = Number(process.env.ZEGO_APP_ID);
  const secret = process.env.ZEGO_SERVER_SECRET || '';
  if (!appId || secret.length !== 32) return null;
  return { appId, secret };
}

export function generateToken04(appId, userId, secret, effectiveSeconds, payload = '') {
  const now = Math.floor(Date.now() / 1000);
  const info = { app_id: appId, user_id: userId, nonce: crypto.randomInt(-(2 ** 31), 2 ** 31 - 1), ctime: now, expire: now + effectiveSeconds, payload };
  const iv = Array.from({ length: 16 }, () => '0123456789abcdefghijklmnopqrstuvwxyz'[crypto.randomInt(36)]).join('');
  const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(secret), Buffer.from(iv));
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(info), 'utf8'), cipher.final()]);
  const expire = Buffer.alloc(8); expire.writeBigInt64BE(BigInt(info.expire));
  const ivLength = Buffer.alloc(2); ivLength.writeUInt16BE(iv.length);
  const dataLength = Buffer.alloc(2); dataLength.writeUInt16BE(encrypted.length);
  return '04' + Buffer.concat([expire, ivLength, Buffer.from(iv), dataLength, encrypted]).toString('base64');
}
