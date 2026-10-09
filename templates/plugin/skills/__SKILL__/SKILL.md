---
name: __SKILL__
description: >
  <무엇을 하는지 1문장>. 산출물: <형식/개수>.
  트리거: "<한국어 문장>", "<한국어 문장>" / "<english phrase>".
  비활성: <발동하면 안 되는 경우>(→ <다른 스킬>).
argument-hint: "[<인자>]"
# disable-model-invocation: true   # 무겁거나 부작용 큰 워크플로면 켠다 (사용자가 직접 부를 때만)
allowed-tools:
  - "Bash(bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/*)"
---

# /__NAME__:__SKILL__ — <제목>

> **한 줄 정의**: <What>. <How 는 다른 스킬에서>.
> **핵심 산출물**: `<파일명 패턴>`

## 스킬 파일 (`${CLAUDE_PLUGIN_ROOT}/shared/`)
- `references/rules.md` — 강제 규칙·금지 (필수)
- `scripts/<helper>` — <결정적 작업, 사용 강제>
<!-- 이 스킬만 쓰는 파일은 스킬 폴더에 두고 ${CLAUDE_SKILL_DIR}/<file> 로 참조 -->

## 강제 규칙 (최우선) — 전체는 `rules.md`
1. <출처 제한 — 지정한 파일·API 만, 학습 지식으로 추정 금지>
2. <실패하면 고지하고 멈춤>
3. <출력은 표준 양식대로>

## 0단계: 사전 조건 / 선행 산출물 확인

## 1단계: 모드 선택
요청에서 분명하면 묻지 않는다. 모호할 때만 한 번 묻는다.
| 모드 | 상황 | 초반 접근 |
|---|---|---|
| NEW | 아무것도 없음 | |
| REVERSE | 이미 있는 코드·산출물 | |
| AUGMENT | 기존 결과물에 추가 | |

## 2단계: 수집 (한 번에 한 묶음, 필수/선택 구분, TBD 허용)

## 3단계: 생성 — 헬퍼 실행
1. 수집 데이터 → (필요하면) `schema.example.json` 형태의 JSON
2. `bash ${CLAUDE_PLUGIN_ROOT}/shared/scripts/<helper> <in> <out>`
3. 스크립트의 검증 출력이 모두 ✅ 가 아니면 보고 후 재실행

## 판단 규칙
| 조건 | 결과 |
|---|---|

## 에러 처리
| 종료 코드 / 상황 | 동작 |
|---|---|

## 체크리스트 (산출 전)
- [ ]

## 관련 스킬
- `/__NAME__:<skill>` — <관계>
