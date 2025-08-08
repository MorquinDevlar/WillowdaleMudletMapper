function mmp.gotoRoom(where, dashtype, gotoType)
	mmp.speedWalk.type = gotoType or "room"
	if not where or not tonumber(where) then
		mmp.echo("Where do you want to go to?")
		return
	end
	if tonumber(where) == mmp.currentroom then
		mmp.echo("We're already at " .. where .. "!")
		raiseEvent("mmapper arrived")
		return
	end
	-- allow mapper 'addons' to link their own exits in
	raiseEvent("mmp link externals")
	-- if getPath worked, then the dirs and room #'s tables were populated for us
	if not mmp.getPath(mmp.currentroom, tonumber(where)) then
		mmp.echo("Don't know how to get there (" .. tostring(where) .. ") from here :(")
		mmp.speedWalkPath = {}
		mmp.speedWalkDir = {}
		mmp.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		-- allow mapper 'addons' to unlink their special exits
		raiseEvent("mmp clear externals")
		return
	end
	doSpeedWalk(dashtype)
	-- allow mapper 'addons' to unlink their special exits
	raiseEvent("mmp clear externals")
end

function mmp.gotoArea(where, number, dashtype, exact)
	mmp.speedWalk.type = "area"
	if not where or type(where) ~= "string" then
		mmp.echo("Where do you want to go to?")
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
		mmp.gotoRoom(destinationRoom, dashtype)
		return
	end
	local areaid, msg, multiples = mmp.findAreaID(where, exact)
	if areaid then
		mmp.gotoAreaID(areaid)
	elseif not areaid and #multiples > 0 then
		if number and number <= #multiples then
			mmp.gotoArea(multiples[number], nil, dashtype, true)
			return
		end
		mmp.echo("Which area would you like to go to?")
		fg("DimGrey")
		for key, areaname in ipairs(multiples) do
			echo("  ")
			echoLink(
				key .. ") ",
				'mmp.gotoArea("'
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
				'mmp.gotoArea("'
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
		mmp.echo(string.format("Don't know of any area named '%s'.", where))
		return
	end
end

--- DOES NOT ACCOUNT FOR CHANGING THE MAP YET (within a profile load), because we don't know when it happens
local getpathcache = {}
--setmetatable(getpathcache, {__mode = "kv"}) -- weak keys/values = it'll periodically get cleaned up by gc

function mmp.getPath(from, to)
	assert(tonumber(from) and tonumber(to), "mmp.getPath: both from and to have to be room IDs")
	local key = string.format("%s_%s", from, to)
	local resulttbl = getpathcache[key]
	-- not in cache?
	if not resulttbl then
		mmp.computeGetPath = mmp.computeGetPath or createStopWatch()
		startStopWatch(mmp.computeGetPath)
		local boolean = getPath(from, to)
		if mmp.debug then
			mmp.echo(
				"a new getPath() from " .. from .. " to " .. to .. " took " .. stopStopWatch(mmp.computeGetPath) .. "s."
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

function mmp.clearpathcache()
	if mmp.debug then
		mmp.echo("path cache cleared")
	end
	getpathcache = {}
end

registerAnonymousEventHandler("mmapper updated map", "mmp.clearpathcache")

function mmp.showpathcache()
	return getpathcache
end

function mmp.setmovetimer(time, ignoreLatency)
	if mmp.movetimer then
		killTimer(mmp.movetimer)
	end
	-- Handle walk speed settings
	if mmp.settings.walkspeed == "slow" and not mmp.hasty then
		return
	elseif mmp.settings.walkspeed == "fast" then
		-- Skip timer for fast mode
		return
	end

	-- Normal timer logic for normal walking
	local laglevel = mmp.settings.laglevel or 1
	time = time or mmp.lagtable[laglevel].time
	local latency = ignoreLatency and 0 or getNetworkLatency()
	if mmp.debug then
		mmp.echo(f("setting move timer according to time {time} and latency {latency}"))
	end
	mmp.movetimer = tempTimer(latency + time, function()
		if mmp.debug then
			mmp.echo("move timer fired")
		end
		mmp.movetimer = false
		mmp.move()
	end)
end

-- moves to the next room we need to.

function mmp.move()
	if mmp.paused or not mmp.autowalking or mmp.movetimer or not mmp.canmove() then
		return
	end
	-- sometimes it's 0 - default to 1
	if mmp.speedWalkCounter == 0 then
		mmp.speedWalkCounter = 1
	end

	-- Check if we have a valid direction to move
	if not mmp.speedWalkDir or not mmp.speedWalkDir[mmp.speedWalkCounter] then
		if mmp.settings.debug then
			mmp.echo("No more directions to walk, stopping.")
		end
		mmp.autowalking = false
		return
	end

	local cmd
	if mmp.settings["caravan"] then
		cmd = "lead caravan " .. mmp.speedWalkDir[mmp.speedWalkCounter]
	else
		cmd = mmp.speedWalkDir[mmp.speedWalkCounter]
	end
	cmd = cmd or ""
	-- In fast mode, don't set a timer - just send the command
	-- The next GMCP room event will trigger the next move
	if mmp.settings.walkspeed ~= "fast" then
		-- timeout before loadstring, so it can set its own if it would like to.
		mmp.setmovetimer()
	end
	if string.starts(cmd, "script:") then
		cmd = string.gsub(cmd, "script:", "")
		loadstring(cmd)()
		if mmp.settings.showcmds and not mmp.hasty then
			cecho(
				string.format(
					"<red>(<maroon>%d - <dark_slate_grey>%s<red>)",
					#mmp.speedWalkDir - mmp.speedWalkCounter + 1,
					"<script>"
				)
			)
		end
		mmp.hasty = false
	else
		send(cmd, false)
		if mmp.settings.showcmds and not mmp.hasty then
			cecho(
				string.format(
					"<red>(<maroon>%d - <dark_slate_grey>%s<red>)",
					#mmp.speedWalkDir - mmp.speedWalkCounter + 1,
					cmd
				)
			)
		end
		mmp.hasty = false
	end
end

function mmp.swim()
	-- not going anywhere? don't do anything
	if not mmp.speedWalkDir[mmp.speedWalkCounter] then
		return
	end
	send("swim " .. mmp.speedWalkDir[mmp.speedWalkCounter], false)
	if mmp.settings.showcmds then
		cecho(
			string.format(
				"<red>(<maroon>%d - <dark_slate_grey>swim %s<red>)",
				#mmp.speedWalkDir - mmp.speedWalkCounter + 1,
				mmp.speedWalkDir[mmp.speedWalkCounter]
			)
		)
	end
	mmp.hasty = true
	mmp.setmovetimer(2.5)
end

function mmp.enterGrate()
	-- This function is no longer needed for GoMud
	-- Keeping empty function to avoid breaking references
end

function mmp.openDoor()
	-- not going anywhere? don't do anything
	if not mmp.speedWalkDir[mmp.speedWalkCounter] then
		return
	end
	send("open door " .. mmp.speedWalkDir[mmp.speedWalkCounter], false)
	if mmp.settings.showcmds then
		cecho(
			string.format(
				"<red>(<maroon>%d - <dark_slate_grey>open door %s<red>)",
				#mmp.speedWalkDir - mmp.speedWalkCounter + 1,
				mmp.speedWalkDir[mmp.speedWalkCounter]
			)
		)
	end
	mmp.hasty = true
	mmp.setmovetimer(getNetworkLatency())
end

function mmp.unlockDoor()
	-- not going anywhere? don't do anything
	if not mmp.speedWalkDir[mmp.speedWalkCounter] then
		return
	end
	send("unlock door " .. mmp.speedWalkDir[mmp.speedWalkCounter], false)
	if mmp.settings.showcmds then
		cecho(
			string.format(
				"<red>(<maroon>%d - <dark_slate_grey>unlock door %s<red>)",
				#mmp.speedWalkDir - mmp.speedWalkCounter,
				mmp.speedWalkDir[mmp.speedWalkCounter]
			)
		)
	end
	mmp.hasty = true
	mmp.setmovetimer(getNetworkLatency())
end

function mmp.customwalkdelay(delay)
	mmp.setmovetimer(getNetworkLatency() + delay)
end

function mmp.stop()
	mmp.speedWalkPath = {}
	mmp.speedWalkDir = {}
	mmp.speedWalkCounter = 0
	stopStopWatch(mmp.speedWalkWatch)
	--if mmp.movetimer then killTimer( mmp.movetimer ) end
	mmp.autowalking = false
	-- clear all the temps we've got
	if mmp.specials then
		for trigger, ID in pairs(mmp.specials) do
			killTrigger(ID)
		end
	end
	mmp.specials = {}
	mmp.echo("Stopped walking.")
	raiseEvent("mmapper stopped")
end

-- GoMud and other games can implement their own balance checking
-- if we can't move, setup a polling timer to prompt walking when we can again.

function mmp.canmove(fromtimer)
	if mmp.mapperCanMove and mmp.mapperCanMove() then
		if fromtimer then
			mmp.move()
		else
			return true
		end
	elseif mmp.mapperCanMove then
		tempTimer(0.2, [[mmp.canmove(true)]])
		return false
	end
	-- Default behavior: assume we can move
	if fromtimer then
		mmp.move()
	else
		return true
	end
end

local oldnum

-- Function to update door statuses based on current GMCP data
function mmp.updateDoorStatuses(roomNum)
	if not roomNum or not mmp.roomexists(roomNum) then
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
			local shortExit = mmp.anytoshort(exit)
			
			-- Check if this exit has door details
			if exitData.details and exitData.details.type == "door" and exitData.details.state then
				local state = exitData.details.state
				
				if state == "closed" or state == "locked" then
					-- Should have a door
					local doorType = state == "locked" and 3 or 2 -- 3 = locked, 2 = closed
					if not doorStatus[shortExit] or doorStatus[shortExit] == 0 then
						-- No door exists, create one
						if mmp.settings.debug then
							mmp.echo("updateDoorStatuses: Creating " .. state .. " door on " .. exit .. " exit (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. roomNum)
						end
						setDoor(roomNum, shortExit, doorType)
						updated = true
					elseif doorStatus[shortExit] ~= doorType then
						-- Door exists but state changed (e.g., closed -> locked or locked -> closed)
						if mmp.settings.debug then
							mmp.echo("updateDoorStatuses: Updating door state on " .. exit .. " exit from " .. (doorStatus[shortExit] == 2 and "closed" or "locked") .. " to " .. state .. " in room " .. roomNum)
						end
						setDoor(roomNum, shortExit, doorType)
						updated = true
					end
					
					-- Lock the exit if door is closed or locked
					if mmp.settings.debug then
						mmp.echo("updateDoorStatuses: Locking exit " .. exit .. " in room " .. roomNum)
					end
					mmp.lockExit(roomNum, exit, true)
					
				elseif state == "open" then
					-- Exit is open - check if we need to update door state
					if doorStatus[shortExit] and doorStatus[shortExit] > 1 then
						-- Door exists and is closed/locked, update to open
						if mmp.settings.debug then
							mmp.echo("updateDoorStatuses: Opening door on " .. exit .. " exit (short: " .. shortExit .. ") in room " .. roomNum)
						end
						setDoor(roomNum, shortExit, 1) -- 1 = open door
						updated = true
					end
					
					-- Unlock the exit since door is open
					if mmp.hasExitLock(roomNum, exit) then
						if mmp.settings.debug then
							mmp.echo("updateDoorStatuses: Unlocking exit " .. exit .. " in room " .. roomNum)
						end
						mmp.lockExit(roomNum, exit, false)
					end
				end
			else
				-- No door details, ensure exit is unlocked
				if mmp.hasExitLock(roomNum, exit) then
					if mmp.settings.debug then
						mmp.echo("updateDoorStatuses: Unlocking exit " .. exit .. " (no door) in room " .. roomNum)
					end
					mmp.lockExit(roomNum, exit, false)
				end
			end
		end
	end
	
	-- Check for doors that should be removed (exit no longer exists)
	for exit, doorType in pairs(doorStatus) do
		if doorType > 0 then
			-- doorStatus uses short forms, currentexits uses long forms
			-- Need to check if this exit exists in any form
			local longExit = mmp.anytolong(exit)
			local found = false
			for gmcpExit, _ in pairs(currentexits) do
				if mmp.anytoshort(gmcpExit) == exit then
					found = true
					break
				end
			end
			if not found then
				if mmp.settings.debug then
					mmp.echo("updateDoorStatuses: Removing door from " .. exit .. " exit (exit no longer exists) in room " .. roomNum)
				end
				setDoor(roomNum, exit, 0) -- Remove door
				updated = true
			end
		end
	end
	
	return updated
end

function mmp.speedwalking(event, num)
	local num = tonumber(num) or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and tonumber(gmcp.Room.Info.Basic.id))
	if num ~= mmp.currentroom then
		mmp.previousroom = mmp.currentroom
	end
	mmp.currentroom = num
	mmp.currentroomname = getRoomName(num)

	-- Debug speedwalking
	if mmp.settings.debug and mmp.autowalking then
		mmp.echo(
			string.format(
				"Room change detected: %d (counter: %d/%d, dest: %s)",
				num,
				mmp.speedWalkCounter or 0,
				#(mmp.speedWalkPath or {}),
				mmp.speedWalkPath and mmp.speedWalkPath[#mmp.speedWalkPath] or "none"
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
		if mmp.flying and not flying then
			-- We were flying, and now we are not. Gravity!
			mmp.flying = false
		elseif not mmp.flying and flying then
			-- We were not flying and now we are.
			madeflight = true
			mmp.flying = true
		elseif not flying then
			mmp.flying = false
		end
	else
		mmp.flying = false
	end
	-- track if we're inside or outside, if possible
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then
		local areaID = getRoomArea(mmp.currentroom)
		if
			mmp.inside
			and not (
				table.contains(gmcp.Room.Info.Basic.details or {}, "indoors")
				or table.contains(gmcp.Room.Info.Basic.details or {}, "considered indoors")
			)
		then
			mmp.inside = false
			raiseEvent("mmapper went outside")
		elseif
			not mmp.inside
			and (
				table.contains(gmcp.Room.Info.Basic.details or {}, "indoors")
				or table.contains(gmcp.Room.Info.Basic.details or {}, "considered indoors")
			)
		then
			mmp.inside = true
			raiseEvent("mmapper went inside")
		end
		-- Continent change detection removed - not used in GoMud
		-- the event could cancel speedwalking - in this case quit
		if mmp.ignore_speedwalking then
			mmp.ignore_speedwalking = nil
			return
		end
	end
	if oldnum == num then
		return
	else
		oldnum = num
	end
	if not mmp.autowalking then
		return
	end
	if mmp.movetimer then
		killTimer(mmp.movetimer)
		mmp.movetimer = false
	end
	if num == mmp.speedWalkPath[#mmp.speedWalkPath] then
		local walktime = stopStopWatch(mmp.speedWalkWatch)
		mmp.echo(string.format("We've arrived! Took us %.1fs.\n", walktime))
		raiseEvent("mmapper arrived")
		mmp.speedWalkPath = {}
		mmp.speedWalkDir = {}
		mmp.speedWalkCounter = 0
		mmp.autowalking = false
	elseif mmp.speedWalkPath[mmp.speedWalkCounter] == num then
		mmp.speedWalkCounter = mmp.speedWalkCounter + 1
		-- Check if we're at the destination after incrementing
		if mmp.speedWalkCounter > #mmp.speedWalkPath or num == mmp.speedWalkPath[#mmp.speedWalkPath] then
			local walktime = stopStopWatch(mmp.speedWalkWatch)
			mmp.echo(string.format("We've arrived! Took us %.1fs.\n", walktime))
			raiseEvent("mmapper arrived")
			mmp.speedWalkPath = {}
			mmp.speedWalkDir = {}
			mmp.speedWalkCounter = 0
			mmp.autowalking = false
		else
			-- For faster movement, call mmp.move directly instead of waiting for prompt
			if mmp.settings.walkspeed == "fast" then
				mmp.move()
			else
				tempPromptTrigger(mmp.move, 1)
			end
		end
	elseif #mmp.speedWalkPath > 0 then
		-- ended up somewhere we didn't want to be, and this isn't a ferry room?
		speedWalkMoved = false
		-- re-calculate path then
		mmp.echo("Ended up off the path, recalculating a new path...")
		local destination = mmp.speedWalkPath[#mmp.speedWalkPath]
		if not mmp.getPath(num, destination) then
			mmp.echo(
				string.format(
					"Don't know how to get to %d (%s) anymore :( Move into a room we know of to continue",
					destination,
					getRoomName(destination)
				)
			)
		else
			mmp.gotoRoom(destination)
		end
	end
end

-- doSpeedWalk is used by the mudlet mapping script and should not be changed
function doSpeedWalk(dashtype)
	mmp.speedWalkDir = mmp.deepcopy(speedWalkDir)
	mmp.speedWalkPath = mmp.deepcopy(speedWalkPath)
	speedWalkDir, speedWalkPath = {}, {}
	resetStopWatch(mmp.speedWalkWatch)
	startStopWatch(mmp.speedWalkWatch)
	if dashtype then
		mmp.fixPath(mmp.currentroom, mmp.speedWalkPath[#mmp.speedWalkPath], dashtype)
	end
	mmp.fixSpecialExits(mmp.speedWalkDir)
	if #mmp.speedWalkPath == 0 then
		mmp.autowalking = false
		mmp.echo("Couldn't find a path to the destination :(")
		raiseEvent("mmapper failed path")
		return
	end
	-- this is a fix: convert nums to actual numbers
	for i = 1, #mmp.speedWalkPath do
		mmp.speedWalkPath[i] = tonumber(mmp.speedWalkPath[i])
	end
	-- Check if we're already at the destination
	if mmp.currentroom == mmp.speedWalkPath[#mmp.speedWalkPath] then
		mmp.echo("We're already at the destination!")
		raiseEvent("mmapper arrived")
		mmp.speedWalkPath = {}
		mmp.speedWalkDir = {}
		mmp.speedWalkCounter = 0
		mmp.autowalking = false
		return
	end

	mmp.autowalking = true
	raiseEvent("s")
	if not mmp.paused then
		mmp.echon("Starting speedwalk from " .. (atcp.RoomNum or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.id)) .. " to ")
		cechoLink(
			"<" .. mmp.settings.echocolour .. ">" .. mmp.speedWalkPath[#mmp.speedWalkPath],
			'mmp.gotoRoom "' .. mmp.speedWalkPath[#mmp.speedWalkPath] .. '"',
			"Go to " .. mmp.speedWalkPath[#mmp.speedWalkPath],
			true
		)
		echo(": ")
		mmp.speedWalkCounter = 1
		if mmp.canmove() then
			mmp.hasty = true
			if mmp.settings.walkspeed == "fast" then
				-- In fast mode, send the first command immediately
				mmp.move()
			else
				mmp.setmovetimer(0.1, true)
			end
		else
			echo("(when we get balance back / aren't hindered)")
		end
	else
		mmp.echo("Will go to " .. mmp.speedWalkPath[#mmp.speedWalkPath] .. " as soon as the mapper is unpaused.")
	end
end

function mmp.failpath()
	if mmp.speedWalkWatch then
		local walktime = stopStopWatch(mmp.speedWalkWatch)
		if walktime then
			mmp.echo(string.format("Can't continue further! Took us %.1fs to get here.\n", walktime))
		else
			mmp.echo("Can't continue further!")
		end
	else
		mmp.echo("Can't continue further!")
	end
	mmp.autowalking = false
	mmp.speedWalkPath = {}
	mmp.speedWalkDir = {}
	mmp.speedWalkCounter = 0
	if mmp.movetimer then
		killTimer(mmp.movetimer)
		mmp.movetimer = nil
	end
	raiseEvent("mmapper failed path")
end

function mmp.changeBoolFunc(name, option)
	local en
	en = option and "will now use" or "will no longer use"
	mmp.echo("<green>Okay, the mapper " .. en .. " <white>" .. name .. "<green>!")
end

function mmp.fixPath(rFrom, rTo, dashtype)
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
	while mmp.speedWalkDir[index] do
		if not table.contains(getSpecialExits(mmp.speedWalkPath[index]), mmp.speedWalkDir[index]) then
			dashExaust = false
			repCount = 1
			while mmp.speedWalkDir[index + repCount] == mmp.speedWalkDir[index] do
				repCount = repCount + 1
				if repCount == 11 then
					dashExaust = true
					break
				end
			end
			if repCount > 1 then
				-- Found direction repetition. Calculate dash path.
				local exits = getRoomExits(mmp.speedWalkPath[index + (repCount - 1)])
				local pname = ""
				for word in mmp.speedWalkDir[index]:gmatch("%w") do
					pname = pname .. (dRef[word] or word)
				end
				if not exits[pname] or dashExaust then
					-- Final room in this direction does not continue, dash!
					table.insert(currentPath, string.format("%s %s", dashtype, mmp.speedWalkDir[index]))
					currentIds[#currentIds + 1] = mmp.speedWalkPath[index + repCount - 1]
				else
					-- Final room in this direction continues onwards, don't dash
					for i = 1, repCount do
						table.insert(currentPath, mmp.speedWalkDir[index])
						currentIds[#currentIds + 1] = mmp.speedWalkPath[index + i - 1]
					end
				end
				index = index + repCount
			else
				-- No repetition, just add the direction.
				table.insert(currentPath, mmp.speedWalkDir[index])
				currentIds[#currentIds + 1] = mmp.speedWalkPath[index]
				index = index + 1
			end
		else
			-- Special exit, skip over this step
			table.insert(currentPath, mmp.speedWalkDir[index])
			currentIds[#currentIds + 1] = mmp.speedWalkPath[index]
			index = index + 1
		end
	end
	mmp.speedWalkDir = currentPath
	mmp.speedWalkPath = currentIds
	return true
end

-- a certain version of the mapper gave us special exits prepended with 0 or 1 in the command
-- depending on if it was locked. Need to remove these before we can use them

function mmp.fixSpecialExits(directions)
	for i = 1, #directions do
		if directions[i]:match("^%d") then
			directions[i] = directions[i]:sub(2)
		end
	end
end

-- cleanup function to remove the temp special exit we made

function mmp.clearspecials(deleterooms)
	local t = getSpecialExits(mmp.currentroom)
	for connectingroom, exits in pairs(t) do
		if table.contains(deleterooms, connectingroom) then
			-- delete the special exits linking to this room
			for command, locked in pairs(exits) do
				removeSpecialExit(mmp.currentroom, command)
			end
		end
	end
end

function mmp.getShortestOfMultipleRooms(possibleRooms)
	local shortestWeight, closestRoom = 10000000, 0
	local checkedsofar, outoftime = 0, false
	local getStopWatchTime, tonumber = getStopWatchTime, tonumber

	-- allocate only 500ms to finding the shortest path, or more if we failed to find anything
	mmp.computeShortestWatch = mmp.computeShortestWatch or createStopWatch()
	startStopWatch(mmp.computeShortestWatch)
	raiseEvent("mmp link externals")

	-- mmp.echo(string.format("Have %s rooms nodes, %ss taken so far...", table.size(possibleRooms), getStopWatchTime(mmp.computeShortestWatch)))
	for _, id in pairs(possibleRooms) do
		local possible, thisWeight = getPath(mmp.currentroom, tonumber(id))
		if possible and thisWeight < shortestWeight then
			shortestWeight = thisWeight
			closestRoom = tonumber(id)
		end
		checkedsofar = checkedsofar + 1
		if getStopWatchTime(mmp.computeShortestWatch) >= 0.5 then
			outoftime = true
			break
		end

		-- mmp.echo(string.format("pathed from %s to %s, running time so far: %s", mmp.currentroom, id, getStopWatchTime(mmp.computeShortestWatch)))
	end
	--mmp.echo(string.format("total time took: %s", getStopWatchTime(mmp.computeShortestWatch)))
	stopStopWatch(mmp.computeShortestWatch)
	return closestRoom, outoftime, checkedsofar
end

function mmp.gotoAreaID(areaid, number, dashtype)
	if not areaid or not tonumber(areaid) then
		mmp.echo("To where do you want to go?")
		return
	end
	areaid = tonumber(areaid)
	if not mmp.areatabler[areaid] then
		mmp.echo("Invalid area ID selected")
		return
	end
	local possibleRooms, shortestBorder = {}, 0
	for id, _ in pairs(mmp.getAreaBorders(areaid)) do
		possibleRooms[#possibleRooms + 1] = id
	end
	shortestBorder, outoftime, checkedsofar = mmp.getShortestOfMultipleRooms(possibleRooms)
	if shortestBorder == 0 then
		if outoftime then
			mmp.echo(
				string.format(
					'I checked %d of the %d possible exits "%s" has, but none of the ways there worked and it was taking too long :( try doing this again?',
					checkedsofar,
					table.size(possibleRooms),
					getRoomAreaName(areaid)
				)
			)
		else
			mmp.echo(
				"Checked "
					.. table.size(possibleRooms)
					.. " exits in that area, and none of them worked :( I Don't know how to get you there."
			)
		end
		mmp.speedWalkPath = {}
		mmp.speedWalkDir = {}
		mmp.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		raiseEvent("mmp clear externals")
		return
	end
	raiseEvent("mmp clear externals")
	mmp.gotoRoom(shortestBorder, dashtype, "area")
end

function mmp.gotoFeature(partialFeatureName, dashtype)
	local mapFeatures = mmp.getMapFeatures()
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
		mmp.echo("No feature like " .. partialFeatureName .. " found.")
		return
	end
	local possibleRooms = searchRoomUserData("feature-" .. feature, "true")
	closestFeature, outoftime, checkedsofar = mmp.getShortestOfMultipleRooms(possibleRooms)
	if closestFeature == 0 then
		if outoftime then
			mmp.echo(
				string.format(
					'I checked %d of the %d possible features "%s" has, but none of the ways there worked and it was taking too long :( try doing this again?',
					checkedsofar,
					table.size(possibleRooms),
					partialFeatureName
				)
			)
		else
			mmp.echo(
				"Checked "
					.. table.size(possibleRooms)
					.. " rooms with that feature, and none of them worked :( I Don't know how to get you there."
			)
		end
		mmp.speedWalkPath = {}
		mmp.speedWalkDir = {}
		mmp.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		raiseEvent("mmp clear externals")
		return
	end
	raiseEvent("mmp clear externals")
	mmp.gotoRoom(closestFeature, dashtype, "room")
end
