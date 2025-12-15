local where = matches[2]:lower()
local gallop
if command:ends("gallop") then
	gallop = "gallop"
	where = where:sub(1, -8)
elseif command:ends("sprint") then
	gallop = "sprint"
	where = where:sub(1, -8)
elseif command:ends("dash") then
	gallop = "dash"
	where = where:sub(1, -6)
elseif command:ends("runaway") then
	gallop = "runaway"
	where = where:sub(1, -9)
elseif command:ends("glide") then
	gallop = "glide"
	where = where:sub(1, -7)
end
if mapper.debug then
	mapper.gotoPerf = mapper.gotoPerf or createStopWatch()
	startStopWatch(mapper.gotoPerf)
end
-- goto room ID
if tonumber(where) then
	mapper.gotoRoom(where, gallop)
else
	-- goto area or feature
	local split = where:split(" ")
	if split[1] == "feature" then
		table.remove(split, 1)
		mapper.gotoFeature(table.concat(split, " "), gallop)
	else
		if tonumber(split[#split]) then
			mapper.gotoArea(where:sub(1, -#split[#split] - 2), tonumber(split[#split]), gallop)
		else
			mapper.gotoArea(where, nil, gallop)
		end
	end
end
if mapper.debug then
	mapper.echo("goto alias took " .. stopStopWatch(mapper.gotoPerf) .. "s to run.")
end
