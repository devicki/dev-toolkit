#!/usr/bin/env bash
# 새 플러그인 스캐폴드: templates/plugin 을 복사하고 marketplace.json 에 등록한다.
# 사용법: scripts/new-plugin.sh <플러그인 이름> [--skill <첫 스킬 이름>] [--desc "<설명>"]
#   이름 규칙: 소문자·숫자·하이픈 (예: api-spec). 이미 있으면 중단한다.
# 끝나면 scripts/validate.py 를 실행해 구조를 확인한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-}"; shift || true
SKILL="main" DESC="<한 줄 설명>"
while [ $# -gt 0 ]; do case "$1" in --skill) SKILL="$2"; shift 2;; --desc) DESC="$2"; shift 2;; *) echo "알 수 없는 인자: $1" >&2; exit 2;; esac; done
re='^[a-z0-9][a-z0-9-]*$'
[[ "$NAME" =~ $re ]] || { echo "사용법: $0 <플러그인 이름(소문자·숫자·-)> [--skill <이름>] [--desc <설명>]" >&2; exit 2; }
[[ "$SKILL" =~ $re ]] || { echo "✘ 스킬 이름은 소문자·숫자·-" >&2; exit 2; }
DST="$ROOT/plugins/$NAME"
[ -e "$DST" ] && { echo "✘ 이미 있음: plugins/$NAME" >&2; exit 2; }

cp -R "$ROOT/templates/plugin" "$DST"
mv "$DST/skills/__SKILL__" "$DST/skills/$SKILL"
# 자리표시자 치환 (설명에 / & | 가 있어도 안전하게 python 으로)
python3 - "$DST" "$NAME" "$SKILL" "$DESC" <<'PY'
import sys, pathlib
dst, name, skill, desc = sys.argv[1:]
for p in pathlib.Path(dst).rglob("*"):
    if p.is_file():
        t = p.read_text(encoding="utf-8")
        n = t.replace("__NAME__", name).replace("__SKILL__", skill).replace("__DESC__", desc)
        if n != t:
            p.write_text(n, encoding="utf-8")
PY
python3 - "$ROOT/.claude-plugin/marketplace.json" "$NAME" "$DESC" <<'PY'
import sys, json
path, name, desc = sys.argv[1:]
m = json.load(open(path, encoding="utf-8"))
if any(p.get("name") == name for p in m["plugins"]):
    sys.exit(f"✘ marketplace.json 에 이미 {name} 이 있음")
m["plugins"].append({"name": name, "source": f"./plugins/{name}", "description": desc})
open(path, "w", encoding="utf-8").write(json.dumps(m, ensure_ascii=False, indent=2) + "\n")
PY
find "$DST" -name '*.sh' -exec chmod +x {} +
echo "+ plugins/$NAME (스킬: $SKILL)"
echo "+ marketplace.json 등록"
echo "다음: skills/$SKILL/SKILL.md 와 shared/references/rules.md 를 채우고, README 의 스킬 표·루트 README 의 플러그인 표를 갱신하세요."
python3 "$ROOT/scripts/validate.py" || true
