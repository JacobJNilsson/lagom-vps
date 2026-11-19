#!/bin/sh
# Test lib/common.sh: put_file is idempotent and run honors --dry-run.
set -eu
# shellcheck source=harness.sh
. "$(dirname "$0")/harness.sh"
# shellcheck source=../lib/common.sh
. "$repo/lib/common.sh"

target=$LAGOM_ROOT/etc/example/file.conf

out=$(printf 'one\n' | put_file "$target" 0644)
assert_has "$out" "^changed: "
[ "$(cat "$target")" = one ] || fail "put_file did not write the file"

out=$(printf 'one\n' | put_file "$target" 0644)
assert_has "$out" "^ok: .* is current"
assert_lacks "$out" "^changed"

out=$(printf 'two\n' | put_file "$target" 0644)
assert_has "$out" "^changed: "
[ "$(cat "$target")" = two ] || fail "put_file did not update the file"

# put_lines runs in the current shell, so changed=1 reaches the caller.
changed=0
put_lines "$target" 0644 "three" "four" >/dev/null
[ "$changed" = 1 ] || fail "put_lines did not set changed"
[ "$(cat "$target")" = "three
four" ] || fail "put_lines wrote the wrong content"
changed=0
put_lines "$target" 0644 "three" "four" >/dev/null
[ "$changed" = 0 ] || fail "put_lines changed an identical file"

dry_run=1
marker=$tmp/marker
out=$(run touch "$marker")
assert_has "$out" "^would run: touch "
[ ! -e "$marker" ] || fail "run executed under --dry-run"
out=$(as_root touch "$marker")
assert_has "$out" "^would run: sudo touch "
[ ! -e "$marker" ] || fail "as_root executed under --dry-run"
dry_run=0

run touch "$marker"
[ -e "$marker" ] || fail "run did not execute"

out=$(miss "thing" "do it")
assert_has "$out" "^MISSING: thing"
assert_has "$out" "^  fix: do it"

if parse_common_flag --check; then :; else fail "--check not parsed"; fi
[ "$check" = 1 ] || fail "check not set"
if parse_common_flag --other; then fail "--other parsed"; fi

printf 'lib-common: ok\n'
