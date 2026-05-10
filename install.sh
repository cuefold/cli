#!/bin/sh
set -e

# Cuefold CLI installer
# Usage: curl -fsSL https://cuefold.com/install.sh | bash
#        curl -fsSL https://cuefold.com/install.sh | bash -s v1.2.0
#
# Environment variables:
#   CUEFOLD_VERSION      Pin a specific version (e.g. v1.2.0)
#   CUEFOLD_INSTALL_DIR  Override install location (default: /usr/local/bin)

CUEFOLD_VERSION="${CUEFOLD_VERSION:-}"
CUEFOLD_INSTALL_DIR="${CUEFOLD_INSTALL_DIR:-/usr/local/bin}"
GITHUB_REPO="cuefold/cli"

# Accept optional positional version arg
if [ -n "${1:-}" ]; then
  CUEFOLD_VERSION="$1"
fi

# ── download helper ────────────────────────────────────────────────────────────

if command -v curl >/dev/null 2>&1; then
  download() { curl -fsSL "$1" ${2:+-o "$2"}; }
elif command -v wget >/dev/null 2>&1; then
  download() {
    if [ -n "${2:-}" ]; then
      wget -qO "$2" "$1"
    else
      wget -qO- "$1"
    fi
  }
else
  echo "error: neither curl nor wget is available. Please install one and try again." >&2
  exit 1
fi

# ── OS detection ───────────────────────────────────────────────────────────────

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
  linux)  ;;
  darwin) ;;
  msys*|cygwin*|mingw*|windows*)
    echo "error: Windows is not supported by this installer." >&2
    echo "Please use WSL2 or download the Windows binary directly from:" >&2
    echo "  https://github.com/${GITHUB_REPO}/releases" >&2
    exit 1 ;;
  *)
    echo "error: unsupported OS: $OS" >&2
    exit 1 ;;
esac

# ── architecture detection ─────────────────────────────────────────────────────

ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64)   ARCH="amd64" ;;
  aarch64|arm64)  ARCH="arm64" ;;
  *)
    echo "error: unsupported architecture: $ARCH" >&2
    exit 1 ;;
esac

# Detect Rosetta 2: x86_64 process running on Apple Silicon
if [ "$OS" = "darwin" ] && [ "$ARCH" = "amd64" ]; then
  if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ]; then
    echo "Detected Rosetta 2 — selecting native arm64 binary."
    ARCH="arm64"
  fi
fi

# Detect musl libc (Alpine etc.) — informational only; binaries are statically linked
if [ "$OS" = "linux" ] && command -v ldd >/dev/null 2>&1; then
  if ldd /bin/sh 2>&1 | grep -q musl; then
    echo "Detected musl libc."
  fi
fi

# ── version resolution ─────────────────────────────────────────────────────────

if [ -z "$CUEFOLD_VERSION" ]; then
  printf "Resolving latest version... "
  API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  CUEFOLD_VERSION=$(download "$API_URL" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  if [ -z "$CUEFOLD_VERSION" ]; then
    echo "failed." >&2
    echo "error: could not resolve the latest version. Set CUEFOLD_VERSION and retry." >&2
    exit 1
  fi
  echo "$CUEFOLD_VERSION"
fi

# GoReleaser strips the leading 'v' from the version in archive filenames
VERSION_NUM="${CUEFOLD_VERSION#v}"
ARCHIVE_NAME="cuefold_${VERSION_NUM}_${OS}_${ARCH}.tar.gz"
RELEASE_BASE="https://github.com/${GITHUB_REPO}/releases/download/${CUEFOLD_VERSION}"

echo "Installing Cuefold CLI ${CUEFOLD_VERSION} (${OS}/${ARCH})..."

# ── download + verify ──────────────────────────────────────────────────────────

TMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$TMP_DIR'" EXIT INT TERM

ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${TMP_DIR}/${ARCHIVE_NAME}.sha256"

download "${RELEASE_BASE}/${ARCHIVE_NAME}"         "$ARCHIVE_PATH"
download "${RELEASE_BASE}/${ARCHIVE_NAME}.sha256"  "$CHECKSUM_PATH"

EXPECTED=$(cat "$CHECKSUM_PATH" | awk '{print $1}')

if [ "$OS" = "darwin" ]; then
  ACTUAL=$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')
else
  ACTUAL=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')
fi

if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "error: checksum verification failed." >&2
  echo "  expected: $EXPECTED" >&2
  echo "  actual:   $ACTUAL" >&2
  exit 1
fi

# ── extract ────────────────────────────────────────────────────────────────────

tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"
chmod +x "${TMP_DIR}/cuefold"

# ── install ────────────────────────────────────────────────────────────────────

if mkdir -p "$CUEFOLD_INSTALL_DIR" 2>/dev/null && [ -w "$CUEFOLD_INSTALL_DIR" ]; then
  INSTALL_PATH="${CUEFOLD_INSTALL_DIR}/cuefold"
  cp "${TMP_DIR}/cuefold" "$INSTALL_PATH"
else
  FALLBACK_DIR="${HOME}/.local/bin"
  mkdir -p "$FALLBACK_DIR"
  INSTALL_PATH="${FALLBACK_DIR}/cuefold"
  cp "${TMP_DIR}/cuefold" "$INSTALL_PATH"
  case ":${PATH}:" in
    *":${FALLBACK_DIR}:"*) ;;
    *)
      echo ""
      echo "Note: ${FALLBACK_DIR} is not in your PATH."
      echo "Add it by running:"
      echo "  export PATH=\"\$PATH:${FALLBACK_DIR}\""
      ;;
  esac
fi

# ── confirm ────────────────────────────────────────────────────────────────────

echo ""
echo "Cuefold CLI installed to ${INSTALL_PATH}"
"$INSTALL_PATH" version
