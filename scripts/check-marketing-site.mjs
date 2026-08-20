import { access, readFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const pagesBase = '/';
const siteOrigin = 'https://getlifeboard.app';
const requiredRoutes = ['features', 'features/home', 'features/plan', 'features/track', 'features/journal', 'features/insights', 'features/eva', 'features/everywhere', 'privacy', 'terms', 'support'];
const webIcons = [
  { file: 'lifeboard-app-icon-32.png', width: 32, height: 32 },
  { file: 'lifeboard-app-icon-180.png', width: 180, height: 180 },
  { file: 'lifeboard-icon-512.png', width: 512, height: 512 },
];
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

const generatedPages = [
  { route: '/', file: join(root, 'dist', 'index.html') },
  ...requiredRoutes.map((route) => ({ route: `/${route}/`, file: join(root, 'dist', route, 'index.html') })),
  { route: '/404.html', file: join(root, 'dist', '404.html') },
];

for (const { route, file } of generatedPages) {
  await access(file);
  const html = await readFile(file, 'utf8');
  if (!/<title>[^<]+<\/title>/.test(html) || !/name="description" content="[^"]+"/.test(html)) {
    throw new Error(`Missing metadata in ${route}`);
  }
  if (/(?:src|href)="\/LifeBoard\/(?:assets\/|[^"]*(?:icon|favicon))/i.test(html)) {
    throw new Error(`Legacy /LifeBoard/ deployment asset path in ${route}`);
  }
  if (/(?:src|href)="\/Tasker\//i.test(html)) throw new Error(`Legacy /Tasker/ deployment path in ${route}`);
  if (!html.includes(`src="${pagesBase}assets/`)) throw new Error(`Missing ${pagesBase} JavaScript asset path in ${route}`);
  if (!html.includes(`href="${pagesBase}assets/`)) throw new Error(`Missing ${pagesBase} stylesheet asset path in ${route}`);
  if (/href="\.\/[^"]*icon/i.test(html)) throw new Error(`Route-relative icon path in ${route}`);
  if (!html.includes(`href="${pagesBase}lifeboard-app-icon-32.png"`)) throw new Error(`Missing app favicon path in ${route}`);
  if (!html.includes(`href="${pagesBase}lifeboard-app-icon-180.png"`)) throw new Error(`Missing app touch-icon path in ${route}`);
  if (route !== '/404.html' && !html.includes(`<link rel="canonical" href="${siteOrigin}${route}" />`)) {
    throw new Error(`Missing canonical custom-domain URL in ${route}`);
  }
}

function pngDimensions(content, file) {
  const signature = '89504e470d0a1a0a';
  if (content.length < 24 || content.subarray(0, 8).toString('hex') !== signature || content.subarray(12, 16).toString('ascii') !== 'IHDR') {
    throw new Error(`Invalid PNG icon: ${file}`);
  }
  return { width: content.readUInt32BE(16), height: content.readUInt32BE(20) };
}

for (const icon of webIcons) {
  for (const directory of ['public', 'dist']) {
    const file = join(root, directory, icon.file);
    const content = await readFile(file);
    const dimensions = pngDimensions(content, file);
    if (dimensions.width !== icon.width || dimensions.height !== icon.height) {
      throw new Error(`${directory}/${icon.file} must be ${icon.width}x${icon.height}, found ${dimensions.width}x${dimensions.height}`);
    }
  }
}

const appIcon180 = await readFile(join(root, 'LifeBoard/Assets.xcassets/AppIcon.appiconset/Icon@3x.png'));
const webIcon180 = await readFile(join(root, 'public/lifeboard-app-icon-180.png'));
if (!appIcon180.equals(webIcon180)) throw new Error('The 180px web icon does not match the app icon');

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
if (!marketing.includes("support@getlifeboard.app")) throw new Error('Support email drift');

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

console.log(`Marketing checks passed: ${generatedPages.length} pages, ${webIcons.length} app-icon assets, ${requiredFeatureIds.length} feature pillars, ${manifest.screenshots.length} approved captures with responsive variants.`);
