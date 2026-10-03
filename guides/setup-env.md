# Environment Setup

Software tools and engines for multi-agent development.

Requires macOS 11 or later on Apple silicon (the OpenShell formula is arm64 only).

## 0. Summary

1. Podman, with the `applehv` VM type
2. GitHub CLI
3. OpenShell, version pinned
4. OpenShell gateway service
5. Troubleshooting

## 1. Podman

Install Podman from [podman.io](https://podman.io/docs/installation).
Version used here: 5.8.2.

The VM type must be `applehv`. With `libkrun`, the VM could not read your Mac home
folder, and sandboxes failed to start.

Set it in `~/.config/containers/containers.conf`:

```
[machine]
provider = "applehv"
```

Make the machine and check it:

```
podman machine init --now
podman machine inspect | grep -i -A1 configdir
```

The path in the output must contain `applehv`.

Test that the VM can read your Mac files:

```
mkdir -p ~/podman-share-test && echo hello > ~/podman-share-test/a.txt
podman machine ssh "cat $HOME/podman-share-test/a.txt"
rm -rf ~/podman-share-test
```

It must print `hello`.

If a machine with another type already exists, remove it first. This deletes its
images and containers:

```
podman machine stop
podman machine rm
```

## 2. GitHub CLI

Used on your Mac by `scripts/apply-repo-rules.sh` (see setup-github.md).
Log in with your own GitHub account, not the agent account. Never run it in a sandbox.

```
brew install gh
gh auth login
gh auth status
```

## 3. OpenShell

Install OpenShell and lock the version.

```
# check the tap remote is NVIDIA's
brew tap-info nvidia/openshell

# trust only this formula
brew trust --formula nvidia/openshell/openshell

# install and pin the version
brew install nvidia/openshell/openshell
brew pin openshell

# e.g. 0.1.2
openshell --version
```

The CLI and the gateway must be the same version. The pin stops a surprise upgrade.

### If you had OpenShell installed before

Old files can stop the new gateway. Before the first start, read each of these and
remove what is left over:

- `~/.config/openshell`: a stale `gateway.toml` can crash the gateway
- `~/.local/state/openshell`: old gateway database
- Containers named `openshell-*` (`podman ps -a`, then `podman rm -f <name>`)
- The Podman network `openshell` (`podman network rm openshell`)

## 4. OpenShell gateway service

```
brew services start nvidia/openshell/openshell
openshell gateway add https://localhost:17670 --local --name openshell
openshell status
```

- `openshell status` must show `Connected` and the same version as the CLI.
- Do not run the gateway by hand and as a service at the same time.
- Check the service: `brew services list | grep openshell` must show `started`.
- Logs: `/opt/homebrew/var/log/openshell/openshell-gateway.out.log`
  and `openshell-gateway.err.log`
- If `brew services list` shows `error`, read the end of the `err.log` file.

## 5. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Connection refused` reading your home folder in the Podman VM | VM type is `libkrun` | Use `applehv`, make the machine again |
| `Refusing to load formula ... untrusted tap` | Homebrew trust check | `brew trust --formula nvidia/openshell/openshell` |
| Service shows `error`, `err.log` says unknown field `enabled` | Stale `~/.config/openshell/gateway.toml` from an older install | Delete that line, then `brew services restart nvidia/openshell/openshell` |
| Protobuf decode error from the CLI | CLI and gateway versions differ | Use one OpenShell version, pinned |
| `openshell status` says connection refused | Service is not running | `brew services list`, then read `err.log` |
| `Gateway 'openshell' already exists` | The gateway is already registered | Skip `gateway add`, run `openshell status` |
