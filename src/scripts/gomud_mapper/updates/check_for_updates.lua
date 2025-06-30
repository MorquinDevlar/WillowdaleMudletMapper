local downloadfolder = getMudletHomeDir() .. "/map downloads/"

-- this should get called at start and every hour after that

function mmp.checkforupdate()
	if not mmp.game or mmp.checkingupdates or mmp.game == "gomud" then
		return
	end
	local game = mmp.game
	mmp.mapfile = downloadfolder .. "MD5"
	mmp.mapperfile = downloadfolder .. "mapper"
	if not downloadFile then
		mmp.echo("Your version of Mudlet doesn't support downloading files - please upgrade to 2.0+")
	else
		if not lfs.attributes(downloadfolder) then
			if lfs and lfs.mkdir then
				local t, s = lfs.mkdir(downloadfolder)
				if not t and s ~= "File exists" then
					mmp.echo("Couldn't make the '" .. downloadfolder .. "' folder; " .. s)
					return
				end
			else
				mmp.echo(
					"Sorry, but you need LuaFileSystem (lfs) installed, or have the '"
						.. downloadfolder
						.. "' folder exist."
				)
				return
			end
		end
		if mmp.settings.crowdmap then
		-- GoMud crowdmap support can be added here in the future
		elseif mmp.settings.updatemap then
			-- GoMud map update support can be added here in the future
		end
		mmp.checkingupdates = true
	end
end

-- called by the user when the map is updated to register the fact that it was

function mmp.updatedmap(currentmd5)
	assert(currentmd5, "need md5 sum to write to file")
	local f, err = io.open(downloadfolder .. "current", "w")
	if not f then
		return mmp.echo("Couldn't write to the update file, because: " .. err)
	end
	f:write(currentmd5)
	f:close()
	local t = { "Go you for updating!", "Thanks for updating the map!", "Alright, map updated!" }
	mmp.echo(t[math.random(1, #t)])
end

-- downloads the latest changelog for the mapper if it was updated

function mmp.retrievechangelog()
	mmp.changelogfile = downloadfolder .. "changelog"
	downloadFile(mmp.changelogfile, "http://ire-mudlet-mapping.github.io/ire-mapping-script/downloads/changelog")
end

function mmp.retrievecrowdchangelog()
	mmp.crowdchangelogfile = downloadfolder .. "crowdchangelogfile"
	-- GoMud-specific crowdmap changelog download can be added here
end

-- downloads the public crowdsources map!

function mmp.downloadmapperscript()
	local file = getModulePath("mudlet-mapper") or getMudletHomeDir() .. "/map downloads/mudlet-mapper.xml"
	if io.exists(file) then
		local s, m = os.remove(file)
		if not s then
			mmp.echo("Couldn't delete the old xml (located at %s), because of: %s. This might be a problem.", file, m)
		end
	end
	mmp.downloadedscript = file
	downloadFile(
		mmp.downloadedscript,
		"http://ire-mudlet-mapping.github.io/ire-mapping-script/downloads/mudlet-mapper.xml"
	)
	mmp.echo("Okay, downloading the mapper script...")
end

function mmp.downloadcrowdmap(newversion)
	mmp.crowdmapfile = downloadfolder .. "crowdmap"
	local f, err = io.open(downloadfolder .. "current", "w")
	if not f then
		return mmp.echo("Couldn't write to the update file, because: " .. err)
	end
	f:write(newversion)
	f:close()
	-- GoMud-specific crowdmap download can be added here
	mmp.echo("Downloading the latest crowdmap...")
end

function mmp.showcrowdchangelog()
	mmp.echo("Public map changelog:")
	if not mmp.crowdchangelog then
		mmp.echo("(none yet)")
		return
	end
	for k, v in ipairs(mmp.crowdchangelog) do
		cecho(string.format("  %s) %s\n", k, v:gsub("\t", "     ")))
	end
end

function mmp.installMapperScript()
	local path = getModulePath("mudlet-mapper")
	if not path then
		uninstallPackage("mudlet-mapper")
		tempTimer(1, [[installPackage(mmp.downloadedscript)]])
	else
		reloadModule("mudlet-mapper")
	end
end
