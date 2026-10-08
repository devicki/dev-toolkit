#!/usr/bin/env bash
# ERD 도구 설치 (sudo 없이 현재 계정에만 설치)
# 사용법: install-tools.sh <tbls|dbml|all> [tbls버전]
#   tbls : ~/.local/bin/tbls  (Linux amd64/arm64, macOS는 Homebrew 우선)
#   dbml : npm install -g @dbml/cli  (전역 설치 권한이 없으면 ~/.local 에 설치)
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
  case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) echo "지원하지 않는 CPU: $(uname -m)"; exit 1 ;; esac
  if [ "$os" = "darwin" ] && command -v brew >/dev/null 2>&1; then
    echo "▶ macOS: brew install tbls"; brew install tbls; return
  fi
  v="${2:-$(latest_tbls_version)}"
  mkdir -p "$BIN"; tmp=$(mktemp -d)
  if [ "$os" = "darwin" ]; then
    url="https://github.com/k1LoW/tbls/releases/download/v$v/tbls_v${v}_darwin_${arch}.zip"
    echo "▶ 다운로드: $url"; curl -sSL -o "$tmp/tbls.zip" "$url"; (cd "$tmp" && unzip -q tbls.zip tbls)
  else
    url="https://github.com/k1LoW/tbls/releases/download/v$v/tbls_v${v}_linux_${arch}.tar.gz"
    echo "▶ 다운로드: $url"; curl -sSL "$url" | tar xz -C "$tmp" tbls
  fi
  install -m 0755 "$tmp/tbls" "$BIN/tbls"; rm -rf "$tmp"
  echo "✔ tbls $v → $BIN/tbls"
  case ":$PATH:" in *":$BIN:"*) ;; *) echo "⚠ $BIN 이 PATH에 없습니다. 셸 설정에 추가하세요 (fish: fish_add_path ~/.local/bin)";; esac
}

install_dbml() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "✘ npm이 없습니다. Node.js 18 이상을 먼저 설치하세요 (예: nvm install 22)"; exit 1
  fi
  local prefix; prefix=$(npm config get prefix 2>/dev/null || echo /usr)
  if [ -w "$prefix/lib" ] || [ -w "$prefix" ]; then
    echo "▶ npm install -g @dbml/cli"; npm install -g @dbml/cli
  else
    echo "▶ 전역 경로($prefix) 쓰기 권한 없음 → ~/.local 에 설치"
    npm install -g --prefix "$HOME/.local" @dbml/cli
  fi
  echo "✔ $(command -v dbml2sql || echo "$BIN/dbml2sql") $( (dbml2sql --version || "$BIN/dbml2sql" --version) 2>/dev/null | head -1)"
}

case "$TARGET" in
  tbls) install_tbls "$@" ;;
  dbml) install_dbml ;;
  all)
    rc=0
    ( install_tbls "$@" ) || { echo "✘ tbls 설치 실패"; rc=1; }
    ( install_dbml )      || { echo "✘ @dbml/cli 설치 실패"; rc=1; }
    exit $rc ;;
  *) echo "사용법: $0 <tbls|dbml|all> [tbls버전]"; exit 1 ;;
esac
