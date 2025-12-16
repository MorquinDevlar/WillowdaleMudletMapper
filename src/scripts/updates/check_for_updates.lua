local downloadfolder = getMudletHomeDir() .. "/map downloads/"

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
	downloadFile(mapper.releasesfile, "https://www.willowdalemud.com/resources/mapper/releases.json")
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
		"https://www.willowdalemud.com/resources/mapper/WillowdaleMudletMapper.mpackage"
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
