--[[
	Shared state for every module.

	The tables here are created once and filled in place, so modules can capture them
	at load time. API and RMD are assigned by Main before the apps are loaded.
]]

local cloneref: <T>(T) -> T = cloneref or function(instance) return instance end

local service: { [string]: any } = setmetatable({} :: any, {
	__index = function(self, name: string)
		local instance = cloneref(game:GetService(name))
		rawset(self, name, instance)
		return instance
	end,
})

local Players = service.Players

local Context = {
	Main = {} :: { [string]: any },
	Lib = {} :: { [string]: any },
	Apps = {} :: { [string]: any },
	Settings = {} :: { [string]: any },
	env = {} :: { [string]: any },
	service = service,
	plr = Players.LocalPlayer or Players.PlayerAdded:Wait(),
	cloneref = cloneref,

	-- Explorer node for each instance, shared with the main menu tools
	Nodes = {} :: { [Instance]: any },

	API = nil :: any,
	RMD = nil :: any,
}

return Context
