if not mmp.deletingarea then
	mmp.echo("I wasn't deleting any areas already.")
	return
end

local areaname = mmp.deletingarea.areaname
mmp.deletingarea = nil

mmp.echo(
	"Stopped deleting rooms in the '"
		.. areaname
		.. "'. The area is partially missing its rooms now, you'll want to restart the process to finish it."
)
