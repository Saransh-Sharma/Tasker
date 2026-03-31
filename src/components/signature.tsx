import { useEffect, useId, useRef, useState } from 'react';

type SignatureProps = {
  text?: string;
  color?: string;
  fontSize?: number;
  duration?: number;
  delay?: number;
  className?: string;
  inView?: boolean;
  once?: boolean;
};

type OpenTypeGlyph = {
  advanceWidth?: number;
  getPath: (x: number, y: number, fontSize: number) => {
    toPathData: (precision?: number) => string;
  };
};

type OpenTypeFont = {
  unitsPerEm: number;
  charToGlyph: (character: string) => OpenTypeGlyph;
};

type OpenTypeLoader = {
  load: (
    path: string,
    callback: (error: Error | null, font?: OpenTypeFont) => void,
  ) => void;
};

declare global {
  interface Window {
    opentype?: OpenTypeLoader;
  }
}

const SIGNATURE_HEIGHT = 100;

function getAssetUrl(fileName: string) {
  return new URL(`${import.meta.env.BASE_URL}${fileName}`, window.location.origin).toString();
}

function loadOpenTypeScript() {
  if (window.opentype) {
    return Promise.resolve(window.opentype);
  }

  return new Promise<OpenTypeLoader>((resolve, reject) => {
    const existingScript = document.querySelector<HTMLScriptElement>('script[data-opentype-script="true"]');

    const handleLoad = () => {
      if (window.opentype) {
        resolve(window.opentype);
        return;
      }

      reject(new Error('opentype.js loaded without exposing window.opentype'));
    };

    const handleError = () => reject(new Error('Failed to load opentype.js'));

    if (existingScript) {
      existingScript.addEventListener('load', handleLoad, { once: true });
      existingScript.addEventListener('error', handleError, { once: true });
      return;
    }

    const script = document.createElement('script');
    script.async = true;
    script.src = getAssetUrl('opentype.min.js');
    script.dataset.opentypeScript = 'true';
    script.addEventListener('load', handleLoad, { once: true });
    script.addEventListener('error', handleError, { once: true });
    document.head.appendChild(script);
  });
}

function loadFont(opentype: OpenTypeLoader, path: string) {
  return new Promise<OpenTypeFont>((resolve, reject) => {
    opentype.load(path, (error, font) => {
      if (error || !font) {
        reject(error ?? new Error(`Unable to load font at ${path}`));
        return;
      }

      resolve(font);
    });
  });
}

export function Signature({
  text = 'Signature',
  color = '#000',
  fontSize = 14,
  duration = 1.5,
  delay = 0,
  className,
  inView = false,
  once = true,
}: SignatureProps) {
  const [paths, setPaths] = useState<string[]>([]);
  const [width, setWidth] = useState(300);
  const [lengths, setLengths] = useState<number[]>([]);
  const [hasFallback, setHasFallback] = useState(false);
  const [isVisible, setIsVisible] = useState(!inView);
  const svgRef = useRef<SVGSVGElement | null>(null);
  const pathRefs = useRef<Array<SVGPathElement | null>>([]);
  const maskId = `signature-reveal-${useId().replace(/:/g, '')}`;

  const horizontalPadding = fontSize * 0.1;
  const topMargin = Math.max(5, (SIGNATURE_HEIGHT - fontSize) / 2);
  const baseline = Math.min(SIGNATURE_HEIGHT - 5, topMargin + fontSize);

  useEffect(() => {
    if (!inView) {
      setIsVisible(true);
      return;
    }

    const target = svgRef.current;
    if (!target) {
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          if (once) {
            observer.disconnect();
          }
          return;
        }

        if (!once) {
          setIsVisible(false);
        }
      },
      { threshold: 0.2 },
    );

    observer.observe(target);

    return () => observer.disconnect();
  }, [inView, once, paths.length]);

  useEffect(() => {
    let cancelled = false;

    async function generateSignaturePaths() {
      try {
        const opentype = await loadOpenTypeScript();
        const fontCandidates = [
          getAssetUrl('LastoriaBoldRegular.otf'),
          `${window.location.origin}${import.meta.env.BASE_URL}LastoriaBoldRegular.otf`,
          './LastoriaBoldRegular.otf',
        ];

        let font: OpenTypeFont | null = null;

        for (const candidate of fontCandidates) {
          try {
            font = await loadFont(opentype, candidate);
            break;
          } catch {
            // Try the next candidate.
          }
        }

        if (!font) {
          throw new Error('Signature font could not be loaded');
        }

        let x = horizontalPadding;
        const nextPaths: string[] = [];

        for (const character of text) {
          const glyph = font.charToGlyph(character);
          const glyphPath = glyph.getPath(x, baseline, fontSize);
          nextPaths.push(glyphPath.toPathData(3));

          const advanceWidth = glyph.advanceWidth ?? font.unitsPerEm;
          x += advanceWidth * (fontSize / font.unitsPerEm);
        }

        if (!cancelled) {
          setPaths(nextPaths);
          setWidth(x + horizontalPadding);
          setHasFallback(false);
        }
      } catch {
        if (!cancelled) {
          setPaths([]);
          setLengths([]);
          setWidth(text.length * fontSize * 0.66);
          setHasFallback(true);
        }
      }
    }

    generateSignaturePaths();

    return () => {
      cancelled = true;
    };
  }, [baseline, fontSize, horizontalPadding, text]);

  useEffect(() => {
    if (!paths.length) {
      return;
    }

    const nextLengths = pathRefs.current.slice(0, paths.length).map((path) => path?.getTotalLength() ?? 0);
    setLengths(nextLengths);
  }, [paths]);

  if (hasFallback) {
    return (
      <span
        className={className}
        style={{
          color,
          display: 'inline-block',
          fontFamily: '"Snell Roundhand", "Segoe Script", "Brush Script MT", cursive',
          fontSize: `${fontSize}px`,
          lineHeight: 1,
          whiteSpace: 'nowrap',
        }}
      >
        {text}
      </span>
    );
  }

  return (
    <svg
      ref={svgRef}
      width={width}
      height={SIGNATURE_HEIGHT}
      viewBox={`0 0 ${width} ${SIGNATURE_HEIGHT}`}
      fill="none"
      className={className}
      preserveAspectRatio="xMinYMid meet"
      role="img"
      aria-label={text}
    >
      <defs>
        <mask id={maskId} maskUnits="userSpaceOnUse">
          {paths.map((path, index) => {
            const pathLength = lengths[index] ?? 0;
            const stepDelay = delay + index * 0.2;

            return (
              <path
                key={`mask-${index}`}
                d={path}
                className="signature-mask-path"
                stroke="white"
                strokeWidth={fontSize * 0.22}
                fill="none"
                vectorEffect="non-scaling-stroke"
                strokeLinecap="round"
                strokeLinejoin="round"
                style={{
                  strokeDasharray: pathLength || undefined,
                  strokeDashoffset: pathLength || undefined,
                  opacity: 0,
                  animation: isVisible && pathLength
                    ? `signature-draw ${duration}s ease-in-out ${stepDelay}s forwards, signature-show 0.01s linear ${stepDelay + 0.01}s forwards`
                    : undefined,
                }}
              />
            );
          })}
        </mask>
      </defs>

      {paths.map((path, index) => {
        const pathLength = lengths[index] ?? 0;
        const stepDelay = delay + index * 0.2;

        return (
          <path
            key={`stroke-${index}`}
            ref={(node) => {
              pathRefs.current[index] = node;
            }}
            d={path}
            className="signature-path"
            stroke={color}
            strokeWidth={2}
            fill="none"
            vectorEffect="non-scaling-stroke"
            strokeLinecap="butt"
            strokeLinejoin="round"
            style={{
              strokeDasharray: pathLength || undefined,
              strokeDashoffset: pathLength || undefined,
              opacity: 0,
              animation: isVisible && pathLength
                ? `signature-draw ${duration}s ease-in-out ${stepDelay}s forwards, signature-show 0.01s linear ${stepDelay + 0.01}s forwards`
                : undefined,
            }}
          />
        );
      })}

      <g mask={`url(#${maskId})`}>
        {paths.map((path, index) => (
          <path key={`fill-${index}`} d={path} fill={color} />
        ))}
      </g>
    </svg>
  );
}
