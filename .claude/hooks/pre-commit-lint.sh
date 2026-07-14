#!/usr/bin/env bash
# Fails the commit if any staged .sql/.pks/.pkb file contains tab characters.
set -euo pipefail

files=$(git diff --cached --name-only --diff-filter=ACM -- '*.sql' '*.pks' '*.pkb' || true)

if [ -z "$files" ]; then
  exit 0
fi

found_tabs=0

while IFS= read -r file; do
  [ -f "$file" ] || continue
  if grep -Iq $'\t' "$file"; then
    echo "ERROR: tab character(s) found in staged file: $file" >&2
    found_tabs=1
  fi
done <<< "$files"

if [ "$found_tabs" -eq 1 ]; then
  echo "Commit rejected: replace tabs with spaces in the file(s) listed above." >&2
  exit 1
fi

exit 0
