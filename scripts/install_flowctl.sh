#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$ROOT_DIR/.flow/bin"
TARGET="$BIN_DIR/flowctl"
PINNED_VERSION="${FLOWCTL_VERSION:-0.1.0}"
DOWNLOAD_URL="${FLOWCTL_DOWNLOAD_URL:-}"
EXPECTED_SHA256="${FLOWCTL_DOWNLOAD_SHA256:-}"
ALLOW_SHIM="${FLOWCTL_ALLOW_SHIM:-0}"

mkdir -p "$BIN_DIR"

if [[ -x "$TARGET" ]]; then
  echo "flowctl already installed at $TARGET"
  exit 0
fi

if [[ -n "$DOWNLOAD_URL" ]]; then
  echo "Installing flowctl ${PINNED_VERSION} from custom URL"
  curl -fsSL "$DOWNLOAD_URL" -o "$TARGET"
  if [[ "${CI:-}" == "true" || "${CI:-}" == "1" ]]; then
    if [[ -z "$EXPECTED_SHA256" ]]; then
      echo "FLOWCTL_DOWNLOAD_SHA256 must be set in CI"
      exit 1
    fi
  fi
  if [[ -n "$EXPECTED_SHA256" ]]; then
    ACTUAL_SHA256="$(shasum -a 256 "$TARGET" | awk '{print $1}')"
    if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
      echo "flowctl checksum mismatch"
      echo "expected: $EXPECTED_SHA256"
      echo "actual:   $ACTUAL_SHA256"
      exit 1
    fi
  fi
  chmod +x "$TARGET"
else
  if [[ "${CI:-}" == "true" || "${CI:-}" == "1" ]]; then
    echo "FLOWCTL_DOWNLOAD_URL must be set in CI; shim install is forbidden"
    exit 1
  fi
  if [[ "$ALLOW_SHIM" != "1" ]]; then
    echo "FLOWCTL_DOWNLOAD_URL is not set and FLOWCTL_ALLOW_SHIM is not enabled"
    echo "Set FLOWCTL_DOWNLOAD_URL to install the official binary."
    echo "For local-only fallback, rerun with FLOWCTL_ALLOW_SHIM=1."
    exit 1
  fi
  echo "Installing local shim for flowctl ${PINNED_VERSION} (FLOWCTL_ALLOW_SHIM=1)"
  cat > "$TARGET" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo "flowctl shim 0.1.0"
  exit 0
fi
echo "flowctl shim: set FLOWCTL_DOWNLOAD_URL and rerun scripts/install_flowctl.sh to install the official binary"
exit 0
SHIM
  chmod +x "$TARGET"
fi

echo "flowctl installed at $TARGET"
"$TARGET" --version
