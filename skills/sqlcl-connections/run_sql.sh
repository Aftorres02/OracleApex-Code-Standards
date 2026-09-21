#!/usr/bin/env bash
# Runs SQL/PL-SQL non-interactively against a saved SQLcl connection.
# Implements: skills/sqlcl-connections/SKILL.md
#
# Usage:
#   ./run_sql.sh <saved-connection-name> <<'EOF'
#   @scripts/grant_ersh_to_user.sql WKSP_DEVAI1
#   EOF
#
#   echo "select user as current_schema from dual;" | ./run_sql.sh AI_LOGGER_USER
#
# Always uses `connect -name` (never a bare `connect <name>`) — see
# SKILL.md's "Lessons learned" for why a bare name silently hangs.

set -euo pipefail

conn_name="${1:-}"

if [ -z "$conn_name" ]; then
  echo "Usage: $0 <saved-connection-name>   (SQL/@script lines on stdin)" >&2
  exit 1
fi

connections="$(sql -nolog <<'EOF'
connmgr list
exit
EOF
)"

if ! grep -qi -- "$conn_name" <<< "$connections"; then
  echo "No saved SQLcl connection named '$conn_name' found." >&2
  echo >&2
  echo "Available connections:" >&2
  echo "$connections" >&2
  echo >&2
  echo "Create it first (fill in real credentials), then re-run:" >&2
  echo "  connect -save $conn_name -savepwd <user>/<password>@<connect_identifier>" >&2
  exit 2
fi

tmp_sql="$(mktemp)"
trap 'rm -f "$tmp_sql"' EXIT

{
  printf 'connect -name "%s"\n' "$conn_name"
  cat
  printf '\nexit\n'
} > "$tmp_sql"

sql -nolog < "$tmp_sql"
