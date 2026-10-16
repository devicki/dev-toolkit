# Changelog (dev-toolkit 마켓플레이스)

플러그인별 변경 이력은 각 플러그인 폴더의 `CHANGELOG.md` 를 본다.

## 2026-10
- README 일본어(`README.ja.md`)·번체 중국어(`README.zh-TW.md`) 추가: 루트와 erd·skill-spy·teamwire. `validate.py` 가 `README.zh-TW.md` 같은 지역 코드 README 도 문서로 보고 버전 올림을 요구하지 않음
- 저장소 검증 스크립트 `scripts/validate.py` + GitHub Actions
- 새 플러그인 스캐폴드 `scripts/new-plugin.sh`, 템플릿 `templates/plugin/`
- 스킬 작성 가이드 `docs/skill-authoring.md`
- erd 0.3.0, 0.3.1, 0.4.0 ([plugins/erd/CHANGELOG.md](plugins/erd/CHANGELOG.md))
- erd 0.4.1: 이모지 대신 기호 (스킬 작성 가이드에도 규칙 추가)
- teamwire 0.1.1, skill-spy 0.1.1: 파스텔 테마, 이모지 대신 기호
- teamwire 0.1.0: 팀 작업을 배선도 패널로 보여주는 모드 ([plugins/teamwire/CHANGELOG.md](plugins/teamwire/CHANGELOG.md))
- skill-spy 0.1.0: 첫 모드(hooks 모듈만 있는 플러그인). `validate.py` 가 skills/commands/agents 없이 `hooks/` 만 있는 플러그인도 허용
- 언어 규칙: 모델이 읽는 내용은 영어 한 벌, 응답은 사용자 언어, 프로젝트 파일은 프로젝트 언어 설정 (`docs/skill-authoring.md` 3-1). `validate.py` 가 SKILL.md 본문의 한국어를 경고. 스캐폴드 영어화
