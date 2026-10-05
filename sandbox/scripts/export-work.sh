#!/usr/bin/env bash
# Usage: export-work.sh <sandbox> <repo-dir-in-sandbox> <branch> <local-clone>
#
# Brings commits from a sandbox branch to your machine for review. It never pushes.
#   1. bundles the branch in the sandbox (only the commits that are not on the default branch)
#   2. downloads the bundle
#   3. verifies it, and fetches it into a new local branch of <local-clone>
#   4. prints the commits and the changed files, and warns about
#      author emails that are not GitHub noreply addresses and about files
#      that add token-like text. The warnings never print the matching text.
#
# Environment:
#   EXPORT_DIR  where bundles are saved (default: ~/Downloads/sandbox-export)
set -euo pipefail

if [ $# -ne 4 ]; then
  echo "Usage: $0 <sandbox> <repo-dir-in-sandbox> <branch> <local-clone>" >&2
  exit 1
fi

SANDBOX=$1
REPO=$2
BRANCH=$3
CLONE=$4
EXPORT_DIR=${EXPORT_DIR:-$HOME/Downloads/sandbox-export}

for value in "$SANDBOX" "$REPO"; do
  if ! [[ $value =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid value: $value" >&2
    exit 1
  fi
done
if ! [[ $BRANCH =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || [[ $BRANCH == *..* ]]; then
  echo "Invalid branch name: $BRANCH" >&2
  exit 1
fi
if [ ! -d "$CLONE/.git" ]; then
  echo "Not a git clone: $CLONE" >&2
  exit 1
fi
if git -C "$CLONE" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Local branch already exists in $CLONE: $BRANCH. Delete it or review it first." >&2
  exit 1
fi

FILE="$(echo "$BRANCH" | tr '/' '-').bundle"
SANDBOX_REPO="/sandbox/$REPO"

if ! openshell sandbox exec -n "$SANDBOX" --no-tty -- git -C "$SANDBOX_REPO" rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null; then
  echo "Branch not found in the sandbox repo $SANDBOX_REPO: $BRANCH" >&2
  exit 1
fi

BASE_REMOTE=$(openshell sandbox exec -n "$SANDBOX" --no-tty -- git -C "$SANDBOX_REPO" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | tr -d '\r' || true)
BASE_REMOTE=${BASE_REMOTE:-origin/main}

openshell sandbox exec -n "$SANDBOX" --no-tty -- mkdir -p /sandbox/bundles
openshell sandbox exec -n "$SANDBOX" --no-tty -- git -C "$SANDBOX_REPO" bundle create "/sandbox/bundles/$FILE" "$BRANCH" --not "$BASE_REMOTE"
mkdir -p "$EXPORT_DIR"
openshell sandbox download "$SANDBOX" "/sandbox/bundles/$FILE" "$EXPORT_DIR"
openshell sandbox exec -n "$SANDBOX" --no-tty -- rm -f "/sandbox/bundles/$FILE"

git -C "$CLONE" fetch --quiet origin
git -C "$CLONE" bundle verify "$EXPORT_DIR/$FILE"
git -C "$CLONE" fetch --quiet "$EXPORT_DIR/$FILE" "$BRANCH:$BRANCH"

BASE=$(git -C "$CLONE" symbolic-ref -q --short refs/remotes/origin/HEAD || echo "$BASE_REMOTE")

echo
echo "== Commits"
git -C "$CLONE" --no-pager log --format='%h %an <%ae>%n   %s' "$BASE..$BRANCH"
echo
echo "== Files"
git -C "$CLONE" --no-pager diff --stat "$BASE...$BRANCH"
echo
echo "== Checks"
checks=0
others=$(git -C "$CLONE" log --format='%ae%n%ce' "$BASE..$BRANCH" | sort -u | grep -v 'users\.noreply\.github\.com$' || true)
if [ -n "$others" ]; then
  echo "WARNING: author or committer email is not a GitHub noreply address:"
  echo "$others" | sed 's/^/  /'
  checks=1
fi
PATTERN='github_pat_|ghp_[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY|sk-ant-'
flagged=""
while IFS= read -r f; do
  if git -C "$CLONE" diff "$BASE...$BRANCH" -- "$f" | grep -E '^\+' | grep -qE "$PATTERN"; then
    flagged="$flagged  $f"$'\n'
  fi
done < <(git -C "$CLONE" diff --name-only "$BASE...$BRANCH")
if [ -n "$flagged" ]; then
  echo "WARNING: added lines in these files look like a token or a key (best effort check):"
  printf '%s' "$flagged"
  checks=1
fi
if [ "$checks" -eq 0 ]; then
  echo "No warnings."
fi

echo
echo "Branch '$BRANCH' is now in $CLONE. Nothing was pushed."
echo "After review, push it yourself: git -C $CLONE push -u origin $BRANCH"
