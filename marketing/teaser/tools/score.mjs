// Render a film's Web Audio score headlessly: node tools/score.mjs film.html out/film.wav
// Loads the page in Chrome (CHROME env or Chrome for Testing), runs FILM.score into an OfflineAudioContext, writes 16-bit stereo WAV.
import puppeteer from 'puppeteer-core';
import { existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const [file, out] = process.argv.slice(2);
if (!file || !out) { console.error('usage: node tools/score.mjs film.html out/film.wav'); process.exit(2); }
function findChrome() { if (process.env.CHROME) return process.env.CHROME; const mac = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'; if (existsSync(mac)) return mac;
  for (const bin of ['google-chrome', 'chromium']) { try { return execFileSync('which', [bin]).toString().trim(); } catch {} } throw new Error('No Chrome found. Set CHROME=/path/to/chrome'); }
const browser = await puppeteer.launch({ executablePath: findChrome(), headless: true });
try {
  const page = await browser.newPage(); const errors = []; page.on('pageerror', e => errors.push(String(e)));
  await page.goto(pathToFileURL(path.resolve(file)).href + '?bare=1&frame=0', { waitUntil: 'load' });
  await page.waitForFunction('window.__ready === true', { timeout: 120000 });
  const b64 = await page.evaluate(async () => {
    const F = window.__FILM; if (!F.score) throw new Error('no score defined'); const sr = 48000, oac = new OfflineAudioContext(2, Math.ceil(sr * F.DUR), sr);
    F.score(oac, 0, oac.destination); const buf = await oac.startRendering();
    const n = buf.length, o = new DataView(new ArrayBuffer(44 + n * 4)), ws = (p, s) => { for (let i = 0; i < s.length; i++) o.setUint8(p + i, s.charCodeAt(i)); };
    ws(0, 'RIFF'); o.setUint32(4, 36 + n * 4, true); ws(8, 'WAVE'); ws(12, 'fmt '); o.setUint32(16, 16, true); o.setUint16(20, 1, true); o.setUint16(22, 2, true); o.setUint32(24, sr, true); o.setUint32(28, sr * 4, true); o.setUint16(32, 4, true); o.setUint16(34, 16, true); ws(36, 'data'); o.setUint32(40, n * 4, true);
    const L = buf.getChannelData(0), R = buf.getChannelData(1); let p = 44; for (let i = 0; i < n; i++) { o.setInt16(p, Math.max(-1, Math.min(1, L[i])) * 32767, true); o.setInt16(p + 2, Math.max(-1, Math.min(1, R[i])) * 32767, true); p += 4; }
    return await new Promise(res => { const fr = new FileReader(); fr.onload = () => res(fr.result.split(',')[1]); fr.readAsDataURL(new Blob([o])); });
  });
  if (errors.length) throw new Error(errors.join('\n'));
  mkdirSync(path.dirname(out), { recursive: true }); writeFileSync(out, Buffer.from(b64, 'base64')); console.log(`score: ${out}`);
} finally { await browser.close(); }
