local m = matches[2]
if m:starts("feature") then
	-- another alias was meant.
	return
end
local rid, rname
if mapper.roomexists(mapper.currentroom) then
	rid, rname = mapper.currentroom, mapper.currentroomname
end
local x, y, z

local function set(newid)
	-- small func to set things
	local rid = newid or createRoomID()
	addRoom(rid)
	setRoomCoordinates(rid, x, y, z)
	if mapper.roomexists(mapper.currentroom) then
		setRoomArea(rid, getRoomArea(mapper.currentroom))
	end
	setRoomEnv(rid, mapper.unexploredroomenv())
	mapper.setExit(mapper.currentroom, rid, m)
	mapper.echo(string.format("Created new room (%d) at %dx, %dy, %dz.\n", rid, x, y, z))
	centerview(mapper.roomexists(mapper.currentroom) and mapper.currentroom or rid)
	if not mapper.roomexists(mapper.currentroom) then
		mapper.currentroom = rid
		mapper.currentroomname = ""
	end
end

-- let's be flexible and allow several ways if giving an arg
-- rc v# x y z
newid, x, y, z = string.match(m, "v(%d+) (%-?%d+) (%-?%d+) (%-?%d+)")
if x then
	set(newid)
	return
end
-- rc x y z
x, y, z = string.match(m, "(%-?%d+) (%-?%d+) (%-?%d+)")
if x then
	set()
	return
end
if not rid then
	mapper.echo("Don't know where we are at the moment in order to use relative coordinates.")
	return
end
-- rc xx? yy? zz?
x, y, z = string.match(m, "(%-?%d+)x"), string.match(m, "(%-?%d+)y"), string.match(m, "(%-?%d+)z")
if x or y or z then
	-- merge w/ old coords if any are missing
	local ox, oy, oz = getRoomCoordinates(rid)
	x = x or ox
	y = y or oy
	z = z or oz
	set()
	return
end
-- rc left/west, right/east, ...
local ox, oy, oz = getRoomCoordinates(rid)
local has = table.contains
for w in string.gmatch(m, "%a+") do
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
end
if x then
	set()
	return
end
mapper.echo([[Where do you want to move the room to?
  You can use direct coordinates or relative directions.]])
