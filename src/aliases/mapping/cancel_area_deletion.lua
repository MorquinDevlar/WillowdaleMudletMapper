if not mapper.deletingarea then
	mapper.echo("I wasn't deleting any areas already.")
	return
end

local areaname = mapper.deletingarea.areaname
mapper.deletingarea = nil

mapper.echo(
	"Stopped deleting rooms in the '"
		.. areaname
		.. "'. The area is partially missing its rooms now, you'll want to restart the process to finish it."
)
