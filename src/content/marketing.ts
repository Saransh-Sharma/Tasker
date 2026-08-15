const marketingAssets = import.meta.glob<string>('../assets/marketing-screens/*.webp', {
  eager: true,
  query: '?url',
  import: 'default',
});

function marketingAsset(name: string): string {
  const value = marketingAssets[`../assets/marketing-screens/${name}`];
  if (!value) throw new Error(`Missing marketing screenshot asset: ${name}`);
  return value;
}

function screenshot(
  id: string,
  stem: string,
  alt: string,
  width = 1206,
  height = 2622,
): ScreenshotSpec {
  return {
    id,
    src: marketingAsset(`${stem}.webp`),
    src480: marketingAsset(`${stem}-480.webp`),
    src760: marketingAsset(`${stem}-760.webp`),
    alt,
    width,
    height,
  };
}

export const APP_STORE_URL = 'https://apps.apple.com/app/id1574046107';
export const SUPPORT_EMAIL = 'support@getlifeboard.app';

export type MarketingPath =
  | '/'
  | '/features/'
  | '/features/home/'
  | '/features/plan/'
  | '/features/track/'
  | '/features/journal/'
  | '/features/insights/'
  | '/features/eva/'
  | '/features/everywhere/'
  | '/privacy/'
  | '/terms/'
  | '/support/';

export type MarketingRoute = MarketingPath;

export type ClaimStatus = 'available' | 'conditional' | 'private-preview' | 'future';

export type PlatformRequirement = {
  platforms: readonly string[];
  qualification: string;
};

export type ScreenshotSpec = {
  id: string;
  src: string;
  src480: string;
  src760: string;
  alt: string;
  width: number;
  height: number;
};

export type ScreenshotManifest = {
  capturedAt: string;
  buildIdentity: string;
  device: string;
  fixedNow: string;
  screenshots: readonly ScreenshotSpec[];
};

export type FeatureChapter = {
  title: string;
  copy: string;
  points: string[];
};

export type FeaturePage = {
  slug: Exclude<MarketingPath, '/' | '/features/' | '/privacy/' | '/terms/' | '/support/'>;
  id: string;
  publicId: string;
  number: string;
  eyebrow: string;
  title: string;
  summary: string;
  promise: string;
  status: ClaimStatus;
  availability: string;
  screenshot: ScreenshotSpec;
  proofScreenshots?: readonly ScreenshotSpec[];
  scenario: string;
  jobs: readonly string[];
  chapters: FeatureChapter[];
  connected: string[];
};

export type PublicFeature = {
  id: string;
  pillar: FeaturePage['id'];
  route: FeaturePage['slug'];
  status: ClaimStatus;
  requirement: PlatformRequirement;
  catalogAnchor: string;
  screenshotIds: readonly string[];
  outcome: string;
};

export const screenshots = {
  home: screenshot('home-command-center', 'life-os-home', 'LifeBoard Home showing focus, health signals, today’s commitments, Universal Capture, and the five Life OS roots.'),
  capture: screenshot('universal-capture-review', 'universal-capture-review', 'Universal Capture reviewing a realistically written commitment before it becomes a structured task.'),
  plan: screenshot('plan-day-capacity', 'life-os-plan', 'LifeBoard Plan showing day capacity and a calendar-aware timeline.'),
  week: screenshot('plan-week-workspace', 'plan-week-workspace', 'LifeBoard planning workspace showing populated commitments and tasks for the week.'),
  focus: screenshot('focus-active-session', 'focus-active-session', 'LifeBoard showing a populated focus context for protected work.'),
  track: screenshot('track-habit-board', 'life-os-track', 'LifeBoard Habit Board showing a populated week of completion, recovery, and lapse history.'),
  trackOverview: screenshot('track-overview', 'track-overview', 'LifeBoard Track showing populated wellbeing and personal-system signals.'),
  goals: screenshot('track-goals-routines', 'track-goals-routines', 'LifeBoard showing a realistic goal, linked progress, and repeatable routines.'),
  wellness: screenshot('track-wellness', 'track-wellness', 'LifeBoard Wellness showing realistic movement and care evidence with clear source context.'),
  nutrition: screenshot('track-nutrition', 'track-nutrition', 'LifeBoard tracking view populated with realistic daily records.'),
  fasting: screenshot('track-fasting', 'track-fasting', 'LifeBoard showing a realistic active-day tracking context.'),
  moment: screenshot('track-life-moment', 'track-life-moment', 'LifeBoard showing realistic personal commitments and meaningful dates in context.'),
  journal: screenshot('journal-day', 'journal-day', 'LifeBoard reflection view populated with a realistic day review.'),
  knowledge: screenshot('knowledge-notes', 'knowledge-notes', 'LifeBoard showing realistic reflection context and connected personal knowledge.'),
  insights: screenshot('insights-evidence', 'life-os-insights', 'LifeBoard Insights showing seven-day evidence grouped by source area.'),
  eva: screenshot('eva-proposal-review', 'life-os-eva', 'LifeBoard EVA proposing a realistic recovery plan for work and life-admin commitments.'),
  recovery: screenshot('recovery-overdue-rescue', 'life-os-recovery', 'LifeBoard Overdue Rescue presenting a realistic passport task with reviewable choices.'),
  ipadWeek: screenshot('plan-week-ipad', 'plan-week-ipad', 'LifeBoard on iPad showing a populated regular-width planning and reflection workspace.', 1668, 2420),
} satisfies Record<string, ScreenshotSpec>;

export const screenshotManifest: ScreenshotManifest = {
  capturedAt: '2026-08-13T09:20:22Z',
  buildIdentity: 'd6986a51cca2',
  device: 'LifeBoard Test iPhone',
  fixedNow: '2026-08-13T10:00:00Z',
  screenshots: Object.values(screenshots),
};

export const operatingLoop = [
  ['Orient', 'See the day, your capacity, and the few signals that can change the next decision.'],
  ['Capture', 'Put a task, thought, note, measurement, or commitment somewhere trustworthy before it disappears.'],
  ['Organize', 'Connect responsibilities to the life area, project, goal, routine, or body of knowledge they serve.'],
  ['Plan', 'Place flexible work around fixed reality without confusing a planned day with a true deadline.'],
  ['Focus or track', 'Start the next action, run a routine, or record useful evidence with minimal setup.'],
  ['Recover', 'Rescue overdue work, reduce the day, or resume after interruption without punishment.'],
  ['Reflect', 'Review what happened with source, timeframe, freshness, and uncertainty kept visible.'],
  ['Adapt', 'Change the system deliberately, preserve history, and carry forward only what still matters.'],
] as const;

export const lifeDomains = [
  ['Work & career', 'Projects, meetings, deliverables, deep work, follow-ups, and decisions.'],
  ['Life admin', 'Home, errands, appointments, documents, bills, and recurring responsibilities.'],
  ['Health & self', 'Habits, routines, movement, sleep, nutrition, hydration, fasting, and recovery.'],
  ['Relationships', 'Meaningful dates, commitments, shared plans, and intentional follow-up.'],
  ['Learning & growth', 'Reading, courses, practice, goals, notes, and evidence of progress.'],
  ['Creativity & fun', 'Ideas, creative projects, recreation, and deliberately unstructured time.'],
  ['Money', 'Tasks, projects, habits, goals, and reminders—without pretending to be financial advice.'],
] as const;

export const featurePages: FeaturePage[] = [
  {
    slug: '/features/home/',
    id: 'home',
    publicId: 'life.home.orientation',
    number: '01',
    eyebrow: 'Orient and capture',
    title: 'A calm command center for the day you actually have.',
    summary: 'Home brings focus, tasks, habits, routines, schedule context, health signals, and recovery into one readable starting point.',
    promise: 'Know what matters now without reconciling five separate systems.',
    status: 'available',
    availability: 'Core workflows work locally. Calendar, Health, and sensitive cards appear only with the relevant permission and consent.',
    screenshot: screenshots.home,
    proofScreenshots: [screenshots.capture, screenshots.recovery],
    scenario: 'Start with one intentional focus, see the fixed commitments around it, capture the thought that arrived overnight, and keep the rest of the system close without letting it take over the screen.',
    jobs: ['Re-enter the day without scanning several apps', 'Capture something quickly without losing the review boundary', 'Reduce or repair the day when capacity changes'],
    chapters: [
      {
        title: 'Build your life structure',
        copy: 'Onboarding creates a useful starting system without making configuration the first project.',
        points: ['Custom life areas and starter structures', 'Nested projects, sections, tags, tasks, habits, routines, and goals', 'Resumable setup with just-in-time permissions'],
      },
      {
        title: 'See the next decision',
        copy: 'Adaptive Home assembles a projection from the records you already own.',
        points: ['Focus Now and a readable day timeline', 'Smart, Work, Personal, and Low Energy modes', 'Customizable cards and consent-aware signals'],
      },
      {
        title: 'Capture once, route correctly',
        copy: 'The persistent composer accepts typing or live dictation and keeps classification behind a review boundary.',
        points: ['Tasks, habits, journal, notes, trackers, mood, hydration, medication events, routines, and time blocks', 'Deterministic commands and structured language parsing', 'Draft preservation, clarification, and EVA fallback'],
      },
      {
        title: 'Treat recovery as normal',
        copy: 'The Daily Loop includes Commit, Act, Repair, Close, and Rest so a changed day does not become a failed day.',
        points: ['Minimum Viable Day', 'Overdue Rescue and replan', 'Receipt-backed changes and Undo where supported'],
      },
    ],
    connected: ['Plan', 'Track', 'EVA'],
  },
  {
    slug: '/features/plan/',
    id: 'plan',
    publicId: 'life.plan.day',
    number: '02',
    eyebrow: 'Plan around reality',
    title: 'Turn intention into time without overfilling the day.',
    summary: 'Plan combines tasks, estimates, working hours, internal time blocks, and read-only calendar commitments to show what can actually fit.',
    promise: 'Make a realistic plan, protect attention, and repair it when circumstances change.',
    status: 'conditional',
    availability: 'Calendar context is optional and read-only. LifeBoard changes its own tasks, plans, and time blocks—not external events.',
    screenshot: screenshots.plan,
    proofScreenshots: [screenshots.week, screenshots.focus, screenshots.ipadWeek],
    scenario: 'Triage the Inbox, place the launch brief into a real opening, keep a meeting fixed, move a small admin task later, and begin a focused session with the right context attached.',
    jobs: ['Separate true deadlines from intended work days', 'See open capacity around fixed commitments', 'Turn a plan into a focused, recoverable session'],
    chapters: [
      {
        title: 'Four planning lenses',
        copy: 'Inbox, Day, Week, and Backlog let the same canonical work answer different planning questions.',
        points: ['Timeline and accessible agenda views', 'Search, filters, batch selection, placement, and unscheduling', 'Deadline, planned day, and scheduled time remain distinct'],
      },
      {
        title: 'Capacity you can explain',
        copy: 'Working hours, fixed commitments, estimates, open gaps, and conflicts form one honest capacity story.',
        points: ['Read-only calendar awareness', 'Over-capacity and stale-context labels', 'Task-fit hints using duration, energy, context, readiness, and project'],
      },
      {
        title: 'Build the week directly',
        copy: 'This Week replaces a brittle planning wizard with concrete source lanes and immediate placement.',
        points: ['Overdue, Inbox, and Anytime lanes', 'Today, near-term days, and Later This Week', 'Bulk distribution, intention, meetings, and overload recovery'],
      },
      {
        title: 'Focus with a durable state',
        copy: 'Run scoped or unscoped sessions and record what interrupted or completed the work.',
        points: ['Pause, resume, finish, abandon, and startup repair', 'Interruption reasons, outcomes, reflection, and history', 'Notifications and Live Activity where supported'],
      },
    ],
    connected: ['Home', 'Insights', 'EVA'],
  },
  {
    slug: '/features/track/',
    id: 'track',
    publicId: 'life.track.habits',
    number: '03',
    eyebrow: 'Sustain and learn',
    title: 'Track life systems without turning life into a score.',
    summary: 'Habits, goals, routines, trackers, care, wellness, nutrition, fasting, and meaningful dates share one evidence-aware home.',
    promise: 'Record what matters, correct it honestly, and keep missing evidence distinct from failure.',
    status: 'conditional',
    availability: 'Health and connected evidence depend on device support and permission. Manual recording remains available.',
    screenshot: screenshots.track,
    proofScreenshots: [screenshots.trackOverview, screenshots.goals, screenshots.wellness, screenshots.nutrition, screenshots.fasting, screenshots.moment],
    scenario: 'Complete a morning habit, resume a shutdown routine, log hydration, review a goal sample, record lunch, and let a missed day remain an honest gap rather than a moral verdict.',
    jobs: ['Sustain routines without demanding perfect streaks', 'Connect daily evidence to goals and care systems', 'Keep health and wellbeing records correctable and source-aware'],
    chapters: [
      {
        title: 'Habits with resilience',
        copy: 'Habit definitions, schedules, outcomes, corrections, pauses, and archives stay distinct from rewards.',
        points: ['Binary, quantity, and count outcomes', 'Board history, streak strength, misses, and recovery', 'Quiet Tracking for low-pressure multi-habit logging'],
      },
      {
        title: 'Goals and routines',
        copy: 'Goals connect direction to evidence; routines turn repeatable work into durable, resumable runs.',
        points: ['Typed progress samples and milestones', 'Links to tasks, habits, routines, and trackers', 'Ordered or branching task, check-in, timer, instruction, and choice steps'],
      },
      {
        title: 'Wellness and care evidence',
        copy: 'Track personal measures without manufacturing diagnosis or false precision.',
        points: ['Hydration, mood, energy, medication events, body metrics, movement, workouts, and sleep', 'Manual fallback when Health access is denied', 'Source, freshness, partial sync, explicit zero, and corrections'],
      },
      {
        title: 'Nutrition, fasting, and moments',
        copy: 'Keep food, voluntary fasting, and meaningful dates useful without forcing them into task semantics.',
        points: ['Food library, recipes, meals, serving conversions, reports, and reviewable barcode lookup', 'Fasting targets, history, early completion, reminders, and startup repair', 'Recurring or one-time Life Moments with timezone-aware countdowns'],
      },
    ],
    connected: ['Home', 'Journal', 'Insights'],
  },
  {
    slug: '/features/journal/',
    id: 'journal',
    publicId: 'life.journal',
    number: '04',
    eyebrow: 'Remember with context',
    title: 'A private place for lived experience and working knowledge.',
    summary: 'Journal, Notes, and Knowledge keep reflection, reference material, decisions, attachments, and search connected without collapsing them into tasks.',
    promise: 'Capture the context behind the plan and find it again when it matters.',
    status: 'conditional',
    availability: 'Audio, camera, photos, files, transcription, and biometric protection depend on device capability and permission.',
    screenshot: screenshots.journal,
    proofScreenshots: [screenshots.knowledge],
    scenario: 'Record a short evening reflection, keep the original audio if transcription is delayed, scan a receipt, link a launch note, and find it later without exposing private text through a widget or system search preview.',
    jobs: ['Preserve thoughts and source material in the moment', 'Build connected notes without losing day context', 'Find private knowledge later with clear protection states'],
    chapters: [
      {
        title: 'Journal by day',
        copy: 'Private entries can combine text, mood, energy, voice, scans, photos, and files.',
        points: ['On-device transcription where available', 'Original-audio durability and attachment recovery', 'Day-based search, protected routes, and deletion of derived indexes'],
      },
      {
        title: 'Notes and Knowledge',
        copy: 'Reference material gets its own structure, editor, links, attachments, and lifecycle.',
        points: ['Spaces, folders, tags, smart collections, and templates', 'TextKit editing, links, scans, files, and indexed search', 'Pin, favorite, secure, trash, restore, and batch actions'],
      },
      {
        title: 'Reflection that changes the system',
        copy: 'Daily and weekly reflection links observations to the records that support them.',
        points: ['Wins, friction, capacity, habits, goals, health signals, and carry-forward', 'Evidence links and explicit insufficient-data language', 'Plan changes remain reviewable mutations'],
      },
    ],
    connected: ['Track', 'Insights', 'EVA'],
  },
  {
    slug: '/features/insights/',
    id: 'insights',
    publicId: 'life.insights',
    number: '05',
    eyebrow: 'Evidence before judgment',
    title: 'Notice what changed—and what the evidence can actually support.',
    summary: 'Insights turns task, focus, habit, goal, health, and reflection history into explanations with source, timeframe, freshness, and limitations.',
    promise: 'Learn from patterns without shame, opaque scoring, or invented certainty.',
    status: 'available',
    availability: 'Reports remain useful with sparse or partial data and state clearly when more history is needed.',
    screenshot: screenshots.insights,
    scenario: 'Review the week, see that the available evidence is complete but still too young for a confident pattern, then ask EVA a follow-up without converting correlation into causation.',
    jobs: ['Understand what changed without fake certainty', 'Trace a pattern back to its supporting records', 'Use rewards as feedback without turning life into a score'],
    chapters: [
      {
        title: 'Today, trends, review, experience',
        copy: 'Different lenses answer what changed, what persisted, and what deserves adjustment.',
        points: ['Timeframe and evidence-source disclosure', 'Text summaries alongside charts', 'Sparse, partial, stale, unavailable, and deleted evidence remain distinct'],
      },
      {
        title: 'Momentum without manipulation',
        copy: 'XP, levels, badges, achievements, and streak relationships recognize applied progress without becoming the authority for it.',
        points: ['Idempotent reward ledger', 'No duplicate rewards after retry or sync', 'Habit truth remains separate from reward presentation'],
      },
      {
        title: 'Review into action',
        copy: 'Insights can lead to a reflection, plan change, or EVA question while preserving the evidence trail.',
        points: ['Weekly review and linked evidence', 'Explainable follow-up prompts', 'No clinical, causal, or moral claims from incomplete records'],
      },
    ],
    connected: ['Plan', 'Track', 'EVA'],
  },
  {
    slug: '/features/eva/',
    id: 'eva',
    publicId: 'life.eva',
    number: '06',
    eyebrow: 'A chief of staff, not an autopilot',
    title: 'Ask for help without handing over the wheel.',
    summary: 'EVA can understand the day, retrieve relevant context, break down work, explain evidence, and prepare changes for review.',
    promise: 'Get useful assistance while meaningful actions remain visible, bounded, and reversible.',
    status: 'conditional',
    availability: 'Model availability varies by device, downloaded runtime, connectivity, and the context grants you choose.',
    screenshot: screenshots.eva,
    scenario: 'Ask EVA to rescue overdue admin work while protecting a launch block. Review the proposed changes, edit anything that feels wrong, apply deliberately, and use the receipt or Undo if the plan needs to change again.',
    jobs: ['Understand a crowded day in context', 'Break difficult work into a smaller next action', 'Prepare changes without surrendering approval or Undo'],
    chapters: [
      {
        title: 'Context with boundaries',
        copy: 'Local context is preferred and protected categories require explicit grants for eligible remote work.',
        points: ['Day overview, selected attachments, task retrieval, and user-controlled memory', 'Category-specific privacy controls', 'No private widget, Watch, notification, Spotlight, or lock-screen expansion'],
      },
      {
        title: 'Conversation that stays usable',
        copy: 'Threads, prompt chips, slash commands, attachments, streaming, and model state remain visible and controllable.',
        points: ['Stop, Continue, Retry, and edit', 'Downloading, unavailable, offline, partial, failed, and stale states', 'Deterministic fallbacks where model work is unnecessary or unavailable'],
      },
      {
        title: 'Propose before acting',
        copy: 'Consequential output crosses an explicit transaction boundary.',
        points: ['Explanation or diff preview', 'Apply, Edit, or Not Now', 'Current-state validation, partial-result disclosure, receipt, and Undo'],
      },
    ],
    connected: ['Home', 'Plan', 'Insights'],
  },
  {
    slug: '/features/everywhere/',
    id: 'everywhere',
    publicId: 'life.continuity.surfaces',
    number: '07',
    eyebrow: 'Private continuity',
    title: 'The right piece of your system, wherever you need it.',
    summary: 'LifeBoard extends glanceable, redacted projections and stable actions across Apple devices without creating parallel stores.',
    promise: 'Capture, glance, and continue while the main app remains the source of truth.',
    status: 'conditional',
    availability: 'Individual surfaces depend on platform, entitlement, permission, connectivity, and installed companion targets.',
    screenshot: screenshots.recovery,
    proofScreenshots: [screenshots.ipadWeek],
    scenario: 'Capture from the share sheet or Watch, start Focus from a shortcut, glance at a widget, follow a notification into the exact record, and keep working locally when an external dependency is offline.',
    jobs: ['Capture at the edge without creating duplicate records', 'Glance safely without exposing unrestricted private content', 'Continue across screen sizes and temporary connectivity loss'],
    chapters: [
      {
        title: 'Apple system surfaces',
        copy: 'Extensions receive small, versioned, redacted envelopes instead of direct database access.',
        points: ['Widgets and interactive App Intents', 'Focus, fasting, and routine Live Activities', 'Siri and App Shortcuts, Spotlight, notifications, and typed deep links'],
      },
      {
        title: 'Capture beyond the phone',
        copy: 'Share Extension and Watch capture use durable outboxes and stable identity.',
        points: ['Text, link, file, and media handoff', 'Watch text or audio capture with retry', 'Reviewable destination remains the final commit boundary where required'],
      },
      {
        title: 'Adapt to the device',
        copy: 'iPad and supported Mac environments expose wider layouts, keyboard access, pointer feedback, and native menus.',
        points: ['Adaptive columns and content-first accessibility layouts', 'Keyboard navigation and shortcuts where implemented', 'Window resizing without clipping or changing data authority'],
      },
      {
        title: 'Local-first and recoverable',
        copy: 'Optional cloud continuity and external integrations never become alternate sources of truth.',
        points: ['Offline-safe local work', 'Freshness, partial sync, conflict, quota, and protected-data states', 'Recovery rebuilds derived indexes and projections without discarding canonical records'],
      },
    ],
    connected: ['Home', 'Plan', 'EVA'],
  },
];

export const routeMetadata: Record<MarketingPath, { title: string; description: string }> = {
  '/': {
    title: 'LifeBoard — One place to run the life you actually have',
    description: 'A private Life OS for planning work, sustaining routines, understanding evidence, recovering from imperfect days, and keeping every part of life connected.',
  },
  '/features/': {
    title: 'LifeBoard features — Explore the complete Life OS',
    description: 'Explore Home, planning, habits, health, Journal, Knowledge, Insights, EVA, and Apple ecosystem continuity in LifeBoard.',
  },
  '/features/home/': { title: 'Home and Universal Capture — LifeBoard', description: featurePages[0].summary },
  '/features/plan/': { title: 'Plan, Week, and Focus — LifeBoard', description: featurePages[1].summary },
  '/features/track/': { title: 'Habits, Health, and Life Tracking — LifeBoard', description: featurePages[2].summary },
  '/features/journal/': { title: 'Journal, Notes, and Knowledge — LifeBoard', description: featurePages[3].summary },
  '/features/insights/': { title: 'Evidence-led Insights — LifeBoard', description: featurePages[4].summary },
  '/features/eva/': { title: 'EVA, your private chief of staff — LifeBoard', description: featurePages[5].summary },
  '/features/everywhere/': { title: 'LifeBoard across your Apple devices', description: featurePages[6].summary },
  '/privacy/': { title: 'Privacy — LifeBoard', description: 'How LifeBoard keeps core workflows local-first and minimizes sensitive context across devices and integrations.' },
  '/terms/': { title: 'Terms — LifeBoard', description: 'The conditions for downloading and using LifeBoard.' },
  '/support/': { title: 'Support — LifeBoard', description: 'Get help with LifeBoard setup, permissions, sync, recovery, or product questions.' },
};

const featureCatalogAnchors: Record<FeaturePage['id'], string> = {
  home: '#adaptive-home',
  plan: '#plan-lenses-and-schedule-capacity',
  track: '#habits-and-quiet-tracking',
  journal: '#journal-and-durable-media',
  insights: '#insights-and-evidence-disclosure',
  eva: '#eva-assistant',
  everywhere: '#share-extension-watch-ipad-and-catalyst',
};

export const publicFeatures: PublicFeature[] = featurePages.map((page) => ({
  id: page.publicId,
  pillar: page.id,
  route: page.slug,
  status: page.status,
  requirement: {
    platforms: page.id === 'everywhere' ? ['iPhone', 'iPad', 'Apple Watch', 'supported Mac'] : ['iPhone', 'iPad'],
    qualification: page.availability,
  },
  catalogAnchor: featureCatalogAnchors[page.id],
  screenshotIds: [page.screenshot.id],
  outcome: page.promise,
}));
