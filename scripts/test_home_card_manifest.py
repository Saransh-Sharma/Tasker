#!/usr/bin/env python3
"""Acceptance/provenance regressions; synthetic inputs never enter the catalog."""
import contextlib, hashlib, io, json, runpy, struct, sys, tempfile, types, unittest
from pathlib import Path
from unittest.mock import patch
SCRIPT=Path(__file__).with_name('record_home_card_generation.py')

def png(tag):
    return b'\x89PNG\r\n\x1a\n'+b'\0'*8+struct.pack('>II',2,2)+tag

class GenerationRecordingTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve(); self.manifest=self.root/'manifest.json'
        self.original=self.root/'reference.source.png';self.original.write_bytes(png(b'old'))
        (self.root/'reference.png').write_bytes(png(b'old-export'))
        self.source=self.root/'incoming.png';self.source.write_bytes(png(b'new'))
        self.entry={'id':'card-wide-light','purpose':'ui-reference','output':'reference.png',
            'generation_status':'generated','inspection_status':'accepted','current_output_status':'accepted',
            'generated_design_revision':'old','generated_specification_sha256':'old-spec','active_submission':'new.json'}
        self.manifest.write_text(json.dumps({'entries':[self.entry]}))
        for name in ('old.json','new.json'):
            (self.root/name).write_text(json.dumps({'id':self.entry['id'],'design_revision':'new',
                'specification_sha256':'new-spec','submitted_prompt':'Immutable test prompt'}))
        self.api=types.ModuleType('home_card_manifest_io')
        self.api.ROOT=self.root;self.api.MANIFEST=self.manifest
        self.api.manifest_lock=contextlib.nullcontext
        self.api.digest=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
        self.api.atomic_json=lambda p,v:Path(p).write_text(json.dumps(v))
        self.api.swift_helper=lambda _: 'test-exporter'
    def invoke(self, submission, failure=None):
        argv=[str(SCRIPT),self.entry['id']]
        argv += ['--failure',failure] if failure else [str(self.source)]
        argv += ['--submission',str(self.root/submission)]
        with patch.dict(sys.modules,{'home_card_manifest_io':self.api}),patch.object(sys,'argv',argv),contextlib.redirect_stdout(io.StringIO()):
            try:runpy.run_path(str(SCRIPT),run_name='__main__')
            except SystemExit as e:self.assertEqual(e.code,0)
        return json.loads(self.manifest.read_text())['entries'][0]
    def testLateResultPreservesAcceptedCurrentAndArchivesOriginal(self):
        e=self.invoke('old.json')
        self.assertEqual(e['current_output_status'],'accepted')
        self.assertEqual(self.original.read_bytes(),png(b'old'))
        attempt=e['generation_attempts'][-1]
        self.assertEqual(attempt['status'],'late-generated')
        self.assertEqual((self.root/attempt['source_output']).read_bytes(),self.source.read_bytes())
    def testLateFailureDoesNotDowngradeCurrentGeneration(self):
        e=self.invoke('old.json','quota failure')
        self.assertEqual(e['generation_status'],'generated')
        self.assertEqual(e['current_output_status'],'accepted')
        self.assertEqual(e['generation_attempts'][-1]['error'],'quota failure')
    def testReplacementRequiresFreshInspectionAndArchivesAcceptedExport(self):
        def export(args,**kwargs):
            Path(args[2]).write_bytes(png(b'new-export'))
            Path(args[4]).write_text(json.dumps({'final_export_pixels':[2,2],'unintended_crop_fraction':0}))
            return types.SimpleNamespace(returncode=0,stderr='')
        with patch('subprocess.run',side_effect=export):e=self.invoke('new.json')
        self.assertEqual(e['current_output_status'],'pending')
        self.assertEqual(e['inspection_status'],'pending')
        self.assertEqual(e['generated_specification_sha256'],'new-spec')
        prior=e['revisions'][-1]
        self.assertEqual(prior['inspection_status'],'accepted')
        self.assertEqual((self.root/prior['export']).read_bytes(),png(b'old-export'))

if __name__=='__main__':unittest.main()
