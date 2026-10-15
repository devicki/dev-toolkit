# teamwire

[English](README.md) · **한국어**

팀 작업을 실시간 배선도로 보여주는 **모드(mod)** 입니다. 팀장 세션이 일을 맡기면 `Team` 패널이 열리고, 팀원 구성, 각자 맡은 일, 쓰는 모델, 그리고 전류가 어디로 흐르는지를 보여줍니다. 팀원이 일하는 동안에는 팀원 쪽으로, 답이 기다리고 있으면 팀장 쪽으로 흐릅니다.

```
TEAMWIRE  4 members · 2 working · 1 reply · 0 needs you        lead: waiting on grok·p2

╭──────────╮
│ ◆ LEAD   ├┳━━━━━━━━━━━━━━━━━━━━━━━━▶ ● grok·p2              WORKING ⏳
│ opus 5.5 │┃                            herdr · grok · Grok 4.7 (xhigh)
╰─high─────╯┃                            Review the diff for bugs
            ┣◀┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅ ◉ Map callers          REPLY READY
            ┃                            subagent · Explore · haiku 5.5 · high
            ┃                            find every caller of parse()
            ┗────────────────────────── ○ grok·p3              IDLE
                                         herdr · grok · Grok 4.7 (xhigh)
                                         List the folders under plugins/

COMMS
lead → grok·p2  Review the diff for bugs  12s
```

화면 문구는 영어입니다.

## 보여주는 것

- **팀원**: 팀원마다 가지 하나. 이름, 상태 배지, `종류 · 에이전트 · 모델 · effort`, 맡은 일.
- **선 위의 전류**: 일하는 동안 팀장 → 팀원, 답을 아직 안 읽었으면 팀원 → 팀장으로 불꽃이 흐르고, 메시지나 지시가 오간 직후 몇 초간 강하게 흐릅니다.
- **상태**: `WORKING`, `REPLY READY`(끝났는데 팀장이 아직 안 읽음), `NEEDS YOU`(승인이나 질문 대기), `IDLE`, `DONE`, `FAILED`.
- **팀장**: 상자 안에 모델과 effort. 특정 팀원을 기다리는 동안 `lead: waiting on <팀원>`과 `⏳`.
- **COMMS**: 최근 지시·메시지 3개. `보낸 쪽 → 받는 쪽`, 첫 줄, 경과 시간.

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
| 서브에이전트, agent teams 팀원 | `agent.spawn`, `$.agent.list()`, `session.send` / `session.receive`. 모델과 effort는 매 모델 요청(`turn.step`)에서 | 없음 |
| 다른 Claude 세션 | 팀장의 SendMessage (`session.send`) | 없음 |
| herdr 패널의 CLI 에이전트 | 팀장이 실행한 `herdr agent prompt / send-keys / read / wait`. 상태는 2초마다 `herdr agent list`, 모델은 에이전트 화면 하단에서 한 번 읽음 | [herdr](https://herdr.dev) |

herdr가 없으면 외부 CLI 팀원만 빼고 모두 동작합니다.

## 설치

```
/plugin marketplace add devicki/dev-toolkit
/plugin install teamwire@dev-toolkit
```

처음 일을 맡기는 순간 패널이 자동으로 열립니다. 직접 닫으면 그 세션에서는 다시 자동으로 열리지 않고, `/teamwire`로 다시 열 수 있습니다.

## 알아둘 점

- **토큰을 쓰지 않습니다.** 훅은 Claude Code 안에서만 실행되고, 프롬프트나 대화에 아무것도 넣지 않습니다. 드는 비용은 로컬 자원뿐입니다. herdr 팀원이 있을 때 2초마다 `herdr agent list` 한 번, 전류가 흐르는 동안 초당 약 7번 다시 그리기.
- 패널이 자동으로 열리려면 터미널 폭이 144칸 이상이어야 합니다(한 번 직접 연 뒤에는 110칸).
- 모드는 Claude Code 안에서 사용자 권한으로 실행되며 샌드박스가 없습니다. teamwire가 실행하는 명령은 `herdr`뿐입니다.
- 조직이 관리하는 Claude Code에서는 직접 설치한 플러그인에 이 이벤트들이 전달되지 않을 수 있습니다.
- 알려진 한계: 변수나 스크립트로 감싼 herdr 호출은 감지하지 못합니다. CLI 모델은 지금의 화면 하단 문구를 기준으로 읽습니다. 팀원끼리 주고받는 메시지는 별도 선 없이 양쪽 선이 함께 반짝입니다.

## 개발

```bash
claude plugin validate plugins/teamwire
claude plugin test plugins/teamwire
claude --plugin-dir plugins/teamwire   # 이 플러그인만 로드해서 실행
```

서브에이전트와 agent teams를 트리로 보여주는 [swarm](https://github.com/OneWave-AI/claude-code-mods)(MIT)에서 아이디어를 얻었습니다.
