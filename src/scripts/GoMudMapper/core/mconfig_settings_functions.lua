function mmp.doLock(what, lock, filter)
	if what then
		mmp.echo(string.format("%s all %s...", (lock and "Locking" or "Unlocking"), what))
	end
	local c = 0

	local getAreaRooms, getSpecialExits, lockSpecialExit, next = getAreaRooms, getSpecialExits, lockSpecialExit, next
	for _, area in pairs(getAreaTable()) do
		local rooms = getAreaRooms(area) or {}
		for i = 0, #rooms do
			local exits = getSpecialExits(rooms[i] or 0)

			if exits and next(exits) then
				for exit, cmd in pairs(exits) do
					if type(cmd) == "table" then
						cmd = next(cmd)
					end

					if (not filter) or (filter and cmd:lower():find(filter, 1, true)) then
						lockSpecialExit(rooms[i], exit, cmd, lock)
						c = c + 1
					end
				end
			end
		end
	end

	if what then
		mmp.echo(string.format("%s %s known %s.", (lock and "Locked" or "Unlocked"), c, what))
	end
	return c
end

function mmp.changeEchoColour()
	mmp.echo("Now displaying echos in <" .. mmp.settings.echocolour .. ">" .. mmp.settings.echocolour)
end


-- GoMud-specific settings functions can be added here
