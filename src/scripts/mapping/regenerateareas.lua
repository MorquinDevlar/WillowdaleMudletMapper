function mapper.regenerateareas()
	-- cached data
	mapper.areatable = getAreaTable() -- this translates an area name to an ID
	mapper.areatabler = {} -- this translates an ID to an area name

	local t = getAreaTable()
	for k, v in pairs(t) do
		mapper.areatabler[tonumber(v)] = k
	end

	mapper.clearpathcache()
end
