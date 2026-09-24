-- Keeping the whole map in step with the mapper's settings.
--
-- Three things the mapper writes into the rooms of a map follow from its
-- settings rather than from the game: which rooms are locked (the areas the
-- player locked), what each room costs a walk (the terrain weights and safe
-- walking) and what character it draws (the roomchar setting). All three are
-- saved in the map file, so a map last saved under the settings in force now
-- already carries them, and going over every room again - when the profile
-- loads, after every update, each time the map window opens - is work a map of
-- a million rooms makes the player wait for. So the map also records, in its
-- own user data, the settings it was brought in line with, and only what
-- differs between those and the ones in force is redone. A map with no record,
-- from an older version or from somewhere else, is gone over room by room once.

local LOCKS = "mapper_locks"
local ROOMCHARS = "mapper_roomchars"
local TERRAIN = "mapper_terrain"

-- The version of the rules the records were written under. A change to how
-- rooms are locked, weighted or drawn bumps it, and every map is gone over
-- again the next time it loads.
local RULES = 1

-- Rooms entered or made before the settings were loaded - an update's first
-- half second, say - whose lock, weight and character could not be set then.
-- mapper.syncmap sets them once it can.
function mapper.deferroom(id)
    mapper.pendingrooms = mapper.pendingrooms or {}
    mapper.pendingrooms[id] = true
end

local function readmark(key)
    local raw = getMapUserData(key)
    if type(raw) ~= "string" or raw == "" then
        return nil
    end
    local ok, mark = pcall(yajl.to_value, raw)
    if not ok or type(mark) ~= "table" or mark.rules ~= RULES then
        return nil
    end
    return mark
end

local function writemark(key, mark)
    mark.rules = RULES
    setMapUserData(key, yajl.to_string(mark))
end

local function setof(list)
    local set = {}
    for _, value in ipairs(type(list) == "table" and list or {}) do
        set[value] = true
    end
    return set
end

local function listof(set)
    local list = {}
    for value in pairs(set) do
        list[#list + 1] = value
    end
    table.sort(list)
    return list
end

local function samepairs(a, b)
    for key, value in pairs(a) do
        if b[key] ~= value then
            return false
        end
    end
    for key, value in pairs(b) do
        if a[key] ~= value then
            return false
        end
    end
    return true
end

-- Every room on the map. getRooms is the one call sure to name them all, and
-- this only runs for a map with no record.
local function eachroom(fn)
    for id in pairs(getRooms() or {}) do
        fn(id)
    end
end

--------------------------------------------------------------------------------
-- Area locks
--------------------------------------------------------------------------------

-- The areas whose rooms should be locked, as a set of area IDs.
local function lockedareas()
    local set = { [0] = true }
    for id, locked in pairs(mapper.locked or {}) do
        if locked and tonumber(id) then
            set[tonumber(id)] = true
        end
    end
    return set
end

-- Record in the map which areas it now has locked.
function mapper.marklocks()
    writemark(LOCKS, { areas = listof(lockedareas()) })
end

-- Put the room locks on the map in line with the areas the player locked.
function mapper.synclocks()
    local want = lockedareas()
    local mark = readmark(LOCKS)
    local rooms = 0
    if mark then
        local had = setof(mark.areas)
        if samepairs(had, want) then
            return
        end
        for area in pairs(want) do
            if not had[area] then
                rooms = rooms + mapper.lockarearooms(area, true)
            end
        end
        for area in pairs(had) do
            if not want[area] then
                rooms = rooms + mapper.lockarearooms(area, false)
            end
        end
    else
        -- Every area, open ones too: a map saved with an area locked that is
        -- not locked now has to have it taken off
        local areas = getAreaTableSwap() or {}
        for area in pairs(areas) do
            rooms = rooms + mapper.lockarearooms(area, want[area] or false)
        end
        if not areas[0] then
            rooms = rooms + mapper.lockarearooms(0, true)
        end
    end
    mapper.marklocks()
    -- Which rooms the pathfinder may enter has changed, so nothing worked out
    -- against the old locks can be trusted
    if rooms > 0 then
        mapper.clearpathcache()
    end
    mapper.mapinfodirty()
end

--------------------------------------------------------------------------------
-- Room characters
--------------------------------------------------------------------------------

-- Redraw the rooms of every biome for which changed(biome) says it is drawn
-- differently now. The game's biome is on every room it has been in, so one
-- search lists the biomes on the map and one more per biome finds its rooms,
-- without reading the rooms of any biome that did not change. Returns how many
-- rooms changed.
local function redrawbiomes(changed)
    local count = 0
    for _, biome in ipairs(searchRoomUserData("biome") or {}) do
        if changed(biome) then
            for _, id in ipairs(searchRoomUserData("biome", biome) or {}) do
                if mapper.refreshroomsymbol(id) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function reportchars(count, quiet)
    if count > 0 and not quiet then
        mapper.echo("Updated characters on " .. count .. " room(s).")
    end
end

-- Bring the room characters on the map in line with what decides them: a tag's
-- symbol first, then the room's biome symbol when the roomchar setting shows
-- it. mapper.roomsymbol is that whole rule, and is what tagging a single room
-- goes through too, so a sweep here and a tag put on cannot disagree. A tag's
-- symbol does not depend on the setting, so a change of setting only redraws
-- the rooms of the biomes it shows or hides. Pass quiet to skip the count, for
-- a caller that reports on its own.
function mapper.refreshRoomChars(quiet)
    if not mapper.optionsloaded then
        return 0
    end
    local mode = mapper.roomCharMode()
    local mark = readmark(ROOMCHARS)
    local count = 0
    if mark then
        if mark.mode == mode then
            return 0
        end
        count = redrawbiomes(function(biome)
            return mapper.shouldShowRoomChar(biome, mark.mode) ~= mapper.shouldShowRoomChar(biome, mode)
        end)
    else
        eachroom(function(id)
            -- One call for the whole of a room's user data rather than one per key
            if mapper.refreshroomsymbol(id, getAllRoomUserData(id) or {}) then
                count = count + 1
            end
        end)
    end
    writemark(ROOMCHARS, { mode = mode })
    reportchars(count, quiet)
    return count
end

--------------------------------------------------------------------------------
-- Terrain weights
--------------------------------------------------------------------------------

local function terrainnow()
    local settings = mapper.settings
    return {
        weights = mapper.terrainweights or {},
        safewalk = settings and settings.safewalk and true or false,
        cost = settings and tonumber(settings.safewalkcost) or 1,
        safe = listof(mapper.safebiomes or {}),
    }
end

-- Whether two sets of terrain settings weigh every room alike. Without safe
-- walking, its cost and which ground is safe decide nothing.
local function sameterrain(a, b)
    local asafe, bsafe = a.safewalk and true or false, b.safewalk and true or false
    if asafe ~= bsafe or not samepairs(a.weights or {}, b.weights or {}) then
        return false
    end
    if not asafe then
        return true
    end
    return tonumber(a.cost) == tonumber(b.cost) and samepairs(setof(a.safe), setof(b.safe))
end

local function weightunder(terrain, name, safe)
    return mapper.weightfor(name, terrain.weights or {}, terrain.safewalk and true or false,
        tonumber(terrain.cost) or 1, safe)
end

-- The weights across the whole map, for the moment a weight or the safewalk
-- setting changes and for a map carrying the weights of whatever was set last
-- time. Only the rooms of a biome whose weight differs between the settings the
-- map was weighted under and the ones in force are touched. Returns how many
-- rooms changed.
function mapper.applyallterrain()
    if not mapper.optionsloaded then
        return 0
    end
    local now = terrainnow()
    local mark = readmark(TERRAIN)
    if mark and sameterrain(mark, now) then
        return 0
    end

    local changed = 0
    if mark then
        local wassafe, nowsafe = setof(mark.safe), setof(now.safe)
        for _, biome in ipairs(searchRoomUserData("biome") or {}) do
            local name = biome:lower()
            local wanted = weightunder(now, name, nowsafe)
            if weightunder(mark, name, wassafe) ~= wanted then
                for _, id in ipairs(searchRoomUserData("biome", biome) or {}) do
                    if mapper.reweighroom(id, wanted) then
                        changed = changed + 1
                    end
                end
            end
        end
    else
        -- With nothing weighted and safe walking off every room wants weight 1
        -- whatever its biome is, so the biome is not worth reading
        local weighting = next(now.weights) ~= nil or now.safewalk
        eachroom(function(id)
            local biome = weighting and getRoomUserData(id, "biome") or nil
            if mapper.reweighroom(id, mapper.roomweight(biome)) then
                changed = changed + 1
            end
        end)
    end
    writemark(TERRAIN, now)

    -- Routes worked out against the old costs are worthless, but one sweep is
    -- one change to the pathfinder however many rooms it touched.
    if changed > 0 then
        raiseEvent("mapper updated map")
    end
    return changed
end

--------------------------------------------------------------------------------
-- All of it
--------------------------------------------------------------------------------

-- Characters and weights in one pass over the rooms, for a map with a record
-- of neither - which is every map the first time it loads under this version,
-- when going over the rooms once for each would be going over a large map
-- twice.
local function fullpass()
    local weights = 0
    eachroom(function(id)
        local data = getAllRoomUserData(id) or {}
        mapper.refreshroomsymbol(id, data)
        if mapper.reweighroom(id, mapper.roomweight(data.biome)) then
            weights = weights + 1
        end
    end)
    writemark(ROOMCHARS, { mode = mapper.roomCharMode() })
    writemark(TERRAIN, terrainnow())
    if weights > 0 then
        raiseEvent("mapper updated map")
    end
end

-- Bring the map in line with the settings in force: after they are loaded, and
-- for every map that arrives after that. Before they are loaded there is
-- nothing to bring it in line with, and doing it from the defaults would undo
-- what the map already carries.
function mapper.syncmap()
    -- What the line over the map says may have come from the map before
    mapper.mapinfodirty()
    if not mapper.optionsloaded then
        return
    end
    mapper.synclocks()
    if not readmark(ROOMCHARS) and not readmark(TERRAIN) then
        fullpass()
    else
        mapper.refreshRoomChars(true)
        mapper.applyallterrain()
    end

    -- Rooms that could not be settled before the settings were loaded
    local pending = mapper.pendingrooms
    if pending then
        mapper.pendingrooms = nil
        local changed = false
        for id in pairs(pending) do
            if roomExists(id) then
                local lock = mapper.wantlocked(getRoomArea(id))
                if roomLocked(id) ~= lock then
                    lockRoom(id, lock)
                    changed = true
                end
                local data = getAllRoomUserData(id) or {}
                mapper.refreshroomsymbol(id, data)
                changed = mapper.reweighroom(id, mapper.roomweight(data.biome)) or changed
            end
        end
        -- A lock or a weight moved, and the pathfinder reads both
        if changed then
            raiseEvent("mapper updated map")
        end
    end
end
