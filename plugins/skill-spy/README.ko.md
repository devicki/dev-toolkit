# skill-spy

[English](README.md) · **한국어**

작업(턴)이 끝나면 그 턴에 쓰인 스킬을 토스트로 알려주는 **모드(mod)** 입니다. `/erd:design` 처럼 직접 입력한 스킬과, 요청을 보고 Claude가 알아서 쓴 스킬을 모두 잡습니다.

```
╭───────────────────────────╮
│ skill-spy                 │
│ ✦ erd:design ×2          │
╰───────────────────────────╯
╭───────────────────────────╮
│ skill-spy                 │
│ ✦ ponytail:ponytail      │
╰───────────────────────────╯
```

- 스킬마다 토스트 하나 (같은 스킬을 여러 번 쓰면 `×횟수`). 스킬을 안 쓴 턴에는 아무것도 뜨지 않습니다.
- 토스트는 오른쪽 위에 60초 동안 보이고, 클릭하면 바로 닫힙니다. 마우스를 올려 두면 사라지지 않습니다.

## 설치

```
/plugin marketplace add devicki/dev-toolkit
/plugin install skill-spy@dev-toolkit
```

## 알아둘 점

- 모드는 Claude Code 안에서 사용자 권한으로 실행됩니다 (샌드박스 없음).
- 조직이 관리하는 Claude Code(회사 계정 등)에서는 사용자가 설치한 플러그인에 `skill.prompt` 이벤트가 전달되지 않아 동작하지 않습니다.
- 토스트는 최대 60초까지 보이고 한 줄만 표시됩니다 (둘 다 Claude Code 제한).

## 개발

```bash
claude plugin validate plugins/skill-spy
claude plugin test plugins/skill-spy
claude --plugin-dir plugins/skill-spy   # 이 플러그인만 로드해서 실행
```
