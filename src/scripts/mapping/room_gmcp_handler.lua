-- GMCP Room Info handler for mapping new rooms

function mapper.createFirstRoom(roomId, areaName, x, y, z)
	-- Ensure environment colors are set (may have been cleared if map was deleted)
	if mapper.setEnvironmentColors then
		mapper.setEnvironmentColors()
	end

	-- Create area if needed
	local areaId = mapper.findOrCreateArea(areaName)
	if not areaId then
		mapper.echo("Failed to create area for first room")
		return false
	end

	-- Create the room
	addRoom(roomId)
	setRoomCoordinates(roomId, x, y, z)
	setRoomArea(roomId, areaId)

	-- Set room name from GMCP
	local roomName = gmcp.Room.Info.Basic.name or "Unknown"
	setRoomName(roomId, roomName)

	-- Set environment/biome if available
	if gmcp.Room.Info.Basic.biome_color then
		local envId = mapper.getBiomeEnvId(gmcp.Room.Info.Basic.biome_color)
		if envId then
			setRoomEnv(roomId, envId)
		end
	end

	-- Store area data
	setRoomUserData(roomId, "Area", areaName)

	-- Update mapper state
	mapper.currentroom = roomId
	mapper.currentroomname = roomName
	mapper.editing = true

	centerview(roomId)
	if mapper.settings and mapper.settings.showmappingmessages then
		mapper.echo("Created first room! Mapping is now enabled.")
	end
	return true
end

function mapper.mappingnewroom(_, num)
	local s, m = xpcall(function()
		if not mapper.editing then
			return
		end
		if not gmcp.Room then
			mapper.echo("You need to have GMCP turned on (see preferences on a recent Mudlet) for mapping stuff.")
			return
		end
		-- wilderness mapping right now is UNFINISHED! It does not handle the grid breakup. So, please don't try it, and please won't whine about it.

		local function inwilderness()
			return (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.coordinates == "" and gmcp.Room.Info.Basic.area == "")
		end

		local getRoomName, getRoomCoordinates, getRoomsByPosition = getRoomName, getRoomCoordinates, getRoomsByPosition
		local num = tonumber(num) or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and tonumber(gmcp.Room.Info.Basic.id))
		local currentexits = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Exits or {}
		local s = ""
		
		-- Debug: Show what exits we received from GMCP
		if mapper.settings.debug then
			local exitList = {}
			for exit, exitData in pairs(currentexits) do
				table.insert(exitList, string.format("%s->%d", exit, exitData.room_id))
			end
			if #exitList > 0 then
				mapper.echo("GMCP exits for room " .. tostring(num) .. ": " .. table.concat(exitList, ", "))
			else
				mapper.echo("No GMCP exits received for room " .. tostring(num))
			end
		end

		-- GMCP coordinate handling for Willowdale
		local currentRoomArea, currentRoomX, currentRoomY, currentRoomZ
		if gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.coordinates and gmcp.Room.Info.Basic.coordinates ~= "" then
			-- Try with spaces pattern
			currentRoomArea, currentRoomX, currentRoomY, currentRoomZ =
				gmcp.Room.Info.Basic.coordinates:match("([^,]+), ([^,]+), ([^,]+), ([^,]+)")

			-- If that fails, try without spaces
			if not (currentRoomArea and currentRoomX and currentRoomY and currentRoomZ) then
				currentRoomArea, currentRoomX, currentRoomY, currentRoomZ =
					gmcp.Room.Info.Basic.coordinates:match("([^,]+),([^,]+),([^,]+),([^,]+)")
			end

			if currentRoomArea and currentRoomX and currentRoomY and currentRoomZ then
				currentRoomX, currentRoomY, currentRoomZ =
					tonumber(currentRoomX), tonumber(currentRoomY), tonumber(currentRoomZ)

				if mapper.settings.debug then
					mapper.echo(string.format("Parsed coordinates for room %d: area='%s', x=%d, y=%d, z=%d",
						num, currentRoomArea, currentRoomX, currentRoomY, currentRoomZ))
				end

				-- Update the current room's coordinates if they're different
				-- Only do this if autopositionrooms is enabled
				if mapper.settings.autopositionrooms and mapper.roomexists(num) then
					local mx, my, mz = getRoomCoordinates(num)
					if mx ~= currentRoomX or my ~= currentRoomY or mz ~= currentRoomZ then
						if mapper.settings.debug then
							mapper.echo(string.format("Moving room %d from (%d,%d,%d) to (%d,%d,%d)",
								num, mx, my, mz, currentRoomX, currentRoomY, currentRoomZ))
						end
						setRoomCoordinates(num, currentRoomX, currentRoomY, currentRoomZ)
						setRoomUserData(num, "Area", currentRoomArea)
						s = s .. (#s > 0 and " " or "") .. string.format("Repositioned room to %d,%d,%d.", currentRoomX, currentRoomY, currentRoomZ)
					end
				end
			else
				if mapper.settings.debug then
					mapper.echo("Failed to parse coordinates from: " .. (gmcp.Room.Info.Basic.coordinates or "nil"))
				end
			end
		end

		if not mapper.roomexists(num) then
			-- Check if this is the first room (empty map with GMCP coordinates)
			if mapper.isMapEmpty() and currentRoomX and currentRoomY and currentRoomZ and currentRoomArea then
				if mapper.createFirstRoom(num, currentRoomArea, currentRoomX, currentRoomY, currentRoomZ) then
					-- First room created, continue to process exits below
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
					setRoomUserData(num, "Area", currentRoomArea)

					-- Set biome color if available
					if gmcp.Room.Info.Basic.biome_color then
						local envId = mapper.getBiomeEnvId(gmcp.Room.Info.Basic.biome_color)
						if envId then
							setRoomEnv(num, envId)
						end
					end

					s = string.format("Created room %d at %d,%d,%d in %s.", num, currentRoomX, currentRoomY, currentRoomZ, currentRoomArea)

					if mapper.settings.debug then
						mapper.echo(s)
					end
				end
			-- see if we can create and link this room with an existing one
			-- wilderness and non-wilderness rooms require different methods of calculating relative coordinates
			elseif not inwilderness() then
				for exit, exitData in pairs(currentexits) do
					local id = exitData.room_id
					-- Only use standard exits for coordinate calculation
					if mapper.roomexists(id) and mapper.isStandardExit(exit) then
						-- getshiftedcoords internally reverses the direction, so if we have exit 'east' to room 'id',
						-- it will place the new room to the west of room 'id' (which is correct)
						s = mapper.makeroom(id, num, mapper.getshiftedcoords(exit, getRoomCoordinates(id)))
						-- After creating the room, check if we need to add a door
						if exitData.details and exitData.details.type == "door" and exitData.details.state then
							local state = exitData.details.state
							if state == "closed" or state == "locked" then
								local shortExit = mapper.anytoshort(exit)
								local doorType = state == "locked" and 3 or 2 -- 3 = locked, 2 = closed
								if mapper.settings.debug then
									mapper.echo("Creating " .. state .. " door: " .. exit .. " exit (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. num)
								end
								setDoor(num, shortExit, doorType)
								s = s .. (#s > 0 and " " or "") .. "Added " .. state .. " door on " .. exit .. " exit."
							end
						end
						break -- Room created, exit the loop
					end
				end
			else
				-- Willowdale doesn't use wilderness coordinate system
				-- This is kept for potential future use
				local x, y = tostring(num):match(".-(%d%d%d)(%d%d%d)$")
				s = mapper.makeroom(mapper.previousroom, num, x, y * -1, 0)
			end
		end
		-- if we created it, and some data could be filled in
		if mapper.roomexists(num) then
			-- cleanup the room name
			local rootroomname = mapper.cleanroomname(gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.name or "")
			-- match exact case, so mappers alertness' works properly
			if getRoomName(num) ~= rootroomname then
				setRoomName(num, rootroomname)
				unHighlightRoom(num)
				s = s .. (#s > 0 and " " or "") .. "Updated room name to '" .. rootroomname .. "'."
			end
			-- autolink exits
			if not inwilderness() then
				local x = getRoomExits(num) or {}
				-- check for missing exits
				for exit, exitData in pairs(currentexits) do
					local id = exitData.room_id
					if id == 0 then
						s = s
							.. (#s > 0 and " " or "")
							.. "Can't link to the "
							.. exit
							.. ", it leads to a room with ID 0 (and that's not supported yet)."
					else
						if not x[mapper.anytolong(exit)] then
							if not mapper.roomexists(id) then
								-- Check if we should use absolute positioning from delta data or standard directional positioning
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
									local newX = currentRoomX + exitData.delta_x
									local newY = currentRoomY + exitData.delta_y
									local newZ = currentRoomZ + exitData.delta_z

									if mapper.settings.debug then
										mapper.echo(string.format("Creating room %d at (%d,%d,%d) using delta (%d,%d,%d) from room %d at (%d,%d,%d)",
											id, newX, newY, newZ, exitData.delta_x, exitData.delta_y, exitData.delta_z,
											num, currentRoomX, currentRoomY, currentRoomZ))
									end

									-- Check if exit leads to a different area
									local targetAreaId = nil
									if mapper.settings.autocreateareas and exitData.details and exitData.details.leads_to_area then
										local targetAreaName = exitData.details.leads_to_area
										-- Try to create the area if it doesn't exist
										targetAreaId = mapper.areatable[targetAreaName]
										if not targetAreaId then
											targetAreaId = addAreaName(targetAreaName)
											if targetAreaId then
												if mapper.settings and mapper.settings.showmappingmessages then
													mapper.echo(string.format("Created new area: %s (ID: %d)", targetAreaName, targetAreaId))
												end
												mapper.regenerateareas()
											end
										end
									end

									s = mapper.makeroom(num, id, newX, newY, newZ, targetAreaId)
									setRoomUserData(id, "Area", exitData.details and exitData.details.leads_to_area or currentRoomArea)
								else
									-- Use standard directional positioning (+1 in direction)
									-- Check if exit leads to a different area
									local targetAreaId = nil
									if mapper.settings.autocreateareas and exitData.details and exitData.details.leads_to_area then
										local targetAreaName = exitData.details.leads_to_area
										-- Try to create the area if it doesn't exist
										targetAreaId = mapper.areatable[targetAreaName]
										if not targetAreaId then
											targetAreaId = addAreaName(targetAreaName)
											if targetAreaId then
												if mapper.settings and mapper.settings.showmappingmessages then
													mapper.echo(string.format("Created new area: %s (ID: %d)", targetAreaName, targetAreaId))
												end
												mapper.regenerateareas()
											end
										end
									end

									s = mapper.makeroom(
										num,
										id,
										mapper.getshiftedcoords(exit, getRoomCoordinates(num)),
										targetAreaId
									)
								end
							end
							-- Check if this is a standard exit or a special exit
							if mapper.isStandardExit(exit) then
								if mapper.setExit(num, id, exit) then
									s = s
										.. (#s > 0 and " " or "")
										.. "Added missing exit "
										.. exit
										.. " to "
										.. (getRoomName(id) ~= "" and getRoomName(id) or "''")
										.. " ("
										.. id
										.. ")."

									-- Check if this exit has a door
									if exitData.details and exitData.details.type == "door" and exitData.details.state then
										local state = exitData.details.state
										if state == "closed" or state == "locked" then
											local shortExit = mapper.anytoshort(exit)
											local doorType = state == "locked" and 3 or 2 -- 3 = locked, 2 = closed
											if mapper.settings.debug then
												mapper.echo("Creating " .. state .. " door: " .. exit .. " exit (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. num)
											end
											setDoor(num, shortExit, doorType)
											s = s .. (#s > 0 and " " or "") .. "Added " .. state .. " door on " .. exit .. " exit."
										end
									end
								else
									s = s
										.. (#s > 0 and " " or "")
										.. string.format(
											"Failed to link %d with %d via %s exit for some reason :/",
											num,
											id,
											exit
										)
								end
							else
								-- This is a special exit (like "touch tree", "enter portal", etc.)
								-- Check if the special exit already exists
								local existingSpecialExits = getSpecialExitsSwap(num) or {}
								if not existingSpecialExits[exit] then
									addSpecialExit(num, id, exit)
									s = s
										.. (#s > 0 and " " or "")
										.. "Added special exit '"
										.. exit
										.. "' to "
										.. (getRoomName(id) ~= "" and getRoomName(id) or "''")
										.. " ("
										.. id
										.. ")."
								end
							end
						else
							-- Exit already exists, check if we need to update door status
							if exitData.details and exitData.details.type == "door" and exitData.details.state then
								local doorState = exitData.details.state
								local shortExit = mapper.anytoshort(exit)
								local doorStatus = getDoors(num)

								if doorState == "closed" or doorState == "locked" then
									if not doorStatus[shortExit] or doorStatus[shortExit] == 0 then
										-- No door exists, add one
										local doorType = doorState == "locked" and 3 or 2 -- 3 = locked, 2 = closed
										if mapper.settings.debug then
											mapper.echo("Creating " .. doorState .. " door on existing exit: " .. exit .. " (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. num)
										end
										setDoor(num, shortExit, doorType)
										s = s .. (#s > 0 and " " or "") .. "Added " .. doorState .. " door on existing " .. exit .. " exit."
									elseif doorStatus[shortExit] ~= (doorState == "locked" and 3 or 2) then
										-- Door exists but wrong type, update it
										local doorType = doorState == "locked" and 3 or 2
										if mapper.settings.debug then
											mapper.echo("Updating door state to " .. doorState .. ": " .. exit .. " (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. num)
										end
										setDoor(num, shortExit, doorType)
										s = s .. (#s > 0 and " " or "") .. "Updated " .. exit .. " door to " .. doorState .. "."
									else
										if mapper.settings.debug then
											mapper.echo("Door already correct: " .. exit .. " is " .. doorState .. " in room " .. num)
										end
									end
								elseif doorState == "open" then
									-- Exit is open, remove door if it exists
									if doorStatus[shortExit] and doorStatus[shortExit] > 0 then
										if mapper.settings.debug then
											mapper.echo("Removing door: " .. exit .. " (short: " .. shortExit .. ") is now open in room " .. num)
										end
										setDoor(num, shortExit, 0) -- 0 = no door
										s = s .. (#s > 0 and " " or "") .. "Removed door from " .. exit .. " exit (now open)."
									end
								end
							end
						end
					end
				end
			else
				local function getshiftedcoords(direction, ox, oy, oz)
					if direction == "n" then
						return ox, oy + 1, oz
					elseif direction == "e" then
						return ox + 1, oy, oz
					elseif direction == "s" then
						return ox, oy - 1, oz
					elseif direction == "w" then
						return ox - 1, oy, oz
					elseif direction == "ne" then
						return ox + 1, oy + 1, oz
					elseif direction == "se" then
						return ox + 1, oy - 1, oz
					elseif direction == "sw" then
						return ox - 1, oy - 1, oz
					elseif direction == "nw" then
						return ox - 1, oy + 1, oz
					else
						error("getshiftedcoords: direction " .. direction .. " isn't supported yet.")
					end
				end

				local x, y, z = getRoomCoordinates(num)
				local currentexits = getRoomExits(num) or {}
				for _, exit in ipairs({ "n", "e", "s", "w", "ne", "se", "sw", "nw" }) do
					local roomatdir = getRoomsByPosition(getRoomArea(num), getshiftedcoords(exit, x, y, z))
					if roomatdir[0] then
						local id = roomatdir[0]
						if not currentexits[mapper.anytolong(exit)] then
							if mapper.setExit(num, id, exit) then
								s = s
									.. (#s > 0 and " " or "")
									.. "Added missing exit "
									.. exit
									.. " to "
									.. (getRoomName(id) ~= "" and getRoomName(id) or "''")
									.. " ("
									.. id
									.. ")."
							else
								s = s
									.. (#s > 0 and " " or "")
									.. string.format(
										"Failed to link %d with %d via %s exit for some reason :/",
										num,
										id,
										exit
									)
							end
							local exit = mapper.anytoshort(mapper.ranytolong(exit))
							if mapper.setExit(id, num, exit) then
								s = s
									.. (#s > 0 and " " or "")
									.. "Added missing exit "
									.. exit
									.. " to "
									.. (getRoomName(id) ~= "" and getRoomName(id) or "''")
									.. " ("
									.. id
									.. ")."
							else
								s = s
									.. (#s > 0 and " " or "")
									.. string.format(
										"Failed to link %d with %d via %s exit for some reason :/",
										num,
										id,
										exit
									)
							end
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
						s = s
							.. (#s > 0 and " " or "")
							.. exit
							.. " exit to "
							.. id
							.. " doesn't actually exist, removed it."
					end
				end
			end
			-- check for biome color update
			if gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.biome_color then
				local envId = mapper.getBiomeEnvId(gmcp.Room.Info.Basic.biome_color)
				if envId and envId ~= getRoomEnv(num) then
					setRoomEnv(num, envId)
					s = s .. (#s > 0 and " " or "") .. "Updated room color to " .. gmcp.Room.Info.Basic.biome_color .. "."
				end
			end
			-- store and display biome data
			if gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.environment then
				local environment = gmcp.Room.Info.Basic.environment
				local envLower = environment:lower()
				local symbol = gmcp.Room.Info.Basic.biome_symbol or ""

				-- Store biome data on the room
				if getRoomUserData(num, "biome") ~= environment then
					setRoomUserData(num, "biome", environment)
				end
				if getRoomUserData(num, "biome_symbol") ~= symbol then
					setRoomUserData(num, "biome_symbol", symbol)
				end

				-- Set room character for biomes based on showbiomesymbols setting
				if symbol ~= "" and mapper.shouldShowSymbol(envLower) then
					if getRoomChar(num) ~= symbol then
						setRoomChar(num, symbol)
						s = s .. (#s > 0 and " " or "") .. "Set room symbol to '" .. symbol .. "'."
					end
				elseif symbol ~= "" and getRoomChar(num) == symbol then
					-- Clear symbol if settings changed and it shouldn't be shown
					setRoomChar(num, "")
				end
			end
			-- check indoors status
			local indoors = gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.details and table.contains(gmcp.Room.Info.Basic.details, "indoors")
			if indoors and (getRoomUserData(num, "indoors") == "" or getRoomUserData(num, "outdoors") ~= "") then
				setRoomUserData(num, "indoors", "y")
				clearRoomUserDataItem(num, "outdoors")
				s = s .. (#s > 0 and " " or "") .. "Updated room to be indoors."
			elseif
				not indoors and (getRoomUserData(num, "indoors") ~= "" or getRoomUserData(num, "outdoors") == "")
			then
				clearRoomUserDataItem(num, "indoors")
				setRoomUserData(num, "outdoors", "y")
				s = s .. (#s > 0 and " " or "") .. "Updated room to be outdoors."
			end

			-- Willowdale can add game area tracking here if needed
			-- check for wilderness exits
			if getRoomChar(num) ~= "W" and gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.details and table.contains(gmcp.Room.Info.Basic.details, "wilderness") then
				setRoomChar(num, "W")
				s = s .. (#s > 0 and " " or "") .. "Added the wilderness mark."
			end
		end
		if #s > 0 then
			if mapper.settings and mapper.settings.showmappingmessages then
				mapper.echo(s)
			end
			centerview(mapper.currentroom)
		end
	end, function(error)
		mapper.echo("Oops! Had a small problem (" .. error .. ").")
		echo("  ")
		echoLink("view steps", "echo[[" .. debug.traceback() .. "]]", "View steps of code that led up to it")
	end)
	if not s then
		mapper.echo(m)
	end
end
