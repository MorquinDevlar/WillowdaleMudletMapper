function mapper.changeBoolFunc(name, option)
	local en
	en = option and "will now use" or "will no longer use"
	mapper.echo("<green>Okay, the mapper " .. en .. " <white>" .. name .. "<green>!")
end
