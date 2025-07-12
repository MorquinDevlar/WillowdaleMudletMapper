-- Alias to show current game detection status
if mmp.game then
    mmp.echo(string.format("Game detected: %s", mmp.game))
    
    -- Show if there are any game-specific features enabled
    local gameSpecificOptions = {}
    for name, def in pairs(mmp.option_definitions or {}) do
        if def.games and table.contains(def.games, mmp.game) then
            table.insert(gameSpecificOptions, name)
        end
    end
    
    if #gameSpecificOptions > 0 then
        mmp.echo(string.format("Game-specific options available: %s", table.concat(gameSpecificOptions, ", ")))
    end
else
    mmp.echo("No game detected yet.")
    mmp.echo("The mapper will try to detect your game from GMCP when you connect.")
    mmp.echo("Your game should set gmcp.Game.Info.engine to identify itself.")
    
    -- Show current GMCP status if available
    if gmcp and gmcp.Game and gmcp.Game.Info then
        if gmcp.Game.Info.engine then
            mmp.echo(string.format("GMCP reports engine as: %s", gmcp.Game.Info.engine))
            mmp.echo("Try reconnecting to properly initialize the mapper.")
        else
            mmp.echo("GMCP is available but engine is not set.")
        end
    else
        mmp.echo("No GMCP game information available.")
    end
end