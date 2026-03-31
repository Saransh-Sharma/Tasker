import { useMemo, type CSSProperties, type ElementType } from 'react';
import { cx, useAnimatedInView, type SpellTextProps } from './shared';

type SlideUpTextProps = SpellTextProps & {
  children: string;
  as?: ElementType;
  split?: 'words' | 'characters';
  stagger?: number;
  duration?: number;
  style?: CSSProperties;
};

export function SlideUpText({
  children,
  className,
  delay = 0,
  inView = false,
  once = true,
  as,
  split = 'words',
  stagger = 0.12,
  duration = 0.68,
  style,
}: SlideUpTextProps) {
  const Component = (as ?? 'span') as ElementType;
  const { ref, isActive, prefersReducedMotion } = useAnimatedInView<HTMLElement>({ inView, once });

  const units = useMemo(() => {
    if (split === 'characters') {
      return Array.from(children).map((character, index) => ({
        content: character === ' ' ? '\u00A0' : character,
        key: `char-${index}`,
      }));
    }

    return children.split(' ').map((word, index, array) => ({
      content: `${word}${index < array.length - 1 ? '\u00A0' : ''}`,
      key: `word-${index}`,
    }));
  }, [children, split]);

  if (prefersReducedMotion) {
    return (
      <Component ref={ref as never} className={className} style={style}>
        {children}
      </Component>
    );
  }

  return (
    <Component ref={ref as never} className={cx('spell-slide-up', className)} style={style}>
      <span className="sr-only">{children}</span>
      {units.map((unit, index) => (
        <span key={unit.key} aria-hidden="true" className="spell-slide-up-clip">
          <span
            className={cx('spell-slide-up-unit', isActive && 'spell-slide-up-unit-active')}
            style={{
              animationDelay: `${delay + index * stagger}s`,
              animationDuration: `${duration}s`,
            }}
          >
            {unit.content}
          </span>
        </span>
      ))}
    </Component>
  );
}
