-- aggregates map load and such events into one
function mapper.mapdata_changed()
	raiseEvent("mmapper map reloaded")
end
