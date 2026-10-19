--[[
	Helpers for the component classes.

	A component declares its default properties in a table. initObj deep-copies it
	for each instance, replacing SIGNAL markers with new signals. PH marks a value
	that the constructor must replace.
]]

local Context = require("@core/Context")

local Lib = Context.Lib

local Class = {}

Class.PH = newproxy()
Class.SIGNAL = newproxy()

-- Usually for classes that work with a Roblox Object
function Class.initObj(props: { [any]: any }, metatable: { [any]: any })
	local function copy(source)
		local result = {}
		for key, value in source do
			if value == Class.SIGNAL then
				result[key] = Lib.Signal.new()
			elseif type(value) == "table" then
				result[key] = copy(value)
			else
				result[key] = value
			end
		end
		return result
	end

	return setmetatable(copy(props), metatable)
end

-- Unknown keys are forwarded to the wrapped self.Gui instance
function Class.getGuiMT(props: { [any]: any }, funcs: { [any]: any })
	return {
		__index = function(self, key)
			if not props[key] then return funcs[key] or self.Gui[key] end
			return nil
		end,
		__newindex = function(self, key, value)
			if not props[key] then
				self.Gui[key] = value
			else
				rawset(self, key, value)
			end
		end,
	}
end

return Class
