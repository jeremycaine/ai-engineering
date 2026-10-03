# GitHub Setup

Accounts in this guide:
- `jeremycaine`: the human. Owns the org, reviews and merges every PR.
- `arkowave-agent`: the agent account. Agents push branches as this account.

## 0. Summary

1. Create the GitHub user for agents
2. Create the project organisation and set its rules
3. Create the project repos with `.gitignore` and license
4. For each repo, update `.gitignore` and add `.github/CODEOWNERS`
5. Add the ruleset script to `todo-platform`
6. Apply the ruleset to each repo
7. Create teams in the org and add members
8. Generate tokens
9. Adding a repo later

## 1. GitHub user for agents

- Create a separate email address for the agent: `<email address here>`.
  GitHub does not allow one email on two accounts. An alias in your mail admin
  console works.
- Make a new `arkowave-agent` account:
    - private browser window: https://github.com/signup
    - email `<email address here>` and username `arkowave-agent`
- Turn on two-factor authentication: Settings > Password and authentication.
  Save the recovery codes in your password manager.
- Set the profile bio to say who operates the account, e.g. "Agent account for
  arkowave-todo. Operated by @jeremycaine".

## 2. Project Organisation

GitHub as `jeremycaine`
- Create org `arkowave-todo` (Free plan)
- Add member `arkowave-agent`, then accept the invite from that account
- Org Settings > Member privileges:
    - Base permissions: **No permission**. Access then comes only from teams.
    - Repository creation by members: off
- Org Settings > Personal access tokens: allow fine-grained tokens, and require
  approval for each token

## 3. Repos

GitHub as `jeremycaine`
- Create repos
    - repos: `todo-spec`; `todo-fe-web`; `todo-api`; `todo-platform`
    - visibility: public
    - `.gitignore` type: Node
    - license: MIT

## 4. Repo Additions

Commit these to `main` now. After step 6, `main` accepts changes only through a PR.

### .gitignore
For each add
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

# TypeScript
dist/
*.tsbuildinfo
```

`todo-spec`
```
playwright-report/
test-results/
k6-results/
```

`todo-fe-web`
```
.astro/
```

`todo-api`
```
# Todo text files (runtime data, not source)
data/
```

`todo-fe-ios`
```
xcuserdata/
*.xcuserstate
```

### CODEOWNERS
On each repo page:
- add file `.github/CODEOWNERS` with
- `* @jeremycaine`

## 5. Add the ruleset script

The script needs the GitHub CLI (`gh`, see setup-env.md).

- Copy [apply-repo-rules.sh](https://github.com/arkowave-todo/todo-platform/blob/main/scripts/apply-repo-rules.sh)
  to `scripts/apply-repo-rules.sh` in `todo-platform`.
- Push it to `main` now, before any ruleset exists.
- Make it executable:

```
cd todo-platform
chmod +x scripts/apply-repo-rules.sh
```

## 6. Apply the ruleset for each repo

```
cd todo-platform
./scripts/apply-repo-rules.sh todo-platform 0
./scripts/apply-repo-rules.sh todo-spec 0
./scripts/apply-repo-rules.sh todo-api 1
./scripts/apply-repo-rules.sh todo-fe-web 1
```

The last number is the required approvals:
- `0` where only you have access. GitHub does not let you approve your own PR.
- `1` for code repos. Agent PRs need your approval.

The script adds a ruleset `main-protection` (no deletion, no force push, PR required)
and turns on secret scanning and push protection.

Check each repo:
- Settings > Rules: `main-protection` is active
- Settings > Advanced Security: secret scanning and push protection are enabled
- A direct push to `main` is refused

## 7. Create Teams and add members

Org `arkowave-todo`
- Teams
    - New teams: `dev-api` and `dev-frontend`
    - add team member `arkowave-agent`
- Repos > Settings > Collaborators and teams > Add Team with *Write*
    - `todo-api`: team `dev-api`
    - `todo-fe-web`: team `dev-frontend`

`arkowave-agent` has no access to `todo-spec` or `todo-platform`.

## 8. Generate tokens

One fine-grained token per code repo. Each sandbox gets only its own token.
There is no token for `todo-spec` or `todo-platform`.

GitHub as `arkowave-agent`
- Settings > Developer settings > Personal access tokens > Fine-grained tokens
    - Generate new token
    - Token name: `pat-todo-api` (then `pat-todo-fe-web`)
    - Resource owner: `arkowave-todo`
    - Expiration: 30 days
    - Repository access: Only select repositories > one repo, e.g. `todo-api`
    - Permissions:
        - Contents: Read and write
        - Pull requests: Read and write
        - Metadata: Read-only (GitHub adds this automatically)
    - Generate token
    - Copy the token. GitHub shows it only once. Do not paste it into a file or a chat.

The token goes into the provider command in setup-sandbox.md, step 4.

GitHub as `jeremycaine`
- Org `arkowave-todo` > Settings > Personal access tokens > Pending requests
    - Approve each token.
    - Without approval, `git push` fails with 403.

Rotation
- Set a calendar reminder for day 25.
- Make a new token, update the provider, then revoke the old token.

## 9. Adding a repo later (e.g. `todo-fe-ios`)

### Setup for any repo
1. Create the repo (public), with the right `.gitignore` template and the MIT license
2. Add the `.gitignore` additions and `.github/CODEOWNERS`
    - Push to `main` now, before the ruleset
3. Run `./scripts/apply-repo-rules.sh <repo> <approvals>`
    - 1 for code repos, 0 for spec and platform
4. Code repos only: create the team, add `arkowave-agent`, give Write on this repo only
    - Spec and platform repos: no team, no agent access
5. Check: the ruleset is active, secret scanning is enabled, and a direct push to `main` is refused

### Sandbox setup for a repo (see setup-sandbox.md)
6. Code repos only: make its token (step 8) and have `jeremycaine` approve it
7. Add its policy file in `todo-platform`, through a PR
8. Check: a push to a test branch works, and a push to another repo is refused (403)
