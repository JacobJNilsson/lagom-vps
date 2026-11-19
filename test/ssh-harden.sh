#!/bin/sh
# Test vps/ssh-harden.sh: it needs keys, writes the drop-in once, and restores on a bad config.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"

script=$repo/vps/ssh-harden.sh
export LAGOM_HOME=$tmp/home
dropin=$LAGOM_ROOT/etc/ssh/sshd_config.d/10-keys-only.conf

run_sh() {
	rc=0
	out=$(sh "$script" "$@" 2>&1) || rc=$?
}

# Without authorized_keys the script exits 1 and writes nothing.
reset_state
run_sh
[ "$rc" = 1 ] || fail "no keys exited $rc, want 1"
assert_has "$out" "no public key found"
[ ! -e "$dropin" ] || fail "the drop-in exists without keys"
log_lacks "sshd -t"

# An empty or comment-only authorized_keys still counts as no keys.
mkdir -p "$LAGOM_HOME/.ssh"
printf '# only a comment\n' >"$LAGOM_HOME/.ssh/authorized_keys"
run_sh
[ "$rc" = 1 ] || fail "comment-only keys exited $rc, want 1"

# --check reports the cloud image defaults as missing.
run_sh --check
[ "$rc" = 1 ] || fail "--check on defaults exited $rc, want 1"
assert_has "$out" "^MISSING: sshd does not show passwordauthentication no"

# With a key, the script writes the drop-in once.
printf 'ssh-ed25519 AAAAfake placeholder\n' >"$LAGOM_HOME/.ssh/authorized_keys"
run_sh
[ "$rc" = 0 ] || fail "run with keys exited $rc: $out"
grep -qx 'PasswordAuthentication no' "$dropin" || fail "drop-in lacks PasswordAuthentication no"
grep -qx 'PermitRootLogin no' "$dropin" || fail "drop-in lacks PermitRootLogin no"
log_has "sshd -t"
log_has "systemctl reload ssh"

run_sh --check
[ "$rc" = 0 ] || fail "--check after a run exited $rc: $out"
assert_has "$out" "^ok: nothing is missing"

reset_log
run_sh
[ "$rc" = 0 ] || fail "second run exited $rc: $out"
log_lacks "sshd -t"
log_lacks "reload"
assert_lacks "$out" "^changed:"

# A failing sshd -t removes a new drop-in.
reset_state
mkdir -p "$LAGOM_HOME/.ssh"
FAKE_SSHD_T_RC=1
export FAKE_SSHD_T_RC
run_sh
[ "$rc" = 1 ] || fail "failing sshd -t exited $rc, want 1"
assert_has "$out" "sshd -t rejected"
[ ! -e "$dropin" ] || fail "the new drop-in stayed after sshd -t failed"
log_lacks "reload"

# A failing sshd -t restores the old drop-in.
mkdir -p "$(dirname "$dropin")"
printf 'old\n' >"$dropin"
run_sh
[ "$rc" = 1 ] || fail "failing sshd -t with an old file exited $rc, want 1"
[ "$(cat "$dropin")" = old ] || fail "the old drop-in was not restored"
unset FAKE_SSHD_T_RC

# --dry-run writes nothing.
reset_state
mkdir -p "$LAGOM_HOME/.ssh"
run_sh --dry-run
[ "$rc" = 0 ] || fail "--dry-run exited $rc: $out"
assert_has "$out" "^would run: sudo install"
[ ! -e "$dropin" ] || fail "--dry-run wrote the drop-in"

printf 'ssh-harden: ok\n'
