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

-- A map that has just arrived knows nothing of where this player is: Mudlet
-- keeps the player's room per profile name, and a downloaded map was saved
-- under another profile's. The room the game last sent is the one to show,
-- when the new map has it.
function mapper.centeronplayer()
	local basic = gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic
	if not basic then
		return
	end
	local roomId = mapper.gmcproomid(basic)
	if not roomId or not roomExists(roomId) then
		return
	end
	centerview(roomId)
	mapper.currentroom = roomId
	mapper.currentroomname = getRoomName(roomId) or basic.name or "(unknown)"
	updateMap()
end
