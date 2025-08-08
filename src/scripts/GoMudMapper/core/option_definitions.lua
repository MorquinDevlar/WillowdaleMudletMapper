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
--       games = {"gomud", "achaea"}  -- Optional: only show for specific games
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
    
    laglevel = {
        default = 1,
        type = "number",
        description = "How laggy is your connection, (fast 1<->5 slow)?",
        validate = mmp.verifyLaglevel,
        onChange = mmp.changeLaglevel
    },
    
    walkspeed = {
        default = "normal",
        type = "string",
        description = "Walking speed (slow/normal/fast)?",
        validate = function(v) 
            return v == "slow" or v == "normal" or v == "fast" 
        end,
        onChange = function(name, value)
            if value == "slow" then
                mmp.echo("Walking speed set to slow - will pause between moves")
            elseif value == "fast" then
                mmp.echo("Walking speed set to fast - will move without waiting for prompts")
            else
                mmp.echo("Walking speed set to normal - will wait for prompts between moves")
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
    
    lockspecials = {
        default = false,
        type = "boolean",
        description = "Lock all special exits?",
        onChange = mmp.lockSpecials
    },
    
    -- GoMud-specific options
    crowdmap = {
        default = false,
        type = "boolean",
        description = "Use a crowd-sourced map instead of games default?",
        games = {"gomud"},
        onChange = mmp.changeMapSource
    },
    
    autopositionrooms = {
        default = true,
        type = "boolean",
        description = "Auto position rooms using GMCP coordinates when mapping?",
        games = {"gomud"},
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
        games = {"gomud"},
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