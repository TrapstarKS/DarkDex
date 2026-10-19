--[[
	Lib: shared helpers and UI component classes.

	Components are required inside Main (not at load time) because some of them read
	settings and services when they are created.
]]

local Context = require("@core/Context")
local Create = require("@core/Create")

local Main = Context.Main
local Lib = Context.Lib
local service = Context.service

local UserInputService = service.UserInputService
local RenderStepped = service.RunService.RenderStepped

local ARROW_COLOR = Color3.fromRGB(220, 220, 220)

local function installHelpers()
	Lib.FormatLuaString = (function()
		local escapes = { ['"'] = '\\"', ["\\"] = "\\\\" }
		for byte = 0, 31 do
			escapes[string.char(byte)] = string.format("\\%03d", byte)
		end
		for byte = 127, 255 do
			escapes[string.char(byte)] = string.format("\\%03d", byte)
		end

		return function(str: string): string return (string.gsub(str, '["\\\0-\31\127-\255]', escapes)) end
	end)()

	Lib.CheckMouseInGui = function(gui: GuiObject?): boolean
		if gui == nil then return false end

		local mouse = Main.Mouse
		local position = gui.AbsolutePosition
		local size = gui.AbsoluteSize
		return mouse.X >= position.X and mouse.X < position.X + size.X and mouse.Y >= position.Y and mouse.Y < position.Y + size.Y
	end

	Lib.IsShiftDown = function(): boolean return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) end

	Lib.IsCtrlDown = function(): boolean return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) end

	-- Builds a pixel arrow from lines of growing length
	Lib.CreateArrow = function(size: number, lineCount: number, direction: "up" | "down" | "left" | "right"): Frame
		local isVertical = direction == "up" or direction == "down"
		local isReversed = direction == "down" or direction == "right"
		local half = math.floor(size / 2)
		local halfCount = math.floor(lineCount / 2)

		local arrowFrame = Create.createSimple("Frame", {
			BackgroundTransparency = 1,
			Name = "Arrow",
			Size = UDim2.new(0, size, 0, size),
		})

		for line = 1, lineCount do
			local across = half - (line - 1)
			local along = half + (isReversed and (halfCount + 1 - line) or (line - halfCount - 1))
			local length = line * 2 - 1

			Create.createSimple("Frame", {
				BackgroundColor3 = ARROW_COLOR,
				BorderSizePixel = 0,
				Position = isVertical and UDim2.new(0, across, 0, along) or UDim2.new(0, along, 0, across),
				Size = isVertical and UDim2.new(0, length, 0, 1) or UDim2.new(0, 1, 0, length),
				Parent = arrowFrame,
			})
		end

		return arrowFrame
	end

	-- Waits one frame, or at least the given number of seconds in whole frames
	Lib.FastWait = function(seconds: number?)
		if not seconds then return RenderStepped:Wait() end

		local start = os.clock()
		while os.clock() - start < seconds do
			RenderStepped:Wait()
		end
		return nil
	end

	Lib.DeferFunc = function(callback: (...any) -> ...any, ...: any)
		RenderStepped:Wait()
		return callback(...)
	end

	-- Mode 1 fades the background, mode 2 tints it with hover/press colors
	Lib.ButtonAnim = function(button: GuiButton, data: { [string]: any }?)
		local holding = false
		local disabled = false
		local mode = data and data.Mode or 1
		local control = {}

		if mode == 2 and data then
			local lerpTo = data.LerpTo or Color3.new(0, 0, 0)
			local delta = data.LerpDelta or 0.2
			control.StartColor = data.StartColor or button.BackgroundColor3
			control.PressColor = data.PressColor or control.StartColor:Lerp(lerpTo, delta)
			control.HoverColor = data.HoverColor or control.StartColor:Lerp(control.PressColor, 0.6)
			control.OutlineColor = data.OutlineColor
		end

		local function showIdle()
			if mode == 1 then
				button.BackgroundTransparency = 1
			else
				button.BackgroundColor3 = control.StartColor
			end
		end

		button.InputBegan:Connect(function(input)
			if disabled then return end

			if input.UserInputType == Enum.UserInputType.MouseMovement and not holding then
				if mode == 1 then
					button.BackgroundTransparency = 0.4
				else
					button.BackgroundColor3 = control.HoverColor
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				holding = true
				if mode == 1 then
					button.BackgroundTransparency = 0
				else
					button.BackgroundColor3 = control.PressColor
					if control.OutlineColor then button.BorderColor3 = control.PressColor end
				end
			end
		end)

		button.InputEnded:Connect(function(input)
			if disabled then return end

			if input.UserInputType == Enum.UserInputType.MouseMovement and not holding then
				showIdle()
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				holding = false
				local isHovered = Lib.CheckMouseInGui(button)
				if mode == 1 then
					button.BackgroundTransparency = isHovered and 0.4 or 1
				else
					button.BackgroundColor3 = isHovered and control.HoverColor or control.StartColor
					if control.OutlineColor then button.BorderColor3 = control.OutlineColor end
				end
			end
		end)

		control.Disable = function()
			disabled = true
			holding = false
			showIdle()
		end

		control.Enable = function() disabled = false end

		return control
	end

	Lib.FindAndRemove = function(list: { any }, item: any)
		local index = table.find(list, item)
		if index then table.remove(list, index) end
	end

	-- Keeps obj positioned (and optionally sized) relative to data.Target
	Lib.AttachTo = function(obj: GuiObject, data: { [string]: any }?)
		local target, posOffX, posOffY, sizeOffX, sizeOffY, resize
		local connections: { RBXScriptConnection } = {}
		local disabled = false

		local function update()
			if disabled or not obj or not target then return end

			local targetPosition = target.AbsolutePosition
			obj.Position = UDim2.new(0, targetPosition.X + posOffX, 0, targetPosition.Y + posOffY)
			if resize then
				local targetSize = target.AbsoluteSize
				obj.Size = UDim2.new(0, targetSize.X + sizeOffX, 0, targetSize.Y + sizeOffY)
			end
		end

		local function disconnect()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
		end

		local function setup(newObj, newData)
			newData = newData or {}
			obj = newObj
			target = newData.Target
			posOffX = newData.PosOffX or 0
			posOffY = newData.PosOffY or 0
			sizeOffX = newData.SizeOffX or 0
			sizeOffY = newData.SizeOffY or 0
			resize = newData.Resize or false

			disconnect()
			if target then
				table.insert(connections, target:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
				table.insert(connections, target:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
			end

			update()
		end
		setup(obj, data)

		return {
			SetData = function(newObj, newData) setup(newObj, newData) end,
			Enable = function()
				disabled = false
				update()
			end,
			Disable = function() disabled = true end,
			Destroy = disconnect,
		}
	end

	Lib.ShowGui = function(gui: ScreenGui) Main.ShowGui(gui) end

	Lib.ColorToBytes = function(color: Color3): string return string.format("%d, %d, %d", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255)) end
end

local LibModule = {}

function LibModule.Main()
	installHelpers()

	-- Order matters: later components use the earlier ones while being created
	Lib.Signal = require("@lib/Signal")
	Lib.Set = require("@lib/Set")
	Lib.IconMap = require("@lib/IconMap")
	Lib.ScrollBar = require("@lib/ScrollBar")
	Lib.Window = require("@lib/Window")
	Lib.ContextMenu = require("@lib/ContextMenu")
	Lib.CodeFrame = require("@lib/CodeFrame")
	Lib.Checkbox = require("@lib/Checkbox")
	Lib.BrickColorPicker = require("@lib/BrickColorPicker")
	Lib.ColorPicker = require("@lib/ColorPicker")
	Lib.NumberSequenceEditor = require("@lib/NumberSequenceEditor")
	Lib.ColorSequenceEditor = require("@lib/ColorSequenceEditor")
	Lib.ViewportTextBox = require("@lib/ViewportTextBox")
	Lib.Label = require("@lib/Label")
	Lib.Frame = require("@lib/Frame")
	Lib.Button = require("@lib/Button")
	Lib.DropDown = require("@lib/DropDown")
	Lib.ClickSystem = require("@lib/ClickSystem")

	return Lib
end

return LibModule
