-- Show syntax help if no argument provided
if not matches[2] or matches[2] == "" then
	mapper.echo("Usage: mapper goto <destination>")
	mapper.echo("")
	mapper.echo("  mapper goto <room ID>       - Go to a specific room by ID")
	mapper.echo("  mapper goto <area name>     - Go to a random room in an area")
	mapper.echo("  mapper goto <area name> N   - Go to room N in an area")
	mapper.echo("  mapper goto feature <name>  - Go to a named feature")
	return
end

local where = matches[2]:lower()

if mapper.settings.debug then
	mapper.gotoPerf = mapper.gotoPerf or createStopWatch()
	startStopWatch(mapper.gotoPerf)
end
-- goto room ID
if tonumber(where) then
	mapper.gotoRoom(where)
else
	-- goto area or feature
	local split = where:split(" ")
	if split[1] == "feature" then
		table.remove(split, 1)
		mapper.gotoFeature(table.concat(split, " "))
	else
		if tonumber(split[#split]) then
			mapper.gotoArea(where:sub(1, -#split[#split] - 2), tonumber(split[#split]))
		else
			mapper.gotoArea(where)
		end
	end
end
if mapper.settings.debug then
	mapper.echo("goto alias took " .. stopStopWatch(mapper.gotoPerf) .. "s to run.")
end
