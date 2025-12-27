-- translates n to north and so forth
local temp = {
	n = "north",
	e = "east",
	s = "south",
	w = "west",
	ne = "northeast",
	se = "southeast",
	sw = "southwest",
	nw = "northwest",
	u = "up",
	d = "down",
	i = "in",
	o = "out",
	["in"] = "in",
}
local anytolongmap = {}
local anytoshortmap = {}
for s, l in pairs(temp) do
	anytolongmap[l] = l
	anytolongmap[s] = l
	anytoshortmap[l] = s
	anytoshortmap[s] = s
end
-- Handle "out" which maps to "o" (not in temp table)
anytoshortmap["out"] = "o"
anytoshortmap["o"] = "o"

function mapper.anytolong(exit)
	return anytolongmap[exit]
end

function mapper.anytoshort(exit)
	return anytoshortmap[exit]
end

function mapper.ranytolong(exit)
	local t = {
		n = "south",
		north = "south",
		e = "west",
		east = "west",
		s = "north",
		south = "north",
		w = "east",
		west = "east",
		ne = "southwest",
		northeast = "southwest",
		se = "northwest",
		southeast = "northwest",
		sw = "northeast",
		southwest = "northeast",
		nw = "southeast",
		northwest = "southeast",
		u = "down",
		up = "down",
		d = "up",
		down = "up",
		i = "out",
		["in"] = "out",
		o = "in",
		out = "in",
	}

	return t[exit]
end

-- returns nil or the room number relative to this one
function mapper.relativeroom(from, dir)
	if not mapper.roomexists(from) then
		return
	end

	local exits = getRoomExits(tonumber(from))
	return exits[mapper.anytolong(dir)]
end
