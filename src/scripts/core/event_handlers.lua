-- Centralized event handler registration
-- All event bindings defined in one place for easy management

mapper = mapper or {}
mapper.events = mapper.events or {}

-- All event handlers in one place
-- Functions stay in the mapper.* namespace
mapper.events.list = {
	-- System events
	sysLoadEvent = { "mapper.startup", "mapper.loadoptions" },
	sysExitEvent = { "mapper.saveoptions", "mapper.clearlastupdate" },
	sysUninstallPackage = { "mapper.handleUninstall" },
	sysDownloadDone = { "mapper.downloadedfile" },
	sysDownloadError = { "mapper.seedownloaderrors" },
	mapDataChanged = { "mapper.mapdata_changed" },

	-- GMCP Game events
	["gmcp.Game.Info"] = { "mapper.checkupdatestart", "mapper.registergomudenvdata" },

	-- GMCP Room events
	["gmcp.Room.Info"] = { "mapper.room_events", "mapper.centerroominfo" },
	["gmcp.Room.Info.Exits"] = { "mapper.updatedoors", "mapper.mappingnewroom" },
	["gmcp.Room.Wrongdir"] = { "mapper.wrongdir_handler" },
	RoomNum = { "mapper.mappingnewroom" },

	-- Custom mapper events
	["mapper logged in"] = { "mapper.registergomudenvdata", "mapper.checkupdatestart" },
	["mapper areas changed"] = { "mapper.regenerateareas" },
}

-- Register all events from the table
function mapper.defineEventHandlers()
	for eventName, handlers in pairs(mapper.events.list) do
		for _, functionRef in pairs(handlers) do
			registerNamedEventHandler("mapper", eventName .. "-" .. functionRef, eventName, functionRef)
		end
	end
end

-- Unregister all events (useful for package uninstall)
function mapper.killEventHandlers()
	for eventName, handlers in pairs(mapper.events.list) do
		for _, functionRef in pairs(handlers) do
			deleteNamedEventHandler("mapper", eventName .. "-" .. functionRef)
		end
	end
end
