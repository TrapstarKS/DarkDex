local funcs = {}

local disconnect = function(con)
	local pos = table.find(con.Signal.Connections, con)
	if pos then table.remove(con.Signal.Connections, pos) end
end

funcs.Connect = function(self, func)
	if type(func) ~= "function" then error("Attempt to connect a non-function") end
	local con = {
		Signal = self,
		Func = func,
		Disconnect = disconnect,
	}
	self.Connections[#self.Connections + 1] = con
	return con
end

funcs.Fire = function(self, ...)
	for i, v in next, self.Connections do
		xpcall(coroutine.wrap(v.Func), function(e) warn(e .. "\n" .. debug.traceback()) end, ...)
	end
end

local mt = {
	__index = funcs,
	__tostring = function(self) return "Signal: " .. tostring(#self.Connections) .. " Connections" end,
}

local function new()
	local obj = {}
	obj.Connections = {}

	return setmetatable(obj, mt)
end

return { new = new }
