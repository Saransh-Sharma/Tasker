import { useMemo, type CSSProperties, type ElementType } from 'react';
import { cx, useAnimatedInView, type SpellTextProps } from './shared';

type WordsStaggerProps = SpellTextProps & {
  children: string;
  as?: ElementType;
  stagger?: number;
  duration?: number;
  style?: CSSProperties;
};

export function WordsStagger({
  children,
  className,
  delay = 0,
  inView = false,
  once = true,
  as,
  stagger = 0.1,
  duration = 0.55,
  style,
}: WordsStaggerProps) {
  const Component = (as ?? 'span') as ElementType;
  const { ref, isActive, prefersReducedMotion } = useAnimatedInView<HTMLElement>({ inView, once });
  const words = useMemo(() => children.split(' ').filter(Boolean), [children]);

  if (prefersReducedMotion) {
    return (
      <Component ref={ref as never} className={className} style={style}>
        {children}
      </Component>
    );
  }

  return (
    <Component ref={ref as never} className={cx('spell-words-stagger', className)} style={style}>
      <span className="sr-only">{children}</span>
      {words.map((word, index) => (
        <span key={`${word}-${index}`} aria-hidden="true" className="inline-block">
          <span
            className={cx('spell-word-stagger-item', isActive && 'spell-word-stagger-item-active')}
            style={{
              animationDelay: `${delay + index * stagger}s`,
              animationDuration: `${duration}s`,
            }}
          >
            {word}
          </span>
          {index < words.length - 1 ? <span className="inline-block">&nbsp;</span> : null}
        </span>
      ))}
    </Component>
  );
}
