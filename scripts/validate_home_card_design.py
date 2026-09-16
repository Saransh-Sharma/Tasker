#!/usr/bin/env python3
"""Read-only integrity and completion checks for the Home card design catalog."""
import argparse, hashlib, json, struct, sys
from pathlib import Path
from home_card_design_catalog import catalog
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--complete',action='store_true');args=p.parse_args()
m=json.loads((ROOT/'docs/design/home-cards/image-generation-manifest.json').read_text());entries=m['entries'];errors=[];pending=[]
expected={f'{k}-{s}-{a}' for k,_,sizes in catalog() for s in sizes for a in ('light','dark')}
expected|={f'{k}-scene-{a}' for k,_,_ in catalog() for a in ('light','dark')}
ids=[e['id'] for e in entries]
if len(ids)!=228 or len(set(ids))!=228 or set(ids)!=expected: errors.append('IDs do not match the 228 supported specifications')
measure_path=ROOT/'docs/design/home-cards/layout-measurements.json';measurements=json.loads(measure_path.read_text())
for e in entries:
 ident=e['id'];path=ROOT/e['output']
 for field in ('prompt','requested_canvas_pixels','final_export_pixels','card_rect_pixels','palette','sample','references','dimensions_source'):
  if field not in e: errors.append(f'{ident}: missing {field}')
 for field in ('requested_canvas_pixels','final_export_pixels'):
  if not all(isinstance(x,int) and x>0 for x in e.get(field,[])): errors.append(f'{ident}: invalid {field}')
 if any(t in e['prompt'].lower() for t in ('same as above','use appropriate dimensions','adapt for dark mode')): errors.append(f'{ident}: unresolved prompt placeholder')
 if e['purpose']=='ui-reference':
  dimensions=measurements.get(f'{e["kind"]}-{e["preset"]}-iphone',{})
  if e.get('native_specification'):
   native=json.loads((ROOT/e['native_specification']).read_text()); dimensions=dict(zip(('width','height'),native['logical_card_points']))
  if e['logical_card_points']!=[dimensions.get('width'),dimensions.get('height')]: errors.append(f'{ident}: stale point dimensions')
 if e['generation_status']=='generated' and e.get('current_output_status') not in ('superseded','rejected','design-review'):
  if not path.is_file(): errors.append(f'{ident}: generated output missing')
  else:
   data=path.read_bytes();size=list(struct.unpack('>II',data[16:24]))
   if size!=e['final_export_pixels']: errors.append(f'{ident}: export size {size} differs from specification')
   if e['alpha_required'] and data[25] not in (4,6): errors.append(f'{ident}: no PNG alpha channel')
 else: pending.append(ident+': generation')
 if e['inspection_status']!='accepted': pending.append(ident+': inspection')
 if e['purpose']=='ui-reference':
  if e.get('specification_status')!='ready': pending.append(ident+': native specification')
  if e.get('current_output_status')!='accepted': pending.append(ident+': current reference acceptance')
  if e.get('specification_status')=='ready':
   if hashlib.sha256(e['prompt'].encode()).hexdigest()!=e.get('specification_sha256'): errors.append(ident+': prompt hash stale')
   for region in e.get('native_elements',[]):
    rect=region.get('rect',[])
    if len(rect)!=4 or not all(isinstance(x,(int,float)) for x in rect) or min(rect[2:])<=0: errors.append(ident+': invalid native region')
   canvas=e['requested_canvas_pixels'];rect=e['card_rect_pixels']
   if any(x%16 for x in canvas) or max(canvas)/min(canvas)>3: errors.append(ident+': invalid generation canvas')
   if min(rect)<0 or rect[0]+rect[2]>canvas[0] or rect[1]+rect[3]>canvas[1]: errors.append(ident+': invalid card placement')
  if e.get('current_output_status')=='accepted':
   if e.get('generated_specification_sha256')!=e.get('specification_sha256'): errors.append(ident+': accepted reference is stale')
   transform=e.get('export_transform',{})
   if transform.get('final_export_pixels')!=e['final_export_pixels'] or transform.get('unintended_crop_fraction',1)>0.04: errors.append(ident+': invalid accepted export transform')
 for ref in e.get('references',[]):
  if isinstance(ref,dict) and 'path' in ref:
   reference=ROOT/ref['path']
   if not reference.is_file(): errors.append(f'{ident}: reference missing: {ref["path"]}')
   elif e.get('specification_status')=='ready' and ref.get('sha256')!=hashlib.sha256(reference.read_bytes()).hexdigest(): errors.append(f'{ident}: input reference hash changed: {ref["path"]}')
 for asset in e.get('runtime_assets',[]):
  file=ROOT/asset['path']
  if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest()!=asset['sha256']: errors.append(f'{ident}: missing or stale runtime asset')
 if args.complete and e['purpose']=='production-scene' and len(e.get('runtime_assets',[]))!=3: errors.append(f'{ident}: runtime scales incomplete')
 if args.complete and e['purpose']=='ui-reference' and not e.get('verification',{}).get('evidence_level'): pending.append(ident+': native evidence classification')
print(json.dumps({'entries':len(entries),'generated':sum(e['generation_status']=='generated' for e in entries),
 'accepted_ui_references':sum(e.get('current_output_status')=='accepted' and e.get('generated_specification_sha256')==e.get('specification_sha256') and e['purpose']=='ui-reference' for e in entries),
 'accepted_production_scenes':sum(e['inspection_status']=='accepted' and e['purpose']=='production-scene' for e in entries),'errors':errors,'pending_count':len(pending),
 'pending':pending if args.complete else pending[:12]},indent=2))
sys.exit(bool(errors or (args.complete and pending)))
