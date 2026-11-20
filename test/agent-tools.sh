#!/bin/sh
# Test vps/agent-tools.sh: clone or pull, run lagom-factory's installer, pass its check through.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"

script=$repo/vps/agent-tools.sh
dir=$tmp/lagom
FAKE_LAGOM_INSTALL=$repo/test/fixtures/fake-lagom-install.sh
export FAKE_LAGOM_INSTALL

run_at() {
	rc=0
	out=$(sh "$script" --lagom-dir "$dir" "$@" 2>&1) || rc=$?
}

# A fresh machine clones lagom-factory, installs, then checks.
reset_state
run_at
[ "$rc" = 0 ] || fail "fresh run exited $rc: $out"
log_has "git clone https://github.com/JacobJNilsson/lagom-factory.git $dir"
log_has "lagom-install --clone-skills"
log_has "lagom-install --check --multiplexer tmux"
log_lacks "sudo"

# With an existing clone the script pulls and does not clone.
reset_log
run_at --multiplexer rex
[ "$rc" = 0 ] || fail "existing clone run exited $rc: $out"
log_has "git -C $dir pull --ff-only"
log_lacks "git clone"
log_has "lagom-install --check --multiplexer rex"

# --check passes the installer's exit code through and installs nothing.
reset_log
FAKE_CHECK_RC=1
export FAKE_CHECK_RC
run_at --check
[ "$rc" = 1 ] || fail "--check with a failing installer exited $rc, want 1"
log_lacks "clone-skills"
log_lacks "git"
unset FAKE_CHECK_RC
run_at --check
[ "$rc" = 0 ] || fail "--check with a passing installer exited $rc: $out"

# --check without a clone reports it as missing.
rm -rf "$dir"
run_at --check
[ "$rc" = 1 ] || fail "--check without a clone exited $rc, want 1"
assert_has "$out" "^MISSING: lagom-factory is not cloned"

# A failing installer stops the script with a pointer to the manual steps.
reset_log
FAKE_INSTALL_RC=1
export FAKE_INSTALL_RC
run_at
[ "$rc" = 1 ] || fail "failing installer exited $rc, want 1"
assert_has "$out" "new-machine.md"
log_lacks "lagom-install --check"
unset FAKE_INSTALL_RC

# A bad multiplexer is a usage error.
run_at --multiplexer screen
[ "$rc" = 2 ] || fail "bad multiplexer exited $rc, want 2"

# --dry-run clones nothing.
rm -rf "$dir"
reset_log
run_at --dry-run
[ "$rc" = 0 ] || fail "--dry-run exited $rc: $out"
assert_has "$out" "would run: git clone"
[ ! -e "$dir" ] || fail "--dry-run created the clone"

printf 'agent-tools: ok\n'
