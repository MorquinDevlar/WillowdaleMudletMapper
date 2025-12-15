local where = matches[2]

if not where then
	centerview(mapper.currentroom)
elseif tonumber(where) then -- view a room ID
	centerview(where)
else -- view an area
	mapper.viewArea(where)
end
