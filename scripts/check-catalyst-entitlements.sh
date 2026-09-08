#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
entitlements="$repo_root/LifeBoard/LifeBoardCatalyst.entitlements"
project="$repo_root/LifeBoard.xcodeproj/project.pbxproj"
plist_buddy=/usr/libexec/PlistBuddy

fail() {
  echo "Catalyst entitlement guard failed: $*" >&2
  exit 1
}

plutil -lint "$entitlements" >/dev/null

calendar_access="$($plist_buddy -c 'Print :com.apple.security.personal-information.calendars' "$entitlements" 2>/dev/null || true)"
[[ "$calendar_access" == "true" ]] || fail "calendar access entitlement must be true"

app_groups="$($plist_buddy -c 'Print :com.apple.security.application-groups' "$entitlements" 2>/dev/null || true)"
grep -Fq 'group.com.saransh1337.tasker.shared' <<<"$app_groups" \
  || fail "shared App Group is missing"

keychain_group="$($plist_buddy -c 'Print :keychain-access-groups:0' "$entitlements" 2>/dev/null || true)"
[[ "$keychain_group" == '$(AppIdentifierPrefix)$(CFBundleIdentifier)' ]] \
  || fail "default Catalyst keychain access group changed"
if $plist_buddy -c 'Print :keychain-access-groups:1' "$entitlements" >/dev/null 2>&1; then
  fail "unexpected additional Catalyst keychain access group"
fi

entitlement_setting='"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]" = LifeBoard/LifeBoardCatalyst.entitlements;'
setting_count="$(grep -Fc "$entitlement_setting" "$project")"
[[ "$setting_count" == "2" ]] \
  || fail "Debug and Release must both select LifeBoardCatalyst.entitlements (found $setting_count settings)"

bundle_setting='"PRODUCT_BUNDLE_IDENTIFIER[sdk=macosx*]" = "com.saransh1337.To-Do-List.mac";'
bundle_count="$(grep -Fc "$bundle_setting" "$project")"
[[ "$bundle_count" == "2" ]] \
  || fail "Debug and Release must preserve the Catalyst bundle identifier (found $bundle_count settings)"

capability_setting='com.apple.ApplicationGroups = {'
capability_count="$(grep -Fc "$capability_setting" "$project")"
[[ "$capability_count" == "1" ]] \
  || fail "the LifeBoard target must declare the App Groups system capability (found $capability_count settings)"

registration_setting='"REGISTER_APP_GROUPS[sdk=macosx*]" = YES;'
registration_count="$(grep -Fc "$registration_setting" "$project")"
[[ "$registration_count" == "2" ]] \
  || fail "Debug and Release must register provisioned Catalyst App Groups (found $registration_count settings)"

echo "Catalyst source entitlement guard passed."
