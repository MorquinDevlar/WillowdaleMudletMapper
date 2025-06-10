-- functions internal to the mapper

function mmp.highlight_unfinished_rooms()
	if not mmp.areatable then return end
	for a,b in pairs (mmp.areatable) do
		local roomList = getAreaRooms(b) or {}
		for c,d in pairs (roomList) do
			if (getRoomName(d) == "") then
				local fgr,fgg,fgb = unpack(color_table.red)
				local bgr,bgg,bgb = unpack(color_table.blue)
				highlightRoom(d, fgr,fgg,fgb,bgr,bgg,bgb, 1, 100, 100)
			end
		end
	end
end

-- GoMud-specific utility functions can be added here