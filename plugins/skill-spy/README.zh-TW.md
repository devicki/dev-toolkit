# skill-spy

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · **繁體中文**

一個 **mod**：每一輪結束時，為該輪用到的每個技能顯示一則提示。不論是你自己輸入的技能（例如 `/erd:design`），還是 Claude 依你的要求自行挑選的技能，都能捕捉到。

![skill-spy 提示](../../docs/images/skill-spy.png)

- 每個技能一則提示。同一個技能用了多次會顯示次數，例如 `×2`。沒有用到技能的一輪不會顯示任何東西。
- 提示顯示在右上角，停留 60 秒。點一下即可關閉，滑鼠停在上面時不會消失。

## 安裝

```
/plugin marketplace add devicki/dev-toolkit
/plugin install skill-spy@dev-toolkit
```

## 注意事項

- mod 以你的使用者權限在 Claude Code 內執行，沒有沙箱。
- 在由組織管理的 Claude Code（例如公司帳號）中，自行安裝的外掛收不到 `skill.prompt` 事件，因此 skill-spy 不會運作。
- 提示最多停留 60 秒，且只能顯示一行。兩者都是 Claude Code 的限制。

## 開發

```bash
claude plugin validate plugins/skill-spy
claude plugin test plugins/skill-spy
claude --plugin-dir plugins/skill-spy   # 只載入此外掛來啟動
```
