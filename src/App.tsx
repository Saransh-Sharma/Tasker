import { useEffect, useState, type ReactNode } from 'react';
import appIcon from './assets/hero.png';
import {
  APP_STORE_URL,
  SUPPORT_EMAIL,
  featurePages,
  lifeDomains,
  operatingLoop,
  routeMetadata,
  screenshots,
  type FeaturePage,
  type MarketingPath,
  type ScreenshotSpec,
} from './content/marketing';

const basePath = import.meta.env.BASE_URL.replace(/\/$/, '');
const knownPaths = new Set<MarketingPath>(Object.keys(routeMetadata) as MarketingPath[]);

function siteHref(path: MarketingPath): string {
  if (path === '/') return basePath ? `${basePath}/` : '/';
  return `${basePath}${path}`;
}

function resolvePathname(): MarketingPath | 'not-found' {
  let pathname = window.location.pathname;
  if (basePath && pathname.startsWith(basePath)) pathname = pathname.slice(basePath.length);
  if (!pathname.startsWith('/')) pathname = `/${pathname}`;
  if (!pathname.endsWith('/')) pathname = `${pathname}/`;
  return knownPaths.has(pathname as MarketingPath) ? (pathname as MarketingPath) : 'not-found';
}

function cx(...values: Array<string | false | null | undefined>) {
  return values.filter(Boolean).join(' ');
}

function AppStoreLink({ className = '', compact = false }: { className?: string; compact?: boolean }) {
  return (
    <a
      className={cx('button button-primary', compact && 'button-compact', className)}
      href={APP_STORE_URL}
      target="_blank"
      rel="noreferrer"
      aria-label="Download LifeBoard on the App Store"
    >
      <span aria-hidden="true"></span>
      <span>{compact ? 'Download' : 'Download LifeBoard'}</span>
      <span aria-hidden="true">↗</span>
    </a>
  );
}

function TextLink({ href, children }: { href: MarketingPath; children: ReactNode }) {
  return (
    <a className="text-link" href={siteHref(href)}>
      {children}<span aria-hidden="true"> ↗</span>
    </a>
  );
}

function ProductScreenshot({ spec, priority = false, className = '' }: { spec: ScreenshotSpec; priority?: boolean; className?: string }) {
  const isWide = spec.width / spec.height > 0.62;
  return (
    <figure className={cx('product-shot', isWide && 'product-shot-wide', className)}>
      <div className="product-shot-shell">
        <div className="product-shot-speaker" aria-hidden="true" />
        <img
          src={spec.src}
          srcSet={`${spec.src480} 480w, ${spec.src760} 760w, ${spec.src} ${spec.width}w`}
          sizes="(max-width: 640px) 72vw, (max-width: 1024px) 38vw, 360px"
          alt={spec.alt}
          width={spec.width}
          height={spec.height}
          loading={priority ? 'eager' : 'lazy'}
          fetchPriority={priority ? 'high' : 'auto'}
          decoding="async"
        />
      </div>
    </figure>
  );
}

function SiteHeader({ current }: { current: MarketingPath | 'not-found' }) {
  const [open, setOpen] = useState(false);
  const featureActive = current === '/features/' || (current !== 'not-found' && current.startsWith('/features/'));

  return (
    <header className="site-header">
      <a className="brand" href={siteHref('/')} aria-label="LifeBoard home">
        LifeBoard<span aria-hidden="true">.</span>
      </a>
      <nav className="desktop-nav" aria-label="Primary navigation">
        <a href={siteHref('/')} aria-current={current === '/' ? 'page' : undefined}>Life OS</a>
        <a href={siteHref('/features/')} aria-current={featureActive ? 'page' : undefined}>Features</a>
        <a href={siteHref('/privacy/')} aria-current={current === '/privacy/' ? 'page' : undefined}>Privacy</a>
        <a href={siteHref('/support/')} aria-current={current === '/support/' ? 'page' : undefined}>Support</a>
      </nav>
      <div className="header-actions">
        <AppStoreLink compact />
        <button
          className="menu-button"
          type="button"
          aria-expanded={open}
          aria-controls="mobile-navigation"
          aria-label={open ? 'Close navigation' : 'Open navigation'}
          onClick={() => setOpen((value) => !value)}
        >
          <span aria-hidden="true">{open ? '×' : '☰'}</span>
        </button>
      </div>
      <div id="mobile-navigation" className={cx('mobile-nav-wrap', open && 'is-open')}>
        <nav className="mobile-nav" aria-label="Mobile navigation">
          <a href={siteHref('/')}>Life OS</a>
          <a href={siteHref('/features/')}>Explore every feature</a>
          <a href={siteHref('/privacy/')}>Privacy</a>
          <a href={siteHref('/support/')}>Support</a>
        </nav>
      </div>
    </header>
  );
}

function SiteFooter() {
  return (
    <footer className="site-footer">
      <div>
        <div className="brand brand-footer">LifeBoard<span aria-hidden="true">.</span></div>
        <p>One place to run the life you actually have.</p>
      </div>
      <nav aria-label="Footer navigation">
        <a href={siteHref('/features/')}>Features</a>
        <a href={siteHref('/privacy/')}>Privacy</a>
        <a href={siteHref('/terms/')}>Terms</a>
        <a href={siteHref('/support/')}>Support</a>
      </nav>
      <p className="copyright">© {new Date().getFullYear()} LifeBoard</p>
    </footer>
  );
}

function PageShell({ current, children }: { current: MarketingPath | 'not-found'; children: ReactNode }) {
  useEffect(() => {
    if (current !== 'not-found') {
      document.title = routeMetadata[current].title;
      const description = document.querySelector<HTMLMetaElement>('meta[name="description"]');
      description?.setAttribute('content', routeMetadata[current].description);
    }
    window.scrollTo(0, 0);
    document.querySelector<HTMLElement>('main h1')?.focus({ preventScroll: true });
  }, [current]);

  return (
    <div className="site-shell">
      <a className="skip-link" href="#main-content">Skip to main content</a>
      <SiteHeader current={current} />
      {children}
      <SiteFooter />
    </div>
  );
}

function CelestialMark({ tone = 'sun' }: { tone?: 'sun' | 'leaf' | 'clay' }) {
  return <span className={`celestial-mark celestial-${tone}`} aria-hidden="true" />;
}

function Homepage() {
  return (
    <PageShell current="/">
      <main id="main-content">
        <section className="hero section-pad">
          <div className="hero-copy">
            <p className="eyebrow">Your private Life OS</p>
            <h1 tabIndex={-1}>One place to run the life you actually have.</h1>
            <p className="hero-lede">Bring your work, home, health, routines, plans, and reflections into one calm system that helps you decide, act, recover, and adapt.</p>
            <div className="hero-actions">
              <AppStoreLink />
              <TextLink href="/features/">Explore the Life OS</TextLink>
            </div>
            <p className="hero-note">Local-first core workflows. Reviewable assistance. No silent consequential changes.</p>
          </div>
          <div className="hero-art">
            <CelestialMark />
            <ProductScreenshot spec={screenshots.home} priority />
            <p className="annotation annotation-top">One focus.<br />A readable day.</p>
            <p className="annotation annotation-bottom">Work, care, habits,<br />and real constraints.</p>
          </div>
        </section>

        <section className="manifesto section-pad">
          <p className="eyebrow">Life is not a list</p>
          <div className="manifesto-grid">
            <h2>Your responsibilities already form a system. LifeBoard helps you see it.</h2>
            <div className="prose-stack">
              <p>Most productivity tools isolate one part of life: tasks, calendars, habits, health, notes, or AI. You still carry the job of reconciling them.</p>
              <p>LifeBoard keeps those parts distinct but connected, so the next decision reflects the whole day—not just the loudest list.</p>
            </div>
          </div>
        </section>

        <section className="loop-section section-pad" aria-labelledby="loop-title">
          <div className="section-heading">
            <p className="eyebrow">One operating loop</p>
            <h2 id="loop-title">Move forward without needing a perfect day.</h2>
          </div>
          <ol className="operating-loop">
            {operatingLoop.map(([title, description], index) => (
              <li key={title}>
                <span className="loop-number">{String(index + 1).padStart(2, '0')}</span>
                <div><h3>{title}</h3><p>{description}</p></div>
              </li>
            ))}
          </ol>
        </section>

        <section className="roots-section section-pad" aria-labelledby="roots-title">
          <div className="section-heading roots-heading">
            <p className="eyebrow">Five roots, one system</p>
            <h2 id="roots-title">Complex enough for a life. Clear enough for this moment.</h2>
          </div>
          <div className="roots-editorial">
            {featurePages.slice(0, 6).filter((page) => page.id !== 'journal').map((page) => (
              <a key={page.id} className="root-entry" href={siteHref(page.slug)}>
                <span>{page.number}</span>
                <div><h3>{page.id === 'eva' ? 'EVA' : page.id[0].toUpperCase() + page.id.slice(1)}</h3><p>{page.promise}</p></div>
                <span aria-hidden="true">↗</span>
              </a>
            ))}
          </div>
        </section>

        <section className="day-story section-pad" aria-labelledby="day-title">
          <div className="day-story-copy">
            <p className="eyebrow">A real day in LifeBoard</p>
            <h2 id="day-title">Commit. Act. Repair. Close. Rest.</h2>
            <div className="story-steps">
              <div><span>Morning</span><p>Choose one intentional starting point around fixed commitments and available capacity.</p></div>
              <div><span>During the day</span><p>Focus, complete, track, and capture without rebuilding context each time.</p></div>
              <div><span>When plans change</span><p>Rescue overdue work, move what no longer fits, or switch to a Minimum Viable Day.</p></div>
              <div><span>Evening</span><p>Reconcile unfinished work, reflect briefly, and name tomorrow’s first thing.</p></div>
            </div>
          </div>
          <div className="shot-pair">
            <ProductScreenshot spec={screenshots.plan} />
            <ProductScreenshot spec={screenshots.recovery} className="shot-offset" />
          </div>
        </section>

        <section className="domains-section section-pad" aria-labelledby="domains-title">
          <div className="section-heading">
            <p className="eyebrow">Every part of life</p>
            <h2 id="domains-title">Separate enough to stay clear. Connected enough to stay useful.</h2>
          </div>
          <div className="domain-list">
            {lifeDomains.map(([title, description], index) => (
              <article key={title}><span>{String(index + 1).padStart(2, '0')}</span><h3>{title}</h3><p>{description}</p></article>
            ))}
          </div>
        </section>

        <section className="proof-section section-pad" aria-labelledby="proof-title">
          <div className="section-heading">
            <p className="eyebrow">Proof, not promises</p>
            <h2 id="proof-title">A Life OS you can inspect.</h2>
          </div>
          <div className="proof-layout">
            <ProductScreenshot spec={screenshots.track} />
            <div className="proof-copy">
              {featurePages.slice(1, 6).map((page) => (
                <a key={page.id} href={siteHref(page.slug)}>
                  <span>{page.eyebrow}</span>
                  <h3>{page.title}</h3>
                  <p>{page.summary}</p>
                </a>
              ))}
            </div>
          </div>
        </section>

        <section className="trust-section section-pad" aria-labelledby="trust-title">
          <div className="trust-intro">
            <p className="eyebrow">Private by architecture</p>
            <h2 id="trust-title">Private context deserves visible boundaries.</h2>
          </div>
          <div className="trust-points">
            <article><h3>Local-first</h3><p>Core work lives on your device. Optional private iCloud continuity does not become a second authority.</p></article>
            <article><h3>Read-only calendar</h3><p>LifeBoard can understand fixed commitments without editing, deleting, or responding to external events.</p></article>
            <article><h3>Reviewable AI</h3><p>EVA explains or proposes. Meaningful changes wait for Apply and produce a receipt with Undo where supported.</p></article>
            <article><h3>Redacted outside the app</h3><p>Widgets, Watch, notifications, Spotlight, and Live Activities receive purpose-built projections, not unrestricted private records.</p></article>
          </div>
          <TextLink href="/privacy/">Read the privacy approach</TextLink>
        </section>

        <section className="everywhere-section section-pad" aria-labelledby="everywhere-title">
          <CelestialMark tone="leaf" />
          <div>
            <p className="eyebrow">Across your Apple devices</p>
            <h2 id="everywhere-title">Glance, capture, and continue without creating another system.</h2>
            <p>Use widgets, Live Activities, Siri, Shortcuts, Spotlight, notifications, the share sheet, Apple Watch, iPad, and supported Mac environments as safe entry points into the same canonical records.</p>
            <TextLink href="/features/everywhere/">Explore continuity</TextLink>
          </div>
        </section>

        <DownloadSection />
      </main>
    </PageShell>
  );
}

function DownloadSection() {
  return (
    <section className="download-section section-pad" aria-labelledby="download-title">
      <img src={appIcon} alt="" width="343" height="361" loading="lazy" />
      <div>
        <p className="eyebrow">Start where you are</p>
        <h2 id="download-title">Build the smallest system that makes tomorrow easier.</h2>
        <p>Download LifeBoard and begin with one life area, one honest day, and one next action.</p>
        <AppStoreLink />
      </div>
    </section>
  );
}

function FeatureHub() {
  return (
    <PageShell current="/features/">
      <main id="main-content">
        <section className="page-hero section-pad">
          <p className="eyebrow">Explore the complete Life OS</p>
          <h1 tabIndex={-1}>Every part has a job. Every part stays connected.</h1>
          <p>Start with the part of life carrying the most friction. LifeBoard lets the system grow only when more structure earns its place.</p>
        </section>
        <section className="feature-hub-layout section-pad" aria-label="LifeBoard feature areas">
          <nav className="feature-chapter-nav" aria-label="Feature chapters">
            <p className="eyebrow">Chapters</p>
            {featurePages.map((page) => <a key={page.id} href={`#${page.id}`}>{page.number} · {page.id === 'eva' ? 'EVA' : page.id}</a>)}
          </nav>
          <div className="feature-index">
            {featurePages.map((page) => (
              <a id={page.id} key={page.id} href={siteHref(page.slug)} className="feature-index-row">
                <span className="feature-number">{page.number}</span>
                <div><p className="eyebrow">{page.eyebrow}</p><h2>{page.title}</h2><p>{page.summary}</p></div>
                <span className="feature-arrow" aria-hidden="true">↗</span>
              </a>
            ))}
          </div>
        </section>
        <DownloadSection />
      </main>
    </PageShell>
  );
}

function FeatureDetail({ page }: { page: FeaturePage }) {
  return (
    <PageShell current={page.slug}>
      <main id="main-content">
        <section className="feature-hero section-pad">
          <div>
            <p className="eyebrow">{page.number} · {page.eyebrow}</p>
            <h1 tabIndex={-1}>{page.title}</h1>
            <p className="feature-lede">{page.summary}</p>
            <AppStoreLink />
          </div>
          <ProductScreenshot spec={page.screenshot} priority />
        </section>

        <section className="promise-band section-pad">
          <p className="eyebrow">The promise</p>
          <h2>{page.promise}</h2>
          <p>{page.availability}</p>
        </section>

        <section className="scenario-section section-pad">
          <p className="eyebrow">Picture this</p>
          <p className="scenario-copy">{page.scenario}</p>
        </section>

        <section className="jobs-section section-pad" aria-labelledby={`${page.id}-jobs`}>
          <div><p className="eyebrow">When this helps</p><h2 id={`${page.id}-jobs`}>Built around the job, not the module.</h2></div>
          <ul>{page.jobs.map((job) => <li key={job}>{job}</li>)}</ul>
        </section>

        <section className="chapter-section section-pad" aria-label={`${page.id} capabilities`}>
          {page.chapters.map((chapter, index) => (
            <article key={chapter.title} className="chapter">
              <span>{String(index + 1).padStart(2, '0')}</span>
              <div><h2>{chapter.title}</h2><p>{chapter.copy}</p></div>
              <ul>{chapter.points.map((point) => <li key={point}>{point}</li>)}</ul>
            </article>
          ))}
        </section>

        {page.proofScreenshots?.length ? (
          <section className="screenshot-proof section-pad" aria-labelledby={`${page.id}-screens`}>
            <div className="section-heading">
              <p className="eyebrow">Real product, lived-in context</p>
              <h2 id={`${page.id}-screens`}>See how this part of the Life OS fits into a real day.</h2>
            </div>
            <div className="screenshot-proof-grid">
              {page.proofScreenshots.map((spec) => <ProductScreenshot key={spec.id} spec={spec} />)}
            </div>
          </section>
        ) : null}

        <section className="states-section section-pad" aria-labelledby={`${page.id}-states`}>
          <div><p className="eyebrow">Reality included</p><h2 id={`${page.id}-states`}>Useful when the data—or the day—is imperfect.</h2></div>
          <div className="state-list">
            <p><strong>Empty and loading</strong><span>A successful absence gets one useful next step; loading preserves expected structure without blocking unrelated work.</span></p>
            <p><strong>Denied and offline</strong><span>Permission or connectivity loss names the unavailable dependency while local alternatives and saved input remain available.</span></p>
            <p><strong>Stale and partial</strong><span>Freshness and missing evidence stay visible. Available information is not discarded or presented as complete.</span></p>
            <p><strong>Recovery</strong><span>Retry, repair, receipts, and Undo preserve identity and prevent duplicate work where the action supports reversal.</span></p>
          </div>
        </section>

        <section className="control-section section-pad">
          <p className="eyebrow">Your system, your call</p>
          <h2>Integrations add context. They do not take ownership.</h2>
          <p>{page.availability} LifeBoard keeps canonical records, explicit permission boundaries, and reviewable consequential actions at the center.</p>
          <TextLink href="/privacy/">Understand privacy and control</TextLink>
        </section>

        <section className="connected-section section-pad">
          <p className="eyebrow">Connected by design</p>
          <h2>This is one part of the Life OS.</h2>
          <div className="connected-links">
            {page.connected.map((name) => {
              const target = featurePages.find((candidate) => candidate.id.toLowerCase() === name.toLowerCase());
              return target ? <a key={name} href={siteHref(target.slug)}>{name}<span aria-hidden="true"> ↗</span></a> : null;
            })}
          </div>
        </section>
        <DownloadSection />
      </main>
    </PageShell>
  );
}

function LegalPage({ type }: { type: 'privacy' | 'terms' }) {
  const isPrivacy = type === 'privacy';
  const current: MarketingPath = isPrivacy ? '/privacy/' : '/terms/';
  return (
    <PageShell current={current}>
      <main id="main-content" className="legal-page section-pad">
        <p className="eyebrow">LifeBoard</p>
        <h1 tabIndex={-1}>{isPrivacy ? 'Privacy' : 'Terms of use'}</h1>
        <p className="legal-updated">Last updated: August 13, 2026</p>
        {isPrivacy ? <PrivacyContent /> : <TermsContent />}
      </main>
    </PageShell>
  );
}

function PrivacyContent() {
  return (
    <div className="legal-content">
      <section><h2>Local-first by default</h2><p>LifeBoard stores its core working records on your device. If private iCloud continuity is enabled and available, Apple’s CloudKit infrastructure synchronizes eligible records. LifeBoard does not operate a separate task-data account service or hold a recovery phrase for your content.</p></section>
      <section><h2>Permissions stay specific</h2><p>Calendar access is used for read-only schedule context. Health access is requested by domain and remains optional; manual recording stays available. Microphone, camera, photos, files, notifications, biometrics, speech, and system integrations are requested only when their related action is understandable.</p></section>
      <section><h2>EVA and model context</h2><p>Local model paths are preferred where available. Eligible remote model work requires explicit account opt-in and category-specific context grants. Revoking a grant affects later requests. Meaningful changes remain behind proposal review and explicit Apply.</p></section>
      <section><h2>Outside the main app</h2><p>Widgets, Watch, notifications, Spotlight, Live Activities, and extensions receive small, versioned, redacted projections. Protected Journal and health content is not copied into unsafe previews.</p></section>
      <section><h2>Advertising and profiling</h2><p>LifeBoard does not sell personal task, journal, or health content and does not use it for advertising profiles. Diagnostics are designed to exclude private content.</p></section>
      <section><h2>Questions</h2><p>Email <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> with privacy or data questions.</p></section>
    </div>
  );
}

function TermsContent() {
  return (
    <div className="legal-content">
      <section><h2>Using LifeBoard</h2><p>By downloading or using LifeBoard, you agree to use the software lawfully and in accordance with these terms and the applicable App Store terms.</p></section>
      <section><h2>Personal license</h2><p>LifeBoard grants you a limited, personal, non-transferable license to use the app. You may not resell, redistribute, reverse engineer, or misuse the software except where applicable law permits otherwise.</p></section>
      <section><h2>Important boundaries</h2><p>LifeBoard is a planning and life-management tool. It is not medical treatment, diagnosis, financial advice, emergency guidance, an autonomous scheduler, or a guarantee of any outcome. You remain responsible for reviewing actions and important decisions.</p></section>
      <section><h2>Availability</h2><p>Some capabilities depend on compatible hardware, operating-system support, permissions, downloaded models, connectivity, iCloud, or third-party services. Features may change as the product evolves.</p></section>
      <section><h2>Disclaimer and liability</h2><p>LifeBoard is provided on an “as is” and “as available” basis to the extent permitted by law. The developer is not liable for indirect or consequential loss arising from use of or inability to use the app.</p></section>
      <section><h2>Contact</h2><p>Email <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> with questions about these terms.</p></section>
    </div>
  );
}

function SupportPage() {
  return (
    <PageShell current="/support/">
      <main id="main-content" className="support-page section-pad">
        <div className="support-intro">
          <p className="eyebrow">LifeBoard support</p>
          <h1 tabIndex={-1}>Tell us what got in your way.</h1>
          <p>For setup, permissions, sync, recovery, billing, or product questions, include your device and what you expected to happen.</p>
          <a className="button button-primary" href={`mailto:${SUPPORT_EMAIL}`}>Email {SUPPORT_EMAIL}</a>
        </div>
        <div className="faq-list">
          <article><h2>Where does LifeBoard store my information?</h2><p>Core records are local-first. Eligible records can use private iCloud continuity when enabled and available.</p></article>
          <article><h2>What if Calendar or Health access is denied?</h2><p>LifeBoard keeps local planning and manual tracking available. Re-enable a permission from system Settings when you want the connected context.</p></article>
          <article><h2>Can EVA change my plan by itself?</h2><p>No. Meaningful changes become a proposal that you can review, edit, decline, or apply. Supported changes produce a receipt and Undo.</p></article>
          <article><h2>Which devices are supported?</h2><p>LifeBoard is built for iPhone and iPad, with Watch, widget, Live Activity, Siri, Spotlight, Share Extension, and supported Mac experiences where the required platform capability is available.</p></article>
          <article><h2>How do I recover damaged or stale state?</h2><p>Open Settings and use the relevant Recovery controls. They rebuild derived indexes or projections while preserving canonical records whenever possible.</p></article>
        </div>
      </main>
    </PageShell>
  );
}

function NotFoundPage() {
  return (
    <PageShell current="not-found">
      <main id="main-content" className="not-found section-pad">
        <p className="eyebrow">That page moved</p>
        <h1 tabIndex={-1}>Return to the Life OS.</h1>
        <p>The page you followed is not part of the current LifeBoard site.</p>
        <a className="button button-primary" href={siteHref('/')}>Go to LifeBoard</a>
      </main>
    </PageShell>
  );
}

export default function App() {
  const route = resolvePathname();
  if (route === '/') return <Homepage />;
  if (route === '/features/') return <FeatureHub />;
  if (route === '/privacy/') return <LegalPage type="privacy" />;
  if (route === '/terms/') return <LegalPage type="terms" />;
  if (route === '/support/') return <SupportPage />;
  if (route === 'not-found') return <NotFoundPage />;
  const feature = featurePages.find((page) => page.slug === route);
  return feature ? <FeatureDetail page={feature} /> : <NotFoundPage />;
}
