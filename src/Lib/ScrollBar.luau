--[[
	Scroll bar measured in items: Index is the first visible item, VisibleSpace the
	number of visible items and TotalSpace the item count. Scrolled fires on changes.
]]

local Context = require("@core/Context")
local Create = require("@core/Create")

local Lib = Context.Lib
local service = Context.service
local plr = Context.plr
local createSimple = Create.createSimple

local UserInputService = service.UserInputService
local mouse = plr:GetMouse()

local HOLD_DELAY = 0.3
local MIN_THUMB_SIZE = 16
local THUMB_COLOR = Color3.fromRGB(60, 60, 60)
local THUMB_SELECT_COLOR = Color3.fromRGB(75, 75, 75)
local FRAME_COLOR = Color3.fromRGB(40, 40, 40)
local BUTTON_COLOR = Color3.fromRGB(75, 75, 75)
local ARROW_COLOR = Color3.new(1, 1, 1)

export type ScrollBar = {
	Index: number,
	VisibleSpace: number,
	TotalSpace: number,
	Increment: number,
	WheelIncrement: number,
	Horizontal: boolean,
	Scrolled: any,
	Gui: Frame,
	GuiElems: { [string]: any },
	ThumbColor: Color3,
	ThumbSelectColor: Color3,
	[any]: any,
}

local methods = {}

local function isMouseButton1(input: InputObject): boolean return input.UserInputType == Enum.UserInputType.MouseButton1 end

-- Calls onRelease once when the left mouse button is released
local function onMouseRelease(onRelease: () -> ())
	local connection
	connection = UserInputService.InputEnded:Connect(function(input)
		if not isMouseButton1(input) then return end
		connection:Disconnect()
		onRelease()
	end)
	return connection
end

local function drawThumb(self: ScrollBar)
	local thumb = self.GuiElems.ScrollThumb
	local thumbFrame = self.GuiElems.ScrollThumbFrame
	local total, visible = self.TotalSpace, self.VisibleSpace

	thumb.Visible = self:CanScrollUp() or self:CanScrollDown()
	if not thumb.Visible then return end

	local axis = self.Horizontal and "X" or "Y"
	local fraction = visible / total
	thumb.Size = self.Horizontal and UDim2.new(fraction, 0, 1, 0) or UDim2.new(1, 0, fraction, 0)
	if thumb.AbsoluteSize[axis] < MIN_THUMB_SIZE then thumb.Size = self.Horizontal and UDim2.new(0, MIN_THUMB_SIZE, 1, 0) or UDim2.new(1, 0, 0, MIN_THUMB_SIZE) end

	local frameSize = thumbFrame.AbsoluteSize[axis]
	local offset = frameSize > 0 and self:GetScrollPercent() * (frameSize - thumb.AbsoluteSize[axis]) / frameSize or 0
	thumb.Position = self.Horizontal and UDim2.new(offset, 0, 0, 0) or UDim2.new(0, 0, offset, 0)
end

local function createArrowButton(parent: Frame, name: string, position: UDim2, direction: string): ImageButton
	local button = createSimple("ImageButton", {
		Name = name,
		Position = position,
		Size = UDim2.new(0, 16, 0, 16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Parent = parent,
	})
	Lib.CreateArrow(16, 4, direction).Parent = button
	return button
end

-- Arrow button that scrolls once on press and repeatedly while held
local function bindArrowButton(self: ScrollBar, button: ImageButton, canScroll: () -> boolean, scroll: () -> ())
	local isHeld = false

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and not isHeld and canScroll() then button.BackgroundTransparency = 0.8 end
		if not isMouseButton1(input) or not canScroll() then return end

		isHeld = true
		button.BackgroundTransparency = 0.5
		scroll()
		self.Scrolled:Fire()

		onMouseRelease(function()
			isHeld = false
			button.BackgroundTransparency = (Lib.CheckMouseInGui(button) and canScroll()) and 0.8 or 1
		end)

		local pressedAt = os.clock()
		while isHeld do
			if os.clock() - pressedAt >= HOLD_DELAY and canScroll() then
				scroll()
				self.Scrolled:Fire()
			end
			task.wait()
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and not isHeld then button.BackgroundTransparency = 1 end
	end)
end

local function bindThumb(self: ScrollBar, thumb: Frame, thumbFrame: Frame)
	local isDragging = false

	thumb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and not isDragging then
			thumb.BackgroundTransparency = 0.2
			thumb.BackgroundColor3 = self.ThumbSelectColor
		end
		if not isMouseButton1(input) then return end

		local axis = self.Horizontal and "X" or "Y"
		local mouseOffset = mouse[axis] - thumb.AbsolutePosition[axis]
		local lastPosition = nil
		local moveConnection

		isDragging = true
		thumb.BackgroundTransparency = 0
		self:Update()

		onMouseRelease(function()
			isDragging = false
			moveConnection:Disconnect()
			if Lib.CheckMouseInGui(thumb) then
				thumb.BackgroundTransparency = 0.2
			else
				thumb.BackgroundTransparency = 0
				thumb.BackgroundColor3 = self.ThumbColor
			end
		end)

		moveConnection = UserInputService.InputChanged:Connect(function(movement)
			if movement.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			local trackSize = thumbFrame.AbsoluteSize[axis] - thumb.AbsoluteSize[axis]
			if trackSize <= 0 then return end

			local position = math.clamp(mouse[axis] - thumbFrame.AbsolutePosition[axis] - mouseOffset, 0, trackSize)
			if position == lastPosition then return end

			lastPosition = position
			self:ScrollTo(math.floor(0.5 + position / trackSize * (self.TotalSpace - self.VisibleSpace)))
		end)
	end)

	thumb.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and not isDragging then
			thumb.BackgroundTransparency = 0
			thumb.BackgroundColor3 = self.ThumbColor
		end
	end)

	-- Clicking the track pages towards the mouse, repeating while held
	thumbFrame.InputBegan:Connect(function(input)
		if not isMouseButton1(input) or Lib.CheckMouseInGui(thumb) then return end

		local axis = self.Horizontal and "X" or "Y"
		local isForward = mouse[axis] >= thumb.AbsolutePosition[axis] + thumb.AbsoluteSize[axis]
		local isHeld = true

		local function page()
			local pageSize = self.VisibleSpace - 1
			local thumbStart = thumb.AbsolutePosition[axis]
			if not isForward and mouse[axis] < thumbStart then
				self:ScrollTo(self.Index - pageSize)
			elseif isForward and mouse[axis] >= thumbStart + thumb.AbsoluteSize[axis] then
				self:ScrollTo(self.Index + pageSize)
			end
		end

		page()
		onMouseRelease(function() isHeld = false end)

		local pressedAt = os.clock()
		while isHeld do
			if os.clock() - pressedAt >= HOLD_DELAY and Lib.CheckMouseInGui(thumbFrame) then page() end
			task.wait()
		end
	end)
end

local function createFrame(self: ScrollBar): Frame
	local isHorizontal = self.Horizontal
	local frame = createSimple("Frame", {
		Name = "ScrollBar",
		Active = true,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -16, 0, 0),
		Size = isHorizontal and UDim2.new(1, 0, 0, 16) or UDim2.new(0, 16, 1, 0),
	})

	local button1 = createArrowButton(frame, isHorizontal and "Left" or "Up", UDim2.new(), isHorizontal and "left" or "up")
	local button2 = createArrowButton(frame, isHorizontal and "Right" or "Down", isHorizontal and UDim2.new(1, -16, 0, 0) or UDim2.new(0, 0, 1, -16), isHorizontal and "right" or "down")

	local thumbFrame = createSimple("Frame", {
		BackgroundTransparency = 1,
		Position = isHorizontal and UDim2.new(0, 16, 0, 0) or UDim2.new(0, 0, 0, 16),
		Size = isHorizontal and UDim2.new(1, -32, 1, 0) or UDim2.new(1, 0, 1, -32),
		Parent = frame,
	})

	local thumb = createSimple("Frame", {
		BorderSizePixel = 0,
		Parent = thumbFrame,
	})

	bindArrowButton(self, button1, function() return self:CanScrollUp() end, function() self:ScrollUp() end)
	bindArrowButton(self, button2, function() return self:CanScrollDown() end, function() self:ScrollDown() end)
	bindThumb(self, thumb, thumbFrame)

	frame.MouseWheelForward:Connect(function() self:ScrollTo(self.Index - self.WheelIncrement) end)
	frame.MouseWheelBackward:Connect(function() self:ScrollTo(self.Index + self.WheelIncrement) end)

	self.GuiElems.ScrollThumb = thumb
	self.GuiElems.ScrollThumbFrame = thumbFrame
	self.GuiElems.Button1 = button1
	self.GuiElems.Button2 = button2
	self.GuiElems.Arrow1Lines = button1.Arrow:GetChildren()
	self.GuiElems.Arrow2Lines = button2.Arrow:GetChildren()

	return frame
end

local function setLinesTransparency(lines: { Frame }, transparency: number)
	for _, line in lines do
		line.BackgroundTransparency = transparency
	end
end

function methods.Update(self: ScrollBar)
	local elems = self.GuiElems
	self.Index = math.clamp(self.Index, 0, math.max(0, self.TotalSpace - self.VisibleSpace))

	local canScrollUp = self:CanScrollUp()
	if not canScrollUp then elems.Button1.BackgroundTransparency = 1 end
	setLinesTransparency(elems.Arrow1Lines, canScrollUp and 0 or 0.5)

	local canScrollDown = self:CanScrollDown()
	if not canScrollDown then elems.Button2.BackgroundTransparency = 1 end
	setLinesTransparency(elems.Arrow2Lines, canScrollDown and 0 or 0.5)

	drawThumb(self)
end

function methods.ScrollTo(self: ScrollBar, index: number, noCallback: boolean?)
	self.Index = index
	self:Update()
	if not noCallback then self.Scrolled:Fire() end
end

function methods.ScrollUp(self: ScrollBar)
	self.Index -= self.Increment
	self:Update()
end

function methods.ScrollDown(self: ScrollBar)
	self.Index += self.Increment
	self:Update()
end

function methods.CanScrollUp(self: ScrollBar): boolean return self.Index > 0 end

function methods.CanScrollDown(self: ScrollBar): boolean return self.Index + self.VisibleSpace < self.TotalSpace end

function methods.GetScrollPercent(self: ScrollBar): number
	local scrollable = self.TotalSpace - self.VisibleSpace
	return scrollable > 0 and self.Index / scrollable or 0
end

function methods.SetScrollPercent(self: ScrollBar, percent: number)
	self.Index = math.floor(percent * (self.TotalSpace - self.VisibleSpace))
	self:Update()
end

function methods.Texture(self: ScrollBar, data: { [string]: Color3 })
	local elems = self.GuiElems
	self.ThumbColor = data.ThumbColor or Color3.new()
	self.ThumbSelectColor = data.ThumbSelectColor or Color3.new()
	elems.ScrollThumb.BackgroundColor3 = self.ThumbColor
	self.Gui.BackgroundColor3 = data.FrameColor or Color3.new()
	elems.Button1.BackgroundColor3 = data.ButtonColor or Color3.new()
	elems.Button2.BackgroundColor3 = data.ButtonColor or Color3.new()

	local arrowColor = data.ArrowColor or Color3.new()
	for _, line in elems.Arrow1Lines do
		line.BackgroundColor3 = arrowColor
	end
	for _, line in elems.Arrow2Lines do
		line.BackgroundColor3 = arrowColor
	end
end

-- Lets another frame scroll this bar with the mouse wheel
function methods.SetScrollFrame(self: ScrollBar, frame: GuiObject)
	if self.ScrollUpEvent then self.ScrollUpEvent:Disconnect() end
	if self.ScrollDownEvent then self.ScrollDownEvent:Disconnect() end

	self.ScrollUpEvent = frame.MouseWheelForward:Connect(function() self:ScrollTo(self.Index - self.WheelIncrement) end)
	self.ScrollDownEvent = frame.MouseWheelBackward:Connect(function() self:ScrollTo(self.Index + self.WheelIncrement) end)
end

local metatable = { __index = methods }

local function new(isHorizontal: boolean?): ScrollBar
	local self = setmetatable({
		Index = 0,
		VisibleSpace = 0,
		TotalSpace = 0,
		Increment = 1,
		WheelIncrement = 1,
		GuiElems = {},
		Horizontal = isHorizontal == true,
		Scrolled = Lib.Signal.new(),
	}, metatable) :: any

	self.Gui = createFrame(self)
	self:Texture({
		ThumbColor = THUMB_COLOR,
		ThumbSelectColor = THUMB_SELECT_COLOR,
		ArrowColor = ARROW_COLOR,
		FrameColor = FRAME_COLOR,
		ButtonColor = BUTTON_COLOR,
	})

	return self
end

return { new = new }
