function mapper.filterRooms(rooms, area)
	local unassignedRooms = {}
	local areaRooms = {}
	for roomnum, roomname in pairs(rooms) do
		local roomarea = getRoomUserData(roomnum, "Game Area")
		if roomarea == "" then
			unassignedRooms[roomnum] = roomname
		elseif roomarea == area then
			areaRooms[roomnum] = roomname
		end
	end
	return next(areaRooms) and areaRooms or unassignedRooms
end

-- for a given room name, we'll echo all the vnums

function mapper.echonums(roomname, area)
	local t = mapper.searchRoomExact(roomname)
	if area then
		t = mapper.filterRooms(t, area)
	end
	if not next(t) then
		echo("?")
		return nil
	end
	-- transform the kv table into a table of tables for cleaner code.
	-- + perhaps Mudlet in future will give this us anyway, sorted by relevancy
	local dt = {}
	for roomid, room in pairs(t) do
		dt[#dt + 1] = { name = room, id = roomid }
	end
	-- we can have nothing if we asked for exact match
	if not dt[1] then
		echo("?---")
		return
	end
	-- display first three ids. Can't really nicely table.concat them.
	cechoLink(
		"<" .. mapper.settings.echocolour .. ">" .. dt[1].id,
		"mapper.gotoRoom(" .. dt[1].id .. ")",
		string.format("Go to %s (%s)", dt[1].id, dt[1].name),
		true
	)
	if not dt[2] then
		return
	end
	echo(", ")
	cechoLink(
		"<" .. mapper.settings.echocolour .. ">" .. dt[2].id,
		"mapper.gotoRoom(" .. dt[2].id .. ")",
		string.format("Go to %s (%s)", dt[2].id, dt[2].name),
		true
	)
	if not dt[3] then
		return
	end
	echo(", ")
	cechoLink(
		"<" .. mapper.settings.echocolour .. ">" .. dt[3].id,
		"mapper.gotoRoom(" .. dt[3].id .. ")",
		string.format("Go to %s (%s)", dt[3].id, dt[3].name),
		true
	)
	if not dt[4] then
		return
	end
	echo(", ...")
end

function mapper.roomEcho(query)
	local result = mapper.searchRoom(query)
	if not tonumber(select(2, next(result))) then
		for roomid, roomname in pairs(result) do
			roomid = tonumber(roomid)
			cecho("<DarkSlateGrey> (")
			cechoLink(
				"<" .. mapper.settings.echocolour .. ">" .. roomid,
				"mapper.gotoRoom(" .. roomid .. ")",
				string.format("Go to %s (%s)", roomid, tostring(roomname)),
				true
			)
			cecho("<DarkSlateGrey>)")
		end
	else
		for roomname, roomid in pairs(result) do
			roomid = tonumber(roomid)
			cecho("<DarkSlateGrey> (")
			cechoLink(
				"<" .. mapper.settings.echocolour .. ">" .. roomid,
				"mapper.gotoRoom(" .. roomid .. ")",
				string.format("Go to %s (%s)", roomid, tostring(roomname)),
				true
			)
			cecho("<DarkSlateGrey>)")
		end
	end
end

function mapper.locateAndEcho(room, person, area)
	local t = mapper.searchRoomExact(room)
	if area then
		t = mapper.filterRooms(t, area)
	end
	echo("  (")
	mapper.echonums(room, area)
	echo(")")
	-- lowercase results
	for k, v in pairs(t) do
		if tonumber(k) then
			t[k] = v:lower()
		else
			t[k:lower()] = v
		end
	end
	if not (t[room:lower()] or table.contains(t, room:lower())) then
		return
	end
	echo("\n")
	if table.size(t) == 1 then
		local k, v = next(t)
		cecho(
			"<red>From your knowledge, that room is in <orange_red>"
				.. mapper.cleanAreaName(mapper.areatabler[getRoomArea(type(k) == "number" and k or v)] or "?")
				.. "<red>."
		)
	else
		local k, v = next(t)
		local areas = {}
		if type(k) == "number" then
			for k, _ in pairs(t) do
				areas[mapper.areatabler[getRoomArea(k)] or "?"] = true
			end
		else
			for _, k in pairs(t) do
				areas[mapper.areatabler[getRoomArea(k)] or "?"] = true
			end
		end
		local flattened_areas = {}
		for k, _ in pairs(areas) do
			if k ~= "" then
				flattened_areas[#flattened_areas + 1] = mapper.cleanAreaName(k)
			end
		end
		cecho(
			"<red>From your knowledge, that room might be in <orange_red>"
				.. table.concat(flattened_areas, ", or ")
				.. "<red>."
		)
	end
	if person then
		mapper.pdb[person] = room
		mapper.pdb_lastupdate[person] = true
		raiseEvent("mmapper updated pdb")
	end
end

function mapper.locateAndEchoSide(room, person)
	local t = mapper.searchRoomExact(room)
	echo("  (")
	mapper.echonums(room)
	echo(")")
	-- lowercase results
	for k, v in pairs(t) do
		if tonumber(k) then
			t[k] = v:lower()
		else
			t[k:lower()] = v
		end
	end
	if not (t[room:lower()] or table.contains(t, room:lower())) then
		return
	end
	--echo"\n"
	if table.size(t) == 1 then
		local k, v = next(t)
		cecho(
			"<red>  (" .. mapper.cleanAreaName(mapper.areatabler[getRoomArea(type(k) == "number" and k or v)] or "?") .. ")"
		)
	else
		local k, v = next(t)
		local areas = {}
		if type(k) == "number" then
			for k, _ in pairs(t) do
				areas[mapper.areatabler[getRoomArea(k)] or "?"] = true
			end
		else
			for _, k in pairs(t) do
				areas[mapper.areatabler[getRoomArea(k)] or "?"] = true
			end
		end
		local flattened_areas = {}
		for k, _ in pairs(areas) do
			if k ~= "" then
				flattened_areas[#flattened_areas + 1] = mapper.cleanAreaName(k)
			end
		end
		cecho("<red> (" .. table.concat(flattened_areas, ", ") .. ")")
	end
	if person then
		mapper.pdb[person] = room
		mapper.pdb_lastupdate[person] = true
		raiseEvent("mmapper updated pdb")
	end
end

function mapper.locateAndEchoInternal(room, person)
	local t = mapper.searchRoomExact(room)
	-- lowercase results
	for k, v in pairs(t) do
		if tonumber(k) then
			t[k] = v:lower()
		else
			t[k:lower()] = v
		end
	end
	if not (t[room:lower()] or table.contains(t, room:lower())) then
		return
	end
	--echo"\n"
	if table.size(t) == 1 then
		local k, v = next(t)
		cecho(
			"<red> in " .. mapper.cleanAreaName(mapper.areatabler[getRoomArea(type(k) == "number" and k or v)] or "?") .. "."
		)
	else
		local k, v = next(t)
		local areas = {}
		if type(k) == "number" then
			for k, _ in pairs(t) do
				areas[mapper.areatabler[getRoomArea(k)] or "?"] = true
			end
		else
			for _, k in pairs(t) do
				areas[mapper.areatabler[getRoomArea(k)] or "?"] = true
			end
		end
		local flattened_areas = {}
		for k, _ in pairs(areas) do
			if k ~= "" then
				flattened_areas[#flattened_areas + 1] = mapper.cleanAreaName(k)
			end
		end
		cecho("<red> in " .. table.concat(flattened_areas, ", ") .. ".")
	end
	echo("  (")
	mapper.echonums(room, true)
	echo(")")
	if person then
		mapper.pdb[person] = room
		mapper.pdb_lastupdate[person] = true
		raiseEvent("mmapper updated pdb")
	end
end
