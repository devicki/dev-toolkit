# skill-spy

[English](README.md) · [한국어](README.ko.md) · **日本語** · [繁體中文](README.zh-TW.md)

ターンが終わると、そのターンで使われたスキルごとにトーストを表示する **mod** です。`/erd:design` のように自分で入力したスキルも、リクエストを見て Claude が自分で選んだスキルも捉えます。

![skill-spy のトースト](../../docs/images/skill-spy.png)

- スキルごとにトーストを 1 つ。同じスキルを複数回使うと `×2` のように回数を表示します。スキルを使わなかったターンには何も表示しません。
- トーストは右上に 60 秒表示されます。クリックすると閉じ、マウスを乗せている間は消えません。

## インストール

```
/plugin marketplace add devicki/dev-toolkit
/plugin install skill-spy@dev-toolkit
```

## 知っておくこと

- mod は Claude Code の中でユーザー権限で動きます。サンドボックスはありません。
- 組織が管理する Claude Code（会社のアカウントなど）では、自分でインストールしたプラグインに `skill.prompt` イベントが届かないため、skill-spy は動作しません。
- トーストの表示は最長 60 秒で、1 行だけです。どちらも Claude Code の制限です。

## 開発

```bash
claude plugin validate plugins/skill-spy
claude plugin test plugins/skill-spy
claude --plugin-dir plugins/skill-spy   # このプラグインだけを読み込んで起動
```
