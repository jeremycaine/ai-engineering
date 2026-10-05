# GitHub Setup

Names in this guide:
- `<you>` is your own GitHub account. You review and merge.
- `<agent>` is the agent account.
- `<org>` is the organisation or user that owns the repos.

## 0. Summary

1. Choose a mode for each repo: push or read
2. The agent account
3. Organisation settings
4. Get access to the repo
5. Push mode: files, rules and teams
6. Read mode
7. Tokens
8. Adding a repo later

## 1. Push mode or read mode

| | Push mode | Read mode |
| --- | --- | --- |
| Use when | GitHub can enforce "no direct push to `main`": a public repo, or a paid plan | The repo is private on the Free plan, or has no branch rules |
| The agent | Pushes branches. You review and merge the pull request. | Commits in the sandbox and cannot push. You bring the commits out and push. |
| Token | Read and write | Read-only |

GitHub's documentation says that rulesets are available in public repos on the Free plan,
and in public and private repos on Pro, Team and Enterprise. A ruleset is what stops an
agent that has write access from pushing to `main`. Where you cannot have one, take away
the write access instead.

Choose the mode for each repo. If in doubt, use read mode.

If a push to `main` publishes your site or your package, treat `main` as a release.
Credentials that publish stay with you and never go into a sandbox.

## 2. The agent account

Do this once. The account gives the agent a commit identity. In push mode it also owns the tokens.

- Make a separate email address for the agent. GitHub does not allow one email on two
  accounts. An alias in your mail console works.
- Make the account in a private browser window: https://github.com/signup
- Turn on two-factor authentication (Settings > Password and authentication).
  Save the recovery codes in your password manager.
- Set the profile bio to say who operates the account.
- Settings > Emails: turn on **Keep my email addresses private** and
  **Block command line pushes that expose my email**. GitHub then rejects a push
  whose commits carry any other address.
- Find the account id and form its noreply address:

```
gh api users/<agent> --jq .id
```

The address is `<id>+<agent>@users.noreply.github.com`. It is public by design and
receives no mail. Put it in your shell profile (`~/.zshrc`):

```
export AGENT_GIT_EMAIL="<id>+<agent>@users.noreply.github.com"
```

## 3. Organisation settings

Skip this for a personal account. An org owner sets these (the menu names can change):

- Settings > Member privileges: **Base permissions: No permission**, so that access comes
  only from teams. **Repository creation by members: off**.
- Settings > Personal access tokens: allow fine-grained tokens, and require approval for each token.

## 4. Get access to the repo

You need access to review and to push.

- In an org, an owner invites you: org > People > Invite member. For one repo, the owner
  adds you under repo Settings > Collaborators and teams, with the **Write** role.
- Accept the invitations as yourself:
    - `https://github.com/orgs/<org>/invitation` for the org
    - `https://github.com/<org>/<repo>/invitations` for the repo
- A private repo returns 404 until you accept. Check your access:

```
gh api repos/<org>/<repo> --jq '{private: .private, default_branch: .default_branch, push: .permissions.push}'
```

You must see `push: true`. A 404 means no access, or an invitation that you have not accepted.

Keep every agent account off the access list of the repo that records the sandbox
settings (see setup-project.md).

## 5. Push mode: files, rules and teams

### Files for each repo

Commit these to `main` first. After the ruleset, `main` accepts changes only through a PR.

- A `.gitignore` with at least:

```
# macOS
.DS_Store

# Secrets
.env
.env.*
!.env.example

# Editor
.vscode/
.idea/
```

Add anything that must never be committed: runtime data, build output.

- A `.github/CODEOWNERS` file with `* @<you>`.
- A license.

### The ruleset

The script is `sandbox/scripts/apply-repo-rules.sh` in this repo. It needs the GitHub CLI
(see setup-env.md) and admin access on the repo. It is safe to run again: it updates the
ruleset if it exists. From the root of this repo:

```
sandbox/scripts/apply-repo-rules.sh <org> <repo> <approvals>
```

The last number is the required approvals:
- `0` where only you have access. GitHub does not let you approve your own PR.
- `1` for code repos where the agent opens pull requests. They need your approval.

The script adds a ruleset `main-protection` (no deletion, no force push, PR required)
and turns on secret scanning and push protection. Check each repo:
- Settings > Rules: `main-protection` is active
- Settings > Advanced Security: secret scanning and push protection are enabled
- A direct push to `main` is refused

### Teams

For each code repo, make a team, add `<agent>`, and give the team **Write** on that repo only.
The agent account has no access to the spec repo or the project repo.

## 6. Read mode

There is no ruleset, so the protection comes from taking write access away:

- the token is read-only (section 7),
- the sandbox policy has no push rule (setup-project.md renders it for you),
- no agent account has access to the repo that records the sandbox settings.

Keep the access list of the repo short, and check it when you add people. You push
branches from your own clone. Find out whether a branch deploys before you push one.

The token can come from any account that has read access to the repo, as long as it is
scoped to that one repo and is read-only.

## 7. Tokens

One fine-grained token per repo. Each sandbox gets only its own.

GitHub: Settings > Developer settings > Personal access tokens > Fine-grained tokens >
Generate new token.

- Token name: `pat-<repo>`
- Resource owner: `<org>`
- Expiration: 30 days
- Repository access: **Only select repositories**, and pick one repo
- Permissions:
    - Contents: **Read and write** in push mode, **Read-only** in read mode
    - Pull requests: **Read and write** in push mode, **No access** in read mode
    - Metadata: Read-only (GitHub adds it)
- Copy the token. GitHub shows it only once. Do not paste it into a file or a chat.

An org owner approves each token: org > Settings > Personal access tokens > Pending requests.
Until then, requests fail.

Test the token before you use it. This reads it without showing it:

```
read -s "GITHUB_TOKEN?Paste token and press Enter: "
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/repos/<org>/<repo>
unset GITHUB_TOKEN
```

- `200`: the token reaches the repo.
- `404`: no access, or the token is not approved yet.
- `401`: the value is wrong.

The token goes into the provider command in setup-project.md.

Rotation: set a calendar reminder for day 25. Make a new token and test it, update the
provider, then revoke the old token.

## 8. Adding a repo later

1. Choose its mode (section 1).
2. Push mode: add the files, run the ruleset script, make the team (section 5).
   Read mode: check the access list (section 6).
3. Make and test its token (section 7).
4. Add it as a project (setup-project.md).
