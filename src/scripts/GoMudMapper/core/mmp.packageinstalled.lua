-- Event handler for when the package is installed or reinstalled
-- This ensures the mapper reinitializes properly after package updates

function mmp.onPackageInstalled(_, package)
    -- Check if this is our package being installed
    if package and (package:find("MudletMapper") or package:find("GoMudMapper")) then
        -- Small delay to ensure all files are loaded
        tempTimer(0.5, function()
            if mmp and mmp.reload then
                mmp.reload()
                mmp.echo("GoMudMapper reinitialized after package installation.")
            end
        end)
    end
end

-- Register the event handler
if mmp.packageInstalledHandler then
    killAnonymousEventHandler(mmp.packageInstalledHandler)
end
mmp.packageInstalledHandler = registerAnonymousEventHandler("sysInstallPackage", "mmp.onPackageInstalled")