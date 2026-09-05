-- The mapper's whole command surface. Four aliases reach it: `mapper <verb>`
-- through dispatch, and mconfig, mstop and showpath straight into the function
-- the matching verb would have reached.
mapper.commands = mapper.commands or {}

-- The two colours a listing says something with rather than about a column:
-- whether a walk may go there, and whether a click undoes something.
local RED, GREEN = { 255, 0, 0 }, { 0, 200, 0 }

-- Every help the mapper prints is a table of rows printed by this, so a command
-- reads the same wherever it is listed and a new one costs a row rather than
-- another copy of the loop.
local function printCommands(title, commands, footer)
    local rows = {}
    for _, c in ipairs(commands) do
        rows[#rows + 1] = { c.cmd, c.args, c.desc }
    end
    mapper.printtable({
        { title = "Command:" },
        { title = "Args:" },
        { title = "Description:" },
    }, rows, { title = title, footer = footer })
end

-- The words of an argument string, so a subcommand can take them apart without
-- repeating the pattern.
local function words(args)
    local parts = {}
    for word in tostring(args or ""):gmatch("%S+") do
        parts[#parts + 1] = word
    end
    return parts
end

-- An area named either way a player might name one: by ID, or by name with an
-- exact match preferred over a partial one. Returns the ID and the full name.
local function resolveArea(what)
    local id = tonumber(what)
    if id then
        local name = getRoomAreaName(id)
        if type(name) ~= "string" or name == "" then
            return nil
        end
        return id, name
    end

    local areaId, areaName = mapper.findAreaID(what, true)
    if not areaId then
        areaId, areaName = mapper.findAreaID(what, false)
    end
    return areaId, areaName
end

-- How many rooms an area holds. getAreaRooms1 is the 1-indexed listing;
-- getAreaRooms starts at 0, which every count and every `rooms[1]` gets wrong.
local function areaRooms(areaId)
    return getAreaRooms1(areaId) or {}
end

--------------------------------------------------------------------------------
-- Walking
--------------------------------------------------------------------------------

function mapper.commands.gotoDestination(where)
    if not where or where == "" then
        return printCommands("Walking somewhere:", {
            { cmd = "mapper goto", args = "<room id>",         desc = "Walk to a room by its ID" },
            { cmd = "mapper goto", args = "<tag>",             desc = "Walk to the nearest room with a tag" },
            { cmd = "mapper goto", args = "<area name>",       desc = "Walk to the nearest way into an area" },
            { cmd = "mapper goto", args = "<area name> <num>", desc = "Walk to the numbered one of several matches" },
            { cmd = "mapper goto", args = "tag <name>",        desc = "Walk to a tag an area happens to share a name with" },
        })
    end

    local dest = where:lower()
    if mapper.debugging() then
        mapper.gotoPerf = mapper.gotoPerf or createStopWatch()
        if mapper.gotoPerf then
            startStopWatch(mapper.gotoPerf)
        end
    end

    -- A number is a room, a word that names a tag is that tag, and anything else
    -- is an area. `goto tag <name>` says which for the name that is both.
    if tonumber(dest) then
        mapper.gotoRoom(dest)
    else
        local parts = words(dest)
        if parts[1] == "tag" then
            table.remove(parts, 1)
            mapper.gotoTag(table.concat(parts, " "))
        elseif mapper.istag(dest) then
            mapper.gotoTag(dest)
        elseif tonumber(parts[#parts]) and #parts > 1 then
            mapper.gotoArea(dest:sub(1, -#parts[#parts] - 2), tonumber(parts[#parts]))
        else
            mapper.gotoArea(dest)
        end
    end

    if mapper.debugging() and mapper.gotoPerf then
        mapper.notify("goto took " .. stopStopWatch(mapper.gotoPerf) .. "s to run.")
    end
end

-- Show the way somewhere without walking it, and highlight it on the map.
function mapper.commands.path(args)
    if not args or args == "" then
        return printCommands("Showing the way somewhere:", {
            { cmd = "mapper path",       args = "<to>",        desc = "The way there from where you are" },
            { cmd = "mapper path",       args = "<to> <from>", desc = "The way between two rooms" },
            { cmd = "mapper path clear", args = "",            desc = "Take the highlight off the map" },
            { cmd = "showpath",          args = "<to> [from]", desc = "Shorthand for 'mapper path'" },
        })
    end

    if args:lower() == "clear" then
        mapper.clearShowPath()
        mapper.echo("Path highlight cleared.")
        return
    end

    local parts = words(args)
    local to = tonumber(parts[1])
    if not to then
        mapper.echo("Not a room ID: " .. parts[1])
        return
    end

    local from = mapper.currentroom
    if parts[2] then
        from = tonumber(parts[2])
        if not from then
            mapper.echo("Not a room ID: " .. parts[2])
            return
        end
    elseif not from or not roomExists(from) then
        mapper.echo("You have to be in a mapped room, or say which room to start from.")
        return
    end

    mapper.echoPath(from, to)
end

--------------------------------------------------------------------------------
-- Mapping
--------------------------------------------------------------------------------

function mapper.commands.mappingOn()
    if mapper.editing then
        mapper.echo("Mapping is already on.")
        return
    end
    mapper.editing = true
    mapper.regenerateareas()
    mapper.echo("Mapping is on. Rooms will be created as you explore.")
end

function mapper.commands.mappingOff()
    if not mapper.editing then
        mapper.echo("Mapping is already off.")
        return
    end
    mapper.editing = false
    mapper.echo("Mapping is off. No new rooms will be created.")
end

-- Wiping the map is not undoable and the map is rebuilt only by walking it
-- again, so the first `mapper reset` only warns and the second one does it.
function mapper.commands.reset()
    if not mapper.pendingMapReset then
        mapper.pendingMapReset = true
        mapper.echo("This deletes every room, area and label on the map. Type 'mapper reset' again to confirm.")
        return
    end
    mapper.pendingMapReset = nil

    local ok, err = deleteMap()
    if not ok then
        mapper.echo("Couldn't delete the map: " .. tostring(err or "unknown error"))
        return
    end

    mapper.regenerateareas()
    raiseEvent("mapper updated map")
    mapper.echo("Deleted the map. It will be built again as you walk.")
end

--------------------------------------------------------------------------------
-- Looking things up
--------------------------------------------------------------------------------

function mapper.commands.find(name)
    if not name or name == "" then
        mapper.echo("Which room name would you like to look for? Use: mapper find <name>")
        return
    end
    mapper.roomFind(name)
end

function mapper.commands.look(what)
    mapper.roomlook(what ~= "" and what or nil)
end

function mapper.commands.rooms(area)
    if not area or area == "" then
        area = mapper.areatabler and mapper.currentroom and roomExists(mapper.currentroom)
            and mapper.areatabler[getRoomArea(mapper.currentroom)]
        if not area then
            mapper.echo("Which area's rooms would you like listed? Use: mapper rooms <area>")
            return
        end
    end
    mapper.echoRoomList(area)
end

function mapper.commands.view(what)
    if not what or what == "" then
        if not mapper.currentroom or not roomExists(mapper.currentroom) then
            mapper.echo("You are not in a mapped room. Use: mapper view <room id or area name>")
            return
        end
        centerview(mapper.currentroom)
    elseif tonumber(what) then
        centerview(tonumber(what))
    else
        mapper.viewArea(what)
    end
end

-- Labels are the player's own writing on the map, so they are all drawn alike
-- rather than each carrying a colour the command has to be told.
function mapper.commands.label(args)
    if not args or args == "" then
        mapper.echo("What should the label say? Use: mapper label [room id] <text>")
        return
    end
    mapper.roomLabel(args)
end

--------------------------------------------------------------------------------
-- Tags
--------------------------------------------------------------------------------

function mapper.commands.tagHelp()
    printCommands("Tagging rooms:", {
        { cmd = "mapper tag",   args = "<name> [room]",        desc = "Put a tag on a room" },
        { cmd = "mapper tag",   args = "<name> symbol <char>", desc = "Draw a character on every room with that tag" },
        { cmd = "mapper tag",   args = "<name> symbol none",   desc = "Stop drawing that tag's character" },
        { cmd = "mapper untag", args = "<name> [room]",        desc = "Take a tag off a room" },
        { cmd = "mapper tags",  args = "",                     desc = "List the tags and how many rooms carry each" },
        { cmd = "mapper tags",  args = "<name>",               desc = "List the rooms carrying one tag" },
        { cmd = "mapper goto",  args = "<name>",               desc = "Walk to the nearest room with that tag" },
    }, {
        "A tag is one word of letters, digits, underscores or hyphens - not digits",
        "alone, which is how a room is named. Naming a tag that does not exist yet",
        "creates it.",
    })
end

-- "help" is the one word that cannot be a tag name, since typing it has to
-- reach the help rather than tag the room you are standing in with it.
function mapper.commands.tag(args)
    local parts = words(args)
    if #parts == 0 or parts[1]:lower() == "help" then
        return mapper.commands.tagHelp()
    end
    if parts[2] and parts[2]:lower() == "symbol" then
        return mapper.tagsymbol(parts[1], parts[3])
    end
    return mapper.tagroom(parts[1], parts[2])
end

function mapper.commands.untag(args)
    local parts = words(args)
    if #parts == 0 or parts[1]:lower() == "help" then
        return mapper.commands.tagHelp()
    end
    return mapper.untagroom(parts[1], parts[2])
end

function mapper.commands.tags(args)
    local parts = words(args)
    if #parts == 0 then
        return mapper.listtags()
    end
    if parts[1]:lower() == "help" then
        return mapper.commands.tagHelp()
    end
    return mapper.listtagrooms(parts[1])
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

function mapper.commands.configHelp()
    printCommands("Settings:", {
        { cmd = "mapper config",      args = "",                 desc = "Show every setting and its value" },
        { cmd = "mapper config",      args = "<option>",         desc = "Show what one setting does" },
        { cmd = "mapper config",      args = "<option> <value>", desc = "Give a setting a new value" },
        { cmd = "mapper config help", args = "",                 desc = "Show this help" },
        { cmd = "mconfig",            args = "[option] [value]", desc = "Shorthand for 'mapper config'" },
    }, {
        "Settings that are on or off take on|off, true|false or yes|no.",
        "Numeric settings take a decimal number, for instance 0.3.",
    })
end

function mapper.commands.config(args)
    -- The map, and the handlers a loaded map runs, arrive before sysLoadEvent
    -- builds the settings, so there is a window where there is nothing to show
    if not mapper.settings then
        mapper.echo("The mapper's settings aren't loaded yet - try again in a moment.")
        return
    end

    if not args or args == "" then
        mapper.settings:showAllOptions()
        return
    end

    if args:lower() == "help" then
        return mapper.commands.configHelp()
    end

    -- The value is the rest of the line, so a setting that takes words keeps them
    local option, val = args:match("^(%S+)%s*(.-)%s*$")

    if val == "" then
        local description, accepted, current = mapper.settings:describe(option)
        if not description then
            mapper.echo("There is no '" .. option .. "' setting. 'mapper config' lists them all.")
            return
        end
        echo("\n")
        decho("<112,229,0>" .. option .. ":<255,255,255> " .. description .. "\n")
        decho("<112,229,0>Current value: <255,255,255>" .. current .. "\n")
        -- A setting whose description is already the list of values it takes
        -- does not need that list printed under it again
        if accepted ~= description then
            decho("<112,229,0>Accepted values: <128,128,128>" .. accepted .. "\n")
        end
        return
    end

    -- The raw word goes through: setOption knows what type the setting is and
    -- turns "on", "yes" and "0.3" into the value that setting takes.
    mapper.settings:setOption(option, val)
end

function mapper.commands.debug(args)
    local value = tostring(args or ""):lower()
    if value ~= "on" and value ~= "off" then
        mapper.echo("Use: mapper debug on|off")
        return
    end
    if not mapper.settings then
        mapper.echo("The mapper's settings aren't loaded yet - try again in a moment.")
        return
    end
    mapper.settings:setOption("debug", value)
end

--------------------------------------------------------------------------------
-- Areas
--------------------------------------------------------------------------------

mapper.commands.area = {}

function mapper.commands.area.help()
    printCommands("Area commands:", {
        { cmd = "mapper area",        args = "",         desc = "Show the room and area you are in" },
        { cmd = "mapper area list",   args = "[filter]", desc = "List the areas of the map" },
        { cmd = "mapper area lock",   args = "[name]",   desc = "Keep walks out of an area" },
        { cmd = "mapper area unlock", args = "<name>",   desc = "Let walks back into an area" },
        { cmd = "mapper area labels", args = "[area]",   desc = "List and delete an area's map labels" },
        { cmd = "mapper area help",   args = "",         desc = "Show this help" },
    })
end

-- Show current area and room info
function mapper.commands.area.info()
    if not mapper.currentroom or not roomExists(mapper.currentroom) then
        mapper.echo("You are not in a mapped room.")
        return
    end

    local roomId = mapper.currentroom
    local areaId = getRoomArea(roomId)
    local areaName = (mapper.areatabler and mapper.areatabler[areaId]) or getRoomAreaName(areaId) or "Unknown"
    local rooms = areaRooms(areaId)

    local labels = getMapLabels(areaId) or {}
    local labelCount = 0
    for _ in pairs(labels) do labelCount = labelCount + 1 end

    local x, y, z = getRoomCoordinates(roomId)
    local roomChar = getRoomChar(roomId) or ""

    mapper.echo("Current location:")

    -- The room and the area it is in read as one block of fields rather than as
    -- two: the area carries its ID the way the room's exits carry theirs, so
    -- there is no second "ID:" line to work out which of the two it belongs to.
    local locked = (mapper.locked and mapper.locked[areaId]) and true or false
    local fields = {
        { "Room:",   mapper.roomName(roomId) },
        { "ID:",     roomId },
        { "Coords:", x .. ", " .. y .. ", " .. z },
    }
    if roomChar ~= "" then
        fields[#fields + 1] = { "Char:", roomChar }
    end
    fields[#fields + 1] = { "Area:", string.format("%s (%d)", areaName, areaId) }
    fields[#fields + 1] = { "Rooms:", #rooms }
    fields[#fields + 1] = { "Status:", { text = locked and "Locked" or "Open", color = locked and RED or GREEN } }
    if labelCount > 0 then
        fields[#fields + 1] = { "Labels:", labelCount }
    end
    mapper.printfields(fields)

    -- Rooms the map draws a character in are the ones worth listing: shops, inns
    -- and whatever else the biome data marks out.
    local charRooms = {}
    for _, rid in ipairs(rooms) do
        local char = getRoomChar(rid)
        if char and char ~= "" then
            charRooms[#charRooms + 1] = { id = rid, name = mapper.roomName(rid), char = char }
        end
    end

    if #charRooms > 0 then
        table.sort(charRooms, function(a, b) return a.name:lower() < b.name:lower() end)

        local rows = {}
        for _, r in ipairs(charRooms) do
            rows[#rows + 1] = { r.id, r.name, r.char, {
                text = "Go to",
                link = [[mapper.gotoRoom(]] .. r.id .. [[)]],
                hint = "Navigate to this room",
                color = GREEN,
            } }
        end

        mapper.printtable({
            { title = "ID:" },
            { title = "Name:" },
            { title = "Char:" },
            { title = "" },
        }, rows, { title = "Marked rooms (" .. #charRooms .. "):" })
    end
end

function mapper.commands.area.list(filter)
    local areas = {}
    for name, id in pairs(getAreaTable()) do
        if mapper.islistablearea(id) then
            if not filter or filter == "" or name:lower():find(filter:lower(), 1, true) then
                areas[#areas + 1] = {
                    name = name,
                    id = id,
                    rooms = #areaRooms(id),
                    locked = (mapper.locked and mapper.locked[id]) and true or false,
                }
            end
        end
    end

    table.sort(areas, function(a, b) return a.name:lower() < b.name:lower() end)

    if #areas == 0 then
        if filter and filter ~= "" then
            mapper.echo("No areas matching '" .. filter .. "'.")
        else
            mapper.echo("No areas found.")
        end
        return
    end

    local rows = {}
    for _, area in ipairs(areas) do
        rows[#rows + 1] = {
            area.id,
            area.name,
            area.rooms,
            { text = area.locked and "Locked" or "Open", color = area.locked and RED or GREEN },
            area.locked
            and { text = "Unlock", link = [[mapper.commands.area.unlock(]] .. area.id .. [[)]],
                hint = "Unlock this area", color = GREEN }
            or { text = "Lock", link = [[mapper.commands.area.lock(]] .. area.id .. [[)]],
                hint = "Lock this area", color = { 180, 180, 0 } },
        }
    end

    mapper.printtable({
        { title = "ID:" },
        { title = "Name:" },
        { title = "Rooms:", align = "right" },
        { title = "Status:" },
        { title = "" },
    }, rows, {
        title = (filter and filter ~= "") and ("Areas matching '" .. filter .. "':") or "Areas:",
    })
end

-- Lock or unlock an area named by ID or by name. Locking with nothing named
-- shows the clickable list instead, which is the only way to lock several areas
-- without typing each name out.
local function setAreaLock(what, lock)
    if (not what or what == "") and not lock then
        mapper.echo("Which area should be unlocked? Use: mapper area unlock <name>")
        return
    end
    if not what or what == "" then
        return mapper.doLockArea()
    end

    local areaId, areaName = resolveArea(what)
    if not areaId then
        mapper.echo("Don't know of any area named '" .. tostring(what) .. "'.")
        return
    end

    local isLocked = (mapper.locked and mapper.locked[areaId]) and true or false
    if isLocked == lock then
        mapper.echo("Area '" .. areaName .. "' is already " .. (lock and "locked" or "unlocked") .. ".")
        return
    end

    mapper.lockArea(areaName, lock, true)
end

function mapper.commands.area.lock(name)
    setAreaLock(name, true)
end

function mapper.commands.area.unlock(name)
    setAreaLock(name, false)
end

function mapper.commands.area.labels(areaArg)
    local areaId, areaName

    if not areaArg or areaArg == "" then
        if not mapper.currentroom or not roomExists(mapper.currentroom) then
            mapper.echo("You are not in a mapped room. Name an area instead.")
            return
        end
        areaId = getRoomArea(mapper.currentroom)
        areaName = (mapper.areatabler and mapper.areatabler[areaId]) or getRoomAreaName(areaId) or "Unknown"
    else
        areaId, areaName = resolveArea(areaArg)
        if not areaId then
            mapper.echo("Don't know of any area named '" .. areaArg .. "'.")
            return
        end
    end

    local labelList = {}
    for labelId, labelText in pairs(getMapLabels(areaId) or {}) do
        labelList[#labelList + 1] = { id = labelId, text = tostring(labelText) }
    end

    if #labelList == 0 then
        mapper.echo("No labels in area '" .. areaName .. "'.")
        return
    end

    table.sort(labelList, function(a, b) return a.id < b.id end)

    local rows = {}
    for _, label in ipairs(labelList) do
        rows[#rows + 1] = { label.id, label.text, {
            text = "Delete",
            link = [[deleteMapLabel(]] .. areaId .. [[, ]] .. label.id .. [[); mapper.echo("Label deleted.")]],
            hint = "Click to delete this label",
            color = RED,
        } }
    end

    mapper.printtable({
        { title = "ID:" },
        { title = "Text:" },
        { title = "" },
    }, rows, { title = "Labels in area '" .. areaName .. "':" })
end

function mapper.commands.area.dispatch(args)
    if not args or args == "" then
        return mapper.commands.area.info()
    end

    local subcommand, rest = args:match("^(%S+)%s*(.-)%s*$")
    subcommand = subcommand:lower()

    local handlers = {
        list = mapper.commands.area.list,
        lock = mapper.commands.area.lock,
        unlock = mapper.commands.area.unlock,
        labels = mapper.commands.area.labels,
        help = mapper.commands.area.help,
    }

    if not handlers[subcommand] then
        mapper.echo("There is no 'mapper area " .. subcommand .. "'.")
        return mapper.commands.area.help()
    end
    return handlers[subcommand](rest)
end

--------------------------------------------------------------------------------
-- Exit locks
--------------------------------------------------------------------------------

mapper.commands.exit = {}

function mapper.commands.exit.help()
    printCommands("Exit locks:", {
        { cmd = "mapper lock",   args = "<direction>",        desc = "Lock an exit of the room you are in" },
        { cmd = "mapper lock",   args = "<room> <direction>", desc = "Lock an exit of a room by ID" },
        { cmd = "mapper unlock", args = "<direction>",        desc = "Unlock an exit of the room you are in" },
        { cmd = "mapper unlock", args = "<room> <direction>", desc = "Unlock an exit of a room by ID" },
    }, {
        "A locked exit is left out of pathfinding, which is how you keep a walk",
        "away from a dangerous way or force it along another.",
        "Directions: n, ne, e, se, s, sw, w, nw, up, down, in, out, or their long names.",
    })
end

-- Lock or unlock one exit. Both commands are the same walk through the map, so
-- they are the same function with the state to leave the exit in.
local function setExitLock(args, lock)
    if not args or args == "" then
        return mapper.commands.exit.help()
    end

    local parts = words(args)
    local roomId, direction

    if #parts == 1 then
        if not mapper.currentroom or not roomExists(mapper.currentroom) then
            mapper.echo("You are not in a mapped room. Name one: mapper "
                .. (lock and "lock" or "unlock") .. " <room> <direction>")
            return
        end
        roomId = mapper.currentroom
        direction = parts[1]:lower()
    else
        roomId = tonumber(parts[1])
        if not roomId then
            mapper.echo("Not a room ID: " .. parts[1])
            return
        end
        direction = parts[2]:lower()
    end

    if not roomExists(roomId) then
        mapper.echo("Room " .. roomId .. " doesn't exist.")
        return
    end

    if not mapper.isStandardExit(direction) then
        mapper.echo("There is no such direction as '" .. direction .. "'.")
        mapper.echo("Directions: n, ne, e, se, s, sw, w, nw, up, down, in, out, or their long names.")
        return
    end

    -- getRoomExits keys its table by the long name of each direction
    if not (getRoomExits(roomId) or {})[mapper.dirlong(direction)] then
        mapper.echo("Room " .. roomId .. " has no exit to the " .. direction .. ".")
        return
    end

    if (mapper.hasExitLock(roomId, direction) and true or false) == lock then
        mapper.echo("The " .. direction .. " exit of room " .. roomId
            .. " is already " .. (lock and "locked" or "unlocked") .. ".")
        return
    end

    mapper.lockExit(roomId, direction, lock)
    if lock then
        mapper.echo(string.format("Locked the %s exit of %s. Walks will not use it.",
            direction, mapper.roomName(roomId, true)))
    else
        mapper.echo(string.format("Unlocked the %s exit of %s. Walks can use it again.",
            direction, mapper.roomName(roomId, true)))
    end
end

function mapper.commands.exit.lock(args)
    setExitLock(args, true)
end

function mapper.commands.exit.unlock(args)
    setExitLock(args, false)
end

--------------------------------------------------------------------------------
-- Terrain weights
--------------------------------------------------------------------------------

mapper.commands.terrain = {}

-- What a weight means, said the same way under the listing and in the help.
local terrainmeaning = {
    "A weight is what crossing one room of that ground costs a walk. 1 is an ordinary",
    "room; 5 means a walk treats one such room as five ordinary ones and goes round",
    "when a shorter detour exists.",
}

-- The forms of the command, for the listing, which has no help table over it.
local terrainforms = {
    "'mapper terrain water 5' weights one biome, 'mapper terrain water clear' takes",
    "that weight off again, and 'mapper terrain clear' takes them all off.",
}

function mapper.commands.terrain.help()
    local footer = { terrainmeaning[1], terrainmeaning[2], terrainmeaning[3],
        "The safewalk setting weights every biome the game does not mark safe, without",
        "your having to name them: 'mconfig safewalk on'." }
    printCommands("Terrain weights:", {
        { cmd = "mapper terrain",       args = "",                 desc = "List the biomes and what each costs a walk" },
        { cmd = "mapper terrain",       args = "<biome> <weight>", desc = "Make that ground cost more to cross (1-50)" },
        { cmd = "mapper terrain",       args = "<biome> clear",    desc = "Take the weight off one biome" },
        { cmd = "mapper terrain clear", args = "",                 desc = "Take every weight off" },
        { cmd = "mapper terrain help",  args = "",                 desc = "Show this help" },
    }, footer)
end

function mapper.commands.terrain.list()
    local names = mapper.knownbiomes()
    if #names == 0 then
        mapper.echo("No biomes are known yet - they arrive with the game's own data when you connect.")
        return
    end

    local rows = {}
    for _, name in ipairs(names) do
        local weight = mapper.terrainweights[name] or 1
        rows[#rows + 1] = {
            name,
            -- A weight of 1 is what every room costs anyway; the ones the player
            -- has set are the ones worth picking out of the column
            { text = tostring(weight), color = weight > 1 and { 255, 255, 0 } or nil },
            mapper.issafebiome(name) and "yes" or "",
        }
    end

    local footer = {}
    for _, line in ipairs(terrainmeaning) do
        footer[#footer + 1] = line
    end
    for _, line in ipairs(terrainforms) do
        footer[#footer + 1] = line
    end

    mapper.printtable({
        { title = "Biome:" },
        { title = "Weight:", align = "right" },
        { title = "Safe:" },
    }, rows, { title = "Terrain weights:", footer = footer })
end

function mapper.commands.terrain.dispatch(args)
    local parts = words(args)
    if #parts == 0 then
        return mapper.commands.terrain.list()
    end

    if #parts == 1 then
        local word = parts[1]:lower()
        if word == "help" then
            return mapper.commands.terrain.help()
        end
        if word == "clear" then
            mapper.echo("Took every terrain weight off.")
            return mapper.reportreweighted(mapper.clearterrainweights())
        end
        mapper.echo("What should " .. parts[1] .. " cost? Use: mapper terrain <biome> <weight>")
        return
    end

    -- A biome can be more than one word ("post office"), so the weight is the
    -- last word and the name is everything in front of it.
    local wanted = parts[#parts]:lower()
    local biome = table.concat(parts, " ", 1, #parts - 1)

    local known = mapper.knownbiomes()
    local match
    for _, name in ipairs(known) do
        if name == biome:lower() then
            match = name
            break
        end
    end
    if not match then
        mapper.echo("There is no '" .. biome .. "' biome.")
        mapper.echo("Known biomes: " .. table.concat(known, ", "))
        return
    end

    -- "clear" is the word for the weight that means "no weight at all", which is
    -- the same thing as an ordinary room's 1.
    local weight = wanted == "clear" and 1 or wanted

    local changed, why = mapper.setterrainweight(match, weight)
    if not changed then
        mapper.echo(why)
        return
    end

    if (mapper.terrainweights[match] or 1) > 1 then
        mapper.echo(string.format("A walk now treats one %s room as %d ordinary ones.",
            match, mapper.terrainweights[match]))
    else
        mapper.echo("A " .. match .. " room now costs a walk what any other room costs.")
    end
    mapper.reportreweighted(changed)
end

--------------------------------------------------------------------------------
-- Updates
--------------------------------------------------------------------------------

function mapper.commands.update()
    if mapper.newmapperversion then
        mapper.downloadmapperscript()
    else
        mapper.echo("No update available. Use 'mapper check' to look for one.")
    end
end

--------------------------------------------------------------------------------
-- Help and dispatch
--------------------------------------------------------------------------------

function mapper.commands.help()
    printCommands("Mapper commands:", {
        { cmd = "mapper",            args = "",                  desc = "Show this help" },
        { cmd = "mapper goto",       args = "<destination>",     desc = "Walk to a room ID, a tag or an area" },
        { cmd = "mapper stop",       args = "",                  desc = "Stop walking" },
        { cmd = "mapper on",         args = "",                  desc = "Map new rooms as you explore" },
        { cmd = "mapper off",        args = "",                  desc = "Stop mapping new rooms" },
        { cmd = "mapper path",       args = "<to> [from]",       desc = "Show the way there and highlight it" },
        { cmd = "mapper path clear", args = "",                  desc = "Take the path highlight off the map" },
        { cmd = "mapper find",       args = "<name>",            desc = "Find rooms by name" },
        { cmd = "mapper look",       args = "[room]",            desc = "Show what is known about a room" },
        { cmd = "mapper rooms",      args = "[area]",            desc = "List the rooms of an area" },
        { cmd = "mapper view",       args = "<room or area>",    desc = "Center the map on a room or an area" },
        { cmd = "mapper area",       args = "[subcommand]",      desc = "Area info, listing, locks and labels" },
        { cmd = "mapper tag",        args = "<name> [room]",     desc = "Tag a room so you can walk back to it" },
        { cmd = "mapper untag",      args = "<name> [room]",     desc = "Take a tag off a room" },
        { cmd = "mapper tags",       args = "[name]",            desc = "List the tags, or the rooms carrying one" },
        { cmd = "mapper lock",       args = "[room] <direction>", desc = "Keep walks out of an exit" },
        { cmd = "mapper unlock",     args = "[room] <direction>", desc = "Let walks use an exit again" },
        { cmd = "mapper terrain",    args = "[biome weight]",    desc = "What each kind of ground costs a walk" },
        { cmd = "mapper label",      args = "[room] <text>",     desc = "Write a label on the map" },
        { cmd = "mapper config",     args = "[option] [value]",  desc = "View or change the mapper's settings" },
        { cmd = "mapper debug",      args = "on|off",            desc = "Turn debug messages on or off" },
        { cmd = "mapper reset",      args = "",                  desc = "Delete the whole map - asks first" },
        { cmd = "mapper reload",     args = "",                  desc = "Reload the mapper's settings" },
        { cmd = "mapper check",      args = "",                  desc = "Check whether an update is out" },
        { cmd = "mapper update",     args = "",                  desc = "Install the update that was found" },
        { cmd = "mstop",             args = "",                  desc = "Shorthand for 'mapper stop'" },
        { cmd = "mconfig",           args = "[option] [value]",  desc = "Shorthand for 'mapper config'" },
        { cmd = "showpath",          args = "<to> [from]",       desc = "Shorthand for 'mapper path'" },
    }, {
        "'mapper area help', 'mapper tag help', 'mapper config help', 'mapper terrain",
        "help' and a command given no arguments each say more about that command.",
        "Right-clicking a room on the map offers the same walking, path, look, lock",
        "and tag commands for the room you clicked.",
    })
end

local subcommands = {
    help = mapper.commands.help,
    ["goto"] = mapper.commands.gotoDestination,
    stop = function() mapper.stop() end,
    on = mapper.commands.mappingOn,
    off = mapper.commands.mappingOff,
    path = mapper.commands.path,
    find = mapper.commands.find,
    look = mapper.commands.look,
    rooms = mapper.commands.rooms,
    view = mapper.commands.view,
    area = mapper.commands.area.dispatch,
    tag = mapper.commands.tag,
    untag = mapper.commands.untag,
    tags = mapper.commands.tags,
    lock = mapper.commands.exit.lock,
    unlock = mapper.commands.exit.unlock,
    terrain = mapper.commands.terrain.dispatch,
    label = mapper.commands.label,
    config = mapper.commands.config,
    debug = mapper.commands.debug,
    reset = mapper.commands.reset,
    reload = function() mapper.reload() end,
    check = function() mapper.checkupdateverbose() end,
    update = mapper.commands.update,
}

function mapper.commands.dispatch(args)
    if not args or args == "" then
        return mapper.commands.help()
    end

    local subcommand, rest = args:match("^(%S+)%s*(.-)%s*$")
    subcommand = subcommand:lower()

    if not subcommands[subcommand] then
        mapper.echo("There is no 'mapper " .. subcommand .. "'.")
        return mapper.commands.help()
    end
    return subcommands[subcommand](rest)
end
