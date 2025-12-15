function mapper.roomArea(otherroom, name, exact)
  local id, fname, ma
  if tonumber(name) then
    id = tonumber(name);
    fname = mapper.areatabler[id]
  else
    id, fname, ma = mapper.findAreaID(name, exact)
  end
  if otherroom ~= "" and not mapper.roomexists(otherroom) then
    mapper.echo("Room id " .. otherroom .. " doesn't seem to exist.")
    return
  elseif otherroom == "" and not mapper.roomexists(mapper.currentroom) then
    mapper.echo("Don't know where we are at the moment.")
    return
  end
  otherroom = otherroom ~= "" and otherroom or mapper.currentroom
  if id then
    setRoomArea(otherroom, id)
    mapper.echo(
      string.format(
        "Moved %s to %s (%d).",
        (getRoomName(otherroom) ~= "" and getRoomName(otherroom) or "''"),
        fname,
        id
      )
    )
    centerview(otherroom)
  elseif next(ma) then
    mapper.echo("Into which area exactly would you like to move the room?")
    fg("DimGrey")
    for _, name in ipairs(ma) do
      echo("  ")
      setUnderline(true)
      echoLink(
        name, [[mapper.roomArea('', "]] .. name .. [[", true)]], "Move the room to " .. name, true
      )
      setUnderline(false)
      echo("\n")
    end
    resetFormat()
  else
    mapper.echo("Don't know of that area.")
  end
end