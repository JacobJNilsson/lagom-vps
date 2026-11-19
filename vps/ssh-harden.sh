#!/bin/sh
# Turn off SSH passwords and root login. Only keys can log in afterwards.
#
# Usage: sudo vps/ssh-harden.sh [--check] [--dry-run]
#   --check    change nothing, print MISSING with a fix, exit 1 when sshd allows passwords
#   --dry-run  print each command that would change the system
#
# The script writes /etc/ssh/sshd_config.d/10-keys-only.conf, runs sshd -t, then reloads ssh.
# The name starts with 10-, so it sorts before the cloud image drop-in 60-cloudimg-settings.conf.
# sshd keeps the first value it reads, so this file wins. The script refuses to run when the
# user has no public key in authorized_keys. It restores the old file when sshd -t fails.
# Keep your first SSH session open and test a second one before you close it.
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

target_user=${SUDO_USER:-$(id -un)}
home_dir=${LAGOM_HOME:-$(getent passwd "$target_user" | cut -d: -f6)}
keys=$home_dir/.ssh/authorized_keys
dropin=$root_prefix/etc/ssh/sshd_config.d/10-keys-only.conf

# has_keys: succeed when authorized_keys holds at least one public key.
has_keys() {
	grep -Eq '^(ssh-|ecdsa-|sk-)' "$keys" 2>/dev/null
}

if [ "$check" = 1 ]; then
	effective=$(priv sshd -T 2>/dev/null || true)
	for want in "passwordauthentication no" "kbdinteractiveauthentication no" "permitrootlogin no" "pubkeyauthentication yes"; do
		if printf '%s\n' "$effective" | grep -qx "$want"; then
			ok "sshd has $want"
		else
			miss "sshd does not show $want" "sudo vps/ssh-harden.sh"
		fi
	done
	finish_check
fi

has_keys || die "no public key found in $keys. Add your key first, or this script would lock you out."

backup=$(mktemp)
trap 'rm -f "$backup"' EXIT
had_old=0
if [ -f "$dropin" ]; then
	cp "$dropin" "$backup"
	had_old=1
fi

put_lines "$dropin" 0644 "PasswordAuthentication no" "KbdInteractiveAuthentication no" "PermitRootLogin no" "PubkeyAuthentication yes"
if [ "$changed" = 1 ]; then
	if ! as_root sshd -t; then
		if [ "$had_old" = 1 ]; then
			as_root install -m 0644 "$backup" "$dropin"
		else
			as_root rm -f "$dropin"
		fi
		die "sshd -t rejected the new config. The old file is back."
	fi
	as_root systemctl reload ssh
fi
finish
