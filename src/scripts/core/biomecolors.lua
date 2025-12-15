-- Biome color management for dynamic room coloring
-- Converts GMCP biome_color hex codes to environment IDs

-- Initialize storage for biome color mappings
mapper.biomeColorToEnvId = mapper.biomeColorToEnvId or {}
mapper.nextBiomeEnvId = mapper.nextBiomeEnvId or 1000  -- Start at 1000 to avoid conflicts with static env IDs

-- Convert hex color string to RGBA values
-- @param hexColor string - Hex color code (e.g., "#708090" or "708090")
-- @return r, g, b, a number - RGBA values (0-255)
function mapper.hexToRGBA(hexColor)
    if not hexColor or type(hexColor) ~= "string" then
        return nil
    end

    -- Remove # if present
    local hex = hexColor:gsub("^#", "")

    -- Handle 6-character hex codes (RGB)
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        return r, g, b, 255
    end

    -- Handle 8-character hex codes (RGBA)
    if #hex == 8 then
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        local a = tonumber(hex:sub(7, 8), 16)
        return r, g, b, a
    end

    -- Invalid format
    return nil
end

-- Get or create an environment ID for a biome color
-- @param biomeColor string - Hex color code from GMCP (e.g., "#708090")
-- @return number - Environment ID to use with setRoomEnv()
function mapper.getBiomeEnvId(biomeColor)
    if not biomeColor or type(biomeColor) ~= "string" then
        return nil
    end

    -- Normalize the color (remove #, convert to uppercase for consistency)
    local normalizedColor = biomeColor:gsub("^#", ""):upper()

    -- Check if we've already registered this color
    if mapper.biomeColorToEnvId[normalizedColor] then
        return mapper.biomeColorToEnvId[normalizedColor]
    end

    -- Convert hex to RGBA
    local r, g, b, a = mapper.hexToRGBA(biomeColor)
    if not r then
        return nil
    end

    -- Allocate a new environment ID
    local envId = mapper.nextBiomeEnvId
    mapper.nextBiomeEnvId = mapper.nextBiomeEnvId + 1

    -- Register the color with Mudlet
    setCustomEnvColor(envId, r, g, b, a)

    -- Store the mapping
    mapper.biomeColorToEnvId[normalizedColor] = envId

    return envId
end

-- Initialize biome colors from stored settings
-- This is called when the mapper loads to restore previously registered colors
function mapper.initializeBiomeColors()
    if not mapper.biomeColorToEnvId then
        mapper.biomeColorToEnvId = {}
    end

    -- Re-register all previously seen colors
    for colorHex, envId in pairs(mapper.biomeColorToEnvId) do
        local r, g, b, a = mapper.hexToRGBA(colorHex)
        if r then
            setCustomEnvColor(envId, r, g, b, a)
        end
    end

    -- Update the next ID counter to be higher than any existing ID
    local maxId = 999
    for _, envId in pairs(mapper.biomeColorToEnvId) do
        if envId > maxId then
            maxId = envId
        end
    end
    mapper.nextBiomeEnvId = maxId + 1
end
