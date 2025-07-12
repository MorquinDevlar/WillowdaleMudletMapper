-- Function to handle door updates whenever GMCP room info is received
function mmp.updatedoors()
	-- Only update doors if we have a valid current room
	if not mmp.currentroom or not mmp.roomexists(mmp.currentroom) then
		if mmp.settings.debug then
			mmp.echo("Door update skipped - no valid current room")
		end
		return
	end
	
	if mmp.settings.debug then
		mmp.echo("Checking doors for room " .. mmp.currentroom)
		-- Show current GMCP exit statuses
		local currentexits = gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.Exits or {}
		local exitInfo = {}
		for exit, exitData in pairs(currentexits) do
			if exitData.details and exitData.details.type == "door" then
				table.insert(exitInfo, string.format("%s:%s", exit, exitData.details.state or "none"))
			end
		end
		if #exitInfo > 0 then
			mmp.echo("GMCP door statuses: " .. table.concat(exitInfo, ", "))
		end
	end
	
	-- Update door statuses for the current room
	local updated = mmp.updateDoorStatuses(mmp.currentroom)
	
	-- Show a message if doors were updated (only in non-debug mode since debug already shows details)
	if updated and not mmp.settings.debug then
		mmp.echo("Door statuses updated for room " .. mmp.currentroom)
	end
end