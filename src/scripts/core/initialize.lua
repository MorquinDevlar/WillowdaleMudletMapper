-- Check for generic_mapper and uninstall if present to avoid conflicts
mapper.checkGenericMapper()

-- Register all event handlers when the package loads
-- This runs before sysLoadEvent, so handlers will be ready
mapper.defineEventHandlers()
