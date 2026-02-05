-- Core walking mechanics

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
	-- Clear path highlighting
	mapper.clearPathHighlight()
	mapper.echo("Stopped walking.")
	raiseEvent("mapper stopped")
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

-- doSpeedWalk is used by the mudlet mapping script and should not be changed
-- This function defines doSpeedWalk and can be called to redefine it after
-- removing conflicting packages like generic_mapper
function mapper.defineDoSpeedWalk()
doSpeedWalk = function()
	mapper.speedWalkDir = mapper.deepcopy(speedWalkDir)
	mapper.speedWalkPath = mapper.deepcopy(speedWalkPath)
	speedWalkDir, speedWalkPath = {}, {}
	resetStopWatch(mapper.speedWalkWatch)
	startStopWatch(mapper.speedWalkWatch)
	mapper.fixSpecialExits(mapper.speedWalkDir)
	if #mapper.speedWalkPath == 0 then
		mapper.autowalking = false
		mapper.echo("Couldn't find a path to the destination :(")
		raiseEvent("mapper failed path")
		return
	end
	-- this is a fix: convert nums to actual numbers
	for i = 1, #mapper.speedWalkPath do
		mapper.speedWalkPath[i] = tonumber(mapper.speedWalkPath[i])
	end
	-- Check if we're already at the destination
	if mapper.currentroom == mapper.speedWalkPath[#mapper.speedWalkPath] then
		mapper.echo("We're already at the destination!")
		raiseEvent("mapper arrived")
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		mapper.autowalking = false
		mapper.clearPathHighlight()
		return
	end

	mapper.autowalking = true
	raiseEvent("s")

	-- Highlight the path on the map if enabled
	if mapper.settings.showspeedwalkpath then
		mapper.highlightPath(mapper.speedWalkPath, mapper.currentroom)
	end

	if not mapper.paused then
		mapper.echon("Starting speedwalk from " .. (atcp.RoomNum or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.id)) .. " to ")
		cechoLink(
			"<yellow>" .. mapper.speedWalkPath[#mapper.speedWalkPath],
			'mapper.gotoRoom "' .. mapper.speedWalkPath[#mapper.speedWalkPath] .. '"',
			"Go to " .. mapper.speedWalkPath[#mapper.speedWalkPath],
			true
		)
		echo(": ")
		mapper.speedWalkCounter = 1
		if mapper.canmove() then
			mapper.hasty = true
			-- Start moving immediately (with delay if configured)
			local delay = mapper.settings.walkdelay
			if delay == nil then delay = 0.3 end
			mapper.delayedMove(delay)
		else
			echo("(when we get balance back / aren't hindered)")
		end
	else
		mapper.echo("Will go to " .. mapper.speedWalkPath[#mapper.speedWalkPath] .. " as soon as the mapper is unpaused.")
	end
end
end

-- Define doSpeedWalk on load
mapper.defineDoSpeedWalk()

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
	-- Clear path highlighting
	mapper.clearPathHighlight()
	-- No longer using movetimer, movement is GMCP-driven
	raiseEvent("mapper failed path")
end
