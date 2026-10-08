#!/usr/bin/env bash
# ERD 작업에 필요한 도구 설치·동작 여부를 점검한다. (변경 없음, 항상 exit 0)
# 출력: 사람이 읽기 좋은 표 + 마지막 줄에 MISSING=<쉼표 목록>
set -u

ok()   { printf '  ✅ %-12s %s\n' "$1" "$2"; }
warn() { printf '  ⚠️  %-12s %s\n' "$1" "$2"; }
miss() { printf '  ❌ %-12s %s\n' "$1" "$2"; MISSING+=("$1"); }
MISSING=()

echo "## 환경"
echo "  OS: $(uname -s) $(uname -m)   SHELL: ${SHELL:-?}   TMPDIR: ${TMPDIR:-(미설정)}"
echo
echo "## 필수 도구"

# dbml2sql (@dbml/cli)
if command -v dbml2sql >/dev/null 2>&1; then
  ok dbml2sql "$(dbml2sql --version 2>/dev/null | head -1) (@dbml/cli)"
else
  miss dbml2sql "@dbml/cli 미설치 → npm install -g @dbml/cli"
fi

# tbls (설치 + 실제 실행 가능 여부)
if command -v tbls >/dev/null 2>&1; then
  out=$(tbls version 2>&1); rc=$?
  if [ $rc -eq 0 ]; then
    ok tbls "$out ($(command -v tbls))"
  elif printf '%s' "$out" | grep -q 'go-graphviz.*permission denied'; then
    warn tbls "설치됨, 그러나 /tmp/go-graphviz 권한 오류 (다른 계정이 먼저 실행함)"
    echo "               해결: 계정별 TMPDIR 사용 (references/tbls-guide.md '공용 /tmp 문제')"
    MISSING+=("tbls-tmpdir")
  else
    warn tbls "설치됨, 실행 오류: $(printf '%s' "$out" | head -1)"
  fi
else
  miss tbls "미설치"
fi

# node/npm (dbml 설치용)
if command -v node >/dev/null 2>&1; then
  ok node "$(node -v)"
else
  miss node "Node.js 미설치 (@dbml/cli 설치에 필요, 18 이상)"
fi

echo
echo "## 임시 DB (둘 중 하나 필요)"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  ok docker "사용 가능"
elif command -v docker >/dev/null 2>&1; then
  warn docker "설치됨, 데몬 접근 불가 (권한: sudo usermod -aG docker \$USER 후 재로그인)"
else
  warn docker "미설치"
fi
if command -v psql >/dev/null 2>&1; then
  ok psql "$(psql --version 2>/dev/null | head -1) → 기존 PostgreSQL 서버 사용 가능 (PG=...)"
else
  warn psql "미설치 (기존 서버를 쓰려면 postgresql-client 필요)"
fi
if command -v mysql >/dev/null 2>&1; then
  ok mysql "$(mysql --version 2>/dev/null | head -1)"
fi

echo
echo "## 선택 도구"
for t in glow atlas; do
  if command -v $t >/dev/null 2>&1; then ok $t "설치됨"; else printf '  ·  %-12s %s\n' "$t" "미설치 (선택)"; fi
done

echo
IFS=,; echo "MISSING=${MISSING[*]:-}"
exit 0
