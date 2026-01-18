-- Search for rooms by name
function mapper.roomFind(query, lines)
	if query:ends(".") then
		query = query:sub(1, -2)
	end
	local defaultLine = 30
	local result = mapper.searchRoom(query)
	if lines == "all" then
		lines = table.size(result)
	end
	lines = (lines ~= "") and tonumber(lines) or defaultLine

	-- create a new table (roomsTable) with keys and add areas to the table
	local roomsTable = {}
	for k, v in pairs(result) do
		local a = (mapper.areatabler and mapper.areatabler[getRoomArea(k)]) or "unknown"
		roomsTable[#roomsTable + 1] = { num = k, area = a, name = v }
	end
	-- sort roomsTable by area name
	table.sort(roomsTable, function(a, b)
		return a.area < b.area
	end)
	-- start displaying info
	if type(result) == "string" or not next(result) then
		cecho("<grey>You have no recollection of any room with that name.")
		return
	end
	cecho("<DarkSlateGrey>You know the following relevant rooms:\n")

	local i = 1
	if not tonumber(select(2, next(result))) then
		cecho(string.format("<white> %-10s%-40s%s\n", "ROOM ID", "ROOM NAME", "ROOM AREA"))
		for _, v in ipairs(roomsTable) do
			if i > lines then
				break
			end
			local roomid = tonumber(v.num)
			local roomname = v.name
			local roomarea = v.area
			cechoLink(
				string.format("<yellow> %-10s", roomid),
				"mapper.gotoRoom(" .. roomid .. ")",
				string.format("Go to %s (%s)", roomid, tostring(roomname)),
				true
			)
			cecho(string.format("<LightSlateGray>%-40s", string.sub(tostring(roomname), 1, 39)))
			cechoLink(
				string.format(
					"<DarkSlateGrey>%s<DarkSlateGrey>\n",
					mapper.cleanAreaName(tostring(mapper.areatabler and mapper.areatabler[getRoomArea(roomid)] or "?"))
				),
				[[mapper.echoPath(mapper.currentroom, ]] .. roomid .. [[)]],
				"Display directions from here to " .. roomname,
				true
			)
			resetFormat()
			i = i + 1
		end
	else
		for roomname, roomid in pairs(result) do
			roomid = tonumber(roomid)
			cecho(string.format("  <LightSlateGray>%s<DarkSlateGrey> (", tostring(roomname)))
			cechoLink(
				"<yellow>" .. roomid,
				"mapper.gotoRoom(" .. roomid .. ")",
				string.format("Go to %s (%s)", roomid, tostring(roomname)),
				true
			)
			cecho(
				string.format(
					"<DarkSlateGrey>) in <LightSlateGray>%s<DarkSlateGrey>.",
					mapper.cleanAreaName(tostring(mapper.areatabler and mapper.areatabler[getRoomArea(roomid)] or "?"))
				)
			)
			fg("DarkSlateGrey")
			echoLink(
				" > Show path\n",
				[[mapper.echoPath(mapper.currentroom, ]] .. roomid .. [[)]],
				"Display directions from here to " .. roomname,
				true
			)
			resetFormat()
		end
	end
	if table.size(result) <= lines then
		cecho(string.format("<DarkSlateGrey>%d rooms found.\n", table.size(result)))
	else
		mapper.lastRoomQuery = query
		cechoLink(
			string.format("<DarkSlateGrey>%d of %d rooms shown. Click to see all rooms.\n", lines, table.size(result)),
			'mapper.roomFind(mapper.lastRoomQuery, "all")',
			string.format("Show all %d rooms.", table.size(result)),
			true
		)
	end
end

-- List all rooms in an area
function mapper.echoRoomList(areaname, exact)
	local areaid, msg, multiples = mapper.findAreaID(areaname, exact)
	if areaid then
		local roomlist, endresult = getAreaRooms(areaid) or {}, {}
		local getRoomName = getRoomName
		for _, id in pairs(roomlist) do
			endresult[id] = getRoomName(id)
		end
		table.sort(roomlist)
		cecho(
			string.format(
				"<DarkSlateGrey>List of all rooms in <grey>%s<DarkSlateGrey> (areaid <grey>%s<DarkSlateGrey> - <grey>%d<DarkSlateGrey> rooms):\n",
				msg,
				areaid,
				table.size(endresult)
			)
		)
		for _, roomid in pairs(roomlist) do
			local roomname = endresult[roomid]
			fg("blue")
			cechoLink(
				"<yellow>" .. string.format("%6s", roomid),
				"mapper.gotoRoom(" .. roomid .. ")",
				string.format("Go to %s (%s)", roomid, tostring(roomname)),
				true
			)
			cecho(string.format("<DarkSlateGrey>: <LightSlateGray>%s<DarkSlateGrey>.\n", roomname))
		end
	elseif multiples and #multiples > 0 then
		mapper.echo("For which area would you want to list rooms for?")
		fg("DimGrey")
		for _, areaname in ipairs(multiples) do
			echo("  ")
			setUnderline(true)
			echoLink(
				areaname,
				'mapper.echoRoomList("' .. areaname .. '", true)',
				"Click to view the room list for " .. areaname,
				true
			)
			setUnderline(false)
			echo("\n")
		end
		resetFormat()
	else
		mapper.echo(string.format("Don't know of any area named '%s'.", areaname))
	end
end

-- Clear all map labels in an area or the entire map
function mapper.clearLabels(areaid)
	local function clearlabels(aid)
		local t = getMapLabels(aid)
		if type(t) ~= "table" then
			return
		end
		for labelid, _ in pairs(t) do
			deleteMapLabel(aid, labelid)
		end
	end

	if areaid == "map" then
		for aid in pairs(mapper.areatabler or {}) do
			clearlabels(aid)
		end
		mapper.echo("Cleared labels in all of the map.")
		return
	end
	clearlabels(areaid)
	mapper.echo(string.format("Cleared all labels in '%s'.", mapper.areatabler and mapper.areatabler[areaid] or areaid))
end

-- Add a label to a room on the map
-- Usage: mapper.roomLabel("text") or mapper.roomLabel("roomid text") or mapper.roomLabel("roomid color text")
function mapper.roomLabel(input)
	if not createMapLabel then
		mapper.echo("Your Mudlet doesn't support createMapLabel() yet - please update.")
		return
	end
	local tk = input:split(" ")
	local room, fgcolor, bgcolor, message = mapper.currentroom, "yellow", "red", "Some room label"
	-- input always have to be something, so tk[1] at least always exists
	if tonumber(tk[1]) then
		room = tonumber(table.remove(tk, 1))
	end
	-- next: is this a foreground color?
	if tk[1] and color_table[tk[1]] then
		fgcolor = table.remove(tk, 1)
	end
	-- next: is this a background color?
	if tk[1] and color_table[tk[1]] then
		bgcolor = table.remove(tk, 1)
	end
	-- the rest would be our message
	if tk[1] then
		message = table.concat(tk, " ")
	end
	-- if we haven't provided a room ID and we don't know where we are yet, we can't make a label
	if not room then
		mapper.echo("We don't know where we are to make a label here.")
		return
	end
	local x, y, z = getRoomCoordinates(room)
	local f1, f2, f3 = unpack(color_table[fgcolor])
	local b1, b2, b3 = unpack(color_table[bgcolor])
	local lid = createMapLabel(getRoomArea(room), message, x, y, z, f1, f2, f3, b1, b2, b3)
	mapper.echo(string.format("Created new label #%d '%s' in %s.", lid, message, getRoomAreaName(getRoomArea(room))))
end

function mapper.roomlook(input)
	-- we can do a report with a number

	local function handle_number(num)
		-- compile all available data
		if not mapper.roomexists(num) then
			mapper.echo(num .. " doesn't seem to exist.")
			return
		end
		local s, areanum = pcall(getRoomArea, num)
		if not s then
			mapper.echo(areanum)
			return
		end
		local exits = getRoomExits(num)
		local name = getRoomName(num)
		local islocked = roomLocked(num)
		local weight = (getRoomWeight(num) and getRoomWeight(num) or "?")
		-- getRoomWeight is buggy in one of the versions, is actually linked to setRoomWeight and thus returns nil
		local exitweights = (getExitWeights and getExitWeights(num) or {})
		local coords = { getRoomCoordinates(num) }
		local specexits = getSpecialExits(num)
		local env = getRoomEnv(num)
		local envname = (mapper.envidsr and mapper.envidsr[env]) or "?"
		-- generate a report
		mapper.echo(string.format("Room: %s #: %d area: %s (%d)", name, num, tostring(mapper.areatabler and mapper.areatabler[areanum] or "?"), areanum))
		mapper.echo(
			string.format(
				"Coordinates: x:%d, y:%d, z:%d, locked: %s, weight: %s",
				coords[1],
				coords[2],
				coords[3],
				(islocked and "yep" or "nope"),
				tostring(weight)
			)
		)
		mapper.echo(
			string.format(
				"Environment: %s (%d)%s",
				tostring(envname),
				env,
				(getRoomUserData(num, "indoors") ~= "" and ", indoors" or "")
			)
		)
		mapper.echo(string.format("Exits (%d):", table.size(exits)))
		for exit, leadsto in pairs(exits) do
			echo(
				string.format(
					"  %s -> %s (%d)%s%s\n",
					exit,
					getRoomName(leadsto),
					leadsto,
					(
						(getRoomArea(leadsto) or "?") == areanum and ""
						or " (in " .. (mapper.areatabler and mapper.areatabler[getRoomArea(leadsto)] or "?") .. ")"
					),
					(
						(not exitweights[mapper.anytoshort(exit)] or exitweights[mapper.anytoshort(exit)] == 0) and ""
						or " (weight: " .. exitweights[mapper.anytoshort(exit)] .. ")"
					)
				)
			)
		end
		-- display special exits if we got any
		if next(specexits) then
			mapper.echo(string.format("Special exits (%d):", table.size(specexits)))
			for leadsto, command in pairs(specexits) do
				if type(command) == "string" then
					echo(string.format("  %s -> %s (%d)\n", command, getRoomName(leadsto), leadsto))
				else
					-- new format - exit name, command
					for cmd, locked in pairs(command) do
						if locked == "1" then
							cecho(
								string.format(
									"<DarkSlateGrey>  %s -> %s (%d) (locked)\n",
									cmd,
									getRoomName(leadsto),
									leadsto
								)
							)
						else
							echo(string.format("  %s -> %s (%d)\n", cmd, getRoomName(leadsto), leadsto))
						end
					end
				end
			end
		end
		local message = "This room has the feature '%s'."
		for _, mapFeature in pairs(mapper.getRoomMapFeatures(num)) do
			mapper.echo(string.format(message, mapFeature))
		end
		-- actions we can do. This will be a short menu of sorts for actions
		mapper.echo("Stuff you can do:")
		echo("  ")
		echo("Clear all labels ")
		setUnderline(true)
		echoLink("(in area)", "mapper.clearLabels(" .. areanum .. ")", "", true)
		setUnderline(false)
		echo(" ")
		setUnderline(true)
		echoLink(
			"(whole map)",
			[[
    if not mapper.clearinglabels then
      mapper.echo("Are you sure you want to clear all of your labels on this map? If yes, click the link again.")
      mapper.clearinglabels = true
    else
      mapper.clearLabels("map")
      mapper.clearinglabels = nil
    end
    ]],
			"",
			true
		)
		setUnderline(false)
		echo("\n")
		echo("  ")
		setUnderline(true)
		echoLink("Check for mapper updates", 'mapper.echo("Checking...") mapper.checkupdateverbose()', "", true)
		setUnderline(false)
		echo("\n")
	end

	-- see if we can do anything with the name

	local function handle_name(name)
		local result = mapper.searchRoom(name)
		if type(result) == "string" then
			cecho("<grey>You have no recollection of any room with that name.")
			return
		end
		-- if we got one result, then act on it
		if table.size(result) == 1 then
			if type(next(result)) == "number" then
				handle_number(next(result))
			else
				handle_number(select(2, next(result)))
			end
			return
		end
		-- if not, then ask the user to clarify which one would they want
		mapper.echo("Which room specifically would you like to look up?")
		if not select(2, next(result)) or not tonumber(select(2, next(result))) then
			for roomid, roomname in pairs(result) do
				roomid = tonumber(roomid)
				cecho(string.format("  <LightSlateGray>%s<DarkSlateGrey> (", tostring(roomname)))
				cechoLink(
					"<yellow>" .. roomid,
					"mapper.roomlook(" .. roomid .. ")",
					string.format("View room details for %s (%s)", roomid, tostring(roomname)),
					true
				)
				cecho(
					string.format(
						"<DarkSlateGrey>) in the <LightSlateGray>%s<DarkSlateGrey>.\n",
						tostring(mapper.areatabler and mapper.areatabler[getRoomArea(roomid)] or "?")
					)
				)
			end
		else
			for roomname, roomid in pairs(result) do
				roomid = tonumber(roomid)
				cecho(string.format("  <LightSlateGray>%s<DarkSlateGrey> (", tostring(roomname)))
				cechoLink(
					"<yellow>" .. roomid,
					"mapper.roomlook(" .. roomid .. ")",
					string.format("View room details for %s (%s)", roomid, tostring(roomname)),
					true
				)
				cecho(
					string.format(
						"<DarkSlateGrey>) in the <LightSlateGray>%s<DarkSlateGrey>.\n",
						tostring(mapper.areatabler and mapper.areatabler[getRoomArea(roomid)] or "?")
					)
				)
			end
		end
	end

	if not input then
		if not mapper.roomexists(mapper.currentroom) then
			mapper.echo(mapper.currentroom .. " doesn't seem to be mapped yet.")
			mapper.echo("Stuff you can do:")
			echo("  ")
			echoLink("Check for mapper updates", 'mapper.echo("Checking...") mapper.checkupdateverbose()', "")
			echo("\n")
			mapper.echo(string.format("version %s.", tostring(mapper.version)))
			return
		else
			input = mapper.currentroom
		end
	end
	if tonumber(input) then
		handle_number(tonumber(input))
	else
		handle_name(input)
	end
	mapper.echo(string.format("version %s.", tostring(mapper.version)))
end
