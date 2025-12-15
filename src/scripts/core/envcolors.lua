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