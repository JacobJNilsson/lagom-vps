# lagom-vps

Set up an Oracle Cloud Always Free ARM VPS for coding agents, then hand off to lagom-factory.

You end with one Ampere A1 instance that runs Ubuntu 24.04, accepts SSH keys only, sits on your Tailscale network and has the tools lagom-factory needs for Claude Code workers. The repo holds step-by-step docs and small POSIX shell scripts. Each script is safe to run twice, and each takes `--check` and `--dry-run`.

Always Free limits changed, and older guides on the web are out of date. Every Oracle fact in these docs carries a link and the date it was read. Oracle's current limit for A1 is 2 OCPU and 12 GB of memory, per [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), read 2026-11-19.

## The path

| Stage | Doc | Where | Time |
| --- | --- | --- | --- |
| 1. Oracle account | [01-oracle-account.md](docs/01-oracle-account.md) | Browser | 15 minutes |
| 2. Create the instance | [02-create-instance.md](docs/02-create-instance.md) | Laptop | 10 minutes, longer when the region is full |
| 3. First login and firewalls | [03-first-login.md](docs/03-first-login.md) | Laptop, then instance | 10 minutes |
| 4. Host setup | [04-host-setup.md](docs/04-host-setup.md) | Instance | 10 minutes |
| 5. Tailscale | [05-tailscale.md](docs/05-tailscale.md) | Instance, then laptop | 15 minutes |
| 6. Agent tools | [06-agent-tools.md](docs/06-agent-tools.md) | Instance | 30 minutes |

The times are rough. [Troubleshooting](docs/troubleshooting.md) covers a full region, idle reclamation and a lockout.

## Quick path

Run these after you have an Oracle account. The docs explain each step and its risks.

1. On your laptop, make a key: `laptop/ssh-key.sh`
2. Create the instance in the console, or run `laptop/oci-launch.sh --compartment <compartment-ocid> --subnet <subnet-ocid> --ssh-key ~/.ssh/oci-vps.pub`
3. Log in: `ssh -i ~/.ssh/oci-vps ubuntu@<public-ip>`
4. On the instance, clone this repo, then check the firewall: `vps/firewall.sh --check`
5. Prepare the host: `sudo vps/host-setup.sh`
6. Limit SSH to keys, with a second session open: `sudo vps/ssh-harden.sh`
7. Join your tailnet: `sudo vps/tailscale.sh`
8. Do the manual steps in lagom-factory's [new-machine.md](https://github.com/JacobJNilsson/lagom-factory/blob/main/docs/new-machine.md), then run: `vps/agent-tools.sh`

Optional, after you prove the tailnet path: `laptop/close-public-ssh.sh` removes public SSH.

## What this repo does not do

- It does not configure sfy factories. lagom-factory does that. Follow its [Start your first factory](https://github.com/JacobJNilsson/lagom-factory/blob/main/README.md#start-your-first-factory) section.
- It does not copy lagom-factory's manual setup steps. It links them.
- It does not install UFW or change iptables rules. Oracle warns against UFW on its images.
- It keeps the default `ubuntu` user and creates no other user.
- It does not install Node, Docker or other tools that lagom-factory does not need.
- It does not keep the instance busy to avoid idle reclamation.

## Development

`make check` runs shellcheck, shfmt and the tests. The tests run the scripts against fake commands, so they change nothing on your machine. CI also fails on addresses, OCIDs and keys in tracked files.

## License

MIT. See [LICENSE](LICENSE).
