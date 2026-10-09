---
name: doctor
description: >
  ERD 도구(tbls, @dbml/cli, Docker/psql) 점검·설치. 산출물: 점검표.
  트리거: "erd 도구 설치", "tbls 안 돼", "dbml2sql 없어" / "install erd tools".
  비활성: 프로젝트 세팅(→ init), make erd 실패 분석(→ sync).
argument-hint: "[install]"
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh)"
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/install-tools.sh *)"
---

# /erd:doctor — 도구 점검·설치

> **한 줄 정의**: ERD 스크립트가 돌아갈 환경을 만든다. 프로젝트 파일은 건드리지 않는다.

## 스킬 파일 (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `scripts/check-tools.sh` — 점검 (읽기 전용, 마지막 줄 `MISSING=<목록>`)
- `scripts/install-tools.sh <tbls|dbml|all>` — **설치 필수 헬퍼** (sudo 없이 현재 계정에 설치, macOS 는 brew 우선)
- `references/tbls-guide.md` — "공용 /tmp 문제" 해결 절차

## 현재 상태 (자동 점검 결과)

!`bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/check-tools.sh`

## 강제 규칙
1. 설치는 **반드시** `install-tools.sh` 로 한다. 설치 명령을 즉석에서 만들지 않는다 (이유: 전역 npm 권한 없음·PATH·아키텍처별 파일명을 스크립트가 처리).
2. 설치 전에 **계획을 보여 주고 확인**을 받는다. 인자 `install` 이 있으면 tbls·dbml 은 확인 없이 설치해도 된다.
3. sudo 가 필요한 것(Docker, psql, Node, libpam-tmpdir)은 **명령만 안내**하고 실행하지 않는다.

## 절차
1. 위 점검 결과를 ✅/⚠️/❌ 표로 요약한다 (설명은 짧게).
2. `MISSING=` 이 비어 있으면 "준비 완료" + 다음 단계 `/erd:init` 안내 후 종료.
3. 빠진 도구별 동작:

| 항목 | 동작 |
|---|---|
| `tbls`, `dbml2sql` | `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/install-tools.sh <tbls\|dbml\|all>` |
| `node` | 설치 방법만 안내 (예: nvm 으로 Node 22) — dbml 설치의 선행 조건 |
| Docker / psql | 둘 중 하나면 충분. Docker(임시 DB 자동) 또는 psql + 개발용 PostgreSQL 서버(`make erd PG=...`). 설치 명령만 안내 |
| `tbls-tmpdir` | `tbls-guide.md` "공용 /tmp 문제": 관리자 권한이 있으면 `libpam-tmpdir` + 재로그인, 없으면 "`make erd` 는 스크립트가 개인 TMPDIR 을 써서 동작함"을 알림 |

4. 설치 후 `check-tools.sh` 를 다시 실행해 결과를 확인한다.
5. `~/.local/bin` 이 PATH 에 없다는 경고가 나오면 셸별 명령을 안내한다 — bash/zsh: `export PATH="$HOME/.local/bin:$PATH"` (rc 파일), fish: `fish_add_path ~/.local/bin`.

## 에러 처리
| 상황 | 동작 |
|---|---|
| install-tools.sh 실패 (네트워크, npm 오류) | 출력 마지막 오류를 그대로 보고. 재시도는 한 번만 |
| 설치는 됐는데 `check-tools.sh` 에서 여전히 ❌ | PATH 문제. 5번 안내 |

## 체크리스트 (종료 전)
- [ ] 재점검 결과 `MISSING=` 이 비었거나, 남은 항목과 이유를 보고했다
- [ ] sudo 필요한 항목은 명령만 안내했다

## 관련 스킬
- `/erd:init` — 다음 단계: 프로젝트 세팅
- `/erd:sync` — 문서 생성이 실패할 때 (`ERD_EXIT` 코드 기준 대응)
