import { BSON, MongoClient, ObjectId } from 'mongodb';
import path from 'node:path';
import { mkdir } from 'node:fs/promises';
import { existsSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

const configuredUri = process.env.MONGODB_URI;
if (!configuredUri) {
  throw new Error('MONGODB_URI is not set (check server/.env)');
}

function mongoUri() {
  const hosts = process.env.MONGODB_DIRECT_HOSTS;
  if (!hosts || !configuredUri.startsWith('mongodb+srv://')) return configuredUri;
  const parsed = new URL(configuredUri);
  const replicaSet = process.env.MONGODB_REPLICA_SET;
  const query = new URLSearchParams(parsed.search);
  query.set('ssl', 'true');
  query.set('authSource', 'admin');
  if (replicaSet) query.set('replicaSet', replicaSet);
  return `mongodb://${parsed.username}:${parsed.password}@${hosts}${parsed.pathname}?${query}`;
}

const isOperatorObject = (value) => value && typeof value === 'object' && !(value instanceof ObjectId) && !(value instanceof Date) && Object.keys(value).some((key) => key.startsWith('$'));
const equalityFields = (filter) => Object.fromEntries(Object.entries(filter).filter(([key, value]) => !key.startsWith('$') && !isOperatorObject(value)));

const mockWriteMethods = ['insertOne', 'insertMany', 'updateOne', 'updateMany', 'replaceOne', 'deleteOne', 'deleteMany', 'findOneAndUpdate'];

// mongo-mock follows the v3 driver: findOneAndUpdate resolves to { value },
// and upserts copy ObjectIds from the filter into plain objects that never
// match again. Adapt both to the v6 driver behaviour the routes rely on.
// Its own file persistence turns Dates into strings and ObjectIds into a
// different class, so snapshots are written as Extended JSON instead.
async function patchMockDb(mockDb, file) {
  const collection = mockDb.collection.bind(mockDb);
  const names = new Set();
  let saveTimer;
  const save = async () => {
    const snapshot = {};
    for (const name of names) snapshot[name] = await collection(name).find({}).toArray();
    writeFileSync(`${file}.tmp`, BSON.EJSON.stringify(snapshot, null, 2));
    renameSync(`${file}.tmp`, file);
  };
  // Saves within 200 ms of the first unsaved write, even under constant
  // traffic (a resetting debounce would never fire while writes keep coming).
  const scheduleSave = () => {
    if (saveTimer) return;
    saveTimer = setTimeout(() => { saveTimer = null; save().catch((err) => console.error('Failed to save local database:', err)); }, 200);
  };
  // Flush on Ctrl+C / stop so the last writes are not lost.
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.once(signal, () => { clearTimeout(saveTimer); save().catch(console.error).finally(() => process.exit(0)); });
  }
  mockDb.collection = (...args) => {
    const col = collection(...args);
    names.add(args[0]);
    if (col.vakilPatched) return col;
    // Some mongo-mock methods are getter-only aliases, so define rather than assign.
    const override = (method, fn) => Object.defineProperty(col, method, { value: fn, writable: true, configurable: true });
    for (const method of mockWriteMethods) {
      const original = col[method]?.bind(col);
      if (original) override(method, async (...callArgs) => { const result = await original(...callArgs); scheduleSave(); return result; });
    }
    // mongo-mock's generated _ids use bson-objectid, which EJSON cannot serialize.
    const withId = (doc) => { doc._id ??= new ObjectId(); return doc; };
    const insertOne = col.insertOne.bind(col);
    const insertMany = col.insertMany.bind(col);
    override('insertOne', (doc, ...rest) => insertOne(withId(doc), ...rest));
    override('insertMany', (docs, ...rest) => insertMany(docs.map(withId), ...rest));
    const updateOne = col.updateOne.bind(col);
    const findOneAndUpdate = col.findOneAndUpdate.bind(col);
    override('updateOne', async (filter, update, options = {}) => {
      if (!options.upsert) return updateOne(filter, update, options);
      if (await col.findOne(filter)) return updateOne(filter, update, { ...options, upsert: false });
      const { insertedId } = await col.insertOne({ ...equalityFields(filter), ...update.$setOnInsert, ...update.$set });
      return { acknowledged: true, matchedCount: 0, modifiedCount: 0, upsertedCount: 1, upsertedId: insertedId };
    });
    override('findOneAndUpdate', async (...callArgs) => (await findOneAndUpdate(...callArgs))?.value ?? null);
    // Not implemented by mongo-mock; enough for the admin stats:
    // distinct(field, filter), and aggregate with $match, $group ($sum), $sort, $limit.
    const key = (value) => value instanceof ObjectId ? `oid:${value}` : value instanceof Date ? `date:${value.toISOString()}` : JSON.stringify(value);
    override('distinct', async (field, filter = {}) => {
      const values = new Map();
      for (const doc of await col.find(filter).toArray()) { const value = doc[field]; if (value !== undefined) values.set(key(value), value); }
      return [...values.values()];
    });
    override('aggregate', (pipeline) => ({ toArray: async () => {
      let docs = null;
      const valueOf = (doc, expr) => typeof expr === 'string' && expr.startsWith('$') ? doc[expr.slice(1)] : expr;
      for (const stage of pipeline) {
        const [op, spec] = Object.entries(stage)[0];
        if (op === '$match') docs = docs ? await col.find({ $and: [spec, { _id: { $in: docs.map((d) => d._id) } }] }).toArray() : await col.find(spec).toArray();
        else {
          docs ??= await col.find({}).toArray();
          if (op === '$group') {
            const groups = new Map();
            for (const doc of docs) {
              const id = valueOf(doc, spec._id); const k = key(id);
              const group = groups.get(k) || Object.fromEntries([['_id', id], ...Object.keys(spec).filter((f) => f !== '_id').map((f) => [f, 0])]);
              for (const [field, acc] of Object.entries(spec)) if (field !== '_id') group[field] += Number(valueOf(doc, acc.$sum)) || 0;
              groups.set(k, group);
            }
            docs = [...groups.values()];
          } else if (op === '$sort') {
            const [[field, dir]] = Object.entries(spec);
            docs = [...docs].sort((a, b) => (a[field] > b[field] ? 1 : a[field] < b[field] ? -1 : 0) * dir);
          } else if (op === '$limit') docs = docs.slice(0, spec);
          else throw new Error(`mock aggregate: ${op} is not supported`);
        }
      }
      return docs ?? await col.find({}).toArray();
    } }));
    override('vakilPatched', true);
    return col;
  };
  if (!existsSync(file)) return;
  const snapshot = BSON.EJSON.parse(readFileSync(file, 'utf8'));
  for (const [name, documents] of Object.entries(snapshot)) {
    if (documents.length) await collection(name).insertMany(documents);
    names.add(name);
  }
}

let client;
let memoryServer;
let db;
// True only after start-up work is done; the API and sockets wait for it.
let ready = false;

export async function connectDb() {
  if (db) return db;
  if (process.env.USE_MONGO_MOCK === 'true') {
    const mongoMock = require('mongo-mock');
    mongoMock.max_delay = 0;
    client = await new Promise((resolve, reject) => mongoMock.MongoClient.connect('mongodb://vakil-local/vakil', {}, (error, value) => error ? reject(error) : resolve(value)));
    db = client.db('vakil');
    await patchMockDb(db, path.resolve(process.cwd(), process.env.LOCAL_MONGO_FILE || '.local-vakil-db.json'));
  } else {
  let uri = mongoUri();
  if (process.env.USE_LOCAL_MONGO === 'true') {
    const { MongoMemoryServer } = await import('mongodb-memory-server');
    const dbPath = path.resolve(process.cwd(), process.env.LOCAL_MONGO_PATH || '.local-mongodb');
    await mkdir(dbPath, { recursive: true });
    memoryServer = await MongoMemoryServer.create({
      binary: { version: process.env.LOCAL_MONGO_VERSION || '7.0.14' },
      instance: { dbName: 'vakil', dbPath, storageEngine: 'wiredTiger' },
    });
    uri = memoryServer.getUri('vakil');
  }
  client = new MongoClient(uri, {
    serverSelectionTimeoutMS: 20000,
    family: 4,
  });
  await client.connect();
  db = client.db();
  }
  await db.collection('users').createIndex({ phone: 1 }, { unique: true });
  await db.collection('lawyers').createIndex({ phone: 1 }, { unique: true, sparse: true });
  await db.collection('consultation_requests').createIndex({ userId: 1, status: 1 });
  await db.collection('consultation_requests').createIndex({ lawyerId: 1, status: 1 });
  await db.collection('consultation_requests').createIndex({ expiresAt: 1, status: 1 });
  await db.collection('request_status_logs').createIndex({ requestId: 1, createdAt: 1 });
  await db.collection('sessions').createIndex({ requestId: 1 }, { unique: true });
  await db.collection('reviews').createIndex({ requestId: 1 }, { unique: true });
  await db.collection('notifications').createIndex({ recipientId: 1, createdAt: -1 });
  await db.collection('messages').createIndex({ requestId: 1, createdAt: 1 });
  await db.collection('messages').createIndex({ requestId: 1, senderId: 1, clientId: 1 });
  await db.collection('calls').createIndex({ requestId: 1, startedAt: -1 });
  await db.collection('calls').createIndex({ status: 1, startedAt: 1 });
  await db.collection('otps').createIndex({ phone: 1 });
  await db
    .collection('otps')
    .createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });
  // Nobody is connected to a freshly started server: clear flags left by the
  // last run before any app can connect, so a fast reconnect is not undone.
  for (const name of ['users', 'lawyers']) await db.collection(name).updateMany({ connected: true }, { $set: { connected: false } });
  ready = true;
  return db;
}

export function getDb() {
  if (!db) throw new Error('Database not connected yet');
  return db;
}

export function isDbConnected() {
  return ready;
}
