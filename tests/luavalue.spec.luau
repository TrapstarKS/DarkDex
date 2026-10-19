-- lune run tests/luavalue.spec
local LuaValue = require("../src/Core/LuaValue")
local roblox = require("@lune/roblox")

local Vector3, Color3, UDim2, CFrame, Enum = roblox.Vector3, roblox.Color3, roblox.UDim2, roblox.CFrame, roblox.Enum

local cases = {
	{ nil, "nil" },
	{ true, "true" },
	{ 0.5, "0.5" },
	{ math.huge, "math.huge" },
	{ 'a "b"\n', '"a \\"b\\"\\\n"' },
	{ Vector3.new(1, 2.5, -3), "Vector3.new(1, 2.5, -3)" },
	{ Color3.fromRGB(255, 128, 0), "Color3.fromRGB(255, 128, 0)" },
	{ UDim2.new(0.5, 10, 1, -4), "UDim2.new(0.5, 10, 1, -4)" },
	{ CFrame.new(1, 2, 3), "CFrame.new(1, 2, 3)" },
	{ Enum.Material.Plastic, "Enum.Material.Plastic" },
}

local failed = 0
for _, case in cases do
	local result = LuaValue.toLua(case[1])
	if result ~= case[2] then
		failed += 1
		print(`FAIL {tostring(case[1])}: expected {case[2]}, got {result}`)
	end
end

if failed > 0 then error(`{failed} case(s) failed`) end
print(`ok: {#cases} cases`)
