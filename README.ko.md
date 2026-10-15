# dev-toolkit

[English](README.md) · **한국어**

devicki의 Claude Code 플러그인 마켓플레이스입니다. 일상 개발 작업에 쓰는 플러그인과 모드를 모아 두었습니다.

| 플러그인 | 버전 | 종류 | 설명 |
|---|---|---|---|
| [erd](plugins/erd) | 0.4.1 | 스킬 | DBML(설계 원본)과 tbls(문서·Mermaid ERD·lint)로 프로젝트 ERD를 설계·문서화·유지보수합니다. 모노레포 지원 |
| [skill-spy](plugins/skill-spy) | 0.1.1 | 모드 | 턴이 끝나면 그 턴에 쓰인 스킬을 토스트로 알려줍니다 |
| [teamwire](plugins/teamwire) | 0.1.3 | 모드 | 팀 작업을 실시간 배선도로 보여주고, 팀장과 팀원 사이의 흐름을 전류처럼 표시합니다 |

## 설치

Claude Code 안에서:

```
/plugin marketplace add devicki/dev-toolkit
/plugin install erd@dev-toolkit
/plugin install skill-spy@dev-toolkit
/plugin install teamwire@dev-toolkit
```

셸에서:

```bash
claude plugin marketplace add devicki/dev-toolkit
claude plugin install erd@dev-toolkit
claude plugin install skill-spy@dev-toolkit
claude plugin install teamwire@dev-toolkit
```

업데이트하려면 `/plugin marketplace update dev-toolkit`을 실행한 뒤, 열려 있는 세션에서 `/reload-plugins`를 실행하세요.

## skill-spy: 어떤 스킬이 쓰였는지 보기

스킬은 모르는 사이에 로드되는 경우가 많습니다. Claude가 요청을 보고 직접 고르기도 하고, 서브에이전트가 미리 불러오기도 합니다. skill-spy는 **모드(mod)** 입니다. 스킬 없이 hooks 모듈만 있는 플러그인이라는 뜻입니다. 턴이 끝나면 그 턴에 쓰인 스킬마다 오른쪽 위에 토스트를 하나씩 띄웁니다.

![skill-spy 토스트](docs/images/skill-spy.png)

- **스킬이 시작되는 모든 경로를 잡습니다:** `/이름`을 직접 입력한 경우, Claude가 스스로 Skill 도구를 호출한 경우, 서브에이전트가 스킬을 미리 불러온 경우 모두요.
- **반복 횟수를 셉니다:** 한 턴에 같은 스킬을 두 번 쓰면 `×2`로 표시합니다. 스킬을 쓰지 않은 턴에는 아무것도 뜨지 않습니다.
- **토스트는 60초 동안 보입니다:** 클릭하면 바로 닫히고, 마우스를 올려 두면 사라지지 않습니다.

동작 방식: `skill.prompt` 훅이 스킬이 로드될 때마다 횟수를 셉니다. 이어서 `turn.complete` 훅이 토스트를 띄우고, 다음 턴을 위해 횟수를 초기화합니다. 모드 전체가 [`hooks/register.ts`](plugins/skill-spy/hooks/register.ts) 하나(약 30줄)입니다.

제한 사항:

- **조직이 관리하는 Claude Code**(회사 계정 등)에서는 직접 설치한 플러그인에 `skill.prompt`가 전달되지 않아 skill-spy가 동작하지 않습니다.
- 토스트는 최대 60초까지 보이고 한 줄만 표시됩니다. 둘 다 Claude Code의 제한입니다.
- 모드는 Claude Code 안에서 사용자 권한으로 실행되며, 샌드박스가 없습니다.

자세한 내용: [plugins/skill-spy/README.ko.md](plugins/skill-spy/README.ko.md)

## teamwire: 팀 작업 지켜보기

팀장 세션이 일을 맡기면 `Team` 패널이 열려 배선도를 보여줍니다. 왼쪽에 팀장, 팀원마다 가지 하나. 팀원마다 상태, `종류 · 에이전트 · 모델 · effort`, 맡은 일이 표시되고, 일하는 동안에는 팀원 쪽으로, 답을 아직 안 읽었으면 팀장 쪽으로 불꽃이 흐릅니다.

![teamwire 패널](docs/images/teamwire.png)

- 팀원: 서브에이전트, agent teams 팀원, 다른 Claude 세션, 그리고 [herdr](https://herdr.dev)를 쓰면 herdr 패널의 codex·grok 같은 CLI 에이전트.
- 종류마다 선 모양이 다릅니다 (`┅` 서브에이전트, `═` 팀원, `━` herdr, `┉` 세션).
- 팀장 context 사용량이 보이는 대시보드, ACTIVITY 기록, 팀원 FOCUS, 승인 대기·팀 작업 종료 알림.
- 토큰을 쓰지 않습니다. 훅은 이벤트를 지켜보고 패널을 그리기만 합니다.

자세한 내용: [plugins/teamwire/README.ko.md](plugins/teamwire/README.ko.md)

## erd: 스키마 설계부터 문서까지

DBML로 스키마를 작성하고, tbls로 모듈별 문서·Mermaid ERD·lint 결과를 만들어 Git으로 관리합니다. 프로젝트에 이미 마이그레이션 도구(Alembic, Prisma, Flyway 등)가 있으면 그 도구를 원본으로 두고 문서를 거기서 만듭니다.

| 명령 | 용도 |
|---|---|
| `/erd:doctor` | tbls, @dbml/cli, Docker/psql 점검과 설치 (설치 전에 확인) |
| `/erd:init` | 프로젝트를 훑어보고 스키마 원본을 정한 뒤 템플릿 설치 |
| `/erd:import` | 소스 코드, ORM 모델·마이그레이션, ERD·ADR 문서, 실행 중인 DB에서 DBML 생성 |
| `/erd:design` | 대화하며 스키마 설계·수정 |
| `/erd:review` | 백엔드·프론트 코드와 대조해 스키마 검토, 심각도별 정리 |
| `/erd:sync` | 문서 갱신, drift 점검, 마이그레이션 생성 연동, CI 검사 추가 |

![/erd:doctor](docs/images/erd-doctor.png)

"주문 기능에 필요한 테이블 설계해줘"처럼 자연어로 요청해도 됩니다. 스킬은 사용자가 쓴 언어로 답하고, 프로젝트에 쓰는 파일은 단위의 `erd.env`에 있는 `ERD_LANG=ko|en`을 따릅니다.

자세한 내용: [plugins/erd/README.md](plugins/erd/README.md)

## 플러그인 개발

```bash
scripts/new-plugin.sh <이름> --skill <첫 스킬> --desc "<설명>"   # 스캐폴드 + marketplace 등록
python3 scripts/validate.py [--base origin/main]                # 저장소 구조 검증 (CI에서도 실행)
claude plugin validate .                                         # 공식 매니페스트 검증
plugins/<이름>/tests/run.sh                                      # 플러그인 회귀 테스트 (erd)
claude plugin test plugins/<이름>                                # 모드 테스트 (hooks 모듈)
claude --plugin-dir plugins/<이름>                               # 이 플러그인만 로드해서 Claude Code 실행
```

```
.claude-plugin/marketplace.json   # 마켓플레이스 목록
plugins/<이름>/                   # 플러그인마다 폴더 하나, 각각 README.md와 CHANGELOG.md 포함
docs/skill-authoring.md           # 스킬 작성 규칙
templates/plugin/                 # new-plugin.sh가 쓰는 스캐폴드
scripts/                          # validate.py, new-plugin.sh
```

CI(`.github/workflows/validate.yml`)는 `validate.py`, `claude plugin validate .`, skill-spy·teamwire 테스트, Postgres를 띄운 erd 테스트를 실행합니다.

변경 이력은 플러그인마다 각자의 `CHANGELOG.md`에 있고, 마켓플레이스 단위 변경은 [CHANGELOG.md](CHANGELOG.md)에 있습니다.

## 라이선스

[MIT](LICENSE)
