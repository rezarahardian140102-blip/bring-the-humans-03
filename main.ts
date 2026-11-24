// bring-the-humans-03 — the entry program (Node 22, program/v1).
//
// The entry is the TikTok video itself: a 15-second vertical ad for make.fun,
// rendered in the build session with ffmpeg from make.fun's press pack
// (brand badge from the first frame, referral end card with the account's
// own referral code 8sbbe4ms over the last 2.5 seconds). See build-ad.sh
// for the render and ad.mp4 for the finished file.
//
// All this program has to do for the gate is hand VIDEO.json over: it reads
// the video's address from the repository root, checks it is a TikTok video
// address, and writes it to /output/VIDEO.json, where the house reads it.
// The house reads the video and its views from TikTok itself; nothing this
// program writes about the video is scored.
//
// Run it locally the same way the grader does, with the two directories
// pointed at this repository and an empty output folder:
//   mkdir -p out && MAKEFUN_BOT_DIR=. MAKEFUN_OUTPUT_DIR=out node main.ts

import { chmodSync, copyFileSync, mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const BOT_DIR = process.env.MAKEFUN_BOT_DIR ?? '/bot';
const OUTPUT_DIR = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// A TikTok video address, as TikTok shows it in a browser:
// https://www.tiktok.com/@<handle>/video/<digits>
const VIDEO_URL = /^https:\/\/(www\.|m\.)?tiktok\.com\/@[^/]+\/video\/\d+\/?$/;

function fail(message: string): never {
  console.error(`main.ts: ${message}`);
  process.exit(1);
}

const source = join(BOT_DIR, 'VIDEO.json');
let raw: string;
try {
  raw = readFileSync(source, 'utf8');
} catch (err) {
  fail(`VIDEO.json could not be read: ${(err as Error).message}`);
}
// The gate refuses a VIDEO.json over 16384 bytes; ours is one short line,
// but fail loudly here instead of shipping a file the gate would reject.
if (Buffer.byteLength(raw, 'utf8') > 16384) {
  fail(`VIDEO.json is over the gate's 16384-byte cap: ${Buffer.byteLength(raw, 'utf8')} bytes`);
}
let parsed: unknown;
try {
  parsed = JSON.parse(raw);
} catch (err) {
  fail(`VIDEO.json could not be read as JSON: ${(err as Error).message}`);
}

if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
  fail('VIDEO.json must be a JSON object like {"url": "https://www.tiktok.com/@handle/video/123"}');
}
const url = (parsed as { url?: unknown }).url;
if (typeof url !== 'string' || !VIDEO_URL.test(url)) {
  fail(`VIDEO.json url is not a TikTok video address: ${String(url)}`);
}

mkdirSync(OUTPUT_DIR, { recursive: true });
const target = join(OUTPUT_DIR, 'VIDEO.json');
try {
  copyFileSync(source, target);
} catch (err) {
  fail(`VIDEO.json could not be copied to ${target}: ${(err as Error).message}`);
}
// The grader collects /output as another user, so the file must be readable
// by everyone, not just by the user this program runs as.
chmodSync(target, 0o644);
console.log(`main.ts: wrote ${target} for ${url}`);
