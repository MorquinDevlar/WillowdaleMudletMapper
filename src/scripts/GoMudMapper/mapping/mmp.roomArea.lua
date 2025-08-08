function mmp.roomArea(otherroom, name, exact)
  local id, fname, ma
  if tonumber(name) then
    id = tonumber(name);
    fname = mmp.areatabler[id]
  else
    id, fname, ma = mmp.findAreaID(name, exact)
  end
  if otherroom ~= "" and not mmp.roomexists(otherroom) then
    mmp.echo("Room id " .. otherroom .. " doesn't seem to exist.")
    return
  elseif otherroom == "" and not mmp.roomexists(mmp.currentroom) then
    mmp.echo("Don't know where we are at the moment.")
    return
  end
  otherroom = otherroom ~= "" and otherroom or mmp.currentroom
  if id then
    setRoomArea(otherroom, id)
    mmp.echo(
      string.format(
        "Moved %s to %s (%d).",
        (getRoomName(otherroom) ~= "" and getRoomName(otherroom) or "''"),
        fname,
        id
      )
    )
    centerview(otherroom)
  elseif next(ma) then
    mmp.echo("Into which area exactly would you like to move the room?")
    fg("DimGrey")
    for _, name in ipairs(ma) do
      echo("  ")
      setUnderline(true)
      echoLink(
        name, [[mmp.roomArea('', "]] .. name .. [[", true)]], "Move the room to " .. name, true
      )
      setUnderline(false)
      echo("\n")
    end
    resetFormat()
  else
    mmp.echo("Don't know of that area.")
  end
end