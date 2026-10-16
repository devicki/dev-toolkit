# erd — ERD 設計、文件與維護外掛

[한국어](README.md) · [日本語](README.ja.md) · **繁體中文**

用 DBML 設計，再以 tbls 產生各模組的文件、ERD（Mermaid）與 lint，並用 Git 管理。
已經有 Alembic、Prisma、Flyway 等遷移工具的專案，會以該工具為原始來源，文件從它衍生。

## 技能

| 指令 | 用途 |
|---|---|
| `/erd:doctor` | 檢查並安裝 tbls、@dbml/cli、Docker/psql（安裝前會先確認） |
| `/erd:init` | 掃描專案 → 決定結構描述的原始來源 → 安裝範本 → 說明下一步 |
| `/erd:import` | 從畫面與 API 原始碼、ORM 與遷移、ERD 與 ADR 文件、執行中的資料庫建立 DBML |
| `/erd:design` | 以對話方式設計或修改（初次領域設計、模組、資料表、欄位的變更） |
| `/erd:review` | 對照後端與前端原始碼審查，依嚴重程度提出改善建議 |
| `/erd:sync` | 更新文件、檢查漂移、串接遷移產生、CI 檢查 |

![/erd:doctor](../../docs/images/erd-doctor.png)

用一般的說法提出要求，也會選到合適的技能（例如「幫我設計訂單功能需要的資料表」）。技能說明中寫有「不適用的情況」，所以相似的要求不會互相搶走。

## 語言

- 技能會用你使用的語言回答（包括中文），報告格式也會用該語言。
- 留在專案中的檔案（ERD_GUIDE、erd.env 與 .tbls.yml 的註解、CLAUDE.md/AGENTS.md 區塊、DBML note、`make erd` 訊息）依照各單位 `erd.env` 中的 `ERD_LANG=ko|en`。目前不支援中文，請選 `en`。`/erd:init` 會依據要求的語言與既有文件的語言提出建議。
- 資料表與欄位名稱不論語言，一律使用英文 snake_case。
- 以 0.3.x 設定的專案：再執行一次 `/erd:init` 就會加入 `ERD_LANG`（保留既有檔案）。

## make 指令（儲存庫根目錄）

| 指令 | 用途 |
|---|---|
| `make erd [P=<單位>]` | 產生文件 + lint |
| `make erd-check [P=<單位>]` | 檢查文件是否為最新（CI） |
| `make erd-check-changed [BASE=origin/main]` | 只檢查與基準分支相比結構描述有變更的單位（PR） |
| `make erd-sql`、`make erd-list`、`make erd-view` | DBML→SQL、單位清單、在終端機中檢視 |

失敗時最後一行會印出 `ERD_EXIT=<代碼> <分類>`，代碼表見 [shared/references/errors.md](shared/references/errors.md)（英文）。

## 專案中會產生的檔案

```
# 儲存庫根目錄（一份）
erd.mk                   # make erd / erd-check / erd-sql / erd-list / erd-view  [P=<單位>]
scripts/erd-doc.sh       # (DBML|遷移) → 暫時資料庫 → tbls 文件
scripts/erd-changed.sh   # 偵測與基準分支相比有變更的單位
docs/ERD_GUIDE.md        # 給團隊成員的作業規則

# ERD 單位資料夾（單一儲存庫時與根目錄相同）
erd.env                  # 語言（ERD_LANG）、結構描述的原始來源（dbml|migrations）、資料庫種類、遷移指令、相關原始碼
.tbls.yml                # 文件位置、Mermaid ERD、模組（viewpoints）、lint 規則
db/schema.dbml           # （以 dbml 為原始來源時）進入點
db/modules/*.dbml        # （以 dbml 為原始來源時）各模組的設計
docs/schema/             # 產生的文件：README.md、viewpoint-*.md、各資料表的 md、schema.json
```

## Monorepo

**ERD 單位 = 一個資料庫 = 有 `erd.env` 的資料夾**。每個服務各有資料庫時，就放在各服務的資料夾；共用資料庫時，放在擁有結構描述的那一個資料夾。
`scripts/erd-doc.sh` 和 `erd.mk` 只在儲存庫根目錄放一份，用 `make erd`（全部）或 `make erd P=apps/api`（單一）執行。
技能會以目前位置最近的 `erd.env` 為對象；不明確時會詢問，也可以用 `--project <資料夾>` 指定。
沒有資料庫的應用程式（例如前端）可透過 `erd.env` 的 `ERD_RELATED_SOURCES` 連結，在 import 與 review 時一併參考。

```
monorepo/
├── erd.mk  scripts/erd-doc.sh
├── apps/api/      erd.env .tbls.yml db/ docs/schema/   (PostgreSQL)
├── apps/billing/  erd.env .tbls.yml docs/schema/       (MySQL)
└── apps/web/      (api 的相關原始碼)
```

## 需求

- tbls、@dbml/cli（Node 18+）— 可用 `/erd:doctor` 安裝
- 暫時資料庫：Docker，或可連線的 PostgreSQL/MySQL 伺服器（`make erd PG=postgres://user:pass@host:5432`）
- 支援的資料庫：PostgreSQL、MySQL（以 dbml 為原始來源時）

## 開發

- 回歸測試：`PG=postgres://user:pass@localhost:5432 plugins/erd/tests/run.sh`（或 Docker）。沒有暫時資料庫時，資料庫情境會 SKIP
- 變更記錄：[CHANGELOG.md](CHANGELOG.md)（韓文）

## 多個帳號共用同一台伺服器時

tbls 可能在共用的 `/tmp/go-graphviz` 遇到權限錯誤。建議由管理員執行 `sudo apt install libpam-tmpdir`，再讓各帳號重新登入。`scripts/erd-doc.sh` 在沒有 TMPDIR 時會自動改用個人的暫存資料夾。
