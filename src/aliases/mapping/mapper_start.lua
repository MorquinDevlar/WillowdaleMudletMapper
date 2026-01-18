if mapper.editing then
	mapper.echo("Mapping is already enabled.")
	return
end

mapper.editing = true
mapper.regenerateareas()
mapper.echo("Mapping enabled. New rooms will be created as you explore.")
