#!/usr/bin/env bash
# Install ERD tools (current account only, no sudo)
# Usage: install-tools.sh <tbls|dbml|all> [tbls-version]
#   tbls : ~/.local/bin/tbls  (Linux amd64/arm64; on macOS Homebrew is preferred)
#   dbml : npm install -g @dbml/cli  (installs into ~/.local if there is no permission for a global install)
set -euo pipefail
TARGET="${1:-all}"
FALLBACK_TBLS_VERSION="1.96.1"
BIN="$HOME/.local/bin"
# Where tbls releases are downloaded from; overridable so the tests can serve a fake release from file://.
TBLS_BASE="${ERD_TBLS_BASE:-https://github.com/k1LoW/tbls/releases/download}"

sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'; }

latest_tbls_version() {
  local url
  url=$(curl -sSL -o /dev/null -w '%{url_effective}' https://github.com/k1LoW/tbls/releases/latest 2>/dev/null || true)
  case "$url" in */tag/v*) echo "${url##*/tag/v}" ;; *) echo "$FALLBACK_TBLS_VERSION" ;; esac
}

install_tbls() {
  local os arch v ext file tmp want got
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;; esac
  if [ "$os" = "darwin" ] && command -v brew >/dev/null 2>&1; then
    echo "▶ macOS: brew install tbls"; brew install tbls; return
  fi
  v="${2:-$(latest_tbls_version)}"
  mkdir -p "$BIN"; tmp=$(mktemp -d)
  if [ "$os" = "darwin" ]; then ext=zip; else ext=tar.gz; fi
  file="tbls_v${v}_${os}_${arch}.$ext"
  echo "▶ Download: $TBLS_BASE/v$v/$file"
  curl -fsSL -o "$tmp/$file" "$TBLS_BASE/v$v/$file" || { echo "✘ Download failed: $file"; rm -rf "$tmp"; exit 1; }
  # The release publishes checksums-<os>.txt; nothing is unpacked unless the archive matches it.
  curl -fsSL -o "$tmp/checksums.txt" "$TBLS_BASE/v$v/checksums-$os.txt" || { echo "✘ Download failed: checksums-$os.txt"; rm -rf "$tmp"; exit 1; }
  want=$(awk -v f="$file" '$2 == f {print $1}' "$tmp/checksums.txt")
  got=$(sha256 "$tmp/$file")
  if [ -z "$want" ] || [ "$want" != "$got" ]; then
    echo "✘ Checksum mismatch for $file (expected ${want:-none listed}, got $got). Not installed."; rm -rf "$tmp"; exit 1
  fi
  echo "✔ sha256 $got"
  if [ "$ext" = zip ]; then (cd "$tmp" && unzip -q "$file" tbls); else tar xzf "$tmp/$file" -C "$tmp" tbls; fi
  install -m 0755 "$tmp/tbls" "$BIN/tbls"; rm -rf "$tmp"
  echo "✔ tbls $v → $BIN/tbls"
  case ":$PATH:" in *":$BIN:"*) ;; *) echo "▲ $BIN is not on PATH. Add it in your shell config (fish: fish_add_path ~/.local/bin)";; esac
}

install_dbml() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "✘ npm not found. Install Node.js 18 or later first (e.g. nvm install 22)"; exit 1
  fi
  local prefix; prefix=$(npm config get prefix 2>/dev/null || echo /usr)
  if [ -w "$prefix/lib" ] || [ -w "$prefix" ]; then
    echo "▶ npm install -g @dbml/cli"; npm install -g @dbml/cli
  else
    echo "▶ No write permission for global path ($prefix) → installing into ~/.local"
    npm install -g --prefix "$HOME/.local" @dbml/cli
  fi
  echo "✔ $(command -v dbml2sql || echo "$BIN/dbml2sql") $( (dbml2sql --version || "$BIN/dbml2sql" --version) 2>/dev/null | head -1)"
}

case "$TARGET" in
  tbls) install_tbls "$@" ;;
  dbml) install_dbml ;;
  all)
    rc=0
    ( install_tbls "$@" ) || { echo "✘ tbls install failed"; rc=1; }
    ( install_dbml )      || { echo "✘ @dbml/cli install failed"; rc=1; }
    exit $rc ;;
  *) echo "Usage: $0 <tbls|dbml|all> [tbls-version]"; exit 1 ;;
esac
