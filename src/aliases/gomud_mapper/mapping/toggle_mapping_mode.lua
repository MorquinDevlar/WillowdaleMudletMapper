if (matches[2] and matches[2] == "on") or (not matches[2] and not mmp.editing) then
	mmp.editing = true
	enableAlias("mm Mapping")

	mmp.regenerateareas()
	mmp.highlight_unfinished_rooms()

	mmp.echo("Mapping mode enabled. Happy mapping!")
elseif (matches[2] and matches[2] == "off") or (not matches[2] and mmp.editing) then
	mmp.editing = false
	disableAlias("mm Mapping")
	mmp.echo("Mapping mode disabled.")
end
