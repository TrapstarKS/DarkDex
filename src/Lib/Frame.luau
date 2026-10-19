local Class = require("@lib/Class")
local Context = require("@core/Context")

local Settings = Context.Settings
local getGuiMT = Class.getGuiMT

local props, funcs = {}, {}

local mt = getGuiMT(props, funcs)

local function new()
	local fr = Instance.new("Frame")
	fr.BackgroundColor3 = Settings.Theme.Main1
	fr.BorderColor3 = Settings.Theme.Outline1
	fr.Size = UDim2.new(0, 50, 0, 50)

	local obj = setmetatable({
		Gui = fr,
	}, mt)
	return obj
end

return { new = new }
