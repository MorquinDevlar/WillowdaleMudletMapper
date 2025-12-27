function mapper.seedownloaderrors(_, filename)
	-- Only show errors for releases.json check when in verbose mode
	if filename and filename:find("releases.json") then
		mapper.checkingupdates = false
		if mapper.updateCheckVerbose then
			mapper.echo("Could not check for updates (server unavailable).")
			mapper.updateCheckVerbose = false
		end
		return
	end
	-- Show errors for other downloads
	mapper.echo("Download failed: " .. tostring(filename))
end
