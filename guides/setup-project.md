# Project Setup

Do this once per project. A project repo records what each sandbox may do, and creates
the sandbox from that record.

Before you start, finish [setup-env.md](setup-env.md), [setup-github.md](setup-github.md)
and [setup-sandbox.md](setup-sandbox.md) (the images and the provider profile).

## 0. Summary

1. Make the project repo from the template
2. Add a project
3. Token and provider
4. Render and check the policy
5. Create the sandbox
6. Test the sandbox
7. Change a policy later
8. Troubleshooting

## 1. The project repo

The template is `sandbox/project-template/` in this repo. Its README explains each file.

Make a repo on GitHub, named for example `platform`. Make it **private** if it will name
private repos. Add no license to a private repo that holds business settings. Then:

```
git clone https://github.com/<org>/platform.git
cd platform
git checkout -b add-first-project
cp -R <path-to>/ai-engineering/sandbox/project-template/. .
```

Two rules for this repo:
1. **No secrets, ever.** No token, no password, no deploy credential.
2. **No agent account has access to it.** If the agent could edit its own policy, the
   limits would mean nothing.

On a private repo on the Free plan, GitHub cannot force a pull request. Work on a
branch, open a pull request, and review it as a habit.

`tooling.lock` pins the commit of this repo that the project uses. A newer version is a
deliberate change: see section 7.

## 2. Add a project

A project is one repo that gets a sandbox. The sandbox is named after the project.

```
cp -R projects/example projects/<name>
```

Edit `projects/<name>/project.env`:

| Key | Meaning |
| --- | --- |
| `ORG` | The organisation or user that owns the repo |
| `REPO` | The repo name |
| `MODE` | `read` or `push` (see setup-github.md, section 1) |
| `AGENT` | The agent layer: `claude` is the tested one |
| `AGENT_GIT_NAME` | The GitHub username of the agent account |
| `PROVIDER` | The name of the OpenShell provider that holds the token. Leave it empty for a public repo that the sandbox only reads. |
| `IMAGE` | The agent image that you built in setup-sandbox.md |

The file holds no secret. It holds the *name* of a provider, never a token.

## 3. Token and provider

Make and test the token as in setup-github.md, section 7. Then make the provider. This
is zsh. It reads the token without showing it:

```
read -s "GITHUB_TOKEN?Paste token and press Enter: "
GITHUB_TOKEN=$GITHUB_TOKEN openshell provider create --name github-<repo> --type github --from-existing
unset GITHUB_TOKEN
openshell provider list
```

The name must match `PROVIDER` in `project.env`. In the sandbox, `GITHUB_TOKEN` holds a
placeholder (`openshell:resolve:env:...`). The proxy swaps in the real token only for the
allowed GitHub hosts.

## 4. Render and check the policy

```
scripts/policy.sh render <name>
scripts/policy.sh check
```

`render` writes `projects/<name>/policy.yaml` from the pinned tooling. `check` renders
again and compares with the committed file. It exits with 1 on any difference.

In read mode, the policy must have no push rule:

```
grep -c receive-pack projects/<name>/policy.yaml
```

The result must be `0`. Commit the files on your branch, open a pull request, and read
the `policy.yaml` diff. It is the part that the review is for. Merge it.

## 5. Create the sandbox

`AGENT_GIT_EMAIL` must be set in your shell (setup-github.md, section 2). Then:

```
scripts/sandbox.sh up <name>
```

The command refuses, with a message that says what to do, if:
- the policy has drifted from a fresh render,
- a sandbox with that name already exists,
- the image is not built,
- the provider does not exist.

Otherwise it creates the sandbox, clones the repo (a private repo works, because the
credential helper is set before the clone), and sets the git identity.

```
scripts/sandbox.sh shell <name>
```

## 6. Test the sandbox

In the sandbox shell, in read mode:

```
env | grep -i -E "token|github"
cd ~/<repo>
git status -sb
git commit --allow-empty -m "push probe"
git push origin HEAD:refs/heads/push-probe
git reset --hard HEAD~1
```

| Command | Expected |
| --- | --- |
| `env \| grep` | Only `openshell:resolve:env:...` placeholders |
| `git status -sb` | `## main...origin/main`, and the files of the repo |
| The push | Refused. `Write access to repository not granted` comes from GitHub and the read-only token. A 403 with no `remote:` line comes from the sandbox policy. Both are a pass. |
| The reset | Removes the probe commit |

In push mode, run this block. Use another repo of the project for `OTHER`:

```
REPO=<repo>
OTHER=<other-repo>

env | grep -i -E "token|github"
cd ~/$REPO
git checkout -b agent/token-test
git commit --allow-empty -m "Test push from sandbox"
git push -u origin agent/token-test
git push https://github.com/<org>/$OTHER.git agent/token-test
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
| Push to your own test branch | Works |
| Push to the other repo | Fails with 403 |
| Push to `main` | Rejected: changes must be made through a pull request |
| Last lines | Test branch deleted, clean tree |

Last, test the way work comes out. In the sandbox, make a branch with one empty commit.
Then, on your machine:

```
scripts/sandbox.sh export <name> <branch>
```

You must see the commit with the agent's noreply address, `No warnings.`, and
`Nothing was pushed.`

## 7. Change a policy later

- **A new rule or setting:** edit `project.env` or the fragments in the tooling. Run
  `scripts/policy.sh render <name>`. Read the diff. Open a pull request. After the merge,
  apply it to the running sandbox:

```
openshell policy set <name> --policy projects/<name>/policy.yaml
```

- **A newer tooling version:** change `TOOLING_COMMIT` and `TOOLING_TAG` in `tooling.lock`.
  Pin a commit, because a tag can be moved. Run `render`, and read the diff of every
  `policy.yaml`.

## 8. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Provider not found` | The provider is not made | Make it (section 3) |
| `Image not found` | The agent image is not built | Build it (setup-sandbox.md, section 2) |
| `DRIFT. policy.yaml differs from a fresh render` | A file was edited by hand, or the tooling changed | Run `render`, read the diff |
| `Set AGENT_GIT_EMAIL ...` | The variable is not in your shell | Set it (setup-github.md, section 2) |
| A private repo clone fails with a 404 | No access, or an invitation that you have not accepted | setup-github.md, section 4 |
| A private repo clone fails with `could not read Username` | The git credential helper is not set | `create-sandbox.sh` sets it before the clone. Use `sandbox.sh up`. |
| `Invalid username or token` on push | The helper read `$GH_TOKEN`, which is empty | The helper must read `$GITHUB_TOKEN` |
| 403 on a push to the right repo (push mode) | The token is not approved, or it is for another repo | Approve it in the org settings |
| `EACCES` for a tool or npm after adding a host | The rule has no `binaries` section | Add the program path. Check `openshell logs <name> --tail`. |
| npm fails on a scoped package | The registry endpoint lacks `allow_encoded_slash: true` | Use the npm fragment from this repo |
| An npm audit request is denied | The audit is a POST, and the registry rule is read-only | Expected. The base image turns the audit off. Run audits on your machine. |
| `sandbox download` refuses a path | It only reads under `/sandbox` | `export` writes its bundle to `/sandbox/bundles` |
| Phase `Error`, `canonical main process already finished` | The main process was a shell that ended | Use `sleep infinity` and open shells with `exec` (`up` does) |
| Phase stuck in `Provisioning` | A broken run | `openshell sandbox delete <name>`, then `up` again |
| `sandbox connect` hangs | `connect` attaches to the main process | Use `sandbox exec --tty` (`sandbox.sh shell`) |

Useful commands: `openshell sandbox list`, `openshell sandbox get <name> --output json`,
`openshell logs <name> --tail`, `podman ps -a`, `openshell policy get <name> --base`.
