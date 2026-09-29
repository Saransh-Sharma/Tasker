'use strict';
// ============================================================
// LifeBoard launch films: shared palettes, puppets, glyphs, scenes and score motifs.
// Loads after core.js (hand-drawn-canvas-animation skill). Films (bumper-6s, teaser-10s,
// advert-30s, launch-45s) declare their own TIMELINE and score and call defineFilm().
//
// Concept: "A real day, drawn." A day scattered across scraps folds into one calm place;
// the app asks LifeBoard's own questions; the plan breaks and EVA helps recover without
// a score; the sun that rose in shot one lands as the icon's eye.
// Anchor: the sun dot. It is in every shot.
// Rules: paper first, seeded rng only, texture is a finish, one label per shot, hard cuts.
// ============================================================

// ===================== BRAND VALUES (DESIGN.md / LifeBoardTokens) =====================
const LB = {
  canvas: '#FFF7D8', surface: '#FBF3E2', recessed: '#F2E6C4', ink: '#2B2118', sun: '#F0CD87', apricot: '#E7BB7E',
  sage: '#5D6A4D', violet: '#6842FF', shadow: '#6B5130', night: '#151B2D', parchment: '#F7F1E7', dimline: '#777C9B',
  light: '#FFFDF7',
  day: { morning: { paper: '#FFF9E4', sun: '#F7D98E', blush: '#E7BB7E' }, afternoon: { paper: '#FFF2C9', sun: '#F3C45F', blush: '#E68F4E' }, evening: { paper: '#FBEBD6', sun: '#E68F4E', blush: '#D98A5E' } },
  nightSun: '#F3E6C8',
  areas: { work: '#C68A64', home: '#C2A35D', health: '#7A956D', relationships: '#B57C84', learning: '#7287A8', creativity: '#8B7EAF', money: '#A68C55' },
  icon: { blue: '#1E8BFF', orange: '#FF6A1A', yellow: '#FFD028', purple: '#6842FF' },
};

// ===================== PALETTES =====================
const lbPaper = makePalette({
  paper: LB.canvas, paperBand: 'rgba(255,243,210,.65)', ink: LB.ink, night: LB.night, chalk: LB.parchment, chalkDim: LB.dimline,
  guide: 'rgba(104,66,255,.45)',
  fills: [LB.sun, LB.apricot, LB.recessed, LB.areas.work, LB.areas.health, LB.areas.learning, LB.areas.creativity],
  shade: LB.shadow, light: LB.light, blush: LB.day.evening.sun,
  accents: [LB.violet, '#F0B944', LB.areas.relationships, LB.sage], inks: [LB.ink, LB.day.evening.sun, LB.violet], finish: 'ink',
}, 'paperInk');
const daypart = k => makePalette({ paper: LB.day[k].paper, blush: LB.day[k].blush, fills: [LB.day[k].sun, ...lbPaper.fills.slice(1)] }, lbPaper);
const lbMorning = daypart('morning'), lbAfternoon = daypart('afternoon'), lbEvening = daypart('evening');
const lbNight = makePalette({
  paper: LB.night, paperBand: null, night: LB.night, ink: LB.parchment, chalk: LB.parchment, chalkDim: LB.dimline, guide: 'rgba(168,144,255,.6)',
  fills: ['#24243B', '#343754', '#4D526D', '#3A3D5E'], shade: '#777C9B', light: '#FFFFFF', blush: '#A890FF',
  accents: ['#A890FF', LB.nightSun, '#C8B7D5', '#D8BD7A'], inks: [LB.parchment, '#A890FF'], finish: 'ink',
}, 'blueprintNight');
const lbRiso = makePalette({
  paper: LB.canvas, paperBand: null, ink: LB.ink, night: LB.night, chalk: LB.light, chalkDim: LB.dimline, guide: 'rgba(43,33,24,.4)',
  fills: [LB.icon.blue, LB.icon.orange, LB.icon.yellow, LB.icon.purple, LB.sun, LB.sage], shade: LB.ink, light: LB.light, blush: LB.icon.orange,
  accents: [LB.icon.orange, LB.icon.blue, LB.icon.yellow, LB.icon.purple], inks: [LB.icon.blue, LB.icon.orange, LB.icon.yellow, LB.icon.purple, LB.ink], finish: 'riso',
}, 'risoPop');
const lbPencil = makePalette({
  paper: LB.surface, paperBand: null, ink: LB.ink, night: '#27251F', chalk: '#D9D2C2', chalkDim: '#7D786C', guide: 'rgba(43,33,24,.35)',
  fills: ['#F6E4DC', '#E6EAD9', LB.recessed, LB.surface], shade: '#5E5A50', light: '#FFFFFF', blush: '#C9A9A0',
  accents: [LB.areas.relationships, LB.areas.health, LB.areas.home, LB.violet], inks: [LB.ink, LB.areas.health], finish: 'pencil',
}, 'pencilMinimal');
const lbDuotone = duotone(LB.violet, LB.sun, LB.canvas);

// ===================== LAYOUT (never a literal pixel in a scene) =====================
// The short side is always 1080 logical units, so sizes are absolute; positions come from here.
function LAYOUT() {
  const tall = H > W;
  return {
    tall,
    stageTop: CY - 540, stageBottom: CY + 540,
    safeTop: tall ? H * .10 : 40, safeBottom: tall ? H * .84 : H - 40,
    labelY: Math.min(CY + 600, H - 64),                       // baseline of the shot's one label
    labelSize: 64,
    sunTop: Math.max(96, CY - 470),
    sunPos(t) { const x = CX + (t - .5) * W * .82, y = this.sunTop + (1 - Math.sin(Math.PI * clamp(t, 0, 1))) * 170; return [x, y]; },
  };
}
const isNight = () => PAL.paper === LB.night;

// ===================== SMALL HELPERS =====================
const rr = (c, x, y, w, h, r) => roundRectPath(x, y, w, h, r);
const rrPts = (x, y, w, h, r, n = 8) => { const p = []; const arc = (cx, cy, a0) => { for (let k = 0; k <= n; k++) { const a = a0 + k / n * Math.PI / 2; p.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
  arc(x + w - r, y + r, -Math.PI / 2); arc(x + w - r, y + h - r, 0); arc(x + r, y + h - r, Math.PI / 2); arc(x + r, y + r, Math.PI); return p; };
function inkShape(c, path, pts, box, o = {}) {   // fill -> surface -> wobbly outline. The whole ink pipeline for one part.
  const { fill = PAL.fills[2], seed = 1, width = 2.2, alpha: al, gap, len, grain: gr, color, line = PAL.ink, amp = 1.8, mode = 'ink' } = o;
  if (mode !== 'blueprint') { c.fillStyle = fill; c.fill(path); surface(c, path, box, { seed, alpha: al, gap, len, grain: gr, color }); c.strokeStyle = line; }
  else c.strokeStyle = PAL.chalk;
  c.lineWidth = mode === 'blueprint' ? 2.4 : width; c.lineJoin = 'round'; c.lineCap = 'round'; wob(c, pts, amp, seed + 7, true);
}
function castShadow(c, x, y, rx, ry, seed) { const p = ellPath(x, y, rx, ry); hatch(c, p, [x - rx, y - ry, rx * 2, ry * 2], { angle: .5, gap: 5, len: 14, jitter: 3, color: PAL.shade, alpha: .28, width: 1, seed }); }

// ===================== THE ANCHOR: the sun dot =====================
// By day: sun with a cocoa rim (sun on cream needs the rim to read). By night: parchment moon with a violet offset.
function sunDot(c, x, y, r = 18, o = {}) {
  const nightMode = o.night ?? isNight(); c.save();
  if (nightMode) { seedDot(c, x, y, r, PAL.chalk, PAL.accents[0]); }
  else { const col = o.color ?? (PAL.finish === 'riso' || PAL.finish === 'pencil' ? LB.sun : PAL.fills[0]); seedDot(c, x, y, r, col, o.offset ?? (PAL.finish === 'riso' ? LB.icon.orange : PAL.blush)); c.strokeStyle = PAL.ink; c.lineWidth = 2; c.globalAlpha = .9; wob(c, ellPts(x, y, r, r, 0, 36), 1.4, 900 + Math.round(r), true); }
  c.restore();
}
function sunRays(c, x, y, r, g, seed, color = PAL.blush) { const rn = rng(seed); c.save(); c.strokeStyle = color; c.globalAlpha = .6 * g; c.lineWidth = 1.6; c.lineCap = 'round';
  for (let k = 0; k < 18; k++) { const a = k / 18 * TAU + (rn() - .5) * .2, r0 = r * 1.5, r1 = r * (2.2 + rn() * 1.4) * g; c.beginPath(); c.moveTo(x + Math.cos(a) * r0, y + Math.sin(a) * r0); c.lineTo(x + Math.cos(a) * r1, y + Math.sin(a) * r1); c.stroke(); } c.restore(); }

// ===================== THE ONE LABEL PER SHOT =====================
function label(c, text, tau, t0 = .15, o = {}) {
  const L = LAYOUT(), p = sm(t0, t0 + .5, tau, easeOut); if (p <= 0) return;
  const t = text.slice(0, Math.round(text.length * p)), nightMode = o.night ?? isNight();
  handText(c, t, o.x ?? CX, o.y ?? L.labelY, { size: o.size ?? L.labelSize, ink: nightMode ? PAL.chalk : PAL.ink, ink2: nightMode ? PAL.accents[0] : PAL.fills[0], offset: 3, align: 'center' });
}

// ===================== PUPPET: EVA =====================
// Local coords, origin at body centre, up = -y, ~230 px tall at scale 1.
// pose: { arm 0..1 (rest -> pointing up), tilt, blink 0|1, bob, run 0..1 (leg phase), jump 0..1, spark 0..1, happy 0|1 }
const EVA_G = { head: [-78, -172, 156, 118, 52], visor: [-60, -156, 120, 78, 30], body: [-52, -58, 104, 108, 44], eyeL: [-32, -134, 16, 34, 8], eyeR: [16, -134, 16, 34, 8] };
function drawEva(c, mode, pose = {}, seed = 40) {
  const { arm = 0, tilt = 0, blink = 0, bob = 0, run = 0, jump = 0, spark = 0, happy = 0 } = pose, bp = mode === 'blueprint', line = bp ? PAL.chalk : PAL.ink;
  c.save(); c.rotate(tilt); c.translate(0, bob - jump * 90); c.lineJoin = 'round'; c.lineCap = 'round';
  // shadow
  if (!bp) castShadow(c, 0, 78 + jump * 90, 70 - jump * 20, 12, seed + 1);
  // feet (run: alternate)
  const fl = run ? Math.sin(run * TAU) * 22 : 0;
  for (const s of [-1, 1]) { const fx = s * 30 + (s < 0 ? fl : -fl) * .5, fy = 66 - Math.abs(s < 0 ? fl : -fl) * .35; const fp = ellPath(fx, fy, 24, 11);
    if (!bp) { c.fillStyle = PAL.light; c.fill(fp); surface(c, fp, [fx - 24, fy - 11, 48, 22], { seed: seed + 2 + s, alpha: .22, grain: 20 }); }
    c.strokeStyle = line; c.lineWidth = bp ? 2.2 : 2.2; wob(c, ellPts(fx, fy, 24, 11, 0, 24), 1.4, seed + 3 + s, true); }
  // left arm (rests / swings when running)
  c.strokeStyle = line; c.lineWidth = bp ? 2.4 : 7;
  const swing = run ? Math.cos(run * TAU) * 26 : 0;
  wob(c, [[-48, -22], [-70, 8 + swing * .4], [-66, 34 + swing]], 1.6, seed + 5);
  if (!bp) { c.strokeStyle = PAL.light; c.lineWidth = 4; wob(c, [[-48, -22], [-70, 8 + swing * .4], [-66, 34 + swing]], 1.2, seed + 5); c.strokeStyle = line; }
  // body
  const bpath = rr(c, ...EVA_G.body); inkShape(c, bpath, rrPts(...EVA_G.body), [-52, -58, 104, 108], { fill: PAL.light, seed: seed + 6, mode, alpha: .16, gap: 5, len: 10, grain: 60 });
  // right arm: pointing up when arm=1
  const hx = lerp(70, 78, arm), hy = lerp(22 - swing, -150, arm), ex = lerp(72, 96, arm), ey = lerp(-4, -70, arm);
  c.strokeStyle = line; c.lineWidth = bp ? 2.4 : 7; wob(c, [[48, -22], [ex, ey], [hx, hy]], 1.6, seed + 7);
  if (!bp) { c.strokeStyle = PAL.light; c.lineWidth = 4; wob(c, [[48, -22], [ex, ey], [hx, hy]], 1.2, seed + 7); c.strokeStyle = line; c.lineWidth = 2; }
  if (!bp) { const hand = ellPath(hx, hy, 9, 9); c.fillStyle = PAL.light; c.fill(hand); c.strokeStyle = line; c.lineWidth = 2; c.stroke(hand); }
  // ears
  for (const s of [-1, 1]) { const ep = ellPath(s * 84, -112, 8, 15); if (!bp) { c.fillStyle = PAL.light; c.fill(ep); } c.strokeStyle = line; c.lineWidth = 2; wob(c, ellPts(s * 84, -112, 8, 15, 0, 20), 1, seed + 8 + s, true); }
  // head
  const hpath = rr(c, ...EVA_G.head); inkShape(c, hpath, rrPts(...EVA_G.head), [-78, -172, 156, 118], { fill: PAL.light, seed: seed + 10, mode, alpha: .14, gap: 5, len: 10, grain: 60, width: 2.4 });
  // visor
  const vpath = rr(c, ...EVA_G.visor);
  if (!bp) { c.fillStyle = PAL.ink; c.fill(vpath); grain(c, vpath, EVA_G.visor.slice(0, 4), 120, PAL.chalkDim, .35, seed + 11, 1.6); }
  c.strokeStyle = line; c.lineWidth = bp ? 2 : 2.4; wob(c, rrPts(...EVA_G.visor), 1.4, seed + 12, true);
  // eyes (pills; blink squashes; happy = arcs)
  for (const k of ['eyeL', 'eyeR']) { const [x, y, w, h, r] = EVA_G[k]; if (happy) { c.strokeStyle = bp ? PAL.chalk : PAL.light; c.lineWidth = 5; c.beginPath(); c.arc(x + w / 2, y + h * .6, w * .9, Math.PI * 1.1, Math.PI * 1.9); c.stroke(); continue; }
    const hh = blink ? 4 : h, yy = y + (h - hh) / 2, ep = rr(c, x, yy, w, hh, Math.min(r, hh / 2)); c.fillStyle = bp ? PAL.chalk : PAL.light; c.fill(ep); }
  // sparkle
  if (spark > 0) { const sx = 118, sy = -196; c.save(); c.globalAlpha = spark; c.fillStyle = bp ? PAL.chalk : PAL.fills[0]; c.strokeStyle = line; c.lineWidth = 1.6; const s = 22 * spark, p = new Path2D();
    for (let k = 0; k < 8; k++) { const a = k / 8 * TAU - Math.PI / 2, d = k % 2 ? s * .35 : s; k ? p.lineTo(sx + Math.cos(a) * d, sy + Math.sin(a) * d) : p.moveTo(sx + Math.cos(a) * d, sy + Math.sin(a) * d); } p.closePath(); c.fill(p); c.stroke(p); c.restore(); }
  c.restore();
}

// ===================== GLYPHS (feature marks, drawn) =====================
// Each draws centred at the origin inside ±s. mode 'ink' fills, 'blueprint' outlines in chalk, 'plate' fills black (for riso coverage).
function glyphStroke(c, mode) { c.strokeStyle = mode === 'blueprint' ? PAL.chalk : mode === 'plate' ? '#000' : PAL.ink; c.fillStyle = mode === 'plate' ? '#000' : mode === 'blueprint' ? 'transparent' : PAL.fills[2]; c.lineWidth = mode === 'plate' ? 10 : 3; c.lineJoin = 'round'; c.lineCap = 'round'; }
const GLYPHS = {
  home(c, mode, s, seed = 1) { glyphStroke(c, mode); const pts = [[-s * .8, 0], [0, -s * .85], [s * .8, 0], [s * .6, 0], [s * .6, s * .8], [-s * .6, s * .8], [-s * .6, 0]]; if (mode !== 'blueprint') c.fill(polyPath(pts)); wob(c, pts, 2, seed, true); c.lineWidth = mode === 'plate' ? 10 : 2.4; wob(c, [[-s * .15, s * .8], [-s * .15, s * .25], [s * .15, s * .25], [s * .15, s * .8]], 1.5, seed + 1); },
  plan(c, mode, s, seed = 1) { glyphStroke(c, mode); const b = [-s * .8, -s * .7, s * 1.6, s * 1.5]; if (mode !== 'blueprint') c.fill(rr(c, ...b, s * .18)); wob(c, rrPts(...b, s * .18), 2, seed, true); wob(c, [[-s * .8, -s * .3], [s * .8, -s * .3]], 1.5, seed + 1);
    for (let r = 0; r < 2; r++) for (let k = 0; k < 4; k++) { const x = -s * .55 + k * s * .37, y = s * .05 + r * s * .38; c.beginPath(); c.arc(x, y, s * .08, 0, TAU); if (mode === 'blueprint') c.stroke(); else { c.fillStyle = mode === 'plate' ? '#000' : PAL.ink; c.fill(); } } },
  track(c, mode, s, seed = 1) { glyphStroke(c, mode); [[-s * .75, s * .1, s * .35, s * .7], [-s * .18, -s * .3, s * .35, s * 1.1], [s * .4, -s * .75, s * .35, s * 1.55]].forEach((b, k) => { if (mode !== 'blueprint') { c.fillStyle = mode === 'plate' ? '#000' : PAL.fills[[0, 4, 1][k]]; c.fill(rectPath(...b)); } wob(c, [[b[0], b[1]], [b[0] + b[2], b[1]], [b[0] + b[2], b[1] + b[3]], [b[0], b[1] + b[3]]], 2, seed + k, true); }); },
  insights(c, mode, s, seed = 1) { glyphStroke(c, mode); const star = (x, y, r) => { const p = new Path2D(); for (let k = 0; k < 8; k++) { const a = k / 8 * TAU - Math.PI / 2, d = k % 2 ? r * .38 : r; k ? p.lineTo(x + Math.cos(a) * d, y + Math.sin(a) * d) : p.moveTo(x + Math.cos(a) * d, y + Math.sin(a) * d); } p.closePath(); return p; };
    if (mode !== 'blueprint') { c.fillStyle = mode === 'plate' ? '#000' : PAL.fills[0]; c.fill(star(-s * .15, s * .1, s * .8)); c.fill(star(s * .55, -s * .55, s * .35)); } c.stroke(star(-s * .15, s * .1, s * .8)); c.stroke(star(s * .55, -s * .55, s * .35)); },
  eva(c, mode, s, seed = 1) { glyphStroke(c, mode); const b1 = [-s * .85, -s * .6, s * 1.1, s * .8], b2 = [-s * .25, -s * .05, s * 1.1, s * .8]; for (const [b, k] of [[b1, 0], [b2, 1]]) { if (mode !== 'blueprint') { c.fillStyle = mode === 'plate' ? '#000' : k ? PAL.fills[0] : PAL.fills[2]; c.fill(rr(c, ...b, s * .3)); } wob(c, rrPts(...b, s * .3), 2, seed + k, true); const tx = b[0] + (k ? b[2] * .8 : b[2] * .2); wob(c, [[tx - s * .1, b[1] + b[3]], [tx, b[1] + b[3] + s * .22], [tx + s * .1, b[1] + b[3]]], 1.5, seed + 3 + k); } },
  focus(c, mode, s, seed = 1) { glyphStroke(c, mode); c.lineWidth = mode === 'plate' ? 14 : 5; wob(c, ellPts(0, 0, s * .8, s * .8, 0, 60), 2, seed, true); c.lineWidth = mode === 'plate' ? 14 : 6; c.strokeStyle = mode === 'plate' ? '#000' : mode === 'blueprint' ? PAL.accents[0] : PAL.fills[0]; c.beginPath(); c.arc(0, 0, s * .8, -Math.PI / 2, Math.PI * .45); c.stroke(); sunDot(c, 0, 0, s * .14, { night: mode === 'blueprint' }); },
  journal(c, mode, s, seed = 1) { glyphStroke(c, mode); const b = [-s * .6, -s * .8, s * 1.2, s * 1.6]; if (mode !== 'blueprint') c.fill(rr(c, ...b, s * .1)); wob(c, rrPts(...b, s * .1), 2, seed, true); c.lineWidth = mode === 'plate' ? 8 : 2; for (let k = 0; k < 4; k++) wob(c, [[-s * .4, -s * .45 + k * s * .3], [s * .1 + (k % 2) * s * .25, -s * .45 + k * s * .3]], 1.2, seed + 1 + k);
    c.lineWidth = mode === 'plate' ? 12 : 4; c.strokeStyle = mode === 'plate' ? '#000' : mode === 'blueprint' ? PAL.chalk : PAL.fills[0]; wob(c, [[s * .2, s * .7], [s * .75, -s * .1]], 1.5, seed + 9); },
  everywhere(c, mode, s, seed = 1) { glyphStroke(c, mode); const ph = [-s * .85, -s * .55, s * .55, s * 1.1], tb = [-s * .15, -s * .8, s * 1.0, s * 1.35], wt = [s * .35, s * .15, s * .5, s * .6];
    for (const [b, r, k] of [[tb, s * .1, 0], [ph, s * .12, 1], [wt, s * .14, 2]]) { if (mode !== 'blueprint') { c.fillStyle = mode === 'plate' ? '#000' : PAL.fills[2]; c.fill(rr(c, ...b, r)); } wob(c, rrPts(...b, r), 2, seed + k, true); } },
};
const AREA_KEYS = ['work', 'home', 'health', 'relationships', 'learning', 'creativity', 'money'];
const AREA_GLYPH = {   // small marks for the seven life areas
  work(c, s) { c.stroke(rr(c, -s * .7, -s * .3, s * 1.4, s * .9, s * .1)); c.stroke(rr(c, -s * .25, -s * .6, s * .5, s * .3, s * .08)); },
  home(c, s) { const pts = [[-s * .7, 0], [0, -s * .7], [s * .7, 0], [s * .5, 0], [s * .5, s * .65], [-s * .5, s * .65], [-s * .5, 0]]; c.stroke(polyPath(pts)); },
  health(c, s) { c.beginPath(); c.moveTo(0, s * .6); c.bezierCurveTo(-s * 1.1, -s * .2, -s * .3, -s * .9, 0, -s * .3); c.bezierCurveTo(s * .3, -s * .9, s * 1.1, -s * .2, 0, s * .6); c.stroke(); },
  relationships(c, s) { for (const x of [-s * .3, s * .3]) { c.beginPath(); c.arc(x, -s * .15, s * .28, 0, TAU); c.stroke(); } c.beginPath(); c.arc(0, s * .55, s * .7, Math.PI * 1.15, Math.PI * 1.85); c.stroke(); },
  learning(c, s) { c.stroke(rr(c, -s * .7, -s * .5, s * .68, s * 1.0, s * .06)); c.stroke(rr(c, s * .02, -s * .5, s * .68, s * 1.0, s * .06)); },
  creativity(c, s) { c.beginPath(); c.moveTo(-s * .5, s * .6); c.lineTo(s * .4, -s * .5); c.lineTo(s * .6, -s * .3); c.lineTo(-s * .3, s * .8); c.closePath(); c.stroke(); },
  money(c, s) { c.beginPath(); c.arc(0, 0, s * .65, 0, TAU); c.stroke(); c.beginPath(); c.arc(0, 0, s * .4, 0, TAU); c.stroke(); },
};

// ===================== PUPPET: THE BOARD (the phone) =====================
// Local coords, centred. 420 x 820 at scale 1. Pieces are composable so scenes build Home / Plan / Track.
const BOARD = { w: 420, h: 820, r: 62 };
function boardFrame(c, mode, seed = 70, o = {}) {
  const { w, h, r } = BOARD, bp = mode === 'blueprint', box = [-w / 2, -h / 2, w, h], path = rr(c, ...box, r);
  if (!bp) { c.save(); c.fillStyle = alpha(PAL.shade, .16); c.fill(rr(c, -w / 2 + 6, -h / 2 + 10, w, h, r)); c.restore(); c.fillStyle = o.screen || PAL.paper; c.fill(path); grain(c, path, box, 500, PAL.shade, .05, seed, 1.5); }
  c.strokeStyle = bp ? PAL.chalk : PAL.ink; c.lineWidth = bp ? 2.4 : 3.2; c.lineJoin = 'round'; wob(c, rrPts(...box, r, 10), 2, seed + 1, true);
  c.lineWidth = bp ? 1.6 : 2; wob(c, rrPts(-40, -h / 2 + 16, 80, 16, 8), 1, seed + 2, true);   // island
}
function clayCard(c, x, y, w, h, seed, o = {}) {
  const { mode = 'ink', fill = PAL.fills[2], lift = 0, r = 26 } = o, bp = mode === 'blueprint', path = rr(c, x, y - lift, w, h, r);
  if (!bp) { c.save(); c.fillStyle = alpha(PAL.shade, .12 + lift * .01); c.fill(rr(c, x + 4, y + 8, w, h, r)); c.restore(); c.fillStyle = fill; c.fill(path); surface(c, path, [x, y - lift, w, h], { seed, alpha: .10, gap: 6, len: 12, grain: 40 });
    c.strokeStyle = alpha(PAL.light, .9); c.lineWidth = 1.2; wob(c, [[x + r, y - lift + 2], [x + w - r, y - lift + 2]], .6, seed + 3); }   // specular rim
  c.strokeStyle = bp ? PAL.chalk : PAL.ink; c.lineWidth = bp ? 1.8 : 2; wob(c, rrPts(x, y - lift, w, h, r), 1.6, seed + 1, true);
}
function checkRow(c, x, y, w, seed, o = {}) {
  const { done = 0, burst = 0, mode = 'ink' } = o, bp = mode === 'blueprint', line = bp ? PAL.chalk : PAL.ink;
  c.strokeStyle = line; c.lineWidth = 2.2; if (done && !bp) { c.fillStyle = PAL.fills[0]; c.fill(circPath(x + 16, y, 15)); } wob(c, ellPts(x + 16, y, 15, 15, 0, 26), 1.3, seed, true);
  if (done) { c.lineWidth = 3; wob(c, [[x + 8, y], [x + 14, y + 6], [x + 25, y - 7]], 1, seed + 1); }
  squiggleText(c, x + 46, y + 4, w - 60, 1, { seed: seed + 2, lineH: 14, amp: 3.5, width: 1.4, color: bp ? PAL.chalk : PAL.ink });
  if (burst > 0) dotBurst(c, x + 16, y, 46, 10, PAL.accents[1], seed + 4, burst);
}
function composer(c, x, y, w, seed, o = {}) { const { mode = 'ink' } = o, bp = mode === 'blueprint', h = 52, path = rr(c, x, y, w, h, 26);
  if (!bp) { c.fillStyle = PAL.light; c.fill(path); c.fillStyle = alpha(PAL.shade, .12); c.fill(rr(c, x + 3, y + 5, w, h, 26)); c.fillStyle = PAL.light; c.fill(path); }
  c.strokeStyle = bp ? PAL.chalk : PAL.ink; c.lineWidth = 2; wob(c, rrPts(x, y, w, h, 26), 1.4, seed, true);
  cross(c, x + 26, y + 26, 7); squiggleText(c, x + 48, y + 30, w - 120, 1, { seed: seed + 1, lineH: 12, amp: 3, width: 1.2, color: bp ? PAL.chalkDim : PAL.chalkDim });
  const ox = x + w - 26; if (!bp) { c.fillStyle = PAL.ink; c.fill(circPath(ox, y + 26, 18)); } else { c.stroke(circPath(ox, y + 26, 18)); }
  c.strokeStyle = bp ? PAL.chalk : PAL.light; c.lineWidth = 2; for (let k = -2; k <= 2; k++) { const hh = [6, 11, 15, 9, 5][k + 2]; c.beginPath(); c.moveTo(ox + k * 5, y + 26 - hh / 2); c.lineTo(ox + k * 5, y + 26 + hh / 2); c.stroke(); }
}
function dock(c, x, y, w, seed, o = {}) { const { active = 0, mode = 'ink' } = o, bp = mode === 'blueprint', path = rr(c, x, y, w, 58, 29);
  if (!bp) { c.fillStyle = PAL.light; c.fill(path); } c.strokeStyle = bp ? PAL.chalk : PAL.ink; c.lineWidth = 2; wob(c, rrPts(x, y, w, 58, 29), 1.4, seed, true);
  ['home', 'plan', 'track', 'insights', 'eva'].forEach((k, n) => { const gx = x + w * (n + .5) / 5, gy = y + 29; if (n === active && !bp) { c.fillStyle = PAL.fills[0]; c.fill(rr(c, gx - 30, gy - 20, 60, 40, 20)); } c.save(); c.translate(gx, gy); GLYPHS[k](c, bp ? 'blueprint' : 'ink', 11, seed + n); c.restore(); });
}
function handGlyph(c, x, y, s, color) { c.save(); c.strokeStyle = color; c.lineWidth = 1.6; c.lineCap = 'round'; c.beginPath(); c.arc(x, y + s * .2, s * .45, 0, TAU); c.stroke(); for (let k = -1; k <= 2; k++) { c.beginPath(); c.moveTo(x + k * s * .28, y); c.lineTo(x + k * s * .28, y - s * .75 + Math.abs(k - .5) * s * .12); c.stroke(); } c.restore(); }
function signalRings(c, x, y, seed, o = {}) {   // one filled (evidence), two honestly empty (dashed, a hand)
  const { p = .7, mode = 'ink' } = o, bp = mode === 'blueprint', line = bp ? PAL.chalk : PAL.ink;
  [0, 1, 2].forEach(k => { const cx = x + k * 96; if (k === 0) { c.strokeStyle = bp ? PAL.chalk : PAL.fills[2]; c.lineWidth = 7; c.beginPath(); c.arc(cx, y, 32, 0, TAU); c.stroke(); c.strokeStyle = bp ? PAL.accents[0] : PAL.shade; c.beginPath(); c.arc(cx, y, 32, -Math.PI / 2, -Math.PI / 2 + TAU * p); c.stroke(); sunDot(c, cx, y, 9, { night: bp }); }
    else { dashedRing(c, cx, y, 32, bp ? PAL.chalkDim : PAL.shade, seed + k, [5, 7], 2.2); handGlyph(c, cx, y + 4, 16, bp ? PAL.chalkDim : PAL.shade); } });
}
function timeCanvas(c, x, y, w, h, seed, o = {}) {   // hour lines and blocks; blocks: [{t0, t1, col, slide, tomorrow}]
  const { blocks = [], mode = 'ink', hours = 6 } = o, bp = mode === 'blueprint', line = bp ? PAL.chalk : PAL.ink;
  c.strokeStyle = bp ? PAL.chalkDim : alpha(PAL.ink, .35); c.lineWidth = 1.2; for (let k = 0; k <= hours; k++) { const yy = y + k * h / hours; wob(c, [[x, yy], [x + w, yy]], .8, seed + k); c.lineWidth = 2; c.strokeStyle = line; wob(c, [[x - 18, yy], [x - 8, yy]], .6, seed + 20 + k); c.lineWidth = 1.2; c.strokeStyle = bp ? PAL.chalkDim : alpha(PAL.ink, .35); }
  blocks.forEach((b, k) => { const y0 = y + b.t0 * h / hours, y1 = y + b.t1 * h / hours, bx = x + 10 + (b.slide ?? 0) * (w + 60), bw = w - 20, path = rr(c, bx, y0 + 3, bw, y1 - y0 - 6, 10);
    if (!bp) { c.fillStyle = b.col || PAL.fills[1]; c.globalAlpha = b.alpha ?? 1; c.fill(path); surface(c, path, [bx, y0, bw, y1 - y0], { seed: seed + 40 + k, alpha: .16, gap: 5, len: 10, grain: 20 }); c.globalAlpha = 1; c.fillStyle = PAL.ink; c.fillRect(bx, y0 + 6, 5, y1 - y0 - 12); }
    c.strokeStyle = line; c.lineWidth = 1.8; wob(c, rrPts(bx, y0 + 3, bw, y1 - y0 - 6, 10), 1.2, seed + 60 + k, true); squiggleText(c, bx + 18, y0 + 24, bw * .6, 1, { seed: seed + 80 + k, lineH: 10, amp: 2.5, width: 1.1, color: line }); });
}
function capacityArc(c, x, y, r, p, seed, o = {}) { const { mode = 'ink' } = o, bp = mode === 'blueprint';
  c.save(); c.setLineDash([6, 8]); c.strokeStyle = bp ? PAL.chalkDim : PAL.fills[1]; c.lineWidth = 2.5; c.beginPath(); c.arc(x, y, r, Math.PI, TAU); c.stroke(); c.restore();
  c.strokeStyle = bp ? PAL.accents[0] : PAL.shade; c.lineWidth = 5; c.lineCap = 'round'; if (p > 0) { c.beginPath(); c.arc(x, y, r, Math.PI, Math.PI + Math.PI * p); c.stroke(); }
  sunDot(c, x + Math.cos(Math.PI + Math.PI * p) * r, y + Math.sin(Math.PI + Math.PI * p) * r, 9, { night: bp });
}
function habitGrid(c, x, y, cols, rows, filled, seed, o = {}) {   // hex cells fill one at a time; the newest bursts
  const { mode = 'ink', burst = 0, s = 16 } = o, bp = mode === 'blueprint', rn = rng(seed), order = []; for (let k = 0; k < cols * rows; k++) order.push(k); for (let k = order.length - 1; k > 0; k--) { const j = rn() * (k + 1) | 0; [order[k], order[j]] = [order[j], order[k]]; }
  const w = Math.sqrt(3) * s, hh = 1.5 * s; let n = 0, last = null;
  for (let r = 0; r < rows; r++) for (let q = 0; q < cols; q++) { const cx = x + q * w + (r % 2 ? w / 2 : 0), cy = y + r * hh, hp = hexPath(cx, cy, s * .92), rank = order[n++], on = rank < filled;
    if (on && !bp) { c.fillStyle = rank < filled * .6 ? PAL.fills[4] : PAL.fills[0]; c.fill(hp); } c.strokeStyle = bp ? PAL.chalkDim : alpha(PAL.ink, on ? .9 : .35); c.lineWidth = 1.1; c.stroke(hp); if (rank === filled - 1) last = [cx, cy]; }
  if (last && burst > 0) dotBurst(c, last[0], last[1], 40, 10, PAL.accents[1], seed + 9, burst);
}
function boardHome(c, mode, o, seed = 70) {   // o: { lift 0..1, done: [0|1 x3], burst, p }
  const { w, h } = BOARD, x0 = -w / 2 + 28, cw = w - 56; boardFrame(c, mode, seed);
  squiggleText(c, x0, -h / 2 + 70, 150, 1, { seed: seed + 1, lineH: 18, amp: 5, width: 2.2, color: mode === 'blueprint' ? PAL.chalk : PAL.ink }); squiggleText(c, x0, -h / 2 + 92, 110, 1, { seed: seed + 2, lineH: 12, amp: 3, width: 1.2, color: PAL.chalkDim });
  sunDot(c, w / 2 - 64, -h / 2 + 88, 26, { night: mode === 'blueprint' });
  clayCard(c, x0, -h / 2 + 130, cw, 96, seed + 3, { mode, lift: (o.lift ?? 0) * 10, fill: PAL.light }); c.save(); c.translate(x0 + 34, -h / 2 + 178); GLYPHS.insights(c, mode === 'blueprint' ? 'blueprint' : 'ink', 12, seed + 4); c.restore(); squiggleText(c, x0 + 66, -h / 2 + 172, cw - 100, 2, { seed: seed + 5, lineH: 18, amp: 4, width: 1.5, color: mode === 'blueprint' ? PAL.chalk : PAL.ink });
  signalRings(c, x0 + 46, -h / 2 + 300, seed + 6, { mode, p: o.p ?? .7 });
  clayCard(c, x0, -h / 2 + 370, cw, 190, seed + 7, { mode }); (o.done || [0, 0, 0]).forEach((d, k) => checkRow(c, x0 + 22, -h / 2 + 412 + k * 50, cw - 40, seed + 10 + k, { done: d, mode, burst: k === (o.burstRow ?? -1) ? (o.burst ?? 0) : 0 }));
  composer(c, x0, h / 2 - 150, cw, seed + 20, { mode }); dock(c, x0, h / 2 - 84, cw, seed + 30, { mode, active: 0 });
}
function boardPlan(c, mode, o, seed = 72) {   // o: { p (capacity), blocks }
  const { w, h } = BOARD, x0 = -w / 2 + 28, cw = w - 56; boardFrame(c, mode, seed);
  squiggleText(c, x0, -h / 2 + 70, 120, 1, { seed: seed + 1, lineH: 18, amp: 5, width: 2.2, color: mode === 'blueprint' ? PAL.chalk : PAL.ink }); sunDot(c, w / 2 - 64, -h / 2 + 88, 26, { night: mode === 'blueprint' });
  clayCard(c, x0, -h / 2 + 130, cw, 150, seed + 3, { mode, fill: PAL.light }); capacityArc(c, 0, -h / 2 + 260, 120, o.p ?? 0, seed + 4, { mode }); squiggleText(c, x0 + 22, -h / 2 + 160, 140, 1, { seed: seed + 5, lineH: 14, amp: 3.5, width: 1.4, color: mode === 'blueprint' ? PAL.chalk : PAL.ink });
  timeCanvas(c, x0 + 40, -h / 2 + 320, cw - 40, 330, seed + 8, { mode, blocks: o.blocks || [] });
  composer(c, x0, h / 2 - 150, cw, seed + 20, { mode }); dock(c, x0, h / 2 - 84, cw, seed + 30, { mode, active: 1 });
}
function boardTrack(c, mode, o, seed = 74) {   // o: { filled, burst, p }
  const { w, h } = BOARD, x0 = -w / 2 + 28, cw = w - 56; boardFrame(c, mode, seed);
  squiggleText(c, x0, -h / 2 + 70, 130, 1, { seed: seed + 1, lineH: 18, amp: 5, width: 2.2, color: mode === 'blueprint' ? PAL.chalk : PAL.ink }); sunDot(c, w / 2 - 64, -h / 2 + 88, 26, { night: mode === 'blueprint' });
  signalRings(c, x0 + 46, -h / 2 + 160, seed + 6, { mode, p: o.p ?? .5 });
  clayCard(c, x0, -h / 2 + 230, cw, 300, seed + 7, { mode }); squiggleText(c, x0 + 22, -h / 2 + 262, 120, 1, { seed: seed + 5, lineH: 14, amp: 3.5, width: 1.5, color: mode === 'blueprint' ? PAL.chalk : PAL.ink });
  habitGrid(c, x0 + 40, -h / 2 + 300, 9, 7, o.filled ?? 0, seed + 9, { mode, burst: o.burst ?? 0, s: 17 });
  composer(c, x0, h / 2 - 150, cw, seed + 20, { mode }); dock(c, x0, h / 2 - 84, cw, seed + 30, { mode, active: 2 });
}

// ===================== THE SCRAPS OF A LIFE (and how they fold) =====================
// 13 scraps, each drawn at the origin within ~±70. Positions are seeded inside the stage.
const SCRAP_DRAW = {
  sticky(c, seed, m) { const b = [-52, -52, 104, 104]; inkShape(c, rectPath(...b), [[-52, -52], [52, -52], [52, 52], [-52, 52]], b, { fill: PAL.fills[0], seed, mode: m, alpha: .12, grain: 30 }); c.strokeStyle = m === 'blueprint' ? PAL.chalk : PAL.ink; c.lineWidth = 1.4; c.beginPath(); for (let a = 0; a < 18; a += .25) c.lineTo(Math.cos(a) * a * 1.6, Math.sin(a) * a * 1.6); c.stroke(); },
  calendar(c, seed, m) { const b = [-60, -50, 120, 100]; inkShape(c, rr(c, ...b, 8), rrPts(...b, 8), b, { fill: PAL.light, seed, mode: m, alpha: .1, grain: 20 }); c.lineWidth = 2; wob(c, [[-60, -22], [60, -22]], 1, seed + 20); for (let r = 0; r < 2; r++) for (let k = 0; k < 4; k++) cross(c, -40 + k * 27, 0 + r * 26, 4); },
  pills(c, seed, m) { const b = [-26, -30, 52, 84]; inkShape(c, rr(c, ...b, 12), rrPts(...b, 12), b, { fill: PAL.fills[1], seed, mode: m, alpha: .18 }); inkShape(c, rr(c, -30, -52, 60, 26, 6), rrPts(-30, -52, 60, 26, 6), [-30, -52, 60, 26], { fill: PAL.light, seed: seed + 1, mode: m, grain: 10 }); },
  receipt(c, seed, m) { const pts = [[-34, -70], [34, -70], [34, 62], [24, 70], [14, 62], [4, 70], [-6, 62], [-16, 70], [-26, 62], [-34, 70]]; inkShape(c, polyPath(pts), pts, [-34, -70, 68, 140], { fill: PAL.light, seed, mode: m, alpha: .08, grain: 20 }); squiggleText(c, -24, -48, 48, 6, { seed: seed + 3, lineH: 16, amp: 2.5, width: 1, color: m === 'blueprint' ? PAL.chalk : PAL.ink }); },
  shoe(c, seed, m) { const pts = [[-70, 20], [-60, -10], [-20, -22], [10, -40], [40, -34], [60, -4], [72, 22], [-70, 30]]; inkShape(c, polyPath(pts), pts, [-72, -42, 144, 74], { fill: PAL.fills[5], seed, mode: m, alpha: .22 }); c.lineWidth = 1.6; for (let k = 0; k < 3; k++) wob(c, [[-10 + k * 14, -18 + k * 2], [4 + k * 14, -34 + k * 2]], 1, seed + 30 + k); },
  book(c, seed, m) { const b = [-46, -60, 92, 120]; inkShape(c, rr(c, ...b, 6), rrPts(...b, 6), b, { fill: PAL.fills[3], seed, mode: m, alpha: .2 }); c.lineWidth = 3; wob(c, [[-36, -60], [-36, 60]], 1, seed + 20); c.lineWidth = 1.4; wob(c, [[-14, -20], [30, -20]], 1, seed + 21); wob(c, [[-14, 0], [30, 0]], 1, seed + 22); },
  glass(c, seed, m) { const pts = [[-30, -60], [30, -60], [22, 60], [-22, 60]]; inkShape(c, polyPath(pts), pts, [-30, -60, 60, 120], { fill: PAL.light, seed, mode: m, alpha: .06, grain: 10 }); const wp = polyPath([[-26, -10], [26, -10], [22, 60], [-22, 60]]); if (m !== 'blueprint') { c.fillStyle = PAL.fills[5]; c.globalAlpha = .55; c.fill(wp); c.globalAlpha = 1; } c.lineWidth = 1.6; wob(c, [[-26, -10], [26, -10]], 1.5, seed + 20); },
  envelope(c, seed, m) { const b = [-64, -42, 128, 84]; inkShape(c, rr(c, ...b, 6), rrPts(...b, 6), b, { fill: PAL.light, seed, mode: m, alpha: .08, grain: 20 }); c.lineWidth = 2; wob(c, [[-64, -42], [0, 10], [64, -42]], 1.5, seed + 20); },
  phone(c, seed, m) { const b = [-38, -70, 76, 140]; inkShape(c, rr(c, ...b, 14), rrPts(...b, 14), b, { fill: PAL.fills[2], seed, mode: m, alpha: .12, grain: 20 }); const rn = rng(seed + 5); for (let k = 0; k < 6; k++) { const x = -24 + (k % 3) * 24, y = -44 + Math.floor(k / 3) * 30; c.strokeStyle = m === 'blueprint' ? PAL.chalk : PAL.ink; c.lineWidth = 1.4; c.strokeRect(x - 9, y - 9, 18, 18); if (rn() < .7) { c.fillStyle = m === 'blueprint' ? PAL.accents[0] : PAL.accents[2]; c.fill(circPath(x + 9, y - 9, 5)); } } },
  fork(c, seed, m) { c.strokeStyle = m === 'blueprint' ? PAL.chalk : PAL.ink; c.lineWidth = 3; wob(c, [[0, 70], [0, -20]], 1.2, seed); for (let k = -1; k <= 1; k++) wob(c, [[k * 10, -20], [k * 12, -66]], 1, seed + 2 + k); c.lineWidth = 2; wob(c, [[-12, -20], [12, -20]], 1, seed + 9); },
  heart(c, seed, m) { const p = new Path2D(); p.moveTo(0, 50); p.bezierCurveTo(-90, -10, -40, -70, 0, -30); p.bezierCurveTo(40, -70, 90, -10, 0, 50); const pts = []; for (let k = 0; k <= 40; k++) { const t = k / 40, a = t * TAU; pts.push([16 * Math.pow(Math.sin(a), 3) * 3.4, -(13 * Math.cos(a) - 5 * Math.cos(2 * a) - 2 * Math.cos(3 * a) - Math.cos(4 * a)) * 3.2]); } inkShape(c, polyPath(pts), pts, [-60, -60, 120, 120], { fill: PAL.accents[2], seed, mode: m, alpha: .2 }); },
  coin(c, seed, m) { inkShape(c, circPath(0, 0, 44), ellPts(0, 0, 44, 44, 0, 40), [-44, -44, 88, 88], { fill: PAL.fills[0], seed, mode: m, alpha: .2 }); c.lineWidth = 1.6; wob(c, ellPts(0, 0, 32, 32, 0, 30), 1.2, seed + 20, true); squiggleText(c, -14, 6, 28, 1, { seed: seed + 3, lineH: 10, amp: 4, width: 1.6, color: m === 'blueprint' ? PAL.chalk : PAL.ink }); },
  dumbbell(c, seed, m) { for (const s of [-1, 1]) inkShape(c, rr(c, s * 44 - 14, -28, 28, 56, 6), rrPts(s * 44 - 14, -28, 28, 56, 6), [s * 44 - 14, -28, 28, 56], { fill: PAL.fills[4], seed: seed + s, mode: m, alpha: .2 }); c.strokeStyle = m === 'blueprint' ? PAL.chalk : PAL.ink; c.lineWidth = 5; wob(c, [[-30, 0], [30, 0]], 1, seed + 5); },
};
const SCRAP_KINDS = Object.keys(SCRAP_DRAW);
function scrapPositions(seed = 11) {   // seeded, inside the stage square, away from the label band
  const rn = rng(seed), L = LAYOUT(), out = []; SCRAP_KINDS.forEach((k, n) => { const col = n % 4, row = Math.floor(n / 4), x = CX - 400 + col * 265 + (rn() - .5) * 120, y = L.stageTop + 150 + row * 240 + (rn() - .5) * 110; out.push({ k, x, y, rot: (rn() - .5) * 1.1, s: .8 + rn() * .35 }); }); return out;
}
function drawScraps(c, mode, o = {}) {   // o: { i (frame), boil, gather 0..1, seed }
  const { i = 0, boil = false, gather = 0, seed = 11 } = o, pos = scrapPositions(seed), boilK = boil ? Math.floor(i / 3) % 4 : 0;
  pos.forEach((p, n) => { const x = lerp(p.x, CX + (n % 3 - 1) * 18, gather), y = lerp(p.y, CY + 40 + (n % 4 - 1.5) * 10, gather), rot = lerp(p.rot, (n % 3 - 1) * .06, gather), s = lerp(p.s, .9, gather);
    c.save(); c.translate(x, y); c.rotate(rot); c.scale(s, s); if (gather < .5 && mode !== 'blueprint') castShadow(c, 6, 40, 60, 14, seed + n); SCRAP_DRAW[p.k](c, seed * 7 + n * 13 + boilK * 101, mode); c.restore(); });
}
function drawSheetFold(c, k, seed = 12) {   // fold states after the pile: 0 one sheet, 1 folded in half, 2 folded to a card, 3 the board outline
  c.save(); c.translate(CX, CY + 20); c.lineJoin = 'round';
  const states = [[-260, -330, 520, 660, 16], [-260, -170, 520, 340, 16], [-130, -170, 260, 340, 24], [-210, -410, 420, 820, 62]]; const b = states[k];
  inkShape(c, rr(c, ...b), rrPts(...b), b.slice(0, 4), { fill: PAL.light, seed: seed + k, mode: 'ink', alpha: .08, grain: 60, width: 3 });
  c.strokeStyle = PAL.ink; c.setLineDash([9, 8]); c.lineWidth = 1.6; if (k === 0) wob(c, [[-260, 0], [260, 0]], 1, seed + 5); if (k === 1) wob(c, [[0, -170], [0, 170]], 1, seed + 6); if (k === 2) wob(c, [[-130, 0], [130, 0]], 1, seed + 7); c.setLineDash([]);
  if (k < 3) squiggleText(c, b[0] + 40, b[1] + 60, b[2] - 80, k === 2 ? 4 : 5, { seed: seed + 9, lineH: 26, amp: 5, width: 1.6, color: PAL.ink });
  c.restore();
}

// ===================== THE ICON, PRINTED (riso plates) =====================
// The LifeBoard icon: a black profile head facing right, a white square eye, and a 4 x 6 colour grid.
const ICON_ROWS = [   // per row: [ink index (0 blue,1 orange,2 yellow,3 purple), base coverage, per-column ramp, second plate index, second coverage]
  [2, .85, 0, 0, .40],   // green = yellow over blue
  [1, .72, .08, 2, .30], // orange
  [2, .88, -.05, 1, .10],// yellow
  [3, .55, .13, 0, .08], // purple
  [0, .45, .12, -1, 0],  // light blue
  [0, .72, .08, 3, .10], // blue
];
function iconGeom(cx, cy, size) {   // unit coords of the 1024 icon mapped to size
  const u = (x, y) => [cx + (x - .5) * size, cy + (y - .5) * size];
  const profile = [[0, 0], [.21, .012], [.28, .03], [.33, .08], [.36, .16], [.385, .27], [.41, .40], [.435, .52], [.45, .60], [.42, .625], [.345, .625], [.345, 1], [0, 1]].map(p => u(...p));
  const eye = [u(.205, .335), u(.27, .40)], cols = [.21, .415, .61, .80, 1.0], rows = [.012, .18, .35, .51, .68, .84, 1.0];
  return { profile, eye, cell: (col, row) => { const [x0, y0] = u(cols[col], rows[row]), [x1, y1] = u(cols[col + 1], rows[row + 1]); return [x0, y0, x1 - x0, y1 - y0]; }, box: [cx - size / 2, cy - size / 2, size, size] };
}
const _iconCache = { key: '', layers: [] };
function iconLayers(cx, cy, size) {
  const key = `${W}x${H}x${S}:${cx},${cy},${size}`; if (_iconCache.key === key) return _iconCache.layers;
  const G = iconGeom(cx, cy, size), inks = [LB.icon.blue, LB.icon.orange, LB.icon.yellow, LB.icon.purple], angles = [.26, 1.31, 0, .8], gray = v => `rgb(${255 - v * 255 | 0},${255 - v * 255 | 0},${255 - v * 255 | 0})`;
  const plates = inks.map((ink, k) => { const P = plate(), g = P.getContext('2d'); g.setTransform(S, 0, 0, S, 0, 0);
    ICON_ROWS.forEach((row, r) => { for (let col = 0; col < 4; col++) { let cov = 0; if (row[0] === k) cov = row[1] + row[2] * col; if (row[3] === k) cov = Math.max(cov, row[4]); if (cov > 0) { g.fillStyle = gray(clamp(cov, 0, 1)); g.fillRect(...G.cell(col, r)); } } });
    g.fillStyle = '#fff'; g.fill(polyPath(G.profile)); return { P, ink, angle: angles[k] }; });
  // the profile: printed nearly solid on the ink plate, eye knocked out
  const PK = plate(), gk = PK.getContext('2d'); gk.setTransform(S, 0, 0, S, 0, 0); gk.fillStyle = '#000'; gk.fill(polyPath(G.profile)); gk.fillStyle = '#fff'; const [e0, e1] = G.eye; gk.fillRect(e0[0], e0[1], e1[0] - e0[0], e1[1] - e0[1]);
  const layers = []; let acc = layer(); const a = acc.getContext('2d'); usePalette(lbRiso); paper(a);
  const snap = () => { const L = layer(); L.getContext('2d').drawImage(acc, 0, 0); layers.push(L); };
  snap(); plates.forEach(pl => { printPlate(a, pl.P, { cell: 6, ink: pl.ink, angle: pl.angle, seed: 300 + layers.length, jitter: .25 }); snap(); });
  printPlate(a, PK, { cell: 4, ink: LB.ink, angle: .5, seed: 310, gain: 1.4, maxCov: .96, jitter: .15 }); a.strokeStyle = LB.ink; a.lineWidth = 3; a.lineJoin = 'round'; wob(a, G.profile, 2, 311, true); snap();
  _iconCache.key = key; _iconCache.layers = layers; return layers;
}
function printIcon(c, cx, cy, size, progress) {   // progress 0..1 prints blue, orange, yellow, purple, then the profile
  const layers = iconLayers(cx, cy, size), k = Math.min(layers.length - 1, Math.floor(progress * (layers.length - 1) + 1e-6)); blit(c, layers[k]); return iconGeom(cx, cy, size);
}
function iconEye(cx, cy, size) { const { eye } = iconGeom(cx, cy, size); return [(eye[0][0] + eye[1][0]) / 2, (eye[0][1] + eye[1][1]) / 2, (eye[1][0] - eye[0][0]) / 2]; }

// ===================== RISO FEATURE CARDS =====================
const CARD_INK = { home: 2, plan: 0, track: 3, insights: 2, eva: 3, focus: 1, journal: 1, everywhere: 0 };
const _cardCache = new Map();
function featureCard(kind) {
  return (c, tau, i) => {
    const key = `${kind}:${W}x${H}x${S}`; let L = _cardCache.get(key);
    if (!L) { L = layer(); const g = L.getContext('2d'); usePalette(lbRiso); paper(g); const gray = v => `rgb(${255 - v * 255 | 0},${255 - v * 255 | 0},${255 - v * 255 | 0})`;
      const P1 = plate(), g1 = P1.getContext('2d'); g1.setTransform(S, 0, 0, S, 0, 0); const gr = g1.createRadialGradient(CX, CY - 40, 60, CX, CY - 40, 520); gr.addColorStop(0, gray(.85)); gr.addColorStop(1, gray(0)); g1.fillStyle = gr; g1.fillRect(0, 0, W, H); g1.save(); g1.translate(CX, CY - 40); g1.fillStyle = '#fff'; g1.strokeStyle = '#fff'; g1.lineWidth = 26; GLYPHS[kind](g1, 'plate', 230, 5); g1.restore();
      const P2 = plate(), g2 = P2.getContext('2d'); g2.setTransform(S, 0, 0, S, 0, 0); g2.save(); g2.translate(CX, CY - 40); GLYPHS[kind](g2, 'plate', 230, 5); g2.restore();
      const P3 = plate(), g3 = P3.getContext('2d'); g3.setTransform(S, 0, 0, S, 0, 0); g3.save(); g3.translate(CX + 12, CY - 30); g3.fillStyle = '#000'; g3.strokeStyle = '#000'; g3.lineWidth = 10; g3.globalAlpha = .55; GLYPHS[kind](g3, 'plate', 230, 6); g3.restore();
      printPlate(g, P1, { cell: 7, ink: lbRiso.inks[CARD_INK[kind]], angle: .26, seed: 320 }); printPlate(g, P3, { cell: 7, ink: lbRiso.inks[(CARD_INK[kind] + 1) % 4], angle: 1.31, seed: 322 }); printPlate(g, P2, { cell: 5, ink: LB.ink, angle: 0, seed: 321, gain: 1.3, maxCov: .9 });
      _cardCache.set(key, L); }
    usePalette(lbRiso); blit(c, L);
  };
}
const FEATURE_KINDS = ['home', 'plan', 'track', 'insights', 'eva', 'focus', 'journal', 'everywhere'];
const FEATURE_CARDS = FEATURE_KINDS.map(featureCard);
function areaCard(kind) { return (c, tau, i) => { usePalette(lbRiso); paper(c); const col = LB.areas[kind]; c.save(); resetT(c); c.translate(CX, CY); c.fillStyle = col; c.globalAlpha = .9; c.fill(circPath(0, 0, 470)); c.globalAlpha = 1; dotScreen(c, circPath(0, 0, 470), [-470, -470, 940, 940], { cell: 8, color: shade(col, .45), density: .35, angle: .3, jitter: .3, seed: 330 }); c.strokeStyle = LB.light; c.lineWidth = 34; c.lineCap = 'round'; c.lineJoin = 'round'; AREA_GLYPH[kind](c, 200); c.strokeStyle = LB.ink; c.lineWidth = 12; AREA_GLYPH[kind](c, 200); c.restore(); }; }
const AREA_CARDS = AREA_KEYS.map(areaCard);

// ===================== SHARED MOTIFS =====================
function loopRing(c, mode, progress, cx, cy, R, seed = 90) {   // the operating loop: orient, capture, organize, plan, focus/track, recover, reflect, adapt
  const line = mode === 'blueprint' ? PAL.chalk : PAL.ink; c.save(); c.lineCap = 'round'; c.lineJoin = 'round';
  construction(c, cx, cy, R * .8, seed, PAL.guide, .8 * clamp(progress * 3, 0, 1));
  c.strokeStyle = line; c.lineWidth = 3; selfDraw(c, ellPts(cx, cy, R, R, -Math.PI / 2, 140), clamp(progress * 1.15, 0, 1), seed + 1, 1.6, true);
  const marks = ['sun', 'cross', 'grid', 'plan', 'focus', 'undo', 'journal', 'insights'];
  marks.forEach((m, k) => { if (progress < (k + .5) / 8) return; const a = -Math.PI / 2 + k / 8 * TAU, x = cx + Math.cos(a) * R, y = cy + Math.sin(a) * R; c.strokeStyle = line; c.lineWidth = 2; c.beginPath(); c.moveTo(x + Math.cos(a) * 10, y + Math.sin(a) * 10); c.lineTo(x + Math.cos(a) * 34, y + Math.sin(a) * 34); c.stroke();
    const gx = cx + Math.cos(a) * (R + 70), gy = cy + Math.sin(a) * (R + 70); c.save(); c.translate(gx, gy);
    if (m === 'sun') sunDot(c, 0, 0, 12, { night: mode === 'blueprint' }); else if (m === 'cross') { c.lineWidth = 2.6; cross(c, 0, 0, 12); } else if (m === 'grid') { for (let r = 0; r < 2; r++) for (let q = 0; q < 2; q++) c.strokeRect(-12 + q * 14, -12 + r * 14, 10, 10); }
    else if (m === 'undo') { c.lineWidth = 2.6; c.beginPath(); c.arc(0, 0, 11, Math.PI * .2, Math.PI * 1.7); c.stroke(); wob(c, [[-6, -14], [-11, -6], [-2, -4]], .8, seed + 5); } else GLYPHS[m](c, mode, 13, seed + k); c.restore(); });
  c.restore();
}
function tallyMarks(c, x, y, n, seed, color) { c.save(); c.strokeStyle = color; c.lineWidth = 2.2; c.lineCap = 'round'; for (let k = 0; k < n; k++) { const g = Math.floor(k / 5), j = k % 5, bx = x + g * 44; if (j < 4) wob(c, [[bx + j * 9, y - 14], [bx + j * 9 + 2, y + 14]], 1, seed + k); else wob(c, [[bx - 4, y + 10], [bx + 32, y - 10]], 1, seed + k); } c.restore(); }
function dunes(c, seed = 20) {   // the Home header's soft hills, hatched
  const L = LAYOUT(), base = L.stageBottom; const hills = [[CX - 620, base + 140, 900, 520, PAL.fills[2]], [CX + 420, base + 260, 1000, 560, PAL.fills[1]], [CX - 120, base + 420, 1100, 520, PAL.fills[0]]];
  hills.forEach(([x, y, rx, ry, col], k) => { const p = ellPath(x, y, rx, ry), box = [x - rx, y - ry, rx * 2, ry * 2]; c.fillStyle = col; c.fill(p); surface(c, p, box, { seed: seed + k, alpha: .22, gap: 7, len: 18, color: PAL.shade, grain: 900, angle: .6 + k * .3 }); hatch(c, p, box, { angle: 2.4, gap: 8, len: 22, jitter: 5, color: PAL.light, alpha: .5, width: 1.3, seed: seed + 10 + k }); c.strokeStyle = PAL.ink; c.lineWidth = 2.6; c.globalAlpha = .85; wob(c, ellPts(x, y, rx, ry, 0, 120), 2.4, seed + 20 + k, true); c.globalAlpha = 1; });
}
function speechBubble(c, x, y, w, h, tailTo, seed, lines = 2) { const b = [x, y, w, h]; c.fillStyle = isNight() ? PAL.accents[1] : PAL.fills[0]; c.fill(rr(c, ...b, 22)); surface(c, rr(c, ...b, 22), b, { seed, alpha: .12, gap: 6, len: 10, grain: 20 }); c.strokeStyle = PAL.ink; c.lineWidth = 2.2; wob(c, rrPts(...b, 22), 1.4, seed + 1, true); wob(c, [[x + 30, y + h], [tailTo[0], tailTo[1]], [x + 60, y + h]], 1.2, seed + 2); squiggleText(c, x + 24, y + 34, w - 48, lines, { seed: seed + 3, lineH: 24, amp: 5, width: 1.6, color: isNight() ? LB.ink : PAL.ink }); }
function receiptStamp(c, x, y, progress, seed = 95) { if (progress <= 0) return; c.save(); c.translate(x, y); c.rotate(-.18); c.scale(lerp(1.6, 1, easeOut(progress)), lerp(1.6, 1, easeOut(progress))); c.globalAlpha = clamp(progress * 2, 0, 1); c.strokeStyle = PAL.accents[3]; c.lineWidth = 4; wob(c, rrPts(-90, -34, 180, 68, 12), 2, seed, true); c.lineWidth = 2.4; wob(c, rrPts(-82, -26, 164, 52, 8), 1.5, seed + 1, true); c.lineWidth = 4; wob(c, [[-52, 2], [-32, 20], [4, -18]], 1.2, seed + 2); squiggleText(c, 18, 8, 60, 1, { seed: seed + 3, lineH: 12, amp: 5, width: 2.2, color: PAL.accents[3] }); c.restore(); }
function undoArrow(c, x, y, progress, seed = 96, color) { if (progress <= 0) return; const pts = []; for (let k = 0; k <= 30; k++) { const a = Math.PI * .1 + k / 30 * Math.PI * 1.3; pts.push([x + Math.cos(a) * 70, y + Math.sin(a) * 70]); } c.save(); c.strokeStyle = color || PAL.accents[0]; c.lineWidth = 4; c.lineCap = 'round'; selfDraw(c, pts, progress, seed, 1.5); if (progress > .95) { const [ex, ey] = pts[30]; wob(c, [[ex + 8, ey - 22], [ex, ey], [ex + 22, ey + 4]], 1, seed + 1); } c.restore(); }
function brandSignOff(c, tau, t0, o = {}) {   // the name in hand lettering with two inks, the tagline smaller, two dots
  const { x = CX, y = CY + 300, size = 96, ink = LB.ink, ink2 = LB.icon.orange, tagline = 'One place to run the life you actually have.' } = o;
  const pa = sm(t0, t0 + .5, tau, easeOut), pb = sm(t0 + .45, t0 + 1.1, tau, easeOut);
  if (pa > 0) handText(c, 'LifeBoard'.slice(0, Math.round(9 * pa)), x, y, { size, ink, ink2, offset: 4, align: 'center' });
  if (pb > 0) handText(c, tagline.slice(0, Math.round(tagline.length * pb)), x, y + size * .78, { size: Math.min(40, W * .036), ink, ink2, offset: 2, align: 'center' });
  if (pa >= 1) { seedDot(c, x - 10, y + size * .3, 5, ink, null); seedDot(c, x + 10, y + size * .3, 5, ink2, null); }
}
const L1 = layer(), L2 = layer();

// ===================== SCENES (factories: dur in seconds; every scene is pure in (c, tau, i)) =====================
const boardScale = () => LAYOUT().tall ? 1.16 : 1.0;
const boardY = () => LAYOUT().tall ? CY - 20 : CY - 40;

const sceneSunrise = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbMorning); paper(c); const L = LAYOUT(); cam(c, CX, CY + 40, lerp(1.12, 1.26, sm(0, dur, tau)));
  const p = sm(0, dur * .55, tau, easeOut), sy0 = L.stageBottom + 60, sy1 = L.stageBottom - 470, sy = lerp(sy0, sy1, p), sx = CX + 140;
  const bloom = circPath(sx, sy, 260 * p); hatch(c, bloom, [sx - 260, sy - 260, 520, 520], { angle: .9, gap: 7, len: 20, jitter: 6, color: PAL.blush, alpha: .28 * p, width: 1.3, seed: 21 });
  dunes(c, 20); c.save(); c.beginPath(); c.rect(0, 0, W, L.stageBottom + 120); c.clip(); sunRays(c, sx, sy, 44, p, 22); sunDot(c, sx, sy, 44); c.restore();
  c.strokeStyle = PAL.guide; c.lineWidth = .9; cross(c, CX - 380, CY - 300, 8); cross(c, CX + 300, CY + 60, 8); construction(c, sx, sy, 90, 23, PAL.guide, .5 * p);
  resetT(c); label(c, o.label ?? 'Good morning.', tau, dur * .35);
};
const sceneScatter = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbMorning); paper(c); const L = LAYOUT(); drawScraps(c, 'ink', { i, boil: true, seed: 11 }); const [sx, sy] = L.sunPos(.16); sunDot(c, sx, sy, 22);
  if (o.crosses !== false) { c.strokeStyle = PAL.guide; c.lineWidth = .9; const rn = rng(300 + Math.floor(i / 3)); for (let k = 0; k < 4; k++) cross(c, CX + (rn() - .5) * 900, CY + (rn() - .5) * 900, 7); }
  label(c, o.label ?? 'A real day has a lot in it.', tau, .25);
};
const sceneBlot = (dur, o = {}) => (c, tau, i) => {
  const L = LAYOUT(), [sx, sy] = L.sunPos(.16);
  const a = L1.getContext('2d'); usePalette(lbMorning); paper(a); drawScraps(a, 'ink', { i: 0, boil: false, seed: 11 }); sunDot(a, sx, sy, 22);
  const b = L2.getContext('2d'); usePalette(lbNight); night(b, PAL.night, 31); drawScraps(b, 'blueprint', { i: 0, seed: 11 }); loopRing(b, 'blueprint', sm(dur * .25, dur, tau, easeOut), CX, CY + 20, 330); sunDot(b, sx, sy, 22, { night: true });
  blit(c, L1); blot(c, L2, sx, sy, lerp(0, Math.hypot(W, H) * .8, sm(0, dur * .6, tau, easeOut)), 32, lbNight.night);
  usePalette(lbNight); if (o.label) label(c, o.label, tau, dur * .4, { night: true });
};
const sceneFold = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbMorning); paper(c); const L = LAYOUT(), k = Math.min(5, Math.floor(tau * 12 / 3)), [sx, sy] = L.sunPos(.2);
  if (k === 0) drawScraps(c, 'ink', { i: 0, boil: false, seed: 11 }); else if (k === 1) drawScraps(c, 'ink', { i: 0, gather: 1, seed: 11 }); else drawSheetFold(c, k - 2, 12);
  if (k === 5) { c.save(); c.translate(CX, CY + 20); c.strokeStyle = PAL.guide; construction(c, 0, 0, 300, 44, PAL.guide, .7); c.restore(); }
  sunDot(c, sx, sy, 22); label(c, o.label ?? 'One place.', tau, 15 / 12);
};
const sceneHome = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbMorning); paper(c); cam(c, CX, boardY(), boardScale() * lerp(1, 1.04, sm(0, dur, tau)));
  const t1 = dur * .45, t2 = dur * .7, burst = k => { const t = [t1, t2][k]; return tau >= t && tau < t + .3 ? 1 - (tau - t) / .3 : 0; };
  c.save(); c.translate(CX, boardY()); construction(c, 0, 0, 380, 45, PAL.guide, .55);
  boardHome(c, 'ink', { lift: sm(0, dur * .3, tau, easeOut), done: [tau >= t1 ? 1 : 0, tau >= t2 ? 1 : 0, 0], burst: Math.max(burst(0), burst(1)), burstRow: tau >= t2 ? 1 : 0, p: sm(0, dur * .6, tau) * .72 }); c.restore();
  resetT(c); label(c, o.label ?? 'What matters now?', tau, .2);
};
const scenePlan = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbAfternoon); paper(c); cam(c, CX, boardY(), boardScale());
  const week = o.week && tau >= o.week, step = dur / 8, blocks = [];
  [[.4, 1.5, PAL.fills[3]], [1.9, 3.1, PAL.fills[1]], [3.5, 4.4, PAL.fills[4]], [4.8, 5.8, PAL.fills[0]]].forEach(([t0, t1, col], k) => { const at = step * (k + .6), s = sm(at, at + .35, tau, easeOut); if (s <= 0) return; let slide = 1.2 - 1.2 * s, al = 1;
    if (k === 3) { const away = sm(at + .7, at + 1.05, tau, easeIn); slide = lerp(slide, .62, away); al = 1 - away * .25; } blocks.push({ t0, t1, col, slide, alpha: al }); });
  c.save(); c.translate(CX, boardY()); boardPlan(c, 'ink', { p: Math.min(.82, blocks.length * .27), blocks }); c.restore();
  resetT(c); label(c, o.label ?? 'When should it happen?', tau, .2);
};
const sceneFocus = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbAfternoon); paper(c); const cx = CX, cy = CY - 80, R = 290, ring = sm(0, dur * .3, tau, easeOut), fill = sm(dur * .3, dur, tau);
  c.save(); c.strokeStyle = PAL.ink; c.lineWidth = 4; selfDraw(c, ellPts(cx, cy, R, R, -Math.PI / 2, 120), ring, 61, 1.8, true); c.restore();
  if (ring >= 1) { c.save(); c.strokeStyle = PAL.fills[2]; c.lineWidth = 16; c.beginPath(); c.arc(cx, cy, R - 24, 0, TAU); c.stroke(); c.strokeStyle = PAL.shade; c.lineCap = 'round'; c.beginPath(); c.arc(cx, cy, R - 24, -Math.PI / 2, -Math.PI / 2 + TAU * fill * .7); c.stroke(); c.restore();
    for (let k = 0; k < 12; k++) { const a = k / 12 * TAU, on = k / 12 < fill * .7; c.strokeStyle = on ? PAL.ink : alpha(PAL.ink, .3); c.lineWidth = on ? 3 : 1.5; wob(c, [[cx + Math.cos(a) * (R - 52), cy + Math.sin(a) * (R - 52)], [cx + Math.cos(a) * (R - 70), cy + Math.sin(a) * (R - 70)]], .8, 62 + k); } }
  if (pulse(i, 9) && ring >= 1) speedLines(c, cx - R - 30, cy, Math.PI, 63 + i, 5, .35);
  clayCard(c, cx - 150, cy + 20, 300, 74, 64, { fill: PAL.light }); squiggleText(c, cx - 118, cy + 62, 240, 1, { seed: 65, lineH: 14, amp: 4, width: 1.6, color: PAL.ink });
  sunDot(c, cx, cy - 60, 34 + (pulse(i, 6) ? 2 : 0)); sunRays(c, cx, cy - 60, 34, fill, 66);
  label(c, o.label ?? 'What am I doing now?', tau, .2);
};
const sceneTrack = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbAfternoon); paper(c); cam(c, CX, boardY(), boardScale()); const start = 3, filled = Math.max(0, Math.min(34, Math.floor(tau * 12) - start)), fresh = (Math.floor(tau * 12) - start) < 34;
  c.save(); c.translate(CX, boardY()); boardTrack(c, 'ink', { filled, burst: fresh && filled > 0 ? 1 - (i % 3) / 3 : 0, p: .35 + sm(0, dur, tau) * .5 }); c.restore();
  resetT(c); label(c, o.label ?? 'What needs sustaining?', tau, .2);
};
const sceneRecover = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbEvening); const T = tau / dur, splatT = .22, W2 = 300, gap = 70, x0 = CX - W2 - gap / 2, x1 = CX + gap / 2, y0 = CY - 330, hh = 560;
  const over = sm(0, splatT * dur, tau, easeIn), flashF = Math.floor(splatT * dur * 12), isFlash = Math.floor(tau * 12) === flashF;
  const runP = sm(splatT * dur + .25, dur * .92, tau, easeIO), ex = lerp(x0 + 40, x1 + W2 - 60, runP), ey = y0 + hh + 70;
  paper(c); cam(c, CX + (runP - .5) * 60, CY, 1); const L = LAYOUT(); sunDot(c, ...L.sunPos(.86), 22);
  // two columns: today and tomorrow
  c.strokeStyle = PAL.ink; c.lineWidth = 2.2; squiggleText(c, x0, y0 - 30, 120, 1, { seed: 81, lineH: 14, amp: 5, width: 2, color: PAL.ink }); squiggleText(c, x1, y0 - 30, 150, 1, { seed: 82, lineH: 14, amp: 5, width: 2, color: PAL.ink });
  const crushed = over, todays = [{ t0: .3, t1: 1.4 + over * 2.2, col: PAL.fills[3] }, { t0: 1.9, t1: 2.9, col: PAL.fills[1], alpha: 1 - crushed * .85 }, { t0: 3.3, t1: 4.2, col: PAL.fills[4], alpha: 1 - crushed * .85 }, { t0: 4.6, t1: 5.5, col: PAL.fills[0], alpha: 1 - crushed * .85 }];
  timeCanvas(c, x0, y0, W2, hh, 83, { blocks: todays });
  const landed = k => sm(splatT * dur + .5 + k * .5, splatT * dur + .85 + k * .5, tau, easeOut), tomorrows = [1, 2, 3].map(k => ({ t0: .4 + (k - 1) * 1.5, t1: 1.4 + (k - 1) * 1.5, col: [PAL.fills[1], PAL.fills[4], PAL.fills[0]][k - 1], alpha: landed(k - 1) })).filter(b => b.alpha > 0);
  timeCanvas(c, x1, y0, W2, hh, 84, { blocks: tomorrows });
  // the spill: splat, droplets, then cards lying on the floor until EVA sweeps them
  if (tau >= splatT * dur) { const sx = x0 + W2 - 10, sy = y0 + (1.4 + 2.2) * hh / 6, g = sm(splatT * dur, splatT * dur + .3, tau, easeOut), rn = rng(85);
    c.fillStyle = PAL.ink; c.fill(circPath(sx, sy, 22 * g)); for (let k = 0; k < 26; k++) { const a = rn() * TAU, d = (30 + rn() * 90) * g; c.fill(circPath(sx + Math.cos(a) * d, sy + Math.sin(a) * d, (1 + rn() * 4) * g)); }
    c.strokeStyle = alpha(PAL.ink, .5); c.lineWidth = 1; c.beginPath(); c.arc(sx, sy, 60 * g, 0, TAU); c.stroke(); c.beginPath(); c.arc(sx, sy, 110 * g, 0, TAU); c.stroke();
    [0, 1, 2].forEach(k => { const l = landed(k); if (l >= 1) return; const fall = sm(splatT * dur, splatT * dur + .35, tau, easeIn), fx = lerp(sx, x0 + W2 + 40 + k * 70, fall), fy = lerp(sy, ey - 10 - k * 6, fall), rot = lerp(0, (k - 1) * .5 + .3, fall), push = clamp((ex - fx) / 80, 0, 1);
      c.save(); c.translate(fx + push * 60, fy); c.rotate(rot + push * .4); c.globalAlpha = 1 - l; clayCard(c, -60, -26, 120, 52, 86 + k, { fill: [PAL.fills[1], PAL.fills[4], PAL.fills[0]][k], r: 10 }); squiggleText(c, -44, 4, 90, 1, { seed: 87 + k, lineH: 10, amp: 3, width: 1.2, color: PAL.ink }); c.restore(); }); }
  // EVA runs along the floor sweeping the cards to tomorrow (camera follows, speed lines, ghost limbs)
  if (runP > 0 && runP < 1) { speedLines(c, ex - 70, ey - 80, 0, 88 + i, 8, .5); loops(c, ex - 80, ey - 90, 0, 89, .3, [PAL.accents[1], PAL.accents[2]]); }
  if (tau >= splatT * dur + .1) { c.save(); c.translate(ex, ey - 90); c.scale(.8, .8); drawEva(c, 'ink', { run: runP > 0 && runP < 1 ? (i % 6) / 6 : 0, arm: runP >= 1 ? 1 : .2, spark: sm(dur * .92, dur, tau), tilt: runP > 0 && runP < 1 ? .12 : 0, happy: runP >= 1 ? 1 : 0 }, 40); c.restore(); }
  if (isFlash) flash(c);
  resetT(c); tallyMarks(c, CX - 80, L.safeTop + 30, Math.min(7, Math.floor(tau * 12 / 5)), 90, PAL.ink);
  label(c, o.label ?? "Plans break. You don't.", tau, dur * .42);
};
const sceneInsights = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbNight); night(c, PAL.night, 51); const L = LAYOUT(), cx = CX, top = CY - 300, w = 760, h = 420, x0 = cx - w / 2, rn = rng(52);
  const open = sm(0, dur * .3, tau, easeOut); iris(c, ...L.sunPos(.95), lerp(30, Math.hypot(W, H), open), cc => {
    night(cc, PAL.night, 51); for (let k = 1; k <= 5; k++) dottedArc(cc, cx, top + h + 260, 120 + k * 70, PAL.chalkDim, 53 + k, 10, 1.2);
    // the day as hex cells: some light up where habits happened
    const lit = sm(dur * .15, dur * .6, tau), rl = rng(58); hexCells([x0 + 20, top + 40, w - 40, h - 80], 17, (x, y) => { const hp = hexPath(x, y, 15.5), u = rl(), on = u < .22 && u / .22 < lit; cc.strokeStyle = alpha(PAL.chalkDim, .45); cc.lineWidth = .9; cc.stroke(hp); if (on) { cc.fillStyle = rl() < .3 ? PAL.accents[1] : PAL.accents[3]; cc.globalAlpha = .8; cc.fill(hp); cc.globalAlpha = 1; } });
    cc.strokeStyle = PAL.chalk; cc.lineWidth = 2; wob(cc, rrPts(x0, top, w, h, 26), 1.6, 54, true);
    // the chart line self-draws through seven points, sparks on the peaks
    const pts = [0, 1, 2, 3, 4, 5, 6].map(k => [x0 + 60 + k * (w - 120) / 6, top + h - 60 - [.2, .45, .3, .6, .5, .85, .7][k] * (h - 120)]), sweep = sm(dur * .35, dur * .8, tau, easeIO);
    cc.strokeStyle = PAL.accents[1]; cc.lineWidth = 4; cc.lineCap = 'round'; selfDraw(cc, pts, sweep, 55, 1.5);
    pts.forEach((p, k) => { if (sweep * 6 >= k) { if (k === 3 || k === 5) aster(cc, p[0], p[1], 6, 12, PAL.accents[0], 56 + k, clamp(sweep * 6 - k, 0, 1)); else { cc.fillStyle = PAL.chalk; cc.fill(circPath(p[0], p[1], 5)); } } });
    handGlyph(cc, x0 + w - 50, top + 34, 14, PAL.chalkDim); dashedRing(cc, x0 + w - 50, top + 30, 22, PAL.chalkDim, 57, [4, 6], 1.5);
  }, PAL.night);
  sunDot(c, ...L.sunPos(.95), 22, { night: true });
  label(c, o.label ?? 'What changed?', tau, dur * .3, { night: true });
};
const sceneEva = (dur, o = {}) => (c, tau, i) => {
  const L = LAYOUT(), ex = CX - 230, ey = CY + 150, duo = tau >= dur * .14 && tau < dur * .14 + .5;
  usePalette(duo ? lbDuotone : lbNight); if (duo) paper(c); else night(c, PAL.night, 61);
  const a = L2.getContext('2d'); if (duo) paper(a); else night(a, PAL.night, 61);
  const propose = sm(dur * .3, dur * .45, tau, easeOut), stamp = sm(dur * .58, dur * .72, tau, easeOut), undo = sm(dur * .74, dur * .86, tau), jump = tau >= dur * .9 ? Math.sin(sm(dur * .9, dur, tau) * Math.PI) : 0;
  // proposal card, then the receipt stamp, then the undo arrow drawn backwards
  if (propose > 0) { const px = CX - 60, py = CY - 300, pw = 440, ph = 250; a.save(); a.globalAlpha = propose; clayCard(a, px, py, pw, ph, 62, { fill: duo ? PAL.fills[3] : PAL.fills[3] }); squiggleText(a, px + 30, py + 50, pw - 60, 3, { seed: 63, lineH: 30, amp: 5, width: 1.6, color: duo ? PAL.ink : PAL.chalk });
    const bx = px + pw - 150, by = py + ph - 62; a.fillStyle = duo ? PAL.ink : PAL.accents[0]; a.fill(rr(a, bx, by, 120, 40, 20)); squiggleText(a, bx + 26, by + 25, 70, 1, { seed: 64, lineH: 10, amp: 4, width: 2, color: PAL.paper }); a.restore(); }
  usePalette(duo ? lbDuotone : lbNight); speechBubble(a, ex - 60, ey - 400, 330, 120, [ex, ey - 200], 65, 2);
  a.save(); a.translate(ex, ey - jump * 0); a.scale(1.25, 1.25); drawEva(a, 'ink', { arm: propose > 0 ? 1 : .3, spark: propose, blink: pulse(i, 17) ? 1 : 0, happy: jump > 0 ? 1 : 0, jump }, 40); a.restore();
  if (stamp > 0) { usePalette(duo ? lbDuotone : lbNight); a.save(); a.globalAlpha = 1 - undo * .7; receiptStamp(a, CX + 240, CY - 50, stamp); a.restore(); }
  if (undo > 0) undoArrow(a, CX + 240, CY - 50, undo, 66, duo ? PAL.ink : PAL.accents[0]);
  // EvaInkReveal: she arrives through an ink blot
  const R = lerp(0, Math.hypot(W, H) * .9, sm(0, dur * .13, tau, easeOut)); blot(c, L2, ex, ey - 120, R, 67, duo ? PAL.ink : PAL.chalk);
  sunDot(c, ...L.sunPos(.97), 22, { night: !duo });
  label(c, o.label ?? 'Ask. Review. Undo.', tau, dur * .35, { night: !duo });
};
const sceneGallery = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbRiso); paper(c); dotScreen(c, rectPath(0, 0, W, H), [0, 0, W, H], { cell: 9, color: lbRiso.inks[2], density: .14, angle: .26, jitter: .3, seed: 50 });
  badges(c, o.cards || FEATURE_CARDS, { cx: CX, cy: CY - 40, r0: 60, gap: 150, size: 68, ring: PAL.ink, seed: 51, progress: sm(0, dur * .35, tau, easeOut), scale: 1 - sm(dur * .6, dur, tau, easeIn) * .985 });
  sunDot(c, CX, CY - 40, 18); if (o.label) label(c, o.label, tau, dur * .15);
};
const sceneAreas = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbRiso); paper(c); dotScreen(c, rectPath(0, 0, W, H), [0, 0, W, H], { cell: 9, color: lbRiso.inks[1], density: .1, angle: 1.31, jitter: .3, seed: 58 });
  badges(c, AREA_CARDS, { cx: CX, cy: CY - 40, r0: 40, gap: 170, size: 84, ring: PAL.ink, seed: 59, progress: sm(0, dur * .4, tau, easeOut), count: 7 });
  sunDot(c, CX, CY - 40, 18); label(c, o.label ?? 'Work. Home. Health. People.', tau, dur * .25);
};
const sceneMontage = (dur, o = {}) => (c, tau, i) => { montage(c, o.cards || FEATURE_CARDS, tau, o.per ?? .25, i); usePalette(lbRiso); sunDot(c, CX, CY + 380, 18); };
const scenePrint = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbRiso); paper(c); const L = LAYOUT(), size = L.tall ? 560 : 440, iy = CY - (L.tall ? 230 : 170), [ex, ey, er] = iconEye(CX, iy, size);
  const drop = sm(0, dur * .18, tau, easeIn), from = (typeof o.from === 'function' ? o.from() : o.from) || [CX, CY - 40], sx = lerp(from[0], ex, drop), sy = lerp(from[1], ey, drop);
  if (drop >= 1) { printIcon(c, CX, iy, size, sm(dur * .18, dur * .55, tau)); for (let b = 0; b < 4; b++) { const r = (tau - dur * .18 - b * 4 / 12) * 260; if (r > 8 && r < 420) crayon(c, ellPts(ex, ey, r, r, 0, 48), b % 2 ? LB.icon.orange : LB.icon.blue, 3.5, 40 + b, true); } }
  sunDot(c, sx, sy, drop >= 1 ? er * .78 : 18, { color: LB.sun, offset: LB.icon.orange });
  brandSignOff(c, tau, dur * .5, { y: iy + size / 2 + 120, tagline: o.tagline });
  if (o.platforms && tau >= dur - 1.5) handText(c, o.platforms, CX, Math.min(iy + size / 2 + 250, H - 40), { size: 30, ink: LB.ink, ink2: LB.icon.blue, offset: 2, align: 'center' });
};
const sceneDay = (dur, o = {}) => (c, tau, i) => {   // the board holds while a whole day passes over it (teaser)
  const T = sm(0, dur, tau), dusk = T > .55 && flicker(i, 2); usePalette(dusk ? lbEvening : lbAfternoon); paper(c); const L = LAYOUT();
  cam(c, CX, boardY(), boardScale() * .96); c.save(); c.translate(CX, boardY()); boardHome(c, 'ink', { lift: 1, done: [T > .25 ? 1 : 0, T > .5 ? 1 : 0, T > .75 ? 1 : 0], burst: [.25, .5, .75].some(t => T >= t && T < t + .12) ? 1 : 0, burstRow: T > .75 ? 2 : T > .5 ? 1 : 0, p: .3 + T * .6 }); c.restore();
  resetT(c); const [sx, sy] = L.sunPos(.1 + T * .8); sunDot(c, sx, sy, 24); tallyMarks(c, CX - 120, L.safeTop + 30, Math.floor(T * 14), 91, PAL.ink);
  label(c, o.label ?? 'for the life you actually have', tau, .2, { size: 54 });
};
const sceneArc = (dur, o = {}) => (c, tau, i) => {   // bumper: the sun arcs across, the paper flickers to dusk
  const T = sm(0, dur, tau), dusk = T > .5 && flicker(i, 2); usePalette(dusk ? lbEvening : lbMorning); paper(c); const L = LAYOUT(); dunes(c, 20);
  c.save(); c.beginPath(); c.rect(0, 0, W, L.stageBottom + 120); c.clip(); const [sx, sy] = L.sunPos(.12 + T * .76); sunRays(c, sx, sy, 40, 1 - T * .5, 22); sunDot(c, sx, sy, 40); c.restore();
  tallyMarks(c, CX - 100, L.safeTop + 30, Math.floor(T * 12), 92, PAL.ink);
};
const sceneJournal = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbPencil); paper(c); const L = LAYOUT(), top = L.stageTop + 60;
  squiggleText(c, CX - 440, top + 40, 880, 6, { seed: 100, lineH: 30, amp: 5, color: PAL.shade }); handText(c, 'today', CX - 440, top + 270, { size: 30, ink: PAL.ink, ink2: null });
  stickyNote(c, CX + 250, top + 200, 130, 101, (cc, s) => { cc.strokeStyle = PAL.ink; cc.lineWidth = 1; cc.beginPath(); for (let a = 0; a < 22; a += .2) cc.lineTo(s / 2 + Math.cos(a) * a * 2, s / 2 + Math.sin(a) * a * 2); cc.stroke(); });
  const y1 = lerp(H + 60, CY + 120, sm(0, dur * .35, tau)); section(c, y1, PAL.fills[0], 102);
  if (y1 < H) { [[CX - 330, 130, 4], [CX + 60, 110, 4], [CX + 380, 90, 3]].forEach(([x, len, d], k) => plant(c, x, H + 10, len, d, 103 + k, { leaf: PAL.accents[1], flower: PAL.accents[0] })); }
  thread(c, CX + 40, 106, PAL.accents[1]); sunDot(c, ...L.sunPos(.9), 20);
  label(c, o.label ?? 'What do I want to remember?', tau, dur * .3, { size: 56 });
};
const sceneEverywhere = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbNight); night(c, PAL.night, 71); const L = LAYOUT(), cy = CY - 60, p = sm(0, dur * .5, tau, easeOut);
  const devices = [[CX - 330, cy + 40, 200, 400, 30, 0], [CX + 60, cy - 20, 420, 320, 22, .2], [CX + 360, cy + 190, 130, 150, 34, .4]];
  devices.forEach(([x, y, w, h, r, d], k) => { const g = sm(d, d + .4, p); if (g <= 0) return; c.save(); c.strokeStyle = PAL.chalk; c.lineWidth = 2.6; selfDraw(c, rrPts(x - w / 2, y - h / 2, w, h, r, 10), g, 72 + k, 1.4, true);
    if (g >= 1) { c.fillStyle = PAL.fills[1]; c.fill(rr(c, x - w / 2 + 14, y - h / 2 + 14, w - 28, h - 28, r - 8)); surface(c, rr(c, x - w / 2 + 14, y - h / 2 + 14, w - 28, h - 28, r - 8), [x - w / 2, y - h / 2, w, h], { seed: 75 + k, alpha: .2, color: PAL.shade }); sunDot(c, x, y - h / 4, k === 2 ? 14 : 22, { night: true }); clayCard(c, x - w / 2 + 34, y + h / 8, w - 68, k === 2 ? 40 : 70, 78 + k, { mode: 'blueprint' }); }
    c.restore(); });
  if (p >= 1) { c.save(); c.strokeStyle = PAL.chalk; c.lineWidth = 2; wob(c, rrPts(CX - 130, cy - 300, 260, 54, 27), 1.4, 79, true); squiggleText(c, CX - 100, cy - 266, 200, 1, { seed: 80, lineH: 12, amp: 4, width: 1.6, color: PAL.chalk }); c.restore(); }   // a Live Activity pill
  label(c, o.label ?? 'Wherever you are.', tau, dur * .3, { night: true });
};
const scenePrivate = (dur, o = {}) => (c, tau, i) => {
  usePalette(lbNight); night(c, PAL.night, 81); const cx = CX, cy = CY - 40, s = 380, p = sm(0, dur * .5, tau, easeOut);
  const house = [[cx - s * .8, cy], [cx, cy - s * .85], [cx + s * .8, cy], [cx + s * .6, cy], [cx + s * .6, cy + s * .8], [cx - s * .6, cy + s * .8], [cx - s * .6, cy]];
  construction(c, cx, cy + 60, s * .7, 82, PAL.guide, .7); c.strokeStyle = PAL.chalk; c.lineWidth = 4; selfDraw(c, house, p, 83, 2, true);
  if (p >= 1) { loopRing(c, 'blueprint', sm(dur * .5, dur * .9, tau, easeOut), cx, cy + 190, 150, 84); c.strokeStyle = PAL.accents[1]; c.lineWidth = 4; wob(c, rrPts(cx - 34, cy - 250, 68, 52, 10), 1.5, 85, true); c.beginPath(); c.arc(cx, cy - 250, 22, Math.PI, TAU); c.stroke(); }
  sunDot(c, cx, cy + 190, 16, { night: true });
  label(c, o.label ?? 'Private by default.', tau, dur * .3, { night: true });
};

// ===================== SCORE MOTIFS (the same timeline drives the sound) =====================
const M = {
  ticks(ac, m, t0, s, d, seed) { const r = rng(seed); let t = s; while (t < s + d) { note(ac, m, pentHz(1, r() * 5 | 0) * (1 + (r() - .5) * .06), t0, t, .12, 'square', .05); t += .12 + r() * .3; } },
  swell(ac, m, t0, s, d) { note(ac, m, 55, t0, s, d + .4, 'sawtooth', .12); note(ac, m, 110, t0, s + .1, d + .2, 'sine', .15); },
  pulse(ac, m, t0, s, d, seed, oct = 0) { const r = rng(seed); for (let t = s; t < s + d; t += .5) note(ac, m, pentHz(oct, r() * 5 | 0), t0, t, .6, 'triangle', .15); },
  cue(ac, m, t0, t, k = 0) { note(ac, m, pentHz(1 + (k % 2), k % 5), t0, t, .22, 'square', .07); },
  splat(ac, m, t0, t) { noiseBurst(ac, m, t0, t, .35, .3, 9); note(ac, m, 55, t0, t, .8, 'sine', .3); },
  run(ac, m, t0, s, d, seed) { const r = rng(seed); for (let t = s; t < s + d; t += .125) note(ac, m, pentHz(1, r() * 5 | 0), t0, t, .14, 'square', .05); for (let t = s; t < s + d; t += .5) note(ac, m, pentHz(0, 0), t0, t, .4, 'sine', .12); },
  page(ac, m, t0, s, d, seed) { const r = rng(seed); for (let t = s; t < s + d; t += .75) note(ac, m, pentHz(-1, r() * 5 | 0), t0, t, .9, 'sine', .12); },
  sting(ac, m, t0, t) { [0, 1, 2, 3].forEach(k => { note(ac, m, pentHz(0, k), t0, t + k * .15, .5, 'triangle', .18); note(ac, m, pentHz(1, k), t0, t + k * .15, .5, 'sine', .08); }); note(ac, m, pentHz(0, 0), t0, t + .6, 1.6, 'sine', .25); note(ac, m, pentHz(1, 3), t0, t + .7, 1.4, 'sine', .15); },
};
// scoreFromTimeline: one motif per scene name, cues on cuts, the brand sting under every sign-off.
function scoreFromTimeline(ac, t0, dest, timeline) {
  const m = ac.createGain(); m.gain.value = .6; m.connect(dest); let s = 0;
  for (const sc of timeline) { const d = sc.dur, n = sc.name;
    if (n === 'sunrise') { M.pulse(ac, m, t0, s, d, 1, 1); note(ac, m, pentHz(-1, 0), t0, s, 1.2, 'sine', .2); }
    else if (n === 'scatter') M.ticks(ac, m, t0, s, d, 2);
    else if (n === 'blot') M.swell(ac, m, t0, s, d);
    else if (n === 'fold') { for (let k = 0; k < Math.floor(d * 4); k++) M.cue(ac, m, t0, s + k * .25, k); M.pulse(ac, m, t0, s + .5, d - .5, 3); }
    else if (n === 'home' || n === 'plan' || n === 'areas') { M.pulse(ac, m, t0, s, d, 4, 0); for (let k = 0; k < 4; k++) M.cue(ac, m, t0, s + d * (k + .6) / 8 * 2, k); }
    else if (n === 'focus') { for (let t = s; t < s + d; t += .5) note(ac, m, pentHz(0, 0), t0, t, .45, 'sine', .14); note(ac, m, pentHz(1, 2), t0, s + .2, d, 'triangle', .07); }
    else if (n === 'track' || n === 'day') { for (let k = 0; k < Math.floor(d * 12 / 3); k++) M.cue(ac, m, t0, s + .25 + k * .25, k); }
    else if (n === 'recover') { M.pulse(ac, m, t0, s, d * .22, 5, -1); M.splat(ac, m, t0, s + d * .22); M.run(ac, m, t0, s + d * .22 + .25, d * .7, 6); }
    else if (n === 'insights' || n === 'everywhere' || n === 'private') M.page(ac, m, t0, s, d, 7);
    else if (n === 'eva') { M.page(ac, m, t0, s, d, 8); M.cue(ac, m, t0, s + d * .3, 2); M.cue(ac, m, t0, s + d * .58, 4); M.cue(ac, m, t0, s + d * .74, 1); M.cue(ac, m, t0, s + d * .9, 3); }
    else if (n === 'journal') M.page(ac, m, t0, s, d, 9);
    else if (n === 'gallery') { note(ac, m, pentHz(0, 0), t0, s, 1.2, 'sine', .25); note(ac, m, pentHz(1, 2), t0, s + .4, .8, 'sine', .15); }
    else if (n === 'montage') { for (let k = 0; k < Math.floor(d * 4); k++) M.cue(ac, m, t0, s + k * .25, k); }
    else if (n === 'print' || n === 'arc') { if (n === 'arc') M.pulse(ac, m, t0, s, d, 10, 1); else { M.cue(ac, m, t0, s + d * .18, 0); M.sting(ac, m, t0, s + d * .45); } }
    s += d; }
}
