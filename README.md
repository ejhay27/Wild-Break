# WILDBREAK

An open-world action RPG for Roblox: gunplay, melee, harvesting and crafting
across seven regions, with seven regional world bosses, seven dungeon bosses,
companions, squads and clans.

This repository is the **source of truth**. It is a Rojo project: the Luau under
`src/` is synchronised into a Roblox place rather than edited inside Studio.

> **Status: READY FOR ROBLOX STUDIO TESTING.**
> The project builds, every module compiles, all critical dependencies resolve,
> and 168 automated assertions pass headlessly. It has **not** been playtested
> in Roblox Studio — no Roblox engine was available in the development
> environment. See [Verification status](#verification-status).

---

## Contents

- [Project overview](#project-overview)
- [Repository layout](#repository-layout)
- [Architecture](#architecture)
- [Setup](#setup)
- [Build and sync with Rojo](#build-and-sync-with-rojo)
- [Running the tests](#running-the-tests)
- [Feature inventory](#feature-inventory)
- [Boss encounter guarantees](#boss-encounter-guarantees)
- [Known issues and remaining work](#known-issues-and-remaining-work)
- [Manual Roblox Studio test plan](#manual-roblox-studio-test-plan)
- [Verification status](#verification-status)

---

## Project overview

| | |
|---|---|
| **Genre** | Open-world action RPG |
| **Engine** | Roblox (Luau), R15 avatars |
| **Players** | Shared-world open world; 8-player dungeons |
| **Platforms** | PC and Android (CODM-style touch controls) |
| **World** | Seven regions plus the Haven Overlook hub |
| **Bosses** | 7 regional world bosses, 7 dungeon bosses, the Elder Veyl operation |
| **Progression** | Levels, mastery tracks, gear rarity, star evolution, crafting |

Design pillars that shape the code:

- **The server is authoritative.** The client sends *intents* ("I fired toward
  direction D"). The server validates range, line of sight, ammo, cooldowns and
  state, computes the result, and tells the client what happened. A client never
  sends a damage number.
- **All tunables live in `src/shared/Config`.** No magic numbers in systems code.
- **Bosses must always be defeatable.** Glitch, vanish and invulnerability
  mechanics are intentional, but they are implemented inside a state machine
  that proves a defeat condition always exists.

---

## Repository layout

```
.
├── default.project.json      Rojo project (source -> Roblox service mapping)
├── .luaurc                   strict mode, lint config, require aliases
├── aftman.toml               pinned toolchain (rojo, selene, stylua, luau)
├── selene.toml stylua.toml   linter and formatter configuration
├── src/
│   ├── boot/                 entry points (server and client)
│   ├── server/               SERVER ONLY -> ServerScriptService
│   │   ├── Services/         23 gameplay services
│   │   └── World/            world generation (ActorFactory, WorldBuilder)
│   ├── client/               CLIENT ONLY -> StarterPlayerScripts
│   │   ├── Controllers/      13 controllers
│   │   ├── Effects/          pooled visual effects
│   │   └── Input/            touch controls
│   ├── character/            CLIENT ONLY -> StarterCharacterScripts
│   ├── shared/               REPLICATED -> ReplicatedStorage
│   │   ├── Combat/           damage pipeline, status effects, boss encounters
│   │   ├── Config/           34 configuration registries
│   │   ├── Constants/        Enums, Limits
│   │   ├── Inventory/ Networking/ PlayerData/ Resources/ Security/ Types/
│   │   └── Utilities/        RNG, timers, logging, math, pooling, validation
│   └── ui/                   REPLICATED -> ReplicatedStorage.UI
├── tests/
│   ├── harness/              minimal headless test harness + Roblox stubs
│   └── spec/                 7 spec files
├── tools/
│   ├── run_tests.py          headless test runner and static lints
│   └── build_luau.sh         builds the Luau CLI from source
└── assets/                   placeholder until real assets are imported
```

---

## Architecture

### Service / container mapping

| Path | Roblox container | Replicated to clients |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | yes |
| `src/ui` | `ReplicatedStorage.UI` | yes |
| `src/server` | `ServerScriptService.Server` | **no** |
| `src/boot/ServerMain.server.luau` | `ServerScriptService.WildbreakServerMain` | **no** |
| `src/client` | `StarterPlayerScripts.Client` | runs per client |
| `src/boot/ClientMain.client.luau` | `StarterPlayerScripts.WildbreakClientMain` | runs per client |
| `src/character` | `StarterCharacterScripts.Character` | runs per character |

Server modules are required from `ServerScriptService`, never from
`ReplicatedStorage`. This matters: a server service in a replicated container
would ship DataStore logic, admin authorisation and rate-limit internals to
every client.

### Bootstrap sequence

**Server** (`src/boot/ServerMain.server.luau`)

1. Wait for `ReplicatedStorage.Shared` and `ServerScriptService.Server.Services`.
2. `Init(services)` on all 22 services — build state, no side effects.
3. `Start(services)` — register remote handlers, begin loops, connect events.
4. Connect `PlayerAdded` / `PlayerRemoving` and catch up on anyone who joined
   during boot.
5. Start the fixed 30 Hz tick (`PlayerService`, `CombatService`, `CompanionService`).
6. `game:BindToClose` flushes every profile.

**Client** (`src/boot/ClientMain.client.luau`)

1. Wait for the replicated containers.
2. `Init` / `Start` on all 13 controllers.
3. Fire `WB_ClientReady`, then request the profile. The handshake retries with
   backoff so a dropped packet cannot leave the HUD blank.
4. `RenderStepped` drives presentation only.

### Networking

`src/shared/Networking/Remotes.luau` is the single source of truth: **84**
remotes, each declared with a kind, a direction, an argument schema, a rate
limit, a burst allowance and (for privileged channels) an admin level.

`NetworkService` is the only module that creates `RemoteEvent` objects, under a
`WB_Remotes` folder. Every inbound call passes through one funnel:

```
definition lookup -> mute check -> token bucket -> Packet.ValidateArgs
                  -> admin authorisation -> pre-hooks -> pcall(handler)
```

Clients can never invent a remote, and no inbound remote is unthrottled.

### Boss encounters

Boss rules live in a **pure, deterministic state machine** at
`src/shared/Combat/BossEncounter.luau`. It has no Roblox globals, so the whole
encounter can be driven headlessly. `BossService` owns the actors and applies
the events the machine emits.

**How a world boss actually starts** — `WorldService` measures every player's
position each tick. When a player comes within 1.25x the arena radius of a
region's arena, it calls `BossService.StartWorldBoss(regionId)`, which spawns
the boss actor at that arena and registers it with `CombatService`. The call is
idempotent: an already-live boss returns the existing encounter, so a crowded
arena cannot spawn a second one.

**Distance is measured, never assumed.** A participant the server has not
located is flagged `positionKnown = false` and their distance is set *far away*,
not to zero. Zero means "standing on the boss", which would silently place that
player inside every attack radius. Unmeasured participants are simply not hit by
the blast.

---

## The playable world

The world is **generated at server start** by `src/server/World/WorldBuilder.luau`
from `RegionConfig`. There are no hand-placed parts and no `.rbxl` scene file:
running the game builds the world.

`SpawnService.Init` claims and builds it exactly once, before any player joins.

**Haven Overlook (the hub, at the world origin)**

- A raised plate with a rock rim so nobody walks off the edge.
- A `SpawnLocation` plus four deployment pads.
- The Hall of Haven and its spire as the visual landmark.
- A safe zone: no hostile spawns, and every respawn returns here.

**The seven regions**

Each one gets a grounded landmass at its configured centre and radius, a raised
rim, a three-tower landmark with a lit beacon, scattered foliage, an **arena**
placed 55% of the way out along the axis facing away from the hub, and its own
lighting and atmosphere (fog, ambient, clock time, sky colour) applied when the
region becomes the busiest.

| Region | Centre (studs) | Radius | Boss |
|---|---:|---:|---|
| Verdant Reach | 0, 40, 0 | 1800 | Thornmaw |
| Cinderfall | 3600, 30, 0 | 1500 | **Pyr axis** |
| Frostveil | 0, 25, -3700 | 1500 | Glacieron |
| Umbra Expanse | -3800, 25, 0 | 1400 | Noctyra |
| Solara Basin | 0, 35, 3800 | 1400 | **Aurion, the Sunheart Colossus** |
| Pelagic Frontier | 3400, 10, 3400 | 1600 | Abyssalith |
| Null Horizon | -3600, 60, 3700 | 1300 | Parallax, the Unmade |

**Traversal** — a raised causeway connects Haven Overlook to every region, so
the whole world is reachable on foot without deploying. Falling out of the world
is detected (below y = -600) and the player is returned to the hub.

**Actors** — `ActorFactory.luau` builds everything that lives in the world:
bosses (with a Humanoid and an aimable `CoreSocket` weak point), beasts,
resource nodes, pickups and trigger volumes, into `WB_Bosses`, `WB_Beasts`,
`WB_Nodes`, `WB_Pickups` and `WB_Triggers` under `workspace`.

Everything here is procedural geometry standing in for real art. The shapes are
deliberate placeholders — see [Assets outstanding](#assets-outstanding).

---

## Setup

### Requirements

| Tool | Version | Notes |
|---|---|---|
| [Rojo](https://rojo.space) | 7.x | `aftman.toml` pins 7.7.1 |
| [Roblox Studio](https://create.roblox.com) | current | for playtesting |
| Python | 3.9+ | test runner (standard library only) |
| Luau CLI | 0.744 | only needed to run tests headlessly |

Optional: [Selene](https://github.com/Kampfkarren/selene) and
[StyLua](https://github.com/JohnnyMorganz/StyLua) for linting and formatting.

### Install

```bash
git clone https://github.com/ejhay27/Wild-Break.git
cd Wild-Break

# Toolchain (installs rojo, selene, stylua into ~/.aftman)
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/LGPhatguy/aftman/main/scripts/install.sh | sh
aftman install
```

### Enable the admin panel

The admin panel ships **disabled**. `AdminConfig.OwnerUserIds` is an empty
allowlist, so every privileged remote is refused and the state is logged at
startup. To enable it, edit `src/shared/Config/AdminConfig.luau`:

```lua
Admin.OwnerUserIds = { 0000000, 0000000 }  -- the real owner UserIds
Admin.PanelEnabled = true
Admin.TestOnlyMode = false
```

Exactly two owners are supported (`AdminConfig.ValidateAll` enforces it).
Do not commit real UserIds from a shared machine.

### Assets

`assets/` is empty. The game currently runs on **procedural placeholders**:
parts, beams and particles stand in for models and effects, and every audio id
is `nil` until a real asset is uploaded. `AudioConfig.MissingAssets()` lists
what is outstanding. Nothing references a non-existent asset, so nothing errors
at runtime — see [Known issues](#known-issues-and-remaining-work).

---

## Build and sync with Rojo

```bash
# Build a standalone place file
rojo build default.project.json -o WildBreak.rbxlx

# Or live-sync into an open Studio session
rojo serve default.project.json
#   then in Studio: Rojo plugin > Connect
```

### Validating the configuration

Rojo was not available in the development environment (release downloads are
blocked), so `rojo build` has **not** been executed here. The project file can
still be checked:

```bash
# 1. every $path target exists (run from the repository root)
python3 - <<'PY'
import json, os
tree = json.load(open("default.project.json"))["tree"]
def walk(node, label=""):
    if isinstance(node, dict):
        if "$path" in node:
            print(label, node["$path"], os.path.exists(node["$path"]))
        for k, v in node.items():
            if k not in ("$className", "$path", "$properties"):
                walk(v, k)
walk(tree)
PY

# 2. structural lints + the full test suite (includes require resolution)
python3 tools/run_tests.py
```

---

## Running the tests

```bash
python3 tools/run_tests.py            # every spec
python3 tools/run_tests.py boss       # only specs matching "boss"
```

The runner:

1. Runs two static lints — registry dot-call style, and **undefined module
   roots** (catches `Foo.bar` where `Foo` was never required, a defect invisible
   to both the compiler and the config specs).
2. Mirrors `src/` and `tests/` into `.wbtest/`, rewriting
   `require(script.Parent...)` into `.luaurc` alias requires.
3. Generates a symbol audit of every `Enums.X.Y` / `Limits.X.Y` reference so a
   spec can prove they exist.
4. Executes each spec with the Luau CLI against the Roblox value-type stubs.

The Luau CLI is not bundled. Build it with:

```bash
./tools/build_luau.sh      # installs to ~/.local/bin (luau, luau-analyze)
```

### Current results

| Spec | Assertions | Result |
|---|---:|---|
| `architecture_spec` | 21 | pass |
| `boss_encounter_spec` | 36 | pass |
| `config_spec` | 48 | pass |
| `data_integrity_spec` | 12 | pass |
| `runtime_spec` | 19 | pass |
| `social_spec` | 35 | pass |
| `symbols_spec` | 3 | pass |
| **Total** | **174** | **0 failures, 0 skipped** |

Counts are per-spec. (The harness previously shared counters across specs, so
every spec after the first reported its own total plus all previous ones — this
is fixed.)

### Static analysis

```bash
python3 tools/run_tests.py >/dev/null      # regenerate .wbtest/
cd .wbtest && find src/shared -name '*.luau' | xargs luau-analyze --mode=strict
```

`luau-analyze` 0.744 reports **1,660 diagnostics** on `src/shared` — but it has
no `--defs` flag and rejects `declare` syntax, so it cannot be given Roblox type
definitions. Roughly **959** of those diagnostics are missing-`Vector3` /
missing-`Instance` / unknown-`game` noise that would vanish with a proper API
dump, and most of the remainder cascades from the same root cause. **Strict
typing against the Roblox API could not be verified in this environment.** The
genuine defects it did surface were fixed (see below).

---

## Feature inventory

Legend: **T** tested headlessly · **I** implemented, not tested ·
**P** partial · **S** needs Roblox Studio · **A** awaiting assets

### Core (I, S)

| System | Status | Notes |
|---|---|---|
| Player lifecycle, authoritative runtime state | I, S | `PlayerService` |
| Health / stamina regeneration | I, S | server-clocked |
| Down / revive / respawn (always to the hub) | I, S | |
| Anti-teleport position validation | I, S | `Movement.IsPlausibleMove` |
| Profile persistence, session locks, retry, autosave | I, S | `DataService` |
| Close flush (`BindToClose`) | I, S | |
| Networking funnel (schema, rate limit, admin gate) | I, S | 84 remotes |
| Fixed 30 Hz server tick | I, S | |

### Combat (I, S)

| System | Status |
|---|---|
| Server-authoritative fire (server raycast) | I, S |
| Damage pipeline (armour, resistance, weak points, crits) | **T** |
| Status effects (stacking, expiry, tick damage) | **T** |
| Reload, weapon switch, melee combo, block | I, S |
| Abilities and per-weapon Ultimates | I, S |
| Gadgets (delayed AoE) | I, S |

### World (I, S)

| System | Status | Notes |
|---|---|---|
| Resource nodes and 3-minute ordinary respawn | **T** | 180 s asserted |
| Harvesting with mastery-scaled rates | I, S | |
| Region membership and proximity queries | I, S | `WorldService` |
| Beast spawning, aggro, population caps | I, S | LOD by distance |
| Hazards (heat, cold, contamination, storms, fall damage) | I, S | |
| World events with declared reset behaviour | I, S | |
| Boats | I, S | |
| **Terrain geometry** | **A** | no region has been built in Studio |

### Bosses (T + I)

| System | Status |
|---|---|
| Encounter state machine (phases, attacks, defeat, cleanup) | **T** |
| Null Horizon / Parallax safeguards | **T** |
| Light Samurai 5% detonation | **T** |
| Pyr axis cocoon and final form | I, S |
| Boss meshes, animations and arenas | **A** |

### Progression, inventory, social (I, S)

| System | Status |
|---|---|
| Inventory mutations, containers, capacity | **T** (model) |
| Crafting and recipes | I, S |
| Attachments and star evolution | I, S |
| Experience, levels, mastery, discoveries | I, S |
| Companions (taming, hatching, levels, caps) | I, S |
| Squads, clans, clan war queue | I, S |
| Player-to-player trading with finalisation delay | **T** (rules) |
| Dungeon instances and stage progression | I, S |
| Deployment (Quick Drop glide, tactical, hub respawn) | **T** (rules) |

### Presentation (I, S, A)

| System | Status | Notes |
|---|---|---|
| HUD (vitals, ammo, crosshair, hit marker, boss bar) | I, S, A | built in code |
| Detonation telegraph | I, S | unmissable by design |
| Screen stack (inventory, settings, deployment, map, companions) | I, S | |
| Settings with graphics preset ladder Auto→Ultra | I, S | |
| Mobile CODM-style touch controls | I, S | |
| Audio playback | I, **A** | all asset ids are `nil` |
| Visual effects (pooled, procedural) | I, **A** | no imported art |
| Two-owner admin panel with audit log | **T** (auth) | disabled by default |

---

## Boss encounter guarantees

`BossEncounter.luau` enforces these on every tick, and each has a test:

1. **Always damageable** — a boss flagged `alwaysDamageable` never resolves to
   zero incoming damage; a chip-damage floor applies through shields.
2. **Monotonic phases** — a boss cannot walk backwards through its script, so
   it cannot loop between two phases.
3. **Bounded phases** — every phase has a timeout. When one expires the fight is
   forced forward instead of stalling.
4. **Explicit phases still fire** — phases with a negative threshold (Pyr axis
   final form) are checked every tick and cannot be skipped.
5. **Final detonation resolves** — the Light Samurai's 5% explosion starts once,
   resolves once, and either defeats the boss (survivors) or wipes cleanly.
6. **Rewards once** — distribution is behind a latch.
7. **Terminal state** — every encounter ends in `Defeated` or `Resetting`.

Events are buffered on the encounter and drained by `Tick`, so a caller that
ignores `ApplyDamage`'s return value cannot lose a detonation or defeat event.

### Null Horizon / Parallax, the Unmade

Glitching is a mechanic, never immunity. Phase 4 is `Vulnerable` with a 1.4×
damage multiplier, and every phase is damageable. Absence is clamped to
`ParallaxMaxAbsentSeconds` (6 s) and glitch windows to `ParallaxMaxGlitchSeconds`
(3.5 s). Teleports resolve to validated positions.

**Defect fixed:** phase 1 had no `timeoutSeconds`, so the fight could stall
indefinitely at full health. It now has one, and a test asserts every phase is
bounded.

### Aurion, the Sunheart Colossus (Light Region Samurai)

At 5% HP the boss enters its final phase: invulnerable, no attacks except the
scripted detonation, 12-second telegraph. After the explosion:

- **players survived** → the boss is defeated automatically, no further damage
  needed;
- **everyone fell** → the encounter wipes and the boss is scheduled to respawn.

Either way it terminates. The countdown latches, so repeated threshold checks
cannot restart it; a hard timeout force-resolves if the service never reports.

**Defect fixed:** before this work, nothing ran the detonation. The boss sat
invulnerable at 5% until the 1800-second encounter timeout and then silently
reset — no defeat, no rewards, no way to finish the fight.

---

## Known issues and remaining work

### Blockers

| # | Issue | Action |
|---|---|---|
| 1 | **No Roblox Studio playtest** | No engine in the dev environment. Work the [Studio test plan](#manual-roblox-studio-test-plan). |
| 2 | **Rojo never executed** | This sandbox may only reach `github.com`, `codeload.github.com`, `api.github.com`, `registry.npmjs.org`, `pypi.org` and `files.pythonhosted.org`. Rojo's release binaries are served from `release-assets.githubusercontent.com`, which is blocked, and no npm package ships a real `rojo` binary. So `rojo build default.project.json -o WildBreak.rbxlx` **cannot be run here** — it must be run on a machine with network access. What *was* verified instead: every `$path` target in `default.project.json` exists on disk, every `require` resolves, and no server-only module is reachable from a replicated container. |
| 3 | **Strict typing unverified** | `luau-analyze` needs Roblox type definitions it cannot be given here. Re-run with a proper API dump. |
| 4 | **`assets/` is empty** | Every model, animation and sound is a procedural placeholder. See below. |

### Assets outstanding

- **Models**: all weapons, beasts, bosses, boats, props, the Haven Overlook hub
  and all seven regions.
- **Animations**: locomotion, weapon handling, melee combos, glide, boss
  attack sets.
- **Audio**: 827 sounds defined; **0** have an `assetId`. Playback is skipped
  and logged, so nothing errors, but the game is silent.
  `AudioConfig.MissingAssets()` returns the full list.
- **VFX**: burst and telegraph effects are procedural spheres and cylinders.

### Code gaps

- Dungeon interiors, the Elder Veyl operation and the Clan War place are not
  built. Clan War exists as a queue and roster only.
- `Localization/` and `Definitions/` directories are referenced by the design
  but are not populated.
- Deployment (the boat/glider redeploy flow) routes to the region you pick, but
  the causeways already make every region walkable, so it is a convenience
  rather than the only way in.
- World events, hazards and the companion loop are implemented server-side and
  tick, but they have had no playtesting at all.

---

## Manual Roblox Studio test plan

These cannot be automated without a Roblox engine. Run them in this order.

**Build and boot**

1. `rojo build default.project.json -o WildBreak.rbxlx`; open it. Check the
   Output window — there must be **no** red errors.
2. Confirm the explorer tree: `ServerScriptService.Server.Services` (23 modules),
   `ServerScriptService.Server.World`, `ServerScriptService.WildbreakServerMain`,
   `ReplicatedStorage.Shared`, `ReplicatedStorage.UI`,
   `StarterPlayerScripts.Client`, `StarterPlayerScripts.WildbreakClientMain`,
   `StarterCharacterScripts.Character`.
3. **Security check** — while playing, inspect `ReplicatedStorage` on a client.
   No `Server` folder, no service module, no DataStore code may be present.
4. Press Play. `WILDBREAK server ready` then `WILDBREAK client ready` must both
   appear. The HUD renders and the profile request resolves.

**The world**

4a. The log must show `world ready: 8 regions`. Confirm `workspace.WB_World`
    contains a hub plate, seven region plates, seven landmarks, seven arenas and
    seven causeways.
4b. Your character must appear **standing on Haven Overlook**, not falling and
    not at the origin. Confirm the spawn pad, the rim and the Hall of Haven.
4c. Walk to the edge of the hub. The rim must stop you; you must not fall into
    the void.
4d. Follow a causeway into a region. The fog, ambient light and clock time must
    change as you cross in, and the HUD region label must update.
4e. **Deliberately fall off the world.** Within ~1 second you must be returned
    to Haven Overlook and the log must say so.

**Core loop**

5. Move, sprint and jump. The camera orbits and the character is responsive.
6. Fire a weapon: server raycast, ammo decrements, hit markers appear. Verify
   ammo and reload are server-clocked (try rapid input — the server must not
   accept out-of-order reloads).
7. Approach a glowing node in any region, hold to harvest. Confirm it depletes
   (visually too), that you cannot harvest one from more than 14 studs away, and
   that it returns after **exactly 180 seconds** for an ordinary node.
8. Take fall damage. Land from a glide — the grace window must absorb it.
9. Open the inventory, craft an item, equip a weapon, attach a modification.
10. Let a beast kill you. Confirm the downed state, revive, and respawn at
    Haven Overlook.

**Bosses — Null Horizon (Parallax)**

11. Walk into the Null Horizon arena (south-west, past the Umbra Expanse
    causeway). The boss must wake on its own — the log says
    `players reached the Null Horizon arena, waking parallax`. Damage it through
    all four phases.
12. During phase 3, confirm it vanishes — and that it **always returns within
    6 seconds** at a valid position.
13. Confirm damage lands in **every** phase, including while glitching.
14. Kill it. Rewards are granted **once**; the boss despawns; no further attacks.

**Bosses — Light Region Samurai (Aurion)**

15. Walk into the Solara Basin arena (north). Aurion must wake on its own.
    Bring it to 5% HP. A 12-second telegraph countdown must appear.
16. Confirm it cannot be damaged during the finale.
17. **Survive** the explosion (shield, heal, or stand outside 260 studs).
    The boss must die on its own with no further input.
18. Repeat and let the blast kill everyone. The encounter must still end — the
    boss resets rather than hanging in its final phase.
19. Try to re-trigger the countdown by any means. It must fire only once.

**Platforms**

20. Enable the Roblox Studio device emulator, pick a phone preset, and confirm
    the touch controls appear and produce the same actions as the keyboard.
21. Set the graphics preset to Auto and confirm the ladder steps down under load
    and back up when it recovers.

**Admin**

22. With the allowlist empty, confirm the admin panel is unavailable and the
    startup log says so.
23. Add two real UserIds, restart, and confirm the panel opens, actions apply,
    and every action — including **denied** ones — appears in the audit log.

---

## Verification status

**Verified here (executed, results above)**

- All 112 Luau modules compile (`luau-compile`, 0 failures).
- Every `$path` in `default.project.json` exists.
- Every `require` across `src/` and `tests/` resolves to a real module.
- No server-only module is reachable from a replicated container.
- Static lints clean: registry dot-calls, undefined module roots.
- Every client-to-server remote declares an argument schema and a rate limit
  (asserted by `architecture_spec`).
- 174 assertions across 7 specs — 0 failures, 0 skipped.
- Boss encounter behaviour: Parallax damageability, phase bounds, absence clamps,
  defeat reachability and single reward distribution; Light Samurai threshold,
  single detonation, survivor auto-defeat, wipe handling and duplicate-event
  resistance.

**Not verified here (needs Roblox Studio)**

- Anything that requires the engine: rendering, physics, character movement,
  raycasts, DataStore round trips, remote delivery, touch input, audio playback.
- `rojo build` / `rojo serve`.
- Strict typechecking against the Roblox API.
- Every asset in [Assets outstanding](#assets-outstanding).

**Summary:** the architecture is consistent, the dependencies resolve, the
critical boss defects are fixed and covered by behavioural tests, and the world
is generated, populated and traversable. The project is ready for its first
Studio playtest. It is **not** yet a finished game: every model, animation and
sound is a placeholder, and not one frame of it has been run in the engine.

---

## Licence

MIT — see [LICENSE](LICENSE).
