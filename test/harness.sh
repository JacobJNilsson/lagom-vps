# test/harness.sh: shared setup for the tests. Source it from a test file.
# It builds a temp folder, puts the fake commands first on PATH and offers assertions.
# shellcheck disable=SC2034

repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export LAGOM_ROOT="$tmp/root"
export FAKE_LOG="$tmp/fake.log"
export FAKE_STATE="$tmp/state"
mkdir -p "$LAGOM_ROOT" "$FAKE_STATE"
: >"$FAKE_LOG"
PATH=$repo/test/fakes:$PATH
export PATH

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

reset_log() {
	: >"$FAKE_LOG"
}

# reset_state: start from a fresh fake machine.
reset_state() {
	rm -rf "$LAGOM_ROOT" "$FAKE_STATE"
	mkdir -p "$LAGOM_ROOT/etc" "$FAKE_STATE"
	reset_log
}

# assert_has TEXT PATTERN: TEXT matches the extended regex PATTERN.
assert_has() {
	printf '%s\n' "$1" | grep -Eq -- "$2" || fail "expected /$2/ in:
$1"
}

# assert_lacks TEXT PATTERN: TEXT does not match PATTERN.
assert_lacks() {
	if printf '%s\n' "$1" | grep -Eq -- "$2"; then
		fail "did not expect /$2/ in:
$1"
	fi
}

log_has() {
	assert_has "$(cat "$FAKE_LOG")" "$1"
}

log_lacks() {
	assert_lacks "$(cat "$FAKE_LOG")" "$1"
}

# status_of CMD...: print the exit code of CMD without stopping the test.
status_of() {
	if "$@" >"$tmp/out" 2>&1; then
		echo 0
	else
		echo $?
	fi
}
