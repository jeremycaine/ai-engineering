#!/usr/bin/env bash
# Usage: create-sandbox.sh <sandbox-name> <repo> <policy-file> [provider]
#
# Environment:
#   ORG              required. GitHub organisation or user that owns the repo.
#   AGENT_GIT_NAME   required. GitHub username of the agent account (used as the commit name).
#   AGENT_GIT_EMAIL  required. Commit email of the agent account.
#                    Use its GitHub noreply address: <id>+<user>@users.noreply.github.com
#   IMAGE            sandbox image (default: localhost/agent-sandbox-claude:0.1)
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <sandbox-name> <repo> <policy-file> [provider]" >&2
  exit 1
fi

NAME=$1
REPO=$2
POLICY=$3
PROVIDER=${4:-}
ORG=${ORG:?Set ORG to the GitHub organisation or user that owns the repo}
IMAGE=${IMAGE:-localhost/agent-sandbox-claude:0.1}
GIT_NAME=${AGENT_GIT_NAME:?Set AGENT_GIT_NAME to the GitHub username of the agent account}
GIT_EMAIL=${AGENT_GIT_EMAIL:?Set AGENT_GIT_EMAIL to the GitHub noreply address of the agent account}

for value in "$NAME" "$REPO" "$ORG" "$GIT_NAME"; do
  if ! [[ $value =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid value: $value" >&2
    exit 1
  fi
done
if ! [[ $GIT_EMAIL =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+$ ]]; then
  echo "Invalid AGENT_GIT_EMAIL: $GIT_EMAIL" >&2
  exit 1
fi
if [ ! -f "$POLICY" ]; then
  echo "Policy file not found: $POLICY" >&2
  exit 1
fi

args=(--name "$NAME" --from "$IMAGE" --policy "$POLICY" --no-auto-providers --detach)
if [ -n "$PROVIDER" ]; then
  args+=(--provider "$PROVIDER")
fi

openshell sandbox create "${args[@]}" -- sleep infinity

# The credential helper is set before the clone, so a private repo can be cloned.
if ! openshell sandbox exec -n "$NAME" --no-tty -- bash -s <<EOF
set -e
HELPER='!f() { echo username=x-access-token; echo password=\$GITHUB_TOKEN; }; f'
git -c credential.helper="\$HELPER" clone https://github.com/$ORG/$REPO.git ~/$REPO
cd ~/$REPO
git config --local credential.helper "\$HELPER"
git config user.name '$GIT_NAME'
git config user.email '$GIT_EMAIL'
git status --short --branch
EOF
then
  echo "$NAME: setup failed. Remove it with: openshell sandbox delete $NAME" >&2
  exit 1
fi

echo "$NAME: ready. Open a shell with: openshell sandbox exec -n $NAME --tty -- /bin/bash -l"
