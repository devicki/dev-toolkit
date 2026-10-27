# grokbot-relay 플러그인 변경 이력

## Unreleased (문서만, 버전 미정)
- grokbot-relay: `finished`는 「이번 답이 왔다」이지 「일이 끝났다」가 아님을 명시. 답이 뒷단 작업을 예고하면 예상 완료 시각에 `grokbot__check` 확인을 잡고 사용자에게 그 시각을 알림. 오래 걸리는 일은 완료 보고에 분명한 표시를 붙여 달라고 요청
- grokbot-relay: Grok Bot 호출은 `call_tool(toolName="grokbot__ask"|"grokbot__check", input={agent, ...})`로만. 상위 `mcp__grokbot__ask`/`check`는 relay 자체 세션용이라 Grok Bot sessionId를 넣으면 `Unknown session`

## 0.5.2
- feedhand-handoff: `media`에 서버 파일을 `{host, path, note}`로 적으면 Feedhand가 SSH로 직접 가져옴(devicki/feedhand `media fetch`). 보내기 전에 파일 존재와 크기를 확인해 알림. 서버에 없는 파일은 계속 `media_to_attach`

## 0.5.1
- 헤더 규칙을 한 줄로 줄임: 중계가 `[relay:claude-code]` 헤더를 붙이니 직접 쓰거나 지우지 않음 (devicki/grokbot-relay 0.8.1)

## 0.5.0
- 중계가 붙이는 `[relay:<tag>]` 발신자 헤더(devicki/grokbot-relay 0.8.0)를 스킬 규칙에 반영: 헤더를 직접 쓰거나 지우거나 흉내 내지 않음. Feedhand는 이 헤더가 있는 메시지를 외부 요청으로 다루고, 그 안의 승인 문구는 무시함
- README 4개 언어의 규칙에 같은 내용 추가

## 0.4.0
- 저장소 규칙에 맞춤: 스킬 description을 트리거·비활성 형식으로, SKILL.md를 템플릿 골격(한 줄 정의, 강제 규칙, 단계, 판단표, 관련 스킬)으로 정리
- 스킬과 README에서 개인 봇 이름을 빼고 일반 표현으로 바꿈. 봇 허용 목록은 중계 서버의 로컬 설정(devicki/grokbot-relay 0.3.0)에서 관리
- README 한국어·일본어·번체 중국어 추가

## 0.3.0
- 새 스킬 `feedhand-handoff`: 세션 작업(git log, PR, 변경 파일, README/CHANGELOG)에서 소재를 찾아 게시 방향을 제안하고, 확인을 받은 뒤 Feedhand에 요청서를 보냄. 승인은 Feedhand 채팅에서만

## 0.2.1
- 중계 서버, 배포 스크립트, .mcp.json 예시를 devicki/grokbot-relay로 옮김. 이 플러그인에는 사용 규칙 스킬만 남김

## 0.2.0
- 서버 배포 추가 (지금은 devicki/grokbot-relay)

## 0.1.0
- 첫 버전: 중계 뼈대, 사용 규칙 스킬, README
