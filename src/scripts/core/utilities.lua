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

-- Check if a symbol should be shown based on current settings
function mapper.shouldShowSymbol(biome)
    local setting = mapper.settings.showbiomesymbols
    if not setting or setting == "off" then
        return false
    end
    local isPOI = mapper.isPOI(biome)
    if setting == "all" then
        return true
    elseif setting == "poi" then
        return isPOI
    elseif setting == "biome" then
        return not isPOI
    end
    return false
end

-- Refresh biome symbols on all rooms that have stored biome data
function mapper.refreshBiomeSymbols()
    if not mapper.areatable then
        return
    end
    local count = 0
    local setting = mapper.settings.showbiomesymbols
    if not setting or setting == "off" then
        return
    end
    for _, areaId in pairs(mapper.areatable) do
        local roomList = getAreaRooms(areaId) or {}
        for _, roomId in pairs(roomList) do
            local biome = getRoomUserData(roomId, "biome")
            local symbol = getRoomUserData(roomId, "biome_symbol")
            if biome ~= "" and symbol ~= "" then
                if mapper.shouldShowSymbol(biome) then
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
    if count > 0 then
        mapper.echo("Updated symbols on " .. count .. " room(s).")
    end
end

-- Clear biome symbols from all rooms that have stored biome data
function mapper.clearBiomeSymbols()
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
    if count > 0 then
        mapper.echo("Cleared symbols from " .. count .. " room(s).")
    end
end

-- Speedwalk path highlighting
mapper.highlightedPathRooms = {}

function mapper.highlightPath(roomIds)
    if not mapper.settings.showspeedwalkpath then
        return
    end

    -- Clear any existing highlights first
    mapper.clearPathHighlight()

    if not roomIds or #roomIds == 0 then
        return
    end

    -- Highlight each room in the path
    -- Using a cyan/blue gradient for the path
    for i, roomId in ipairs(roomIds) do
        if roomExists(roomId) then
            -- Gradient from start (green) to end (cyan)
            local progress = i / #roomIds
            local r = math.floor(0 + (0 - 0) * progress)
            local g = math.floor(200 - (200 - 150) * progress)
            local b = math.floor(100 + (255 - 100) * progress)

            highlightRoom(roomId, r, g, b, r, g, b, 1, 180, 80)
            mapper.highlightedPathRooms[#mapper.highlightedPathRooms + 1] = roomId
        end
    end
end

function mapper.clearPathHighlight()
    for _, roomId in ipairs(mapper.highlightedPathRooms) do
        if roomExists(roomId) then
            unHighlightRoom(roomId)
        end
    end
    mapper.highlightedPathRooms = {}
end

-- Willowdale-specific utility functions can be added here
