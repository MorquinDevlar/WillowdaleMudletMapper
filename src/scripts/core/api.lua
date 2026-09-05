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

-- Puts the cursor at the start of a line of its own, so nothing the mapper
-- prints begins in the middle of a line the game left open.
local function startline()
    moveCursorEnd("main")
    if getCurrentLine() ~= "" then
        echo("\n")
    end
end

-- Writes a message on its own line, with the margin in front of the first line
-- and as many spaces in front of every line that follows.
local function write(margin, what)
    startline()
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
    startline()
    decho("<255,255,255>")
    cecho(tostring(what))
end

-- Opens a line inside a mapper.notify block for a caller that writes it itself,
-- which is what a line with a clickable link in it has to do.
function mapper.notifyIndent()
    startline()
    decho("<255,255,255>" .. string.rep(" ", #PREFIX))
end

-------------------------------------------------
-- Listings
--
-- Every listing the mapper prints - the settings, each help, the areas, the
-- tags, a room's exits - is drawn by mapper.printtable, so they all line up the
-- same way and a new one costs a table of rows rather than another copy of the
-- column arithmetic.
--
-- A column is { title = "Name:", min = 24, align = "left"|"right" }; a cell is
-- a string, a number, or { text = ..., link = "lua code", hint = "tooltip",
-- color = { r, g, b } }.

-- The first column green, the second white, the rest grey. A column's title is
-- drawn in the column's own colour, so a title says which column it heads.
local COLUMNCOLORS = { { 112, 229, 0 }, { 255, 255, 255 } }
local GREY = { 128, 128, 128 }

-- Listings are laid out to a fixed width rather than to the window: columns
-- that move with the window do not line up from one printing to the next. The
-- rule under the titles is never drawn narrower than the settings listing's,
-- which is the look every other listing was brought in line with.
local TABLEWIDTH = 100
local RULEWIDTH = 78

local function columncolor(index)
    return COLUMNCOLORS[index] or GREY
end

-- Cells are printed literally rather than through cecho, so every character in
-- one counts towards its column: "<room id>" is nine columns of help, not a
-- colour name that disappears.
local function cellwidth(text)
    text = tostring(text)
    return (utf8 and utf8.len and utf8.len(text)) or #text
end

local function ascell(cell)
    if type(cell) == "table" then
        return cell
    end
    return { text = cell == nil and "" or tostring(cell) }
end

-- One cell, in its column's colour unless it names its own, padded out to the
-- column's width. The last cell of a line is left unpadded: trailing spaces are
-- invisible right up until someone copies the line out.
local function drawcell(cell, color, width, align, last)
    local text = tostring(cell.text or "")
    local pad = math.max(width - cellwidth(text), 0)
    if align == "right" then
        echo(string.rep(" ", pad))
    end
    setFgColor(unpack(cell.color or color))
    if cell.link then
        setUnderline(true)
        echoLink(text, cell.link, cell.hint or "", true)
    else
        echo(text)
    end
    resetFormat()
    if align ~= "right" and not last then
        echo(string.rep(" ", pad))
    end
end

-- One line of cells, each in its column. A line stops at the last cell with
-- anything in it: an empty column at the end of a row is nothing to line up
-- with, and padding out to it would leave the line ending in spaces.
local function drawline(cells, columns, widths)
    local last = 0
    for i = 1, #cells do
        if tostring(cells[i].text or "") ~= "" then
            last = i
        end
    end
    startline()
    for i = 1, last do
        if i > 1 then
            echo(" ")
        end
        drawcell(cells[i], columncolor(i), widths[i] or 0, columns[i] and columns[i].align, i == last)
    end
    echo("\n")
end

-- opts.title is printed above the table through mapper.echo; opts.footer is a
-- list of grey lines printed under it.
function mapper.printtable(columns, rows, opts)
    opts, rows = opts or {}, rows or {}

    local widths = {}
    for i, column in ipairs(columns) do
        widths[i] = math.max(cellwidth(column.title or ""), column.min or 0)
    end
    for _, row in ipairs(rows) do
        for i = 1, #columns do
            widths[i] = math.max(widths[i], cellwidth(ascell(row[i]).text or ""))
        end
    end

    -- What the table is over its width comes off the last column, which is the
    -- one whose text can be carried onto a line of its own.
    local last = #columns
    local indent = 0
    for i = 1, last - 1 do
        indent = indent + widths[i] + 1
    end
    widths[last] = math.min(widths[last], math.max(TABLEWIDTH - indent, 1))

    if opts.title then
        mapper.echo(opts.title)
    end

    local titles = {}
    for i, column in ipairs(columns) do
        titles[i] = { text = column.title or "" }
    end
    drawline(titles, columns, widths)

    startline()
    drawcell({ text = string.rep("-", math.max(indent + widths[last], RULEWIDTH)) }, GREY, 0, nil, true)
    echo("\n")

    local hang = string.rep(" ", indent)
    for _, row in ipairs(rows) do
        local cells = {}
        for i = 1, last do
            cells[i] = ascell(row[i])
        end

        -- A link is one clickable word wherever it lands, so only a plain cell
        -- is carried over onto the lines below it.
        local cell = cells[last]
        local text = tostring(cell.text or "")
        local folded = cell.link and { text } or fold(text, widths[last], hang)
        cells[last] = { text = folded[1], link = cell.link, hint = cell.hint, color = cell.color }
        drawline(cells, columns, widths)

        for i = 2, #folded do
            startline()
            drawcell({ text = folded[i], color = cell.color }, columncolor(last), 0, nil, true)
            echo("\n")
        end
    end

    for _, line in ipairs(opts.footer or {}) do
        for _, folded in ipairs(fold(line, TABLEWIDTH, "")) do
            startline()
            drawcell({ text = folded }, GREY, 0, nil, true)
            echo("\n")
        end
    end
end

-- A key/value block: what one thing is, rather than a column of many of them.
-- A field is { label, value } or { label, cell, cell... }; the labels line up
-- with each other and there is no rule over them.
function mapper.printfields(fields)
    local labelwidth = 0
    for _, field in ipairs(fields) do
        labelwidth = math.max(labelwidth, cellwidth(tostring(field[1] or "")))
    end
    for _, field in ipairs(fields) do
        local cells = { { text = tostring(field[1] or "") } }
        for i = 2, #field do
            cells[i] = ascell(field[i])
        end
        drawline(cells, {}, { labelwidth })
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
	local id = tonumber(num)
	return id ~= nil and roomExists(id)
end

function mapper.isMapEmpty()
	return next(getRooms()) == nil
end

-- returns rooms in an area that have entrances from outside the area (border rooms)
function mapper.getAreaBorders(areaid)
	if mapper.debugging() then
		mapper.getAreaBordersTimer = mapper.getAreaBordersTimer or createStopWatch()
		if mapper.getAreaBordersTimer then
			startStopWatch(mapper.getAreaBordersTimer)
		end
	end
	local roomlist, endresult = getAreaRooms1(areaid), {}
	-- sometimes getAreaRooms1 can give us no result
	if not roomlist then
		mapper.echo(
			"Sorry, seems we can't go there - getAreaRooms1("
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
	for _, id in ipairs(roomlist) do
		reverselist[id] = true
	end
	local getRoomName = getRoomName
	for _, id in ipairs(roomlist) do
		local entrancesFrom = getAllRoomEntrances(id)
		for remoteRoomIndex = 1, #entrancesFrom do
			if not reverselist[entrancesFrom[remoteRoomIndex]] then
				endresult[id] = getRoomName(id)
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

