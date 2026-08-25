function mapper.saveoptions()
	-- Nothing to write before the settings table exists, and at exit the mapper
	-- can be half torn down by an uninstall
	if not mapper.settings or type(mapper.settings.getAllOptions) ~= "function" then
		return
	end
	local saveTable = {
		locked_areas = mapper.locked or {},
		options = mapper.settings:getAllOptions(),
	}
	local _sep
	if string.char(getMudletHomeDir():byte()) == "/" then
		_sep = "/"
	else
		_sep = "\\"
	end
	local saveFile = getMudletHomeDir() .. _sep .. "mapper.options.lua"

	table.save(saveFile, saveTable)
end
