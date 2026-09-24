# MudletMapper Development Notes

## Important References

### Mudlet Mapper API Documentation
- **URL**: https://wiki.mudlet.org/w/Manual:Mapper_Functions
- **Purpose**: Complete reference for all Mudlet mapper functions
- **Note**: Always check this page when working with mapper functionality to ensure correct usage of:
  - Room manipulation functions (addRoom, setRoomCoordinates, etc.)
  - Exit handling (setExit, setDoor, getRoomExits, etc.)
  - Area management (setRoomArea, getRoomArea, etc.)
  - Pathfinding (getPath, speedwalk functions)
  - Special exits and room properties
  - Environment and terrain functions

## Project Structure

Four aliases in `src/aliases/aliases.json` (`mapper`, `mconfig`, `mstop`,
`showpath`) dispatch into `src/scripts/mapping/commands.lua`, which holds the
whole command tree. Everything else is scripts:

- `src/scripts/core/` - output (`api.lua`), the one directions table
  (`directions.lua`), settings and their file (`options.lua`), event bindings
  (`event_handlers.lua`), room-character rules (`utilities.lua`), colours
- `src/scripts/mapping/` - room creation and GMCP mapping
  (`room_gmcp_handler.lua`, `room_creation.lua`), exit and lock wrappers
  (`exit_functions.lua`), area locks, tags (`tags.lua`), terrain weights
  (`terrain.lua`), the command tree (`commands.lua`)
- `src/scripts/navigation/` - the room-arrival pipeline
  (`room_pipeline.lua`, one handler on `gmcp.Room.Info.Exits`), walking and
  its watchdog (`walking.lua`), path cache (`pathfinding.lua`), doors, move
  signals, destinations, the right-click map menu, map info line and starting
  zoom (`mapmenu.lua`)
- `src/scripts/game_specific/` - Willowdale environment ids and colours
- `src/scripts/updates/` - the self-updater

Commands are `mapper <verb>` only; no other alias is added. Rooms are placed
and moved from the coordinates the game sends, so there are no manual
room-editing commands. Updates are checked on connection and by `mapper
check`; there is no periodic check.

## Releases and self-update

PUBLISHING THE GITHUB RELEASE IS DEPLOYING - pushing main is not. The game
server subscribes to this repo's *release* events; when one is published it
downloads that release's two assets into its own `static/resources/mapper/`,
which is the ONLY place an installed client ever looks (see the autoupdater in
`src/scripts/updates/autoupdater.lua`, which reads exactly those two URLs).
There is no deploy-on-push, by design: a release is a deliberate act with a
deliberate payload, so an ordinary commit - or a mistaken one - can never reach
a player.

Consequently NOTHING GENERATED IS COMMITTED. `build/` and `releases/` are both
gitignored; `tools/release.sh X.Y.Z` builds the package, generates the feed
into a temp file, and uploads both as release assets. A generated file in git
is a generated file someone can ship by mistake.

The tag format `vX.Y.Z` and the two ASSET BASENAMES are a contract with the
server's release handler, which looks assets up by name:

- `WillowdaleMudletMapper.mpackage` - the package itself;
- `releases.json` - the update feed.

A release published with only one of them deploys a package no feed announces,
or a feed pointing at a package that never arrived.

`CHANGELOG.md` is the source of truth for release notes. Entries land under
`## Unreleased` in the same commit as the change they describe;
`tools/changelog_to_releases.lua` turns the file into the `releases.json`
players read, so the notes in the repo and the notes a player is shown cannot
drift apart. NEVER hand-edit `releases.json` - it is generated, and it was
converted from the old hand-maintained feed without losing an entry.

Only `mfile` carries the version: muddler substitutes `__VERSION__` into
`mapper.version` at build time, so there is no second constant to keep in step.
`tools/release.sh` is the ONLY way a release is cut - never bump, tag, or
publish by hand. An empty `## Unreleased` is a hard stop, as is a feed whose
newest entry is not the version being cut, and any failure from the bump
onwards restores the tree.

Note on old tags: `v.2.0.0` through `v2.0.3` are from 2025, when this package
numbered its versions differently; the live line has been 1.4.x since. They are
vestigial and harmless - the server keys on a published release's assets, never
on tag ordering - but do not read them as "the latest version".

## Verification

There is no test suite and no luacheck config in this repo, so the checks
before calling work done are a parse of every Lua file and the build, both run
from the repo root:

```bash
luac5.1 -p src/scripts/*.lua src/scripts/*/*.lua tools/*.lua
muddle                      # builds build/WillowdaleMudletMapper.mpackage
```

The build does not cover the parse: muddler packages the Lua without parsing
it, and reports "Build completed successfully!" for a file with a syntax error.
`luac5.1` parses the Lua version Mudlet embeds, so syntax from a later Lua,
such as `goto` or `//`, fails the parse as well.

The build is what proves the muddler substitution still lands: `__VERSION__`
becomes `mapper.version` at build time, so a package that builds is a package
whose version is real. The build cannot validate Qt rendering, live GMCP
framing, or the mapper against a real map - flag when a change needs testing
against the running game.

## Committing

A change a player would notice gets a `## Unreleased` entry in `CHANGELOG.md`
IN THE SAME COMMIT. That file is what the update feed is generated from, so a
change committed without its note is a change no player is ever told about -
and the notes for a release then have to be reconstructed from the git log,
which is exactly what this avoids.

Never commit `build/` or `releases/`. Both are gitignored; `tools/release.sh`
uploads them as release assets instead. A release commit therefore touches only
`mfile` and `CHANGELOG.md`, and the script makes it - do not hand-craft one.

Commit message best practices:
- Always write in the past tense
- Always compare to the previous commit or branch
- Never write up fixes for things that you broke yourself inside the same commit
- If possible, add these sections to the commit message: Added, Fixed, Changed, Removed

## Developing with agents

- The main session plans, designs and reviews, whatever model it runs on
  (Fable 5.1 by default). Code is written by the `implementer` agent
  (`.claude/agents/implementer.md`, `model: opus`, effort `xhigh`), started
  with the Agent tool and a self-contained brief: the agreed plan, the files
  involved, the rules of this file that bear on it, and what done means. The
  agent does not see the conversation.
- Exceptions the main session does itself: trivial edits (a few lines, a
  config or data tweak, a doc fix), and reading, planning and review of any
  size. A main session that itself runs Opus may write the code directly,
  since the code is Opus's either way.
- The main session reviews the agent's change before anything is reported
  done, stages by explicit path and commits it; the agent never commits,
  stages, pushes or deploys.

## Notes verified from source

- The server sends `Room.Info.Basic` then `Room.Info.Exits` per room change,
  and `Room.Info.Exits` alone when a door or lock changes. Mudlet raises one
  event per level of a GMCP key, so a handler on `gmcp.Room.Info` runs once per
  message; the mapper therefore hangs everything off `gmcp.Room.Info.Exits`.
- Mudlet's `setDoor`, `getDoors` and exit weights key directions as `n`, `ne`,
  `e`, `se`, `s`, `sw`, `w`, `nw`, `up`, `down`, `in`, `out`; `mapper.dirdoor`
  gives that spelling. `getAreaRooms` is 0-indexed; use `getAreaRooms1`.
- `getNetworkLatency()` returns seconds. `setExitStub` raises on a missing
  room. A map-info callback returning nil for its colour gets Mudlet's own
  adaptive one.
- Mudlet keeps a 2D zoom per area, saved in the map file (default 20, minimum
  3), and raises `sysMapAreaChanged` from the 2D map on every area switch,
  including the first area shown after a load; `getMapZoom(areaId)` and
  `setMapZoom(zoom, areaId)` read and set an area's zoom.
- Local checkouts for checking such things: the server at
  `/Users/jens/mud/WillowdaleMUD` (`modules/gmcp/gmcp.Room.go`,
  `internal/usercommands/movesignals.go`) and Mudlet at
  `/Users/jens/mud/Mudlet/src` (`TLuaInterpreterMapper.cpp`).
