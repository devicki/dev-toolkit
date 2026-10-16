# teamwire

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · **繁體中文**

一個以即時配線圖呈現代理團隊的 **mod**。領導工作階段分派工作時，會開啟 `Team` 面板，顯示團隊成員、每位成員被交付的工作、使用的模型，以及電流流向哪裡：成員工作時流向成員，有回覆等待讀取時流回領導。

![teamwire 面板](../../docs/images/teamwire.png)

畫面文字為英文。

## 顯示的內容

- **儀表板**：領導狀態標籤，TEAM / WORKING / REPLY / NEEDS YOU / DONE / UPTIME 方塊，忙碌比例長條，以及領導的**上下文視窗**（`38% · 376k / 1M tokens`）與工作階段費用。低於 60% 為綠色，60% 以上為橘色，85% 以上為紅色。
- **ORCHESTRATION**：以領導為中心的圓角扇形配線。每位成員顯示名稱、狀態標記、`kind · agent · model · effort`、經過時間、工具呼叫次數、輸出 token，以及被交付的工作。領導的方框顯示模型、上下文量表與 effort。
- **線上的電流**：工作中時火花從領導流向成員，回覆尚未讀取時從成員流回領導；訊息或指示往來後的幾秒內會流得更強。超過 5 分鐘沒讀的回覆會變成 **stale**（`REPLY · 7m`），電流停止。
- **工作中的名稱**：工作中成員的名稱，以及領導工作時的 `◆ LEAD`，會有一道光掃過。
- **成員之間**：兩位成員互傳訊息時，右側的軌道會在幾秒內連起他們的兩行，箭頭指向接收方。
- **FOCUS**：按成員名稱（或編號 `1`–`9`）可展開完整工作內容、模型、時間、用量與最近的訊息；再按一次關閉。
- **ACTIVITY**：加入、開始工作、`finished in 34s · reply ready`、`done`、`failed`、`needs you`、`answer read by lead`，以及最後一位成員完成時的 `team stood down · 4 members · 3m 20s`。
- **COMMS**：最近的指示與訊息，`發送方 → 接收方`、第一行內容與經過時間。
- **通知**：成員等待核准或回答時顯示提示與桌面通知（透過你設定的通知管道）；回覆就緒、失敗、團隊收工時顯示提示。
- **狀態列**：面板關閉或沒有繪製時，在提示字元下方以一行摘要：`◆ team 2 working · 1 reply · ctx 38% · /teamwire`
- **狀態**：`WORKING`、`REPLY READY`（已完成但尚未讀取）、`NEEDS YOU`（等待核准或問題回覆，包括子代理的工具呼叫正在等你核准）、`IDLE`、`DONE`、`FAILED`。

每種成員有自己的線：

| 類型 | 待機 | 流動時 |
|---|---|---|
| subagent | `┄┄┄` | `┅┅┅` |
| teammate（agent teams） | `═══` 暗 | `═══` 亮 |
| herdr（codex、grok 等） | `───` | `━━━` |
| session（其他 Claude 工作階段） | `┈┈┈` | `┉┉┉` |

## 資料來源

| 成員 | 來源 | 需要 |
|---|---|---|
| 子代理、隊友 | `agent.spawn`、`$.agent.list()`、`session.send` / `session.receive`；模型與 effort 來自每次模型請求（`turn.step`），核准等待來自 `tool.check`，工具呼叫次數與 token 來自 `tool.call` / `turn.complete` | 無 |
| 領導 | `session.measure`（上下文視窗、費用）、`turn.start` / `turn.complete` | 無 |
| 其他 Claude 工作階段 | 領導的 SendMessage（`session.send`）；狀態每 2 秒從各工作階段的狀態檔（`~/.claude/sessions/*.json`，只讀取）取得：工作中、等待核准或回答、閒置、已結束 | 無 |
| herdr 面板中的 CLI 代理 | 領導執行的 `herdr agent prompt / send-keys / read / wait`；狀態每 2 秒從 `herdr agent list` 取得；模型從代理畫面底部讀取一次 | [herdr](https://herdr.dev) |

沒有 herdr 時，除了外部 CLI 代理之外都能運作。

## 安裝

```
/plugin marketplace add devicki/dev-toolkit
/plugin install teamwire@dev-toolkit
```

第一次分派工作時面板會自動開啟。手動關閉後，該工作階段就不會再自動開啟，可用 `/teamwire` 重新開啟。

## 注意事項

- **不消耗 token。** hooks 只在 Claude Code 內執行，不會在提示或對話中加入任何內容。成本只有本機資源：有 herdr 成員時每 2 秒執行一次 `herdr agent list`，電流流動或有人工作時每秒約重繪 7 次。
- 按鍵（`c`、`l`、`1`–`9`）在面板取得焦點時才有作用：點一下面板，或按 ctrl+x tab。
- 只有在終端機寬度達 144 欄以上時，面板才會自動開啟（手動開過一次後為 110 欄）。
- 面板高度不夠時，會保留儀表板與配線圖，依序省略 COMMS、ACTIVITY、FOCUS；省略的區段會寫在按鍵旁的一行（`+ ACTIVITY 6 · COMMS 3 hidden`）。把面板拉高就會顯示。過長的文字會在面板邊緣以 `…` 截斷，完整的工作內容可在 FOCUS 中查看。
- mod 以你的使用者權限在 Claude Code 內執行，沒有沙箱。teamwire 只執行 `herdr` 指令，不寫入任何檔案；其他工作階段的狀態檔只會讀取。
- 在由組織管理的 Claude Code 中，自行安裝的外掛可能收不到這些事件。
- 已知限制：用變數或腳本包起來的 herdr 呼叫無法偵測；CLI 模型是依目前畫面底部的文字讀取；其他工作階段的狀態來自 Claude Code 內部的狀態檔，若該格式改變，這類成員會停在最後的狀態；成員之間的訊息不會畫出專屬的線，而是讓兩條線一起閃爍。

## 開發

```bash
claude plugin validate plugins/teamwire
claude plugin test plugins/teamwire
claude --plugin-dir plugins/teamwire   # 只載入此外掛來啟動
```

靈感來自以樹狀圖呈現子代理與 agent teams 的 [swarm](https://github.com/OneWave-AI/claude-code-mods)（MIT）。
