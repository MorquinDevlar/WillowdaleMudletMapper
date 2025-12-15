-- want the current room, but we're lost
if not matches[2] and (not mapper.currentroom or not mapper.roomexists(mapper.currentroom)) then
	mapper.echo("Don't know where we are at the moment.")
	return
end

-- want another room, but it doesn't exist
if matches[2] and tonumber(matches[2]) and not mapper.roomexists(matches[2]) then
	mapper.echo("v" .. matches[2] .. " doesn't exist.")
	return
end

-- or a relative one
if matches[2] and not tonumber(matches[2]) and not mapper.relativeroom(mapper.currentroom, matches[2]) then
	mapper.echo("There is no room " .. matches[2] .. " of us.")
	return
end

local rid = (
	not matches[2] and mapper.currentroom or (tonumber(matches[2]) or mapper.relativeroom(mapper.currentroom, matches[2]))
)

clearSpecialExits(rid)
mapper.echo(string.format("Cleared all special exits in %s (%d).\n", getRoomName(rid), rid))
