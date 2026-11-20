#!/bin/sh
# Test laptop/close-public-ssh.sh: it needs a working Tailscale path and removes only port 22.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"

script=$repo/laptop/close-public-ssh.sh
list=ocid1.securitylist.oc1..fake
rules=$FAKE_STATE/seclist-rules.json

run_cp() {
	rc=0
	out=$(sh "$script" --security-list "$list" "$@" 2>&1) || rc=$?
}

# --check fails while TCP 22 is open to the world.
reset_state
run_cp --check
[ "$rc" = 1 ] || fail "--check exited $rc, want 1"
assert_has "$out" "^MISSING: a TCP 22 ingress rule from 0.0.0.0/0 remains"

# Without --vps or --force the script refuses.
run_cp
[ "$rc" = 2 ] || fail "run without --vps exited $rc, want 2"
log_lacks "security-list update"

# An offline VPS stops the script.
FAKE_TS_PEER_ONLINE=no
export FAKE_TS_PEER_ONLINE
run_cp --vps lagom-vps
[ "$rc" = 1 ] || fail "offline VPS exited $rc, want 1"
assert_has "$out" "does not list lagom-vps as online"
log_lacks "security-list update"

# An online VPS lets the script remove port 22 and keep the other rules.
FAKE_TS_PEER_ONLINE=yes
run_cp --vps lagom-vps --instance ocid1.instance.oc1..fake
[ "$rc" = 0 ] || fail "run exited $rc: $out"
log_has "security-list update --security-list-id $list"
[ "$(jq 'length' "$rules")" = 2 ] || fail "want two rules left"
[ "$(jq '[.[] | select(.["tcp-options"]["destination-port-range"].min == 22)] | length' "$rules")" = 0 ] || fail "port 22 rule stayed"
[ "$(jq '[.[] | select(.["tcp-options"]["destination-port-range"].min == 443)] | length' "$rules")" = 1 ] || fail "port 443 rule was removed"
assert_has "$out" "NSG ocid1.nsg.oc1..fake allows TCP 22"

run_cp --check
[ "$rc" = 0 ] || fail "--check after a run exited $rc: $out"
assert_has "$out" "^ok: nothing is missing"

# A second run changes nothing.
reset_log
run_cp --vps lagom-vps
[ "$rc" = 0 ] || fail "second run exited $rc: $out"
log_lacks "security-list update"

# --undo adds TCP 22 back from one source, once.
run_cp --undo --source 203.0.113.7/32
[ "$rc" = 0 ] || fail "--undo exited $rc: $out"
[ "$(jq '[.[] | select(.source == "203.0.113.7/32")] | length' "$rules")" = 1 ] || fail "undo rule missing"
reset_log
run_cp --undo --source 203.0.113.7/32
log_lacks "security-list update"
run_cp --undo
[ "$rc" = 2 ] || fail "--undo without --source exited $rc, want 2"

# --force skips the Tailscale check, and --dry-run updates nothing.
reset_state
FAKE_TS_PEER_ONLINE=no
run_cp --force --dry-run
[ "$rc" = 0 ] || fail "--force --dry-run exited $rc: $out"
assert_has "$out" "would run: oci network security-list update"
log_lacks "security-list update"
[ ! -e "$rules" ] || fail "--dry-run changed the rules"

printf 'close-public-ssh: ok\n'
