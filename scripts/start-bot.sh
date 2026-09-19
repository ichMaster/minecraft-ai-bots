#!/usr/bin/env bash
# Starts ONE bot of the swarm in its own process, with its own MindServer.
#
# Usage: ./scripts/start-bot.sh <role>[index] [index] [--log]
#   ./scripts/start-bot.sh porter        - the single Porter
#   ./scripts/start-bot.sh guard 2       - Guard2 of a multi-guard roster
#   ./scripts/start-bot.sh guard2        - the same thing
#
# Which bots exist is decided by config/roster.json and materialised by deploy.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MINDCRAFT="$ROOT/mindcraft"
CUSTOM="$MINDCRAFT/profiles/custom"

LOG=""
ARGS=()
for a in "$@"; do
    if [ "$a" = "--log" ]; then LOG=1; else ARGS+=("$a"); fi
done

RAW="$(printf '%s' "${ARGS[0]:-}" | tr '[:upper:]' '[:lower:]')"
[ -n "$RAW" ] || { echo "usage: $(basename "$0") <role>[index] [index] [--log]"; exit 1; }

# 'guard2' and 'guard 2' are the same bot.
ROLE="${RAW%%[0-9]*}"
INDEX="${RAW#"$ROLE"}"
[ -n "$INDEX" ] || INDEX="${ARGS[1]:-}"

# A role with one bot has no number; with several, the files are guard1.json, guard2.json...
if [ -n "$INDEX" ]; then
    PROFILE_FILE="$ROLE$INDEX.json"
else
    PROFILE_FILE="$ROLE.json"
    INDEX=1
fi

if [ ! -f "$CUSTOM/$PROFILE_FILE" ]; then
    echo "no such bot: $PROFILE_FILE"
    if [ -d "$CUSTOM" ] && ls "$CUSTOM"/*.json >/dev/null 2>&1; then
        echo "available: $(cd "$CUSTOM" && ls *.json | sed 's/\.json$//' | tr '\n' ' ')"
    fi
    echo "the roster lives in config/roster.json - edit it and run ./scripts/deploy.sh"
    exit 1
fi

# Ports are spaced 10 apart per role, so Guard1..Guard9 never collide with Miner.
# The 813x-815x range is used because 808x was taken by unrelated software.
case "$ROLE" in
    porter) BASE=8130 ;;
    miner)  BASE=8140 ;;
    guard)  BASE=8150 ;;
    *)      BASE=8160 ;;
esac
PORT=$((BASE + INDEX - 1))

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if command -v nvm >/dev/null 2>&1; then
    nvm use >/dev/null 2>&1 || nvm use 22 >/dev/null
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" = "22" ] || { echo "Node $NODE_MAJOR is active, need Node 22. Run: nvm install 22"; exit 1; }
[ -d "$MINDCRAFT/node_modules" ] || { echo "dependencies missing. Run: cd mindcraft && nvm use && npm install"; exit 1; }

lsof -i :25565 -sTCP:LISTEN >/dev/null 2>&1 || { echo "nothing on 25565 - start the server first: ./scripts/start-server.sh"; exit 1; }

PORT="${MINDSERVER_PORT_OVERRIDE:-$PORT}"
if lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    HOLDER="$(lsof -i ":$PORT" -sTCP:LISTEN -t | head -1)"
    HOLDER_CMD="$(ps -p "$HOLDER" -o command= 2>/dev/null | cut -c1-70)"
    if printf '%s' "$HOLDER_CMD" | grep -q "custom/$PROFILE_FILE"; then
        echo "${PROFILE_FILE%.json} is already running (pid $HOLDER)"
    else
        echo "mindserver port $PORT is taken by something else: pid $HOLDER, $HOLDER_CMD"
        echo "pick a free port: MINDSERVER_PORT_OVERRIDE=<port> $(basename "$0") $RAW"
    fi
    exit 1
fi

export MINDSERVER_PORT="$PORT"
# One browser tab per bot would be a tab per swarm member; print the URL instead.
export SETTINGS_JSON='{"auto_open_ui":false}'

NAME="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['name'])" "$CUSTOM/$PROFILE_FILE")"
echo "$NAME on node $(node -v), mindserver http://localhost:$PORT"
cd "$MINDCRAFT"
if [ -n "$LOG" ]; then
    exec node main.js --profiles "./profiles/custom/$PROFILE_FILE" 2>&1 | tee "run-${PROFILE_FILE%.json}.log"
else
    exec node main.js --profiles "./profiles/custom/$PROFILE_FILE"
fi
