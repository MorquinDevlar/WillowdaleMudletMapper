-- Door handling from GMCP exit data.
--
-- The game reports a door on every exit that carries a lock, the state that
-- lock is in, and whether this player gets past it. Passability is the server's
-- answer rather than ours to work out: a lock relocks on a timer the client
-- cannot see, and the key is on the character, so the same door is shut to one
-- player and open to another.

-- Mudlet's door markers, keyed by the state GMCP reports. The game currently
-- only ever reports a lock as "locked" or "open"; "closed" is here so a door
-- that is shut but not locked would be drawn correctly if one is ever added.
local doorTypeForState = { open = 1, closed = 2, locked = 3 }

-- Whether the player can walk through this exit as things stand. The server
-- resolves it into `passable`, having checked the key ring and, for a lock the
-- player knows the combination to, whether they are carrying lockpicks. The key
-- and combination flags are only a fallback for a server too old to send it,
-- and are optimistic: trying a door and stopping beats routing around one that
-- would have opened.
local function exitIsPassable(details)
	if details.passable ~= nil then
		return details.passable and true or false
	end
	if details.state ~= "locked" then
		return true
	end
	return (details.hasKey or details.hasPicked) and true or false
end

-- Bring the doors and exit locks of one room in line with what GMCP reports.
-- Returns whether anything changed, so a caller can report it.
function mapper.updateDoorStatuses(roomNum)
	if not roomNum or not mapper.roomexists(roomNum) then
		return false
	end

	local currentexits = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Exits or {}
	local doorStatus = getDoors(roomNum) or {}
	local changed, locksChanged = false, false

	for exit, exitData in pairs(currentexits) do
		-- GMCP hands us a table per exit; anything else is not one.
		if type(exitData) == "table" then
			local details = exitData.details
			local isDoor = (details and details.type == "door" and details.state) and true or false
			-- The pathfinder may only be steered away from a door this player
			-- cannot open. Locking one they hold the key to would route them the
			-- long way round, or report no route at all when the door is the only
			-- way out of a room.
			local shouldLock = isDoor and not exitIsPassable(details)

			if mapper.isStandardExit(exit) then
				local shortExit = mapper.anytoshort(exit)
				local wantType = isDoor and (doorTypeForState[details.state] or 1) or 0
				if (doorStatus[shortExit] or 0) ~= wantType then
					setDoor(roomNum, shortExit, wantType)
					changed = true
					if mapper.settings.debug then
						mapper.echo(string.format("Door on %s in room %d set to %d.", exit, roomNum, wantType))
					end
				end

				if mapper.hasExitLock(roomNum, exit) ~= shouldLock then
					mapper.lockExit(roomNum, exit, shouldLock)
					locksChanged = true
					if mapper.settings.debug then
						mapper.echo(
							string.format(
								"%s exit %s in room %d for pathfinding.",
								shouldLock and "Locked" or "Unlocked",
								exit,
								roomNum
							)
						)
					end
				end
			elseif lockSpecialExit and exitData.room_id then
				-- A lock can sit on an exit with any name the room gives it, and
				-- Mudlet can neither draw a door on one of those nor lock it through
				-- the compass-direction calls - it wants the destination room and the
				-- command. Setting it every time is why no before-state is read here.
				lockSpecialExit(roomNum, tonumber(exitData.room_id), exit, shouldLock)
			end
		end
	end

	-- Doors left on exits the room no longer has.
	for exit, doorType in pairs(doorStatus) do
		if doorType > 0 then
			local found = false
			for gmcpExit in pairs(currentexits) do
				if mapper.anytoshort(gmcpExit) == exit then
					found = true
					break
				end
			end
			if not found then
				setDoor(roomNum, exit, 0)
				changed = true
				if mapper.settings.debug then
					mapper.echo(string.format("Removed door from %s in room %d - the exit is gone.", exit, roomNum))
				end
			end
		end
	end

	-- A lock the pathfinder honours has moved, so any cached path crossing this
	-- room may no longer be walkable.
	if locksChanged then
		raiseEvent("mapper updated map")
	end

	return changed or locksChanged
end

-- Event handler for door updates whenever GMCP room info is received
function mapper.updatedoors()
	-- The same room mapping works from, rather than mapper.currentroom, so that
	-- doors land on a room the moment it is created rather than on the next visit.
	local num = (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic and tonumber(gmcp.Room.Info.Basic.id))
		or mapper.currentroom
	if not num or not mapper.roomexists(num) then
		return
	end

	if mapper.updateDoorStatuses(num) and mapper.settings and mapper.settings.showmappingmessages then
		mapper.echo("Door statuses updated for room " .. num)
	end
end
