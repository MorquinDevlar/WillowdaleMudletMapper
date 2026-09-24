-- functions internal to the mapper

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

-- Whether a room of this biome shows its biome symbol under a roomchar mode,
-- the current one unless another is named. Naming one is how a change of mode
-- works out which rooms it touches.
function mapper.shouldShowRoomChar(biome, mode)
    mode = mode or mapper.roomCharMode()
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

-- Speedwalk path highlighting using room borders
--
-- The rooms currently carrying a highlight, as roomId -> role, where the role
-- is "start", "mid" or "end". Keeping the role lets a repaint touch only the
-- rooms whose part in the path actually changed.
mapper.highlightedPathRooms = {}
mapper.showPathDestination = nil  -- Destination for showpath command
-- The route showpath is highlighting: { dirs, rooms, first }, where rooms[first]
-- is the next room along it. A player walking it by hand is followed along
-- this instead of having the route worked out again at every step.
mapper.showPathRoute = nil

-- Border colour per role, indexed the same way the tracking table is
local pathHighlightColors = {
    start = { 255, 220, 0 },    -- current room: yellow
    mid = { 100, 220, 100 },    -- in-between rooms: light green
    ["end"] = { 100, 180, 255 } -- destination room: light blue
}

-- The room painted as the start, so that a step along the path can move the
-- start on without looking through the rest of the highlight.
local startroom

-- Whether the map may be carrying highlights: "1" while this session has put
-- some on it, "0" once they are all off. It lives in the map because the
-- highlights do, so a map saved in the middle of a walk says so when it is
-- next loaded, and a clean one spares that load a search through every room.
local HIGHLIGHTS = "mapper_highlights"
local marked -- what this session last wrote there

local function markhighlights(on)
    local value = on and "1" or "0"
    if marked ~= value then
        setMapUserData(HIGHLIGHTS, value)
        marked = value
    end
end

local function paint(roomId, role, previous)
    local color = pathHighlightColors[role]
    setRoomBorderColor(roomId, color[1], color[2], color[3])
    -- A room that only changed role keeps its thickness and its stored marker
    if not previous then
        setRoomBorderThickness(roomId, 2)
        setRoomUserData(roomId, "showpath", "1")
    end
end

local function unpaint(roomId)
    clearRoomBorderColor(roomId)
    clearRoomBorderThickness(roomId)
    clearRoomUserDataItem(roomId, "showpath")
end

-- Paint roomIds[first..] as the path, with fromRoom (or the current room) as
-- its start. The highlight already on the map is diffed against the one asked
-- for, so only rooms whose part in the path changed are repainted.
function mapper.highlightPath(roomIds, fromRoom, first)
    -- Check if the new border functions are available
    if not setRoomBorderColor then
        return
    end

    first = first or 1
    if not roomIds or first > #roomIds then
        mapper.clearPathHighlight()
        return
    end

    -- Work out what the map should look like. Mudlet hands a route over with
    -- its room IDs as strings, so they are made numbers here.
    local desired = {}
    local startRoom = tonumber(fromRoom or mapper.currentroom)
    if startRoom and roomExists(startRoom) then
        desired[startRoom] = "start"
    end
    local last = #roomIds
    for i = first, last do
        local roomId = tonumber(roomIds[i])
        if roomId and roomId ~= startRoom and roomExists(roomId) then
            desired[roomId] = (i == last) and "end" or "mid"
        end
    end

    -- Rooms that have dropped out of the path lose their highlight
    local current = mapper.highlightedPathRooms
    for roomId in pairs(current) do
        if not desired[roomId] and roomExists(roomId) then
            unpaint(roomId)
        end
    end

    -- Rooms that are new to the path, or have changed their part in it
    for roomId, role in pairs(desired) do
        local previous = current[roomId]
        if previous ~= role then
            paint(roomId, role, previous)
        end
    end

    mapper.highlightedPathRooms = desired
    startroom = startRoom and desired[startRoom] and startRoom or nil
    if next(desired) then
        markhighlights(true)
    elseif marked == "1" then
        markhighlights(false)
    end
end

-- One step along the highlighted path: the room left behind loses its
-- highlight and the room arrived in becomes the start. Only those two rooms
-- change, so a long walk does not go over its whole path at every step.
-- Returns false when the room is not on the highlight at all, for the caller
-- to paint the path afresh.
function mapper.advancePathHighlight(roomId)
    if not setRoomBorderColor then
        return true
    end
    local rooms = mapper.highlightedPathRooms
    local role = rooms[roomId]
    if not role then
        return false
    end
    if role == "start" then
        return true
    end
    if startroom and startroom ~= roomId and rooms[startroom] == "start" then
        if roomExists(startroom) then
            unpaint(startroom)
        end
        rooms[startroom] = nil
    end
    paint(roomId, "start", role)
    rooms[roomId] = "start"
    startroom = roomId
    return true
end

-- Clear path highlight from map (does not clear destination)
function mapper.clearPathHighlight()
    -- Mudlet before 4.21 has no room borders; the old highlight stands in
    local clear = clearRoomBorderColor and unpaint or unHighlightRoom
    for roomId in pairs(mapper.highlightedPathRooms) do
        if roomExists(roomId) then
            clear(roomId)
        end
    end
    mapper.highlightedPathRooms = {}
    startroom = nil
    if marked == "1" then
        markhighlights(false)
    end
end

-- Clear highlights the tracking table above knows nothing about: ones a session
-- that ended mid-walk persisted into the map, or ones a package reload left
-- behind when it dropped the table. The search reads every room on the map, so
-- it only runs for a map that does not say it is clean.
function mapper.clearStalePathHighlights()
    if not clearRoomBorderColor then
        return
    end

    -- A map saved by a version that did not keep the mark says nothing, and is
    -- searched once; from then on it carries the mark.
    local state = getMapUserData(HIGHLIGHTS)
    if state ~= "0" then
        -- searchRoomUserData with key and value returns a plain list of room IDs
        for _, roomId in ipairs(searchRoomUserData("showpath", "1") or {}) do
            -- The path being walked right now is not stale
            if not mapper.highlightedPathRooms[roomId] and roomExists(roomId) then
                unpaint(roomId)
            end
        end
    end
    marked = state
    markhighlights(next(mapper.highlightedPathRooms) ~= nil)
end

-- Clear path highlight and destination (used by showpath clear)
function mapper.clearShowPath()
    mapper.showPathDestination = nil
    mapper.showPathRoute = nil
    mapper.clearPathHighlight()
    -- The map menu's path entry reads "Clear path" only while there is one
    if mapper.refreshmapmenu then
        mapper.refreshmapmenu()
    end
end

-- Update path highlight to show remaining path during speedwalk. `arrived` is
-- the room a walk has just stepped into along its path, which is one room's
-- repaint; without it, the whole remaining path is painted afresh.
function mapper.updatePathHighlight(arrived)
    if not mapper.settings.showspeedwalkpath then
        return
    end
    if arrived and mapper.advancePathHighlight(arrived) then
        return
    end

    -- The path from where the walk has got to, with the current room as start
    local path = mapper.speedWalkPath or {}
    mapper.highlightPath(path, mapper.currentroom, mapper.speedWalkCounter or 1)
end

-- Willowdale-specific utility functions can be added here
