#!/usr/bin/env bash
# (Installed into the project's scripts/ by the erd plugin. Plugin source: shared/templates/scripts/erd-changed.sh)
# Groups files changed against the base branch by ERD unit. (read-only)
# Usage: scripts/erd-changed.sh [--base <ref>] [--json] [--names] [repo path]
#   --base  : comparison base. Default: the remote default branch (origin/HEAD → origin/main → origin/master → main)
#             The remote is preferred because local branches can lag behind it.
#   --names : only unit paths with schema-related changes, one per line (for make erd-check-changed)
#   --json  : machine-readable output
# Changes = committed since the base + uncommitted + untracked new files
# Categories: schema (source of truth, settings), docs (generated docs/schema), related (ERD_RELATED_SOURCES folders), other
# Message language: ERD_LANG env, else the first unit's erd.env, else en
# Exit codes: 0 ok | 2 not a git repo / base ref not found
set -u
set -f
BASE="" FMT=text DIR="."
while [ $# -gt 0 ]; do
  case "$1" in --base) BASE="$2"; shift 2;; --json) FMT=json; shift;; --names) FMT=names; shift;; *) DIR="$1"; shift;; esac
done
m() { if [ "${ERD_LANG:-en}" = "ko" ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }   # m <ko> <en>
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)" || { echo "✘ $(m "git 저장소가 아닙니다" "Not a git repository"): $DIR" >&2; exit 2; }
cd "$ROOT"
UNITS="$(git ls-files --cached --others --exclude-standard 2>/dev/null | grep -E '(^|/)erd\.env$' | sed -E 's#/?erd\.env$##; s#^$#.#' | sort -u)"
if [ -z "${ERD_LANG:-}" ]; then
  for u in $UNITS; do ERD_LANG="$(grep -h '^ERD_LANG=' "$u/erd.env" 2>/dev/null | head -1 | cut -d= -f2 | tr -d "'\" ")"; break; done
fi
if [ -z "$BASE" ]; then
  for r in "$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" origin/main origin/master main master; do
    [ -n "$r" ] && git rev-parse -q --verify "$r^{commit}" >/dev/null 2>&1 && { BASE="$r"; break; }
  done
fi
[ -n "$BASE" ] && git rev-parse -q --verify "$BASE^{commit}" >/dev/null 2>&1 || { echo "✘ $(m "기준 ref 를 찾을 수 없습니다: ${BASE:-(자동 탐지 실패)} — --base 로 지정하세요" "Base ref not found: ${BASE:-(auto-detect failed)} — pass --base")" >&2; exit 2; }
MB="$(git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")"

FILES="$( { git diff --name-only "$MB" HEAD; git diff --name-only HEAD; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u )"

unit_of() { # deepest unit containing the file
  local f="$1" best="" u
  for u in $UNITS; do
    if [ "$u" = "." ] || [ "${f#"$u"/}" != "$f" ]; then
      [ ${#u} -gt ${#best} ] || [ -z "$best" ] && best="$u"
    fi
  done
  echo "$best"
}
related_of() { # units that list the file's folder as a related source
  local f="$1" u rel r
  for u in $UNITS; do
    rel="$(grep -h '^ERD_RELATED_SOURCES=' "$u/erd.env" 2>/dev/null | cut -d= -f2- | tr -d "'\"" | tr ',' ' ')"
    for r in $rel; do r="${r%/}"; [ -n "$r" ] && [ "${f#"$r"/}" != "$f" ] && echo "$u"; done
  done
}
classify() { # categorize by path relative to the unit
  local p="$1"
  case "$p" in
    docs/schema/*) echo docs;;
    *.dbml|erd.env|.tbls.yml|db/*|*migrations/*|*migrate/*|*alembic/*|*prisma/*|*schema.prisma|*/models/*|models/*|*/models.py|*/entity/*|*/entities/*|*schema.rb|*changelog*.xml|*changelog*.y*ml|*drizzle*|*/Migrations/*) echo schema;;
    *) echo other;;
  esac
}

# Records: "<unit>\t<category>\t<file>" (temp file instead of associative arrays: stock macOS bash 3.2)
REC="$(mktemp)"; trap 'rm -f "$REC"' EXIT
for f in $FILES; do
  u="$(unit_of "$f")"
  if [ -n "$u" ]; then
    p="$f"; [ "$u" != "." ] && p="${f#"$u"/}"
    printf '%s\t%s\t%s\n' "$u" "$(classify "$p")" "$f" >> "$REC"
  fi
  for r in $(related_of "$f"); do printf '%s\trelated\t%s\n' "$r" "$f" >> "$REC"; done
done
get() { awk -F'\t' -v u="$1" -v c="$2" '$1==u && $2==c {print $3}' "$REC" | tr '\n' ' '; }
has() { awk -F'\t' -v u="$1" '$1==u {f=1} END {exit !f}' "$REC"; }

cnt() { set -- $1; echo $#; }
case "$FMT" in
  names)
    for u in $UNITS; do [ -n "$(get "$u" schema)" ] && echo "$u"; done ;;
  json)
    jarr() { local first=1 x; printf '['; for x in $1; do [ $first = 1 ] || printf ','; first=0; printf '"%s"' "$(printf '%s' "$x" | sed 's/\\/\\\\/g; s/"/\\"/g')"; done; printf ']'; }
    printf '{"base":"%s","merge_base":"%s","units":[' "$BASE" "$MB"
    first=1
    for u in $UNITS; do
      has "$u" || continue
      [ $first = 1 ] || printf ','; first=0
      printf '{"unit":"%s","schema":%s,"docs":%s,"related":%s,"other":%s}' "$u" "$(jarr "$(get "$u" schema)")" "$(jarr "$(get "$u" docs)")" "$(jarr "$(get "$u" related)")" "$(jarr "$(get "$u" other)")"
    done
    printf ']}\n' ;;
  *)
    echo "# $(m "변경된 ERD 단위 (기준" "Changed ERD units (base"): $BASE, merge-base $(printf '%s' "$MB" | cut -c1-8))"
    any=0
    for u in $UNITS; do
      has "$u" || continue
      any=1; S="$(get "$u" schema)"; D="$(get "$u" docs)"; R="$(get "$u" related)"; O="$(get "$u" other)"
      echo "- $u   $(m "스키마" "schema") $(cnt "$S") · $(m "문서" "docs") $(cnt "$D") · $(m "관련소스" "related") $(cnt "$R") · $(m "기타" "other") $(cnt "$O")"
      for f in $S; do echo "    schema   $f"; done
      for f in $R; do echo "    related  $f"; done
      [ -n "$S" ] && [ -z "$D" ] && echo "    ⚠ $(m "스키마는 바뀌었는데 docs/schema 변경이 없음 → make erd P=$u 필요 가능성" "schema changed but docs/schema did not → probably needs make erd P=$u")"
    done
    [ $any = 0 ] && echo "- $(m "ERD 단위에 해당하는 변경 없음" "no changes in any ERD unit")"
    ;;
esac
exit 0
