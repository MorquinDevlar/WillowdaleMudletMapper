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
        
        -- Raise event for other scripts that might need to know
        raiseEvent("mmp game detected", mmp.game)
    else
        mmp.game = false
        if mmp.settings and mmp.settings.debug then
            mmp.echo("Game detection cleared")
        end
    end
end