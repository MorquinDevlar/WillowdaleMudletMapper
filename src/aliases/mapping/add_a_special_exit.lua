-- spe clear and spe list match on this
if matches[2] == "clear" or matches[2] == "list" then
	return
end

-- need the current room, but we're lost
if not mapper.currentroom or not mapper.roomexists(mapper.currentroom) then
	mapper.echo("Don't know where we are at the moment.")
	return
end

local otherroom = tonumber(matches[2]) or mapper.relativeroom(mapper.currentroom, matches[2])

-- need the another room, but it doesn't actually exist
if not otherroom or not mapper.roomexists(otherroom) then
	mapper.echo(matches[2] .. " doesn't exist.")
	return
end

addSpecialExit(mapper.currentroom, tonumber(otherroom), matches[3])
addSpecialExit(mapper.currentroom, tonumber(otherroom), matches[3])
mapper.echo(
	string.format("Added special exit with command '%s' to %s (%d).", matches[3], getRoomName(otherroom), otherroom)
)
centerview(mapper.currentroom)
