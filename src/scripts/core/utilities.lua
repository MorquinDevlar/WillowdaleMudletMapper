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

-- Willowdale-specific utility functions can be added here
