--[[
	UniversalSynSaveInstance, downloaded on first use instead of at startup.
]]

local Http = require("@core/Http")

local SOURCE_URL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau"

local saveinstance: ((options: { [string]: any }) -> ())?

local SaveInstance = {}

function SaveInstance.get(): (options: { [string]: any }) -> ()
	if saveinstance then return saveinstance end

	local source = Http.get(SOURCE_URL) or error("Could not download SynSaveInstance")
	-- Renamed so the executor's own RequireOnlineModule global is not used by the module
	source = string.gsub(source, "RequireOnlineModule", "DarkDexRequireOnlineModule")

	local chunk, compileError = loadstring(source, "saveinstance")
	if not chunk then error(`Could not compile SynSaveInstance: {compileError}`) end

	saveinstance = chunk()
	return saveinstance :: any
end

function SaveInstance.run(options: { [string]: any }) SaveInstance.get()(options) end

return SaveInstance
