#!/bin/sh
# Install Tailscale from its apt repo, start it and log in.
#
# Usage: sudo vps/tailscale.sh [--check] [--dry-run] [--ssh] [--auth-key-file FILE]
#   --ssh                 turn on Tailscale SSH with: tailscale set --ssh
#   --auth-key-file FILE  read an auth key from FILE and log in without a browser
#   --check               change nothing, print MISSING with a fix, exit 1 when anything is missing
#   --dry-run             print each command that would change the system
#
# The script adds the repo and key from pkgs.tailscale.com. It never pipes a download into a shell.
# Without --auth-key-file, "tailscale up" prints a login URL. Open it in a browser and log in.
# Tailscale documents no way to read the key from a file, so the key reaches "tailscale up" as
# an argument. Local users can see it in the process list while that command runs. Use a one-off
# key with a short expiry, and delete the file afterwards. The script never prints the key.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$here/../lib/common.sh"

want_ssh=0
auth_key_file=

while [ "$#" -gt 0 ]; do
	if parse_common_flag "$1"; then
		shift
		continue
	fi
	case $1 in
	--ssh)
		want_ssh=1
		shift
		;;
	--auth-key-file)
		[ "$#" -ge 2 ] || usage_error "--auth-key-file needs a value"
		auth_key_file=$2
		shift 2
		;;
	*) usage_error "unknown option: $1" ;;
	esac
done

if [ -n "$auth_key_file" ] && [ ! -s "$auth_key_file" ]; then
	die "auth key file is missing or empty: $auth_key_file"
fi

require_os

codename=noble
keyring=$root_prefix/usr/share/keyrings/tailscale-archive-keyring.gpg
list_file=$root_prefix/etc/apt/sources.list.d/tailscale.list
key_url=https://pkgs.tailscale.com/stable/ubuntu/$codename.noarmor.gpg
list_line="deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu $codename main"

# --- install -------------------------------------------------------------

install_ok() {
	dpkg -s tailscale >/dev/null 2>&1 && [ -f "$keyring" ] && printf '%s\n' "$list_line" | file_matches "$list_file"
}

install_apply() {
	key_tmp=$(mktemp)
	curl -fsSL "$key_url" -o "$key_tmp"
	put_file "$keyring" 0644 <"$key_tmp"
	rm -f "$key_tmp"
	put_lines "$list_file" 0644 "$list_line"
	as_root apt-get update
	as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale
}

# --- service -------------------------------------------------------------

service_ok() {
	systemctl is-active tailscaled >/dev/null 2>&1
}

service_apply() {
	as_root systemctl enable --now tailscaled
}

# --- login ---------------------------------------------------------------

logged_in() {
	have tailscale && priv tailscale status --json 2>/dev/null | grep -Eq '"BackendState": *"Running"'
}

login_apply() {
	if [ -z "$auth_key_file" ]; then
		as_root tailscale up
	elif [ "$dry_run" = 1 ]; then
		printf 'would run: sudo tailscale up --auth-key=<redacted>\n'
	else
		ts_key=$(cat "$auth_key_file")
		as_root tailscale up --auth-key="$ts_key"
		ts_key=
	fi
}

# --- Tailscale SSH -------------------------------------------------------

ssh_on() {
	have tailscale && priv tailscale debug prefs 2>/dev/null | grep -Eq '"RunSSH": *true'
}

ssh_apply() {
	as_root tailscale set --ssh
}

ensure "Tailscale is installed from pkgs.tailscale.com" install_ok install_apply "sudo vps/tailscale.sh"
ensure "tailscaled is active" service_ok service_apply "sudo systemctl enable --now tailscaled"
ensure "this node is logged in to a tailnet" logged_in login_apply "sudo vps/tailscale.sh, or sudo tailscale up"
if [ "$want_ssh" = 1 ]; then
	ensure "Tailscale SSH is on" ssh_on ssh_apply "sudo tailscale set --ssh"
fi
finish
