-- Event handler for when the package is installed or reinstalled
-- This ensures the mapper reinitializes properly after package updates

function mapper.onPackageInstalled(_, package)
    -- Check if this is our package being installed
    if package and (package:find("MudletMapper") or package:find("WillowdaleMudletMapper")) then
        -- Small delay to ensure all files are loaded
        tempTimer(0.5, function()
            if mapper and mapper.reload then
                mapper.reload()
                mapper.echo("WillowdaleMudletMapper reinitialized after package installation.")
            end
        end)
    end
end

-- Register the event handler
if mapper.packageInstalledHandler then
    killAnonymousEventHandler(mapper.packageInstalledHandler)
end
mapper.packageInstalledHandler = registerAnonymousEventHandler("sysInstallPackage", "mapper.onPackageInstalled")