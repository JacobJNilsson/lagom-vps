#!/bin/sh
# Create an ed25519 SSH key for the new instance. It never overwrites a key.
#
# Usage: laptop/ssh-key.sh [--check] [--dry-run] [NAME]
#   NAME       key file name under ~/.ssh (default: oci-vps)
#   --check    install nothing, print MISSING with a fix, exit 1 when the key is absent
#   --dry-run  print the commands that would run
#
# ssh-keygen asks for a passphrase. The script prints the public key path and content.
# It writes no ~/.ssh/config block. SSH_DIR overrides the folder, for tests.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$here/../lib/common.sh"

name=oci-vps
while [ "$#" -gt 0 ]; do
	if parse_common_flag "$1"; then
		shift
		continue
	fi
	case $1 in
	-*) usage_error "unknown option: $1" ;;
	*/* | "") usage_error "NAME must be a plain file name: $1" ;;
	*) name=$1 ;;
	esac
	shift
done

ssh_dir=${SSH_DIR:-$HOME/.ssh}
key=$ssh_dir/$name

key_present() {
	[ -f "$key" ] && [ -f "$key.pub" ]
}

make_key() {
	run mkdir -p "$ssh_dir"
	run chmod 700 "$ssh_dir"
	if [ ! -f "$key" ]; then
		run ssh-keygen -t ed25519 -f "$key" -C "$name"
	else
		# The private key exists and the public half is missing. Rebuild only the public half.
		if [ "$dry_run" = 1 ]; then
			printf 'would run: ssh-keygen -y -f %s > %s.pub\n' "$key" "$key"
		else
			ssh-keygen -y -f "$key" >"$key.pub"
		fi
	fi
}

ensure "SSH key $key and $key.pub exist" key_present make_key "laptop/ssh-key.sh $name"

if [ "$check" = 0 ] && [ "$dry_run" = 0 ]; then
	printf 'public key file: %s.pub\n' "$key"
	cat "$key.pub"
fi
finish
