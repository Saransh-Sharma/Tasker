#!/usr/bin/env python3
"""Persist a frozen built-in generation result, retaining every replaced original."""
import argparse, json, shutil, struct, subprocess
from datetime import datetime, timezone
from pathlib import Path
from home_card_manifest_io import ROOT, MANIFEST, atomic_json, digest, manifest_lock, swift_helper

p = argparse.ArgumentParser()
p.add_argument('id'); p.add_argument('source', nargs='?')
p.add_argument('--submission', required=True)
p.add_argument('--failure')
a = p.parse_args()
submission_path = Path(a.submission)
submission = json.loads(submission_path.read_text())
if submission['id'] != a.id: raise SystemExit('Submission ID mismatch')
with manifest_lock():
    m = json.loads(MANIFEST.read_text())
    e = next(e for e in m['entries'] if e['id'] == a.id)
    attempt = {**submission, 'recorded_at':datetime.now(timezone.utc).isoformat(),
               'submission':str(submission_path.resolve().relative_to(ROOT))}
    is_current_submission = e.get('active_submission') == attempt['submission']
    if a.failure:
        attempt.update(status='failed', error=a.failure)
        e.setdefault('generation_attempts', []).append(attempt)
        if is_current_submission: e['generation_status'] = 'failed'
        atomic_json(MANIFEST, m)
        print(a.id, 'failure recorded; prior outputs preserved')
        raise SystemExit(0)
    if not a.source: raise SystemExit('A source or --failure is required')
    source = Path(a.source)
    if source.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n': raise SystemExit('Expected PNG')
    if not is_current_submission:
        # A slow older request must never replace a newer accepted result.
        archive = ROOT / 'docs/design/home-cards/references/revisions'
        archive.mkdir(parents=True, exist_ok=True)
        saved = archive / (a.id + '-late-' + digest(source)[:12] + '.source.png')
        shutil.copy2(source, saved)
        attempt.update(status='late-generated', tool_output=str(source),
            source_output=str(saved.relative_to(ROOT)), source_sha256=digest(source),
            actual_pixels=list(struct.unpack('>II', source.read_bytes()[16:24])),
            export_status='not-current-submission')
        e.setdefault('generation_attempts', []).append(attempt)
        atomic_json(MANIFEST, m)
        print(a.id, 'late original archived; current result unchanged')
        raise SystemExit(0)
    target = ROOT / e['output']; original = target.with_suffix('.source.png')
    target.parent.mkdir(parents=True, exist_ok=True)
    if original.exists():
        archive = target.parent / 'revisions'; archive.mkdir(exist_ok=True)
        old = archive / (a.id + '-' + digest(original)[:12] + '.source.png')
        shutil.copy2(original, old)
        old_export = old.with_name(old.name.replace('.source.png', '.png'))
        if target.exists(): shutil.copy2(target, old_export)
        e.setdefault('revisions', []).append({'source':str(old.relative_to(ROOT)),
            'export':str(old_export.relative_to(ROOT)) if old_export.exists() else None,
            'inspection_status':e.get('inspection_status'), 'notes':e.get('revision_notes'),
            'design_revision':e.get('generated_design_revision'), 'status':'superseded'})
    shutil.copy2(source, original)
    transform = target.with_suffix('.transform.json')
    if e['purpose'] == 'production-scene':
        result = subprocess.run([swift_helper('normalize_home_card_scene'), str(original), str(target)], capture_output=True, text=True)
    else:
        result = subprocess.run([swift_helper('export_home_card_reference'), str(original), str(target), str(submission_path), str(transform)], capture_output=True, text=True)
    ok = result.returncode == 0
    if not ok:
        # A failed export must not leave a stale file looking like a new result.
        target.unlink(missing_ok=True); transform.unlink(missing_ok=True)
    e.update(generation_status='generated', inspection_status='pending' if ok else 'rejected',
             current_output_status='pending' if ok else 'rejected',
             source_output=str(original.relative_to(ROOT)), actual_pixels=list(struct.unpack('>II', source.read_bytes()[16:24])),
             source_sha256=digest(source), generated_design_revision=submission['design_revision'],
             generated_specification_sha256=submission['specification_sha256'])
    e.pop('revision_notes', None)
    e.pop('export_transform', None)
    if not ok: e['revision_notes'] = result.stderr.strip()
    elif transform.exists(): e['export_transform'] = json.loads(transform.read_text())
    attempt.update(status='generated', tool_output=str(source), source_sha256=digest(source),
                   export_status='exported' if ok else 'rejected', export_error=None if ok else result.stderr.strip())
    e.setdefault('generation_attempts', []).append(attempt)
    atomic_json(MANIFEST, m)
    print(a.id, 'saved for inspection' if ok else 'original saved; export rejected')
