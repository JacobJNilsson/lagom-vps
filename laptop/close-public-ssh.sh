#!/bin/sh
# Remove public SSH (TCP 22) from a VCN security list, after you proved Tailscale works.
#
# Usage: laptop/close-public-ssh.sh [--check] [--dry-run] [--undo --source CIDR] [--force]
#          --security-list OCID [--vps NAME] [--instance OCID]
#   --security-list OCID  the security list of the instance's subnet
#   --vps NAME            the instance's Tailscale host name. It must show online here.
#   --instance OCID       also list the NSGs on the instance's VNIC that allow TCP 22
#   --force               skip the Tailscale online check
#   --undo --source CIDR  add TCP 22 back from CIDR, for example your own address with /32
#   --check               change nothing, exit 1 when a TCP 22 rule from 0.0.0.0/0 remains
#   --dry-run             print the update command instead of running it
#
# The script keeps the host iptables rule for port 22. Tailscale traffic reaches sshd through it.
# Remove port 22 from every NSG on the VNIC too. A security list and an NSG add up.
# If you lose access, use the serial console. See docs/05-tailscale.md.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$here/../lib/common.sh"

security_list=
vps=
instance=
source_cidr=
undo=0
force=0

while [ "$#" -gt 0 ]; do
	if parse_common_flag "$1"; then
		shift
		continue
	fi
	case $1 in
	--security-list | --vps | --instance | --source)
		[ "$#" -ge 2 ] || usage_error "$1 needs a value"
		case $1 in
		--security-list) security_list=$2 ;;
		--vps) vps=$2 ;;
		--instance) instance=$2 ;;
		--source) source_cidr=$2 ;;
		esac
		shift 2
		;;
	--undo)
		undo=1
		shift
		;;
	--force)
		force=1
		shift
		;;
	*) usage_error "unknown option: $1" ;;
	esac
done

[ -n "$security_list" ] || usage_error "--security-list is required"
if [ "$undo" = 1 ] && [ -z "$source_cidr" ]; then
	usage_error "--undo needs --source CIDR"
fi
have oci || die "oci is not installed. See docs/02-create-instance.md."
have jq || die "jq is not installed"

# A rule covers port 22 when it is TCP and its destination range holds 22.
covers22='((.["tcp-options"] // {}) | .["destination-port-range"] // null) as $r | .protocol == "6" and $r != null and $r.min <= 22 and $r.max >= 22'

rules_file=$(mktemp)
trap 'rm -f "$rules_file"' EXIT

oci network security-list get --security-list-id "$security_list" | jq '.data["ingress-security-rules"] // []' >"$rules_file"

open_to_world() {
	jq -e "[.[] | select($covers22) | select(.source == \"0.0.0.0/0\")] | length > 0" "$rules_file" >/dev/null
}

# list_nsgs: print the NSGs on the instance's VNIC that allow TCP 22.
list_nsgs() {
	if [ -z "$instance" ]; then
		printf 'note: pass --instance OCID to list NSGs. Remove TCP 22 from every NSG on the VNIC too.\n'
		return 0
	fi
	for nsg in $(oci compute instance list-vnics --instance-id "$instance" | jq -r '(.data // [])[] | (.["nsg-ids"] // [])[]'); do
		if oci network nsg rules list --nsg-id "$nsg" --direction INGRESS | jq -e "[(.data // [])[] | select($covers22)] | length > 0" >/dev/null; then
			printf 'note: NSG %s allows TCP 22. Remove that rule too.\n' "$nsg"
		fi
	done
}

# vps_online: succeed when tailscale on this machine lists the VPS as online.
vps_online() {
	have tailscale || return 1
	tailscale status --json | jq -e --arg n "$vps" '[(.Peer // {})[] | select(.HostName == $n and .Online == true)] | length > 0' >/dev/null
}

if [ "$check" = 1 ]; then
	if open_to_world; then
		miss "a TCP 22 ingress rule from 0.0.0.0/0 remains" "laptop/close-public-ssh.sh --security-list $security_list --vps <tailscale-name>"
	else
		ok "no TCP 22 ingress rule from 0.0.0.0/0"
	fi
	list_nsgs
	finish_check
fi

new_file=$(mktemp)
trap 'rm -f "$rules_file" "$new_file"' EXIT

if [ "$undo" = 1 ]; then
	rule=$(jq -n --arg cidr "$source_cidr" '{"protocol": "6", "source": $cidr, "source-type": "CIDR_BLOCK", "is-stateless": false, "description": "SSH", "tcp-options": {"destination-port-range": {"min": 22, "max": 22}}}')
	jq --arg cidr "$source_cidr" --argjson rule "$rule" "if any(.[]; ($covers22) and .source == \$cidr) then . else . + [\$rule] end" "$rules_file" >"$new_file"
else
	if [ "$force" = 0 ]; then
		[ -n "$vps" ] || usage_error "--vps NAME is required, or pass --force"
		vps_online || die "tailscale does not list $vps as online on this machine. Fix Tailscale first, or pass --force."
	fi
	jq "[.[] | select(($covers22) | not)]" "$rules_file" >"$new_file"
fi

if cmp -s "$rules_file" "$new_file"; then
	ok "the security list already has the wanted rules"
else
	run oci network security-list update --security-list-id "$security_list" --ingress-security-rules "file://$new_file" --force
	if [ "$undo" = 0 ]; then
		list_nsgs
	fi
fi
finish
