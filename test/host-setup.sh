#!/bin/sh
# Test vps/host-setup.sh on a fake machine: check, apply and a second run that writes nothing.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"

script=$repo/vps/host-setup.sh
export OS_RELEASE="$tmp/os-release"
printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"$OS_RELEASE"
export SUDO_USER=tester

run_hs() {
	rc=0
	out=$(sh "$script" "$@" 2>&1) || rc=$?
}

writes='-y|mkswap|fallocate|swapon [^-]|enable-linger|set-timezone|sysctl -w'

# A fresh machine is missing swap and lingering.
reset_state
FAKE_UPGRADABLE=3
export FAKE_UPGRADABLE
run_hs --check --swap-gb 1
[ "$rc" = 1 ] || fail "fresh --check exited $rc, want 1"
assert_has "$out" "^MISSING: swap file"
assert_has "$out" "^MISSING: lingering is on for tester"
assert_has "$out" "^MISSING: unattended-upgrades"
assert_has "$out" "^note: 3 pending apt upgrades"
log_lacks "$writes"

# A run fixes everything. A check afterwards passes.
run_hs --swap-gb 1
[ "$rc" = 0 ] || fail "first run exited $rc: $out"
log_has "apt-get -y -oDpkg::Options::=--force-confold upgrade"
log_has "fallocate -l 1G $LAGOM_ROOT/swapfile"
log_has "mkswap $LAGOM_ROOT/swapfile"
log_has "loginctl enable-linger tester"
log_has "sysctl -w vm.swappiness=10"
grep -q '^APT::Periodic::Unattended-Upgrade "1";$' "$LAGOM_ROOT/etc/apt/apt.conf.d/20auto-upgrades" || fail "20auto-upgrades lacks the upgrade line"
grep -q '^APT::Periodic::Update-Package-Lists "1";$' "$LAGOM_ROOT/etc/apt/apt.conf.d/20auto-upgrades" || fail "20auto-upgrades lacks the lists line"
grep -q '^/swapfile none swap sw 0 0$' "$LAGOM_ROOT/etc/fstab" || fail "fstab lacks the swap line"
grep -q '^vm.swappiness=10$' "$LAGOM_ROOT/etc/sysctl.d/99-lagom-swappiness.conf" || fail "swappiness drop-in is missing"

run_hs --check --swap-gb 1
[ "$rc" = 0 ] || fail "--check after a run exited $rc: $out"
assert_has "$out" "^ok: nothing is missing"

# A second run logs no write commands and the fstab keeps one swap line.
reset_log
run_hs --swap-gb 1
[ "$rc" = 0 ] || fail "second run exited $rc: $out"
log_lacks "$writes"
[ "$(grep -c '^/swapfile ' "$LAGOM_ROOT/etc/fstab")" = 1 ] || fail "fstab holds the swap line more than once"
assert_lacks "$out" "^changed:"

# The time zone changes once, and only when asked.
reset_log
run_hs --swap-gb 1 --timezone America/New_York
log_has "timedatectl set-timezone America/New_York"
reset_log
run_hs --swap-gb 1 --timezone America/New_York
log_lacks "set-timezone"
unset FAKE_UPGRADABLE

# --swap-gb 0 skips swap.
reset_state
run_hs --swap-gb 0
[ "$rc" = 0 ] || fail "--swap-gb 0 exited $rc: $out"
assert_has "$out" "^ok: swap skipped"
log_lacks "fallocate"

# --dry-run prints commands and changes nothing.
reset_state
run_hs --dry-run
[ "$rc" = 0 ] || fail "--dry-run exited $rc: $out"
assert_has "$out" "^would run: sudo fallocate -l 4G "
log_lacks "$writes"
[ ! -e "$LAGOM_ROOT/swapfile" ] || fail "--dry-run created the swap file"
[ ! -e "$LAGOM_ROOT/var/lib/systemd/linger/tester" ] || fail "--dry-run enabled lingering"

# A non-Ubuntu release is refused.
printf 'ID=debian\nVERSION_ID="12"\n' >"$OS_RELEASE"
run_hs --check
[ "$rc" = 1 ] || fail "wrong OS exited $rc, want 1"
assert_has "$out" "Ubuntu 24.04"

printf 'host-setup: ok\n'
