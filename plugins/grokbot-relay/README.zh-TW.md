# grokbot-relay

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · **繁體中文**

在 Claude Code 中透過 grokbot MCP 中繼向你自己的 Grok Bot 代理提問，並把工作階段中的成果交給 Feedhand 作為發文請求的**技能**外掛。

此外掛只包含技能。中繼伺服器、systemd 部署、機器人允許清單與 Claude Code 連線腳本都在 **[devicki/grokbot-relay](https://github.com/devicki/grokbot-relay)**。

| 技能 | 用途 |
|---|---|
| `/grokbot-relay:grokbot-relay` | 向允許的機器人送出一個問題並帶回回覆（`grokbot__ask`、`check`、`list`） |
| `/grokbot-relay:feedhand-handoff` | 從 git log、PR、變更檔案與 README/CHANGELOG 收集素材，提出 2–3 個發文角度，確認後向 Feedhand 送出結構化請求。`media` 中的伺服器檔案（`{host, path, note}`）由 Feedhand 透過 SSH 取得 |

## 設定

1. 設定中繼與允許清單：[devicki/grokbot-relay](https://github.com/devicki/grokbot-relay)
2. 用 [`deploy/connect-claude.sh`](https://github.com/devicki/grokbot-relay/blob/main/deploy/connect-claude.sh) 註冊 MCP 伺服器
3. 安裝外掛：

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
```

## 規則

- Claude 不撰寫最終貼文。語氣與頻道規則由 Feedhand 負責。
- Feedhand 只接受請求。貼文只有在你於 Feedhand 聊天中核准後才會發布；中繼永遠不會核准。
- 不捏造事實或數字，請求中不放任何機密。
- 中繼會在每則訊息加上 `[relay:claude-code]` 標頭；請勿自行撰寫或移除。
