# grokbot-relay 플러그인 변경 이력

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
