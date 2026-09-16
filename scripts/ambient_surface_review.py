#!/usr/bin/env python3
"""Read-only evidence gallery for dedicated feature header artwork."""
import html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];base=ROOT/'docs/design/ambient-surfaces'
m=json.loads((base/'manifest.json').read_text())
parts=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>LifeBoard feature artwork</title><style>body{font:16px system-ui;background:#fbf3e2;color:#2b2118;margin:32px}section{border-top:1px solid #bfb198;padding:24px 0}.pair{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:24px}figure{margin:0;padding:12px;border-radius:16px;background:#f5ebd8}figure.dark{background:#171c2c;color:#f5ebd8}img{display:block;width:100%;height:auto;margin:8px 0}a{color:inherit}small{display:block}h2{font-size:22px}</style><h1>LifeBoard feature header artwork</h1><p>Dedicated panoramic artwork for 17 feature families. Original production scenes remain preserved. Native header captures below use default text size at 353 points wide; these are component captures, not full-screen route acceptance.</p><p><a href="IMAGE_GENERATION_PROMPTS.md">Exact prompts</a> · <a href="manifest.json">Manifest and source history</a> · <a href="VALIDATION.md">Validation</a></p>']
for name in dict.fromkeys(e['asset_name'] for e in m['entries']):
 group=[e for e in m['entries'] if e['asset_name']==name];feature=name.removeprefix('AmbientSurface_').removesuffix('Header')
 parts.append(f'<section><h2>{html.escape(feature.title())}</h2><div class="pair">')
 for e in group:
  a=e['appearance'];parts.append(f'<figure class="{a}"><figcaption>{a.title()} · {e["inspection_status"]}</figcaption>')
  if (ROOT/e['output']).exists():parts.append(f'<img loading="lazy" alt="{feature} production panorama" src="../../../{e["output"]}">')
  native=base/'native'/f'feature-header-{feature}-{a}.png'
  if native.exists():parts.append(f'<small>Native title/control treatment</small><img loading="lazy" alt="{feature} native header" src="native/{native.name}">')
  parts.append('</figure>')
 parts.append('</div></section>')
(base/'index.html').write_text('\n'.join(parts)+'\n</html>\n')
print('Feature header gallery refreshed')
