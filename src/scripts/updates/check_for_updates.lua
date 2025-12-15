local downloadfolder = getMudletHomeDir() .. "/map downloads/"

-- this should get called at start and every hour after that

function mapper.checkforupdate()
	if not mapper.game or mapper.checkingupdates or mapper.game == "gomud" then
		return
	end
	local game = mapper.game
	mapper.mapfile = downloadfolder .. "MD5"
	mapper.mapperfile = downloadfolder .. "mapper"
	if not downloadFile then
		mapper.echo("Your version of Mudlet doesn't support downloading files - please upgrade to 2.0+")
	else
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
		if mapper.settings.updatemap then
			-- Willowdale map update support can be added here in the future
		end
		mapper.checkingupdates = true
	end
end

-- called by the user when the map is updated to register the fact that it was

function mapper.updatedmap(currentmd5)
	assert(currentmd5, "need md5 sum to write to file")
	local f, err = io.open(downloadfolder .. "current", "w")
	if not f then
		return mapper.echo("Couldn't write to the update file, because: " .. err)
	end
	f:write(currentmd5)
	f:close()
	local t = { "Go you for updating!", "Thanks for updating the map!", "Alright, map updated!" }
	mapper.echo(t[math.random(1, #t)])
end

-- downloads the latest changelog for the mapper if it was updated

function mapper.retrievechangelog()
	mapper.changelogfile = downloadfolder .. "changelog"
	downloadFile(mapper.changelogfile, "https://www.willowdalemud.com/static/resources/changelog")
end

-- Map download functions

function mapper.downloadmapperscript()
	local file = getModulePath("WillowdaleMudletMapper") or getMudletHomeDir() .. "/map downloads/WillowdaleMudletMapper.mpackage"
	if io.exists(file) then
		local s, m = os.remove(file)
		if not s then
			mapper.echo("Couldn't delete the old package (located at %s), because of: %s. This might be a problem.", file, m)
		end
	end
	mapper.downloadedscript = file
	downloadFile(
		mapper.downloadedscript,
		"https://www.willowdalemud.com/static/resources/WillowdaleMudletMapper.mpackage"
	)
	mapper.echo("Okay, downloading the mapper script...")
end


function mapper.installMapperScript()
	local path = getModulePath("WillowdaleMudletMapper")
	if not path then
		uninstallPackage("WillowdaleMudletMapper")
		tempTimer(1, [[installPackage(mapper.downloadedscript)]])
	else
		reloadModule("WillowdaleMudletMapper")
	end
end
