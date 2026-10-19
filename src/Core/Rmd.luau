--[[
	Parser for ReflectionMetadata.xml (explorer icons, property order and class info).
]]

local Xml = require("@core/Xml")

type Fields = { [string]: any }

export type ClassMetadata = Fields & {
	Properties: { [string]: Fields },
	Functions: { [string]: Fields },
}

export type Rmd = {
	Classes: { [string]: ClassMetadata },
	PropertyOrders: { [string]: { [string]: number } },
}

local function capitalize(name: string): string return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) end

-- Reads a <Properties> node into { Name = text, ... }
local function readProperties(propertiesNode: Xml.Node, into: Fields): Fields
	for _, property in propertiesNode.children :: { Xml.Node } do
		local attrs = property.attrs
		if attrs and attrs.name then
			local valueNode = (property.children :: { Xml.Node })[1]
			into[capitalize(attrs.name)] = valueNode and valueNode.text
		end
	end
	return into
end

-- Reads every ReflectionMetadataMember of a members container
local function readMembers(container: Xml.Node, callback: (Fields) -> ())
	for _, member in container.children :: { Xml.Node } do
		local memberChildren = member.children :: { Xml.Node }
		if member.attrs and member.attrs.class == "ReflectionMetadataMember" and memberChildren[1] and memberChildren[1].tag == "Properties" then callback(readProperties(memberChildren[1], {})) end
	end
end

local Rmd = {}

function Rmd.parse(rawXml: string): Rmd
	local document = Xml.parse(rawXml)
	local root = (document.children[1] :: any).children
	local classList = root[1].children

	local classes: { [string]: ClassMetadata } = {}
	local propertyOrders: { [string]: { [string]: number } } = {}

	for _, classNode in classList do
		local className
		local metadata: any

		for _, child in classNode.children do
			if child.tag == "Properties" then
				metadata = readProperties(child, { Properties = {}, Functions = {} }) :: ClassMetadata
				className = metadata.Name
				classes[className] = metadata
			elseif metadata and child.attrs then
				local containerClass = child.attrs.class
				if containerClass == "ReflectionMetadataProperties" then
					readMembers(child, function(data)
						if data.PropertyOrder then
							local orders = propertyOrders[className]
							if not orders then
								orders = {}
								propertyOrders[className] = orders
							end
							orders[data.Name] = tonumber(data.PropertyOrder)
						end
						metadata.Properties[data.Name] = data
					end)
				elseif containerClass == "ReflectionMetadataFunctions" then
					readMembers(child, function(data) metadata.Functions[data.Name] = data end)
				end
			end
		end
	end

	return { Classes = classes, PropertyOrders = propertyOrders }
end

return Rmd
