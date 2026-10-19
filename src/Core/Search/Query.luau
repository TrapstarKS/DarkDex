--[[
	Compiles a search query (see Search/Parser) into a predicate over instances.

	Matching follows the Studio Explorer filter: names, strings and enums match partially
	and case insensitively (an enum value that matches an item exactly only matches that
	item), booleans accept prefixes such as "t", colors use 0-255 and quoted whole values
	such as "1, 2, 3" are compared component by component.
]]

local Context = require("@core/Context")
local Parser = require("@core/Search/Parser")

local service = Context.service
local env = Context.env

export type Predicate = (Instance) -> boolean

local NUMBER_EPSILON = 1e-4

local FIELD_NAMES = {
	x = "X",
	y = "Y",
	z = "Z",
	r = "R",
	g = "G",
	b = "B",
	scale = "Scale",
	offset = "Offset",
	min = "Min",
	max = "Max",
	width = "Width",
	height = "Height",
	position = "Position",
	rotation = "Rotation",
	lookvector = "LookVector",
	rightvector = "RightVector",
	upvector = "UpVector",
	magnitude = "Magnitude",
	density = "Density",
	friction = "Friction",
	elasticity = "Elasticity",
}

local Query = {}

-- lower-case property name -> real name, per class
local propertyNameCache: { [string]: { [string]: string | false } } = {}
local classNameCache: { [string]: string }?

local function getClassNames(): { [string]: string }
	if classNameCache then return classNameCache end

	local names = {}
	for className in Context.API.Classes do
		names[string.lower(className)] = className
	end
	classNameCache = names
	return names
end

local function resolvePropertyName(className: string, lowerName: string): string?
	local cache = propertyNameCache[className]
	if not cache then
		cache = {}
		propertyNameCache[className] = cache
	end

	local cached = cache[lowerName]
	if cached ~= nil then return cached or nil end

	local apiClass = Context.API.Classes[className]
	while apiClass do
		for _, property in apiClass.Properties do
			if string.lower(property.Name) == lowerName then
				cache[lowerName] = property.Name
				return property.Name
			end
		end
		apiClass = apiClass.Superclass
	end

	cache[lowerName] = false
	return nil
end

local function readField(value: any, fieldName: string): (boolean, any)
	local valueType = typeof(value)
	local lowerField = string.lower(fieldName)
	local realName = FIELD_NAMES[lowerField] or fieldName

	local success, fieldValue = pcall(function() return value[realName] end)
	if not success then return false, nil end

	-- Studio compares color channels in 0-255
	if valueType == "Color3" and (lowerField == "r" or lowerField == "g" or lowerField == "b") then
		fieldValue *= 255
	end
	return true, fieldValue
end

local function readProperty(obj: Instance, path: { string }): (boolean, any)
	local propertyName = resolvePropertyName(obj.ClassName, string.lower(path[1]))
	if not propertyName then return false, nil end

	local success, value = pcall(function() return (obj :: any)[propertyName] end)
	if not success then return false, nil end

	for index = 2, #path do
		if value == nil then return false, nil end
		local found
		found, value = readField(value, path[index])
		if not found then return false, nil end
	end

	return true, value
end

local function parseBoolean(text: string): boolean?
	local lower = string.lower(text)
	if lower == "" then return nil end
	if lower == "1" or lower == "yes" or string.sub("true", 1, #lower) == lower then return true end
	if lower == "0" or lower == "no" or string.sub("false", 1, #lower) == lower then return false end
	return nil
end

local function parseNumbers(text: string): { number }
	local numbers = {}
	for token in string.gmatch(text, "[%-%+]?%d*%.?%d+[eE]?[%-%+]?%d*") do
		local number = tonumber(token)
		if number then table.insert(numbers, number) end
	end
	return numbers
end

-- Numeric components of a whole value, colors in 0-255
local function getComponents(value: any): { number }
	if typeof(value) == "Color3" then return { value.R * 255, value.G * 255, value.B * 255 } end
	if typeof(value) == "CFrame" then return { value:GetComponents() } end
	return parseNumbers(tostring(value))
end

local function compareNumbers(a: number, op: string, b: number): boolean
	if op == "=" then return math.abs(a - b) <= NUMBER_EPSILON end
	if op == "~=" then return math.abs(a - b) > NUMBER_EPSILON end
	if op == ">" then return a > b end
	if op == "<" then return a < b end
	if op == ">=" then return a >= b - NUMBER_EPSILON end
	if op == "<=" then return a <= b + NUMBER_EPSILON end
	return false
end

local function compareText(text: string, op: string, query: string): boolean
	text = string.lower(text)
	query = string.lower(query)
	if op == "=" then return string.find(text, query, 1, true) ~= nil end
	if op == "~=" then return string.find(text, query, 1, true) == nil end
	if op == ">" then return text > query end
	if op == "<" then return text < query end
	if op == ">=" then return text >= query end
	if op == "<=" then return text <= query end
	return false
end

local enumExactCache: { [any]: { [string]: boolean } } = {}

local function matchesEnum(item: EnumItem, op: string, query: string): boolean
	local lowerQuery = string.lower(query)
	local enumType = item.EnumType

	local exactNames = enumExactCache[enumType]
	if not exactNames then
		exactNames = {}
		for _, enumItem in enumType:GetEnumItems() do
			exactNames[string.lower(enumItem.Name)] = true
		end
		enumExactCache[enumType] = exactNames
	end

	local itemName = string.lower(item.Name)
	local isMatch
	if exactNames[lowerQuery] then
		isMatch = itemName == lowerQuery
	else
		isMatch = string.find(itemName, lowerQuery, 1, true) ~= nil
	end

	if op == "=" then return isMatch end
	if op == "~=" then return not isMatch end
	return compareText(item.Name, op, query)
end

local function compareValue(value: any, op: string, query: string): boolean
	local valueType = typeof(value)

	-- An empty query asks whether the property is empty, e.g. MeshId=
	if query == "" then
		local isEmpty = value == nil or value == ""
		if op == "=" then return isEmpty end
		if op == "~=" then return not isEmpty end
		return false
	end

	if valueType == "boolean" then
		local expected = parseBoolean(query)
		if expected == nil then return false end
		if op == "=" then return value == expected end
		if op == "~=" then return value ~= expected end
		return false
	elseif valueType == "number" then
		local expected = tonumber(query)
		return expected ~= nil and compareNumbers(value, op, expected)
	elseif valueType == "string" then
		return compareText(value, op, query)
	elseif valueType == "EnumItem" then
		return matchesEnum(value, op, query)
	elseif valueType == "Instance" then
		return compareText(value.Name, op, query)
	elseif valueType == "BrickColor" then
		return compareText(value.Name, op, query)
	elseif value == nil then
		return op == "~=" or (op == "=" and string.lower(query) == "nil")
	end

	local components = getComponents(value)
	local expected = parseNumbers(query)
	if #components == 0 or #expected ~= #components then return compareText(tostring(value), op, query) end

	if op == "~=" then
		for index, component in components do
			if not compareNumbers(component, "=", expected[index]) then return true end
		end
		return false
	end

	for index, component in components do
		if not compareNumbers(component, op, expected[index]) then return false end
	end
	return true
end

local function containsName(obj: Instance, lowerNeedle: string): boolean return string.find(string.lower(obj.Name), lowerNeedle, 1, true) ~= nil end

local function compilePath(segments: { string }): Predicate
	local lowerSegments = table.create(#segments)
	for index, segment in segments do
		lowerSegments[index] = string.lower(segment)
	end

	local function matchSegment(obj: Instance?, index: number): boolean
		if not obj then return false end

		local segment = lowerSegments[index]
		if segment == "**" then
			-- One or more levels: the object itself and any number of its ancestors
			if index == 1 then return true end
			local ancestor = obj.Parent
			while ancestor do
				if matchSegment(ancestor, index - 1) then return true end
				ancestor = ancestor.Parent
			end
			return false
		end

		if segment ~= "*" and not containsName(obj, segment) then return false end
		if index == 1 then return true end
		return matchSegment(obj.Parent, index - 1)
	end

	local lastIndex = #lowerSegments
	return function(obj) return matchSegment(obj, lastIndex) end
end

local function compileKeyword(keyword: string, value: string): Predicate
	local lowerValue = string.lower(value)

	if keyword == "is" then
		local className = getClassNames()[lowerValue]
		if not className then
			return function() return false end
		end
		return function(obj) return obj:IsA(className) end
	elseif keyword == "class" then
		return function(obj) return string.lower(obj.ClassName) == lowerValue end
	elseif keyword == "tag" then
		-- Instances of every tag whose name contains the value
		local tagged: { [Instance]: true } = {}
		local CollectionService = service.CollectionService
		for _, tag in CollectionService:GetAllTags() do
			if string.find(string.lower(tag), lowerValue, 1, true) then
				for _, instance in CollectionService:GetTagged(tag) do
					tagged[instance] = true
				end
			end
		end
		return function(obj) return tagged[obj] == true end
	end

	return function(obj) return containsName(obj, lowerValue) end
end

local function compileCommand(name: string, arg: string?): (Predicate?, string?)
	if name == "remotes" then
		return function(obj) return obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") end
	elseif name == "bindables" then
		return function(obj) return obj:IsA("BindableEvent") or obj:IsA("BindableFunction") end
	elseif name == "players" then
		local players = {}
		for _, player in service.Players:GetPlayers() do
			players[player] = true
		end
		return function(obj) return players[obj] == true end
	elseif name == "loadedmodules" then
		if not env.getloadedmodules then return nil, "/loadedmodules needs getloadedmodules" end
		local modules = {}
		for _, module in env.getloadedmodules() do
			modules[module] = true
		end
		return function(obj) return modules[obj] == true end
	elseif name == "rad" then
		local radius = tonumber(arg)
		if not radius then return nil, "/rad needs a distance, e.g. /rad 50" end
		local character = Context.plr.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then return nil, "/rad needs your character" end
		local origin = root.Position
		return function(obj) return obj:IsA("BasePart") and ((obj :: BasePart).Position - origin).Magnitude <= radius end
	end
	return nil, `Unknown command /{name}`
end

local function compileNode(astNode: Parser.Node): Predicate
	-- The old type solver cannot narrow the union by kind
	local node = astNode :: any
	local kind = node.kind
	if kind == "and" then
		local left, right = compileNode(node.left), compileNode(node.right)
		return function(obj) return left(obj) and right(obj) end
	elseif kind == "or" then
		local left, right = compileNode(node.left), compileNode(node.right)
		return function(obj) return left(obj) or right(obj) end
	elseif kind == "not" then
		local expr = compileNode(node.expr)
		return function(obj) return not expr(obj) end
	elseif kind == "name" then
		local needle = string.lower(node.value)
		return function(obj) return containsName(obj, needle) end
	elseif kind == "keyword" then
		return compileKeyword(node.keyword, node.value)
	elseif kind == "property" then
		local path, op, value = node.path, node.op, node.value
		return function(obj)
			local found, propertyValue = readProperty(obj, path)
			return found and compareValue(propertyValue, op, value)
		end
	elseif kind == "path" then
		return compilePath(node.segments)
	end

	local predicate, err = compileCommand(node.name, node.arg)
	if not predicate then error(err, 0) end
	return predicate
end

-- Returns nil and an error message when the query is invalid, nil and nil when empty
function Query.compile(query: string): (Predicate?, string?)
	local ast, parseError = Parser.parse(query)
	if not ast then return nil, parseError end

	local success, result = pcall(compileNode, ast)
	if not success then return nil, tostring(result) end
	return result, nil
end

return Query
