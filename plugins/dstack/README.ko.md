# dstack

[English](README.md) · **한국어**

[pstack](https://github.com/cursor/plugins/tree/main/pstack) 위에 얹은 devicki의 에이전트 작업 방식입니다. Claude가 지휘하고, [herdr](https://herdr.dev) 탭의 Grok CLI 세션이 위임받은 작업을 합니다.

## 스킬

| 명령 | 용도 |
|---|---|
| `/dstack:devicki-mode` | 작업을 poteto-mode(pstack)로 진행하되, grok 역할은 모두 herdr의 grok 탭에서 돌립니다. 직접 입력할 때만 동작합니다. |
| `/dstack:herdr-grok-delegate` | 작업을 전용 herdr 탭(`grok:<이름>`)의 grok에 넘기고, 보고서를 기다린 뒤 diff를 검토합니다. "grok한테 넘겨줘"로도 동작합니다. |

## 위임 흐름

1. Claude가 grok이 혼자 읽어도 되는 지시문을 파일로 씁니다.
2. `delegate.py`가 `grok:<이름>` 탭을 열고 `grok --always-approve`를 띄웁니다. 같은 이름의 grok이 살아 있으면 그대로 다시 씁니다.
3. grok이 지시문을 읽고 `GROK_DONE`으로 끝나는 보고서를 씁니다. 백그라운드 실행이 끝나면 Claude가 알림을 받습니다.
4. Claude가 보고서를 읽고, `git diff`를 확인하고, 검증 명령을 직접 다시 돌린 뒤 자기 판단으로 답합니다.

[teamwire](../teamwire)를 설치해 두면 각 grok이 Team 패널에도 표시됩니다.

## 필요 조건

- `devicki-mode`용 [pstack](https://github.com/cursor/plugins/tree/main/pstack) (`/plugin marketplace add cursor/plugins`, `/plugin install pstack@cursor-plugins`)
- herdr 페인 안에서 실행 중인 Claude Code (`HERDR_ENV=1`)
- `PATH`에 `grok` CLI

## 개발

- 테스트: `plugins/dstack/tests/run.sh` (가짜 herdr 사용, 실제 세션은 건드리지 않음)
- 저장소 검증: `python3 scripts/validate.py`
- 작성 규칙: [docs/skill-authoring.md](../../docs/skill-authoring.md)
