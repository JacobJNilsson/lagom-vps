# Troubleshooting

Oracle's rules change. Each section carries the date it was last checked.

## Out of host capacity

The launch fails with `Out of host capacity`. The API error is `InternalError`. Oracle says the cause is "a lack of physical infrastructure capacity for the shape in the requested fault domain and availability domain." See [Compute known issues](https://docs.oracle.com/en-us/iaas/Content/Compute/known-issues.htm).

For Always Free shapes, Oracle says the error "indicates a temporary lack of Always Free shapes in your home region. Try creating the instance in a different availability domain, or wait a while, then try to create the instance again." See [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

Oracle's workarounds on the known issues page:

- Check capacity with the `CreateComputeCapacityReport` operation.
- Try another availability domain.
- Leave the fault domain unset.
- Use a smaller shape.
- Wait a few minutes before you retry.

The [Free Tier FAQ](https://www.oracle.com/cloud/free/faq/) adds that "it might take several days before additional capacity is available."

`laptop/oci-launch.sh` automates the first, second and fifth workarounds. It tries every availability domain, leaves the fault domain unset and waits between rounds. Use `--retry N --wait SECONDS`. The script raises any wait below 60 seconds to 60 and caps `--retry` at 100 rounds, so it stays below the API rate limit. Oracle documents no retry loop, so this is a community practice.

```sh
laptop/oci-launch.sh --compartment <compartment-ocid> --subnet <subnet-ocid> --ssh-key ~/.ssh/oci-vps.pub --retry 60 --wait 300
```

Oracle also mentions an upgrade to Pay As You Go and says "Oracle doesn't charge for Always Free resources after you upgrade." The upgrade needs a payment card that you may not want charged for other services, so this repo leaves the choice to you.

Last checked: 2026-11-19.

## Idle reclamation

Oracle may reclaim an idle Always Free compute instance. Oracle says an instance is idle when, "during a 7-day period", all of these hold: the 95th percentile CPU use is under 20%, network use is under 20%, and memory use is under 20%. The memory rule applies to A1 only. See [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

An agent machine that waits for work can sit under all three limits for a week. Plan for that.

Oracle's docs say nothing about a Pay As You Go exemption. Community posts claim that upgrading avoids reclamation. This is unconfirmed, so do not rely on it.

The [Free Tier FAQ](https://www.oracle.com/cloud/free/faq/) also says: "Accounts left idle for 30 days or more may be deemed abandoned."

This repo ships no keep-alive job. Work that only exists to look busy goes against the spirit of the tier. If the instance matters, keep backups of anything you cannot recreate, and check that the instance still runs.

Last checked: 2026-11-19.

## Locked out of SSH

If `ssh-harden.sh` or `close-public-ssh.sh` locks you out:

1. Add public SSH back from your laptop with `laptop/close-public-ssh.sh --undo --source <your-public-ip>/32 --security-list <security-list-ocid>`. This needs only the OCI CLI.
2. If keys-only SSH is the problem, use the serial console. Oracle describes it as a troubleshooting tool. See [Instance console connections](https://docs.oracle.com/en-us/iaas/Content/Compute/References/serialconsole.htm). Oracle's page says a console sign-in needs an account with a password.
3. As a last resort, stop the instance, attach its boot volume to another instance and fix the files there.

Check the NSGs on the instance's VNIC too. A port 22 rule in an NSG keeps the port open even after you remove it from the security list.

Last checked: 2026-11-19.

## Tailscale SSH sessions hang

Turning on Tailscale SSH makes open SSH sessions to the Tailscale IP address hang. Reconnect. See [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh).

Last checked: 2026-11-19.

## Block volumes stop working

UFW or `iptables -F` can remove the rules that reach the boot and block volumes. Oracle says: "Do not use UFW to edit firewall rules." See [Compute known issues](https://docs.oracle.com/en-us/iaas/Content/Compute/known-issues.htm). Run `vps/firewall.sh --check` to see what is wrong. It never changes rules. Restore `/etc/iptables/rules.v4` from a backup and apply it with `iptables-restore`.

Last checked: 2026-11-19.

## bwrap or the sandbox fails

Workers exit at once when Claude's sandbox cannot start. The usual cause on Ubuntu 24.04 is a missing `bubblewrap` or `socat` package, or a missing AppArmor profile for `bwrap`. Both are manual steps in lagom-factory's [new-machine.md](https://github.com/JacobJNilsson/lagom-factory/blob/main/docs/new-machine.md). Run `machine/install.sh --check` in lagom-factory. It lists each missing item with its fix.

Last checked: 2026-11-19.
