# Report templates (fixed)

> Baseline: erd plugin 0.4.0 — 2026-10. Do not change the format. `{}` are placeholders.
> Templates are rendered in the user's language (R8): headings and labels follow the language of the user's latest message. For Korean, use the "Korean labels" table at the end so the output stays identical to 0.3.x.
> Every report ends with a **Data as of** line: the commit (`git rev-parse --short HEAD`, plus `+dirty` if there are uncommitted changes) and the `docs/schema` generation time.

## §1 Review report — /erd:review

```markdown
# 🔍 ERD review report — {unit} {scope: all | module | table | changes (base ref)}
**Target**: {unit} ({DB}, ERD_SOURCE={value})  **Checked on**: {YYYY-MM-DD}  **Passed/checked**: {n}/{m}
**Summary**: 🚨 {c} · ⚠️ {w} · 💡 {i} · 🔎 {q}

## 🚨 Critical (must fix)
### [{ID}] {table.column} — {one-line description}
- Evidence: `{file}:{line}` {what the code does}
- Suggestion:
  ```dbml
  {DBML after the change}
  ```
- Impact: {migration risk / affected code}

## ⚠️ Warning (should fix)
(same format)

## 💡 Info
- [{ID}] {one line}

## 🔎 Needs confirmation
- {what could not be confirmed, whom to ask and what}

## Code change suggestions
- `{file}:{line}` {validation looser than the DB constraint, etc.}

## ✅ Passed
- {items among core violations C1–C5 that passed}

## Next steps
- {pick item numbers to apply them the /erd:design way | confirm with the owner}

Data as of: {commit} · docs/schema {generated at}
```

## §2 Drift report — /erd:sync drift

```markdown
# 🔀 Schema drift report — {unit}
**Compared**: {source of truth} ↔ {compared target}  **Checked on**: {YYYY-MM-DD}  **Differences**: {n}

| Item | Source-of-truth side | Compared side | Suggested action |
|---|---|---|---|
| {table.column} | {value} | {value} | {which side to align — the user decides} |

## Next steps
- {make erd / add a migration / fix the source of truth — items needing the user's decision}

Data as of: {commit} · docs/schema {generated at}
```

## §3 Completion report — /erd:design, /erd:import, /erd:init

```markdown
**Target**: {unit} ({DB}, ERD_SOURCE={value})
**Changes**: {n tables added · m columns changed …}
**Files changed**: `{file}` …
**Docs**: `{unit}/docs/schema/viewpoint-{module}.md` (make erd: ✔ | ✘ ERD_EXIT={code})
**lint**: {n warnings — summary | none}
**[inferred] / [TBD]**: {list | none}
**Next steps**: {1–2 commands}
```

## Korean labels

When the user writes in Korean, replace each fixed heading/label with the Korean below (as used in 0.3.x). Placeholder contents are written in Korean too.

| English | Korean |
|---|---|
| `🔍 ERD review report` (§1 title) | `🔍 ERD 검수 리포트` |
| scope `all \| module \| table \| changes (base ref)` | `전체 \| 모듈 \| 테이블 \| 변경분(기준 ref)` |
| `Target` | `대상` |
| `Checked on` | `검사일` |
| `Passed/checked` | `통과/검사 항목` |
| `Summary` | `요약` |
| `🚨 Critical (must fix)` | `🚨 Critical (수정 필수)` |
| `Evidence` | `근거` |
| `Suggestion` | `제안` |
| `Impact` | `영향` |
| `⚠️ Warning (should fix)` | `⚠️ Warning (권장 수정)` |
| `(same format)` | `(같은 형식)` |
| `💡 Info` | `💡 Info` |
| `🔎 Needs confirmation` | `🔎 확인 필요` |
| `Code change suggestions` | `코드 수정 제안` |
| `✅ Passed` | `✅ 통과` |
| `Next steps` | `다음 단계` |
| `Data as of` | `데이터 기준` |
| `{generated at}` (in the Data as of line) | `{생성 시각}` |
| `🔀 Schema drift report` (§2 title) | `🔀 스키마 차이 점검` |
| `Compared` | `비교` |
| `Differences`: `{n}` | `차이`: `{n}건` |
| table header `Item \| Source-of-truth side \| Compared side \| Suggested action` | `항목 \| 원본 쪽 \| 비교 대상 쪽 \| 조치 제안` |
| `Changes` | `변경` |
| `Files changed` | `수정한 파일` |
| `Docs` | `문서` |
| `lint`: `{n warnings — summary \| none}` | `lint`: `{경고 n건 — 요약 \| 없음}` |
| `[inferred] / [TBD]` | `[추정] / [TBD]` |
| `none` | `없음` |
| Review report (§1 name) | 검수 리포트 |
| Drift report (§2 name) | 차이 점검 리포트 |
| Completion report (§3 name) | 작업 마무리 보고 |
| Rule change proposal | 규칙 변경 제안 |
