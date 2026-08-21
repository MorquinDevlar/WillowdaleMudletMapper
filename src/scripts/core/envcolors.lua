-- Generic function to set environment colors if mapper.colorcodes is defined
function mapper.setEnvironmentColors()
    -- Check if color codes are defined
    if not mapper.colorcodes or type(mapper.colorcodes) ~= "table" then
        return false
    end
    
    -- Apply color codes to environments
    local count = 0
    for id, rgba in pairs(mapper.colorcodes) do
        if type(rgba) == "table" and #rgba >= 3 then
            -- setCustomEnvColor expects RGB values, with optional alpha (default 255)
            local r, g, b, a = rgba[1], rgba[2], rgba[3], rgba[4] or 255
            setCustomEnvColor(id, r, g, b, a)
            count = count + 1
        end
    end
    
    if count > 0 and mapper.settings and mapper.settings.debug then
        mapper.echo(string.format("Applied custom colors to %d environments", count))
    end
    
    return count > 0
end

-- The environment a room the player has actually entered gets when the game
-- sent no biome color for it.
function mapper.defaultroomenv()
    return (mapper.envids and mapper.envids.Default) or 28
end

-- The environment stub rooms get: rooms we only know about because an exit
-- leads there, drawn in a muted dark red so they read as unexplored rather
-- than as the biome of the room they were seen from.
function mapper.unexploredroomenv()
    return (mapper.envids and mapper.envids.Unexplored) or 53
end
