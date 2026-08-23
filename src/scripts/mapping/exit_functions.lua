-- Exit handling functions with direction string support
-- Wraps Mudlet's exit functions to accept both numeric and string directions

do
	local oldsetExit = setExit
	local oldlockExit = lockExit
	local oldhasExitLock = hasExitLock

	local exitmap = {
		n = 1,
		north = 1,
		ne = 2,
		northeast = 2,
		nw = 3,
		northwest = 3,
		e = 4,
		east = 4,
		w = 5,
		west = 5,
		s = 6,
		south = 6,
		se = 7,
		southeast = 7,
		sw = 8,
		southwest = 8,
		u = 9,
		up = 9,
		d = 10,
		down = 10,
		["in"] = 11,
		out = 12,
	}

	-- Check if a direction is a standard cardinal direction
	function mapper.isStandardExit(direction)
		if type(direction) ~= "string" then
			return type(direction) == "number" and direction >= 1 and direction <= 12
		end
		return exitmap[direction:lower()] ~= nil
	end

	-- The direction as Mudlet wants it, or nil when it is not one of the twelve
	-- Mudlet knows. Matched the same way mapper.isStandardExit matches, so a
	-- direction that passes that check is never quietly refused here.
	local function exitnumber(direction)
		if type(direction) == "string" then
			return exitmap[direction:lower()]
		end
		return direction
	end

	function mapper.setExit(from, to, direction)
		local dir = exitnumber(direction)
		if not dir then
			return false
		end

		return oldsetExit(from, to, dir)
	end

	function mapper.lockExit(from, direction, status)
		local dir = exitnumber(direction)
		if not dir then
			return false
		end

		return oldlockExit(from, dir, status)
	end

	function mapper.hasExitLock(from, direction)
		local dir = exitnumber(direction)
		if not dir then
			return false
		end

		return oldhasExitLock(from, dir)
	end
end
