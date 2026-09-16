#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED="${LIFEBOARD_TEST_DERIVED_DATA:-build/DerivedData/HomeCards}"
DESTINATION="${LIFEBOARD_TEST_DESTINATION:-platform=iOS Simulator,name=LifeBoard Test iPhone}"
CAPTURE_TEST="${LIFEBOARD_CAPTURE_TEST_FILTER:-LifeBoardTests/HomeCardPresentationTests/testPreviewDimensionsAndRenderEvidence}"
# Accept a class/method shorthand without accidentally selecting zero tests.
if [[ "$CAPTURE_TEST" == HomeCardPresentationTests/* ]]; then
  CAPTURE_TEST="LifeBoardTests/$CAPTURE_TEST"
fi
if [[ -d docs/design/home-cards/implementation && ! -d docs/design/home-cards/history/initial-sample-captures ]]; then
  mkdir -p docs/design/home-cards/history
  cp -R docs/design/home-cards/implementation docs/design/home-cards/history/initial-sample-captures
  cp docs/design/home-cards/layout-measurements.json docs/design/home-cards/history/initial-layout-measurements.json
fi
xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination "$DESTINATION" -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build-for-testing
RUN_FILE="$(mktemp /tmp/lifeboard-home-cards.XXXXXX.xctestrun)"
trap 'rm -f "$RUN_FILE"' EXIT
python3 - "$DERIVED" "$RUN_FILE" <<'PY'
import pathlib,plistlib,sys,os
products=pathlib.Path(sys.argv[1]).resolve()/'Build/Products'
source=max(products.glob('*.xctestrun'),key=lambda p:p.stat().st_mtime)
data=plistlib.loads(source.read_bytes())
def edit(value):
 if isinstance(value,dict):
  if 'TestBundlePath' in value:
   value.setdefault('EnvironmentVariables',{})['LIFEBOARD_CAPTURE_HOME_CARDS']='1'
   if os.environ.get('LIFEBOARD_CAPTURE_KINDS'): value['EnvironmentVariables']['LIFEBOARD_CAPTURE_KINDS']=os.environ['LIFEBOARD_CAPTURE_KINDS']
  for k,v in value.items():
   if isinstance(v,str):value[k]=v.replace('__TESTROOT__',str(products))
   else:edit(v)
 elif isinstance(value,list):
  for item in value:edit(item)
edit(data);pathlib.Path(sys.argv[2]).write_bytes(plistlib.dumps(data))
PY
xcodebuild -xctestrun "$RUN_FILE" -destination "$DESTINATION" -only-testing:"$CAPTURE_TEST" test-without-building

if [[ "$CAPTURE_TEST" == "LifeBoardTests/HomeCardPresentationTests/testExportInstrumentedElementSpecifications" ]]; then
  python3 scripts/sign_home_card_specifications.py
fi
