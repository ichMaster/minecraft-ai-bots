# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Minecraft assistant bots built on [Mindcraft](https://github.com/kolbytn/mindcraft) (Mineflayer). No game code, mod, or plugin is written — bots join a local server as ordinary players and all behavior comes from Mindcraft's built-in command set plus per-role prompts. [CONCEPT.md](CONCEPT.md) is the spec (Ukrainian); [docs/step1-instructions.md](docs/step1-instructions.md) is the current working instruction set for stage 1.

This directory is not its own git repo — the enclosing repo root is `~/development`, shared with many unrelated projects. Scope every git operation to this directory's paths.

## Config is the source; mindcraft/ and server/ are output

```
config/settings.js         -> mindcraft/settings.js
config/profiles/*.json     -> role templates for the generator below
config/roster.json         -> mindcraft/profiles/custom/*.json + the profiles list in settings.js
config/patches/*.patch     -> mindcraft/patches/
config/npm-pins.txt        -> exact versions in mindcraft/package.json
config/server.properties   -> server/server.properties   (merged, server rewrites this file)
GEMINI_API_KEY             -> mindcraft/keys.json        (read from ~/development/lumi/.env)
```

Edit only `config/`, then run `./scripts/deploy.sh`. `mindcraft/` (upstream clone) and `server/` are gitignored build output — hand edits there are lost on the next deploy. The deploy is idempotent; re-run it after the Minecraft server regenerates `server.properties`.

## Commands

```
nvm use                                            # Node 22 (.nvmrc) - required, see below
./scripts/deploy.sh                                # push configs into place, regenerate keys.json
./scripts/fetch-server.sh                          # download+verify server/paper.jar, accept EULA
./scripts/start-server.sh                          # Paper on Java 21, preflight-checked
./scripts/start-bots.sh [--log]                    # all three bots in one process, preflight-checked
./scripts/start-porter.sh                          # one bot alone (also -miner, -guard);
                                                   # wrappers over start-bot.sh <name>; mindserver 813x,
                                                   # not 808x - that range clashed with other software
cd mindcraft && npm install                        # already done; native deps: canvas, node-canvas-webgl, gl
cd mindcraft && nvm use && node main.js            # what start-bots.sh wraps; UI on :8080
cd server && java -Xms2G -Xmx4G -jar paper.jar nogui   # what start-server.sh wraps
```

There is no automated test suite. Verification is the in-game acceptance criteria in [docs/step1-instructions.md](docs/step1-instructions.md) step 5, logged to `docs/test-log.md`.

## Mindcraft constraints that shape the config

- **`blocked_actions` is global**, not per-profile (`mindcraft/src/agent/agent.js:62`). `config/settings.js` holds only what no role may do (`!newAction`, `!attackPlayer`, `!goal`/`!endGoal`, which are blocked to keep behaviour predictable rather than to save quota); per-role prohibitions from CONCEPT.md live in each profile's prompt and are therefore advisory, not enforced.
- **A profile that overrides `conversing` must keep the placeholders** `$COMMAND_DOCS`, `$EXAMPLES`, `$STATS`, `$INVENTORY`, `$MEMORY`, `$SELF_PROMPT`. Dropping `$COMMAND_DOCS` leaves the bot with no commands at all — it will just talk.
- **With more than one agent, public chat is ignored** (`agent.js` returns early when other agents are present). Bots only hear `/msg <name> <text>`.
- **No runtime code generation in stage 1**: `allow_insecure_coding: false` plus `!newAction` blocked. Builder in stage 2 is the single exception, and only inside a bounded build radius that never destroys player-placed blocks.
- **Java 21 is keg-only** (`/opt/homebrew/opt/openjdk@21`): the system `java` and `/usr/libexec/java_home -v 21` both return the old Corretto 11. Paper then prints a misleading `Minecraft 1.19 requires ... Java 17` - the version in that string is hardcoded and means nothing. `start-server.sh` resolves the path itself.
- **The swarm is generated, not hand-listed.** `config/roster.json` says how many bots per role; `deploy.sh` stamps out one profile per bot with a unique `name` (Guard1..GuardN, or plain Guard when the count is 1) and rewrites the `profiles` array in the deployed `settings.js`. Minecraft usernames must be unique, so never hand-add a second profile with the same name. Each extra bot is another stream of Gemini requests - not a quota problem on this key, but more chatter to follow.
- **Node 22 only.** `gl` (pulled in by `node-canvas-webgl`/`prismarine-viewer`) has prebuilds up to ABI 127; on Node 25 it compiles ANGLE from source and fails. The render stack cannot be dropped either — `src/agent/agent.js` statically imports the vision modules even with `render_bot_view`/`allow_vision` off.
- **Upstream patches drift.** mindcraft cuts patches against exact versions but declares `^` ranges. `config/npm-pins.txt` pins `mineflayer` and `minecraft-data`, and `config/patches/mineflayer+4.39.0.patch` replaces the stale 4.33.0 one — it keeps only the hunk that still matters (ore blocks report material `incorrect_for_wooden_tool`, which inflates `digTime` ~4x).
- **Paper downloads go through `fill.papermc.io/v3`** with a `User-Agent` header; the old `api.papermc.io/v2` is sunset and returns `{"ok":false,"error":"sunset"}`. `scripts/fetch-server.sh` handles this — do not hand-download the jar.
- **The server rewrites `server.properties` on first start**, so re-run `./scripts/deploy.sh` afterwards; the deploy merges our keys back over the generated file.
- **`minecraft_version` is pinned to 1.21.6** — Mineflayer supports up to 1.21.11; do not follow the latest Minecraft release.
- **No emoji** in any prompt, profile, log, or output.
- Models: `gemini-flash-latest` (chat), `gemini-pro-latest` (code), `gemini-embedding-001` (embeddings), verified against ListModels. `cooldown: 1000` per profile - rate limits are not a constraint on this key, so the pause is minimal; a 429 storm means raise it.

## Language

CONCEPT.md, the role prompts, the docs, and in-game chat are Ukrainian; `settings.js` keeps `language: "en"` so Mindcraft's translation layer stays off and the model's own Ukrainian output reaches the player unaltered. Code and identifiers are English.
