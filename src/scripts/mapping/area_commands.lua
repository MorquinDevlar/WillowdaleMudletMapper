-- Main mapper command dispatcher and subcommand handlers
mapper.commands = mapper.commands or {}

-- Main mapper help
function mapper.commands.help()
    mapper.echo("Mapper Commands:")

    local commands = {
        { cmd = "mapper",             args = "",              desc = "Show this help" },
        { cmd = "mapper start",       args = "",              desc = "Enable mapping (create new rooms)" },
        { cmd = "mapper stop",        args = "",              desc = "Disable mapping" },
        { cmd = "mapper goto",        args = "<destination>", desc = "Go to room ID, area, or feature" },
        { cmd = "mapper find",        args = "<name>",        desc = "Find rooms by name" },
        { cmd = "mapper look",        args = "[room]",        desc = "Show room information" },
        { cmd = "mapper area",        args = "[subcommand]",  desc = "Area management (list, add, delete, lock)" },
        { cmd = "mapper lock",        args = "[room] <dir>",  desc = "Lock exit (prevent speedwalk)" },
        { cmd = "mapper unlock",      args = "[room] <dir>",  desc = "Unlock exit (allow speedwalk)" },
        { cmd = "mapper config",      args = "[option] [val]", desc = "View or change mapper settings" },
        { cmd = "mconfig",            args = "[option] [val]", desc = "Shorthand for 'mapper config'" },
        { cmd = "mapper check",       args = "",              desc = "Check for mapper updates" },
        { cmd = "mapper update",      args = "",              desc = "Install available update" },
        { cmd = "mapper reload",      args = "",              desc = "Reload mapper settings" },
        { cmd = "showpath",           args = "<room>|clear",  desc = "Show/highlight path or clear highlight" },
        { cmd = "mstop",              args = "",              desc = "Stop speedwalking" },
    }

    -- Calculate column widths
    local cmdWidth = 7
    local argsWidth = 4

    for _, c in ipairs(commands) do
        cmdWidth = math.max(cmdWidth, #c.cmd)
        argsWidth = math.max(argsWidth, #c.args)
    end

    local header = string.format("\n  %-" .. cmdWidth .. "s   %-" .. argsWidth .. "s   %s",
        "Command", "Args", "Description")
    cecho("<dim_grey>" .. header .. "<reset>")

    for _, c in ipairs(commands) do
        echo("\n  ")
        cecho("<white>" .. c.cmd .. "<reset>")
        echo(string.rep(" ", cmdWidth - #c.cmd) .. "   ")
        cecho("<yellow>" .. c.args .. "<reset>")
        echo(string.rep(" ", argsWidth - #c.args) .. "   ")
        echo(c.desc)
    end

    cecho("\n\n  <dim_grey>Use 'mapper <command> help' for more details on each command.<reset>")
    echo("\n")
end

-- Config help
function mapper.commands.configHelp()
    mapper.echo("Config Commands:")

    local commands = {
        { cmd = "mapper config",          args = "",              desc = "Show all settings and their values" },
        { cmd = "mapper config",          args = "<option>",      desc = "Show details for a specific option" },
        { cmd = "mapper config",          args = "<option> <value>", desc = "Set an option to a new value" },
        { cmd = "mapper config help",     args = "",              desc = "Show this help" },
        { cmd = "mconfig",                args = "[option] [value]", desc = "Shorthand for 'mapper config'" },
    }

    -- Calculate column widths
    local cmdWidth = 7
    local argsWidth = 4

    for _, c in ipairs(commands) do
        cmdWidth = math.max(cmdWidth, #c.cmd)
        argsWidth = math.max(argsWidth, #c.args)
    end

    local header = string.format("\n  %-" .. cmdWidth .. "s   %-" .. argsWidth .. "s   %s",
        "Command", "Args", "Description")
    cecho("<dim_grey>" .. header .. "<reset>")

    for _, c in ipairs(commands) do
        echo("\n  ")
        cecho("<white>" .. c.cmd .. "<reset>")
        echo(string.rep(" ", cmdWidth - #c.cmd) .. "   ")
        cecho("<yellow>" .. c.args .. "<reset>")
        echo(string.rep(" ", argsWidth - #c.args) .. "   ")
        echo(c.desc)
    end

    cecho("\n\n  <dim_grey>Boolean options accept: on/off, true/false, yes/no<reset>")
    cecho("\n  <dim_grey>Numeric options accept decimal numbers (e.g., 0.3)<reset>")
    echo("\n")
end

-- Config command (wrapper for mconfig)
function mapper.commands.config(args)
    -- Check if game is detected
    if not mapper.game then
        mapper.echo("Game not detected. Please reconnect to your MUD so the mapper can identify which game you're playing.")
        return
    end

    if not args or args == "" then
        -- Show all options
        mapper.settings:showAllOptions(mapper.game)
        return
    end

    -- Handle help subcommand
    if args == "help" then
        return mapper.commands.configHelp()
    end

    local parts = {}
    for word in args:gmatch("%S+") do
        parts[#parts + 1] = word
    end

    local option = parts[1]
    local val = parts[2]

    -- If only option name is provided, show its description
    if option and (not val or val == "") then
        local optionDef = mapper.settings:getOptionDef(option)
        if optionDef then
            echo("\n")
            decho("<112,229,0>" .. option .. ":<255,255,255> " .. (optionDef.use or "No description available") .. "\n")
            local currentValue = mapper.settings[option]
            if type(currentValue) == "boolean" then
                currentValue = currentValue and "on" or "off"
            end
            decho("<112,229,0>Current value: <255,255,255>" .. tostring(currentValue) .. "\n")
        else
            mapper.echo("Unknown option: " .. option)
        end
        return
    end

    -- Convert values
    if val == "true" or val == "yes" or val == "on" then
        val = true
    elseif val == "false" or val == "no" or val == "off" then
        val = false
    else
        local numberVal = tonumber(val)
        val = numberVal and numberVal or val
    end

    mapper.settings:setOption(option, val)
end

-- Area subcommands
mapper.commands.area = {}

-- Dispatch subcommands
function mapper.commands.area.dispatch(args)
    if not args or args == "" then
        return mapper.commands.area.info()
    end

    local parts = {}
    for word in args:gmatch("%S+") do
        parts[#parts + 1] = word
    end

    local subcommand = parts[1]:lower()
    table.remove(parts, 1)
    local rest = table.concat(parts, " ")

    local handlers = {
        list = mapper.commands.area.list,
        add = mapper.commands.area.add,
        delete = mapper.commands.area.delete,
        rename = mapper.commands.area.rename,
        lock = mapper.commands.area.lock,
        unlock = mapper.commands.area.unlock,
        labels = mapper.commands.area.labels,
        help = mapper.commands.area.help,
    }

    if handlers[subcommand] then
        return handlers[subcommand](rest)
    else
        -- Unknown subcommand - show help
        mapper.echo("Unknown subcommand: " .. subcommand)
        return mapper.commands.area.help()
    end
end

-- Show current area and room info
function mapper.commands.area.info()
    if not mapper.currentroom or not roomExists(mapper.currentroom) then
        mapper.echo("Not currently in a mapped room.")
        return
    end

    local roomId = mapper.currentroom
    local roomName = getRoomName(roomId) or "Unknown"
    local areaId = getRoomArea(roomId)
    local areaName = mapper.areatabler and mapper.areatabler[areaId] or getRoomAreaName(areaId) or "Unknown"
    local rooms = getAreaRooms(areaId) or {}
    local roomCount = 0
    for _ in pairs(rooms) do roomCount = roomCount + 1 end

    local isLocked = mapper.locked and mapper.locked[areaId] or false
    local labels = getMapLabels(areaId) or {}
    local labelCount = 0
    for _ in pairs(labels) do labelCount = labelCount + 1 end

    -- Room coordinates
    local x, y, z = getRoomCoordinates(roomId)

    -- Room character
    local roomChar = getRoomChar(roomId) or ""

    mapper.echo("Current Location:")

    -- Room info
    cecho("\n\n  <dim_grey>Room<reset>")
    cecho("\n  <white>Name:<reset>   " .. roomName)
    cecho("\n  <white>ID:<reset>     " .. roomId)
    cecho("\n  <white>Coords:<reset> " .. x .. ", " .. y .. ", " .. z)
    if roomChar ~= "" then
        cecho("\n  <white>Char:<reset>   " .. roomChar)
    end

    -- Area info
    cecho("\n\n  <dim_grey>Area<reset>")
    cecho("\n  <white>Name:<reset>   " .. areaName)
    cecho("\n  <white>ID:<reset>     " .. areaId)
    cecho("\n  <white>Rooms:<reset>  " .. roomCount)
    cecho("\n  <white>Status:<reset> " .. (isLocked and "<red>Locked" or "<green>Open") .. "<reset>")
    if labelCount > 0 then
        cecho("\n  <white>Labels:<reset> " .. labelCount)
    end

    -- Collect rooms with characters in this area
    local charRooms = {}
    for _, rid in pairs(rooms) do
        local char = getRoomChar(rid)
        if char and char ~= "" then
            charRooms[#charRooms + 1] = { id = rid, name = getRoomName(rid) or "Unknown", char = char }
        end
    end

    if #charRooms > 0 then
        table.sort(charRooms, function(a, b) return a.name:lower() < b.name:lower() end)

        -- Calculate column widths
        local idWidth = 2
        local nameWidth = 4
        for _, r in ipairs(charRooms) do
            idWidth = math.max(idWidth, #tostring(r.id))
            nameWidth = math.max(nameWidth, #r.name)
        end

        cecho("\n\n  <dim_grey>Marked Rooms (" .. #charRooms .. ")<reset>")
        local header = string.format("\n  %-" .. idWidth .. "s   %-" .. nameWidth .. "s   %s",
            "ID", "Name", "Char")
        cecho("<dim_grey>" .. header .. "<reset>")

        for _, r in ipairs(charRooms) do
            local row = string.format("\n  %-" .. idWidth .. "s   %-" .. nameWidth .. "s   ",
                tostring(r.id), r.name)
            echo(row)
            cecho("<yellow>" .. r.char .. "<reset>")
            echo("      ")
            setUnderline(true)
            setFgColor(0, 180, 0)
            echoLink("Go to", [[mapper.gotoRoom(]] .. r.id .. [[)]], "Navigate to this room", true)
            resetFormat()
        end
    end

    echo("\n")
end

-- List all areas
function mapper.commands.area.list(filter)
    local areaTable = getAreaTable()
    local areas = {}

    -- Build sorted list
    for name, id in pairs(areaTable) do
        if mapper.islistablearea(id) then
            if not filter or filter == "" or name:lower():find(filter:lower(), 1, true) then
                local rooms = getAreaRooms(id) or {}
                local roomCount = 0
                for _ in pairs(rooms) do roomCount = roomCount + 1 end
                local locked = mapper.locked and mapper.locked[id] or false
                areas[#areas + 1] = { name = name, id = id, rooms = roomCount, locked = locked }
            end
        end
    end

    table.sort(areas, function(a, b) return a.name:lower() < b.name:lower() end)

    if #areas == 0 then
        if filter then
            mapper.echo("No areas matching '" .. filter .. "'")
        else
            mapper.echo("No areas found.")
        end
        return
    end

    -- Calculate column widths
    local idWidth = 2 -- minimum "ID"
    local nameWidth = 4 -- minimum "Name"
    local roomsWidth = 5 -- minimum "Rooms"

    for _, area in ipairs(areas) do
        idWidth = math.max(idWidth, #tostring(area.id))
        nameWidth = math.max(nameWidth, #area.name)
        roomsWidth = math.max(roomsWidth, #tostring(area.rooms))
    end

    -- Print header
    if filter and filter ~= "" then
        mapper.echo("Areas matching '" .. filter .. "':")
    else
        mapper.echo("Areas:")
    end

    local header = string.format("\n  %-" .. idWidth .. "s   %-" .. nameWidth .. "s   %" .. roomsWidth .. "s   %s",
        "ID", "Name", "Rooms", "Status")
    cecho("<dim_grey>" .. header .. "<reset>")

    -- Print rows
    for _, area in ipairs(areas) do
        local row = string.format("\n  %-" .. idWidth .. "s   %-" .. nameWidth .. "s   %" .. roomsWidth .. "s   ",
            tostring(area.id), area.name, tostring(area.rooms))
        echo(row)

        -- Status (fixed width: 6 chars for "Locked"/"Open  ")
        if area.locked then
            cecho("<red>Locked<reset>")
        else
            cecho("<green>Open<reset>  ")
        end

        -- Actions
        echo("  ")

        -- Lock/Unlock link (fixed width: 6 chars for "Unlock"/"Lock  ")
        setUnderline(true)
        if area.locked then
            setFgColor(0, 180, 0)
            echoLink("Unlock", [[mapper.commands.area.unlockById(]] .. area.id .. [[)]], "Unlock this area", true)
        else
            setFgColor(180, 180, 0)
            echoLink("Lock", [[mapper.commands.area.lockById(]] .. area.id .. [[)]], "Lock this area", true)
            resetFormat()
            echo("  ")
        end
        resetFormat()

        echo("  ")

        -- Delete link
        setUnderline(true)
        setFgColor(200, 0, 0)
        echoLink("Delete", [[mapper.commands.area.deleteById(]] .. area.id .. [[)]], "Delete this area", true)
        resetFormat()
    end
    echo("\n")
end

-- Create a new area
function mapper.commands.area.add(name)
    if not name or name == "" then
        mapper.echo("Usage: mapper area add <name>")
        return
    end

    -- Check if area already exists
    local existing = getAreaTable()
    for areaName, _ in pairs(existing) do
        if areaName:lower() == name:lower() then
            mapper.echo("Area '" .. areaName .. "' already exists.")
            return
        end
    end

    -- Find next available ID
    local t = getAreaTable()
    local tr = {}
    for k, v in pairs(t) do
        tr[v] = k
    end
    local newid = table.maxn(tr) + 1

    setAreaName(newid, name)
    mapper.echo(string.format("Created new area '%s' (ID: %d)", name, newid))

    if mapper.currentroom and roomExists(mapper.currentroom) then
        centerview(mapper.currentroom)
    end

    mapper.regenerateareas()
    raiseEvent("mapper areas changed")
end

-- Delete an area
function mapper.commands.area.delete(name)
    if not name or name == "" then
        mapper.echo("Usage: mapper area delete <name>")
        return
    end

    -- Try exact match first, then partial match
    local areaId, areaName = mapper.findAreaID(name, true)
    if not areaId then
        areaId, areaName = mapper.findAreaID(name, false)
    end

    if not areaId then
        mapper.echo("Area '" .. name .. "' not found.")
        return
    end

    local rooms = getAreaRooms(areaId) or {}
    local roomCount = 0
    for _ in pairs(rooms) do roomCount = roomCount + 1 end

    -- Store for confirmation
    mapper.pendingAreaDelete = { id = areaId, name = areaName, rooms = roomCount }

    mapper.echo("Are you sure you want to delete area '" .. areaName .. "'?")
    cecho("\n  <yellow>This will delete " .. roomCount .. " room(s).<reset>")
    echo("\n  ")
    setUnderline(true)
    setFgColor(200, 0, 0)
    echoLink("Yes, delete", [[mapper.commands.area.confirmDelete()]], "Click to confirm deletion", true)
    resetFormat()
    echo("  ")
    setUnderline(true)
    echoLink("Cancel", [[mapper.pendingAreaDelete = nil; mapper.echo("Deletion cancelled.")]], "Click to cancel", true)
    resetFormat()
    echo("\n")
end

-- Delete area by ID (used by clickable links)
function mapper.commands.area.deleteById(areaId)
    if not areaId then
        mapper.echo("Invalid area ID.")
        return
    end

    local areaName = getRoomAreaName(areaId)
    if not areaName or areaName == "" then
        mapper.echo("Area with ID " .. areaId .. " not found.")
        return
    end

    local rooms = getAreaRooms(areaId) or {}
    local roomCount = 0
    for _ in pairs(rooms) do roomCount = roomCount + 1 end

    -- Store for confirmation
    mapper.pendingAreaDelete = { id = areaId, name = areaName, rooms = roomCount }

    mapper.echo("Are you sure you want to delete area '" .. areaName .. "'?")
    cecho("\n  <yellow>This will delete " .. roomCount .. " room(s).<reset>")
    echo("\n  ")
    setUnderline(true)
    setFgColor(200, 0, 0)
    echoLink("Yes, delete", [[mapper.commands.area.confirmDelete()]], "Click to confirm deletion", true)
    resetFormat()
    echo("  ")
    setUnderline(true)
    echoLink("Cancel", [[mapper.pendingAreaDelete = nil; mapper.echo("Deletion cancelled.")]], "Click to cancel", true)
    resetFormat()
    echo("\n")
end

-- Confirm area deletion
function mapper.commands.area.confirmDelete()
    if not mapper.pendingAreaDelete then
        mapper.echo("No pending area deletion.")
        return
    end

    local areaId = mapper.pendingAreaDelete.id
    local areaName = mapper.pendingAreaDelete.name
    local roomCount = mapper.pendingAreaDelete.rooms

    -- Delete all rooms in the area first
    local rooms = getAreaRooms(areaId) or {}
    for _, roomId in pairs(rooms) do
        deleteRoom(roomId)
    end

    -- Delete the area
    deleteArea(areaId)

    mapper.echo(string.format("Deleted area '%s' and %d room(s).", areaName, roomCount))
    mapper.pendingAreaDelete = nil

    mapper.regenerateareas()
    raiseEvent("mapper areas changed")
end

-- Rename current area
function mapper.commands.area.rename(name)
    if not name or name == "" then
        mapper.echo("Usage: mapper area rename <new name>")
        return
    end

    if not mapper.currentroom or not roomExists(mapper.currentroom) then
        mapper.echo("Not currently in a mapped room.")
        return
    end

    local areaId = getRoomArea(mapper.currentroom)
    local oldName = mapper.areatabler and mapper.areatabler[areaId] or getRoomAreaName(areaId) or "Unknown"

    setAreaName(areaId, name)
    mapper.echo(string.format("Renamed area from '%s' to '%s'", oldName, name))

    mapper.regenerateareas()
    raiseEvent("mapper areas changed")
end

-- Lock area (interactive or direct)
function mapper.commands.area.lock(name)
    if not name or name == "" then
        -- No name provided - show interactive menu
        return mapper.doLockArea()
    end

    -- Try exact match first, then partial match
    local areaId, areaName = mapper.findAreaID(name, true)
    if not areaId then
        areaId, areaName = mapper.findAreaID(name, false)
    end

    if not areaId then
        mapper.echo("Area '" .. name .. "' not found.")
        return
    end

    if mapper.locked and mapper.locked[areaId] then
        mapper.echo("Area '" .. areaName .. "' is already locked.")
        return
    end

    mapper.lockArea(areaName, true, true)
end

-- Lock area by ID (used by clickable links)
function mapper.commands.area.lockById(areaId)
    if not areaId then
        mapper.echo("Invalid area ID.")
        return
    end

    local areaName = getRoomAreaName(areaId)
    if not areaName or areaName == "" then
        mapper.echo("Area with ID " .. areaId .. " not found.")
        return
    end

    if mapper.locked and mapper.locked[areaId] then
        mapper.echo("Area '" .. areaName .. "' is already locked.")
        return
    end

    mapper.lockArea(areaName, true, true)
end

-- Unlock area directly
function mapper.commands.area.unlock(name)
    if not name or name == "" then
        mapper.echo("Usage: mapper area unlock <name>")
        return
    end

    -- Try exact match first, then partial match
    local areaId, areaName = mapper.findAreaID(name, true)
    if not areaId then
        areaId, areaName = mapper.findAreaID(name, false)
    end

    if not areaId then
        mapper.echo("Area '" .. name .. "' not found.")
        return
    end

    if not mapper.locked or not mapper.locked[areaId] then
        mapper.echo("Area '" .. areaName .. "' is not locked.")
        return
    end

    mapper.lockArea(areaName, false, true)
end

-- Unlock area by ID (used by clickable links)
function mapper.commands.area.unlockById(areaId)
    if not areaId then
        mapper.echo("Invalid area ID.")
        return
    end

    local areaName = getRoomAreaName(areaId)
    if not areaName or areaName == "" then
        mapper.echo("Area with ID " .. areaId .. " not found.")
        return
    end

    if not mapper.locked or not mapper.locked[areaId] then
        mapper.echo("Area '" .. areaName .. "' is not locked.")
        return
    end

    mapper.lockArea(areaName, false, true)
end

-- View/delete area labels
function mapper.commands.area.labels(areaArg)
    local areaId, areaName

    if not areaArg or areaArg == "" then
        -- Use current area
        if not mapper.currentroom or not roomExists(mapper.currentroom) then
            mapper.echo("Not currently in a mapped room. Specify an area name.")
            return
        end
        areaId = getRoomArea(mapper.currentroom)
        areaName = mapper.areatabler and mapper.areatabler[areaId] or getRoomAreaName(areaId) or "Unknown"
    else
        -- Try exact match first, then partial match
        areaId, areaName = mapper.findAreaID(areaArg, true)
        if not areaId then
            areaId, areaName = mapper.findAreaID(areaArg, false)
        end
        if not areaId then
            mapper.echo("Area '" .. areaArg .. "' not found.")
            return
        end
    end

    local labels = getMapLabels(areaId) or {}
    local labelList = {}
    for labelId, labelText in pairs(labels) do
        labelList[#labelList + 1] = { id = labelId, text = tostring(labelText) }
    end

    if #labelList == 0 then
        mapper.echo("No labels in area '" .. areaName .. "'")
        return
    end

    -- Sort by ID
    table.sort(labelList, function(a, b) return a.id < b.id end)

    -- Calculate column widths
    local idWidth = 2 -- minimum "ID"
    local textWidth = 4 -- minimum "Text"

    for _, label in ipairs(labelList) do
        idWidth = math.max(idWidth, #tostring(label.id))
        textWidth = math.max(textWidth, #label.text)
    end

    mapper.echo("Labels in area '" .. areaName .. "':")

    local header = string.format("\n  %-" .. idWidth .. "s   %-" .. textWidth .. "s",
        "ID", "Text")
    cecho("<dim_grey>" .. header .. "<reset>")

    for _, label in ipairs(labelList) do
        local row = string.format("\n  %-" .. idWidth .. "s   %-" .. textWidth .. "s   ",
            tostring(label.id), label.text)
        echo(row)
        setUnderline(true)
        setFgColor(200, 0, 0)
        echoLink(
            "Delete",
            [[deleteMapLabel(]] .. areaId .. [[, ]] .. label.id .. [[); mapper.echo("Label deleted.")]],
            "Click to delete this label",
            true
        )
        resetFormat()
    end
    echo("\n")
end

-- Show help
function mapper.commands.area.help()
    mapper.echo("Area Commands:")

    local commands = {
        { cmd = "mapper area",             args = "",         desc = "Show current area info" },
        { cmd = "mapper area list",        args = "[filter]", desc = "List all areas" },
        { cmd = "mapper area add",         args = "<name>",   desc = "Create a new area" },
        { cmd = "mapper area delete",      args = "<name>",   desc = "Delete an area" },
        { cmd = "mapper area rename",      args = "<name>",   desc = "Rename current area" },
        { cmd = "mapper area lock",        args = "[name]",   desc = "Lock area (interactive if no name)" },
        { cmd = "mapper area unlock",      args = "<name>",   desc = "Unlock an area" },
        { cmd = "mapper area labels",      args = "[area]",   desc = "View/delete labels" },
        { cmd = "mapper area help",        args = "",         desc = "Show this help" },
    }

    -- Calculate column widths
    local cmdWidth = 7 -- minimum "Command"
    local argsWidth = 4 -- minimum "Args"

    for _, c in ipairs(commands) do
        cmdWidth = math.max(cmdWidth, #c.cmd)
        argsWidth = math.max(argsWidth, #c.args)
    end

    local header = string.format("\n  %-" .. cmdWidth .. "s   %-" .. argsWidth .. "s   %s",
        "Command", "Args", "Description")
    cecho("<dim_grey>" .. header .. "<reset>")

    for _, c in ipairs(commands) do
        echo("\n  ")
        cecho("<white>" .. c.cmd .. "<reset>")
        echo(string.rep(" ", cmdWidth - #c.cmd) .. "   ")
        cecho("<yellow>" .. c.args .. "<reset>")
        echo(string.rep(" ", argsWidth - #c.args) .. "   ")
        echo(c.desc)
    end
    echo("\n")
end

-- Exit lock/unlock commands
mapper.commands.exit = {}

-- Lock an exit to prevent speedwalking through it
function mapper.commands.exit.lock(args)
    if not args or args == "" then
        return mapper.commands.exit.help()
    end

    local parts = {}
    for word in args:gmatch("%S+") do
        parts[#parts + 1] = word
    end

    local roomId, direction

    if #parts == 1 then
        -- Just direction - use current room
        if not mapper.currentroom or not roomExists(mapper.currentroom) then
            mapper.echo("Not in a mapped room. Specify room ID: mapper lock <room> <direction>")
            return
        end
        roomId = mapper.currentroom
        direction = parts[1]:lower()
    elseif #parts >= 2 then
        -- Room ID and direction
        roomId = tonumber(parts[1])
        if not roomId then
            mapper.echo("Invalid room ID: " .. parts[1])
            return
        end
        direction = parts[2]:lower()
    end

    if not roomExists(roomId) then
        mapper.echo("Room " .. roomId .. " doesn't exist.")
        return
    end

    -- Check if direction is valid
    if not mapper.isStandardExit(direction) then
        mapper.echo("Invalid direction: " .. direction)
        mapper.echo("Valid directions: n/north, s/south, e/east, w/west, ne/northeast, nw/northwest, se/southeast, sw/southwest, u/up, d/down, in, out")
        return
    end

    -- Check if exit exists
    local exits = getRoomExits(roomId)
    local shortDir = mapper.anytoshort(direction)
    if not exits[shortDir] then
        mapper.echo("Room " .. roomId .. " has no exit to the " .. direction .. ".")
        return
    end

    -- Check if already locked
    if mapper.hasExitLock(roomId, direction) then
        mapper.echo("Exit " .. direction .. " in room " .. roomId .. " is already locked.")
        return
    end

    mapper.lockExit(roomId, direction, true)
    local roomName = getRoomName(roomId) or "Unknown"
    mapper.echo("Locked " .. direction .. " exit in room " .. roomId .. " (" .. roomName .. ").")
    mapper.echo("Speedwalk will no longer use this exit.")
end

-- Unlock an exit to allow speedwalking through it
function mapper.commands.exit.unlock(args)
    if not args or args == "" then
        return mapper.commands.exit.help()
    end

    local parts = {}
    for word in args:gmatch("%S+") do
        parts[#parts + 1] = word
    end

    local roomId, direction

    if #parts == 1 then
        -- Just direction - use current room
        if not mapper.currentroom or not roomExists(mapper.currentroom) then
            mapper.echo("Not in a mapped room. Specify room ID: mapper unlock <room> <direction>")
            return
        end
        roomId = mapper.currentroom
        direction = parts[1]:lower()
    elseif #parts >= 2 then
        -- Room ID and direction
        roomId = tonumber(parts[1])
        if not roomId then
            mapper.echo("Invalid room ID: " .. parts[1])
            return
        end
        direction = parts[2]:lower()
    end

    if not roomExists(roomId) then
        mapper.echo("Room " .. roomId .. " doesn't exist.")
        return
    end

    -- Check if direction is valid
    if not mapper.isStandardExit(direction) then
        mapper.echo("Invalid direction: " .. direction)
        mapper.echo("Valid directions: n/north, s/south, e/east, w/west, ne/northeast, nw/northwest, se/southeast, sw/southwest, u/up, d/down, in, out")
        return
    end

    -- Check if exit exists
    local exits = getRoomExits(roomId)
    local shortDir = mapper.anytoshort(direction)
    if not exits[shortDir] then
        mapper.echo("Room " .. roomId .. " has no exit to the " .. direction .. ".")
        return
    end

    -- Check if not locked
    if not mapper.hasExitLock(roomId, direction) then
        mapper.echo("Exit " .. direction .. " in room " .. roomId .. " is not locked.")
        return
    end

    mapper.lockExit(roomId, direction, false)
    local roomName = getRoomName(roomId) or "Unknown"
    mapper.echo("Unlocked " .. direction .. " exit in room " .. roomId .. " (" .. roomName .. ").")
    mapper.echo("Speedwalk can now use this exit.")
end

-- Show exit lock help
function mapper.commands.exit.help()
    mapper.echo("Exit Lock Commands:")

    local commands = {
        { cmd = "mapper lock",        args = "<direction>",        desc = "Lock exit in current room" },
        { cmd = "mapper lock",        args = "<room> <direction>", desc = "Lock exit in specific room" },
        { cmd = "mapper unlock",      args = "<direction>",        desc = "Unlock exit in current room" },
        { cmd = "mapper unlock",      args = "<room> <direction>", desc = "Unlock exit in specific room" },
    }

    -- Calculate column widths
    local cmdWidth = 7 -- minimum "Command"
    local argsWidth = 4 -- minimum "Args"

    for _, c in ipairs(commands) do
        cmdWidth = math.max(cmdWidth, #c.cmd)
        argsWidth = math.max(argsWidth, #c.args)
    end

    local header = string.format("\n  %-" .. cmdWidth .. "s   %-" .. argsWidth .. "s   %s",
        "Command", "Args", "Description")
    cecho("<dim_grey>" .. header .. "<reset>")

    for _, c in ipairs(commands) do
        echo("\n  ")
        cecho("<white>" .. c.cmd .. "<reset>")
        echo(string.rep(" ", cmdWidth - #c.cmd) .. "   ")
        cecho("<yellow>" .. c.args .. "<reset>")
        echo(string.rep(" ", argsWidth - #c.args) .. "   ")
        echo(c.desc)
    end

    cecho("\n\n  <dim_grey>Locked exits are excluded from pathfinding. Use this to avoid")
    cecho("\n  dangerous exits or force specific routes.<reset>")
    cecho("\n  <dim_grey>Directions: n/north, s/south, e/east, w/west, ne/northeast,<reset>")
    cecho("\n  <dim_grey>nw/northwest, se/southeast, sw/southwest, u/up, d/down, in, out<reset>")
    echo("\n")
end
