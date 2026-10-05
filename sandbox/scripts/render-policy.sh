#!/usr/bin/env bash
# Usage: render-policy.sh <org> <repo> <read|push>
#
# Builds a sandbox policy from the fragments in sandbox/policies/fragments.
#   read  the sandbox may clone and fetch the repo. It cannot push.
#   push  the sandbox may also push to the repo.
#
# Environment:
#   AGENT           agent fragment to use (default: claude)
#   ALLOW_UNTESTED  set to 1 to use a placeholder agent fragment
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 <org> <repo> <read|push>" >&2
  exit 1
fi

ORG=$1
REPO=$2
MODE=$3
AGENT=${AGENT:-claude}
DIR=$(cd "$(dirname "$0")/../policies/fragments" && pwd)

for value in "$ORG" "$REPO" "$AGENT"; do
  if ! [[ $value =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid value: $value" >&2
    exit 1
  fi
done
case $MODE in
  read|push) ;;
  *) echo "Mode must be read or push, not: $MODE" >&2; exit 1 ;;
esac

AGENT_FILE="$DIR/20-agent-$AGENT.yaml"
GITHUB_FILE="$DIR/30-github-$MODE.yaml"
for f in "$AGENT_FILE" "$GITHUB_FILE"; do
  if [ ! -f "$f" ]; then
    echo "Fragment not found: $f" >&2
    exit 1
  fi
done
if grep -q PLACEHOLDER "$AGENT_FILE" && [ "${ALLOW_UNTESTED:-}" != 1 ]; then
  echo "Agent '$AGENT' is an untested placeholder. Set ALLOW_UNTESTED=1 to use it." >&2
  exit 1
fi

cat "$DIR/00-base.yaml" "$DIR/10-npm.yaml" "$AGENT_FILE" "$GITHUB_FILE" \
  | sed -e "s|{{ORG}}|$ORG|g" -e "s|{{REPO}}|$REPO|g"
