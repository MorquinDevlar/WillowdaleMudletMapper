-- functions internal to the mapper

-- Deep copy function to create a complete copy of a table
function mapper.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[mapper.deepcopy(orig_key)] = mapper.deepcopy(orig_value)
        end
        setmetatable(copy, mapper.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Whether an area is one a player maps into, and so one worth offering in a
-- listing. Area -1 is Mudlet's own "Default Area", where it parks rooms that
-- have no area yet, and area 0 is not a real area either: both are work areas of
-- the map editor rather than places in the game.
function mapper.islistablearea(id)
    id = tonumber(id)
    return id ~= nil and id ~= 0 and id ~= -1
end

-- How a room is named in messages: the game's own name, in the game's own
-- casing, and the ID for a room we have no name for. Pass withId to name both.
-- Not to be confused with mapper.roomLabel, which puts a label on the map.
function mapper.roomName(roomId, withId)
    local id = tonumber(roomId)
    if not id then
        return tostring(roomId)
    end
    local name = getRoomName(id)
    if not name or name == "" then
        return tostring(id)
    end
    if withId then
        return string.format("%s (%s)", name, id)
    end
    return name
end

function mapper.highlight_unfinished_rooms()
    if not mapper.areatable then
        return
    end
    for a, b in pairs(mapper.areatable) do
        local roomList = getAreaRooms(b) or {}
        for c, d in pairs(roomList) do
            if getRoomName(d) == "" then
                local fgr, fgg, fgb = unpack(color_table.red)
                local bgr, bgg, bgb = unpack(color_table.blue)
                highlightRoom(d, fgr, fgg, fgb, bgr, bgg, bgb, 1, 100, 100)
            end
        end
    end
end

-- Check if a biome is a Point of Interest (shop, inn, post office)
function mapper.isPOI(biome)
    if not biome then return false end
    local biomeLower = biome:lower()
    return biomeLower == "shop" or biomeLower == "inn" or biomeLower == "post office"
end

-- Which room characters the player wants drawn: all, biome, poi or none
function mapper.roomCharMode()
    local mode = mapper.settings and mapper.settings.roomchar
    if type(mode) ~= "string" then
        return "none"
    end
    return mode:lower()
end

-- Check if a room character should be shown based on current settings
function mapper.shouldShowRoomChar(biome)
    local mode = mapper.roomCharMode()
    if mode == "none" then
        return false
    end
    local isPOI = mapper.isPOI(biome)
    if mode == "all" then
        return true
    elseif mode == "poi" then
        return isPOI
    elseif mode == "biome" then
        return not isPOI
    end
    return false
end

-- Refresh room characters on all rooms that have stored biome data. Pass quiet
-- to skip the count, for a caller that reports on its own.
function mapper.refreshRoomChars(quiet)
    if not mapper.areatable then
        return
    end
    local count = 0
    if mapper.roomCharMode() == "none" then
        return
    end
    for _, areaId in pairs(mapper.areatable) do
        local roomList = getAreaRooms(areaId) or {}
        for _, roomId in pairs(roomList) do
            local biome = getRoomUserData(roomId, "biome")
            local symbol = getRoomUserData(roomId, "biome_symbol")
            if biome ~= "" and symbol ~= "" then
                if mapper.shouldShowRoomChar(biome) then
                    if getRoomChar(roomId) ~= symbol then
                        setRoomChar(roomId, symbol)
                        count = count + 1
                    end
                else
                    -- Clear symbol if it shouldn't be shown with current setting
                    if getRoomChar(roomId) == symbol then
                        setRoomChar(roomId, "")
                        count = count + 1
                    end
                end
            end
        end
    end
    if count > 0 and not quiet then
        mapper.echo("Updated characters on " .. count .. " room(s).")
    end
end

-- Clear room characters from all rooms that have stored biome data. Pass quiet
-- to skip the count, for a caller that reports on its own.
function mapper.clearRoomChars(quiet)
    if not mapper.areatable then
        return
    end
    local count = 0
    for _, areaId in pairs(mapper.areatable) do
        local roomList = getAreaRooms(areaId) or {}
        for _, roomId in pairs(roomList) do
            local biome = getRoomUserData(roomId, "biome")
            local symbol = getRoomUserData(roomId, "biome_symbol")
            if biome ~= "" and symbol ~= "" then
                if getRoomChar(roomId) == symbol then
                    setRoomChar(roomId, "")
                    count = count + 1
                end
            end
        end
    end
    if count > 0 and not quiet then
        mapper.echo("Cleared characters from " .. count .. " room(s).")
    end
end

-- Speedwalk path highlighting using room borders
mapper.highlightedPathRooms = {}
mapper.showPathDestination = nil  -- Destination for showpath command

function mapper.highlightPath(roomIds, fromRoom)
    -- Check if the new border functions are available
    if not setRoomBorderColor then
        return
    end

    -- Clear any existing highlights first
    mapper.clearPathHighlight()

    if not roomIds or #roomIds == 0 then
        return
    end

    -- Highlight current room (fromRoom) as yellow if provided
    local startRoom = fromRoom or mapper.currentroom
    if startRoom and roomExists(startRoom) then
        setRoomBorderColor(startRoom, 255, 220, 0)
        setRoomBorderThickness(startRoom, 2)
        setRoomUserData(startRoom, "showpath", "1")
        mapper.highlightedPathRooms[#mapper.highlightedPathRooms + 1] = startRoom
    end

    -- Highlight each room in the path with colored borders
    -- End: light blue, In-between: light green
    for i, roomId in ipairs(roomIds) do
        if roomExists(roomId) and roomId ~= startRoom then
            if i == #roomIds then
                -- Destination room: light blue border
                setRoomBorderColor(roomId, 100, 180, 255)
            else
                -- In-between rooms: light green border
                setRoomBorderColor(roomId, 100, 220, 100)
            end
            setRoomBorderThickness(roomId, 2)
            setRoomUserData(roomId, "showpath", "1")
            mapper.highlightedPathRooms[#mapper.highlightedPathRooms + 1] = roomId
        end
    end
end

-- Clear path highlight from map (does not clear destination)
function mapper.clearPathHighlight()
    -- Check if the new border functions are available
    if not clearRoomBorderColor then
        -- Fallback to old method if new functions not available
        for _, roomId in ipairs(mapper.highlightedPathRooms) do
            if roomExists(roomId) then
                unHighlightRoom(roomId)
            end
        end
        mapper.highlightedPathRooms = {}
        return
    end

    for _, roomId in ipairs(mapper.highlightedPathRooms) do
        if roomExists(roomId) then
            clearRoomBorderColor(roomId)
            clearRoomBorderThickness(roomId)
            clearRoomUserDataItem(roomId, "showpath")
        end
    end
    mapper.highlightedPathRooms = {}

    -- Clean up any orphaned highlights (e.g. from before a package reload)
    local orphans = searchRoomUserData("showpath", "1") or {}
    for roomId, _ in pairs(orphans) do
        if roomExists(roomId) then
            clearRoomBorderColor(roomId)
            clearRoomBorderThickness(roomId)
            clearRoomUserDataItem(roomId, "showpath")
        end
    end
end

-- Clear path highlight and destination (used by showpath clear)
function mapper.clearShowPath()
    mapper.showPathDestination = nil
    mapper.clearPathHighlight()
end

-- Update path highlight to show remaining path during speedwalk
function mapper.updatePathHighlight()
    if not mapper.settings.showspeedwalkpath then
        return
    end

    -- Get remaining path from current position
    local counter = mapper.speedWalkCounter or 1
    local path = mapper.speedWalkPath or {}

    if #path == 0 or counter > #path then
        mapper.clearPathHighlight()
        return
    end

    -- Build remaining path
    local remainingPath = {}
    for i = counter, #path do
        remainingPath[#remainingPath + 1] = path[i]
    end

    if #remainingPath == 0 then
        mapper.clearPathHighlight()
        return
    end

    -- Highlight remaining path with current room as start
    mapper.highlightPath(remainingPath, mapper.currentroom)
end

-- Willowdale-specific utility functions can be added here
