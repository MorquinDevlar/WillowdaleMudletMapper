-- What the game says when a move does not simply happen.
--
-- Three GMCP signals cover it: Room.Wrongdir when the exit itself could not be
-- used, Room.MoveBlocked when the player cannot move at all whatever exit they
-- picked, and Room.MoveDelayed when the move was accepted but lands later. Each
-- carries a stable reason code, because a speedwalk has to tell "this way is
-- shut, find another" apart from "wait" and from "give up" - and the ordinary
-- game text that a person reads says which is which only to a person.

-- Why the player cannot move at all, in the mapper's own words. The game has
-- already printed its version to the screen, so these stay short.
local blockedReasons = {
	melee = "you are in melee",
	combat = "you are in combat",
	unconscious = "you are unconscious",
	downed = "you are down and still being attacked",
	restrained = "something is holding you",
	["exit-refused"] = "the room will not let you leave",
	["entry-refused"] = "the way ahead will not let you in",
	["in-transit"] = "the way onward is still underway",
}

-- Head for the same destination again, now that one more thing about the map is
-- known. Every caller shuts the offending exit first, so a fresh path cannot
-- pick the same one and the walk converges rather than looping.
local function repath(what)
	if not mapper.autowalking or #mapper.speedWalkPath == 0 then
		return
	end
	local destination = mapper.speedWalkPath[#mapper.speedWalkPath]
	-- the exit that just changed may be on a cached path
	mapper.clearpathcache()
	if mapper.getPath(mapper.currentroom, destination) then
		mapper.notify(what .. " Going around.")
		mapper.gotoRoom(destination)
	else
		mapper.notify(string.format("%s No other way to %s (%d) from here.", what, getRoomName(destination), destination))
		mapper.stop()
	end
end

-- An exit could not be used. Only the walk cares; walking into a wall by hand is
-- the player's own business.
function mapper.wrongdir_handler()
	local signal = gmcp.Room and gmcp.Room.Wrongdir
	if not signal or not mapper.autowalking or #mapper.speedWalkPath == 0 then
		return
	end
	local dir = signal.dir or "that way"
	local room = mapper.currentroom

	if signal.reason == "locked" then
		-- The door is shut to us after all - the lock had relocked, or the key is
		-- gone. Record that before repathing, or the same route comes straight back.
		if mapper.isStandardExit(dir) then
			mapper.lockExit(room, dir, true)
		else
			local destination = tonumber((getSpecialExitsSwap(room) or {})[dir])
			if destination then
				mapper.lockSpecialExit(room, destination, dir, true)
			end
		end
		repath(string.format("The %s exit is locked and we cannot open it.", dir))
	elseif signal.reason == "noexit" and mapper.isStandardExit(dir) then
		-- The map believes in an exit the room does not have.
		mapper.setExit(room, -1, dir)
		repath(string.format("There is no %s exit here after all.", dir))
	else
		-- A room script claimed the direction, or an older server sent no reason.
		mapper.notify(string.format('Cannot go "%s" from here.', dir))
		mapper.stop()
	end
end

-- The player cannot move at present, whichever way they face.
function mapper.moveblocked_handler()
	local signal = gmcp.Room and gmcp.Room.MoveBlocked
	if not signal or not mapper.autowalking then
		return
	end

	if signal.reason == "unbalanced" then
		-- Not a refusal so much as a "not yet"; canmove polls and resumes the walk,
		-- and the move it resends arms a fresh watchdog, so this one would only be
		-- counting down against a move nobody has made yet.
		mapper.disarmwatchdog()
		mapper.canmove(true)
		return
	end

	if signal.reason == "in-transit" then
		-- A move already accepted is still landing. Say so and keep waiting for the
		-- room change: stopping here would abandon a walk that is about to continue.
		-- The wait starts again from here, since this is the last we have heard.
		mapper.notify("Waiting - " .. blockedReasons["in-transit"] .. ".")
		mapper.armwatchdog()
		return
	end

	mapper.notify("Cannot move - " .. (blockedReasons[signal.reason] or "the game will not let you") .. ".")
	mapper.stop()
end

-- The move was accepted but arrives after a wait. Nothing has gone wrong, so the
-- walk keeps waiting for the room change; this only says so, since a silent
-- pause mid-walk reads as a mapper that has hung.
function mapper.movedelayed_handler()
	local signal = gmcp.Room and gmcp.Room.MoveDelayed
	if not signal or not mapper.autowalking then
		return
	end
	local seconds = tonumber(signal.seconds)
	if not seconds or seconds <= 0 then
		return
	end
	if mapper.settings and mapper.settings.showcmds then
		mapper.notify(string.format("Waiting %ds for the way %s.", seconds, signal.dir or "onward"))
	end
	-- The watchdog was armed for a move that lands straight away. This one has
	-- been promised for later, so it gets the wait the game named on top.
	mapper.armwatchdog(signal.dir, seconds)
end
