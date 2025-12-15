-- need the current room, but we're lost
if not mapper.currentroom or not mapper.roomexists(mapper.currentroom) then
	mapper.echo("Don't know where we are at the moment.")
	return
end

-- make sure the dir is valid
local dir = mapper.anytolong(matches[3])
if not dir then
	mapper.echo(matches[3] .. " isn't a valid normal exit.")
	return
end

-- if we don't give a room number, then we want to auto-locate an appropriate room nearby.
local otherroom
if matches[2] == "" then
	local w = matches[3]
	local ox, oy, oz, x, y, z = getRoomCoordinates(mapper.currentroom)
	local has = table.contains
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
	end

	local carea = getRoomArea(mapper.currentroom)
	if not carea then
		mapper.echo("Don't know what area are we in.")
		return
	end

	otherroom = select(2, next(getRoomsByPosition(carea, x, y, z)))

	if not otherroom then
		mapper.echo("There isn't a room to the " .. w .. " that I see - try with an exact room id.")
		return
	end
else
	if not mapper.roomexists(matches[2]) then -- check that an explicit other room ID is valid
		mapper.echo("A room with id " .. matches[2] .. " doesn't exist.")
		return
	else
		otherroom = tonumber(matches[2])
	end
end

if mapper.setExit(mapper.currentroom, otherroom, matches[3]) then
	if not matches[4] then
		mapper.setExit(otherroom, mapper.currentroom, mapper.ranytolong(matches[3]))
	end

	mapper.echo(
		string.format(
			"Linked %s (%d) to %s (%d) via a %s%s exit.",
			(getRoomName(mapper.currentroom) ~= "" and getRoomName(mapper.currentroom) or "''"),
			mapper.currentroom,
			(getRoomName(otherroom) ~= "" and getRoomName(otherroom) or "''"),
			otherroom,
			(matches[4] and "one-way " or ""),
			matches[3]
		)
	)
else
	mapper.echo("Couldn't create an exit.")
end
centerview(mapper.currentroom)
