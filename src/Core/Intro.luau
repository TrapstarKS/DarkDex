--[[
	Animated loading screen shown while DarkDex initializes.
]]

local Context = require("@core/Context")
local Create = require("@core/Create")

local Main = Context.Main
local service = Context.service

local TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PROGRESS_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local HIDDEN_SEQUENCE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1, 0), NumberSequenceKeypoint.new(1, 1, 0) })

export type Intro = {
	SetProgress: (text: string, fraction: number) -> (),
	Close: () -> (),
}

local function buildGui()
	return Create.create({
		{ 1, "ScreenGui", { Name = "Intro" } },
		{ 2, "Frame", { Active = true, BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Name = "Main", Parent = { 1 }, Position = UDim2.new(0.5, -175, 0.5, -100), Size = UDim2.new(0, 350, 0, 200) } },
		{ 3, "Frame", { BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0, ClipsDescendants = true, Name = "Holder", Parent = { 2 }, Size = UDim2.new(1, 0, 1, 0) } },
		{ 4, "UIGradient", { Parent = { 3 }, Rotation = 30, Transparency = HIDDEN_SEQUENCE } },
		{ 5, "TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.SourceSansBold, Name = "Title", Parent = { 3 }, Position = UDim2.new(0, -190, 0, 15), Size = UDim2.new(0, 100, 0, 50), Text = "Dex", TextColor3 = Color3.new(1, 1, 1), TextSize = 50, TextTransparency = 1 } },
		{ 6, "TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Name = "Desc", Parent = { 3 }, Position = UDim2.new(0, -230, 0, 60), Size = UDim2.new(0, 180, 0, 25), Text = "Ultimate Debugging Suite", TextColor3 = Color3.new(1, 1, 1), TextSize = 18, TextTransparency = 1 } },
		{ 7, "TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Name = "StatusText", Parent = { 3 }, Position = UDim2.new(0, 20, 0, 110), Size = UDim2.new(0, 180, 0, 25), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextTransparency = 1 } },
		{ 8, "Frame", { BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Name = "ProgressBar", Parent = { 3 }, Position = UDim2.new(0, 110, 0, 145), Size = UDim2.new(0, 0, 0, 4) } },
		{ 9, "Frame", { BackgroundColor3 = Color3.fromRGB(61, 143, 220), BorderSizePixel = 0, Name = "Bar", Parent = { 8 }, Size = UDim2.new(0, 0, 1, 0) } },
		{ 10, "ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://2764171053", ImageColor3 = Color3.fromRGB(45, 45, 45), Parent = { 8 }, ScaleType = Enum.ScaleType.Slice, Size = UDim2.new(1, 0, 1, 0), SliceCenter = Rect.new(2, 2, 254, 254) } },
		{
			11,
			"TextLabel",
			{ BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Name = "Creator", Parent = { 2 }, Position = UDim2.new(1, -110, 1, -20), Size = UDim2.new(0, 105, 0, 20), Text = "Developed by Moon", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right },
		},
		{ 12, "UIGradient", { Parent = { 11 }, Transparency = HIDDEN_SEQUENCE } },
		{
			13,
			"TextLabel",
			{ BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Name = "Version", Parent = { 2 }, Position = UDim2.new(1, -110, 1, -35), Size = UDim2.new(0, 105, 0, 20), Text = Main.Version, TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right },
		},
		{ 14, "UIGradient", { Parent = { 13 }, Transparency = HIDDEN_SEQUENCE } },
		{
			15,
			"ImageLabel",
			{
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = "rbxassetid://1427967925",
				Name = "Outlines",
				Parent = { 2 },
				Position = UDim2.new(0, -5, 0, -5),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.new(1, 10, 1, 10),
				SliceCenter = Rect.new(6, 6, 25, 25),
				TileSize = UDim2.new(0, 20, 0, 20),
			},
		},
		{ 16, "UIGradient", { Parent = { 15 }, Rotation = -30, Transparency = HIDDEN_SEQUENCE } },
		{ 17, "UIGradient", { Parent = { 2 }, Rotation = -30, Transparency = HIDDEN_SEQUENCE } },
	})
end

-- Tweens a number from 0 to target and calls onStep with each value
local function tweenNumber(target: number, tweenInfo: TweenInfo, onStep: (number) -> ())
	local value = Instance.new("NumberValue")
	value.Changed:Connect(onStep)

	local tween = service.TweenService:Create(value, tweenInfo, { Value = target })
	tween.Completed:Once(function() value:Destroy() end)
	tween:Play()
end

local function play(instance: Instance, tweenInfo: TweenInfo, goal: { [string]: any }) service.TweenService:Create(instance, tweenInfo, goal):Play() end

local Intro = {}

function Intro.create(initialStatus: string): Intro
	local gui = buildGui()
	Main.ShowGui(gui)

	local mainFrame = gui.Main
	local holder = mainFrame.Holder
	local backGradient = mainFrame.UIGradient
	local outlinesGradient = mainFrame.Outlines.UIGradient
	local holderGradient = holder.UIGradient
	local titleText = holder.Title
	local descText = holder.Desc
	local versionText = mainFrame.Version
	local creatorText = mainFrame.Creator
	local statusText = holder.StatusText
	local progressBar = holder.ProgressBar

	statusText.Text = initialStatus

	tweenNumber(100, TWEEN_INFO, function(value)
		value /= 200
		local a1 = NumberSequenceKeypoint.new(value, 0)
		local a2 = NumberSequenceKeypoint.new(math.min(0.5, value + math.min(0.05, value)), 1)
		if a1.Time == a2.Time then a2 = a1 end
		local b1 = NumberSequenceKeypoint.new(1 - value, 0)
		local b2 = NumberSequenceKeypoint.new(math.max(0.5, 1 - value - math.min(0.05, value)), 1)
		if b1.Time == b2.Time then b2 = b1 end

		local sequence = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), a1, a2, b2, b1, NumberSequenceKeypoint.new(1, 0) })
		backGradient.Transparency = sequence
		outlinesGradient.Transparency = sequence
	end)

	task.wait(0.4)

	tweenNumber(100, TWEEN_INFO, function(value)
		value /= 166.66
		holderGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(value, 0),
			NumberSequenceKeypoint.new(value + 0.01, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end)

	play(titleText, TWEEN_INFO, { Position = UDim2.new(0, 60, 0, 15), TextTransparency = 0 })
	play(descText, TWEEN_INFO, { Position = UDim2.new(0, 20, 0, 60), TextTransparency = 0 })

	local function revealFromRight(gradient: UIGradient)
		tweenNumber(100, TWEEN_INFO, function(value)
			value /= 100
			local a1 = NumberSequenceKeypoint.new(1 - value, 0)
			local a2 = NumberSequenceKeypoint.new(math.max(0, 1 - value - 0.01), 1)
			if a1.Time == a2.Time then a2 = a1 end
			gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, a1 == a2 and 0 or 1), a2, a1, NumberSequenceKeypoint.new(1, 0) })
		end)
	end
	revealFromRight(versionText.UIGradient)
	revealFromRight(creatorText.UIGradient)

	task.wait(0.9)

	play(statusText, PROGRESS_TWEEN_INFO, { Position = UDim2.new(0, 20, 0, 120), TextTransparency = 0 })
	play(progressBar, PROGRESS_TWEEN_INFO, { Position = UDim2.new(0, 60, 0, 145), Size = UDim2.new(0, 100, 0, 4) })

	task.wait(0.25)

	local function setProgress(text: string, fraction: number)
		statusText.Text = text
		play(progressBar.Bar, PROGRESS_TWEEN_INFO, { Size = UDim2.new(fraction, 0, 1, 0) })
	end

	local function close()
		for _, label in { titleText, descText, versionText, creatorText, statusText } do
			play(label, PROGRESS_TWEEN_INFO, { TextTransparency = 1 })
		end
		play(progressBar, PROGRESS_TWEEN_INFO, { BackgroundTransparency = 1 })
		play(progressBar.Bar, PROGRESS_TWEEN_INFO, { BackgroundTransparency = 1 })
		play(progressBar.ImageLabel, PROGRESS_TWEEN_INFO, { ImageTransparency = 1 })

		tweenNumber(100, CLOSE_TWEEN_INFO, function(value)
			value /= 250
			local a1 = NumberSequenceKeypoint.new(0.6 + value, 0)
			local a2 = NumberSequenceKeypoint.new(math.min(1, 0.601 + value), 1)
			if a1.Time == a2.Time then a2 = a1 end
			holderGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), a1, a2, NumberSequenceKeypoint.new(1, a1 == a2 and 0 or 1) })
		end)

		task.wait(0.5)
		mainFrame.BackgroundTransparency = 1
		outlinesGradient.Rotation = 30

		tweenNumber(100, TWEEN_INFO, function(value)
			value /= 100
			local a1 = NumberSequenceKeypoint.new(value, 1)
			local a2 = NumberSequenceKeypoint.new(math.min(1, value + math.min(0.05, value)), 0)
			if a1.Time == a2.Time then a2 = a1 end
			local sequence = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), a1, a2, NumberSequenceKeypoint.new(1, a1 == a2 and 1 or 0) })
			outlinesGradient.Transparency = sequence
			holderGradient.Transparency = sequence
		end)

		task.wait(0.45)
		gui:Destroy()
	end

	return { SetProgress = setProgress, Close = close }
end

return Intro
