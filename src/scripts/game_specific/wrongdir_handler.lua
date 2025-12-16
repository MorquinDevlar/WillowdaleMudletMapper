function mapper.wrongdir_handler()
	if #mapper.speedWalkPath > 0 then
		echo("Can't go \"" .. gmcp.Room.Wrongdir.dir .. '". Stopping speedwalk.')
		mapper.stop()
	end
end
