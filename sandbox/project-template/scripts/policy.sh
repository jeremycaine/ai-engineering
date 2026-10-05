#!/usr/bin/env bash
# Usage: policy.sh render [project]    write projects/<project>/policy.yaml from the pinned tooling
#        policy.sh check  [project]    compare the committed policy.yaml with a fresh render
#
# The tooling version is pinned in tooling.lock (a commit of ai-engineering).
# Environment:
#   TOOLING_CACHE  where the tooling is cloned (default: ~/.cache/arkowave-platform)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)

usage() { echo "Usage: $0 <render|check|path> [project]" >&2; exit 1; }
[ $# -ge 1 ] && [ $# -le 2 ] || usage
CMD=$1
ONLY=${2:-}
case $CMD in render|check|path) ;; *) usage ;; esac
if ! [[ $ONLY =~ ^[A-Za-z0-9._-]*$ ]]; then
  echo "Invalid project name: $ONLY" >&2
  exit 1
fi

get() { sed -n "s/^$1=//p" "$ROOT/$2" | head -1; }

REPO_URL=$(get TOOLING_REPO tooling.lock)
COMMIT=$(get TOOLING_COMMIT tooling.lock)
if [ -z "$REPO_URL" ] || ! [[ $COMMIT =~ ^[0-9a-f]{40}$ ]]; then
  echo "tooling.lock needs TOOLING_REPO and a 40-character TOOLING_COMMIT" >&2
  exit 1
fi

CACHE=${TOOLING_CACHE:-$HOME/.cache/arkowave-platform}/ai-engineering
if [ ! -d "$CACHE/.git" ]; then
  mkdir -p "$(dirname "$CACHE")"
  git clone --quiet "$REPO_URL" "$CACHE"
fi
git -C "$CACHE" fetch --quiet --tags origin
git -C "$CACHE" checkout --quiet "$COMMIT"
if [ "$CMD" = path ]; then echo "$CACHE"; exit 0; fi
RENDER="$CACHE/sandbox/scripts/render-policy.sh"

status=0
found=0
for dir in "$ROOT"/projects/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  if [ -n "$ONLY" ] && [ "$ONLY" != "$name" ]; then
    continue
  fi
  found=1
  env_file="projects/$name/project.env"
  org=$(get ORG "$env_file")
  repo=$(get REPO "$env_file")
  mode=$(get MODE "$env_file")
  agent=$(get AGENT "$env_file")
  if [ -z "$org" ] || [ -z "$repo" ] || [ -z "$mode" ] || [ -z "$agent" ]; then
    echo "$name: project.env needs ORG, REPO, MODE and AGENT" >&2
    status=1
    continue
  fi
  fresh=$(mktemp)
  if ! AGENT=$agent "$RENDER" "$org" "$repo" "$mode" > "$fresh"; then
    echo "$name: render failed" >&2
    status=1
    rm -f "$fresh"
    continue
  fi
  if [ "$CMD" = render ]; then
    cp "$fresh" "${dir%/}/policy.yaml"
    echo "$name: policy.yaml written"
  elif diff -u "${dir%/}/policy.yaml" "$fresh" >/dev/null 2>&1; then
    echo "$name: ok"
  else
    echo "$name: DRIFT. policy.yaml differs from a fresh render. Run: $0 render $name" >&2
    diff -u "${dir%/}/policy.yaml" "$fresh" 2>&1 | head -20 >&2 || true
    status=1
  fi
  rm -f "$fresh"
done
if [ "$found" -eq 0 ]; then
  echo "No project found${ONLY:+: $ONLY}" >&2
  exit 1
fi
exit $status
