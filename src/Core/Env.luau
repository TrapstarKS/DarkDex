--[[
	Executor capability detection.

	Every optional executor function is read once into Context.env. A missing function
	is left nil and its name is recorded in Main.MissingEnv, so features can check
	`env.name` instead of touching executor globals directly.
]]

local Context = require("@core/Context")

local env = Context.env
local Main = Context.Main

local function base64encode(data: string): string
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = table.create(math.ceil(#data / 3) * 4)

	for index = 1, #data, 3 do
		local a, b, c = string.byte(data, index, index + 2)
		local chunk = bit32.bor(bit32.lshift(a, 16), bit32.lshift(b or 0, 8), c or 0)
		for slot = 0, 3 do
			if slot <= 1 or (slot == 2 and b) or (slot == 3 and c) then
				local sextet = bit32.band(bit32.rshift(chunk, (3 - slot) * 6), 63)
				table.insert(output, string.sub(alphabet, sextet + 1, sextet + 1))
			else
				table.insert(output, "=")
			end
		end
	end

	return table.concat(output)
end

local Env = {}

function Env.init()
	Main.MissingEnv = {}

	local function define(name: string, value: any)
		if value == nil then
			table.insert(Main.MissingEnv, name)
			return
		end
		env[name] = value
	end

	-- Filesystem
	define("readfile", readfile)
	define("writefile", writefile)
	define("makefolder", makefolder)
	define("isfile", isfile)
	define("isfolder", isfolder)
	define("movefileas", movefileas)
	define("getcustomasset", getcustomasset or getsynasset)

	-- Inspection
	define("getscriptbytecode", getscriptbytecode or dumpstring)
	define("decompile", decompile)
	define("getnilinstances", getnilinstances or get_nil_instances)
	define("getloadedmodules", getloadedmodules)
	define("saveinstance", saveinstance)

	-- Other
	define("request", (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request)
	define("protectgui", protect_gui or (syn and syn.protect_gui))
	define("gethui", gethui or get_hidden_gui)
	define("setclipboard", setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set))

	local crypt = crypt or (syn and syn.crypt)
	env.base64encode = (crypt and (crypt.base64encode or crypt.base64_encode)) or base64_encode or base64encode
end

return Env
