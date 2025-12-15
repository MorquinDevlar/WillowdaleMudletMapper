local room = matches[3] or mapper.currentroom
room = tonumber(room) or mapper.relativeroom(mapper.currentroom, room)
if not room or not mapper.roomexists(room) then
	mapper.echo(
		"Sorry - which room do you want to put this character in? I don't know where you are at the moment, if you want to do the current room."
	)
	return
end

local char = matches[2]

if char == "clear" then
	setRoomChar(room, " ")
	mapper.echo("Cleared the character from " .. room .. " (" .. getRoomName(room) .. ")")
else
	setRoomChar(room, char)
	mapper.echo("Set the " .. char:sub(1, 1) .. " character on " .. room .. " (" .. getRoomName(room) .. ")")
end
centerview(mapper.currentroom)
