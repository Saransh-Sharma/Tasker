import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const template = await readFile(join(dist, 'index.html'), 'utf8');

const routes = {
  '/': ['LifeBoard — One place to run the life you actually have', 'A private, recovery-aware Life OS for work, home, health, routines, plans, and reflections.'],
  '/features/': ['LifeBoard features — Your whole Life OS', 'Explore the connected Home, Plan, Track, Journal, Insights, EVA, and Apple ecosystem capabilities in LifeBoard.'],
  '/features/home/': ['Home — Orient, capture, and recover | LifeBoard', 'See the Adaptive Home, Universal Capture, Daily Loop, life areas, projects, tasks, and recovery workflows in LifeBoard.'],
  '/features/plan/': ['Plan — Turn intention into time | LifeBoard', 'Plan days and weeks with capacity, calendar context, scheduling, Focus, Backlog, and weekly review.'],
  '/features/track/': ['Track — Care for the systems that sustain you | LifeBoard', 'Track habits, goals, routines, wellbeing, meals, fasting, and meaningful Life Moments without perfection pressure.'],
  '/features/journal/': ['Journal — Keep context, not clutter | LifeBoard', 'Capture journals, audio, scans, files, photos, notes, knowledge, and searchable reflection in one private system.'],
  '/features/insights/': ['Insights — Learn from evidence, honestly | LifeBoard', 'Explore trends, reviews, achievements, XP, and evidence-aware insights that make uncertainty visible.'],
  '/features/eva/': ['EVA — Assistance you stay in control of | LifeBoard', 'Use context controls, retrieval, reviewable proposals, Apply, receipts, and Undo with LifeBoard’s private assistant.'],
  '/features/everywhere/': ['Everywhere — Continue across your Apple devices | LifeBoard', 'Use LifeBoard with widgets, Live Activities, Siri, Spotlight, Share Extension, Watch, iPad, Mac, sync, and offline workflows.'],
  '/privacy/': ['Privacy | LifeBoard', 'Understand LifeBoard’s local-first storage, optional iCloud continuity, permission boundaries, reviewable assistance, and redacted surfaces.'],
  '/terms/': ['Terms | LifeBoard', 'Read the terms and important capability boundaries for using LifeBoard.'],
  '/support/': ['Support | LifeBoard', 'Get practical LifeBoard help for setup, permissions, syncing, recovery, and contacting support.'],
};

function escaped(value) {
  return value.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}

for (const [route, [title, description]] of Object.entries(routes)) {
  const relative = route === '/' ? '' : route.slice(1);
  const outputDir = join(dist, relative);
  await mkdir(outputDir, { recursive: true });
  const html = template
    .replace(/<title>.*?<\/title>/, `<title>${escaped(title)}</title>`)
    .replace(/<meta name="description" content="[^"]*"\s*\/>/, `<meta name="description" content="${escaped(description)}" />`)
    .replace(/<meta property="og:title" content="[^"]*"\s*\/>/, `<meta property="og:title" content="${escaped(title)}" />`)
    .replace(/<meta property="og:description" content="[^"]*"\s*\/>/, `<meta property="og:description" content="${escaped(description)}" />`)
    .replace('</head>', `    <link rel="canonical" href="https://getlifeboard.app/LifeBoard${route}" />\n  </head>`);
  await writeFile(join(outputDir, 'index.html'), html);
}

const notFound = template
  .replace(/<title>.*?<\/title>/, '<title>Page not found | LifeBoard</title>')
  .replace(/<meta name="description" content="[^"]*"\s*\/>/, '<meta name="description" content="Return to the LifeBoard Life OS homepage." />')
  .replace(/<meta property="og:title" content="[^"]*"\s*\/>/, '<meta property="og:title" content="Page not found | LifeBoard" />')
  .replace(/<meta property="og:description" content="[^"]*"\s*\/>/, '<meta property="og:description" content="Return to the LifeBoard Life OS homepage." />');
await writeFile(join(dist, '404.html'), notFound);
