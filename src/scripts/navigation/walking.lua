-- Core walking mechanics

-- The watchdog on a move the game never answers.
--
-- Every step of a walk is driven by the room change GMCP sends when the move
-- lands, so a move that is swallowed - a dropped packet, a command the server
-- never acted on - leaves the walk waiting for a message that will not come.
-- One timer per step catches that: the first time it fires the move is sent
-- again, the second time the walk is given up on rather than left hanging.

local watchdog   -- the timer waiting on the move we last sent
local watchroom  -- the room we were in when we sent it
local retried    -- this step has already been sent a second time

function mapper.disarmwatchdog()
	if watchdog then
		killTimer(watchdog)
		watchdog = nil
	end
end

-- A step really landed, so the next one gets its own two tries.
function mapper.resetwatchdog()
	retried = false
end

local function movetimedout(waited, what)
	watchdog = nil
	-- The walk ended, or the move landed after all, while the timer ran
	if not mapper.autowalking or mapper.currentroom ~= watchroom then
		return
	end

	if retried then
		mapper.notify(string.format("No reply to %s after %gs. Stopped walking.", what, waited))
		mapper.endwalk("failed")
		return
	end

	retried = true
	mapper.notify(string.format("No reply to %s after %gs - trying it again.", what, waited))
	mapper.move()
end

-- Start the wait for the move we just sent. `extra` is time the game has
-- already told us to expect on top of the usual wait, as a delayed exit does.
function mapper.armwatchdog(what, extra)
	mapper.disarmwatchdog()
	if not mapper.autowalking then
		return
	end

	local timeout = mapper.settings and mapper.settings.walktimeout
	if type(timeout) ~= "number" then
		timeout = 5
	end
	-- getNetworkLatency reports seconds, and a laggy connection is exactly when
	-- a reply is slowest rather than missing
	local latency = getNetworkLatency and getNetworkLatency() or 0
	if type(latency) ~= "number" or latency < 0 then
		latency = 0
	end

	local waited = timeout + (tonumber(extra) or 0)
	what = what or (mapper.speedWalkDir and mapper.speedWalkDir[mapper.speedWalkCounter]) or "that move"
	watchroom = mapper.currentroom
	watchdog = tempTimer(waited + latency, function() movetimedout(waited, what) end)
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
	if not mapper.autowalking or not mapper.canmove() then
		return
	end
	-- sometimes it's 0 - default to 1
	if mapper.speedWalkCounter == 0 then
		mapper.speedWalkCounter = 1
	end

	-- Check if we have a valid direction to move
	if not mapper.speedWalkDir or not mapper.speedWalkDir[mapper.speedWalkCounter] then
		if mapper.debugging() then
			mapper.notify("No more directions to walk, stopping.")
		end
		mapper.autowalking = false
		return
	end

	local cmd = mapper.speedWalkDir[mapper.speedWalkCounter] or ""
	local shown = cmd
	if string.starts(cmd, "script:") then
		loadstring((string.gsub(cmd, "script:", "")))()
		shown = "<script>"
	else
		send(cmd, false)
	end
	if mapper.settings.showcmds then
		cecho(
			string.format(
				"<red>(<maroon>%d - <dark_slate_grey>%s<red>)",
				#mapper.speedWalkDir - mapper.speedWalkCounter + 1,
				shown
			)
		)
	end
	-- Movement continues when GMCP room change event fires - or, if it does not,
	-- when this runs out
	mapper.armwatchdog(shown)
end

-- Every way a walk ends. What it leaves behind is the same whichever way it was
-- - no path, no counter, no balance poll and no highlight - so only the message
-- and the event told the rest of the profile differ. "failed" says nothing of
-- its own: the caller has just printed why, and two messages would be worse than
-- one. Outcomes: "arrived", "there" (we were already), "stopped", "failed".
function mapper.endwalk(outcome)
	local walktime = mapper.speedWalkWatch and stopStopWatch(mapper.speedWalkWatch)
	mapper.speedWalkPath = {}
	mapper.speedWalkDir = {}
	mapper.speedWalkCounter = 0
	mapper.autowalking = false
	-- Left running, the balance poll goes on prompting a walk that has ended
	if mapper.balancetimer then
		killTimer(mapper.balancetimer)
		mapper.balancetimer = nil
	end
	-- and the watchdog goes on waiting for a move nobody is making
	mapper.disarmwatchdog()
	mapper.resetwatchdog()
	mapper.clearPathHighlight()

	if outcome == "arrived" then
		if type(walktime) == "number" then
			mapper.notify(string.format("We've arrived! Took us %.1fs.\n", walktime))
		else
			mapper.notify("We've arrived!")
		end
		raiseEvent("mapper arrived")
	elseif outcome == "there" then
		mapper.echo("We're already at the destination!")
		raiseEvent("mapper arrived")
	elseif outcome == "stopped" then
		mapper.notify("Stopped walking.")
		raiseEvent("mapper stopped")
	else
		raiseEvent("mapper failed path")
	end
end

function mapper.stop()
	if not mapper.autowalking and #mapper.speedWalkPath == 0 then
		mapper.echo("We're not walking anywhere.")
		return
	end
	mapper.endwalk("stopped")
end

-- Willowdale and other games can implement their own balance checking.
--
-- If we cannot move yet, poll until we can. One timer at a time and only while
-- a walk is actually running: every blocked move used to arm its own, so
-- several chains ran at once and went on prompting after mstop.

function mapper.canmove(fromtimer)
	if fromtimer then
		mapper.balancetimer = nil
	end

	if mapper.mapperCanMove and not mapper.mapperCanMove() then
		if mapper.autowalking and not mapper.balancetimer then
			mapper.balancetimer = tempTimer(0.2, [[mapper.canmove(true)]])
		end
		return false
	end

	if fromtimer then
		mapper.move()
	end
	return true
end

-- Mudlet hands the route over in two flat lists, of commands and of room IDs,
-- so a copy of one is a copy of its elements.
local function copylist(list)
	local copy = {}
	for i = 1, #list do
		copy[i] = list[i]
	end
	return copy
end

-- doSpeedWalk is used by the mudlet mapping script and should not be changed
-- This function defines doSpeedWalk and can be called to redefine it after
-- removing conflicting packages like generic_mapper
function mapper.defineDoSpeedWalk()
doSpeedWalk = function()
	mapper.speedWalkDir = copylist(speedWalkDir)
	mapper.speedWalkPath = copylist(speedWalkPath)
	speedWalkDir, speedWalkPath = {}, {}
	-- Made here rather than at load: Mudlet will not create a stopwatch while
	-- it is loading scripts, and hands back nil instead. Without one the walk
	-- still runs, it just cannot say how long it took.
	mapper.speedWalkWatch = mapper.speedWalkWatch or createStopWatch()
	if mapper.speedWalkWatch then
		resetStopWatch(mapper.speedWalkWatch)
		startStopWatch(mapper.speedWalkWatch)
	end
	if #mapper.speedWalkPath == 0 then
		mapper.echo("Couldn't find a path to the destination :(")
		mapper.endwalk("failed")
		return
	end
	-- this is a fix: convert nums to actual numbers
	for i = 1, #mapper.speedWalkPath do
		mapper.speedWalkPath[i] = tonumber(mapper.speedWalkPath[i])
	end
	-- Check if we're already at the destination
	if mapper.currentroom == mapper.speedWalkPath[#mapper.speedWalkPath] then
		mapper.endwalk("there")
		return
	end

	mapper.autowalking = true
	mapper.resetwatchdog()

	-- Highlight the path on the map if enabled
	if mapper.settings.showspeedwalkpath then
		mapper.highlightPath(mapper.speedWalkPath, mapper.currentroom)
	end

	local destination = mapper.speedWalkPath[#mapper.speedWalkPath]
	mapper.echon("Starting speedwalk from " .. mapper.roomName(mapper.currentroom) .. " to ")
	cechoLink(
		"<yellow>" .. mapper.roomName(destination),
		'mapper.gotoRoom "' .. destination .. '"',
		"Go to " .. mapper.roomName(destination, true),
		true
	)
	echo(": ")
	mapper.speedWalkCounter = 1
	if mapper.canmove() then
		-- Start moving immediately (with delay if configured)
		local delay = mapper.settings.walkdelay
		if delay == nil then delay = 0.3 end
		mapper.delayedMove(delay)
	else
		echo("(when we get balance back / aren't hindered)")
	end
end
end

-- Define doSpeedWalk on load
mapper.defineDoSpeedWalk()
