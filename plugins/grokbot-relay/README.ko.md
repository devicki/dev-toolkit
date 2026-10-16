# grokbot-relay

[English](README.md) · **한국어** · [日本語](README.ja.md) · [繁體中文](README.zh-TW.md)

Claude Code에서 grokbot MCP 중계로 내 Grok Bot 에이전트에게 묻고, 세션에서 한 작업을 Feedhand 게시 요청으로 넘기는 **스킬** 플러그인입니다.

이 플러그인에는 스킬만 있습니다. 중계 서버, systemd 배포, 봇 허용 목록, Claude Code 연결 스크립트는 **[devicki/grokbot-relay](https://github.com/devicki/grokbot-relay)**에 있습니다.

| 스킬 | 용도 |
|---|---|
| `/grokbot-relay:grokbot-relay` | 허용된 봇에게 질문 하나를 보내고 답을 가져옴 (`grokbot__ask`, `check`, `list`) |
| `/grokbot-relay:feedhand-handoff` | git log, PR, 변경 파일, README/CHANGELOG에서 소재를 찾아 게시 방향 2~3개를 제안하고, 확인을 받은 뒤 Feedhand에 요청서를 보냄 |

## 설치

1. 중계와 허용 목록 설정: [devicki/grokbot-relay](https://github.com/devicki/grokbot-relay)
2. [`deploy/connect-claude.sh`](https://github.com/devicki/grokbot-relay/blob/main/deploy/connect-claude.sh)로 MCP 서버 등록
3. 플러그인 설치:

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
```

## 규칙

- 최종 게시글은 Claude가 쓰지 않습니다. 말투와 채널 규칙은 Feedhand가 맡습니다.
- Feedhand는 요청만 받습니다. 게시는 Feedhand 채팅에서 직접 승인해야 나갑니다. 중계로는 승인하지 않습니다.
- 사실이나 숫자를 지어내지 않고, 요청에 비밀값을 넣지 않습니다.
