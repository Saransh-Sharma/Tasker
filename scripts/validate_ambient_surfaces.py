#!/usr/bin/env python3
"""Read-only verification of the feature header production catalog."""
import hashlib,json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];m=json.loads((ROOT/'docs/design/ambient-surfaces/manifest.json').read_text());errors=[]
entries=m['entries'];ids=[e['id'] for e in entries]
if len(ids)!=34 or len(set(ids))!=34:errors.append('Expected 34 unique appearance entries')
for e in entries:
 ident=e['id']
 if e['generation_status']!='generated' or e['inspection_status']!='accepted':errors.append(ident+': not accepted')
 if not e.get('submitted_prompt') or not e.get('tool_output'):errors.append(ident+': missing provenance')
 for field,hashfield,size in [('source_output','source_sha256',e.get('actual_pixels')),('output','export_sha256',[1536,512])]:
  p=ROOT/e[field]
  if not p.exists():errors.append(ident+': missing '+field);continue
  data=p.read_bytes()
  if hashlib.sha256(data).hexdigest()!=e.get(hashfield):errors.append(ident+': stale '+field)
  if list(struct.unpack('>II',data[16:24]))!=size:errors.append(ident+': wrong dimensions '+field)
 if not 0<e.get('audit',{}).get('transparent_fraction',0)<1:errors.append(ident+': missing genuine transparency audit')
 assets=e.get('runtime_assets',[])
 if len(assets)!=3:errors.append(ident+': expected three scale files')
 for asset in assets:
  p=ROOT/asset['path']
  if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=asset['sha256']:errors.append(ident+': stale runtime asset')
  elif list(struct.unpack('>II',p.read_bytes()[16:24]))!=asset['pixels']:errors.append(ident+': wrong runtime dimensions')
print(json.dumps({'entries':len(entries),'accepted':sum(e['inspection_status']=='accepted' for e in entries),'runtime_files':sum(len(e.get('runtime_assets',[])) for e in entries),'errors':errors},indent=2))
sys.exit(bool(errors))
