#!/usr/bin/env bash
# Usage: sandbox.sh up <project>                create the sandbox for a project
#        sandbox.sh shell <project>             open a shell in it
#        sandbox.sh export <project> <branch>   bring a branch out for review (never pushes)
#
# The sandbox is named after the project. Settings come from projects/<project>/project.env.
# Environment:
#   AGENT_GIT_EMAIL  required for up. GitHub noreply address of the agent account.
#   CLONE_ROOT       where your local clones live, as <root>/<org>/<repo> (default: ~/code/github.com)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
usage() {
  echo "Usage: $0 up <project> | shell <project> | export <project> <branch>" >&2
  exit 1
}
[ $# -ge 2 ] || usage
CMD=$1
PROJECT=$2
if ! [[ $PROJECT =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid project name: $PROJECT" >&2
  exit 1
fi
ENV_FILE="$ROOT/projects/$PROJECT/project.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "No project: $PROJECT" >&2
  exit 1
fi
get() { sed -n "s/^$1=//p" "$ENV_FILE" | head -1; }
ORG=$(get ORG)
REPO=$(get REPO)
AGENT_GIT_NAME=$(get AGENT_GIT_NAME)
PROVIDER=$(get PROVIDER)
IMAGE=$(get IMAGE)
for name in ORG REPO AGENT_GIT_NAME IMAGE; do
  if [ -z "${!name}" ]; then
    echo "$PROJECT: project.env needs $name" >&2
    exit 1
  fi
done

case $CMD in
  up)
    [ $# -eq 2 ] || usage
    : "${AGENT_GIT_EMAIL:?Set AGENT_GIT_EMAIL to the GitHub noreply address of the agent account}"
    "$ROOT/scripts/policy.sh" check "$PROJECT"
    if openshell sandbox list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$PROJECT"; then
      echo "$PROJECT: a sandbox with this name already exists. Delete it first: openshell sandbox delete $PROJECT" >&2
      exit 1
    fi
    if ! podman image exists "$IMAGE"; then
      echo "Image not found: $IMAGE" >&2
      echo "Build it from the tooling (see sandbox/images in the ai-engineering repo)." >&2
      exit 1
    fi
    if [ -n "$PROVIDER" ] && ! openshell provider list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$PROVIDER"; then
      echo "Provider not found: $PROVIDER" >&2
      echo "Create it with the token: openshell provider create --name $PROVIDER --type github --from-existing" >&2
      exit 1
    fi
    TOOLING=$("$ROOT/scripts/policy.sh" path)
    args=("$PROJECT" "$REPO" "$ROOT/projects/$PROJECT/policy.yaml")
    if [ -n "$PROVIDER" ]; then
      args+=("$PROVIDER")
    fi
    ORG=$ORG AGENT_GIT_NAME=$AGENT_GIT_NAME IMAGE=$IMAGE AGENT_GIT_EMAIL=$AGENT_GIT_EMAIL \
      "$TOOLING/sandbox/scripts/create-sandbox.sh" "${args[@]}"
    ;;
  shell)
    [ $# -eq 2 ] || usage
    exec openshell sandbox exec -n "$PROJECT" --tty -- /bin/bash -l
    ;;
  export)
    [ $# -eq 3 ] || usage
    CLONE="${CLONE_ROOT:-$HOME/code/github.com}/$ORG/$REPO"
    TOOLING=$("$ROOT/scripts/policy.sh" path)
    "$TOOLING/sandbox/scripts/export-work.sh" "$PROJECT" "$REPO" "$3" "$CLONE"
    ;;
  *)
    usage
    ;;
esac
