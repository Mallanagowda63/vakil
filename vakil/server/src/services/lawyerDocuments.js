import { getDb } from '../db.js';

// Verification documents a lawyer sends from the Partner App: the selfie from
// face verification and the advocate licence (image or PDF). They are kept in
// MongoDB, not on disk: the cloud server's disk is wiped on every restart.

export const documentKinds = { face: 'Face verification photo', license: 'Advocate licence' };
export const documentTypes = { 'image/jpeg': 'jpg', 'image/png': 'png', 'application/pdf': 'pdf' };
export const MAX_DOCUMENT_BYTES = 5 * 1024 * 1024;

const col = () => getDb().collection('lawyer_documents');

/** Saves (or replaces) one document and notes it on the lawyer. */
export async function saveDocument({ lawyerId, kind, bytes, contentType, fileName }) {
  const meta = { fileName: String(fileName || `${kind}.${documentTypes[contentType]}`).slice(0, 200), contentType, size: bytes.length, uploadedAt: new Date() };
  await col().updateOne({ lawyerId, kind }, { $set: { lawyerId, kind, data: bytes, ...meta } }, { upsert: true });
  await getDb().collection('lawyers').updateOne({ _id: lawyerId }, { $set: { [`documents.${kind}`]: meta } });
  return meta;
}

export const findDocument = (lawyerId, kind) => col().findOne({ lawyerId, kind });

/** What the Admin Panel shows for each kind: file details, or null when not uploaded. */
export const documentsOf = (lawyer) => Object.fromEntries(Object.keys(documentKinds).map((kind) => [kind, lawyer.documents?.[kind] || null]));
