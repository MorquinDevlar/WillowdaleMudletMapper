-- GMCP Room Info handler for mapping new rooms

function mapper.createFirstRoom(roomId, areaName, x, y, z)
	-- Ensure environment colors are set (may have been cleared if map was deleted)
	if mapper.setEnvironmentColors then
		mapper.setEnvironmentColors()
	end

	-- Create area if needed
	local areaId = mapper.findOrCreateArea(areaName)
	if not areaId then
		mapper.notify("Failed to create area for first room")
		return false
	end

	-- Create the room
	addRoom(roomId)
	setRoomCoordinates(roomId, x, y, z)
	setRoomArea(roomId, areaId)

	-- Set room name from GMCP
	local roomName = gmcp.Room.Info.Basic.name or "Unknown"
	setRoomName(roomId, roomName)

	-- Set environment/biome if available, otherwise the neutral default
	local envId
	if gmcp.Room.Info.Basic.biome_color then
		envId = mapper.getBiomeEnvId(gmcp.Room.Info.Basic.biome_color)
	end
	setRoomEnv(roomId, envId or mapper.defaultroomenv())

	-- Store where the game says this room lives
	mapper.storeroomorigin(roomId, areaName, gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.area)

	-- Update mapper state
	mapper.currentroom = roomId
	mapper.currentroomname = roomName
	mapper.editing = true

	centerview(roomId)
	if mapper.settings and mapper.settings.showmappingmessages then
		mapper.notify("Created first room! Mapping is now enabled.")
	end
	return true
end

-- Bring the map's idea of a room in line with what GMCP says about it: create
-- it if it is new, place it, file it under its area, and link its exits.
function mapper.mappingnewroom(num)
	local ok, err = xpcall(function()
		if not gmcp.Room then
			mapper.notify("You need to have GMCP turned on (see preferences on a recent Mudlet) for mapping stuff.")
			return
		end
		local getRoomName, getRoomCoordinates = getRoomName, getRoomCoordinates
		num = tonumber(num) or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and tonumber(gmcp.Room.Info.Basic.id))
		local currentexits = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Exits or {}

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
		local currentRoomZone = gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.area
		local coordZone, currentRoomX, currentRoomY, currentRoomZ
		if gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.coordinates and gmcp.Room.Info.Basic.coordinates ~= "" then
			-- Try with spaces pattern
			coordZone, currentRoomX, currentRoomY, currentRoomZ =
				gmcp.Room.Info.Basic.coordinates:match("([^,]+), ([^,]+), ([^,]+), ([^,]+)")

			-- If that fails, try without spaces
			if not (coordZone and currentRoomX and currentRoomY and currentRoomZ) then
				coordZone, currentRoomX, currentRoomY, currentRoomZ =
					gmcp.Room.Info.Basic.coordinates:match("([^,]+),([^,]+),([^,]+),([^,]+)")
			end

			if coordZone and currentRoomX and currentRoomY and currentRoomZ then
				currentRoomX, currentRoomY, currentRoomZ =
					tonumber(currentRoomX), tonumber(currentRoomY), tonumber(currentRoomZ)

				-- The coordinate prefix is the zone, and it is all there is to go on if
				-- the server is old enough not to send the two names apart.
				currentRoomZone = (currentRoomZone ~= "" and currentRoomZone) or coordZone
				currentRoomArea = currentRoomArea or coordZone

				if mapper.debugging() then
					mapper.notify(string.format("Parsed coordinates for room %d: area='%s', zone='%s', x=%d, y=%d, z=%d",
						num, tostring(currentRoomArea), tostring(currentRoomZone), currentRoomX, currentRoomY, currentRoomZ))
				end

				-- Update the current room's coordinates if they're different
				-- Only do this if autopositionrooms is enabled
				if mapper.settings.autopositionrooms and mapper.roomexists(num) then
					local mx, my, mz = getRoomCoordinates(num)
					if mx ~= currentRoomX or my ~= currentRoomY or mz ~= currentRoomZ then
						if mapper.debugging() then
							mapper.notify(string.format("Moving room %d from (%d,%d,%d) to (%d,%d,%d)",
								num, mx, my, mz, currentRoomX, currentRoomY, currentRoomZ))
						end
						setRoomCoordinates(num, currentRoomX, currentRoomY, currentRoomZ)
						mapper.storeroomorigin(num, currentRoomArea, currentRoomZone)
						note(string.format("Repositioned room to %d,%d,%d.", currentRoomX, currentRoomY, currentRoomZ), true)
					end
				end
			else
				if mapper.debugging() then
					mapper.notify("Failed to parse coordinates from: " .. (gmcp.Room.Info.Basic.coordinates or "nil"))
				end
			end
		end

		if not mapper.roomexists(num) then
			-- Check if this is the first room (empty map with GMCP coordinates)
			if mapper.isMapEmpty() and currentRoomX and currentRoomY and currentRoomZ and currentRoomArea then
				if mapper.createFirstRoom(num, currentRoomArea, currentRoomX, currentRoomY, currentRoomZ) then
					topology = true
				end
			-- If we have GMCP coordinates, use them directly to create the room
			-- This handles moving to new areas via special exits (e.g., "touch tree")
			elseif currentRoomX and currentRoomY and currentRoomZ and currentRoomArea then
				-- Ensure environment colors are set (may have been cleared if map was deleted)
				if mapper.setEnvironmentColors then
					mapper.setEnvironmentColors()
				end

				-- Create or find the area
				local areaId = mapper.findOrCreateArea(currentRoomArea)
				if areaId then
					addRoom(num)
					setRoomCoordinates(num, currentRoomX, currentRoomY, currentRoomZ)
					setRoomArea(num, areaId)
					mapper.storeroomorigin(num, currentRoomArea, currentRoomZone)

					-- Set biome color if available, otherwise the neutral default
					local envId
					if gmcp.Room.Info.Basic.biome_color then
						envId = mapper.getBiomeEnvId(gmcp.Room.Info.Basic.biome_color)
					end
					setRoomEnv(num, envId or mapper.defaultroomenv())

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
		if mapper.roomexists(num) then
			-- keep the room name in step with what the game reports
			local rootroomname = (gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.name) or ""
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
					setRoomArea(num, areaId)
					mapper.storeroomorigin(num, currentRoomArea, currentRoomZone)
					note("Moved room into area '" .. currentRoomArea .. "'.", true)
				end
			end
			-- autolink exits
			local x = getRoomExits(num) or {}
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
							and currentRoomY
							and currentRoomZ
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
								mapper.storeroomorigin(id, targetAreaId and targetZone or nil, targetZone)
							else
								mapper.storeroomorigin(id, currentRoomArea, nil)
							end
						end
					end
					-- Check if this is a standard exit or a special exit
					if mapper.isStandardExit(exit) then
						if mapper.setExit(num, id, exit) then
							note("Added missing exit "
								.. exit
								.. " to "
								.. (getRoomName(id) ~= "" and getRoomName(id) or "''")
								.. " ("
								.. id
								.. ").", true)
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
						local existingSpecialExits = getSpecialExitsSwap(num) or {}
						local knownDestination = tonumber(existingSpecialExits[exit])
						if not knownDestination then
							addSpecialExit(num, id, exit)
							note("Added special exit '"
								.. exit
								.. "' to "
								.. (getRoomName(id) ~= "" and getRoomName(id) or "''")
								.. " ("
								.. id
								.. ").", true)
						elseif knownDestination ~= tonumber(id) then
							removeSpecialExit(num, exit)
							addSpecialExit(num, id, exit)
							note("Special exit '"
								.. exit
								.. "' now leads to "
								.. (getRoomName(id) ~= "" and getRoomName(id) or "''")
								.. " ("
								.. id
								.. ").", true)
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
			if gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.biome_color then
				local envId = mapper.getBiomeEnvId(gmcp.Room.Info.Basic.biome_color)
				if envId and envId ~= getRoomEnv(num) then
					setRoomEnv(num, envId)
					note("Updated room color to " .. gmcp.Room.Info.Basic.biome_color .. ".")
				end
			end
			-- check indoors status
			local indoors = gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.details and table.contains(gmcp.Room.Info.Basic.details, "indoors")
			if indoors and (getRoomUserData(num, "indoors") == "" or getRoomUserData(num, "outdoors") ~= "") then
				setRoomUserData(num, "indoors", "y")
				clearRoomUserDataItem(num, "outdoors")
				note("Updated room to be indoors.")
			elseif
				not indoors and (getRoomUserData(num, "indoors") ~= "" or getRoomUserData(num, "outdoors") == "")
			then
				clearRoomUserDataItem(num, "indoors")
				setRoomUserData(num, "outdoors", "y")
				note("Updated room to be outdoors.")
			end

			-- Willowdale can add game area tracking here if needed
		end
		if #report > 0 and mapper.settings and mapper.settings.showmappingmessages then
			mapper.notify(report)
		end
		if topology then
			raiseEvent("mapper updated map")
		end
	end, function(error)
		mapper.notify("Oops! Had a small problem (" .. error .. ").")
		echo("  ")
		echoLink("view steps", "echo[[" .. debug.traceback() .. "]]", "View steps of code that led up to it")
	end)
	if not ok then
		mapper.notify(err)
	end
end

-- What the game says about the kind of place a room is, kept on the room itself
-- and drawn as its character when the roomchar setting asks for it. Stored on
-- every arrival rather than only while mapping: the data belongs to the room
-- whether or not new rooms are being created.
function mapper.storebiome(num)
	local basic = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic
	local environment = basic and basic.environment
	if not environment or environment == "" then
		return
	end
	local symbol = basic.biome_symbol or ""

	if getRoomUserData(num, "biome") ~= environment then
		setRoomUserData(num, "biome", environment)
	end
	if getRoomUserData(num, "biome_symbol") ~= symbol then
		setRoomUserData(num, "biome_symbol", symbol)
	end

	-- What a room costs to cross follows from its biome, so it is set where the
	-- biome is stored. A weight change is a change to the pathfinding graph.
	if mapper.applyterrain(num, environment) then
		raiseEvent("mapper updated map")
	end

	-- What the room draws is one rule shared with tagging and the roomchar
	-- setting, so that they cannot each leave a different character behind.
	mapper.refreshroomsymbol(num)
end
