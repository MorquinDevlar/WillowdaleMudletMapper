function mmp.loadoptions()
	-- Ensure mmp is properly initialized before loading options
	if not mmp then
		return
	end
	
	-- If settings don't exist yet, we need to initialize them
	if not mmp.settings then
		-- Force initialization by setting firstRun to true
		local oldFirstRun = mmp.firstRun
		mmp.firstRun = true
		
		if mmp.startup then
			mmp.startup()
		end
		
		-- If settings still don't exist, return
		if not mmp.settings then
			return
		end
		
		-- Restore firstRun if it was false
		if oldFirstRun == false then
			mmp.firstRun = false
		end
	end
	
	local loadTable = mmp.loadlocks()

	if loadTable.options then
		for k, v in pairs(loadTable.options) do
			-- Check if the option exists before trying to set it
			-- This prevents errors when loading old option files with removed options
			if mmp.settings[k] ~= nil then
				mmp.settings:setOption(k, v, true)
			end
		end
	end
end

function mmp.loadlocks()
	local loadTable = {}
	local _sep
	if string.char(getMudletHomeDir():byte()) == "/" then
		_sep = "/"
	else
		_sep = "\\"
	end
	local loadFile = getMudletHomeDir() .. _sep .. "mapper.options.lua"

	if io.exists(loadFile) then
		table.load(loadFile, loadTable)
	end

	if loadTable.locked_areas then
		mmp.locked = loadTable.locked_areas
	end

	local lockRoom, getAreaRooms = lockRoom, getAreaRooms
	for area in pairs(mmp.locked) do
		local rooms = getAreaRooms(area)
		for _, roomid in pairs(rooms or {}) do
			lockRoom(roomid, true)
		end
	end

	return loadTable
end
