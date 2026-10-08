---
name: doctor
description: ERD 작업 도구(tbls, @dbml/cli, Docker/psql 등) 설치·동작 여부를 점검하고, 사용자 확인 후 없는 도구를 설치한다. "erd 도구 설치", "tbls 안 돼", "dbml2sql 없음", /erd:init 전 환경 점검에 사용.
argument-hint: "[install]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh)
---

# /erd:doctor — 도구 점검·설치

## 현재 상태 (자동 점검 결과)

!`bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh`

## 할 일

1. 위 결과를 사용자에게 짧은 표로 요약한다 (✅/⚠️/❌ 만, 장황한 설명 없이).
2. `MISSING=` 이 비어 있으면 "준비 완료"라고 말하고 끝낸다. 다음 단계로 `/erd:init` 을 안내한다.
3. 빠진 도구가 있으면 **설치 계획을 보여 주고 확인을 받은 뒤** 설치한다. 확인 없이 설치하지 않는다.
   - 설치 스크립트: `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/install-tools.sh <tbls|dbml|all>`
     - tbls → `~/.local/bin/tbls` (sudo 불필요, macOS 는 brew 우선)
     - dbml → `npm install -g @dbml/cli` (전역 권한 없으면 `~/.local`)
   - `node` 가 없으면 직접 설치하지 말고 방법만 안내한다 (예: nvm 으로 Node 22).
   - Docker/psql 은 시스템 패키지라 sudo 가 필요하다. 명령만 안내하고 사용자가 실행하게 한다.
     - 둘 중 하나만 있으면 된다: Docker(임시 DB 자동 실행) 또는 psql + 접근 가능한 PostgreSQL 서버(`make erd PG=...`).
4. `tbls-tmpdir` 이 있으면 (공용 `/tmp/go-graphviz` 권한 문제) `${CLAUDE_PLUGIN_ROOT}/shared/references/tbls-guide.md` 의 "공용 /tmp 문제" 절차를 안내한다.
   - 서버 관리자 권한이 있으면 `libpam-tmpdir` 설치 + 재로그인을 권장.
   - 없으면 프로젝트 스크립트(`scripts/erd-doc.sh`)가 자동으로 개인 TMPDIR 을 쓰므로 `make erd` 는 동작한다고 알려 준다.
5. 설치 후 `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh` 를 다시 실행해 결과를 확인한다.
6. 설치 경로(`~/.local/bin`)가 PATH 에 없다는 경고가 나오면 사용자의 셸에 맞는 명령을 안내한다.
   - bash/zsh: `export PATH="$HOME/.local/bin:$PATH"` 를 rc 파일에
   - fish: `fish_add_path ~/.local/bin`

인자로 `install` 이 주어지면 3단계에서 확인 질문 없이 tbls·dbml 을 설치해도 된다 (사용자가 명시적으로 요청한 것).
