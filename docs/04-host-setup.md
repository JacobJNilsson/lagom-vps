# Stage 4: host setup

This stage updates the instance, adds swap, turns on lingering and limits SSH to keys. Both scripts are safe to run twice. Run them on the instance, in the clone from [Stage 3](03-first-login.md).

Keep your first SSH session open for the whole stage. Test every change from a second session before you close the first one.

## Host setup

`vps/host-setup.sh` needs sudo. It does five things:

- Runs `apt-get update` and a non-interactive upgrade.
- Installs `unattended-upgrades` when absent and writes `/etc/apt/apt.conf.d/20auto-upgrades` with both values set to `"1"`. Ubuntu enables this by default, so the script mostly confirms it. Only security updates install automatically, and the machine never reboots by itself. See [Automatic updates](https://ubuntu.com/server/docs/how-to/software/automatic-updates/), read 2026-11-19.
- Creates a swap file. The default is 4 GB in `/swapfile`, with `vm.swappiness` set to 10. The free shape has 12 GB of RAM, and swap softens a busy build. Swap uses part of the 200 GB storage budget. Use `--swap-gb N` to change the size or `--swap-gb 0` to skip swap.
- Sets the time zone only when you pass `--timezone ZONE`. The image default is UTC.
- Turns on lingering for your user with `loginctl enable-linger`, so user services run without a login session.

Look first, then apply:

```sh
vps/host-setup.sh --check
sudo vps/host-setup.sh
```

`--check` prints `MISSING` with a fix for each gap and changes nothing. Pending apt upgrades show as a note, not as missing. `--dry-run` prints each command that would change the system.

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--swap-gb N` | 4 | Swap file size in GB. 0 skips swap. |
| `--timezone ZONE` | none | Time zone name, for example `America/New_York` |
| `--user NAME` | the user who ran sudo | Account that gets lingering |

The script keeps the default `ubuntu` user. It creates no other user.

## Keys-only SSH

`vps/ssh-harden.sh` needs sudo. It writes `/etc/ssh/sshd_config.d/10-keys-only.conf`, runs `sshd -t`, and reloads the `ssh` service. The file sets `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no` and `PubkeyAuthentication yes`.

The file name starts with `10-`, so it sorts before the cloud image drop-in `60-cloudimg-settings.conf`. sshd keeps the first value it reads, so the `10-` file wins.

The script refuses to run when `~/.ssh/authorized_keys` holds no public key. It restores the old file when `sshd -t` fails. Both guards protect you from a lockout.

```sh
vps/ssh-harden.sh --check
sudo vps/ssh-harden.sh
```

Open a second terminal and log in again with your key. Close the first session only after that works. If you lock yourself out, use the serial console in [Stage 5](05-tailscale.md#if-you-lose-access).

## Next

Go to [Stage 5: Tailscale](05-tailscale.md).

Last checked: 2026-11-19.
