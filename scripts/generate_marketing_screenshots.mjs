import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { copyFile, mkdtemp, mkdir, readFile, rename, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = join(root, 'screenshots/marketing');
const targetRoot = join(root, 'src/assets/marketing-screens');
const stagingRoot = await mkdtemp(join(targetRoot, '.marketing-next-'));
const backupRoot = await mkdtemp(join(tmpdir(), 'lifeboard-marketing-backup-'));
const fixedNow = process.env.LIFEBOARD_SCREENSHOT_FIXED_NOW ?? '2026-08-13T10:00:00Z';
const capturedAt = new Date().toISOString();
const buildIdentity = execFileSync('git', ['rev-parse', '--short=12', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim();

const captures = [
  ['home-command-center', '01-home-command-center.webp', 'life-os-home'],
  ['universal-capture-review', '02-universal-capture-review.webp', 'universal-capture-review'],
  ['plan-day-capacity', '03-plan-day-capacity.webp', 'life-os-plan'],
  ['plan-week-workspace', '04-plan-week-workspace.webp', 'plan-week-workspace'],
  ['focus-active-session', '05-focus-active-session.webp', 'focus-active-session'],
  ['track-habit-board', '06-track-habit-board.webp', 'life-os-track'],
  ['track-overview', '07-track-overview.webp', 'track-overview'],
  ['track-goals-routines', '08-track-goals-routines.webp', 'track-goals-routines'],
  ['track-wellness', '09-track-wellness.webp', 'track-wellness'],
  ['track-nutrition', '10-track-nutrition.webp', 'track-nutrition'],
  ['track-fasting', '11-track-fasting.webp', 'track-fasting'],
  ['track-life-moment', '12-track-life-moment.webp', 'track-life-moment'],
  ['journal-day', '13-journal-day.webp', 'journal-day'],
  ['knowledge-notes', '14-knowledge-notes.webp', 'knowledge-notes'],
  ['insights-evidence', '15-insights-evidence.webp', 'life-os-insights'],
  ['eva-proposal-review', '16-eva-proposal-review.webp', 'life-os-eva'],
  ['recovery-overdue-rescue', '17-recovery-overdue-rescue.webp', 'life-os-recovery'],
  ['plan-week-ipad', '18-plan-week-ipad.webp', 'plan-week-ipad'],
];

const publishedFiles = [];
const manifestItems = [];

function sha256(content) {
  return createHash('sha256').update(content).digest('hex');
}

async function describe(file, width, height) {
  const content = await readFile(file);
  return { file: basename(file), width, ...(height ? { height } : {}), bytes: content.byteLength, sha256: sha256(content) };
}

function dimensions(file) {
  const output = execFileSync('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', file], { encoding: 'utf8' });
  const width = Number(output.match(/pixelWidth: (\d+)/)?.[1]);
  const height = Number(output.match(/pixelHeight: (\d+)/)?.[1]);
  if (!width || !height) throw new Error(`Could not read image dimensions: ${file}`);
  return { width, height };
}

try {
  for (const [id, sourceName, targetStem] of captures) {
    const source = join(sourceRoot, sourceName);
    if ((await stat(source)).size === 0) throw new Error(`Empty source capture: ${sourceName}`);
    const sourcePng = join(stagingRoot, `${targetStem}-source.png`);
    execFileSync('dwebp', [source, '-quiet', '-o', sourcePng]);
    const sourceDimensions = dimensions(sourcePng);

    const full = join(stagingRoot, `${targetStem}.webp`);
    const small = join(stagingRoot, `${targetStem}-480.webp`);
    const medium = join(stagingRoot, `${targetStem}-760.webp`);
    execFileSync('cwebp', ['-quiet', '-q', id === 'plan-week-ipad' ? '80' : '88', '-m', '6', sourcePng, '-o', full]);
    execFileSync('cwebp', ['-quiet', '-q', '82', '-m', '6', '-resize', '480', '0', sourcePng, '-o', small]);
    execFileSync('cwebp', ['-quiet', '-q', '84', '-m', '6', '-resize', '760', '0', sourcePng, '-o', medium]);

    const fullInfo = await describe(full, sourceDimensions.width, sourceDimensions.height);
    const smallInfo = await describe(small, 480, Math.round(sourceDimensions.height * 480 / sourceDimensions.width));
    const mediumInfo = await describe(medium, 760, Math.round(sourceDimensions.height * 760 / sourceDimensions.width));
    if (fullInfo.bytes > 400_000 || smallInfo.bytes > 100_000 || mediumInfo.bytes > 200_000) {
      throw new Error(`Screenshot budget exceeded: ${targetStem}`);
    }
    publishedFiles.push(fullInfo.file, smallInfo.file, mediumInfo.file);
    manifestItems.push({
      id,
      device: id === 'plan-week-ipad'
        ? (process.env.LIFEBOARD_MARKETING_IPAD_DEVICE ?? 'LifeBoard Test iPad')
        : (process.env.LIFEBOARD_README_SCREENSHOT_DEVICE ?? 'LifeBoard Test iPhone'),
      ...fullInfo,
      variants: [smallInfo, mediumInfo],
    });
  }

  const manifest = {
    schemaVersion: 1,
    capturedAt,
    fixedNow,
    buildIdentity,
    device: process.env.LIFEBOARD_README_SCREENSHOT_DEVICE ?? 'LifeBoard Test iPhone',
    devices: [
      process.env.LIFEBOARD_README_SCREENSHOT_DEVICE ?? 'LifeBoard Test iPhone',
      process.env.LIFEBOARD_MARKETING_IPAD_DEVICE ?? 'LifeBoard Test iPad',
    ],
    locale: 'en_US',
    timezone: 'UTC',
    appearance: 'Light',
    dynamicType: 'UICTContentSizeCategoryL',
    sourceTest: 'LifeBoardUITests/AppStoreScreenshotUITests/testCaptureReadmeLifeOSTour',
    screenshots: manifestItems,
  };
  await writeFile(join(stagingRoot, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  publishedFiles.push('manifest.json');

  await mkdir(backupRoot, { recursive: true });
  for (const file of publishedFiles) {
    try { await copyFile(join(targetRoot, file), join(backupRoot, file)); } catch { /* A first publish has no prior file. */ }
    await rename(join(stagingRoot, file), join(targetRoot, file));
  }

  try {
    execFileSync('npm', ['run', 'build'], { cwd: root, stdio: 'inherit' });
    execFileSync('npm', ['run', 'check:marketing'], { cwd: root, stdio: 'inherit' });
  } catch (error) {
    for (const file of publishedFiles) {
      try { await copyFile(join(backupRoot, file), join(targetRoot, file)); } catch { /* Nothing to restore. */ }
    }
    throw error;
  }
} finally {
  await rm(stagingRoot, { recursive: true, force: true });
  await rm(backupRoot, { recursive: true, force: true });
}

console.log(`Published ${manifestItems.length} populated marketing captures with responsive variants.`);
