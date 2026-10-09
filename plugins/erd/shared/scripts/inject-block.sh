#!/usr/bin/env bash
# Insert or replace a marker-delimited block in a file. Running it repeatedly leaves exactly one block (idempotent).
# Usage: inject-block.sh <target file> <block id> <content file|->
#   Block form:  <!-- <id>:start --> … <!-- <id>:end -->
#   If content is '-', read from stdin. Creates the target file if it does not exist.
# Output: "+ <file> (block added)" | "~ <file> (block updated)" | "= <file> (unchanged)"
set -euo pipefail
[ $# -eq 3 ] || { echo "Usage: $0 <target file> <block id> <content file|->" >&2; exit 2; }
target="$1"; id="$2"; src="$3"
start="<!-- ${id}:start -->"; end="<!-- ${id}:end -->"

content="$(if [ "$src" = "-" ]; then cat; else cat "$src"; fi)"
block="$(printf '%s\n%s\n%s' "$start" "$content" "$end")"

mkdir -p "$(dirname "$target")"
if [ -f "$target" ] && grep -qF "$start" "$target"; then
  tmp="$(mktemp)"
  # Put the new block exactly where the old block was (block position preserved)
  BLK="$block" S="$start" E="$end" awk '
    BEGIN { s = ENVIRON["S"]; e = ENVIRON["E"] }
    $0 == s { print ENVIRON["BLK"]; skip = 1; next }
    $0 == e && skip { skip = 0; next }
    !skip { print }
  ' "$target" > "$tmp"
  if cmp -s "$tmp" "$target"; then rm -f "$tmp"; echo "= $target (unchanged)"; else cat "$tmp" > "$target"; rm -f "$tmp"; echo "~ $target (block updated)"; fi   # overwrite via cat to keep file permissions
else
  { [ -s "${target}" ] && printf '\n'; printf '%s\n' "$block"; } >> "$target"
  echo "+ $target (block added)"
fi
