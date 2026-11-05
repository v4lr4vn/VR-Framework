local LEVEL_PREFIXES = {
	"^1[ERROR]",
	"^3[WARNING]",
	"^7[INFO]",
	"^4[VERBOSE]",
	"^6[DEBUG]",
}

local CURRENT_RESOURCE_NAME = GetCurrentResourceName()
local CONVAR_PRINT_LEVEL = GetConvarInt(CURRENT_RESOURCE_NAME .. ":printlevel", GetConvarInt("global:printlevel", 3))
local RESOURCE_PRINT_LEVEL = type(CONVAR_PRINT_LEVEL) == "number" and math.max(1, math.min(CONVAR_PRINT_LEVEL, 5)) or 3
local TEMPLATE = "%s %s^7"

local function processValue(value)
	if type(value) == "function" then
		return tostring(value)
	end

	if type(value) == "nil" then return "nil" end

	return tostring(value)
end

local function processArgs(...)
	local args = { ... }
	local argsLen = select("#", args)

	if argsLen <= 0 then
		return args
	end

	for i = 1, argsLen do
		args[i] = processValue(args[i])
	end

	return args
end

local function buildLogMessage(level, ...)
	if not LEVEL_PREFIXES[level] or level > RESOURCE_PRINT_LEVEL then return end

	return TEMPLATE:format(LEVEL_PREFIXES[level], table.unpack(processArgs(...)))
end

local function buildLogfMessage(level, string, ...)
	if not LEVEL_PREFIXES[level] or level > RESOURCE_PRINT_LEVEL then return end

	return TEMPLATE:format(LEVEL_PREFIXES[level], string:format(table.unpack(processArgs(...))))
end

return {
	error = function(...)
		local msg = buildLogMessage(1, ...)

		if not msg then return end

		error(msg, 2)
	end,
	errorf = function(...)
		local msg = buildLogfMessage(1, ...)

		if not msg then return end

		error(msg, 2)
	end,
	warning = function(...)
		local msg = buildLogMessage(2, ...)

		if not msg then return end

		print(msg)
	end,
	warningf = function(...)
		local msg = buildLogfMessage(2, ...)

		if not msg then return end

		print(msg)
	end,
	info = function(...)
		local msg = buildLogMessage(3, ...)

		if not msg then return end

		print(msg)
	end,
	infof = function(...)
		local msg = buildLogfMessage(3, ...)

		if not msg then return end

		print(msg)
	end,
	verbose = function(...)
		local msg = buildLogMessage(4, ...)

		if not msg then return end

		print(msg)
	end,
	verbosef = function(...)
		local msg = buildLogfMessage(4, ...)

		if not msg then return end

		print(msg)
	end,
	debug = function(...)
		local msg = buildLogMessage(5, ...)

		if not msg then return end

		print(msg)
	end,
	debugf = function(...)
		local msg = buildLogfMessage(5, ...)

		if not msg then return end

		print(msg)
	end
}
