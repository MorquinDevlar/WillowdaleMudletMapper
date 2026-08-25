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
--   }

mapper.option_definitions = {
    -- General settings
    showcmds = {
        default = true,
        type = "boolean",
        description = "Show walking commands?",
        onChange = mapper.changeBoolFunc
    },

    walkdelay = {
        default = 0,
        type = "number",
        description = "Delay between moves in seconds (0 = fast, 0.3 = normal, 1+ = slow)?",
        validate = function(v)
            return type(v) == "number" and v >= 0 and v <= 5
        end,
        onChange = function(name, value)
            if value == 0 then
                mapper.echo(string.format("Walk delay set to %.1f seconds - moving as fast as possible", value))
            elseif value < 0.3 then
                mapper.echo(string.format("Walk delay set to %.1f seconds - very fast movement", value))
            elseif value <= 0.5 then
                mapper.echo(string.format("Walk delay set to %.1f seconds - normal speed", value))
            elseif value <= 1 then
                mapper.echo(string.format("Walk delay set to %.1f seconds - slow movement", value))
            else
                mapper.echo(string.format("Walk delay set to %.1f seconds - very slow movement", value))
            end
        end
    },

    autoclear = {
        default = true,
        type = "boolean",
        description = "Automatically remove exits that no longer exist?",
        onChange = mapper.changeBoolFunc
    },

    debug = {
        default = false,
        type = "boolean",
        description = "Enable debug messages?",
        onChange = mapper.changeBoolFunc
    },

    -- GMCP coordinate features

    autopositionrooms = {
        default = true,
        type = "boolean",
        description = "Auto position rooms using GMCP coordinates when mapping?",
        onChange = function(name, option)
            mapper.changeBoolFunc(name, option)
            if option then
                mapper.echo("Rooms will now be positioned using absolute coordinates from GMCP")
            else
                mapper.echo("Rooms will now be positioned using standard directional offsets (+1)")
            end
        end
    },

    autocreateareas = {
        default = true,
        type = "boolean",
        description = "Auto create areas based on GMCP area information when mapping?",
        onChange = function(name, option)
            mapper.changeBoolFunc(name, option)
            if option then
                mapper.echo("Areas will now be automatically created based on GMCP area information")
            else
                mapper.echo("Areas will need to be created manually")
            end
        end
    },

    roomchar = {
        default = "poi",
        type = "string",
        description = "all|biome|poi|none",
        validate = function(v)
            if type(v) ~= "string" then
                return false
            end
            local valid = { all = true, biome = true, poi = true, none = true }
            return valid[v:lower()] == true
        end,
        onChange = function(name, value)
            local mode = tostring(value):lower()
            -- Store the canonical spelling, without running this handler again
            if mode ~= value then
                mapper.settings:setOption(name, mode, true)
            end
            if mode == "none" then
                mapper.echo("Room characters will be hidden from the map")
                mapper.clearRoomChars()
            elseif mode == "poi" then
                mapper.echo("Only POI characters (shop, inn, post office) will be shown")
                mapper.refreshRoomChars()
            elseif mode == "biome" then
                mapper.echo("Only biome characters will be shown (not POI)")
                mapper.refreshRoomChars()
            elseif mode == "all" then
                mapper.echo("All room characters will be shown")
                mapper.refreshRoomChars()
            end
        end
    },

    showspeedwalkpath = {
        default = true,
        type = "boolean",
        description = "Highlight the path on the map during speedwalk?",
        onChange = function(name, option)
            mapper.changeBoolFunc(name, option)
            if option then
                mapper.echo("Speedwalk path will be highlighted on the map")
            else
                mapper.echo("Speedwalk path highlighting disabled")
                mapper.clearPathHighlight()
            end
        end
    },

    showmappingmessages = {
        default = false,
        type = "boolean",
        description = "Show messages when mapping (room creation, exits, doors, colors)?",
        onChange = mapper.changeBoolFunc
    }
}

-- Helper function to convert simple definitions to the old format
function mapper.convertOptionsFromDefinitions()
    local private_settings = {}

    for name, def in pairs(mapper.option_definitions) do
        -- Determine allowed types
        local allowedTypes = {}
        if def.type then
            table.insert(allowedTypes, def.type)
        end

        -- Create the option using the existing system
        private_settings[name] = mapper.createOption(
            def.default,
            def.onChange,
            allowedTypes,
            def.description,
            def.validate
        )
    end

    return private_settings
end
