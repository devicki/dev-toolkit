# erd — ERD の設計・文書化・保守プラグイン

[한국어](README.md) · **日本語** · [繁體中文](README.zh-TW.md)

DBML で設計し、tbls でモジュールごとのドキュメント・ERD（Mermaid）・lint を生成して Git で管理します。
Alembic・Prisma・Flyway など既存のマイグレーションツールがあるプロジェクトでは、そのツールを原本とし、ドキュメントはそこから生成します。

## スキル

| コマンド | 用途 |
|---|---|
| `/erd:doctor` | tbls、@dbml/cli、Docker/psql の確認とインストール（インストール前に確認） |
| `/erd:init` | プロジェクトをスキャン → スキーマの原本を決定 → テンプレートをインストール → 次の手順を案内 |
| `/erd:import` | 画面・API のソース、ORM・マイグレーション、ERD・ADR ドキュメント、稼働中の DB から DBML を作成 |
| `/erd:design` | 対話しながら設計・変更（最初のドメイン設計、モジュール・テーブル・カラムの変更） |
| `/erd:review` | バックエンド・フロントエンドのソースと照らし合わせてレビューし、深刻度順に改善案を提示 |
| `/erd:sync` | ドキュメント更新、ドリフト確認、マイグレーション生成との連携、CI チェック |

![/erd:doctor](../../docs/images/erd-doctor.png)

普通の言葉で頼んでも、合うスキルが選ばれます（例: 「注文機能に必要なテーブルを設計して」）。スキルの説明に「使わない場面」が書いてあるので、似たリクエスト同士で取り合いになりません。

## 言語

- スキルはユーザーが使った言語で答えます（日本語も可）。レポートの書式もその言語になります。
- プロジェクトに残るファイル（ERD_GUIDE、erd.env・.tbls.yml のコメント、CLAUDE.md/AGENTS.md のブロック、DBML の note、`make erd` のメッセージ）は、単位ごとの `erd.env` にある `ERD_LANG=ko|en` に従います。日本語には未対応のため、`en` を選んでください。`/erd:init` がリクエストの言語と既存ドキュメントの言語を見て提案します。
- テーブル・カラム名は言語に関係なく英語の snake_case です。
- 0.3.x でセットアップしたプロジェクト: `/erd:init` をもう一度実行すると `ERD_LANG` を追加します（既存ファイルはそのまま）。

## make コマンド（リポジトリのルート）

| コマンド | 用途 |
|---|---|
| `make erd [P=<単位>]` | ドキュメント生成 + lint |
| `make erd-check [P=<単位>]` | ドキュメントが最新か確認（CI） |
| `make erd-check-changed [BASE=origin/main]` | 基準ブランチと比べてスキーマが変わった単位だけを確認（PR） |
| `make erd-sql`、`make erd-list`、`make erd-view` | DBML→SQL、単位の一覧、ターミナルで表示 |

失敗すると最後の行に `ERD_EXIT=<コード> <分類>` が出力されます。コード表は [shared/references/errors.md](shared/references/errors.md)（英語）です。

## プロジェクトにできるファイル

```
# リポジトリのルート（1 つ）
erd.mk                   # make erd / erd-check / erd-sql / erd-list / erd-view  [P=<単位>]
scripts/erd-doc.sh       # (DBML|マイグレーション) → 一時 DB → tbls ドキュメント
scripts/erd-changed.sh   # 基準ブランチと比べて変わった単位を検出
docs/ERD_GUIDE.md        # チームメンバー向けの作業ルール

# ERD 単位のフォルダ（単一リポジトリならルートと同じ）
erd.env                  # 言語（ERD_LANG）、スキーマの原本（dbml|migrations）、DB の種類、マイグレーションコマンド、関連ソース
.tbls.yml                # ドキュメントの場所、Mermaid ERD、モジュール（viewpoints）、lint ルール
db/schema.dbml           # （dbml が原本の場合）エントリーポイント
db/modules/*.dbml        # （dbml が原本の場合）モジュールごとの設計
docs/schema/             # 生成ドキュメント: README.md、viewpoint-*.md、テーブルごとの md、schema.json
```

## モノレポ

**ERD 単位 = DB 1 つ = `erd.env` があるフォルダ**です。サービスごとに DB があればサービスのフォルダごとに、共有 DB ならスキーマを持つフォルダ 1 つに置きます。
`scripts/erd-doc.sh` と `erd.mk` はリポジトリのルートに 1 つだけ置き、`make erd`（全体）/ `make erd P=apps/api`（1 つ）で実行します。
スキルは現在の場所から最も近い `erd.env` を対象にし、曖昧なときは質問するか、`--project <フォルダ>` で指定できます。
DB を持たないアプリ（フロントエンドなど）は `erd.env` の `ERD_RELATED_SOURCES` でつなぎ、import・review のときに一緒に参照します。

```
monorepo/
├── erd.mk  scripts/erd-doc.sh
├── apps/api/      erd.env .tbls.yml db/ docs/schema/   (PostgreSQL)
├── apps/billing/  erd.env .tbls.yml docs/schema/       (MySQL)
└── apps/web/      (api の関連ソース)
```

## 必要なもの

- tbls、@dbml/cli（Node 18+）— `/erd:doctor` でインストールできます
- 一時 DB: Docker、またはアクセスできる PostgreSQL/MySQL サーバー（`make erd PG=postgres://user:pass@host:5432`）
- 対応 DB: PostgreSQL、MySQL（dbml が原本の場合）

## 開発

- 回帰テスト: `PG=postgres://user:pass@localhost:5432 plugins/erd/tests/run.sh`（または Docker）。一時 DB がなければ DB のシナリオは SKIP
- 変更履歴: [CHANGELOG.md](CHANGELOG.md)（韓国語）

## 複数のアカウントが同じサーバーを使う場合

tbls が共用の `/tmp/go-graphviz` で権限エラーを出すことがあります。管理者が `sudo apt install libpam-tmpdir` を実行し、各アカウントで再ログインすることをおすすめします。`scripts/erd-doc.sh` は TMPDIR がなければ自動で個人用の一時フォルダを使います。
