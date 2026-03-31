import { useEffect, useRef, useState } from 'react';

export type SpellTextProps = {
  className?: string;
  delay?: number;
  inView?: boolean;
  once?: boolean;
};

export function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(' ');
}

export function usePrefersReducedMotion() {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    const updatePreference = () => setPrefersReducedMotion(mediaQuery.matches);

    updatePreference();
    mediaQuery.addEventListener('change', updatePreference);

    return () => mediaQuery.removeEventListener('change', updatePreference);
  }, []);

  return prefersReducedMotion;
}

export function useAnimatedInView<T extends HTMLElement>({
  inView = false,
  once = true,
}: {
  inView?: boolean;
  once?: boolean;
}) {
  const prefersReducedMotion = usePrefersReducedMotion();
  const ref = useRef<T | null>(null);
  const [isActive, setIsActive] = useState(!inView);

  useEffect(() => {
    if (prefersReducedMotion || !inView) {
      setIsActive(true);
      return;
    }

    const target = ref.current;
    if (!target) {
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsActive(true);
          if (once) {
            observer.disconnect();
          }
          return;
        }

        if (!once) {
          setIsActive(false);
        }
      },
      { threshold: 0.2, rootMargin: '0px 0px -10% 0px' },
    );

    observer.observe(target);

    return () => observer.disconnect();
  }, [inView, once, prefersReducedMotion]);

  return { ref, isActive, prefersReducedMotion };
}
