-- mmp = mudlet mapper namespace
mmp = mmp
	or {
		paused = false,
		autowalking = false,
		currentroom = 0,
		currentroomname = "(unknown)",
		firstRun = true,
		specials = {},
	}
mmp.speedWalkWatch = createStopWatch()
-- speedWalkPath and speedWalkDir populated by Mudlet from getPath() and gotoRoom()
speedWalkPath = speedWalkPath or {}
speedWalkDir = speedWalkDir or {}

-- actually used by the mapper for walking
mmp.speedWalkCounter = 0
mmp.speedWalk = mmp.speedWalk or {}
mmp.speedWalkPath = mmp.speedWalkPath or {}
mmp.speedWalkDir = mmp.speedWalkDir or {}
mmp.lagtable = {
	[1] = { description = "Normal, default level.", time = 0.5 },
	[2] = { description = "Decent, but slightly laggy.", time = 1 },
	[3] = { description = "Noticeably laggy with occasional spikes.", time = 2 },
	[4] = { description = "Bad. Terrible. Terribad.", time = 5 },
	[5] = { description = "Carrier Pigeon", time = 10 },
}
local newversion = "2.0.0"
if mmp.version and mmp.version ~= newversion then
	if not mmp.game then
		mmp.echo(
			"Mapper script updated - Thanks! I don't know what game are you connected to, though - so please reconnect, if you could."
		)
	else
		mmp.echo("Mapper script updated - thanks! You don't need to restart.")
	end
end
mmp.version = newversion

function mmp.reload()
	-- Force reload of settings
	mmp.firstRun = true
	mmp.startup()
	mmp.echo("Mapper settings reloaded!")
end

function mmp.startup()
	if not mmp.firstRun then
		return
	end
	local private_settings = {}

	--General settings

	private_settings["echocolour"] = mmp.createOption(
		"cyan",
		mmp.changeEchoColour,
		{ "string" },
		"Set the color for room number echos?",
		function(newSetting)
			return color_table[newSetting] ~= nil
		end
	)
	private_settings["crowdmap"] = mmp.createOption(
		false,
		mmp.changeMapSource,
		{ "boolean" },
		"Use a crowd-sourced map instead of games default?",
		nil,
		{ gomud = true }
	)
	private_settings["showcmds"] = mmp.createOption(true, mmp.changeBoolFunc, { "boolean" }, "Show walking commands?")
	private_settings["laglevel"] = mmp.createOption(
		1,
		mmp.changeLaglevel,
		{ "number" },
		"How laggy is your connection, (fast 1<->5 slow)?",
		mmp.verifyLaglevel
	)
	private_settings["slowwalk"] =
		mmp.createOption(false, mmp.setSlowWalk, { "boolean" }, "Walk slowly instead of as quick as possible?")
	private_settings["fastwalk"] = mmp.createOption(
		false,
		mmp.changeBoolFunc,
		{ "boolean" },
		"Walk as quick as possible instead of waiting for prompts?"
	)
	private_settings["updatemap"] =
		mmp.createOption(true, mmp.changeUpdateMap, { "boolean" }, "Check for new maps from your MUD?")
	private_settings["autopositionrooms"] = mmp.createOption(
		true,
		mmp.setAutoPositionRooms,
		{ "boolean" },
		"Auto position rooms when mapping?",
		nil,
		{ gomud = true }
	)
	private_settings["debug"] = mmp.createOption(false, mmp.changeBoolFunc, { "boolean" }, "Enable debug messages?")

	--Settings that lock things

	private_settings["lockspecials"] =
		mmp.createOption(false, mmp.lockSpecials, { "boolean" }, "Lock all special exits?")

	mmp.settings = mmp.createOptionsTable(private_settings)
	mmp.settings.disp = mmp.echo
	mmp.game = false
	mmp.settings.dispOption = function(opt, val)
		cecho(
			"<green>"
				.. val.use
				.. "<white> ("
				.. opt
				.. ") "
				.. string.rep(" ", 50 - val.use:len() - opt:len())
				.. tostring(val.value)
				.. "\n"
		)
	end
	mmp.settings.dispDefaultWriteError = function()
		mmp.echo("Please use the mconfig alias to set options!")
	end
	raiseEvent("mmp areas changed")
	mmp.firstRun = false
	mmp.echon("Mudlet Mapper script for GoMud (" .. tostring(mmp.version) .. ") loaded! (")
	echoLink(
		"See more on Github",
		"(openUrl or openURL)('https://github.com/GoMudEngine/MudletMapper')",
		"Clicky clicky to read up on what's this about"
	)
	echo(")\n")
end
