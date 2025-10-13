-- matches[1] is the full command
-- matches[2] is the option name (if provided)
-- matches[3] is the value (if provided)

-- Check if game is detected
if not mmp.game then
	mmp.echo("Game not detected. Please reconnect to your MUD so the mapper can identify which game you're playing.")
	mmp.echo("The mapper uses gmcp.Game.Info.name to identify the specific game.")
	return
end

if not matches[2] then
	-- Show all options with the new display format
	mmp.settings:showAllOptions(mmp.game)
	return
end

local option = matches[2]
local val = matches[3]

-- If only option name is provided (no value), show description
if option and (not val or val == "") then
	-- Use the new getOptionDef method to get the option definition
	local optionDef = mmp.settings:getOptionDef(option)
	
	if optionDef then
		-- Use mapper color scheme: light green for labels, white for values
		echo("\n")
		decho("<112,229,0>" .. option .. ":<255,255,255> " .. (optionDef.use or "No description available") .. "\n")
		-- Show current value
		local currentValue = mmp.settings[option]
		if type(currentValue) == "boolean" then
			currentValue = currentValue and "on" or "off"
		end
		decho("<112,229,0>Current value: <255,255,255>" .. tostring(currentValue) .. "\n")
		
		-- Show accepted values
		if optionDef.allowedVarTypes and table.contains(optionDef.allowedVarTypes, "boolean") then
			decho("<112,229,0>Accepted values: <128,128,128>on, off\n")
		elseif option == "echocolour" then
			decho("<112,229,0>Accepted values: <128,128,128>Any valid color name (see 'mcolor' for options)\n")
		elseif option == "walkdelay" then
			decho("<112,229,0>Accepted values: <128,128,128>0-5 (0=instant, 0.3=normal, 1+=slow)\n")
		end
	else
		mmp.echo("Unknown option: " .. option)
	end
	return
end

-- Convert values
if val == "true" or val == "yes" or val == "on" then
	val = true
end
if val == "false" or val == "no" or val == "off" then
	val = false
end
local numberVal = tonumber(val)
val = numberVal and numberVal or val
mmp.settings:setOption(option, val)
