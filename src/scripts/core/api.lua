-------------------------------------------------
-- This script lists some of the API functions available from the IRE mudlet-mapper
-- not all functions that are available are included here, however.

-------------------------------------------------
-- Output
--
-- Two kinds of message, told apart by who asked for it. An answer to a command
-- the player just typed prints bare - they know where it came from. Anything
-- that arrives on its own, a walk reporting in or a room being mapped, carries
-- the "Mapper: " prefix, because it lands in the middle of the game's own
-- output and has to be told apart from it.
--
-- Both fold their own long lines. Left to Mudlet, the tail of a folded line
-- restarts in column zero and reads as a message of its own; folded here it
-- lines up under the text it belongs to, and a block of lines carries the
-- prefix on its first line instead of on all of them.

local PREFIX = "Mapper: "

-- The column output is folded at: the narrower of what the player set the main
-- window to wrap at and what fits in it, and 80 if Mudlet will not say.
local function foldcolumn()
    local width
    local function narrower(get)
        if type(get) ~= "function" then
            return
        end
        local ok, columns = pcall(get, "main")
        if ok and type(columns) == "number" and columns > 20 then
            width = math.min(width or columns, columns)
        end
    end
    narrower(getWindowWrap)
    narrower(getColumnCount)
    return (width or 80) - 1
end

-- What a line takes up on screen: colour markup is not characters.
local function displaywidth(text)
    local plain = text:gsub("<[^<>]*>", "")
    return (utf8 and utf8.len and utf8.len(plain)) or #plain
end

-- One line as the lines it is written on, broken at spaces. The tail lines up
-- under the text it came from - under the words of a bullet, not under its
-- dash - and is indented by `hang` on top of that, which is what keeps an
-- unprefixed message from folding back into column zero and reading as a new
-- one. A line that already fits is returned untouched, so output laid out in
-- columns keeps its spacing.
local function fold(text, width, hang)
    if width < 20 or displaywidth(text) <= width then
        return { text }
    end
    local lead = text:match("^[ \t]*")
    local bullet = text:match("^[ \t]*(%-[ \t]+)")
    hang = hang .. lead .. string.rep(" ", bullet and #bullet or 0)
    local folded, line, used, empty = {}, lead, #lead, true
    for gap, word in text:sub(#lead + 1):gmatch("([ \t]*)([^ \t]+)") do
        local wide = displaywidth(word)
        if not empty and used + #gap + wide > width then
            folded[#folded + 1] = line
            line, used = hang .. word, #hang + wide
        else
            line, used = line .. gap .. word, used + #gap + wide
        end
        empty = false
    end
    folded[#folded + 1] = line
    return folded
end

-- The lines of a message: a string, or a list of strings that belong together,
-- either of which may carry newlines of its own.
local function lines(what)
    local given = type(what) == "table" and what or { what }
    local result = {}
    for i = 1, #given do
        for line in (tostring(given[i] or "") .. "\n"):gmatch("([^\n]*)\n") do
            result[#result + 1] = line
        end
    end
    return result
end

-- Writes a message on its own line, with the margin in front of the first line
-- and as many spaces in front of every line that follows.
local function write(margin, what)
    moveCursorEnd("main")
    if getCurrentLine() ~= "" then
        echo("\n")
    end
    local indent = string.rep(" ", #margin)
    local width = foldcolumn() - #margin
    -- A margin already sets a folded tail apart from the line above it; without
    -- one the tail has to say so itself.
    local hang = margin == "" and "  " or ""
    local first = true
    for _, line in ipairs(lines(what)) do
        for _, folded in ipairs(fold(line, width, hang)) do
            if first then
                decho("<73,149,0>" .. margin .. "<255,255,255>")
                first = false
            elseif folded ~= "" then
                decho("<255,255,255>" .. indent)
            end
            cecho(folded)
            echo("\n")
        end
    end
end

-- An answer to something the player just typed.
function mapper.echo(what)
    write("", what or "")
end

-- A message that arrives on its own, in among the game's own output: a walk
-- reporting in, a room being mapped, an update being available, debug.
function mapper.notify(what)
    write(PREFIX, what or "")
end

-- Whether debug output is on. Read through this rather than off the settings
-- table: the map, and the handlers a loaded map runs, arrive before
-- sysLoadEvent builds the settings, so mapper.settings.debug is an index into
-- nil for the first part of a profile's life.
function mapper.debugging()
    return mapper.settings ~= nil and mapper.settings.debug == true
end

-- As mapper.echo, but leaves the cursor on the line for a caller that writes
-- the rest of it itself.
function mapper.echon(what)
    moveCursorEnd("main")
    if getCurrentLine() ~= "" then
        echo("\n")
    end
    decho("<255,255,255>")
    cecho(tostring(what))
end

-- Opens a line inside a mapper.notify block for a caller that writes it itself,
-- which is what a line with a clickable link in it has to do.
function mapper.notifyIndent()
    moveCursorEnd("main")
    if getCurrentLine() ~= "" then
        echo("\n")
    end
    decho("<255,255,255>" .. string.rep(" ", #PREFIX))
end

function mapper.deleteLineP()
	deleteLine()
	tempLineTrigger(
		1,
		1,
		[[
    if isPrompt() then deleteLine() end
  ]]
	)
end

function mapper.mapLook(roomid, delay)
	centerview(roomid)
	if mapper.maplooktimer then
		killTimer(mapper.maplooktimer)
	end
	mapper.maplooktimer = tempTimer(tonumber(delay) or 4, [[centerview(mapper.currentroom); mapper.maplooktimer = nil]])
end

function mapper.getnums(roomname, exact)
	if tonumber(roomname) then
		return { roomname }
	end

	local t = (not exact and mapper.searchRoom or mapper.searchRoomExact)(roomname)

	if not t or not next(t) then
		return nil
	end

	local result = {}

	if not tonumber(select(2, next(t))) then
		for roomid, _ in pairs(t) do
			if roomid ~= 0 then
				result[#result + 1] = tonumber(roomid)
			end
		end
	else
		for _, roomid in pairs(t) do
			if roomid ~= 0 then
				result[#result + 1] = tonumber(roomid)
			end
		end
	end

	return result
end

-- searchRoom with a cache!
local cache = {}
setmetatable(cache, { __mode = "kv" }) -- weak keys/values = it'll periodically get cleaned up by gc

function mapper.searchRoom(what)
	local result = cache[what]
	if not result then
		result = searchRoom(what)
		local realResult = {}
		for key, value in pairs(type(result) == "table" and result or {}) do
			-- both ways, because searchRoom can return either id-room name or the reverse
			if type(key) == "string" then
				realResult[key:ends(" (road)") and key:sub(1, -8) or key] = value
			else
				realResult[key] = value:ends(" (road)") and value:sub(1, -8) or value
			end
		end
		cache[what] = realResult
		result = realResult
	end
	return result
end

local function endswith(s, suffix)
	return s:sub(#s - #suffix + 1) == suffix
end

function mapper.searchRoomExact(what)
	if type(what) ~= "string" then
		return
	end

	local roomTable = mapper.searchRoom(what)
	local realResult = {}
	what = what:lower()
	for key, value in pairs(roomTable) do
		if type(key) == "string" and (key:lower() == what or (endswith(key, ".") and key:sub(1, -2) == what)) then
			realResult[key:ends(" (road)") and key:sub(1, -8) or key] = value
		elseif
			type(value) == "string" and (value:lower() == what or (endswith(value, ".") and value:sub(1, -2) == what))
		then
			realResult[key] = value:ends(" (road)") and value:sub(1, -8) or value
		end
	end
	if table.is_empty(realResult) then
		return roomTable
	else
		return realResult
	end
end

function mapper.findAreaID(areaname, exact)
	local areaname = areaname:lower()
	local list = getAreaTable()

	-- iterate over the list of areas, matching them with substring match.
	-- if we get match a single area, then return it's ID, otherwise return
	-- 'false' and a message that there are than one are matches
	local returnid, fullareaname, multipleareas = nil, nil, {}
	for area, id in pairs(list) do
		if (not exact and area:lower():find(areaname, 1, true)) or (exact and areaname == area:lower()) then
			returnid = id
			fullareaname = area
			multipleareas[#multipleareas + 1] = area
		end
	end

	if #multipleareas == 1 then
		return returnid, fullareaname
	else
		return nil, nil, multipleareas
	end
end

function mapper.roomexists(num)
	if not num then
		return false
	end
	if roomExists then
		return roomExists(num)
	end

	local s, m = pcall(getRoomArea, tonumber(num))
	return (s and true or false)
end

function mapper.isMapEmpty()
	local areaTable = getAreaTable()
	for _, areaId in pairs(areaTable) do
		if areaId ~= 0 then
			local rooms = getAreaRooms(areaId) or {}
			if next(rooms) then
				return false
			end
		end
	end
	return true
end

-- accepts areaname or ID
function mapper.cleanAreaName(area)
	local areaname = type(area) == "number" and mapper.areatabler[area] or area
	if not areaname then
		return area
	end

	-- strip , the
	areaname = areaname:gsub(", the$", "")

	-- strip , the Type of
	areaname = areaname:gsub(", the %w+ of$", "")

	-- strip , the Type of (important)
	areaname = areaname:gsub(", the %w+ of %((.+)%)$", " (%1)")

	-- strip , the (important)
	areaname = areaname:gsub(", the %((.+)%)$", " (%1)")

	return areaname
end

-- if this room is in a unique area, report it. Otherwise gives nil
function mapper.getexactarea(roomname)
	local rooms = mapper.searchRoomExact(roomname)

	if not rooms or not next(rooms) then
		return nil
	end

	local areaid
	for roomid, roomname in pairs(rooms) do
		local caid = getRoomArea(roomid)
		if areaid and areaid ~= caid then
			return nil
		end
		areaid = caid
	end

	if areaid then
		return mapper.areatabler[areaid]
	end
end

-- returns the area name of a room or ?
function mapper.getAreaName(roomid)
	return mapper.areatabler[getRoomArea(roomid)] or "?"
end

-- returns rooms in an area that have entrances from outside the area (border rooms)
function mapper.getAreaBorders(areaid)
	if mapper.debugging() then
		mapper.getAreaBordersTimer = mapper.getAreaBordersTimer or createStopWatch()
		startStopWatch(mapper.getAreaBordersTimer)
	end
	local roomlist, endresult = getAreaRooms(areaid), {}
	-- sometimes getAreaRooms can give us no result
	if not roomlist then
		mapper.echo(
			"Sorry, seems we can't go there - getAreaRooms("
				.. areaid
				.. ") didn't give us any results (Mudlet problem - redownloading the map might help fix it)"
		)
		return {}
	end
	if table.is_empty(roomlist) then
		mapper.echo("Sorry, seems we can't go there - " .. getRoomAreaName(areaid) .. " has no rooms in it.")
		return {}
	end
	-- make a key-value list of room IDs
	local reverselist = {}
	for i = 0, #roomlist do
		reverselist[roomlist[i]] = true
	end
	local getRoomName, pairs = getRoomName, pairs
	if getAllRoomEntrances then
		for i = 0, #roomlist do
			local id = roomlist[i]
			local entrancesFrom = getAllRoomEntrances(id)
			for remoteRoomIndex = 1, #entrancesFrom do
				if not reverselist[entrancesFrom[remoteRoomIndex]] then
					endresult[id] = getRoomName(id)
				end
			end
		end
	else
		local getRoomExits, getSpecialExitsSwap = getRoomExits, getSpecialExitsSwap
		for i = 0, #roomlist do
			local id = roomlist[i]
			local exits = getRoomExits(id)
			for _, to in pairs(exits) do
				if not reverselist[to] then
					endresult[id] = getRoomName(id)
				end
			end
			local specialexits = getSpecialExitsSwap(id)
			for _, to in pairs(specialexits) do
				if not reverselist[to] then
					endresult[id] = getRoomName(id)
				end
			end
		end
	end
	if mapper.debugging() then
		mapper.notify(
			"mapper.getAreaBorders() on areaid "
				.. areaid
				.. " took "
				.. stopStopWatch(mapper.getAreaBordersTimer)
				.. "s to run. Returned "
				.. table.size(endresult)
				.. " results."
		)
	end
	return endresult
end

