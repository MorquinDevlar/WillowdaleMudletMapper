-- mapper = mudlet mapper namespace
mapper = mapper or {}

-- Game and engine are set dynamically from gmcp.Game.Info
-- mapper.game = gmcp.Game.Info.name (e.g., "Willowdale")
-- mapper.engine = gmcp.Game.Info.engine (e.g., "GoMud")

-- Initialize default values if not set
mapper.autowalking = mapper.autowalking or false
mapper.currentroom = mapper.currentroom or 0
mapper.currentroomname = mapper.currentroomname or "(unknown)"

-- firstRun must be explicitly checked for nil since false is a valid value
if mapper.firstRun == nil then
	mapper.firstRun = true
end

-- Mapping mode is always enabled (auto-creates rooms from GMCP data)
if mapper.editing == nil then
	mapper.editing = true
end
-- The walk's stopwatch is not made here: Mudlet refuses to create one while it
-- is loading scripts, so one made at load time is nil. walking.lua makes it
-- the first time a walk starts, when creation is allowed.
-- speedWalkPath and speedWalkDir populated by Mudlet from getPath() and gotoRoom()
speedWalkPath = speedWalkPath or {}
speedWalkDir = speedWalkDir or {}

-- actually used by the mapper for walking
mapper.speedWalkCounter = 0
mapper.speedWalkPath = mapper.speedWalkPath or {}
mapper.speedWalkDir = mapper.speedWalkDir or {}
local newversion = "__VERSION__"
if mapper.version and mapper.version ~= newversion then
	mapper.notify("Script updated - thanks! You don't need to restart.")
end
mapper.version = newversion

function mapper.reload()
	-- Force reload of settings
	mapper.firstRun = true
	mapper.startup()
	-- startup() rebuilds the settings from their defaults, so the saved ones have
	-- to be read back or a reload would quietly reset the player's config. It
	-- reports the restore itself, which leaves this nothing of its own to say.
	mapper.loadoptions()
end

function mapper.startup()
	if not mapper.firstRun then
		return
	end

	mapper.settings = mapper.newsettings()

	-- Set environment colors if they're defined
	if mapper.setEnvironmentColors then
		mapper.setEnvironmentColors()
	end

	-- Initialize biome colors from saved mappings
	if mapper.initializeBiomeColors then
		mapper.initializeBiomeColors()
	end

	raiseEvent("mapper areas changed")
	mapper.firstRun = false
	mapper.notify("Willowdale mapper " .. tostring(mapper.version) .. " loaded.")
end
