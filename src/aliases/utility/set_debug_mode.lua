-- Shorthand for `mapper option debug on|off`: one debug switch, persisted and
-- echoed by the option system rather than tracked in a flag of its own.
mapper.settings:setOption("debug", matches[2])
