--mmp.mappingNewroom

local function makeroom(oldid, newid, x, y, z, targetAreaId)
	assert(x and y and z, "makeroom: need all 3 coordinates")
	addRoom(newid)
	setRoomCoordinates(newid, x, y, z)
	-- Use target area if provided, otherwise inherit from old room
	if targetAreaId then
		setRoomArea(newid, targetAreaId)
	else
		setRoomArea(newid, getRoomArea(oldid))
	end
	local fgr, fgg, fgb = unpack(color_table.red)
	local bgr, bgg, bgb = unpack(color_table.blue)
	highlightRoom(newid, fgr, fgg, fgb, bgr, bgg, bgb, 1, 100, 100)
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and mmp.envids and mmp.envids[gmcp.Room.Info.Basic.environment] then
		setRoomEnv(newid, mmp.envids[gmcp.Room.Info.Basic.environment])
	else
		setRoomEnv(newid, getRoomEnv(oldid))
	end
	return string.format("Created new room %d at %dx,%dy,%dz.", newid, x, y, z)
end

-- gives the reverse shifted coordinates, ie asking for the sw exit + coords will give the coords at ne

local function getshiftedcoords(original, ox, oy, oz)
	local x, y, z
	local has = table.contains
	-- reverse the exit
	w = mmp.ranytolong(original)
	if has({ "west", "left", "w", "l" }, w) then
		x = (x or ox) - 1
		y = (y or oy)
		z = (z or oz)
	elseif has({ "east", "right", "e", "r" }, w) then
		x = (x or ox) + 1
		y = (y or oy)
		z = (z or oz)
	elseif has({ "north", "top", "n", "t" }, w) then
		x = (x or ox)
		y = (y or oy) + 1
		z = (z or oz)
	elseif has({ "south", "bottom", "s", "b" }, w) then
		x = (x or ox)
		y = (y or oy) - 1
		z = (z or oz)
	elseif has({ "northwest", "topleft", "nw", "tl" }, w) then
		x = (x or ox) - 1
		y = (y or oy) + 1
		z = (z or oz)
	elseif has({ "northeast", "topright", "ne", "tr" }, w) then
		x = (x or ox) + 1
		y = (y or oy) + 1
		z = (z or oz)
	elseif has({ "southeast", "bottomright", "se", "br" }, w) then
		x = (x or ox) + 1
		y = (y or oy) - 1
		z = (z or oz)
	elseif has({ "southwest", "bottomleft", "sw", "bl" }, w) then
		x = (x or ox) - 1
		y = (y or oy) - 1
		z = (z or oz)
	elseif has({ "up", "u" }, w) then
		x = (x or ox)
		y = (y or oy)
		z = (z or oz) + 1
	elseif has({ "down", "d" }, w) then
		x = (x or ox)
		y = (y or oy)
		z = (z or oz) - 1
	elseif has({ "in", "i" }, w) then
		x = (x or ox)
		y = (y or oy)
		z = (z or oz) - 1
	elseif has({ "out", "o" }, w) then
		x = (x or ox)
		y = (y or oy)
		z = (z or oz) + 1
	else
		mmp.echo(
			"Don't know where to shift the coordinates for a " .. tostring(w) .. " (" .. tostring(original) .. ") exit."
		)
	end
	return x, y, z
end

function mmp.mappingnewroom(_, num)
	local s, m = xpcall(function()
		if not mmp.editing then
			return
		end
		if not gmcp.Room then
			mmp.echo("You need to have GMCP turned on (see preferences on a recent Mudlet) for mapping stuff.")
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
		if mmp.settings.debug then
			local exitList = {}
			for exit, exitData in pairs(currentexits) do
				table.insert(exitList, string.format("%s->%d", exit, exitData.room_id))
			end
			if #exitList > 0 then
				mmp.echo("GMCP exits for room " .. tostring(num) .. ": " .. table.concat(exitList, ", "))
			else
				mmp.echo("No GMCP exits received for room " .. tostring(num))
			end
		end

		-- GoMUD-specific coordinate handling
		local currentRoomArea, currentRoomX, currentRoomY, currentRoomZ
		if mmp.game == "gomud" then
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

					-- INVERT the Y coordinate to match Mudlet's coordinate system
					currentRoomY = currentRoomY * -1
					
					if mmp.settings.debug then
						mmp.echo(string.format("Parsed coordinates for room %d: area='%s', x=%d, y=%d (inverted from %d), z=%d", 
							num, currentRoomArea, currentRoomX, currentRoomY, currentRoomY * -1, currentRoomZ))
					end

					-- Update the current room's coordinates if they're different
					-- Only do this if autopositionrooms is enabled
					if mmp.settings.autopositionrooms and mmp.roomexists(num) then
						local mx, my, mz = getRoomCoordinates(num)
						if mx ~= currentRoomX or my ~= currentRoomY or mz ~= currentRoomZ then
							if mmp.settings.debug then
								mmp.echo(string.format("Moving room %d from (%d,%d,%d) to (%d,%d,%d)", 
									num, mx, my, mz, currentRoomX, currentRoomY, currentRoomZ))
							end
							setRoomCoordinates(num, currentRoomX, currentRoomY, currentRoomZ)
							setRoomUserData(num, "Area", currentRoomArea)
							s = s .. (#s > 0 and " " or "") .. string.format("Repositioned room to %d,%d,%d.", currentRoomX, currentRoomY, currentRoomZ)
						end
					end
				else
					if mmp.settings.debug then
						mmp.echo("Failed to parse coordinates from: " .. (gmcp.Room.Info.Basic.coordinates or "nil"))
					end
				end
			end
		end

		if not mmp.roomexists(num) then
			-- see if we can create and link this room with an existing one
			-- wilderness and non-wilderness rooms require different methods of calculating relative coordinates
			if not inwilderness() then
				for exit, exitData in pairs(currentexits) do
					local id = exitData.room_id
					if mmp.roomexists(id) then
						-- getshiftedcoords internally reverses the direction, so if we have exit 'east' to room 'id',
						-- it will place the new room to the west of room 'id' (which is correct)
						s = makeroom(id, num, getshiftedcoords(exit, getRoomCoordinates(id)))
						-- After creating the room, check if we need to add a door
						if exitData.details and exitData.details.type == "door" and exitData.details.state then
							local state = exitData.details.state
							if state == "closed" or state == "locked" then
								local shortExit = mmp.anytoshort(exit)
								local doorType = state == "locked" and 3 or 2 -- 3 = locked, 2 = closed
								if mmp.settings.debug then
									mmp.echo("Creating " .. state .. " door: " .. exit .. " exit (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. num)
								end
								setDoor(num, shortExit, doorType)
								s = s .. (#s > 0 and " " or "") .. "Added " .. state .. " door on " .. exit .. " exit."
							end
						end
					end
				end
			else
				-- GoMud doesn't use wilderness coordinate system
				-- This is kept for potential future use
				local x, y = tostring(num):match(".-(%d%d%d)(%d%d%d)$")
				s = makeroom(mmp.previousroom, num, x, y * -1, 0)
			end
		end
		-- if we created it, and some data could be filled in
		if mmp.roomexists(num) then
			-- cleanup the room name
			local rootroomname = mmp.cleanroomname(gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.name or "")
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
						if not x[mmp.anytolong(exit)] then
							if not mmp.roomexists(id) then
								if mmp.game == "gomud" then
									-- GoMUD-specific room creation
									-- Check if we should use absolute positioning or standard directional positioning
									if
										mmp.settings.autopositionrooms
										and exitData.delta_x
										and exitData.delta_y
										and exitData.delta_z
										and currentRoomX
										and currentRoomY
										and currentRoomZ
									then
										-- Use absolute positioning from GMCP delta data
										local newX = currentRoomX + exitData.delta_x

										-- currentRoomY already has inverted sign, and delta_y also needs inverted sign
										local newY = currentRoomY + (exitData.delta_y * -1)
										local newZ = currentRoomZ + exitData.delta_z

										-- Check if exit leads to a different area
										local targetAreaId = nil
										if mmp.settings.autocreateareas and exitData.details and exitData.details.leads_to_area then
											local targetAreaName = exitData.details.leads_to_area
											-- Try to create the area if it doesn't exist
											targetAreaId = mmp.areatable[targetAreaName]
											if not targetAreaId then
												targetAreaId = addAreaName(targetAreaName)
												if targetAreaId then
													mmp.echo(string.format("Created new area: %s (ID: %d)", targetAreaName, targetAreaId))
													mmp.regenerateareas()
												end
											end
										end
										
										s = makeroom(num, id, newX, newY, newZ, targetAreaId)
										setRoomUserData(id, "Area", exitData.details and exitData.details.leads_to_area or currentRoomArea)
									else
										-- Use standard directional positioning (+1 in direction)
										-- Check if exit leads to a different area
										local targetAreaId = nil
										if mmp.settings.autocreateareas and exitData.details and exitData.details.leads_to_area then
											local targetAreaName = exitData.details.leads_to_area
											-- Try to create the area if it doesn't exist
											targetAreaId = mmp.areatable[targetAreaName]
											if not targetAreaId then
												targetAreaId = addAreaName(targetAreaName)
												if targetAreaId then
													mmp.echo(string.format("Created new area: %s (ID: %d)", targetAreaName, targetAreaId))
													mmp.regenerateareas()
												end
											end
										end
										
										s = makeroom(
											num,
											id,
											getshiftedcoords(exit, getRoomCoordinates(num)),
											targetAreaId
										)
									end
								else
									-- Standard room creation for other games
									s = makeroom(
										num,
										id,
										getshiftedcoords(exit, getRoomCoordinates(num))
									)
								end
							end
							if mmp.setExit(num, id, exit) then
								s = s
									.. (#s > 0 and " " or "")
									.. "Added missing exit "
									.. exit
									.. " to "
									.. (getRoomName(id) ~= "" and getRoomName(id) or "''")
									.. " ("
									.. id
									.. ")."
								
								-- Check if this exit has a door (closed or locked status)
								if exitData.status and (exitData.status == "closed" or exitData.status == "locked") then
									local shortExit = mmp.anytoshort(exit)
									local doorType = exitData.status == "locked" and 3 or 2 -- 3 = locked, 2 = closed
									if mmp.settings.debug then
							mmp.echo("Creating " .. exitData.status .. " door: " .. exit .. " exit (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. num)
						end
									setDoor(num, shortExit, doorType)
									s = s .. (#s > 0 and " " or "") .. "Added " .. exitData.status .. " door on " .. exit .. " exit."
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
							-- Exit already exists, check if we need to update door status
							if exitData.status and (exitData.status == "closed" or exitData.status == "locked") then
								local shortExit = mmp.anytoshort(exit)
								local doorStatus = getDoors(num)
								if not doorStatus[shortExit] or doorStatus[shortExit] == 0 then
									-- No door exists, add one
									local doorType = exitData.status == "locked" and 3 or 2 -- 3 = locked, 2 = closed
									if mmp.settings.debug then
										mmp.echo("Creating " .. exitData.status .. " door on existing exit: " .. exit .. " (short: " .. shortExit .. ", type: " .. doorType .. ") in room " .. num)
									end
									setDoor(num, shortExit, doorType)
									s = s .. (#s > 0 and " " or "") .. "Added " .. exitData.status .. " door on existing " .. exit .. " exit."
								else
									if mmp.settings.debug then
										mmp.echo("Door already exists: " .. exit .. " in room " .. num)
									end
								end
							elseif exitData.status == "open" then
								-- Exit is open, remove door if it exists
								local shortExit = mmp.anytoshort(exit)
								local doorStatus = getDoors(num)
								if doorStatus[shortExit] and doorStatus[shortExit] > 0 then
									if mmp.settings.debug then
										mmp.echo("Removing door: " .. exit .. " (short: " .. shortExit .. ") is now open in room " .. num)
									end
									setDoor(num, shortExit, 0) -- 0 = no door
									s = s .. (#s > 0 and " " or "") .. "Removed door from " .. exit .. " exit (now open)."
								end
							else
								if mmp.settings.debug then
									mmp.echo("Exit " .. exit .. " has status: " .. tostring(exitData.status) .. " in room " .. num)
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
						if not currentexits[mmp.anytolong(exit)] then
							if mmp.setExit(num, id, exit) then
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
							local exit = mmp.anytoshort(mmp.ranytolong(exit))
							if mmp.setExit(id, num, exit) then
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
			if mmp.settings["autoclear"] then
				for exit, id in pairs(getRoomExits(num)) do
					-- getRoomExits returns exits in long form (e.g., "east", "west")
					-- currentexits from GMCP also uses long form as keys
					-- So we should check against the long form directly
					if not currentexits[exit] then
						mmp.setExit(num, -1, exit)
						s = s
							.. (#s > 0 and " " or "")
							.. exit
							.. " exit to "
							.. id
							.. " doesn't actually exist, removed it."
					end
				end
			end
			-- check for environment update, if we have environments mapped out
			if gmcp.Room.Info.Basic and mmp.envids and mmp.envids[gmcp.Room.Info.Basic.environment] and mmp.envids[gmcp.Room.Info.Basic.environment] ~= getRoomEnv(num) then
				setRoomEnv(num, mmp.envids[gmcp.Room.Info.Basic.environment])
				s = s .. (#s > 0 and " " or "") .. "Updated environment name to " .. gmcp.Room.Info.Basic.environment .. "."
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

			-- GoMud can add game area tracking here if needed
			-- check for wilderness exits
			if getRoomChar(num) ~= "W" and gmcp.Room.Info.Basic and gmcp.Room.Info.Basic.details and table.contains(gmcp.Room.Info.Basic.details, "wilderness") then
				setRoomChar(num, "W")
				s = s .. (#s > 0 and " " or "") .. "Added the wilderness mark."
			end
		end
		if #s > 0 then
			mmp.echo(s)
			centerview(mmp.currentroom)
		end
	end, function(error)
		mmp.echo("Oops! Had a small problem (" .. error .. ").")
		echo("  ")
		echoLink("view steps", "echo[[" .. debug.traceback() .. "]]", "View steps of code that led up to it")
	end)
	if not s then
		mmp.echo(m)
	end
end
