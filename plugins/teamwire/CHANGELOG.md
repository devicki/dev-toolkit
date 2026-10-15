# teamwire 플러그인 변경 이력

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
