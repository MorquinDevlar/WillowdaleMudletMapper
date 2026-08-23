-- Centralized event handler registration
-- All event bindings defined in one place for easy management

mapper = mapper or {}
mapper.events = mapper.events or {}

-- All event handlers in one place
-- Functions stay in the mapper.* namespace
mapper.events.list = {
	-- System events
	sysLoadEvent = { "mapper.startup", "mapper.loadoptions" },
	sysExitEvent = { "mapper.saveoptions" },
	sysUninstallPackage = { "mapper.handleUninstall" },
	sysDownloadDone = { "mapper.downloadedfile" },
	sysDownloadError = { "mapper.seedownloaderrors" },

	-- Every way a different map can arrive, funnelled into one event below.
	mapDataChanged = { "mapper.mapdata_changed" },
	sysMapLoad = { "mapper.mapdata_changed" },
	sys2DMapLoad = { "mapper.mapdata_changed" },
	sys3DMapLoad = { "mapper.mapdata_changed" },
	sysMapDownloadEvent = { "mapper.mapdata_changed" },
	mapOpenEvent = { "mapper.mapdata_changed" },

	-- GMCP Game events
	["gmcp.Game.Info"] = { "mapper.checkupdatestart", "mapper.registergomudenvdata" },

	-- GMCP Room events. Mapping runs before doors so that a room created on this
	-- pass has its doors set now rather than on the next visit.
	["gmcp.Room.Info"] = { "mapper.room_events", "mapper.centerroominfo" },
	["gmcp.Room.Info.Exits"] = { "mapper.mappingnewroom", "mapper.updatedoors" },
	["gmcp.Room.Wrongdir"] = { "mapper.wrongdir_handler" },
	["gmcp.Room.MoveBlocked"] = { "mapper.moveblocked_handler" },
	["gmcp.Room.MoveDelayed"] = { "mapper.movedelayed_handler" },

	-- Custom mapper events
	["mapper areas changed"] = { "mapper.regenerateareas" },
	-- A freshly loaded map has its own areas, and the room locks that keep
	-- pathfinding out of an area the player locked are not part of the map file.
	["mapper map reloaded"] = { "mapper.regenerateareas", "mapper.relockareas" },
}

-- Register all events from the table
function mapper.defineEventHandlers()
	for eventName, handlers in pairs(mapper.events.list) do
		for _, functionRef in ipairs(handlers) do
			registerNamedEventHandler("mapper", eventName .. "-" .. functionRef, eventName, functionRef)
		end
	end
end

-- Unregister all events (useful for package uninstall)
function mapper.killEventHandlers()
	for eventName, handlers in pairs(mapper.events.list) do
		for _, functionRef in ipairs(handlers) do
			deleteNamedEventHandler("mapper", eventName .. "-" .. functionRef)
		end
	end
end
