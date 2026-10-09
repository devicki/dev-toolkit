#!/usr/bin/env bash
# (erd 플러그인이 프로젝트 scripts/ 에 설치. 플러그인 원본: shared/templates/scripts/erd-changed.sh)
# 기준 브랜치 대비 바뀐 파일을 ERD 단위별로 묶는다. (읽기 전용)
# 사용법: scripts/erd-changed.sh [--base <ref>] [--json] [--names] [레포 경로]
#   --base  : 비교 기준. 기본은 원격 기본 브랜치(origin/HEAD → origin/main → origin/master → main)
#             로컬 브랜치는 원격과 어긋날 수 있어 원격 기준을 우선한다.
#   --names : 스키마 관련 변경이 있는 단위 경로만 한 줄씩 (make erd-check-changed 용)
#   --json  : 기계용 출력
# 대상 변경 = 기준 대비 커밋된 변경 + 커밋 안 한 변경 + 추적 안 하는 새 파일
# 분류: schema(스키마 원본·설정), docs(docs/schema 생성물), related(ERD_RELATED_SOURCES 폴더), other
# 종료 코드: 0 성공 | 2 git 저장소 아님·기준 ref 없음
set -u
set -f
BASE="" FMT=text DIR="."
while [ $# -gt 0 ]; do
  case "$1" in --base) BASE="$2"; shift 2;; --json) FMT=json; shift;; --names) FMT=names; shift;; *) DIR="$1"; shift;; esac
done
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)" || { echo "✘ git 저장소가 아닙니다: $DIR" >&2; exit 2; }
cd "$ROOT"
if [ -z "$BASE" ]; then
  for r in "$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" origin/main origin/master main master; do
    [ -n "$r" ] && git rev-parse -q --verify "$r^{commit}" >/dev/null 2>&1 && { BASE="$r"; break; }
  done
fi
[ -n "$BASE" ] && git rev-parse -q --verify "$BASE^{commit}" >/dev/null 2>&1 || { echo "✘ 기준 ref 를 찾을 수 없습니다: ${BASE:-(자동 탐지 실패)} — --base 로 지정하세요" >&2; exit 2; }
MB="$(git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")"

FILES="$( { git diff --name-only "$MB" HEAD; git diff --name-only HEAD; git ls-files --others --exclude-standard; } 2>/dev/null | sort -u )"
UNITS="$(git ls-files --cached --others --exclude-standard 2>/dev/null | grep -E '(^|/)erd\.env$' | sed -E 's#/?erd\.env$##; s#^$#.#' | sort -u)"

unit_of() { # 파일이 속한 가장 깊은 단위
  local f="$1" best="" u
  for u in $UNITS; do
    if [ "$u" = "." ] || [ "${f#"$u"/}" != "$f" ]; then
      [ ${#u} -gt ${#best} ] || [ -z "$best" ] && best="$u"
    fi
  done
  echo "$best"
}
related_of() { # 파일을 관련 소스로 둔 단위들
  local f="$1" u rel r
  for u in $UNITS; do
    rel="$(grep -h '^ERD_RELATED_SOURCES=' "$u/erd.env" 2>/dev/null | cut -d= -f2- | tr -d "'\"" | tr ',' ' ')"
    for r in $rel; do r="${r%/}"; [ -n "$r" ] && [ "${f#"$r"/}" != "$f" ] && echo "$u"; done
  done
}
classify() { # 단위 기준 상대 경로로 분류
  local p="$1"
  case "$p" in
    docs/schema/*) echo docs;;
    *.dbml|erd.env|.tbls.yml|db/*|*migrations/*|*migrate/*|*alembic/*|*prisma/*|*schema.prisma|*/models/*|models/*|*/models.py|*/entity/*|*/entities/*|*schema.rb|*changelog*.xml|*changelog*.y*ml|*drizzle*|*/Migrations/*) echo schema;;
    *) echo other;;
  esac
}

# 기록: "<단위>\t<분류>\t<파일>" (macOS 기본 bash 3.2 호환을 위해 연관 배열 대신 임시 파일)
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
    echo "# 변경된 ERD 단위 (기준: $BASE, merge-base $(printf '%s' "$MB" | cut -c1-8))"
    any=0
    for u in $UNITS; do
      has "$u" || continue
      any=1; S="$(get "$u" schema)"; D="$(get "$u" docs)"; R="$(get "$u" related)"; O="$(get "$u" other)"
      echo "- $u   스키마 $(cnt "$S") · 문서 $(cnt "$D") · 관련소스 $(cnt "$R") · 기타 $(cnt "$O")"
      for f in $S; do echo "    schema   $f"; done
      for f in $R; do echo "    related  $f"; done
      [ -n "$S" ] && [ -z "$D" ] && echo "    ⚠ 스키마는 바뀌었는데 docs/schema 변경이 없음 → make erd P=$u 필요 가능성"
    done
    [ $any = 0 ] && echo "- ERD 단위에 해당하는 변경 없음"
    ;;
esac
exit 0
