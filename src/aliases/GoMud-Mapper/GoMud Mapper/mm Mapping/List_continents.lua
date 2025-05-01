local continents = mmp.getcontinents()

if not next(continents) then mmp.echo("No continents known.")
else
  for continent, areadata in pairs(continents) do
    mmp.echo(continent.." continent:")

    for _, areaid in ipairs(areadata) do
      cecho("  "..getRoomAreaName(areaid).."\n")
    end
  end
end