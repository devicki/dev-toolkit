#!/usr/bin/env bash
# Check whether the tools needed for ERD work are installed and working. (No changes, always exit 0)
# Output: human-readable table + last line MISSING=<comma list>
set -u

ok()   { printf '  ✅ %-12s %s\n' "$1" "$2"; }
warn() { printf '  ⚠️  %-12s %s\n' "$1" "$2"; }
miss() { printf '  ❌ %-12s %s\n' "$1" "$2"; MISSING+=("$1"); }
MISSING=()

echo "## Environment"
echo "  OS: $(uname -s) $(uname -m)   SHELL: ${SHELL:-?}   TMPDIR: ${TMPDIR:-(unset)}"
echo
echo "## Required tools"

# dbml2sql (@dbml/cli)
if command -v dbml2sql >/dev/null 2>&1; then
  ok dbml2sql "$(dbml2sql --version 2>/dev/null | head -1) (@dbml/cli)"
else
  miss dbml2sql "@dbml/cli not installed → npm install -g @dbml/cli"
fi

# tbls (installed + actually runnable)
if command -v tbls >/dev/null 2>&1; then
  out=$(tbls version 2>&1); rc=$?
  if [ $rc -eq 0 ]; then
    ok tbls "$out ($(command -v tbls))"
  elif printf '%s' "$out" | grep -q 'go-graphviz.*permission denied'; then
    warn tbls "installed, but /tmp/go-graphviz permission error (another account ran it first)"
    echo "               Fix: use a per-account TMPDIR (references/tbls-guide.md 'Shared /tmp problem')"
    MISSING+=("tbls-tmpdir")
  else
    warn tbls "installed, run error: $(printf '%s' "$out" | head -1)"
  fi
else
  miss tbls "not installed"
fi

# node/npm (for installing dbml)
if command -v node >/dev/null 2>&1; then
  ok node "$(node -v)"
else
  miss node "Node.js not installed (needed to install @dbml/cli, 18 or later)"
fi

echo
echo "## Temporary DB (one of these is required)"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  ok docker "available"
elif command -v docker >/dev/null 2>&1; then
  warn docker "installed, cannot reach daemon (permissions: sudo usermod -aG docker \$USER, then log in again)"
else
  warn docker "not installed"
fi
if command -v psql >/dev/null 2>&1; then
  ok psql "$(psql --version 2>/dev/null | head -1) → existing PostgreSQL server available (PG=...)"
else
  warn psql "not installed (postgresql-client needed to use an existing server)"
fi
if command -v mysql >/dev/null 2>&1; then
  ok mysql "$(mysql --version 2>/dev/null | head -1)"
fi

echo
echo "## Optional tools"
for t in glow atlas; do
  if command -v $t >/dev/null 2>&1; then ok $t "installed"; else printf '  ·  %-12s %s\n' "$t" "not installed (optional)"; fi
done

echo
IFS=,; echo "MISSING=${MISSING[*]:-}"
exit 0
