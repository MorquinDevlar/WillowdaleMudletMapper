function mmp.doLock(what, lock, filter)
  if what then mmp.echo(string.format("%s all %s...", (lock and "Locking" or "Unlocking"), what)) end
  local c = 0

  local getAreaRooms, getSpecialExits, lockSpecialExit, next = getAreaRooms, getSpecialExits, lockSpecialExit, next
  for _, area in pairs(getAreaTable()) do
    local rooms = getAreaRooms(area) or {}
    for i = 0, #rooms do
      local exits = getSpecialExits(rooms[i] or 0)

       if exits and next(exits) then
         for exit, cmd in pairs(exits) do
           if type(cmd) == "table" then cmd = next(cmd) end

           if (not filter and not (cmd:lower():find("pathfind", 1, true) or cmd:lower():find("worm warp", 1, true) or cmd:lower():find("enter grate", 1, true))) or (filter and cmd:lower():find(filter, 1, true)) then
             lockSpecialExit(rooms[i], exit, cmd, lock)
             c = c + 1
           end
         end
       end
    end
  end

  if what then mmp.echo(string.format("%s %s known %s.", (lock and "Locked" or "Unlocked"), c, what)) end
  return c
end

function mmp.changeEchoColour()
    mmp.echo("Now displaying echos in <"..mmp.settings.echocolour..">"..mmp.settings.echocolour )
end

function mmp.changeLaglevel()
    local laglevel = mmp.settings.laglevel
    local laginfo = mmp.lagtable[laglevel]
    mmp.echo(string.format("Lag level set to [%d]: %s (%ss timer)", laglevel, laginfo.description, tostring(laginfo.time)))
end

function mmp.verifyLaglevel(value)
  if mmp.lagtable[value] then return true end
  return false
end

-- GoMud-specific lock functions can be added here

function mmp.lockSpecials()
  local lock = mmp.settings.lockspecials and true or false
  mmp.doLock("special exits", lock)
end


function mmp.changeMapSource()
  local use = mmp.settings.crowdmap and true or false
  if use and mmp.game ~= "gomud" then
    mmp.echo("Crowdsourced map support for GoMud is not yet available.")
    mmp.settings.crowdmap = false
  elseif use and not loadMap then
   mmp.echo("Sorry - your Mudlet is too old and can't load maps. Please update: http://forums.mudlet.org/viewtopic.php?f=5&t=1874")
   mmp.settings.crowdmap = false
  elseif use then
    mmp.echo("Will use the crowdsourced map for updates instead!")
    mmp.checkforupdate()
  else
    mmp.echo("Will use the default game map for updates.")
  end
end


function mmp.setSlowWalk()
  if mmp.settings.slowwalk then
    mmp.echo("Will walk 'slowly' - that is, only try to move in a direction once per room, and move again once we've arrived. This will make us better walkers when it's very laggy, as we won't spam directions unnecessarily and miss certain turns - but it does mean that if we fail to move for some reason, we won't retry again either at all.")
  else
    mmp.echo("Will walk as quick as we can!")
  end
end

-- GoMud-specific settings functions can be added here

