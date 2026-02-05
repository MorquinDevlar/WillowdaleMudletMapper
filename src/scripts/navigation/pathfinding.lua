-- Path calculation and caching

-- DOES NOT ACCOUNT FOR CHANGING THE MAP YET (within a profile load), because we don't know when it happens
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

registerAnonymousEventHandler("mapper updated map", "mapper.clearpathcache")

-- Display the path directions between two rooms and optionally highlight on map
function mapper.echoPath(from, to)
	assert(tonumber(from) and tonumber(to), "mapper.echoPath: both from and to have to be room IDs")
	if mapper.getPath(from, to) then
		local fromName = getRoomName(from) or tostring(from)
		local toName = getRoomName(to) or tostring(to)
		mapper.echo("<white>Directions from <yellow>" .. string.upper(fromName) .. " <white>to <yellow>" .. string.upper(toName) .. "<white>:")
		mapper.echo(table.concat(speedWalkDir, ", "))
		-- Store destination for dynamic path updates
		mapper.showPathDestination = tonumber(to)
		-- Highlight the path on the map
		if speedWalkPath then
			mapper.highlightPath(speedWalkPath, tonumber(from))
		end
		return speedWalkDir
	else
		local fromName = getRoomName(from) or tostring(from)
		local toName = getRoomName(to) or tostring(to)
		mapper.echo("<white>I can't find a way from <yellow>" .. string.upper(fromName) .. " <white>to <yellow>" .. string.upper(toName) .. "<white>")
	end
end

function mapper.getShortestOfMultipleRooms(possibleRooms)
	local shortestWeight, closestRoom = 10000000, 0
	local checkedsofar, outoftime = 0, false
	local getStopWatchTime, tonumber = getStopWatchTime, tonumber

	-- allocate only 500ms to finding the shortest path, or more if we failed to find anything
	mapper.computeShortestWatch = mapper.computeShortestWatch or createStopWatch()
	startStopWatch(mapper.computeShortestWatch)
	raiseEvent("mapper link externals")

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
