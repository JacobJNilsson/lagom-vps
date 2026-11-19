#!/bin/sh
# Test vps/tailscale.sh: install, login, the key staying out of logs and output, and a no-op rerun.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"

script=$repo/vps/tailscale.sh
export OS_RELEASE=$tmp/os-release
printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"$OS_RELEASE"
secret=s3cr3t-placeholder-value
printf '%s\n' "$secret" >"$tmp/keyfile"

run_ts() {
	rc=0
	out=$(sh "$script" "$@" 2>&1) || rc=$?
}

# A fresh machine is missing Tailscale, the service and the login.
reset_state
run_ts --check
[ "$rc" = 1 ] || fail "fresh --check exited $rc, want 1"
assert_has "$out" "^MISSING: Tailscale is installed"
assert_has "$out" "^MISSING: tailscaled is active"
assert_has "$out" "^MISSING: this node is logged in"
log_lacks "apt-get"

# A run with a key file installs, starts and logs in. The key stays out of the log and output.
run_ts --auth-key-file "$tmp/keyfile"
[ "$rc" = 0 ] || fail "run exited $rc: $out"
assert_lacks "$out" "$secret"
log_lacks "$secret"
log_has "tailscale up --auth-key=<redacted>"
[ "$(cat "$FAKE_STATE/ts-key")" = "$secret" ] || fail "the key did not reach tailscale up"
log_has "apt-get install -y tailscale"
log_has "systemctl enable --now tailscaled"
grep -q 'fake content' "$LAGOM_ROOT/usr/share/keyrings/tailscale-archive-keyring.gpg" || fail "keyring not written"
grep -qx 'deb \[signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg\] https://pkgs.tailscale.com/stable/ubuntu noble main' "$LAGOM_ROOT/etc/apt/sources.list.d/tailscale.list" || fail "apt list line is wrong"
log_has "curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg"
log_lacks "\| *(sh|bash)"

run_ts --check
[ "$rc" = 0 ] || fail "--check after a run exited $rc: $out"
assert_has "$out" "^ok: nothing is missing"

# A second run installs and logs in nothing.
reset_log
run_ts --auth-key-file "$tmp/keyfile"
[ "$rc" = 0 ] || fail "second run exited $rc: $out"
log_lacks "apt-get install"
log_lacks "tailscale up"
log_lacks "enable"
assert_lacks "$out" "^changed:"

# --ssh is off until asked, then on once.
run_ts --check --ssh
[ "$rc" = 1 ] || fail "--check --ssh exited $rc, want 1"
assert_has "$out" "^MISSING: Tailscale SSH is on"
run_ts --ssh
log_has "tailscale set --ssh"
reset_log
run_ts --ssh
log_lacks "tailscale set --ssh"

# Without a key file, the login prints a URL through plain "tailscale up".
reset_state
run_ts
[ "$rc" = 0 ] || fail "run without key exited $rc: $out"
log_has "tailscale up$"

# --dry-run changes nothing and never prints the key.
reset_state
run_ts --dry-run --auth-key-file "$tmp/keyfile"
[ "$rc" = 0 ] || fail "--dry-run exited $rc: $out"
assert_has "$out" "would run: sudo tailscale up --auth-key=<redacted>"
assert_lacks "$out" "$secret"
log_lacks "apt-get install"
[ ! -e "$LAGOM_ROOT/etc/apt/sources.list.d/tailscale.list" ] || fail "--dry-run wrote the apt list"

# A missing key file stops the script before any change.
reset_state
run_ts --auth-key-file "$tmp/nope"
[ "$rc" = 1 ] || fail "missing key file exited $rc, want 1"
log_lacks "apt-get"

printf 'tailscale: ok\n'
