-- Function to set the game, ensuring it's always lowercase
function mmp.setGame(gameName)
    if gameName and type(gameName) == "string" then
        mmp.game = string.lower(gameName)
        
        -- Initialize game-specific data if needed
        if mmp.game == "gomud" and mmp.registergomudenvdata then
            mmp.registergomudenvdata(nil, mmp.game)
        end
        
        if mmp.settings and mmp.settings.debug then
            mmp.echo(string.format("Game set to: %s", mmp.game))
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