#!/usr/bin/env bash
# Downloads the pinned Paper server jar into server/paper.jar and verifies its sha256.
#
# The old api.papermc.io/v2 endpoint is sunset and answers {"ok":false,"error":"sunset"}.
# The current one is fill.papermc.io/v3 and requires a User-Agent header.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MC_VERSION="${MC_VERSION:-1.21.6}"   # must match minecraft_version in config/settings.js
SERVER="$ROOT/server"
UA="minecraft-ai-bots/1.0"

mkdir -p "$SERVER"

read -r BUILD URL SHA < <(
    curl -fsS -H "User-Agent: $UA" "https://fill.papermc.io/v3/projects/paper/versions/$MC_VERSION/builds" |
    python3 -c "
import json, sys
builds = json.load(sys.stdin)
stable = [b for b in builds if b.get('channel') == 'STABLE'] or builds
b = stable[0]
d = b['downloads']['server:default']
print(b['id'], d['url'], d['checksums']['sha256'])
"
)

echo "Paper $MC_VERSION build $BUILD"

if [ -f "$SERVER/paper.jar" ] && echo "$SHA  $SERVER/paper.jar" | shasum -a 256 -c - >/dev/null 2>&1; then
    echo "server/paper.jar already up to date"
else
    curl -fsSL -H "User-Agent: $UA" -o "$SERVER/paper.jar.tmp" "$URL"
    echo "$SHA  $SERVER/paper.jar.tmp" | shasum -a 256 -c - >/dev/null
    mv "$SERVER/paper.jar.tmp" "$SERVER/paper.jar"
    echo "server/paper.jar downloaded and verified"
fi

# Paper refuses to start until the EULA is accepted; accepting it here is the same
# click-through as editing eula.txt by hand after the first failed start.
if ! grep -qs '^eula=true' "$SERVER/eula.txt"; then
    printf 'eula=true\n' > "$SERVER/eula.txt"
    echo "server/eula.txt accepted (https://aka.ms/MinecraftEULA)"
fi

echo "done"
