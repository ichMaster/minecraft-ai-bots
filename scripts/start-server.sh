#!/usr/bin/env bash
# Starts the local Paper server with the right Java, whatever the shell's default is.
# Usage: ./scripts/start-server.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="$ROOT/server"
JAVA_HOME_21="${JAVA_HOME_21:-/opt/homebrew/opt/openjdk@21}"
HEAP_MIN="${HEAP_MIN:-2G}"
HEAP_MAX="${HEAP_MAX:-4G}"

# homebrew's openjdk@21 is keg-only: the system java and /usr/libexec/java_home
# both ignore it, so point at it directly rather than trusting PATH.
if [ -x "$JAVA_HOME_21/bin/java" ]; then
    JAVA="$JAVA_HOME_21/bin/java"
elif java -version 2>&1 | grep -qE '"(2[1-9]|[3-9][0-9])'; then
    JAVA="java"
else
    echo "Java 21 not found at $JAVA_HOME_21. Install it: brew install openjdk@21"; exit 1
fi

[ -f "$SERVER/paper.jar" ] || { echo "server/paper.jar missing. Run: ./scripts/fetch-server.sh"; exit 1; }

if lsof -i :25565 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "port 25565 is already in use - the server is probably already running"; exit 1
fi

echo "Paper on $("$JAVA" -version 2>&1 | head -1)"
cd "$SERVER"
exec "$JAVA" -Xms"$HEAP_MIN" -Xmx"$HEAP_MAX" -jar paper.jar nogui
