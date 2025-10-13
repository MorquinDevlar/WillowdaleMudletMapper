-- mmp = mudlet mapper namespace
mmp = mmp
    or {
        paused = false,
        autowalking = false,
        currentroom = 0,
        currentroomname = "(unknown)",
        firstRun = true,
        specials = {},
    }
mmp.speedWalkWatch = createStopWatch()
-- speedWalkPath and speedWalkDir populated by Mudlet from getPath() and gotoRoom()
speedWalkPath = speedWalkPath or {}
speedWalkDir = speedWalkDir or {}

-- actually used by the mapper for walking
mmp.speedWalkCounter = 0
mmp.speedWalk = mmp.speedWalk or {}
mmp.speedWalkPath = mmp.speedWalkPath or {}
mmp.speedWalkDir = mmp.speedWalkDir or {}
local newversion = "__VERSION__"
if mmp.version and mmp.version ~= newversion then
    if not mmp.game then
        -- Check if we can detect the game via GMCP
        if mmp.detectGameFromGMCP then
            mmp.detectGameFromGMCP()
            mmp.echo("Mapper script updated - thanks! You don't need to restart.")
        else
            mmp.echo(
                "Mapper script updated - Thanks! I don't know what game are you connected to, though - so please reconnect, if you could."
            )
        end
    else
        mmp.echo("Mapper script updated - thanks! You don't need to restart.")
    end
end
mmp.version = newversion

function mmp.reload()
    -- Force reload of settings
    mmp.firstRun = true
    mmp.startup()
    mmp.echo("Mapper settings reloaded!")
end

function mmp.startup()
    if not mmp.firstRun then
        return
    end

    -- Load options from the simple definition table
    local private_settings = mmp.convertOptionsFromDefinitions()

    mmp.settings = mmp.createOptionsTable(private_settings)
    mmp.settings.disp = mmp.echo

    -- Detect game type if not already set
    if not mmp.game then
        if mmp.detectGameFromGMCP then
            mmp.detectGameFromGMCP()
        else
            mmp.game = false
        end
    end

    mmp.settings.dispOption = function(opt, val)
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
            options = tostring(displayValue)
        end

        -- Display in columns: Setting, State, Option
        -- Using mapper's color scheme: light green for settings, white for values, dim gray for options
        decho(string.format("<112,229,0>%-22s <255,255,255>%-15s <128,128,128>%s\n", opt, tostring(displayValue), options))
    end

    mmp.settings.dispDefaultWriteError = function()
        mmp.echo("Please use the mconfig alias to set options!")
    end

    -- Set environment colors if they're defined
    if mmp.setEnvironmentColors then
        mmp.setEnvironmentColors()
    end

    raiseEvent("mmp areas changed")
    mmp.firstRun = false
    mmp.echon("Mudlet Mapper script for GoMud (" .. tostring(mmp.version) .. ") loaded! (")
    echoLink(
        "See more on Github",
        "(openUrl or openURL)('https://github.com/GoMudEngine/MudletMapper')",
        "Clicky clicky to read up on what's this about"
    )
    echo(")\n")
end
