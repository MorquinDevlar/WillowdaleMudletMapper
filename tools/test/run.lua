-- Runs the package's scripts against the stand-in for Mudlet in
-- mudlet_stub.lua, and checks what they do to a small map: which rooms get
-- locked, weighted and drawn, what a walk and showpath do step by step, and
-- how much of the map each of those reads. From anywhere:
--
--   lua5.1 tools/test/run.lua
--
-- It exits non-zero if any check fails. It cannot show Qt rendering, live GMCP
-- framing or Mudlet's own pathfinder: the map, the pathfinder and the events
-- are the stand-in's.

local HERE = arg[0]:match("^(.*)/[^/]*$") or "."
dofile(HERE .. "/mudlet_stub.lua")

local ROOT = HERE .. "/../../src/scripts/"

local function readjson(path)
    local file = assert(io.open(path))
    local text = file:read("*a")
    file:close()
    return yajl.to_value(text)
end

-- The scripts in the order the package runs them: the order src/scripts/
-- scripts.json lists them in, a folder's own script before the scripts in it.
local function loadpackage()
    for _, entry in ipairs(readjson(ROOT .. "scripts.json")) do
        if entry.isFolder == "yes" then
            if entry.script and entry.script ~= "" then
                assert(loadstring(entry.script, entry.name))()
            end
            for _, child in ipairs(readjson(ROOT .. entry.name .. "/scripts.json")) do
                assert(child.isFolder ~= "yes", "nested folder " .. child.name)
                dofile(ROOT .. entry.name .. "/" .. child.name .. ".lua")
            end
        else
            dofile(ROOT .. entry.name .. ".lua")
        end
    end
    STUB.runtimers()
end

local failures, passes = 0, 0
local function check(cond, what)
    if cond then passes = passes + 1 else failures = failures + 1; print("FAIL: " .. what) end
end

-- A 3x3 grid of rooms in area "Town", two biomes, exits both ways
local function buildtown()
    STUB.newmap()
    local town = addAreaName("Town")
    local id = 0
    local grid = {}
    for y = 1, 3 do
        for x = 1, 3 do
            id = id + 1
            addRoom(id); setRoomArea(id, town); setRoomCoordinates(id, x, y, 0); setRoomName(id, "Room " .. id)
            setRoomUserData(id, "biome", (x == 1) and "Road" or "Forest")
            setRoomUserData(id, "biome_symbol", (x == 1) and "=" or "T")
            grid[y * 10 + x] = id
        end
    end
    for y = 1, 3 do
        for x = 1, 3 do
            local a = grid[y * 10 + x]
            if grid[y * 10 + x + 1] then setExit(a, grid[y * 10 + x + 1], "east"); setExit(grid[y * 10 + x + 1], a, "west") end
            if grid[(y + 1) * 10 + x] then setExit(a, grid[(y + 1) * 10 + x], "north"); setExit(grid[(y + 1) * 10 + x], a, "south") end
        end
    end
    return town
end

local function gmcpfor(id, extra)
    local r = STUB.map.rooms[id]
    gmcp = gmcp or {}
    gmcp.Room = { Info = {
        Basic = { id = id, name = r and r.name or ("Room " .. id), area = "Town zone", area_name = "Town",
            coordinates = r and string.format("Town zone, %d, %d, %d", r.x, r.y, r.z) or nil,
            environment = r and r.data.biome or "Road", biome_symbol = r and r.data.biome_symbol or "=", details = {} },
        Exits = {},
    } }
    if r then
        for long, to in pairs(r.exits) do gmcp.Room.Info.Exits[long] = { room_id = to } end
    end
    for k, v in pairs(extra or {}) do gmcp.Room.Info.Basic[k] = v end
end

---------------------------------------------------------------------------
print("== first load: map without records")
local town = buildtown()
loadpackage()
raiseEvent("sysLoadEvent")
STUB.runtimers()
check(mapper.optionsloaded == true, "options loaded after sysLoadEvent")
check(STUB.map.data.mapper_roomchars ~= nil, "room-char record written")
check(STUB.map.data.mapper_terrain ~= nil, "terrain record written")
check(STUB.map.data.mapper_locks ~= nil, "lock record written")
check(STUB.map.rooms[1].char == "", "poi mode hides road symbol")
check(STUB.c("getRooms") == 1, "one fused pass over the rooms, got " .. STUB.c("getRooms"))

print("== map opened: records match, nothing redone")
STUB.reset_counts()
raiseEvent("mapOpenEvent"); raiseEvent("sysMapDownloadEvent")
STUB.runtimers()
check(STUB.c("raise:mapper map reloaded") == 1, "two map events coalesce into one reload, got " .. STUB.c("raise:mapper map reloaded"))
check(STUB.c("getRooms") == 0, "no full pass on a matching map")
check(STUB.c("lockRoom") == 0, "no relock on a matching map, got " .. STUB.c("lockRoom"))
check(STUB.c("setRoomWeight") == 0 and STUB.c("setRoomChar") == 0, "no weight or char writes")

print("== roomchar all: only the biomes that change are redrawn")
STUB.reset_counts()
mapper.settings:setOption("roomchar", "all")
check(STUB.map.rooms[1].char == "=" and STUB.map.rooms[2].char == "T", "all mode draws both symbols")
check(STUB.c("getRooms") == 0, "mode change does not read every room")
mapper.settings:setOption("roomchar", "biome")
check(STUB.map.rooms[1].char == "=", "biome mode keeps road symbol")
STUB.reset_counts()
mapper.settings:setOption("roomchar", "biome")
check(STUB.c("setRoomChar") == 0, "same mode again changes nothing")

print("== terrain: weighting forest touches forest rooms only")
STUB.reset_counts()
local changed = mapper.setterrainweight("forest", 5)
check(changed == 6, "six forest rooms reweighed, got " .. tostring(changed))
check(STUB.map.rooms[2].weight == 5 and STUB.map.rooms[1].weight == 1, "forest 5, road 1")
check(STUB.c("getRooms") == 0, "no full pass for a weight change")
mapper.settings:setOption("safewalk", "on")
check(STUB.map.rooms[1].weight == 1 and STUB.map.rooms[2].weight == 5, "safewalk: road safe, forest stays 5 (cost 5)")
mapper.settings:setOption("safewalkcost", 9)
check(STUB.map.rooms[2].weight == 9, "safewalkcost 9 raises unsafe forest to 9")
mapper.settings:setOption("safewalk", "off")
check(STUB.map.rooms[2].weight == 5, "safewalk off drops forest back to its own 5")
check(mapper.clearterrainweights() == 6, "clearing weights resets six rooms")
check(STUB.map.rooms[2].weight == 1, "forest back to 1")

print("== area lock: rooms locked, record kept, reload does nothing")
STUB.reset_counts()
mapper.lockArea("Town", true, true)
check(STUB.map.rooms[5].locked, "rooms of a locked area are locked")
check(mapper.arealocked(town), "area recorded as locked")
STUB.reset_counts()
mapper.syncmap()
check(STUB.c("lockRoom") == 0, "sync after lock does nothing, got " .. STUB.c("lockRoom"))
-- the options file says unlocked while the map says locked: sync takes it off
mapper.locked = {}
mapper.syncmap()
check(not STUB.map.rooms[5].locked, "sync unlocks an area no longer locked")
mapper.lockArea(town, true, true)

print("== mapping a new room into a locked area locks it")
gmcpfor(10, { name = "New room", coordinates = "Town zone, 4, 1, 0", environment = "Forest", biome_symbol = "T" })
gmcp.Room.Info.Exits = { west = { room_id = 3 } }
mapper.onroom()
check(roomExists(10), "room 10 created from coordinates")
check(STUB.map.rooms[10].area == town, "filed under Town")
check(STUB.map.rooms[10].locked == true, "locked like the rest of its area")
check(STUB.map.rooms[10].data.Zone == "Town zone" and STUB.map.rooms[10].data.Area == "Town", "origin stored")
check(STUB.map.rooms[10].data.outdoors == "y", "outdoors flag set")
check(STUB.map.rooms[10].exits.west == 3, "exit linked")
mapper.lockArea(town, false, true)

print("== arriving before settings load defers the room, sync settles it")
mapper.setterrainweight("forest", 4)
mapper.optionsloaded = false
setRoomWeight(2, 1)
gmcpfor(2)
mapper.onroom()
check(STUB.map.rooms[2].weight == 1, "weight left alone before settings load")
check(mapper.pendingrooms and mapper.pendingrooms[2], "room 2 queued")
mapper.optionsloaded = true
mapper.syncmap()
check(STUB.map.rooms[2].weight == 4, "queued room weighed once settings are in, got " .. STUB.map.rooms[2].weight)
mapper.clearterrainweights()

print("== walking: one step repaints two rooms; skipping ahead carries on")
mapper.currentroom = 1
gmcpfor(1); mapper.onroom()
STUB.sent = {}
mapper.gotoRoom(9)
STUB.runtimers()
check(mapper.autowalking, "walk started")
check(#mapper.speedWalkPath == 4, "path of 4 rooms, got " .. #mapper.speedWalkPath)
local first = mapper.speedWalkPath[1]
STUB.reset_counts()
gmcpfor(first); mapper.onroom(); STUB.runtimers()
check(mapper.speedWalkCounter == 2, "counter moved to 2")
check(STUB.c("setRoomBorderColor") == 1 and STUB.c("clearRoomBorderColor") == 1, "one room painted, one cleared: got "
    .. STUB.c("setRoomBorderColor") .. "/" .. STUB.c("clearRoomBorderColor"))
-- land two rooms further on than expected
local third = mapper.speedWalkPath[3]
STUB.reset_counts()
gmcpfor(third); mapper.onroom(); STUB.runtimers()
check(mapper.speedWalkCounter == 4, "skipped ahead to counter 4, got " .. mapper.speedWalkCounter)
check(STUB.c("getPath") == 0, "no new search for a room on the path")
gmcpfor(9); mapper.onroom(); STUB.runtimers()
check(not mapper.autowalking, "arrived and stopped")
check(next(mapper.highlightedPathRooms) == nil, "highlight cleared at the end")
check(STUB.map.data.mapper_highlights == "0", "map marked clean, got " .. tostring(STUB.map.data.mapper_highlights))

print("== showpath by hand follows its route without searching")
gmcpfor(1); mapper.onroom()
mapper.echoPath(1, 9)
local route = mapper.showPathRoute
check(route and #route.rooms == 4, "route kept")
STUB.reset_counts()
gmcpfor(route.rooms[1]); mapper.onroom()
gmcpfor(route.rooms[2]); mapper.onroom()
check(STUB.c("getPath") == 0, "no search while on the route, got " .. STUB.c("getPath"))
check(mapper.showPathRoute.first == 3, "route position advanced")
-- step off the route
local off = STUB.map.rooms[1].exits.east == route.rooms[1] and 4 or 2
gmcpfor(off); mapper.onroom()
check(STUB.c("getPath") == 1, "one search after leaving the route")
gmcpfor(9); mapper.onroom()
check(mapper.showPathDestination == nil, "arrival clears showpath")

print("== cache: goto <area> reuses the nearest way in")
local far = addAreaName("Far")
addRoom(20); setRoomArea(20, far); setRoomName(20, "Far gate"); setExit(9, 20, "up"); setExit(20, 9, "down")
raiseEvent("mapper updated map")
gmcpfor(1); mapper.onroom()
STUB.reset_counts()
mapper.gotoAreaID(far)
check(STUB.c("getPath") == 1, "one search for one border room, walk reuses it: got " .. STUB.c("getPath"))
check(mapper.autowalking and mapper.speedWalkPath[#mapper.speedWalkPath] == 20, "walking to the gate")
mapper.stop()
STUB.reset_counts()
mapper.getAreaBorders(far); mapper.getAreaBorders(far)
check(STUB.c("getAllRoomEntrances") == 0, "borders cached until the map changes")

print("== tags: symbol beats biome; listing and migration")
mapper.tagroom("inn", "5")
mapper.tagsymbol("inn", "I")
check(STUB.map.rooms[5].char == "I", "tag symbol drawn")
check(table.concat(mapper.roomtags(5), ",") == "inn", "roomtags")
mapper.untagroom("inn", "5")
check(STUB.map.rooms[5].char == "T", "biome symbol back after untag (biome mode)")
STUB.clearout()
mapper.echoAreaRooms(town)
check(STUB.text():find("10 rooms") ~= nil, "area listing counts all rooms")

print("== map deleted by reset writes fresh records")
mapper.commands.reset(); mapper.commands.reset()
check(STUB.map.data.mapper_terrain ~= nil and STUB.map.data.mapper_locks ~= nil, "records on the empty map")


print("== second profile: map opens before settings load, old map with stale highlight and features")
STUB.newmap()
local t2 = buildtown()
setRoomUserData(4, "showpath", "1"); setRoomBorderColor(4, 1, 2, 3)
lockRoom(7, true) -- a lock the old relock would have taken off
setMapUserData("mapFeatures", yajl.to_string({ ["Post Office"] = "P" }))
setRoomUserData(6, "feature-Post Office", "true")
STUB.files["/home/mapper.options.lua"] = { options = { roomchar = "all" }, locked_areas = {}, terrain = { road = 3 } }
mapper = nil
STUB.handlers = {}
loadpackage()
STUB.reset_counts()
raiseEvent("mapOpenEvent"); STUB.runtimers()
check(STUB.c("lockRoom") == 0 and STUB.c("setRoomWeight") == 0, "nothing synced before settings load")
check(STUB.map.rooms[6].data["tag-post-office"] == "1", "feature migrated to a tag")
check(mapper.pendingrooms and mapper.pendingrooms[6], "migrated room waits for settings")
raiseEvent("sysLoadEvent"); STUB.runtimers()
check(STUB.map.rooms[1].weight == 3, "road weighted 3 from the options file")
check(STUB.map.rooms[1].char == "=", "roomchar all from the options file")
check(STUB.map.rooms[6].char == "P", "migrated tag symbol drawn")
check(STUB.map.rooms[4].border == nil and STUB.map.rooms[4].data.showpath == nil, "stale highlight cleared")
check(STUB.map.rooms[7].locked == false, "first sync of a map with no record clears foreign room locks")
check(STUB.map.data.mapper_highlights == "0", "map marked clean")
STUB.reset_counts()
mapper.clearStalePathHighlights()
check(STUB.c("searchRoomUserData") == 0, "clean map is not searched again")

print("== listings are capped")
for i = 100, 160 do addRoom(i); setRoomArea(i, t2); setRoomName(i, "Lane " .. i) end
STUB.clearout()
mapper.echoAreaRooms(t2)
check(STUB.text():find("30 of 70 rooms shown") ~= nil, "area listing capped at 30 of 70")
STUB.clearout()
mapper.roomFind("Lane")
check(STUB.text():find("30 of 61 rooms shown") ~= nil, "find capped at 30 of 61")
STUB.clearout()
mapper.roomlook("Lane")
check(STUB.text():find("30 of 61 rooms shown") ~= nil, "look by name capped too")


print("== a different map loads: its own tags draw, not the last map's")
STUB.newmap()
local t3 = buildtown()
setMapUserData("tags", yajl.to_string({ market = "M" }))
setRoomUserData(5, "tag-market", "1")
raiseEvent("sysMapDownloadEvent"); STUB.runtimers()
check(STUB.map.rooms[5].char == "M", "new map's tag symbol drawn on its first sync, got '" .. STUB.map.rooms[5].char .. "'")


print("== an update's first moment: moving maps nothing and prints no error")
loadpackage()
check(mapper.settings == nil and not mapper.optionsloaded, "the new instance has no settings yet")
STUB.clearout()
gmcpfor(30, { name = "Update room", coordinates = "Town zone, 9, 9, 0", environment = "Road", biome_symbol = "=" })
mapper.onroom()
check(not STUB.text():find("Oops"), "no error while the settings load")
check(not roomExists(30), "the room waits for the settings")
mapper.reload()
mapper.onroom()
check(roomExists(30), "mapped when next entered")

print("== reset forgets the deleted map's tags")
check(mapper.istag("market"), "the map's tag is known before the reset")
mapper.commands.reset(); mapper.commands.reset()
check(not mapper.istag("market") and next(mapper.loadtags()) == nil, "no tags after the reset")

print(string.format("\n%d passed, %d failed", passes, failures))
os.exit(failures == 0 and 0 or 1)
