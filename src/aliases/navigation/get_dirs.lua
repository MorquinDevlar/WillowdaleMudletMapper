if not matches[2] and not matches[3] then
	mapper.echo("Where do you want to showpath to?")
elseif matches[2] and not matches[3] then
	mapper.echoPath(mapper.currentroom, matches[2])
else
	mapper.echoPath(matches[2], matches[3])
end
