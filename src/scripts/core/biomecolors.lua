-- Which environment a room of each biome colour is drawn with.
--
-- The game sends a room's biome as a colour (Room.Info.Basic.biome_color) and
-- Mudlet draws a room by an environment id, so each colour has to come out as
-- the same id every time. A room is recoloured when the id it wants differs
-- from the one it has, and two ids for one colour repaint it for nothing and
-- report a change nobody can see.

-- A colour the package has no environment for - a biome the game added after
-- this version - gets an id made from the colour itself, so it is the same in
-- every session and on every map without being written down anywhere, and no
-- two colours can share one. It sits above the package's own ids, Mudlet's
-- palette and the ids earlier versions handed out from 1000 up.
local COLOURENVS = 0x1000000

-- A GMCP colour as the six upper-case hex digits the lookups key on, or nil for
-- anything that is not one.
function mapper.normalisehex(color)
    if type(color) ~= "string" then
        return nil
    end
    local hex = color:gsub("^#", ""):upper()
    if not hex:match("^%x%x%x%x%x%x$") then
        return nil
    end
    return hex
end

-- The environment a room of this biome colour is drawn with: the package's own
-- for a colour it knows (see mapper.buildBiomeColorLookup), else the one made
-- from the colour. Nil for anything that is not a colour.
function mapper.getBiomeEnvId(biomeColor)
    local hex = mapper.normalisehex(biomeColor)
    if not hex then
        return nil
    end
    local known = mapper.hexToStaticEnvId and mapper.hexToStaticEnvId[hex]
    return known or (COLOURENVS + tonumber(hex, 16))
end

-- The red, green and blue of an environment made from a colour; nil for any
-- other environment.
local function colourenv(env)
    local value = tonumber(env) and tonumber(env) - COLOURENVS
    if not value or value < 0 or value > 0xFFFFFF then
        return nil
    end
    return math.floor(value / 65536), math.floor(value / 256) % 256, value % 256
end

-- What the map calls an environment: the package's name for it, or the colour
-- for one made from a colour. Nil for one it knows nothing about.
function mapper.envname(env)
    local name = mapper.envidsr and mapper.envidsr[env]
    if name then
        return name
    end
    local r, g, b = colourenv(env)
    return r and string.format("#%02X%02X%02X", r, g, b) or nil
end

-- Put a room on an environment. One made from a colour is given its colour
-- here, as a room is put on it, rather than on every arrival: Mudlet redraws
-- the whole map for each colour set, and keeps the colour in the map file, so
-- the map carries it from then on.
function mapper.setroomenv(id, env)
    local r, g, b = colourenv(env)
    if r then
        setCustomEnvColor(env, r, g, b, 255)
    end
    setRoomEnv(id, env)
end

-- Whether two environments are drawn in the same colour, as Mudlet's table of
-- environment colours has them. One missing from it is drawn in something else
-- entirely, so it matches nothing.
function mapper.sameenvcolour(a, b)
    local colours = getCustomEnvColorTable() or {}
    local ca, cb = colours[a], colours[b]
    if not ca or not cb then
        return false
    end
    for i = 1, 4 do
        if (ca[i] or 255) ~= (cb[i] or 255) then
            return false
        end
    end
    return true
end
