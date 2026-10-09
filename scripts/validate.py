#!/usr/bin/env python3
"""dev-toolkit 마켓플레이스 구조 검증 (표준 라이브러리만 사용).

`claude plugin validate` 가 보지 않는 저장소 규칙을 검사한다. pre-commit / CI 용.

사용법: python3 scripts/validate.py [--base <git ref>] [--strict]
  --base   : 이 ref 대비 내용이 바뀐 플러그인의 version 이 그대로면 경고 (예: origin/main)
  --strict : 경고도 실패로 처리

종료 코드: 0 통과 | 1 오류(또는 --strict 에서 경고) | 2 실행 오류
"""
from __future__ import annotations

import argparse
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESC_MAX = 1024          # description 권장 상한 (목록에서 1,536자에서 잘림)
SKILL_MD_MAX_LINES = 500 # SKILL.md 권장 상한 (자세한 내용은 참고 문서로)

errors: list[str] = []
warnings: list[str] = []
checks = 0


def check(ok: bool, msg: str, level: str = "error") -> bool:
    global checks
    checks += 1
    if not ok:
        (errors if level == "error" else warnings).append(msg)
    return ok


def load_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        check(False, f"{rel(path)}: 파일 없음")
    except json.JSONDecodeError as e:
        check(False, f"{rel(path)}: JSON 문법 오류 ({e})")
    return None


def rel(p: Path) -> str:
    try:
        return str(p.relative_to(ROOT))
    except ValueError:
        return str(p)


def frontmatter(text: str) -> dict[str, str] | None:
    """간단한 YAML frontmatter 파서: 최상위 키와 (접힌) 문자열 값만 읽는다."""
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    out: dict[str, str] = {}
    key = None
    for line in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if km:
            key, val = km.group(1), km.group(2).strip()
            out[key] = "" if val in (">", "|", ">-", "|-") else val.strip("'\"")
        elif key and line.startswith("  "):
            out[key] = (out[key] + " " + line.strip()).strip()
    return out


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout


def validate_plugin(entry: dict, base: str | None) -> None:
    name = entry.get("name", "")
    src = entry.get("source")
    if not isinstance(src, str):
        return  # 원격 소스(github 등)는 이 스크립트 범위 밖
    pdir = (ROOT / src).resolve()
    if not check(pdir.is_dir(), f"plugins[{name}]: source 경로 없음 ({src})"):
        return
    check(".." not in Path(src).parts, f"plugins[{name}]: source 에 '..' 사용 금지")

    manifest = load_json(pdir / ".claude-plugin" / "plugin.json")
    if manifest:
        for field in ("name", "version", "description"):
            check(bool(manifest.get(field)), f"{name}/plugin.json: '{field}' 필수")
        check(bool((manifest.get("author") or {}).get("name")), f"{name}/plugin.json: 'author.name' 필수")
        check(manifest.get("name") == name, f"{name}: marketplace 항목 이름과 plugin.json name 이 다름 ({manifest.get('name')})")
        check(re.fullmatch(r"\d+\.\d+\.\d+([-+].*)?", str(manifest.get("version", ""))) is not None,
              f"{name}/plugin.json: version 은 SemVer (예: 0.3.0)")
        if "keywords" in manifest:
            check(isinstance(manifest["keywords"], list), f"{name}/plugin.json: keywords 는 배열")
        allowed = {"name", "version", "description", "author", "homepage", "repository", "license",
                   "keywords", "commands", "agents", "skills", "hooks", "mcpServers", "lspServers",
                   "outputStyles", "userConfig", "dependencies"}
        extra = set(manifest) - allowed
        check(not extra, f"{name}/plugin.json: 비표준 키 {sorted(extra)} — 공식 스키마 필드만 사용", "warning")

    for doc in ("README.md", "CHANGELOG.md"):
        check((pdir / doc).is_file(), f"{name}: {doc} 없음")

    skills_dir = pdir / "skills"
    skills = sorted(skills_dir.glob("*/SKILL.md")) if skills_dir.is_dir() else []
    check(bool(skills) or (pdir / "commands").is_dir() or (pdir / "agents").is_dir(),
          f"{name}: skills/commands/agents 중 하나는 있어야 함")
    for sk in skills:
        text = sk.read_text(encoding="utf-8")
        fm = frontmatter(text)
        label = rel(sk)
        if not check(fm is not None, f"{label}: frontmatter 없음"):
            continue
        check(bool(fm.get("name")), f"{label}: frontmatter 'name' 필수")
        check(fm.get("name") == sk.parent.name, f"{label}: name 이 폴더 이름과 다름 ({fm.get('name')})", "warning")
        desc = fm.get("description", "")
        check(bool(desc), f"{label}: frontmatter 'description' 필수")
        check(len(desc) <= DESC_MAX, f"{label}: description {len(desc)}자 > {DESC_MAX} (상시 토큰 비용·잘림)", "warning")
        check("비활성" in desc or "not for" in desc.lower() or "→" in desc,
              f"{label}: description 에 비활성 조건(언제 쓰지 않는지·대신 쓸 스킬) 권장", "warning")
        n = text.count("\n")
        check(n <= SKILL_MD_MAX_LINES, f"{label}: {n}줄 > {SKILL_MD_MAX_LINES} — 참고 문서로 분리 권장", "warning")
        # 경로 규칙: 플러그인 루트의 공용 파일은 ${CLAUDE_PLUGIN_ROOT} 로, 상위(..) 경로 금지
        for m in re.finditer(r"(?<![\w}/$])(shared|scripts)/[\w./-]+", text):
            pre = text[max(0, m.start() - 25):m.start()]
            if "CLAUDE_PLUGIN_ROOT" in pre or "CLAUDE_SKILL_DIR" in pre:
                continue
            # 프로젝트 쪽 scripts/ (예: scripts/erd-doc.sh) 언급은 허용, 플러그인 shared/ 는 변수 필수
            if m.group(1) == "shared":
                check(False, f"{label}: '{m.group(0)}' — 플러그인 공용 파일은 ${{CLAUDE_PLUGIN_ROOT}}/ 로 참조", "warning")
                break

    # 셸 스크립트 실행 권한
    for sh in pdir.rglob("*.sh"):
        mode = sh.stat().st_mode
        check(bool(mode & stat.S_IXUSR), f"{rel(sh)}: 실행 권한 없음 (chmod +x)", "warning")

    # 버전 올림 확인 (선택)
    if base and manifest:
        changed = git("diff", "--name-only", f"{base}...HEAD", "--", str(pdir.relative_to(ROOT))).split()
        changed += git("diff", "--name-only", "HEAD", "--", str(pdir.relative_to(ROOT))).split()
        changed = [c for c in changed if not c.endswith(("README.md", "CHANGELOG.md")) and "/tests/" not in c]
        if changed:
            old = git("show", f"{base}:{pdir.relative_to(ROOT)}/.claude-plugin/plugin.json")
            try:
                old_ver = json.loads(old).get("version") if old else None
            except json.JSONDecodeError:
                old_ver = None
            check(old_ver is None or old_ver != manifest.get("version"),
                  f"{name}: 내용이 바뀌었는데 version 이 그대로 ({old_ver}) — 사용자에게 업데이트가 전달되지 않음", "warning")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base")
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    market = load_json(ROOT / ".claude-plugin" / "marketplace.json")
    if market:
        for field in ("name", "owner", "plugins"):
            check(field in market, f"marketplace.json: '{field}' 필수")
        names = [p.get("name") for p in market.get("plugins", [])]
        check(len(names) == len(set(names)), f"marketplace.json: 플러그인 이름 중복 {names}")
        for entry in market.get("plugins", []):
            check(bool(entry.get("name")) and " " not in entry.get("name", ""), f"marketplace.json: 잘못된 플러그인 이름 {entry.get('name')!r}")
            check(bool(entry.get("description")), f"marketplace.json: {entry.get('name')} description 권장", "warning")
            validate_plugin(entry, args.base)
        listed = {Path(e["source"]).name for e in market.get("plugins", []) if isinstance(e.get("source"), str)}
        for d in sorted((ROOT / "plugins").glob("*/")):
            check(d.name in listed, f"plugins/{d.name}: marketplace.json 에 등록되지 않음")
    for doc in ("README.md",):
        check((ROOT / doc).is_file(), f"{doc} 없음 (저장소 루트)")

    for e in errors:
        print(f"FAIL  {e}")
    for w in warnings:
        print(f"WARN  {w}")
    print(f"\n{checks}개 검사, 오류 {len(errors)}, 경고 {len(warnings)}")
    return 1 if errors or (args.strict and warnings) else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001
        print(f"실행 오류: {e}", file=sys.stderr)
        sys.exit(2)
