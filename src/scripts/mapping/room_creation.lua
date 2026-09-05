-- Room creation and coordinate calculation functions

-- The areas are looked up in the mapper's own table rather than asked of Mudlet:
-- this runs for every room the player walks into, and getAreaTable builds a
-- fresh table of every area on the map each time it is called. The table is
-- rebuilt whenever the areas change, including by the branch below.
function mapper.findOrCreateArea(areaName)
	if not areaName or areaName == "" then
		return nil
	end

	local known = mapper.areatable or {}
	if known[areaName] then
		return known[areaName]
	end
	local wanted = areaName:lower()
	for name, id in pairs(known) do
		if name:lower() == wanted then
			return id
		end
	end

	-- Create new area
	local newId = addAreaName(areaName)
	if newId then
		mapper.regenerateareas()
		raiseEvent("mapper areas changed")
		if mapper.settings and mapper.settings.showmappingmessages then
			mapper.notify("Created new area: " .. areaName)
		end
	end
	return newId
end

-- The area a room belongs to on the Mudlet map. GMCP names a room's place twice:
-- `area` is the server's zone (one piece of a map, e.g. "West Willowdale
-- Fields"), while `area_name` is the map that zone is part of (e.g. "Willowdale
-- Village"). Every zone of a map shares one coordinate space, so the map is what
-- a Mudlet area has to be - filing by zone would cut a single coordinate space
-- into several areas whose rooms then cannot be drawn next to each other.
function mapper.gmcpareaname()
	local basic = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic
	if not basic then
		return nil
	end
	local name = basic.area_name
	if not name or name == "" then
		-- Older servers, and zones with no map of their own, only send the zone.
		name = basic.area
	end
	if not name or name == "" then
		return nil
	end
	return name
end

-- A room reached through an exit is known only by the zone GMCP names on the
-- other side of it, and a zone is not necessarily the name of the map its rooms
-- are drawn on. So the zone is used as an area only when it already names one -
-- which is what happens for a zone that is a map of its own. Anything else waits
-- for the first visit, when GMCP reports the room's own area_name.
function mapper.exitareaid(zone)
	if not (mapper.settings and mapper.settings.autocreateareas) or not zone or zone == "" then
		return nil
	end
	return mapper.areatable and mapper.areatable[zone] or nil
end

-- Record what the game says about where a room lives. The Mudlet area carries
-- the map, so the zone is kept alongside it - it is the finer name the game uses
-- and nothing else on the map preserves it.
function mapper.storeroomorigin(roomId, areaName, zone)
	if areaName and areaName ~= "" and getRoomUserData(roomId, "Area") ~= areaName then
		setRoomUserData(roomId, "Area", areaName)
	end
	if zone and zone ~= "" and getRoomUserData(roomId, "Zone") ~= zone then
		setRoomUserData(roomId, "Zone", zone)
	end
end

function mapper.makeroom(oldid, newid, x, y, z, targetAreaId)
	assert(x and y and z, "makeroom: need all 3 coordinates")
	addRoom(newid)
	setRoomCoordinates(newid, x, y, z)
	-- Use target area if provided, otherwise inherit from old room
	if targetAreaId then
		setRoomArea(newid, targetAreaId)
	else
		setRoomArea(newid, getRoomArea(oldid))
	end
	local fgr, fgg, fgb = unpack(color_table.red)
	local bgr, bgg, bgb = unpack(color_table.blue)
	highlightRoom(newid, fgr, fgg, fgb, bgr, bgg, bgb, 1, 100, 100)
	-- The biome color in GMCP describes the room the player is standing in, so
	-- only that room may use it. Stub rooms created ahead of the player, from
	-- exits leading somewhere unvisited, stay in the muted unexplored color until
	-- they are entered and GMCP reports their own biome.
	local basic = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic
	local iscurrentroom = basic and tonumber(basic.id) == tonumber(newid)
	local envId
	if iscurrentroom and basic.biome_color then
		envId = mapper.getBiomeEnvId(basic.biome_color)
	elseif iscurrentroom then
		envId = mapper.defaultroomenv()
	end
	setRoomEnv(newid, envId or mapper.unexploredroomenv())
	return string.format("Created new room %d at %dx,%dy,%dz.", newid, x, y, z)
end
