-- Lock Area

mapper.locked = mapper.locked or {}
mapper.lastLockSearch = mapper.lastLockSearch or nil

function mapper.doLockArea(search)
	local areaList
	if search ~= nil then
		local r = rex.new(string.lower(search))
		mapper.lastLockSearch = search
		for name, id in pairs(getAreaTable()) do
			if r:match(string.lower(name)) then
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
		areaList = getAreaTable()
	end

	for name, id in pairs(areaList) do
		mapper.echon(name .. string.rep(" ", 40 - string.len(name)))
		if not mapper.locked[id] then
			setFgColor(0, 200, 0)
			setUnderline(true)
			echoLink(
				"Lock!",
				[[mapper.lockArea( ']] .. name:gsub("'", [[\']]) .. [[', true )]],
				"Click to lock area '" .. name .. "'",
				true
			)
		else
			setFgColor(200, 0, 0)
			setUnderline(true)
			echoLink(
				"Unlock!",
				[[mapper.lockArea( ']] .. name:gsub("'", [[\']]) .. [[', false )]],
				"Click to unlock area '" .. name .. "'",
				true
			)
		end
	end

	if not search then
		echo("\n\n")
		mapper.echo("Use <green>arealock <area><white> to filter areas.")
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

	mapper.locked[areas[name]] = lock and true or nil
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
