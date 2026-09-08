#!/bin/bash
set -euo pipefail

expected_team='CJ43UNM3AR'
expected_bundle_id='com.saransh1337.To-Do-List.mac'
expected_application_id="$expected_team.$expected_bundle_id"
expected_app_group='group.com.saransh1337.tasker.shared'
plist_buddy=/usr/libexec/PlistBuddy

fail() {
  echo "Catalyst signing preflight failed: $*" >&2
  exit 1
}

[[ "$#" == "1" ]] || fail "usage: bash scripts/verify-catalyst-signing.sh /path/to/LifeBoard.app"
app_path="$1"
[[ -d "$app_path" ]] || fail "app bundle not found: $app_path"

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeboard-catalyst-signing.XXXXXX")"
cleanup() {
  rm -rf -- "$temp_dir"
}
trap cleanup EXIT

app_entitlements="$temp_dir/app-entitlements.plist"
profile_plist="$temp_dir/profile.plist"

codesign --verify --deep --strict --verbose=2 "$app_path"
codesign -d --entitlements :- "$app_path" >"$app_entitlements" 2>/dev/null
plutil -lint "$app_entitlements" >/dev/null \
  || fail "signed app entitlements are not a readable property list"

profile_path=''
for candidate in \
  "$app_path/Contents/embedded.provisionprofile" \
  "$app_path/embedded.provisionprofile" \
  "$app_path/embedded.mobileprovision"; do
  if [[ -f "$candidate" ]]; then
    profile_path="$candidate"
    break
  fi
done
[[ -n "$profile_path" ]] || fail "embedded provisioning profile is missing"
security cms -D -i "$profile_path" >"$profile_plist"

app_calendar="$($plist_buddy -c 'Print :com.apple.security.personal-information.calendars' "$app_entitlements" 2>/dev/null || true)"
[[ "$app_calendar" == "true" ]] || fail "signed app is missing Calendar access"

app_identifier="$($plist_buddy -c 'Print :application-identifier' "$app_entitlements" 2>/dev/null || true)"
[[ "$app_identifier" == "$expected_application_id" ]] \
  || fail "signed application-identifier is '$app_identifier', expected '$expected_application_id'"

app_groups="$($plist_buddy -c 'Print :com.apple.security.application-groups' "$app_entitlements" 2>/dev/null || true)"
grep -Fq "$expected_app_group" <<<"$app_groups" \
  || fail "signed app is missing $expected_app_group"

app_keychain_groups="$($plist_buddy -c 'Print :keychain-access-groups' "$app_entitlements" 2>/dev/null || true)"
grep -Fq "$expected_application_id" <<<"$app_keychain_groups" \
  || fail "signed app keychain group does not preserve $expected_application_id"

profile_identifier="$($plist_buddy -c 'Print :Entitlements:application-identifier' "$profile_plist" 2>/dev/null || true)"
[[ "$profile_identifier" == "$expected_application_id" ]] \
  || fail "profile application-identifier is '$profile_identifier', expected '$expected_application_id'"

profile_app_groups="$($plist_buddy -c 'Print :Entitlements:com.apple.security.application-groups' "$profile_plist" 2>/dev/null || true)"
grep -Fq "$expected_app_group" <<<"$profile_app_groups" \
  || fail "embedded profile does not authorize $expected_app_group"

profile_keychain_groups="$($plist_buddy -c 'Print :Entitlements:keychain-access-groups' "$profile_plist" 2>/dev/null || true)"
if ! grep -Fq "$expected_application_id" <<<"$profile_keychain_groups" \
  && ! grep -Fq "$expected_team.*" <<<"$profile_keychain_groups"; then
  fail "embedded profile does not authorize $expected_application_id"
fi

echo "Catalyst signed-product preflight passed for $app_path"
