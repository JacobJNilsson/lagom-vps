#!/bin/sh
# Clone lagom-factory and run its installer, then run its check.
#
# Usage: vps/agent-tools.sh [--check] [--dry-run] [--multiplexer tmux|rex] [--lagom-dir DIR]
#   --multiplexer MUX  terminal tool that lagom-factory checks for (default: tmux)
#   --lagom-dir DIR    where the clone lives (default: ~/src/lagom-factory)
#   --check            run only DIR/machine/install.sh --check and pass its exit code through
#   --dry-run          print each command that would change the system
#
# The script tracks lagom-factory's default branch. It runs no sudo. It does not copy
# lagom-factory's manual steps (apt packages, the AppArmor profile, Go, Claude Code, sfy and
# links). Do those first, from lagom-factory's docs/new-machine.md. See docs/06-agent-tools.md.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$here/../lib/common.sh"

repo_url=https://github.com/JacobJNilsson/lagom-factory.git
multiplexer=tmux
lagom_dir=${HOME:-}/src/lagom-factory

while [ "$#" -gt 0 ]; do
	if parse_common_flag "$1"; then
		shift
		continue
	fi
	case $1 in
	--multiplexer)
		[ "$#" -ge 2 ] || usage_error "--multiplexer needs a value"
		case $2 in
		tmux | rex) multiplexer=$2 ;;
		*) usage_error "--multiplexer must be tmux or rex" ;;
		esac
		shift 2
		;;
	--lagom-dir)
		[ "$#" -ge 2 ] || usage_error "--lagom-dir needs a value"
		lagom_dir=$2
		shift 2
		;;
	*) usage_error "unknown option: $1" ;;
	esac
done

installer=$lagom_dir/machine/install.sh
guide=https://github.com/JacobJNilsson/lagom-factory/blob/main/docs/new-machine.md

if [ "$check" = 1 ]; then
	if [ ! -x "$installer" ]; then
		miss "lagom-factory is not cloned at $lagom_dir" "vps/agent-tools.sh --lagom-dir $lagom_dir"
		finish_check
	fi
	exec "$installer" --check --multiplexer "$multiplexer"
fi

have git || die "git is not installed. Run: sudo apt install git"

# clone_lagom: clone lagom-factory, or fast-forward an existing clone.
clone_lagom() {
	if [ -d "$lagom_dir/.git" ]; then
		run git -C "$lagom_dir" pull --ff-only
	else
		run git clone "$repo_url" "$lagom_dir"
	fi
}

# run_lagom: install the Go tools and skills, then run lagom-factory's own check.
run_lagom() {
	if ! run "$installer" --clone-skills; then
		printf 'The lagom-factory installer failed. Finish the manual steps first: %s\n' "$guide" >&2
		exit 1
	fi
	if ! run "$installer" --check --multiplexer "$multiplexer"; then
		printf 'Fix the items above. The manual steps are in %s\n' "$guide" >&2
		exit 1
	fi
}

clone_lagom
run_lagom
finish
