local where = matches[2]

if not where then
	centerview(mmp.currentroom)
elseif tonumber(where) then -- view a room ID
	centerview(where)
else -- view an area
	mmp.viewArea(where)
end
