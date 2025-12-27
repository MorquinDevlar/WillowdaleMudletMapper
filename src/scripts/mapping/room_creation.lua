-- Room creation and coordinate calculation functions

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
	-- Use biome_color from GMCP if available
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.biome_color then
		local envId = mapper.getBiomeEnvId(gmcp.Room.Info.Basic.biome_color)
		if envId then
			setRoomEnv(newid, envId)
		else
			setRoomEnv(newid, getRoomEnv(oldid))
		end
	else
		setRoomEnv(newid, getRoomEnv(oldid))
	end
	return string.format("Created new room %d at %dx,%dy,%dz.", newid, x, y, z)
end

-- gives the reverse shifted coordinates, ie asking for the sw exit + coords will give the coords at ne

function mapper.getshiftedcoords(original, ox, oy, oz)
	local x, y, z
	local has = table.contains
	-- reverse the exit
	local w = mapper.ranytolong(original)
	if has({ "west", "left", "w", "l" }, w) then
		x = (x or ox) - 1
		y = (y or oy)
		z = (z or oz)
	elseif has({ "east", "right", "e", "r" }, w) then
		x = (x or ox) + 1
		y = (y or oy)
		z = (z or oz)
	elseif has({ "north", "top", "n", "t" }, w) then
		x = (x or ox)
		y = (y or oy) + 1
		z = (z or oz)
	elseif has({ "south", "bottom", "s", "b" }, w) then
		x = (x or ox)
		y = (y or oy) - 1
		z = (z or oz)
	elseif has({ "northwest", "topleft", "nw", "tl" }, w) then
		x = (x or ox) - 1
		y = (y or oy) + 1
		z = (z or oz)
	elseif has({ "northeast", "topright", "ne", "tr" }, w) then
		x = (x or ox) + 1
		y = (y or oy) + 1
		z = (z or oz)
	elseif has({ "southeast", "bottomright", "se", "br" }, w) then
		x = (x or ox) + 1
		y = (y or oy) - 1
		z = (z or oz)
	elseif has({ "southwest", "bottomleft", "sw", "bl" }, w) then
		x = (x or ox) - 1
		y = (y or oy) - 1
		z = (z or oz)
	elseif has({ "up", "u" }, w) then
		x = (x or ox)
		y = (y or oy)
		z = (z or oz) + 1
	elseif has({ "down", "d" }, w) then
		x = (x or ox)
		y = (y or oy)
		z = (z or oz) - 1
	elseif has({ "in", "i" }, w) then
		x = (x or ox)
		y = (y or oy)
		z = (z or oz) - 1
	elseif has({ "out", "o" }, w) then
		x = (x or ox)
		y = (y or oy)
		z = (z or oz) + 1
	else
		mapper.echo(
			"Don't know where to shift the coordinates for a " .. tostring(w) .. " (" .. tostring(original) .. ") exit."
		)
	end
	return x, y, z
end
