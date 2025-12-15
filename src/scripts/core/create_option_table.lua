-------------------------------------------------
--         Put your Lua functions here.        --
--                                             --
-- Note that you can also use external Scripts --
-------------------------------------------------
local spairs = spairs
	or function(tbl, order)
		local keys = table.keys(tbl)
		if order then
			table.sort(keys, function(a, b)
				return order(tbl, a, b)
			end)
		else
			table.sort(keys)
		end

		local i = 0
		return function()
			i = i + 1
			if keys[i] then
				return keys[i], tbl[keys[i]]
			end
		end
	end

function mmp.createOption(startingValue, onChangeFunc, allowedVarTypes, use, checkOption, games)
	if allowedVarTypes then -- make sure our starting Value follows type rules
		if not table.contains(allowedVarTypes, type(startingValue)) then
			echo("Starting type is not of allowed type!\n")
			display(allowedVarTypes)
			echo("type: " .. type(startingValue) .. "\n")
			return
		end
	end

	local option = {
		value = startingValue,
		onChange = onChangeFunc,
		allowedVarTypes = allowedVarTypes,
		use = use or "",
		games = games,
		checkOption = checkOption or function()
			return true
		end,
	}

	return option
end

function mmp.createOptionsTable(defaultTable)
	local index = {} -- index to store the default table at in our proxy table

	local proxyTable = {} -- This is the table that is returned to the user

	proxyTable.disp = echo

	proxyTable.dispDefaultWriteError = function()
		echo("Can't overwrite default options. Please use the SetOption function to change the value\n")
	end

	proxyTable.dispOption = function(opt, val)
		if not opt or not val then
			return
		end
		echo("Name: " .. string.title(opt) .. string.rep(" ", 10 - string.len(opt)))
		echo("Val: " .. tostring(val.value))
		echo(string.rep(" ", 10 - string.len(tostring(val.value))) .. "- " .. val.use .. "\n")
	end

	function proxyTable:showAllOptions(game)
		-- Display header using mapper color scheme
		decho("<112,229,0>Setting:               <255,255,255>State:          <128,128,128>Option:\n")
		decho("<128,128,128>" .. string.rep("-", 60) .. "\n")
		
		-- Display all options
		for k, v in spairs(self[index]) do
			if not game or not v.games or v.games["all"] or v.games[game] then
				self.dispOption(k, v)
			end
		end
		for k, v in spairs(self["_customOptions"]) do
			self.dispOption(k, v)
		end
	end

	function proxyTable:getAllOptions()
		local t = {}
		for k, v in pairs(self[index]) do
			t[k] = v.value
		end

		return t
	end
	
	function proxyTable:getOptionDef(option)
		-- Check custom options first
		if self["_customOptions"][option] then
			return self["_customOptions"][option]
		-- Then check default options
		elseif self[index][option] then
			return self[index][option]
		end
		return nil
	end

	function proxyTable:setOption(option, value, silent)
		if self[option] == nil then
			proxyTable.disp("No such option!\n")
			return
		end
		
		-- Convert on/off to boolean for boolean options
		local optionDef = self["_customOptions"][option] or self[index][option]
		if optionDef and optionDef.allowedVarTypes and table.contains(optionDef.allowedVarTypes, "boolean") then
			if value == "on" then
				value = true
			elseif value == "off" then
				value = false
			elseif type(value) == "string" then
				-- Try to parse other string boolean values
				local lowerValue = value:lower()
				if lowerValue == "true" or lowerValue == "yes" or lowerValue == "1" then
					value = true
				elseif lowerValue == "false" or lowerValue == "no" or lowerValue == "0" then
					value = false
				end
			end
		end

		-- otherwise, set the option
		if self["_customOptions"][option] then
			if
				not (
					table.contains(self["_customOptions"][option].allowedVarTypes, type(value))
					and self["_customOptions"][option].checkOption(value)
				)
			then
				proxyTable.disp("You can't set '" .. option .. "' to that!\n")
				return
			end
			self["_customOptions"][option].value = value
			if self["_customOptions"][option].onChange then
				self["_customOptions"][option].onChange(option, value)
			end
		else
			if
				not (
					table.contains(self[index][option].allowedVarTypes, type(value))
					and self[index][option].checkOption(value)
				)
			then
				proxyTable.disp("You can't set '" .. option .. "' to that!\n")
				return
			end
			rawset(self[index][option], "value", value)
			local opt = rawget(self[index], option)
			if opt.onChange and not silent then
				opt.onChange(option, value)
			end
		end
		if mmp and mmp.clearpathcache then
			mmp.clearpathcache()
		end
	end

	proxyTable._customOptions = {}

	local mt = {
		__index = function(t, k)
			local custOp = rawget(t, "_customOptions")
			if custOp[k] then
				local opt = custOp[k]
				if opt then
					return opt.value
				else
					return nil
				end
			else
				local opt = t[index][k]
				if opt then
					return opt.value
				else
					return nil
				end
			end
		end,

		__newindex = function(t, k, v)
			if t[index][k] then
				proxyTable.dispDefaultWriteError()
			else
				t["_customOptions"][k] = v
			end
		end,
	}

	proxyTable[index] = defaultTable

	setmetatable(proxyTable, mt)

	return proxyTable
end
