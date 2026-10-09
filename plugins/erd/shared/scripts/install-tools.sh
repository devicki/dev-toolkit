#!/usr/bin/env bash
# Install ERD tools (current account only, no sudo)
# Usage: install-tools.sh <tbls|dbml|all> [tbls-version]
#   tbls : ~/.local/bin/tbls  (Linux amd64/arm64; on macOS Homebrew is preferred)
#   dbml : npm install -g @dbml/cli  (installs into ~/.local if there is no permission for a global install)
set -euo pipefail
TARGET="${1:-all}"
FALLBACK_TBLS_VERSION="1.96.1"
BIN="$HOME/.local/bin"

latest_tbls_version() {
  local url
  url=$(curl -sSL -o /dev/null -w '%{url_effective}' https://github.com/k1LoW/tbls/releases/latest 2>/dev/null || true)
  case "$url" in */tag/v*) echo "${url##*/tag/v}" ;; *) echo "$FALLBACK_TBLS_VERSION" ;; esac
}

install_tbls() {
  local os arch v url tmp
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;; esac
  if [ "$os" = "darwin" ] && command -v brew >/dev/null 2>&1; then
    echo "▶ macOS: brew install tbls"; brew install tbls; return
  fi
  v="${2:-$(latest_tbls_version)}"
  mkdir -p "$BIN"; tmp=$(mktemp -d)
  if [ "$os" = "darwin" ]; then
    url="https://github.com/k1LoW/tbls/releases/download/v$v/tbls_v${v}_darwin_${arch}.zip"
    echo "▶ Download: $url"; curl -sSL -o "$tmp/tbls.zip" "$url"; (cd "$tmp" && unzip -q tbls.zip tbls)
  else
    url="https://github.com/k1LoW/tbls/releases/download/v$v/tbls_v${v}_linux_${arch}.tar.gz"
    echo "▶ Download: $url"; curl -sSL "$url" | tar xz -C "$tmp" tbls
  fi
  install -m 0755 "$tmp/tbls" "$BIN/tbls"; rm -rf "$tmp"
  echo "✔ tbls $v → $BIN/tbls"
  case ":$PATH:" in *":$BIN:"*) ;; *) echo "⚠ $BIN is not on PATH. Add it in your shell config (fish: fish_add_path ~/.local/bin)";; esac
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
