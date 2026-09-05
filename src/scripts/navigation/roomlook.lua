-- Search for rooms by name
function mapper.roomFind(query, lines)
	if query:ends(".") then
		query = query:sub(1, -2)
	end
	local defaultLine = 30
	local result = searchRoom(query)
	if type(result) == "string" or not next(result) then
		mapper.echo("You have no recollection of any room with that name.")
		return
	end
	local found = table.size(result)
	if lines == "all" then
		lines = found
	end
	lines = (lines ~= "") and tonumber(lines) or defaultLine

	-- searchRoom answers with room ID -> name, but has answered name -> room ID
	-- in the past; either way round, a row is the ID, the name and the area.
	local byid = tonumber(select(2, next(result))) == nil
	local roomsTable = {}
	for k, v in pairs(result) do
		local id = tonumber(byid and k or v)
		roomsTable[#roomsTable + 1] = {
			num = id,
			name = tostring(byid and v or k),
			area = (mapper.areatabler and mapper.areatabler[getRoomArea(id)]) or "unknown",
		}
	end
	table.sort(roomsTable, function(a, b)
		if a.area ~= b.area then
			return a.area < b.area
		end
		return a.name < b.name
	end)

	local rows = {}
	for _, room in ipairs(roomsTable) do
		if #rows >= lines then
			break
		end
		rows[#rows + 1] = {
			{
				text = tostring(room.num),
				link = "mapper.gotoRoom(" .. room.num .. ")",
				hint = string.format("Go to %s (%s)", room.num, room.name),
			},
			room.name,
			{
				text = room.area,
				link = [[mapper.echoPath(mapper.currentroom, ]] .. room.num .. [[)]],
				hint = "Display directions from here to " .. room.name,
			},
		}
	end

	mapper.printtable({
		{ title = "ID:" },
		{ title = "Name:" },
		{ title = "Area:" },
	}, rows, { title = "You know the following relevant rooms:" })

	if found <= lines then
		mapper.echo(string.format("%d rooms found.", found))
	else
		mapper.lastRoomQuery = query
		-- The table left the cursor on a line of its own, so the link can start
		-- here; it is echoed rather than printed as a row because it is one line
		-- about the table rather than another row of it.
		cechoLink(
			string.format("<dim_grey>%d of %d rooms shown. Click to see all rooms.", lines, found),
			'mapper.roomFind(mapper.lastRoomQuery, "all")',
			string.format("Show all %d rooms.", found),
			true
		)
		echo("\n")
	end
end

-- List all rooms in an area
function mapper.echoRoomList(areaname, exact)
	local areaid, msg, multiples = mapper.findAreaID(areaname, exact)
	if areaid then
		-- getAreaRooms1, not getAreaRooms: the latter starts at index 0, which
		-- table.sort leaves out and so prints one room out of order
		local roomlist, endresult = getAreaRooms1(areaid) or {}, {}
		local getRoomName = getRoomName
		for _, id in ipairs(roomlist) do
			endresult[id] = getRoomName(id)
		end
		table.sort(roomlist)
		local rows = {}
		for _, roomid in ipairs(roomlist) do
			local roomname = tostring(endresult[roomid])
			rows[#rows + 1] = {
				{
					text = tostring(roomid),
					link = "mapper.gotoRoom(" .. roomid .. ")",
					hint = string.format("Go to %s (%s)", roomid, roomname),
				},
				roomname,
			}
		end

		mapper.printtable({
			{ title = "ID:" },
			{ title = "Name:" },
		}, rows, {
			title = string.format("List of all rooms in %s (areaid %s - %d rooms):",
				msg, areaid, table.size(endresult)),
		})
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

-- Write a label on the map, at the room the player is in or at one named by ID.
-- Every label is drawn alike, so the whole of the text is the label rather than
-- the first words of it being read as colour names.
function mapper.roomLabel(input)
	local tk = input:split(" ")
	local room, message = mapper.currentroom, "Some room label"
	-- input always have to be something, so tk[1] at least always exists
	if tonumber(tk[1]) and #tk > 1 then
		room = tonumber(table.remove(tk, 1))
	end
	if tk[1] then
		message = table.concat(tk, " ")
	end
	-- if we haven't provided a room ID and we don't know where we are yet, we can't make a label
	if not room or not roomExists(room) then
		mapper.echo("We don't know where we are to make a label here.")
		return
	end
	local x, y, z = getRoomCoordinates(room)
	local f1, f2, f3 = unpack(color_table.yellow)
	local b1, b2, b3 = unpack(color_table.red)
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
		mapper.printfields({
			{ "Room:", name },
			{ "ID:", num },
			{ "Area:", string.format("%s (%d)",
				tostring(mapper.areatabler and mapper.areatabler[areanum] or "?"), areanum) },
			{ "Coordinates:", string.format("x:%d, y:%d, z:%d", coords[1], coords[2], coords[3]) },
			{ "Locked:", islocked and "yep" or "nope" },
			{ "Weight:", tostring(weight) },
			{ "Environment:", string.format("%s (%d)%s", tostring(envname), env,
				(getRoomUserData(num, "indoors") ~= "" and ", indoors" or "")) },
		})

		-- Where an exit leads, the area it lands in and what it costs a walk are
		-- columns of their own rather than parentheses trailing off the line
		local exitrows = {}
		for exit, leadsto in pairs(exits) do
			local exitweight = exitweights[mapper.dirdoor(exit)]
			exitrows[#exitrows + 1] = {
				exit,
				string.format("%s (%d)", tostring(getRoomName(leadsto)), leadsto),
				tostring(mapper.areatabler and mapper.areatabler[getRoomArea(leadsto)] or "?"),
				(not exitweight or exitweight == 0) and "" or tostring(exitweight),
			}
		end
		table.sort(exitrows, function(a, b)
			return a[1] < b[1]
		end)
		mapper.printtable({
			{ title = "Exit:" },
			{ title = "Leads to:" },
			{ title = "Area:" },
			{ title = "Weight:", align = "right" },
		}, exitrows, { title = string.format("Exits (%d):", table.size(exits)) })

		-- display special exits if we got any
		if next(specexits) then
			local specialrows = {}
			local function specialrow(command, leadsto, locked)
				specialrows[#specialrows + 1] = {
					tostring(command),
					string.format("%s (%d)", tostring(getRoomName(leadsto)), leadsto),
					tostring(mapper.areatabler and mapper.areatabler[getRoomArea(leadsto)] or "?"),
					locked and "locked" or "",
				}
			end
			for leadsto, command in pairs(specexits) do
				if type(command) == "string" then
					specialrow(command, leadsto, false)
				else
					-- new format - exit name, command
					for cmd, locked in pairs(command) do
						specialrow(cmd, leadsto, locked == "1")
					end
				end
			end
			table.sort(specialrows, function(a, b)
				return a[1] < b[1]
			end)
			mapper.printtable({
				{ title = "Exit:" },
				{ title = "Leads to:" },
				{ title = "Area:" },
				{ title = "Status:" },
			}, specialrows, { title = string.format("Special exits (%d):", table.size(specexits)) })
		end
		local tags = mapper.roomtags(num)
		if #tags > 0 then
			mapper.echo(string.format("Tags (%d): %s", #tags, table.concat(tags, ", ")))
		end
		-- actions we can do. This will be a short menu of sorts for actions
		mapper.echo("Stuff you can do:")
		echo("  ")
		setUnderline(true)
		echoLink("Check for mapper updates", 'mapper.echo("Checking...") mapper.checkupdateverbose()', "", true)
		setUnderline(false)
		echo("\n")
	end

	-- see if we can do anything with the name

	local function handle_name(name)
		local result = searchRoom(name)
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
