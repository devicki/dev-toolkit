# teamwire 플러그인 변경 이력

## 0.1.14
- 한 명령 안에서 brief를 here-document로 쓰고(`cat > f <<'EOF' … EOF`) 바로 `delegate.py run`이나 `herdr agent prompt`를 실행하면 팀원이 안 잡히던 문제 수정(0.1.13 실사용 확인에서 발견): 본문의 작은따옴표(`lead's`)가 따옴표 시작으로 읽혀 뒤의 명령까지 삼켰음. 이제 명령을 나누기 전에 here-document 본문을 빼고 읽음

## 0.1.13
- grok 팀원이 직접 부른 서브에이전트도 팀원으로 표시: grok이 서브에이전트마다 남기는 `~/.grok/sessions/<cwd>/<세션>/subagents/<id>/meta.json`(시작할 때 `running`, 끝나면 `completed`)을 2초마다 읽음. 세션 id는 `herdr agent list`의 `agent_session`(herdr의 grok 연동이 알려 줌). 이름은 서브에이전트 설명, 종류 `subagent · grok`, 모델과 도구 호출 수 표시. 생길 때 부모 grok에서 연결선과 메시지가 이어짐. 팀장이 일을 맡기기 전에 같은 grok이 부른 서브에이전트는 제외. `GROK_HOME`이 있으면 그 아래를 읽음

## 0.1.12
- dstack `delegate.py run`을 백그라운드로 돌리면 grok 팀원이 1초 만에 DONE이 되고 그 뒤로 상태를 따라가지 않던 문제 수정(0.1.11 실사용 확인에서 발견): 호출 직후 조회 때 grok이 아직 `herdr agent list`에 없어서 사라진 것으로 봤음. 이제 목록에서 한 번도 못 본 팀원은 일을 맡긴 뒤 2분 동안 시작 중으로 보고 상태를 유지

## 0.1.11
- dstack `delegate.py`로 grok에 일을 맡기면 팀원이 하나도 안 잡히던 문제 수정: herdr 호출이 Python 안에서 일어나 명령에 `herdr`가 없었음. 이제 `delegate.py run`은 일 맡김(역할은 `--brief` 파일의 첫 줄, 못 읽으면 `delegate: <이름>`), `wait`는 기다림, `close`는 완료로 표시. 팀원 이름은 `--name`. `D=…/delegate.py; python3 $D …`처럼 명령 안에서 정한 변수와 `for n in 1 2 3 4`(또는 `{1..4}`) 반복문의 이름도 풀어서, 알 수 없는 이름(`$(…)`, 정하지 않은 변수)은 가짜 팀원을 만들지 않고 건너뜀
- Bash를 `run_in_background`로 돌린 herdr 호출은 팀장을 기다림 상태로 두지 않음

## 0.1.10
- 에이전트가 없는 셸 패널에 글자를 입력한 것(`herdr pane send-text wQ:p2 'n'`로 업그레이드 y/n 질문에 답하기)을 일 맡김으로 보고 팀원으로 연결하던 문제 수정: `pane send-text`/`pane run`은 `herdr agent list`에 에이전트가 있는 패널일 때만 팀원으로 연결

## 0.1.9
- 팀장이 셸 함수나 반복문으로 herdr 패널에 일을 맡길 때(`ask() { herdr agent prompt "$1" "$2"; }; ask pG "…"`, `for p in pG pS; do herdr agent prompt "$p" …`) 이름이 `$1`, 일이 `$2`인 가짜 팀원 하나만 생기고 실제 팀원은 빠지던 문제 수정: 대상이 변수이면 명령에 적힌 패널 번호마다 팀원을 하나씩 연결하고, 패널 번호 다음 인자를 맡긴 일로 씀. 팀장 자신의 패널과 두 워크스페이스에 같은 번호가 있는 짧은 패널 번호(`p3`)는 제외

## 0.1.8
- 쉬던 팀원이 새 일을 맡으면 그 일을 깨운 팀장의 메시지로 task를 바꿈. 이전에는 처음 맡은 일이 계속 표시됨. JSON 형식의 프로토콜 메시지는 task로 삼지 않음
- FOCUS의 task를 단어 사이에서 줄바꿈하고, 한 줄보다 긴 단어만 나눔. 이전에는 단어 중간(`eve` / `nt`)에서 끊김. 3줄을 넘으면 마지막 줄을 `…`로 끝냄
- COMMS에 남기는 메시지 길이를 120자에서 400자로 늘림(task로 쓰기 위해). 화면에는 지금처럼 폭에 맞춰 잘림

## 0.1.7
- 상태 시각(`stateAt`)이 없는 팀원(이전 버전에서 연결된 팀원)은 답이 5분 넘게 안 읽혀도 stale 이 되지 않아 선에 전류가 계속 흐르던 문제 수정: 합류 시각을 기준으로 판단

## 0.1.6
- 일하는 팀원 이름과 일하는 팀장의 `◆ LEAD` 위로 빛이 지나가는 효과
- 패널이 낮아 빠진 섹션을 단축키 옆에 표시(`+ ACTIVITY 6 · COMMS 3 hidden`)
- 좁은 패널에서 `busy` 줄과 팀원 정보 줄이 폭을 넘어 다음 줄로 밀리던 문제 수정: 모든 줄을 패널 폭에서 `…`로 자름

## 0.1.5
- 다른 Claude 세션 팀원의 상태 표시: 각 세션의 상태 파일(`~/.claude/sessions/*.json`)을 2초마다 읽어 WORKING / NEEDS YOU(승인·질문 대기, 알림 포함) / IDLE / 종료 시 DONE. 이전에는 항상 IDLE. 읽기만 하며 다른 세션에는 아무것도 쓰지 않음

## 0.1.4
- 한글·한자를 두 칸으로 세어 자름. 맡긴 일이나 이름에 한글이 있으면 줄이 패널 폭을 넘어 다음 줄 왼쪽(`briefly: …`)으로 넘치던 문제 수정. FOCUS 줄바꿈과 ACTIVITY 정렬도 같이

## 0.1.3
- herdr 팀원: 이 팀장이 맡긴 일만 반영. 다른 세션이 같은 패널에 맡긴 작업으로 상태·ACTIVITY가 바뀌지 않음
- `send-keys`(승인 키, Enter)는 지시가 아니므로 COMMS·handoff에 남기지 않고 선에 짧은 흐름만

## 0.1.2
- 팀장 상자에 긴 모델 이름(`sonnet 5.5`)이 잘리지 않게, 도구 1개일 때 `1 tool`

## 0.1.1
- 테마: 파스텔 톤. 전선과 전류는 구리·노란색 계열, 경고(NEEDS YOU·실패·context 가득)는 붉은색, 여유(context)는 초록색만

## 0.1.0
- 첫 버전: 팀장이 일을 맡기면 `Team` 패널이 열려 팀원을 배선도로 표시. 선 위 전류로 지시(팀장 → 팀원)와 답 대기(팀원 → 팀장)를 구분
- 팀원: 서브에이전트, agent teams 팀원, 다른 Claude 세션, herdr 패널의 CLI 에이전트(`herdr agent prompt/read/wait/send-keys` 감지, `herdr agent list`로 상태)
- 종류별 선 모양, `종류 · 에이전트 · 모델 · effort` 줄, 팀장 대기 표시(`◆`), COMMS 최근 3건
- 모델·effort: Claude 에이전트는 `turn.step`, herdr CLI는 화면 하단에서 읽음
- 대시보드: 상태 타일, busy 막대, 팀장 context 게이지와 세션 비용(`session.measure`)
- 디자인: 팀장 중심의 둥근 부채꼴 배선, 섹션 제목과 구분선, 상태 칩, 키 칩 버튼
- ACTIVITY: 합류·시작·완료(소요 시간)·실패·승인 대기·읽음·팀 작업 종료 기록
- 알림: NEEDS YOU(토스트 + 데스크톱 알림), REPLY READY, 실패, 팀 작업 종료 토스트
- 5분 넘게 안 읽은 답은 stale 표시, 팀원별 경과 시간·도구 호출 수·출력 토큰
- FOCUS: 팀원 이름이나 `1`~`9`로 상세 보기
- 팀원끼리 메시지를 주고받으면 오른쪽 레일로 연결
- 패널이 닫혀 있으면 상태줄 요약
- 서브에이전트의 도구 호출이 승인을 기다리면 NEEDS YOU (`tool.check`)
