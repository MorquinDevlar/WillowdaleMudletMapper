function mmp.centerRoominfo()
  -- Center the map view when room info is available
  if gmcp.Room.Info then centerview(gmcp.Room.Info.num) end
end