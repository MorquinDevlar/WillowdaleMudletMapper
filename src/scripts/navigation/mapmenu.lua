-- The mapper on the map itself: its entries on the right-click menu, the line
-- of information drawn over the map, and the zoom an area starts at.
--
-- All three live in the map rather than in this package. Menus and entries are a
-- QMap insert keyed by their unique name, so installing them again is a
-- no-op rather than a second copy - which is what lets a map that arrives
-- without them (a fresh one, or one downloaded from elsewhere) be given them
-- again on every load.

mapper = mapper or {}

local MENU = "willowdale_mapper"
local MENU_LABEL = "Willowdale mapper"
local EVENT = "mapper mapmenu"

-- The info line's own name. It is what the player sees in the map's Info menu,
-- where they can turn it off again.
local INFO = "Willowdale mapper"

--------------------------------------------------------------------------------
-- The right-click menu
--------------------------------------------------------------------------------

-- What each entry does with the room that was clicked. Keyed by the unique name
-- Mudlet hands back, which is the only thing the event says about which entry
-- was picked.
local actions = {}

local function setlock(room, lock)
    local areaId = getRoomArea(room)
    if not mapper.areaname(areaId) then
        mapper.echo("That room is not in an area that can be locked.")
        return
    end
    mapper.setarealock(areaId, lock)
end

local entries = {
    { name = MENU .. "_walk", label = "Walk here", action = function(room)
        mapper.gotoRoom(room)
    end },

    -- One entry for both halves of showpath: while a path is highlighted the
    -- entry offers to take it off, since the rooms stay coloured until someone
    -- does, and once it is off the entry offers to show one again. The label
    -- is re-registered whenever that state changes (mapper.refreshmapmenu), and
    -- Mudlet builds the menu afresh on every right-click, so it reads right.
    { name = MENU .. "_path", label = function()
        return mapper.showPathDestination and "Clear path" or "Show path here"
    end, action = function(room)
        if mapper.showPathDestination then
            mapper.clearShowPath()
            mapper.echo("Path highlight cleared.")
            return
        end
        if not mapper.inmappedroom() then
            mapper.echo("You have to be in a mapped room to be shown the way from it.")
            return
        end
        mapper.echoPath(mapper.currentroom, room)
    end },

    { name = MENU .. "_look", label = "Look at room", action = function(room)
        mapper.roomlook(room)
    end },

    { name = MENU .. "_lock", label = "Lock this area", action = function(room)
        setlock(room, true)
    end },

    { name = MENU .. "_unlock", label = "Unlock this area", action = function(room)
        setlock(room, false)
    end },

    -- There is nowhere in a menu entry to type a tag name, so this repeats the
    -- last one the player named. Tagging a run of rooms is what the entry is
    -- for, and that is the same name each time.
    { name = MENU .. "_tag", label = "Tag this room", action = function(room)
        if not mapper.lasttag then
            mapper.echo("No tag to apply yet - name one with 'mapper tag <name>' first.")
            return
        end
        mapper.tagroom(mapper.lasttag, room)
    end },
}

for _, entry in ipairs(entries) do
    actions[entry.name] = entry.action
end

local function labelof(entry)
    if type(entry.label) == "function" then
        return entry.label()
    end
    return entry.label
end

-- Register the entries again with the labels the mapper's state calls for.
-- addMapEvent replaces an entry of the same unique name, so this is how a
-- label changes; the menu itself is drawn from these on every right-click.
function mapper.refreshmapmenu()
    if not addMapEvent then
        return
    end
    for _, entry in ipairs(entries) do
        addMapEvent(entry.name, EVENT, MENU, labelof(entry))
    end
end

function mapper.installmapmenu()
    if not addMapMenu or not addMapEvent then
        return
    end
    addMapMenu(MENU, "", MENU_LABEL)
    mapper.refreshmapmenu()
end

-- Which room the entry was clicked on. A right-click selects the room under it,
-- and Mudlet passes every selected room after the unique name, as numbers; with
-- nothing selected it passes strings instead, so the first number is the room
-- and anything else falls back to what Mudlet reports as selected and then to
-- where the player is standing.
local function clickedroom(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "number" and roomExists(value) then
            return value
        end
    end
    if getMapSelection then
        local selection = getMapSelection() or {}
        if selection.center and roomExists(selection.center) then
            return selection.center
        end
    end
    return mapper.inmappedroom()
end

-- Menus and entries are stored in the map, so an uninstall that left them there
-- would leave a submenu behind that raises an event nothing answers.
function mapper.removemapmenu()
    if not removeMapMenu or not removeMapEvent then
        return
    end
    for _, entry in ipairs(entries) do
        pcall(removeMapEvent, entry.name)
    end
    pcall(removeMapMenu, MENU)
end

function mapper.onmapmenu(_, uniquename, ...)
    local action = actions[uniquename]
    if not action then
        return
    end
    local room = clickedroom(...)
    if not room then
        mapper.echo("Right-click the room on the map you mean.")
        return
    end
    action(room)
end

--------------------------------------------------------------------------------
-- The information line over the map
--------------------------------------------------------------------------------

-- What the line says about the room itself, kept between repaints: it only
-- changes when the player moves, a tag goes on or comes off, or a lock changes,
-- and each of those forgets it through mapper.mapinfodirty.
local roominfo

function mapper.mapinfodirty()
    roominfo = nil
end

local function describeroom(room)
    if roominfo and roominfo.room == room then
        return roominfo.text
    end

    -- One read of the room's user data for the zone, the biome and the tags
    local data = getAllRoomUserData(room) or {}
    local parts = {}
    if data.Zone and data.Zone ~= "" then
        parts[#parts + 1] = "Zone: " .. data.Zone
    end
    if data.biome and data.biome ~= "" then
        parts[#parts + 1] = "Biome: " .. data.biome
    end
    local tags = mapper.roomtags and mapper.roomtags(room, data) or {}
    if #tags > 0 then
        parts[#parts + 1] = "Tags: " .. table.concat(tags, ", ")
    end
    if mapper.arealocked(getRoomArea(room)) then
        parts[#parts + 1] = "Area locked"
    end

    local text = table.concat(parts, " | ")
    roominfo = { room = room, text = text }
    return text
end

-- Mudlet calls this on every repaint and reads six results: the text, bold,
-- italic and a colour. The colour is left nil, which Mudlet treats as "pick one
-- that reads against this map background" - the same as its own info lines get.
-- The roomID it passes is the room under the mouse; what this says is about the
-- room the player is in, which is the one they want to read about while walking.
local function mapinfo()
    local room = mapper.inmappedroom()
    if not room then
        return "", false, false, nil, nil, nil
    end

    local text = describeroom(room)

    local path = mapper.speedWalkPath or {}
    if mapper.autowalking and #path > 0 then
        local step = math.min(math.max(mapper.speedWalkCounter or 1, 1), #path)
        text = text .. (text ~= "" and "\n" or "")
            .. string.format("Walking: step %d of %d to %s", step, #path, mapper.roomName(path[#path]))
    end

    return text, false, false, nil, nil, nil
end

function mapper.installmapinfo()
    -- registerMapInfo arrived in Mudlet 4.11
    if not registerMapInfo then
        return
    end
    registerMapInfo(INFO, mapinfo)
    -- Registering only makes it available; the profile's own set of enabled
    -- info lines decides what is drawn, and a profile that has never seen this
    -- one has it off. Turned on once, and remembered on the map that it has
    -- been: the profile keeps the player's choice from then on, and enabling it
    -- on every load would undo anyone who turned it off in the map's Info menu.
    if enableMapInfo and getMapUserData("mapper_mapinfo_offered") ~= "1" then
        setMapUserData("mapper_mapinfo_offered", "1")
        enableMapInfo(INFO)
    end
end

function mapper.removemapinfo()
    if killMapInfo then
        pcall(killMapInfo, INFO)
    end
end

--------------------------------------------------------------------------------
-- The zoom an area starts at
--------------------------------------------------------------------------------

local DEFAULT_ZOOM = 10
local MUDLET_DEFAULT_ZOOM = 20

-- Mudlet shows an area at 20 until someone zooms it, and from then on keeps
-- that area's zoom in the map file. 20 is further out than this game's rooms
-- want to be read at, so an area still sitting at Mudlet's default is brought
-- in to 10; an area with any other zoom was zoomed by the player and keeps what
-- they chose. This runs on the area switch because that is when the mapper
-- widget is certain to exist and the area in hand is the one being drawn.
function mapper.defaultzoom(_, newArea)
    local area = tonumber(newArea)
    if not area then
        return
    end
    if getMapZoom(area) == MUDLET_DEFAULT_ZOOM then
        setMapZoom(DEFAULT_ZOOM, area)
    end
end
