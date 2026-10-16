# grokbot-relay

Claude Code, Cursor, 터미널에서 내 Grok Bot 에이전트(helper, botkit, 집순이, Feedhand, Watchless)에게 **로컬** Cursor BDK 중계(`cursor-grokbot-agents` 확장)로 질문하고 답을 받아옵니다. [English](README.md)

> 0.1.0: `@cursor/bdk` 0.2.25 문서 기준 뼈대입니다. **로컬 확인 필요** 표시는 아직 테스트하지 않았습니다.

## 구조

```
Claude Code / Cursor ──stdio──> bdk mcp ──HTTP(127.0.0.1)──> bdk serve(relay/) ──> 내 Grok Bot 에이전트
```

- 허용 목록: `relay/bot/extensions/grokbot/extension.ts`. `grokbot__interrupt`는 `tools/interrupt.ts`로 껐습니다.
- 인증은 이 컴퓨터의 내 Cursor 로그인입니다. 저장소에는 아무 키도 없습니다.

## 설치 (로컬)

Node.js 22 이상이 필요합니다.

```bash
cd plugins/grokbot-relay/relay
npm install
npx bdk login                     # 브라우저에서 내 Cursor 계정 로그인
npx bdk validate
npx bdk dev                       # 선택: playground에서 "누구랑 얘기할 수 있어?" 시험

export GROKBOT_RELAY_TOKEN="$(openssl rand -hex 32)"   # git에 넣지 마세요
npx bdk serve --dir . --bearer-token "$GROKBOT_RELAY_TOKEN"
```

**로컬 확인 필요**
- `bdk serve`가 출력하는 포트와 주소, MCP 경로가 `/v1/mcp`인지 `/<slug>/v1/mcp`인지
- `serve`가 `--bearer-token`을 받는지(CLI 도움말엔 serve용으로 나옴), 127.0.0.1에서만 열리는지

### Cursor

```bash
npx bdk mcp install --url http://127.0.0.1:<PORT> --bearer-token "$GROKBOT_RELAY_TOKEN" --name grokbot --print   # 미리보기
npx bdk mcp install --url http://127.0.0.1:<PORT> --bearer-token "$GROKBOT_RELAY_TOKEN" --name grokbot
```

토큰이 `~/.cursor/mcp.json`에 저장됩니다. 이 파일은 비밀번호처럼 다루세요.

### Claude Code

```bash
export GROKBOT_RELAY_PORT=<PORT>
claude mcp add grokbot -- npx -y @cursor/bdk mcp --url "http://127.0.0.1:$GROKBOT_RELAY_PORT" --bearer-token "$GROKBOT_RELAY_TOKEN"
```

또는 `.mcp.json.example`을 프로젝트의 `.mcp.json`으로 복사하세요. 포트와 토큰은 환경변수에서 읽습니다. 사용 규칙 스킬은 플러그인으로 설치합니다.

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
```

## 안전

- `serve`는 루프백에서만 여세요. 밖으로 열려면 인증 프록시를 앞에 두세요.
- `check`는 봇 대화를 읽습니다. 중계에 접근할 수 있는 사람은 답을 읽을 수 있습니다.
- 모든 호출자가 Grok Bot 계정 하나와 봇 기억을 같이 씁니다.
- **Feedhand는 요청만 받습니다.** 게시는 Feedhand 채팅에서 내가 승인해야 나갑니다. 중계로는 절대 승인하지 않습니다.
- `bdk mcp`는 `--prod` 클라우드 배포에서 동작하지 않습니다. 로컬에서 실행하세요.
