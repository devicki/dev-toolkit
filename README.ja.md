# dev-toolkit

[English](README.md) · [한국어](README.ko.md) · **日本語** · [繁體中文](README.zh-TW.md)

devicki による Claude Code プラグインマーケットプレイスです。日々の開発作業で使うプラグインと mod をまとめています。

| プラグイン | バージョン | 種類 | 内容 |
|---|---|---|---|
| [erd](plugins/erd) | 0.4.2 | スキル | DBML（スキーマの原本）と tbls（ドキュメント、Mermaid ERD、lint）で、プロジェクトの ERD を設計・文書化・保守します。モノレポ対応。 |
| [skill-spy](plugins/skill-spy) | 0.1.1 | mod | ターンが終わると、そのターンで使われたスキルごとにトーストを表示します。 |
| [teamwire](plugins/teamwire) | 0.1.10 | mod | エージェントチームをリアルタイムの配線図で表示し、リードと各メンバーの間の流れを電流のように見せます。 |
| [grokbot-relay](plugins/grokbot-relay) | 0.5.2 | スキル | Claude Code からローカル MCP リレー経由で自分の Grok Bot エージェントに質問し、セッションの作業を Feedhand への投稿リクエストとして渡します。 |
| [dstack](plugins/dstack) | 0.2.0 | スキル | 作業を専用の herdr タブの Grok CLI セッションに渡し、Claude が diff をレビューします。`devicki-mode` は pstack の poteto-mode を、grok の役割だけ herdr で動かして実行します。 |

## インストール

Claude Code の中で:

```
/plugin marketplace add devicki/dev-toolkit
/plugin install erd@dev-toolkit
/plugin install skill-spy@dev-toolkit
/plugin install teamwire@dev-toolkit
/plugin install grokbot-relay@dev-toolkit
/plugin install dstack@dev-toolkit
```

シェルから:

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install erd@dev-toolkit
claude plugin install skill-spy@dev-toolkit
claude plugin install teamwire@dev-toolkit
claude plugin install grokbot-relay@dev-toolkit
claude plugin install dstack@dev-toolkit
```

更新するには `/plugin marketplace update dev-toolkit` を実行し、開いているセッションで `/reload-plugins` を実行します。

## skill-spy: どのスキルが動いたかを見る

スキルは気づかないうちに読み込まれることがよくあります。Claude がリクエストを見て自分で選んだり、サブエージェントが事前に読み込んだりするためです。skill-spy は **mod**（スキルを持たず、フックモジュールだけのプラグイン）です。ターンが終わると、そのターンで使われたスキルごとに右上にトーストを 1 つ表示します。

![skill-spy のトースト](docs/images/skill-spy.png)

- **スキルの起動方法をすべて捉えます:** `/name` の入力、Claude が自分で Skill ツールを呼ぶ場合、サブエージェントがスキルを事前に読み込む場合。
- **繰り返しは数えます:** 同じスキルが 1 ターンに 2 回動くと、トーストに `×2` と表示されます。スキルを使わなかったターンには何も表示しません。
- **トーストは 60 秒表示されます:** クリックすると早めに閉じ、マウスを乗せている間は消えません。

仕組み: `skill.prompt` フックがスキルの読み込みごとに数え、`turn.complete` フックがトーストを表示して次のターンのためにカウントをリセットします。mod 全体は約 30 行の [`hooks/register.ts`](plugins/skill-spy/hooks/register.ts) です。

制限:

- **組織が管理する Claude Code**（会社のアカウントなど）では、自分でインストールしたプラグインに `skill.prompt` が届かないため、skill-spy は何も表示しません。
- トーストの表示は最長 60 秒で、1 行だけです。どちらも Claude Code の制限です。
- mod は Claude Code の中でユーザー権限で動きます。サンドボックスはありません。

詳細: [plugins/skill-spy/README.ja.md](plugins/skill-spy/README.ja.md)

## teamwire: エージェントチームの作業を見る

リードセッションが仕事を任せると `Team` ペインが開き、配線図を表示します。左にリード、右にメンバーごとの枝が並びます。各メンバーには状態、`kind · agent · model · effort`、任された作業が表示されます。メンバーが作業中はリードからメンバーへ、回答が読まれるのを待っている間はメンバーからリードへ火花が流れます。

![teamwire ペイン](docs/images/teamwire.png)

- メンバー: サブエージェント、agent teams のチームメイト、ほかの Claude セッション、そして [herdr](https://herdr.dev) があれば herdr ペインで動く codex や grok などの CLI エージェント。
- 種類ごとに線の形が違います（`┅` サブエージェント、`═` チームメイト、`━` herdr、`┉` セッション）。
- リードのコンテキストウィンドウを示すダッシュボード、ACTIVITY ログ、1 人のメンバーを詳しく見る FOCUS、メンバーがあなたの対応を待つときやチームの作業が終わったときの通知。
- トークンを使いません。フックはイベントを観察してペインを描くだけです。

詳細: [plugins/teamwire/README.ja.md](plugins/teamwire/README.ja.md)

## grokbot-relay: 自分の Grok Bot エージェントと話す

[devicki/grokbot-relay](https://github.com/devicki/grokbot-relay) の grokbot MCP リレー（ローカルの Cursor BDK サーバー、先にセットアップ）を使うスキル 2 つです。

| コマンド | 用途 |
|---|---|
| `/grokbot-relay:grokbot-relay` | 許可されたボットに質問し、返事を持ち帰る |
| `/grokbot-relay:feedhand-handoff` | このセッションの作業（git log、PR、変更）を Feedhand への投稿リクエストにし、確認後にだけ送る |

最終的な投稿文の作成と承認は Claude が行いません。Feedhand が下書きし、承認は Feedhand のチャットで行います。

詳細: [plugins/grokbot-relay/README.ja.md](plugins/grokbot-relay/README.ja.md)

## erd: スキーマ設計からドキュメントまで

スキーマを DBML で書き、tbls でモジュールごとのドキュメント、Mermaid ERD、lint 結果を生成して、すべて Git で管理します。プロジェクトにすでにマイグレーションツール（Alembic、Prisma、Flyway など）があれば、そのツールを原本とし、ドキュメントはそこから生成します。

| コマンド | 用途 |
|---|---|
| `/erd:doctor` | tbls、@dbml/cli、Docker/psql の確認とインストール（インストール前に確認します） |
| `/erd:init` | プロジェクトをスキャンし、スキーマの原本を決めてテンプレートをインストール |
| `/erd:import` | ソースコード、ORM モデルやマイグレーション、ERD/ADR ドキュメント、稼働中の DB から DBML を作成 |
| `/erd:design` | 対話しながらスキーマを設計・変更 |
| `/erd:review` | バックエンドとフロントエンドのコードに照らしてスキーマをレビューし、深刻度順に指摘 |
| `/erd:sync` | ドキュメント更新、ドリフト確認、マイグレーション生成との連携、CI チェックの追加 |

![/erd:doctor](docs/images/erd-doctor.png)

「注文のテーブルを設計して」のように普通に頼んでも動きます。スキルはあなたが使った言語で答えます。プロジェクトに書き込まれるファイルは、各単位の `erd.env` にある `ERD_LANG=ko|en` に従います（日本語には未対応のため、日本語の環境では `en` を選んでください）。

詳細: [plugins/erd/README.ja.md](plugins/erd/README.ja.md)

## プラグインの開発

```bash
scripts/new-plugin.sh <name> --skill <first-skill> --desc "<description>"  # 雛形を作りマーケットプレイスに追加
python3 scripts/validate.py [--base origin/main]                           # リポジトリ構造の確認（CI でも実行）
claude plugin validate .                                                    # 公式のマニフェスト確認
plugins/<name>/tests/run.sh                                                 # プラグインの回帰テスト（erd）
claude plugin test plugins/<name>                                           # mod のテスト（フックモジュール）
claude --plugin-dir plugins/<name>                                          # このプラグインだけを読み込んで Claude Code を起動
```

```
.claude-plugin/marketplace.json   # マーケットプレイスのカタログ
plugins/<name>/                   # プラグインごとに 1 フォルダ。それぞれ README.md と CHANGELOG.md を持つ
docs/skill-authoring.md           # スキルの書き方のルール
templates/plugin/                 # new-plugin.sh が使う雛形
scripts/                          # validate.py、new-plugin.sh
```

CI（`.github/workflows/validate.yml`）は `validate.py`、`claude plugin validate .`、skill-spy と teamwire のテスト、Postgres を使った erd のテストを実行します。

各プラグインの変更はそれぞれの `CHANGELOG.md` に、マーケットプレイス全体の変更は [CHANGELOG.md](CHANGELOG.md) にあります（どちらも韓国語）。

## ライセンス

[MIT](LICENSE)
