-- Special exit handling and path fixing

function mapper.fixPath(rFrom, rTo, dashtype)
	local currentPath, currentIds = {}, {}
	local dRef = { ["n"] = "north", ["e"] = "east", ["s"] = "south", ["w"] = "west" }
	if not getPath(rFrom, rTo) then
		return false
	end
	-- Logic: Look for a direction repeated at least two times.
	-- count the number of times it repeats, then look that many rooms ahead.
	-- if that room also contains the direction we're headed, just travel that many directions.
	-- otherwise, dash.
	local repCount = 1
	local index = 1
	local dashExaust = false
	while mapper.speedWalkDir[index] do
		if not table.contains(getSpecialExits(mapper.speedWalkPath[index]), mapper.speedWalkDir[index]) then
			dashExaust = false
			repCount = 1
			while mapper.speedWalkDir[index + repCount] == mapper.speedWalkDir[index] do
				repCount = repCount + 1
				if repCount == 11 then
					dashExaust = true
					break
				end
			end
			if repCount > 1 then
				-- Found direction repetition. Calculate dash path.
				local exits = getRoomExits(mapper.speedWalkPath[index + (repCount - 1)])
				local pname = ""
				for word in mapper.speedWalkDir[index]:gmatch("%w") do
					pname = pname .. (dRef[word] or word)
				end
				if not exits[pname] or dashExaust then
					-- Final room in this direction does not continue, dash!
					table.insert(currentPath, string.format("%s %s", dashtype, mapper.speedWalkDir[index]))
					currentIds[#currentIds + 1] = mapper.speedWalkPath[index + repCount - 1]
				else
					-- Final room in this direction continues onwards, don't dash
					for i = 1, repCount do
						table.insert(currentPath, mapper.speedWalkDir[index])
						currentIds[#currentIds + 1] = mapper.speedWalkPath[index + i - 1]
					end
				end
				index = index + repCount
			else
				-- No repetition, just add the direction.
				table.insert(currentPath, mapper.speedWalkDir[index])
				currentIds[#currentIds + 1] = mapper.speedWalkPath[index]
				index = index + 1
			end
		else
			-- Special exit, skip over this step
			table.insert(currentPath, mapper.speedWalkDir[index])
			currentIds[#currentIds + 1] = mapper.speedWalkPath[index]
			index = index + 1
		end
	end
	mapper.speedWalkDir = currentPath
	mapper.speedWalkPath = currentIds
	return true
end

-- a certain version of the mapper gave us special exits prepended with 0 or 1 in the command
-- depending on if it was locked. Need to remove these before we can use them

function mapper.fixSpecialExits(directions)
	for i = 1, #directions do
		if directions[i]:match("^%d") then
			directions[i] = directions[i]:sub(2)
		end
	end
end

-- cleanup function to remove the temp special exit we made

function mapper.clearspecials(deleterooms)
	local t = getSpecialExits(mapper.currentroom)
	for connectingroom, exits in pairs(t) do
		if table.contains(deleterooms, connectingroom) then
			-- delete the special exits linking to this room
			for command, locked in pairs(exits) do
				removeSpecialExit(mapper.currentroom, command)
			end
		end
	end
end
