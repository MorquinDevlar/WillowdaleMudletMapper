-- Destination navigation functions

-- Center the map view on an area
function mapper.viewArea(where, exact)
	if not where or type(where) ~= "string" then
		mapper.echo("Which area would you like to view?")
		return
	end
	local areaid, msg, multiples = mapper.findAreaID(where, exact)
	if areaid then
		local rooms = getAreaRooms(areaid) or {}
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

function mapper.gotoRoom(where, gotoType)
	mapper.speedWalk.type = gotoType or "room"
	if not where or not tonumber(where) then
		mapper.echo("Where do you want to go to?")
		return
	end
	if tonumber(where) == mapper.currentroom then
		mapper.echo("We're already at " .. where .. "!")
		raiseEvent("mmapper arrived")
		return
	end
	-- allow mapper 'addons' to link their own exits in
	raiseEvent("mapper link externals")
	-- if getPath worked, then the dirs and room #'s tables were populated for us
	if not mapper.getPath(mapper.currentroom, tonumber(where)) then
		mapper.echo("Don't know how to get there (" .. tostring(where) .. ") from here :(")
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		-- allow mapper 'addons' to unlink their special exits
		raiseEvent("mapper clear externals")
		return
	end
	doSpeedWalk()
	-- allow mapper 'addons' to unlink their special exits
	raiseEvent("mapper clear externals")
end

function mapper.gotoArea(where, number, exact)
	mapper.speedWalk.type = "area"
	if not where or type(where) ~= "string" then
		mapper.echo("Where do you want to go to?")
		return
	end
	local where = where:lower()
	number = tonumber(number)
	local tmp = getRoomUserData(1, "gotoMapping")
	if not tmp or tmp == "" then
		tmp = "[]"
	end
	local temp, maptable = yajl.to_value(tmp), {}
	for k, v in pairs(temp) do
		maptable[k:lower()] = v
	end
	local destinationRoom = maptable[where]
	if destinationRoom then
		mapper.gotoRoom(destinationRoom)
		return
	end
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
	if areaLocked(areaid) then
		mapper.echo("The area '" .. areaName .. "' is locked. Unlock it first with: mapper area unlock " .. areaName)
		return
	end
	local possibleRooms, shortestBorder = {}, 0
	for id, _ in pairs(mapper.getAreaBorders(areaid)) do
		possibleRooms[#possibleRooms + 1] = id
	end
	local shortestBorder, outoftime, checkedsofar = mapper.getShortestOfMultipleRooms(possibleRooms)
	if shortestBorder == 0 then
		if outoftime then
			mapper.echo(
				string.format(
					'I checked %d of the %d possible exits "%s" has, but none of the ways there worked and it was taking too long :( try doing this again?',
					checkedsofar,
					table.size(possibleRooms),
					areaName
				)
			)
		else
			mapper.echo(
				"Checked "
					.. table.size(possibleRooms)
					.. " exits in that area, and none of them worked :( I Don't know how to get you there."
			)
		end
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		raiseEvent("mapper clear externals")
		return
	end
	raiseEvent("mapper clear externals")
	mapper.gotoRoom(shortestBorder, "area")
end

function mapper.gotoFeature(partialFeatureName)
	local mapFeatures = mapper.getMapFeatures()
	local feature
	if mapFeatures[partialFeatureName:lower()] then
		feature = partialFeatureName:lower()
	else
		for key in pairs(mapFeatures) do
			if key:find(partialFeatureName:lower()) then
				feature = key
				break
			end
		end
	end
	if not feature then
		mapper.echo("No feature like " .. partialFeatureName .. " found.")
		return
	end
	local possibleRooms = searchRoomUserData("feature-" .. feature, "true")
	local closestFeature, outoftime, checkedsofar = mapper.getShortestOfMultipleRooms(possibleRooms)
	if closestFeature == 0 then
		if outoftime then
			mapper.echo(
				string.format(
					'I checked %d of the %d possible features "%s" has, but none of the ways there worked and it was taking too long :( try doing this again?',
					checkedsofar,
					table.size(possibleRooms),
					partialFeatureName
				)
			)
		else
			mapper.echo(
				"Checked "
					.. table.size(possibleRooms)
					.. " rooms with that feature, and none of them worked :( I Don't know how to get you there."
			)
		end
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		raiseEvent("mmapper failed path")
		raiseEvent("mapper clear externals")
		return
	end
	raiseEvent("mapper clear externals")
	mapper.gotoRoom(closestFeature, "room")
end
