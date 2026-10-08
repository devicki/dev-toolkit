# dev-toolkit

devicki의 Claude Code 플러그인 모음(마켓플레이스)입니다.

## 설치

```
/plugin marketplace add devicki/dev-toolkit
/plugin install erd@dev-toolkit
```

셸에서: `claude plugin marketplace add devicki/dev-toolkit && claude plugin install erd@dev-toolkit`
업데이트: `/plugin marketplace update dev-toolkit`

## 플러그인

| 플러그인 | 설명 |
|---|---|
| [erd](plugins/erd) | DBML(설계 원본) + tbls(문서·ERD·lint)로 프로젝트 ERD를 설계·문서화·유지보수 |

## 플러그인 추가하기

1. `plugins/<이름>/.claude-plugin/plugin.json` 과 `plugins/<이름>/skills/<스킬>/SKILL.md` 작성
2. `.claude-plugin/marketplace.json` 의 `plugins` 배열에 항목 추가 (`name` 은 plugin.json 의 name 과 같게)
3. `claude plugin validate .` 로 검증 후 푸시
