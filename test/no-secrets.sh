#!/bin/sh
# Fail when a tracked file holds an address or key that identifies a machine or account.
# Checks IPv4 addresses outside the allowed ranges, OCIDs and Tailscale keys with real-looking
# suffixes, and private key headers. Placeholders such as ocid1.compartment.oc1..<id> pass.
# The script tests its own patterns first.
#
# Names cannot live in a tracked file. Keep your own deny words in an untracked list instead.
# The list holds one extended regular expression per line. The check reads the file named by
# NO_SECRETS_DENY_FILE, or .no-secrets.local in the repo root when it exists.
#
# Usage: sh test/no-secrets.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
self=test/no-secrets.sh

# Allowed: link-local, loopback, the three documentation ranges and the any-address 0.0.0.0.
ip_ok=':(169\.254\.|127\.|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)|:0\.0\.0\.0$'

found=0
deny_file=

report() {
	if [ -n "$2" ]; then
		printf 'FAIL: %s\n%s\n' "$1" "$2" >&2
		found=1
	fi
}

# scan FILE...: report each forbidden pattern in the given files.
scan() {
	hits=$(grep -HnIEo '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$@" | grep -Ev "$ip_ok" || true)
	report "IPv4 address outside the allowed ranges" "$hits"
	hits=$(grep -HnIEo 'ocid1\.[a-z0-9_]+\.[a-z0-9-]*\.[a-z0-9-]*\.[a-z0-9]{20,}' "$@" || true)
	report "OCID with a real-looking suffix" "$hits"
	hits=$(grep -HnIEo 'tskey-[A-Za-z0-9-]{10,}' "$@" || true)
	report "Tailscale key" "$hits"
	hits=$(grep -HnIE 'BEGIN [A-Z ]*PRIVATE KEY' "$@" || true)
	report "private key header" "$hits"
	if [ -n "$deny_file" ]; then
		hits=$(grep -HnIi -f "$deny_file" "$@" || true)
		report "word from the deny list" "$hits"
	fi
}

# Self test: bad samples must fail and good samples must pass.
samples=$(mktemp -d)
trap 'rm -rf "$samples"' EXIT
printf '%s\n' '10.20.30.40' >"$samples/ip"
printf '%s\n' 'ocid1.instance.oc1.eu-example-1.abcdefghijklmnopqrstuvwxyz' >"$samples/ocid"
printf '%s\n' 'tskey-auth-abcdefghijklmnop' >"$samples/ts"
printf '%s\n' '-----BEGIN OPENSSH PRIVATE KEY-----' >"$samples/key"
printf '%s\n' 'blocked-example-word' >"$samples/deny"
printf '%s\n' 'a line with Blocked-Example-Word inside' >"$samples/word"
for sample in ip ocid ts key word; do
	found=0
	deny_file=
	[ "$sample" = word ] && deny_file=$samples/deny
	scan "$samples/$sample" 2>/dev/null
	[ "$found" = 1 ] || {
		echo "self test: pattern '$sample' did not fail" >&2
		exit 1
	}
done
printf '%s\n' '169.254.169.254 203.0.113.7 198.51.100.1 192.0.2.9 127.0.0.1 0.0.0.0/0' >"$samples/good"
printf '%s\n' 'ocid1.compartment.oc1..<id> tskey-auth-<key> https://example.com/x' >>"$samples/good"
found=0
deny_file=$samples/deny
scan "$samples/good"
[ "$found" = 0 ] || {
	echo "self test: good sample failed" >&2
	exit 1
}

cd "$repo"
deny_file=${NO_SECRETS_DENY_FILE:-}
if [ -z "$deny_file" ] && [ -f .no-secrets.local ]; then
	deny_file=.no-secrets.local
fi
files=$(git ls-files | grep -v "^$self$")
# shellcheck disable=SC2086
scan $files
if [ "$found" = 1 ]; then
	exit 1
fi
printf 'no-secrets: ok\n'
