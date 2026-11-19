# Stage 5: Tailscale

This stage puts the instance on your tailnet, so you can reach it without a public SSH port. You then close public SSH if you want to.

Tailscale needs no inbound rule on either firewall. Its traffic is outbound or a reply to outbound traffic, so it passes the host's REJECT rule. This repo adds no firewall rule for it.

## Create a tailnet

Sign up at [tailscale.com](https://tailscale.com) and install Tailscale on your laptop. Follow [Install Tailscale on Linux](https://tailscale.com/kb/1031/install-linux) for Linux, or the download page for your system. Log in on the laptop. Your tailnet exists after the first login.

## Install and log in on the instance

`vps/tailscale.sh` needs sudo. It adds Tailscale's apt repo and signing key from [pkgs.tailscale.com](https://pkgs.tailscale.com/stable/#linux), installs the `tailscale` package, starts `tailscaled` and logs in. It does not pipe a download into a shell. Tailscale's own one-line installer does, so this repo spells the steps out.

```sh
vps/tailscale.sh --check
sudo vps/tailscale.sh
```

The script prints a login URL. Open it in a browser and approve the machine.

To log in without a browser, create an auth key in the Tailscale admin console and save it to a file on the instance. Pick a one-off key with a short expiry. Tailscale keys are one-off or reusable and expire in 1 to 90 days. See [Auth keys](https://tailscale.com/kb/1085/auth-keys), read 2026-11-19.

```sh
sudo vps/tailscale.sh --auth-key-file ~/ts-key
rm ~/ts-key
```

Tailscale documents no way to pass a key from a file, so the script passes it as an argument to `tailscale up`. Other users on the machine could read it from the process list while that command runs. The script never prints the key and keeps it out of your shell history. A one-off key is useless after the first use, which limits the risk.

Run `vps/tailscale.sh --check` to confirm. It prints `MISSING` when Tailscale is absent, `tailscaled` is inactive or the node is logged out.

## Test the tailnet path

On your laptop, find the machine's name in `tailscale status`, then log in over the tailnet with the same key.

```sh
ssh -i ~/.ssh/oci-vps ubuntu@<tailnet-name>
```

Do not go on until this works. Everything after this point can lock you out.

## Optional: Tailscale SSH

Tailscale SSH lets Tailscale handle SSH authentication for tailnet connections. Turn it on with the `--ssh` option, which runs `tailscale set --ssh`. It needs Tailscale 1.24 or later.

```sh
sudo vps/tailscale.sh --ssh
```

Your tailnet policy needs a network rule and an `ssh` rule. The default policy has an SSH rule with `"action": "check"`, `src` set to `autogroup:member` and `dst` set to `autogroup:self`. See [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh), read 2026-11-19.

Enabling it makes open SSH sessions to the Tailscale IP address hang. It does not change `sshd_config`. Reconnect after you enable it.

The `check` action asks you to re-authenticate in a browser from time to time. That can stall an agent that opens SSH sessions on its own. The `accept` action skips the re-authentication. It trades away that check, so anyone with access to a permitted device gets in without it. Choose with that in mind.

## Optional: close public SSH

With the tailnet path proven, you can remove the public port. This script edits the VCN security list on your laptop.

```sh
laptop/close-public-ssh.sh --check --security-list <security-list-ocid>
laptop/close-public-ssh.sh --security-list <security-list-ocid> --vps <tailnet-name> --instance <instance-ocid>
```

The script refuses to run unless `tailscale status` on your laptop lists the instance as online. Pass `--force` to skip that check. It removes every TCP 22 ingress rule from the security list and writes the other rules back. It keeps the host's port 22 rule, because Tailscale traffic to sshd arrives through it.

A security list and an NSG add up, so a port 22 rule in either keeps the port open. With `--instance`, the script lists NSGs on the instance's VNIC that allow TCP 22. Remove those rules in the console too. See [Security rules](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securityrules.htm).

## If you lose access

If Tailscale breaks after you closed public SSH, put the rule back from your laptop. Use your own public address with `/32`.

```sh
laptop/close-public-ssh.sh --undo --source <your-public-ip>/32 --security-list <security-list-ocid>
```

That needs only the OCI CLI. If you cannot reach the instance any other way, use the serial console. Oracle describes it as a troubleshooting tool, not an administration tool. Open the instance in the console, choose **Console connection**, and follow Oracle's page [Instance console connections](https://docs.oracle.com/en-us/iaas/Content/Compute/References/serialconsole.htm). Oracle's page says that a sign-in through the console needs an account with a password, so plan ahead if you want that option.

## Next

Go to [Stage 6: agent tools](06-agent-tools.md).

Last checked: 2026-11-19.
