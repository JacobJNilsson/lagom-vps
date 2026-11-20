#!/bin/sh
# Test vps/firewall.sh: stock rules pass, an active UFW or a missing chain or port rule fails.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"

script=$repo/vps/firewall.sh
stock=$repo/test/fixtures/iptables-stock.txt

run_fw() {
	rc=0
	out=$(sh "$script" "$@" 2>&1) || rc=$?
}

# Stock Oracle rules with netfilter-persistent enabled pass.
: >"$FAKE_STATE/svc-netfilter-persistent"
export FAKE_IPTABLES_FILE="$stock"
run_fw --check
[ "$rc" = 0 ] || fail "stock rules exited $rc: $out"
assert_has "$out" "^ok: nothing is missing"

# The script changes nothing. Only "-S" reads reach iptables.
log_lacks "iptables -(I|A|D|F|X|P|R)( |$)"
log_lacks "iptables-restore"

# An active UFW fails.
export FAKE_UFW=active
run_fw --check
[ "$rc" = 1 ] || fail "active UFW exited $rc, want 1"
assert_has "$out" "^MISSING: UFW is active"
unset FAKE_UFW

# A missing InstanceServices chain fails.
grep -v 'InstanceServices' "$stock" >"$tmp/no-chain.txt"
export FAKE_IPTABLES_FILE="$tmp/no-chain.txt"
run_fw --check
[ "$rc" = 1 ] || fail "missing chain exited $rc, want 1"
assert_has "$out" "^MISSING: the InstanceServices chain is absent"

# A missing port 22 rule fails.
grep -v 'dport 22' "$stock" >"$tmp/no-ssh.txt"
export FAKE_IPTABLES_FILE="$tmp/no-ssh.txt"
run_fw --check
[ "$rc" = 1 ] || fail "missing port rule exited $rc, want 1"
assert_has "$out" "^MISSING: no INPUT rule accepts TCP port 22"
export FAKE_IPTABLES_FILE="$stock"

# A disabled netfilter-persistent fails.
rm "$FAKE_STATE/svc-netfilter-persistent"
run_fw --check
[ "$rc" = 1 ] || fail "disabled persistence exited $rc, want 1"
assert_has "$out" "^MISSING: netfilter-persistent is not enabled"

printf 'firewall: ok\n'
