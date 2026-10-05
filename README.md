# ai-engineering

AI engineering lifecycle tools and guides.

How to develop a system architecture-first with coding agents that run in sandboxes,
with a human who reviews every change. The agents run on [OpenShell](https://github.com/NVIDIA/OpenShell).
The worked example is a small todo app.

Status: work in progress. The guides describe what has been built and tested.

## The idea

- **Architecture first.** Describe the system, model it, record the decisions, write the requirements, then build.
- **Agents in sandboxes.** Each agent works in its own sandbox, with its own network policy and its own token.
- **Humans decide.** Agents draft. A person reviews every change before it reaches `main`.
- **Repeatable.** Images, policies, profiles and scripts are files in a repo, so a new project starts from them.

## What is here

| Folder | Holds |
| --- | --- |
| [guides/](guides/) | The setup and daily-use guides |
| `sandbox/images/` | The base image and the agent layers |
| `sandbox/policies/` | Policy fragments, one per concern |
| `sandbox/providers/` | The GitHub provider profile |
| `sandbox/scripts/` | Create a sandbox, render a policy, bring work out for review |
| `sandbox/project-template/` | The starting point for a project repo |

## Order of work

Do the guides in this order. Each one needs the one before it.

1. [setup-env.md](guides/setup-env.md): Podman, GitHub CLI, OpenShell and the gateway service
2. [setup-github.md](guides/setup-github.md): the agent account, organisation settings, repo access, rules and tokens
3. [setup-sandbox.md](guides/setup-sandbox.md): the images, the provider profile and how policies are built (once per machine)
4. [setup-project.md](guides/setup-project.md): one project: its settings, token, policy and sandbox (once per project)
5. [daily-use.md](guides/daily-use.md): open a shell, run an agent, bring work out, stop and start

## Two modes

Choose a mode for each repo.

| | Push mode | Read mode |
| --- | --- | --- |
| Use when | GitHub can enforce "no direct push to `main`": a public repo, or a paid plan | The repo is private on the Free plan, or has no branch rules |
| The agent | Pushes branches. You review and merge the pull request. | Commits in the sandbox and cannot push. You bring the commits out and push. |
| Token | Contents and pull requests: read and write | Contents: read-only |
| Worked example | The todo app | A private website repo |

## How the safety fits together

- **Sandbox:** the agent runs in a container with no access to your machine's files.
- **Policy:** network access is deny by default. A sandbox in push mode may push to its own repo only. A sandbox in read mode has no push rule at all.
- **Token:** one fine-grained GitHub token per repo. The agent sees a placeholder, not the token.
- **Repo rules:** where GitHub can enforce them, `main` accepts changes only through a pull request. Where it cannot, the agent has no write access.
- **Publishing credentials** (hosting, deploy tools) stay with you and never go into a sandbox.

## Agents

| Agent | Status |
| --- | --- |
| Claude Code | Tested |
| Codex | Placeholder, not tested |
| OpenCode | Placeholder, not tested |

Each agent is a thin layer on a shared base image. You build the layer on your own machine
from a pinned version. This repo does not contain or publish any agent software.
Claude Code is proprietary and is used under Anthropic's own terms.

## Worked example: the todo app

The example project lives in the GitHub organisation [arkowave-todo](https://github.com/arkowave-todo).

| Repo | Role |
| --- | --- |
| [todo-spec](https://github.com/arkowave-todo/todo-spec) | System description, architecture model, ADRs, requirements |
| [todo-api](https://github.com/arkowave-todo/todo-api) | Backend (Fastify) |
| [todo-fe-web](https://github.com/arkowave-todo/todo-fe-web) | Web frontend (Astro) |
| todo-fe-ios | iOS frontend (SwiftUI), planned for release r2 |
| [todo-platform](https://github.com/arkowave-todo/todo-platform) | The project repo for the todo sandboxes, from before the template existed |

## Plan

- [x] Environment, GitHub and sandbox setup
- [x] System description, architecture model, ADRs and requirements for the todo app
- [x] The reusable sandbox tooling in `sandbox/`
- [x] A read mode for private repos, tested on a real website repo
- [x] Move the ruleset script (`apply-repo-rules.sh`) into `sandbox/scripts/`
- [ ] Component specs and the API contract
- [ ] Deployment (test and prod)
- [ ] Release r1: web frontend can create and view todos
- [ ] Turn the process into a skill, and templates for `system.md` and `AGENTS.md`
- [ ] A lifecycle guide

## Licence

MIT. See [LICENSE](LICENSE). Files copied from other projects keep their own licence headers.
