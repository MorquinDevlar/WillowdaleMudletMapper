-- Generic mapper package management
-- Handles automatic uninstall/reinstall of generic_mapper package

mapper = mapper or {}

-- Check if generic_mapper is installed and uninstall it to avoid conflicts
-- Called during package initialization
function mapper.checkGenericMapper()
	local packages = getPackages()
	if packages and table.contains(packages, "generic_mapper") then
		uninstallPackage("generic_mapper")
		mapper.notify("Detected generic_mapper package. Uninstalling to avoid conflicts with WillowdaleMudletMapper.")
	end
end

-- Handle package uninstall - reinstall generic_mapper if this package is being removed
-- Called by sysUninstallPackage event
function mapper.handleUninstall(_, packageName)
	if not (packageName:find("WillowdaleMudletMapper") or packageName:find("MudletMapper")) then
		return
	end

	-- Save before the scripts go, whether this is an update or a real uninstall
	if mapper.saveoptions then
		mapper.saveoptions()
	end

	-- Skip restoring generic_mapper in a development profile. A local muddler
	-- build uninstalls and reinstalls this package on every rebuild, so the
	-- restore would download generic_mapper and race the reinstall each time.
	-- Muddler is the local CI helper's own global, so its presence identifies a
	-- dev profile without any setup; _willowdale_mapper_devmode is the explicit
	-- opt-out for a profile that builds some other way. Both are plain globals
	-- rather than mapper.* fields so they survive the uninstall.
	if _willowdale_mapper_devmode or Muddler then
		return
	end

	-- Skip restoring generic_mapper if this is an update (not a real uninstall)
	if mapper.isUpdating then
		mapper.isUpdating = nil
		return
	end

	mapper.notify("WillowdaleMudletMapper uninstalled. Reinstalling generic_mapper...")

	-- Use global variables so they survive package uninstall
	local downloadfolder = getMudletHomeDir() .. "/map downloads/"
	_generic_mapper_restore_path = downloadfolder .. "generic_mapper.mpackage"

	-- Register anonymous handler that survives package uninstall
	_generic_mapper_download_handler = registerAnonymousEventHandler("sysDownloadDone", function(_, filename)
		if filename == _generic_mapper_restore_path then
			installPackage(filename)
			cecho("\n<green>[Mapper]<reset> Generic mapper has been restored.\n")
			-- Clean up
			if _generic_mapper_download_handler then
				killAnonymousEventHandler(_generic_mapper_download_handler)
			end
			_generic_mapper_restore_path = nil
			_generic_mapper_download_handler = nil
		end
	end)

	downloadFile(
		_generic_mapper_restore_path,
		"https://github.com/Mudlet/mudlet-package-repository/raw/refs/heads/main/packages/generic_mapper.mpackage"
	)
end
