-- Event handler for when the package is installed or reinstalled
-- This ensures the mapper reinitializes properly after package updates

function mapper.onPackageInstalled(_, package)
    -- Check if this is our package being installed
    if package and (package:find("MudletMapper") or package:find("WillowdaleMudletMapper")) then
        -- Small delay to ensure all files are loaded
        tempTimer(0.5, function()
            -- Check for and remove generic_mapper if present
            if mapper and mapper.checkGenericMapper then
                mapper.checkGenericMapper()
            end
            -- Redefine doSpeedWalk in case generic_mapper overwrote it
            if mapper and mapper.defineDoSpeedWalk then
                mapper.defineDoSpeedWalk()
            end
            -- reload() rebuilds the settings and reads the saved ones back,
            -- which sysLoadEvent would have done had it fired on a reinstall
            if mapper and mapper.reload then
                mapper.reload()
            end
            -- An update installs in the middle of a session, so the map it
            -- finds may still carry the features and marks of the version it
            -- replaced; sysLoadEvent, which normally turns them into tags,
            -- does not fire for an install.
            if mapper and mapper.migratetags then
                mapper.migratetags()
            end
            -- Restore Mudlet's current room from GMCP data so double-click works
            if gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then
                local roomId = tonumber(gmcp.Room.Info.Basic.id)
                if roomId and roomExists(roomId) then
                    centerview(roomId)
                    mapper.currentroom = roomId
                    mapper.currentroomname = getRoomName(roomId) or gmcp.Room.Info.Basic.name or "(unknown)"
                    -- Refresh map widget to ensure it recognizes the current room
                    updateMap()
                end
            end
        end)
    end
end

-- The version before this one registered the handler above anonymously and
-- kept the id here; the table carries it across a reinstall so that it can be
-- taken down, or the install would be handled twice.
if mapper.packageInstalledHandler then
    killAnonymousEventHandler(mapper.packageInstalledHandler)
    mapper.packageInstalledHandler = nil
end
