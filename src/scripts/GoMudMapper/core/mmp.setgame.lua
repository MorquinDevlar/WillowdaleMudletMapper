-- Function to set the game, ensuring it's always lowercase
function mmp.setGame(gameName)
    if gameName and type(gameName) == "string" then
        mmp.game = string.lower(gameName)

        -- Initialize game-specific features based on the game name
        -- For example, "willowdale" might have different features than other GoMud games
        if mmp.game and mmp["register_" .. mmp.game .. "_features"] then
            -- Call game-specific initialization if it exists
            mmp["register_" .. mmp.game .. "_features"]()
        end

        -- Register environment data for GoMud-based games
        if gmcp and gmcp.Game and gmcp.Game.Info and gmcp.Game.Info.engine == "GoMud" then
            if mmp.registergomudenvdata then
                mmp.registergomudenvdata(nil, mmp.game)
            end
        end

        -- Raise events for other scripts that might need to know
        raiseEvent("mmp game detected", mmp.game)
        raiseEvent("mmp logged in", mmp.game)
    else
        mmp.game = false
        if mmp.settings and mmp.settings.debug then
            mmp.echo("Game detection cleared")
        end
    end
end