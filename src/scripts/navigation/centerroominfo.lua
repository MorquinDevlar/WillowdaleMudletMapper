function mapper.centerroominfo()
	-- Center the map view when room info is available
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then
		local roomId = tonumber(gmcp.Room.Info.Basic.id)
		if roomId then
			centerview(roomId)
		end
	end
end
