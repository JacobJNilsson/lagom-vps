# Stage 3: first login and firewalls

This stage logs in for the first time and checks both firewalls. Two layers filter traffic to the instance, and you need to know both before you change anything.

## Log in

Use the key from [Stage 2](02-create-instance.md) and the public IP address from the console.

```sh
ssh -i ~/.ssh/oci-vps ubuntu@<public-ip>
```

Oracle creates the `ubuntu` user on Ubuntu images. Oracle Linux uses `opc` instead. See [Oracle-provided images](https://docs.oracle.com/en-us/iaas/Content/Compute/References/images.htm). This repo keeps the `ubuntu` user.

Clone this repo on the instance. The next stages run its scripts from there.

```sh
git clone https://github.com/JacobJNilsson/lagom-vps.git
cd lagom-vps
```

## The two firewalls

Traffic passes the VCN security rules first. Then it passes the iptables rules on the instance.

### VCN security list

The default security list allows stateful ingress on TCP 22 "from authorized source IP addresses". It also allows some ICMP traffic and all egress. See [Security lists](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securitylists.htm).

That page does not say whether the console wizard fills in `0.0.0.0/0` as the source. Open the security list in the console and read the source of the port 22 rule yourself.

A security list applies to every VNIC in a subnet. A network security group (NSG) applies to chosen VNICs. When both exist, Oracle allows the union of their rules. Oracle recommends NSGs. See [Security rules](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securityrules.htm). To block a port you must remove it from the security list and from every NSG on the VNIC.

### Host iptables

Oracle's Ubuntu images ship `/etc/iptables/rules.v4` and `rules.v6`. The `netfilter-persistent` service loads them at boot. This is what the image ships, and no Oracle page describes the exact layout. See it yourself:

```sh
sudo iptables -L INPUT --line-numbers
sudo iptables -S OUTPUT
```

On the images this repo was written against, the INPUT chain accepts established traffic, ICMP, loopback and new connections to TCP 22. It then rejects everything else. An `InstanceServices` chain on OUTPUT lets root reach the boot and block volume endpoints. Oracle says only root can reach those endpoints and recommends keeping the rules. See [Compute best practices](https://docs.oracle.com/en-us/iaas/Content/Compute/References/bestpracticescompute.htm).

## Do not use UFW

Oracle says: "Do not use UFW to edit firewall rules." UFW "may remove" the rules that reach the boot and block volumes. Edit `/etc/iptables/rules.v4` and apply it with `iptables-restore < /etc/iptables/rules.v4`. See [Compute known issues](https://docs.oracle.com/en-us/iaas/Content/Compute/known-issues.htm).

This repo never installs UFW and never flushes iptables rules. Do not run `iptables -F` on these images.

## Aside: open a port the Oracle way

You need no extra port for this repo, because Tailscale works without an inbound rule. If you add a service later, do two things. First, allow the port in the VCN security list or an NSG. Second, insert a rule above the final REJECT rule and save it.

```sh
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo netfilter-persistent save
```

This is the pattern from Oracle's [Apache on Ubuntu tutorial](https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/apache-on-ubuntu/01oci-ubuntu-apache-summary.htm). Check the rule number with `--line-numbers` first.

## Check the host firewall

This script reads the iptables state and changes nothing. It needs sudo to read the rules.

```sh
vps/firewall.sh --check
```

It prints `MISSING` with a fix when UFW is active, when the `InstanceServices` chain is gone, when `netfilter-persistent` is not enabled, or when no INPUT rule accepts TCP 22. A healthy machine prints `ok: nothing is missing`.

## Next

Go to [Stage 4: host setup](04-host-setup.md).

Last checked: 2026-11-19.
