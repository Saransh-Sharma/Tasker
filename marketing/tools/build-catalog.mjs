// Build marketing/index.html: a dependency-free catalog of every film (both sets, three formats) and every curated asset.
// Usage: node marketing/tools/build-catalog.mjs      Re-run after any build; the page uses relative paths and works from file://.
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const HERE = path.dirname(fileURLToPath(import.meta.url)), M = path.resolve(HERE, '..');
const SETS = [
  { id: 'teaser', title: 'Set one: Drawn', concept: '"A real day, drawn." Every frame drawn in ink on warm paper: scraps of a life fold into one place, the app asks its own questions, plans break and EVA helps recover, the sun lands as the icon\'s eye.',
    cuts: [['bumper-6s', 'Bumper', '6 s', 'Logo ident: the sun crosses a day and becomes the icon\'s eye.', '6 s bumper (YouTube), pre-roll sting'], ['teaser-10s', 'Teaser', '9.5 s', 'Scraps boil, fold into one place, a day passes, sign-off.', 'Reels, TikTok, Shorts'], ['advert-30s', 'Advert', '30 s', 'One day through the app: Home, Plan, Focus, Track, recover, Insights, Eva.', 'Site, App Store preview, pre-roll'], ['launch-45s', 'Launch film', '45 s', 'The advert plus life areas, Journal, everywhere and private by default.', 'Site hero, launch post, YouTube']] },
];
const FORMATS = [['9x16', '9:16', '1080 x 1920'], ['16x9', '16:9', '1920 x 1080'], ['1x1', '1:1', '1080 x 1080']];
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const kb = f => existsSync(f) ? Math.round(statSync(f).size / 1024) : 0;
function beatSheet(html) {   // parse the "// t  dur  scene ... label" comment table above the timeline
  const lines = html.split('\n').map(l => l.trim()).filter(l => l.startsWith('//'));
  const head = lines.findIndex(l => /^\/\/\s*t\s{2,}dur/.test(l)); if (head < 0) return [];
  const cols = lines[head].replace(/^\/\/\s*/, '').split(/\s{2,}/).map(s => s.toLowerCase()), out = [];
  for (let k = head + 1; k < lines.length; k++) { const row = lines[k].replace(/^\/\/\s*/, ''); if (!/^\d/.test(row)) break; const cells = row.split(/\s{2,}/); const o = {}; cols.forEach((c, n) => o[c] = cells[n] ?? ''); if (cols.includes('label') && cells.length > cols.length) o.label = cells.slice(cols.length - 1).join(' '); out.push(o); }
  return out;
}
function copyLines(html) {   // the on-screen lines in order, with timecodes, from the beat sheet and the sign-off calls
  const rows = beatSheet(html), lines = rows.filter(r => r.label && !/^[-(]/.test(r.label)).map(r => ({ t: r.t, text: r.label.replace(/\s*\|.*$/, '') }));
  const tag = /tagline:\s*'([^']+)'/.exec(html), plat = /platforms:\s*'([^']+)'/.exec(html);
  lines.push({ t: rows.length ? rows[rows.length - 1].t : '', text: 'LifeBoard / ' + (tag ? tag[1] : 'One place to run the life you actually have.') });
  if (plat) lines.push({ t: '', text: plat[1] }); if (/cta: false/.test(html) === false && html.includes('cPrint(')) lines.push({ t: '', text: 'On the App Store.' }); return lines;
}
const films = SETS.map(set => ({ ...set, cuts: set.cuts.map(([file, name, len, concept, placement]) => { const html = readFileSync(path.join(M, set.id, file + '.html'), 'utf8'); return { file, name, len, concept, placement, beats: beatSheet(html), copy: copyLines(html),
  formats: FORMATS.map(([d, ar, px]) => { const base = `${set.id}/out/final/${file}-${d}`; return { d, ar, px, mp4: base + '.mp4', silent: base + '-silent.mp4', poster: base + '-poster.png', contact: base + '-contact.jpg', exists: existsSync(path.join(M, base + '.mp4')), kb: kb(path.join(M, base + '.mp4')) }; }) }; }) }));
const manifest = JSON.parse(readFileSync(path.join(M, 'assets', 'manifest.json'), 'utf8'));
const FAMILY = { celestial: ['Celestial phases', 'The six felt-textured discs and their dune backgrounds, in the app\'s daypart order.'], headers: ['Headers', 'Torn-edge watercolour header vignettes for the 17 feature surfaces, light and dark.'], scenes: ['Card scenes', 'The 22 painted home-card vignettes, light and dark.'], decor: ['Decor stickers', 'Sunrise and rescue stickers: happy sun, moonrise, mountain, shield and friends.'], strips: ['Routine strips', 'Morning and evening watercolour strips.'], postcards: ['Task cards', 'Six square watercolour scenes used as postcards.'], companions: ['Companions', 'The pixel-art chief-of-staff personas as sprite sheets (8 x 9 cells of 192 x 208).'], brand: ['Brand', 'The icon, its light variant, the logo mark and the vector source.'], hero: ['Hero', 'The welcome poster.'] };
const families = Object.keys(FAMILY).map(f => ({ id: f, title: FAMILY[f][0], desc: FAMILY[f][1], items: manifest.filter(a => a.family === f) }));
const totalFilms = films.reduce((n, s) => n + s.cuts.length, 0), rendered = films.reduce((n, s) => n + s.cuts.reduce((m, c) => m + c.formats.filter(f => f.exists).length, 0), 0);

const css = `
:root{--paper:#FFF7D8;--paper2:#FBF3E2;--ink:#2B2118;--ink2:#6F6252;--sun:#F0CD87;--apricot:#E7BB7E;--violet:#6842FF;--sage:#5D6A4D;--line:#E9DFC6;--night:#151B2D;--parch:#F7F1E7}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.5 -apple-system,"SF Pro Text",Inter,system-ui,sans-serif}
body::before{content:"";position:fixed;inset:0;pointer-events:none;background:repeating-linear-gradient(-45deg,rgba(255,243,210,.55) 0 60px,transparent 60px 120px);z-index:-1}
h1,h2,h3,.hand{font-family:"Bradley Hand","Chalkboard SE","Segoe Script",cursive;font-weight:700;letter-spacing:.01em}
h1{font-size:44px;margin:0}h2{font-size:34px;margin:56px 0 8px;scroll-margin-top:24px}h3{font-size:24px;margin:0 0 4px}
a{color:var(--ink)}.muted{color:var(--ink2)}.wrap{max-width:1180px;margin:0 auto;padding:28px 20px 80px}
header{display:flex;gap:22px;align-items:center;flex-wrap:wrap}header img{width:84px;height:84px;border-radius:20px;box-shadow:4px 6px 0 var(--sun)}
.kpis{display:flex;gap:16px;flex-wrap:wrap;margin:18px 0 0}.kpi{background:var(--paper2);border:1px solid var(--ink);border-radius:14px;padding:8px 14px;box-shadow:3px 4px 0 var(--sun);font-size:14px}
nav.top{position:sticky;top:0;z-index:5;background:rgba(255,247,216,.92);backdrop-filter:blur(6px);border-bottom:1px solid var(--line);margin:22px -20px 0;padding:10px 20px;display:flex;gap:14px;flex-wrap:wrap;align-items:center}
nav.top a{text-decoration:none;font-weight:600;font-size:15px;padding:4px 10px;border-radius:999px}nav.top a:hover{background:var(--sun)}nav.top input{margin-left:auto;font:inherit;padding:6px 12px;border:1px solid var(--ink);border-radius:999px;background:var(--paper2);min-width:220px}
.set{margin-top:12px}.concept{max-width:820px;margin:0 0 18px}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:22px}
.card{background:var(--paper2);border:1px solid var(--ink);border-radius:20px;padding:16px;box-shadow:5px 7px 0 var(--sun);display:flex;flex-direction:column;gap:10px}
.card .len{font-family:"SF Mono",Menlo,monospace;font-size:13px;background:var(--sun);border-radius:999px;padding:2px 10px;margin-left:8px}
.tabs{display:flex;gap:6px}.tabs button{font:inherit;font-size:13px;font-weight:600;border:1px solid var(--ink);background:var(--paper);border-radius:999px;padding:4px 12px;cursor:pointer}.tabs button[aria-selected=true]{background:var(--ink);color:var(--parch)}
.player{position:relative;background:var(--night);border-radius:14px;overflow:hidden;display:grid;place-items:center;min-height:200px}
.player video{width:100%;max-height:520px;display:block;background:#000}.missing{color:var(--parch);padding:24px;text-align:center;font-size:14px}.missing code{display:block;margin-top:8px;font-size:12px;background:rgba(255,255,255,.08);padding:6px 10px;border-radius:8px;user-select:all}
.links{display:flex;gap:10px;flex-wrap:wrap;font-size:14px}.links a{text-decoration:none;border:1px solid var(--ink);border-radius:999px;padding:3px 10px;background:var(--paper)}.links a[aria-disabled=true]{opacity:.35;pointer-events:none}
details{border-top:1px dashed var(--line);padding-top:8px}summary{cursor:pointer;font-weight:600;font-size:14px}
table.beats{width:100%;border-collapse:collapse;font-size:13px;margin-top:8px}table.beats td,table.beats th{text-align:left;padding:4px 6px;border-bottom:1px solid var(--line);vertical-align:top}table.beats th{font-weight:600;color:var(--ink2)}
.placement{font-size:13px;color:var(--ink2)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:14px}
.asset{background:var(--paper2);border:1px solid var(--ink);border-radius:14px;padding:10px;box-shadow:3px 4px 0 var(--sun);font-size:12px;display:flex;flex-direction:column;gap:6px}
.asset .thumb{height:120px;display:grid;place-items:center;background:repeating-conic-gradient(rgba(43,33,24,.06) 0 25%,transparent 0 50%) 0 0/16px 16px;border-radius:8px;overflow:hidden}
.asset .thumb.dark{background:var(--night)}.asset img{max-width:100%;max-height:120px;object-fit:contain}.asset .name{font-weight:600;font-size:13px}.asset .meta{color:var(--ink2);font-family:"SF Mono",Menlo,monospace;font-size:11px;word-break:break-all}
.asset button{font:inherit;font-size:11px;border:1px solid var(--ink);background:var(--paper);border-radius:999px;padding:2px 8px;cursor:pointer;align-self:flex-start}
.sprite{width:96px;height:104px;image-rendering:pixelated;background-repeat:no-repeat;background-size:768px auto}
.deck{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:18px}.deck .card ol{margin:0;padding-left:20px;font-size:14px}.deck .card li{margin:4px 0}.deck .t{font-family:"SF Mono",Menlo,monospace;font-size:11px;color:var(--ink2);margin-right:6px}
pre{background:var(--night);color:var(--parch);padding:14px 16px;border-radius:14px;overflow:auto;font-size:13px}
dialog{border:1px solid var(--ink);border-radius:16px;padding:0;max-width:min(96vw,1400px);background:var(--paper2)}dialog img{max-width:100%;display:block}dialog form{padding:8px 12px;text-align:right}
.hidden{display:none!important}footer{margin-top:60px;color:var(--ink2);font-size:13px}
@media (max-width:640px){h1{font-size:34px}h2{font-size:28px}.cards{grid-template-columns:1fr}}
`;

const filmCard = (set, c) => `
<article class="card film" data-search="${esc(set.title + ' ' + c.name + ' ' + c.concept + ' ' + c.file)}">
  <div><h3 style="display:inline">${esc(c.name)}</h3><span class="len">${esc(c.len)}</span></div>
  <p class="muted" style="margin:0">${esc(c.concept)}</p>
  <div class="tabs" role="tablist">${c.formats.map((f, n) => `<button role="tab" aria-selected="${n === 0}" data-fmt="${f.d}">${f.ar}</button>`).join('')}</div>
  ${c.formats.map((f, n) => `<div class="fmt ${n ? 'hidden' : ''}" data-fmt="${f.d}">
    <div class="player">${f.exists ? `<video controls playsinline preload="none" poster="${f.poster}" src="${f.mp4}"></video>` : `<div class="missing">Not rendered yet (${f.px}).<code>bash marketing/${set.id}/build.sh ${c.file}</code></div>`}</div>
    <div class="links"><a href="${f.mp4}" download aria-disabled="${!f.exists}">scored mp4${f.exists ? ' · ' + f.kb + ' KB' : ''}</a><a href="${f.silent}" download aria-disabled="${!f.exists}">silent mp4</a><a href="${f.poster}" target="_blank" aria-disabled="${!f.exists}">poster</a><a href="#" class="sheet" data-src="${f.contact}" aria-disabled="${!f.exists}">contact sheet</a><span class="muted">${f.px}</span></div>
  </div>`).join('')}
  <div class="placement">Placements: ${esc(c.placement)}</div>
  <details><summary>Beat sheet (${c.beats.length} shots)</summary><table class="beats"><tr><th>t</th><th>dur</th><th>scene</th><th>look</th><th>label</th></tr>${c.beats.map(b => `<tr><td>${esc(b.t)}</td><td>${esc(b.dur)}</td><td>${esc(b.scene)}</td><td>${esc(b.look || '')}</td><td>${esc(b.label || b['what happens'] || '')}</td></tr>`).join('')}</table><p class="muted" style="font-size:12px">Source: <a href="${set.id}/${c.file}.html">${set.id}/${c.file}.html</a> (open it in a browser to scrub and play with sound)</p></details>
</article>`;

const assetCard = a => { const dark = a.variant === 'dark' || a.key.startsWith('celestial/bg_night') || a.key.includes('night'); const thumb = a.sprite ? `<div class="sprite" style="background-image:url('assets/${a.file}')"></div>` : `<img loading="lazy" src="assets/${a.file}" alt="${esc(a.name)}">`;
  return `<div class="asset" data-search="${esc(a.name + ' ' + a.key + ' ' + a.desc + ' ' + a.source)}"><div class="thumb ${dark ? 'dark' : ''}">${thumb}</div><div class="name">${esc(a.name)}</div><div class="meta">${a.w} x ${a.h} · ${a.kb} KB · ${esc(a.variant)}${a.alpha ? ' · alpha' : ''}</div><div class="meta" title="source in the app">${esc(a.source)}</div><button data-copy="marketing/assets/${esc(a.file)}">copy path</button></div>`; };

const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>LifeBoard marketing</title><style>${css}</style></head>
<body><div class="wrap">
<header><img src="assets/brand/icon.png" alt="LifeBoard icon"><div><h1>LifeBoard marketing</h1><div class="muted">Launch films and the artwork they are made of. One place to run the life you actually have.</div>
<div class="kpis"><span class="kpi">${totalFilms} cuts</span><span class="kpi">${rendered} of ${totalFilms * 3} renders present</span><span class="kpi">${manifest.length} assets in ${families.length} families</span><span class="kpi">Built ${new Date().toISOString().slice(0, 16).replace('T', ' ')}</span></div></div></header>
<nav class="top"><a href="#films">Films</a>${films.map(s => `<a href="#set-${s.id}">${esc(s.title.split(': ')[1])}</a>`).join('')}<a href="#assets">Assets</a><a href="#copy">Copy deck</a><a href="#render">How to render</a><input id="q" type="search" placeholder="Filter films and assets"></nav>

<h2 id="films">Films</h2>
<p class="concept muted">Every cut renders in three formats from the same code: 9:16 for Reels, TikTok, Shorts and the App Store; 16:9 for the site and YouTube; 1:1 for feeds. Each has a scored and a silent version, a poster frame and a contact sheet.</p>
${films.map(s => `<section class="set" id="set-${s.id}"><h2>${esc(s.title)}</h2><p class="concept">${esc(s.concept)}</p><div class="cards">${s.cuts.map(c => filmCard(s, c)).join('')}</div></section>`).join('')}

<h2 id="assets">Assets</h2>
<p class="concept muted">Curated copies of the app's own artwork for future marketing work, downsized to 1254 px at most, with the source path inside the Xcode asset catalog. Regenerate with <code>node marketing/tools/curate-assets.mjs</code>.</p>
${families.map(f => `<section id="fam-${f.id}"><h3>${esc(f.title)} <span class="muted" style="font-size:14px;font-family:inherit;font-weight:400">${f.items.length}</span></h3><p class="muted" style="margin:0 0 10px">${esc(f.desc)}</p><div class="grid">${f.items.map(assetCard).join('')}</div></section>`).join('')}

<h2 id="copy">Copy deck</h2>
<p class="concept muted">Every on-screen line per cut, in order, for captions, alt text and ad copy. Brand line: <b>LifeBoard. One place to run the life you actually have.</b> Call to action: <b>On the App Store.</b></p>
<div class="deck">${films.map(s => s.cuts.map(c => `<div class="card"><h3>${esc(s.title.split(': ')[1])} · ${esc(c.name)} <span class="len">${esc(c.len)}</span></h3><ol>${c.copy.map(l => `<li><span class="t">${esc(l.t)}</span>${esc(l.text)}</li>`).join('')}</ol></div>`).join('')).join('')}</div>

<h2 id="render">How to render</h2>
<pre>cd marketing
bash build-all.sh                         # curate assets, build both sets in 3 formats, rebuild this page
bash teaser/build.sh advert-30s           # one film of set one
node teaser/render.mjs teaser/advert-30s.html --grid 24 --ar 9:16 --out teaser/out/grid   # a 24-frame sheet in seconds
node tools/build-catalog.mjs              # rebuild this page after any render</pre>
<p class="muted">Needs Node 18+, ffmpeg and a Chromium; the scripts default to Playwright's Chrome for Testing on this Mac (set <code>CHROME</code> to override). Films are drawn at 12 fps on twos and packed to 24 fps with the hand-drawn-canvas-animation skill; the score is Web Audio written from the same timeline. Outputs live in each set's gitignored <code>out/final</code>.</p>
<footer>LifeBoard marketing catalog. Built by <code>marketing/tools/build-catalog.mjs</code>.</footer>
</div>
<dialog id="sheet"><img alt="contact sheet"><form method="dialog"><button>close</button></form></dialog>
<script>
document.querySelectorAll('.film').forEach(card => { card.querySelectorAll('.tabs button').forEach(b => b.addEventListener('click', () => { card.querySelectorAll('.tabs button').forEach(x => x.setAttribute('aria-selected', x === b)); card.querySelectorAll('.fmt').forEach(f => f.classList.toggle('hidden', f.dataset.fmt !== b.dataset.fmt)); card.querySelectorAll('video').forEach(v => v.pause()); })); });
document.querySelectorAll('a.sheet').forEach(a => a.addEventListener('click', e => { e.preventDefault(); if (a.getAttribute('aria-disabled') === 'true') return; const d = document.getElementById('sheet'); d.querySelector('img').src = a.dataset.src; d.showModal(); }));
document.querySelectorAll('button[data-copy]').forEach(b => b.addEventListener('click', async () => { try { await navigator.clipboard.writeText(b.dataset.copy); b.textContent = 'copied'; setTimeout(() => b.textContent = 'copy path', 1200); } catch { prompt('Path', b.dataset.copy); } }));
const q = document.getElementById('q'); q.addEventListener('input', () => { const s = q.value.trim().toLowerCase(); document.querySelectorAll('[data-search]').forEach(el => el.classList.toggle('hidden', !!s && !el.dataset.search.toLowerCase().includes(s))); });
</script></body></html>`;
writeFileSync(path.join(M, 'index.html'), html);
console.log(`catalog: ${path.join(M, 'index.html')} (${totalFilms} cuts, ${rendered} renders, ${manifest.length} assets)`);
