#!/usr/bin/env python3
"""Rebuild the owned runtime catalog from accepted, complete appearance pairs."""
import hashlib
import json
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path
from home_card_manifest_io import atomic_json, manifest_lock
ROOT = Path(__file__).resolve().parents[1]
manifest_path = ROOT / 'docs/design/home-cards/image-generation-manifest.json'
def package():
    m = json.loads(manifest_path.read_text())
    scenes = [e for e in m['entries'] if e['purpose'] == 'production-scene']
    accepted = {e['id']: e for e in scenes if e.get('inspection_status') == 'accepted' and (ROOT / e['output']).is_file()}
    paired = sorted({e['kind'] for e in scenes if all(f'{e["kind"]}-scene-{a}' in accepted for a in ('light', 'dark'))})
    assets = ROOT / 'LifeBoard/Assets.xcassets/HomeCardScenes'
    info = {'author': 'xcode', 'version': 1}
    def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='lifeboard-scenes-') as temp:
        temp = Path(temp)
        normalizer = temp / 'normalizer'
        subprocess.run(['swiftc', str(ROOT / 'scripts/normalize_home_card_scene.swift'), '-o', str(normalizer)], check=True)
        staged = temp / 'HomeCardScenes'
        staged.mkdir()
        (staged / 'Contents.json').write_text(json.dumps({'info': info}, indent=2)+'\n')
        for e in scenes:
            path = ROOT / e['output']
            e['runtime_assets'] = []
            if not path.exists(): continue
            source = path.with_suffix('.source.png')
            if not source.exists(): shutil.copy2(path, source)
            e['source_sha256'] = digest(source)
            e['export_sha256'] = digest(path)
            e['source_output'] = str(source.relative_to(ROOT))
            if e['kind'] not in paired: continue
            target = staged / f'HomeCardScene_{e["kind"]}.imageset'
            target.mkdir(exist_ok=True)
            content_path = target / 'Contents.json'
            content = json.loads(content_path.read_text()) if content_path.exists() else {'images': [], 'info': info}
            for scale in (1, 2, 3):
                name = f'{e["appearance"]}@{scale}x.png'
                output = target / name
                subprocess.run([str(normalizer), str(path), str(output), str(256*scale)], check=True)
                dimensions = list(struct.unpack('>II', output.read_bytes()[16:24]))
                record = {'filename': name, 'idiom': 'universal', 'scale': f'{scale}x'}
                if e['appearance'] == 'dark': record['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
                content['images'].append(record)
                e['runtime_assets'].append({'path': str((assets / target.name / name).relative_to(ROOT)),
                    'pixels': dimensions, 'sha256': digest(output), 'scale': scale,
                    'crop_policy': 'visible alpha >16 bounds plus 24 source pixels; aspect preserved'})
            content_path.write_text(json.dumps(content, indent=2)+'\n')
        # Replace only this generator-owned directory, after every export succeeds.
        if assets.exists(): shutil.rmtree(assets)
        shutil.copytree(staged, assets)
    atomic_json(manifest_path, m)
    print(f'Packaged {len(paired)*2}/44 variants in {len(paired)} complete appearance pairs.')

if __name__ == "__main__":
    with manifest_lock():
        package()
