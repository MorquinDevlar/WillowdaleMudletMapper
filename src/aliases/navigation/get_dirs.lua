-- matches[2] is the argument (can be: clear, or room_id, or "from_room to_room")
local arg = matches[2]

if not arg or arg == "" then
	-- No argument: show usage
	mapper.echo("Usage: showpath <room id> - Show directions and highlight path")
	mapper.echo("       showpath <from> <to> - Show directions between rooms")
	mapper.echo("       showpath clear - Clear path highlight from map")
	return
end

-- Check for clear command
if arg == "clear" then
	mapper.clearShowPath()
	mapper.echo("Path highlight cleared.")
	return
end

-- Parse room IDs
local parts = {}
for word in arg:gmatch("%S+") do
	parts[#parts + 1] = word
end

if #parts == 1 then
	-- Single room ID: show path from current room
	local to = tonumber(parts[1])
	if not to then
		mapper.echo("Invalid room ID: " .. parts[1])
		return
	end
	if not mapper.currentroom or not roomExists(mapper.currentroom) then
		mapper.echo("You need to be in a mapped room first.")
		return
	end
	mapper.echoPath(mapper.currentroom, to)
elseif #parts >= 2 then
	-- Two room IDs: show path between them
	local from = tonumber(parts[1])
	local to = tonumber(parts[2])
	if not from then
		mapper.echo("Invalid from room ID: " .. parts[1])
		return
	end
	if not to then
		mapper.echo("Invalid to room ID: " .. parts[2])
		return
	end
	mapper.echoPath(from, to)
end
