-- Lock Area

mapper.locked = mapper.locked or {}
mapper.lastLockSearch = mapper.lastLockSearch or nil

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
		local quoted = name:gsub("'", [[\']])
		local locked = mapper.locked[id] and true or false
		rows[#rows + 1] = {
			name,
			{ text = locked and "Locked" or "Open", color = locked and { 255, 0, 0 } or { 0, 200, 0 } },
			locked
			and { text = "Unlock!", link = [[mapper.lockArea( ']] .. quoted .. [[', false )]],
				hint = "Click to unlock area '" .. name .. "'", color = { 0, 200, 0 } }
			or { text = "Lock!", link = [[mapper.lockArea( ']] .. quoted .. [[', true )]],
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

function mapper.lockArea(name, lock, dontreshow)
	local areas = getAreaTable()
	local rooms = getAreaRooms(areas[name]) or {}
	local lockRoom = lockRoom
	local count = 0
	for _, room in pairs(rooms) do
		lockRoom(room, lock)
		count = count + 1
	end

	-- Whether the pathfinder may enter this area just changed, so routes worked
	-- out before it are no good. Cleared once here rather than per room: an area
	-- runs to thousands of them.
	if count > 0 then
		mapper.clearpathcache()
	end

	mapper.locked[areas[name]] = lock and true or nil
	-- Locks live in the same file as the settings, so save them as they change
	if mapper.saveoptions then
		mapper.saveoptions()
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
