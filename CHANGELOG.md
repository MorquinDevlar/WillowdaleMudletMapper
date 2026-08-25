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

## 1.5.0 - 2026-08-25

- Changed the `showbiomesymbols` setting to `roomchar`, taking `all`, `biome`, `poi` or `none` in place of the old `off`
- Changed `showpath` to name rooms the way the game does instead of shouting them in capitals
- Changed `goto` to name the room it walks to, rather than showing only its ID
- Fixed room characters being drawn in rooms already on the map regardless of the setting, where POI characters showed even with characters turned off
- Added the accepted values to the message a setting prints when it is given a value it doesn't take
- Removed the `mpp` pause command, which came from the IRE mapper this one was forked from and paused a speedwalk mid-route
- Fixed settings and area locks being lost on `mapper reload`, on an update, and on any exit that wasn't a clean one; both are now written out as they change rather than only when Mudlet closes
- Fixed restored settings not taking effect until the option was set again, so a saved room character mode now shows on the map at once; the mapper says `Applying existing settings...` once while it does, in place of the reload and reinstall lines that used to claim the same thing twice more afterwards

## 1.4.4 - 2026-08-23

- Added `mconfig` to the command list `mapper` prints, so the settings command can be found without knowing its name beforehand
- Added `mconfig help`, which shows the same help as `mapper config help`
- Fixed the mapper routing around doors you hold the key to or know the combination of; a locked door only keeps a path out now when you actually cannot open it
- Fixed doors being drawn a visit late, so a door shows on the map the first time its room is mapped
- Fixed a special exit keeping the first destination it was ever seen to lead to, so an exit that now goes somewhere else is re-pointed instead
- Fixed a path being reused after a door had changed, which could send a speedwalk at a door that had since locked
- Fixed area locks being lost, and the area list going stale, after loading a different map
- Fixed room names losing a trailing period, and losing an opening "The ruins of", to a naming rule that belonged to another game
- Removed the `who b` and `fr` commands, which came from the IRE mapper and errored when used
- Added a route around a door that turns out to be locked mid-walk, and around an exit the map has that the room does not, instead of the walk simply stopping
- Added the reason a walk stopped, so being in combat, held, or turned back by the room each say so rather than all reading the same
- Added a note when a way onward takes a few seconds, so a walk that is waiting no longer looks like one that has hung

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
