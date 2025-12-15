mapper.echo("Deleting all known stockroom exits (rooms with $ and a down exit)")
local c = 0

for area, areaname in pairs(mapper.areatabler) do
	local rooms = getAreaRooms(area) or {}
	for i = 0, #rooms do
		if rooms[i] then
			local char = getRoomChar(rooms[i])
			if char == "$" then
				local exits = getRoomExits(rooms[i]) -- retrieve after $, more efficient

				if exits.down then
					mapper.setExit(rooms[i], -1, "down")
					mapper.echo(
						string.format(
							"Deleted the stockroom exit at %s (#%d in %s)",
							getRoomName(rooms[i]),
							rooms[i],
							mapper.areatabler[getRoomArea(rooms[i])]
						)
					)
					c = c + 1
				end
			end
		end
	end
end

mapper.echo(string.format("Deleted %s known stockroom exit%s.", c, (c ~= 1 and "s" or "")))
centerview(mapper.currentroom)
