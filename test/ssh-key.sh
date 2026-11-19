#!/bin/sh
# Test laptop/ssh-key.sh: it creates a key once and never overwrites it.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"

script=$repo/laptop/ssh-key.sh
export SSH_DIR=$tmp/ssh

rc=0
out=$(sh "$script" --check 2>&1) || rc=$?
[ "$rc" = 1 ] || fail "--check without a key exited $rc, want 1"
assert_has "$out" "^MISSING: "

out=$(sh "$script" 2>&1)
[ -f "$SSH_DIR/oci-vps" ] || fail "private key not created"
[ -f "$SSH_DIR/oci-vps.pub" ] || fail "public key not created"
assert_has "$out" "^ssh-ed25519 "
log_has "ssh-keygen -t ed25519 -f $SSH_DIR/oci-vps -C oci-vps"

reset_log
echo marker >"$SSH_DIR/oci-vps"
out=$(sh "$script" 2>&1)
[ "$(cat "$SSH_DIR/oci-vps")" = marker ] || fail "the private key was overwritten"
log_lacks "ssh-keygen"
assert_has "$out" "^ok: SSH key"

out=$(sh "$script" --check 2>&1)
assert_has "$out" "^ok: nothing is missing"

rm "$SSH_DIR/oci-vps.pub"
reset_log
out=$(sh "$script" 2>&1)
log_has "ssh-keygen -y -f $SSH_DIR/oci-vps"
[ "$(cat "$SSH_DIR/oci-vps")" = marker ] || fail "rebuilding the public key touched the private key"

rm "$SSH_DIR/oci-vps" "$SSH_DIR/oci-vps.pub"
out=$(sh "$script" --dry-run named 2>&1)
assert_has "$out" "would run: ssh-keygen -t ed25519"
[ ! -e "$SSH_DIR/named" ] || fail "--dry-run created a key"

printf 'ssh-key: ok\n'
