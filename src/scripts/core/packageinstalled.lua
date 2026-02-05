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
            if mapper and mapper.reload then
                mapper.reload()
            end
            -- Load saved options (normally done by sysLoadEvent which doesn't fire on reinstall)
            if mapper and mapper.loadoptions then
                mapper.loadoptions()
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
            mapper.echo("WillowdaleMudletMapper reinitialized after package installation.")
        end)
    end
end

-- Register the event handler
if mapper.packageInstalledHandler then
    killAnonymousEventHandler(mapper.packageInstalledHandler)
end
mapper.packageInstalledHandler = registerAnonymousEventHandler("sysInstallPackage", "mapper.onPackageInstalled")