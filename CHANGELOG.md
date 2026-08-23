# Changelog

Only what a player notices: commands, settings, and the things that go wrong
for them. Development tooling and internal refactors are not listed here.

An entry is written under `## Unreleased` in the same commit as the change it
describes, so the notes for a release already exist when the release is cut.
`tools/release.sh X.Y.Z` promotes `## Unreleased` to `## X.Y.Z - YYYY-MM-DD`
and leaves a fresh empty one behind.

This file is the SOURCE for the update feed players read:
`tools/changelog_to_releases.lua` turns it into the `releases.json` that
`tools/release.sh` uploads as a release asset. Never hand-edit that feed - it
is generated, and the next release overwrites it.

## Unreleased

- Added `mconfig` to the command list `mapper` prints, so the settings command can be found without knowing its name beforehand
- Added `mconfig help`, which shows the same help as `mapper config help`

## 1.4.3 - 2026-08-23

- Changed areas to be named after the area the game reports a room is in, rather than the zone it sits in, so the zones of one area are mapped together instead of being split into an area each
- Changed rooms mapped ahead of you, from an exit alone, to move into their real area the first time you enter them
- Removed Mudlet's own "Default Area" from the area listings of `mapper area list` and `arealock`; it is a work area of the map editor, not one you map into

## 1.4.2 - 2026-08-21

- Changed unexplored rooms to be drawn in a muted dark red instead of the color of the room they were seen from; a room gets its real biome color when you enter it

## 1.4.1 - 2026-02-05

- Fixed update server URL

## 1.4.0 - 2026-02-05

- Added showpath command with path highlighting and clear option
- Added dynamic path updates while walking manually
- Fixed walkdelay=0 not working (was defaulting to 0.3)

## 1.3.1 - 2026-01-18

- Added exit lock/unlock commands (mapper lock/unlock)
- Added mapper goto/find/look/check/update commands
- Changed showbiomesymbols to multi-value option (all/poi/biome/off)
- Fixed locked area navigation message

## 1.3.0 - 2026-01-13

- Added automatic generic_mapper handling (removes on install, restores on uninstall)
- Added showmappingmessages setting (mapping is silent by default)
- Fixed biome colors not appearing on first room creation
- Fixed room creation when entering new areas via special exits

## 1.2.0 - 2026-01-11

- Added unified command system (mapper, mapper area, mapper config)
- Added speedwalk path highlighting on map
- Added biome symbols for shops, inns, and post offices
- Added first room creation for empty maps

## 1.1.1 - 2025-12-30

- Fixed biome colors using GMCP color data

## 1.1.0 - 2025-12-28

- Fixed update checker version comparison for multi-digit versions

## 1.0.6 - 2025-12-28

- Added update check status messages on login

## 1.0.5 - 2025-12-27

- Fixed mconfig display formatting for long option values

## 1.0.4 - 2025-12-27

- Internal code cleanup and optimizations

## 1.0.3 - 2025-12-27

- Fixed update server URL

## 1.0.2 - 2025-12-27

- Speedwalking now runs at maximum speed by default
- Auto-create areas enabled by default

## 1.0.1 - 2025-01-15

- Fixed speedwalking door handling
- Added new biome colors
