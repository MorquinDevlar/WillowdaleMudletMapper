-- How many rows a listing of rooms shows unless all of them are asked for.
-- Printing a row costs a line of clickable output, and an area or a search
-- on a large map can run to many thousands of rooms.
local DEFAULTLINES = 30

-- How many rows to show: every one when asked for "all", the number asked for,
-- or the default.
local function rowlimit(lines, total)
	if lines == "all" then
		return total
	end
	return tonumber(lines) or DEFAULTLINES
end

-- Under a listing cut short, how much of it was shown, as a link that runs
-- `code` to show the rest. Returns whether there was a rest to offer.
local function offerrest(shown, total, code)
	if total <= shown then
		return false
	end
	-- The table left the cursor on a line of its own, so the link can start
	-- here; it is echoed rather than printed as a row because it is one line
	-- about the table rather than another row of it.
	cechoLink(
		string.format("<dim_grey>%d of %d rooms shown. Click to see all rooms.", shown, total),
		code,
		string.format("Show all %d rooms.", total),
		true
	)
	echo("\n")
	return true
end

-- The rooms whose name matches `query`, as a list of { id, name }.
-- searchRoom answers with room ID -> name, but has answered name -> room ID
-- in the past; either way round it comes out the same here.
local function searchrooms(query)
	local result = searchRoom(query)
	local rooms = {}
	if type(result) ~= "table" then
		return rooms
	end
	for k, v in pairs(result) do
		local byid = type(k) == "number"
		local id = tonumber(byid and k or v)
		if id then
			rooms[#rooms + 1] = { id = id, name = tostring(byid and v or k) }
		end
	end
	return rooms
end

-- Search for rooms by name
function mapper.roomFind(query, lines)
	if query:ends(".") then
		query = query:sub(1, -2)
	end
	local found = searchrooms(query)
	if #found == 0 then
		mapper.echo("You have no recollection of any room with that name.")
		return
	end
	local total = #found
	lines = rowlimit(lines, total)

	-- A row is the ID, the name and the area; the area names are looked up
	-- once per area rather than once per room
	local areanames = {}
	for _, room in ipairs(found) do
		local areaid = getRoomArea(room.id)
		local area = areanames[areaid]
		if not area then
			area = mapper.areaname(areaid) or "unknown"
			areanames[areaid] = area
		end
		room.area = area
	end
	table.sort(found, function(a, b)
		if a.area ~= b.area then
			return a.area < b.area
		end
		return a.name < b.name
	end)

	local rows = {}
	for i = 1, math.min(lines, total) do
		local room = found[i]
		rows[i] = {
			{
				text = tostring(room.id),
				link = "mapper.gotoRoom(" .. room.id .. ")",
				hint = string.format("Go to %s (%s)", room.id, room.name),
			},
			room.name,
			{
				text = room.area,
				link = [[mapper.echoPath(mapper.currentroom, ]] .. room.id .. [[)]],
				hint = "Display directions from here to " .. room.name,
			},
		}
	end

	mapper.printtable({
		{ title = "ID:" },
		{ title = "Name:" },
		{ title = "Area:" },
	}, rows, { title = "You know the following relevant rooms:" })

	if total <= lines then
		mapper.echo(string.format("%d rooms found.", total))
	else
		mapper.lastRoomQuery = query
		offerrest(lines, total, 'mapper.roomFind(mapper.lastRoomQuery, "all")')
	end
end

-- List all rooms in an area
function mapper.echoRoomList(areaname, exact, lines)
	local areaid, _, multiples = mapper.findAreaID(areaname, exact)
	if areaid then
		mapper.echoAreaRooms(areaid, lines)
	elseif multiples and #multiples > 0 then
		mapper.offerareas("For which area would you want to list rooms for?", multiples,
			function(name) return string.format("mapper.echoRoomList(%q, true)", name) end,
			function(name) return "Click to view the room list for " .. name end)
	else
		mapper.echo(string.format("Don't know of any area named '%s'.", areaname))
	end
end

-- The rooms of an area by ID, in ID order: the first few, or all of them when
-- `lines` is "all".
function mapper.echoAreaRooms(areaid, lines)
	-- getAreaRooms1, not getAreaRooms: the latter starts at index 0, which
	-- table.sort leaves out and so prints one room out of order
	local roomlist = getAreaRooms1(areaid) or {}
	local total = #roomlist
	lines = rowlimit(lines, total)
	table.sort(roomlist)

	-- Names are only fetched for the rooms that are shown
	local getRoomName = getRoomName
	local rows = {}
	for i = 1, math.min(lines, total) do
		local roomid = roomlist[i]
		local roomname = tostring(getRoomName(roomid))
		rows[i] = {
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
			mapper.areaname(areaid) or "?", areaid, total),
	})
	offerrest(#rows, total, "mapper.echoAreaRooms(" .. areaid .. ', "all")')
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
	mapper.echo(string.format("Created new label #%d '%s' in %s.", lid, message, tostring(mapper.roomareaname(room))))
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
		local weight = getRoomWeight(num) or "?"
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
			{ "Area:", string.format("%s (%d)", mapper.areaname(areanum) or "?", areanum) },
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
				mapper.roomareaname(leadsto) or "?",
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
					mapper.roomareaname(leadsto) or "?",
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
		local found = searchrooms(name)
		if #found == 0 then
			cecho("<grey>You have no recollection of any room with that name.")
			return
		end
		-- if we got one result, then act on it
		if #found == 1 then
			handle_number(found[1].id)
			return
		end
		-- if not, then ask the user to clarify which one would they want
		mapper.echo("Which room specifically would you like to look up?")
		table.sort(found, function(a, b)
			return a.id < b.id
		end)
		for i = 1, math.min(#found, DEFAULTLINES) do
			local room = found[i]
			cecho(string.format("  <LightSlateGray>%s<DarkSlateGrey> (", room.name))
			cechoLink(
				"<yellow>" .. room.id,
				"mapper.roomlook(" .. room.id .. ")",
				string.format("View room details for %s (%s)", room.id, room.name),
				true
			)
			cecho(
				string.format(
					"<DarkSlateGrey>) in the <LightSlateGray>%s<DarkSlateGrey>.\n",
					mapper.roomareaname(room.id) or "?"
				)
			)
		end
		if #found > DEFAULTLINES then
			mapper.lastRoomQuery = name
			offerrest(DEFAULTLINES, #found, 'mapper.roomFind(mapper.lastRoomQuery, "all")')
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
