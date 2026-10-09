#!/usr/bin/env bash
# 마커로 감싼 블록을 파일에 넣거나 교체한다. 여러 번 실행해도 블록은 하나만 남는다 (멱등).
# 사용법: inject-block.sh <대상 파일> <블록 id> <내용 파일|->
#   블록 형태:  <!-- <id>:start --> … <!-- <id>:end -->
#   내용이 '-' 이면 stdin 에서 읽는다. 대상 파일이 없으면 만든다.
# 출력: "+ <파일> (블록 추가)" | "~ <파일> (블록 갱신)" | "= <파일> (변경 없음)"
set -euo pipefail
[ $# -eq 3 ] || { echo "사용법: $0 <대상 파일> <블록 id> <내용 파일|->" >&2; exit 2; }
target="$1"; id="$2"; src="$3"
start="<!-- ${id}:start -->"; end="<!-- ${id}:end -->"

content="$(if [ "$src" = "-" ]; then cat; else cat "$src"; fi)"
block="$(printf '%s\n%s\n%s' "$start" "$content" "$end")"

mkdir -p "$(dirname "$target")"
if [ -f "$target" ] && grep -qF "$start" "$target"; then
  tmp="$(mktemp)"
  # 기존 블록 자리에 새 블록을 그대로 끼운다 (블록 위치 유지)
  BLK="$block" S="$start" E="$end" awk '
    BEGIN { s = ENVIRON["S"]; e = ENVIRON["E"] }
    $0 == s { print ENVIRON["BLK"]; skip = 1; next }
    $0 == e && skip { skip = 0; next }
    !skip { print }
  ' "$target" > "$tmp"
  if cmp -s "$tmp" "$target"; then rm -f "$tmp"; echo "= $target (변경 없음)"; else cat "$tmp" > "$target"; rm -f "$tmp"; echo "~ $target (블록 갱신)"; fi   # cat 으로 덮어써 권한 유지
else
  { [ -s "${target}" ] && printf '\n'; printf '%s\n' "$block"; } >> "$target"
  echo "+ $target (블록 추가)"
fi
