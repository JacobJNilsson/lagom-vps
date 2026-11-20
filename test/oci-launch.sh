#!/bin/sh
# Test laptop/oci-launch.sh against the fake oci: reuse, AD fallback, limits, retry and dry-run.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"

script=$repo/laptop/oci-launch.sh
export HOME="$tmp/home"
mkdir -p "$HOME"
export OCI_CLI_CONFIG_FILE="$tmp/oci-config"
: >"$OCI_CLI_CONFIG_FILE"
echo "ssh-ed25519 AAAAfake placeholder" >"$tmp/key.pub"
args="--compartment ocid1.compartment.oc1..fake --subnet ocid1.subnet.oc1..fake --ssh-key $tmp/key.pub"

launch() {
	rc=0
	# shellcheck disable=SC2086
	out=$(sh "$script" $args "$@" 2>&1) || rc=$?
}

# An instance with the name exists: no launch call.
# shellcheck disable=SC2089,SC2090
FAKE_OCI_INSTANCES='{"data": [{"id": "ocid1.instance.oc1..exists", "lifecycle-state": "RUNNING"}]}'
# shellcheck disable=SC2090
export FAKE_OCI_INSTANCES
launch
[ "$rc" = 0 ] || fail "existing instance run exited $rc: $out"
assert_has "$out" "^ok: instance lagom-vps exists"
log_lacks "compute instance launch"
unset FAKE_OCI_INSTANCES

# Capacity error in the first AD: the script tries the second AD, newest non-Minimal image.
reset_log
FAKE_OCI_FULL_ADS=AD-1
export FAKE_OCI_FULL_ADS
launch
[ "$rc" = 0 ] || fail "AD fallback run exited $rc: $out"
assert_has "$out" "no capacity in AD-1"
assert_has "$out" "^ok: launched ocid1.instance.oc1..fake in AD-2"
log_has "launch --availability-domain AD-1"
log_has "launch --availability-domain AD-2"
log_has "--image-id ocid1.image.oc1..newest"
log_has "--shape-config \{\"ocpus\": 2, \"memoryInGBs\": 12\}"
log_lacks "fault-domain"
unset FAKE_OCI_FULL_ADS

# Values above the Always Free limits fail without --allow-paid.
reset_log
launch --ocpus 4
[ "$rc" = 2 ] || fail "--ocpus 4 exited $rc, want 2"
assert_has "$out" "Always Free limit"
launch --memory 24
[ "$rc" = 2 ] || fail "--memory 24 exited $rc, want 2"
log_lacks "compute instance launch"
launch --ocpus 4 --memory 24 --allow-paid
[ "$rc" = 0 ] || fail "--allow-paid run exited $rc: $out"
log_has "memoryInGBs\": 24"

# Retry waits at least 60 seconds per round and stops after N rounds.
reset_log
FAKE_OCI_FULL_ADS="AD-1 AD-2"
export FAKE_OCI_FULL_ADS
launch --retry 3 --wait 5
[ "$rc" = 1 ] || fail "full region exited $rc, want 1"
assert_has "$out" "no capacity in any availability domain after 3 round"
[ "$(grep -c '^sleep 60$' "$FAKE_LOG")" = 2 ] || fail "want two sleeps of 60 seconds"
log_lacks "^sleep 5$"
[ "$(grep -c 'compute instance launch' "$FAKE_LOG")" = 6 ] || fail "want six launch calls"

# The round count has a cap.
reset_log
launch --retry 5000
[ "$rc" = 1 ] || fail "capped run exited $rc, want 1"
assert_has "$out" "after 100 round"
unset FAKE_OCI_FULL_ADS

# --dry-run prints the launch command and runs none.
reset_log
launch --dry-run
[ "$rc" = 0 ] || fail "dry run exited $rc: $out"
assert_has "$out" "would run: oci compute instance launch"
log_lacks "compute instance launch"

# --check passes with a good setup, and reports each gap.
launch --check
[ "$rc" = 0 ] || fail "--check exited $rc: $out"
assert_has "$out" "^ok: nothing is missing"
rm "$OCI_CLI_CONFIG_FILE"
launch --check
[ "$rc" = 1 ] || fail "--check without config exited $rc, want 1"
assert_has "$out" "^MISSING: .*oci-config is missing"
: >"$OCI_CLI_CONFIG_FILE"
FAKE_OCI_BAD_COMPARTMENT=1
export FAKE_OCI_BAD_COMPARTMENT
launch --check
[ "$rc" = 1 ] || fail "--check with a bad compartment exited $rc, want 1"
assert_has "$out" "^MISSING: compartment .* is not readable"

printf 'oci-launch: ok\n'
