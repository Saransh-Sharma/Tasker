"""Shared atomic IO and source-built helpers for Home design operations."""
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'docs/design/home-cards/image-generation-manifest.json'

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)

@contextlib.contextmanager
def manifest_lock():
    # One location shared by catalog, submission, recording, and acceptance writers.
    directory = ROOT / 'build/design-tools'
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / 'home-manifest.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield

def swift_helper(name):
    source = ROOT / 'scripts' / (name + '.swift')
    version = subprocess.check_output(['xcrun', 'swiftc', '--version'])
    signature = hashlib.sha256(source.read_bytes() + version).hexdigest()[:16]
    directory = ROOT / 'build/design-tools'
    directory.mkdir(parents=True, exist_ok=True)
    executable = directory / (name + '-' + signature)
    if not executable.exists():
        temporary = executable.with_suffix('.building')
        subprocess.run(['xcrun', 'swiftc', '-O', str(source), '-o', str(temporary)], check=True)
        os.replace(temporary, executable)
    return str(executable)
