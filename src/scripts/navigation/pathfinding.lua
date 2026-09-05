-- Path calculation and caching

-- Routes worked out once are kept, because a walk asks for the same one in
-- every room it passes through. They are dropped whenever something the
-- pathfinder reads changes: the map itself, a room or exit lock, a weight.
-- Locks also move from outside this script - Mudlet's own map menu, a
-- lockRoom() typed at the prompt, another package - and none of that says so,
-- so a cache hit is checked before it is handed out rather than trusted.
local getpathcache = {}

-- Whether every room and exit a kept route uses is still open to us. One
-- lookup per step, against a search across the whole map if it is not: worth
-- doing on every hit.
local function stillopen(from, dirs, rooms)
	if not dirs or not rooms or #rooms == 0 or #dirs ~= #rooms then
		return false
	end
	local previous = from
	for i = 1, #rooms do
		local room, dir = tonumber(rooms[i]), dirs[i]
		-- A room the map no longer has - deleted, or gone with a reloaded map -
		-- makes the rest of the route meaningless, and roomLocked would say false
		-- for it as readily as for one that is there.
		if not room or not roomExists(room) or roomLocked(room) then
			return false
		end
		if mapper.isStandardExit(dir) then
			if mapper.hasExitLock(previous, dir) then
				return false
			end
		elseif hasSpecialExitLock and hasSpecialExitLock(previous, room, dir) then
			return false
		end
		previous = room
	end
	return true
end

function mapper.getPath(from, to)
	assert(tonumber(from) and tonumber(to), "mapper.getPath: both from and to have to be room IDs")
	from, to = tonumber(from), tonumber(to)
	local key = string.format("%s_%s", from, to)
	local cached = getpathcache[key]
	if cached and stillopen(from, cached[1], cached[2]) then
		speedWalkDir, speedWalkPath = cached[1], cached[2]
		return true
	end

	-- The stopwatch only runs when its reading is going to be printed; left
	-- running it would report the time since the first path of the session.
	local debugging = mapper.debugging()
	if debugging then
		mapper.computeGetPath = mapper.computeGetPath or createStopWatch()
		if mapper.computeGetPath then
			startStopWatch(mapper.computeGetPath)
		end
	end
	local found = getPath(from, to)
	if debugging and mapper.computeGetPath then
		mapper.notify(
			"a new getPath() from " .. from .. " to " .. to .. " took " .. stopStopWatch(mapper.computeGetPath) .. "s."
		)
	end
	-- Only a route is worth keeping. A failure kept is a "there is no way
	-- there" that outlives the door being opened.
	getpathcache[key] = found and { speedWalkDir, speedWalkPath } or nil
	return found
end

function mapper.clearpathcache()
	if mapper.debugging() then
		mapper.notify("path cache cleared")
	end
	getpathcache = {}
end

-- Display the path directions between two rooms and optionally highlight on map
function mapper.echoPath(from, to)
	assert(tonumber(from) and tonumber(to), "mapper.echoPath: both from and to have to be room IDs")
	if mapper.getPath(from, to) then
		local fromName = mapper.roomName(from)
		local toName = mapper.roomName(to)
		mapper.echo("<white>Directions from <yellow>" .. fromName .. " <white>to <yellow>" .. toName .. "<white>:")
		mapper.echo(table.concat(speedWalkDir, ", "))
		-- Store destination for dynamic path updates
		mapper.showPathDestination = tonumber(to)
		-- The map menu's path entry now offers to clear this
		if mapper.refreshmapmenu then
			mapper.refreshmapmenu()
		end
		-- Highlight the path on the map
		if speedWalkPath then
			mapper.highlightPath(speedWalkPath, tonumber(from))
		end
		return speedWalkDir
	else
		local fromName = mapper.roomName(from)
		local toName = mapper.roomName(to)
		mapper.echo("<white>I can't find a way from <yellow>" .. fromName .. " <white>to <yellow>" .. toName .. "<white>")
	end
end

function mapper.getShortestOfMultipleRooms(possibleRooms)
	local shortestWeight, closestRoom = 10000000, 0
	local checkedsofar, outoftime = 0, false
	local getStopWatchTime, tonumber = getStopWatchTime, tonumber

	-- allocate only 500ms to finding the shortest path, or more if we failed to find anything.
	-- Mudlet can decline to make a stopwatch; without one there is no time cap,
	-- which beats erroring out of every `mapper goto <area>`.
	mapper.computeShortestWatch = mapper.computeShortestWatch or createStopWatch()
	local watch = mapper.computeShortestWatch
	if watch then
		startStopWatch(watch)
	end

	-- mapper.echo(string.format("Have %s rooms nodes, %ss taken so far...", table.size(possibleRooms), getStopWatchTime(mapper.computeShortestWatch)))
	for _, id in pairs(possibleRooms) do
		local possible, thisWeight = getPath(mapper.currentroom, tonumber(id))
		if possible and thisWeight < shortestWeight then
			shortestWeight = thisWeight
			closestRoom = tonumber(id)
		end
		checkedsofar = checkedsofar + 1
		if watch and getStopWatchTime(watch) >= 0.5 then
			outoftime = true
			break
		end

		-- mapper.echo(string.format("pathed from %s to %s, running time so far: %s", mapper.currentroom, id, getStopWatchTime(mapper.computeShortestWatch)))
	end
	--mapper.echo(string.format("total time took: %s", getStopWatchTime(mapper.computeShortestWatch)))
	if watch then
		stopStopWatch(watch)
	end
	return closestRoom, outoftime, checkedsofar
end
