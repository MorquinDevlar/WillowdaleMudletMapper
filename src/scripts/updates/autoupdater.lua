-- Auto-updater for mapper script and crowdmap
-- Consolidates: check_for_updates, checkupdatestart, downloadedfile, seedownloaderrors

local downloadfolder = getMudletHomeDir() .. "/map downloads/"

--------------------------------------------------------------------------------
-- Version Comparison
--------------------------------------------------------------------------------

-- Compare semantic versions: returns true if v1 > v2
function mapper.compare_versions(v1, v2)
	local function split(v)
		local t = {}
		for num in string.gmatch(tostring(v), "%d+") do
			table.insert(t, tonumber(num))
		end
		return t
	end

	local version1 = split(v1)
	local version2 = split(v2)

	for i = 1, math.max(#version1, #version2) do
		local part1 = version1[i] or 0
		local part2 = version2[i] or 0
		if part1 > part2 then return true end
		if part1 < part2 then return false end
	end
	return false
end

--------------------------------------------------------------------------------
-- Update Check Triggers
--------------------------------------------------------------------------------

function mapper.checkupdatestart(...)
	if mapper.checkforupdatetimer then
		killTimer(mapper.checkforupdatetimer)
	end
	-- Check for mapper script updates after a short random delay
	-- Set verbose flag for login-triggered checks
	mapper.updateCheckVerbose = true
	mapper.checkforupdatetimer = tempTimer(math.random(3, 10), function()
		mapper.checkforupdate()
	end)
end

-- Silent update check (for periodic timer)
function mapper.checkupdatesilent()
	mapper.updateCheckVerbose = false
	mapper.checkforupdate()
end

function mapper.changeUpdateMap()
	if mapper.settings.updatemap then
		mapper.echo("Will check for new map updates from your MUD.")
		enableTimer("Check for updates periodically")
	--mapper.checkUpdateStart()
	else
		mapper.echo("Won't check for new map updates from your MUD.")
		disableTimer("Check for updates periodically")
		if mapper.checkforupdatetimer then
			killTimer("mapper.checkforupdatetimer")
		end
	end
end

--------------------------------------------------------------------------------
-- Update Check Functions
--------------------------------------------------------------------------------

-- Check for mapper script updates
-- Called automatically on login via "mapper logged in" event
function mapper.checkforupdate()
	if mapper.checkingupdates then
		return
	end

	if not downloadFile then
		mapper.echo("Your version of Mudlet doesn't support downloading files - please upgrade to 2.0+")
		return
	end

	-- Ensure download folder exists
	if not lfs.attributes(downloadfolder) then
		if lfs and lfs.mkdir then
			local t, s = lfs.mkdir(downloadfolder)
			if not t and s ~= "File exists" then
				mapper.echo("Couldn't make the '" .. downloadfolder .. "' folder; " .. s)
				return
			end
		else
			mapper.echo(
				"Sorry, but you need LuaFileSystem (lfs) installed, or have the '"
					.. downloadfolder
					.. "' folder exist."
			)
			return
		end
	end

	-- Download releases.json to check for updates
	mapper.releasesfile = downloadfolder .. "releases.json"
	mapper.checkingupdates = true
	if mapper.updateCheckVerbose then
		mapper.echo("Checking for mapper updates...")
	end
	downloadFile(mapper.releasesfile, "https://www.willowdalemud.com/static/resources/mapper/releases.json")
end

-- Download the latest mapper package
function mapper.downloadmapperscript()
	local file = getModulePath("WillowdaleMudletMapper") or getMudletHomeDir() .. "/map downloads/WillowdaleMudletMapper.mpackage"
	if io.exists(file) then
		local s, m = os.remove(file)
		if not s then
			mapper.echo(string.format("Couldn't delete the old package (located at %s), because of: %s. This might be a problem.", file, m))
		end
	end
	mapper.downloadedscript = file
	downloadFile(
		mapper.downloadedscript,
		"https://www.willowdalemud.com/static/resources/mapper/WillowdaleMudletMapper.mpackage"
	)
	mapper.echo("Downloading mapper update...")
end

-- Install the downloaded mapper package
function mapper.installMapperScript()
	local path = getModulePath("WillowdaleMudletMapper")
	if not path then
		uninstallPackage("WillowdaleMudletMapper")
		tempTimer(1, [[installPackage(mapper.downloadedscript)]])
	else
		reloadModule("WillowdaleMudletMapper")
	end
end

--------------------------------------------------------------------------------
-- Download Handlers
--------------------------------------------------------------------------------

function mapper.downloadedfile(_, filename)
	if not io.exists(filename) then
		return
	end

	-- Handle releases.json for mapper script updates
	if filename == tostring(mapper.releasesfile) then
		mapper.checkingupdates = false

		local f = io.open(filename)
		if not f then
			return
		end
		local content = f:read("*a")
		io.close(f)

		-- Parse JSON
		local ok, releases = pcall(yajl.to_value, content)
		if not ok or not releases or #releases == 0 then
			mapper.echo("Failed to parse releases.json")
			return
		end

		local latest = releases[1]
		if not latest or not latest.version then
			mapper.echo("Invalid releases.json format")
			return
		end

		-- Compare versions (check if latest is newer than current)
		if not mapper.compare_versions(latest.version, mapper.version) then
			if mapper.updateCheckVerbose then
				mapper.echo("You're running the latest version (" .. mapper.version .. ").")
			end
			mapper.updateCheckVerbose = false
			return
		end

		-- Update available
		mapper.newmapperversion = latest.version

		echo("\n")
		mapper.echo("------------------[ Mapper Update Available ]------------------")
		mapper.echo(
			"Version <orange>"
				.. tostring(mapper.version)
				.. "<reset> -> <green>"
				.. tostring(latest.version)
				.. "<reset>"
		)
		if latest.released then
			mapper.echo("Released: " .. latest.released)
		end
		mapper.echo("")
		if latest.changes and #latest.changes > 0 then
			mapper.echo("Changes:")
			for _, change in ipairs(latest.changes) do
				mapper.echo("  - " .. change)
			end
			mapper.echo("")
		end
		cechoLink(
			"<ForestGreen>[Click here to install update]<reset>",
			"mapper.downloadmapperscript()",
			"Download and install version " .. latest.version,
			true
		)
		echo("\n\n")
		mapper.updateCheckVerbose = false

	-- Handle downloaded mapper package
	elseif filename == tostring(mapper.downloadedscript) then
		mapper.checkingupdates = false
		mapper.installMapperScript()

	-- Handle crowdmap changelog
	elseif filename == mapper.crowdchangelogfile then
		local f, s = io.open(filename)
		if f then
			s = f:read("*a")
			io.close(f)
		end

		-- make environment
		local env = {} -- add functions you know are safe here

		-- run code under environment [Lua 5.1]
		local function run(untrusted_code)
			if untrusted_code:byte(1) == 27 then
				return nil, "binary bytecode prohibited"
			end
			local untrusted_function, message = loadstring(untrusted_code)
			if not untrusted_function then
				return nil, message
			end
			setfenv(untrusted_function, env)
			return pcall(untrusted_function)
		end

		run(s)

		mapper.crowdchangelog = env.changelog

		echo("\n")
		mapper.echon("------------------[ Map Update ]------------------")
		mapper.echon(
			" The crowdmap map was updated from <orange>"
				.. (mapper.oldversion or "(none)")
				.. " <reset>-> <green>"
				.. tostring(mapper.newversion)
				.. "<reset>!"
		)
		mapper.echon(" Want to see the full changelog?")
		cechoLink(
			" <ForestGreen>Click here<reset>.",
			"mapper.showcrowdchangelog()",
			"View the full changelog for mappers",
			true
		)
		mapper.echon(
			" Latest changes were: <LightSkyBlue>"
				.. tostring(mapper.crowdchangelog and mapper.crowdchangelog[#mapper.crowdchangelog] or "?")
				.. ".\n"
		)
		echo("\n\n")

		mapper.downloadcrowdmap(mapper.newversion)

	-- Handle crowdmap map file
	elseif filename == mapper.crowdmapfile then
		mapper.echo("Map downloaded, loading it in...")

		local tmp = getRoomUserData(1, "gotoMapping")
		local oldmaptable = {}

		if tmp ~= "" then
			oldmaptable = yajl.to_value(tmp)
		end

		local ok = loadMap(filename)

		if ok then
			-- Willowdale-specific map post-processing can be added here

			if mapper.settings.lockspecials then
				mapper.lockSpecials()
			end

			mapper.echo("Map loaded fine - enjoy!")

			tmp = getRoomUserData(1, "gotoMapping")
			local newmaptable = {}

			if tmp ~= "" then
				newmaptable = yajl.to_value(tmp)
			end

			for k, v in pairs(oldmaptable) do
				newmaptable[k] = v
			end
			setRoomUserData(1, "gotoMapping", yajl.to_string(newmaptable))
			mapper.echo("Marks from the old map migrated successfully.")

			raiseEvent("mapper updated map")
		else
			mapper.echon("Map failed to load - you need to have the mapper open. Please open it, and then ")
			echoLink("click here", [[
        local tmp = getRoomUserData(1, "gotoMapping")
        local oldmaptable = {}
        if tmp ~= "" then
          oldmaptable = yajl.to_value(tmp)
        end

        local ok = loadMap(']] .. filename .. [[')
        if ok then
        -- Willowdale-specific map post-processing can be added here

        if mapper.settings.lockspecials then mapper.lockSpecials() end

        mapper.echo("Map loaded successfully!")

          tmp = getRoomUserData(1, "gotoMapping")
          local newmaptable = {}
          if tmp ~= "" then
            newmaptable = yajl.to_value(tmp)
          end
          for k,v in pairs(oldmaptable) do newmaptable[k] = v end
          setRoomUserData(1, "gotoMapping", yajl.to_string(newmaptable))
          mapper.echo("Marks from the old map migrated successfully.")
          raiseEvent("mapper updated map")
        else mapper.echo("Nope, didn't work. Open the map and try again?") end
      ]], "Click here to try loading the map again")
			echo(" to try loading it in again.\n")
		end
	end
end

--------------------------------------------------------------------------------
-- Error Handlers
--------------------------------------------------------------------------------

function mapper.seedownloaderrors(_, filename)
	-- Only show errors for releases.json check when in verbose mode
	if filename and filename:find("releases.json") then
		mapper.checkingupdates = false
		if mapper.updateCheckVerbose then
			mapper.echo("Could not check for updates (server unavailable).")
			mapper.updateCheckVerbose = false
		end
		return
	end
	-- Show errors for other downloads
	mapper.echo("Download failed: " .. tostring(filename))
end
