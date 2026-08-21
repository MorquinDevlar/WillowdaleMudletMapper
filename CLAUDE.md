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

The mapper script is organized into several key modules:
- Core functionality in `/src/scripts/core/`
- Navigation features in `/src/scripts/navigation/`
- Mapping features in `/src/scripts/mapping/`
- Game-specific code in `/src/scripts/game_specific/`

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

There is no test suite and no luacheck config in this repo, so the one check
before calling work done is the build, run from the repo root:

```bash
muddle                      # builds build/WillowdaleMudletMapper.mpackage
```

That is also what proves the muddler substitution still lands: `__VERSION__`
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

## Recent Changes

### Simplified Option System
- Options are now defined in a simple table structure in `option_definitions.lua`
- Easy to add new options without complex function calls
- Supports all existing features (validation, onChange handlers, game-specific options)

### GMCP Structure Support
- Handles hierarchical GMCP room data (Info.Basic, Info.Exits, etc.)
- Automatic door creation and state tracking
- Coordinate system conversion for Y-axis inversion

### Package Installation Handler
- Automatically reloads mapper settings when package is reinstalled
- Listens to `sysInstallPackage` event
