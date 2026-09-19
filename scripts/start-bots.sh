#!/usr/bin/env bash
# Starts the three bots on Node 22, after checking the server is actually up.
# Usage: ./scripts/start-bots.sh [--log]   (--log tees output to mindcraft/run.log)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MINDCRAFT="$ROOT/mindcraft"

# nvm is a shell function, not a binary, so it has to be sourced.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if command -v nvm >/dev/null 2>&1; then
    nvm use >/dev/null 2>&1 || nvm use 22 >/dev/null
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" != "22" ]; then
    echo "Node $NODE_MAJOR is active, but the native modules (gl, canvas) need Node 22. Run: nvm install 22"; exit 1
fi

[ -d "$MINDCRAFT/node_modules" ] || { echo "dependencies missing. Run: cd mindcraft && nvm use && npm install"; exit 1; }

if ! lsof -i :25565 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "nothing is listening on 25565 - start the server first: ./scripts/start-server.sh"; exit 1
fi

echo "node $(node -v), server on :25565, starting Porter/Miner/Guard"
cd "$MINDCRAFT"
if [ "${1:-}" = "--log" ]; then
    # run.log is what the Gemini request count is counted from
    exec node main.js 2>&1 | tee run.log
else
    exec node main.js
fi
