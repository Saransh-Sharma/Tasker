#!/usr/bin/env python3
"""Bind explicitly exported native specifications to their current source inputs."""
import hashlib, json
from pathlib import Path
from home_card_manifest_io import ROOT, atomic_json, digest
base=ROOT/'docs/design/home-cards/native-specifications'
# Run immediately after the explicit capture, never as part of ordinary tests.
sources=sorted((ROOT/'LifeBoard/DesignSystem/HomeCards').glob('*.swift'))
sources += [ROOT/'LifeBoard/DesignSystem/LifeBoardHomeCardBodies.swift',
            ROOT/'LifeBoard/DesignSystem/LifeBoardCardPrimitives.swift',
            ROOT/'LifeBoard/Foundation/Design/LifeBoardFoundationGallery.swift',
            ROOT/'Packages/LifeBoardTokens/Sources/LifeBoardTokens/SemanticTypographyTokens.swift',
            ROOT/'Packages/LifeBoardUI/Sources/LifeBoardUI/NumericRoll.swift']
source_hashes={str(p.relative_to(ROOT)):digest(p) for p in sources}
for path in base.glob('*.json'):
    e=json.loads(path.read_text())
    e['source_signatures']={'renderer':hashlib.sha256(json.dumps(source_hashes,sort_keys=True).encode()).hexdigest(),
       'files':source_hashes,'typography':digest(sources[-2]),
       'fixture':digest(ROOT/'LifeBoard/DesignSystem/HomeCards/HomeCardPreviewFixtures.swift'),
       'artwork':digest(ROOT/f'DesignAssets/Sources/HomeCards/{e["id"].split("-")[0]}-scene-{e["appearance"]}.png'),
       'capture':digest(path.with_suffix('.png'))}
    atomic_json(path,e)
print('Signed',len(list(base.glob('*.json'))),'native specifications.')
