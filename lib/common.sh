# lib/common.sh: shared helpers for the lagom-vps scripts.
# Source this file. Sourcing runs nothing. It sets check, dry_run, missing and changed.
#
# Helpers:
#   run CMD [ARG...]           run CMD, or print "would run: CMD ARG..." under --dry-run
#   as_root CMD [ARG...]       like run, through sudo when the user is not root
#   priv CMD [ARG...]          run CMD through sudo when not root, even under --dry-run (for reads)
#   probe CMD [ARG...]         run CMD with PATH=$CHECK_PATH when set (read-only checks)
#   have CMD                   succeed when CMD is on PATH
#   ok MESSAGE                 print "ok: MESSAGE"
#   miss MESSAGE FIX           print "MISSING: MESSAGE" and "  fix: FIX", set missing=1
#   ensure LABEL STATE APPLY FIX   report ok, report missing under --check, or run APPLY
#   finish_check               exit 1 when missing=1, else print "ok: nothing is missing"
#   parse_common_flag ARG      consume --check, --dry-run or --help
#   put_file PATH MODE         write stdin to PATH only when the content differs
#                              (redirect with <, a pipe runs it in a subshell and hides changed)
#   put_lines PATH MODE LINE...  like put_file, with the lines as arguments
#   file_matches PATH          succeed when stdin equals the content of PATH
#   require_os                 fail unless /etc/os-release says Ubuntu 24.04
#
# LAGOM_ROOT prefixes every system path a script writes. Tests set it to a temp folder.

# The sourcing scripts read these variables.
# shellcheck disable=SC2034
check=0
dry_run=0
missing=0
changed=0
root_prefix=${LAGOM_ROOT:-}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

usage_error() {
	printf 'error: %s\n' "$*" >&2
	printf 'Run with --help for usage.\n' >&2
	exit 2
}

# print_usage FILE: print the comment block at the top of FILE.
print_usage() {
	awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$1"
}

# parse_common_flag ARG: succeed when ARG is a shared flag and set its variable.
parse_common_flag() {
	case $1 in
	--check) check=1 ;;
	--dry-run) dry_run=1 ;;
	-h | --help)
		print_usage "$0"
		exit 0
		;;
	*) return 1 ;;
	esac
}

have() {
	command -v "$1" >/dev/null 2>&1
}

run() {
	if [ "$dry_run" = 1 ]; then
		printf 'would run: %s\n' "$*"
		return 0
	fi
	"$@"
}

priv() {
	if [ "$(id -u)" = 0 ]; then
		"$@"
	else
		sudo "$@"
	fi
}

as_root() {
	if [ "$dry_run" = 1 ]; then
		printf 'would run: sudo %s\n' "$*"
		return 0
	fi
	priv "$@"
}

probe() {
	if [ -n "${CHECK_PATH:-}" ]; then
		PATH=$CHECK_PATH "$@"
	else
		"$@"
	fi
}

ok() {
	printf 'ok: %s\n' "$1"
}

miss() {
	printf 'MISSING: %s\n' "$1"
	printf '  fix: %s\n' "$2"
	missing=1
}

# ensure LABEL STATE_FN APPLY_FN FIX
ensure() {
	if "$2"; then
		ok "$1"
	elif [ "$check" = 1 ]; then
		miss "$1" "$4"
	else
		"$3"
		if [ "$dry_run" = 1 ]; then
			printf 'plan: %s\n' "$1"
		else
			ok "$1"
		fi
	fi
}

finish_check() {
	if [ "$missing" = 1 ]; then
		exit 1
	fi
	ok "nothing is missing"
	exit 0
}

# finish: end a script in either mode.
finish() {
	if [ "$check" = 1 ]; then
		finish_check
	fi
	ok "done"
}

# file_matches PATH: succeed when stdin equals the content of PATH.
file_matches() {
	fm_tmp=$(mktemp)
	cat >"$fm_tmp"
	if cmp -s "$fm_tmp" "$1" 2>/dev/null; then
		fm_rc=0
	else
		fm_rc=1
	fi
	rm -f "$fm_tmp"
	return "$fm_rc"
}

# put_file PATH MODE: write stdin to PATH when the content differs. Sets changed=1 on a write.
put_file() {
	pf_tmp=$(mktemp)
	cat >"$pf_tmp"
	if file_matches "$1" <"$pf_tmp"; then
		rm -f "$pf_tmp"
		ok "$1 is current"
		return 0
	fi
	as_root mkdir -p "$(dirname "$1")"
	as_root install -m "$2" "$pf_tmp" "$1"
	rm -f "$pf_tmp"
	changed=1
	printf 'changed: %s\n' "$1"
}

# put_lines PATH MODE LINE...: like put_file, with each LINE on its own line.
# It runs in the current shell, so changed=1 survives. A pipe into put_file would lose it.
put_lines() {
	pl_path=$1
	pl_mode=$2
	shift 2
	pl_tmp=$(mktemp)
	printf '%s\n' "$@" >"$pl_tmp"
	put_file "$pl_path" "$pl_mode" <"$pl_tmp"
	rm -f "$pl_tmp"
}

# require_os: fail unless the machine runs Ubuntu 24.04. OS_RELEASE overrides the file for tests.
require_os() {
	os_file=${OS_RELEASE:-/etc/os-release}
	[ -r "$os_file" ] || die "cannot read $os_file"
	# shellcheck disable=SC1090
	os_ok=$(
		. "$os_file"
		if [ "${ID:-}" = ubuntu ] && [ "${VERSION_ID:-}" = 24.04 ]; then
			echo yes
		fi
	)
	[ "$os_ok" = yes ] || die "this repo targets Ubuntu 24.04. $os_file says otherwise."
}
