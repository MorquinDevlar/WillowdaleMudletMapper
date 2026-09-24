-- Tags: words the player puts on rooms so they can find their way back.
--
-- A tag is one word, stored in lower case. The map itself carries the list of
-- them, as a JSON object of name -> map symbol under the map user data key
-- "tags"; a tag with no symbol keeps an empty string there. Each tagged room
-- carries "tag-<name>" = "1", so searchRoomUserData finds every room with a tag
-- in one call rather than a walk over the map.
--
-- Tags replace the old "map features", which were the same idea written twice:
-- see mapper.migratetags at the bottom.

mapper = mapper or {}

-- The tag list as last read from the map. Every room the roomchar rules touch
-- asks for it, and re-parsing the JSON per room made refreshing the whole map
-- quadratic in the number of tags.
local cache

-- The same list worked out for reading rooms: every tag in name order with the
-- user data key a room carries it under, and apart from those the ones that
-- draw a symbol. Built once per change to the list rather than for every room.
local index

-- Forget the cached list: a different map has different tags.
function mapper.forgettags()
    cache = nil
    index = nil
end

function mapper.loadtags()
    if cache then
        return cache
    end
    local tags = {}
    local raw = getMapUserData("tags")
    if raw and raw ~= "" then
        local ok, decoded = pcall(yajl.to_value, raw)
        if ok and type(decoded) == "table" then
            for name, symbol in pairs(decoded) do
                tags[tostring(name)] = tostring(symbol or "")
            end
        end
    end
    cache = tags
    return tags
end

function mapper.savetags(tags)
    cache = tags
    index = nil
    -- yajl writes an empty table as [], which reads back as a list rather than
    -- as the object every other tag write expects
    if next(tags) == nil then
        clearMapUserDataItem("tags")
        return
    end
    setMapUserData("tags", yajl.to_string(tags))
end

-- A tag name as it is stored, or nil and what to tell the player. Digits alone
-- are refused because that is how a room is named, and `mapper goto 42` has to
-- go on meaning room 42.
function mapper.tagname(word)
    word = tostring(word or "")
    if word == "" then
        return nil, "Which tag? Use: mapper tag <name>"
    end
    if not word:match("^[%w_%-]+$") then
        return nil, "A tag name is one word of letters, digits, underscores or hyphens."
    end
    if tonumber(word) then
        return nil, "A tag name cannot be only digits - that is how a room is named."
    end
    return word:lower()
end

function mapper.istag(word)
    local name = mapper.tagname(word)
    return name ~= nil and mapper.loadtags()[name] ~= nil
end

local function tagindex()
    if index then
        return index
    end
    local tags = mapper.loadtags()
    local names = {}
    for name in pairs(tags) do
        names[#names + 1] = name
    end
    table.sort(names)
    local all, symbols = {}, {}
    for _, name in ipairs(names) do
        local tag = { name = name, key = "tag-" .. name, symbol = tags[name] or "" }
        all[#all + 1] = tag
        if tag.symbol ~= "" then
            symbols[#symbols + 1] = tag
        end
    end
    index = { all = all, symbols = symbols }
    return index
end

-- A tag name as typed, made the name it is stored under, or nil once the
-- player has been told what is wrong with it.
local function validtag(word)
    local name, why = mapper.tagname(word)
    if not name then
        mapper.echo(why)
    end
    return name
end

-- The same, for a command that needs the tag to exist already.
local function existingtag(word)
    local name = validtag(word)
    if name and mapper.loadtags()[name] == nil then
        mapper.echo("There is no '" .. name .. "' tag. 'mapper tags' lists them.")
        return nil
    end
    return name
end

-- The tags on one room, sorted by name. Pass the room's user data when the
-- caller already has it, which is what keeps a sweep over the map to one
-- getAllRoomUserData per room.
function mapper.roomtags(id, data)
    data = data or getAllRoomUserData(id) or {}
    local names = {}
    for _, tag in ipairs(tagindex().all) do
        if data[tag.key] == "1" then
            names[#names + 1] = tag.name
        end
    end
    return names
end

-- The one rule for what character a room draws on the map: the symbol of its
-- first tag that has one, else its biome symbol when the roomchar setting shows
-- it, else nothing. Tagging, untagging and the setting all go through here, so
-- they cannot disagree about what a room should be showing.
function mapper.roomsymbol(id, data)
    data = data or getAllRoomUserData(id) or {}

    -- Only the tags with a symbol can decide it, and they are in name order
    for _, tag in ipairs(tagindex().symbols) do
        if data[tag.key] == "1" then
            return tag.symbol
        end
    end

    local biome, symbol = data.biome, data.biome_symbol
    if biome and biome ~= "" and symbol and symbol ~= "" and mapper.shouldShowRoomChar(biome) then
        return symbol
    end
    return ""
end

-- Redraw one room's character after something that decides it changed.
-- Returns whether the character actually changed.
function mapper.refreshroomsymbol(id, data)
    local wanted = mapper.roomsymbol(id, data)
    if getRoomChar(id) == wanted then
        return false
    end
    setRoomChar(id, wanted)
    return true
end

-- The room a tag command works on: the one named, or the one we are standing in.
local function targetroom(arg, verb)
    if arg and arg ~= "" then
        local id = tonumber(arg)
        if not id then
            mapper.echo("Not a room ID: " .. tostring(arg))
            return nil
        end
        if not roomExists(id) then
            mapper.echo("Room " .. id .. " doesn't exist.")
            return nil
        end
        return id
    end
    local room = mapper.inmappedroom()
    if not room then
        mapper.echo("You are not in a mapped room. Name one: mapper " .. verb .. " <name> <room id>")
    end
    return room
end

--------------------------------------------------------------------------------
-- Putting tags on and taking them off
--------------------------------------------------------------------------------

-- The tag named last, which is the one the map menu's "Tag this room" applies.
mapper.lasttag = mapper.lasttag or nil

function mapper.tagroom(word, roomarg)
    local name = validtag(word)
    if not name then
        return
    end
    local room = targetroom(roomarg, "tag")
    if not room then
        return
    end

    local tags = mapper.loadtags()
    local isnew = tags[name] == nil
    if isnew then
        tags[name] = ""
        mapper.savetags(tags)
    end
    mapper.lasttag = name

    if getRoomUserData(room, "tag-" .. name) == "1" then
        mapper.echo(string.format("%s already carries the '%s' tag.", mapper.roomName(room, true), name))
        return
    end

    setRoomUserData(room, "tag-" .. name, "1")
    mapper.refreshroomsymbol(room)
    mapper.mapinfodirty()
    mapper.echo(string.format("Tagged %s as '%s'.%s", mapper.roomName(room, true), name,
        isnew and " That is a new tag - 'mapper tag " .. name .. " symbol <char>' gives it a map symbol." or ""))
end

function mapper.untagroom(word, roomarg)
    local name = validtag(word)
    if not name then
        return
    end
    local room = targetroom(roomarg, "untag")
    if not room then
        return
    end

    if getRoomUserData(room, "tag-" .. name) ~= "1" then
        mapper.echo(string.format("%s does not carry the '%s' tag.", mapper.roomName(room, true), name))
        return
    end

    clearRoomUserDataItem(room, "tag-" .. name)
    mapper.refreshroomsymbol(room)
    mapper.mapinfodirty()
    mapper.lasttag = name
    mapper.echo(string.format("Took the '%s' tag off %s.", name, mapper.roomName(room, true)))
end

-- Give a tag the character its rooms draw on the map, or take it away again.
function mapper.tagsymbol(word, char)
    local name = existingtag(word)
    if not name then
        return
    end

    local tags = mapper.loadtags()

    local usage = "Use: mapper tag " .. name .. " symbol <char>, or 'none' to take it away."
    if not char or char == "" then
        mapper.echo("Which character? " .. usage)
        return
    end

    if char:lower() == "none" then
        char = ""
    else
        -- A room draws one character, and the biome symbols are single ones too
        local width = (utf8 and utf8.len and utf8.len(char)) or #char
        if width ~= 1 then
            mapper.echo("A tag symbol is one character. " .. usage)
            return
        end
    end

    tags[name] = char
    mapper.savetags(tags)

    for _, id in ipairs(searchRoomUserData("tag-" .. name, "1") or {}) do
        mapper.refreshroomsymbol(id)
    end

    if char == "" then
        mapper.echo("The '" .. name .. "' tag no longer draws a symbol on the map.")
    else
        mapper.echo("Rooms tagged '" .. name .. "' now show " .. char .. " on the map.")
    end
end

--------------------------------------------------------------------------------
-- Reading them back
--------------------------------------------------------------------------------

function mapper.listtags()
    local tags = mapper.loadtags()
    local names = {}
    for name in pairs(tags) do
        names[#names + 1] = name
    end
    if #names == 0 then
        mapper.echo("No tags yet. 'mapper tag <name>' puts one on the room you are in.")
        return
    end
    table.sort(names)

    local rows = {}
    for _, name in ipairs(names) do
        rows[#rows + 1] = {
            {
                text = name,
                link = [[mapper.listtagrooms("]] .. name .. [[")]],
                hint = "List the rooms tagged '" .. name .. "'",
            },
            #(searchRoomUserData("tag-" .. name, "1") or {}),
            tags[name] or "",
        }
    end

    mapper.printtable({
        { title = "Name:" },
        { title = "Rooms:", align = "right" },
        { title = "Symbol:" },
    }, rows, { title = "Tags:" })
end

function mapper.listtagrooms(word)
    local name = existingtag(word)
    if not name then
        return
    end

    local rooms = searchRoomUserData("tag-" .. name, "1") or {}
    if #rooms == 0 then
        mapper.echo("No room carries the '" .. name .. "' tag.")
        return
    end
    table.sort(rooms)

    local rows = {}
    for _, id in ipairs(rooms) do
        rows[#rows + 1] = {
            id,
            mapper.roomName(id),
            mapper.roomareaname(id) or "?",
            {
                text = "Go to",
                link = [[mapper.gotoRoom(]] .. id .. [[)]],
                hint = "Navigate to this room",
                color = { 0, 200, 0 },
            },
        }
    end

    mapper.printtable({
        { title = "ID:" },
        { title = "Name:" },
        { title = "Area:" },
        { title = "" },
    }, rows, { title = string.format("Rooms tagged '%s' (%d):", name, #rows) })
end

-- Walk to whichever room carrying this tag is quickest to reach.
function mapper.gotoTag(word)
    local name = existingtag(word)
    if not name then
        return
    end

    local rooms = searchRoomUserData("tag-" .. name, "1") or {}
    if #rooms == 0 then
        mapper.echo("No room carries the '" .. name .. "' tag yet.")
        return
    end
    mapper.gotoNearest(rooms, string.format("to a room tagged '%s'", name))
end

--------------------------------------------------------------------------------
-- Migration
--------------------------------------------------------------------------------

-- An old feature or mark name as a tag name. Those were free text, so anything
-- a tag name cannot hold becomes a hyphen rather than costing the whole name:
-- a feature called "Post Office" comes across as "post-office".
local function migratedname(word)
    word = tostring(word or ""):lower()
    word = word:gsub("[^%w_%-]+", "-")
    word = word:gsub("^%-+", "")
    word = word:gsub("%-+$", "")
    if word == "" or tonumber(word) then
        return nil
    end
    return word
end

-- Two older ways of writing a name on a room, turned into tags.
--
-- "mapFeatures" was the same list under another name, with the room flag
-- "feature-<name>" = "true". "gotoMapping" was a JSON object of mark name ->
-- room ID kept on room 1, whichever room that was - the command that wrote it
-- created room 1 out of nothing if the map had none, which is the phantom this
-- deletes once its marks are safe.
function mapper.migratetags()
    -- A map has just loaded, or is loading; whatever was cached belongs to the
    -- one before it.
    mapper.forgettags()

    local tags = mapper.loadtags()
    -- The rooms given a tag here, whose character the tag may now decide
    local migrated, touched = 0, {}

    local features = getMapUserData("mapFeatures")
    if features and features ~= "" then
        local ok, decoded = pcall(yajl.to_value, features)
        if ok and type(decoded) == "table" then
            for feature, symbol in pairs(decoded) do
                local name = migratedname(feature)
                if name then
                    if tags[name] == nil then
                        tags[name] = tostring(symbol or "")
                        migrated = migrated + 1
                    end
                    for _, id in ipairs(searchRoomUserData("feature-" .. feature, "true") or {}) do
                        setRoomUserData(id, "tag-" .. name, "1")
                        clearRoomUserDataItem(id, "feature-" .. feature)
                        touched[id] = true
                    end
                end
            end
        end
        clearMapUserDataItem("mapFeatures")
    end

    local marks = roomExists(1) and getRoomUserData(1, "gotoMapping") or ""
    if marks and marks ~= "" then
        local ok, decoded = pcall(yajl.to_value, marks)
        if ok and type(decoded) == "table" then
            for mark, id in pairs(decoded) do
                local name = migratedname(mark)
                id = tonumber(id)
                if name and id and roomExists(id) then
                    if tags[name] == nil then
                        tags[name] = ""
                        migrated = migrated + 1
                    end
                    setRoomUserData(id, "tag-" .. name, "1")
                    touched[id] = true
                end
            end
        end
        clearRoomUserDataItem(1, "gotoMapping")

        -- Room 1 was only ever a place to hang that key on if it has nothing
        -- else about it
        local name = getRoomName(1)
        local area = getRoomArea(1)
        if (not name or name == "") and next(getRoomExits(1) or {}) == nil
            and not next(getSpecialExits(1) or {}) and (not area or area <= 0) then
            deleteRoom(1)
            -- A room has gone, so routes worked out through it are worthless
            raiseEvent("mapper updated map")
        end
    end

    if migrated > 0 then
        mapper.savetags(tags)
    end
    if next(touched) then
        -- Before the settings are loaded there is no roomchar mode to draw by,
        -- so the rooms wait for mapper.syncmap to redraw them
        for id in pairs(touched) do
            if not mapper.optionsloaded then
                mapper.deferroom(id)
            elseif roomExists(id) then
                mapper.refreshroomsymbol(id)
            end
        end
        mapper.mapinfodirty()
    end
    if migrated > 0 then
        mapper.notify(string.format("Turned %d map feature%s into tag%s - 'mapper tags' lists them.",
            migrated, migrated == 1 and "" or "s", migrated == 1 and "" or "s"))
    end
end
