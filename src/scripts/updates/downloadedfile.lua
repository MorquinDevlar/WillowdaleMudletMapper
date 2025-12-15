function mapper.downloadedfile(_, filename)
	if not io.exists(filename) then
		return
	end

	-- workaround for https://bugs.launchpad.net/mudlet/+bug/1092769
	--  if mmp["downloaded_file_block_"..filename] then return end
	--  mmp["downloaded_file_block_"..filename] = tempTimer(5, [[mmp["downloaded_file_block_]]..filename..[["] = nil]])

	if filename == tostring(mapper.mapperfile) then -- mapper script version
		mapper.checkingupdates = false

		local f, s = io.open(filename)
		if f then
			s = f:read("*l"):trim()
			io.close(f)
		end

		if s ~= tostring(mapper.version) then
			mapper.newmapperversion = s
			mapper.retrievechangelog()
		end
	elseif filename == tostring(mapper.changelogfile) then -- changelog for the mapper script
		mapper.checkingupdates = false

		local f, s, changelog = io.open(filename)
		if f then
			changelog = f:read("*a")
			io.close(f)
		end

		echo("\n")
		mapper.echon("------------------[ Mapper Script Update ]------------------")
		mapper.echon(
			" The mapper script was updated from <orange>"
				.. tostring(mapper.version)
				.. "<reset> -> <green>"
				.. tostring(mapper.newmapperversion)
				.. "<reset>!"
		)
		mapper.echon("")
		cechoLink(
			" Would you like to install the update? <u><ForestGreen>Click here if so</u><reset>.",
			"mapper.downloadmapperscript()",
			"Changelog for the latest ("
				.. tostring(mapper.version)
				.. " -> "
				.. tostring(mapper.newmapperversion)
				.. ") update:\n"
				.. changelog,
			true
		)
		echo("\n\n")
	elseif filename == mapper.crowdchangelogfile then -- changelog for the crowdmap
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
	elseif filename == mapper.crowdmapfile then -- crowdmap map
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

			raiseEvent("mmapper updated map")
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
          raiseEvent("mmapper updated map")
        else mapper.echo("Nope, didn't work. Open the map and try again?") end
      ]], "Click here to try loading the map again")
			echo(" to try loading it in again.\n")
		end
	elseif filename == tostring(mapper.downloadedscript) then -- new mapper script xml downloaded
		mapper.checkingupdates = false
		mapper.installMapperScript()
	elseif filename == tostring(mapper.mapfile) then -- map version #, either IRE's or crowd
		mapper.checkingupdates = false

		local function needupdate(currentmd5, oldmd5)
			mapper.echon("The games map was ")
			echoLink(
				"updated",
				"",
				"New MD5: " .. tostring(currentmd5) .. ", previous MD5: " .. (oldmd5 or "(none)"),
				true
			)
			echo(
				" - you should update yours! Go to Settings -> Mapper tab and click on the 'Download' button there. Once you've updated, "
			)
			echoLink(
				"click here",
				"mapper.updatedmap('" .. currentmd5 .. "')",
				"Click here to quiet the update reminder"
			)
			echo(" to remove the reminder.")
		end

		local f, s = io.open(filename)
		if f then
			s = f:read("*a")
			io.close(f)
		end
		local currentmd5 = string.match(s, "([a-z0-9]+)  map%.xml")

		-- using crowdsourced map
		if not currentmd5 then
			currentmd5 = s:trim()
		end

		os.remove(filename)

		-- never checked yet?
		if not io.exists(getMudletHomeDir() .. "/map downloads/current") then
			needupdate(currentmd5)
			return
		end

		-- otherwise read old file and check
		local f, s = io.open(getMudletHomeDir() .. "/map downloads/current")
		if f then
			s = f:read("*a")
			io.close(f)
		end

		if s ~= currentmd5 then
			needupdate(currentmd5, s)
		end
	end
end
