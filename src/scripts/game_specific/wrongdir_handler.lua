function mapper.gomudstopspeedwalkforwrongdir()
	if mapper.game and mapper.game ~= "gomud" then
		return
	end
	if #mapper.speedWalkPath > 0 then
		echo("Can't go \"" .. gmcp.Room.Wrongdir.dir .. '". Stopping speedwalk.')
		mapper.stop()
	end
end
