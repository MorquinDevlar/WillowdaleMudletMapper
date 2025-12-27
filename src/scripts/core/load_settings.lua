-- mapper = mudlet mapper namespace
-- Hardcoded for Willowdale
mapper.game = "willowdale"

mapper = mapper
    or {
        paused = false,
        autowalking = false,
        currentroom = 0,
        currentroomname = "(unknown)",
        firstRun = true,
        specials = {},
    }
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

function mapper.setFonts()
    setFont("main", mapper.settings.font)
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
        elseif opt == "font" then
            options = "(font name)"
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

    -- Apply font settings
    mapper.setFonts()

    raiseEvent("mapper areas changed")
    mapper.firstRun = false
    mapper.echo("Mudlet Mapper script for Willowdale (" .. tostring(mapper.version) .. ") loaded!")
end
