--[[
	Converts property values to Luau source, e.g. Vector3.new(1, 2, 3), for "Copy as Lua".

	Instances need a path, so the caller passes instancePath; without it they become nil
	with a comment.
]]

local LuaValue = {}

local function number(value: number): string
	if value ~= value then return "0 / 0" end
	if value == math.huge then return "math.huge" end
	if value == -math.huge then return "-math.huge" end
	return tostring(value)
end

local function numbers(...: number): string
	local parts = table.pack(...)
	for index = 1, parts.n do
		parts[index] = number(parts[index])
	end
	return table.concat(parts, ", ", 1, parts.n)
end

local function color(value: Color3): string
	local r, g, b = value.R * 255, value.G * 255, value.B * 255
	local isWhole = math.abs(r - math.round(r)) < 1e-3 and math.abs(g - math.round(g)) < 1e-3 and math.abs(b - math.round(b)) < 1e-3
	if isWhole then return `Color3.fromRGB({math.round(r)}, {math.round(g)}, {math.round(b)})` end
	return `Color3.new({numbers(value.R, value.G, value.B)})`
end

function LuaValue.toLua(value: any, instancePath: ((Instance) -> string)?): string
	local valueType = typeof(value)

	if value == nil then
		return "nil"
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "number" then
		return number(value)
	elseif valueType == "string" then
		return string.format("%q", value)
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif valueType == "Instance" then
		return instancePath and instancePath(value) or `nil --[[ {value:GetFullName()} ]]`
	elseif valueType == "Vector3" or valueType == "Vector3int16" then
		return `{valueType}.new({numbers(value.X, value.Y, value.Z)})`
	elseif valueType == "Vector2" or valueType == "Vector2int16" then
		return `{valueType}.new({numbers(value.X, value.Y)})`
	elseif valueType == "Color3" then
		return color(value)
	elseif valueType == "UDim" then
		return `UDim.new({numbers(value.Scale, value.Offset)})`
	elseif valueType == "UDim2" then
		return `UDim2.new({numbers(value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)})`
	elseif valueType == "CFrame" then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
		if r00 == 1 and r11 == 1 and r22 == 1 and r01 == 0 and r02 == 0 and r10 == 0 and r12 == 0 and r20 == 0 and r21 == 0 then return `CFrame.new({numbers(x, y, z)})` end
		return `CFrame.new({numbers(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)})`
	elseif valueType == "BrickColor" then
		return `BrickColor.new({string.format("%q", value.Name)})`
	elseif valueType == "NumberRange" then
		return `NumberRange.new({numbers(value.Min, value.Max)})`
	elseif valueType == "Rect" then
		return `Rect.new({numbers(value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)})`
	elseif valueType == "NumberSequence" then
		local keypoints = {}
		for _, keypoint in value.Keypoints do
			table.insert(keypoints, `NumberSequenceKeypoint.new({numbers(keypoint.Time, keypoint.Value, keypoint.Envelope)})`)
		end
		return `NumberSequence.new(\{ {table.concat(keypoints, ", ")} \})`
	elseif valueType == "ColorSequence" then
		local keypoints = {}
		for _, keypoint in value.Keypoints do
			table.insert(keypoints, `ColorSequenceKeypoint.new({number(keypoint.Time)}, {color(keypoint.Value)})`)
		end
		return `ColorSequence.new(\{ {table.concat(keypoints, ", ")} \})`
	elseif valueType == "PhysicalProperties" then
		return `PhysicalProperties.new({numbers(value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight)})`
	elseif valueType == "Font" then
		return `Font.new({string.format("%q", value.Family)}, {tostring(value.Weight)}, {tostring(value.Style)})`
	end

	return `nil --[[ {valueType}: {tostring(value)} ]]`
end

return LuaValue
