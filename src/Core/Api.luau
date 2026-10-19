--[[
	Parser for the Roblox API dump (API-Dump.json).
]]

local Context = require("@core/Context")

local service = Context.service

export type Member = {
	Name: string,
	Class: string,
	Security: any,
	Tags: { [string]: boolean },
	ValueType: any?,
	Category: string?,
	Serialization: any?,
	Parameters: { { Name: string, Type: string } }?,
	ReturnType: string?,
}

export type Class = {
	Name: string,
	Superclass: Class?,
	Properties: { Member },
	Functions: { Member },
	Events: { Member },
	Callbacks: { Member },
	Tags: { [string]: boolean },
}

export type Api = {
	Classes: { [string]: Class },
	CategoryOrder: { [string]: number },
}

local function toTagSet(tags: { any }?): { [string]: boolean }
	local set = {}
	if tags then
		for _, tag in tags do
			-- Some tags are objects such as { PreferredDescriptor = ... }
			if type(tag) == "string" then set[tag] = true end
		end
	end
	return set
end

local function toParameters(parameters: { any }): { { Name: string, Type: string } }
	local result = table.create(#parameters)
	for _, parameter in parameters do
		table.insert(result, { Name = parameter.Name, Type = parameter.Type.Name })
	end
	return result
end

local function moveAbove(list: { string }, item: string, aboveItem: string)
	local from = table.find(list, item)
	if not from then return end
	table.remove(list, from)

	local to = table.find(list, aboveItem)
	if not to then return end
	table.insert(list, to, item)
end

local Api = {}

function Api.parse(rawApi: string): Api
	local dump = service.HttpService:JSONDecode(rawApi)
	local classes: { [string]: Class } = {}
	local superclassNames: { [Class]: string } = {}
	local categoryOrder, seenCategories = {}, {}

	for _, class in dump.Classes do
		local newClass: Class = {
			Name = class.Name,
			Superclass = nil,
			Properties = {},
			Functions = {},
			Events = {},
			Callbacks = {},
			Tags = toTagSet(class.Tags),
		}
		superclassNames[newClass] = class.Superclass

		for _, member in class.Members do
			local newMember: Member = {
				Name = member.Name,
				Class = class.Name,
				Security = member.Security,
				Tags = toTagSet(member.Tags),
			}

			local memberType = member.MemberType
			if memberType == "Property" then
				local category = string.match(member.Category or "Other", "^%s*(.-)%s*$")
				if not seenCategories[category] then
					table.insert(categoryOrder, category)
					seenCategories[category] = true
				end
				newMember.ValueType = member.ValueType
				newMember.Category = category
				newMember.Serialization = member.Serialization
				table.insert(newClass.Properties, newMember)
			elseif memberType == "Function" then
				newMember.Parameters = toParameters(member.Parameters)
				newMember.ReturnType = member.ReturnType.Name
				table.insert(newClass.Functions, newMember)
			elseif memberType == "Event" then
				newMember.Parameters = toParameters(member.Parameters)
				table.insert(newClass.Events, newMember)
			end
		end

		classes[class.Name] = newClass
	end

	for class, superclassName in superclassNames do
		class.Superclass = classes[superclassName]
	end

	moveAbove(categoryOrder, "Behavior", "Tuning")
	moveAbove(categoryOrder, "Appearance", "Data")
	moveAbove(categoryOrder, "Attachments", "Axes")
	moveAbove(categoryOrder, "Cylinder", "Slider")
	moveAbove(categoryOrder, "Localization", "Jump Settings")
	moveAbove(categoryOrder, "Surface", "Motion")
	moveAbove(categoryOrder, "Surface Inputs", "Surface")
	moveAbove(categoryOrder, "Part", "Surface Inputs")
	moveAbove(categoryOrder, "Assembly", "Surface Inputs")
	moveAbove(categoryOrder, "Character", "Controls")
	table.insert(categoryOrder, "Unscriptable")
	table.insert(categoryOrder, "Tags")
	table.insert(categoryOrder, "Attributes")

	local categoryIndex = {}
	for index, category in categoryOrder do
		categoryIndex[category] = index
	end

	return {
		Classes = classes,
		CategoryOrder = categoryIndex,
	}
end

return Api
