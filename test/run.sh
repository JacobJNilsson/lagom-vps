#!/bin/sh
# Run every test/*.sh and stop at the first failure.
#
# Usage: sh test/run.sh [NAME...]
set -eu

here=$(cd "$(dirname "$0")" && pwd)

if [ "$#" -gt 0 ]; then
	names=$*
else
	names=$(cd "$here" && ls ./*.sh | sed 's|^\./||; s|\.sh$||')
fi

for name in $names; do
	case $name in
	run | harness) continue ;;
	esac
	printf '== %s\n' "$name"
	sh "$here/$name.sh"
done
printf 'all tests passed\n'
