# ERD 작업 명령 (erd 플러그인이 생성) — 레포 루트에 두고 루트에서 실행
# 기존 Makefile이 있으면 그 파일에 `include erd.mk` 한 줄만 추가하세요.
#
#   make erd               : 모든 ERD 단위(erd.env 가 있는 폴더)의 문서 생성 + lint
#   make erd P=apps/api    : 특정 단위만
#   make erd-check [P=..]  : 문서가 최신인지 검사 (CI용, 다르면 실패)
#   make erd-sql   [P=..]  : DBML → SQL 만 생성
#   make erd-list          : ERD 단위 목록
#   make erd-view  [P=..]  : 터미널에서 문서 보기 (glow)
# 기존 DB 서버 사용: make erd PG=postgres://user:pass@localhost:5432  (MySQL: MY=mysql://...)

ERD_SCRIPT := scripts/erd-doc.sh
ERD_UNITS = $(if $(P),$(P),$(patsubst %/erd.env,%,$(shell find . -name erd.env -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/.venv/*' | sort)))

.PHONY: erd erd-check erd-sql erd-list erd-view

erd:
	@set -e; for u in $(ERD_UNITS); do PG=$(PG) MY=$(MY) $(ERD_SCRIPT) doc $$u; echo; done

erd-check:
	@rc=0; for u in $(ERD_UNITS); do PG=$(PG) MY=$(MY) $(ERD_SCRIPT) check $$u || rc=1; echo; done; exit $$rc

erd-sql:
	@set -e; for u in $(ERD_UNITS); do $(ERD_SCRIPT) sql $$u; done

erd-list:
	@for u in $(ERD_UNITS); do printf '%-30s %s\n' "$$u" "$$(grep -hE '^ERD_(DIALECT|SOURCE)=' $$u/erd.env | tr '\n' ' ')"; done

erd-view:
	@glow -p $(firstword $(ERD_UNITS))/docs/schema/README.md
