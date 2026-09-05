-- Centralized event handler registration
-- All event bindings defined in one place for easy management

mapper = mapper or {}
mapper.events = mapper.events or {}

-- All event handlers in one place
-- Functions stay in the mapper.* namespace
mapper.events.list = {
	-- System events
	sysLoadEvent = { "mapper.startup", "mapper.loadoptions", "mapper.migratetags", "mapper.clearStalePathHighlights" },
	sysExitEvent = { "mapper.saveoptions" },
	sysInstallPackage = { "mapper.onPackageInstalled" },
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

	-- GMCP Room events. One handler for the whole arrival, on the Exits message:
	-- a room change sends Basic and then Exits, and a door or lock change sends
	-- Exits alone, so Exits is the message that is always last and always
	-- complete. Nothing may hang off gmcp.Room.Info - Mudlet raises an event per
	-- level of a GMCP key, so a handler there runs once per message.
	["gmcp.Room.Info.Exits"] = { "mapper.onroom" },
	["gmcp.Room.Wrongdir"] = { "mapper.wrongdir_handler" },
	["gmcp.Room.MoveBlocked"] = { "mapper.moveblocked_handler" },
	["gmcp.Room.MoveDelayed"] = { "mapper.movedelayed_handler" },

	-- Custom mapper events
	["mapper areas changed"] = { "mapper.regenerateareas" },
	-- Anything the pathfinder reads has changed, so kept routes are worthless
	["mapper updated map"] = { "mapper.clearpathcache" },
	-- A freshly loaded map has its own areas and its own tags, and neither the
	-- room locks that keep pathfinding out of an area the player locked nor the
	-- mapper's right-click menu are part of the map file it arrived in.
	["mapper map reloaded"] = {
		"mapper.regenerateareas",
		"mapper.relockareas",
		"mapper.clearStalePathHighlights",
		"mapper.migratetags",
		"mapper.installmapmenu",
	},

	-- One entry of the mapper's right-click map menu was picked. Nothing else
	-- may register here: Mudlet says which entry only by its unique name, so a
	-- second handler would act on entries that are not its own.
	["mapper mapmenu"] = { "mapper.onmapmenu" },
}

-- Register all events from the table.
--
-- Named handlers live in the profile, not in the package: an update uninstalls
-- and reinstalls the package inside one session and leaves every handler the
-- old version registered in place, still pointing at the old functions, which
-- also survive in the old mapper table. A handler whose name has changed
-- between versions is then not replaced but joined, and the walk was being
-- stepped twice per room. So everything under the "mapper" name goes first,
-- and the core folder script rebuilds the mapper table on load for the same
-- reason.
function mapper.defineEventHandlers()
	if deleteAllNamedEventHandlers then
		deleteAllNamedEventHandlers("mapper")
	end
	for eventName, handlers in pairs(mapper.events.list) do
		for _, functionRef in ipairs(handlers) do
			registerNamedEventHandler("mapper", eventName .. "-" .. functionRef, eventName, functionRef)
		end
	end
end
