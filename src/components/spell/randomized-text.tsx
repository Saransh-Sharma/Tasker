import { useMemo } from 'react';
import { cx, useAnimatedInView, type SpellTextProps } from './shared';

type RandomizedTextProps = SpellTextProps & {
  children: string;
  split?: 'words' | 'chars';
};

export function RandomizedText({
  children,
  className,
  delay = 0.2,
  inView = false,
  once = true,
  split = 'words',
}: RandomizedTextProps) {
  const { ref, isActive, prefersReducedMotion } = useAnimatedInView<HTMLSpanElement>({ inView, once });

  const elements = useMemo(() => {
    if (split === 'chars') {
      return Array.from(children).map((character, index) => ({
        content: character === ' ' ? '\u00A0' : character,
        key: `char-${index}`,
      }));
    }

    return children.split(' ').map((word, index) => ({
      content: word,
      key: `word-${index}`,
    }));
  }, [children, split]);

  const randomizedDelays = useMemo(
    () => elements.map(() => delay + Math.random() * 0.32 + Math.random() * 0.06),
    [delay, elements],
  );

  if (prefersReducedMotion) {
    return (
      <span ref={ref} className={className}>
        {children}
      </span>
    );
  }

  return (
    <span
      ref={ref}
      className={cx('spell-randomized-text', className)}
      aria-label={children}
    >
      {elements.map((element, index) => (
        <span
          key={element.key}
          className={cx('spell-randomized-unit', isActive && 'spell-randomized-unit-active')}
          style={{
            animationDelay: `${randomizedDelays[index]}s`,
          }}
        >
          {element.content}
          {split === 'words' && index < elements.length - 1 ? '\u00A0' : null}
        </span>
      ))}
    </span>
  );
}
