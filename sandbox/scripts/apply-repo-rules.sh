#!/usr/bin/env bash
# Usage: apply-repo-rules.sh <org> <repo> <required-approvals>
#
# Applies the ruleset "main-protection" to the default branch of a repo:
# no deletion, no force push, and changes only through a pull request.
# It also turns on secret scanning and push protection.
# If the ruleset exists, it is updated, so a changed approval count is applied.
#
# Needs the GitHub CLI, logged in as a person who has admin on the repo.
# Rulesets on a private repo need a paid GitHub plan.
#
# Environment:
#   DRY_RUN=1  print what would happen and change nothing
set -euo pipefail
export GH_PAGER=cat

if [ $# -ne 3 ]; then
  echo "Usage: $0 <org> <repo> <required-approvals>" >&2
  exit 1
fi
ORG=$1
REPO=$2
APPROVALS=$3
for value in "$ORG" "$REPO"; do
  if ! [[ $value =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid value: $value" >&2
    exit 1
  fi
done
if ! [[ $APPROVALS =~ ^([0-9]|10)$ ]]; then
  echo "Required approvals must be a whole number from 0 to 10, not: $APPROVALS" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "Not logged in to GitHub. Run: gh auth login" >&2
  exit 1
fi

if ! facts=$(gh api "repos/$ORG/$REPO" --jq '"\(.private) \(.permissions.admin)"' 2>/dev/null); then
  echo "Cannot read $ORG/$REPO. It does not exist, or you have no access." >&2
  exit 1
fi
read -r private admin <<<"$facts"
if [ "$private" = "true" ]; then
  echo "NOTE: $ORG/$REPO is private. Rulesets on a private repo need a paid GitHub plan (Pro, Team or Enterprise). If the call fails with 403, use read mode for this repo." >&2
fi
if [ "$admin" != "true" ]; then
  echo "You need admin access on $ORG/$REPO to set rules." >&2
  exit 1
fi

BODY=$(cat <<EOF
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": $APPROVALS,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false } }
  ]
}
EOF
)

RULESET_ID=$(gh api "repos/$ORG/$REPO/rulesets" --jq '.[] | select(.name == "main-protection") | .id' 2>/dev/null | head -1 || true)

if [ "${DRY_RUN:-}" = 1 ]; then
  if [ -n "$RULESET_ID" ]; then
    action="update the ruleset main-protection (id $RULESET_ID)"
  else
    action="create the ruleset main-protection"
  fi
  echo "DRY RUN: would $action with $APPROVALS required approvals on $ORG/$REPO, and turn on secret scanning and push protection."
  exit 0
fi

if [ -n "$RULESET_ID" ]; then
  method=PUT
  url="repos/$ORG/$REPO/rulesets/$RULESET_ID"
  done_msg="ruleset updated"
else
  method=POST
  url="repos/$ORG/$REPO/rulesets"
  done_msg="ruleset created"
fi
if ! out=$(printf '%s' "$BODY" | gh api "$url" --method "$method" --input - 2>&1); then
  echo "$ORG/$REPO: the ruleset call failed:" >&2
  echo "$out" | head -5 >&2
  echo "On a private repo this usually means that the plan has no rulesets. Use read mode for this repo." >&2
  exit 1
fi
echo "$REPO: $done_msg ($APPROVALS required approvals)"

if ! out=$(gh api "repos/$ORG/$REPO" --method PATCH --input - 2>&1 <<'EOF'
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" } } }
EOF
); then
  echo "$ORG/$REPO: turning on secret scanning failed:" >&2
  echo "$out" | head -5 >&2
  exit 1
fi
echo "$REPO: security settings applied"
