local function s(loc)
	if string.ends(loc, ".json") and not loadJsonMap then
		mapper.echo("Your Mudlet can't load maps in JSON, please upgrade first.")
		return
	end

	local allok = true
	if string.ends(loc, ".json") then
		allok = loadJsonMap(loc)
	else
		allok = loadMap(loc)
	end

	if not allok then
		mapper.echo("Couldn't load the map :(")
	else
		if loc ~= "" then
			mapper.echo("Map loaded.")
		else
			mapper.echo("Loaded the default map.")
		end
		mapper.mapdata_changed()
	end
end

if matches[2] and matches[2] == "custom" then
	s(invokeFileDialog(true, "Please select the map file and click Open to load it"))
elseif matches[2] then
	s(getMudletHomeDir() .. "/map/" .. matches[2])
else
	s("")
end
