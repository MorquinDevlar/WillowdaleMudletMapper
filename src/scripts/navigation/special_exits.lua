-- Special exit handling

-- List all special exits, optionally filtered by command
function mapper.listSpecialExits(filter)
	local c = 0
	mapper.echo("Listing special exits...")
	for area, areaname in pairs(mapper.areatabler or {}) do
		local rooms = getAreaRooms(area) or {}
		for i = 0, #rooms do
			local exits = getSpecialExits(rooms[i] or 0)
			if exits and next(exits) then
				for exit, cmd in pairs(exits) do
					if type(cmd) == "table" then
						cmd = next(cmd)
					end
					if cmd and cmd:match("^%d") then
						cmd = cmd:sub(2)
					end
					if not filter or (cmd and cmd:lower():find(filter, 1, true)) then
						if getRoomArea(exit) ~= area then
							cecho(
								string.format(
									"<dark_slate_grey>%s <LightSlateGray>(%d, in %s)<dark_slate_grey> <MediumSlateBlue>-> <coral>%s -<MediumSlateBlue>><dark_slate_grey> %s <LightSlateGray>(%d, in %s)\n",
									getRoomName(rooms[i]),
									rooms[i],
									areaname,
									cmd,
									getRoomName(exit),
									exit,
									(mapper.areatabler and mapper.areatabler[getRoomArea(exit)]) or "?"
								)
							)
						else
							cecho(
								string.format(
									"<dark_slate_grey>%s <LightSlateGray>(%d)<dark_slate_grey> <MediumSlateBlue>-> <coral>%s <MediumSlateBlue>-><dark_slate_grey> %s <LightSlateGray>(%d)<dark_slate_grey> in %s\n",
									getRoomName(rooms[i]),
									rooms[i],
									cmd,
									getRoomName(exit),
									exit,
									areaname
								)
							)
						end
						c = c + 1
					end
				end
			end
		end
	end
	mapper.echo(string.format("%d exits listed%s.", c, (not filter and "" or ", with the filter '" .. filter .. "'")))
end

-- Delete special exits matching a filter
function mapper.delSpecialExits(filter)
	local c = 0
	for area, areaname in pairs(mapper.areatabler or {}) do
		local rooms = getAreaRooms(area) or {}
		for i = 0, #rooms do
			local exits = getSpecialExits(rooms[i] or 0)
			if exits and next(exits) then
				for exit, cmd in pairs(exits) do
					if type(cmd) == "table" then
						cmd = next(cmd)
					end
					if cmd and cmd:match("^%d") then
						cmd = cmd:sub(2)
					end
					if not filter or (cmd and cmd:lower():find(filter, 1, true)) then
						local originalExits = {}
						local e = getSpecialExits(rooms[i])
						for t, n in pairs(e) do
							local rid = tonumber(t)
							local action
							for a, l in pairs(n) do
								action = tostring(a)
							end
							if action and not action:find(filter, 1, true) then
								originalExits[rid] = action
							end
						end
						clearSpecialExits(rooms[i])
						for rid, act in pairs(originalExits) do
							addSpecialExit(rooms[i], tonumber(rid), tostring(act))
						end
						c = c + 1
					end
				end
			end
		end
	end
	mapper.echo(string.format("%d exits deleted%s.", c, (not filter and "" or ", with the filter '" .. filter .. "'")))
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
