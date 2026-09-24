-- Lock Area

mapper.locked = mapper.locked or {}
mapper.lastLockSearch = mapper.lastLockSearch or nil

-- Whether the player has locked an area against walks.
function mapper.arealocked(areaId)
	return (mapper.locked and mapper.locked[areaId]) and true or false
end

-- Whether an area's rooms should be locked: the areas the player locked, and
-- area 0, which is not a real area - leaving its rooms open to the pathfinder
-- was causing crashing issues.
function mapper.wantlocked(areaId)
	return areaId == 0 or mapper.arealocked(areaId)
end

-- Lock or unlock every room of an area. Returns how many rooms that was.
function mapper.lockarearooms(areaId, lock)
	local lockRoom = lockRoom
	local rooms = getAreaRooms1(areaId) or {}
	for i = 1, #rooms do
		lockRoom(rooms[i], lock)
	end
	return #rooms
end

function mapper.doLockArea(search)
	local areaList
	if search ~= nil then
		local r = rex.new(string.lower(search))
		mapper.lastLockSearch = search
		for name, id in pairs(getAreaTable()) do
			if mapper.islistablearea(id) and r:match(string.lower(name)) then
				areaList = areaList or {}
				areaList[name] = id
			end
		end
		if areaList == nil then
			mapper.echo("'" .. search .. "' did not match any known areas!")
			return
		end
	else
		mapper.lastLockSearch = nil
		areaList = {}
		for name, id in pairs(getAreaTable()) do
			if mapper.islistablearea(id) then
				areaList[name] = id
			end
		end
	end

	local names = {}
	for name in pairs(areaList) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)

	local rows = {}
	for _, name in ipairs(names) do
		local id = areaList[name]
		local locked = mapper.arealocked(id)
		rows[#rows + 1] = {
			name,
			{ text = locked and "Locked" or "Open", color = locked and { 255, 0, 0 } or { 0, 200, 0 } },
			locked
			and { text = "Unlock!", link = [[mapper.lockArea(]] .. id .. [[, false)]],
				hint = "Click to unlock area '" .. name .. "'", color = { 0, 200, 0 } }
			or { text = "Lock!", link = [[mapper.lockArea(]] .. id .. [[, true)]],
				hint = "Click to lock area '" .. name .. "'", color = { 180, 180, 0 } },
		}
	end

	mapper.printtable({
		{ title = "Area:" },
		{ title = "Status:" },
		{ title = "" },
	}, rows)

	if not search then
		mapper.echo("Use <green>mapper area lock <name><white> to lock one area by name.")
	end
end

-- Lock or unlock an area, named by ID or by name.
function mapper.lockArea(area, lock, dontreshow)
	local areaId = tonumber(area) or mapper.areaidbyname(area)
	if not areaId then
		mapper.echo("Don't know of any area named '" .. tostring(area) .. "'.")
		return
	end
	lock = lock and true or false
	local name = mapper.areaname(areaId) or tostring(area)

	local count = mapper.lockarearooms(areaId, lock)
	mapper.locked[areaId] = lock or nil

	-- Whether the pathfinder may enter this area just changed, so routes worked
	-- out before it are no good. Cleared once here rather than per room: an area
	-- runs to thousands of them.
	if count > 0 then
		mapper.clearpathcache()
	end
	-- The map carries the lock now; saying so in the map is what spares the
	-- next load from locking it all over again
	if mapper.marklocks then
		mapper.marklocks()
	end
	-- Locks live in the same file as the settings, so save them as they change
	if mapper.saveoptions then
		mapper.saveoptions()
	end
	if mapper.mapinfodirty then
		mapper.mapinfodirty()
	end
	mapper.echo(
		string.format(
			"Area '%s' %slocked! All %s room%s within it.",
			name,
			(lock and "" or "un"),
			count,
			(count == 1 and "" or "s")
		)
	)

	if not dontreshow then
		mapper.doLockArea(mapper.lastLockSearch)
	end
end

-- Lock or unlock an area by ID, or say that it already is.
function mapper.setarealock(areaId, lock)
	if mapper.arealocked(areaId) == lock then
		mapper.echo(string.format("Area '%s' is already %slocked.",
			mapper.areaname(areaId) or tostring(areaId), lock and "" or "un"))
		return
	end
	mapper.lockArea(areaId, lock, true)
end
