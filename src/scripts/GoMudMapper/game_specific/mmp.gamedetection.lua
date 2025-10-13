-- Game detection based on GMCP Game.Info
-- This handles both initial connection and reconnection after copyover
-- The mapper is GoMud-specific, so we only care about Game.Info.name

-- This is the event handler function that gets called by GMCP events
function mmp.gamedetection()
    -- Check if we have the necessary GMCP data
    if not gmcp or not gmcp.Game or not gmcp.Game.Info then
        if mmp.settings and mmp.settings.debug then
            mmp.echo("No GMCP Game.Info available for game detection")
        end
        return
    end
    
    local gameName = gmcp.Game.Info.name
    
    -- If no game name is specified, we can't identify the specific game
    if not gameName then
        if mmp.settings and mmp.settings.debug then
            mmp.echo("GMCP Game.Info.name not set - cannot identify game")
        end
        return
    end
    
    -- Set the game based on the name (always lowercase for consistency)
    local detectedGame = string.lower(gameName)
    
    -- Don't re-initialize if already set to the same game
    if mmp.game == detectedGame then
        return
    end
    
    -- Set the game
    mmp.setGame(detectedGame)
    
    -- Log what was detected
    mmp.echo(string.format("Connected to %s", gameName))
    
    -- Raise event for other scripts
    raiseEvent("mmp game detected", detectedGame)
end

-- Alias for backwards compatibility and manual calls
mmp.detectGameFromGMCP = mmp.gamedetection