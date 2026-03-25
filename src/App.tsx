import { useEffect, useRef, useState } from 'react';

function useScrollReveal() {
  const ref = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('animate-fade-rise');
          entry.target.classList.remove('opacity-0', 'translate-y-6');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15, rootMargin: '0px 0px -50px 0px' });

    const elements = document.querySelectorAll('.scroll-reveal');
    elements.forEach((el) => observer.observe(el));

    return () => observer.disconnect();
  }, []);
  
  return ref;
}

function Privacy() {
  return (
    <div className="min-h-screen bg-[#030305] text-white font-sans selection:bg-indigo-500/30 selection:text-white pb-32">
      <div className="max-w-3xl mx-auto px-8 pt-32">
        <a href="#/" className="inline-block mb-16 text-sm uppercase tracking-widest text-gray-500 hover:text-white transition-colors">← Back to Tasker</a>
        <h1 className="font-serif text-5xl md:text-6xl mb-6">Privacy Policy</h1>
        <p className="text-gray-500 italic mb-16">Last updated: March 25, 2026</p>
        
        <div className="space-y-12 text-gray-300 font-light leading-relaxed text-lg">
          <div>
            <h2 className="font-serif text-3xl text-white mb-6">1. The Guarantee</h2>
            <p>Tasker is designed as a sanctuary for your mind. Because of this, our privacy policy is extremely simple: <strong>We do not harvest, read, or sell your data. period.</strong> Your thoughts mathematically belong to you alone via end-to-end encryption.</p>
          </div>
          <div>
            <h2 className="font-serif text-3xl text-white mb-6">2. Data Collection & Usage</h2>
            <p className="mb-4">We only collect the absolute minimum data required to make syncing function across your devices:</p>
            <ul className="list-disc pl-6 space-y-2 text-gray-400">
              <li><strong>Authentication Data:</strong> To verify your account identity securely.</li>
              <li><strong>Encrypted Sync Data:</strong> Your tasks are synchronized across your devices via our servers. However, this payload is End-to-End Encrypted. We literally cannot read it.</li>
            </ul>
          </div>
          <div>
            <h2 className="font-serif text-3xl text-white mb-6">3. Local Storage</h2>
            <p>By default, Tasker functions entirely offline, keeping your tasks strictly local to your device's secure enclave until you explicitly enable sync.</p>
          </div>
          <div>
            <h2 className="font-serif text-3xl text-white mb-6">4. Tracking & Third Parties</h2>
            <p>We do not use tracking pixels, analytics SDKs, or third-party ad networks. We do not sell or share your data with advertisers.</p>
          </div>
        </div>
      </div>
    </div>
  );
}

function Terms() {
  return (
    <div className="min-h-screen bg-[#030305] text-white font-sans selection:bg-indigo-500/30 selection:text-white pb-32">
      <div className="max-w-3xl mx-auto px-8 pt-32">
        <a href="#/" className="inline-block mb-16 text-sm uppercase tracking-widest text-gray-500 hover:text-white transition-colors">← Back to Tasker</a>
        <h1 className="font-serif text-5xl md:text-6xl mb-6">Terms of Service</h1>
        <p className="text-gray-500 italic mb-16">Last updated: March 25, 2026</p>
        
        <div className="space-y-12 text-gray-300 font-light leading-relaxed text-lg">
          <div>
            <h2 className="font-serif text-3xl text-white mb-6">1. Acceptance of Terms</h2>
            <p>By downloading or using the Tasker iOS application, these terms will automatically apply to you. You should make sure therefore that you read them carefully before using the app.</p>
          </div>
          <div>
            <h2 className="font-serif text-3xl text-white mb-6">2. Use License</h2>
            <p>Permission is granted to temporarily download one copy of Tasker per device for personal, non-commercial transitory viewing only. You may not modify or copy the materials, use the materials for any commercial purpose, or attempt to reverse engineer any software contained within Tasker.</p>
          </div>
          <div>
            <h2 className="font-serif text-3xl text-white mb-6">3. Disclaimer</h2>
            <p>The materials within Tasker are provided on an 'as is' basis. We make no warranties, expressed or implied, and hereby disclaim all other warranties including, without limitation, implied warranties or conditions of merchantability, or non-infringement of intellectual property.</p>
          </div>
          <div>
            <h2 className="font-serif text-3xl text-white mb-6">4. Limitations</h2>
            <p>In no event shall Tasker or its developers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the Tasker application.</p>
          </div>
        </div>
      </div>
    </div>
  );
}

function Support() {
  return (
    <div className="min-h-screen bg-[#030305] text-white font-sans selection:bg-indigo-500/30 selection:text-white pb-32">
      <div className="max-w-3xl mx-auto px-8 pt-32">
        <a href="#/" className="inline-block mb-16 text-sm uppercase tracking-widest text-gray-500 hover:text-white transition-colors">← Back to Tasker</a>
        <h1 className="font-serif text-5xl md:text-6xl mb-6">Support</h1>
        <p className="text-gray-400 text-xl font-light mb-16">We are here to help you regain your focus.</p>
        
        <div className="space-y-16">
          <div className="bg-[#0A0A0E] border border-white/5 rounded-3xl p-8 md:p-12 relative overflow-hidden group">
            <div className="absolute inset-0 bg-gradient-to-b from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />
            <h2 className="font-serif text-3xl text-white mb-4 relative z-10">Contact Us</h2>
            <p className="text-gray-400 font-light mb-8 relative z-10">If you're experiencing bugs, syncing issues, or have billing inquiries, please reach out directly. We aim to respond within 24 hours.</p>
            <a href="mailto:support@tasker.app" className="inline-block liquid-glass border border-white/10 rounded-full px-8 py-3 text-sm font-medium text-white hover:bg-white/10 transition-all duration-300 relative z-10">
              Email support@tasker.app
            </a>
          </div>

          <div>
            <h2 className="font-serif text-3xl text-white mb-8 border-b border-white/5 pb-6">Frequently Asked Questions</h2>
            
            <div className="space-y-10">
              <div>
                <h3 className="text-xl font-medium text-white mb-3">How do I delete my entire account?</h3>
                <p className="text-gray-400 font-light leading-relaxed">Open the Tasker iOS app, navigate to Settings &gt; Account, and tap "Delete Account & Data". This will permanently and irreversibly wipe your synced data from our servers.</p>
              </div>
              
              <div>
                <h3 className="text-xl font-medium text-white mb-3">I forgot my password, can you recover my tasks?</h3>
                <p className="text-gray-400 font-light leading-relaxed">Because Tasker is End-to-End Encrypted, we do not hold your decryption keys. If you lose your account recovery phrase, we cannot restore your encrypted data.</p>
              </div>
              
              <div>
                <h3 className="text-xl font-medium text-white mb-3">Is there a web or Mac version?</h3>
                <p className="text-gray-400 font-light leading-relaxed">Currently Tasker is incredibly focused on delivering a perfect iOS experience. Mac and Web platforms are on our roadmap.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Landing() {
  useScrollReveal();

  return (
    // Colorize: Using a deeply tinted, rich indigo-black instead of pure #000 for warmth
    <div className="min-h-screen bg-[#030305] text-white font-sans selection:bg-indigo-500/30 selection:text-white relative overflow-x-hidden">
      
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 px-8 py-6 w-full">
        <div className="absolute inset-0 bg-gradient-to-b from-[#030305]/80 to-transparent backdrop-blur-sm -z-10 pointer-events-none"></div>
        <div className="max-w-7xl mx-auto flex flex-row justify-between items-center w-full relative z-10">
          <div className="font-serif text-3xl tracking-tight text-white select-none cursor-pointer hover:opacity-80 transition-opacity duration-300 drop-shadow-md">
            Tasker.
          </div>
          <div className="hidden md:flex items-center gap-10">
            <a href="#focus" className="text-sm font-medium text-gray-400 hover:text-white hover:-translate-y-0.5 transition-all duration-300">Audience</a>
            <a href="#flow" className="text-sm font-medium text-gray-400 hover:text-white hover:-translate-y-0.5 transition-all duration-300">The Loop</a>
            <a href="#surfaces" className="text-sm font-medium text-gray-400 hover:text-white hover:-translate-y-0.5 transition-all duration-300">Surfaces</a>
          </div>
          <div>
            <button className="liquid-glass rounded-full px-6 py-2.5 text-sm font-medium text-white hover:bg-white/10 hover:shadow-[0_0_20px_rgba(255,255,255,0.15)] active:scale-95 transition-all duration-300">
              Begin
            </button>
          </div>
        </div>
      </nav>

      {/* Section 1: The Hero */}
      <section className="relative w-full h-screen flex flex-col items-center justify-center overflow-hidden">
        <video 
          autoPlay 
          loop 
          muted 
          playsInline 
          className="absolute inset-0 w-full h-full object-cover z-0"
        >
          <source src="https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260324_151826_c7218672-6e92-402c-9e45-f1e0f454bdc4.mp4" type="video/mp4" />
        </video>
        
        {/* Adjusted Video Overlay */}
        <div className="absolute inset-0 bg-[#030305]/60 z-[1]"></div>
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_0%,#030305_100%)] opacity-80 z-[2]"></div>
        
        <div className="relative z-10 text-center px-6 flex flex-col items-center justify-center h-full pt-16 w-full max-w-5xl mx-auto">
          <h1 className="font-serif text-6xl md:text-[7.5rem] leading-[0.9] text-white animate-fade-rise drop-shadow-2xl tracking-tight">
            Intent to Action.
          </h1>
          <p className="text-gray-300 text-lg md:text-2xl md:leading-relaxed mt-10 max-w-3xl mx-auto tracking-wide animate-fade-rise-delay font-light drop-shadow-md">
            An ADHD-focused life-management app built for low-friction planning, fast execution, and momentum-preserving follow-through.
          </p>
          <button 
            onClick={() => document.getElementById('focus')?.scrollIntoView({ behavior: 'smooth' })}
            className="liquid-glass rounded-full px-12 py-4 mt-12 text-white font-medium hover:bg-white/10 hover:shadow-[0_0_30px_rgba(255,255,255,0.15)] active:scale-[0.97] transition-all duration-300 animate-fade-rise-delay-2 flex items-center gap-3 group"
          >
            <span>Enter Tasker</span>
            <svg className="w-4 h-4 opacity-50 group-hover:opacity-100 group-hover:translate-x-1 transition-all duration-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
            </svg>
          </button>
        </div>
      </section>

      {/* Section 2: Audience Context */}
      <section id="focus" className="relative w-full min-h-screen">
        <video 
          autoPlay 
          loop 
          muted 
          playsInline 
          className="absolute inset-0 w-full h-full object-cover z-0"
        >
          <source src="https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260314_131748_f2ca2a28-fed7-44c8-b9a9-bd9acdd5ec31.mp4" type="video/mp4" />
        </video>
        
        {/* Adjusted Video Overlay */}
        <div className="absolute inset-0 bg-gradient-to-r from-[#030305]/95 via-[#030305]/40 to-transparent z-[1]"></div>
        <div className="absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-[#030305] to-transparent z-[1]"></div>
        <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-[#030305] to-transparent z-[1]"></div>
        
        <div className="relative z-10 max-w-7xl mx-auto px-8 py-32 flex flex-col justify-center h-full min-h-screen">
          <div className="max-w-xl">
            <h2 className="scroll-reveal opacity-0 translate-y-6 font-serif text-5xl md:text-7xl mb-16 text-white leading-tight drop-shadow-xl">
              Execution, <span className="text-gray-400 italic">unlocked.</span>
            </h2>
            
            <div className="flex flex-col gap-10">
              <div className="scroll-reveal opacity-0 translate-y-6 group cursor-default" style={{ animationDelay: '100ms' }}>
                <div className="pl-6 border-l w-full border-white/10 group-hover:border-white/50 transition-colors duration-500">
                  <h3 className="font-medium text-white/80 group-hover:text-white text-xl md:text-2xl transition-colors duration-500">No Shame-Based Pressure.</h3>
                  <p className="text-gray-400 group-hover:text-gray-300 mt-2 text-base md:text-lg font-light transition-colors duration-500">Gentle restart paths for low-energy and burnout-prone minds. Recover from interruptions gracefully.</p>
                </div>
              </div>
              
              <div className="scroll-reveal opacity-0 translate-y-6 group cursor-default" style={{ animationDelay: '200ms' }}>
                <div className="pl-6 border-l border-white/10 group-hover:border-white/50 transition-colors duration-500">
                  <h3 className="font-medium text-white/80 group-hover:text-white text-xl md:text-2xl transition-colors duration-500">High Context Load.</h3>
                  <p className="text-gray-400 group-hover:text-gray-300 mt-2 text-base md:text-lg font-light transition-colors duration-500">Adults and students facing deadlines are supported by bounded 'Now' lists and intelligent Quick Views.</p>
                </div>
              </div>
              
              <div className="scroll-reveal opacity-0 translate-y-6 group cursor-default" style={{ animationDelay: '300ms' }}>
                <div className="pl-6 border-l border-white/10 group-hover:border-white/50 transition-colors duration-500">
                  <h3 className="font-medium text-white/80 group-hover:text-white text-xl md:text-2xl transition-colors duration-500">Behavior Consistency.</h3>
                  <p className="text-gray-400 group-hover:text-gray-300 mt-2 text-base md:text-lg font-light transition-colors duration-500">Habit-oriented users can build structure and momentum securely, without the stress of perfection.</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Section 3: The 5-Phase Loop Showcase */}
      <section id="flow" className="bg-[#030305] pt-32 pb-40 px-8 relative overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-2xl h-[400px] bg-indigo-500/5 blur-[120px] rounded-full pointer-events-none"></div>

        <h2 className="scroll-reveal opacity-0 translate-y-6 font-serif text-5xl md:text-6xl text-white md:mb-8 mb-6 text-center relative z-10">
          The Five-Phase Loop.
        </h2>
        <p className="scroll-reveal opacity-0 translate-y-6 text-center text-gray-400 max-w-2xl mx-auto mb-24 text-lg font-light">Tasker intentionally structures your execution lifecycle to reduce friction at every single critical transition.</p>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 max-w-7xl mx-auto relative z-10">
          
          <div className="scroll-reveal opacity-0 translate-y-6 group relative cursor-pointer overflow-hidden transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] hover:-translate-y-4 hover:shadow-[0_20px_40px_rgba(0,0,0,0.4)] bg-[#0A0A0E] rounded-[2.5rem] border border-white/5 hover:border-white/20 p-8 py-10 aspect-square lg:aspect-[3/4] xl:aspect-[4/5] flex flex-col justify-end">
            <div className="absolute inset-0 bg-gradient-to-b from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />
            <div className="text-indigo-400/20 font-serif text-6xl absolute top-8 right-8 group-hover:scale-110 group-hover:text-indigo-400/40 transition-all duration-500">1</div>
            <h3 className="font-serif text-3xl text-white relative z-10">Capture.</h3>
            <p className="text-sm md:text-base text-gray-500 mt-3 font-light relative z-10 group-hover:text-gray-300 transition-colors">Lightning fast input. Minimal required fields with specialized Clarify modes.</p>
          </div>

          <div className="scroll-reveal opacity-0 translate-y-6 group relative cursor-pointer overflow-hidden transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] hover:-translate-y-4 hover:shadow-[0_20px_40px_rgba(0,0,0,0.4)] bg-[#0A0A0E] rounded-[2.5rem] border border-white/5 hover:border-white/20 p-8 py-10 aspect-square lg:aspect-[3/4] xl:aspect-[4/5] flex flex-col justify-end" style={{ animationDelay: '100ms' }}>
            <div className="absolute inset-0 bg-gradient-to-b from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />
            <div className="text-indigo-400/20 font-serif text-6xl absolute top-8 right-8 group-hover:scale-110 group-hover:text-indigo-400/40 transition-all duration-500">2</div>
            <h3 className="font-serif text-3xl text-white relative z-10">Decide.</h3>
            <p className="text-sm md:text-base text-gray-500 mt-3 font-light relative z-10 group-hover:text-gray-300 transition-colors">Narrow your focus to actionable choices now using a bounded "Now" list.</p>
          </div>

          <div className="scroll-reveal opacity-0 translate-y-6 group relative cursor-pointer overflow-hidden transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] hover:-translate-y-4 hover:shadow-[0_20px_40px_rgba(0,0,0,0.4)] bg-[#0A0A0E] rounded-[2.5rem] border border-white/5 hover:border-white/20 p-8 py-10 aspect-square lg:aspect-[3/4] xl:aspect-[4/5] flex flex-col justify-end" style={{ animationDelay: '200ms' }}>
            <div className="absolute inset-0 bg-gradient-to-b from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />
            <div className="text-indigo-400/20 font-serif text-6xl absolute top-8 right-8 group-hover:scale-110 group-hover:text-indigo-400/40 transition-all duration-500">3</div>
            <h3 className="font-serif text-3xl text-white relative z-10">Start.</h3>
            <p className="text-sm md:text-base text-gray-500 mt-3 font-light relative z-10 group-hover:text-gray-300 transition-colors">Minimize transition costs from planning to action. No UI clutter just your work.</p>
          </div>

          <div className="scroll-reveal opacity-0 translate-y-6 group relative cursor-pointer overflow-hidden transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] hover:-translate-y-4 hover:shadow-[0_20px_40px_rgba(0,0,0,0.4)] bg-[#0A0A0E] rounded-[2.5rem] border border-white/5 hover:border-white/20 p-8 py-10 aspect-square lg:aspect-[3/4] xl:aspect-[4/5] flex flex-col justify-end" style={{ animationDelay: '300ms' }}>
            <div className="absolute inset-0 bg-gradient-to-b from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />
            <div className="text-indigo-400/20 font-serif text-6xl absolute top-8 right-8 group-hover:scale-110 group-hover:text-indigo-400/40 transition-all duration-500">4</div>
            <h3 className="font-serif text-3xl text-white relative z-10">Resume.</h3>
            <p className="text-sm md:text-base text-gray-500 mt-3 font-light relative z-10 group-hover:text-gray-300 transition-colors">Keep context instantly available after interruptions with intelligent resume cues.</p>
          </div>

          <div className="scroll-reveal opacity-0 translate-y-6 group relative cursor-pointer overflow-hidden transition-all duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] hover:-translate-y-4 hover:shadow-[0_20px_40px_rgba(0,0,0,0.4)] bg-[#0A0A0E] rounded-[2.5rem] border border-white/5 hover:border-white/20 p-8 py-10 aspect-square lg:aspect-[3/4] xl:aspect-[4/5] flex flex-col justify-end" style={{ animationDelay: '400ms' }}>
            <div className="absolute inset-0 bg-gradient-to-b from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />
            <div className="text-indigo-400/20 font-serif text-6xl absolute top-8 right-8 group-hover:scale-110 group-hover:text-indigo-400/40 transition-all duration-500">5</div>
            <h3 className="font-serif text-3xl text-white relative z-10">Reflect.</h3>
            <p className="text-sm md:text-base text-gray-500 mt-3 font-light relative z-10 group-hover:text-gray-300 transition-colors">A lightweight done timeline to encourage continuity and healthy recovery loops.</p>
          </div>
          
        </div>
      </section>

      {/* Experience Surfaces Section */}
      <section id="surfaces" className="bg-[#0A0A0E] py-32 px-8 relative border-y border-white/5">
        <div className="max-w-6xl mx-auto">
          <h2 className="scroll-reveal opacity-0 translate-y-6 font-serif text-5xl md:text-6xl text-white mb-20 text-center">Safety. Rules. Intelligence.</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-y-16 gap-x-12">
            <div className="scroll-reveal opacity-0 translate-y-6 group">
              <h3 className="text-3xl font-serif text-white mb-4 group-hover:text-indigo-400 transition-colors duration-300">First-Class Habits</h3>
              <p className="text-gray-400 font-light leading-relaxed">Integrated tracking for positive and negative behaviors. Build resilience with 14-day histories, daily check-ins, and realistic recovery loops.</p>
            </div>
            <div className="scroll-reveal opacity-0 translate-y-6 group" style={{ animationDelay: '100ms' }}>
              <h3 className="text-3xl font-serif text-white mb-4 group-hover:text-indigo-400 transition-colors duration-300">Safe Assistant</h3>
              <p className="text-gray-400 font-light leading-relaxed">An intelligent partner in Ask, Plan, or Apply modes. It strictly abides by trust guardrails: confirmation prompts, bounded undo, and zero silent mutations.</p>
            </div>
            <div className="scroll-reveal opacity-0 translate-y-6 group" style={{ animationDelay: '200ms' }}>
              <h3 className="text-3xl font-serif text-white mb-4 group-hover:text-indigo-400 transition-colors duration-300">Momentum Insights</h3>
              <p className="text-gray-400 font-light leading-relaxed">Systematic analytics dissect your focus pulse, completion mix, and priority patterns. No toxic gamification—just objective progression visibility.</p>
            </div>
            <div className="scroll-reveal opacity-0 translate-y-6 group" style={{ animationDelay: '300ms' }}>
              <h3 className="text-3xl font-serif text-white mb-4 group-hover:text-indigo-400 transition-colors duration-300">Notification Boundaries</h3>
              <p className="text-gray-400 font-light leading-relaxed">Relevance over volume. Tasker avoids stale prompts, focusing on actionable cues that frame your day naturally without overwhelming noise.</p>
            </div>
          </div>
        </div>
      </section>

      {/* The Manifesto */}
      <section className="bg-[#030305] py-32 md:py-48 px-8 relative">
        <div className="max-w-3xl mx-auto text-center">
          <h2 className="scroll-reveal opacity-0 translate-y-6 font-serif text-4xl md:text-5xl text-white mb-8 leading-tight">
            Software as an extension<br/>of the mind.
          </h2>
          <div className="scroll-reveal opacity-0 translate-y-6 flex flex-col gap-6 text-gray-400 font-light text-lg md:text-xl leading-relaxed" style={{ animationDelay: '100ms' }}>
            <p>
              Most tools today are built to harvest your attention. They are loud, complex, and designed for engagement metrics over human output.
            </p>
            <p>
              Tasker is built differently. It's a quiet sanctuary for your life's work. We believe in reducing execution friction, absolute privacy, and the undeniable power of deep focus. No ads. No addictive loops.
            </p>
          </div>
          <div className="scroll-reveal opacity-0 translate-y-6 mt-16" style={{ animationDelay: '200ms' }}>
            <p className="text-white/80 font-serif italic text-2xl">— Saransh</p>
          </div>
        </div>
      </section>

      {/* Footer (App Store Requirements) */}
      <footer className="bg-[#0A0A0E] border-t border-white/5 py-16 px-8 relative z-10">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-8">
          <div className="font-serif text-2xl text-white/30 select-none">
            Tasker.
          </div>
          <div className="flex flex-wrap justify-center gap-10">
            <a href="#/support" className="text-sm font-medium text-gray-500 hover:text-white transition-colors duration-300">Support</a>
            <a href="#/privacy" className="text-sm font-medium text-gray-500 hover:text-white transition-colors duration-300">Privacy Policy</a>
            <a href="#/terms" className="text-sm font-medium text-gray-500 hover:text-white transition-colors duration-300">Terms of Service</a>
          </div>
          <div className="text-sm text-gray-600">
            &copy; {new Date().getFullYear()} Tasker App.
          </div>
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
