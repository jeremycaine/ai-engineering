# Sandbox Tooling

The parts that you build once per machine: the images, the provider profile, and the
policy fragments. Per-project setup is in [setup-project.md](setup-project.md).

Before you start, finish [setup-env.md](setup-env.md). Get this repo, and run the
commands from its root, unless a step says otherwise:

```
git clone https://github.com/jeremycaine/ai-engineering.git
cd ai-engineering
```

## 0. Summary

1. Build the base image
2. Build an agent layer
3. Test the images
4. Import the GitHub provider profile
5. How policies are built
6. Limits and next steps

## 1. Base image

File: `sandbox/images/base/Dockerfile`. It holds Node 22, git, curl, iproute2, `jq`,
Python 3 (as `python3` and `python`), and a user `sandbox` (UID and GID 1000, home
`/sandbox`). It holds no agent.

```
podman build -t agent-sandbox-base:0.1 sandbox/images/base
```

- The default OpenShell image is bare Ubuntu. It has no git, no Node and no agent, so we build our own.
- The image turns off the npm audit. The sandbox policy allows only read requests to the npm
  registry, and the audit is a POST.
- Python has no network rule, so `pip install` stays blocked. It is for scripting on local files.
- To pin the Node base by digest, pass `--build-arg NODE_IMAGE=<image>@sha256:<digest>`.

## 2. Agent layer

Each agent is a thin layer on the base. You build it on your own machine from a pinned
version. Do not publish the result. Claude Code is proprietary software, and its terms
do not give you the right to redistribute it.

```
podman build -t agent-sandbox-claude:0.1 \
  --build-arg CLAUDE_CODE_VERSION=<version> \
  sandbox/images/agents/claude
```

- There is no default version. A build without one fails with a message. Choose a
  version on purpose. Version 2.1.286 is the one that was tested.
- The layer installs Claude Code from npm, and writes managed settings that turn off
  the self-update and the non-essential traffic. The install folder is read-only for the
  sandbox user, so a self-update would fail anyway.
- The project marks the npm install route as deprecated. If you change the route, the
  binary path in `sandbox/policies/fragments/20-agent-claude.yaml` changes too.
- The Codex and OpenCode layers are placeholders. Their builds fail with a message until
  someone fills them in and tests them.

## 3. Test the images

```
podman run --rm localhost/agent-sandbox-claude:0.1 sh -c 'id -un; claude --version; python --version; jq --version'
openshell sandbox create --name image-test --no-keep --from localhost/agent-sandbox-claude:0.1 -- \
  sh -c 'whoami; claude --version'
```

You must see `sandbox`, the Claude version, a Python 3 version and a `jq` version. The
sandbox is deleted when the command ends.

Check that the binary path in the image is the one in the policy fragment. The two
results must be the same string:

```
podman run --rm localhost/agent-sandbox-claude:0.1 sh -c 'readlink -f "$(command -v claude)"'
grep claude.exe sandbox/policies/fragments/20-agent-claude.yaml
```

## 4. GitHub provider profile

The gateway has no built-in profiles. Import the copy in this repo:

```
openshell provider profile lint -f sandbox/providers/github.yaml
openshell provider profile import -f sandbox/providers/github.yaml --global
openshell profile list
```

- The file comes from the OpenShell project (Apache-2.0). Keep its license header.
- The profile allows clone and fetch only. A push needs a rule in the policy (push mode).

## 5. How policies are built

A sandbox policy is built from small fragments in `sandbox/policies/fragments/`:

| Fragment | Holds |
| --- | --- |
| `00-base.yaml` | Filesystem rules, and the start of the network section |
| `10-npm.yaml` | The npm registry, for `node` and `curl` |
| `20-agent-<name>.yaml` | The hosts and the binary of one agent |
| `30-github-read.yaml` | Clone and fetch of one repo |
| `30-github-push.yaml` | Clone, fetch and push of one repo |

`sandbox/scripts/render-policy.sh <org> <repo> <read|push>` joins them and prints the
policy. `AGENT=<name>` picks the agent (default `claude`). A placeholder agent needs
`ALLOW_UNTESTED=1`.

You do not run it by hand. A project repo renders and commits the result, so that a
pull request shows exactly what a sandbox may do (see [setup-project.md](setup-project.md)).

Rules to know:
- The default is deny. A rule with no `binaries` section allows no program.
- Use the real file path of a program, not a symlink. Check with `readlink -f`.
- See what was denied with `openshell logs <sandbox> --tail`.
- `openshell policy set <sandbox> --policy <file>` replaces the whole policy. Keep the
  filesystem section the same.
- Policy changes load without a restart.
- Scoped npm packages (`@scope/name`) need `allow_encoded_slash: true` on the registry
  endpoint. The npm fragment has it.
- Claude Code with a subscription login needs no provider, only its three hosts.
- A proxy rule can name a repo, but not a branch. The branch is inside the push data,
  not in the URL. Only GitHub can limit branches.

## 6. Limits and next steps

- Tokens expire after 30 days. Rotate them before that.
- Codex and OpenCode are not tested.
- The image has no `gh`, so an agent cannot open a pull request. It would need the
  package and a rule for `api.github.com`.
- Images are built locally, never published.
- A sandbox protects your machine. It does not check the code that the agent writes.
  Review every change.
