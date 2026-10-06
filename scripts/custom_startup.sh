#!/usr/bin/env bash
set -euo pipefail

# Kasm also invokes this hook when assigning/opening an existing session.
# This full-desktop workspace only starts applications at initial launch.
for argument in "$@"; do
    case "$argument" in
        -g|--go|-a|--assign) exit 0 ;;
    esac
done
if [[ -n "${DISABLE_CUSTOM_STARTUP:-}" ]]; then
    exit 0
fi

/usr/bin/desktop_ready

if [[ "${AUTOSTART_THUNDERBIRD:-true}" == "true" ]] && ! pgrep -x 'thunderbird|thunderbird-bin' > /dev/null; then
    thunderbird &
fi
if [[ "${AUTOSTART_NEXTCLOUD:-true}" == "true" ]] && ! pgrep -x nextcloud > /dev/null; then
    nextcloud &
fi
