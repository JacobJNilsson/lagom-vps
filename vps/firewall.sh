#!/bin/sh
# Report the state of the Oracle host firewall. It reads only and never changes rules.
#
# Usage: vps/firewall.sh [--check]
#   --check  the only mode. Print MISSING with a fix and exit 1 when the state looks wrong.
#
# MISSING when UFW is active, when the InstanceServices chain is absent, when
# netfilter-persistent is not enabled, or when no INPUT rule accepts TCP port 22.
# The script needs sudo to read iptables. It has no install mode, because Oracle warns that
# UFW and careless rule changes can cut off the boot and block volumes.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$here/../lib/common.sh"

while [ "$#" -gt 0 ]; do
	if parse_common_flag "$1"; then
		shift
		continue
	fi
	usage_error "unknown option: $1"
done

# This script only reports, so every run is a check.
check=1

ufw_state=
if have ufw; then
	ufw_state=$(priv ufw status 2>/dev/null || true)
fi
case $ufw_state in
*"Status: active"*)
	miss "UFW is active. Oracle says not to use UFW to edit firewall rules." "sudo ufw disable, then restore /etc/iptables/rules.v4 from a backup. See docs/03-first-login.md."
	;;
*) ok "UFW is not active" ;;
esac

if ! have iptables; then
	miss "iptables is not installed" "sudo apt install iptables iptables-persistent"
else
	rules=$(priv iptables -S 2>/dev/null || true)
	case $rules in
	*"-N InstanceServices"*) ok "the InstanceServices chain exists" ;;
	*) miss "the InstanceServices chain is absent. Oracle's image rules for the boot and block volumes may be gone." "restore /etc/iptables/rules.v4 from the image or a backup, then run: sudo iptables-restore < /etc/iptables/rules.v4" ;;
	esac
	if printf '%s\n' "$rules" | grep -Eq -- '^-A INPUT .*--dport 22 .*-j ACCEPT'; then
		ok "an INPUT rule accepts TCP port 22"
	else
		miss "no INPUT rule accepts TCP port 22" "sudo iptables -I INPUT 5 -m state --state NEW -p tcp --dport 22 -j ACCEPT, then: sudo netfilter-persistent save"
	fi
fi

if systemctl is-enabled netfilter-persistent >/dev/null 2>&1; then
	ok "netfilter-persistent is enabled"
else
	miss "netfilter-persistent is not enabled, so rules do not survive a reboot" "sudo apt install iptables-persistent, then: sudo systemctl enable netfilter-persistent"
fi

finish_check
