# teamwire

[English](README.md) · [한국어](README.ko.md) · **日本語** · [繁體中文](README.zh-TW.md)

エージェントチームをリアルタイムの配線図で表示する **mod** です。リードセッションが仕事を任せると `Team` ペインが開き、チームの顔ぶれ、各メンバーが任された作業、使っているモデル、そして電流がどこへ流れているかを表示します。メンバーが作業中はメンバーへ、回答が待っている間はリードへ流れます。

![teamwire ペイン](../../docs/images/teamwire.png)

画面の文言は英語です。

## 表示するもの

- **ダッシュボード**: リードの状態を示すチップ、TEAM / WORKING / REPLY / NEEDS YOU / DONE / UPTIME のタイル、稼働率のバー、リードの**コンテキストウィンドウ**（`38% · 376k / 1M tokens`）とセッションの費用。60% 未満は緑、60% 以上はオレンジ、85% 以上は赤。
- **ORCHESTRATION**: リードを中心にした角の丸い扇形の配線。メンバーごとに名前、状態バッジ、`kind · agent · model · effort`、経過時間・ツール呼び出し数・出力トークン、任された作業。リードの箱にはモデル、コンテキストのゲージ、effort。
- **線の上の電流**: 作業中はリード → メンバー、回答がまだ読まれていなければメンバー → リードへ火花が流れ、メッセージや指示のやり取り直後の数秒は強く流れます。5 分以上読まれていない回答は **stale**（`REPLY · 7m`）になり、流れが止まります。
- **作業中の名前**: 作業中のメンバーの名前と、リードが作業している間の `◆ LEAD` の上を光が通り過ぎます。
- **メンバー同士**: 2 人のメンバーがメッセージをやり取りすると、右側のレールが数秒間その 2 行をつなぎます。矢印は受け手側です。
- **FOCUS**: メンバーの名前（または番号 `1`〜`9`）を押すと、任された作業の全文、モデル、時間、使用量、最近のメッセージを開きます。もう一度押すと閉じます。
- **ACTIVITY**: 参加、作業開始、`finished in 34s · reply ready`、`done`、`failed`、`needs you`、`answer read by lead`、最後のメンバーが終わったときの `team stood down · 4 members · 3m 20s`。
- **COMMS**: 最近の指示とメッセージ。`送り手 → 受け手`、1 行目、経過時間。
- **通知**: メンバーが承認や回答を待つとトーストとデスクトップ通知（設定した通知チャネル）、回答の準備ができたとき・失敗したとき・チームの作業が終わったときにトースト。
- **ステータスライン**: ペインを閉じているか描画されていないとき、プロンプトの下に 1 行で要約します。`◆ team 2 working · 1 reply · ctx 38% · /teamwire`
- **状態**: `WORKING`、`REPLY READY`（終わったがまだ読まれていない）、`NEEDS YOU`（承認や質問を待っている。サブエージェントのツール呼び出しが承認待ちの場合を含む）、`IDLE`、`DONE`、`FAILED`。

メンバーの種類ごとに線の形が違います。

| 種類 | 待機 | 流れているとき |
|---|---|---|
| subagent | `┄┄┄` | `┅┅┅` |
| teammate（agent teams） | `═══` 暗め | `═══` 明るめ |
| herdr（codex、grok など） | `───` | `━━━` |
| session（ほかの Claude セッション） | `┈┈┈` | `┉┉┉` |

## データの出どころ

| メンバー | 出どころ | 必要なもの |
|---|---|---|
| サブエージェント、チームメイト | `agent.spawn`、`$.agent.list()`、`session.send` / `session.receive`。モデルと effort は毎回のモデルリクエスト（`turn.step`）、承認待ちは `tool.check`、ツール呼び出し数とトークンは `tool.call` / `turn.complete` から | なし |
| リード | `session.measure`（コンテキストウィンドウ、費用）、`turn.start` / `turn.complete` | なし |
| ほかの Claude セッション | リードの SendMessage（`session.send`）。状態は 2 秒ごとに各セッションの状態ファイル（`~/.claude/sessions/*.json`、読むだけ）から: 作業中、承認・質問待ち、待機、終了 | なし |
| herdr ペインの CLI エージェント | リードが実行した `herdr agent prompt / send-keys / read / wait`、または dstack の `delegate.py run / wait / close`。状態は 2 秒ごとに `herdr agent list`、モデルはエージェント画面のフッターから一度だけ読み取り。grok が自分で呼んだサブエージェントは grok のセッションファイル（`~/.grok/sessions/…/subagents/*/meta.json`）から読んでメンバーに加える。セッション ID は herdr の grok 連携が知らせる | [herdr](https://herdr.dev) |

herdr がなくても、外部の CLI エージェント以外はすべて動きます。

## インストール

```
/plugin marketplace add devicki/dev-toolkit
/plugin install teamwire@dev-toolkit
```

最初に仕事を任せた時点でペインが自動で開きます。自分で閉じるとそのセッションでは自動で開かなくなり、`/teamwire` でまた開けます。

## 知っておくこと

- **トークンを使いません。** フックは Claude Code の中だけで動き、プロンプトや会話に何も加えません。コストはローカルの資源だけです。herdr のメンバーがいる間は 2 秒ごとに `herdr agent list` を 1 回、電流が流れているか誰かが作業している間は 1 秒に約 7 回の再描画。
- キー（`c`、`l`、`1`〜`9`）はペインにフォーカスがあるときに効きます。ペインをクリックするか ctrl+x tab。
- ペインが自動で開くのはターミナルの幅が 144 桁以上のときだけです（一度自分で開いた後は 110 桁）。
- ペインの高さが足りないときは、ダッシュボードと配線図を残し、COMMS、ACTIVITY、FOCUS の順に省きます。省いたセクションはキーの横の 1 行に表示します（`+ ACTIVITY 6 · COMMS 3 hidden`）。ペインを高くすると表示されます。長い文はペインの端で `…` で切り、任された作業の全文は FOCUS で見られます。
- mod は Claude Code の中でユーザー権限で動きます。サンドボックスはありません。teamwire が実行するコマンドは `herdr` だけで、ファイルは書きません。読むファイルは、ほかのセッションの状態ファイル、dstack 委任の brief ファイル、grok のサブエージェント記録だけです。
- 組織が管理する Claude Code では、自分でインストールしたプラグインにこれらのイベントが届かないことがあります。
- 既知の制限: 変数で対象を受け取る herdr の呼び出し（シェル関数やループ）は、コマンドに書かれたペイン番号からメンバーを見つけます。ファイルから読み込んだスクリプト内の呼び出しは検出できません。CLI のモデルは現在のフッターの文言を前提に読み取ります。ほかのセッションの状態は Claude Code 内部の状態ファイルから読むため、その形式が変わると該当メンバーは最後の状態のままになります。メンバー同士のメッセージは専用の線を描かず、両方の線が一緒に光ります。

## 開発

```bash
claude plugin validate plugins/teamwire
claude plugin test plugins/teamwire
claude --plugin-dir plugins/teamwire   # このプラグインだけを読み込んで起動
```

サブエージェントと agent teams をツリーで表示する [swarm](https://github.com/OneWave-AI/claude-code-mods)（MIT）から着想を得ました。
