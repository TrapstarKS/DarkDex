--[[
	The "Dex" button at the top of the screen with the app launcher and settings.
]]

local Context = require("@core/Context")
local Create = require("@core/Create")
local SettingsStore = require("@core/Settings")

local Main = Context.Main
local Lib = Context.Lib
local Apps = Context.Apps
local Settings = Context.Settings
local service = Context.service
local plr = Context.plr
local nodes = Context.Nodes

local MENU_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_TWEEN_INFO = TweenInfo.new(0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MENU_SIZE = UDim2.new(0, 224, 0, 200)

export type AppData = {
	Name: string,
	IconMap: any?,
	Icon: (number | string)?,
	Open: boolean?,
	Window: any?,
	Container: Instance?,
	OnClick: ((isOpen: boolean) -> ())?,
}

export type AppControl = {
	Enable: (silent: boolean?) -> (),
	Disable: (silent: boolean?) -> (),
}

local MainMenu = {}

local function buildGui()
	return Create.create({
		{ 1, "ScreenGui", { IgnoreGuiInset = true, Name = "MainMenu" } },
		{
			2,
			"TextButton",
			{
				AnchorPoint = Vector2.new(0.5, 0),
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(45, 45, 45),
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSansBold,
				Name = "OpenButton",
				Parent = { 1 },
				Position = UDim2.new(0.5, 0, 0, 2),
				Size = UDim2.new(0, 32, 0, 32),
				Text = "Dex",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 16,
				TextTransparency = 0.2,
			},
		},
		{ 3, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 2 } } },
		{ 4, "Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(45, 45, 45), ClipsDescendants = true, Name = "MainFrame", Parent = { 2 }, Position = UDim2.new(0.5, 0, 1, -4), Size = MENU_SIZE } },
		{ 5, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 4 } } },
		{ 6, "Frame", { BackgroundColor3 = Color3.fromRGB(52, 52, 52), Name = "BottomFrame", Parent = { 4 }, Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 24) } },
		{ 7, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 6 } } },
		{ 8, "Frame", { BackgroundColor3 = Color3.fromRGB(52, 52, 52), BorderSizePixel = 0, Name = "CoverFrame", Parent = { 6 }, Size = UDim2.new(1, 0, 0, 4) } },
		{ 9, "Frame", { BackgroundColor3 = Color3.fromRGB(33, 33, 33), BorderSizePixel = 0, Name = "Line", Parent = { 8 }, Position = UDim2.new(0, 0, 0, -1), Size = UDim2.new(1, 0, 0, 1) } },
		{ 10, "TextButton", { BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Name = "Settings", Parent = { 6 }, Position = UDim2.new(1, -48, 0, 0), Size = UDim2.new(0, 24, 1, 0), Text = "", TextSize = 14 } },
		{ 11, "ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://6578871732", ImageTransparency = 0.2, Name = "Icon", Parent = { 10 }, Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(0, 16, 0, 16) } },
		{ 12, "TextButton", { BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Name = "Information", Parent = { 6 }, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.new(0, 24, 1, 0), Text = "", TextSize = 14 } },
		{ 13, "ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://6578933307", ImageTransparency = 0.2, Name = "Icon", Parent = { 12 }, Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(0, 16, 0, 16) } },
		{
			14,
			"ScrollingFrame",
			{ Active = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "AppsFrame", Parent = { 4 }, Position = UDim2.new(0.5, 0, 0, 0), ScrollBarImageColor3 = Color3.new(0, 0, 0), ScrollBarThickness = 4, Size = UDim2.new(0, 222, 1, -25) },
		},
		{ 15, "Frame", { BackgroundTransparency = 1, Name = "Container", Parent = { 14 }, Position = UDim2.new(0, 7, 0, 8), Size = UDim2.new(1, -14, 0, 2) } },
		{ 16, "UIGridLayout", { CellSize = UDim2.new(0, 66, 0, 74), Parent = { 15 }, SortOrder = Enum.SortOrder.LayoutOrder } },
		{ 17, "Frame", { BackgroundTransparency = 1, Name = "App", Parent = { 1 }, Size = UDim2.new(0, 100, 0, 100), Visible = false } },
		{ 18, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(60, 60, 60), BorderSizePixel = 0, Font = Enum.Font.SourceSans, Name = "Main", Parent = { 17 }, Size = UDim2.new(1, 0, 0, 60), Text = "", TextSize = 14 } },
		{ 19, "ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://6579106223", ImageRectSize = Vector2.new(32, 32), Name = "Icon", Parent = { 18 }, Position = UDim2.new(0.5, -16, 0, 4), ScaleType = Enum.ScaleType.Crop, Size = UDim2.new(0, 32, 0, 32) } },
		{
			20,
			"TextLabel",
			{
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSans,
				Name = "AppName",
				Parent = { 18 },
				Position = UDim2.new(0, 2, 0, 38),
				Size = UDim2.new(1, -4, 1, -40),
				Text = "Explorer",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				TextTransparency = 0.1,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			},
		},
		{ 21, "Frame", { BackgroundColor3 = Color3.fromRGB(0, 170, 255), BorderSizePixel = 0, Name = "Highlight", Parent = { 18 }, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2) } },
	})
end

function MainMenu.CreateApp(data: AppData): AppControl?
	if Main.MenuApps[data.Name] then return nil end

	local app = Main.AppTemplate:Clone()
	local button = app.Main
	local icon = data.Icon

	if data.IconMap and icon then
		if type(icon) == "number" then
			data.IconMap:Display(button.Icon, icon)
		else
			data.IconMap:DisplayByKey(button.Icon, icon)
		end
	elseif type(icon) == "string" then
		button.Icon.Image = icon
	else
		button.Icon.Image = ""
	end

	local function updateState()
		button.BackgroundTransparency = (data.Open or Lib.CheckMouseInGui(button)) and 0 or 1
		button.Highlight.Visible = data.Open == true
	end

	local function setOpen(isOpen: boolean, silent: boolean?)
		if (data.Open == true) == isOpen then return end
		data.Open = isOpen
		updateState()
		if silent then return end

		if data.Window then
			if isOpen then
				data.Window:Show()
			else
				data.Window:Hide()
			end
		end
		if data.OnClick then data.OnClick(isOpen) end
	end

	local control: AppControl = {
		Enable = function(silent) setOpen(true, silent) end,
		Disable = function(silent) setOpen(false, silent) end,
	}

	updateState()

	local textHeight = service.TextService:GetTextSize(data.Name, 14, Enum.Font.SourceSans, Vector2.new(62, math.huge)).Y
	button.Size = UDim2.new(1, 0, 0, math.clamp(46 + textHeight, 60, 74))
	button.AppName.Text = data.Name

	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		button.BackgroundTransparency = 0
		button.BackgroundColor3 = Settings.Theme.ButtonHover
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		button.BackgroundTransparency = data.Open and 0 or 1
		button.BackgroundColor3 = Settings.Theme.Button
	end)

	button.MouseButton1Click:Connect(function() setOpen(not data.Open) end)

	local window = data.Window
	if window then
		window.OnActivate:Connect(function() control.Enable(true) end)
		window.OnDeactivate:Connect(function() control.Disable(true) end)
	end

	app.Visible = true
	app.Parent = data.Container or Main.AppsContainer
	Main.AppsFrame.CanvasSize = UDim2.new(0, 0, 0, Main.AppsContainerGrid.AbsoluteCellCount.Y * 82 + 8)

	-- TextFits is only correct after the label is rendered
	task.delay(0.1, function()
		local appName = button.AppName
		if appName.Parent and not appName.TextFits then appName.TextScaled = true end
	end)

	Main.MenuApps[data.Name] = control
	return control
end

function MainMenu.OpenSettings(isOpen: boolean)
	Main.MainGuiSettingsOpen = isOpen
	Main.AppsContainer.Visible = not isOpen
	Main.AppsSettings.Visible = isOpen
end

function MainMenu.SetOpen(isOpen: boolean)
	local openButton = Main.MainGui.OpenButton
	local menuFrame = openButton.MainFrame

	Main.MainGuiOpen = isOpen
	openButton.Text = isOpen and "X" or "Dex"
	if isOpen then menuFrame.Visible = true end

	menuFrame:TweenSize(isOpen and MENU_SIZE or UDim2.new(), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
	service.TweenService:Create(openButton, MENU_TWEEN_INFO, { BackgroundTransparency = (isOpen or Lib.CheckMouseInGui(openButton)) and 0 or 0.2 }):Play()

	if Main.MainGuiMouseEvent then
		Main.MainGuiMouseEvent:Disconnect()
		Main.MainGuiMouseEvent = nil
	end

	if isOpen then
		Main.MainGuiMouseEvent = service.UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if Lib.CheckMouseInGui(openButton) or Lib.CheckMouseInGui(menuFrame) then return end
			MainMenu.SetOpen(false)
		end)
		return
	end

	local closeTime = os.clock()
	Main.MainGuiCloseTime = closeTime
	task.delay(0.2, function()
		if not Main.MainGuiOpen and Main.MainGuiCloseTime == closeTime then menuFrame.Visible = false end
	end)
end

local function selectNode(node)
	local Explorer = Apps.Explorer
	Explorer.Selection:Set(node)
	Explorer.ViewNode(node)
end

local function createSelectionTools()
	local clickPartConnection
	Main.CreateApp({
		Name = "Click part to select",
		IconMap = Main.LargeIcons,
		Icon = 6,
		OnClick = function(isOpen)
			if clickPartConnection then
				clickPartConnection:Disconnect()
				clickPartConnection = nil
			end
			if not isOpen then return end

			local mouse = Main.Mouse
			clickPartConnection = Main.Track(mouse.Button1Down:Connect(function()
				local node = mouse.Target and nodes[mouse.Target]
				if node then selectNode(node) end
			end))
		end,
	})

	local clickGuiConnection
	local clickGuiApp
	clickGuiApp = Main.CreateApp({
		Name = "Click gui to select",
		IconMap = Main.LargeIcons,
		Icon = 6,
		OnClick = function(isOpen)
			if clickGuiConnection then
				clickGuiConnection:Disconnect()
				clickGuiConnection = nil
			end
			if not isOpen then return end

			clickGuiConnection = Main.Track(service.UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 or gameProcessed then return end

				local playerGui = plr:FindFirstChildWhichIsA("PlayerGui")
				if not playerGui then return end

				local position = input.Position
				for _, guiObject in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
					local node = nodes[guiObject]
					if node then
						selectNode(node)
						clickGuiApp.Disable()
						return
					end
				end
			end))
		end,
	})
end

local function createRejoinApp()
	Main.CreateApp({
		Name = "Rejoin Server",
		IconMap = Main.LargeIcons,
		Icon = 9,
		OnClick = function()
			local TeleportService = service.TeleportService
			if #service.Players:GetPlayers() <= 1 then
				plr:Kick("Rejoining...")
				task.wait()
				TeleportService:Teleport(game.PlaceId, plr)
			else
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, plr)
			end
		end,
	})
end

local SETTING_TOGGLES = {
	{ Name = "Show Deprecated Properties", Key = "ShowDeprecatedProperties" },
	{ Name = "Show Hidden Properties", Key = "ShowHiddenProperties" },
	{ Name = "Show Deprecated Events", Key = "ShowDeprecatedEvents" },
	{ Name = "Show Deprecated Functions", Key = "ShowDeprecatedFunctions" },
	{ Name = "Show Attributes", Key = "ShowAttributes" },
	{ Name = "Show Tags", Key = "ShowTags" },
}

local function createSettingToggles()
	for _, toggle in SETTING_TOGGLES do
		Main.CreateApp({
			Name = toggle.Name,
			IconMap = Main.LargeIcons,
			Container = Main.AppsSettings,
			Icon = 9,
			Open = Settings.Properties[toggle.Key],
			OnClick = function(isOpen)
				Settings.Properties[toggle.Key] = isOpen
				SettingsStore.save()
				Apps.Properties.ShowExplorerProps()
			end,
		})
	end
end

function MainMenu.create()
	local gui = buildGui()
	local openButton = gui.OpenButton
	local menuFrame = openButton.MainFrame

	Main.MainGui = gui
	Main.AppsFrame = menuFrame.AppsFrame
	Main.AppsContainer = Main.AppsFrame.Container
	Main.AppsContainerGrid = Main.AppsContainer.UIGridLayout

	Main.AppsSettings = Main.AppsContainer:Clone()
	Main.AppsSettings.Name = "Settings"
	Main.AppsSettings.Visible = false
	Main.AppsSettings.Parent = Main.AppsFrame
	Main.AppsSettingsGrid = Main.AppsSettings.UIGridLayout

	Main.AppTemplate = gui.App
	Main.MainGuiOpen = false

	openButton.BackgroundTransparency = 0.2
	menuFrame.Size = UDim2.new()
	menuFrame.Visible = false

	openButton.MouseButton1Click:Connect(function() MainMenu.SetOpen(not Main.MainGuiOpen) end)

	menuFrame.BottomFrame.Settings.MouseButton1Click:Connect(function() MainMenu.OpenSettings(not Main.MainGuiSettingsOpen) end)

	openButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		service.TweenService:Create(openButton, HOVER_TWEEN_INFO, { BackgroundTransparency = 0 }):Play()
	end)

	openButton.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		service.TweenService:Create(openButton, HOVER_TWEEN_INFO, { BackgroundTransparency = Main.MainGuiOpen and 0 or 0.2 }):Play()
	end)

	Main.CreateApp({ Name = "Explorer", IconMap = Main.LargeIcons, Icon = "Explorer", Open = true, Window = Apps.Explorer.Window })
	Main.CreateApp({ Name = "Properties", IconMap = Main.LargeIcons, Icon = "Properties", Open = true, Window = Apps.Properties.Window })
	Main.CreateApp({ Name = "Script Viewer", IconMap = Main.LargeIcons, Icon = "Script_Viewer", Window = Apps.ScriptViewer.Window })

	createSelectionTools()
	createRejoinApp()
	createSettingToggles()

	Main.ShowGui(gui)
end

return MainMenu
