function mapper.gotoRoom(where, dashtype, gotoType)
	mapper.speedWalk.type = gotoType or "room"
	if not where or not tonumber(where) then
		mapper.echo("Where do you want to go to?")
		return
	end
	if tonumber(where) == mapper.currentroom then
		mapper.echo("We're already at " .. where .. "!")
		raiseEvent("mmapper arrived")
		return
	end
	-- allow mapper 'addons' to link their own exits in
	raiseEvent("mmp link externals")
	-- if getPath worked, then the dirs and room #'s tables were populated for us
	if not mapper.getPath(mapper.currentroom, tonumber(where)) then
		mapper.echo("Don't know how to get there (" .. tostring(where) .. ") from here :(")
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		-- allow mapper 'addons' to unlink their special exits
		raiseEvent("mmp clear externals")
		return
	end
	doSpeedWalk(dashtype)
	-- allow mapper 'addons' to unlink their special exits
	raiseEvent("mmp clear externals")
end

function mapper.gotoArea(where, number, dashtype, exact)
	mapper.speedWalk.type = "area"
	if not where or type(where) ~= "string" then
		mapper.echo("Where do you want to go to?")
		return
	end
	local where = where:lower()
	number = tonumber(number)
	local tmp = getRoomUserData(1, "gotoMapping")
	if not tmp or tmp == "" then
		tmp = "[]"
	end
	local temp, maptable = yajl.to_value(tmp), {}
	for k, v in pairs(temp) do
		maptable[k:lower()] = v
	end
	local destinationRoom = maptable[where]
	if destinationRoom then
		mapper.gotoRoom(destinationRoom, dashtype)
		return
	end
	local areaid, msg, multiples = mapper.findAreaID(where, exact)
	if areaid then
		mapper.gotoAreaID(areaid)
	elseif not areaid and #multiples > 0 then
		if number and number <= #multiples then
			mapper.gotoArea(multiples[number], nil, dashtype, true)
			return
		end
		mapper.echo("Which area would you like to go to?")
		fg("DimGrey")
		for key, areaname in ipairs(multiples) do
			echo("  ")
			echoLink(
				key .. ") ",
				'mapper.gotoArea("'
					.. areaname
					.. '", nil, '
					.. (dashtype and '"' .. dashtype .. '"' or "nil")
					.. ", true)",
				"Click to go to " .. areaname,
				true
			)
			setUnderline(true)
			echoLink(
				areaname,
				'mapper.gotoArea("'
					.. areaname
					.. '", nil, '
					.. (dashtype and '"' .. dashtype .. '"' or "nil")
					.. ", true)",
				"Click to go to " .. areaname,
				true
			)
			setUnderline(false)
			echo("\n")
		end
		resetFormat()
		return
	else
		mapper.echo(string.format("Don't know of any area named '%s'.", where))
		return
	end
end

--- DOES NOT ACCOUNT FOR CHANGING THE MAP YET (within a profile load), because we don't know when it happens
local getpathcache = {}
--setmetatable(getpathcache, {__mode = "kv"}) -- weak keys/values = it'll periodically get cleaned up by gc

function mapper.getPath(from, to)
	assert(tonumber(from) and tonumber(to), "mapper.getPath: both from and to have to be room IDs")
	local key = string.format("%s_%s", from, to)
	local resulttbl = getpathcache[key]
	-- not in cache?
	if not resulttbl then
		mapper.computeGetPath = mapper.computeGetPath or createStopWatch()
		startStopWatch(mapper.computeGetPath)
		local boolean = getPath(from, to)
		if mapper.debug then
			mapper.echo(
				"a new getPath() from " .. from .. " to " .. to .. " took " .. stopStopWatch(mapper.computeGetPath) .. "s."
			)
		end
		-- save it into the cache & send away
		getpathcache[key] = { boolean, speedWalkDir, speedWalkPath }
		return boolean
	end
	-- or if it is, retrieve & send away
	speedWalkDir = resulttbl[2]
	speedWalkPath = resulttbl[3]
	return resulttbl[1]
end

function mapper.clearpathcache()
	if mapper.debug then
		mapper.echo("path cache cleared")
	end
	getpathcache = {}
end

registerAnonymousEventHandler("mmapper updated map", "mapper.clearpathcache")

function mapper.showpathcache()
	return getpathcache
end

-- Simple delay function for movement
function mapper.delayedMove(delay)
	if delay and delay > 0 then
		tempTimer(delay, function() mapper.move() end)
	else
		mapper.move()
	end
end

-- moves to the next room we need to.

function mapper.move()
	if mapper.paused or not mapper.autowalking or not mapper.canmove() then
		return
	end
	-- sometimes it's 0 - default to 1
	if mapper.speedWalkCounter == 0 then
		mapper.speedWalkCounter = 1
	end

	-- Check if we have a valid direction to move
	if not mapper.speedWalkDir or not mapper.speedWalkDir[mapper.speedWalkCounter] then
		if mapper.settings.debug then
			mapper.echo("No more directions to walk, stopping.")
		end
		mapper.autowalking = false
		return
	end

	local cmd
	if mapper.settings["caravan"] then
		cmd = "lead caravan " .. mapper.speedWalkDir[mapper.speedWalkCounter]
	else
		cmd = mapper.speedWalkDir[mapper.speedWalkCounter]
	end
	cmd = cmd or ""
	if string.starts(cmd, "script:") then
		cmd = string.gsub(cmd, "script:", "")
		loadstring(cmd)()
		if mapper.settings.showcmds and not mapper.hasty then
			cecho(
				string.format(
					"<red>(<maroon>%d - <dark_slate_grey>%s<red>)",
					#mapper.speedWalkDir - mapper.speedWalkCounter + 1,
					"<script>"
				)
			)
		end
		mapper.hasty = false
	else
		send(cmd, false)
		if mapper.settings.showcmds and not mapper.hasty then
			cecho(
				string.format(
					"<red>(<maroon>%d - <dark_slate_grey>%s<red>)",
					#mapper.speedWalkDir - mapper.speedWalkCounter + 1,
					cmd
				)
			)
		end
		mapper.hasty = false
	end
	-- Movement continues when GMCP room change event fires
end

function mapper.swim()
	-- not going anywhere? don't do anything
	if not mapper.speedWalkDir[mapper.speedWalkCounter] then
		return
	end
	send("swim " .. mapper.speedWalkDir[mapper.speedWalkCounter], false)
	if mapper.settings.showcmds then
		cecho(
			string.format(
				"<red>(<maroon>%d - <dark_slate_grey>swim %s<red>)",
				#mapper.speedWalkDir - mapper.speedWalkCounter + 1,
				mapper.speedWalkDir[mapper.speedWalkCounter]
			)
		)
	end
	mapper.hasty = true
	tempTimer(2.5, function() mapper.move() end)
end

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

function mapper.customwalkdelay(delay)
	local latency = getNetworkLatency() / 1000  -- Convert ms to seconds
	tempTimer(latency + delay, function() mapper.move() end)
end

function mapper.stop()
	mapper.speedWalkPath = {}
	mapper.speedWalkDir = {}
	mapper.speedWalkCounter = 0
	stopStopWatch(mapper.speedWalkWatch)
	mapper.autowalking = false
	-- clear all the temps we've got
	if mapper.specials then
		for trigger, ID in pairs(mapper.specials) do
			killTrigger(ID)
		end
	end
	mapper.specials = {}
	mapper.echo("Stopped walking.")
	raiseEvent("mmapper stopped")
end

-- Willowdale and other games can implement their own balance checking
-- if we can't move, setup a polling timer to prompt walking when we can again.

function mapper.canmove(fromtimer)
	if mapper.mapperCanMove and mapper.mapperCanMove() then
		if fromtimer then
			mapper.move()
		else
			return true
		end
	elseif mapper.mapperCanMove then
		tempTimer(0.2, [[mapper.canmove(true)]])
		return false
	end
	-- Default behavior: assume we can move
	if fromtimer then
		mapper.move()
	else
		return true
	end
end

local oldnum

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

function mapper.speedwalking(event, num)
	local num = tonumber(num) or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and tonumber(gmcp.Room.Info.Basic.id))
	if num ~= mapper.currentroom then
		mapper.previousroom = mapper.currentroom
	end
	mapper.currentroom = num
	mapper.currentroomname = getRoomName(num)

	-- Debug speedwalking
	if mapper.settings.debug and mapper.autowalking then
		mapper.echo(
			string.format(
				"Room change detected: %d (counter: %d/%d, dest: %s)",
				num,
				mapper.speedWalkCounter or 0,
				#(mapper.speedWalkPath or {}),
				mapper.speedWalkPath and mapper.speedWalkPath[#mapper.speedWalkPath] or "none"
			)
		)
	end
	-- Try to track if we're flying or not
	-- This is to avoid being "off path" if we FLY due to flight mechanics.
	local madeflight = false
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then
		local flying = false
		if string.find(gmcp.Room.Info.Basic.name, "^flying above") then
			flying = true
		end
		if mapper.flying and not flying then
			-- We were flying, and now we are not. Gravity!
			mapper.flying = false
		elseif not mapper.flying and flying then
			-- We were not flying and now we are.
			madeflight = true
			mapper.flying = true
		elseif not flying then
			mapper.flying = false
		end
	else
		mapper.flying = false
	end
	-- track if we're inside or outside, if possible
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then
		local areaID = getRoomArea(mapper.currentroom)
		if
			mapper.inside
			and not (
				table.contains(gmcp.Room.Info.Basic.details or {}, "indoors")
				or table.contains(gmcp.Room.Info.Basic.details or {}, "considered indoors")
			)
		then
			mapper.inside = false
			raiseEvent("mmapper went outside")
		elseif
			not mapper.inside
			and (
				table.contains(gmcp.Room.Info.Basic.details or {}, "indoors")
				or table.contains(gmcp.Room.Info.Basic.details or {}, "considered indoors")
			)
		then
			mapper.inside = true
			raiseEvent("mmapper went inside")
		end
		-- Continent change detection removed - not used in Willowdale
		-- the event could cancel speedwalking - in this case quit
		if mapper.ignore_speedwalking then
			mapper.ignore_speedwalking = nil
			return
		end
	end
	if oldnum == num then
		return
	else
		oldnum = num
	end
	if not mapper.autowalking then
		return
	end
	-- No longer using movetimer, movement is GMCP-driven
	if num == mapper.speedWalkPath[#mapper.speedWalkPath] then
		local walktime = stopStopWatch(mapper.speedWalkWatch)
		mapper.echo(string.format("We've arrived! Took us %.1fs.\n", walktime))
		raiseEvent("mmapper arrived")
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		mapper.autowalking = false
	elseif mapper.speedWalkPath[mapper.speedWalkCounter] == num then
		mapper.speedWalkCounter = mapper.speedWalkCounter + 1
		-- Check if we're at the destination after incrementing
		if mapper.speedWalkCounter > #mapper.speedWalkPath or num == mapper.speedWalkPath[#mapper.speedWalkPath] then
			local walktime = stopStopWatch(mapper.speedWalkWatch)
			mapper.echo(string.format("We've arrived! Took us %.1fs.\n", walktime))
			raiseEvent("mmapper arrived")
			mapper.speedWalkPath = {}
			mapper.speedWalkDir = {}
			mapper.speedWalkCounter = 0
			mapper.autowalking = false
		else
			-- GMCP room change detected, continue walking
			-- Use delay if configured, otherwise move immediately
			local delay = mapper.settings.walkdelay or 0.3
			mapper.delayedMove(delay)
		end
	elseif #mapper.speedWalkPath > 0 then
		-- ended up somewhere we didn't want to be, and this isn't a ferry room?
		speedWalkMoved = false
		-- re-calculate path then
		mapper.echo("Ended up off the path, recalculating a new path...")
		local destination = mapper.speedWalkPath[#mapper.speedWalkPath]
		if not mapper.getPath(num, destination) then
			mapper.echo(
				string.format(
					"Don't know how to get to %d (%s) anymore :( Move into a room we know of to continue",
					destination,
					getRoomName(destination)
				)
			)
		else
			mapper.gotoRoom(destination)
		end
	end
end

-- doSpeedWalk is used by the mudlet mapping script and should not be changed
function doSpeedWalk(dashtype)
	mapper.speedWalkDir = mapper.deepcopy(speedWalkDir)
	mapper.speedWalkPath = mapper.deepcopy(speedWalkPath)
	speedWalkDir, speedWalkPath = {}, {}
	resetStopWatch(mapper.speedWalkWatch)
	startStopWatch(mapper.speedWalkWatch)
	if dashtype then
		mapper.fixPath(mapper.currentroom, mapper.speedWalkPath[#mapper.speedWalkPath], dashtype)
	end
	mapper.fixSpecialExits(mapper.speedWalkDir)
	if #mapper.speedWalkPath == 0 then
		mapper.autowalking = false
		mapper.echo("Couldn't find a path to the destination :(")
		raiseEvent("mmapper failed path")
		return
	end
	-- this is a fix: convert nums to actual numbers
	for i = 1, #mapper.speedWalkPath do
		mapper.speedWalkPath[i] = tonumber(mapper.speedWalkPath[i])
	end
	-- Check if we're already at the destination
	if mapper.currentroom == mapper.speedWalkPath[#mapper.speedWalkPath] then
		mapper.echo("We're already at the destination!")
		raiseEvent("mmapper arrived")
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		mapper.autowalking = false
		return
	end

	mapper.autowalking = true
	raiseEvent("s")
	if not mapper.paused then
		mapper.echon("Starting speedwalk from " .. (atcp.RoomNum or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.id)) .. " to ")
		cechoLink(
			"<" .. mapper.settings.echocolour .. ">" .. mapper.speedWalkPath[#mapper.speedWalkPath],
			'mapper.gotoRoom "' .. mapper.speedWalkPath[#mapper.speedWalkPath] .. '"',
			"Go to " .. mapper.speedWalkPath[#mapper.speedWalkPath],
			true
		)
		echo(": ")
		mapper.speedWalkCounter = 1
		if mapper.canmove() then
			mapper.hasty = true
			-- Start moving immediately (with delay if configured)
			local delay = mapper.settings.walkdelay or 0.3
			mapper.delayedMove(delay)
		else
			echo("(when we get balance back / aren't hindered)")
		end
	else
		mapper.echo("Will go to " .. mapper.speedWalkPath[#mapper.speedWalkPath] .. " as soon as the mapper is unpaused.")
	end
end

function mapper.failpath()
	if mapper.speedWalkWatch then
		local walktime = stopStopWatch(mapper.speedWalkWatch)
		if walktime then
			mapper.echo(string.format("Can't continue further! Took us %.1fs to get here.\n", walktime))
		else
			mapper.echo("Can't continue further!")
		end
	else
		mapper.echo("Can't continue further!")
	end
	mapper.autowalking = false
	mapper.speedWalkPath = {}
	mapper.speedWalkDir = {}
	mapper.speedWalkCounter = 0
	-- No longer using movetimer, movement is GMCP-driven
	raiseEvent("mmapper failed path")
end

function mapper.changeBoolFunc(name, option)
	local en
	en = option and "will now use" or "will no longer use"
	mapper.echo("<green>Okay, the mapper " .. en .. " <white>" .. name .. "<green>!")
end

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

function mapper.getShortestOfMultipleRooms(possibleRooms)
	local shortestWeight, closestRoom = 10000000, 0
	local checkedsofar, outoftime = 0, false
	local getStopWatchTime, tonumber = getStopWatchTime, tonumber

	-- allocate only 500ms to finding the shortest path, or more if we failed to find anything
	mapper.computeShortestWatch = mapper.computeShortestWatch or createStopWatch()
	startStopWatch(mapper.computeShortestWatch)
	raiseEvent("mmp link externals")

	-- mapper.echo(string.format("Have %s rooms nodes, %ss taken so far...", table.size(possibleRooms), getStopWatchTime(mapper.computeShortestWatch)))
	for _, id in pairs(possibleRooms) do
		local possible, thisWeight = getPath(mapper.currentroom, tonumber(id))
		if possible and thisWeight < shortestWeight then
			shortestWeight = thisWeight
			closestRoom = tonumber(id)
		end
		checkedsofar = checkedsofar + 1
		if getStopWatchTime(mapper.computeShortestWatch) >= 0.5 then
			outoftime = true
			break
		end

		-- mapper.echo(string.format("pathed from %s to %s, running time so far: %s", mapper.currentroom, id, getStopWatchTime(mapper.computeShortestWatch)))
	end
	--mapper.echo(string.format("total time took: %s", getStopWatchTime(mapper.computeShortestWatch)))
	stopStopWatch(mapper.computeShortestWatch)
	return closestRoom, outoftime, checkedsofar
end

function mapper.gotoAreaID(areaid, number, dashtype)
	if not areaid or not tonumber(areaid) then
		mapper.echo("To where do you want to go?")
		return
	end
	areaid = tonumber(areaid)
	if not mapper.areatabler[areaid] then
		mapper.echo("Invalid area ID selected")
		return
	end
	local possibleRooms, shortestBorder = {}, 0
	for id, _ in pairs(mapper.getAreaBorders(areaid)) do
		possibleRooms[#possibleRooms + 1] = id
	end
	shortestBorder, outoftime, checkedsofar = mapper.getShortestOfMultipleRooms(possibleRooms)
	if shortestBorder == 0 then
		if outoftime then
			mapper.echo(
				string.format(
					'I checked %d of the %d possible exits "%s" has, but none of the ways there worked and it was taking too long :( try doing this again?',
					checkedsofar,
					table.size(possibleRooms),
					getRoomAreaName(areaid)
				)
			)
		else
			mapper.echo(
				"Checked "
					.. table.size(possibleRooms)
					.. " exits in that area, and none of them worked :( I Don't know how to get you there."
			)
		end
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		raiseEvent("mmp clear externals")
		return
	end
	raiseEvent("mmp clear externals")
	mapper.gotoRoom(shortestBorder, dashtype, "area")
end

function mapper.gotoFeature(partialFeatureName, dashtype)
	local mapFeatures = mapper.getMapFeatures()
	local feature
	if mapFeatures[partialFeatureName:lower()] then
		feature = partialFeatureName:lower()
	else
		for key in pairs(mapFeatures) do
			if key:find(partialFeatureName:lower()) then
				feature = key
				break
			end
		end
	end
	if not feature then
		mapper.echo("No feature like " .. partialFeatureName .. " found.")
		return
	end
	local possibleRooms = searchRoomUserData("feature-" .. feature, "true")
	closestFeature, outoftime, checkedsofar = mapper.getShortestOfMultipleRooms(possibleRooms)
	if closestFeature == 0 then
		if outoftime then
			mapper.echo(
				string.format(
					'I checked %d of the %d possible features "%s" has, but none of the ways there worked and it was taking too long :( try doing this again?',
					checkedsofar,
					table.size(possibleRooms),
					partialFeatureName
				)
			)
		else
			mapper.echo(
				"Checked "
					.. table.size(possibleRooms)
					.. " rooms with that feature, and none of them worked :( I Don't know how to get you there."
			)
		end
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		raiseEvent("mmp clear externals")
		return
	end
	raiseEvent("mmp clear externals")
	mapper.gotoRoom(closestFeature, dashtype, "room")
end
