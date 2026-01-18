-------------------------------------------------
--         Put your Lua functions here.        --
--                                             --
-- Note that you can also use external Scripts --
-------------------------------------------------

-- Check if the player can move based on GMCP balance data
-- Returns true if balanced, false if off-balance
function mapper.mapperCanMove()
	if gmcp and gmcp.Char and gmcp.Char.Balance then
		return gmcp.Char.Balance.is_balanced == true
	end
	-- Default to true if no balance data available yet
	return true
end
