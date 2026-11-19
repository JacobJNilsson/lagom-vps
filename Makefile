SHELL := /bin/sh

# Every shell file: scripts, helpers, tests and the fake commands used by tests.
SH_FILES = $$(find lib laptop vps test -type f \( -name '*.sh' -o -path 'test/fakes/*' \) 2>/dev/null | sort)

.PHONY: check lint test

check: lint test

# Set LINT_STRICT=1 (CI does) to fail when shellcheck or shfmt is missing.
lint:
	@for f in $(SH_FILES); do sh -n "$$f" || exit 1; done
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x -s sh $(SH_FILES); \
	elif [ -n "$$LINT_STRICT" ]; then echo "shellcheck is missing"; exit 1; \
	else echo "skip: shellcheck is not installed"; fi
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -d -p $(SH_FILES); \
	elif [ -n "$$LINT_STRICT" ]; then echo "shfmt is missing"; exit 1; \
	else echo "skip: shfmt is not installed"; fi

test:
	@sh test/run.sh
