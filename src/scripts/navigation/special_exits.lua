-- Special exit handling

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
