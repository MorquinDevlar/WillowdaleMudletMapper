-- Room creation and coordinate calculation functions

-- An area's ID from the mapper's own tables, in whatever case the game gives
-- the name, or nil.
local function cachedareaid(areaName)
	local id = mapper.areatable and mapper.areatable[areaName]
	if id then
		return id
	end
	return mapper.areatablelower and mapper.areatablelower[areaName:lower()]
end

-- An area's ID from its name, in whatever case the game gives it. The areas
-- are looked up in the mapper's own tables rather than asked of Mudlet: this
-- runs for every room the player walks into, and getAreaTable builds a fresh
-- table of every area on the map each time it is called. The tables are rebuilt
-- whenever the mapper changes the areas, including by mapper.findOrCreateArea.
--
-- Mudlet can change them without telling the mapper, though: deleting the map
-- from the profile preferences raises no event, and nor does deleting or
-- renaming an area in the map window. An ID the tables keep for a name is then
-- refused by setRoomArea, and every room filed under it stays in the Default
-- Area. So a found ID is checked against the one area Mudlet has under it,
-- which is a single lookup; when the name there is not the one the tables have,
-- the tables are rebuilt and the name looked up again, and the rest of what the
-- mapper keeps about the map is redone as for any map it was not told about.
function mapper.areaidbyname(areaName)
	if not areaName or areaName == "" then
		return nil
	end
	local id = cachedareaid(areaName)
	if not id or getRoomAreaName(id) == mapper.areatabler[tonumber(id)] then
		return id
	end
	mapper.regenerateareas()
	if mapper.mapdata_changed then
		mapper.mapdata_changed()
	end
	return cachedareaid(areaName)
end

function mapper.findOrCreateArea(areaName)
	if not areaName or areaName == "" then
		return nil
	end

	local known = mapper.areaidbyname(areaName)
	if known then
		return known
	end

	-- Create new area
	local newId = addAreaName(areaName)
	if newId then
		mapper.regenerateareas()
		raiseEvent("mapper areas changed")
		if mapper.settings and mapper.settings.showmappingmessages then
			mapper.notify("Created new area: " .. areaName)
		end
		return newId
	end
	-- Mudlet refuses a name an area already has, so the likeliest reason is an
	-- area made where the mapper did not see it, in the map window or by
	-- another script. Only then are the areas read again: a name the tables
	-- miss is otherwise a new area, and reading them costs a table of them all.
	mapper.regenerateareas()
	return mapper.areaidbyname(areaName)
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
	if not (mapper.settings and mapper.settings.autocreateareas) then
		return nil
	end
	return mapper.areaidbyname(zone)
end

-- Room user data, written only where it differs from what the room carries.
-- `data` is the room's user data as getAllRoomUserData returned it, and is kept
-- in step with every write, so one read serves a whole arrival. A missing key
-- reads as "", the way getRoomUserData has it. Returns whether it wrote.
function mapper.setroomdata(id, data, key, value)
	if (data[key] or "") == value then
		return false
	end
	setRoomUserData(id, key, value)
	data[key] = value
	return true
end

function mapper.clearroomdata(id, data, key)
	if data[key] == nil then
		return false
	end
	clearRoomUserDataItem(id, key)
	data[key] = nil
	return true
end

-- Record what the game says about where a room lives. The Mudlet area carries
-- the map, so the zone is kept alongside it - it is the finer name the game uses
-- and nothing else on the map preserves it. Pass the room's user data when the
-- caller has it; a room created a moment ago has none, and passes {}.
function mapper.storeroomorigin(roomId, areaName, zone, data)
	data = data or getAllRoomUserData(roomId) or {}
	if areaName and areaName ~= "" then
		mapper.setroomdata(roomId, data, "Area", areaName)
	end
	if zone and zone ~= "" then
		mapper.setroomdata(roomId, data, "Zone", zone)
	end
end

-- The environment of the room GMCP describes: its biome colour, or the neutral
-- default when the game sent none.
function mapper.biomeenv(basic)
	local envId = basic and basic.biome_color and mapper.getBiomeEnvId(basic.biome_color)
	return envId or mapper.defaultroomenv()
end

-- Put a room in an area, and under whatever lock that area is under: a room
-- mapped into a locked area is as closed to walks as the rest of it, and one
-- moved out of one is open again. Which areas are locked is only known once
-- the settings are loaded.
function mapper.fileroom(id, areaId)
	setRoomArea(id, areaId)
	if not mapper.optionsloaded then
		mapper.deferroom(id)
		return
	end
	local lock = mapper.wantlocked(areaId)
	if roomLocked(id) ~= lock then
		lockRoom(id, lock)
	end
end

-- Every room the mapper makes is made here: added, placed, filed and coloured.
-- A room with no area to go in is left in the Default Area (-1), which is where
-- Mudlet puts a new room anyway and an area setRoomArea refuses.
function mapper.createroom(id, x, y, z, areaId, env)
	addRoom(id)
	setRoomCoordinates(id, x, y, z)
	if areaId and areaId ~= -1 then
		mapper.fileroom(id, areaId)
	end
	mapper.setroomenv(id, env)
end

-- A room seen through an exit of oldid, which it takes its area from unless it
-- is given one.
function mapper.makeroom(oldid, newid, x, y, z, targetAreaId)
	assert(x and y and z, "makeroom: need all 3 coordinates")
	-- The biome color in GMCP describes the room the player is standing in, so
	-- only that room may use it. Stub rooms created ahead of the player, from
	-- exits leading somewhere unvisited, stay in the muted unexplored color until
	-- they are entered and GMCP reports their own biome.
	local basic = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic
	local iscurrentroom = basic and tonumber(basic.id) == tonumber(newid)
	mapper.createroom(newid, x, y, z, targetAreaId or getRoomArea(oldid),
		iscurrentroom and mapper.biomeenv(basic) or mapper.unexploredroomenv())
	local fgr, fgg, fgb = unpack(color_table.red)
	local bgr, bgg, bgb = unpack(color_table.blue)
	highlightRoom(newid, fgr, fgg, fgb, bgr, bgg, bgb, 1, 100, 100)
	return string.format("Created new room %d at %dx,%dy,%dz.", newid, x, y, z)
end
