#!/usr/bin/env bash
set -euo pipefail

plist_path="${1:-GoogleService-Info.plist}"

if [[ -f "$plist_path" ]]; then
  echo "Using existing $plist_path"
  exit 0
fi

cat > "$plist_path" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>ci-placeholder-api-key</string>
	<key>GCM_SENDER_ID</key>
	<string>000000000000</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>com.saranshsharma.LifeBoard</string>
	<key>PROJECT_ID</key>
	<string>lifeboard-ci</string>
	<key>STORAGE_BUCKET</key>
	<string>lifeboard-ci.appspot.com</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>IS_APPINVITE_ENABLED</key>
	<false/>
	<key>IS_GCM_ENABLED</key>
	<false/>
	<key>IS_SIGNIN_ENABLED</key>
	<false/>
	<key>GOOGLE_APP_ID</key>
	<string>1:000000000000:ios:0000000000000000000000</string>
</dict>
</plist>
PLIST

echo "Wrote CI placeholder $plist_path"
