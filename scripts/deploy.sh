#!/usr/bin/env bash
# Deploys the configs from config/ into the places on this Mac where they are actually read.
#
#   config/settings.js        -> mindcraft/settings.js
#   config/profiles/*.json    -> mindcraft/profiles/custom/
#   config/patches/*.patch    -> mindcraft/patches/         (replaces the stale upstream mineflayer patch)
#   config/npm-pins.txt       -> exact versions in mindcraft/package.json
#   config/server.properties  -> server/server.properties   (merged into an existing file if present)
#   GEMINI_API_KEY            -> mindcraft/keys.json        (read from the lumi project's .env)
#
# Idempotent. Run it after every config change; mindcraft/ and server/ are treated as build output.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MINDCRAFT="$ROOT/mindcraft"
SERVER="$ROOT/server"
KEY_SOURCE="${KEY_SOURCE:-$HOME/development/lumi/.env}"

[ -d "$MINDCRAFT" ] || { echo "mindcraft/ not found. Run: git clone https://github.com/kolbytn/mindcraft.git '$MINDCRAFT'"; exit 1; }

# 1. settings.js
cp "$ROOT/config/settings.js" "$MINDCRAFT/settings.js"
echo "settings.js -> mindcraft/settings.js"

# 2. profiles, generated from the roster.
#    Minecraft usernames must be unique, so N bots of one role become Guard1..GuardN,
#    each a copy of the role template with its own "name". A role with count 1 keeps
#    the plain name (Guard), so single-bot setups read the same as before.
mkdir -p "$MINDCRAFT/profiles/custom"
rm -f "$MINDCRAFT"/profiles/custom/*.json
python3 - "$ROOT" "$MINDCRAFT" <<'PYGEN'
import json, sys, pathlib, re

root, mindcraft = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
roster = json.loads((root / "config/roster.json").read_text())
out_dir = mindcraft / "profiles/custom"
generated = []

for role, count in roster.items():
    if role.startswith("_"):
        continue
    if not isinstance(count, int) or count < 0:
        sys.exit(f"roster.json: '{role}' must be a non-negative integer, got {count!r}")
    template_path = root / f"config/profiles/{role}.json"
    if not template_path.exists():
        sys.exit(f"roster.json names '{role}', but config/profiles/{role}.json does not exist")
    template = template_path.read_text()
    for i in range(1, count + 1):
        name = role.capitalize() if count == 1 else f"{role.capitalize()}{i}"
        # Replace only the profile's own "name" field, never text inside the prompts.
        body = re.sub(r'"name"\s*:\s*"[^"]*"', f'"name": "{name}"', template, count=1)
        json.loads(body)
        out_name = f"{role}.json" if count == 1 else f"{role}{i}.json"
        (out_dir / out_name).write_text(body)
        generated.append((name, f"./profiles/custom/{out_name}"))

if not generated:
    sys.exit("roster.json asks for zero bots")

# Keep the deployed settings.js in sync so `node main.js` with no arguments
# launches exactly the roster.
settings_path = mindcraft / "settings.js"
settings = settings_path.read_text()
listing = "\n".join(f'        "{path}",' for _, path in generated)
settings, n = re.subn(r'("profiles"\s*:\s*\[)[^\]]*(\])',
                      lambda m: f"{m.group(1)}\n{listing}\n    {m.group(2)}", settings, count=1)
if n != 1:
    sys.exit("could not rewrite the profiles list in settings.js")
settings_path.write_text(settings)

print("roster -> " + ", ".join(name for name, _ in generated))
PYGEN

# 2b. dependency pins and patches.
#     mindcraft's patches are cut against exact versions; its package.json uses ^ ranges, so a
#     fresh npm install drifts past them (mineflayer 4.33 -> 4.39 breaks patches/mineflayer+4.33.0.patch).
rm -f "$MINDCRAFT/patches/mineflayer+4.33.0.patch"
cp "$ROOT"/config/patches/*.patch "$MINDCRAFT/patches/"
echo "patches -> mindcraft/patches/"

while IFS='=' read -r pkg ver; do
    case "$pkg" in ''|\#*) continue ;; esac
    (cd "$MINDCRAFT" && npm pkg set "dependencies.$pkg=$ver")
    echo "pinned $pkg=$ver"
done < "$ROOT/config/npm-pins.txt"

cp "$ROOT/.nvmrc" "$MINDCRAFT/.nvmrc"

# Re-apply patches if dependencies are already installed.
if [ -d "$MINDCRAFT/node_modules" ]; then
    (cd "$MINDCRAFT" && npx --no-install patch-package >/dev/null 2>&1) && echo "patches re-applied" || echo "patch-package did not run (re-run npm install)"
fi

# 3. keys.json, from the lumi project's .env. Never commit the result.
if [ -n "${GEMINI_API_KEY:-}" ]; then
    KEY="$GEMINI_API_KEY"
elif [ -f "$KEY_SOURCE" ]; then
    # The source line carries an inline comment:
    #   GEMINI_API_KEY=AIza...  # gemini-2.5-flash-image key for /generate-faces
    # so strip ' #...' as well as quotes and trailing whitespace.
    KEY="$(grep -m1 '^GEMINI_API_KEY=' "$KEY_SOURCE" |
        sed -E 's/^GEMINI_API_KEY=//; s/[[:space:]]+#.*$//; s/^["'"'"']//; s/["'"'"']$//; s/[[:space:]]+$//')"
else
    echo "no GEMINI_API_KEY in env and $KEY_SOURCE not found"; exit 1
fi
[ -n "$KEY" ] || { echo "GEMINI_API_KEY is empty in $KEY_SOURCE"; exit 1; }

# A Google API key is 'AIza' + 35 chars. Anything else means the line was parsed wrong,
# and the failure would otherwise only surface as a 400 API_KEY_INVALID per bot turn.
if ! printf '%s' "$KEY" | grep -qE '^AIza[0-9A-Za-z_-]{35}$'; then
    echo "GEMINI_API_KEY does not look like a Google API key (length ${#KEY}, expected 39)"; exit 1
fi

# Verify against the API. Note: a key passed as ?key=... in a URL hides this class of bug,
# because curl cuts everything from the first '#', so send it as a header like mindcraft does.
if command -v curl >/dev/null 2>&1; then
    if curl -sf -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent" \
        -H "x-goog-api-key: $KEY" -H 'Content-Type: application/json' \
        -d '{"contents":[{"parts":[{"text":"ok"}]}]}' >/dev/null 2>&1; then
        echo "GEMINI_API_KEY verified against the API"
    else
        echo "WARNING: the API rejected this key - the bots will start but never answer"
    fi
fi
printf '{\n    "GEMINI_API_KEY": "%s"\n}\n' "$KEY" > "$MINDCRAFT/keys.json"
chmod 600 "$MINDCRAFT/keys.json"
echo "GEMINI_API_KEY -> mindcraft/keys.json (${KEY:0:6}...)"

# 4. server.properties. Keys from config/ win; anything the server generated and we do not
#    manage is preserved, so the file survives a server restart rewriting it.
mkdir -p "$SERVER"
if [ -f "$SERVER/server.properties" ]; then
    TMP="$(mktemp)"
    MANAGED="$(grep -vE '^\s*#|^\s*$' "$ROOT/config/server.properties" | cut -d= -f1 | paste -sd'|' -)"
    grep -vE "^($MANAGED)=" "$SERVER/server.properties" > "$TMP" || true
    grep -vE '^\s*#|^\s*$' "$ROOT/config/server.properties" >> "$TMP"
    mv "$TMP" "$SERVER/server.properties"
    echo "server.properties -> server/server.properties (merged)"
else
    cp "$ROOT/config/server.properties" "$SERVER/server.properties"
    echo "server.properties -> server/server.properties (new)"
fi

# 5. Keep the mindcraft clone's own git quiet.
#    It is an upstream checkout we never commit to, but everything deployed above shows up
#    as changes there - and editors that scan nested repositories surface them as pending work.
#    Untracked output goes into its .gitignore; files it tracks are marked skip-worktree, which
#    hides local modifications from git without affecting what deploy writes.
GITIGNORE="$MINDCRAFT/.gitignore"
git -C "$MINDCRAFT" update-index --no-skip-worktree .gitignore 2>/dev/null || true
for entry in 'keys.json' '.nvmrc' 'profiles/custom/' 'patches/mineflayer+4.39.0.patch'; do
    grep -qxF "$entry" "$GITIGNORE" 2>/dev/null || printf '%s\n' "$entry" >> "$GITIGNORE"
done
for tracked in settings.js package.json patches/mineflayer+4.33.0.patch .gitignore; do
    git -C "$MINDCRAFT" update-index --skip-worktree "$tracked" 2>/dev/null || true
done

echo "done"
