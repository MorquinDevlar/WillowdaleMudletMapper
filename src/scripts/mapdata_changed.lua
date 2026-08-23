-- Aggregates every way a different map can arrive into one event.
--
-- A new map means new rooms, so everything derived from the old one has to be
-- redone: the area name/id tables the mapper looks areas up in, the cached
-- paths, and the room locks that keep pathfinding out of areas the player
-- locked, which live in the mapper's own settings rather than in the map file.
function mapper.mapdata_changed()
	raiseEvent("mapper map reloaded")
	raiseEvent("mapper updated map")
end
