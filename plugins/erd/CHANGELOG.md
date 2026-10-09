# erd 플러그인 변경 이력

## 0.3.0
- 스킬 작성 패턴 반영: description(산출물·한/영 트리거·비활성 조건), 스킬별 파일 목록, 강제 규칙(rules.md), 모드표, 판단표, 오류표, 체크리스트, 관련 스킬
- `erd-doc.sh` 종료 코드 세분화(2~8)와 `ERD_EXIT=<코드> <분류>` 출력, 오류 대응표(errors.md)
  - dbml2sql 이 문법 오류에도 exit 0 인 문제를 로그로 판정, tbls 공용 /tmp 권한 panic 감지, 임시 DB 대기 시간 상한
- `install-templates.sh`: init 손작업을 대체하는 멱등 설치 스크립트, `inject-block.sh`: CLAUDE.md/AGENTS.md 마커 블록 교체
- `scripts/erd-changed.sh` + `make erd-check-changed`: 원격 기준 브랜치 대비 스키마가 바뀐 단위만 검사, `/erd:review --changed`
- `find-units.sh --json`, 후보 폴더 판별 개선
- import `augment` 모드, design 의 필수/선택 질문·TBD·바꾸기 비싼 것·규모 감각, review 고정 검수 리포트·심각도 판단표
- 참고 문서에 출처·버전·날짜 표기, 보고 양식(report-templates.md)
- 회귀 테스트 `tests/run.sh` (10개 시나리오)

## 0.2.0
- 모노레포 지원: ERD 단위(= DB 하나 = erd.env 폴더), `find-units.sh`, `make erd P=<단위>`, `--project`, `ERD_RELATED_SOURCES`
- `make erd-check` 의 lint 경고는 기본 경고만 (`ERD_CHECK_LINT=strict`)

## 0.1.0
- 최초 공개: doctor, init, import, design, review, sync
