mapper.getPathPerf = mapper.getPathPerf or createStopWatch()
startStopWatch(mapper.getPathPerf)

local from, to = tonumber(matches[2]), tonumber(matches[3])

getPath(from, to)

mapper.echon = mapper.echon or echo
mapper.echon(
	"a new getPath() from "
		.. from
		.. " to "
		.. to
		.. " took "
		.. stopStopWatch(mapper.getPathPerf)
		.. "s. There are "
		.. #speedWalkPath
		.. " rooms to visit in it."
)
echo(" ")
echoLink(
	"[unhighlight]",
	[[
  for room in pairs(mapper.getpathhighlights) do
    unHighlightRoom(room)
  end
]],
	"Click me to remove highlighting from getpath"
)

mapper.getpathhighlights = mapper.getpathhighlights or {}

for room in pairs(mapper.getpathhighlights) do
	unHighlightRoom(room)
end

mapper.getpathhighlights = {}

local r, g, b = unpack(color_table.yellow)
local br, bg, bb = unpack(color_table.yellow)
-- add the first room to the speedWalkPath, as we'd like it highlighted as well
table.insert(speedWalkPath, 1, from)
for i = 1, #speedWalkPath do
	local room = speedWalkPath[i]
	highlightRoom(room, r, g, b, br, bg, bb, 1, 255, 255)
	mapper.getpathhighlights[room] = true
end

centerview(from)
