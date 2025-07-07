-- functions internal to the mapper

-- Deep copy function to create a complete copy of a table
function mmp.deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[mmp.deepcopy(orig_key)] = mmp.deepcopy(orig_value)
		end
		setmetatable(copy, mmp.deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function mmp.highlight_unfinished_rooms()
	if not mmp.areatable then
		return
	end
	for a, b in pairs(mmp.areatable) do
		local roomList = getAreaRooms(b) or {}
		for c, d in pairs(roomList) do
			if getRoomName(d) == "" then
				local fgr, fgg, fgb = unpack(color_table.red)
				local bgr, bgg, bgb = unpack(color_table.blue)
				highlightRoom(d, fgr, fgg, fgb, bgr, bgg, bgb, 1, 100, 100)
			end
		end
	end
end

-- GoMud-specific utility functions can be added here
