if matches[2] == "on" then
	mmp.debug = true
else
	mmp.debug = false
end

mmp.echo("Debug & performance telemetry " .. (mmp.debug and "enabled" or "disabled") .. ".")
