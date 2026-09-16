#!/usr/bin/env python3
"""Freeze an exact prompt and input references BEFORE a built-in tool dispatch."""
import argparse, hashlib, json, shutil
from datetime import datetime, timezone
from pathlib import Path
from home_card_manifest_io import ROOT, MANIFEST, atomic_json, digest, manifest_lock

p = argparse.ArgumentParser()
p.add_argument('id')
p.add_argument('--revision-reason', required=True)
p.add_argument('--design-review-hypothesis', help='Explicit new design hypothesis after targeted revisions failed')
a = p.parse_args()
with manifest_lock():
    m = json.loads(MANIFEST.read_text())
    e = next(e for e in m['entries'] if e['id'] == a.id)
    if e['purpose']=='ui-reference' and e.get('specification_status') != 'ready':
        raise SystemExit('Specification is not ready; export and validate native element data first.')
    if e.get('inspection_status') == 'design-review' and not a.design_review_hypothesis:
        raise SystemExit('Entry needs design review; supply a new --design-review-hypothesis before another attempt.')
    references = [{**r, 'sha256': digest(ROOT / r['path'])} for r in e['references']]
    if references != e['references']:
        raise SystemExit('Input reference hashes changed; rebuild the specification first.')
    input_directory = ROOT / 'docs/design/home-cards/submissions/inputs'
    input_directory.mkdir(parents=True, exist_ok=True)
    for reference in references:
        snapshot = input_directory / (reference['sha256'] + Path(reference['path']).suffix)
        if not snapshot.exists(): shutil.copy2(ROOT / reference['path'], snapshot)
        if digest(snapshot) != reference['sha256']: raise SystemExit('Frozen input hash mismatch')
        reference['frozen_path'] = str(snapshot.relative_to(ROOT))
    prompt = e.get('next_prompt', e['prompt'])
    frozen = {k:e[k] for k in ('id', 'appearance', 'requested_canvas_pixels', 'card_rect_pixels', 'final_export_pixels')}
    frozen.update(submitted_prompt=prompt, references=references, specification_sha256=e.get('specification_sha256', hashlib.sha256(prompt.encode()).hexdigest()),
                  prepared_at=datetime.now(timezone.utc).isoformat(), revision_reason=a.revision_reason,
                  design_review_hypothesis=a.design_review_hypothesis,
                  design_revision=m['active_design_revision'], source_signatures=e.get('source_signatures', {}))
    signature = hashlib.sha256(json.dumps(frozen, sort_keys=True).encode()).hexdigest()
    path = ROOT / 'docs/design/home-cards/submissions' / (a.id + '-' + signature[:16] + '.json')
    atomic_json(path, frozen)
    e['active_submission'] = str(path.relative_to(ROOT))
    e['generation_status'] = 'prepared'
    atomic_json(MANIFEST, m)
    print(path)
