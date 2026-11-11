#!/usr/bin/env bash
# --------------------------------------------------------------------------
# update-claude-submodule.sh
#
# Moves a consumer project's submodule (default: .claude, this standards
# package) to the latest commit of its tracked remote branch, shows what
# changed, checks that every path the project references inside the
# submodule still exists, and prints what is left to commit.
#
# Project-independent: the parent repo is resolved from this script's own
# location. It normally runs from inside the submodule
# (.claude/scripts/update-claude-submodule.sh), where the superproject is
# used; a copy placed directly in a project also works.
#
# It only updates the working tree — it never commits or pushes. The new
# submodule pointer still goes through a branch + PR like any other change
# (see guides/consuming-this-repo-tech-lead.md §5).
#
# Usage (from anywhere):
#   .claude/scripts/update-claude-submodule.sh            # updates .claude
#   .claude/scripts/update-claude-submodule.sh <path>     # another submodule
# --------------------------------------------------------------------------

set -euo pipefail

# Everything runs inside main(), called on the last line, so bash has parsed
# the whole script before the update touches the folder it lives in. Today
# that is only a guard: git replaces a changed file with a new one, and the
# running bash keeps reading the old one it already has open (verified). It
# would matter if anything ever rewrote this file in place, since bash reads
# a script from disk as it runs. The .bat version has the real problem —
# cmd.exe reopens a batch file by name for every line — and copies itself
# to %TEMP% first.
main() {
  local submodule_path="${1:-.claude}"
  submodule_path="${submodule_path%/}"

  # ------------------------------------------------------------------------
  # Resolve the parent repo
  # ------------------------------------------------------------------------
  local script_dir repo_root
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  repo_root="$(git -C "$script_dir" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
  if [ -z "$repo_root" ]; then
    repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  if [ -z "$repo_root" ]; then
    echo "ERROR: $script_dir is not inside a git repository." >&2
    return 1
  fi
  cd "$repo_root"

  if ! git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
       | awk '{print $2}' | grep -qxF "$submodule_path"; then
    echo "ERROR: '$submodule_path' is not a submodule registered in $repo_root/.gitmodules." >&2
    return 1
  fi

  local submodule_url
  submodule_url="$(git config -f .gitmodules --get "submodule.$submodule_path.url" || echo 'url unknown')"
  echo "Repo:      $repo_root"
  echo "Submodule: $submodule_path ($submodule_url)"
  echo

  # ------------------------------------------------------------------------
  # Refuse to run over local edits inside the submodule
  # ------------------------------------------------------------------------
  local old_sha=""
  if [ -e "$submodule_path/.git" ]; then
    if [ -n "$(git -C "$submodule_path" status --porcelain --untracked-files=no)" ]; then
      echo "ERROR: $submodule_path has uncommitted changes — commit, push or discard them first:" >&2
      git -C "$submodule_path" status --short --untracked-files=no >&2
      return 1
    fi
    old_sha="$(git -C "$submodule_path" rev-parse HEAD)"
  fi

  # ------------------------------------------------------------------------
  # Update to the latest remote commit
  # ------------------------------------------------------------------------
  echo "Updating $submodule_path to the latest remote commit ..."
  git submodule update --init --remote -- "$submodule_path"

  local new_sha
  new_sha="$(git -C "$submodule_path" rev-parse HEAD)"
  echo

  if [ -n "$old_sha" ] && [ "$old_sha" = "$new_sha" ]; then
    echo "Already up to date at:"
    git -C "$submodule_path" log --oneline -1
    return 0
  fi

  echo "Now at:"
  git -C "$submodule_path" log --oneline -1
  echo

  if [ -n "$old_sha" ]; then
    echo "New commits ($(git -C "$submodule_path" rev-list --count "$old_sha..$new_sha")):"
    git -C "$submodule_path" log --oneline --no-merges "$old_sha..$new_sha"
    echo
    echo "Files added (A), modified (M), deleted (D) or renamed (R):"
    git -C "$submodule_path" diff --name-status "$old_sha" "$new_sha"
    echo
  fi

  # ------------------------------------------------------------------------
  # Check that every path the project references inside the submodule
  # still exists — a renamed or removed rule, skill or template breaks
  # those links silently.
  # ------------------------------------------------------------------------
  local path_regex missing=0 ref_path
  path_regex="${submodule_path//./\\.}/[A-Za-z0-9_./-]+"
  while IFS= read -r ref_path; do
    if [ ! -e "$ref_path" ]; then
      echo "MISSING: $ref_path is referenced in this project but no longer exists." >&2
      missing=1
    fi
  done < <(git grep -ohE "$path_regex" -- ":(exclude)$submodule_path" | sed 's/\.*$//' | sort -u || true)

  if [ "$missing" -eq 1 ]; then
    echo "         Fix those references before committing the new pointer" >&2
    echo "         (find them with: git grep -n '<path>')." >&2
  else
    echo "Every $submodule_path/... path referenced in this project still exists."
  fi
  echo

  # ------------------------------------------------------------------------
  # What is left to do in the parent repo
  # ------------------------------------------------------------------------
  echo "Parent repo status for $submodule_path (M = new pointer not committed yet):"
  git status --short -- "$submodule_path"
  echo
  echo "To keep it, on a branch:"
  echo "  git add $submodule_path && git commit -m \"Update $submodule_path to ${new_sha:0:7}\""
  echo "To undo it:"
  echo "  git submodule update -- $submodule_path"
}

main "$@"; exit $?
