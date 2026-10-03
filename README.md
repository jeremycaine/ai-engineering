# ai-engineering

AI engineering lifecycle tools and guides.

How to develop a system architecture-first with coding agents that run in sandboxes,
with a human who reviews every change. The agents run on [OpenShell](https://github.com/NVIDIA/OpenShell).
The worked example is a small todo app.

Status: work in progress. The guides describe what has been built and tested.

## The idea

- **Architecture first.** Describe the system, model it, record the decisions, write the requirements, then build.
- **Agents in sandboxes.** Each agent works in its own sandbox, with its own network policy and its own token.
- **Humans decide.** Agents draft and push branches. A person reviews every pull request and merges it.
- **Repeatable.** Images, policies, profiles and scripts are files in a repo, so a new project starts from them.

## What is here

| Folder | Holds | Status |
| --- | --- | --- |
| [guides/](guides/) | The setup and daily-use guides | Done |
| `sandbox/` | Base image, agent layers, provider profiles, policy templates, scripts | Coming |

## Order of work

Do the guides in this order. Each one needs the one before it.

1. [setup-env.md](guides/setup-env.md): Podman, GitHub CLI, OpenShell and the gateway service
2. [setup-github.md](guides/setup-github.md): agent account, org, repos, rulesets, teams, tokens
3. [setup-sandbox.md](guides/setup-sandbox.md): base image, policies, providers, tested sandboxes
4. [daily-use.md](guides/daily-use.md): open a shell, run an agent, stop and start

## How the safety fits together

- **Sandbox:** the agent runs in a container with no access to your machine's files.
- **Policy:** network access is deny by default. Each sandbox may push to its own repo only.
- **Token:** one fine-grained GitHub token per code repo. The agent sees a placeholder, not the token.
- **Repo rules:** `main` accepts changes only through a pull request.

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
| [todo-platform](https://github.com/arkowave-todo/todo-platform) | Sandbox image, policies, provider profiles and scripts for this project |

## Plan

- [x] Environment, GitHub and sandbox setup
- [x] System description, architecture model, ADRs and requirements for the todo app
- [ ] Move the reusable sandbox tooling into `sandbox/`
- [ ] Component specs and the API contract
- [ ] Deployment (test and prod)
- [ ] Release r1: web frontend can create and view todos
- [ ] Turn the process into a skill, and templates for `system.md` and `AGENTS.md`
- [ ] A lifecycle guide

## Licence

MIT. See [LICENSE](LICENSE). Files copied from other projects keep their own licence headers.
