# Sandbox Setup

Run coding agents in sandboxes, one per repo. Each sandbox has its own network policy,
its own GitHub token (code repos only) and Claude Code.

Before you start, finish [setup-env.md](setup-env.md) (Podman, OpenShell, gateway)
and [setup-github.md](setup-github.md) (org, repos, rulesets, tokens).

Run every command on your Mac from the root of the
[todo-platform](https://github.com/arkowave-todo/todo-platform) repo, unless a step
says "in the sandbox".

## 0. Summary

1. Build the base image
2. Import the GitHub provider profile
3. Write one policy file per sandbox
4. Make tokens and providers
5. Create the sandboxes
6. Test each sandbox
7. Troubleshooting
8. Limits and next steps

After this, see [daily-use.md](daily-use.md).

## 1. Base image

File: [images/Dockerfile](https://github.com/arkowave-todo/todo-platform/blob/main/images/Dockerfile).
It holds Node 22, git, curl, iproute2, Claude Code and a user `sandbox`
(UID and GID 1000, home `/sandbox`).

```
podman build -t todo-sandbox-base:0.1 images
openshell sandbox create --name img-test --no-keep --from localhost/todo-sandbox-base:0.1 -- \
  sh -c 'whoami; which git node npm curl claude; claude --version'
```

The default OpenShell image is bare Ubuntu. It has no git, node or Claude Code,
so we build our own.

## 2. GitHub provider profile

The gateway has no built-in profiles. Import one.

```
mkdir -p providers
curl -fsSL https://raw.githubusercontent.com/NVIDIA/OpenShell/main/providers/github.yaml -o providers/github.yaml
openshell provider profile lint -f providers/github.yaml
openshell provider profile import -f providers/github.yaml --global
openshell profile list
```

- Keep the copy in `providers/github.yaml` in the repo. Review changes in a PR.
- Keep the license header in the file. It comes from the OpenShell project (Apache-2.0).
- The profile allows clone and fetch only. A push needs a rule in the policy file.

## 3. Policy files

| File | Sandbox | npm | Claude Code | Push |
| --- | --- | --- | --- | --- |
| `policies/api.yaml` | `todo-api` | yes | yes | only to `todo-api` |
| `policies/fe-web.yaml` | `todo-fe-web` | yes | yes | only to `todo-fe-web` |
| `policies/spec.yaml` | `todo-spec` | yes | yes | none (read only) |

Each file holds:
- `filesystem_policy` and `landlock`: same as the OpenShell default
- `npm_registry`: `registry.npmjs.org:443` for `node` and `curl`
- `claude_code`: `api.anthropic.com`, `claude.ai` and `platform.claude.com` for `claude`
- `github_repository_push`: GitHub paths for one repo only, for `git`
  (`spec.yaml` has a read rule without `git-receive-pack`)

Key rules:
- Default is deny. A rule with no `binaries` section allows no program.
- Use the real file path of a program, not a symlink. Check with `readlink -f`.
- See what was denied with `openshell logs <sandbox> --tail`.
- `openshell policy set <sandbox> --policy <file>` replaces the whole policy.
  Keep the filesystem and landlock sections the same.
- Policy changes load without a restart.
- Claude Code with a subscription login needs no provider, only the three hosts.

## 4. Tokens and providers

Make one fine-grained token per code repo, and approve it
(see setup-github.md, step 8). An unapproved token fails with 403.
Then make a provider from it. This is zsh. It reads the token without showing it:

```
read -s "GITHUB_TOKEN?Paste token and press Enter: "
GITHUB_TOKEN=$GITHUB_TOKEN openshell provider create --name github-todo-api --type github --from-existing
unset GITHUB_TOKEN
openshell provider list
```

Repeat for `todo-fe-web` with the name `github-todo-fe-web`.

- `todo-spec` has no token and no provider.
- In the sandbox, `GITHUB_TOKEN` holds a placeholder (`openshell:resolve:env:...`).
  The proxy swaps in the real token only for the allowed GitHub hosts.

## 5. Create the sandboxes

```
./scripts/create-sandbox.sh todo-api todo-api policies/api.yaml github-todo-api
./scripts/create-sandbox.sh todo-fe-web todo-fe-web policies/fe-web.yaml github-todo-fe-web
./scripts/create-sandbox.sh todo-spec todo-spec policies/spec.yaml
openshell sandbox list
```

Usage: `create-sandbox.sh <sandbox-name> <repo> <policy-file> [provider]`

The script:
1. Creates the sandbox with `sleep infinity` as the main process
2. Clones the repo (the `.git` folder is not copied from your Mac)
3. Sets the git credential helper, name and email

The main process decides the life of the sandbox. If it were a shell, leaving the
shell would end the sandbox.

All three sandboxes must show `Ready`. The first time you use Claude Code in a
sandbox, you log in. See [daily-use.md](daily-use.md).

## 6. Test each sandbox

Open a shell in the sandbox (see [daily-use.md](daily-use.md)). Set the two names,
then run the block. `OTHER` is a different project repo.

```
REPO=todo-api
OTHER=todo-fe-web

env | grep -i -E "token|github"
cd ~/$REPO
git checkout -b agent/token-test
git commit --allow-empty -m "Test push from sandbox"
git push -u origin agent/token-test
git push https://github.com/arkowave-todo/$OTHER.git agent/token-test
git checkout main
git commit --allow-empty -m "Test direct push"
git push origin main
git reset --hard origin/main
git push origin --delete agent/token-test
git branch -D agent/token-test
git status
```

| Command | Expected |
| --- | --- |
| `env \| grep` | Only `openshell:resolve:env:...` placeholders |
| Push to own test branch | Works |
| Push to another repo | Fails with 403 |
| Push to `main` | Rejected: changes must be made through a pull request |
| Last lines | Test branch deleted, clean tree |

For `todo-fe-web`, use `REPO=todo-fe-web` and `OTHER=todo-api`.

`todo-spec` has no token. Use `REPO=todo-spec`. Every push must fail, `env | grep`
prints nothing, and the delete step fails because nothing was pushed.

## 7. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `sandbox create -- claude` fails, no such file | Default image has no Claude Code | Use our image with `--from` |
| `EACCES` for npm or curl after adding a host | Rule has no `binaries` section | Add the program path, check `openshell logs` |
| `could not read Username` on push | No git credential helper | Set it (see `create-sandbox.sh`) |
| `Invalid username or token` on push | Helper read `$GH_TOKEN`, which is empty | Use `$GITHUB_TOKEN` |
| 403 on push to the right repo | Token not approved, or wrong repo | Approve it in the org settings, check the repo |
| Phase `Error`, `canonical main process already finished` | The main process was a shell that ended | Use `sleep infinity` and open shells with `exec` |
| Phase stuck in `Provisioning` | Broken run | `openshell sandbox delete`, then create again |
| `sandbox connect` hangs | `connect` attaches to the main process | Use `sandbox exec --tty` |

Useful commands: `openshell sandbox list`, `openshell sandbox get <name> --output json`,
`openshell logs <name> --tail`, `podman ps -a`, `openshell policy get <name> --base`.

## 8. Limits and next steps

- Tokens expire after 30 days. Rotate them before that.
- Pin the base image by digest and Claude Code by version.
- Add a `CLAUDE.md` to each repo: the spec is the source of truth, push only branches.
- Add `gh` to the image so agents can open PRs, with a rule for `api.github.com`.
- A sandbox protects your Mac. It does not check the code the agent writes. Review every PR.
