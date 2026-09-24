-- Everything that happens when the player arrives in a room, in the order it
-- has to happen in.
--
-- The server sends Room.Info.Basic and Room.Info.Exits together for a room
-- change, Basic first, and Room.Info.Exits on its own when a door or a lock in
-- the room changes. Mudlet raises an event for every level of a GMCP key, so
-- handlers hung on gmcp.Room.Info run once per message; the Exits message is the
-- one that is always last and always complete, so the whole pipeline hangs off
-- that and nothing hangs off gmcp.Room.Info.

-- Where a room comes on a list of room IDs, trying first the place the list
-- says the player is headed for next.
local function positionon(rooms, room, expected)
    if expected and rooms[expected] == room then
        return expected
    end
    for i = 1, #rooms do
        if rooms[i] == room then
            return i
        end
    end
    return nil
end

-- Keeps the showpath highlight in step with a player walking by hand. Runs after
-- mapping, because a room entered for the first time has no exits of its own
-- until mapping links them - a path recalculated before that would find no way
-- onward and the highlight would freeze where the mapped rooms ended.
function mapper.updateshowpath(num)
    local destination = mapper.showPathDestination
    if not destination or mapper.autowalking or not num then
        return
    end
    if num == destination then
        mapper.clearShowPath()
        mapper.notify("You've arrived at your destination.")
        return
    end
    -- A room the map does not have, or a path it cannot find, keeps the
    -- existing highlight rather than clearing it
    if not roomExists(num) then
        return
    end

    -- Still on the route being shown, with nothing along the rest of it shut
    -- since: the route goes on from here, and working it out again would be a
    -- search of the whole map - after rebuilding Mudlet's whole pathfinding
    -- graph, whenever this step mapped something new.
    local route = mapper.showPathRoute
    local at = route and positionon(route.rooms, num, route.first)
    if at and mapper.routeopen(num, route.dirs, route.rooms, at + 1) then
        -- One room on is one room's repaint; anything else is the path afresh
        if at ~= route.first or not mapper.advancePathHighlight(num) then
            mapper.highlightPath(route.rooms, num, at + 1)
        end
        route.first = at + 1
        return
    end

    if mapper.getPath(num, destination) then
        mapper.showPathRoute = { dirs = speedWalkDir, rooms = speedWalkPath, first = 1 }
        mapper.highlightPath(speedWalkPath, num)
    end
end

-- The room the walk last took a step in. A door or lock change sends the exits
-- of the room the player is standing in all over again, and that is not another
-- step.
local lastroom

-- One step of a speedwalk: the room we just landed in either finishes the walk,
-- moves it on, or means we are off the path and need a new one.
function mapper.walkstep(num)
    if mapper.debugging() and mapper.autowalking then
        mapper.notify(
            string.format(
                "Room change detected: %d (counter: %d/%d, dest: %s)",
                num,
                mapper.speedWalkCounter or 0,
                #(mapper.speedWalkPath or {}),
                mapper.speedWalkPath and mapper.speedWalkPath[#mapper.speedWalkPath] or "none"
            )
        )
    end

    if lastroom == num then
        return
    end
    lastroom = num
    -- A move landed, so whatever the last one needed retrying for is behind us
    mapper.resetwatchdog()

    if not mapper.autowalking then
        return
    end

    local path = mapper.speedWalkPath
    if num == path[#path] then
        mapper.endwalk("arrived")
        return
    end

    local expected = mapper.speedWalkCounter
    local at = positionon(path, num, expected)
    if at then
        -- The room the walk was heading for, or another room on its path: a
        -- move that carried the player past a room, or back along the way. The
        -- walk goes on from wherever on the path that is.
        mapper.speedWalkCounter = at + 1
        mapper.updatePathHighlight(at == expected and num or nil)
        mapper.delayedMove()
    elseif #path > 0 then
        -- ended up somewhere we didn't want to be - re-calculate path
        mapper.notify("Ended up off the path, recalculating a new path...")
        local destination = path[#path]
        if not mapper.getPath(num, destination) then
            mapper.notify(
                string.format(
                    "Don't know how to get to %d (%s) anymore :( Move into a room we know of to continue",
                    destination,
                    getRoomName(destination)
                )
            )
        else
            mapper.gotoRoom(destination)
        end
    end
end

function mapper.onroom()
    local basic = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic
    local num = basic and tonumber(basic.id)
    if not num then
        return
    end

    mapper.currentroom = num
    local name = basic.name
    if not name or name == "" then
        name = getRoomName(num)
    end
    mapper.currentroomname = name

    -- Mapping first: the rest of the pipeline works on a room that exists and
    -- has its exits, which on a first visit is only true once mapping has run.
    -- It hands back the room's user data, so the arrival reads it once.
    local data
    if mapper.editing then
        data = mapper.mappingnewroom(num)
    end

    if mapper.roomexists(num) then
        mapper.storebiome(num, data)
        if mapper.updateDoorStatuses(num) and mapper.settings and mapper.settings.showmappingmessages then
            mapper.notify("Door statuses updated for room " .. num)
        end
        centerview(num)
    end

    -- The line over the map is about the room the player is in
    mapper.mapinfodirty()
    mapper.updateshowpath(num)
    mapper.walkstep(num)
end
