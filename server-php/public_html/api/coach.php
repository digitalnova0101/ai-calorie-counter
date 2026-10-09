<?php
// AI coach chat for the AI Calorie Counter app (PHP, shared hosting).
// Uses the same aicc-config.php (one folder above public_html) as analyze.php.
header('Content-Type: application/json; charset=utf-8');
function out($code, $data) { http_response_code($code); echo json_encode($data); exit; }

// aicc-config.php sits in your home folder (next to public_html). Works for the main
// domain and for subdomains, whose folder can be inside or outside public_html.
$cfgFile = '';
foreach ([dirname(__DIR__, 2), dirname(__DIR__, 3), dirname(__DIR__, 4)] as $d) {
  if (is_file($d . '/aicc-config.php')) { $cfgFile = $d . '/aicc-config.php'; break; }
}
if (!$cfgFile) out(500, ['error' => 'Server setup not finished (aicc-config.php missing).']);
$cfg = require $cfgFile;
$GEMINI_KEY = $cfg['GEMINI_API_KEY'] ?? '';
$FIREBASE_KEY = $cfg['FIREBASE_API_KEY'] ?? '';
$MODEL = $cfg['GEMINI_MODEL'] ?? 'gemini-3.5-flash-lite';
$LIMIT = intval($cfg['DAILY_COACH_LIMIT'] ?? 60);
if ($_SERVER['REQUEST_METHOD'] !== 'POST') out(405, ['error' => 'Use POST.']);
if (!$GEMINI_KEY || !$FIREBASE_KEY) out(500, ['error' => 'Server keys are missing.']);

function post_json($url, $body, $headers = []) {
  $ch = curl_init($url);
  curl_setopt_array($ch, [CURLOPT_POST => true, CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 55,
    CURLOPT_HTTPHEADER => array_merge(['Content-Type: application/json'], $headers), CURLOPT_POSTFIELDS => json_encode($body)]);
  $res = curl_exec($ch); $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); curl_close($ch);
  return [$code, json_decode($res ?: '{}', true) ?: []];
}

$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
if (!preg_match('/^Bearer (.+)$/', $auth, $m)) out(401, ['error' => 'Please sign in again.']);
[$c, $u] = post_json('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' . urlencode($FIREBASE_KEY), ['idToken' => $m[1]]);
$uid = $u['users'][0]['localId'] ?? '';
if ($c !== 200 || !$uid) out(401, ['error' => 'Please sign in again.']);

$dir = dirname($cfgFile) . '/aicc-usage';
if (!is_dir($dir)) @mkdir($dir, 0700, true);
$f = $dir . '/coach_' . preg_replace('/[^A-Za-z0-9_-]/', '', $uid) . '_' . gmdate('Y-m-d', time() + 19800);
$n = file_exists($f) ? intval(file_get_contents($f)) : 0;
if ($n >= $LIMIT) out(429, ['error' => "You've asked $LIMIT questions today. Try again tomorrow."]);
@file_put_contents($f, $n + 1);

$in = json_decode(file_get_contents('php://input'), true) ?: [];
$context = mb_substr((string)($in['context'] ?? ''), 0, 4000);
$contents = [];
foreach (array_slice($in['messages'] ?? [], -12) as $msg) {
  if (!is_array($msg) || !is_string($msg['text'] ?? null)) continue;
  $contents[] = ['role' => ($msg['role'] ?? '') === 'user' ? 'user' : 'model', 'parts' => [['text' => mb_substr($msg['text'], 0, 1500)]]];
}
if (!$contents || end($contents)['role'] !== 'user') out(400, ['error' => 'Ask a question first.']);

$rules = 'You are "AI Coach", a friendly Indian nutrition coach inside the app "AI Calorie Counter".
Use the USER DATA to give personal answers.
Rules:
- Start with a direct answer in the first line (for example "Yes, 1 samosa is fine today" or "Better to skip it today").
- Then 2 to 4 short lines with real numbers: calories and protein of the food, and what will be left for today after eating it.
- Prefer Indian foods, Indian portions (katori, roti, piece) and give one healthier swap when useful.
- Reply in the same language and style the user writes in (English, Hindi or Hinglish). Use simple words.
- Keep it under 110 words. You may use **bold** and "- " bullet lines. No headings, no tables.
- If a food has something from the user\'s allergies, warn clearly first.
- Respect health concerns (for blood sugar: low-GI choices; for BP: less salt; and so on).
- You are not a doctor. For medicines, pregnancy, illness or eating-disorder signs, say kindly to talk to a doctor.
- Never suggest eating under 1200 kcal a day, skipping meals for long, or extreme diets.
- If the question is not about food, health or fitness, answer in one line and bring it back to their goal.';

$ask = fn($model) => post_json('https://generativelanguage.googleapis.com/v1beta/models/' . rawurlencode($model) . ':generateContent',
  ['systemInstruction' => ['parts' => [['text' => $rules . "\n\nUSER DATA:\n" . $context]]],
   'contents' => $contents, 'generationConfig' => ['temperature' => 0.6, 'maxOutputTokens' => 600]],
  ['x-goog-api-key: ' . $GEMINI_KEY]);
[$code, $body] = $ask($MODEL);
if ($code === 404 || ($code === 400 && stripos($body['error']['message'] ?? '', 'model') !== false)) [$code, $body] = $ask('gemini-flash-latest');
if ($code !== 200) out($code === 429 ? 429 : 500, ['error' => $code === 429 ? 'AI is busy right now. Try again in a minute.' : 'Something went wrong. Please try again.']);
$reply = '';
foreach (($body['candidates'][0]['content']['parts'] ?? []) as $p) $reply .= $p['text'] ?? '';
if (!trim($reply)) out(500, ['error' => 'No answer came back. Please try again.']);
out(200, ['reply' => trim($reply)]);
