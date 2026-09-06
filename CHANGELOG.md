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

## 1.6.2 - 2026-09-06

- Changed the zoom an area is first shown at from Mudlet's 20 to 10, so the map starts closer in; an area you have zoomed yourself keeps the zoom you gave it, as before

## 1.6.1 - 2026-09-05

- Fixed the mapper leaving `Applying existing settings...` as its last line after an update and on connecting, with nothing to say it had finished; it now says `Settings restored.` once they are

## 1.6.0 - 2026-09-05

- Added room tags, which are words you put on rooms to find your way back to them: `mapper tag <name> [room]` tags a room, `mapper untag <name> [room]` takes the tag off, `mapper tags` lists every tag with how many rooms carry it, `mapper tags <name>` lists those rooms, and `mapper goto <name>` walks to the nearest one
- Added `mapper tag <name> symbol <char>`, which draws that character on every room carrying the tag, and `mapper tag <name> symbol none` to take it off again; a room with a tag symbol shows it in place of its biome symbol
- Added a "Willowdale mapper" submenu to the map's right-click menu, with Walk here, Show path here, Look at room, Lock this area, Unlock this area and Tag this room, which applies the tag you named last; while a path is highlighted the Show path here entry reads Clear path and takes the highlight off
- Added a line of the mapper's own over the map: the zone, biome and tags of the room you are in, whether its area is locked, and which step of the way you are on while walking. It can be turned off in the map's own Info menu
- Added the `walktimeout` setting: a move the game never answers is sent again after that many seconds instead of leaving the walk waiting forever, and the walk is given up on if the second try goes unanswered too
- Added `mapper terrain`, which lists every kind of ground the game names and what crossing one room of it costs a walk; `mapper terrain <biome> <weight>` makes that ground dearer, from 1 to 50, so walks go round it when a shorter way exists, and `mapper terrain <biome> clear` or `mapper terrain clear` takes the weights off again. Nothing is weighted until you weight it - the game puts no cost on any ground of its own
- Added the `safewalk` setting, which keeps walks on roads, paths, inns and post offices, the ground the game marks safe from hostile mobs, by making every other room cost more to cross; `safewalkcost` is how many safe rooms one room off safe ground is worth to a walk, and is 5 to begin with
- Added unexplored exit markers where the game reports a way out of a room but will not say what is on the other side, which used to be drawn as no exit at all
- Fixed a room lock not being seen by routes worked out earlier, which could keep `goto` walking into a room that had just been locked - `mapper area lock`, `mapper lock`, `mapper unlock` and locking a room from Mudlet's own map menu are all noticed now
- Fixed `goto` remembering that it could not reach somewhere, so it went on refusing the trip after the door in the way had opened
- Fixed `mapper goto <area name>` erroring instead of walking there
- Fixed doors on `up`, `down`, `in` and `out` exits never being drawn on the map, and those exits never being routed around when the door was shut to you
- Fixed `mapper lock` and `mapper unlock` reporting that the room had no exit that way, whichever way you named
- Fixed `showcmds`, `autoclear`, `debug` and `showmappingmessages` printing no confirmation when changed on a fresh install
- Fixed a walk stopping when the game reported that a move already underway had not landed yet; it now waits for the room change
- Fixed `mmap`, now `mapper view`, reporting that a one-room area has no rooms in it
- Fixed the balance poll continuing after `mstop`, and a fresh one starting on every blocked move
- Fixed `mapper look` not showing the weight set on an `up`, `down`, `in` or `out` exit
- Fixed a room mapped from an exit alone being placed on the wrong side of the room it was seen from, which drew it back the way you came instead of ahead of you; this happened when `autopositionrooms` was off, or when the game sent no coordinates for that exit
- Fixed the mapper throwing away every route it had worked out when a room only changed its name, colour or symbol, which made each step of a walk through rooms being mapped for the first time recalculate the way onward
- Fixed `mapper rooms` listing one of an area's rooms out of order
- Fixed the previous version's room handlers staying active after an update until Mudlet was restarted, which sent every step of a walk twice and left the game complaining about commands like `ee`
- Fixed a `resetStopWatch` error that could stop the first walk after the mapper was installed or updated before it began
- Changed `mapper look` to list a room's tags where it listed its map features
- Changed `mapper stop` to stop walking; mapping is switched with `mapper on` and `mapper off`
- Changed `showpath`, `mmap`, `room list`, `mdg`/`mdebug` and `map delete all` into `mapper path`, `mapper view`, `mapper rooms`, `mapper debug` and `mapper reset`; `showpath`, `mstop` and `mconfig` remain as shorthands
- Changed the two-room form of `showpath` to take the destination first, as `mapper path <to> <from>`, so the room you name first is the same one in both forms
- Changed `mapper` to list every command the mapper has, with its arguments and what it does
- Changed every listing the mapper prints - the help, `mapper config`, `mapper area list`, `mapper area labels`, `mapper tags`, `mapper terrain`, `mapper find`, `mapper rooms`, `mapper look` and the clickable area lock list - to one set of columns: titles ending in a colon over a grey rule, the first column green, the second white and the rest grey, at most a hundred characters wide, with a description too long for its column carried onto the line below it
- Removed the manual room-editing commands `rlc`/`room create`, `rlk`/`room link`, `urlk`/`room unlink`, `rld`/`room delete`, `rc`/`room coords`, `room area`, `rcc` and `rd`; the game sends every room's coordinates, area and doors over GMCP, so the map places and moves itself
- Removed the special-exit commands `spe`, `spev`, `spe clear`, `spe list` and `spe delete all`; special exits are created and re-pointed from GMCP as you walk
- Removed the exit and room weight commands `rw` and `rwe`
- Removed the `map save` and `map load` commands
- Removed the `smallmap`, `bigmap` and `biggestmap` commands
- Removed `delete known stockrooms`, `delete suffixed periods`, `find single exits` and `show char marks`, which cleaned up after a game this mapper does not serve
- Removed the feature and mark commands `feature create`, `feature list`, `feature delete`, `feature migrate`, `rcf`, `rdf`, `room mark`, `room unmark`, `room marks` and `mapper goto feature <name>`; the features and marks your map already carries become tags the first time this version loads, and `mapper tags` lists them
- Removed the `getpath` timing command
- Removed the hourly update check; the mapper still looks for an update when you connect, and `mapper check` asks at any time
- Removed the clear-all-labels links from `mapper look`, which deleted every label in an area or on the whole map in one click; `mapper area labels` deletes them one at a time
- Removed the colour names `mapper label` used to accept, so the whole of what you type is the label text
- Removed `mapper area add`, `mapper area delete` and `mapper area rename`; areas come from the game as you explore

## 1.5.2 - 2026-08-26

- Fixed the two `attempt to index field 'settings'` errors printed when a profile opened, which came from the map being loaded before the mapper's settings existed

## 1.5.1 - 2026-08-26

- Changed the speedwalk path highlight to move along a room at a time as you walk, in place of being wiped off the whole map and drawn again in every room, which drops a search across every room you have mapped out of each step and makes a long walk with `showspeedwalkpath` on markedly lighter
- Changed walking with a `showpath` destination set to stop redrawing the whole map in every room
- Fixed the `showpath` highlight freezing when you walk into a room being mapped for the first time; the path now recalculates once the new room's exits are on the map
- Fixed the cleanup of path highlights left over from a session that ended mid-walk, which had been clearing the borders of the lowest-numbered rooms on the map instead of the leftover ones
- Changed `mdg`/`mdebug` to switch the same `debug` setting as `mapper option debug`, so the performance timings it gated separately now print alongside the other debug messages and the choice survives a restart
- Fixed every walk through a room with a special exit rebuilding the pathfinding data and marking the map as changed, which made the next `goto` slower to start than it needed to be
- Fixed a special exit locking or unlocking not being seen by paths computed earlier, which could keep a speedwalk routed through a way that had just shut
- Changed the `Mapper: ` prefix to appear only on messages that arrive on their own - a walk reporting in, a room being mapped, an update being available - so an answer to a command you typed prints without it
- Changed long mapper messages to be wrapped by the mapper rather than by Mudlet, so the rest of a wrapped line lines up under the text it belongs to instead of restarting at the left edge, and a message of several lines carries the prefix on its first line instead of on all of them
- Changed the update notice to list every release you have not got yet, each under its own version heading, in place of the newest release's notes alone

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
