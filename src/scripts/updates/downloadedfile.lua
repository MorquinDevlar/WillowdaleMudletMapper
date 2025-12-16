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

		-- Compare versions
		if latest.version ~= tostring(mapper.version) then
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
		end

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
