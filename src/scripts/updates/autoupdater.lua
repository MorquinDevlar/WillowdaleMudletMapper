-- Auto-updater for mapper script
-- Checks for new versions and allows one-click updates

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
	-- Silent by default - only show messages if an update is available
	mapper.updateCheckVerbose = false
	mapper.checkforupdatetimer = tempTimer(math.random(3, 10), function()
		mapper.checkforupdate()
	end)
end

-- Silent update check (for periodic timer)
function mapper.checkupdatesilent()
	mapper.updateCheckVerbose = false
	mapper.checkforupdate()
end

-- Verbose update check (manual trigger)
function mapper.checkupdateverbose()
	mapper.updateCheckVerbose = true
	mapper.checkforupdate()
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
		mapper.notify("Your version of Mudlet doesn't support downloading files - please upgrade to 2.0+")
		return
	end

	-- Ensure download folder exists
	if not lfs.attributes(downloadfolder) then
		if lfs and lfs.mkdir then
			local t, s = lfs.mkdir(downloadfolder)
			if not t and s ~= "File exists" then
				mapper.notify("Couldn't make the '" .. downloadfolder .. "' folder; " .. s)
				return
			end
		else
			mapper.notify(
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
	downloadFile(mapper.releasesfile, "https://updates.willowdalemud.com/static/resources/mapper/releases.json")
end

-- Download the latest mapper package
function mapper.downloadmapperscript()
	local file = getModulePath("WillowdaleMudletMapper") or
		getMudletHomeDir() .. "/map downloads/WillowdaleMudletMapper.mpackage"
	if io.exists(file) then
		local s, m = os.remove(file)
		if not s then
			mapper.echo(string.format(
				"Couldn't delete the old package (located at %s), because of: %s. This might be a problem.", file, m))
		end
	end
	mapper.downloadedscript = file
	downloadFile(
		mapper.downloadedscript,
		"https://updates.willowdalemud.com/static/resources/mapper/WillowdaleMudletMapper.mpackage"
	)
	mapper.echo("Downloading mapper update...")
end

-- Install the downloaded mapper package
function mapper.installMapperScript()
	-- Write the settings out before the package goes away, so an update keeps
	-- whatever the player changed this session
	if mapper.saveoptions then
		mapper.saveoptions()
	end
	local path = getModulePath("WillowdaleMudletMapper")
	if not path then
		-- Set flag so handleUninstall knows this is an update, not a real uninstall
		mapper.isUpdating = true
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
			mapper.notify("Failed to parse releases.json")
			return
		end

		local latest = releases[1]
		if not latest or not latest.version then
			mapper.notify("Invalid releases.json format")
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

		-- Every release the player has not got yet, newest first and each under
		-- its own heading: an update that skips versions still says what changed
		-- in the ones it skipped, instead of running their notes together into one
		-- list that looks like a single release.
		local block = {
			"Update available: <orange>"
			.. tostring(mapper.version)
			.. "<reset> -> <green>"
			.. tostring(latest.version)
			.. "<reset>",
		}
		for _, release in ipairs(releases) do
			if release.version and mapper.compare_versions(release.version, mapper.version) then
				block[#block + 1] = ""
				block[#block + 1] = "<white>"
					.. release.version
					.. (release.released and (" <reset><dim_grey>- " .. release.released) or "")
					.. "<reset>"
				for _, change in ipairs(release.changes or {}) do
					block[#block + 1] = "  - " .. change
				end
			end
		end
		block[#block + 1] = ""
		mapper.notify(block)

		mapper.notifyIndent()
		cechoLink(
			"<ForestGreen>[Click here to install update]<reset>",
			"mapper.downloadmapperscript()",
			"Download and install version " .. latest.version,
			true
		)
		echo(" or type ")
		cecho("<yellow>mapper update<reset>")
		echo("\n")
		mapper.updateCheckVerbose = false

		-- Handle downloaded mapper package
	elseif filename == tostring(mapper.downloadedscript) then
		mapper.checkingupdates = false
		mapper.installMapperScript()
	end
end

--------------------------------------------------------------------------------
-- Error Handlers
--------------------------------------------------------------------------------

function mapper.seedownloaderrors(_, filename, errorMessage)
	-- Only handle mapper-related downloads, ignore everything else
	if not filename then return end

	-- Handle releases.json check errors - silent unless verbose
	if filename == mapper.releasesfile or (filename:find("releases%.json") and mapper.checkingupdates) then
		mapper.checkingupdates = false
		if mapper.updateCheckVerbose then
			mapper.echo("Could not check for updates (server unavailable).")
			mapper.updateCheckVerbose = false
		end
		return
	end

	-- Handle mapper package download errors
	if filename == mapper.downloadedscript then
		mapper.notify("Failed to download the update: " .. tostring(errorMessage or "Unknown error"))
		return
	end

	-- Handle generic_mapper restore errors
	if filename == _generic_mapper_restore_path then
		cecho("\n<yellow>[Mapper]<reset> Failed to restore generic_mapper: " ..
			tostring(errorMessage or "Unknown error") .. "\n")
		return
	end

	-- Ignore all other download errors (not our business)
end
