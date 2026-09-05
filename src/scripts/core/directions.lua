-- The twelve directions, in one table.
--
-- A direction is spelled four different ways depending on who is being talked
-- to: Mudlet's setExit and lockExit want a number, GMCP and getRoomExits use the
-- long name, a player types either name, and setDoor and the exit weights want a
-- fifth spelling that is the short name for the eight compass directions and the
-- long name for up, down, in and out. Keeping one record per direction is what
-- stops those four from drifting apart.

mapper = mapper or {}

mapper.dirs = {
    { number = 1,  long = "north",     short = "n",  door = "n",    reverse = "south",     dx = 0,  dy = 1,  dz = 0 },
    { number = 2,  long = "northeast", short = "ne", door = "ne",   reverse = "southwest", dx = 1,  dy = 1,  dz = 0 },
    { number = 3,  long = "northwest", short = "nw", door = "nw",   reverse = "southeast", dx = -1, dy = 1,  dz = 0 },
    { number = 4,  long = "east",      short = "e",  door = "e",    reverse = "west",      dx = 1,  dy = 0,  dz = 0 },
    { number = 5,  long = "west",      short = "w",  door = "w",    reverse = "east",      dx = -1, dy = 0,  dz = 0 },
    { number = 6,  long = "south",     short = "s",  door = "s",    reverse = "north",     dx = 0,  dy = -1, dz = 0 },
    { number = 7,  long = "southeast", short = "se", door = "se",   reverse = "northwest", dx = 1,  dy = -1, dz = 0 },
    { number = 8,  long = "southwest", short = "sw", door = "sw",   reverse = "northeast", dx = -1, dy = -1, dz = 0 },
    { number = 9,  long = "up",        short = "u",  door = "up",   reverse = "down",      dx = 0,  dy = 0,  dz = 1 },
    { number = 10, long = "down",      short = "d",  door = "down", reverse = "up",        dx = 0,  dy = 0,  dz = -1 },
    -- in and out have no direction of their own on a map, so they borrow the
    -- vertical axis: this is the convention the map was drawn with.
    { number = 11, long = "in",        short = "i",  door = "in",   reverse = "out",       dx = 0,  dy = 0,  dz = -1 },
    { number = 12, long = "out",       short = "o",  door = "out",  reverse = "in",        dx = 0,  dy = 0,  dz = 1 },
}

-- Every spelling of a direction, pointing at its record.
local byname = {}
for _, dir in ipairs(mapper.dirs) do
    byname[dir.number] = dir
    byname[dir.long] = dir
    byname[dir.short] = dir
end

-- The record for a direction given as a number, a short name or a long name in
-- any case, or nil for anything else. Everything below is a field of this.
local function record(any)
    if type(any) == "string" then
        return byname[any:lower()]
    end
    return byname[any]
end

function mapper.dirnumber(any)
    local dir = record(any)
    return dir and dir.number
end

function mapper.dirlong(any)
    local dir = record(any)
    return dir and dir.long
end

-- The name Mudlet's door and exit-weight calls know this direction by.
function mapper.dirdoor(any)
    local dir = record(any)
    return dir and dir.door
end

-- The long name of the way back.
function mapper.dirreverse(any)
    local dir = record(any)
    return dir and dir.reverse
end

function mapper.isStandardExit(any)
    return record(any) ~= nil
end

-- Where one step in `dir` from (x, y, z) lands.
function mapper.shiftcoords(dir, x, y, z)
    local step = record(dir)
    if not step or not (x and y and z) then
        return nil
    end
    return x + step.dx, y + step.dy, z + step.dz
end
