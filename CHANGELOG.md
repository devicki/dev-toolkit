# Changelog

## erd 0.2.0
- 모노레포 지원: ERD 단위(= DB 하나 = erd.env 폴더) 개념 도입
  - `find-units.sh`: 모노레포 단서, 기존 단위, 현재 위치의 대상 단위, 새 단위 후보, DB 없는 소스 폴더 탐색
  - `erd-doc.sh <모드> [단위]`: 가장 가까운 erd.env 자동 인식, 단위가 여러 개면 지정 요구, 단위별 임시 DB 이름
  - `erd.mk`: `make erd` 전체 단위 / `make erd P=<단위>` / `make erd-list`
  - 모든 스킬에 `--project <단위 폴더>` 지원, review·sync 는 `--all-units`
  - `ERD_RELATED_SOURCES`: DB 없는 앱(프론트 등)을 단위에 연결
  - 서비스 간(다른 DB) 참조 표기 규칙
- `make erd-check`: lint 경고는 기본 경고만 (`ERD_CHECK_LINT=strict` 로 실패 처리)

## erd 0.1.0
- 최초 공개: doctor, init, import, design, review, sync
