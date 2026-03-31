import { type CSSProperties, type ElementType } from 'react';
import { cx, useAnimatedInView, type SpellTextProps } from './shared';

type BlurRevealProps = SpellTextProps & {
  children: string;
  as?: ElementType;
  speedReveal?: number;
  speedSegment?: number;
  letterSpacing?: string | number;
  style?: CSSProperties;
};

export function BlurReveal({
  children,
  className,
  delay = 0,
  inView = false,
  once = true,
  as,
  speedReveal = 0.85,
  speedSegment = 0.32,
  letterSpacing,
  style,
}: BlurRevealProps) {
  const Component = (as ?? 'p') as ElementType;
  const { ref, isActive, prefersReducedMotion } = useAnimatedInView<HTMLElement>({ inView, once });
  const stagger = 0.03 / speedReveal;
  const duration = 0.3 / speedSegment;

  if (prefersReducedMotion) {
    return (
      <Component ref={ref as never} className={className} style={style}>
        {children}
      </Component>
    );
  }

  return (
    <Component ref={ref as never} className={cx('spell-blur-reveal', className)} style={style}>
      <span className="sr-only">{children}</span>
      {children.split(' ').map((word, wordIndex, wordArray) => (
        <span key={`word-${wordIndex}`} aria-hidden="true" className="inline-block whitespace-nowrap">
          {Array.from(word).map((character, charIndex) => (
            <span
              key={`char-${wordIndex}-${charIndex}`}
              className={cx('spell-blur-char', isActive && 'spell-blur-char-active')}
              style={{
                animationDelay: `${delay + (wordIndex * 0.4 + charIndex) * stagger}s`,
                animationDuration: `${duration}s`,
                marginRight: letterSpacing,
              }}
            >
              {character}
            </span>
          ))}
          {wordIndex < wordArray.length - 1 ? (
            <span
              className={cx('spell-blur-char', isActive && 'spell-blur-char-active')}
              style={{
                animationDelay: `${delay + (wordIndex * 0.4 + word.length) * stagger}s`,
                animationDuration: `${duration}s`,
              }}
            >
              &nbsp;
            </span>
          ) : null}
        </span>
      ))}
    </Component>
  );
}
