-- Destination navigation functions

-- Center the map view on an area
function mapper.viewArea(where, exact)
	if not where or type(where) ~= "string" then
		mapper.echo("Which area would you like to view?")
		return
	end
	local areaid, msg, multiples = mapper.findAreaID(where, exact)
	if areaid then
		-- getAreaRooms1, not getAreaRooms: the latter starts at index 0, so a
		-- one-room area looked empty here
		local rooms = getAreaRooms1(areaid) or {}
		if not rooms[1] then
			mapper.echo("The area has no rooms in it.")
		else
			centerview(rooms[1])
		end
	elseif multiples and #multiples > 0 then
		mapper.echo("Which area would you like to view exactly?")
		fg("DimGrey")
		for _, areaname in ipairs(multiples) do
			echo("  ")
			setUnderline(true)
			echoLink(areaname, 'mapper.viewArea("' .. areaname .. '", true)', "Click to view " .. areaname, true)
			setUnderline(false)
			echo("\n")
		end
		resetFormat()
		return
	else
		mapper.echo(string.format("Don't know of any area named '%s'.", where))
		return
	end
end

function mapper.gotoRoom(where)
	if not where or not tonumber(where) then
		mapper.echo("Where do you want to go to?")
		return
	end
	if tonumber(where) == mapper.currentroom then
		mapper.echo("We're already at " .. mapper.roomName(where, true) .. "!")
		raiseEvent("mapper arrived")
		return
	end
	-- if getPath worked, then the dirs and room #'s tables were populated for us
	if not mapper.getPath(mapper.currentroom, tonumber(where)) then
		mapper.echo("Don't know how to get to " .. mapper.roomName(where, true) .. " from here :(")
		mapper.endwalk("failed")
		return
	end
	doSpeedWalk()
end

function mapper.gotoArea(where, number, exact)
	if not where or type(where) ~= "string" then
		mapper.echo("Where do you want to go to?")
		return
	end
	local where = where:lower()
	number = tonumber(number)
	local areaid, _, multiples = mapper.findAreaID(where, exact)
	if areaid then
		mapper.gotoAreaID(areaid)
	elseif not areaid and #multiples > 0 then
		if number and number <= #multiples then
			mapper.gotoArea(multiples[number], nil, true)
			return
		end
		mapper.echo("Which area would you like to go to?")
		fg("DimGrey")
		for key, areaname in ipairs(multiples) do
			echo("  ")
			echoLink(
				key .. ") ",
				'mapper.gotoArea("' .. areaname .. '", nil, true)',
				"Click to go to " .. areaname,
				true
			)
			setUnderline(true)
			echoLink(
				areaname,
				'mapper.gotoArea("' .. areaname .. '", nil, true)',
				"Click to go to " .. areaname,
				true
			)
			setUnderline(false)
			echo("\n")
		end
		resetFormat()
		return
	else
		mapper.echo(string.format("Don't know of any area named '%s'.", where))
		return
	end
end

function mapper.gotoAreaID(areaid)
	if not areaid or not tonumber(areaid) then
		mapper.echo("To where do you want to go?")
		return
	end
	areaid = tonumber(areaid)
	local areaName = getRoomAreaName(areaid)
	if not areaName or areaName == "" then
		mapper.echo("Invalid area ID selected")
		return
	end
	-- Check if the area is locked
	if mapper.locked and mapper.locked[areaid] then
		mapper.echo("The area '" .. areaName .. "' is locked. Unlock it first with: mapper area unlock " .. areaName)
		return
	end
	local possibleRooms = {}
	for id, _ in pairs(mapper.getAreaBorders(areaid)) do
		possibleRooms[#possibleRooms + 1] = id
	end
	mapper.gotoNearest(possibleRooms, string.format('into "%s"', areaName))
end

-- Walk to whichever of several rooms is quickest to reach - the ways into an
-- area, or the rooms carrying a tag. `description` finishes the sentence
-- "none of the ways ... worked" for the case where none of them can be reached.
function mapper.gotoNearest(candidateRooms, description)
	local closest, outoftime, checkedsofar = mapper.getShortestOfMultipleRooms(candidateRooms)
	if closest ~= 0 then
		mapper.gotoRoom(closest)
		return
	end

	local total = table.size(candidateRooms)
	if outoftime then
		mapper.echo(string.format(
			"I checked %d of the %d ways %s, but none of them worked and it was taking too long :( try doing this again?",
			checkedsofar,
			total,
			description
		))
	else
		mapper.echo(string.format(
			"Checked all %d ways %s, and none of them worked :( I don't know how to get you there.",
			total,
			description
		))
	end
	mapper.endwalk("failed")
end
