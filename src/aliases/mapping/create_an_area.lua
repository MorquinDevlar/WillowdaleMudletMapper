local t = getAreaTable()
local tr = {}
for k, v in pairs(t) do
	tr[v] = k
end
local newid = table.maxn(tr) + 1

setAreaName(newid, matches[2])
mapper.echo(string.format("Created new area %s (%d)", matches[2], newid))
centerview(mapper.currentroom)
raiseEvent("mapper areas changed")
