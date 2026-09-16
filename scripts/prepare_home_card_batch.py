#!/usr/bin/env python3
"""Prepare a small built-in-tool batch. This script makes no generation calls."""
import json, subprocess, sys
from pathlib import Path
from home_card_manifest_io import ROOT
batch=[]
for ident in sys.argv[1:]:
    output=subprocess.check_output([sys.executable,str(ROOT/'scripts/prepare_home_card_generation.py'),ident,
        '--revision-reason','Current native-first reference using measured Swift fixture copy, typography, controls, and ambient framing.'],text=True)
    path=Path(output.strip());submission=json.loads(path.read_text())
    batch.append({'id':ident,'submission':str(path.relative_to(ROOT)),'prompt':submission['submitted_prompt'],'references':submission['references']})
print(json.dumps(batch))
