# teamwire

[English](README.md) · **한국어** · [日本語](README.ja.md) · [繁體中文](README.zh-TW.md)

팀 작업을 실시간 배선도로 보여주는 **모드(mod)** 입니다. 팀장 세션이 일을 맡기면 `Team` 패널이 열리고, 팀원 구성, 각자 맡은 일, 쓰는 모델, 그리고 전류가 어디로 흐르는지를 보여줍니다. 팀원이 일하는 동안에는 팀원 쪽으로, 답이 기다리고 있으면 팀장 쪽으로 흐릅니다.

![teamwire 패널](../../docs/images/teamwire.png)

화면 문구는 영어입니다.

## 보여주는 것

- **대시보드**: 팀장 상태 칩, TEAM / WORKING / REPLY / NEEDS YOU / DONE / UPTIME 타일, 바쁜 비율 막대, 그리고 팀장의 **context 사용량**(`38% · 376k / 1M tokens`)과 세션 비용. 60% 미만 초록, 60% 이상 주황, 85% 이상 빨강.
- **ORCHESTRATION**: 팀장을 가운데 둔 둥근 부채꼴 배선. 팀원마다 이름, 상태 배지, `종류 · 에이전트 · 모델 · effort`, 경과 시간·도구 호출 수·출력 토큰, 맡은 일. 팀장 상자에는 모델, context 게이지, effort.
- **선 위의 전류**: 일하는 동안 팀장 → 팀원, 답을 아직 안 읽었으면 팀원 → 팀장으로 흐르고, 메시지나 지시가 오간 직후 몇 초간 강하게 흐릅니다. 5분 넘게 안 읽은 답은 **stale**(`REPLY · 7m`)로 바뀌고 흐름이 멈춥니다.
- **일하는 이름**: 일하는 팀원의 이름과, 팀장이 일하는 동안 `◆ LEAD` 위로 빛이 지나갑니다.
- **팀원끼리**: 두 팀원이 메시지를 주고받으면 오른쪽 레일이 몇 초간 두 줄을 이어 줍니다. 화살표는 받는 쪽.
- **FOCUS**: 팀원 이름(또는 번호 `1`~`9`)을 누르면 맡은 일 전체, 모델, 시간, 사용량, 최근 메시지를 펼칩니다. 다시 누르면 닫힙니다.
- **ACTIVITY**: 합류, 작업 시작, `finished in 34s · reply ready`, `done`, `failed`, `needs you`, `answer read by lead`, 마지막 팀원이 끝나면 `team stood down · 4 members · 3m 20s`.
- **COMMS**: 최근 지시·메시지. `보낸 쪽 → 받는 쪽`, 첫 줄, 경과 시간.
- **알림**: 팀원이 승인이나 답을 기다리면 토스트와 데스크톱 알림(설정한 알림 채널), 답이 준비되거나 실패했을 때, 팀 작업이 끝났을 때 토스트.
- **상태줄**: 패널을 닫았거나 그려지지 않을 때 프롬프트 아래 한 줄로 요약합니다. `◆ team 2 working · 1 reply · ctx 38% · /teamwire`
- **상태**: `WORKING`, `REPLY READY`(끝났는데 아직 안 읽음), `NEEDS YOU`(승인이나 질문 대기. 서브에이전트의 도구 호출이 승인을 기다릴 때 포함), `IDLE`, `DONE`, `FAILED`.

팀원 종류마다 선 모양이 다릅니다.

| 종류 | 대기 | 흐를 때 |
|---|---|---|
| subagent | `┄┄┄` | `┅┅┅` |
| teammate (agent teams) | `═══` 흐림 | `═══` 밝음 |
| herdr (codex, grok 등) | `───` | `━━━` |
| session (다른 Claude 세션) | `┈┈┈` | `┉┉┉` |

## 데이터를 받는 곳

| 팀원 | 출처 | 필요한 것 |
|---|---|---|
| 서브에이전트, agent teams 팀원 | `agent.spawn`, `$.agent.list()`, `session.send` / `session.receive`. 모델과 effort는 매 모델 요청(`turn.step`), 승인 대기는 `tool.check`, 도구 호출 수와 토큰은 `tool.call` / `turn.complete`에서 | 없음 |
| 팀장 | `session.measure`(context, 비용), `turn.start` / `turn.complete` | 없음 |
| 다른 Claude 세션 | 팀장의 SendMessage (`session.send`). 상태는 2초마다 각 세션의 상태 파일(`~/.claude/sessions/*.json`, 읽기만)에서: 작업 중, 승인·질문 대기, 대기, 종료 | 없음 |
| herdr 패널의 CLI 에이전트 | 팀장이 실행한 `herdr agent prompt / send-keys / read / wait`. 상태는 2초마다 `herdr agent list`, 모델은 에이전트 화면 하단에서 한 번 읽음 | [herdr](https://herdr.dev) |

herdr가 없으면 외부 CLI 팀원만 빼고 모두 동작합니다.

## 설치

```
/plugin marketplace add devicki/dev-toolkit
/plugin install teamwire@dev-toolkit
```

처음 일을 맡기는 순간 패널이 자동으로 열립니다. 직접 닫으면 그 세션에서는 다시 자동으로 열리지 않고, `/teamwire`로 다시 열 수 있습니다.

## 알아둘 점

- **토큰을 쓰지 않습니다.** 훅은 Claude Code 안에서만 실행되고, 프롬프트나 대화에 아무것도 넣지 않습니다. 드는 비용은 로컬 자원뿐입니다. herdr 팀원이 있을 때 2초마다 `herdr agent list` 한 번, 전류가 흐르거나 누군가 일하는 동안 초당 약 7번 다시 그리기.
- 단축키(`c`, `l`, `1`~`9`)는 패널에 포커스가 있을 때 동작합니다. 패널을 클릭하거나 ctrl+x tab.
- 패널이 자동으로 열리려면 터미널 폭이 144칸 이상이어야 합니다(한 번 직접 연 뒤에는 110칸).
- 패널이 낮으면 대시보드와 배선도를 남기고 COMMS, ACTIVITY, FOCUS 순으로 뺍니다. 뺀 섹션은 단축키 옆 한 줄에 적습니다(`+ ACTIVITY 6 · COMMS 3 hidden`). 패널을 키우면 다시 보입니다. 긴 문장은 패널 끝에서 `…`로 자르고, 맡긴 일 전체는 FOCUS에서 봅니다.
- 모드는 Claude Code 안에서 사용자 권한으로 실행되며 샌드박스가 없습니다. teamwire가 실행하는 명령은 `herdr`뿐이고, 파일은 쓰지 않습니다. 다른 세션의 상태 파일은 읽기만 합니다.
- 조직이 관리하는 Claude Code에서는 직접 설치한 플러그인에 이 이벤트들이 전달되지 않을 수 있습니다.
- 알려진 한계: 변수로 대상을 받는 herdr 호출(셸 함수, 반복문)은 명령에 적힌 패널 번호로 팀원을 찾으며, 파일에서 불러온 스크립트 안의 호출은 감지하지 못합니다. CLI 모델은 지금의 화면 하단 문구를 기준으로 읽습니다. 다른 세션의 상태는 Claude Code 내부 상태 파일에서 읽으므로, 그 형식이 바뀌면 해당 팀원은 마지막 상태에 머뭅니다. 팀원끼리 주고받는 메시지는 별도 선 없이 양쪽 선이 함께 반짝입니다.

## 개발

```bash
claude plugin validate plugins/teamwire
claude plugin test plugins/teamwire
claude --plugin-dir plugins/teamwire   # 이 플러그인만 로드해서 실행
```

서브에이전트와 agent teams를 트리로 보여주는 [swarm](https://github.com/OneWave-AI/claude-code-mods)(MIT)에서 아이디어를 얻었습니다.
