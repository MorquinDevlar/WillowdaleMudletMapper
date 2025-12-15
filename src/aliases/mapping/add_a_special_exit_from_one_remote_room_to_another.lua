local room1, room2 = tonumber(matches[2]), tonumber(matches[3])

if not room1 or not mapper.roomexists(room1) then
	mapper.echo("Room #" .. matches[2] .. " doesn't exist - create it first, or make sure you got the room ID right?")
	return
end

if not room2 or not mapper.roomexists(room2) then
	mapper.echo("Room #" .. matches[3] .. " doesn't exist - create it first, or make sure you got the room ID right?")
	return
end

addSpecialExit(room1, room2, matches[4])
mapper.echo(
	string.format(
		"Added special exit with command '%s' to from %s (%d) to %s (%d).",
		matches[4],
		getRoomName(room1),
		room1,
		getRoomName(room2),
		room2
	)
)
