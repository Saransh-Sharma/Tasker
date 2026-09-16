#!/usr/bin/env python3
"""Preserve generated sources, export panoramas, and rebuild accepted runtime pairs."""
import hashlib,json,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'docs/design/ambient-surfaces/manifest.json'
m=json.loads(p.read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='lifeboard-headers-') as tmp:
 tmp=Path(tmp);exporter=tmp/'export'
 subprocess.run(['swiftc',str(ROOT/'scripts/export_ambient_surface.swift'),'-o',str(exporter)],check=True)
 staged=tmp/'AmbientSurfaces';staged.mkdir();info={'author':'xcode','version':1}
 (staged/'Contents.json').write_text(json.dumps({'info':info},indent=2)+'\n')
 for e in m['entries']:
  source=ROOT/e['source_output'];e['runtime_assets']=[]
  if not source.is_file(): continue
  e['generation_status']='generated';e['source_sha256']=sha(source)
  e.setdefault('submitted_prompt',e['prompt'])
  audit=json.loads(subprocess.check_output([str(exporter),str(source),str(ROOT/e['output']),'1536','512'],text=True))
  e['actual_pixels']=audit['source_pixels'];e['audit']=audit;e['export_sha256']=sha(ROOT/e['output'])
 paired={e['asset_name'] for e in m['entries'] if all(any(x['asset_name']==e['asset_name'] and x['appearance']==a and x['inspection_status']=='accepted' and (ROOT/x['output']).exists() for x in m['entries']) for a in ('light','dark'))}
 for e in m['entries']:
  if e['asset_name'] not in paired: continue
  folder=staged/(e['asset_name']+'.imageset');folder.mkdir(exist_ok=True)
  content=folder/'Contents.json';data=json.loads(content.read_text()) if content.exists() else {'images':[],'info':info}
  for scale in (1,2,3):
   filename=f'{e["appearance"]}@{scale}x.png';target=folder/filename
   audit=json.loads(subprocess.check_output([str(exporter),str(ROOT/e['output']),str(target),str(512*scale),str(171*scale)],text=True))
   record={'filename':filename,'idiom':'universal','scale':f'{scale}x'}
   if e['appearance']=='dark':record['appearances']=[{'appearance':'luminosity','value':'dark'}]
   data['images'].append(record)
   e['runtime_assets'].append({'path':str(Path('LifeBoard/Assets.xcassets/AmbientSurfaces')/folder.name/filename),'pixels':audit['export_pixels'],'sha256':sha(target)})
  content.write_text(json.dumps(data,indent=2)+'\n')
 target=ROOT/'LifeBoard/Assets.xcassets/AmbientSurfaces'
 if target.exists():shutil.rmtree(target)
 shutil.copytree(staged,target)
p.write_text(json.dumps(m,indent=2)+'\n')
print(f'{sum(e["generation_status"]=="generated" for e in m["entries"])}/34 sources; {len(paired)} accepted runtime pairs')
