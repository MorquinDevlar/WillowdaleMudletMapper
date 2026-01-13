-- mapper = mudlet mapper namespace
-- Hardcoded for Willowdale
mapper.game = "willowdale"

mapper = mapper or {}

-- Initialize default values if not set
mapper.paused = mapper.paused or false
mapper.autowalking = mapper.autowalking or false
mapper.currentroom = mapper.currentroom or 0
mapper.currentroomname = mapper.currentroomname or "(unknown)"
mapper.specials = mapper.specials or {}

-- firstRun must be explicitly checked for nil since false is a valid value
if mapper.firstRun == nil then
    mapper.firstRun = true
end

-- Mapping mode is always enabled (auto-creates rooms from GMCP data)
if mapper.editing == nil then
    mapper.editing = true
end
mapper.speedWalkWatch = createStopWatch()
-- speedWalkPath and speedWalkDir populated by Mudlet from getPath() and gotoRoom()
speedWalkPath = speedWalkPath or {}
speedWalkDir = speedWalkDir or {}

-- actually used by the mapper for walking
mapper.speedWalkCounter = 0
mapper.speedWalk = mapper.speedWalk or {}
mapper.speedWalkPath = mapper.speedWalkPath or {}
mapper.speedWalkDir = mapper.speedWalkDir or {}
local newversion = "__VERSION__"
if mapper.version and mapper.version ~= newversion then
    mapper.echo("Mapper script updated - thanks! You don't need to restart.")
end
mapper.version = newversion

function mapper.reload()
    -- Force reload of settings
    mapper.firstRun = true
    mapper.startup()
    mapper.echo("Mapper settings reloaded!")
end

function mapper.startup()
    if not mapper.firstRun then
        return
    end

    -- Load options from the simple definition table
    local private_settings = mapper.convertOptionsFromDefinitions()

    mapper.settings = mapper.createOptionsTable(private_settings)
    mapper.settings.disp = mapper.echo

    mapper.settings.dispOption = function(opt, val)
        -- Format boolean values as on/off
        local displayValue = val.value
        if type(val.value) == "boolean" then
            displayValue = val.value and "on" or "off"
        end

        -- Determine options available
        local options = ""
        if val.allowedVarTypes and table.contains(val.allowedVarTypes, "boolean") then
            options = "on|off"
        elseif opt == "echocolour" then
            options = "See mcolor for options"
        elseif opt == "walkdelay" then
            options = "0-5 seconds"
        else
            options = val.use or ""
        end

        -- Truncate long values for display
        local stateStr = tostring(displayValue)
        if #stateStr > 29 then
            stateStr = stateStr:sub(1, 26) .. "..."
        end

        -- Display in columns: Setting, State, Option
        decho(string.format("<112,229,0>%-19s <255,255,255>%-29s <128,128,128>%s\n", opt, stateStr, options))
    end

    mapper.settings.dispDefaultWriteError = function()
        mapper.echo("Please use the mconfig alias to set options!")
    end

    -- Set environment colors if they're defined
    if mapper.setEnvironmentColors then
        mapper.setEnvironmentColors()
    end

    -- Initialize biome colors from saved mappings
    if mapper.initializeBiomeColors then
        mapper.initializeBiomeColors()
    end

    raiseEvent("mapper areas changed")
    mapper.firstRun = false
    mapper.echo("Mudlet Mapper script for Willowdale (" .. tostring(mapper.version) .. ") loaded!")
end
