function mapper.roomlook(input)
	-- we can do a report with a number

	local function handle_number(num)
		-- compile all available data
		if not mapper.roomexists(num) then
			mapper.echo(num .. " doesn't seem to exist.")
			return
		end
		local s, areanum = pcall(getRoomArea, num)
		if not s then
			mapper.echo(areanum)
			return
		end
		local exits = getRoomExits(num)
		local name = getRoomName(num)
		local islocked = roomLocked(num)
		local weight = (getRoomWeight(num) and getRoomWeight(num) or "?")
		-- getRoomWeight is buggy in one of the versions, is actually linked to setRoomWeight and thus returns nil
		local exitweights = (getExitWeights and getExitWeights(num) or {})
		local coords = { getRoomCoordinates(num) }
		local specexits = getSpecialExits(num)
		local env = getRoomEnv(num)
		local envname = (mapper.envidsr and mapper.envidsr[env]) or "?"
		-- generate a report
		mapper.echo(string.format("Room: %s #: %d area: %s (%d)", name, num, tostring(mapper.areatabler and mapper.areatabler[areanum] or "?"), areanum))
		mapper.echo(
			string.format(
				"Coordinates: x:%d, y:%d, z:%d, locked: %s, weight: %s",
				coords[1],
				coords[2],
				coords[3],
				(islocked and "yep" or "nope"),
				tostring(weight)
			)
		)
		mapper.echo(
			string.format(
				"Environment: %s (%d)%s",
				tostring(envname),
				env,
				(getRoomUserData(num, "indoors") ~= "" and ", indoors" or "")
			)
		)
		mapper.echo(string.format("Exits (%d):", table.size(exits)))
		for exit, leadsto in pairs(exits) do
			echo(
				string.format(
					"  %s -> %s (%d)%s%s\n",
					exit,
					getRoomName(leadsto),
					leadsto,
					(
						(getRoomArea(leadsto) or "?") == areanum and ""
						or " (in " .. (mapper.areatabler and mapper.areatabler[getRoomArea(leadsto)] or "?") .. ")"
					),
					(
						(not exitweights[mapper.anytoshort(exit)] or exitweights[mapper.anytoshort(exit)] == 0) and ""
						or " (weight: " .. exitweights[mapper.anytoshort(exit)] .. ")"
					)
				)
			)
		end
		-- display special exits if we got any
		if next(specexits) then
			mapper.echo(string.format("Special exits (%d):", table.size(specexits)))
			for leadsto, command in pairs(specexits) do
				if type(command) == "string" then
					echo(string.format("  %s -> %s (%d)\n", command, getRoomName(leadsto), leadsto))
				else
					-- new format - exit name, command
					for cmd, locked in pairs(command) do
						if locked == "1" then
							cecho(
								string.format(
									"<DarkSlateGrey>  %s -> %s (%d) (locked)\n",
									cmd,
									getRoomName(leadsto),
									leadsto
								)
							)
						else
							echo(string.format("  %s -> %s (%d)\n", cmd, getRoomName(leadsto), leadsto))
						end
					end
				end
			end
		end
		local message = "This room has the feature '%s'."
		for _, mapFeature in pairs(mapper.getRoomMapFeatures(num)) do
			mapper.echo(string.format(message, mapFeature))
		end
		-- actions we can do. This will be a short menu of sorts for actions
		mapper.echo("Stuff you can do:")
		echo("  ")
		echo("Clear all labels ")
		setUnderline(true)
		echoLink("(in area)", "mapper.clearLabels(" .. areanum .. ")", "", true)
		setUnderline(false)
		echo(" ")
		setUnderline(true)
		echoLink(
			"(whole map)",
			[[
    if not mapper.clearinglabels then
      mapper.echo("Are you sure you want to clear all of your labels on this map? If yes, click the link again.")
      mapper.clearinglabels = true
    else
      mapper.clearLabels("map")
      mapper.clearinglabels = nil
    end
    ]],
			"",
			true
		)
		setUnderline(false)
		echo("\n")
		echo("  ")
		setUnderline(true)
		echoLink("Check for mapper updates", 'mapper.echo("Checking...") mapper.checkupdateverbose()', "", true)
		setUnderline(false)
		echo("\n")
	end

	-- see if we can do anything with the name

	local function handle_name(name)
		local result = mapper.searchRoom(name)
		if type(result) == "string" then
			cecho("<grey>You have no recollection of any room with that name.")
			return
		end
		-- if we got one result, then act on it
		if table.size(result) == 1 then
			if type(next(result)) == "number" then
				handle_number(next(result))
			else
				handle_number(select(2, next(result)))
			end
			return
		end
		-- if not, then ask the user to clarify which one would they want
		mapper.echo("Which room specifically would you like to look up?")
		if not select(2, next(result)) or not tonumber(select(2, next(result))) then
			for roomid, roomname in pairs(result) do
				roomid = tonumber(roomid)
				cecho(string.format("  <LightSlateGray>%s<DarkSlateGrey> (", tostring(roomname)))
				cechoLink(
					"<" .. mapper.settings.echocolour .. ">" .. roomid,
					"mapper.roomlook(" .. roomid .. ")",
					string.format("View room details for %s (%s)", roomid, tostring(roomname)),
					true
				)
				cecho(
					string.format(
						"<DarkSlateGrey>) in the <LightSlateGray>%s<DarkSlateGrey>.\n",
						tostring(mapper.areatabler and mapper.areatabler[getRoomArea(roomid)] or "?")
					)
				)
			end
		else
			for roomname, roomid in pairs(result) do
				roomid = tonumber(roomid)
				cecho(string.format("  <LightSlateGray>%s<DarkSlateGrey> (", tostring(roomname)))
				cechoLink(
					"<" .. mapper.settings.echocolour .. ">" .. roomid,
					"mapper.roomlook(" .. roomid .. ")",
					string.format("View room details for %s (%s)", roomid, tostring(roomname)),
					true
				)
				cecho(
					string.format(
						"<DarkSlateGrey>) in the <LightSlateGray>%s<DarkSlateGrey>.\n",
						tostring(mapper.areatabler and mapper.areatabler[getRoomArea(roomid)] or "?")
					)
				)
			end
		end
	end

	if not input then
		if not mapper.roomexists(mapper.currentroom) then
			mapper.echo(mapper.currentroom .. " doesn't seem to be mapped yet.")
			mapper.echo("Stuff you can do:")
			echo("  ")
			echoLink("Check for mapper updates", 'mapper.echo("Checking...") mapper.checkupdateverbose()', "")
			echo("\n")
			mapper.echo(string.format("version %s.", tostring(mapper.version)))
			return
		else
			input = mapper.currentroom
		end
	end
	if tonumber(input) then
		handle_number(tonumber(input))
	else
		handle_name(input)
	end
	mapper.echo(string.format("version %s.", tostring(mapper.version)))
end
