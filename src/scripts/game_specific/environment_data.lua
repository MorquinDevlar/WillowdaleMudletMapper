-- Static environment IDs and colors - defined at package load time
mapper.envids = {
    Air = 20,
    Badland = 22,
    Beach = 23,
    Cave = 25,
    City = 26,
    Coast = 27,
    Default = 28,
    Desert = 29,
    Field = 30,
    Forest = 31,
    Garden = 32,
    Grove = 33,
    Hills = 34,
    Home = 35,
    House = 35,
    Inn = 36,
    Inside = 37,
    Marsh = 38,
    Meadow = 39,
    Mountain = 40,
    Orchard = 41,
    Path = 42,
    Road = 43,
    Ship = 44,
    Shop = 45,
    Temple = 46,
    Thicket = 47,
    Tundra = 48,
    Snow = 48,
    Underwater = 49,
    Water = 50,
    Glade = 51,
    Clearing = 52,
}

mapper.colorcodes = {
    [20] = { 176, 224, 230, 255 }, -- Air: Light blue
    [22] = { 205, 133, 63, 255 },  -- Badland: Peru brown
    [23] = { 218, 165, 32, 255 },  -- Beach: Goldenrod
    [25] = { 47, 79, 79, 255 },    -- Cave: Dark slate gray
    [26] = { 190, 190, 190, 255 }, -- City: Gray
    [27] = { 210, 180, 140, 255 }, -- Coast: Tan
    [28] = { 255, 69, 0, 255 },    -- Default: Red-orange
    [29] = { 255, 215, 0, 255 },   -- Desert: Gold
    [30] = { 127, 255, 0, 255 },   -- Field: Chartreuse
    [31] = { 0, 100, 0, 255 },     -- Forest: Dark green
    [32] = { 152, 251, 152, 255 }, -- Garden: Pale green
    [33] = { 34, 139, 34, 255 },   -- Grove: Forest green
    [34] = { 50, 205, 50, 255 },   -- Hills: Lime green
    [35] = { 102, 205, 170, 255 }, -- Home: Medium aquamarine
    [36] = { 0, 128, 128, 255 },   -- Inn: Teal
    [37] = { 255, 250, 205, 255 }, -- Inside: Lemon chiffon
    [38] = { 107, 142, 35, 255 },  -- Marsh: Olive drab
    [39] = { 154, 205, 50, 255 },  -- Meadow: Yellow green
    [40] = { 139, 69, 19, 255 },   -- Mountain: Saddle brown
    [41] = { 124, 252, 0, 255 },   -- Orchard: Lawn green
    [42] = { 153, 102, 51, 255 },  -- Path: Brown
    [43] = { 112, 128, 144, 255 }, -- Road: Slate gray
    [44] = { 255, 42, 42, 255 },   -- Ship: Red
    [45] = { 0, 190, 255, 255 },   -- Shop: Deep sky blue
    [46] = { 138, 43, 226, 255 },  -- Temple: Blue violet
    [47] = { 85, 107, 47, 255 },   -- Thicket: Dark olive green
    [48] = { 255, 250, 250, 255 }, -- Tundra: Snow
    [49] = { 65, 105, 225, 255 },  -- Underwater: Royal blue
    [50] = { 30, 144, 255, 255 },  -- Water: Dodger blue
    [51] = { 144, 238, 144, 255 }, -- Glade: Light green
    [52] = { 143, 188, 143, 255 }, -- Clearing: Dark sea green
}

-- Build reverse lookup table
mapper.waterenvs = {}
mapper.envidsr = {}
for name, id in pairs(mapper.envids) do
    mapper.envidsr[id] = name
end

-- Apply environment colors immediately at package load time
if mapper.setEnvironmentColors then
    mapper.setEnvironmentColors()
end

function mapper.registergomudenvdata(_, game)
    -- Check if this is running on the GoMud engine
    if not (gmcp and gmcp.Game and gmcp.Game.Info and gmcp.Game.Info.engine == "GoMud") then
        return
    end

    -- Build hex→envId lookup from GMCP biome_colors
    mapper.buildBiomeColorLookup()
end

-- Build hex color → static env ID lookup from GMCP biome_colors
function mapper.buildBiomeColorLookup()
    if not (gmcp and gmcp.Game and gmcp.Game.Info and gmcp.Game.Info.biome_colors) then
        return
    end

    mapper.hexToStaticEnvId = {}

    for biomeName, hexColor in pairs(gmcp.Game.Info.biome_colors) do
        -- Capitalize first letter to match mapper.envids keys (e.g., "road" → "Road")
        local capitalizedName = biomeName:gsub("^%l", string.upper)
        local envId = mapper.envids[capitalizedName]

        if envId then
            -- Normalize hex (remove #, uppercase)
            local normalizedHex = hexColor:gsub("^#", ""):upper()
            mapper.hexToStaticEnvId[normalizedHex] = envId
        end
    end
end
