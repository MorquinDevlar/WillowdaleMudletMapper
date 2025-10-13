-- Simple table structure for defining mapper options
-- This makes it easy to add new options without complex function calls
--
-- To add a new option, just add an entry like:
--   myoption = {
--       default = "value",           -- The default value
--       type = "string",             -- "boolean", "string", or "number"
--       description = "What it does", -- Shown in mconfig
--       validate = function(v) ... end,  -- Optional: return true if value is valid
--       onChange = function(name, value) ... end,  -- Optional: called when value changes
--       games = {"all"}              -- Optional: {"all"} for all games, or {"game1", "game2"} for specific games
--   }

mmp.option_definitions = {
    -- General settings
    echocolour = {
        default = "cyan",
        type = "string",
        description = "Set the color for room number echos?",
        validate = function(v) return color_table[v] ~= nil end,
        onChange = mmp.changeEchoColour
    },
    
    showcmds = {
        default = true,
        type = "boolean",
        description = "Show walking commands?",
        onChange = mmp.changeBoolFunc
    },
    
    walkdelay = {
        default = 0.3,
        type = "number",
        description = "Delay between moves in seconds (0 = fast, 0.3 = normal, 1+ = slow)?",
        validate = function(v) 
            return type(v) == "number" and v >= 0 and v <= 5
        end,
        onChange = function(name, value)
            if value == 0 then
                mmp.echo(string.format("Walk delay set to %.1f seconds - moving as fast as possible", value))
            elseif value < 0.3 then
                mmp.echo(string.format("Walk delay set to %.1f seconds - very fast movement", value))
            elseif value <= 0.5 then
                mmp.echo(string.format("Walk delay set to %.1f seconds - normal speed", value))
            elseif value <= 1 then
                mmp.echo(string.format("Walk delay set to %.1f seconds - slow movement", value))
            else
                mmp.echo(string.format("Walk delay set to %.1f seconds - very slow movement", value))
            end
        end
    },
    
    updatemap = {
        default = true,
        type = "boolean",
        description = "Check for new maps from your MUD?",
        onChange = mmp.changeUpdateMap
    },
    
    autoclear = {
        default = true,
        type = "boolean",
        description = "Automatically remove exits that no longer exist?",
        onChange = mmp.changeBoolFunc
    },
    
    debug = {
        default = false,
        type = "boolean",
        description = "Enable debug messages?",
        onChange = mmp.changeBoolFunc
    },
    
    -- GoMud engine features
    -- These are available for all GoMud-based games
    
    autopositionrooms = {
        default = true,
        type = "boolean",
        description = "Auto position rooms using GMCP coordinates when mapping?",
        games = {"all"},  -- Available for all games
        onChange = function(name, option)
            mmp.changeBoolFunc(name, option)
            if option then
                mmp.echo("Rooms will now be positioned using absolute coordinates from GMCP")
            else
                mmp.echo("Rooms will now be positioned using standard directional offsets (+1)")
            end
        end
    },
    
    autocreateareas = {
        default = false,
        type = "boolean",
        description = "Auto create areas based on GMCP area information when mapping?",
        games = {"all"},  -- Available for all games
        onChange = function(name, option)
            mmp.changeBoolFunc(name, option)
            if option then
                mmp.echo("Areas will now be automatically created based on GMCP area information")
            else
                mmp.echo("Areas will need to be created manually")
            end
        end
    }
}

-- Helper function to convert simple definitions to the old format
function mmp.convertOptionsFromDefinitions()
    local private_settings = {}
    
    for name, def in pairs(mmp.option_definitions) do
        -- Determine allowed types
        local allowedTypes = {}
        if def.type then
            table.insert(allowedTypes, def.type)
        end
        
        -- Convert games array to the format expected by createOption
        local games = nil
        if def.games then
            games = {}
            for _, game in ipairs(def.games) do
                games[game] = true
            end
        end
        
        -- Create the option using the existing system
        private_settings[name] = mmp.createOption(
            def.default,
            def.onChange,
            allowedTypes,
            def.description,
            def.validate,
            games
        )
    end
    
    return private_settings
end