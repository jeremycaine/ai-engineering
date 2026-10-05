# Daily use

How to work with the sandboxes once a project is set up (see
[setup-project.md](setup-project.md)). Run the `scripts/` commands from your project repo.

## Start of day

```
podman machine list
openshell status
openshell sandbox list
```

- The Podman machine must be running. If not: `podman machine start`.
- `openshell status` must show `Connected`.
- Every sandbox that you need must show `Ready`. If one is `Stopped`:
  `openshell sandbox start <name>`.
- If a sandbox is stuck, delete it and create it again with `scripts/sandbox.sh up <name>`.
  Anything that you did not bring out is lost.

## Work in a sandbox

Open a shell. Leaving it does not end the sandbox.

```
scripts/sandbox.sh shell <name>
```

Start the agent in the repo. The first time in a new sandbox, type `/login`.

```
cd ~/<repo>
claude
```

- Check `/model` at the start. The choice is saved in the sandbox.
- Use a shell from `sandbox.sh shell`. Do not use `sandbox connect`. It attaches to the main
  process (`sleep infinity`), and it hangs.

### A repo that has its own rules

The agent loads the rules file of the repo (`CLAUDE.md`, or `AGENTS.md` if the file imports
it or is a link to it). Those rules are advice. An agent can decide to skip one, for
example "run the formatter before committing". Put a check that must run in a script or a
hook, and read the diff yourself.

## Bring work out

**Push mode.** The agent pushes a branch `agent/<task>`. Open the pull request on GitHub,
read the diff, and merge it. Then update the sandbox copy:

```
cd ~/<repo>
git checkout main
git pull
```

The agent never pushes to `main`. The ruleset refuses it.

**Read mode.** The agent commits on a branch in the sandbox. It cannot push. Bring the branch
out for review. This never pushes:

```
scripts/sandbox.sh export <name> <branch>
```

It shows the commits and the changed files. It warns if an author email is not a GitHub
noreply address, and if a file adds text that looks like a token. Read the diff yourself.
Then push the branch from your own clone, as yourself:

```
git -C <your-clone> push -u origin <branch>
```

Before you push, find out whether that branch deploys anything.

## Publishing stays with you

Credentials that publish a site or a package (hosting, deploy tools, dev logins) stay on
your machine. They never go into a sandbox or into a provider. Run a deploy from your own
machine, after you have reviewed the change.

## End of day

Bring out or push your work. Then stop each sandbox:

```
openshell sandbox stop <name>
```

Next morning, start it again:

```
openshell sandbox start <name>
```

- Everything in `/sandbox` survives a stop and start: files, the cloned repo, the git
  settings and the agent login.
- `openshell sandbox delete` removes it all, with the login. Bring your work out first.

## Now and then

- **A new image or tooling version:** a running sandbox keeps its old image. Bring your work
  out, delete the sandbox, and create it again. You log in again.
- **A changed policy:** apply it to the running sandbox (setup-project.md, section 7).
- **Tokens:** they expire after 30 days. Rotate them before that (setup-github.md, section 7).
- **The access list of the project repo:** check that no agent account is on it.
