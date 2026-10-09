# Changelog (dev-toolkit 마켓플레이스)

플러그인별 변경 이력은 각 플러그인 폴더의 `CHANGELOG.md` 를 본다.

## 2026-10
- 저장소 검증 스크립트 `scripts/validate.py` + GitHub Actions
- 새 플러그인 스캐폴드 `scripts/new-plugin.sh`, 템플릿 `templates/plugin/`
- 스킬 작성 가이드 `docs/skill-authoring.md`
- erd 0.3.0, 0.3.1, 0.4.0 ([plugins/erd/CHANGELOG.md](plugins/erd/CHANGELOG.md))
- 언어 규칙: 모델이 읽는 내용은 영어 한 벌, 응답은 사용자 언어, 프로젝트 파일은 프로젝트 언어 설정 (`docs/skill-authoring.md` 3-1). `validate.py` 가 SKILL.md 본문의 한국어를 경고. 스캐폴드 영어화
