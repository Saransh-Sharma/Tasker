import type { CSSProperties, ReactNode } from 'react';
import { cx, useAnimatedInView, type SpellTextProps } from './shared';

type HighlightDirection = 'left' | 'right' | 'top' | 'bottom';

type HighlightedTextProps = SpellTextProps & {
  children: ReactNode;
  from?: HighlightDirection;
  style?: CSSProperties;
};

const highlightAnimations: Record<HighlightDirection, string> = {
  left: 'spell-highlight-slide-left',
  right: 'spell-highlight-slide-right',
  top: 'spell-highlight-slide-top',
  bottom: 'spell-highlight-slide-bottom',
};

const highlightTransforms: Record<HighlightDirection, string> = {
  left: 'translateX(-100%)',
  right: 'translateX(100%)',
  top: 'translateY(-100%)',
  bottom: 'translateY(100%)',
};

export function HighlightedText({
  children,
  className,
  delay = 0,
  inView = false,
  once = true,
  from = 'bottom',
  style,
}: HighlightedTextProps) {
  const { ref, isActive, prefersReducedMotion } = useAnimatedInView<HTMLSpanElement>({ inView, once });

  return (
    <span
      ref={ref}
      className={cx('spell-highlight', className)}
      style={style}
    >
      <span
        className="spell-highlight-fill"
        aria-hidden="true"
        style={
          prefersReducedMotion
            ? undefined
            : isActive
              ? {
                  animationName: highlightAnimations[from],
                  animationDelay: `${delay}s`,
                }
              : { transform: highlightTransforms[from] }
        }
      />
      <span className="spell-highlight-content">{children}</span>
    </span>
  );
}
