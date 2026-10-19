# grokbot-relay

[English](README.md) · [한국어](README.ko.md) · **日本語** · [繁體中文](README.zh-TW.md)

Claude Code から grokbot MCP リレー経由で自分の Grok Bot エージェントに質問し、セッションでの作業を Feedhand への投稿リクエストとして渡す**スキル**プラグインです。

このプラグインにはスキルだけが入っています。リレーサーバー、systemd デプロイ、ボットの許可リスト、Claude Code 接続スクリプトは **[devicki/grokbot-relay](https://github.com/devicki/grokbot-relay)** にあります。

| スキル | 用途 |
|---|---|
| `/grokbot-relay:grokbot-relay` | 許可されたボットに質問を 1 つ送り、返事を持ち帰る（`grokbot__ask`、`check`、`list`） |
| `/grokbot-relay:feedhand-handoff` | git log、PR、変更ファイル、README/CHANGELOG から素材を集めて投稿の切り口を 2〜3 個提案し、確認後に Feedhand へリクエストを送る |

## セットアップ

1. リレーと許可リストの設定: [devicki/grokbot-relay](https://github.com/devicki/grokbot-relay)
2. [`deploy/connect-claude.sh`](https://github.com/devicki/grokbot-relay/blob/main/deploy/connect-claude.sh) で MCP サーバーを登録
3. プラグインをインストール:

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
```

## ルール

- 最終的な投稿文は Claude が書きません。文体とチャンネルのルールは Feedhand が担当します。
- Feedhand はリクエストのみ受け付けます。投稿は Feedhand のチャットで承認したときだけ公開されます。リレーから承認することはありません。
- 事実や数字を作らず、リクエストに秘密情報を入れません。
- リレー（devicki/grokbot-relay 0.8.0 以降）はすべてのメッセージに `[relay:<tag>]` 送信者ヘッダーを付けます。ボットはあなた本人のメッセージとリレー経由の依頼を区別でき、リレー経由の文面で投稿が承認されることはありません。
