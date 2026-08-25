-- Room change event handler for speedwalking

-- Keeps the showpath highlight in step with a player walking by hand. Runs on
-- the same event as mapping and after it, because a room entered for the first
-- time has no exits of its own until mapping links them - a path recalculated
-- from gmcp.Room.Info would find no way onward from such a room and the
-- highlight would freeze where the mapped rooms ended.
function mapper.updateshowpath()
	if not mapper.showPathDestination or mapper.autowalking then
		return
	end
	local num = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and tonumber(gmcp.Room.Info.Basic.id)
	if not num then
		return
	end
	if num == mapper.showPathDestination then
		mapper.clearShowPath()
		mapper.notify("You've arrived at your destination.")
	elseif roomExists(num) then
		-- A room the map does not have, or a path it cannot find, keeps the
		-- existing highlight rather than clearing it
		if mapper.getPath(num, mapper.showPathDestination) then
			mapper.highlightPath(speedWalkPath, num)
		end
	end
end

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
		mapper.notify(
			string.format(
				"Room change detected: %d (counter: %d/%d, dest: %s)",
				num,
				mapper.speedWalkCounter or 0,
				#(mapper.speedWalkPath or {}),
				mapper.speedWalkPath and mapper.speedWalkPath[#mapper.speedWalkPath] or "none"
			)
		)
	end
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then

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

			-- Set room character based on the roomchar setting
			if symbol ~= "" then
				if mapper.shouldShowRoomChar(envLower) then
					if getRoomChar(num) ~= symbol then
						setRoomChar(num, symbol)
					end
				elseif getRoomChar(num) == symbol then
					-- Clear the character if the setting no longer shows it
					setRoomChar(num, "")
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
		mapper.notify(string.format("We've arrived! Took us %.1fs.\n", walktime))
		raiseEvent("mapper arrived")
		mapper.speedWalkPath = {}
		mapper.speedWalkDir = {}
		mapper.speedWalkCounter = 0
		mapper.autowalking = false
		mapper.clearPathHighlight()
	elseif mapper.speedWalkPath[mapper.speedWalkCounter] == num then
		mapper.speedWalkCounter = mapper.speedWalkCounter + 1
		-- Check if we're at the destination after incrementing
		if mapper.speedWalkCounter > #mapper.speedWalkPath or num == mapper.speedWalkPath[#mapper.speedWalkPath] then
			local walktime = stopStopWatch(mapper.speedWalkWatch)
			mapper.notify(string.format("We've arrived! Took us %.1fs.\n", walktime))
			raiseEvent("mapper arrived")
			mapper.speedWalkPath = {}
			mapper.speedWalkDir = {}
			mapper.speedWalkCounter = 0
			mapper.autowalking = false
			mapper.clearPathHighlight()
		else
			-- Update path highlight to show remaining path
			mapper.updatePathHighlight()
			-- GMCP room change detected, continue walking
			-- Use delay if configured, otherwise move immediately
			local delay = mapper.settings.walkdelay
			if delay == nil then delay = 0.3 end
			mapper.delayedMove(delay)
		end
	elseif #mapper.speedWalkPath > 0 then
		-- ended up somewhere we didn't want to be - re-calculate path
		mapper.notify("Ended up off the path, recalculating a new path...")
		local destination = mapper.speedWalkPath[#mapper.speedWalkPath]
		if not mapper.getPath(num, destination) then
			mapper.notify(
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
