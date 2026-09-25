import { Router } from 'express';
import { getDb } from '../db.js';
import { requireAuth } from './auth.js';

export const trialRouter = Router();

// POST /api/trial/complete  (Authorization: Bearer <token>)
// Marks the user's one-time free chat session as consumed. Idempotent.
trialRouter.post('/complete', requireAuth, async (req, res) => {
  const db = getDb();
  await db
    .collection('users')
    .updateOne({ _id: req.user._id }, { $set: { trialUsed: true } });

  res.json({ trialUsed: true });
});
