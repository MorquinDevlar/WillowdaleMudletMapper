-- Room change event handler for speedwalking

local oldnum

function mapper.room_events(event, num)
	local num = tonumber(num) or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and tonumber(gmcp.Room.Info.Basic.id))
	if num ~= mapper.currentroom then
		mapper.previousroom = mapper.currentroom
	end
	mapper.currentroom = num
	mapper.currentroomname = getRoomName(num)

	-- Debug speedwalking
	if mapper.settings.debug and mapper.autowalking then
		mapper.echo(
			string.format(
				"Room change detected: %d (counter: %d/%d, dest: %s)",
				num,
				mapper.speedWalkCounter or 0,
				#(mapper.speedWalkPath or {}),
				mapper.speedWalkPath and mapper.speedWalkPath[#mapper.speedWalkPath] or "none"
			)
		)
	end
	-- Try to track if we're flying or not
	-- This is to avoid being "off path" if we FLY due to flight mechanics.
	local madeflight = false
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then
		local flying = false
		if string.find(gmcp.Room.Info.Basic.name, "^flying above") then
			flying = true
		end
		if mapper.flying and not flying then
			-- We were flying, and now we are not. Gravity!
			mapper.flying = false
		elseif not mapper.flying and flying then
			-- We were not flying and now we are.
			madeflight = true
			mapper.flying = true
		elseif not flying then
			mapper.flying = false
		end
	else
		mapper.flying = false
	end
	-- track if we're inside or outside, if possible
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then
		local areaID = getRoomArea(mapper.currentroom)
		if
			mapper.inside
			and not (
				table.contains(gmcp.Room.Info.Basic.details or {}, "indoors")
				or table.contains(gmcp.Room.Info.Basic.details or {}, "considered indoors")
			)
		then
			mapper.inside = false
			raiseEvent("mmapper went outside")
		elseif
			not mapper.inside
			and (
				table.contains(gmcp.Room.Info.Basic.details or {}, "indoors")
				or table.contains(gmcp.Room.Info.Basic.details or {}, "considered indoors")
			)
		then
			mapper.inside = true
			raiseEvent("mmapper went inside")
		end

		-- Store and display biome data on existing rooms
		if mapper.roomexists(num) and gmcp.Room.Info.Basic.environment then
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

			-- Set room character for special biomes if enabled
			if mapper.settings.showbiomesymbols and symbol ~= "" then
				if envLower == "shop" or envLower == "inn" or envLower == "post office" then
					if getRoomChar(num) ~= symbol then
						setRoomChar(num, symbol)
					end
				end
			end
		end
		-- Continent change detection removed - not used in Willowdale
		-- the event could cancel speedwalking - in this case quit
		if mapper.ignore_speedwalking then
			mapper.ignore_speedwalking = nil
			return
		end
	end
	if oldnum == num then
		return
	else
		oldnum = num
	end
	if not mapper.autowalking then
		return
	end
	-- No longer using movetimer, movement is GMCP-driven
	if num == mapper.speedWalkPath[#mapper.speedWalkPath] then
		local walktime = stopStopWatch(mapper.speedWalkWatch)
		mapper.echo(string.format("We've arrived! Took us %.1fs.\n", walktime))
		raiseEvent("mmapper arrived")
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		mapper.autowalking = false
		mapper.clearPathHighlight()
	elseif mapper.speedWalkPath[mapper.speedWalkCounter] == num then
		-- Clear highlight from the room we just entered
		if mapper.settings.showspeedwalkpath and roomExists(num) then
			unHighlightRoom(num)
		end
		mapper.speedWalkCounter = mapper.speedWalkCounter + 1
		-- Check if we're at the destination after incrementing
		if mapper.speedWalkCounter > #mapper.speedWalkPath or num == mapper.speedWalkPath[#mapper.speedWalkPath] then
			local walktime = stopStopWatch(mapper.speedWalkWatch)
			mapper.echo(string.format("We've arrived! Took us %.1fs.\n", walktime))
			raiseEvent("mmapper arrived")
			mapper.speedWalkPath = {}
			mapper.speedWalkDir = {}
			mapper.speedWalkCounter = 0
			mapper.autowalking = false
			mapper.clearPathHighlight()
		else
			-- GMCP room change detected, continue walking
			-- Use delay if configured, otherwise move immediately
			local delay = mapper.settings.walkdelay or 0.3
			mapper.delayedMove(delay)
		end
	elseif #mapper.speedWalkPath > 0 then
		-- ended up somewhere we didn't want to be - re-calculate path
		mapper.echo("Ended up off the path, recalculating a new path...")
		local destination = mapper.speedWalkPath[#mapper.speedWalkPath]
		if not mapper.getPath(num, destination) then
			mapper.echo(
				string.format(
					"Don't know how to get to %d (%s) anymore :( Move into a room we know of to continue",
					destination,
					getRoomName(destination)
				)
			)
		else
			mapper.gotoRoom(destination)
		end
	end
end
