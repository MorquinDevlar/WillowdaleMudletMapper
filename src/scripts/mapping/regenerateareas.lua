function mapper.regenerateareas()
	-- cached data
	mapper.areatable = getAreaTable() -- this translates an area name to an ID
	mapper.areatabler = {} -- this translates an ID to an area name
	-- The same names in lower case, for the game naming an area in a
	-- different case from the one it was created with
	mapper.areatablelower = {}

	for name, id in pairs(mapper.areatable) do
		mapper.areatabler[tonumber(id)] = name
		mapper.areatablelower[name:lower()] = id
	end

	mapper.clearpathcache()
end
