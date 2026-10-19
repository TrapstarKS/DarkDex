--[[
	getgenv().prettyPrint(value): readable serialization of tables for the console.
	Thanks corewave for the original version.
]]

local getmetatable = getrawmetatable or getmetatable

-- tostring that ignores a custom __tostring, so tables show their address
local function rawToString(value: any): string
	local metatable = getmetatable(value)
	if type(metatable) ~= "table" then return tostring(value) end

	local custom = rawget(metatable, "__tostring")
	if custom == nil then return tostring(value) end

	local cleared = pcall(rawset, metatable, "__tostring", nil)
	if not cleared then return tostring(value) end

	local result = tostring(value)
	rawset(metatable, "__tostring", custom)
	return result
end

local function formatValue(value: any): string
	local valueType = typeof(value)
	if valueType == "string" then return string.format("%q", value) end
	if valueType == "Instance" then return value:GetFullName() end
	if valueType == "table" or valueType == "userdata" then return rawToString(value) end
	if valueType == "boolean" or valueType == "function" or valueType == "number" or valueType == "nil" then return tostring(value) end
	return `{valueType}.new({value})`
end

local function serialize(value: any, depth: number, visiting: { [any]: boolean }): string
	if type(value) ~= "table" then return formatValue(value) end
	if visiting[value] then return `{rawToString(value)} --[[cycle]]` end
	if next(value) == nil then return "{}" end

	visiting[value] = true

	local indent = string.rep("  ", depth)
	local lines = { "{" }
	for key, item in value do
		table.insert(lines, `{indent}[{serialize(key, depth + 1, visiting)}] = {serialize(item, depth + 1, visiting)},`)
	end
	table.insert(lines, string.rep("  ", depth - 1) .. "}")

	visiting[value] = nil
	return table.concat(lines, "\n")
end

local PrettyPrint = {}

function PrettyPrint.serialize(value: any): string return serialize(value, 1, {}) end

function PrettyPrint.install()
	if getgenv then getgenv().prettyPrint = PrettyPrint.serialize end
end

return PrettyPrint
