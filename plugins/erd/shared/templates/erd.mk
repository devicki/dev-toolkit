# ERD 작업 명령 (erd 플러그인이 생성)
# 기존 Makefile이 있으면 그 파일에 `include erd.mk` 한 줄만 추가하세요.
#   make erd        : 문서(docs/schema) 생성 + lint
#   make erd-check  : 문서가 최신인지 검사 (CI용, 다르면 실패)
#   make erd-sql    : DBML → SQL 만 생성
#   make erd-view   : 터미널에서 문서 보기 (glow)
# 기존 DB 서버 사용: make erd PG=postgres://user:pass@localhost:5432  (MySQL: MY=mysql://...)

.PHONY: erd erd-check erd-sql erd-view

erd:
	PG=$(PG) MY=$(MY) scripts/erd-doc.sh doc

erd-check:
	PG=$(PG) MY=$(MY) scripts/erd-doc.sh check

erd-sql:
	scripts/erd-doc.sh sql

erd-view:
	glow -p docs/schema/README.md
