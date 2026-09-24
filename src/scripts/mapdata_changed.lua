-- Aggregates every way a different map can arrive into one event.
--
-- A new map means new rooms, so everything derived from the old one has to be
-- redone: the area name/id tables the mapper looks areas up in, the cached
-- paths, and the room locks, weights and characters that follow from the
-- mapper's own settings rather than from the map file.
--
-- Mudlet can raise more than one of these for the same map, one after another,
-- so the work waits for the end of the current round of events and is done
-- once for all of them.
local pending

function mapper.mapdata_changed()
	if pending then
		return
	end
	pending = tempTimer(0, function()
		pending = nil
		raiseEvent("mapper map reloaded")
		raiseEvent("mapper updated map")
	end)
end
