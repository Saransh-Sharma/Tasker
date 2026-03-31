import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import analyticsOne from './assets/marketing-screens/analytics-1.png';
import analyticsTwo from './assets/marketing-screens/analytics-2.png';
import builtInAI from './assets/marketing-screens/built-in-ai.png';
import homeScreen from './assets/marketing-screens/home.png';
import privateAI from './assets/marketing-screens/private-ai.png';
import tasksHabits from './assets/marketing-screens/tasks-habits.png';
import { BlurReveal } from './components/spell/blur-reveal';
import { HighlightedText } from './components/spell/highlighted-text';
import { RandomizedText } from './components/spell/randomized-text';
import { SlideUpText } from './components/spell/slide-up-text';
import { SpecialText } from './components/spell/special-text';
import { WordsStagger } from './components/spell/words-stagger';
import { Signature } from './components/signature';

type TextSection = {
  title: string;
  content: ReactNode;
};

type StoryContent = {
  id: string;
  title: ReactNode;
  description: ReactNode;
};

type ShowcaseStory = {
  id: string;
  eyebrow: ReactNode;
  title: ReactNode;
  description: ReactNode;
  layoutVariant: 'image-left' | 'image-right' | 'paired-right';
  images: Array<{
    src: string;
    alt: string;
    className?: string;
  }>;
};

const audienceNotes: StoryContent[] = [
  {
    id: 'decide-faster',
    title: 'Decide faster.',
    description:
      'Home collapses your workload into a bounded next move so you spend less energy negotiating with the backlog.',
  },
  {
    id: 'restart-faster',
    title: 'Restart faster.',
    description:
      'Quick views, resume cues, and due pressure make it easier to get moving again after interruptions instead of starting from zero.',
  },
  {
    id: 'momentum-survives',
    title: 'Keep momentum through imperfect days.',
    description:
      'Tasks, habits, XP, and streak-safe recovery loops keep progress alive even when the week is messy.',
  },
];

const loopPhases: Array<{ step: string; title: ReactNode; description: ReactNode }> = [
  {
    step: '1',
    title: 'Capture.',
    description: 'Capture work before it disappears, then add structure only when you actually need it.',
  },
  {
    step: '2',
    title: 'Decide.',
    description: 'Turn scattered inputs into a bounded now list with choices you can immediately act on.',
  },
  {
    step: '3',
    title: 'Start.',
    description: 'Move from plan to action with less setup drag and a cleaner handoff into real work.',
  },
  {
    step: '4',
    title: 'Resume.',
    description: 'Recover after interruptions with enough context, cues, and timing signals to restart fast.',
  },
  {
    step: '5',
    title: 'Reflect.',
    description: 'Use XP, insights, and recovery signals to improve the system without punishment framing.',
  },
];

const surfaceStories: StoryContent[] = [
  {
    id: 'capture',
    title: 'Capture at the speed of thought',
    description:
      'Fast entry keeps ideas, tasks, and obligations from vanishing while deeper clarify tools stay optional.',
  },
  {
    id: 'tasks-habits',
    title: 'Tasks and habits in one system',
    description:
      'Plan finite work and recurring behavior together without brittle streak logic or a split-brain workflow.',
  },
  {
    id: 'assistant',
    title: (
      <>
        LLM <HighlightedText from="left" inView delay={0.55}>chief of staff</HighlightedText>
      </>
    ),
    description: 'Ask, plan, and apply with diff previews, confirmation gates, model control, visible undo, and no silent mutations.',
  },
  {
    id: 'momentum',
    title: (
      <>
        <HighlightedText from="bottom" inView delay={0.42}>XP</HighlightedText>-powered momentum
      </>
    ),
    description: 'Levels, milestones, streak resilience, and recovery-aware loops reward real progress without punishing misses.',
  },
  {
    id: 'analytics',
    title: (
      <>
        <HighlightedText from="bottom" inView delay={0.5}>Today. Week. Systems.</HighlightedText>
      </>
    ),
    description: 'Decision-ready analytics surface pace, pressure, focus health, and recovery patterns so reflection leads to action.',
  },
];

const privacySections: TextSection[] = [
  {
    title: '1. The guarantee',
    content: (
      <p>
        Tasker is built to protect working context. <strong>We do not read, mine, or sell your task data.</strong>{' '}
        If you enable sync, your content remains end-to-end encrypted.
      </p>
    ),
  },
  {
    title: '2. Data collection and usage',
    content: (
      <>
        <p className="mb-4">We only collect the minimum data required to make accounts and sync function:</p>
        <ul className="list-disc pl-6 space-y-3 text-white/62">
          <li><strong>Authentication data:</strong> used to verify account identity securely.</li>
          <li>
            <strong>Encrypted sync payloads:</strong> synchronized through our servers, but unreadable to us
            because the content stays end-to-end encrypted.
          </li>
        </ul>
      </>
    ),
  },
  {
    title: '3. Local storage',
    content: <p>Tasker works locally by default. Your data stays on-device unless you explicitly turn on sync.</p>,
  },
  {
    title: '4. Tracking and third parties',
    content: (
      <p>We do not run ad tech, trackers, or third-party analytics that profile your behavior or sell your attention.</p>
    ),
  },
];

const termsSections: TextSection[] = [
  {
    title: '1. Acceptance of terms',
    content: <p>By downloading or using Tasker, you agree to these terms. Please read them before using the app.</p>,
  },
  {
    title: '2. Use license',
    content: (
      <p>
        We grant a limited, personal, non-commercial license to use Tasker. You may not resell, redistribute,
        reverse engineer, or otherwise misuse the software.
      </p>
    ),
  },
  {
    title: '3. Disclaimer',
    content: (
      <p>
        Tasker is provided on an &quot;as is&quot; basis, without warranties of any kind, including implied
        warranties of merchantability, fitness for a particular purpose, or non-infringement.
      </p>
    ),
  },
  {
    title: '4. Limitations',
    content: (
      <p>
        Tasker and its developers are not liable for damages resulting from use of the app, inability to use it,
        data loss, or business interruption, to the extent permitted by law.
      </p>
    ),
  },
];

const supportFaqs = [
  {
    question: 'How do I delete my account?',
    answer:
      'Open the Tasker iOS app, go to Settings > Account, and choose "Delete Account & Data." This permanently removes your synced data from our servers.',
  },
  {
    question: 'Can you recover my tasks if I lose my password?',
    answer:
      'No. Because Tasker uses end-to-end encryption, we do not hold your decryption keys. Without your recovery phrase, encrypted data cannot be restored.',
  },
  {
    question: 'Is there a web or Mac app?',
    answer:
      'Not yet. The current release is focused on iOS. Mac and web are planned, but they are not available today.',
  },
];

const showcaseStories: ShowcaseStory[] = [
  {
    id: 'home',
    eyebrow: 'Bounded focus',
    title: 'One home for what matters today.',
    description:
      'Daily focus, due pressure, and quick views keep the next move visible without forcing you to rebuild context first.',
    layoutVariant: 'image-right',
    images: [
      {
        src: homeScreen,
        alt: 'Tasker home view showing the main focus surface and current priorities.',
      },
    ],
  },
  {
    id: 'tasks-habits',
    eyebrow: 'Structure that holds',
    title: 'Tasks and habits, one operating system.',
    description:
      'Finite work and recurring behavior live in the same execution system while keeping habits analytically distinct and recovery-aware.',
    layoutVariant: 'image-left',
    images: [
      {
        src: tasksHabits,
        alt: 'Tasker tasks and habits screen showing tasks and recurring habits in one workflow.',
      },
    ],
  },
  {
    id: 'assistant',
    eyebrow: (
      <RandomizedText split="chars" inView className="tracking-[0.24em]">
        CHIEF OF STAFF
      </RandomizedText>
    ),
    title: (
      <>
        A <HighlightedText from="bottom" inView delay={0.56}>personal chief of staff</HighlightedText> that proposes before it acts.
      </>
    ),
    description: (
      <>
        Tasker lets you ask, plan, and apply changes with confirmation gates, diff previews, and bounded undo instead
        of blind automation.
        <div className="mt-4 type-system-label text-white/58">
          <RandomizedText inView>Ask. Plan. Apply.</RandomizedText>
        </div>
      </>
    ),
    layoutVariant: 'image-right',
    images: [
      {
        src: builtInAI,
        alt: 'Tasker built-in AI screen for planning and task guidance.',
      },
    ],
  },
  {
    id: 'privacy',
    eyebrow: 'User-controlled AI',
    title: 'Model choice and privacy posture stay explicit.',
    description: (
      <>
        Sensitive work never disappears behind vague AI settings. History clearing, model control, and privacy posture
        stay visible and user-owned.
        <div className="mt-4 type-system-label text-white/58">
          <SpecialText inView>NO SILENT MUTATIONS</SpecialText>
        </div>
      </>
    ),
    layoutVariant: 'image-left',
    images: [
      {
        src: privateAI,
        alt: 'Tasker private AI screen showing privacy-focused assistant controls.',
      },
    ],
  },
  {
    id: 'analytics',
    eyebrow: 'Momentum analytics',
    title: (
      <>
        See pace, <HighlightedText from="bottom" inView delay={0.42}>XP</HighlightedText>, and recovery across{' '}
        <HighlightedText from="left" inView delay={0.64}>Today. Week. Systems.</HighlightedText>
      </>
    ),
    description:
      'Tasker turns your history into decision support with streak resilience, level progression, focus health, and recovery signals that stay actionable instead of judgmental.',
    layoutVariant: 'paired-right',
    images: [
      {
        src: analyticsOne,
        alt: 'Tasker analytics screen highlighting momentum and completion patterns.',
        className: 'md:-translate-y-10',
      },
      {
        src: analyticsTwo,
        alt: 'Tasker analytics screen showing follow-through and recovery insights.',
        className: 'md:translate-y-10',
      },
    ],
  },
];

const legalShell =
  'min-h-screen bg-[#030305] pb-32 text-white selection:bg-indigo-500/30 selection:text-white';
const legalContainer = 'mx-auto max-w-3xl px-8 pt-32';
const legalBackLink = 'type-nav mb-16 inline-block transition-colors duration-300 hover:text-white';
const legalSectionStack = 'type-legal-body measure-legal space-y-12';
const legalSectionTitle = 'type-legal-heading mb-5';

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(' ');
}

function delayStyle(delay: number): CSSProperties {
  return { animationDelay: `${delay}ms` };
}

function scrollToId(id: string) {
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' });
}

function useScrollReveal() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('animate-fade-rise');
            entry.target.classList.remove('opacity-0', 'translate-y-6');
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: '0px 0px -50px 0px' },
    );

    const elements = document.querySelectorAll('.scroll-reveal');
    elements.forEach((el) => observer.observe(el));

    return () => observer.disconnect();
  }, []);

  return ref;
}

function LegalLayout({
  title,
  updated,
  intro,
  children,
}: {
  title: string;
  updated?: string;
  intro?: string;
  children: ReactNode;
}) {
  return (
    <div className={legalShell}>
      <div className={legalContainer}>
        <a href="#/" className={legalBackLink}>← Back to Tasker</a>
        <div className="max-w-[44rem]">
          <h1 className="type-legal-title mb-5">{title}</h1>
          {updated ? <p className="type-meta mb-5">{updated}</p> : null}
          {intro ? <p className="type-body-lg measure-reading mb-16">{intro}</p> : null}
        </div>
        {children}
      </div>
    </div>
  );
}

function LegalSectionList({ sections }: { sections: TextSection[] }) {
  return (
    <div className={legalSectionStack}>
      {sections.map((section) => (
        <section key={section.title}>
          <h2 className={legalSectionTitle}>{section.title}</h2>
          {section.content}
        </section>
      ))}
    </div>
  );
}

function Privacy() {
  return (
    <LegalLayout
      title="Privacy Policy"
      updated="Last updated: March 25, 2026"
      intro="Tasker is designed to keep your working life private, local-first, and readable on low bandwidth days."
    >
      <LegalSectionList sections={privacySections} />
    </LegalLayout>
  );
}

function Terms() {
  return (
    <LegalLayout
      title="Terms of Service"
      updated="Last updated: March 25, 2026"
      intro="These terms cover the basic conditions for using Tasker. They are intentionally short and direct."
    >
      <LegalSectionList sections={termsSections} />
    </LegalLayout>
  );
}

function Support() {
  return (
    <LegalLayout
      title="Support"
      intro="Help with bugs, sync issues, billing, and account questions. If Tasker is failing, tell us what broke and what device you are on."
    >
      <div className="space-y-16">
        <section className="group relative overflow-hidden rounded-3xl border border-white/5 bg-[#0A0A0E] p-8 md:p-12">
          <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-white/5 to-transparent opacity-0 transition-opacity duration-700 group-hover:opacity-100" />
          <div className="relative z-10">
            <h2 className="type-legal-heading mb-4">Contact us</h2>
            <p className="type-legal-body measure-reading mb-8">
              Include screenshots or device details if you can. We aim to respond within 24 hours.
            </p>
            <a
              href="mailto:support@tasker.app"
              className="liquid-glass inline-block rounded-full border border-white/10 px-8 py-3 text-sm font-medium text-white transition-all duration-300 hover:bg-white/10"
            >
              Email support@tasker.app
            </a>
          </div>
        </section>

        <section>
          <div className="mb-8 border-b border-white/5 pb-6">
            <h2 className="type-legal-heading">Frequently asked questions</h2>
          </div>
          <div className="space-y-10">
            {supportFaqs.map((faq) => (
              <div key={faq.question} className="measure-legal">
                <h3 className="type-question mb-3">{faq.question}</h3>
                <p className="type-legal-body">{faq.answer}</p>
              </div>
            ))}
          </div>
        </section>
      </div>
    </LegalLayout>
  );
}

function ScreenshotFrame({
  src,
  alt,
  className = '',
}: {
  src: string;
  alt: string;
  className?: string;
}) {
  return (
    <figure
      className={`group relative mx-auto w-full max-w-[20rem] transition-transform duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] motion-safe:hover:-translate-y-2 ${className}`}
    >
      <div className="pointer-events-none absolute inset-x-8 bottom-2 h-20 rounded-full bg-[radial-gradient(circle,rgba(99,102,241,0.22),transparent_72%)] blur-3xl opacity-70 transition-opacity duration-700 group-hover:opacity-100" />
      <div className="relative rounded-[2.6rem] border border-white/12 bg-[#090A10] p-3 shadow-[0_26px_90px_rgba(0,0,0,0.42)]">
        <div className="pointer-events-none absolute inset-x-0 top-0 flex justify-center pt-3">
          <div className="h-1.5 w-24 rounded-full bg-white/10" />
        </div>
        <div className="overflow-hidden rounded-[2.1rem] border border-white/8 bg-[#0E1018]">
          <img
            src={src}
            alt={alt}
            loading="lazy"
            decoding="async"
            className="h-auto w-full object-cover transition-transform duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] motion-safe:group-hover:scale-[1.015]"
          />
        </div>
      </div>
    </figure>
  );
}

function ProductShowcase() {
  return (
    <section id="inside" className="relative overflow-hidden bg-[#06070B] px-8 py-32">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-40 bg-gradient-to-b from-[#030305] to-transparent" />
      <div className="pointer-events-none absolute right-0 top-24 h-72 w-72 rounded-full bg-[radial-gradient(circle,rgba(99,102,241,0.12),transparent_68%)] blur-3xl" />
      <div className="pointer-events-none absolute bottom-24 left-0 h-72 w-72 rounded-full bg-[radial-gradient(circle,rgba(255,255,255,0.06),transparent_68%)] blur-3xl" />

      <div className="relative z-10 mx-auto max-w-6xl">
        <div className="mb-20 max-w-3xl md:mb-28">
          <SlideUpText inView className="type-eyebrow mb-5 inline-flex">
            Inside
          </SlideUpText>
          <WordsStagger
            as="h2"
            inView
            className="type-section-title"
          >
            Proof for every promise.
          </WordsStagger>
          <BlurReveal
            as="p"
            inView
            className="type-body-lg measure-reading mt-6"
          >
            These product surfaces show how Tasker turns tasks, habits, AI planning, and analytics into a single execution system that keeps momentum alive.
          </BlurReveal>
        </div>

        <div className="space-y-24 md:space-y-32">
          {showcaseStories.map((story, index) => {
            const copyOrderClass = story.layoutVariant === 'image-left' ? 'md:order-2' : 'md:order-1';
            const mediaOrderClass = story.layoutVariant === 'image-left' ? 'md:order-1' : 'md:order-2';
            const mediaLayoutClass =
              story.layoutVariant === 'paired-right'
                ? 'grid grid-cols-1 items-start gap-6 sm:grid-cols-2'
                : 'flex justify-center';

            return (
              <article
                key={story.id}
                className="grid grid-cols-1 items-center gap-10 md:grid-cols-[minmax(0,0.88fr)_minmax(0,1.12fr)] md:gap-16"
              >
                <div
                  className={cx(
                    'scroll-reveal opacity-0 translate-y-6',
                    copyOrderClass,
                    story.layoutVariant === 'image-left' ? 'md:pl-8' : 'md:pr-8',
                  )}
                  style={delayStyle(index * 90)}
                >
                  <p className="type-eyebrow mb-4">{story.eyebrow}</p>
                  <h3 className="type-story-title">{story.title}</h3>
                  <div className="type-body measure-reading mt-5 space-y-3">{story.description}</div>
                </div>

                <div
                  className={cx('scroll-reveal opacity-0 translate-y-6', mediaOrderClass)}
                  style={delayStyle(index * 90 + 120)}
                >
                  <div className="relative overflow-hidden rounded-[2.8rem] border border-white/8 bg-[linear-gradient(180deg,rgba(255,255,255,0.03),rgba(255,255,255,0.01))] px-4 py-6 md:px-8 md:py-10">
                    <div className="pointer-events-none absolute inset-x-10 top-0 h-px bg-gradient-to-r from-transparent via-white/18 to-transparent" />
                    <div className={mediaLayoutClass}>
                      {story.images.map((image, imageIndex) => (
                        <ScreenshotFrame
                          key={`${story.id}-${imageIndex}`}
                          src={image.src}
                          alt={image.alt}
                          className={image.className}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}

function Landing() {
  useScrollReveal();

  return (
    <div className="relative min-h-screen overflow-x-hidden bg-[#030305] text-white selection:bg-indigo-500/30 selection:text-white">
      <nav className="fixed left-0 right-0 top-0 z-50 w-full px-8 py-6">
        <div className="pointer-events-none absolute inset-0 -z-10 bg-gradient-to-b from-[#030305]/80 to-transparent backdrop-blur-sm" />
        <div className="relative z-10 mx-auto flex w-full max-w-7xl flex-row items-center justify-between">
          <div className="type-brand cursor-pointer select-none drop-shadow-md transition-opacity duration-300 hover:opacity-80">
            Tasker.
          </div>
          <div className="hidden items-center gap-10 md:flex">
            <a href="#focus" className="type-nav transition-all duration-300 hover:-translate-y-0.5 hover:text-white">Why Tasker</a>
            <a href="#flow" className="type-nav transition-all duration-300 hover:-translate-y-0.5 hover:text-white">How It Works</a>
            <a href="#inside" className="type-nav transition-all duration-300 hover:-translate-y-0.5 hover:text-white">Inside</a>
            <a href="#surfaces" className="type-nav transition-all duration-300 hover:-translate-y-0.5 hover:text-white">Standouts</a>
          </div>
          <div>
            <button
              onClick={() => scrollToId('inside')}
              className="liquid-glass rounded-full px-6 py-2.5 text-sm font-medium text-white transition-all duration-300 hover:bg-white/10 hover:shadow-[0_0_20px_rgba(255,255,255,0.15)] active:scale-95"
            >
              <SlideUpText split="characters">See the system</SlideUpText>
            </button>
          </div>
        </div>
      </nav>

      <section className="relative flex min-h-[100dvh] w-full flex-col items-center justify-center overflow-hidden">
        <video autoPlay loop muted playsInline className="absolute inset-0 h-full w-full object-cover z-0">
          <source
            src="https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260324_151826_c7218672-6e92-402c-9e45-f1e0f454bdc4.mp4"
            type="video/mp4"
          />
        </video>

        <div className="absolute inset-0 z-[1] bg-[#030305]/60" />
        <div className="absolute inset-0 z-[2] bg-[radial-gradient(circle_at_center,transparent_0%,#030305_100%)] opacity-80" />

        <div className="relative z-10 mx-auto flex h-full w-full max-w-5xl flex-col items-center justify-center px-6 pt-16 text-center">
          <SpecialText className="type-system-label animate-fade-rise text-white/62">
            PERSONAL CHIEF OF STAFF FOR THE DAY
          </SpecialText>
          <WordsStagger
            as="h1"
            stagger={0.1}
            duration={0.74}
            className="type-display-hero mt-8 drop-shadow-2xl"
          >
            The execution OS for everything on your plate.
          </WordsStagger>
          <BlurReveal
            as="p"
            speedReveal={1}
            speedSegment={0.38}
            className="type-body-lg mt-10 max-w-[46rem] drop-shadow-md"
          >
            Tasks, habits, AI planning, XP-driven momentum, and Today, Week, and Systems analytics in one product built to turn intent into follow-through.
          </BlurReveal>
          <button
            onClick={() => scrollToId('focus')}
            className="liquid-glass group mt-12 flex items-center gap-3 rounded-full px-12 py-4 text-white transition-all duration-300 hover:bg-white/10 hover:shadow-[0_0_30px_rgba(255,255,255,0.15)] active:scale-[0.97] animate-fade-rise-delay-2"
          >
            <SlideUpText split="characters">Explore the system</SlideUpText>
            <svg className="h-4 w-4 opacity-50 transition-all duration-300 group-hover:translate-x-1 group-hover:opacity-100" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
            </svg>
          </button>
          <div className="mt-6 type-system-label text-white/54 animate-fade-rise-delay-2">
            <RandomizedText>Ask. Plan. Apply.</RandomizedText>
          </div>
        </div>
      </section>

      <section id="focus" className="relative min-h-screen w-full">
        <video autoPlay loop muted playsInline className="absolute inset-0 h-full w-full object-cover z-0">
          <source
            src="https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260314_131748_f2ca2a28-fed7-44c8-b9a9-bd9acdd5ec31.mp4"
            type="video/mp4"
          />
        </video>

        <div className="absolute inset-0 z-[1] bg-gradient-to-r from-[#030305]/95 via-[#030305]/40 to-transparent" />
        <div className="absolute inset-x-0 top-0 z-[1] h-32 bg-gradient-to-b from-[#030305] to-transparent" />
        <div className="absolute inset-x-0 bottom-0 z-[1] h-32 bg-gradient-to-t from-[#030305] to-transparent" />

        <div className="relative z-10 mx-auto flex h-full min-h-screen max-w-7xl flex-col justify-center px-8 py-32">
          <div className="max-w-xl">
            <SlideUpText inView className="type-eyebrow mb-5 inline-flex">
              Why Tasker
            </SlideUpText>
            <h2 className="type-section-title mb-16 drop-shadow-xl">
              Built for <HighlightedText from="bottom" inView delay={0.46}>real workload</HighlightedText>, not ideal conditions.
            </h2>

            <div className="flex flex-col gap-10">
              {audienceNotes.map((note, index) => (
                <div
                  key={note.id}
                  className="scroll-reveal group cursor-default opacity-0 translate-y-6"
                  style={delayStyle((index + 1) * 100)}
                >
                  <div className="w-full border-l border-white/10 pl-6 transition-colors duration-500 group-hover:border-white/50">
                    <h3 className="type-question text-white/82 transition-colors duration-500 group-hover:text-white">
                      {note.title}
                    </h3>
                    <p className="type-body mt-3 transition-colors duration-500 group-hover:text-white/74">
                      {note.description}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section id="flow" className="relative overflow-hidden bg-[#030305] px-8 pb-40 pt-32">
        <div className="pointer-events-none absolute left-1/2 top-0 h-[400px] w-full max-w-2xl -translate-x-1/2 rounded-full bg-indigo-500/5 blur-[120px]" />

        <SlideUpText inView className="type-eyebrow relative z-10 mb-5 inline-flex w-full justify-center">
          How It Works
        </SlideUpText>
        <h2 className="type-section-title relative z-10 mb-6 text-center md:mb-8">
          The Five-Phase Loop.
        </h2>
        <BlurReveal
          as="p"
          inView
          className="type-body-lg mx-auto mb-24 max-w-[44rem] text-center"
        >
          Tasker turns capture, decision-making, starting, resuming, and reflection into one operating model for reliable follow-through.
        </BlurReveal>

        <div className="relative z-10 mx-auto grid max-w-7xl grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-5">
          {loopPhases.map((phase, index) => (
            <div
              key={phase.step}
              className="scroll-reveal group relative flex aspect-square cursor-pointer flex-col justify-end overflow-hidden rounded-[2.5rem] border border-white/5 bg-[#0A0A0E] p-8 py-10 opacity-0 transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] hover:-translate-y-4 hover:border-white/20 hover:shadow-[0_20px_40px_rgba(0,0,0,0.4)] translate-y-6 lg:aspect-[3/4] xl:aspect-[4/5]"
              style={delayStyle(index * 100)}
            >
              <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-white/5 to-transparent opacity-0 transition-opacity duration-700 group-hover:opacity-100" />
              <div className="absolute right-8 top-8 font-serif text-6xl text-indigo-400/20 transition-all duration-500 group-hover:scale-110 group-hover:text-indigo-400/40">
                {phase.step}
              </div>
              <h3 className="type-story-title relative z-10 text-[2.1rem] md:text-[2.2rem]">{phase.title}</h3>
              <p className="type-body relative z-10 mt-3 text-white/50 transition-colors group-hover:text-white/70">
                {phase.description}
              </p>
            </div>
          ))}
        </div>
      </section>

      <ProductShowcase />

      <section id="surfaces" className="relative border-y border-white/5 bg-[#0A0A0E] px-8 py-32">
        <div className="mx-auto max-w-6xl">
          <SlideUpText inView className="type-eyebrow mb-5 inline-flex w-full justify-center">
            Standouts
          </SlideUpText>
          <h2 className="type-section-title mb-6 text-center">
            Everything your execution system should do.
          </h2>
          <BlurReveal
            as="p"
            inView
            className="type-body-lg mx-auto mb-20 max-w-[48rem] text-center"
          >
            Tasker combines capture speed, habit structure, chief-of-staff AI, XP momentum, and decision-ready analytics without sacrificing privacy, trust, or clarity.
          </BlurReveal>
          <div className="grid grid-cols-1 gap-x-12 gap-y-16 md:grid-cols-2 xl:grid-cols-5">
            {surfaceStories.map((story, index) => (
              <div
                key={story.id}
                className="scroll-reveal group opacity-0 translate-y-6"
                style={delayStyle(index * 100)}
              >
                <h3 className="type-story-title mb-4 text-[2rem] md:text-[2.25rem] transition-colors duration-300 group-hover:text-indigo-400">
                  {story.title}
                </h3>
                <p className="type-body measure-reading">{story.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="relative bg-[#030305] px-8 py-32 md:py-48">
        <div className="mx-auto max-w-3xl text-center">
          <SlideUpText inView className="type-eyebrow mb-5 inline-flex">
            Built to last
          </SlideUpText>
          <h2 className="type-section-title mb-8">
            Serious productivity without <HighlightedText from="bottom" inView>attention extraction</HighlightedText>.
          </h2>
          <div className="type-body-lg scroll-reveal mx-auto flex max-w-[42rem] flex-col gap-6 opacity-0 translate-y-6" style={delayStyle(100)}>
            <p>Most productivity software optimizes for return visits, not completed work. It gets louder as the day gets harder.</p>
            <p>
              Tasker is built as execution infrastructure: a quieter system for deciding, starting, recovering, and improving without ads, shame loops, or ambiguous AI behavior.
            </p>
          </div>
          <div className="scroll-reveal mt-16 opacity-0 translate-y-6" style={delayStyle(200)}>
            <div className="flex justify-center">
              <Signature
                text="Saransh"
                color="rgba(255, 255, 255, 0.88)"
                fontSize={72}
                duration={1.25}
                className="h-auto w-[14rem] md:w-[18rem] drop-shadow-[0_0_24px_rgba(255,255,255,0.08)]"
              />
            </div>
          </div>
        </div>
      </section>

      <footer className="relative z-10 border-t border-white/5 bg-[#0A0A0E] px-8 py-16">
        <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-8 md:flex-row">
          <div className="type-brand select-none text-white/30">Tasker.</div>
          <div className="flex flex-wrap justify-center gap-10">
            <a href="#/support" className="type-footer transition-colors duration-300 hover:text-white">Support</a>
            <a href="#/privacy" className="type-footer transition-colors duration-300 hover:text-white">Privacy Policy</a>
            <a href="#/terms" className="type-footer transition-colors duration-300 hover:text-white">Terms of Service</a>
          </div>
          <div className="type-footer text-white/30">&copy; {new Date().getFullYear()} Tasker App.</div>
        </div>
      </footer>
    </div>
  );
}

export default function App() {
  const [route, setRoute] = useState(window.location.hash);

  useEffect(() => {
    const handleHashChange = () => {
      setRoute(window.location.hash);
      window.scrollTo(0, 0);
    };
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

  if (route === '#/privacy') return <Privacy />;
  if (route === '#/terms') return <Terms />;
  if (route === '#/support') return <Support />;

  return <Landing />;
}
