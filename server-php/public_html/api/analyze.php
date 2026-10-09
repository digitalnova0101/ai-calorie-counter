<?php
// AI food scan for the AI Calorie Counter app (PHP version for shared hosting).
// Your keys are NOT in this file. They live in aicc-config.php, one folder ABOVE
// public_html, so nobody can open it from the internet.

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
$FALLBACK = 'gemini-flash-latest';
$LIMIT = intval($cfg['DAILY_SCAN_LIMIT'] ?? 40);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') out(405, ['error' => 'Use POST.']);
if (!$GEMINI_KEY || !$FIREBASE_KEY) out(500, ['error' => 'Server keys are missing.']);

function post_json($url, $body, $headers = []) {
  $ch = curl_init($url);
  curl_setopt_array($ch, [
    CURLOPT_POST => true, CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 55,
    CURLOPT_HTTPHEADER => array_merge(['Content-Type: application/json'], $headers),
    CURLOPT_POSTFIELDS => json_encode($body),
  ]);
  $res = curl_exec($ch);
  $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);
  return [$code, json_decode($res ?: '{}', true) ?: []];
}

// 1) only signed-in app users: check the Firebase sign-in token with Google
$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
if (!preg_match('/^Bearer (.+)$/', $auth, $m)) out(401, ['error' => 'Please sign in again.']);
[$c, $u] = post_json('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' . urlencode($FIREBASE_KEY), ['idToken' => $m[1]]);
$uid = $u['users'][0]['localId'] ?? '';
if ($c !== 200 || !$uid) out(401, ['error' => 'Please sign in again.']);

// 2) daily limit per user (stored in a private folder above public_html)
$dir = dirname($cfgFile) . '/aicc-usage';
if (!is_dir($dir)) @mkdir($dir, 0700, true);
$day = gmdate('Y-m-d', time() + 19800);
$f = $dir . '/' . preg_replace('/[^A-Za-z0-9_-]/', '', $uid) . '_' . $day;
$n = file_exists($f) ? intval(file_get_contents($f)) : 0;
if ($n >= $LIMIT) out(429, ['error' => "Daily limit of $LIMIT scans reached. Try again tomorrow."]);
@file_put_contents($f, $n + 1);

// 3) read the request
$in = json_decode(file_get_contents('php://input'), true) ?: [];
$img = is_string($in['imageBase64'] ?? null) ? $in['imageBase64'] : '';
$text = is_string($in['text'] ?? null) ? trim($in['text']) : '';
$names = array_slice(array_values(array_filter($in['dbNames'] ?? [], 'is_string')), 0, 300);
$names = array_map(fn($x) => mb_substr($x, 0, 60), $names);
if (!$img && !$text) out(400, ['error' => 'Send a photo or a description.']);
if (strlen($img) > 2000000) out(400, ['error' => 'Photo is too large. Try again.']);

$list = $names ? "\nIf a food matches a name in THALI LIST, use the short form {\"db\": \"<exact list name>\", \"grams\": <grams eaten>, \"portion\": \"2 medium\"}.\nTHALI LIST: " . implode('; ', $names) : '';
$schema = "Reply with ONLY one JSON object, no other text:\n{\"dish\": \"short meal name\",\n \"items\": [ {\"name\": \"Food name\", \"portion\": \"1 bowl\", \"grams\": 150, \"kcal\": 210, \"protein\": 9, \"carbs\": 30, \"fat\": 6} ],\n \"note\": \"one short simple-English sentence about assumptions (oil, portion size)\"}\nNumbers are for the whole portion eaten, not per 100 g. Protein, carbs and fat in grams.\nUse Indian home-cooking norms (IFCT values, typical recipes) and include cooking oil or ghee.$list\nIf there is no food, return {\"dish\":\"\",\"items\":[],\"note\":\"No food found.\"}";
$intro = "You are a nutrition estimator for an Indian calorie tracking app.\n";
$parts = $img
  ? [['text' => $intro . "Look at this food photo. Identify each distinct food item and estimate its portion from visual cues (plate, katori, hand size).\n\n" . $schema],
     ['inline_data' => ['mime_type' => 'image/jpeg', 'data' => $img]]]
  : [['text' => $intro . 'The user ate: "' . mb_substr($text, 0, 500) . "\". Split it into items and estimate each. If a quantity is missing, assume one normal serving.\n\n" . $schema]];

// 4) ask Gemini (fall back once if the fast model is not available)
$ask = function ($model) use ($GEMINI_KEY, $parts) {
  return post_json('https://generativelanguage.googleapis.com/v1beta/models/' . rawurlencode($model) . ':generateContent',
    ['contents' => [['role' => 'user', 'parts' => $parts]],
     'generationConfig' => ['temperature' => 0.1, 'maxOutputTokens' => 700, 'responseMimeType' => 'application/json']],
    ['x-goog-api-key: ' . $GEMINI_KEY]);
};
[$code, $body] = $ask($MODEL);
if ($code === 404 || ($code === 400 && stripos($body['error']['message'] ?? '', 'model') !== false)) [$code, $body] = $ask($FALLBACK);
if ($code === 0) out(503, ['error' => 'AI service is not reachable.']);
if ($code !== 200) out($code === 429 ? 429 : 500, ['error' => $code === 429 ? 'AI is busy right now. Try again in a minute.' : 'AI could not process this. Try again.']);

$raw = '';
foreach (($body['candidates'][0]['content']['parts'] ?? []) as $p) $raw .= $p['text'] ?? '';
$parsed = json_decode($raw, true);
if (!$parsed && preg_match('/\{[\s\S]*\}/', $raw, $mm)) $parsed = json_decode($mm[0], true);
if (!$parsed) out(500, ['error' => 'Could not read the AI reply. Try again.']);

// 5) clean the reply
$num = fn($v) => is_numeric($v) && $v >= 0 ? round($v * 10) / 10 : 0;
$items = [];
foreach (array_slice($parsed['items'] ?? [], 0, 15) as $i) {
  if (!is_array($i) || (empty($i['name']) && empty($i['db']))) continue;
  $o = ['portion' => mb_substr((string)($i['portion'] ?? ''), 0, 60), 'grams' => $num($i['grams'] ?? 0)];
  if (!empty($i['db'])) $o['db'] = mb_substr((string)$i['db'], 0, 80);
  if (!empty($i['name'])) $o['name'] = mb_substr((string)$i['name'], 0, 80);
  if (isset($i['kcal'])) { $o['kcal'] = $num($i['kcal']); $o['protein'] = $num($i['protein'] ?? 0); $o['carbs'] = $num($i['carbs'] ?? 0); $o['fat'] = $num($i['fat'] ?? 0); }
  $items[] = $o;
}
out(200, ['dish' => mb_substr((string)($parsed['dish'] ?? ''), 0, 80), 'note' => mb_substr((string)($parsed['note'] ?? ''), 0, 200), 'items' => $items]);
