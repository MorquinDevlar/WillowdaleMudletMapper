if matches[2] == "on" then
	mapper.debug = true
else
	mapper.debug = false
end

mapper.echo("Debug & performance telemetry " .. (mapper.debug and "enabled" or "disabled") .. ".")
