import { access, readFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const requiredRoutes = ['features', 'features/home', 'features/plan', 'features/track', 'features/journal', 'features/insights', 'features/eva', 'features/everywhere', 'privacy', 'terms', 'support'];
const requiredFeatureIds = ['life.home.orientation', 'life.plan.day', 'life.track.habits', 'life.journal', 'life.insights', 'life.eva', 'life.continuity.surfaces'];
const requiredScreenshotIds = [
  'home-command-center', 'universal-capture-review', 'plan-day-capacity', 'plan-week-workspace',
  'focus-active-session', 'track-habit-board', 'track-overview', 'track-goals-routines',
  'track-wellness', 'track-nutrition', 'track-fasting', 'track-life-moment', 'journal-day',
  'knowledge-notes', 'insights-evidence', 'eva-proposal-review', 'recovery-overdue-rescue',
  'plan-week-ipad',
];
const marketing = await readFile(join(root, 'src/content/marketing.ts'), 'utf8');
const app = await readFile(join(root, 'src/App.tsx'), 'utf8');
const capabilityMatrix = await readFile(join(root, 'docs/product/PUBLIC_CAPABILITY_MATRIX.md'), 'utf8');
const screenshotRoot = join(root, 'src/assets/marketing-screens');
const manifest = JSON.parse(await readFile(join(screenshotRoot, 'manifest.json'), 'utf8'));

for (const route of requiredRoutes) {
  const file = join(root, 'dist', route, 'index.html');
  await access(file);
  const html = await readFile(file, 'utf8');
  if (!/<title>[^<]+<\/title>/.test(html) || !/name="description" content="[^"]+"/.test(html)) {
    throw new Error(`Missing metadata in ${route}`);
  }
}

for (const id of requiredFeatureIds) {
  if (!marketing.includes(`publicId: '${id}'`)) throw new Error(`Missing public feature: ${id}`);
  if (!capabilityMatrix.includes(`\`${id}\``)) throw new Error(`Public feature is absent from capability matrix: ${id}`);
}

const manifestIds = new Set(manifest.screenshots.map((item) => item.id));
for (const id of requiredScreenshotIds) {
  if (!marketing.includes(`'${id}'`)) throw new Error(`Typed screenshot contract is missing: ${id}`);
  if (!capabilityMatrix.includes(`\`${id}\``)) throw new Error(`Screenshot is absent from capability matrix: ${id}`);
  if (!manifestIds.has(id)) throw new Error(`Screenshot manifest entry is missing: ${id}`);
}

if (!marketing.includes("https://apps.apple.com/app/id1574046107")) throw new Error('App Store URL drift');
if (!marketing.includes("support@lifeboard.app")) throw new Error('Support email drift');

const forbidden = ['secured by a recovery phrase', 'end-to-end encrypted by lifeboard', 'autonomous calendar editing', 'silent ai mutations'];
for (const phrase of forbidden) {
  if (`${marketing}\n${app}`.toLowerCase().includes(phrase)) throw new Error(`Unsupported public claim: ${phrase}`);
}

const screenshotFiles = [...marketing.matchAll(/'\.\.\/assets\/marketing-screens\/([^']+\.webp)'/g)]
  .map((match) => match[1])
  .filter((file) => file.includes('*') === false);
for (const file of screenshotFiles) {
  const bytes = (await stat(join(screenshotRoot, file))).size;
  if (bytes > 400_000) throw new Error(`${file} exceeds the 400 KB full-resolution budget`);
}

for (const item of manifest.screenshots) {
  for (const asset of [{ file: item.file, bytes: item.bytes, sha256: item.sha256, width: item.width }, ...item.variants]) {
    const file = join(screenshotRoot, asset.file);
    const content = await readFile(file);
    if (content.byteLength !== asset.bytes) throw new Error(`Manifest byte count drift: ${asset.file}`);
    const digest = createHash('sha256').update(content).digest('hex');
    if (digest !== asset.sha256) throw new Error(`Manifest checksum drift: ${asset.file}`);
    const budget = asset.width === 480 ? 100_000 : asset.width === 760 ? 200_000 : 400_000;
    if (content.byteLength > budget) throw new Error(`${asset.file} exceeds its ${budget / 1000} KB budget`);
  }
}

console.log(`Marketing checks passed: ${requiredRoutes.length + 1} routes, ${requiredFeatureIds.length} feature pillars, ${manifest.screenshots.length} approved captures with responsive variants.`);
