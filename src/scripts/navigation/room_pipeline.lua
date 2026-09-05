-- Everything that happens when the player arrives in a room, in the order it
-- has to happen in.
--
-- The server sends Room.Info.Basic and Room.Info.Exits together for a room
-- change, Basic first, and Room.Info.Exits on its own when a door or a lock in
-- the room changes. Mudlet raises an event for every level of a GMCP key, so
-- handlers hung on gmcp.Room.Info run once per message; the Exits message is the
-- one that is always last and always complete, so the whole pipeline hangs off
-- that and nothing hangs off gmcp.Room.Info.

-- Keeps the showpath highlight in step with a player walking by hand. Runs after
-- mapping, because a room entered for the first time has no exits of its own
-- until mapping links them - a path recalculated before that would find no way
-- onward and the highlight would freeze where the mapped rooms ended.
function mapper.updateshowpath(num)
    if not mapper.showPathDestination or mapper.autowalking or not num then
        return
    end
    if num == mapper.showPathDestination then
        mapper.clearShowPath()
        mapper.notify("You've arrived at your destination.")
    elseif roomExists(num) then
        -- A room the map does not have, or a path it cannot find, keeps the
        -- existing highlight rather than clearing it
        if mapper.getPath(num, mapper.showPathDestination) then
            mapper.highlightPath(speedWalkPath, num)
        end
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

    if num == mapper.speedWalkPath[#mapper.speedWalkPath] then
        mapper.endwalk("arrived")
    elseif mapper.speedWalkPath[mapper.speedWalkCounter] == num then
        mapper.speedWalkCounter = mapper.speedWalkCounter + 1
        if mapper.speedWalkCounter > #mapper.speedWalkPath then
            mapper.endwalk("arrived")
        else
            mapper.updatePathHighlight()
            local delay = mapper.settings.walkdelay
            if delay == nil then
                delay = 0.3
            end
            mapper.delayedMove(delay)
        end
    elseif #mapper.speedWalkPath > 0 then
        -- ended up somewhere we didn't want to be - re-calculate path
        mapper.notify("Ended up off the path, recalculating a new path...")
        local destination = mapper.speedWalkPath[#mapper.speedWalkPath]
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
    if mapper.editing then
        mapper.mappingnewroom(num)
    end

    if mapper.roomexists(num) then
        mapper.storebiome(num)
        if mapper.updateDoorStatuses(num) and mapper.settings and mapper.settings.showmappingmessages then
            mapper.notify("Door statuses updated for room " .. num)
        end
        centerview(num)
    end

    mapper.updateshowpath(num)
    mapper.walkstep(num)
end
