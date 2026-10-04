import Anthropic from '@anthropic-ai/sdk';
import { getDb } from '../db.js';
import { lawyerCards, listedLawyers } from '../routes/platform.js';

// Legal Saathi: the client describes their problem, and the suggestions come
// from Vakil's own lawyers, ranked on practice area, client ratings and
// reviews, experience, price and who is available now. Claude writes the
// reply and picks the lawyers when ANTHROPIC_API_KEY is set; without it a
// simple ranking does the same job so the feature always works.

const MODEL = 'claude-opus-5-5';
const MAX_PICKS = 3;

let client;
const claude = () => (process.env.ANTHROPIC_API_KEY ? (client ??= new Anthropic({ timeout: 45_000, maxRetries: 1 })) : null);

const SYSTEM = `You are Legal Saathi, the assistant inside Vakil, an Indian app where clients pay per minute to chat or call verified lawyers.

Your job: understand the client's legal problem and recommend the best lawyers for it from the <lawyers> list you are given. Never mention or invent a lawyer who is not in that list, and never invent facts about a lawyer (experience, prices, ratings, reviews) beyond what the list says.

How to choose:
- Practice area fit matters most. Map the problem to the right area (for example arrest, FIR, bail, theft, cheating → criminal; divorce, custody, maintenance, dowry → family; land, tenant, builder → property or real estate; salary, termination → employment).
- Then prefer higher client ratings with more reviews, what recent reviews say, more years of experience and more consultations completed on Vakil.
- Prefer lawyers who are available right now (chat or call as the client wants), and mention price when the client cares about cost.
- Use the client's own history: prefer lawyers they rated 4-5 for a similar matter, and avoid lawyers they rated 1-2.
- Recommend at most ${MAX_PICKS} lawyers, best first. If nobody fits the area, say so honestly and suggest the closest options, or none.

Your reply:
- Write in the same language the client used (English, Hindi, Hinglish, Kannada, etc.), warm and simple, 2 to 5 short sentences, no markdown.
- Briefly say what kind of lawyer they need and why, then introduce your picks; the app shows each lawyer's card (photo, price, rating, experience) under your reply, so do not repeat every number.
- Give general information only, never a final legal opinion; the lawyer gives the advice.
- If the client describes an emergency or danger (violence, threat to life, someone missing), tell them to call 112 first.
- If the problem is unclear, recommend the best general options and ask one short question.

For each pick, the reason is one short sentence the client sees on that lawyer's card (for example "Criminal lawyer, 4.9★ from 25 clients, available to chat now").`;

const SCHEMA = {
  type: 'object',
  properties: {
    reply: { type: 'string', description: 'The message shown to the client.' },
    practice_area: { type: 'string', description: 'The area of law the problem belongs to, or an empty string if unclear.' },
    picks: {
      type: 'array',
      description: `Up to ${MAX_PICKS} recommended lawyers, best first.`,
      items: {
        type: 'object',
        properties: { lawyer_id: { type: 'string' }, reason: { type: 'string' } },
        required: ['lawyer_id', 'reason'],
        additionalProperties: false,
      },
    },
  },
  required: ['reply', 'practice_area', 'picks'],
  additionalProperties: false,
};

// Recent client reviews per lawyer (lawyers also rate clients; those are skipped).
async function recentReviews() {
  const rows = await getDb().collection('reviews').find({ hidden: { $ne: true }, authorRole: { $ne: 'lawyer' } }).sort({ createdAt: -1 }).limit(500).toArray();
  const out = new Map();
  for (const r of rows) {
    if (!r.lawyerId || !String(r.comment || '').trim()) continue;
    const list = out.get(String(r.lawyerId)) || [];
    if (list.length < 3) list.push({ rating: r.rating, comment: String(r.comment).trim().slice(0, 200) });
    out.set(String(r.lawyerId), list);
  }
  return out;
}

// This client's past consultations: which lawyer, what for, and how they rated it.
async function clientHistory(userId) {
  const rows = await getDb().collection('consultation_requests').find({ userId, status: 'COMPLETED' }).sort({ updatedAt: -1 }).limit(10).toArray();
  return rows.map((r) => ({ lawyer_id: String(r.lawyerId), lawyer: r.lawyerName || 'Lawyer', area: r.category || '', type: r.consultationType || 'chat', my_rating: r.rating ?? null }));
}

function catalogEntry(card, reviews) {
  return {
    id: card.id, name: card.name, practice_areas: card.categories, experience_years: card.experienceYears, consultations_on_vakil: card.consultationsDone,
    rating: card.ratingAverage, ratings_count: card.ratingCount, recent_reviews: reviews.get(card.id) || [],
    chat_price_per_min: card.ratePerMinute, call_price_per_min: card.callRatePerMinute, available_for_chat_now: Boolean(card.isChatOnline), available_for_call_now: Boolean(card.isCallOnline),
    city: card.city, languages: card.languages, bio: String(card.bio || '').slice(0, 300),
  };
}

async function askClaude(api, { message, history, catalog, past }) {
  const transcript = history.map((t) => `${t.role === 'assistant' ? 'Legal Saathi' : 'Client'}: ${t.text}`).join('\n');
  const content = `<lawyers>\n${JSON.stringify(catalog)}\n</lawyers>\n\n<client_history>\n${JSON.stringify(past)}\n</client_history>\n\n`
    + (transcript ? `<conversation_so_far>\n${transcript}\n</conversation_so_far>\n\n` : '')
    + `<client_message>\n${message}\n</client_message>`;
  const response = await api.beta.messages.create({
    model: MODEL,
    max_tokens: 8000,
    // A policy decline is retried on Anthropic's recommended fallback model.
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: 'low', format: { type: 'json_schema', schema: SCHEMA } },
    system: SYSTEM,
    messages: [{ role: 'user', content }],
  });
  if (response.stop_reason === 'refusal' || response.stop_reason === 'max_tokens') return null;
  const text = response.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
  try { return JSON.parse(text); } catch { return null; }
}

// Without Claude: practice-area words in the message pick the area, then
// rating, reviews, experience and availability rank the lawyers.
const AREAS = [
  { area: 'Criminal', match: /crimin/i, words: /crim|police|arrest|fir\b|bail|theft|stole|murder|assault|cheat|fraud|jail|custody of police|kidnap|harass|threat|beat|attack|chor|giraft|thana/i },
  { area: 'Family', match: /family|divorce|matrimon/i, words: /divorce|marriage|married|custody|alimony|maintenance|wife|husband|dowry|domestic|talaq|shaadi|child support|in-laws/i },
  { area: 'Property', match: /property|real estate|land|civil/i, words: /property|land|plot|house|flat|rent|tenant|landlord|builder|possession|registry|mutation|encroach|zameen|makaan/i },
  { area: 'Employment', match: /employ|labou?r/i, words: /job|salary|employer|fired|terminat|resign|office|workplace|pf\b|gratuity|wages|boss|naukri/i },
  { area: 'Corporate', match: /corporate|business|commercial|company/i, words: /company|business|startup|contract|gst|partner|shares|agreement|vendor|invoice|trademark/i },
  { area: 'Consumer', match: /consumer/i, words: /consumer|refund|defective|warranty|online order|service provider|insurance claim/i },
  { area: 'Cyber', match: /cyber/i, words: /cyber|online fraud|hack|upi fraud|otp|social media|scam/i },
];

function ruleBased({ message, cards, past }) {
  const found = AREAS.find((a) => a.words.test(message));
  const rated = new Map(past.filter((p) => p.my_rating != null).map((p) => [p.lawyer_id, p.my_rating]));
  const score = (c) => {
    const fits = found ? c.categories.some((cat) => found.match.test(cat)) : false;
    const mine = rated.get(c.id);
    return (fits ? 100 : 0) + (c.ratingAverage || 0) * 8 + Math.log1p(c.ratingCount) * 4 + Math.min(c.experienceYears || 0, 30) * 0.5
      + Math.log1p(c.consultationsDone) * 2 + (c.isChatOnline || c.isCallOnline ? 10 : 0) + (mine >= 4 ? 15 : mine != null && mine <= 2 ? -40 : 0);
  };
  const ranked = [...cards].sort((a, b) => score(b) - score(a));
  const fitting = found ? ranked.filter((c) => c.categories.some((cat) => found.match.test(cat))) : [];
  const picks = (fitting.length ? fitting : ranked).slice(0, MAX_PICKS);
  const reason = (c) => [
    c.categories.slice(0, 2).join(', ') || 'Lawyer',
    c.ratingAverage != null ? `${c.ratingAverage}★ from ${c.ratingCount} client${c.ratingCount === 1 ? '' : 's'}` : null,
    c.experienceYears != null ? `${c.experienceYears} yrs experience` : null,
    c.isChatOnline || c.isCallOnline ? 'available now' : null,
  ].filter(Boolean).join(' · ');
  const reply = !picks.length ? 'Sorry, no lawyers are listed on Vakil right now. Please try again a little later.'
    : found && fitting.length ? `This sounds like a ${found.area.toLowerCase()} law matter. Here are the best ${found.area.toLowerCase()} lawyers on Vakil, based on client ratings, reviews, experience and who is available now.`
      : found ? `This sounds like a ${found.area.toLowerCase()} law matter, but no ${found.area.toLowerCase()} lawyer is listed right now. These are our best-rated lawyers who may still help.`
        : 'Here are the best-rated lawyers on Vakil right now. Tell me a little more about your problem (for example police case, divorce, property or job) and I can suggest the right specialist.';
  return { reply, practiceArea: found?.area || '', picks: picks.map((c) => ({ card: c, reason: reason(c) })) };
}

/**
 * Suggests lawyers for a client's message. `history` is the earlier turns of
 * this Legal Saathi conversation ({ role: 'user' | 'assistant', text }).
 */
export async function suggestLawyers({ userId, message, history = [] }) {
  const [cards, reviews, past] = await Promise.all([listedLawyers().then(lawyerCards), recentReviews(), clientHistory(userId)]);
  const api = claude();
  let result = null;
  if (api && cards.length) {
    try {
      const answer = await askClaude(api, { message, history, catalog: cards.map((c) => catalogEntry(c, reviews)), past });
      if (answer) {
        const byId = new Map(cards.map((c) => [c.id, c])); const seen = new Set();
        const picks = (answer.picks || []).filter((p) => byId.has(p.lawyer_id) && !seen.has(p.lawyer_id) && seen.add(p.lawyer_id)).slice(0, MAX_PICKS).map((p) => ({ card: byId.get(p.lawyer_id), reason: String(p.reason || '') }));
        result = { reply: String(answer.reply || '').trim(), practiceArea: String(answer.practice_area || ''), picks, ai: true };
      }
    } catch (error) {
      if (error instanceof Anthropic.AuthenticationError) console.error('Legal Saathi: ANTHROPIC_API_KEY was rejected');
      else if (error instanceof Anthropic.RateLimitError) console.error('Legal Saathi: Claude rate limit reached');
      else if (error instanceof Anthropic.APIError) console.error(`Legal Saathi: Claude API error ${error.status}:`, error.message);
      else console.error('Legal Saathi:', error);
    }
  }
  if (!result?.reply) result = { ...ruleBased({ message, cards, past }), ai: false };
  return { reply: result.reply, practiceArea: result.practiceArea, ai: result.ai, lawyers: result.picks.map((p) => ({ ...p.card, reason: p.reason })) };
}
