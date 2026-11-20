#!/bin/sh
# Stand-in for lagom-factory's machine/install.sh. It logs its arguments and exits with
# FAKE_INSTALL_RC for --clone-skills and FAKE_CHECK_RC for --check.
printf 'lagom-install %s\n' "$*" >>"$FAKE_LOG"
case $1 in
--clone-skills) exit "${FAKE_INSTALL_RC:-0}" ;;
--check) exit "${FAKE_CHECK_RC:-0}" ;;
esac
exit 0
