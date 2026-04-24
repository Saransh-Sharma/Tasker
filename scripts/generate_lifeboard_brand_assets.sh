#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SVG="${REPO_ROOT}/LifeBoard_Icon Abstract_Face.svg"

ICON_SET_MAIN="${REPO_ROOT}/To Do List/Assets.xcassets/AppIcon.appiconset"
ICON_SET_WHITE="${REPO_ROOT}/To Do List/Assets.xcassets/AppIcon_WHITE.appiconset"
IN_APP_LOGO_SET="${REPO_ROOT}/To Do List/Assets.xcassets/LifeBoardLogo.imageset"

if [[ ! -f "${SOURCE_SVG}" ]]; then
  echo "Missing source SVG: ${SOURCE_SVG}" >&2
  exit 1
fi

if ! command -v qlmanage >/dev/null 2>&1; then
  echo "qlmanage is required but not installed." >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required but not installed." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmpdir}"
}
trap cleanup EXIT

qlmanage -t -s 1024 -o "${tmpdir}" "${SOURCE_SVG}" >/dev/null 2>&1

source_png="$(find "${tmpdir}" -maxdepth 1 -type f -name '*.png' | head -n 1)"
if [[ -z "${source_png}" ]]; then
  echo "Failed to render PNG from SVG with qlmanage." >&2
  exit 1
fi

resize_png() {
  local size="$1"
  local output="$2"
  mkdir -p "$(dirname "${output}")"
  sips -z "${size}" "${size}" "${source_png}" --out "${output}" >/dev/null
}

png_has_alpha() {
  local file="$1"
  local has_alpha
  has_alpha="$(sips -g hasAlpha "${file}" 2>/dev/null | awk '/hasAlpha:/ {print $2}' | tr '[:upper:]' '[:lower:]')"
  [[ "${has_alpha}" == "yes" ]]
}

generate_icon_set() {
  local set_dir="$1"
  local -a targets=(
    "IconSmall-20@2x.png:40"
    "IconSmall-20@3x.png:60"
    "IconSmall@2x.png:58"
    "IconSmall@3x.png:87"
    "IconSmall-40@2x.png:80"
    "IconSmall-40@3x.png:120"
    "Icon@2x.png:120"
    "Icon@3x.png:180"
    "IconSmall-20.png:20"
    "IconSmall-20-iPad@2x.png:40"
    "IconSmall.png:29"
    "IconSmall-iPad@2x.png:58"
    "IconSmall-40.png:40"
    "IconSmall-40-iPad@2x.png:80"
    "Icon-76.png:76"
    "Icon-76@2x.png:152"
    "Icon-83.5@2x.png:167"
    "AppStoreIcon.png:1024"
  )

  for entry in "${targets[@]}"; do
    local filename="${entry%%:*}"
    local size="${entry##*:}"
    resize_png "${size}" "${set_dir}/${filename}"
  done
}

generate_icon_set "${ICON_SET_MAIN}"
generate_icon_set "${ICON_SET_WHITE}"

validate_icon_set_opaque() {
  local set_dir="$1"
  local failed=0
  while IFS= read -r icon_path; do
    if png_has_alpha "${icon_path}"; then
      echo "Generated icon contains alpha channel (not allowed): ${icon_path}" >&2
      failed=1
    fi
  done < <(find "${set_dir}" -maxdepth 1 -type f -name '*.png' | sort)

  if [[ "${failed}" -ne 0 ]]; then
    echo "Aborting because generated app icons must be opaque." >&2
    exit 1
  fi
}

validate_icon_set_opaque "${ICON_SET_MAIN}"
validate_icon_set_opaque "${ICON_SET_WHITE}"

resize_png 64 "${IN_APP_LOGO_SET}/LifeBoardLogo@1x.png"
resize_png 128 "${IN_APP_LOGO_SET}/LifeBoardLogo@2x.png"
resize_png 192 "${IN_APP_LOGO_SET}/LifeBoardLogo@3x.png"

echo "Generated app icon assets and in-app logo from ${SOURCE_SVG}"
