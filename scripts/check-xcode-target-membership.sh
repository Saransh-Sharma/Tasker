#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lifeboard-paths.env
source "$SCRIPT_DIR/lifeboard-paths.env"

usage() {
  echo "usage: $0 [--derived-data PATH]" >&2
}

derived_data=""
if [[ $# -gt 0 ]]; then
  if [[ $# -ne 2 || "$1" != "--derived-data" ]]; then
    usage
    exit 2
  fi
  derived_data="$2"
fi

cleanup_dir=""
if [[ -z "$derived_data" ]]; then
  cleanup_dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeboard-membership.XXXXXX")"
  derived_data="$cleanup_dir/DerivedData"
  trap '[[ -n "$cleanup_dir" ]] && rm -rf "$cleanup_dir"' EXIT

  build_scheme() {
    local scheme="$1" destination="$2" action="$3"
    local log="$cleanup_dir/${scheme}.log"
    if ! xcodebuild \
      -workspace "$LIFEBOARD_WORKSPACE" \
      -scheme "$scheme" \
      -configuration Debug \
      -destination "$destination" \
      -derivedDataPath "$derived_data" \
      -skipPackageUpdates \
      -disableAutomaticPackageResolution \
      -jobs 4 \
      CODE_SIGNING_ALLOWED=NO \
      COMPILER_INDEX_STORE_ENABLE=NO \
      SWIFT_EMIT_LOC_STRINGS=NO \
      "$action" >"$log" 2>&1; then
      echo "error: compilation membership probe failed for $scheme" >&2
      tail -n 200 "$log" >&2
      exit 1
    fi
  }

  build_scheme "LifeBoard" "generic/platform=iOS Simulator" "build-for-testing"
  build_scheme "LifeBoardWatch" "generic/platform=watchOS Simulator" "build"
  build_scheme "LifeBoardWatchWidgets" "generic/platform=watchOS Simulator" "build"

  package_workspace="$cleanup_dir/PackageWorkspace"
  mkdir -p "$package_workspace"
  ln -s "$LIFEBOARD_ROOT_DIR/Package.swift" "$package_workspace/Package.swift"
  ln -s "$LIFEBOARD_ROOT_DIR/Packages" "$package_workspace/Packages"
  ln -s "$LIFEBOARD_ROOT_DIR/LifeBoard" "$package_workspace/LifeBoard"
  package_test_scheme="$(swift package dump-package --package-path "$LIFEBOARD_ROOT_DIR" | ruby -rjson -e '
    package = JSON.parse($stdin.read)
    puts "#{package.fetch("name")}-Package" if package.fetch("targets").any? { |target| target["type"] == "test" }
  ')"
  if [[ -n "$package_test_scheme" ]]; then
    log="$cleanup_dir/${package_test_scheme}.log"
    if ! (cd "$package_workspace" && xcodebuild \
      -scheme "$package_test_scheme" \
      -configuration Debug \
      -destination "generic/platform=iOS Simulator" \
      -derivedDataPath "$derived_data" \
      -skipPackageUpdates \
      -disableAutomaticPackageResolution \
      -jobs 4 \
      CODE_SIGNING_ALLOWED=NO \
      COMPILER_INDEX_STORE_ENABLE=NO \
      SWIFT_EMIT_LOC_STRINGS=NO \
      build-for-testing >"$log" 2>&1); then
      echo "error: compilation membership probe failed for package test scheme $package_test_scheme" >&2
      tail -n 200 "$log" >&2
      exit 1
    fi
  fi
fi

export LIFEBOARD_ROOT_DIR LIFEBOARD_TARGET_MEMBERSHIP_ALLOWLIST
export LIFEBOARD_TARGET_MEMBERSHIP_EXCLUSIONS
export LIFEBOARD_MEMBERSHIP_DERIVED_DATA="$derived_data"
export LIFEBOARD_SWIFT_SOURCE_ROOTS="$(IFS=:; echo "${LIFEBOARD_SWIFT_SOURCE_ROOTS[*]}")"

exec ruby "$SCRIPT_DIR/check_xcode_target_membership.rb"
