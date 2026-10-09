// AI coach chat (Vercel version). Same keys as api/analyze.js.
const MODEL = process.env.GEMINI_MODEL || "gemini-3.5-flash-lite";
const RULES = `You are "AI Coach", a friendly Indian nutrition coach inside the app "AI Calorie Counter".
Use the USER DATA to give personal answers.
Rules:
- Start with a direct answer in the first line (for example "Yes, 1 samosa is fine today" or "Better to skip it today").
- Then 2 to 4 short lines with real numbers: calories and protein of the food, and what will be left for today after eating it.
- Prefer Indian foods, Indian portions (katori, roti, piece) and give one healthier swap when useful.
- Reply in the same language and style the user writes in (English, Hindi or Hinglish). Use simple words.
- Keep it under 110 words. You may use **bold** and "- " bullet lines. No headings, no tables.
- If a food has something from the user's allergies, warn clearly first.
- Respect health concerns (for blood sugar: low-GI choices; for BP: less salt; and so on).
- You are not a doctor. For medicines, pregnancy, illness or eating-disorder signs, say kindly to talk to a doctor.
- Never suggest eating under 1200 kcal a day, skipping meals for long, or extreme diets.
- If the question is not about food, health or fitness, answer in one line and bring it back to their goal.`;

async function userFromToken(req) {
  const m = /^Bearer (.+)$/.exec(req.headers.authorization || "");
  if (!m || !process.env.FIREBASE_API_KEY) return null;
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${process.env.FIREBASE_API_KEY}`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ idToken: m[1] }) });
  if (!r.ok) return null;
  const b = await r.json().catch(() => ({}));
  return b?.users?.[0]?.localId || null;
}

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "Use POST." });
  if (!process.env.GEMINI_API_KEY) return res.status(500).json({ error: "Server is missing GEMINI_API_KEY." });
  if (!(await userFromToken(req).catch(() => null))) return res.status(401).json({ error: "Please sign in again." });
  const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
  const contents = (Array.isArray(body.messages) ? body.messages : []).slice(-12)
    .filter((m) => m && typeof m.text === "string")
    .map((m) => ({ role: m.role === "user" ? "user" : "model", parts: [{ text: m.text.slice(0, 1500) }] }));
  if (!contents.length || contents[contents.length - 1].role !== "user") return res.status(400).json({ error: "Ask a question first." });
  const ask = (model) => fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`, {
    method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": process.env.GEMINI_API_KEY },
    body: JSON.stringify({ systemInstruction: { parts: [{ text: RULES + "\n\nUSER DATA:\n" + String(body.context || "").slice(0, 4000) }] },
      contents, generationConfig: { temperature: 0.6, maxOutputTokens: 600 } }) });
  let r = await ask(MODEL);
  if (r.status === 404) r = await ask("gemini-flash-latest");
  const b = await r.json().catch(() => ({}));
  if (!r.ok) return res.status(r.status === 429 ? 429 : 500).json({ error: r.status === 429 ? "AI is busy right now. Try again in a minute." : "Something went wrong. Please try again." });
  const reply = (b?.candidates?.[0]?.content?.parts || []).map((p) => p.text || "").join("").trim();
  if (!reply) return res.status(500).json({ error: "No answer came back. Please try again." });
  return res.status(200).json({ reply });
};
