# teamwire 플러그인 변경 이력

## 0.1.0
- 첫 버전: 팀장이 일을 맡기면 `Team` 패널이 열려 팀원을 배선도로 표시. 선 위 전류로 지시(팀장 → 팀원)와 답 대기(팀원 → 팀장)를 구분
- 팀원: 서브에이전트, agent teams 팀원, 다른 Claude 세션, herdr 패널의 CLI 에이전트(`herdr agent prompt/read/wait/send-keys` 감지, `herdr agent list`로 상태)
- 종류별 선 모양, `종류 · 에이전트 · 모델 · effort` 줄, 팀장 대기 표시(`⏳`), COMMS 최근 3건
- 모델·effort: Claude 에이전트는 `turn.step`, herdr CLI는 화면 하단에서 읽음
