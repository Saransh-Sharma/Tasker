#!/usr/bin/env python3
"""Reproducible prompt inventory. No network calls or generated-image substitutes."""
import argparse
import json
import re
import math
from home_card_manifest_io import atomic_json, manifest_lock, digest as file_digest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/design/home-cards'
SIZES = dict(compact=('Glance', 104), standard=('Compact', 178), wide=('Wide', 178), tall=('Story', 260), expanded=('Expanded', 340))
# Explicit synthetic display copy; never sourced from user records.
BRIEFS = {
'setupChecklist': ('Welcoming doorway', 'Choose the next setup step', '2 of 5 steps', 'Connect your calendar', 'Continue setup'),
'focusNow': ('Sunlit desk', 'Choose one next task', 'Sketch the first draft', 'A quiet 25-minute focus block', 'Open focus'),
'lifeSnapshot': ('Balanced landscape', 'See recorded life signals', 'Your day at a glance', 'Tasks, care, and reflection', 'View snapshot'),
'care': ('Botanical alcove', 'See the next care action', 'A little care', 'Water break', 'Open care'),
'tasks': ('Paper-and-pencil vignette', 'Act on today’s open tasks', 'Today’s Tasks', 'Sketch the first draft', 'View tasks'),
'routines': ('Garden stepping stones', 'Continue the next routine', 'Evening wind-down', 'Read for ten minutes', 'View routines'),
'scheduleCapacity': ('Light through architectural openings', 'Understand commitments and space', 'Room to breathe', 'One open afternoon block', 'View schedule'),
'quickCapture': ('Open notebook', 'Capture an idea', 'Make a little room', 'Capture what is on your mind', 'Capture'),
'compactTimeline': ('Soft horizon strip', 'Understand the shape of today', 'Your day, in order', '09:00 Design review', 'View day'),
'journal': ('Writing nook', 'Return to reflection', 'A moment for you', 'The walk home helped me slow down.', 'Open journal'),
'progressReflection': ('Winding landscape path', 'Review recorded progress', 'Small steps count', 'Look back at what you recorded', 'View reflection'),
'fasting': ('Ceramic still life', 'Check the actual fasting session', 'No active fast', 'Start when it works for you', 'Open fasting'),
'goals': ('Distant summit', 'Review the selected goal', '3 of 5 milestones', 'Finish the portfolio', 'View goal'),
'evaConversation': ('Violet-lit reading alcove', 'Return to a saved insight', 'Leave a little space', 'Keep one afternoon free for focused work.', 'Open insight'),
'bodyMetric': ('Neutral balanced forms', 'Read a recorded measurement', '72.4 kg', 'Recorded 15 September', 'View body metrics'),
'workout': ('Trail and equipment', 'Review a recorded workout', '30 min', 'Afternoon walk', 'View workout'),
'sleep': ('Moonlit window', 'Review a recorded sleep note', '7.5 hours', 'Recorded 15 September', 'View sleep'),
'movement': ('Walking path', 'Review recorded movement', '6,240 steps', 'Recorded 15 September', 'View movement'),
'lifeMoment': ('Celebratory still life', 'Remember a selected occasion', 'A day to remember', 'Family picnic · 22 September', 'View moment'),
'nutritionSummary': ('Kitchen tabletop', 'Review recorded nutrition', '2 meals logged', 'Today’s recorded meals', 'View nutrition'),
'recentMeal': ('Neutral dining vignette', 'Return to an actual meal record', 'Lunch', 'Vegetable soup · 12:30', 'View meal'),
'logMeal': ('Plate and sketchbook', 'Record a meal', 'What was on your plate?', 'Add a meal when you are ready', 'Log meal'),
}


def catalog():
    source = (ROOT / 'Packages/LifeBoardDomain/Sources/LifeBoardDomain/HomeDashboardContracts.swift').read_text()
    rows = re.findall(r'\.init\(kind: \.(\w+), title: "([^"]+)", category: \.\w+, supportedSizes: (allSizes|\[[^\]]+\])', source)
    return [(kind, title, list(SIZES) if sizes == 'allSizes' else re.findall(r'\.(\w+)', sizes)) for kind, title, sizes in rows]


def build():
    from home_card_prompt_content import content
    import hashlib
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / 'image-generation-manifest.json'
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    old = {e['id']: e for e in previous.get('entries', [])}
    measurements = json.loads((OUT/'layout-measurements.json').read_text())
    composition_path = OUT/'composition-measurements.json'
    compositions = json.loads(composition_path.read_text()) if composition_path.exists() else {}
    entries=[]
    for kind,title,sizes in catalog():
        motif,intent,value,detail,action=BRIEFS[kind]
        for preset in [*sizes,'scene']:
            for appearance in ('light','dark'):
                ident=f'{kind}-{preset}-{appearance}'; scene=preset=='scene'
                e=dict(old.get(ident,{}))
                measured=measurements.get(f'{kind}-{preset}-iphone',{})
                width,height=measured.get('width',353),measured.get('height',340)
                pixels=[1024,1024] if scene else [round(width*4),round(height*4)]
                palette={'surface':'#FBF3E2','ink':'#2B2118','secondary':'#6F6252','accent':'#F0CD87'} if appearance=='light' else {'surface':'#282A44','ink':'#F7F1E7','secondary':'#C9C3B8','accent':'#E5B96D'}
                sample={'text':'None','rows':[],'actions':[]} if scene else content(kind,title,preset,value,detail,action)
                rects=compositions.get(f'{kind}-{preset}-iphone',{'content':[0,0,width,height],'scene':[0,0,0,0]})
                padding=14 if preset=='compact' else 16
                output=f'DesignAssets/Sources/HomeCards/{ident}.png' if scene else f'docs/design/home-cards/references/{ident}.png'
                e.update(id=ident,kind=kind,title=title,preset=preset,appearance=appearance,purpose='production-scene' if scene else 'ui-reference',
                    product_intent=intent,logical_card_points=None if scene else [width,height],
                    dimensions_source='asset-specification' if scene else 'shared-content-renderer-measured; full-dashboard validation pending',
                    requested_canvas_pixels=pixels,final_export_pixels=pixels,card_rect_pixels=[0,0,*pixels],
                    content_padding_points=padding,sample=sample,palette=palette,motif=motif,output=output,format='PNG',alpha_required=scene,
                    crop_anchor=[0.75,0.5],generation_status=e.get('generation_status','pending'),inspection_status=e.get('inspection_status','pending'),
                    fixture={'date':'2026-09-15','locale':'en_US','time_zone':'UTC','daypart':'morning','dynamic_type':'large','care_enabled':True,'task_completion_enabled':True,'version':3})
                if scene:
                    e['logical_card_usages']={size:{device:measurements.get(f'{kind}-{size}-{device}') for device in ('iphone','ipad')} for size in sizes}
                    e['safe_zones_pixels']={'transparent_reading_field':[0,0,352,1024],'paint_bounds':[384,128,576,768],'edge_clearance':64}
                    layout='Canvas and final export: 1024 x 1024 pixels. No logical card silhouette: this is reusable artwork. Paint bounds x=384,y=128,width=576,height=768. Keep x=0..352 fully transparent. Minimum edge clearance 64 pixels. Genuine RGBA alpha with soft painterly edges; never a checkerboard or opaque paper background.'
                    exact='No text, numbers, letters, charts, rings, buttons, UI symbols or chrome. Subject conveys purpose only, never recorded data, completion or health status.'
                    e.setdefault('references',[])
                else:
                    e['ipad_adaptation']=measurements.get(f'{kind}-{preset}-ipad')
                    e['layout_points']=rects
                    e['safe_zones_points']={'native_content':rects['content'],'ambient_background':rects['scene'],'control_edge_clearance':padding}
                    e['ambient_opacity']=0.18 if preset=='compact' else 0.28 if appearance=='dark' else 0.24
                    e['geometry_refresh_required']=False
                    e['reading_mask']={'direction':'leading to trailing','alpha_stops':[[0,0.08],[0.35,0.20],[1,1]]}
                    actions=sample.get('actions',[])
                    e['control_region_points']=[padding,max(padding,rects['content'][3]-padding-44*max(1,len(actions))),max(0,rects['content'][2]-2*padding),44*max(1,len(actions))]
                    e['references']=[{'name':ident+' accepted scene','path':f'DesignAssets/Sources/HomeCards/{kind}-scene-{appearance}.png','role':'Image 1: scene subject, palette, texture and objects. Reuse the visible paint proportionally across the surface.'},{'name':ident+' measured native structure','path':f'docs/design/home-cards/implementation/{kind}-{preset}-iphone-{appearance}.png','role':'Image 2: exact outer aspect ratio, native content, copy, controls and ambient composition. This structural input is not a generated reference.'}]
                    for ref in e['references']: ref['sha256']=hashlib.sha256((ROOT/ref['path']).read_bytes()).hexdigest()
                    layout=(f'Logical card: {width} x {height} points. Requested canvas and final export: {pixels[0]} x {pixels[1]} pixels at 4 pixels/point. '
                        f'Card rectangle x=0,y=0,width={pixels[0]},height={pixels[1]}. Card corner radius 24 points. Content padding {padding} points. '
                        f'Content bounds in points x,y,width,height={rects["content"]}; illustration bounds={rects["scene"]}. '
                        f'Artwork is an ambient background across the complete card bounds. It never appends height or reserves a text column. Artwork opacity {e["ambient_opacity"]}, multiplied by a leading-to-trailing alpha mask with stops 0:0.08, 0.35:0.20, 1:1. Text and controls remain native, opaque, and foreground. '
                        f'Composition: {dict(compact="one summary with one whole-card opening action",standard="primary information and controls using the complete width",wide="native reading and actions across full width",tall="native content and existing context across full width",expanded="existing evidence and rows with grouping across full width")[preset]}. '
                        f'iPad adaptation at 834 x 1194 points uses measured card bounds {e["ipad_adaptation"]}; reflow native content with the same hierarchy, never stretch this phone reference.')
                    exact='Exact synthetic visible content and native controls: '+json.dumps(sample,ensure_ascii=False)+'. Do not print JSON keys or metadata; only the specified visible copy. No additional rows or controls.'
                e['typography']={'family':'San Francisco','title':{'points':17 if kind in ('journal','tasks','care','routines','scheduleCapacity','progressReflection','compactTimeline') and preset!='compact' else 13,'weight':'semibold','role':'headline or caption'},'value':{'points':28 if preset in ('wide','tall','expanded') else 20,'weight':'semibold','role':'metric or title3'},'body':{'points':17,'weight':'regular','role':'body'},'support':{'points':13,'weight':'regular','role':'caption'},'action':{'points':15,'weight':'semibold','role':'subheadline'}}
                references='Reference images: '+json.dumps(e['references'],ensure_ascii=False)
                prompt='\n'.join([f'Use case: {"illustration-story" if scene else "ui-mockup"}. Stable ID: {ident}.',
                    f'Create one {appearance} {e["purpose"]} for LifeBoard’s "{title}". User question answered: {intent}.',layout,exact,
                    f'Palette: surface {palette["surface"]}, ink {palette["ink"]}, secondary {palette["secondary"]}, warm accent {palette["accent"]}. Assistant violet #6842FF is reserved for Saved Eva Insight.',
                    f'Illustration: {motif}. Editorial gouache, soft brush texture, restrained depth and natural edge fade. '+('Warm diffuse lighting.' if appearance=='light' else 'Indigo ambient lighting with warm parchment highlights.'),
                    ('No typography in production artwork.' if scene else 'Typography: '+json.dumps(e['typography'])+'. Left-aligned reading order. Opaque quiet surface behind every glyph; native controls at least 44 x 44 points.'),
                    references,('' if scene else 'CRITICAL: Preserve the exact full outer aspect ratio, content hierarchy, controls, line wrapping, and ambient artwork placement of Image 2. Do not substitute a conventional aspect ratio. Image 1 supplies the original illustration. Do not add a separate artwork panel, footer, margin, caption or corner vignette.'),'State: deterministic synthetic fixture, never user data. No health conclusions, invented historical charts, completion claims, new assistant identity, logos, watermark, device frame, outside caption or extra panel.',
                    'Preserve aspect ratio; never stretch. Record actual generated dimensions. Export by deterministic proportional resampling; regenerate if required cropping removes essential content.',
                    f'Output: {output}; PNG; alpha required: {scene}.',
                    'Acceptance: correct subject and copy, visible complete controls, ambient scene behind native reading field, consistent style, exact final dimensions, alpha verified, no essential cropping.'
                ])
                if e.get('prompt') and e['prompt']!=prompt:
                    history=e.setdefault('specification_history',[])
                    digest=hashlib.sha256(e['prompt'].encode()).hexdigest()
                    if not any(h['sha256']==digest for h in history):history.append({'sha256':digest,'prompt':e['prompt'],'note':'Previous specification; not proof of exact historical submission.'})
                if not scene:
                    native_path = OUT/'native-specifications'/f'{ident}.json'
                    e['specification_status'] = 'awaiting-native-elements'
                    e['native_evidence_status'] = e.get('native_evidence_status', 'not-directly-sampled')
                    e.pop('control_region_points', None)
                    if native_path.exists():
                        native = json.loads(native_path.read_text())
                        width, height = native['logical_card_points']
                        pixels = [round(width*4), round(height*4)]
                        e['logical_card_points'] = [width, height]
                        e['final_export_pixels'] = pixels
                        elements = native['elements']
                        e['native_elements'] = elements
                        e['sample'] = {'visible_elements': elements, 'state': 'deterministic synthetic fixture'}
                        e['typography'] = {item['id']: item['typography'] for item in elements if item.get('typography')}
                        e['safe_zones_points'] = {'reading_regions': [item['rect'] for item in elements if item.get('copy')],
                                                  'controls': [item['rect'] for item in elements if item['role']=='control'],
                                                  'ambient_background': [0,0,width,height], 'edge_clearance': padding}
                        structural = OUT/'native-specifications'/f'{ident}.png'
                        e['references'][1].update(path=str(structural.relative_to(ROOT)), sha256=file_digest(structural))
                        e['native_specification'] = str(native_path.relative_to(ROOT))
                        e['native_specification_sha256'] = file_digest(native_path)
                        e['fixture'] = {k:v for k,v in native.items() if k not in ('elements', 'logical_card_points', 'source_signatures')}
                        e['source_signatures'] = native.get('source_signatures', {})
                        e['specification_status'] = 'ready' if e['source_signatures'] else 'awaiting-source-signatures'
                    if e.get('structural_canvas_reference'):
                        # An explicit native canvas teaches narrow-card placement without
                        # altering the authoritative card-local capture or its geometry.
                        structural_canvas = ROOT / e['structural_canvas_reference']
                        e['references'][1].update(path=str(structural_canvas.relative_to(ROOT)),
                            sha256=file_digest(structural_canvas))
                    # The requested canvas may contain intentional centered padding.
                    canvas = [math.ceil(pixels[0]/16)*16, math.ceil(pixels[1]/16)*16]
                    if canvas[0] > 3*canvas[1]: canvas[1] = math.ceil(canvas[0]/3/16)*16
                    if canvas[1] > 3*canvas[0]: canvas[0] = math.ceil(canvas[1]/3/16)*16
                    canvas = e.get('canvas_override', canvas)
                    e['requested_canvas_pixels'] = canvas
                    e['card_rect_pixels'] = e.get('card_rect_override', [(canvas[0]-pixels[0])//2, (canvas[1]-pixels[1])//2, *pixels])
                    if e['specification_status'] == 'ready':
                        prompt = '\n'.join([
                            f'Use case: ui-mockup. Stable ID {ident}. Create one {appearance} LifeBoard {title} Home card reference.',
                            f'Image 1 is accepted scene artwork; Image 2 is the authoritative native structural fixture. Preserve its exact copy, symbols, line wrapping, foreground, controls, and relative geometry.',
                            f'Logical bounds {width} x {height} points. Final export {pixels[0]} x {pixels[1]} pixels at 4 pixels per point. Requested generation canvas {canvas[0]} x {canvas[1]} pixels. Exact card placement x,y,width,height={e["card_rect_pixels"]}. Only the specified canvas padding is allowed. No extra internal or external margin, frame or drop-shadow canvas.',
                            f'Native elements in logical points (rectangles x,y,width,height), with exact visible text and resolved San Francisco typography: {json.dumps(e["native_elements"], ensure_ascii=False)}. Empty copy means a symbol-only control or grouping, never print the IDs, roles, or JSON metadata.',
                            f'Artwork fills the existing card background [0,0,{width},{height}] beneath every native layer. Proportional fill clipped to 24-point rounded bounds. Opacity {e["ambient_opacity"]} multiplied by leading-to-trailing mask 0:0.08, 0.35:0.20, 1:1. Artwork should be as faint as Image 2. No separate artwork row, reserved text column, footer, or increased card height.',
                            f'Palette {json.dumps(palette)}. Subject {motif}; preserve the accepted scene objects and painterly medium. Opaque UI reference, no alpha required. Appearance is independent of morning daypart.',
                            f'Reading and control regions: {json.dumps(e["safe_zones_points"])}. Preserve exact native control sizes; retain opaque foreground text. Do not add buttons, rows, data, logos, watermark, device frame, completion or health claims.',
                            f'Fixed fixture {json.dumps(e["fixture"])}. References: {json.dumps(e["references"])}.',
                            f'Output PNG: {output}. Preserve aspect ratio; never stretch. Record actual dimensions and explicit export transform; reject essential clipping and unintended aspect correction above 4%.',
                            'Acceptance: exact copy and rows/actions, recognizable but quiet ambient art, readable native foreground, consistent appearance, correct dimensions, no extra margins or essential clipping.'
                        ])
                    else:
                        prompt = 'SPECIFICATION NOT READY: native element export required before dispatch.\n' + prompt
                    if e.get('native_first'):
                        e['references'].reverse()
                        for ref in e['references']: ref['role'] = ref['role'].replace('Image 1','TEMP').replace('Image 2','Image 1').replace('TEMP','Image 2')
                        prompt = prompt.replace('Image 1','TEMP').replace('Image 2','Image 1').replace('TEMP','Image 2')
                    if e.get('prompt_prefix'): prompt = e['prompt_prefix'] + '\n' + prompt
                    if e.get('prompt_appendix'): prompt += '\n' + e['prompt_appendix']
                    e['specification_sha256'] = hashlib.sha256(prompt.encode()).hexdigest()
                    if e.get('generated_specification_sha256') != e['specification_sha256']:
                        e['current_output_status'] = 'superseded' if e.get('source_output') else 'missing'
                    else:
                        e['current_output_status'] = e['inspection_status']
                e['prompt']=prompt
                e.pop('next_prompt',None)
                entries.append(e)
    assert len(entries)==228 and len({e['id'] for e in entries})==228
    previous.update(version=3,entries=entries)
    previous['measurement_contract']={'renderer':'Shared native content with isolated synthetic fixtures','viewport_points':{'iphone':[393,852],'ipad':[834,1194]},'margins':20,'gap':12,'safe_areas':'Card-local zero; full device safe areas still require live dashboard capture','height':'Intrinsic with preset minimum','paired_narrow_cards':True,'solitary_widening':'Validated separately against DashboardFramePlanner'}
    atomic_json(manifest_path, previous)
    (OUT/'IMAGE_GENERATION_PROMPTS.md').write_text('# Home card image-generation prompts\n\n228 stable specifications: 184 UI references and 44 reusable production scenes. Measurements identify their renderer; full-dashboard verification is tracked separately. Exact historical submissions are retained under generation_attempts when available.\n\n'+'\n\n'.join(f'## {e["id"]}\n\n```text\n{e["prompt"]}\n```' for e in entries)+'\n')
    print('Updated 228 prompt specifications without discarding generation provenance.')

if __name__ == '__main__':
    with manifest_lock():
        build()
