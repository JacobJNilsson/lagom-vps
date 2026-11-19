#!/bin/sh
# Prepare a fresh Ubuntu 24.04 instance: upgrades, swap, time zone and lingering.
#
# Usage: sudo vps/host-setup.sh [--check] [--dry-run] [--timezone ZONE] [--swap-gb N] [--user NAME]
#   --timezone ZONE  set the time zone, for example America/New_York (default: leave as is)
#   --swap-gb N      size of /swapfile in GB (default: 4). 0 skips swap.
#   --user NAME      account that gets lingering (default: the user who ran sudo)
#   --check          change nothing, print MISSING with a fix, exit 1 when anything is missing
#   --dry-run        print each command that would change the system
#
# Steps: apt upgrade, unattended-upgrades with 20auto-upgrades, time zone, swap file with
# vm.swappiness 10, and loginctl enable-linger. The script keeps the default user.
# A second run changes nothing. LAGOM_ROOT prefixes the paths it writes, for tests.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$here/../lib/common.sh"

timezone=
swap_gb=4
target_user=${SUDO_USER:-$(id -un)}

while [ "$#" -gt 0 ]; do
	if parse_common_flag "$1"; then
		shift
		continue
	fi
	case $1 in
	--timezone | --swap-gb | --user)
		[ "$#" -ge 2 ] || usage_error "$1 needs a value"
		case $1 in
		--timezone) timezone=$2 ;;
		--swap-gb) swap_gb=$2 ;;
		--user) target_user=$2 ;;
		esac
		shift 2
		;;
	*) usage_error "unknown option: $1" ;;
	esac
done

case $swap_gb in
'' | *[!0-9]*) usage_error "--swap-gb must be a whole number" ;;
esac

swapfile=$root_prefix/swapfile
fstab=$root_prefix/etc/fstab
sysctl_file=$root_prefix/etc/sysctl.d/99-lagom-swappiness.conf
auto_file=$root_prefix/etc/apt/apt.conf.d/20auto-upgrades
linger_file=$root_prefix/var/lib/systemd/linger/$target_user

require_os

# --- apt upgrade ---------------------------------------------------------

pending_count() {
	priv apt-get -s upgrade 2>/dev/null | grep -c '^Inst ' || true
}

apt_upgrade() {
	if [ "$check" = 0 ]; then
		as_root apt-get update
	fi
	pending=$(pending_count)
	if [ "$pending" = 0 ]; then
		ok "no pending apt upgrades"
	elif [ "$check" = 1 ]; then
		printf 'note: %s pending apt upgrades. Run without --check to apply them.\n' "$pending"
	else
		as_root env DEBIAN_FRONTEND=noninteractive apt-get -y -oDpkg::Options::=--force-confold upgrade
		ok "applied $pending apt upgrades"
	fi
}

# --- unattended upgrades -------------------------------------------------

auto_lists='APT::Periodic::Update-Package-Lists "1";'
auto_upgrade='APT::Periodic::Unattended-Upgrade "1";'

auto_ok() {
	dpkg -s unattended-upgrades >/dev/null 2>&1 && printf '%s\n%s\n' "$auto_lists" "$auto_upgrade" | file_matches "$auto_file"
}

auto_apply() {
	if ! dpkg -s unattended-upgrades >/dev/null 2>&1; then
		as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades
	fi
	put_lines "$auto_file" 0644 "$auto_lists" "$auto_upgrade"
}

# --- time zone -----------------------------------------------------------

tz_ok() {
	[ -z "$timezone" ] || [ "$(probe timedatectl show -p Timezone --value)" = "$timezone" ]
}

tz_apply() {
	as_root timedatectl set-timezone "$timezone"
}

# --- swap ----------------------------------------------------------------

swap_active() {
	probe swapon --show=NAME --noheadings | grep -q 'swapfile'
}

fstab_has_swap() {
	grep -q '^/swapfile ' "$fstab" 2>/dev/null
}

swap_ok() {
	[ -f "$swapfile" ] && swap_active && fstab_has_swap && printf 'vm.swappiness=10\n' | file_matches "$sysctl_file"
}

swap_apply() {
	if [ ! -f "$swapfile" ]; then
		as_root fallocate -l "${swap_gb}G" "$swapfile"
		as_root chmod 600 "$swapfile"
		as_root mkswap "$swapfile"
	fi
	if ! swap_active; then
		as_root swapon "$swapfile"
	fi
	if ! fstab_has_swap; then
		if [ "$dry_run" = 1 ]; then
			printf 'would run: append "/swapfile none swap sw 0 0" to %s\n' "$fstab"
		else
			printf '/swapfile none swap sw 0 0\n' | as_root tee -a "$fstab" >/dev/null
		fi
	fi
	changed=0
	put_lines "$sysctl_file" 0644 "vm.swappiness=10"
	if [ "$changed" = 1 ]; then
		as_root sysctl -w vm.swappiness=10
	fi
}

# --- lingering -----------------------------------------------------------

linger_ok() {
	[ -e "$linger_file" ]
}

linger_apply() {
	as_root loginctl enable-linger "$target_user"
}

apt_upgrade
ensure "unattended-upgrades is installed with 20auto-upgrades" auto_ok auto_apply "sudo vps/host-setup.sh"
if [ -n "$timezone" ]; then
	ensure "time zone is $timezone" tz_ok tz_apply "sudo timedatectl set-timezone $timezone"
else
	ok "time zone left as is"
fi
if [ "$swap_gb" = 0 ]; then
	ok "swap skipped (--swap-gb 0)"
else
	ensure "swap file /swapfile of ${swap_gb} GB is active" swap_ok swap_apply "sudo vps/host-setup.sh --swap-gb $swap_gb"
fi
ensure "lingering is on for $target_user" linger_ok linger_apply "sudo loginctl enable-linger $target_user"
finish
