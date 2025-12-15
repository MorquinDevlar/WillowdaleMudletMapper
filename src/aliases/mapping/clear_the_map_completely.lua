if not mapper.map_delete_warning then
	mapper.echo(
		"Are you really, really, really sure you want to delete all of the map to go to a blank state? Do the command again if you're certain."
	)
	mapper.map_delete_warning = true
	return
end

mapper.echo("Okay, deleting...")

tempTimer(0.1, function()
	for name, id in pairs(getAreaTable()) do
		deleteArea(tonumber(id))
	end

	mapper.echo("Deleted everything. It's all gone.")
	mapper.map_delete_warning = nil
	centerview(1)
end)
