function mmp.centerroominfo()
	-- Center the map view when room info is available
	if gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Basic then
		centerview(gmcp.Room.Info.Basic.id)
	end
end
