#!/usr/bin/env python3
"""Read-only manifest-to-gallery export with explicit evidence classifications."""
import html, json, os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; base=ROOT/'docs/design/home-cards'
m=json.loads((base/'image-generation-manifest.json').read_text())
escape=html.escape

def figure(path,label):
 p=ROOT/path
 if not p.is_file():return '<div class="missing">'+escape(label)+' — unavailable</div>'
 src=escape(os.path.relpath(p,base),quote=True)
 return f'<figure><a href="{src}"><img loading="lazy" src="{src}" alt="{escape(label,quote=True)}"></a><figcaption>{escape(label)}</figcaption></figure>'

parts=['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>LifeBoard artwork evidence</title>
<style>body{background:#fff7d8;color:#2b2118;font:16px system-ui;margin:24px;line-height:1.5}nav{display:flex;gap:12px;flex-wrap:wrap;padding:16px 0;position:sticky;top:0;background:#fff7d8;z-index:1}label{display:grid;font-size:13px}select{font:inherit;max-width:200px;padding:8px}section{padding:24px 0;border-top:1px solid #a89572}.grid{display:flex;gap:20px;flex-wrap:wrap}figure{margin:0;max-width:353px}img{max-width:100%;max-height:420px;object-fit:contain}figcaption{font-size:13px;margin:8px 0}.missing{border:1px dashed #a89572;padding:24px;max-width:250px}a{color:inherit}[hidden]{display:none!important}details{margin-top:12px}</style>
<h1>Home artwork and native evidence</h1><p>Generated concepts, production-adapter captures, previews, and structural samples have separate labels. Matching adapter heights do not establish interaction correctness or full-dashboard placement. Unselected presets are not directly verified.</p>
<p><a href="IMPLEMENTED_DESIGN_SYSTEM.md">Design guide</a> · <a href="VALIDATION.md">Validation</a> · <a href="IMAGE_GENERATION_PROMPTS.md">Prompts</a> · <a href="../ambient-surfaces/index.html">Feature header components</a> · <a href="COMPLETION_TODO.md">Release gates and actual-route work</a></p><nav>''']
fields={'kind':sorted({e['kind'] for e in m['entries']}),'preset': ['compact','standard','wide','tall','expanded'],
        'appearance':['light','dark'],'status':['accepted','pending','rejected','design-review','superseded','missing'],
        'revision':sorted({e.get('generated_design_revision','none') for e in m['entries'] if e['purpose']=='ui-reference'})}
for field,values in fields.items():
 parts.append(f'<label>{field.title()}<select id="{field}"><option value="">All</option>'+''.join(f'<option>{escape(v)}</option>' for v in values)+'</select></label>')
parts.append('</nav><p id="count"></p>')
for e in m['entries']:
 if e['purpose']!='ui-reference':continue
 status=e.get('current_output_status','missing');rev=e.get('generated_design_revision','none')
 attrs=' '.join(f'data-{k}="{escape(str(v),quote=True)}"' for k,v in dict(kind=e['kind'],preset=e['preset'],appearance=e['appearance'],status=status,revision=rev).items())
 parts.append(f'<section class="entry" {attrs}><h2>{escape(e["title"])} · {escape(e["preset"])} · {e["appearance"]}</h2><p>Specification: {escape(e.get("specification_status","not audited"))} · Current reference: {escape(status)} · Revision: {escape(rev)}</p><div class="grid">')
 parts.append(figure(e['output'],f'Generated concept · {status} · {rev}'))
 sampled=False
 for device in ('iphone','ipad'):
  name=f'{e["kind"]}-{e["preset"]}-{device}-{e["appearance"]}.png'
  if (base/'live'/name).exists():
   sampled=True
   parts.append(figure(str((base/'live'/name).relative_to(ROOT)),f'Production card adapter, isolated fixture · {device} · default text'))
   parts.append(figure(str((base/'preview'/name).relative_to(ROOT)),f'Inert native preview · {device} · default text'))
 if not sampled:
  native=base/'native-specifications'/f'{e["id"]}.png'
  if not native.exists():native=base/'implementation'/f'{e["kind"]}-{e["preset"]}-iphone-{e["appearance"]}.png'
  parts.append(figure(str(native.relative_to(ROOT)),'Structural sample only · no direct native acceptance'))
 parts.append('</div><p>'+escape(e.get('revision_notes','Inspection remains pending.'))+'</p>')
 revisions=e.get('revisions',[])
 if revisions:
  parts.append('<details><summary>Superseded generation history</summary><div class="grid">')
  for r in revisions:
   if r.get('source'):parts.append(figure(r['source'],'Historical source · '+str(r.get('inspection_status','unclassified'))))
  parts.append('</div></details>')
 parts.append('</section>')
parts.append('''<script>
const fields=['kind','preset','appearance','status','revision'];
function filter(){let count=0;document.querySelectorAll('.entry').forEach(e=>{e.hidden=fields.some(k=>document.getElementById(k).value&&e.dataset[k]!==document.getElementById(k).value);if(!e.hidden)count++});document.getElementById('count').textContent=count+' reference entries shown';}
fields.forEach(k=>document.getElementById(k).addEventListener('change',filter));filter();
</script></html>''')
(base/'index.html').write_text('\n'.join(parts))
print('Gallery written; manifest acceptance unchanged.')
