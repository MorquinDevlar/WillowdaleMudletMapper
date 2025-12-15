if (matches[2] and matches[2] == "on") or (not matches[2] and not mapper.editing) then
	mapper.editing = true
	enableAlias("mm Mapping")

	mapper.regenerateareas()
	mapper.highlight_unfinished_rooms()

	mapper.echo("Mapping mode enabled. Happy mapping!")
elseif (matches[2] and matches[2] == "off") or (not matches[2] and mapper.editing) then
	mapper.editing = false
	disableAlias("mm Mapping")
	mapper.echo("Mapping mode disabled.")
end
