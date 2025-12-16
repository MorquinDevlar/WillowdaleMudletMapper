function mapper.checkupdatestart(...)
	if mapper.checkforupdatetimer then
		killTimer(mapper.checkforupdatetimer)
	end
	-- Check for mapper script updates after a short random delay
	mapper.checkforupdatetimer = tempTimer(math.random(3, 10), mapper.checkforupdate)
end

function mapper.changeUpdateMap()
	if mapper.settings.updatemap then
		mapper.echo("Will check for new map updates from your MUD.")
		enableTimer("Check for updates periodically")
	--mapper.checkUpdateStart()
	else
		mapper.echo("Won't check for new map updates from your MUD.")
		disableTimer("Check for updates periodically")
		if mapper.checkforupdatetimer then
			killTimer("mapper.checkforupdatetimer")
		end
	end
end
