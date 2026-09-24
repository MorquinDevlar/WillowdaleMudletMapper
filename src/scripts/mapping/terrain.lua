-- What it costs to cross a room, by the kind of ground it is.
--
-- Mudlet's room weight is the cost the pathfinder counts for entering a room,
-- and 1 is what an ordinary room costs. Giving deep water a weight of 5 does
-- not forbid it: it says that five ordinary rooms of dry road are the better
-- way, and four are not. Weights are stored in the map file, so they are only
-- written when they actually change - each write rebuilds Mudlet's pathfinding
-- graph, and this runs for every room the player walks into.
--
-- The game puts no movement cost on any biome, so there is no right number for
-- one here: nothing is weighted until the player weights it with
-- `mapper terrain`.

-- The player's weights, biome name in lower case (the game sends them
-- capitalised) to a whole number. Kept across a package reload, and read back
-- out of the options file by mapper.loadoptions.
mapper.terrainweights = mapper.terrainweights or {}

-- The ground the game marks as safe from hostile mobs: the biomes carrying
-- `safe: true` in the server's biome data. That flag is not part of GMCP, so
-- the names are written out here; mapper.buildSafeBiomeSet replaces the whole
-- set if the game ever starts sending one.
mapper.safebiomes = {
    ["road"] = true,
    ["path"] = true,
    ["inn"] = true,
    ["post office"] = true,
}

function mapper.issafebiome(biome)
    if type(biome) ~= "string" then
        return false
    end
    return mapper.safebiomes[biome:lower()] == true
end

-- Every biome a weight can be set on, sorted and in lower case: the ones this
-- package has a colour for, the ones the game names when connected, and any the
-- player has already weighted - a weight stays visible and clearable even if the
-- game stops naming that biome.
function mapper.knownbiomes()
    local seen = {}

    for name in pairs(mapper.envids or {}) do
        -- Default and Unexplored are the map's own two, not ground to walk on
        if type(name) == "string" and name ~= "Default" and name ~= "Unexplored" then
            seen[name:lower()] = true
        end
    end

    local colors = gmcp and gmcp.Game and gmcp.Game.Info and gmcp.Game.Info.biome_colors
    if type(colors) == "table" then
        for name in pairs(colors) do
            if type(name) == "string" and name ~= "" then
                seen[name:lower()] = true
            end
        end
    end

    -- Safe ground has to be listed to be shown as safe, and Post Office is
    -- named nowhere else: this package has no colour of its own for it, and
    -- biome_colors keys biomes by id, where that one is "post".
    for name in pairs(mapper.safebiomes or {}) do
        seen[name] = true
    end

    for name in pairs(mapper.terrainweights or {}) do
        seen[name] = true
    end

    local names = {}
    for name in pairs(seen) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

-- What a room of a biome (in lower case) costs to enter under a set of
-- terrain settings: the player's weights, whether safe walking is on, what it
-- charges for unsafe ground and which ground is safe. Taking them as arguments
-- lets a change of settings be compared against the ones the map was weighted
-- under, as well as weigh a room under the ones in force.
function mapper.weightfor(name, weights, safewalk, cost, safe)
    local weight = weights[name] or 1
    -- Safe walking is a floor under every unsafe biome rather than a weight of
    -- its own, so a biome the player already made dearer stays that dear.
    if safewalk and not safe[name] then
        weight = math.max(weight, cost)
    end
    return weight
end

-- What a room of this biome should cost a walk to enter.
function mapper.roomweight(biome)
    if type(biome) ~= "string" or biome == "" then
        return 1
    end
    local settings = mapper.settings
    return mapper.weightfor(biome:lower(), mapper.terrainweights or {},
        settings and settings.safewalk and true or false,
        settings and tonumber(settings.safewalkcost) or 1,
        mapper.safebiomes or {})
end

-- Give a room the weight asked for. Weights are only written when they change:
-- each write rebuilds Mudlet's pathfinding graph. Returns whether it changed.
function mapper.reweighroom(id, wanted)
    if (getRoomWeight(id) or 1) == wanted then
        return false
    end
    setRoomWeight(id, wanted)
    return true
end

-- Put one room's weight in line with its biome. Returns whether the map
-- actually changed.
function mapper.applyterrain(id, biome)
    id = tonumber(id)
    if not id or not roomExists(id) then
        return false
    end
    return mapper.reweighroom(id, mapper.roomweight(biome))
end

-- What a sweep did, in the one wording every command that causes one uses.
function mapper.reportreweighted(changed)
    if changed == 0 then
        mapper.echo("No room's weight had to change.")
    else
        mapper.echo(string.format("Reweighted %d room%s.", changed, changed == 1 and "" or "s"))
    end
end

-- Give a biome a weight; 1 is what an ordinary room costs, so it takes the
-- weight off instead of storing it. Returns how many rooms changed, or nil and
-- what was wrong with the request.
function mapper.setterrainweight(biome, weight)
    if type(biome) ~= "string" or biome == "" then
        return nil, "Which biome? 'mapper terrain' lists them."
    end

    local name = biome:lower()
    local known = false
    for _, candidate in ipairs(mapper.knownbiomes()) do
        if candidate == name then
            known = true
            break
        end
    end
    if not known then
        return nil, "There is no '" .. biome .. "' biome. 'mapper terrain' lists them."
    end

    weight = tonumber(weight)
    if not weight or weight ~= math.floor(weight) or weight < 1 or weight > 50 then
        return nil, "A weight is a whole number from 1 to 50, where 1 is an ordinary room."
    end

    mapper.terrainweights[name] = weight > 1 and weight or nil
    mapper.saveoptions()
    return mapper.applyallterrain()
end

-- Take every weight off. Returns how many rooms changed.
function mapper.clearterrainweights()
    mapper.terrainweights = {}
    mapper.saveoptions()
    return mapper.applyallterrain()
end
