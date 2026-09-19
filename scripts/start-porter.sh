#!/usr/bin/env bash
# Starts porter alone. Thin wrapper over start-bot.sh, which holds the actual logic.
exec "$(dirname "${BASH_SOURCE[0]}")/start-bot.sh" porter "$@"
