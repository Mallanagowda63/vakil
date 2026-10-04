import { Router } from 'express';
import { roles } from './auth.js';
import { suggestLawyers } from '../services/lawyerAdvisor.js';

export const aiRouter = Router();

// Each question costs an AI call: at most 30 per client per hour.
const LIMIT = 30; const WINDOW = 60 * 60 * 1000;
const asked = new Map();
function allow(userId) {
  const now = Date.now(); const key = String(userId);
  const recent = (asked.get(key) || []).filter((t) => now - t < WINDOW);
  if (recent.length >= LIMIT) return false;
  recent.push(now); asked.set(key, recent);
  return true;
}

// POST /api/ai/lawyer-suggestions { message, history?: [{ role: 'user' | 'assistant', text }] }
// Legal Saathi (User App): a reply plus up to 3 suggested lawyers.
aiRouter.post('/lawyer-suggestions', ...roles('user'), async (req, res) => {
  const message = String(req.body.message ?? '').trim().slice(0, 1500);
  if (!message) return res.status(400).json({ error: 'Tell Legal Saathi about your problem first' });
  if (!allow(req.user._id)) return res.status(429).json({ error: 'You have asked a lot of questions in the last hour. Please try again later.' });
  const history = (Array.isArray(req.body.history) ? req.body.history : []).slice(-10)
    .map((t) => ({ role: t?.role === 'assistant' ? 'assistant' : 'user', text: String(t?.text ?? '').trim().slice(0, 1500) }))
    .filter((t) => t.text);
  res.json(await suggestLawyers({ userId: req.user._id, message, history }));
});
