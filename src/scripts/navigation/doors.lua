-- Function to handle door updates whenever GMCP room info is received
function mapper.updatedoors()
	-- Only update doors if we have a valid current room
	if not mapper.currentroom or not mapper.roomexists(mapper.currentroom) then
		if mapper.settings.debug then
			mapper.echo("Door update skipped - no valid current room")
		end
		return
	end
	
	if mapper.settings.debug then
		mapper.echo("Checking doors for room " .. mapper.currentroom)
		-- Show current GMCP exit statuses
		local currentexits = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Exits or {}
		local exitInfo = {}
		for exit, exitData in pairs(currentexits) do
			if exitData.details and exitData.details.type == "door" then
				table.insert(exitInfo, string.format("%s:%s", exit, exitData.details.state or "none"))
			end
		end
		if #exitInfo > 0 then
			mapper.echo("GMCP door statuses: " .. table.concat(exitInfo, ", "))
		end
	end
	
	-- Update door statuses for the current room
	local updated = mapper.updateDoorStatuses(mapper.currentroom)
	
	-- Show a message if doors were updated (only in non-debug mode since debug already shows details)
	if updated and not mapper.settings.debug then
		mapper.echo("Door statuses updated for room " .. mapper.currentroom)
	end
end