--[[
	Instance builders.

	create takes a flat list of { id, className, properties } where a property value
	of { id } references another entry, and returns the first instance.
]]

export type InstanceSpec = { any }

local Create = {}

function Create.create(data: { InstanceSpec }): any
	local instances = {}
	for _, spec in data do
		instances[spec[1]] = Instance.new(spec[2])
	end

	for _, spec in data do
		local instance = instances[spec[1]]
		for property, value in spec[3] do
			if type(value) == "table" then
				instance[property] = instances[value[1]]
			else
				instance[property] = value
			end
		end
	end

	return instances[1]
end

function Create.createSimple(className: string, properties: { [string]: any }): any
	local instance = Instance.new(className)
	for property, value in properties do
		instance[property] = value
	end
	return instance
end

return Create
