if mapper.newmapperversion then
	mapper.downloadmapperscript()
else
	mapper.echo("No update available. Use 'mapper check' to check for updates.")
end
