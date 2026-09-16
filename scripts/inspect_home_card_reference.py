#!/usr/bin/env python3
"""Record a human/agent visual review without conflating native verification."""
import argparse, json
from datetime import datetime, timezone
from home_card_manifest_io import ROOT, MANIFEST, atomic_json, digest, manifest_lock
p=argparse.ArgumentParser();p.add_argument('id');p.add_argument('status',choices=['accepted','rejected','design-review']);p.add_argument('--notes',required=True)
a=p.parse_args()
with manifest_lock():
 m=json.loads(MANIFEST.read_text());e=next(e for e in m['entries'] if e['id']==a.id)
 if a.status=='accepted':
  if e.get('specification_status')!='ready' or e.get('generated_specification_sha256')!=e.get('specification_sha256'): raise SystemExit('Cannot accept stale specification')
  if not (ROOT/e['output']).is_file() or not e.get('export_transform'): raise SystemExit('Current transformed export required')
  if any(digest(ROOT/r['path'])!=r['sha256'] for r in e['references']): raise SystemExit('Stale input reference')
 inspection={'status':a.status,'notes':a.notes,'reviewed_at':datetime.now(timezone.utc).isoformat(),
             'source_sha256':e['source_sha256'],'specification_sha256':e['generated_specification_sha256'],
             'export_sha256':digest(ROOT/e['output']) if (ROOT/e['output']).exists() else None}
 e.setdefault('inspections',[]).append(inspection)
 e.update(inspection_status=a.status,current_output_status=a.status,revision_notes=a.notes)
 atomic_json(MANIFEST,m)
 print(a.id,a.status)
