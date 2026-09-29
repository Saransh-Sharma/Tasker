#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED="${LIFEBOARD_TEST_DERIVED_DATA:-build/DerivedData/HomeCards}"
DESTINATION="${LIFEBOARD_TEST_DESTINATION:-platform=iOS Simulator,name=LifeBoard Artwork iPhone 16}"
if [[ "${LIFEBOARD_SKIP_BUILD:-0}" != 1 ]]; then
  xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination "$DESTINATION" -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build-for-testing
fi
RUN_FILE="$(mktemp /tmp/lifeboard-production-evidence.XXXXXX.xctestrun)"
trap 'rm -f "$RUN_FILE"' EXIT
python3 - "$DERIVED" "$RUN_FILE" <<'PY'
import hashlib, os, pathlib, plistlib, subprocess, sys
root=pathlib.Path.cwd()
products=(root/sys.argv[1]/'Build/Products').resolve()
source=max(products.glob('*.xctestrun'),key=lambda p:p.stat().st_mtime)
data=plistlib.loads(source.read_bytes())
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
sources=sorted((root/'LifeBoard').rglob('*.swift'))
signature=hashlib.sha256(b''.join(str(p.relative_to(root)).encode()+p.read_bytes() for p in sources)).hexdigest()
environment={
 'LIFEBOARD_CAPTURE_PRODUCTION_ROUTES':'1',
 'LIFEBOARD_EVIDENCE_OUTPUT':str(root/'docs/design/home-cards/production-routes'),
 'LIFEBOARD_EVIDENCE_ROUTES':os.environ.get('LIFEBOARD_EVIDENCE_ROUTES','home'),
 'LIFEBOARD_EVIDENCE_ARRANGEMENTS':os.environ.get('LIFEBOARD_EVIDENCE_ARRANGEMENTS','paired,solitary,mixed,lowEnergy'),
 'LIFEBOARD_EVIDENCE_APPEARANCES':os.environ.get('LIFEBOARD_EVIDENCE_APPEARANCES','light,dark'),
 'LIFEBOARD_EVIDENCE_CONTENT_SIZE':os.environ.get('LIFEBOARD_EVIDENCE_CONTENT_SIZE','UICTContentSizeCategoryL'),
 'LIFEBOARD_EVIDENCE_CELESTIAL_PHASE':os.environ.get('LIFEBOARD_EVIDENCE_CELESTIAL_PHASE','morning'),
 'LIFEBOARD_EVIDENCE_RENDERER_REVISION':revision+'+working-tree:'+signature
}
def edit(value):
 if isinstance(value,dict):
  if 'TestBundlePath' in value:
   value.setdefault('EnvironmentVariables',{}).update(environment)
   # Xcode leaves the test-host placeholder in TestBundlePath while the
   # wrapper makes TestHostPath absolute. Resolve both sides together so an
   # xctestrun copied outside DerivedData still installs the host application.
   host=value.get('TestHostPath')
   if isinstance(host,str):
    host=host.replace('__TESTROOT__',str(products))
    value['TestHostPath']=host
    bundle=value['TestBundlePath']
    if isinstance(bundle,str):value['TestBundlePath']=bundle.replace('__TESTHOST__',host)
  for k,v in value.items():
   if isinstance(v,str):value[k]=v.replace('__TESTROOT__',str(products))
   else:edit(v)
 elif isinstance(value,list):
  for item in value:edit(item)
edit(data)
pathlib.Path(sys.argv[2]).write_bytes(plistlib.dumps(data))
PY
xcodebuild -xctestrun "$RUN_FILE" -destination "$DESTINATION" -only-testing:LifeBoardUITests/LifeBoardUITests/testProductionArtworkRouteEvidence test-without-building
