# dev-toolkit

devicki의 Claude Code 플러그인 모음(마켓플레이스)입니다.

## 설치

```
/plugin marketplace add devicki/dev-toolkit
/plugin install erd@dev-toolkit
```

셸에서: `claude plugin marketplace add devicki/dev-toolkit && claude plugin install erd@dev-toolkit`
업데이트: `/plugin marketplace update dev-toolkit` 후 열린 세션에서 `/reload-plugins`

## 플러그인

| 플러그인 | 버전 | 설명 |
|---|---|---|
| [erd](plugins/erd) | 0.3.0 | DBML(설계 원본) + tbls(문서·ERD·lint)로 프로젝트 ERD를 설계·문서화·유지보수. 모노레포 지원 |

## 플러그인 개발

```bash
scripts/new-plugin.sh <이름> --skill <첫 스킬> --desc "<설명>"   # 스캐폴드 + marketplace 등록
python3 scripts/validate.py [--base origin/main]                # 구조 검증 (CI 에서도 실행)
claude plugin validate .                                         # 공식 검증
plugins/<이름>/tests/run.sh                                      # 플러그인 회귀 테스트
```

작성 규칙: [docs/skill-authoring.md](docs/skill-authoring.md) · 변경 이력: 각 플러그인의 `CHANGELOG.md`
