SHELL := /bin/sh

# Every shell file: scripts, helpers, tests and the fake commands used by tests.
SH_FILES = $$(find lib laptop vps test -type f \( -name '*.sh' -o -path 'test/fakes/*' \) 2>/dev/null | sort)

.PHONY: check lint test

check: lint test

# Lint fails when shellcheck or shfmt is missing. It never skips a tool.
# -P SCRIPTDIR resolves each "source=" directive against the script's own folder.
lint:
	@for f in $(SH_FILES); do sh -n "$$f" || exit 1; done
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck is missing: install it to run make lint"; exit 1; }
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt is missing: install it to run make lint"; exit 1; }
	@shellcheck -x -P SCRIPTDIR -s sh $(SH_FILES)
	@shfmt -d -p $(SH_FILES)

test:
	@sh test/run.sh
