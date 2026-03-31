import { useEffect, useRef, useState } from 'react';
import { cx, useAnimatedInView, type SpellTextProps } from './shared';

type SpecialTextProps = SpellTextProps & {
  children: string;
  speed?: number;
};

const RANDOM_CHARS = '_!X$0-+*#';

function getRandomChar(previousChar?: string) {
  let character = RANDOM_CHARS[Math.floor(Math.random() * RANDOM_CHARS.length)];

  while (character === previousChar) {
    character = RANDOM_CHARS[Math.floor(Math.random() * RANDOM_CHARS.length)];
  }

  return character;
}

export function SpecialText({
  children,
  className,
  delay = 0,
  inView = false,
  once = true,
  speed = 20,
}: SpecialTextProps) {
  const { ref, isActive, prefersReducedMotion } = useAnimatedInView<HTMLSpanElement>({ inView, once });
  const [displayText, setDisplayText] = useState(() => children);
  const [hasStarted, setHasStarted] = useState(false);
  const intervalRef = useRef<number | null>(null);
  const timeoutRef = useRef<number | null>(null);

  useEffect(() => {
    if (!isActive || prefersReducedMotion) {
      setDisplayText(children);
      return () => {
        if (timeoutRef.current !== null) {
          window.clearTimeout(timeoutRef.current);
          timeoutRef.current = null;
        }

        if (intervalRef.current !== null) {
          window.clearInterval(intervalRef.current);
          intervalRef.current = null;
        }
      };
    }

    if (hasStarted) {
      return () => {
        if (timeoutRef.current !== null) {
          window.clearTimeout(timeoutRef.current);
          timeoutRef.current = null;
        }

        if (intervalRef.current !== null) {
          window.clearInterval(intervalRef.current);
          intervalRef.current = null;
        }
      };
    }

    const begin = () => {
      setHasStarted(true);

      let step = 0;
      const totalSteps = children.length * 2;

      intervalRef.current = window.setInterval(() => {
        const revealedCount = Math.floor(step / 2);
        const nextChars: string[] = [];

        for (let index = 0; index < revealedCount && index < children.length; index += 1) {
          nextChars.push(children[index]);
        }

        if (revealedCount < children.length) {
          nextChars.push(step % 2 === 0 ? '_' : getRandomChar());
        }

        while (nextChars.length < children.length) {
          nextChars.push(getRandomChar(nextChars[nextChars.length - 1]));
        }

        setDisplayText(nextChars.join(''));
        step += 1;

        if (step >= totalSteps) {
          if (intervalRef.current !== null) {
            window.clearInterval(intervalRef.current);
            intervalRef.current = null;
          }
          setDisplayText(children);
        }
      }, speed);
    };

    if (delay > 0) {
      timeoutRef.current = window.setTimeout(begin, delay * 1000);
    }
    else {
      begin();
    }

    return () => {
      if (timeoutRef.current !== null) {
        window.clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }

      if (intervalRef.current !== null) {
        window.clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, [children, delay, hasStarted, isActive, prefersReducedMotion, speed]);

  useEffect(() => {
    setHasStarted(false);
    setDisplayText(children);
  }, [children]);

  return (
    <span ref={ref} className={cx('spell-special-text', className)}>
      {displayText}
    </span>
  );
}
