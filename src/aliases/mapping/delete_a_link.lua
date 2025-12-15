-- need the current room, but we're lost
if not mapper.currentroom or not mapper.roomexists(mapper.currentroom) then
	mapper.echo("Don't know where we are at the moment.")
	return
end

-- make sure the dir is valid
local dir = mapper.anytolong(matches[2])
if not dir then
	mapper.echo(matches[2] .. " isn't a valid normal exit.")
	return
end

-- gone already?
if not getRoomExits(mapper.currentroom)[dir] then
	mapper.echo(dir .. " link doesn't exist already.")
end

-- locate the room on the other end, so we can unlink it from there as well if necessary
local otherroom
if getRoomExits(getRoomExits(mapper.currentroom)[dir])[mapper.ranytolong(dir)] then
	otherroom = getRoomExits(mapper.currentroom)[dir]
end

if mapper.setExit(mapper.currentroom, -1, dir) then
	if otherroom then
		if mapper.setExit(otherroom, -1, mapper.ranytolong(dir)) then
			mapper.echo(
				string.format("Deleted the %s exit from %s (%d).", dir, getRoomName(mapper.currentroom), mapper.currentroom)
			)
		else
			mapper.echo("Couldn't delete the incoming exit.")
		end
	else
		mapper.echo(
			string.format(
				"Deleted the one-way %s exit from %s (%d).",
				dir,
				getRoomName(mapper.currentroom),
				mapper.currentroom
			)
		)
	end
else
	mapper.echo("Couldn't delete the outgoing exit.")
end
centerview(mapper.currentroom)
