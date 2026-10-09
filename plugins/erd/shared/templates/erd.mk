# ERD 작업 명령 (erd 플러그인이 생성) — 레포 루트에 두고 루트에서 실행
# 기존 Makefile이 있으면 그 파일에 `include erd.mk` 한 줄만 추가하세요.
#
#   make erd               : 모든 ERD 단위(erd.env 가 있는 폴더)의 문서 생성 + lint
#   make erd P=apps/api    : 특정 단위만
#   make erd-check [P=..]  : 문서가 최신인지 검사 (CI용, 다르면 실패)
#   make erd-sql   [P=..]  : DBML → SQL 만 생성
#   make erd-list          : ERD 단위 목록
#   make erd-view  [P=..]  : 터미널에서 문서 보기 (glow)
#   make erd-check-changed [BASE=origin/main] : 기준 브랜치 대비 스키마가 바뀐 단위만 검사 (PR·CI용)
# 기존 DB 서버 사용: make erd PG=postgres://user:pass@localhost:5432  (MySQL: MY=mysql://...)

ERD_SCRIPT := scripts/erd-doc.sh
ERD_UNITS = $(if $(P),$(P),$(patsubst %/erd.env,%,$(shell find . -name erd.env -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/.venv/*' | sort)))

.PHONY: erd erd-check erd-check-changed erd-sql erd-list erd-view

erd:
	@set -e; for u in $(ERD_UNITS); do PG=$(PG) MY=$(MY) $(ERD_SCRIPT) doc $$u; echo; done

erd-check:
	@rc=0; for u in $(ERD_UNITS); do PG=$(PG) MY=$(MY) $(ERD_SCRIPT) check $$u || rc=1; echo; done; exit $$rc

# 스키마 관련 파일이 바뀐 단위 = 기준 대비 커밋 변경 + 커밋 안 한 변경 + 새 파일 (scripts/erd-changed.sh)
erd-check-changed:
	@units="$$(scripts/erd-changed.sh --names $(if $(BASE),--base $(BASE)))" || exit $$?; \
	if [ -z "$$units" ]; then echo "스키마가 바뀐 ERD 단위 없음"; exit 0; fi; \
	rc=0; for u in $$units; do PG=$(PG) MY=$(MY) $(ERD_SCRIPT) check $$u || rc=1; echo; done; exit $$rc

erd-sql:
	@set -e; for u in $(ERD_UNITS); do $(ERD_SCRIPT) sql $$u; done

erd-list:
	@for u in $(ERD_UNITS); do printf '%-30s %s\n' "$$u" "$$(grep -hE '^ERD_(DIALECT|SOURCE)=' $$u/erd.env | tr '\n' ' ')"; done

erd-view:
	@glow -p $(firstword $(ERD_UNITS))/docs/schema/README.md
