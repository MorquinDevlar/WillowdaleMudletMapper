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
	-- The room's stored exits and special exits, each read the first time a
	-- temporary exit needs them
	local storedexits, storedspecials

	for exit, exitData in pairs(currentexits) do
		-- GMCP hands us a table per exit; anything else is not one. An exit
		-- marked temporary, a room script's or an active mutator's, gets no door
		-- or lock of its own: either would stay on the map after the exit closed.
		-- A mutator's exit can take over one of the room's own exits by name and
		-- lead somewhere else. A walk would then go through it to the wrong room,
		-- look for a new path from there and could come back through the same
		-- exit until the mutator ended, so the stored exit is locked for
		-- pathfinding while that lasts. Its door marker stays as it is: Mudlet
		-- only draws doors, and only a lock keeps its pathfinder off an exit.
		-- When the server sends the room's own exit again, it is handled below
		-- like any other and its lock set from its own door, which takes this
		-- one off; a mutator that ends while the player is elsewhere leaves the
		-- exit locked until the player next enters the room. A temporary exit
		-- leading where the stored one does, or one under a name the room has no
		-- exit for, changes nothing.
		if type(exitData) == "table" and mapper.temporaryexit(exitData) then
			local destination = tonumber(exitData.room_id)
			local longname = mapper.dirlong(exit)
			local held
			if longname then
				storedexits = storedexits or getRoomExits(roomNum) or {}
				local stored = tonumber(storedexits[longname])
				if stored and stored ~= destination and not mapper.hasExitLock(roomNum, exit) then
					mapper.lockExit(roomNum, exit, true)
					held = stored
				end
			elseif hasSpecialExitLock then
				storedspecials = storedspecials or getSpecialExitsSwap(roomNum) or {}
				local stored = tonumber(storedspecials[exit])
				if stored and stored ~= destination and not hasSpecialExitLock(roomNum, stored, exit) then
					mapper.lockSpecialExit(roomNum, stored, exit, true)
					held = stored
				end
			end
			if held then
				locksChanged = true
				if mapper.debugging() then
					mapper.notify(string.format("Locked exit %s to room %d in room %d for pathfinding while a temporary exit has its name.",
						exit, held, roomNum))
				end
			end
		elseif type(exitData) == "table" then
			local details = exitData.details
			local isDoor = (details and details.type == "door" and details.state) and true or false
			-- The pathfinder may only be steered away from a door this player
			-- cannot open. Locking one they hold the key to would route them the
			-- long way round, or report no route at all when the door is the only
			-- way out of a room.
			local shouldLock = isDoor and not exitIsPassable(details)

			local doorExit = mapper.dirdoor(exit)
			if doorExit then
				local wantType = isDoor and (doorTypeForState[details.state] or 1) or 0
				if (doorStatus[doorExit] or 0) ~= wantType then
					setDoor(roomNum, doorExit, wantType)
					changed = true
					if mapper.debugging() then
						mapper.notify(string.format("Door on %s in room %d set to %d.", exit, roomNum, wantType))
					end
				end

				if mapper.hasExitLock(roomNum, exit) ~= shouldLock then
					mapper.lockExit(roomNum, exit, shouldLock)
					locksChanged = true
					if mapper.debugging() then
						mapper.notify(
							string.format(
								"%s exit %s in room %d for pathfinding.",
								shouldLock and "Locked" or "Unlocked",
								exit,
								roomNum
							)
						)
					end
				end
			elseif hasSpecialExitLock and exitData.room_id then
				-- A lock can sit on an exit with any name the room gives it, and
				-- Mudlet can neither draw a door on one of those nor lock it through
				-- the compass-direction calls. mapper.lockSpecialExit takes it from
				-- here, including dropping cached routes and refusing to touch a lock
				-- that is already in the state asked for; the check below is only so
				-- this room can report that something changed.
				local destination = tonumber(exitData.room_id)
				local wasLocked = destination and hasSpecialExitLock(roomNum, destination, exit) or false
				if destination and wasLocked ~= shouldLock then
					mapper.lockSpecialExit(roomNum, destination, exit, shouldLock)
					locksChanged = true
				end
			end
		end
	end

	-- Doors left on exits the room no longer has. A temporary exit counts as
	-- present: under the name of one of the room's own exits it stands in for
	-- that exit only while it lasts, so the door stored on it stays drawn as it
	-- was, and the lock set above keeps walks off it where the two lead to
	-- different rooms.
	local present = {}
	for gmcpExit in pairs(currentexits) do
		local doorExit = mapper.dirdoor(gmcpExit)
		if doorExit then
			present[doorExit] = true
		end
	end
	for exit, doorType in pairs(doorStatus) do
		if doorType > 0 and not present[exit] then
			setDoor(roomNum, exit, 0)
			changed = true
			if mapper.debugging() then
				mapper.notify(string.format("Removed door from %s in room %d - the exit is gone.", exit, roomNum))
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
