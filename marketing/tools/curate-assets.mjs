// Curate the app artwork the marketing films use into marketing/assets/<family>/ and write manifest.json + manifest.js.
// Usage: node marketing/tools/curate-assets.mjs        (idempotent: skips files whose copy is newer than the source)
import { existsSync, mkdirSync, copyFileSync, statSync, writeFileSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const HERE = path.dirname(fileURLToPath(import.meta.url)), ROOT = path.resolve(HERE, '..', '..'), OUT = path.resolve(HERE, '..', 'assets');
const X = p => path.join(ROOT, 'LifeBoard/Assets.xcassets', p);
const size = f => { const o = execFileSync('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', f]).toString(); return [+/pixelWidth: (\d+)/.exec(o)[1], +/pixelHeight: (\d+)/.exec(o)[1]]; };
const cap = s => s.replace(/([A-Z])/g, ' $1').replace(/[_-]/g, ' ').replace(/\s+/g, ' ').trim().replace(/^./, c => c.toUpperCase());
const ITEMS = [];
const add = (family, key, src, o = {}) => ITEMS.push({ family, key, src, ...o });
// celestial: six discs (@2x) and six backgrounds (1x only)
for (const ph of ['Dawn', 'Morning', 'Midday', 'GoldenHour', 'Twilight', 'Night']) {
  add('celestial', `disc_${ph.toLowerCase()}`, X(`CelestialAtmospheres/Celestial${ph}.imageset/Celestial${ph}@2x.png`), { name: `${cap(ph)} ${ph === 'Twilight' || ph === 'Night' ? 'moon' : 'sun'}`, desc: `Felt-textured celestial disc for the ${cap(ph).toLowerCase()} phase (LifeBoardAtmosphereRenderer)`, alpha: true });
  add('celestial', `bg_${ph.toLowerCase()}`, X(`CelestialAtmospheres/Celestial${ph}Background.imageset/Celestial${ph}Background.png`), { name: `${cap(ph)} dunes`, desc: `Layered dune landscape behind the ${cap(ph).toLowerCase()} disc`, alpha: false });
}
// headers: 17 ambient surfaces, light + dark @2x
for (const d of readdirSync(X('AmbientSurfaces')).filter(n => n.endsWith('.imageset'))) { const k = d.replace('AmbientSurface_', '').replace('Header.imageset', '');
  for (const v of ['light', 'dark']) add('headers', `${k}_${v}`, X(`AmbientSurfaces/${d}/${v}@2x.png`), { name: `${cap(k)} header (${v})`, desc: `Torn-edge watercolour header for the ${cap(k).toLowerCase()} surface`, variant: v, alpha: true }); }
// scenes: 22 home card scenes, light + dark @2x
for (const d of readdirSync(X('HomeCardScenes')).filter(n => n.endsWith('.imageset'))) { const k = d.replace('HomeCardScene_', '').replace('.imageset', '');
  for (const v of ['light', 'dark']) add('scenes', `${k}_${v}`, X(`HomeCardScenes/${d}/${v}@2x.png`), { name: `${cap(k)} scene (${v})`, desc: `Painted home-card vignette for ${cap(k).toLowerCase()}`, variant: v, alpha: true }); }
// decor stickers
for (const d of readdirSync(X('SunriseDecor')).filter(n => n.endsWith('.imageset'))) { const k = d.replace('.imageset', ''); add('decor', k.replace(/^(sunrise|rescue)_decor_/, ''), X(`SunriseDecor/${d}/${k}.png`), { name: cap(k.replace(/^(sunrise|rescue)_decor_/, '')), desc: `${k.startsWith('rescue') ? '3D' : 'Watercolour'} decor sticker from ${k.startsWith('rescue') ? 'overdue rescue' : 'sunrise onboarding'}`, alpha: true }); }
// strips, postcards, brand, hero
add('strips', 'morning', X('routine_morning_strip.imageset/Morning_Strip.png'), { name: 'Morning strip', desc: 'Watercolour sunrise strip for morning routines', alpha: true });
add('strips', 'evening', X('routine_evening_strip.imageset/Evening_Strip.png'), { name: 'Evening strip', desc: 'Crescent moon, candle and mug strip for evening routines', alpha: true });
for (let k = 1; k <= 6; k++) add('postcards', `card0${k}`, X(`TaskCard0${k}.imageset/TaskCard0${k}@2x.png`), { name: `Task card 0${k}`, desc: 'Watercolour task-card scene', alpha: false });
add('brand', 'icon', X('AppIcon.appiconset/AppStoreIcon.png'), { name: 'App icon', desc: 'The LifeBoard icon: black profile, white square eye, colour grid', alpha: false });
add('brand', 'icon_white', X('AppIcon_WHITE.appiconset/AppStoreIcon.png'), { name: 'App icon (light)', desc: 'Light variant of the icon', alpha: false });
add('brand', 'logo', X('LifeBoardLogo.imageset/LifeBoardLogo@3x.png'), { name: 'Logo mark', desc: 'Small in-app logo mark', alpha: true });
add('brand', 'icon_svg', path.join(ROOT, 'LifeBoard_Icon Abstract_Face.svg'), { name: 'Icon (vector)', desc: 'Vector source of the icon', alpha: false, ext: '.svg' });
add('hero', 'welcome', X('HeroWelcomePoster.imageset/HeroWelcomePoster.jpg'), { name: 'Welcome poster', desc: 'Woman reading above a cloud sea at dusk (hero video poster)', alpha: false, ext: '.jpg', max: 1254 });
// companions: pixel sprite sheets (8 cols x 9 rows, 192x208 cells)
for (const p of ['Cloudlet', 'Dude', 'Friday', 'Punch', 'Sato', 'Elon', 'Steve', 'YesMan']) { const dir = path.join(ROOT, 'LifeBoard/Features/Eva/MascotSprites', p); const meta = JSON.parse(execFileSync('cat', [path.join(dir, 'pet.json')]).toString());
  add('companions', p.toLowerCase(), path.join(dir, 'spritesheet.webp'), { name: meta.displayName || p, desc: meta.description || '', alpha: true, ext: '.png', convert: true, sprite: { cols: 8, rows: 9, cell: [192, 208], rowNames: ['idle', 'runRight', 'runLeft', 'waving', 'jumping', 'failed', 'waiting', 'running', 'review'], frames: [6, 8, 8, 4, 5, 8, 6, 6, 6] } }); }

const manifest = []; let copied = 0;
for (const it of ITEMS) {
  if (!existsSync(it.src)) { console.warn('missing', it.src); continue; }
  const ext = it.ext || '.png', file = `${it.family}/${it.key}${ext}`, dest = path.join(OUT, file); mkdirSync(path.dirname(dest), { recursive: true });
  const fresh = existsSync(dest) && statSync(dest).mtimeMs >= statSync(it.src).mtimeMs;
  if (!fresh) { if (it.convert) execFileSync('sips', ['-s', 'format', 'png', it.src, '--out', dest], { stdio: 'ignore' }); else copyFileSync(it.src, dest); if (it.max && ext !== '.svg') execFileSync('sips', ['-Z', String(it.max), dest], { stdio: 'ignore' }); copied++; }
  const [w, h] = ext === '.svg' ? [1254, 1254] : size(dest);
  manifest.push({ key: `${it.family}/${it.key}`, family: it.family, name: it.name, file, w, h, variant: it.variant || 'single', alpha: !!it.alpha, kb: Math.round(statSync(dest).size / 1024), source: path.relative(ROOT, it.src), desc: it.desc || '', ...(it.sprite ? { sprite: it.sprite } : {}) });
}
writeFileSync(path.join(OUT, 'manifest.json'), JSON.stringify(manifest, null, 1));
writeFileSync(path.join(OUT, 'manifest.js'), 'window.LB_MANIFEST = ' + JSON.stringify(manifest) + ';\n');
console.log(`${manifest.length} assets, ${copied} copied/updated -> ${OUT}`);
