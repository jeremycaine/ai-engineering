# platform

The record of what each of your sandboxes is allowed to do, and who decided it.

For each project, this repo holds:
- the sandbox settings (`project.env`): which repo, read or push, which agent, which image, the name of the provider,
- the rendered network policy (`policy.yaml`), committed, so a pull request shows exactly what a sandbox may do,
- the version of the [ai-engineering](https://github.com/jeremycaine/ai-engineering) tooling that the project uses (`tooling.lock`),
- a check that renders each policy again and compares it with the committed file.

It holds no tooling, no project code and no secrets.

## Rules

1. **No secrets, ever.** No token, no password, no deploy credential. `project.env` holds the *name* of a provider, never a token. Credentials that publish a site stay on the human side and never go into a sandbox.
2. **No agent account has access to this repo.** The agent works in a clone of the project repo. If it could edit its own network policy, the limits would mean nothing. Keep the access list to the people who review.

On a private repo on the GitHub Free plan, GitHub cannot force a pull request. Work on a branch, open a pull request, and review it as a habit. Check the access list when you add someone to the organisation.

## Layout

    tooling.lock                    the pinned version of the tooling (a commit)
    scripts/policy.sh               render and check policies
    scripts/sandbox.sh              create a sandbox, open a shell, bring work out for review
    projects/<name>/project.env     non-secret settings for the project's sandbox
    projects/<name>/policy.yaml     the rendered policy

## Use

Render a policy, then review the pull request:

    scripts/policy.sh render <project>

Check that every committed policy matches a fresh render with the pinned tooling:

    scripts/policy.sh check

To move to a newer tooling version: change `TOOLING_COMMIT` (and `TOOLING_TAG`) in `tooling.lock`, run `render`, and read the diff of every `policy.yaml`. A changed policy has to be applied to the running sandbox: `openshell policy set <sandbox> --policy projects/<name>/policy.yaml`.

## Sandboxes

    scripts/sandbox.sh up <project>               create the sandbox (refuses on a drifted policy, a missing image or a missing provider)
    scripts/sandbox.sh shell <project>            open a shell in it
    scripts/sandbox.sh export <project> <branch>  bring a branch out for review. It never pushes.

The sandbox is named after the project. `up` needs `AGENT_GIT_EMAIL` in your shell (the GitHub noreply address of the agent account).
`export` finds your clone at `$CLONE_ROOT/<org>/<repo>` (default `~/code/github.com`).
