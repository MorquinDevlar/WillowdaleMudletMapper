local tmp = getRoomUserData(1, "gotoMapping")
if tmp ~= "" then
	local maptable = yajl.to_value(tmp)
	if not maptable[matches[2]] then
		mapper.echo("Don't have such a mark in the db.")
		return
	end

	maptable[matches[2]] = nil
	local tmp2 = yajl.to_string(maptable)
	setRoomUserData(1, "gotoMapping", tmp2)
	mapper.echo("Removed the " .. matches[2] .. " mark.")
else
	mapper.echo("We don't have any marks stored anyway.")
end
