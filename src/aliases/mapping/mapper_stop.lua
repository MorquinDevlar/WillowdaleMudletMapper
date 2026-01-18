if not mapper.editing then
	mapper.echo("Mapping is already disabled.")
	return
end

mapper.editing = false
mapper.echo("Mapping disabled. No new rooms will be created.")
