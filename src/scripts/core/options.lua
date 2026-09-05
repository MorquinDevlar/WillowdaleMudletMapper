-- The mapper's settings: what they are, what they accept, and the file they
-- live in.
--
-- To add a setting, add an entry to mapper.option_definitions:
--   myoption = {
--       default = "value",                        -- also fixes the type
--       type = "boolean", "string" or "number",
--       description = "What it does",             -- shown by mapper config
--       validate = function(v) ... end,           -- optional, true if allowed
--       onChange = function(name, value) ... end, -- optional, on a real change
--   }

mapper = mapper or {}

-- The message a plain on/off setting prints when it changes. Defined here rather
-- than in a script of its own: the table below reads it as it is built, so a
-- definition that loads later leaves every setting using it with no handler at
-- all until something reloads the mapper.
function mapper.changeBoolFunc(name, option)
    local en = option and "will now use" or "will no longer use"
    mapper.echo("<green>Okay, the mapper " .. en .. " <white>" .. name .. "<green>!")
end

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

    walktimeout = {
        default = 5,
        type = "number",
        description = "Seconds to wait for a move to land before trying it again",
        validate = function(v)
            return type(v) == "number" and v >= 1 and v <= 60
        end,
        onChange = function(name, value)
            mapper.echo(string.format(
                "A move the game does not answer within %gs will be sent again, and the walk given up on if that goes unanswered too.",
                value))
        end
    },

    safewalk = {
        default = false,
        type = "boolean",
        description = "Keep walks on roads, paths and other safe ground, where hostile mobs do not roam?",
        onChange = function(name, option)
            mapper.changeBoolFunc(name, option)
            mapper.reportreweighted(mapper.applyallterrain())
        end
    },

    safewalkcost = {
        default = 5,
        type = "number",
        description = "How many safe rooms one room off safe ground is worth to a walk",
        validate = function(v)
            return type(v) == "number" and v == math.floor(v) and v >= 2 and v <= 50
        end,
        onChange = function(name, value)
            mapper.echo(string.format(
                "A walk will now go up to %d safe rooms out of its way rather than cross one unsafe one.",
                value))
            -- The cost is only in the map's weights while safe walking is on
            if mapper.settings and mapper.settings.safewalk then
                mapper.reportreweighted(mapper.applyallterrain())
            end
        end
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
            elseif mode == "poi" then
                mapper.echo("Only POI characters (shop, inn, post office) will be shown")
            elseif mode == "biome" then
                mapper.echo("Only biome characters will be shown (not POI)")
            elseif mode == "all" then
                mapper.echo("All room characters will be shown")
            end
            mapper.refreshRoomChars()
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

-- The numeric settings have descriptions too long to stand in a column, and
-- their range is the thing worth saying in that column instead.
local numberranges = {
    walkdelay = "0-5 seconds",
    walktimeout = "1-60 seconds",
    safewalkcost = "2-50 rooms",
}

-- What a setting will take, for the listing and for the complaint when it is
-- given something else.
local function accepts(name, def)
    if def.type == "boolean" then
        return "on|off"
    elseif def.type == "number" then
        return numberranges[name] or "a number"
    end
    return def.description or ""
end

-- The words a player may type for a value, turned into the value itself. A
-- setting that takes a string keeps whatever was typed.
local function coerce(def, value)
    if type(value) ~= "string" then
        return value
    end
    if def.type == "boolean" then
        local word = value:lower()
        if word == "on" or word == "true" or word == "yes" or word == "1" then
            return true
        elseif word == "off" or word == "false" or word == "no" or word == "0" then
            return false
        end
    elseif def.type == "number" then
        return tonumber(value) or value
    end
    return value
end

-- The settings table. Values are read straight off it (mapper.settings.debug),
-- but writing one has to go through setOption, so that a change is checked,
-- reported and saved rather than silently dropped into the table.
function mapper.newsettings()
    local values = {}
    for name, def in pairs(mapper.option_definitions) do
        values[name] = def.default
    end

    local methods = {}

    function methods:setOption(name, value, silent)
        local def = mapper.option_definitions[name]
        if not def then
            mapper.echo("There is no '" .. tostring(name) .. "' setting.")
            return
        end

        value = coerce(def, value)
        if type(value) ~= def.type or (def.validate and not def.validate(value)) then
            mapper.echo("You can't set '" .. name .. "' to that! Accepted: " .. accepts(name, def))
            return
        end

        values[name] = value
        if silent then
            return
        end
        if def.onChange then
            def.onChange(name, value)
        end
        mapper.saveoptions()
    end

    function methods:showAllOptions()
        local names = table.keys(mapper.option_definitions)
        table.sort(names)
        local rows = {}
        for _, name in ipairs(names) do
            local def = mapper.option_definitions[name]
            local value = values[name]
            if def.type == "boolean" then
                value = value and "on" or "off"
            end
            value = tostring(value)
            if #value > 29 then
                value = value:sub(1, 26) .. "..."
            end
            rows[#rows + 1] = { name, value, accepts(name, def) }
        end
        -- The minimum widths are what the columns had before there was a table
        -- printer, and are what keeps a short setting from squeezing them up
        mapper.printtable({
            { title = "Setting:", min = 24 },
            { title = "State:",   min = 10 },
            { title = "Option:" },
        }, rows)
    end

    -- What one setting is: what it does, what it takes and what it is set to.
    function methods:describe(name)
        local def = mapper.option_definitions[name]
        if not def then
            return nil
        end
        local value = values[name]
        if def.type == "boolean" then
            value = value and "on" or "off"
        end
        return def.description, accepts(name, def), tostring(value)
    end

    return setmetatable({}, {
        __index = function(_, key)
            return methods[key] or values[key]
        end,
        __newindex = function()
            mapper.echo("Please use the mconfig alias to set options!")
        end,
    })
end

-- Settings and area locks share one file. Mudlet takes "/" as the separator on
-- every platform it runs on.
local function optionsfile()
    return getMudletHomeDir() .. "/mapper.options.lua"
end

function mapper.saveoptions()
    -- Nothing to write before the settings table exists, and at exit the mapper
    -- can be half torn down by an uninstall
    if not mapper.settings or not mapper.option_definitions then
        return
    end
    local options = {}
    for name in pairs(mapper.option_definitions) do
        options[name] = mapper.settings[name]
    end
    table.save(optionsfile(), {
        options = options,
        locked_areas = mapper.locked or {},
        terrain = mapper.terrainweights or {},
    })
end

-- The terrain weights out of that file, which anything may have been written
-- into by hand. A name that is not a name, or a weight the command would not
-- have accepted, is dropped here rather than reaching setRoomWeight; 1 is not
-- stored in the first place, since it is what an unweighted room costs.
local function restoreterrain(saved)
    local weights = {}
    if type(saved) == "table" then
        for name, weight in pairs(saved) do
            if type(name) == "string" and type(weight) == "number"
                and weight == math.floor(weight) and weight >= 2 and weight <= 50 then
                weights[name:lower()] = weight
            end
        end
    end
    mapper.terrainweights = weights
end

-- Read the file back and put the areas the player locked back under lock: a lock
-- keeps pathfinding out of an area, and it is the mapper's own state rather than
-- part of the map file, so a fresh map arrives with none of them in place.
function mapper.loadlocks()
    local loaded = {}
    if io.exists(optionsfile()) then
        table.load(optionsfile(), loaded)
    end

    mapper.locked = loaded.locked_areas or mapper.locked or {}

    local lockRoom, getAreaRooms1 = lockRoom, getAreaRooms1
    local lockedany = false
    for area in pairs(mapper.locked) do
        for _, roomid in ipairs(getAreaRooms1(area) or {}) do
            lockRoom(roomid, true)
            lockedany = true
        end
    end
    -- Reloading the mapper runs this again, over a cache that has routes in it.
    if lockedany then
        mapper.clearpathcache()
    end

    return loaded
end

function mapper.loadoptions()
    -- The settings have to exist to be restored into. They normally do by now:
    -- sysLoadEvent runs mapper.startup() before this.
    if not mapper.settings then
        mapper.firstRun = true
        mapper.startup()
        if not mapper.settings then
            return
        end
    end

    local loaded = mapper.loadlocks()
    -- Before the settings, and so before applysettings sweeps the map: what a
    -- room should weigh is these weights and the safewalk setting together.
    restoreterrain(loaded.terrain)
    if not loaded.options then
        return
    end
    for name, value in pairs(loaded.options) do
        -- A file written by an older version can name settings that are gone
        if mapper.option_definitions[name] then
            mapper.settings:setOption(name, value, true)
        end
    end
    mapper.applysettings()
end

-- Settings are restored silently, so the handlers that act on the map never run.
-- Put the loaded values into effect once, with one message instead of the
-- running commentary each option would print on its own.
function mapper.applysettings()
    mapper.notify("Applying existing settings...")
    mapper.refreshRoomChars(true)
    if not mapper.settings.showspeedwalkpath then
        mapper.clearPathHighlight()
    end
    -- Room weights live in the map file rather than in the options file, so a
    -- map built under other terrain weights, or under safewalk set the other
    -- way, carries the wrong costs until they are put back in line with what
    -- has just been loaded.
    mapper.applyallterrain()
end
