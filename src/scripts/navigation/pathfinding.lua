-- Path calculation and caching

-- The route worked out last, kept because it is so often asked for again at
-- once: a walk that has strayed works out the way back and then starts walking
-- it, and `mapper goto <area>` finds the nearest way in and then walks to it.
-- One route rather than every route asked for: a player walking by hand under
-- showpath used to add one per room, each carrying its whole list of rooms.
-- It is dropped whenever something the pathfinder reads changes: the map
-- itself, a room or exit lock, a weight. Locks also move from outside this
-- script - Mudlet's own map menu, a lockRoom() typed at the prompt, another
-- package - and none of that says so, so it is checked before it is handed out
-- rather than trusted.
local last

-- Whether every room and exit of a route from rooms[first] on is still open to
-- us, setting out from `from`. One lookup per step, against a search across the
-- whole map if it is not: worth doing whenever a route is reused.
function mapper.routeopen(from, dirs, rooms, first)
	first = first or 1
	if not dirs or not rooms or first > #rooms or #dirs ~= #rooms then
		return false
	end
	local previous = from
	for i = first, #rooms do
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

-- Keep a route as the one worked out last. Mudlet hands its rooms over as
-- strings; they are kept as numbers, which is what everything reading them
-- compares room IDs as.
function mapper.rememberpath(from, to, dirs, rooms)
	local numbers = {}
	for i = 1, #rooms do
		numbers[i] = tonumber(rooms[i])
	end
	last = { from = from, to = to, dirs = dirs, rooms = numbers }
	return last
end

function mapper.getPath(from, to)
	assert(tonumber(from) and tonumber(to), "mapper.getPath: both from and to have to be room IDs")
	from, to = tonumber(from), tonumber(to)
	if last and last.from == from and last.to == to and mapper.routeopen(from, last.dirs, last.rooms) then
		speedWalkDir, speedWalkPath = last.dirs, last.rooms
		return true
	end

	local found = mapper.timed("getPath", function(elapsed)
		return "a new getPath() from " .. from .. " to " .. to .. " took " .. elapsed .. "s."
	end, getPath, from, to)
	-- Only a route is worth keeping. A failure kept is a "there is no way
	-- there" that outlives the door being opened.
	if found then
		speedWalkPath = mapper.rememberpath(from, to, speedWalkDir, speedWalkPath).rooms
	else
		last = nil
	end
	return found
end

function mapper.clearpathcache()
	if mapper.debugging() then
		mapper.notify("path cache cleared")
	end
	last = nil
end

-- Display the path directions between two rooms and optionally highlight on map
function mapper.echoPath(from, to)
	assert(tonumber(from) and tonumber(to), "mapper.echoPath: both from and to have to be room IDs")
	local fromName = mapper.roomName(from)
	local toName = mapper.roomName(to)
	if not mapper.getPath(from, to) then
		mapper.echo("<white>I can't find a way from <yellow>" .. fromName .. " <white>to <yellow>" .. toName .. "<white>")
		return
	end

	mapper.echo("<white>Directions from <yellow>" .. fromName .. " <white>to <yellow>" .. toName .. "<white>:")
	mapper.echo(table.concat(speedWalkDir, ", "))
	-- Store destination for dynamic path updates, and the route, which a
	-- player walking it by hand is followed along
	mapper.showPathDestination = tonumber(to)
	mapper.showPathRoute = { dirs = speedWalkDir, rooms = speedWalkPath, first = 1 }
	-- The map menu's path entry now offers to clear this
	if mapper.refreshmapmenu then
		mapper.refreshmapmenu()
	end
	-- Highlight the path on the map
	mapper.highlightPath(speedWalkPath, tonumber(from))
	return speedWalkDir
end

function mapper.getShortestOfMultipleRooms(possibleRooms)
	local shortestWeight, closestRoom = 10000000, 0
	local bestDirs, bestRooms
	local checkedsofar, outoftime = 0, false
	local getStopWatchTime, tonumber = getStopWatchTime, tonumber
	local from = mapper.currentroom

	-- allocate only 500ms to finding the shortest path, or more if we failed to find anything.
	-- Mudlet can decline to make a stopwatch; without one there is no time cap,
	-- which beats erroring out of every `mapper goto <area>`.
	mapper.computeShortestWatch = mapper.computeShortestWatch or createStopWatch()
	local watch = mapper.computeShortestWatch
	if watch then
		startStopWatch(watch)
	end

	for _, id in pairs(possibleRooms) do
		local room = tonumber(id)
		local possible, thisWeight = getPath(from, room)
		if possible and thisWeight < shortestWeight then
			shortestWeight = thisWeight
			closestRoom = room
			-- Mudlet gives every search tables of its own, so these stay as
			-- they are while the next ones are tried
			bestDirs, bestRooms = speedWalkDir, speedWalkPath
		end
		checkedsofar = checkedsofar + 1
		if watch and getStopWatchTime(watch) >= 0.5 then
			outoftime = true
			break
		end
	end
	if watch then
		stopStopWatch(watch)
	end

	-- The walk to the nearest one goes by the route just found, so it is kept
	-- rather than searched for again
	if bestDirs then
		mapper.rememberpath(from, closestRoom, bestDirs, bestRooms)
	end
	return closestRoom, outoftime, checkedsofar
end
