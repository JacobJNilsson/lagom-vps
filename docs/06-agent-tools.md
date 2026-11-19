# Stage 6: agent tools

This stage hands the machine to lagom-factory. `vps/agent-tools.sh` clones lagom-factory and runs its installer. lagom-factory owns the steps, so this repo links them and does not copy them.

lagom-factory's [new-machine.md](https://github.com/JacobJNilsson/lagom-factory/blob/main/docs/new-machine.md) is the source of truth. Read its Linux list before you run the script. The list was read on 2026-11-19 and may have changed since.

## Do the manual steps first

lagom-factory's installer installs Go tools and links skills. It installs no apt packages, no Go, no Claude Code and no sfy. Without Go, it stops at once. Work through the Linux list in [new-machine.md](https://github.com/JacobJNilsson/lagom-factory/blob/main/docs/new-machine.md) up to the installer step:

1. The sandbox packages: `bubblewrap`, `socat`, `git` and `gh`.
2. The AppArmor profile for `bwrap`. Ubuntu 24.04 blocks unprivileged user namespaces without it.
3. Go in `/usr/local/go` and Claude Code, then run `claude` once to log in.
4. A terminal tool: tmux, or Rex.
5. sfy, and the links into `/usr/local/bin`.
6. The `PATH` entries for `~/.local/bin`, `/usr/local/go/bin` and `~/go/bin`.
7. A global git identity.
8. `gh auth login`, with the `workflow` scope.

Four of these need you: the `claude` login, `gh auth login`, the git identity and the choice of terminal tool. This repo uses tmux by default. It is one apt package, and Rex has no public Linux install doc. If you use Rex, install it and pass `--multiplexer rex` below. lagom-factory's [No Rex? Use tmux](https://github.com/JacobJNilsson/lagom-factory/blob/main/README.md#no-rex-use-tmux) section covers the tmux setup.

## Run the script

```sh
vps/agent-tools.sh --check
vps/agent-tools.sh
```

The script needs no sudo. It does two things:

1. It clones lagom-factory into `~/src/lagom-factory`, or runs `git pull --ff-only` when the clone exists. It tracks the default branch. Use `--lagom-dir DIR` to pick another folder.
2. It runs `machine/install.sh --clone-skills`, then `machine/install.sh --check --multiplexer tmux`.

`--check` on this script runs only lagom-factory's check and passes its exit code through. It lists each missing item with its fix. `--multiplexer rex` swaps tmux for Rex.

The run ends with `ok: nothing is missing` from lagom-factory's check. If it lists items, fix them in order and run the script again. A second run is safe.

## How many workers fit

The free shape has 12 GB of RAM. lagom-factory's default is four workers at once, and four Claude Code workers plus Go builds may run out of memory on 12 GB. This repo has not measured a safe number. Start with fewer workers, watch `free -h` and raise the number if memory stays free. The swap file from [Stage 4](04-host-setup.md) softens spikes but does not replace RAM.

## Next

Install a factory and start it. Follow [Start your first factory](https://github.com/JacobJNilsson/lagom-factory/blob/main/README.md#start-your-first-factory) in lagom-factory's README.

If something fails, see [Troubleshooting](troubleshooting.md).

Last checked: 2026-11-19.
