-- to be enabled by functions that need it and disabled after it's done. Sort of like a cheap prompttrigger from Svo.
mapper.firstAlert = false
-- handle alertness
if mapper.alertness and next(mapper.alertness) then
	local dirs = {}
	for direction, _ in pairs(mapper.alertness) do
		dirs[#dirs + 1] = direction
	end
	local people = select(2, next(mapper.alertness)) or {}

	moveCursor(0, getLineNumber())

	if ndb then
		local getcolor = ndb.getcolor
		for i = 1, #people do
			people[i] = getcolor(people[i]) .. people[i]
		end
	end

	cinsertText(
		"<red>[<cyan>"
			.. table.concat(dirs, ", ")
			.. " <red>-"
			.. (#dirs > 1 and "\n  " or "")
			.. " <white>"
			.. ((svo and svo.concatand) and svo.concatand(people) or table.concat(people, ", "))
			.. "<cyan> ("
			.. #people
			.. ")<red>]\n"
	)

	moveCursorEnd()

	mapper.alertness = nil

	raiseEvent("mapper updated pdb")
end

-- reset names we last seen, so scripts can be efficient
-- not finished yet
--if next(mapper.pdb_lastupdate) then
--  mapper.pdb_lastupdate = {}
--end

disableTrigger("Mudlet Mapper prompt trigger")
