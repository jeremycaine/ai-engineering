# Daily use

How to work with the sandboxes once setup is done (see setup-sandbox.md).

## Start of day

```
podman machine list
openshell status
openshell sandbox list
```

- The Podman machine must be running. If not: `podman machine start`.
- `openshell status` must show `Connected`.
- Every sandbox you need must show `Ready`. If one is `Stopped`:
  `openshell sandbox start <name>`.
- If a sandbox is stuck, delete it and create it again (setup-sandbox.md, step 5).
  Work that you pushed is safe.

## Work in a sandbox

Open a shell. Leaving it does not end the sandbox.

```
openshell sandbox exec -n todo-api --tty -- /bin/bash -l
```

Start Claude Code in the repo. The first time in a new sandbox, type `/login`.

```
cd ~/todo-api
claude
```

Use `sandbox exec` for shells. Do not use `sandbox connect`. It attaches to the main
process (`sleep infinity`), and it hangs.

## Review and merge

1. The agent works on a branch `agent/<task>` and pushes it.
2. Open the pull request on GitHub as `jeremycaine`. Read the diff and merge it.
3. Update the sandbox copy of the repo:

```
cd ~/todo-api
git checkout main
git pull
```

Agents never push to `main`. The ruleset refuses it.

## End of day

Push your work. Then stop each sandbox:

```
openshell sandbox stop todo-api
```

Next morning, start it again:

```
openshell sandbox start todo-api
```

- Everything in `/sandbox` survives a stop and start: files, the cloned repo, the
  git settings and the Claude login.
- `openshell sandbox delete` removes it all. Push your work first.
