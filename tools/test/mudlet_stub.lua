-- A small in-memory stand-in for the parts of Mudlet's Lua API the mapper uses,
-- enough to run the package's scripts outside Mudlet and count what they do.
-- The map is a table of rooms, getPath is Dijkstra over it with Mudlet's rules
-- (a step costs the weight of the room entered; locked rooms and exits are
-- skipped), and tempTimer only fires when a test says so, through
-- STUB.runtimers. STUB.c(name) counts the calls made to the map since
-- STUB.reset_counts(), which is how a test tells a targeted change from a
-- pass over every room.

STUB = { out = {}, sent = {}, timers = {}, handlers = {}, counts = {} }
local function count(name) STUB.counts[name] = (STUB.counts[name] or 0) + 1 end
function STUB.reset_counts() STUB.counts = {} end
function STUB.c(name) return STUB.counts[name] or 0 end

-- ---------------------------------------------------------------- lua helpers
function string.starts(s, p) return s:sub(1, #p) == p end
function string.ends(s, p) return p == "" or s:sub(-#p) == p end
function table.contains(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
function table.size(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
function table.keys(t) local k = {} for x in pairs(t) do k[#k + 1] = x end return k end
function table.is_empty(t) return next(t) == nil end
function string.split(s, sep) local r = {} for w in (s .. sep):gmatch("(.-)" .. sep) do r[#r + 1] = w end return r end
local saved = {}
function table.save(path, t) saved[path] = t end
function table.load(path, into) for k, v in pairs(saved[path] or {}) do into[k] = v end end
io.exists = function(path) return saved[path] ~= nil end
STUB.files = saved

-- ---------------------------------------------------------------- minimal JSON
local function isarray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then return false end
        n = n + 1
    end
    return true, n
end
local function enc(v)
    local t = type(v)
    if t == "table" then
        local arr, n = isarray(v)
        if arr then
            local parts = {}
            for i = 1, n do parts[i] = enc(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = string.format("%q", tostring(k)) .. ":" .. enc(x) end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then return string.format("%q", v)
    elseif t == "boolean" or t == "number" then return tostring(v)
    end
    return "null"
end
local function dec(s)
    local i = 1
    local function ws() i = s:find("%S", i) or #s + 1 end
    local val
    local function str()
        local j = i + 1
        local out = {}
        while true do
            local c = s:sub(j, j)
            if c == '"' then break end
            if c == "\\" then
                j = j + 1
                c = s:sub(j, j)
                c = ({ n = "\n", t = "\t", r = "\r" })[c] or c
            end
            out[#out + 1] = c
            j = j + 1
        end
        i = j + 1
        return table.concat(out)
    end
    function val()
        ws()
        local c = s:sub(i, i)
        if c == "{" then
            i = i + 1; local t = {}
            ws()
            if s:sub(i, i) == "}" then i = i + 1 return t end
            while true do
                ws(); local k = str(); ws(); i = i + 1
                t[k] = val(); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "}" then return t end
            end
        elseif c == "[" then
            i = i + 1; local t = {}
            ws()
            if s:sub(i, i) == "]" then i = i + 1 return t end
            while true do
                t[#t + 1] = val(); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "]" then return t end
            end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == "true" then i = i + 4 return true
        elseif s:sub(i, i + 4) == "false" then i = i + 5 return false
        elseif s:sub(i, i + 3) == "null" then i = i + 4 return nil
        else
            local num = s:match("^-?[%d%.eE+-]+", i)
            i = i + #num
            return tonumber(num)
        end
    end
    return val()
end
yajl = { to_string = enc, to_value = dec }
rex = { new = function(p) return { match = function(_, s) return s:find(p) end } end }
color_table = { red = { 255, 0, 0 }, blue = { 0, 0, 255 }, yellow = { 255, 255, 0 } }

-- ---------------------------------------------------------------- output
local function out(s) STUB.out[#STUB.out + 1] = tostring(s) end
echo = out; cecho = out; decho = out
function echoLink(t) out(t) end
function cechoLink(t) out(t) end
function setFgColor() end; function resetFormat() end; function setUnderline() end; function fg() end
function moveCursorEnd() end; function getCurrentLine() return "" end
function send(cmd) STUB.sent[#STUB.sent + 1] = cmd end
function STUB.text() return table.concat(STUB.out, "") end
function STUB.clearout() STUB.out = {} end

-- ---------------------------------------------------------------- timers/events
local timerid = 0
function tempTimer(t, fn)
    timerid = timerid + 1
    STUB.timers[#STUB.timers + 1] = { id = timerid, fn = fn, t = t }
    return timerid
end
function killTimer(id)
    for i, t in ipairs(STUB.timers) do if t.id == id then table.remove(STUB.timers, i) return end end
end
-- Fires the timers due within `upto` seconds (0: only the zero-delay ones)
function STUB.runtimers(upto)
    upto = upto or 0
    local guard = 0
    while guard < 1000 do
        guard = guard + 1
        local due
        for i, t in ipairs(STUB.timers) do if t.t <= upto then due = i break end end
        if not due then return end
        local t = table.remove(STUB.timers, due)
        if type(t.fn) == "function" then t.fn() else assert(loadstring(t.fn))() end
    end
end
local function resolve(name)
    local f = _G
    for part in name:gmatch("[^%.]+") do f = f and f[part] end
    return f
end
function registerNamedEventHandler(user, name, event, fn)
    STUB.handlers[event] = STUB.handlers[event] or {}
    table.insert(STUB.handlers[event], fn)
end
function deleteAllNamedEventHandlers() STUB.handlers = {} end
function raiseEvent(event, ...)
    count("raise:" .. event)
    for _, fn in ipairs(STUB.handlers[event] or {}) do
        resolve(fn)(event, ...)
    end
end
function registerAnonymousEventHandler() return 1 end
function killAnonymousEventHandler() end
function getPackages() return {} end
function getMudletHomeDir() return "/home" end
function createStopWatch() return nil end
function getNetworkLatency() return 0 end
function getModulePath() return nil end
function centerview() end
function updateMap() end
function getMapZoom() return 20 end
function setMapZoom() end
function addMapMenu() end; function addMapEvent() end; function removeMapMenu() end; function removeMapEvent() end
function registerMapInfo(_, fn) STUB.mapinfo = fn end
function enableMapInfo() end; function killMapInfo() end
function getMapLabels() return {} end
function setCustomEnvColor() end
function highlightRoom() end; function unHighlightRoom() end

-- ---------------------------------------------------------------- the map
local M
function STUB.newmap()
    M = { rooms = {}, areas = { [-1] = "Default Area" }, nextarea = 1, data = {} }
    STUB.map = M
end
STUB.newmap()

local LONG = { "north", "northeast", "northwest", "east", "west", "south", "southeast", "southwest", "up", "down", "in", "out" }
local NUM = {}
for i, l in ipairs(LONG) do NUM[l] = i end
local SHORT = { n = 1, ne = 2, nw = 3, e = 4, w = 5, s = 6, se = 7, sw = 8, u = 9, d = 10, i = 11, o = 12 }
local function dirnum(d)
    if type(d) == "number" then return d end
    return NUM[d] or SHORT[d] or NUM[tostring(d):lower()]
end
local function R(id) local r = M.rooms[tonumber(id)]; if not r then error("no room " .. tostring(id), 2) end return r end

function addRoom(id)
    count("addRoom")
    M.rooms[id] = { id = id, name = "", area = -1, x = 0, y = 0, z = 0, env = -1, weight = 1, locked = false,
        char = "", data = {}, exits = {}, special = {}, stubs = {}, doors = {}, exitlocks = {}, speclocks = {} }
    return true
end
function roomExists(id) id = tonumber(id) return id ~= nil and M.rooms[id] ~= nil end
function deleteRoom(id) M.rooms[id] = nil end
function getRooms() count("getRooms") local t = {} for id, r in pairs(M.rooms) do t[id] = r.name end return t end
function setRoomCoordinates(id, x, y, z) local r = R(id) r.x, r.y, r.z = x, y, z end
function getRoomCoordinates(id) local r = R(id) return r.x, r.y, r.z end
function setRoomArea(id, area) count("setRoomArea") R(id).area = area end
function getRoomArea(id) return R(id).area end
function addAreaName(name) local id = M.nextarea; M.nextarea = id + 1; M.areas[id] = name; return id end
function getAreaTable() local t = {} for id, n in pairs(M.areas) do t[n] = id end return t end
function getAreaTableSwap() local t = {} for id, n in pairs(M.areas) do t[id] = n end return t end
function getRoomAreaName(id) return M.areas[id] end
function getAreaRooms1(area)
    if not M.areas[area] and area ~= 0 then return nil end
    local t = {}
    for id, r in pairs(M.rooms) do if r.area == area then t[#t + 1] = id end end
    table.sort(t)
    return t
end
function setRoomName(id, n) R(id).name = n end
function getRoomName(id) local r = M.rooms[tonumber(id)] return r and r.name end
function setRoomEnv(id, e) R(id).env = e end
function getRoomEnv(id) return R(id).env end
function setRoomWeight(id, w) count("setRoomWeight") R(id).weight = w end
function getRoomWeight(id) return R(id).weight end
function lockRoom(id, b) count("lockRoom") local r = M.rooms[id] if r then r.locked = b end return r ~= nil end
function roomLocked(id) return R(id).locked end
function setRoomChar(id, c) count("setRoomChar") R(id).char = c end
function getRoomChar(id) return R(id).char end
function getAllRoomUserData(id) count("getAllRoomUserData") local t = {} for k, v in pairs(R(id).data) do t[k] = v end return t end
function getRoomUserData(id, k) count("getRoomUserData") return R(id).data[k] or "" end
function setRoomUserData(id, k, v) count("setRoomUserData") R(id).data[k] = v end
function clearRoomUserDataItem(id, k) R(id).data[k] = nil end
function searchRoomUserData(key, value)
    count("searchRoomUserData")
    local out, seen = {}, {}
    for id, r in pairs(M.rooms) do
        local v = r.data[key]
        if v ~= nil then
            if value == nil then
                if not seen[v] then seen[v] = true; out[#out + 1] = v end
            elseif v == value then
                out[#out + 1] = id
            end
        end
    end
    table.sort(out)
    return out
end
function getMapUserData(k) local v = M.data[k] if v == nil then return nil, "no such key" end return v end
function setMapUserData(k, v) count("setMapUserData") M.data[k] = v return true end
function clearMapUserDataItem(k) M.data[k] = nil end
function deleteMap() STUB.newmap() return true end

function setExit(from, to, dir)
    local d = dirnum(dir)
    local r = R(from)
    if to == -1 then r.exits[LONG[d]] = nil else r.exits[LONG[d]] = to; r.stubs[d] = nil end
    return true
end
function getRoomExits(id) local t = {} for k, v in pairs(R(id).exits) do t[k] = v end return t end
function getSpecialExitsSwap(id) local t = {} for k, v in pairs(R(id).special) do t[k] = v end return t end
function getSpecialExits(id) local t = {} for k, v in pairs(R(id).special) do t[v] = { [k] = "0" } end return t end
function addSpecialExit(from, to, cmd) R(from).special[cmd] = to end
function removeSpecialExit(from, cmd) R(from).special[cmd] = nil end
function lockExit(id, dir, b) count("lockExit") R(id).exitlocks[dirnum(dir)] = b end
function hasExitLock(id, dir) return R(id).exitlocks[dirnum(dir)] == true end
function lockSpecialExit(from, to, cmd, b) R(from).speclocks[cmd] = b end
function hasSpecialExitLock(from, to, cmd) return R(from).speclocks[cmd] == true end
function setExitStub(id, dir, b) R(id).stubs[dirnum(dir)] = b or nil end
function getExitStubs1(id) local t = {} for d in pairs(R(id).stubs) do t[#t + 1] = d end table.sort(t) return t end
function setDoor(id, dir, v) R(id).doors[dir] = v ~= 0 and v or nil end
function getDoors(id) local t = {} for k, v in pairs(R(id).doors) do t[k] = v end return t end
function getExitWeights() return {} end
function getAllRoomEntrances(id)
    count("getAllRoomEntrances")
    local t = {}
    for fid, r in pairs(M.rooms) do
        for _, to in pairs(r.exits) do if to == id then t[#t + 1] = fid end end
        for _, to in pairs(r.special) do if to == id then t[#t + 1] = fid end end
    end
    return t
end
function setRoomBorderColor(id, r, g, b) count("setRoomBorderColor") R(id).border = { r, g, b } end
function clearRoomBorderColor(id) count("clearRoomBorderColor") R(id).border = nil end
function setRoomBorderThickness(id, t) R(id).thick = t end
function clearRoomBorderThickness(id) R(id).thick = nil end
function searchRoom(q)
    local t = {}
    for id, r in pairs(M.rooms) do if r.name:lower():find(q:lower(), 1, true) then t[id] = r.name end end
    return t
end

-- Dijkstra over the fake map, honouring room/exit locks and weights, the way
-- Mudlet does: the cost of a step is the weight of the room entered.
function getPath(from, to)
    count("getPath")
    if not M.rooms[from] or not M.rooms[to] then return nil, "bad room" end
    local dist, prev, via, done = { [from] = 0 }, {}, {}, {}
    while true do
        local best, bd
        for id, d in pairs(dist) do if not done[id] and (not bd or d < bd) then best, bd = id, d end end
        if not best then break end
        done[best] = true
        if best == to then break end
        local r = M.rooms[best]
        local function relax(nb, cmd, locked)
            local n = M.rooms[nb]
            if n and not n.locked and not locked then
                local nd = bd + n.weight
                if not dist[nb] or nd < dist[nb] then dist[nb], prev[nb], via[nb] = nd, best, cmd end
            end
        end
        for long, nb in pairs(r.exits) do relax(nb, long, r.exitlocks[NUM[long]]) end
        for cmd, nb in pairs(r.special) do relax(nb, cmd, r.speclocks[cmd]) end
    end
    if not dist[to] then speedWalkDir, speedWalkPath = {}, {} return false, -1 end
    local dirs, rooms, id = {}, {}, to
    while id ~= from do table.insert(dirs, 1, via[id]); table.insert(rooms, 1, tostring(id)); id = prev[id] end
    speedWalkDir, speedWalkPath = dirs, rooms
    return true, dist[to]
end
