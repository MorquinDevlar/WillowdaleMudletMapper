-- Exit handling functions with direction string support
-- Wraps Mudlet's exit functions to accept both numeric and string directions

do
	local oldsetExit = setExit
	local oldlockExit = lockExit
	local oldhasExitLock = hasExitLock
	local oldsetExitStub = setExitStub

	local dirnumber = mapper.dirnumber

	-- Whether a direction is already marked as a way out we have not been
	-- through. getExitStubs1 lists them as direction numbers.
	function mapper.hasExitStub(from, direction)
		local dir = dirnumber(direction)
		if not dir or not getExitStubs1 or not roomExists(from) then
			return false
		end
		for _, stub in ipairs(getExitStubs1(from) or {}) do
			if stub == dir then
				return true
			end
		end
		return false
	end

	-- Mark a direction as an unexplored way out, or take the mark off again.
	-- Mudlet raises an error rather than returning for a room it does not have,
	-- and redraws the area even for a stub already in the state asked for, so
	-- both are settled here. Returns whether anything changed.
	function mapper.setExitStub(from, direction, on)
		local dir = dirnumber(direction)
		if not dir or not oldsetExitStub or not roomExists(from) then
			return false
		end

		on = on and true or false
		if mapper.hasExitStub(from, dir) == on then
			return false
		end

		oldsetExitStub(from, dir, on)
		return true
	end

	function mapper.setExit(from, to, direction)
		local dir = dirnumber(direction)
		if not dir then
			return false
		end

		-- A stub says "there is a way out here we have not been through", which
		-- a linked exit is not. Mudlet does not take one off by itself, and a
		-- room with both draws the stub over the exit.
		if (tonumber(to) or -1) > 0 then
			mapper.setExitStub(from, dir, false)
		end

		return oldsetExit(from, to, dir)
	end

	-- A lock the pathfinder honours has moved, so routes worked out before it
	-- may cross an exit that is now shut, or go the long way round one that has
	-- just opened. Every lock this script sets goes through here or through
	-- mapper.lockSpecialExit, so this is the one place that has to say so.
	function mapper.lockExit(from, direction, status)
		local dir = dirnumber(direction)
		if not dir then
			return false
		end

		status = status and true or false
		if (oldhasExitLock(from, dir) and true or false) ~= status then
			mapper.clearpathcache()
		end

		return oldlockExit(from, dir, status)
	end

	-- Locks on exits Mudlet has no compass direction for. It wants the
	-- destination room and the command in place of a direction number; current
	-- Mudlet ignores the destination, older ones require it. Locking one dirties
	-- the map, redraws the area and rebuilds the pathfinding graph even when the
	-- lock is already in the state asked for, and a walk passes through door
	-- handling in every room, so only an actual change may reach it.
	function mapper.lockSpecialExit(from, to, command, status)
		if not lockSpecialExit or not hasSpecialExitLock then
			return false
		end

		status = status and true or false
		if (hasSpecialExitLock(from, to, command) and true or false) == status then
			return true
		end

		mapper.clearpathcache()
		return lockSpecialExit(from, to, command, status)
	end

	function mapper.hasExitLock(from, direction)
		local dir = dirnumber(direction)
		if not dir then
			return false
		end

		return oldhasExitLock(from, dir)
	end
end
