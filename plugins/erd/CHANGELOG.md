# erd 플러그인 변경 이력

## 0.4.0 — 영어 우선 + 언어 선택
- SKILL.md 6개·참고 문서 9개·플러그인 헬퍼 스크립트를 영어 한 벌로 (description 은 영어 + 한국어 트리거 예시). 상시 토큰 약 1,076 → 약 750
- R8 언어 규칙: 대화·리포트는 사용자 언어(한국어 라벨표로 0.3.x 양식 유지), 프로젝트에 쓰는 내용은 `ERD_LANG`, 식별자는 항상 영어
- `erd.env` 에 `ERD_LANG=ko|en`. `install-templates.sh --lang`: ERD_GUIDE·erd.env·.tbls.yml·DBML 예시·CLAUDE.md/AGENTS.md 블록을 언어별로 (`shared/templates/i18n/{ko,en}/`)
  - `--lang` 없으면 기존 단위 설정 → 다른 단위 설정 → en. 기존 `ERD_LANG` 은 바꾸지 않음(`!`)
  - **0.3.x 단위 업그레이드**: `erd.env` 에 `ERD_LANG` 이 없으면 `!` 경고 — `/erd:init` 재실행(또는 `--lang ko`)으로 추가. 없으면 메시지는 영어
- `scripts/erd-doc.sh`·`erd-changed.sh`·`erd.mk` 메시지 한/영 (`ERD_LANG` 환경변수로 덮어쓰기 가능). 기존 프로젝트는 `install-templates.sh ... --update-scripts` 로 교체
- 수정: `set -o pipefail` 에서 grep 무결과로 조용히 종료될 수 있던 경로 방지
- 테스트 12개 (영어 설치에 한글 없음, 한국어 메시지, 언어 상속, 0.3.x erd.env 업그레이드)

## 0.3.1
- `ERD_SOURCE=migrations` 단위의 ADR 연결: `/erd:import docs`(와 orm 후속 단계)가 결정을 `.tbls.yml` `comments:`(tableComment·columnComments·`labels: [ADR-xxx]`)에 기록. 파생 DBML·ORM 코드는 건드리지 않음
  - tbls 1.96.1 동작 확인: 설정 주석은 DB 주석을 **대체**(기존 문구 보존 규칙), lint 가 설정 주석을 인정, 설정만 바꾸면 `erd-check` 가 차이로 감지 — `tbls-guide.md` "comments" 절
- CLAUDE.md/AGENTS.md `erd:unit` 블록: 테이블·컬럼을 참조하는 작업 전에 볼 문서 순서(개요 DBML → viewpoint → 테이블 문서)와 설명·ADR 기록 위치를 명시. MySQL 은 테이블 문서 이름에 스키마 접두사 없음
- `.tbls.yml` 템플릿에 `comments:` 예시(주석)
- 테스트: migrations 단위 comments·라벨·drift 시나리오 추가 (11개)

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
