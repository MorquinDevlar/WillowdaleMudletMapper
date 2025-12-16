-- Door handling during speedwalking and GMCP updates

function mapper.openDoor()
	-- not going anywhere? don't do anything
	if not mapper.speedWalkDir[mapper.speedWalkCounter] then
		return
	end
	send("open door " .. mapper.speedWalkDir[mapper.speedWalkCounter], false)
	if mapper.settings.showcmds then
		cecho(
			string.format(
				"<red>(<maroon>%d - <dark_slate_grey>open door %s<red>)",
				#mapper.speedWalkDir - mapper.speedWalkCounter + 1,
				mapper.speedWalkDir[mapper.speedWalkCounter]
			)
		)
	end
	mapper.hasty = true
	local latency = getNetworkLatency() / 1000  -- Convert ms to seconds
	tempTimer(latency, function() mapper.move() end)
end

function mapper.unlockDoor()
	-- not going anywhere? don't do anything
	if not mapper.speedWalkDir[mapper.speedWalkCounter] then
		return
	end
	send("unlock door " .. mapper.speedWalkDir[mapper.speedWalkCounter], false)
	if mapper.settings.showcmds then
		cecho(
			string.format(
				"<red>(<maroon>%d - <dark_slate_grey>unlock door %s<red>)",
				#mapper.speedWalkDir - mapper.speedWalkCounter,
				mapper.speedWalkDir[mapper.speedWalkCounter]
			)
		)
	end
	mapper.hasty = true
	local latency = getNetworkLatency() / 1000  -- Convert ms to seconds
	tempTimer(latency, function() mapper.move() end)
end

-- Function to update door statuses based on current GMCP data
function mapper.updateDoorStatuses(roomNum)
	if not roomNum or not mapper.roomexists(roomNum) then
		return
	end

	-- Get current exits from GMCP
	local currentexits = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Exits or {}
	local doorStatus = getDoors(roomNum)
	local updated = false

	-- Check each exit for door status
	for exit, exitData in pairs(currentexits) do
		-- Skip if exitData is not a table (might be a function or other non-exit data)
		if type(exitData) == "table" then
			-- Convert to short form for setDoor (north -> n, east -> e, etc.)
			local shortExit = mapper.anytoshort(exit)

			-- Check if this exit has door details
			if exitData.details and exitData.details.type == "door" and exitData.details.state then
				local state = exitData.details.state

				if state == "closed" or state == "locked" then
					-- Should have a door
					local doorType = state == "locked" and 3 or 2 -- 3 = locked, 2 = closed
					if not doorStatus[shortExit] or doorStatus[shortExit] == 0 then
						-- No door exists, create one
						if mapper.settings.debug then
							mapper.echo("updateDoorStatuses: Creating " .. state .. " door on " .. exit .. " exit (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. roomNum)
						end
						setDoor(roomNum, shortExit, doorType)
						updated = true
					elseif doorStatus[shortExit] ~= doorType then
						-- Door exists but state changed (e.g., closed -> locked or locked -> closed)
						if mapper.settings.debug then
							mapper.echo("updateDoorStatuses: Updating door state on " .. exit .. " exit from " .. (doorStatus[shortExit] == 2 and "closed" or "locked") .. " to " .. state .. " in room " .. roomNum)
						end
						setDoor(roomNum, shortExit, doorType)
						updated = true
					end

					-- Lock the exit if door is closed or locked
					if mapper.settings.debug then
						mapper.echo("updateDoorStatuses: Locking exit " .. exit .. " in room " .. roomNum)
					end
					mapper.lockExit(roomNum, exit, true)

				elseif state == "open" then
					-- Exit is open - check if we need to update door state
					if doorStatus[shortExit] and doorStatus[shortExit] > 1 then
						-- Door exists and is closed/locked, update to open
						if mapper.settings.debug then
							mapper.echo("updateDoorStatuses: Opening door on " .. exit .. " exit (short: " .. shortExit .. ") in room " .. roomNum)
						end
						setDoor(roomNum, shortExit, 1) -- 1 = open door
						updated = true
					end

					-- Unlock the exit since door is open
					if mapper.hasExitLock(roomNum, exit) then
						if mapper.settings.debug then
							mapper.echo("updateDoorStatuses: Unlocking exit " .. exit .. " in room " .. roomNum)
						end
						mapper.lockExit(roomNum, exit, false)
					end
				end
			else
				-- No door details, ensure exit is unlocked
				if mapper.hasExitLock(roomNum, exit) then
					if mapper.settings.debug then
						mapper.echo("updateDoorStatuses: Unlocking exit " .. exit .. " (no door) in room " .. roomNum)
					end
					mapper.lockExit(roomNum, exit, false)
				end
			end
		end
	end

	-- Check for doors that should be removed (exit no longer exists)
	for exit, doorType in pairs(doorStatus) do
		if doorType > 0 then
			-- doorStatus uses short forms, currentexits uses long forms
			-- Need to check if this exit exists in any form
			local longExit = mapper.anytolong(exit)
			local found = false
			for gmcpExit, _ in pairs(currentexits) do
				if mapper.anytoshort(gmcpExit) == exit then
					found = true
					break
				end
			end
			if not found then
				if mapper.settings.debug then
					mapper.echo("updateDoorStatuses: Removing door from " .. exit .. " exit (exit no longer exists) in room " .. roomNum)
				end
				setDoor(roomNum, exit, 0) -- Remove door
				updated = true
			end
		end
	end

	return updated
end

-- Function to handle door updates whenever GMCP room info is received
function mapper.updatedoors()
	-- Only update doors if we have a valid current room
	if not mapper.currentroom or not mapper.roomexists(mapper.currentroom) then
		if mapper.settings.debug then
			mapper.echo("Door update skipped - no valid current room")
		end
		return
	end

	if mapper.settings.debug then
		mapper.echo("Checking doors for room " .. mapper.currentroom)
		-- Show current GMCP exit statuses
		local currentexits = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Exits or {}
		local exitInfo = {}
		for exit, exitData in pairs(currentexits) do
			if exitData.details and exitData.details.type == "door" then
				table.insert(exitInfo, string.format("%s:%s", exit, exitData.details.state or "none"))
			end
		end
		if #exitInfo > 0 then
			mapper.echo("GMCP door statuses: " .. table.concat(exitInfo, ", "))
		end
	end

	-- Update door statuses for the current room
	local updated = mapper.updateDoorStatuses(mapper.currentroom)

	-- Show a message if doors were updated (only in non-debug mode since debug already shows details)
	if updated and not mapper.settings.debug then
		mapper.echo("Door statuses updated for room " .. mapper.currentroom)
	end
end