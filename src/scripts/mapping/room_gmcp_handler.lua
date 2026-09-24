-- GMCP Room Info handler for mapping new rooms

-- Bring the map's idea of a room in line with what GMCP says about it: create
-- it if it is new, place it, file it under its area, and link its exits.
-- Returns the room's user data as it stands afterwards, so the rest of the
-- arrival does not have to read it again, or nil if the room is not on the map.
function mapper.mappingnewroom(num)
	local ok, result = xpcall(function()
		if not gmcp.Room then
			mapper.notify("You need to have GMCP turned on (see preferences on a recent Mudlet) for mapping stuff.")
			return
		end
		local getRoomName, getRoomCoordinates = getRoomName, getRoomCoordinates
		local basic = gmcp.Room.Info and gmcp.Room.Info.Basic
		num = tonumber(num) or (basic and tonumber(basic.id))
		local currentexits = gmcp.Room.Info and gmcp.Room.Info.Exits or {}

		-- What this pass did, and whether any of it changed the shape of the map.
		-- A room, an exit, a lock or a room's area moving makes routes worked out
		-- earlier worthless; a name, a colour, a symbol or an indoors flag does
		-- not, and saying so for one of those threw the whole path cache away on
		-- every step of a walk through rooms being seen for the first time.
		local report, topology = "", false
		local function note(what, changedshape)
			report = report .. (#report > 0 and " " or "") .. what
			if changedshape then
				topology = true
			end
		end

		-- The room's user data, read once, the first time something needs it,
		-- and kept in step with what this pass writes
		local data
		local function roomdata()
			data = data or getAllRoomUserData(num) or {}
			return data
		end

		-- Debug: Show what exits we received from GMCP
		if mapper.debugging() then
			local exitList = {}
			for exit, exitData in pairs(currentexits) do
				table.insert(exitList, string.format("%s->%d", exit, exitData.room_id))
			end
			if #exitList > 0 then
				mapper.notify("GMCP exits for room " .. tostring(num) .. ": " .. table.concat(exitList, ", "))
			else
				mapper.notify("No GMCP exits received for room " .. tostring(num))
			end
		end

		-- GMCP coordinate handling for Willowdale
		-- The coordinate string is prefixed with the room's zone, but the area a room
		-- is filed under is the map that zone belongs to, which GMCP sends separately
		-- as area_name (see mapper.gmcpareaname).
		local currentRoomArea = mapper.gmcpareaname()
		local currentRoomZone = basic and basic.area
		local currentRoomX, currentRoomY, currentRoomZ
		local coordinates = basic and basic.coordinates
		if coordinates and coordinates ~= "" then
			-- "zone, x, y, z", with or without the spaces
			local coordZone, x, y, z = coordinates:match("([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+)")
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if coordZone and x and y and z then
				currentRoomX, currentRoomY, currentRoomZ = x, y, z

				-- The coordinate prefix is the zone, and it is all there is to go on if
				-- the server is old enough not to send the two names apart.
				currentRoomZone = (currentRoomZone ~= "" and currentRoomZone) or coordZone
				currentRoomArea = currentRoomArea or coordZone

				if mapper.debugging() then
					mapper.notify(string.format("Parsed coordinates for room %d: area='%s', zone='%s', x=%d, y=%d, z=%d",
						num, tostring(currentRoomArea), tostring(currentRoomZone), x, y, z))
				end

				-- Update the current room's coordinates if they're different
				-- Only do this if autopositionrooms is enabled
				if mapper.settings.autopositionrooms and mapper.roomexists(num) then
					local mx, my, mz = getRoomCoordinates(num)
					if mx ~= x or my ~= y or mz ~= z then
						if mapper.debugging() then
							mapper.notify(string.format("Moving room %d from (%d,%d,%d) to (%d,%d,%d)",
								num, mx, my, mz, x, y, z))
						end
						setRoomCoordinates(num, x, y, z)
						mapper.storeroomorigin(num, currentRoomArea, currentRoomZone, roomdata())
						note(string.format("Repositioned room to %d,%d,%d.", x, y, z), true)
					end
				end
			elseif mapper.debugging() then
				mapper.notify("Failed to parse coordinates from: " .. coordinates)
			end
		end

		if not mapper.roomexists(num) then
			-- If we have GMCP coordinates, use them directly to create the room.
			-- This is also how the first room of an empty map is made, and how a
			-- room reached through a special exit (e.g., "touch tree") is placed.
			if currentRoomX and currentRoomArea then
				-- Ensure environment colors are set (may have been cleared if map was deleted)
				if mapper.setEnvironmentColors then
					mapper.setEnvironmentColors()
				end

				local areaId = mapper.findOrCreateArea(currentRoomArea)
				if areaId then
					mapper.createroom(num, currentRoomX, currentRoomY, currentRoomZ, areaId, mapper.biomeenv(basic))
					-- A room made a moment ago carries no data yet
					data = {}
					mapper.storeroomorigin(num, currentRoomArea, currentRoomZone, data)

					local made = string.format("Created room %d at %d,%d,%d in %s.", num, currentRoomX, currentRoomY, currentRoomZ, currentRoomArea)
					note(made, true)

					if mapper.debugging() then
						mapper.notify(made)
					end
				end
			-- otherwise place it next to a room we already know. This room has
			-- `exit` leading to that one, so it sits one step the other way from it.
			else
				for exit, exitData in pairs(currentexits) do
					local id = exitData.room_id
					-- Only use standard exits for coordinate calculation
					if mapper.roomexists(id) and mapper.isStandardExit(exit) then
						local x, y, z = mapper.shiftcoords(mapper.dirreverse(exit), getRoomCoordinates(id))
						if x then
							note(mapper.makeroom(id, num, x, y, z), true)
							break -- Room created, exit the loop
						end
					end
				end
			end
		end
		-- if we created it, and some data could be filled in
		if not mapper.roomexists(num) then
			return nil
		end

		-- keep the room name in step with what the game reports
		local rootroomname = (basic and basic.name) or ""
		-- the game sends the name as it should be shown, so it is stored verbatim
		if getRoomName(num) ~= rootroomname then
			setRoomName(num, rootroomname)
			unHighlightRoom(num)
			note("Updated room name to '" .. rootroomname .. "'.")
		end
		-- File the room under the area GMCP reports for it. A room mapped ahead of
		-- the player, from an exit alone, was placed with the room it was seen from
		-- or under the zone that exit named; standing in it is the first moment the
		-- map it really belongs to is known, so that is when it is moved.
		if mapper.settings.autocreateareas and currentRoomArea then
			local areaId = mapper.findOrCreateArea(currentRoomArea)
			if areaId and getRoomArea(num) ~= areaId then
				mapper.fileroom(num, areaId)
				mapper.storeroomorigin(num, currentRoomArea, currentRoomZone, roomdata())
				note("Moved room into area '" .. currentRoomArea .. "'.", true)
			end
		end
		-- autolink exits
		local x = getRoomExits(num) or {}
		-- The room's special exits by command, read when the first one is needed
		local special
		-- check for missing exits
		for exit, exitData in pairs(currentexits) do
			local id = exitData.room_id
			local longname = mapper.dirlong(exit)
			if id == 0 then
				-- The game says there is a way out here but will not name the
				-- room on the other side. A stub is exactly that: the map draws
				-- the exit as one nobody has been through, instead of drawing
				-- nothing and reading as a wall.
				if mapper.isStandardExit(exit) then
					if mapper.setExitStub(num, exit, true) then
						note("Marked the " .. exit .. " exit as unexplored.", true)
					end
				else
					note("Can't link to the " .. exit .. ", it leads to a room with ID 0 (and that's not supported yet).")
				end
			elseif not (longname and x[longname]) then
				if not mapper.roomexists(id) then
					-- Check if exit leads out of this map
					local targetZone = exitData.details and exitData.details.leads_to_area
					local targetAreaId = mapper.exitareaid(targetZone)

					-- Check if we should use absolute positioning from delta data or standard directional positioning
					local newX, newY, newZ
					if
						mapper.settings.autopositionrooms
						and exitData.delta_x
						and exitData.delta_y
						and exitData.delta_z
						and currentRoomX
					then
						-- Use absolute positioning from GMCP delta data
						-- Delta values match Mudlet's coordinate system directly (no inversion needed)
						newX = currentRoomX + exitData.delta_x
						newY = currentRoomY + exitData.delta_y
						newZ = currentRoomZ + exitData.delta_z

						if mapper.debugging() then
							mapper.notify(string.format("Creating room %d at (%d,%d,%d) using delta (%d,%d,%d) from room %d at (%d,%d,%d)",
								id, newX, newY, newZ, exitData.delta_x, exitData.delta_y, exitData.delta_z,
								num, currentRoomX, currentRoomY, currentRoomZ))
						end
					else
						-- Nothing to go on but the direction: the room is reached BY
						-- `exit` from here, so it sits one step along `exit`.
						newX, newY, newZ = mapper.shiftcoords(exit, getRoomCoordinates(num))
					end

					if newX then
						note(mapper.makeroom(num, id, newX, newY, newZ, targetAreaId), true)

						-- The zone is all an exit tells us about the room on the other
						-- side; its area is only recorded once that zone is known to name
						-- one, or once the room is entered.
						if targetZone then
							mapper.storeroomorigin(id, targetAreaId and targetZone or nil, targetZone, {})
						else
							mapper.storeroomorigin(id, currentRoomArea, nil, {})
						end
					end
				end
				-- Check if this is a standard exit or a special exit
				if mapper.isStandardExit(exit) then
					if mapper.setExit(num, id, exit) then
						note("Added missing exit " .. exit .. " to " .. mapper.roomName(id, true) .. ".", true)
					else
						note(string.format("Failed to link %d with %d via %s exit for some reason :/", num, id, exit))
					end
				else
					-- This is a special exit (like "touch tree", "enter portal", etc.)
					-- Where the command goes can change - a gangway that leads to
					-- whichever dock the boat is at now, a portal that was mapped
					-- wrong once. Keeping the first destination we ever saw would
					-- send speedwalks to a room the command no longer reaches, so
					-- an exit that already exists is repointed rather than skipped.
					special = special or getSpecialExitsSwap(num) or {}
					local knownDestination = tonumber(special[exit])
					if not knownDestination then
						addSpecialExit(num, id, exit)
						note("Added special exit '" .. exit .. "' to " .. mapper.roomName(id, true) .. ".", true)
					elseif knownDestination ~= tonumber(id) then
						removeSpecialExit(num, exit)
						addSpecialExit(num, id, exit)
						note("Special exit '" .. exit .. "' now leads to " .. mapper.roomName(id, true) .. ".", true)
					end
				end
			end
		end
		-- check for unexisting exits
		if mapper.settings["autoclear"] then
			for exit, id in pairs(getRoomExits(num)) do
				-- getRoomExits returns exits in long form (e.g., "east", "west")
				-- currentexits from GMCP also uses long form as keys
				-- So we should check against the long form directly
				if not currentexits[exit] then
					mapper.setExit(num, -1, exit)
					note(exit .. " exit to " .. id .. " doesn't actually exist, removed it.", true)
				end
			end
			-- The same for the ways out the map only knows as unexplored:
			-- the game has stopped reporting them, so they are not there.
			if getExitStubs1 then
				for _, stub in ipairs(getExitStubs1(num) or {}) do
					local stubname = mapper.dirlong(stub)
					if stubname and not currentexits[stubname]
						and mapper.setExitStub(num, stub, false) then
						note("The unexplored " .. stubname .. " exit isn't there any more, removed it.", true)
					end
				end
			end
		end
		-- check for biome color update
		if basic and basic.biome_color then
			local envId = mapper.getBiomeEnvId(basic.biome_color)
			if envId and envId ~= getRoomEnv(num) then
				setRoomEnv(num, envId)
				note("Updated room color to " .. basic.biome_color .. ".")
			end
		end
		-- check indoors status: a room is one or the other, so the two flags
		-- change together
		local indoors = basic and basic.details and table.contains(basic.details, "indoors")
		local flags = roomdata()
		local changed
		if indoors then
			changed = mapper.setroomdata(num, flags, "indoors", "y")
			changed = mapper.clearroomdata(num, flags, "outdoors") or changed
		else
			changed = mapper.clearroomdata(num, flags, "indoors")
			changed = mapper.setroomdata(num, flags, "outdoors", "y") or changed
		end
		if changed then
			note(indoors and "Updated room to be indoors." or "Updated room to be outdoors.")
		end

		-- Willowdale can add game area tracking here if needed

		if #report > 0 and mapper.settings and mapper.settings.showmappingmessages then
			mapper.notify(report)
		end
		if topology then
			raiseEvent("mapper updated map")
		end
		return data
	end, function(error)
		mapper.notify("Oops! Had a small problem (" .. error .. ").")
		echo("  ")
		echoLink("view steps", "echo[[" .. debug.traceback() .. "]]", "View steps of code that led up to it")
	end)
	-- The error handler has already said what went wrong
	if not ok then
		return nil
	end
	return result
end

-- What the game says about the kind of place a room is, kept on the room itself
-- and drawn as its character when the roomchar setting asks for it. Stored on
-- every arrival rather than only while mapping: the data belongs to the room
-- whether or not new rooms are being created. Pass the room's user data when the
-- caller has already read it.
function mapper.storebiome(num, data)
	local basic = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic
	local environment = basic and basic.environment
	if not environment or environment == "" then
		return
	end
	data = data or getAllRoomUserData(num) or {}

	mapper.setroomdata(num, data, "biome", environment)
	mapper.setroomdata(num, data, "biome_symbol", basic.biome_symbol or "")

	-- The weight and the character both follow from the player's settings, so
	-- until those are loaded - an update's first half second, say - there is
	-- nothing right to set them to, and setting them from the defaults would
	-- undo what the map already carries. The room is settled once they are.
	if not mapper.optionsloaded then
		mapper.deferroom(num)
		return
	end

	-- What a room costs to cross follows from its biome, so it is set where the
	-- biome is stored. A weight change is a change to the pathfinding graph.
	if mapper.applyterrain(num, environment) then
		raiseEvent("mapper updated map")
	end

	-- What the room draws is one rule shared with tagging and the roomchar
	-- setting, so that they cannot each leave a different character behind.
	mapper.refreshroomsymbol(num, data)
end
