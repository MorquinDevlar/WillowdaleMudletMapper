-- Check for generic_mapper and uninstall if present to avoid conflicts
mapper.checkGenericMapper()

-- Register all event handlers when the package loads
-- This runs before sysLoadEvent, so handlers will be ready
mapper.defineEventHandlers()

-- What the mapper puts on the map itself. Both live in navigation/, which is
-- compiled after core/, so this waits for the rest of the package rather than
-- calling functions that do not exist yet.
tempTimer(0, function()
    if mapper.installmapmenu then
        mapper.installmapmenu()
    end
    if mapper.installmapinfo then
        mapper.installmapinfo()
    end
end)
