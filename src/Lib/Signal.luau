--[[
	Lightweight signal for the Lua side of the UI (not a Roblox event).
	Each handler runs in its own thread, so one failing handler does not stop the others.
]]

export type Connection = {
	Signal: Signal,
	Func: (...any) -> (),
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connections: { Connection },
	Connect: (self: Signal, func: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

local function disconnect(connection: Connection)
	if not connection.Connected then return end
	connection.Connected = false

	local connections = connection.Signal.Connections
	local index = table.find(connections, connection)
	if index then table.remove(connections, index) end
end

local methods = {}

function methods.Connect(self: Signal, func: (...any) -> ()): Connection
	assert(type(func) == "function", "Attempt to connect a non-function")

	local connection: Connection = {
		Signal = self,
		Func = func,
		Connected = true,
		Disconnect = disconnect,
	}
	table.insert(self.Connections, connection)
	return connection
end

function methods.Fire(self: Signal, ...: any)
	-- Handlers may disconnect while firing, so iterate over a snapshot
	for _, connection in table.clone(self.Connections) do
		if connection.Connected then task.spawn(connection.Func, ...) end
	end
end

function methods.DisconnectAll(self: Signal)
	for _, connection in self.Connections do
		connection.Connected = false
	end
	table.clear(self.Connections)
end

local metatable = {
	__index = methods,
	__tostring = function(self: Signal) return `Signal: {#self.Connections} Connections` end,
}

local function new(): Signal return setmetatable({ Connections = {} }, metatable) :: any end

return { new = new }
