// AI food scan for the AI Calorie Counter app (runs on Vercel).
// The Gemini key lives only here (Vercel → Settings → Environment Variables → GEMINI_API_KEY).
// Only signed-in app users can call it: we check their Firebase sign-in token.
//
// Speed: the app sends the names in its Indian food list. For foods in that list
// the AI only replies {"db": name, "grams": n}; the app fills in the numbers.

const MODEL = process.env.GEMINI_MODEL || "gemini-3.5-flash-lite";
const FALLBACK_MODEL = "gemini-flash-latest";
const DAILY_LIMIT = Number(process.env.DAILY_SCAN_LIMIT || 40);
const MAX_IMAGE_BASE64 = 2_000_000;

const usage = new Map(); // best-effort per-user daily count (per server instance)

function schema(dbNames) {
  const list = dbNames.length
    ? `\nIf a food matches a name in THALI LIST, use the short form {"db": "<exact list name>", "grams": <grams eaten>, "portion": "2 medium"}.\nTHALI LIST: ${dbNames.join("; ")}`
    : "";
  return `Reply with ONLY one JSON object, no other text:
{"dish": "short meal name",
 "items": [ {"name": "Food name", "portion": "1 bowl", "grams": 150, "kcal": 210, "protein": 9, "carbs": 30, "fat": 6} ],
 "note": "one short simple-English sentence about assumptions (oil, portion size)"}
Numbers are for the whole portion eaten, not per 100 g. Protein, carbs and fat in grams.
Use Indian home-cooking norms (IFCT values, typical recipes) and include cooking oil or ghee.${list}
If there is no food, return {"dish":"","items":[],"note":"No food found."}`;
}

const num = (v) => { const n = Number(v); return Number.isFinite(n) && n >= 0 ? Math.round(n * 10) / 10 : 0; };

function clean(result) {
  const items = (Array.isArray(result?.items) ? result.items : [])
    .filter((i) => i && (i.name || i.db)).slice(0, 15)
    .map((i) => {
      const out = { portion: String(i.portion || "").slice(0, 60), grams: num(i.grams) };
      if (i.db) out.db = String(i.db).slice(0, 80);
      if (i.name) out.name = String(i.name).slice(0, 80);
      if (i.kcal != null) Object.assign(out, { kcal: num(i.kcal), protein: num(i.protein), carbs: num(i.carbs), fat: num(i.fat) });
      return out;
    });
  return { dish: String(result?.dish || "").slice(0, 80), note: String(result?.note || "").slice(0, 200), items };
}

/** Checks the Firebase sign-in token with Google. Returns the user id or null. */
async function userFromToken(req) {
  const m = /^Bearer (.+)$/.exec(req.headers.authorization || "");
  if (!m || !process.env.FIREBASE_API_KEY) return null;
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${process.env.FIREBASE_API_KEY}`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ idToken: m[1] }),
  });
  if (!r.ok) return null;
  const b = await r.json().catch(() => ({}));
  return b?.users?.[0]?.localId || null;
}

async function askGemini(model, parts) {
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": process.env.GEMINI_API_KEY },
    body: JSON.stringify({ contents: [{ role: "user", parts }], generationConfig: { temperature: 0.1, maxOutputTokens: 700, responseMimeType: "application/json" } }),
  });
  return { res, body: await res.json().catch(() => ({})) };
}

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Use POST." });
  if (!process.env.GEMINI_API_KEY) return res.status(500).json({ error: "Server is missing GEMINI_API_KEY." });
  const uid = await userFromToken(req).catch(() => null);
  if (!uid) return res.status(401).json({ error: "Please sign in again." });

  const day = new Date(Date.now() + 5.5 * 3600e3).toISOString().slice(0, 10);
  const k = uid + day, n = usage.get(k) || 0;
  if (n >= DAILY_LIMIT) return res.status(429).json({ error: `Daily limit of ${DAILY_LIMIT} scans reached. Try again tomorrow.` });
  usage.set(k, n + 1);

  const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
  const { imageBase64, text } = body;
  const dbNames = (Array.isArray(body.dbNames) ? body.dbNames : []).filter((x) => typeof x === "string").slice(0, 300).map((x) => x.slice(0, 60));
  const hasImage = typeof imageBase64 === "string" && imageBase64.length > 0;
  const hasText = typeof text === "string" && text.trim().length > 0;
  if (!hasImage && !hasText) return res.status(400).json({ error: "Send a photo or a description." });
  if (hasImage && imageBase64.length > MAX_IMAGE_BASE64) return res.status(400).json({ error: "Photo is too large. Try again." });

  const intro = "You are a nutrition estimator for an Indian calorie tracking app.\n";
  const parts = hasImage
    ? [{ text: intro + "Look at this food photo. Identify each distinct food item and estimate its portion from visual cues (plate, katori, hand size).\n\n" + schema(dbNames) },
       { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }]
    : [{ text: intro + `The user ate: "${text.trim().slice(0, 500)}". Split it into items and estimate each. If a quantity is missing, assume one normal serving.\n\n` + schema(dbNames) }];

  let out;
  try {
    out = await askGemini(MODEL, parts);
    if (!out.res.ok && (out.res.status === 404 || (out.res.status === 400 && /model/i.test(out.body?.error?.message || "")))) out = await askGemini(FALLBACK_MODEL, parts);
  } catch (e) {
    return res.status(503).json({ error: "AI service is not reachable." });
  }
  if (!out.res.ok) {
    console.error("Gemini error", out.res.status, out.body?.error?.message);
    return res.status(out.res.status === 429 ? 429 : 500).json({ error: out.res.status === 429 ? "AI is busy right now. Try again in a minute." : "AI could not process this. Try again." });
  }
  const raw = (out.body?.candidates?.[0]?.content?.parts || []).map((p) => p.text || "").join("");
  let parsed = null;
  try { parsed = JSON.parse(raw); } catch { const m = raw.match(/\{[\s\S]*\}/); if (m) { try { parsed = JSON.parse(m[0]); } catch {} } }
  if (!parsed) return res.status(500).json({ error: "Could not read the AI reply. Try again." });
  return res.status(200).json(clean(parsed));
};
