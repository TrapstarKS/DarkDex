local __DARKDEX_MODULES={cache={}}do do local function __modImpl()--[[
	Shared state for every module.

	The tables here are created once and filled in place, so modules can capture them
	at load time. API and RMD are assigned by Main before the apps are loaded.
]]


























































































































local cloneref= cloneref or function(instance) return instance end

local service= setmetatable({}, {
	__index = function(self, name)
		local instance = cloneref(game:GetService(name))
		rawset(self, name, instance)
		return instance
	end,
})

local Players = service.Players

local Context = {
	Main = {} ,
	Lib = {} ,
	Apps = {} ,
	Settings = {} ,
	env = {} ,
	service = service,
	plr = Players.LocalPlayer or Players.PlayerAdded:Wait(),
	cloneref = cloneref,

	-- Explorer node for each instance, shared with the main menu tools
	Nodes = {} ,

	API = nil ,
	RMD = nil ,
}

return Context
end function __DARKDEX_MODULES.a()local v=__DARKDEX_MODULES.cache.a if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.a=v end return v.c end end do local function __modImpl()--[[
	HTTP helpers.

	Some executors return an error page or an empty string instead of throwing,
	so a response only counts when it passes the caller's validation.
]]


local Http = {}

function Http.get(url, isValid)	
local success, body = pcall(game.HttpGet, game, url)
	if not success then
		warn(`[DarkDex] GET {url} failed: {body}`)
		return nil
	end

	if type(body) ~= "string" or body == "" or (isValid and not isValid(body)) then
		warn(`[DarkDex] GET {url} returned an invalid response`)
		return nil
	end

	return body
end

-- Tries each url in order and returns the first valid response
function Http.getFirst(urls, isValid)	
for _, url in urls do
		local body = Http.get(url, isValid)
		if body then return body end
	end
	return nil
end

return Http
end function __DARKDEX_MODULES.b()local v=__DARKDEX_MODULES.cache.b if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.b=v end return v.c end end do local function __modImpl()--[[
	Source of the explorer class icons (16x16 strip indexed by the RMD ExplorerImageIndex).

	The client ships the same strip that the ReflectionMetadata indexes, so it is used
	first. When it cannot be loaded, a copy from the client tracker is cached in the
	workspace and loaded through getcustomasset. The old androssy.net mirror is gone.
]]


local Context = __DARKDEX_MODULES.a()
local Http = __DARKDEX_MODULES.b()

local env = Context.env
local service = Context.service

local CLIENT_ASSET = "rbxasset://textures/ClassImages.PNG"
local MIRROR_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/textures/ClassImages.PNG"
local CACHE_PATH = "dex/assets/ClassImages.png"
local PNG_SIGNATURE = "\137PNG\r\n\26\n"

local function isPng(data)return string.sub(data, 1, #PNG_SIGNATURE) == PNG_SIGNATURE end

local function canLoad(contentId)	
local loaded = false
	local success = pcall(service.ContentProvider.PreloadAsync, service.ContentProvider, { contentId }, function(_, status) loaded = status == Enum.AssetFetchStatus.Success end)
	return success and loaded
end

local function readCache()	
local success, data = pcall(function() return env.isfile(CACHE_PATH) and env.readfile(CACHE_PATH) end)
	if success and type(data) == "string" and isPng(data) then return data end
	return nil
end

local function loadCustomAsset()	
if not (env.getcustomasset and env.writefile and env.readfile and env.isfile) then return nil end

	if not readCache() then
		local data = Http.get(MIRROR_URL, isPng)
		if not data then return nil end

		local written = pcall(env.writefile, CACHE_PATH, data)
		if not written then return nil end
	end

	local success, asset = pcall(env.getcustomasset, CACHE_PATH)
	if success and type(asset) == "string" then return asset end
	return nil
end

local ClassImages = {}

function ClassImages.resolve()	
if canLoad(CLIENT_ASSET) then return CLIENT_ASSET end
	return loadCustomAsset() or CLIENT_ASSET
end

return ClassImages
end function __DARKDEX_MODULES.c()local v=__DARKDEX_MODULES.cache.c if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.c=v end return v.c end end do local function __modImpl()--[[
	Executor capability detection.

	Every optional executor function is read once into Context.env. A missing function
	is left nil and its name is recorded in Main.MissingEnv, so features can check
	`env.name` instead of touching executor globals directly.
]]


local Context = __DARKDEX_MODULES.a()

local env = Context.env
local Main = Context.Main

local function base64encode(data)	
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = table.create(math.ceil(#data / 3) * 4)

	for index = 1, #data, 3 do
		local a, b, c = string.byte(data, index, index + 2)
		local chunk = bit32.bor(bit32.lshift(a, 16), bit32.lshift(b or 0, 8), c or 0)
		for slot = 0, 3 do
			if slot <= 1 or (slot == 2 and b) or (slot == 3 and c) then
				local sextet = bit32.band(bit32.rshift(chunk, (3 - slot) * 6), 63)
				table.insert(output, string.sub(alphabet, sextet + 1, sextet + 1))
			else
				table.insert(output, "=")
			end
		end
	end

	return table.concat(output)
end

local Env = {}

function Env.init()
	Main.MissingEnv = {}

	local function define(name, value)
		if value == nil then
			table.insert(Main.MissingEnv, name)
			return
		end
		env[name] = value
	end

	-- Filesystem
	define("readfile", readfile)
	define("writefile", writefile)
	define("makefolder", makefolder)
	define("isfile", isfile)
	define("isfolder", isfolder)
	define("movefileas", movefileas)
	define("getcustomasset", getcustomasset or getsynasset)

	-- Inspection
	define("getscriptbytecode", getscriptbytecode or dumpstring)
	define("decompile", decompile)
	define("getnilinstances", getnilinstances or get_nil_instances)
	define("getloadedmodules", getloadedmodules)
	define("saveinstance", saveinstance)

	-- Other
	define("request", (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request)
	define("protectgui", protect_gui or (syn and syn.protect_gui))
	define("gethui", gethui or get_hidden_gui)
	define("setclipboard", setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set))

	local crypt = crypt or (syn and syn.crypt)
	env.base64encode = (crypt and (crypt.base64encode or crypt.base64_encode)) or base64_encode or base64encode
end

return Env
end function __DARKDEX_MODULES.d()local v=__DARKDEX_MODULES.cache.d if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.d=v end return v.c end end do local function __modImpl()









local Create = {}

function Create.create(data)	
local instances = {}
	for _, spec in data do
		instances[spec[1] ] = Instance.new(spec[2])
	end

	for _, spec in data do
		local instance = instances[spec[1] ]
		for property, value in spec[3] do
			if type(value) == "table" then
				instance[property] = instances[value[1] ]
			else
				instance[property] = value
			end
		end
	end

	return instances[1]
end

function Create.createSimple(className, properties)	
local instance = Instance.new(className)
	for property, value in properties do
		instance[property] = value
	end
	return instance
end

return Create
end function __DARKDEX_MODULES.e()local v=__DARKDEX_MODULES.cache.e if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.e=v end return v.c end end do local function __modImpl()--[[
	Animated loading screen shown while DarkDex initializes.
]]


local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Main = Context.Main
local service = Context.service

local TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PROGRESS_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local HIDDEN_SEQUENCE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1, 0), NumberSequenceKeypoint.new(1, 1, 0) })






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
local function tweenNumber(target, tweenInfo, onStep)
	local value = Instance.new("NumberValue")
	value.Changed:Connect(onStep)

	local tween = service.TweenService:Create(value, tweenInfo, { Value = target })
	tween.Completed:Once(function() value:Destroy() end)
	tween:Play()
end

local function play(instance, tweenInfo, goal) service.TweenService:Create(instance, tweenInfo, goal):Play() end

local Intro = {}

function Intro.create(initialStatus)	
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

	local function revealFromRight(gradient)
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

	local function setProgress(text, fraction)
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
end function __DARKDEX_MODULES.f()local v=__DARKDEX_MODULES.cache.f if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.f=v end return v.c end end do local function __modImpl()--[[
	Default settings and persistence of the user toggles.

	Settings is filled in place (Context.Settings) because modules hold a reference to
	it. Only the keys in PERSISTED_KEYS are written to disk.
]]


local Context = __DARKDEX_MODULES.a()

local Settings = Context.Settings
local env = Context.env
local service = Context.service

local SETTINGS_PATH = "dex/settings.json"

local PERSISTED_KEYS = {
	"ShowDeprecatedProperties",
	"ShowHiddenProperties",
	"ShowDeprecatedFunctions",
	"ShowDeprecatedEvents",
	"ShowAttributes",
	"ShowTags",
}

local rgb = Color3.fromRGB

-- Tables marked with _Recurse are merged key by key instead of replaced
local DEFAULT_SETTINGS = {
	Explorer = {
		_Recurse = true,
		Sorting = true,
		TeleportToOffset = Vector3.zero,
		ClickToRename = true,
		AutoUpdateSearch = true,
		LiveSearch = true, -- search while typing instead of on Enter
		AutoUpdateMode = 0, -- 0 Default, 1 no tree update, 2 no descendant events, 3 frozen
		PartSelectionBox = true,
		GuiSelectionBox = true,
		CopyPathUseGetChildren = true,
	},
	Properties = {
		_Recurse = true,
		MaxConflictCheck = 50,

		ClearOnFocus = false,
		LoadstringInput = true,
		NumberRounding = 3,

		ShowDeprecatedProperties = false,
		ShowHiddenProperties = false,

		ShowDeprecatedFunctions = false,
		ShowDeprecatedEvents = false,

		ShowAttributes = true,
		MaxAttributes = 50,

		ShowTags = true,
		MaxTags = 50,

		ScaleType = 1, -- 0 Full Name Shown, 1 Equal Halves
	},
	Theme = {
		_Recurse = true,
		Main1 = rgb(52, 52, 52),
		Main2 = rgb(45, 45, 45),
		Outline1 = rgb(33, 33, 33), -- Mainly frames
		Outline2 = rgb(55, 55, 55), -- Mainly button
		Outline3 = rgb(30, 30, 30), -- Mainly textbox
		TextBox = rgb(38, 38, 38),
		Menu = rgb(32, 32, 32),
		ListSelection = rgb(11, 90, 175),
		Button = rgb(60, 60, 60),
		ButtonHover = rgb(68, 68, 68),
		ButtonPress = rgb(40, 40, 40),
		Highlight = rgb(75, 75, 75),
		Text = rgb(255, 255, 255),
		PlaceholderText = rgb(100, 100, 100),
		Important = rgb(255, 0, 0),
		ExplorerIconMap = "",
		MiscIconMap = "",
		Syntax = {
			Text = rgb(204, 204, 204),
			Background = rgb(36, 36, 36),
			Selection = rgb(255, 255, 255),
			SelectionBack = rgb(11, 90, 175),
			Operator = rgb(204, 204, 204),
			Number = rgb(255, 198, 0),
			String = rgb(173, 241, 149),
			Comment = rgb(102, 102, 102),
			Keyword = rgb(248, 109, 124),
			Error = rgb(255, 0, 0),
			FindBackground = rgb(141, 118, 0),
			MatchingWord = rgb(85, 85, 85),
			BuiltIn = rgb(132, 214, 247),
			CurrentLine = rgb(45, 50, 65),
			LocalMethod = rgb(253, 251, 172),
			LocalProperty = rgb(97, 161, 241),
			Nil = rgb(255, 198, 0),
			Bool = rgb(255, 198, 0),
			Function = rgb(248, 109, 124),
			Local = rgb(248, 109, 124),
			Self = rgb(248, 109, 124),
			FunctionName = rgb(253, 251, 172),
			Bracket = rgb(204, 204, 204),
		},
	},
}

local SettingsStore = {}

function SettingsStore.reset()
	local function merge(source, target)
		for key, value in source do
			if type(value) == "table" and value._Recurse then
				if type(target[key]) ~= "table" then target[key] = {} end
				merge(value, target[key])
			else
				target[key] = value
			end
		end
	end

	merge(DEFAULT_SETTINGS, Settings)
end

function SettingsStore.load()
	if not env.readfile or not env.isfile then return end

	local readSuccess, contents = pcall(function() return env.isfile(SETTINGS_PATH) and env.readfile(SETTINGS_PATH) end)
	if not readSuccess or not contents or contents == "" then return end

	local decodeSuccess, decoded = pcall(service.HttpService.JSONDecode, service.HttpService, contents)
	if not decodeSuccess or type(decoded) ~= "table" then
		warn(`[DarkDex] Ignoring invalid {SETTINGS_PATH}`)
		return
	end

	local properties = Settings.Properties
	for _, key in PERSISTED_KEYS do
		local value = decoded[key]
		if type(value) == type(properties[key]) then properties[key] = value end
	end
end

function SettingsStore.save()
	if not env.writefile then return end

	local fields = {}
	for _, key in PERSISTED_KEYS do
		fields[key] = Settings.Properties[key]
	end

	local success, err = pcall(function() env.writefile(SETTINGS_PATH, service.HttpService:JSONEncode(fields)) end)
	if not success then warn(`[DarkDex] Failed to save settings: {err}`) end
end

return SettingsStore
end function __DARKDEX_MODULES.g()local v=__DARKDEX_MODULES.cache.g if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.g=v end return v.c end end do local function __modImpl()--[[
	The "Dex" button at the top of the screen with the app launcher and settings.
]]


local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()
local SettingsStore = __DARKDEX_MODULES.g()

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

function MainMenu.CreateApp(data)	
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

	local function setOpen(isOpen, silent)
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

	local control= {
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

function MainMenu.OpenSettings(isOpen)
	Main.MainGuiSettingsOpen = isOpen
	Main.AppsContainer.Visible = not isOpen
	Main.AppsSettings.Visible = isOpen
end

function MainMenu.SetOpen(isOpen)
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
end function __DARKDEX_MODULES.h()local v=__DARKDEX_MODULES.cache.h if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.h=v end return v.c end end do local function __modImpl()--[[
	getgenv().prettyPrint(value): readable serialization of tables for the console.
	Thanks corewave for the original version.
]]


local getmetatable = getrawmetatable or getmetatable

-- tostring that ignores a custom __tostring, so tables show their address
local function rawToString(value)	
local metatable = getmetatable(value)
	if type(metatable) ~= "table" then return tostring(value) end

	local custom = rawget(metatable, "__tostring")
	if custom == nil then return tostring(value) end

	local cleared = pcall(rawset, metatable, "__tostring", nil)
	if not cleared then return tostring(value) end

	local result = tostring(value)
	rawset(metatable, "__tostring", custom)
	return result
end

local function formatValue(value)	
local valueType = typeof(value)
	if valueType == "string" then return string.format("%q", value) end
	if valueType == "Instance" then return value:GetFullName() end
	if valueType == "table" or valueType == "userdata" then return rawToString(value) end
	if valueType == "boolean" or valueType == "function" or valueType == "number" or valueType == "nil" then return tostring(value) end
	return `{valueType}.new({value})`
end

local function serialize(value, depth, visiting)	
if type(value) ~= "table" then return formatValue(value) end
	if visiting[value] then return `{rawToString(value)} --[[cycle]]` end
	if next(value) == nil then return "{}" end

	visiting[value] = true

	local indent = string.rep("  ", depth)
	local lines = { "{" }
	for key, item in value do
		table.insert(lines, `{indent}[{serialize(key, depth + 1, visiting)}] = {serialize(item, depth + 1, visiting)},`)
	end
	table.insert(lines, string.rep("  ", depth - 1) .. "}")

	visiting[value] = nil
	return table.concat(lines, "\n")
end

local PrettyPrint = {}

function PrettyPrint.serialize(value)return serialize(value, 1, {}) end

function PrettyPrint.install()
	if getgenv then getgenv().prettyPrint = PrettyPrint.serialize end
end

return PrettyPrint
end function __DARKDEX_MODULES.i()local v=__DARKDEX_MODULES.cache.i if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.i=v end return v.c end end do local function __modImpl()--[[
	Parser for the Roblox API dump (API-Dump.json).
]]


local Context = __DARKDEX_MODULES.a()

local service = Context.service




























local function toTagSet(tags)	
local set = {}
	if tags then
		for _, tag in tags do
			-- Some tags are objects such as { PreferredDescriptor = ... }
			if type(tag) == "string" then set[tag] = true end
		end
	end
	return set
end

local function toParameters(parameters)	
local result = table.create(#parameters)
	for _, parameter in parameters do
		table.insert(result, { Name = parameter.Name, Type = parameter.Type.Name })
	end
	return result
end

local function moveAbove(list, item, aboveItem)
	local from = table.find(list, item)
	if not from then return end
	table.remove(list, from)

	local to = table.find(list, aboveItem)
	if not to then return end
	table.insert(list, to, item)
end

local Api = {}

function Api.parse(rawApi)	
local dump = service.HttpService:JSONDecode(rawApi)
	local classes= {}
	local superclassNames= {}
	local categoryOrder, seenCategories = {}, {}

	for _, class in dump.Classes do
		local newClass= {
			Name = class.Name,
			Superclass = nil,
			Properties = {},
			Functions = {},
			Events = {},
			Callbacks = {},
			Tags = toTagSet(class.Tags),
		}
		superclassNames[newClass] = class.Superclass

		for _, member in class.Members do
			local newMember= {
				Name = member.Name,
				Class = class.Name,
				Security = member.Security,
				Tags = toTagSet(member.Tags),
			}

			local memberType = member.MemberType
			if memberType == "Property" then
				local category = string.match(member.Category or "Other", "^%s*(.-)%s*$")
				if not seenCategories[category] then
					table.insert(categoryOrder, category)
					seenCategories[category] = true
				end
				newMember.ValueType = member.ValueType
				newMember.Category = category
				newMember.Serialization = member.Serialization
				table.insert(newClass.Properties, newMember)
			elseif memberType == "Function" then
				newMember.Parameters = toParameters(member.Parameters)
				newMember.ReturnType = member.ReturnType.Name
				table.insert(newClass.Functions, newMember)
			elseif memberType == "Event" then
				newMember.Parameters = toParameters(member.Parameters)
				table.insert(newClass.Events, newMember)
			end
		end

		classes[class.Name] = newClass
	end

	for class, superclassName in superclassNames do
		class.Superclass = classes[superclassName]
	end

	moveAbove(categoryOrder, "Behavior", "Tuning")
	moveAbove(categoryOrder, "Appearance", "Data")
	moveAbove(categoryOrder, "Attachments", "Axes")
	moveAbove(categoryOrder, "Cylinder", "Slider")
	moveAbove(categoryOrder, "Localization", "Jump Settings")
	moveAbove(categoryOrder, "Surface", "Motion")
	moveAbove(categoryOrder, "Surface Inputs", "Surface")
	moveAbove(categoryOrder, "Part", "Surface Inputs")
	moveAbove(categoryOrder, "Assembly", "Surface Inputs")
	moveAbove(categoryOrder, "Character", "Controls")
	table.insert(categoryOrder, "Unscriptable")
	table.insert(categoryOrder, "Tags")
	table.insert(categoryOrder, "Attributes")

	local categoryIndex = {}
	for index, category in categoryOrder do
		categoryIndex[category] = index
	end

	return {
		Classes = classes,
		CategoryOrder = categoryIndex,
	}
end

return Api
end function __DARKDEX_MODULES.j()local v=__DARKDEX_MODULES.cache.j if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.j=v end return v.c end end do local function __modImpl()












local SLASH_BYTE = string.byte("/")

local Xml = {}

function Xml.parse(source)	
source = string.gsub(source, "<!%-%-(.-)%-%->", "")

	local current= {}
	local stack= {}

	local function addText(text)
		text = string.match(text, "^%s*(.*%S)") or ""
		if #text ~= 0 then table.insert(current, { text = text }) end
	end

	for kind, name, closed, text in string.gmatch(source, "<([?!/]?)([-:_%w]+)%s*(/?>?)([^<]*)") do
		if kind == "" then
			local attrs = {}
			if closed == "" then
				local length = 0
				for all, attrName, _, value, startText in string.gmatch(text, "(.-([-_%w]+)%s*=%s*(.)(.-)%3%s*(/?>?))") do
					length += #all
					attrs[attrName] = value
					if #startText ~= 0 then
						text = string.sub(text, length + 1)
						closed = startText
						break
					end
				end
			end

			local node = { tag = name, attrs = attrs, children = {} }
			table.insert(current, node)

			if string.byte(closed, 1) ~= SLASH_BYTE then
				table.insert(stack, current)
				current = node.children
			end

			addText(text)
		elseif kind == "/" then
			current = table.remove(stack) or current
			addText(text)
		end
	end

	return { children = current }
end

return Xml
end function __DARKDEX_MODULES.k()local v=__DARKDEX_MODULES.cache.k if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.k=v end return v.c end end do local function __modImpl()--[[
	Parser for ReflectionMetadata.xml (explorer icons, property order and class info).
]]


local Xml = __DARKDEX_MODULES.k()













local function capitalize(name)return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) end

-- Reads a <Properties> node into { Name = text, ... }
local function readProperties(propertiesNode, into)	
for _, property in (propertiesNode.children )do
		local attrs = property.attrs
		if attrs and attrs.name then
			local valueNode = ((property.children ))[1]
			into[capitalize(attrs.name)] = valueNode and valueNode.text
		end
	end
	return into
end

-- Reads every ReflectionMetadataMember of a members container
local function readMembers(container, callback)
	for _, member in (container.children )do
		local memberChildren = (member.children )		
if member.attrs and member.attrs.class == "ReflectionMetadataMember" and memberChildren[1] and memberChildren[1].tag == "Properties" then callback(readProperties(memberChildren[1], {})) end
	end
end

local Rmd = {}

function Rmd.parse(rawXml)	
local document = Xml.parse(rawXml)
	local root = ((document.children[1] )).children
	local classList = root[1].children

	local classes= {}
	local propertyOrders= {}

	for _, classNode in classList do
		local className
		local metadata
		
for _, child in classNode.children do
			if child.tag == "Properties" then
				metadata = (readProperties(child, { Properties = {}, Functions = {} }) )				
className = metadata.Name
				classes[className] = metadata
			elseif metadata and child.attrs then
				local containerClass = child.attrs.class
				if containerClass == "ReflectionMetadataProperties" then
					readMembers(child, function(data)
						if data.PropertyOrder then
							local orders = propertyOrders[className]
							if not orders then
								orders = {}
								propertyOrders[className] = orders
							end
							orders[data.Name] = tonumber(data.PropertyOrder)
						end
						metadata.Properties[data.Name] = data
					end)
				elseif containerClass == "ReflectionMetadataFunctions" then
					readMembers(child, function(data) metadata.Functions[data.Name] = data end)
				end
			end
		end
	end

	return { Classes = classes, PropertyOrders = propertyOrders }
end

return Rmd
end function __DARKDEX_MODULES.l()local v=__DARKDEX_MODULES.cache.l if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.l=v end return v.c end end do local function __modImpl()--[[
	Downloads the API dump and ReflectionMetadata, caching both in the workspace.

	The cache is keyed by the running client version, so a cached copy is used without
	any request until Roblox updates.
]]


local Api = __DARKDEX_MODULES.j()
local Context = __DARKDEX_MODULES.a()
local Http = __DARKDEX_MODULES.b()
local Rmd = __DARKDEX_MODULES.l()

local env = Context.env

local VERSION_PATH = "dex/deps_version.dat"
local API_PATH = "dex/rbx_api.dat"
local RMD_PATH = "dex/rbx_rmd.dat"

local STUDIO_VERSION_URLS = {
	"https://clientsettings.roblox.com/v2/client-version/WindowsStudio64",
	"https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/version-guid.txt",
}
local API_URL = "https://setup.rbxcdn.com/%s-API-Dump.json"
local API_FALLBACK_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"
local RMD_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/ReflectionMetadata.xml"

local function readFile(path)	
if not (env.readfile and env.isfile) then return nil end

	local success, contents = pcall(function() return env.isfile(path) and env.readfile(path) end)
	if success and type(contents) == "string" and contents ~= "" then return contents end
	return nil
end

local function writeFile(path, contents)
	if not env.writefile then return end

	local success, err = pcall(env.writefile, path, contents)
	if not success then warn(`[DarkDex] Failed to write {path}: {err}`) end
end

local function getClientVersion()	
local success, clientVersion = pcall(version)
	return success and clientVersion or "unknown"
end

local function fetchStudioVersion()	
for _, url in STUDIO_VERSION_URLS do
		local body = Http.get(url)
		local studioVersion = body and string.match(body, "version%-%x+")
		if studioVersion then return studioVersion end
	end
	return nil
end

local function isJsonObject(body)return string.sub(body, 1, 1) == "{" end

local function isXml(body)return string.find(body, "<roblox", 1, true) ~= nil end

local function fetchApi()	
local studioVersion = fetchStudioVersion()
	local urls = studioVersion and { string.format(API_URL, studioVersion), API_FALLBACK_URL } or { API_FALLBACK_URL }
	return Http.getFirst(urls, isJsonObject) or error("Could not download the API dump")
end

local function fetchRmd()return Http.get(RMD_URL, isXml) or error("Could not download the ReflectionMetadata") end

local ReflectionData = {}

-- onProgress(status, fraction) is called before each slow step
function ReflectionData.load(onProgress)
	local clientVersion = getClientVersion()
	local isCached = readFile(VERSION_PATH) == clientVersion

	onProgress("Fetching API", 0.35)
	local rawApi = isCached and readFile(API_PATH) or nil
	local rawApiFromCache = rawApi ~= nil
	rawApi = rawApi or fetchApi()

	onProgress("Fetching RMD", 0.5)
	local rawRmd = isCached and readFile(RMD_PATH) or nil
	local rawRmdFromCache = rawRmd ~= nil
	rawRmd = rawRmd or fetchRmd()

	onProgress("Parsing API", 0.6)
	Context.API = Api.parse(rawApi)
	Context.RMD = Rmd.parse(rawRmd)

	if not (rawApiFromCache and rawRmdFromCache) then
		writeFile(API_PATH, rawApi)
		writeFile(RMD_PATH, rawRmd)
		writeFile(VERSION_PATH, clientVersion)
	end

	return Context.API, Context.RMD
end

return ReflectionData
end function __DARKDEX_MODULES.m()local v=__DARKDEX_MODULES.cache.m if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.m=v end return v.c end end do local function __modImpl()--[[
	UniversalSynSaveInstance, downloaded on first use instead of at startup.
]]


local Http = __DARKDEX_MODULES.b()

local SOURCE_URL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau"

local saveinstance

local SaveInstance = {}

function SaveInstance.get()	
if saveinstance then return saveinstance end

	local source = Http.get(SOURCE_URL) or error("Could not download SynSaveInstance")
	-- Renamed so the executor's own RequireOnlineModule global is not used by the module
	source = string.gsub(source, "RequireOnlineModule", "DarkDexRequireOnlineModule")

	local chunk, compileError = loadstring(source, "saveinstance")
	if not chunk then error(`Could not compile SynSaveInstance: {compileError}`) end

	saveinstance = chunk()
	return saveinstance 
end

function SaveInstance.run(options) SaveInstance.get()(options) end

return SaveInstance
end function __DARKDEX_MODULES.n()local v=__DARKDEX_MODULES.cache.n if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.n=v end return v.c end end do local function __modImpl()



































local KEYWORDS = {
	is = "is",
	classname = "class",
	c = "class",
	tag = "tag",
	name = "name",
}

local COMMANDS_WITH_ARGUMENT = {
	rad = true,
	isa = true,
}

-- Longest first so ">=" is not read as ">"
local OPERATORS = { "==", "~=", "!=", ">=", "<=", "=", ">", "<" }
local OPERATOR_ALIASES = { ["=="] = "=", ["!="] = "~=" }

local WORD_END = '[%s%(%)"=~<>!&|]'

local Parser = {}

function Parser.tokenize(query)	
local tokens= {}
	local index, length = 1, #query

	while index <= length do
		local char = string.sub(query, index, index)
		local pair = string.sub(query, index, index + 1)

		if string.find(char, "%s") then
			index += 1
		elseif char == "(" or char == ")" then
			table.insert(tokens, { type = char == "(" and "lparen" or "rparen", value = char })
			index += 1
		elseif char == '"' then
			local parts = {}
			local cursor = index + 1
			while true do
				if cursor > length then return nil, "Unclosed quote" end
				local current = string.sub(query, cursor, cursor)
				if current == "\\" and cursor < length then
					table.insert(parts, string.sub(query, cursor + 1, cursor + 1))
					cursor += 2
				elseif current == '"' then
					break
				else
					table.insert(parts, current)
					cursor += 1
				end
			end
			table.insert(tokens, { type = "string", value = table.concat(parts) })
			index = cursor + 1
		elseif pair == "&&" or pair == "||" then
			table.insert(tokens, { type = pair == "&&" and "and" or "or", value = pair })
			index += 2
		else
			local operator
			for _, candidate in OPERATORS do
				if string.sub(query, index, index + #candidate - 1) == candidate then
					operator = candidate
					break
				end
			end

			if operator then
				table.insert(tokens, { type = "op", value = OPERATOR_ALIASES[operator] or operator })
				index += #operator
			elseif char == "!" then
				table.insert(tokens, { type = "not", value = char })
				index += 1
			elseif char == "&" or char == "|" or char == "~" then
				-- A lone & | ~ is part of a name
				table.insert(tokens, { type = "word", value = char })
				index += 1
			else
				local wordEnd = (string.find(query, WORD_END, index) or length + 1) - 1
				local word = string.sub(query, index, wordEnd)
				local lower = string.lower(word)
				if lower == "and" or lower == "or" or lower == "not" then
					table.insert(tokens, { type = lower , value = word })
				else
					table.insert(tokens, { type = "word", value = word })
				end
				index = wordEnd + 1
			end
		end
	end

	return tokens, nil
end

local function isPath(word)	-- A number such as 1.5 is a name, not a path
	
return string.find(word, ".", 1, true) ~= nil and tonumber(word) == nil and not string.find(word, "^%.") and not string.find(word, "%.$")
end

function Parser.parse(query)	
local tokens, tokenizeError = Parser.tokenize(query)
	if not tokens then return nil, tokenizeError end
	if #tokens == 0 then return nil, nil end

	local position = 1

	local function peek()return tokens[position] end

	local function advance()		
local token = tokens[position]
		position += 1
		return token
	end

	local function isValueToken(token)return token ~= nil and (token.type == "word" or token.type == "string") end

	local parseOr

	local function parsePrimary()		
local token = advance()
		if not token then error("Unexpected end of search", 0) end

		if token.type == "lparen" then
			local expr = parseOr()
			local closing = advance()
			if not closing or closing.type ~= "rparen" then error("Unclosed parenthesis", 0) end
			return expr
		elseif token.type == "string" then
			return { kind = "name", value = token.value }
		elseif token.type ~= "word" then
			error(`Unexpected "{token.value}"`, 0)
		end

		local word = token.value

		local command = string.match(word, "^/(%a+)$")
		if command then
			command = string.lower(command)
			local arg
			if COMMANDS_WITH_ARGUMENT[command] and isValueToken(peek()) then arg = advance().value end
			if command == "isa" then return { kind = "keyword", keyword = "is", value = arg or "" } end
			return { kind = "command", name = command, arg = arg }
		end

		local keywordName, keywordValue = string.match(word, "^(%a+):(.*)$")
		local keyword = keywordName and KEYWORDS[string.lower(keywordName)]
		if keyword then
			if keywordValue == "" then
				if not isValueToken(peek()) then error(`Missing value after {keywordName}:`, 0) end
				keywordValue = advance().value
			end
			return { kind = "keyword", keyword = keyword, value = keywordValue }
		end

		local nextToken = peek()
		if nextToken and nextToken.type == "op" then
			advance()
			local value = isValueToken(peek()) and advance().value or ""
			local propertyName = string.gsub(word, "^%.", "")
			return { kind = "property", path = string.split(propertyName, "."), op = (nextToken.value ), value = value }
		end

		if isPath(word) then return { kind = "path", segments = string.split(word, ".") } end

		return { kind = "name", value = word }
	end

	local function parseUnary()		
local token = peek()
		if token and token.type == "not" then
			advance()
			return { kind = "not", expr = parseUnary() }
		end
		return parsePrimary()
	end

	local function parseAnd()		
local left = parseUnary()
		while true do
			local token = peek()
			if not token or token.type == "rparen" or token.type == "or" then break end
			if token.type == "and" then advance() end
			left = { kind = "and", left = left, right = parseUnary() }
		end
		return left
	end

	function parseOr()		
local left = parseAnd()
		while peek() and ((peek() )).type == "or" do
			advance()
			left = { kind = "or", left = left, right = parseAnd() }
		end
		return left
	end

	local success, result = pcall(function()
		local expr = parseOr()
		local extra = peek()
		if extra then error(`Unexpected "{extra.value}"`, 0) end
		return expr
	end)

	if not success then return nil, tostring(result) end
	return result, nil
end

return Parser
end function __DARKDEX_MODULES.o()local v=__DARKDEX_MODULES.cache.o if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.o=v end return v.c end end do local function __modImpl()--[[
	Compiles a search query (see Search/Parser) into a predicate over instances.

	Matching follows the Studio Explorer filter: names, strings and enums match partially
	and case insensitively (an enum value that matches an item exactly only matches that
	item), booleans accept prefixes such as "t", colors use 0-255 and quoted whole values
	such as "1, 2, 3" are compared component by component.
]]


local Context = __DARKDEX_MODULES.a()
local Parser = __DARKDEX_MODULES.o()

local service = Context.service
local env = Context.env



local NUMBER_EPSILON = 1e-4

local FIELD_NAMES = {
	x = "X",
	y = "Y",
	z = "Z",
	r = "R",
	g = "G",
	b = "B",
	scale = "Scale",
	offset = "Offset",
	min = "Min",
	max = "Max",
	width = "Width",
	height = "Height",
	position = "Position",
	rotation = "Rotation",
	lookvector = "LookVector",
	rightvector = "RightVector",
	upvector = "UpVector",
	magnitude = "Magnitude",
	density = "Density",
	friction = "Friction",
	elasticity = "Elasticity",
}

local Query = {}

-- lower-case property name -> real name, per class
local propertyNameCache= {}
local classNameCache

local function getClassNames()	
if classNameCache then return classNameCache end

	local names = {}
	for className in Context.API.Classes do
		names[string.lower(className)] = className
	end
	classNameCache = names
	return names
end

local function resolvePropertyName(className, lowerName)	
local cache = propertyNameCache[className]
	if not cache then
		cache = {}
		propertyNameCache[className] = cache
	end

	local cached = cache[lowerName]
	if cached ~= nil then return cached or nil end

	local apiClass = Context.API.Classes[className]
	while apiClass do
		for _, property in apiClass.Properties do
			if string.lower(property.Name) == lowerName then
				cache[lowerName] = property.Name
				return property.Name
			end
		end
		apiClass = apiClass.Superclass
	end

	cache[lowerName] = false
	return nil
end

local function readField(value, fieldName)	
local valueType = typeof(value)
	local lowerField = string.lower(fieldName)
	local realName = FIELD_NAMES[lowerField] or fieldName

	local success, fieldValue = pcall(function() return value[realName] end)
	if not success then return false, nil end

	-- Studio compares color channels in 0-255
	if valueType == "Color3" and (lowerField == "r" or lowerField == "g" or lowerField == "b") then
		fieldValue *= 255
	end
	return true, fieldValue
end

local function readProperty(obj, path)	
local propertyName = resolvePropertyName(obj.ClassName, string.lower(path[1]))
	if not propertyName then return false, nil end

	local success, value = pcall(function() return (obj )[propertyName] end)
	if not success then return false, nil end

	for index = 2, #path do
		if value == nil then return false, nil end
		local found
		found, value = readField(value, path[index])
		if not found then return false, nil end
	end

	return true, value
end

local function parseBoolean(text)	
local lower = string.lower(text)
	if lower == "" then return nil end
	if lower == "1" or lower == "yes" or string.sub("true", 1, #lower) == lower then return true end
	if lower == "0" or lower == "no" or string.sub("false", 1, #lower) == lower then return false end
	return nil
end

local function parseNumbers(text)	
local numbers = {}
	for token in string.gmatch(text, "[%-%+]?%d*%.?%d+[eE]?[%-%+]?%d*") do
		local number = tonumber(token)
		if number then table.insert(numbers, number) end
	end
	return numbers
end

-- Numeric components of a whole value, colors in 0-255
local function getComponents(value)	
if typeof(value) == "Color3" then return { value.R * 255, value.G * 255, value.B * 255 } end
	if typeof(value) == "CFrame" then return { value:GetComponents() } end
	return parseNumbers(tostring(value))
end

local function compareNumbers(a, op, b)	
if op == "=" then return math.abs(a - b) <= NUMBER_EPSILON end
	if op == "~=" then return math.abs(a - b) > NUMBER_EPSILON end
	if op == ">" then return a > b end
	if op == "<" then return a < b end
	if op == ">=" then return a >= b - NUMBER_EPSILON end
	if op == "<=" then return a <= b + NUMBER_EPSILON end
	return false
end

local function compareText(text, op, query)	
text = string.lower(text)
	query = string.lower(query)
	if op == "=" then return string.find(text, query, 1, true) ~= nil end
	if op == "~=" then return string.find(text, query, 1, true) == nil end
	if op == ">" then return text > query end
	if op == "<" then return text < query end
	if op == ">=" then return text >= query end
	if op == "<=" then return text <= query end
	return false
end

local enumExactCache= {}

local function matchesEnum(item, op, query)	
local lowerQuery = string.lower(query)
	local enumType = item.EnumType

	local exactNames = enumExactCache[enumType]
	if not exactNames then
		exactNames = {}
		for _, enumItem in enumType:GetEnumItems() do
			exactNames[string.lower(enumItem.Name)] = true
		end
		enumExactCache[enumType] = exactNames
	end

	local itemName = string.lower(item.Name)
	local isMatch
	if exactNames[lowerQuery] then
		isMatch = itemName == lowerQuery
	else
		isMatch = string.find(itemName, lowerQuery, 1, true) ~= nil
	end

	if op == "=" then return isMatch end
	if op == "~=" then return not isMatch end
	return compareText(item.Name, op, query)
end

local function compareValue(value, op, query)	
local valueType = typeof(value)

	-- An empty query asks whether the property is empty, e.g. MeshId=
	if query == "" then
		local isEmpty = value == nil or value == ""
		if op == "=" then return isEmpty end
		if op == "~=" then return not isEmpty end
		return false
	end

	if valueType == "boolean" then
		local expected = parseBoolean(query)
		if expected == nil then return false end
		if op == "=" then return value == expected end
		if op == "~=" then return value ~= expected end
		return false
	elseif valueType == "number" then
		local expected = tonumber(query)
		return expected ~= nil and compareNumbers(value, op, expected)
	elseif valueType == "string" then
		return compareText(value, op, query)
	elseif valueType == "EnumItem" then
		return matchesEnum(value, op, query)
	elseif valueType == "Instance" then
		return compareText(value.Name, op, query)
	elseif valueType == "BrickColor" then
		return compareText(value.Name, op, query)
	elseif value == nil then
		return op == "~=" or (op == "=" and string.lower(query) == "nil")
	end

	local components = getComponents(value)
	local expected = parseNumbers(query)
	if #components == 0 or #expected ~= #components then return compareText(tostring(value), op, query) end

	if op == "~=" then
		for index, component in components do
			if not compareNumbers(component, "=", expected[index]) then return true end
		end
		return false
	end

	for index, component in components do
		if not compareNumbers(component, op, expected[index]) then return false end
	end
	return true
end

local function containsName(obj, lowerNeedle)return string.find(string.lower(obj.Name), lowerNeedle, 1, true) ~= nil end

local function compilePath(segments)	
local lowerSegments = table.create(#segments)
	for index, segment in segments do
		lowerSegments[index] = string.lower(segment)
	end

	local function matchSegment(obj, index)		
if not obj then return false end

		local segment = lowerSegments[index]
		if segment == "**" then
			-- One or more levels: the object itself and any number of its ancestors
			if index == 1 then return true end
			local ancestor = obj.Parent
			while ancestor do
				if matchSegment(ancestor, index - 1) then return true end
				ancestor = ancestor.Parent
			end
			return false
		end

		if segment ~= "*" and not containsName(obj, segment) then return false end
		if index == 1 then return true end
		return matchSegment(obj.Parent, index - 1)
	end

	local lastIndex = #lowerSegments
	return function(obj) return matchSegment(obj, lastIndex) end
end

local function compileKeyword(keyword, value)	
local lowerValue = string.lower(value)

	if keyword == "is" then
		local className = getClassNames()[lowerValue]
		if not className then
			return function() return false end
		end
		return function(obj) return obj:IsA(className) end
	elseif keyword == "class" then
		return function(obj) return string.lower(obj.ClassName) == lowerValue end
	elseif keyword == "tag" then
		-- Instances of every tag whose name contains the value
		local tagged= {}
		local CollectionService = service.CollectionService
		for _, tag in CollectionService:GetAllTags() do
			if string.find(string.lower(tag), lowerValue, 1, true) then
				for _, instance in CollectionService:GetTagged(tag) do
					tagged[instance] = true
				end
			end
		end
		return function(obj) return tagged[obj] == true end
	end

	return function(obj) return containsName(obj, lowerValue) end
end

local function compileCommand(name, arg)	
if name == "remotes" then
		return function(obj) return obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") end
	elseif name == "bindables" then
		return function(obj) return obj:IsA("BindableEvent") or obj:IsA("BindableFunction") end
	elseif name == "players" then
		local players = {}
		for _, player in service.Players:GetPlayers() do
			players[player] = true
		end
		return function(obj) return players[obj] == true end
	elseif name == "loadedmodules" then
		if not env.getloadedmodules then return nil, "/loadedmodules needs getloadedmodules" end
		local modules = {}
		for _, module in env.getloadedmodules() do
			modules[module] = true
		end
		return function(obj) return modules[obj] == true end
	elseif name == "rad" then
		local radius = tonumber(arg)
		if not radius then return nil, "/rad needs a distance, e.g. /rad 50" end
		local character = Context.plr.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then return nil, "/rad needs your character" end
		local origin = root.Position
		return function(obj) return obj:IsA("BasePart") and ((obj ).Position - origin).Magnitude <= radius end
	end
	return nil, `Unknown command /{name}`
end

local function compileNode(node)	
local kind = node.kind
	if kind == "and" then
		local left, right = compileNode(node.left), compileNode(node.right)
		return function(obj) return left(obj) and right(obj) end
	elseif kind == "or" then
		local left, right = compileNode(node.left), compileNode(node.right)
		return function(obj) return left(obj) or right(obj) end
	elseif kind == "not" then
		local expr = compileNode(node.expr)
		return function(obj) return not expr(obj) end
	elseif kind == "name" then
		local needle = string.lower(node.value)
		return function(obj) return containsName(obj, needle) end
	elseif kind == "keyword" then
		return compileKeyword(node.keyword, node.value)
	elseif kind == "property" then
		local path, op, value = node.path, node.op, node.value
		return function(obj)
			local found, propertyValue = readProperty(obj, path)
			return found and compareValue(propertyValue, op, value)
		end
	elseif kind == "path" then
		return compilePath(node.segments)
	end

	local predicate, err = compileCommand(node.name, node.arg)
	if not predicate then error(err, 0) end
	return predicate
end

-- Returns nil and an error message when the query is invalid, nil and nil when empty
function Query.compile(query)	
local ast, parseError = Parser.parse(query)
	if not ast then return nil, parseError end

	local success, result = pcall(compileNode, ast)
	if not success then return nil, tostring(result) end
	return result, nil
end

return Query
end function __DARKDEX_MODULES.p()local v=__DARKDEX_MODULES.cache.p if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.p=v end return v.c end end do local function __modImpl()--[[
	Autocomplete for the Explorer search box.

	get(text) looks at the token being typed and returns completions that replace it:
	suggested filters for an empty box, classes after is:/c:, tags after tag:, property
	names, and enum or boolean values after a property operator.
]]


local Context = __DARKDEX_MODULES.a()

local service = Context.service







local MAX_SUGGESTIONS = 50

local SUGGESTED_FILTERS = { "anchored=", "locked=", "transparency=", "material=", "meshId=", "textureId=", "tag:", "is:" }
local CLASS_KEYWORDS = { is = true, c = true, classname = true }
local KEYWORDS = { "is:", "c:", "classname:", "tag:", "name:" }



local propertyIndex
local propertyNames
local classList

local function getPropertyIndex()	
if propertyIndex and propertyNames then return propertyIndex, propertyNames end

	local index, names = {}, {}
	for _, class in Context.API.Classes do
		for _, property in class.Properties do
			local lower = string.lower(property.Name)
			if not index[lower] then
				index[lower] = property
				table.insert(names, property.Name)
			end
		end
	end
	table.sort(names)

	propertyIndex, propertyNames = index, names
	return index, names
end

local function getClassList()	
if classList then return classList end

	local list = {}
	for className in Context.API.Classes do
		table.insert(list, className)
	end
	table.sort(list)
	classList = list
	return list
end

-- Items that start with the query first, then items that contain it
local function filterByQuery(items, query, limit)	
local lowerQuery = string.lower(query)
	local startsWith, contains = {}, {}

	for _, item in items do
		local lowerItem = string.lower(item)
		if string.sub(lowerItem, 1, #lowerQuery) == lowerQuery then
			table.insert(startsWith, item)
			if #startsWith >= limit then break end
		elseif #contains < limit and string.find(lowerItem, lowerQuery, 1, true) then
			table.insert(contains, item)
		end
	end

	for _, item in contains do
		if #startsWith >= limit then break end
		table.insert(startsWith, item)
	end
	return startsWith
end

local function quoteIfNeeded(value)	
if string.find(value, "^[%w_%-%.]+$") then return value end
	return `"{string.gsub(value, '"', '\\"')}"`
end

-- Splits the text into the part before the token being typed and the token itself
local function splitCurrentToken(text)	
local tokenStart = 1
	local inQuote = false

	for index = 1, #text do
		local char = string.sub(text, index, index)
		if char == '"' then
			inQuote = not inQuote
		elseif not inQuote and (string.find(char, "%s") or char == "(" or char == ")") then
			tokenStart = index + 1
		end
	end

	return string.sub(text, 1, tokenStart - 1), string.sub(text, tokenStart), inQuote
end

local Suggest = {}

function Suggest.get(text)	
local results= {}
	local before, current, inQuote = splitCurrentToken(text)

	if current == "" then
		if string.find(before, "^%s*$") then
			for _, filter in SUGGESTED_FILTERS do
				table.insert(results, { Text = filter, Label = filter })
			end
			return results, "Suggested Filters"
		end
		return results, nil
	end

	local keywordName, keywordValue = string.match(current, "^(%a+):(.*)$")
	if keywordName then
		local keyword = string.lower(keywordName)
		local value = string.gsub(keywordValue, '"', "")

		if CLASS_KEYWORDS[keyword] then
			for _, className in filterByQuery(getClassList(), value, MAX_SUGGESTIONS) do
				table.insert(results, { Text = `{before}{keywordName}:{className}`, Label = className, ClassIcon = className })
			end
			return results, "Classes"
		elseif keyword == "tag" then
			local tags = service.CollectionService:GetAllTags()
			table.sort(tags)
			for _, tag in filterByQuery(tags, value, MAX_SUGGESTIONS) do
				table.insert(results, { Text = `{before}{keywordName}:{quoteIfNeeded(tag)}`, Label = tag })
			end
			return results, "Tags"
		end
		return results, nil
	end

	if inQuote then return results, nil end

	local dot, propertyPath, operator, value = string.match(current, "^(%.?)([%w_%.]+)([=~<>!]+)(.*)$")
	if propertyPath then
		local propertyName = string.split(propertyPath, ".")[1]
		local info = getPropertyIndex()[string.lower(propertyName)]
		if not info or propertyPath ~= propertyName then return results, nil end

		local valueType = info.ValueType
		local options = {}
		if valueType.Category == "Enum" then
			local success, enum = pcall(function() return (Enum )[valueType.Name] end)
			if success and enum then
				for _, item in enum:GetEnumItems() do
					table.insert(options, item.Name)
				end
				table.sort(options)
			end
		elseif valueType.Name == "bool" then
			options = { "true", "false" }
		end

		for _, option in filterByQuery(options, (string.gsub(value, '"', "")), MAX_SUGGESTIONS) do
			table.insert(results, { Text = `{before}{dot}{info.Name}{operator}{option}`, Label = option })
		end
		return results, #results > 0 and info.Name or nil
	end

	local wordDot, word = string.match(current, "^(%.?)([%a_][%w_]*)$")
	if word then
		local lowerWord = string.lower(word)
		if wordDot == "" then
			for _, keyword in KEYWORDS do
				if string.sub(keyword, 1, #lowerWord) == lowerWord then table.insert(results, { Text = before .. keyword, Label = keyword }) end
			end
		end

		local _, names = getPropertyIndex()
		for _, name in filterByQuery(names, word, MAX_SUGGESTIONS - #results) do
			table.insert(results, { Text = `{before}{wordDot}{name}=`, Label = name .. "=" })
		end
		return results, nil
	end

	return results, nil
end

return Suggest
end function __DARKDEX_MODULES.q()local v=__DARKDEX_MODULES.cache.q if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.q=v end return v.c end end do local function __modImpl()--[[
	Explorer App Module

	The main explorer interface
]]


local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()
local SaveInstance = __DARKDEX_MODULES.n()
local SearchQuery = __DARKDEX_MODULES.p()
local Suggest = __DARKDEX_MODULES.q()

local Main = Context.Main
local Lib = Context.Lib
local Apps = Context.Apps
local Settings = Context.Settings
local env = Context.env
local service = Context.service
local plr = Context.plr
local create = Create.create
local nodes = Context.Nodes
local API, RMD
local Explorer, Properties, ScriptViewer
local selection

-- Shortens copied paths: workspace and the LocalPlayer instead of their full GetService paths
local function shortenPath(path)	
local workspacePrefix = 'game:GetService("Workspace")'
	if string.sub(path, 1, #workspacePrefix) == workspacePrefix then path = "workspace" .. string.sub(path, #workspacePrefix + 1) end

	local playerPrefix = 'game:GetService("Players").' .. plr.Name
	if string.sub(path, 1, #playerPrefix) == playerPrefix then path = 'game:GetService("Players").LocalPlayer' .. string.sub(path, #playerPrefix + 1) end

	return path
end

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer
end

local function main()
	API, RMD = Context.API, Context.RMD
	local Explorer = {}
	local tree, listEntries, explorerOrders, searchResults = {}, {}, {}, {}
	local expanded
	local entryTemplate, treeFrame, toolBar, descendantAddedCon, descendantRemovingCon, itemChangedCon
	local ffa = game.FindFirstAncestorWhichIsA
	local getDescendants = game.GetDescendants
	local getTextSize = service.TextService.GetTextSize
	local updateDebounce, refreshDebounce = false, false
	local nilNode = { Obj = Instance.new("Folder") }
	local idCounter = 0
	local scrollV, scrollH, clipboard
	local renameBox, renamingNode, searchFunc
	local sortingEnabled, autoUpdateSearch
	local table, math = table, math
	local nilMap, nilCons = {}, {}
	local connectSignal = game.DescendantAdded.Connect
	local addObject, removeObject, moveObject = nil, nil, nil
	local pendingDelParents = {}

	addObject = function(root)
		if nodes[root] then return end

		local isNil = false
		local rootParObj = ffa(root, "Instance")
		local par = nodes[rootParObj]

		-- Nil Handling
		if not par then
			if nilMap[root] then
				nilCons[root] = nilCons[root] or {
					connectSignal(root.ChildAdded, addObject),
					connectSignal(root.AncestryChanged, moveObject),
				}
				par = nilNode
				isNil = true
			else
				return
			end
		elseif nilMap[rootParObj] or par == nilNode then
			nilMap[root] = true
			nilCons[root] = nilCons[root] or {
				connectSignal(root.ChildAdded, addObject),
				connectSignal(root.AncestryChanged, moveObject),
			}
			isNil = true
		end

		local newNode = { Obj = root, Parent = par }
		nodes[root] = newNode

		-- Automatic sorting if expanded
		if sortingEnabled and expanded[par] and par.Sorted then
			local left, right = 1, #par
			local floor = math.floor
			local sorter = Explorer.NodeSorter
			local pos = (right == 0 and 1)

			if not pos then
				while true do
					if left >= right then
						if sorter(newNode, par[left]) then
							pos = left
						else
							pos = left + 1
						end
						break
					end

					local mid = floor((left + right) / 2)
					if sorter(newNode, par[mid]) then
						right = mid - 1
					else
						left = mid + 1
					end
				end
			end

			table.insert(par, pos, newNode)
		else
			par[#par + 1] = newNode
			par.Sorted = nil
		end

		local insts = getDescendants(root)
		for i = 1, #insts do
			local obj = insts[i]
			if nodes[obj] then continue end -- Deferred

			local par = nodes[ffa(obj, "Instance")]
			if not par then continue end
			local newNode = { Obj = obj, Parent = par }
			nodes[obj] = newNode
			par[#par + 1] = newNode

			-- Nil Handling
			if isNil then
				nilMap[obj] = true
				nilCons[obj] = nilCons[obj] or {
					connectSignal(obj.ChildAdded, addObject),
					connectSignal(obj.AncestryChanged, moveObject),
				}
			end
		end

		if searchFunc and autoUpdateSearch then searchFunc({ newNode }) end

		if not updateDebounce and Explorer.IsNodeVisible(par) then
			if expanded[par] then
				Explorer.PerformUpdate()
			elseif not refreshDebounce then
				Explorer.PerformRefresh()
			end
		end
	end

	removeObject = function(root)
		local node = nodes[root]
		if not node then return end

		-- Nil Handling
		if nilMap[node.Obj] then
			moveObject(node.Obj)
			return
		end

		local par = node.Parent
		if par and not par.HasDel then
			par.HasDel = true
			pendingDelParents[par] = true
		end

		local function recur(root)
			for i = 1, #root do
				local node = root[i]
				if not node.Del then
					nodes[node.Obj] = nil
					if #node > 0 then recur(node) end
				end
			end
		end
		recur(node)
		node.Del = true
		nodes[root] = nil

		if par and not updateDebounce and Explorer.IsNodeVisible(par) then
			if expanded[par] then
				Explorer.PerformUpdate()
			elseif not refreshDebounce then
				Explorer.PerformRefresh()
			end
		end
	end

	moveObject = function(obj)
		local node = nodes[obj]
		if not node then return end

		local oldPar = node.Parent
		local newPar = nodes[ffa(obj, "Instance")]
		if oldPar == newPar then return end

		-- Nil Handling
		if not newPar then
			if nilMap[obj] then
				newPar = nilNode
			else
				return
			end
		elseif nilMap[newPar.Obj] or newPar == nilNode then
			nilMap[obj] = true
			nilCons[obj] = nilCons[obj] or {
				connectSignal(obj.ChildAdded, addObject),
				connectSignal(obj.AncestryChanged, moveObject),
			}
		end

		if oldPar then
			local parPos = table.find(oldPar, node)
			if parPos then table.remove(oldPar, parPos) end
		end

		node.Id = nil
		node.Parent = newPar

		if sortingEnabled and expanded[newPar] and newPar.Sorted then
			local left, right = 1, #newPar
			local floor = math.floor
			local sorter = Explorer.NodeSorter
			local pos = (right == 0 and 1)

			if not pos then
				while true do
					if left >= right then
						if sorter(node, newPar[left]) then
							pos = left
						else
							pos = left + 1
						end
						break
					end

					local mid = floor((left + right) / 2)
					if sorter(node, newPar[mid]) then
						right = mid - 1
					else
						left = mid + 1
					end
				end
			end

			table.insert(newPar, pos, node)
		else
			newPar[#newPar + 1] = node
			newPar.Sorted = nil
		end

		if searchFunc and searchResults[node] then
			local currentNode = node.Parent
			while currentNode and (not searchResults[currentNode] or expanded[currentNode] == 0) do
				expanded[currentNode] = true
				searchResults[currentNode] = true
				currentNode = currentNode.Parent
			end
		end

		if not updateDebounce and (Explorer.IsNodeVisible(newPar) or Explorer.IsNodeVisible(oldPar)) then
			if expanded[newPar] or expanded[oldPar] then
				Explorer.PerformUpdate()
			elseif not refreshDebounce then
				Explorer.PerformRefresh()
			end
		end
	end

	Explorer.ViewWidth = 0
	Explorer.Index = 0
	Explorer.EntryIndent = 20
	Explorer.FreeWidth = 32
	Explorer.GuiElems = {}

	Explorer.InitRenameBox = function()
		renameBox = create({
			{
				1,
				"TextBox",
				{
					BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799),
					BorderColor3 = Color3.new(0.062745101749897, 0.51764708757401, 1),
					BorderMode = 2,
					ClearTextOnFocus = false,
					Font = 3,
					Name = "RenameBox",
					PlaceholderColor3 = Color3.new(0.69803923368454, 0.69803923368454, 0.69803923368454),
					Position = UDim2.new(0, 26, 0, 2),
					Size = UDim2.new(0, 200, 0, 16),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextXAlignment = 0,
					Visible = false,
					ZIndex = 2,
				},
			},
		})

		renameBox.Parent = Explorer.Window.GuiElems.Content.List

		renameBox.FocusLost:Connect(function()
			if not renamingNode then return end

			pcall(function() renamingNode.Obj.Name = renameBox.Text end)
			renamingNode = nil
			Explorer.Refresh()
		end)

		renameBox.Focused:Connect(function()
			renameBox.SelectionStart = 1
			renameBox.CursorPosition = #renameBox.Text + 1
		end)
	end

	Explorer.SetRenamingNode = function(node)
		renamingNode = node
		renameBox.Text = tostring(node.Obj)
		renameBox:CaptureFocus()
		Explorer.Refresh()
	end

	Explorer.SetSortingEnabled = function(val)
		sortingEnabled = val
		Settings.Explorer.Sorting = val
	end

	Explorer.UpdateView = function()
		local maxNodes = math.ceil(treeFrame.AbsoluteSize.Y / 20)
		local maxX = treeFrame.AbsoluteSize.X
		local totalWidth = Explorer.ViewWidth + Explorer.FreeWidth

		scrollV.VisibleSpace = maxNodes
		scrollV.TotalSpace = #tree + 1
		scrollH.VisibleSpace = maxX
		scrollH.TotalSpace = totalWidth

		scrollV.Gui.Visible = #tree + 1 > maxNodes
		scrollH.Gui.Visible = totalWidth > maxX

		local oldSize = treeFrame.Size
		treeFrame.Size = UDim2.new(1, (scrollV.Gui.Visible and -16 or 0), 1, (scrollH.Gui.Visible and -39 or -23))
		if oldSize ~= treeFrame.Size then
			Explorer.UpdateView()
		else
			scrollV:Update()
			scrollH:Update()

			renameBox.Size = UDim2.new(0, maxX - 100, 0, 16)

			if scrollV.Gui.Visible and scrollH.Gui.Visible then
				scrollV.Gui.Size = UDim2.new(0, 16, 1, -39)
				scrollH.Gui.Size = UDim2.new(1, -16, 0, 16)
				Explorer.Window.GuiElems.Content.ScrollCorner.Visible = true
			else
				scrollV.Gui.Size = UDim2.new(0, 16, 1, -23)
				scrollH.Gui.Size = UDim2.new(1, 0, 0, 16)
				Explorer.Window.GuiElems.Content.ScrollCorner.Visible = false
			end

			Explorer.Index = scrollV.Index
		end
	end

	Explorer.NodeSorter = function(a, b)
		if a.Del or b.Del then return false end -- Ghost node

		local aClass = a.Class
		local bClass = b.Class
		if not aClass then
			aClass = a.Obj.ClassName
			a.Class = aClass
		end
		if not bClass then
			bClass = b.Obj.ClassName
			b.Class = bClass
		end

		local aOrder = explorerOrders[aClass]
		local bOrder = explorerOrders[bClass]
		if not aOrder then
			aOrder = RMD.Classes[aClass] and tonumber(RMD.Classes[aClass].ExplorerOrder) or 9999
			explorerOrders[aClass] = aOrder
		end
		if not bOrder then
			bOrder = RMD.Classes[bClass] and tonumber(RMD.Classes[bClass].ExplorerOrder) or 9999
			explorerOrders[bClass] = bOrder
		end

		if aOrder ~= bOrder then
			return aOrder < bOrder
		else
			local aName, bName = tostring(a.Obj), tostring(b.Obj)
			if aName ~= bName then
				return aName < bName
			elseif aClass ~= bClass then
				return aClass < bClass
			else
				local aId = a.Id
				if not aId then
					aId = idCounter
					idCounter = (idCounter + 0.001) % 999999999
					a.Id = aId
				end
				local bId = b.Id
				if not bId then
					bId = idCounter
					idCounter = (idCounter + 0.001) % 999999999
					b.Id = bId
				end
				return aId < bId
			end
		end
	end

	Explorer.Update = function()
		table.clear(tree)
		local maxNameWidth, maxDepth, count = 0, 1, 1
		local nameCache = {}
		local font = Enum.Font.SourceSans
		local size = Vector2.new(math.huge, 20)
		local useNameWidth = Settings.Explorer.UseNameWidth
		local tSort = table.sort
		local sortFunc = Explorer.NodeSorter
		local isSearching = (expanded == Explorer.SearchExpanded)
		local textServ = service.TextService

		local function recur(root, depth)
			if depth > maxDepth then maxDepth = depth end
			depth = depth + 1
			if sortingEnabled and not root.Sorted then
				tSort(root, sortFunc)
				root.Sorted = true
			end
			for i = 1, #root do
				local n = root[i]

				if (isSearching and not searchResults[n]) or n.Del then continue end

				if useNameWidth then
					local nameWidth = n.NameWidth
					if not nameWidth then
						local objName = tostring(n.Obj)
						nameWidth = nameCache[objName]
						if not nameWidth then
							nameWidth = getTextSize(textServ, objName, 14, font, size).X
							nameCache[objName] = nameWidth
						end
						n.NameWidth = nameWidth
					end
					if nameWidth > maxNameWidth then maxNameWidth = nameWidth end
				end

				tree[count] = n
				count = count + 1
				if expanded[n] and #n > 0 then recur(n, depth) end
			end
		end

		recur(nodes[game], 1)

		-- Nil Instances
		if env.getnilinstances then
			if not (isSearching and not searchResults[nilNode]) then
				tree[count] = nilNode
				count = count + 1
				if expanded[nilNode] then recur(nilNode, 2) end
			end
		end

		Explorer.MaxNameWidth = maxNameWidth
		Explorer.MaxDepth = maxDepth
		Explorer.ViewWidth = useNameWidth and Explorer.EntryIndent * maxDepth + maxNameWidth + 26 or Explorer.EntryIndent * maxDepth + 226
		Explorer.UpdateView()
	end

	Explorer.StartDrag = function(offX, offY)
		if Explorer.Dragging then return end
		Explorer.Dragging = true

		local dragTree = treeFrame:Clone()
		dragTree:ClearAllChildren()

		for i, v in pairs(listEntries) do
			local node = tree[i + Explorer.Index]
			if node and selection.Map[node] then
				local clone = v:Clone()
				clone.Active = false
				clone.Indent.Expand.Visible = false
				clone.Parent = dragTree
			end
		end

		local newGui = Instance.new("ScreenGui")
		newGui.DisplayOrder = Main.DisplayOrders.Menu
		dragTree.Parent = newGui
		Lib.ShowGui(newGui)

		local dragOutline = create({
			{ 1, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Name = "DragSelect", Size = UDim2.new(1, 0, 1, 0) } },
			{ 2, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Line", Parent = { 1 }, Size = UDim2.new(1, 0, 0, 1), ZIndex = 2 } },
			{ 3, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Line", Parent = { 1 }, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), ZIndex = 2 } },
			{ 4, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Line", Parent = { 1 }, Size = UDim2.new(0, 1, 1, 0), ZIndex = 2 } },
			{ 5, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Line", Parent = { 1 }, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = 2 } },
		})
		dragOutline.Parent = treeFrame

		local mouse = Main.Mouse or service.Players.LocalPlayer:GetMouse()
		local function move()
			local posX = mouse.X - offX
			local posY = mouse.Y - offY
			dragTree.Position = UDim2.new(0, posX, 0, posY)

			for i = 1, #listEntries do
				local entry = listEntries[i]
				if Lib.CheckMouseInGui(entry) then
					dragOutline.Position = UDim2.new(0, entry.Indent.Position.X.Offset - scrollH.Index, 0, entry.Position.Y.Offset)
					dragOutline.Size = UDim2.new(0, entry.Size.X.Offset - entry.Indent.Position.X.Offset, 0, 20)
					dragOutline.Visible = true
					return
				end
			end
			dragOutline.Visible = false
		end
		move()

		local input = service.UserInputService
		local mouseEvent, releaseEvent

		mouseEvent = input.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then move() end
		end)

		releaseEvent = input.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				releaseEvent:Disconnect()
				mouseEvent:Disconnect()
				newGui:Destroy()
				dragOutline:Destroy()
				Explorer.Dragging = false

				for i = 1, #listEntries do
					if Lib.CheckMouseInGui(listEntries[i]) then
						local node = tree[i + Explorer.Index]
						if node then
							if selection.Map[node] then return end
							local newPar = node.Obj
							local sList = selection.List
							for i = 1, #sList do
								local n = sList[i]
								pcall(function() n.Obj.Parent = newPar end)
							end
							Explorer.ViewNode(sList[1])
						end
						break
					end
				end
			end
		end)
	end

	Explorer.NewListEntry = function(index)
		local newEntry = entryTemplate:Clone()
		newEntry.Position = UDim2.new(0, 0, 0, 20 * (index - 1))

		local isRenaming = false

		newEntry.InputBegan:Connect(function(input)
			local node = tree[index + Explorer.Index]
			if not node or selection.Map[node] or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			newEntry.Indent.BackgroundColor3 = Settings.Theme.Button
			newEntry.Indent.BorderSizePixel = 0
			newEntry.Indent.BackgroundTransparency = 0
		end)

		newEntry.InputEnded:Connect(function(input)
			local node = tree[index + Explorer.Index]
			if not node or selection.Map[node] or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			newEntry.Indent.BackgroundTransparency = 1
		end)

		newEntry.MouseButton1Down:Connect(function() end)

		newEntry.MouseButton1Up:Connect(function() end)

		newEntry.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local releaseEvent, mouseEvent

				local mouse = Main.Mouse or plr:GetMouse()
				local startX = mouse.X
				local startY = mouse.Y

				local listOffsetX = startX - treeFrame.AbsolutePosition.X
				local listOffsetY = startY - treeFrame.AbsolutePosition.Y

				releaseEvent = service.UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						releaseEvent:Disconnect()
						mouseEvent:Disconnect()
					end
				end)

				mouseEvent = service.UserInputService.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement then
						local deltaX = mouse.X - startX
						local deltaY = mouse.Y - startY
						local dist = math.sqrt(deltaX ^ 2 + deltaY ^ 2)

						if dist > 5 then
							releaseEvent:Disconnect()
							mouseEvent:Disconnect()
							isRenaming = false
							Explorer.StartDrag(listOffsetX, listOffsetY)
						end
					end
				end)
			end
		end)

		newEntry.MouseButton2Down:Connect(function() end)

		newEntry.Indent.Expand.InputBegan:Connect(function(input)
			local node = tree[index + Explorer.Index]
			if not node or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			Explorer.MiscIcons:DisplayByKey(newEntry.Indent.Expand.Icon, expanded[node] and "Collapse_Over" or "Expand_Over")
		end)

		newEntry.Indent.Expand.InputEnded:Connect(function(input)
			local node = tree[index + Explorer.Index]
			if not node or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			Explorer.MiscIcons:DisplayByKey(newEntry.Indent.Expand.Icon, expanded[node] and "Collapse" or "Expand")
		end)

		newEntry.Indent.Expand.MouseButton1Down:Connect(function()
			local node = tree[index + Explorer.Index]
			if not node or #node == 0 then return end

			expanded[node] = not expanded[node]
			Explorer.Update()
			Explorer.Refresh()
		end)

		newEntry.Parent = treeFrame
		return newEntry
	end

	Explorer.Refresh = function()
		local maxNodes = math.max(math.ceil(treeFrame.AbsoluteSize.Y / 20), 0)
		local renameNodeVisible = false
		local isa = game.IsA

		for i = 1, maxNodes do
			local entry = listEntries[i]
			if not listEntries[i] then
				entry = Explorer.NewListEntry(i)
				listEntries[i] = entry
				Explorer.ClickSystem:Add(entry)
			end

			local node = tree[i + Explorer.Index]
			if node then
				local obj = node.Obj
				local depth = Explorer.EntryIndent * Explorer.NodeDepth(node)

				entry.Visible = true
				entry.Position = UDim2.new(0, -scrollH.Index, 0, entry.Position.Y.Offset)
				entry.Size = UDim2.new(0, Explorer.ViewWidth, 0, 20)
				entry.Indent.EntryName.Text = tostring(node.Obj)
				entry.Indent.Position = UDim2.new(0, depth, 0, 0)
				entry.Indent.Size = UDim2.new(1, -depth, 1, 0)

				entry.Indent.EntryName.TextTruncate = (Settings.Explorer.UseNameWidth and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd)

				if (isa(obj, "LocalScript") or isa(obj, "Script")) and obj.Disabled then
					Explorer.MiscIcons:DisplayByKey(entry.Indent.Icon, isa(obj, "LocalScript") and "LocalScript_Disabled" or "Script_Disabled")
				else
					local rmdEntry = RMD.Classes[obj.ClassName]
					Explorer.ClassIcons:Display(entry.Indent.Icon, rmdEntry and rmdEntry.ExplorerImageIndex or 0)
				end

				if selection.Map[node] then
					entry.Indent.BackgroundColor3 = Settings.Theme.ListSelection
					entry.Indent.BorderSizePixel = 0
					entry.Indent.BackgroundTransparency = 0
				else
					if Lib.CheckMouseInGui(entry) then
						entry.Indent.BackgroundColor3 = Settings.Theme.Button
					else
						entry.Indent.BackgroundTransparency = 1
					end
				end

				if node == renamingNode then
					renameNodeVisible = true
					renameBox.Position = UDim2.new(0, depth + 25 - scrollH.Index, 0, entry.Position.Y.Offset + 2)
					renameBox.Visible = true
				end

				if #node > 0 and expanded[node] ~= 0 then
					if Lib.CheckMouseInGui(entry.Indent.Expand) then
						Explorer.MiscIcons:DisplayByKey(entry.Indent.Expand.Icon, expanded[node] and "Collapse_Over" or "Expand_Over")
					else
						Explorer.MiscIcons:DisplayByKey(entry.Indent.Expand.Icon, expanded[node] and "Collapse" or "Expand")
					end
					entry.Indent.Expand.Visible = true
				else
					entry.Indent.Expand.Visible = false
				end
			else
				entry.Visible = false
			end
		end

		if not renameNodeVisible then renameBox.Visible = false end

		for i = maxNodes + 1, #listEntries do
			Explorer.ClickSystem:Remove(listEntries[i])
			listEntries[i]:Destroy()
			listEntries[i] = nil
		end
	end

	Explorer.PerformUpdate = function(instant)
		updateDebounce = true
		Lib.FastWait(not instant and 0.1)
		if not updateDebounce then return end
		updateDebounce = false
		if not Explorer.Window:IsVisible() then return end
		Explorer.Update()
		Explorer.Refresh()
	end

	Explorer.ForceUpdate = function(norefresh)
		updateDebounce = false
		Explorer.Update()
		if not norefresh then Explorer.Refresh() end
	end

	Explorer.PerformRefresh = function()
		refreshDebounce = true
		Lib.FastWait(0.1)
		refreshDebounce = false
		if updateDebounce or not Explorer.Window:IsVisible() then return end
		Explorer.Refresh()
	end

	Explorer.IsNodeVisible = function(node)
		if not node then return end

		local curNode = node.Parent
		while curNode do
			if not expanded[curNode] then return false end
			curNode = curNode.Parent
		end
		return true
	end

	Explorer.NodeDepth = function(node)
		local depth = 0

		if node == nilNode then return 1 end

		local curNode = node.Parent
		while curNode do
			if curNode == nilNode then depth = depth + 1 end
			curNode = curNode.Parent
			depth = depth + 1
		end
		return depth
	end

	Explorer.SetupConnections = function()
		if descendantAddedCon then descendantAddedCon:Disconnect() end
		if descendantRemovingCon then descendantRemovingCon:Disconnect() end
		if itemChangedCon then itemChangedCon:Disconnect() end

		if Main.Elevated then
			descendantAddedCon = game.DescendantAdded:Connect(addObject)
			descendantRemovingCon = game.DescendantRemoving:Connect(removeObject)
		else
			descendantAddedCon = game.DescendantAdded:Connect(function(obj) pcall(addObject, obj) end)
			descendantRemovingCon = game.DescendantRemoving:Connect(function(obj) pcall(removeObject, obj) end)
		end

		if Settings.Explorer.UseNameWidth then
			itemChangedCon = game.ItemChanged:Connect(function(obj, prop)
				if prop == "Parent" and nodes[obj] then
					moveObject(obj)
				elseif prop == "Name" and nodes[obj] then
					nodes[obj].NameWidth = nil
				end
			end)
		else
			itemChangedCon = game.ItemChanged:Connect(function(obj, prop)
				if prop == "Parent" and nodes[obj] then moveObject(obj) end
			end)
		end
	end

	Explorer.ViewNode = function(node)
		if not node then return end

		Explorer.MakeNodeVisible(node)
		Explorer.ForceUpdate(true)
		local visibleSpace = scrollV.VisibleSpace

		for i, v in next, tree do
			if v == node then
				local relative = i - 1
				if Explorer.Index > relative then
					scrollV.Index = relative
				elseif Explorer.Index + visibleSpace - 1 <= relative then
					scrollV.Index = relative - visibleSpace + 2
				end
			end
		end

		scrollV:Update()
		Explorer.Index = scrollV.Index
		Explorer.Refresh()
	end

	Explorer.ViewObj = function(obj) Explorer.ViewNode(nodes[obj]) end

	Explorer.GetNode = function(obj) return nodes[obj] end

	Explorer.MakeNodeVisible = function(node, expandRoot)
		if not node then return end

		local hasExpanded = false

		if expandRoot and not expanded[node] then
			expanded[node] = true
			hasExpanded = true
		end

		local currentNode = node.Parent
		while currentNode do
			hasExpanded = true
			expanded[currentNode] = true
			currentNode = currentNode.Parent
		end

		if hasExpanded and not updateDebounce then coroutine.wrap(Explorer.PerformUpdate)(true) end
	end

	Explorer.ShowRightClick = function()
		local context = Explorer.RightClickContext
		context:Clear()

		local sList = selection.List
		local sMap = selection.Map
		local emptyClipboard = #clipboard == 0
		local presentClasses = {}
		local apiClasses = API.Classes

		for i = 1, #sList do
			local node = sList[i]
			local class = node.Class
			if not class then
				class = node.Obj.ClassName
				node.Class = class
			end
			local curClass = apiClasses[class]
			while curClass and not presentClasses[curClass.Name] do
				presentClasses[curClass.Name] = true
				curClass = curClass.Superclass
			end
		end

		context:AddRegistered("CUT")
		context:AddRegistered("COPY")
		context:AddRegistered("PASTE", emptyClipboard)
		context:AddRegistered("DUPLICATE")
		context:AddRegistered("DELETE")
		context:AddRegistered("RENAME", #sList ~= 1)

		context:AddDivider()
		context:AddRegistered("GROUP")
		context:AddRegistered("UNGROUP")
		context:AddRegistered("SELECT_CHILDREN")
		context:AddRegistered("JUMP_TO_PARENT")
		context:AddRegistered("EXPAND_ALL")
		context:AddRegistered("COLLAPSE_ALL")

		context:AddDivider()
		if expanded == Explorer.SearchExpanded then
			context:AddRegistered("SELECT_SEARCH_MATCHES")
			context:AddRegistered("CLEAR_SEARCH_AND_JUMP_TO")
		end
		if env.setclipboard then
			context:AddRegistered("COPY_PATH")
			context:AddRegistered("COPY_NODE")
		end
		context:AddRegistered("INSERT_OBJECT")
		context:AddRegistered("SAVE_INST")
		context:AddRegistered("VIEW_FUNCTIONS")
		context:AddRegistered("VIEW_CONNECTIONS")
		context:AddRegistered("GET_REFERENCES")
		context:AddRegistered("VIEW_API")

		context:QueueDivider()

		if presentClasses["BasePart"] or presentClasses["Model"] then
			context:AddRegistered("TELEPORT_TO")
			context:AddRegistered("VIEW_OBJECT")
			context:AddRegistered("REQUEST_STREAM_AROUND")
			context:AddRegistered("SELECT_PLAYER")
		end

		if presentClasses["TouchTransmitter"] then context:AddRegistered("FIRE_TOUCHTRANSMITTER", firetouchinterest == nil) end
		if presentClasses["ClickDetector"] then context:AddRegistered("FIRE_CLICKDETECTOR", fireclickdetector == nil) end
		if presentClasses["ProximityPrompt"] then context:AddRegistered("FIRE_PROXIMITYPROMPT", fireproximityprompt == nil) end
		if presentClasses["Player"] or presentClasses["Workspace"] then context:AddRegistered("SELECT_CHARACTER") end
		if presentClasses["Players"] then context:AddRegistered("SELECT_LOCAL_PLAYER") end
		if presentClasses["LuaSourceContainer"] then
			context:AddRegistered("VIEW_SCRIPT")
			context:AddRegistered("COPY_BASE64")
		end

		if sMap[nilNode] then
			context:AddRegistered("REFRESH_NIL")
			context:AddRegistered("HIDE_NIL")
		end

		Explorer.LastRightClickX, Explorer.LastRightClickY = Main.Mouse.X, Main.Mouse.Y
		context:Show()
	end

	Explorer.InitRightClick = function()
		local context = Lib.ContextMenu.new()

		context:Register("CUT", {
			Name = "Cut",
			IconMap = Explorer.MiscIcons,
			Icon = "Cut",
			DisabledIcon = "Cut_Disabled",
			Shortcut = "Ctrl+X",
			OnClick = function()
				local destroy, clone = game.Destroy, game.Clone
				local sList, newClipboard = selection.List, {}
				local count = 1
				for i = 1, #sList do
					local inst = sList[i].Obj
					local s, cloned = pcall(clone, inst)
					if s and cloned then
						newClipboard[count] = cloned
						count = count + 1
					end
					pcall(destroy, inst)
				end
				clipboard = newClipboard
				selection:Clear()
			end,
		})

		context:Register("COPY", {
			Name = "Copy",
			IconMap = Explorer.MiscIcons,
			Icon = "Copy",
			DisabledIcon = "Copy_Disabled",
			Shortcut = "Ctrl+C",
			OnClick = function()
				local clone = game.Clone
				local sList, newClipboard = selection.List, {}
				local count = 1
				for i = 1, #sList do
					local inst = sList[i].Obj
					local s, cloned = pcall(clone, inst)
					if s and cloned then
						newClipboard[count] = cloned
						count = count + 1
					end
				end
				clipboard = newClipboard
			end,
		})

		context:Register("PASTE", {
			Name = "Paste Into",
			IconMap = Explorer.MiscIcons,
			Icon = "Paste",
			DisabledIcon = "Paste_Disabled",
			Shortcut = "Ctrl+Shift+V",
			OnClick = function()
				local sList = selection.List
				local newSelection = {}
				local count = 1
				for i = 1, #sList do
					local node = sList[i]
					local inst = node.Obj
					Explorer.MakeNodeVisible(node, true)
					for c = 1, #clipboard do
						local cloned = clipboard[c]:Clone()
						if cloned then
							cloned.Parent = inst
							local clonedNode = nodes[cloned]
							if clonedNode then
								newSelection[count] = clonedNode
								count = count + 1
							end
						end
					end
				end
				selection:SetTable(newSelection)

				if #newSelection > 0 then Explorer.ViewNode(newSelection[1]) end
			end,
		})

		context:Register("DUPLICATE", {
			Name = "Duplicate",
			IconMap = Explorer.MiscIcons,
			Icon = "Copy",
			DisabledIcon = "Copy_Disabled",
			Shortcut = "Ctrl+D",
			OnClick = function()
				local clone = game.Clone
				local sList = selection.List
				local newSelection = {}
				local count = 1
				for i = 1, #sList do
					local node = sList[i]
					local inst = node.Obj
					local instPar = node.Parent and node.Parent.Obj
					Explorer.MakeNodeVisible(node)
					local s, cloned = pcall(clone, inst)
					if s and cloned then
						cloned.Parent = instPar
						local clonedNode = nodes[cloned]
						if clonedNode then
							newSelection[count] = clonedNode
							count = count + 1
						end
					end
				end

				selection:SetTable(newSelection)
				if #newSelection > 0 then Explorer.ViewNode(newSelection[1]) end
			end,
		})

		context:Register("DELETE", {
			Name = "Delete",
			IconMap = Explorer.MiscIcons,
			Icon = "Delete",
			DisabledIcon = "Delete_Disabled",
			Shortcut = "Del",
			OnClick = function()
				local destroy = game.Destroy
				local sList = selection.List
				for i = 1, #sList do
					pcall(destroy, sList[i].Obj)
				end
				selection:Clear()
			end,
		})

		context:Register("RENAME", {
			Name = "Rename",
			IconMap = Explorer.MiscIcons,
			Icon = "Rename",
			DisabledIcon = "Rename_Disabled",
			Shortcut = "F2",
			OnClick = function()
				local sList = selection.List
				if sList[1] then Explorer.SetRenamingNode(sList[1]) end
			end,
		})

		context:Register("GROUP", {
			Name = "Group",
			IconMap = Explorer.MiscIcons,
			Icon = "Group",
			DisabledIcon = "Group_Disabled",
			Shortcut = "Ctrl+G",
			OnClick = function()
				local sList = selection.List
				if #sList == 0 then return end

				local model = Instance.new("Model")
				model.Parent = sList[#sList].Obj.Parent
				for i = 1, #sList do
					pcall(function() sList[i].Obj.Parent = model end)
				end

				if nodes[model] then
					selection:Set(nodes[model])
					Explorer.ViewNode(nodes[model])
				end
			end,
		})

		context:Register("UNGROUP", {
			Name = "Ungroup",
			IconMap = Explorer.MiscIcons,
			Icon = "Ungroup",
			DisabledIcon = "Ungroup_Disabled",
			Shortcut = "Ctrl+U",
			OnClick = function()
				local newSelection = {}
				local count = 1
				local isa = game.IsA

				local function ungroup(node)
					local par = node.Parent.Obj
					local ch = {}
					local chCount = 1

					for i = 1, #node do
						local n = node[i]
						newSelection[count] = n
						ch[chCount] = n
						count = count + 1
						chCount = chCount + 1
					end

					for i = 1, #ch do
						pcall(function() ch[i].Obj.Parent = par end)
					end

					pcall(node.Obj.Destroy, node.Obj)
				end

				for i, v in next, selection.List do
					if isa(v.Obj, "Model") then ungroup(v) end
				end

				selection:SetTable(newSelection)
				if #newSelection > 0 then Explorer.ViewNode(newSelection[1]) end
			end,
		})

		context:Register("SELECT_CHILDREN", {
			Name = "Select Children",
			IconMap = Explorer.MiscIcons,
			Icon = "SelectChildren",
			DisabledIcon = "SelectChildren_Disabled",
			OnClick = function()
				local newSelection = {}
				local count = 1
				local sList = selection.List

				for i = 1, #sList do
					local node = sList[i]
					for ind = 1, #node do
						local cNode = node[ind]
						if ind == 1 then Explorer.MakeNodeVisible(cNode) end

						newSelection[count] = cNode
						count = count + 1
					end
				end

				selection:SetTable(newSelection)
				if #newSelection > 0 then
					Explorer.ViewNode(newSelection[1])
				else
					Explorer.Refresh()
				end
			end,
		})

		context:Register("JUMP_TO_PARENT", {
			Name = "Jump to Parent",
			IconMap = Explorer.MiscIcons,
			Icon = "JumpToParent",
			OnClick = function()
				local newSelection = {}
				local count = 1
				local sList = selection.List

				for i = 1, #sList do
					local node = sList[i]
					if node.Parent then
						newSelection[count] = node.Parent
						count = count + 1
					end
				end

				selection:SetTable(newSelection)
				if #newSelection > 0 then
					Explorer.ViewNode(newSelection[1])
				else
					Explorer.Refresh()
				end
			end,
		})

		context:Register("REQUEST_STREAM_AROUND", {
			Name = "Request Stream Around",
			IconMap = Explorer.ClassIcons,
			Icon = 5,
			OnClick = function()
				local sList = selection.List
				local isa = game.IsA

				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if not hrp then return end

				for i = 1, #sList do
					local node = sList[i]

					local cframe
					if isa(node.Obj, "BasePart") then
						cframe = node.Obj.CFrame + Settings.Explorer.TeleportToOffset
					elseif isa(node.Obj, "Model") or isa(node.Obj, "Tool") then
						if node.Obj.PrimaryPart then
							cframe = node.Obj.PrimaryPart.CFrame + Settings.Explorer.TeleportToOffset
						else
							cframe = node.Obj:GetPivot() + Settings.Explorer.TeleportToOffset
						end
					end

					if cframe then plr:RequestStreamAroundAsync(cframe.Position, 1) end
				end
			end,
		})

		context:Register("TELEPORT_TO", {
			Name = "Teleport To",
			IconMap = Explorer.MiscIcons,
			Icon = "TeleportTo",
			OnClick = function()
				local sList = selection.List
				local isa = game.IsA

				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if not hrp then return end

				for i = 1, #sList do
					local node = sList[i]

					if isa(node.Obj, "BasePart") then
						hrp.CFrame = node.Obj.CFrame + Settings.Explorer.TeleportToOffset
						break
					elseif isa(node.Obj, "Model") or isa(node.Obj, "Tool") then
						if node.Obj.PrimaryPart then
							hrp.CFrame = node.Obj.PrimaryPart.CFrame + Settings.Explorer.TeleportToOffset
							break
						else
							plr:RequestStreamAroundAsync(node.Obj:GetPivot().Position, 1)
							-- local part = node.Obj:FindFirstChildWhichIsA("BasePart", true)
							-- if part and nodes[part] then hrp.CFrame = nodes[part].Obj.CFrame + Settings.Explorer.TeleportToOffset end
							hrp.CFrame = node.Obj:GetPivot() + Settings.Explorer.TeleportToOffset
						end
						break
					end
				end
			end,
		})

		context:Register("EXPAND_ALL", {
			Name = "Expand All",
			OnClick = function()
				local sList = selection.List

				local function expand(node)
					expanded[node] = true
					for i = 1, #node do
						if #node[i] > 0 then expand(node[i]) end
					end
				end

				for i = 1, #sList do
					expand(sList[i])
				end

				Explorer.ForceUpdate()
			end,
		})

		context:Register("COLLAPSE_ALL", {
			Name = "Collapse All",
			OnClick = function()
				local sList = selection.List

				local function expand(node)
					expanded[node] = nil
					for i = 1, #node do
						if #node[i] > 0 then expand(node[i]) end
					end
				end

				for i = 1, #sList do
					expand(sList[i])
				end

				Explorer.ForceUpdate()
			end,
		})

		context:Register("SELECT_SEARCH_MATCHES", {
			Name = "Select All Matches",
			IconMap = Explorer.MiscIcons,
			Icon = "SelectChildren",
			OnClick = function()
				selection:SetTable(Explorer.GetSearchMatches())
				Explorer.Refresh()
			end,
		})

		context:Register("CLEAR_SEARCH_AND_JUMP_TO", {
			Name = "Clear Search and Jump to",
			OnClick = function()
				local newSelection = {}
				local count = 1
				local sList = selection.List

				for i = 1, #sList do
					newSelection[count] = sList[i]
					count = count + 1
				end

				selection:SetTable(newSelection)
				Explorer.ClearSearch()
				if #newSelection > 0 then Explorer.ViewNode(newSelection[1]) end
			end,
		})

		context:Register("COPY_PATH", {
			Name = "Copy Path",
			OnClick = function()
				local sList = selection.List
				if #sList == 1 then
					env.setclipboard(shortenPath(Explorer.GetInstancePath(sList[1].Obj)))
				elseif #sList > 1 then
					local resList = { "{" }
					local count = 2
					for i = 1, #sList do
						local path = "\t" .. shortenPath(Explorer.GetInstancePath(sList[i].Obj)) .. ","
						if #path > 0 then
							resList[count] = path
							count = count + 1
						end
					end
					resList[count] = "}"
					env.setclipboard(table.concat(resList, "\n"))
				end
			end,
		})

		context:Register("COPY_NODE", {
			Name = "Copy Node Info",
			OnClick = function()
				local lines = {}
				for _, node in selection.List do
					local obj = node.Obj
					table.insert(lines, string.format("%s (%s) | %d children | %s", obj.Name, obj.ClassName, #node, shortenPath(Explorer.GetInstancePath(obj))))
				end
				env.setclipboard(table.concat(lines, "\n"))
			end,
		})

		context:Register("INSERT_OBJECT", {
			Name = "Insert Object",
			IconMap = Explorer.MiscIcons,
			Icon = "InsertObject",
			OnClick = function()
				local mouse = Main.Mouse
				local x, y = Explorer.LastRightClickX or mouse.X, Explorer.LastRightClickY or mouse.Y
				Explorer.InsertObjectContext:Show(x, y)
			end,
		})

		context:Register("VIEW_FUNCTIONS", {
			Name = "View Function",
			IconMap = Explorer.ClassIcons,
			Icon = 66,
			OnClick = function()
				local mouse = Main.Mouse
				local x, y = Explorer.LastRightClickX or mouse.X, Explorer.LastRightClickY or mouse.Y
				Explorer.InitViewFunctions(x, y)
			end,
		})

		context:Register("GET_REFERENCES", {
			Name = "Get Lua References",
			IconMap = Explorer.ClassIcons,
			Icon = 34,
			OnClick = function()
				local node = selection.List[1]
				if not node then return end
				ScriptViewer.ShowText("Lua References", Explorer.FindReferences(node.Obj))
			end,
		})

		context:Register("SAVE_INST", {
			Name = "Save to File",
			IconMap = Explorer.MiscIcons,
			Icon = "Save",
			OnClick = function()
				local sList = selection.List
				if #sList == 0 then return end
				SaveInstance.run({
					AntiIdle = false,
					noscripts = true,
					SaveBytecode = true,
					Object = sList[1].Obj,
					FilePath = sList[1].Obj.Name .. "_" .. os.time(),
				})
			end,
		})

		context:Register("VIEW_CONNECTIONS", {
			Name = "View Connections",
			OnClick = function()
				local mouse = Main.Mouse
				local x, y = Explorer.LastRightClickX or mouse.X, Explorer.LastRightClickY or mouse.Y
				Explorer.InitViewConnections(x, y)
			end,
		})

		context:Register("VIEW_API", {
			Name = "Copy API Page Link",
			IconMap = Explorer.MiscIcons,
			Icon = "Reference",
			OnClick = function()
				local node = selection.List[1]
				if not node then return end
				local url = "https://create.roblox.com/docs/reference/engine/classes/" .. node.Obj.ClassName
				if env.setclipboard then
					env.setclipboard(url)
				else
					print(url)
				end
			end,
		})

		context:Register("VIEW_OBJECT", {
			Name = "View Object (Right click to reset)",
			IconMap = Explorer.ClassIcons,
			Icon = 5,
			OnClick = function()
				local sList = selection.List
				local isa = game.IsA

				for i = 1, #sList do
					local node = sList[i]

					if isa(node.Obj, "BasePart") or isa(node.Obj, "Model") then
						workspace.CurrentCamera.CameraSubject = node.Obj
						break
					end
				end
			end,
			OnRightClick = function() workspace.CurrentCamera.CameraSubject = plr.Character end,
		})

		context:Register("FIRE_TOUCHTRANSMITTER", {
			Name = "Fire TouchTransmitter",
			IconMap = Explorer.ClassIcons,
			Icon = 37,
			OnClick = function()
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if not hrp then return end
				for _, v in ipairs(selection.List) do
					if v.Obj and v.Obj:IsA("TouchTransmitter") then firetouchinterest(hrp, v.Obj.Parent, 0) end
				end
			end,
		})

		context:Register("FIRE_CLICKDETECTOR", {
			Name = "Fire ClickDetector",
			IconMap = Explorer.ClassIcons,
			Icon = 41,
			OnClick = function()
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if not hrp then return end
				for _, v in ipairs(selection.List) do
					if v.Obj and v.Obj:IsA("ClickDetector") then fireclickdetector(v.Obj) end
				end
			end,
		})

		context:Register("FIRE_PROXIMITYPROMPT", {
			Name = "Fire ProximityPrompt",
			IconMap = Explorer.ClassIcons,
			Icon = 124,
			OnClick = function()
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if not hrp then return end
				for _, v in ipairs(selection.List) do
					if v.Obj and v.Obj:IsA("ProximityPrompt") then fireproximityprompt(v.Obj) end
				end
			end,
		})

		context:Register("VIEW_SCRIPT", {
			Name = "View Script",
			IconMap = Explorer.MiscIcons,
			Icon = "ViewScript",
			OnClick = function()
				local scr = selection.List[1] and selection.List[1].Obj
				if scr then ScriptViewer.ViewScript(scr) end
			end,
		})

		context:Register("COPY_BASE64", {
			Name = "Copy Base64",
			IconMap = Explorer.MiscIcons,
			Icon = "Copy",
			OnClick = function()
				local src = selection.List[1] and selection.List[1].Obj
				if src then
					local text = env.base64encode(env.getscriptbytecode(src))

					-- for i = 1, 4 do
					env.setclipboard(text)
					-- end
				end
			end,
		})

		context:Register("SELECT_CHARACTER", {
			Name = "Select Character",
			IconMap = Explorer.ClassIcons,
			Icon = 9,
			OnClick = function()
				local newSelection = {}
				local count = 1
				local sList = selection.List
				local isa = game.IsA

				for i = 1, #sList do
					local node = sList[i]
					if isa(node.Obj, "Player") and nodes[node.Obj.Character] then
						newSelection[count] = nodes[node.Obj.Character]
						count = count + 1
					elseif isa(node.Obj, "Workspace") then
						newSelection[count] = nodes[plr.Character]
						count = count + 1
					end
				end

				selection:SetTable(newSelection)
				if #newSelection > 0 then
					Explorer.ViewNode(newSelection[1])
				else
					Explorer.Refresh()
				end
			end,
		})

		context:Register("SELECT_PLAYER", {
			Name = "Select Player",
			IconMap = Explorer.ClassIcons,
			Icon = 9,
			OnClick = function()
				local sList = selection.List
				local isa = game.IsA

				local node = sList[1]
				if isa(node.Obj, "Model") then
					for _, v in ipairs(service.Players:GetPlayers()) do
						if v.Character == node.Obj then
							selection:Set(nodes[v])
							Explorer.ViewNode(nodes[v])
							break
						end
					end
				end
			end,
		})

		context:Register("SELECT_LOCAL_PLAYER", {
			Name = "Select Local Player",
			IconMap = Explorer.ClassIcons,
			Icon = 9,
			OnClick = function()
				pcall(function()
					if nodes[plr] then
						selection:Set(nodes[plr])
						Explorer.ViewNode(nodes[plr])
					end
				end)
			end,
		})

		context:Register("REFRESH_NIL", { Name = "Refresh Nil Instances", OnClick = function() Explorer.RefreshNilInstances() end })

		context:Register("HIDE_NIL", { Name = "Hide Nil Instances", OnClick = function() Explorer.HideNilInstances() end })

		Explorer.RightClickContext = context
	end

	Explorer.HideNilInstances = function()
		table.clear(nilMap)

		local disconnectCon = Instance.new("Folder").ChildAdded:Connect(function() end).Disconnect
		for i, v in next, nilCons do
			disconnectCon(v[1])
			disconnectCon(v[2])
		end
		table.clear(nilCons)

		for i = 1, #nilNode do
			coroutine.wrap(removeObject)(nilNode[i].Obj)
		end

		Explorer.Update()
		Explorer.Refresh()
	end

	Explorer.RefreshNilInstances = function()
		if not env.getnilinstances then return end

		local nilInsts = env.getnilinstances()
		local game = game
		local getDescs = game.GetDescendants
		--local newNilMap = {}
		--local newNilRoots = {}
		--local nilRoots = Explorer.NilRoots
		--local connect = game.DescendantAdded.Connect
		--local disconnect
		--if not nilRoots then nilRoots = {} Explorer.NilRoots = nilRoots end

		for i = 1, #nilInsts do
			local obj = nilInsts[i]
			if obj ~= game then
				nilMap[obj] = true
				--newNilRoots[obj] = true

				local descs = getDescs(obj)
				for j = 1, #descs do
					nilMap[descs[j] ] = true
				end
			end
		end

		-- Remove unmapped nil nodes
		--[[for i = 1,#nilNode do
			local node = nilNode[i]
			if not newNilMap[node.Obj] then
				nilMap[node.Obj] = nil
				coroutine.wrap(removeObject)(node)
			end
		end]]

		--nilMap = newNilMap

		for i = 1, #nilInsts do
			local obj = nilInsts[i]
			local node = nodes[obj]
			if not node then coroutine.wrap(addObject)(obj) end
		end

		--[[
		-- Remove old root connections
		for obj in next,nilRoots do
			if not newNilRoots[obj] then
				if not disconnect then disconnect = obj[1].Disconnect end
				disconnect(obj[1])
				disconnect(obj[2])
			end
		end

		for obj in next,newNilRoots do
			if not nilRoots[obj] then
				nilRoots[obj] = {
					connect(obj.DescendantAdded,addObject),
					connect(obj.DescendantRemoving,removeObject)
				}
			end
		end]]

		--nilMap = newNilMap
		--Explorer.NilRoots = newNilRoots

		Explorer.Update()
		Explorer.Refresh()
	end

	Explorer.GetInstancePath = function(obj)
		local ffc = game.FindFirstChild
		local getCh = game.GetChildren
		local path = ""
		local curObj = obj
		local ts = tostring
		local match = string.match
		local gsub = string.gsub
		local tableFind = table.find
		local useGetCh = Settings.Explorer.CopyPathUseGetChildren
		local formatLuaString = Lib.FormatLuaString

		while curObj do
			if curObj == game then
				path = "game" .. path
				break
			end

			local className = curObj.ClassName
			local curName = ts(curObj)
			local indexName
			if match(curName, "^[%a_][%w_]*$") then
				indexName = "." .. curName
			else
				local cleanName = formatLuaString(curName)
				indexName = '["' .. cleanName .. '"]'
			end

			local parObj = curObj.Parent
			if parObj then
				local fc = ffc(parObj, curName)
				if useGetCh and fc and fc ~= curObj then
					local parCh = getCh(parObj)
					local fcInd = tableFind(parCh, curObj)
					indexName = ":GetChildren()[" .. fcInd .. "]"
				elseif parObj == game and API.Classes[className] and API.Classes[className].Tags.Service then
					indexName = ':GetService("' .. className .. '")'
				end
			elseif parObj == nil then
				local getnil = "local getNil = function(name, class) for _, v in next, getnilinstances() do if v.ClassName == class and v.Name == name then return v end end end"
				local gotnil = '\n\ngetNil("%s", "%s")'
				indexName = getnil .. gotnil:format(curObj.Name, className)
			end

			path = indexName .. path
			curObj = parObj
		end

		return path
	end

	-- The API class of className followed by all its superclasses
	local function getClassChain(className)
		local chain = {}
		local apiClass = API.Classes[className]
		while apiClass do
			table.insert(chain, apiClass)
			apiClass = apiClass.Superclass
		end
		return chain
	end

	local function findMember(className, kind, name)
		for _, apiClass in getClassChain(className) do
			for _, member in apiClass[kind] do
				if member.Name == name then return member end
			end
		end
		return nil
	end

	local function parameterNames(member)
		local names = {}
		for _, parameter in member and member.Parameters or {} do
			table.insert(names, parameter.Name)
		end
		return table.concat(names, ", ")
	end

	local function createMemberContext()
		local context = Lib.ContextMenu.new()
		context.SearchEnabled = true
		context.MaxHeight = 400
		context:ApplyTheme({
			ContentColor = Settings.Theme.Main2,
			OutlineColor = Settings.Theme.Outline1,
			DividerColor = Settings.Theme.Outline1,
			TextColor = Settings.Theme.Text,
			HighlightColor = Settings.Theme.ButtonHover,
		})
		return context
	end

	-- Adds every member of the selected classes, grouped under the class that declares it
	local function addClassMembers(context, nodesList, kind, showDeprecated, makeItem)
		local seenClasses, added = {}, {}
		for _, node in nodesList do
			local className = node.Obj.ClassName
			if seenClasses[className] then continue end
			seenClasses[className] = true

			for _, apiClass in getClassChain(className) do
				local rmdEntry = RMD.Classes[apiClass.Name]
				local icon = rmdEntry and tonumber(rmdEntry.ExplorerImageIndex) or 0
				local hasDivider = false

				for _, member in apiClass[kind] do
					if added[member.Name] or (member.Tags.Deprecated and not showDeprecated) then continue end
					added[member.Name] = true

					if not hasDivider then
						context:AddDivider(apiClass.Name)
						hasDivider = true
					end

					local item = makeItem(member)
					item.IconMap = Explorer.ClassIcons
					item.Icon = icon
					context:Add(item)
				end
			end
		end
	end

	Explorer.InitViewFunctions = function(x, y)
		local context = Explorer.ViewFunctionsContext
		if not context then
			context = createMemberContext()
			Explorer.ViewFunctionsContext = context
		end

		local selectedNodes = table.clone(selection.List)

		local function copyCalls(functionName)
			local lines = {}
			for _, node in selectedNodes do
				local obj = node.Obj
				local member = findMember(obj.ClassName, "Functions", functionName)
				local path = shortenPath(Explorer.GetInstancePath(obj))
				table.insert(lines, string.format("%s:%s(%s) --[[ Return: %s ]]", path, functionName, parameterNames(member), member and member.ReturnType or ""))
			end
			env.setclipboard(table.concat(lines, "\n") .. "\n")
		end

		context:Clear()
		addClassMembers(context, selectedNodes, "Functions", Settings.Properties.ShowDeprecatedFunctions, function(member)
			return {
				Name = member.Name,
				OnClick = function() copyCalls(member.Name) end,
			}
		end)
		context:Show(x, y)
	end

	-- Scripts with Lua handlers connected to signal, or nil when getconnections is missing
	local function getConnectedScripts(signal)
		if not getconnections then return nil end

		local success, connections = pcall(getconnections, signal)
		if not success then return {} end

		local scripts = {}
		for _, connection in connections do
			local func = connection.Function
			if type(func) == "function" and (not islclosure or islclosure(func)) then
				local hasEnv, fenv = pcall(getfenv, func)
				local scr = hasEnv and rawget(fenv, "script")
				table.insert(scripts, typeof(scr) == "Instance" and scr or false)
			end
		end
		return scripts
	end

	Explorer.InitViewConnections = function(x, y)
		local context = Explorer.ViewConnectionsContext
		if not context then
			context = createMemberContext()
			Explorer.ViewConnectionsContext = context
		end

		local selectedNodes = table.clone(selection.List)
		-- true: has Lua handlers, false: checked and has none
		local checked = {}
		local updateEvents

		local function getSignal(obj, eventName)
			local success, signal = pcall(function() return obj[eventName] end)
			return success and signal or nil
		end

		local function checkEvent(eventName)
			checked[eventName] = false
			for _, node in selectedNodes do
				local signal = getSignal(node.Obj, eventName)
				local scripts = signal and getConnectedScripts(signal)
				if scripts and #scripts > 0 then
					checked[eventName] = true
					break
				end
			end
			updateEvents()
		end

		local function copyConnections(eventName)
			local comments, templates = {}, {}
			for _, node in selectedNodes do
				local obj = node.Obj
				local path = shortenPath(Explorer.GetInstancePath(obj))
				table.insert(comments, `-- Connection: {path}.{eventName}`)

				local signal = getSignal(obj, eventName)
				local scripts = signal and getConnectedScripts(signal)
				if scripts and #scripts > 0 then
					table.insert(comments, "--[[\n\tScripts:")
					for _, scr in scripts do
						table.insert(comments, "\t" .. (scr and shortenPath(Explorer.GetInstancePath(scr)) or "<no script>"))
					end
					table.insert(comments, "--]]")
				end

				local member = findMember(obj.ClassName, "Events", eventName)
				table.insert(templates, string.format("%s.%s:Connect(function(%s)\n\nend)", path, eventName, parameterNames(member)))
			end
			env.setclipboard(table.concat(comments, "\n") .. "\n" .. table.concat(templates, "\n") .. "\n")
		end

		updateEvents = function()
			context:Clear()
			addClassMembers(context, selectedNodes, "Events", Settings.Properties.ShowDeprecatedEvents, function(member)
				local status = checked[member.Name]
				return {
					Name = member.Name .. (status == true and " 🟢" or status == false and " 🔴" or ""),
					OnClick = function() checkEvent(member.Name) end,
					OnRightClick = function() copyConnections(member.Name) end,
					NoHide = true,
				}
			end)
			context:Refresh()
		end

		updateEvents()
		context:Show(x, y)
	end

	local MAX_REFERENCES = 500

	-- Lists the tables and function upvalues that hold a reference to target
	Explorer.FindReferences = function(target)		
local getgc = getgc or get_gc_objects
		if not getgc then return "-- Get Lua References needs getgc" end
		local getupvalues = (debug and debug.getupvalues) or getupvalues

		local lines = { `-- Lua references to {shortenPath(Explorer.GetInstancePath(target))}`, "" }
		local count = 0

		local function add(line)
			count += 1
			table.insert(lines, line)
		end

		local objects = getgc(true)
		for index, value in objects do
			if count >= MAX_REFERENCES then break end
			if index % 20000 == 0 then task.wait() end

			local valueType = type(value)
			if valueType == "table" then
				-- Raw iteration: a __iter or __index metamethod must not run game code
				for key, item in next, value do
					if item == target then
						add(`[table] key {tostring(key)} = <instance>`)
					elseif key == target then
						add(`[table] key <instance> = {typeof(item)}`)
					end
				end
			elseif valueType == "function" and getupvalues and (not islclosure or islclosure(value)) then
				local success, upvalues = pcall(getupvalues, value)
				if success then
					for upvalueIndex, upvalue in upvalues do
						if upvalue == target then
							local source, line, name = debug.info(value, "sln")
							add(`[upvalue {upvalueIndex}] function {name ~= "" and name or "<anonymous>"} at {source}:{line}`)
							break
						end
					end
				end
			end
		end

		if count == 0 then table.insert(lines, "-- No references found") end
		if count >= MAX_REFERENCES then table.insert(lines, `-- Stopped after {MAX_REFERENCES} references`) end
		return table.concat(lines, "\n")
	end

	Explorer.InitInsertObject = function()
		local context = Lib.ContextMenu.new()
		context.SearchEnabled = true
		context.MaxHeight = 400
		context:ApplyTheme({
			ContentColor = Settings.Theme.Main2,
			OutlineColor = Settings.Theme.Outline1,
			DividerColor = Settings.Theme.Outline1,
			TextColor = Settings.Theme.Text,
			HighlightColor = Settings.Theme.ButtonHover,
		})

		local classes = {}
		for i, class in next, API.Classes do
			local tags = class.Tags
			if not tags.NotCreatable and not tags.Service then
				local rmdEntry = RMD.Classes[class.Name]
				classes[#classes + 1] = { class, rmdEntry and rmdEntry.ClassCategory or "Uncategorized" }
			end
		end
		table.sort(classes, function(a, b)
			if a[2] ~= b[2] then
				return a[2] < b[2]
			else
				return a[1].Name < b[1].Name
			end
		end)

		local function onClick(className)
			local sList = selection.List
			local instNew = Instance.new
			for i = 1, #sList do
				local node = sList[i]
				local obj = node.Obj
				Explorer.MakeNodeVisible(node, true)
				pcall(instNew, className, obj)
			end
		end

		local lastCategory = ""
		for i = 1, #classes do
			local class = classes[i][1]
			local rmdEntry = RMD.Classes[class.Name]
			local iconInd = rmdEntry and tonumber(rmdEntry.ExplorerImageIndex) or 0
			local category = classes[i][2]

			if lastCategory ~= category then
				context:AddDivider(category)
				lastCategory = category
			end
			context:Add({ Name = class.Name, IconMap = Explorer.ClassIcons, Icon = iconInd, OnClick = onClick })
		end

		Explorer.InsertObjectContext = context
	end

	local SUGGESTION_ROW_HEIGHT = 20
	local MAX_VISIBLE_SUGGESTIONS = 8
	local LIVE_SEARCH_DELAY = 0.35

	local function setSearchStatus(text) Explorer.Window:SetTitle(text and `Explorer - {text}` or "Explorer") end

	-- Runs a search. A live search keeps the previous results when the query is incomplete.
	Explorer.DoSearch = function(query, isLive)
		local predicate, err = SearchQuery.compile(query)
		if #query > 0 and not predicate then
			if not isLive then setSearchStatus(err) end
			return
		end

		table.clear(Explorer.SearchExpanded)
		table.clear(searchResults)
		expanded = predicate and Explorer.SearchExpanded or Explorer.Expanded
		searchFunc = nil
		Explorer.SearchMatchCount = 0

		if predicate then
			local expandTable = Explorer.SearchExpanded

			local function search(root)
				local expandedParent = false
				for i = 1, #root do
					local node = root[i]
					local obj = node.Obj

					if not node.Del and predicate(obj) then
						Explorer.SearchMatchCount += 1
						expandTable[node] = 0
						searchResults[node] = true
						if not expandedParent then
							local parentNode = node.Parent
							while parentNode and (not searchResults[parentNode] or expandTable[parentNode] == 0) do
								expandTable[parentNode] = true
								searchResults[parentNode] = true
								parentNode = parentNode.Parent
							end
							expandedParent = true
						end
					end

					if #node > 0 then search(node) end
				end
			end

			searchFunc = search
			search(nodes[game])
			search(nilNode)

			local count = Explorer.SearchMatchCount
			setSearchStatus(count == 1 and "1 match" or `{count} matches`)
		else
			setSearchStatus(nil)
		end

		Explorer.ForceUpdate()
	end

	Explorer.ClearSearch = function()
		Explorer.GuiElems.SearchBar.Text = ""
		Explorer.DoSearch("")
	end

	-- Nodes that matched the search, without the ancestors expanded to show them
	Explorer.GetSearchMatches = function()
		local matches = {}
		for node in searchResults do
			if Explorer.SearchExpanded[node] == 0 then table.insert(matches, node) end
		end
		return matches
	end

	Explorer.InitSearchSuggestions = function(searchBox)
		local content = Explorer.Window.GuiElems.Content
		local suggestions = {}
		local rows = {}
		local highlighted = 0
		local keyConnection

		local frame = Instance.new("Frame")
		frame.Name = "SearchSuggestions"
		frame.BackgroundColor3 = Settings.Theme.Menu
		frame.BorderColor3 = Settings.Theme.Outline1
		frame.Position = UDim2.new(0, 3, 0, 20)
		frame.Visible = false
		frame.ZIndex = 10
		frame.Parent = content

		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.SourceSansBold
		header.TextSize = 14
		header.TextColor3 = Settings.Theme.PlaceholderText
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Position = UDim2.new(0, 6, 0, 0)
		header.Size = UDim2.new(1, -12, 0, 18)
		header.ZIndex = 11
		header.Parent = frame

		local list = Instance.new("ScrollingFrame")
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 4
		list.ScrollBarImageColor3 = Settings.Theme.Highlight
		list.ZIndex = 11
		list.Parent = frame

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list

		local function paint()
			for index, row in rows do
				row.BackgroundTransparency = index == highlighted and 0 or 1
			end
		end

		local function hide()
			frame.Visible = false
			highlighted = 0
		end

		local function accept(index)
			local suggestion = suggestions[index]
			if not suggestion then return end

			searchBox.Text = suggestion.Text
			searchBox:CaptureFocus()
			searchBox.CursorPosition = #suggestion.Text + 1
		end

		local function getRow(index)			
local row = rows[index]
			if row then return row end

			row = Instance.new("TextButton")
			row.AutoButtonColor = false
			row.Text = ""
			row.BorderSizePixel = 0
			row.BackgroundColor3 = Settings.Theme.ListSelection
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, SUGGESTION_ROW_HEIGHT)
			row.LayoutOrder = index
			row.ZIndex = 12

			local icon = Explorer.ClassIcons:GetLabel()
			icon.Name = "Icon"
			icon.Position = UDim2.new(0, 4, 0, 2)
			icon.ZIndex = 13
			icon.Parent = row

			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.SourceSans
			label.TextSize = 14
			label.TextColor3 = Settings.Theme.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.ZIndex = 13
			label.Parent = row

			row.MouseButton1Down:Connect(function() accept(index) end)
			row.MouseEnter:Connect(function()
				highlighted = index
				paint()
			end)

			row.Parent = list
			rows[index] = row
			return row
		end

		local function scrollToHighlighted()
			local top = (highlighted - 1) * SUGGESTION_ROW_HEIGHT
			local viewHeight = list.AbsoluteSize.Y
			if top < list.CanvasPosition.Y then
				list.CanvasPosition = Vector2.new(0, top)
			elseif top + SUGGESTION_ROW_HEIGHT > list.CanvasPosition.Y + viewHeight then
				list.CanvasPosition = Vector2.new(0, top + SUGGESTION_ROW_HEIGHT - viewHeight)
			end
		end

		local function refresh()
			if not searchBox:IsFocused() then return hide() end

			local headerText
			suggestions, headerText = Suggest.get(searchBox.Text)
			highlighted = 0
			if #suggestions == 0 then return hide() end

			for index, suggestion in suggestions do
				local row = getRow(index)
				local hasIcon = suggestion.ClassIcon ~= nil
				row.Icon.Visible = hasIcon
				if hasIcon then
					local rmdEntry = RMD.Classes[suggestion.ClassIcon]
					Explorer.ClassIcons:Display(row.Icon, rmdEntry and tonumber(rmdEntry.ExplorerImageIndex) or 0)
				end
				row.Label.Position = UDim2.new(0, hasIcon and 24 or 6, 0, 0)
				row.Label.Size = UDim2.new(1, hasIcon and -28 or -10, 1, 0)
				row.Label.Text = suggestion.Label
				row.Visible = true
			end
			for index = #suggestions + 1, #rows do
				rows[index].Visible = false
			end
			paint()

			local headerHeight = headerText and 18 or 0
			header.Visible = headerText ~= nil
			header.Text = headerText or ""
			list.Position = UDim2.new(0, 0, 0, headerHeight)
			list.Size = UDim2.new(1, 0, 1, -headerHeight)
			list.CanvasSize = UDim2.new(0, 0, 0, #suggestions * SUGGESTION_ROW_HEIGHT)
			list.CanvasPosition = Vector2.zero
			frame.Size = UDim2.new(1, -6, 0, headerHeight + math.min(#suggestions, MAX_VISIBLE_SUGGESTIONS) * SUGGESTION_ROW_HEIGHT)
			frame.Visible = true
		end

		searchBox.Focused:Connect(function()
			refresh()
			if keyConnection then keyConnection:Disconnect() end
			keyConnection = service.UserInputService.InputBegan:Connect(function(input)
				if not frame.Visible or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

				local keyCode = input.KeyCode
				if keyCode == Enum.KeyCode.Down then
					highlighted = math.min(#suggestions, highlighted + 1)
				elseif keyCode == Enum.KeyCode.Up then
					highlighted = math.max(1, highlighted - 1)
				elseif keyCode == Enum.KeyCode.Tab then
					accept(math.max(highlighted, 1))
					return
				else
					return
				end
				paint()
				scrollToHighlighted()
			end)
		end)

		searchBox.FocusLost:Connect(function(enterPressed)
			if keyConnection then
				keyConnection:Disconnect()
				keyConnection = nil
			end

			if enterPressed and frame.Visible and highlighted > 0 then
				accept(highlighted)
				return
			end

			-- Wait so a click on a suggestion row is handled before the list hides
			task.delay(0.15, function()
				if not searchBox:IsFocused() then hide() end
			end)
			if enterPressed then Explorer.DoSearch(searchBox.Text) end
		end)

		return refresh
	end

	Explorer.InitSearch = function()
		local searchBox = Explorer.GuiElems.ToolBar.SearchFrame.SearchBox
		Explorer.GuiElems.SearchBar = searchBox
		searchBox.PlaceholderText = "Search (is:Part, Anchored=true, tag:...)"

		Lib.ViewportTextBox.convert(searchBox)
		local refreshSuggestions = Explorer.InitSearchSuggestions(searchBox)

		local searchId = 0
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			-- Tab accepts a suggestion and must not end up in the query
			if string.find(searchBox.Text, "\t", 1, true) then
				searchBox.Text = string.gsub(searchBox.Text, "\t", "")
				return
			end

			refreshSuggestions()
			if not Settings.Explorer.LiveSearch then return end

			searchId += 1
			local currentId = searchId
			task.delay(LIVE_SEARCH_DELAY, function()
				if currentId == searchId then Explorer.DoSearch(searchBox.Text, true) end
			end)
		end)

		Explorer.GuiElems.ToolBar.SearchFrame.Reset.MouseButton1Click:Connect(function()
			searchId += 1
			Explorer.ClearSearch()
		end)
	end

	Explorer.InitEntryTemplate = function()
		entryTemplate = create({
			{ 1, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderColor3 = Color3.new(0, 0, 0), Font = 3, Name = "Entry", Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(0, 250, 0, 20), Text = "", TextSize = 14 } },
			{
				2,
				"Frame",
				{
					BackgroundColor3 = Color3.new(0.04313725605607, 0.35294118523598, 0.68627452850342),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.new(0.33725491166115, 0.49019610881805, 0.73725491762161),
					BorderSizePixel = 0,
					Name = "Indent",
					Parent = { 1 },
					Position = UDim2.new(0, 20, 0, 0),
					Size = UDim2.new(1, -20, 1, 0),
				},
			},
			{
				3,
				"TextLabel",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Font = 3,
					Name = "EntryName",
					Parent = { 2 },
					Position = UDim2.new(0, 26, 0, 0),
					Size = UDim2.new(1, -26, 1, 0),
					Text = "Workspace",
					TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
					TextSize = 14,
					TextXAlignment = 0,
				},
			},
			{ 4, "TextButton", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Font = 3, Name = "Expand", Parent = { 2 }, Position = UDim2.new(0, -20, 0, 0), Size = UDim2.new(0, 20, 0, 20), Text = "", TextSize = 14 } },
			{
				5,
				"ImageLabel",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Image = "rbxassetid://5642383285",
					ImageRectOffset = Vector2.new(144, 16),
					ImageRectSize = Vector2.new(16, 16),
					Name = "Icon",
					Parent = { 4 },
					Position = UDim2.new(0, 2, 0, 2),
					ScaleType = 4,
					Size = UDim2.new(0, 16, 0, 16),
				},
			},
			{
				6,
				"ImageLabel",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Image = Main.ClassImages,
					ImageRectOffset = Vector2.new(304, 0),
					ImageRectSize = Vector2.new(16, 16),
					Name = "Icon",
					Parent = { 2 },
					Position = UDim2.new(0, 4, 0, 2),
					ScaleType = 4,
					Size = UDim2.new(0, 16, 0, 16),
				},
			},
		})

		local sys = Lib.ClickSystem.new()
		sys.AllowedButtons = { 1, 2 }
		sys.OnDown:Connect(function(item, combo, button)
			local ind = table.find(listEntries, item)
			if not ind then return end
			local node = tree[ind + Explorer.Index]
			if not node then return end

			local entry = listEntries[ind]

			if button == 1 then
				if combo == 2 then
					if node.Obj:IsA("LuaSourceContainer") then
						ScriptViewer.ViewScript(node.Obj)
					elseif #node > 0 and expanded[node] ~= 0 then
						expanded[node] = not expanded[node]
						Explorer.Update()
					end
				end

				if Properties.SelectObject(node.Obj) then
					sys.IsRenaming = false
					return
				end

				sys.IsRenaming = selection.Map[node]

				if Lib.IsShiftDown() then
					if not selection.Piviot then return end

					local fromIndex = table.find(tree, selection.Piviot)
					local toIndex = table.find(tree, node)
					if not fromIndex or not toIndex then return end
					fromIndex, toIndex = math.min(fromIndex, toIndex), math.max(fromIndex, toIndex)

					local sList = selection.List
					for i = #sList, 1, -1 do
						local elem = sList[i]
						if selection.ShiftSet[elem] then
							selection.Map[elem] = nil
							table.remove(sList, i)
						end
					end
					selection.ShiftSet = {}
					for i = fromIndex, toIndex do
						local elem = tree[i]
						if not selection.Map[elem] then
							selection.ShiftSet[elem] = true
							selection.Map[elem] = true
							sList[#sList + 1] = elem
						end
					end
					selection.Changed:Fire()
				elseif Lib.IsCtrlDown() then
					selection.ShiftSet = {}
					if selection.Map[node] then
						selection:Remove(node)
					else
						selection:Add(node)
					end
					selection.Piviot = node
					sys.IsRenaming = false
				elseif not selection.Map[node] then
					selection.ShiftSet = {}
					selection:Set(node)
					selection.Piviot = node
				end
			elseif button == 2 then
				if Properties.SelectObject(node.Obj) then return end

				if not Lib.IsCtrlDown() and not selection.Map[node] then
					selection.ShiftSet = {}
					selection:Set(node)
					selection.Piviot = node
					Explorer.Refresh()
				end
			end

			Explorer.Refresh()
		end)

		sys.OnRelease:Connect(function(item, combo, button)
			local ind = table.find(listEntries, item)
			if not ind then return end
			local node = tree[ind + Explorer.Index]
			if not node then return end

			if button == 1 then
				if selection.Map[node] and not Lib.IsShiftDown() and not Lib.IsCtrlDown() then
					selection.ShiftSet = {}
					selection:Set(node)
					selection.Piviot = node
					Explorer.Refresh()
				end

				local id = sys.ClickId
				Lib.FastWait(sys.ComboTime)
				if combo == 1 and id == sys.ClickId and sys.IsRenaming and selection.Map[node] then Explorer.SetRenamingNode(node) end
			elseif button == 2 then
				Explorer.ShowRightClick()
			end
		end)
		Explorer.ClickSystem = sys
	end

	-- Compacts children lists after deletions. removeObject marks the parent instead of
	-- shifting arrays on every removal, so bulk deletions stay cheap.
	Explorer.InitDelCleaner = function()
		task.spawn(function()
			while not Main.Destroyed do
				local processed = false
				for node in pendingDelParents do
					pendingDelParents[node] = nil
					local writeIndex = 1
					for readIndex = 1, #node do
						local child = node[readIndex]
						if not child.Del then
							node[writeIndex] = child
							writeIndex += 1
						end
					end
					for index = writeIndex, #node do
						node[index] = nil
					end
					node.HasDel = false
					processed = true
				end

				if processed and not refreshDebounce then Explorer.PerformRefresh() end
				task.wait(0.5)
			end
		end)
	end

	Explorer.UpdateSelectionVisuals = function()
		local holder = Explorer.SelectionVisualsHolder
		local isa = game.IsA
		local clone = game.Clone
		if not holder then
			holder = Instance.new("ScreenGui")
			holder.Name = "ExplorerSelections"
			holder.DisplayOrder = Main.DisplayOrders.Core
			Lib.ShowGui(holder)
			Explorer.SelectionVisualsHolder = holder
			Explorer.SelectionVisualCons = {}

			local guiTemplate = create({
				{ 1, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.new(0, 100, 0, 100) } },
				{ 2, "Frame", { BackgroundColor3 = Color3.new(0.04313725605607, 0.35294118523598, 0.68627452850342), BorderSizePixel = 0, Parent = { 1 }, Position = UDim2.new(0, -1, 0, -1), Size = UDim2.new(1, 2, 0, 1) } },
				{ 3, "Frame", { BackgroundColor3 = Color3.new(0.04313725605607, 0.35294118523598, 0.68627452850342), BorderSizePixel = 0, Parent = { 1 }, Position = UDim2.new(0, -1, 1, 0), Size = UDim2.new(1, 2, 0, 1) } },
				{ 4, "Frame", { BackgroundColor3 = Color3.new(0.04313725605607, 0.35294118523598, 0.68627452850342), BorderSizePixel = 0, Parent = { 1 }, Position = UDim2.new(0, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0) } },
				{ 5, "Frame", { BackgroundColor3 = Color3.new(0.04313725605607, 0.35294118523598, 0.68627452850342), BorderSizePixel = 0, Parent = { 1 }, Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0) } },
			})
			Explorer.SelectionVisualGui = guiTemplate

			local boxTemplate = Instance.new("SelectionBox")
			boxTemplate.LineThickness = 0.03
			boxTemplate.Color3 = Color3.fromRGB(0, 170, 255)
			Explorer.SelectionVisualBox = boxTemplate
		end
		holder:ClearAllChildren()

		-- Updates theme
		for i, v in pairs(Explorer.SelectionVisualGui:GetChildren()) do
			v.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
		end

		local attachCons = Explorer.SelectionVisualCons
		for i = 1, #attachCons do
			attachCons[i].Destroy()
		end
		table.clear(attachCons)

		local partEnabled = Settings.Explorer.PartSelectionBox
		local guiEnabled = Settings.Explorer.GuiSelectionBox
		if not partEnabled and not guiEnabled then return end

		local svg = Explorer.SelectionVisualGui
		local svb = Explorer.SelectionVisualBox
		local attachTo = Lib.AttachTo
		local sList = selection.List
		local count = 1
		local boxCount = 0
		local workspaceNode = nodes[workspace]
		for i = 1, #sList do
			if boxCount > 1000 then break end
			local node = sList[i]
			local obj = node.Obj

			if node ~= workspaceNode then
				if isa(obj, "GuiObject") and guiEnabled then
					local newVisual = clone(svg)
					attachCons[count] = attachTo(newVisual, { Target = obj, Resize = true })
					count = count + 1
					newVisual.Parent = holder
					boxCount = boxCount + 1
				elseif isa(obj, "PVInstance") and partEnabled then
					local newBox = clone(svb)
					newBox.Adornee = obj
					newBox.Parent = holder
					boxCount = boxCount + 1
				end
			end
		end
	end

	Explorer.Destroy = function()
		for _, connection in { descendantAddedCon, descendantRemovingCon, itemChangedCon } do
			connection:Disconnect()
		end
		for _, connections in nilCons do
			for _, connection in connections do
				connection:Disconnect()
			end
		end
		table.clear(nilCons)
		table.clear(pendingDelParents)
		table.clear(nodes)
	end

	Explorer.Init = function()
		Explorer.ClassIcons = Lib.IconMap.newLinear(Main.ClassImages, 16, 16)
		Explorer.MiscIcons = Main.MiscIcons

		clipboard = {}

		selection = Lib.Set.new()
		selection.ShiftSet = {}
		selection.Changed:Connect(Properties.ShowExplorerProps)
		Explorer.Selection = selection

		Explorer.InitRightClick()
		Explorer.InitInsertObject()
		Explorer.SetSortingEnabled(Settings.Explorer.Sorting)
		Explorer.Expanded = setmetatable({}, { __mode = "k" })
		Explorer.SearchExpanded = setmetatable({}, { __mode = "k" })
		expanded = Explorer.Expanded

		nilNode.Obj.Name = "Nil Instances"
		nilNode.Locked = true

		local explorerItems = create({
			{ 1, "Folder", { Name = "ExplorerItems" } },
			{ 2, "Frame", { BackgroundColor3 = Color3.new(0.20392157137394, 0.20392157137394, 0.20392157137394), BorderSizePixel = 0, Name = "ToolBar", Parent = { 1 }, Size = UDim2.new(1, 0, 0, 22) } },
			{
				3,
				"Frame",
				{
					BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
					BorderColor3 = Color3.new(0.1176470592618, 0.1176470592618, 0.1176470592618),
					BorderSizePixel = 0,
					Name = "SearchFrame",
					Parent = { 2 },
					Position = UDim2.new(0, 3, 0, 1),
					Size = UDim2.new(1, -6, 0, 18),
				},
			},
			{
				4,
				"TextBox",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					Font = 3,
					Name = "SearchBox",
					Parent = { 3 },
					PlaceholderColor3 = Color3.new(0.39215689897537, 0.39215689897537, 0.39215689897537),
					PlaceholderText = "Search workspace",
					Position = UDim2.new(0, 4, 0, 0),
					Size = UDim2.new(1, -24, 0, 18),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextXAlignment = 0,
				},
			},
			{ 5, "UICorner", { CornerRadius = UDim.new(0, 2), Parent = { 3 } } },
			{
				6,
				"TextButton",
				{
					AutoButtonColor = false,
					BackgroundColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = 3,
					Name = "Reset",
					Parent = { 3 },
					Position = UDim2.new(1, -17, 0, 1),
					Size = UDim2.new(0, 16, 0, 16),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
				},
			},
			{ 7, "ImageLabel", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Image = "rbxassetid://5034718129", ImageColor3 = Color3.new(0.39215686917305, 0.39215686917305, 0.39215686917305), Parent = { 6 }, Size = UDim2.new(0, 16, 0, 16) } },
			{
				8,
				"TextButton",
				{
					AutoButtonColor = false,
					BackgroundColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = 3,
					Name = "Refresh",
					Parent = { 2 },
					Position = UDim2.new(1, -20, 0, 1),
					Size = UDim2.new(0, 18, 0, 18),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					Visible = false,
				},
			},
			{ 9, "ImageLabel", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Image = "rbxassetid://5642310344", Parent = { 8 }, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0, 12, 0, 12) } },
			{ 10, "Frame", { BackgroundColor3 = Color3.new(0.15686275064945, 0.15686275064945, 0.15686275064945), BorderSizePixel = 0, Name = "ScrollCorner", Parent = { 1 }, Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 16, 0, 16), Visible = false } },
			{ 11, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Name = "List", Parent = { 1 }, Position = UDim2.new(0, 0, 0, 23), Size = UDim2.new(1, 0, 1, -23) } },
		})

		toolBar = explorerItems.ToolBar
		treeFrame = explorerItems.List

		Explorer.GuiElems.ToolBar = toolBar
		Explorer.GuiElems.TreeFrame = treeFrame

		scrollV = Lib.ScrollBar.new()
		scrollV.WheelIncrement = 3
		scrollV.Gui.Position = UDim2.new(1, -16, 0, 23)
		scrollV:SetScrollFrame(treeFrame)
		scrollV.Scrolled:Connect(function()
			Explorer.Index = scrollV.Index
			Explorer.Refresh()
		end)

		scrollH = Lib.ScrollBar.new(true)
		scrollH.Increment = 5
		scrollH.WheelIncrement = Explorer.EntryIndent
		scrollH.Gui.Position = UDim2.new(0, 0, 1, -16)
		scrollH.Scrolled:Connect(function() Explorer.Refresh() end)

		local window = Lib.Window.new()
		Explorer.Window = window
		window:SetTitle("Explorer")
		window.GuiElems.Line.Position = UDim2.new(0, 0, 0, 22)

		Explorer.InitEntryTemplate()
		toolBar.Parent = window.GuiElems.Content
		treeFrame.Parent = window.GuiElems.Content
		explorerItems.ScrollCorner.Parent = window.GuiElems.Content
		scrollV.Gui.Parent = window.GuiElems.Content
		scrollH.Gui.Parent = window.GuiElems.Content

		-- Init stuff that requires the window
		Explorer.InitRenameBox()
		Explorer.InitSearch()
		Explorer.InitDelCleaner()
		selection.Changed:Connect(Explorer.UpdateSelectionVisuals)

		-- Window events
		window.GuiElems.Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if Explorer.Active then
				Explorer.UpdateView()
				Explorer.Refresh()
			end
		end)
		window.OnActivate:Connect(function()
			Explorer.Active = true
			Explorer.UpdateView()
			Explorer.Update()
			Explorer.Refresh()
		end)
		window.OnRestore:Connect(function()
			Explorer.Active = true
			Explorer.UpdateView()
			Explorer.Update()
			Explorer.Refresh()
		end)
		window.OnDeactivate:Connect(function() Explorer.Active = false end)
		window.OnMinimize:Connect(function() Explorer.Active = false end)

		-- Settings
		autoUpdateSearch = Settings.Explorer.AutoUpdateSearch

		-- Fill in nodes
		nodes[game] = { Obj = game }
		expanded[nodes[game] ] = true

		-- Nil Instances
		if env.getnilinstances then nodes[nilNode.Obj] = nilNode end

		Explorer.SetupConnections()

		local insts = getDescendants(game)
		if Main.Elevated then
			for i = 1, #insts do
				local obj = insts[i]
				local par = nodes[ffa(obj, "Instance")]
				if not par then continue end
				local newNode = {
					Obj = obj,
					Parent = par,
				}
				nodes[obj] = newNode
				par[#par + 1] = newNode
			end
		else
			for i = 1, #insts do
				local obj = insts[i]
				local s, parObj = pcall(ffa, obj, "Instance")
				local par = nodes[parObj]
				if not par then continue end
				local newNode = {
					Obj = obj,
					Parent = par,
				}
				nodes[obj] = newNode
				par[#par + 1] = newNode
			end
		end
	end

	return Explorer
end

return { InitAfterMain = initAfterMain, Main = main }
end function __DARKDEX_MODULES.r()local v=__DARKDEX_MODULES.cache.r if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.r=v end return v.c end end do local function __modImpl()--[[
	Properties App Module

	The main properties interface
]]


local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Main = Context.Main
local Lib = Context.Lib
local Apps = Context.Apps
local Settings = Context.Settings
local service = Context.service
local create = Create.create
local CollectionService = service.CollectionService
local API, RMD
local Explorer, Properties

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
end

local function main()
	API, RMD = Context.API, Context.RMD
	local Properties = {}

	local window, toolBar, propsFrame
	local scrollV, scrollH
	local categoryOrder
	local props, viewList, expanded, indexableProps, propEntries, autoUpdateObjs = {}, {}, {}, {}, {}, {}
	local inputBox, inputTextBox, inputProp
	local checkboxes, propCons = {}, {}
	local table, string = table, string
	local getPropChangedSignal = game.GetPropertyChangedSignal
	local getAttributeChangedSignal = game.GetAttributeChangedSignal
	local isa = game.IsA
	local getAttribute = game.GetAttribute
	local setAttribute = game.SetAttribute

	Properties.GuiElems = {}
	Properties.Index = 0
	Properties.ViewWidth = 0
	Properties.MinInputWidth = 100
	Properties.EntryIndent = 16
	Properties.EntryOffset = 4
	Properties.NameWidthCache = {}
	Properties.SubPropCache = {}
	Properties.ClassLists = {}
	Properties.SearchText = ""

	Properties.AddAttributeProp = { Category = "Attributes", Class = "", Name = "", SpecialRow = "AddAttribute", Tags = {} }
	Properties.SoundPreviewProp = { Category = "Data", ValueType = { Name = "SoundPlayer" }, Class = "Sound", Name = "Preview", Tags = {} }

	Properties.IgnoreProps = {
		["DataModel"] = {
			["PrivateServerId"] = true,
			["PrivateServerOwnerId"] = true,
			["VIPServerId"] = true,
			["VIPServerOwnerId"] = true,
		},
	}

	Properties.ExpandableTypes = {
		["Vector2"] = true,
		["Vector3"] = true,
		["UDim"] = true,
		["UDim2"] = true,
		["CFrame"] = true,
		["Rect"] = true,
		["PhysicalProperties"] = true,
		["Ray"] = true,
		["NumberRange"] = true,
		["Faces"] = true,
		["Axes"] = true,
	}

	Properties.ExpandableProps = {
		["Sound.SoundId"] = true,
	}

	Properties.CollapsedCategories = {
		["Surface Inputs"] = true,
		["Surface"] = true,
	}

	Properties.ConflictSubProps = {
		["Vector2"] = { "X", "Y" },
		["Vector3"] = { "X", "Y", "Z" },
		["UDim"] = { "Scale", "Offset" },
		["UDim2"] = { "X", "X.Scale", "X.Offset", "Y", "Y.Scale", "Y.Offset" },
		["CFrame"] = { "Position", "Position.X", "Position.Y", "Position.Z", "RightVector", "RightVector.X", "RightVector.Y", "RightVector.Z", "UpVector", "UpVector.X", "UpVector.Y", "UpVector.Z", "LookVector", "LookVector.X", "LookVector.Y", "LookVector.Z" },
		["Rect"] = { "Min.X", "Min.Y", "Max.X", "Max.Y" },
		["PhysicalProperties"] = { "Density", "Elasticity", "ElasticityWeight", "Friction", "FrictionWeight" },
		["Ray"] = { "Origin", "Origin.X", "Origin.Y", "Origin.Z", "Direction", "Direction.X", "Direction.Y", "Direction.Z" },
		["NumberRange"] = { "Min", "Max" },
		["Faces"] = { "Back", "Bottom", "Front", "Left", "Right", "Top" },
		["Axes"] = { "X", "Y", "Z" },
	}

	Properties.ConflictIgnore = {
		["BasePart"] = {
			["ResizableFaces"] = true,
		},
	}

	Properties.RoundableTypes = {
		["float"] = true,
		["double"] = true,
		["Color3"] = true,
		["UDim"] = true,
		["UDim2"] = true,
		["Vector2"] = true,
		["Vector3"] = true,
		["NumberRange"] = true,
		["Rect"] = true,
		["NumberSequence"] = true,
		["ColorSequence"] = true,
		["Ray"] = true,
		["CFrame"] = true,
	}

	Properties.TypeNameConvert = {
		["number"] = "double",
		["boolean"] = "bool",
	}

	Properties.ToNumberTypes = {
		["int"] = true,
		["int64"] = true,
		["float"] = true,
		["double"] = true,
	}

	Properties.DefaultPropValue = {
		string = "",
		bool = false,
		double = 0,
		UDim = UDim.new(0, 0),
		UDim2 = UDim2.new(0, 0, 0, 0),
		BrickColor = BrickColor.new("Medium stone grey"),
		Color3 = Color3.new(1, 1, 1),
		Vector2 = Vector2.new(0, 0),
		Vector3 = Vector3.new(0, 0, 0),
		NumberSequence = NumberSequence.new(1),
		ColorSequence = ColorSequence.new(Color3.new(1, 1, 1)),
		NumberRange = NumberRange.new(0),
		Rect = Rect.new(0, 0, 0, 0),
	}

	Properties.AllowedAttributeTypes = { "string", "boolean", "number", "UDim", "UDim2", "BrickColor", "Color3", "Vector2", "Vector3", "NumberSequence", "ColorSequence", "NumberRange", "Rect" }

	Properties.StringToValue = function(prop, str)
		local typeData = prop.ValueType
		local typeName = typeData.Name

		if typeName == "string" or typeName == "Content" then
			return str
		elseif Properties.ToNumberTypes[typeName] then
			return tonumber(str)
		elseif typeName == "Vector2" then
			local vals = str:split(",")
			local x, y = tonumber(vals[1]), tonumber(vals[2])
			if x and y and #vals >= 2 then return Vector2.new(x, y) end
		elseif typeName == "Vector3" then
			local vals = str:split(",")
			local x, y, z = tonumber(vals[1]), tonumber(vals[2]), tonumber(vals[3])
			if x and y and z and #vals >= 3 then return Vector3.new(x, y, z) end
		elseif typeName == "UDim" then
			local vals = str:split(",")
			local scale, offset = tonumber(vals[1]), tonumber(vals[2])
			if scale and offset and #vals >= 2 then return UDim.new(scale, offset) end
		elseif typeName == "UDim2" then
			local vals = str:gsub("[{}]", ""):split(",")
			local xScale, xOffset, yScale, yOffset = tonumber(vals[1]), tonumber(vals[2]), tonumber(vals[3]), tonumber(vals[4])
			if xScale and xOffset and yScale and yOffset and #vals >= 4 then return UDim2.new(xScale, xOffset, yScale, yOffset) end
		elseif typeName == "CFrame" then
			local vals = str:split(",")
			local s, result = pcall(CFrame.new, unpack(vals))
			if s and #vals >= 12 then return result end
		elseif typeName == "Rect" then
			local vals = str:split(",")
			local s, result = pcall(Rect.new, unpack(vals))
			if s and #vals >= 4 then return result end
		elseif typeName == "Ray" then
			local vals = str:gsub("[{}]", ""):split(",")
			local s, origin = pcall(Vector3.new, unpack(vals, 1, 3))
			local s2, direction = pcall(Vector3.new, unpack(vals, 4, 6))
			if s and s2 and #vals >= 6 then return Ray.new(origin, direction) end
		elseif typeName == "NumberRange" then
			local vals = str:split(",")
			local s, result = pcall(NumberRange.new, unpack(vals))
			if s and #vals >= 1 then return result end
		elseif typeName == "Color3" then
			local vals = str:gsub("[{}]", ""):split(",")
			local s, result = pcall(Color3.fromRGB, unpack(vals))
			if s and #vals >= 3 then return result end
		end

		return nil
	end

	Properties.ValueToString = function(prop, val)
		local typeData = prop.ValueType
		local typeName = typeData.Name

		if typeName == "Color3" then
			return Lib.ColorToBytes(val)
		elseif typeName == "NumberRange" then
			return val.Min .. ", " .. val.Max
		end

		return tostring(val)
	end

	Properties.GetIndexableProps = function(obj, classData)
		if not Main.Elevated then
			if not pcall(function() return obj.ClassName end) then return nil end
		end

		local ignoreProps = Properties.IgnoreProps[classData.Name] or {}

		local result = {}
		local count = 1
		local props = classData.Properties
		for i = 1, #props do
			local prop = props[i]
			if not ignoreProps[prop.Name] then
				local s = pcall(function() return obj[prop.Name] end)
				if s then
					result[count] = prop
					count = count + 1
				end
			end
		end

		return result
	end

	Properties.FindFirstObjWhichIsA = function(class)
		local classList = Properties.ClassLists[class] or {}
		if classList and #classList > 0 then return classList[1] end

		return nil
	end

	Properties.ComputeConflicts = function(p)
		local maxConflictCheck = Settings.Properties.MaxConflictCheck
		local sList = Explorer.Selection.List
		local classLists = Properties.ClassLists
		local stringSplit = string.split
		local t_clear = table.clear
		local conflictIgnore = Properties.ConflictIgnore
		local conflictMap = {}
		local propList = p and { p } or props

		if p then
			local gName = p.Class .. "." .. p.Name
			autoUpdateObjs[gName] = nil
			local subProps = Properties.ConflictSubProps[p.ValueType.Name] or {}
			for i = 1, #subProps do
				autoUpdateObjs[gName .. "." .. subProps[i] ] = nil
			end
		else
			table.clear(autoUpdateObjs)
		end

		if #sList > 0 then
			for i = 1, #propList do
				local prop = propList[i]
				local propName, propClass = prop.Name, prop.Class
				local typeData = prop.RootType or prop.ValueType
				local typeName = typeData.Name
				local attributeName = prop.AttributeName
				local gName = propClass .. "." .. propName

				local checked = 0
				local subProps = Properties.ConflictSubProps[typeName] or {}
				local subPropCount = #subProps
				local toCheck = subPropCount + 1
				local conflictsFound = 0
				local indexNames = {}
				local ignored = conflictIgnore[propClass] and conflictIgnore[propClass][propName]
				local truthyCheck = (typeName == "PhysicalProperties")
				local isAttribute = prop.IsAttribute
				local IsTag = prop.IsTag
				local isMultiType = prop.MultiType

				t_clear(conflictMap)

				if not isMultiType then
					local firstVal, firstObj, firstSet
					local classList = classLists[prop.Class] or {}
					for c = 1, #classList do
						local obj = classList[c]
						if not firstSet then
							if isAttribute then
								firstVal = getAttribute(obj, attributeName)
								if firstVal ~= nil then
									firstObj = obj
									firstSet = true
								end
							elseif IsTag then
								local tagVal = CollectionService:HasTag(obj, attributeName)
								if tagVal then
									firstObj = obj
									firstSet = true
								end
							else
								firstVal = obj[propName]
								firstObj = obj
								firstSet = true
							end
							if ignored then break end
						else
							local propVal, skip
							if isAttribute then
								propVal = getAttribute(obj, attributeName)
								if propVal == nil then skip = true end
							elseif IsTag then
								propVal = CollectionService:HasTag(obj, attributeName) and attributeName or nil
								if propVal == nil then skip = true end
							else
								propVal = obj[propName]
							end

							if not skip then
								if not conflictMap[1] then
									if truthyCheck then
										if (firstVal and true or false) ~= (propVal and true or false) then
											conflictMap[1] = true
											conflictsFound = conflictsFound + 1
										end
									elseif firstVal ~= propVal then
										conflictMap[1] = true
										conflictsFound = conflictsFound + 1
									end
								end

								if subPropCount > 0 then
									for sPropInd = 1, subPropCount do
										local indexes = indexNames[sPropInd]
										if not indexes then
											indexes = stringSplit(subProps[sPropInd], ".")
											indexNames[sPropInd] = indexes
										end

										local firstValSub = firstVal
										local propValSub = propVal

										for j = 1, #indexes do
											if not firstValSub or not propValSub then break end -- PhysicalProperties
											local indexName = indexes[j]
											firstValSub = firstValSub[indexName]
											propValSub = propValSub[indexName]
										end

										local mapInd = sPropInd + 1
										if not conflictMap[mapInd] and firstValSub ~= propValSub then
											conflictMap[mapInd] = true
											conflictsFound = conflictsFound + 1
										end
									end
								end

								if conflictsFound == toCheck then break end
							end
						end

						checked = checked + 1
						if checked == maxConflictCheck then break end
					end

					if not conflictMap[1] then autoUpdateObjs[gName] = firstObj end
					for sPropInd = 1, subPropCount do
						if not conflictMap[sPropInd + 1] then autoUpdateObjs[gName .. "." .. subProps[sPropInd] ] = firstObj end
					end
				end
			end
		end

		if p then Properties.Refresh() end
	end

	-- Fetches the properties to be displayed based on the explorer selection
	-- Settings.Properties.ShowAttributes = true -- im making it true anyway since its useful by default and people complain
	-- Settings.Properties.ShowTags = true
	Properties.ShowExplorerProps = function()
		local maxConflictCheck = Settings.Properties.MaxConflictCheck
		local sList = Explorer.Selection.List
		local foundClasses = {}
		local propCount = 1
		local elevated = Main.Elevated
		local ShowDeprecatedProperties, ShowHiddenProperties = Settings.Properties.ShowDeprecatedProperties, Settings.Properties.ShowHiddenProperties
		local Classes = API.Classes
		local classLists = {}
		local lower = string.lower
		local RMDCustomOrders = RMD.PropertyOrders
		local getAttributes = game.GetAttributes
		local maxAttrs = Settings.Properties.MaxAttributes
		local showingAttrs = Settings.Properties.ShowAttributes
		local foundAttrs = {}
		local attrCount = 0
		local getTags = CollectionService.GetTags
		local maxTags = Settings.Properties.MaxTags
		local showingTags = Settings.Properties.ShowTags
		local foundTags = {}
		local tagCount = 0

		local typeof = typeof
		local typeNameConvert = Properties.TypeNameConvert

		table.clear(props)

		for i = 1, #sList do
			local node = sList[i]
			local obj = node.Obj
			local class = node.Class
			if not class then
				class = obj.ClassName
				node.Class = class
			end

			local apiClass = Classes[class]
			while apiClass do
				local APIClassName = apiClass.Name
				if not foundClasses[APIClassName] then
					local apiProps = indexableProps[APIClassName]
					if not apiProps then
						apiProps = Properties.GetIndexableProps(obj, apiClass)
						indexableProps[APIClassName] = apiProps
					end

					for i = 1, #apiProps do
						local prop = apiProps[i]
						local tags = prop.Tags
						if (not tags.Deprecated or ShowDeprecatedProperties) and (not tags.Hidden or ShowHiddenProperties) then
							props[propCount] = prop
							propCount = propCount + 1
						end
					end
					foundClasses[APIClassName] = true
				end

				local classList = classLists[APIClassName]
				if not classList then
					classList = {}
					classLists[APIClassName] = classList
				end
				classList[#classList + 1] = obj

				apiClass = apiClass.Superclass
			end

			if showingAttrs and attrCount < maxAttrs then
				local attrs = getAttributes(obj)
				for name, val in pairs(attrs) do
					local typ = typeof(val)
					if not foundAttrs[name] then
						local category = (typ == "Instance" and "Class") or (typ == "EnumItem" and "Enum") or "Other"
						local valType = { Name = typeNameConvert[typ] or typ, Category = category }
						local attrProp = { IsAttribute = true, Name = "ATTR_" .. name, AttributeName = name, DisplayName = name, Class = "Instance", ValueType = valType, Category = "Attributes", Tags = {} }
						props[propCount] = attrProp
						propCount = propCount + 1
						attrCount = attrCount + 1
						foundAttrs[name] = { typ, attrProp }
						if attrCount == maxAttrs then break end
					elseif foundAttrs[name][1] ~= typ then
						foundAttrs[name][2].MultiType = true
						foundAttrs[name][2].Tags.ReadOnly = true
						foundAttrs[name][2].ValueType = { Name = "string" }
					end
				end
			end

			if showingTags and tagCount < maxTags then
				local tags = CollectionService:GetTags(obj)
				for _, name in pairs(tags) do
					if not foundTags[name] then
						local tagProp = { IsTag = true, Name = "TAG_" .. name, AttributeName = name, DisplayName = name, Class = "Instance", ValueType = { Name = "string" }, Category = "Tags", Tags = { ReadOnly = true } }
						props[propCount] = tagProp
						propCount = propCount + 1
						tagCount = tagCount + 1
						foundTags[name] = true
						if tagCount == maxTags then break end
					end
				end
			end
		end

		table.sort(props, function(a, b)
			if a.Category ~= b.Category then
				return (categoryOrder[a.Category] or 9999) < (categoryOrder[b.Category] or 9999)
			else
				local aOrder = (RMDCustomOrders[a.Class] and RMDCustomOrders[a.Class][a.Name]) or 9999999
				local bOrder = (RMDCustomOrders[b.Class] and RMDCustomOrders[b.Class][b.Name]) or 9999999
				if aOrder ~= bOrder then
					return aOrder < bOrder
				else
					return lower(a.Name) < lower(b.Name)
				end
			end
		end)

		-- Find conflicts and get auto-update instances
		Properties.ClassLists = classLists
		Properties.ComputeConflicts()
		--warn("CONFLICT",os.clock()-start)
		if #props > 0 then props[#props + 1] = Properties.AddAttributeProp end

		Properties.Update()
		Properties.Refresh()
	end

	Properties.UpdateView = function()
		local maxEntries = math.ceil(propsFrame.AbsoluteSize.Y / 23)
		local maxX = propsFrame.AbsoluteSize.X
		local totalWidth = Properties.ViewWidth + Properties.MinInputWidth

		scrollV.VisibleSpace = maxEntries
		scrollV.TotalSpace = #viewList + 1
		scrollH.VisibleSpace = maxX
		scrollH.TotalSpace = totalWidth

		scrollV.Gui.Visible = #viewList + 1 > maxEntries
		scrollH.Gui.Visible = Settings.Properties.ScaleType == 0 and totalWidth > maxX

		local oldSize = propsFrame.Size
		propsFrame.Size = UDim2.new(1, (scrollV.Gui.Visible and -16 or 0), 1, (scrollH.Gui.Visible and -39 or -23))
		if oldSize ~= propsFrame.Size then
			Properties.UpdateView()
		else
			scrollV:Update()
			scrollH:Update()

			if scrollV.Gui.Visible and scrollH.Gui.Visible then
				scrollV.Gui.Size = UDim2.new(0, 16, 1, -39)
				scrollH.Gui.Size = UDim2.new(1, -16, 0, 16)
				Properties.Window.GuiElems.Content.ScrollCorner.Visible = true
			else
				scrollV.Gui.Size = UDim2.new(0, 16, 1, -23)
				scrollH.Gui.Size = UDim2.new(1, 0, 0, 16)
				Properties.Window.GuiElems.Content.ScrollCorner.Visible = false
			end

			Properties.Index = scrollV.Index
		end
	end

	Properties.MakeSubProp = function(prop, subName, valueType, displayName)
		local subProp = table.clone(prop)
		subProp.RootType = subProp.RootType or subProp.ValueType
		subProp.ValueType = valueType
		subProp.SubName = subProp.SubName and (subProp.SubName .. subName) or subName
		subProp.DisplayName = displayName

		return subProp
	end

	Properties.GetExpandedProps = function(prop) -- TODO: Optimize using table
		local result = {}
		local typeData = prop.ValueType
		local typeName = typeData.Name
		local makeSubProp = Properties.MakeSubProp

		if typeName == "Vector2" then
			result[1] = makeSubProp(prop, ".X", { Name = "float" })
			result[2] = makeSubProp(prop, ".Y", { Name = "float" })
		elseif typeName == "Vector3" then
			result[1] = makeSubProp(prop, ".X", { Name = "float" })
			result[2] = makeSubProp(prop, ".Y", { Name = "float" })
			result[3] = makeSubProp(prop, ".Z", { Name = "float" })
		elseif typeName == "CFrame" then
			result[1] = makeSubProp(prop, ".Position", { Name = "Vector3" })
			result[2] = makeSubProp(prop, ".RightVector", { Name = "Vector3" })
			result[3] = makeSubProp(prop, ".UpVector", { Name = "Vector3" })
			result[4] = makeSubProp(prop, ".LookVector", { Name = "Vector3" })
		elseif typeName == "UDim" then
			result[1] = makeSubProp(prop, ".Scale", { Name = "float" })
			result[2] = makeSubProp(prop, ".Offset", { Name = "int" })
		elseif typeName == "UDim2" then
			result[1] = makeSubProp(prop, ".X", { Name = "UDim" })
			result[2] = makeSubProp(prop, ".Y", { Name = "UDim" })
		elseif typeName == "Rect" then
			result[1] = makeSubProp(prop, ".Min.X", { Name = "float" }, "X0")
			result[2] = makeSubProp(prop, ".Min.Y", { Name = "float" }, "Y0")
			result[3] = makeSubProp(prop, ".Max.X", { Name = "float" }, "X1")
			result[4] = makeSubProp(prop, ".Max.Y", { Name = "float" }, "Y1")
		elseif typeName == "PhysicalProperties" then
			result[1] = makeSubProp(prop, ".Density", { Name = "float" })
			result[2] = makeSubProp(prop, ".Elasticity", { Name = "float" })
			result[3] = makeSubProp(prop, ".ElasticityWeight", { Name = "float" })
			result[4] = makeSubProp(prop, ".Friction", { Name = "float" })
			result[5] = makeSubProp(prop, ".FrictionWeight", { Name = "float" })
		elseif typeName == "Ray" then
			result[1] = makeSubProp(prop, ".Origin", { Name = "Vector3" })
			result[2] = makeSubProp(prop, ".Direction", { Name = "Vector3" })
		elseif typeName == "NumberRange" then
			result[1] = makeSubProp(prop, ".Min", { Name = "float" })
			result[2] = makeSubProp(prop, ".Max", { Name = "float" })
		elseif typeName == "Faces" then
			result[1] = makeSubProp(prop, ".Back", { Name = "bool" })
			result[2] = makeSubProp(prop, ".Bottom", { Name = "bool" })
			result[3] = makeSubProp(prop, ".Front", { Name = "bool" })
			result[4] = makeSubProp(prop, ".Left", { Name = "bool" })
			result[5] = makeSubProp(prop, ".Right", { Name = "bool" })
			result[6] = makeSubProp(prop, ".Top", { Name = "bool" })
		elseif typeName == "Axes" then
			result[1] = makeSubProp(prop, ".X", { Name = "bool" })
			result[2] = makeSubProp(prop, ".Y", { Name = "bool" })
			result[3] = makeSubProp(prop, ".Z", { Name = "bool" })
		end

		if prop.Name == "SoundId" and prop.Class == "Sound" then result[1] = Properties.SoundPreviewProp end

		return result
	end

	Properties.Update = function()
		table.clear(viewList)

		local nameWidthCache = Properties.NameWidthCache
		local lastCategory
		local count = 1
		local maxWidth, maxDepth = 0, 1

		local textServ = service.TextService
		local getTextSize = textServ.GetTextSize
		local font = Enum.Font.SourceSans
		local size = Vector2.new(math.huge, 20)
		local stringSplit = string.split
		local entryIndent = Properties.EntryIndent
		local isFirstScaleType = Settings.Properties.ScaleType == 0
		local find, lower = string.find, string.lower
		local searchText = (#Properties.SearchText > 0 and lower(Properties.SearchText))

		local function recur(props, depth)
			for i = 1, #props do
				local prop = props[i]
				local propName = prop.Name
				local subName = prop.SubName
				local category = prop.Category

				local visible
				if searchText and depth == 1 then
					if find(lower(propName), searchText, 1, true) then visible = true end
				else
					visible = true
				end

				if visible and lastCategory ~= category then
					viewList[count] = { CategoryName = category }
					count = count + 1
					lastCategory = category
				end

				if (expanded["CAT_" .. category] and visible) or prop.SpecialRow then
					if depth > 1 then
						prop.Depth = depth
						if depth > maxDepth then maxDepth = depth end
					end

					if isFirstScaleType then
						local nameArr = subName and stringSplit(subName, ".")
						local displayName = prop.DisplayName or (nameArr and nameArr[#nameArr]) or propName

						local nameWidth = nameWidthCache[displayName]
						if not nameWidth then
							nameWidth = getTextSize(textServ, displayName, 14, font, size).X
							nameWidthCache[displayName] = nameWidth
						end

						local totalWidth = nameWidth + entryIndent * depth
						if totalWidth > maxWidth then maxWidth = totalWidth end
					end

					viewList[count] = prop
					count = count + 1

					local fullName = prop.Class .. "." .. prop.Name .. (prop.SubName or "")
					if expanded[fullName] then
						local nextDepth = depth + 1
						local expandedProps = Properties.GetExpandedProps(prop)
						if #expandedProps > 0 then recur(expandedProps, nextDepth) end
					end
				end
			end
		end
		recur(props, 1)

		inputProp = nil
		Properties.ViewWidth = maxWidth + 9 + Properties.EntryOffset
		Properties.UpdateView()
	end

	Properties.NewPropEntry = function(index)
		local newEntry = Properties.EntryTemplate:Clone()
		local nameFrame = newEntry.NameFrame
		local valueFrame = newEntry.ValueFrame
		local newCheckbox = Lib.Checkbox.new(1)
		newCheckbox.Gui.Position = UDim2.new(0, 3, 0, 3)
		newCheckbox.Gui.Parent = valueFrame
		newCheckbox.OnInput:Connect(function()
			local prop = viewList[index + Properties.Index]
			if not prop then return end

			if prop.ValueType.Name == "PhysicalProperties" then
				Properties.SetProp(prop, newCheckbox.Toggled and true or nil)
			else
				Properties.SetProp(prop, newCheckbox.Toggled)
			end
		end)
		checkboxes[index] = newCheckbox

		local iconFrame = Main.MiscIcons:GetLabel()
		iconFrame.Position = UDim2.new(0, 2, 0, 3)
		iconFrame.Parent = newEntry.ValueFrame.RightButton

		newEntry.Position = UDim2.new(0, 0, 0, 23 * (index - 1))

		nameFrame.Expand.InputBegan:Connect(function(input)
			local prop = viewList[index + Properties.Index]
			if not prop or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			local fullName = (prop.CategoryName and "CAT_" .. prop.CategoryName) or prop.Class .. "." .. prop.Name .. (prop.SubName or "")

			Main.MiscIcons:DisplayByKey(newEntry.NameFrame.Expand.Icon, expanded[fullName] and "Collapse_Over" or "Expand_Over")
		end)

		nameFrame.Expand.InputEnded:Connect(function(input)
			local prop = viewList[index + Properties.Index]
			if not prop or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			local fullName = (prop.CategoryName and "CAT_" .. prop.CategoryName) or prop.Class .. "." .. prop.Name .. (prop.SubName or "")

			Main.MiscIcons:DisplayByKey(newEntry.NameFrame.Expand.Icon, expanded[fullName] and "Collapse" or "Expand")
		end)

		nameFrame.Expand.MouseButton1Down:Connect(function()
			local prop = viewList[index + Properties.Index]
			if not prop then return end

			local fullName = (prop.CategoryName and "CAT_" .. prop.CategoryName) or prop.Class .. "." .. prop.Name .. (prop.SubName or "")
			if not prop.CategoryName and not Properties.ExpandableTypes[prop.ValueType and prop.ValueType.Name] and not Properties.ExpandableProps[fullName] then return end

			expanded[fullName] = not expanded[fullName]
			Properties.Update()
			Properties.Refresh()
		end)

		nameFrame.PropName.InputBegan:Connect(function(input)
			local prop = viewList[index + Properties.Index]
			if not prop then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement and not nameFrame.PropName.TextFits then
				local fullNameFrame = Properties.FullNameFrame
				local nameArr = string.split(prop.Class .. "." .. prop.Name .. (prop.SubName or ""), ".")
				local dispName = prop.DisplayName or nameArr[#nameArr]
				local sizeX = service.TextService:GetTextSize(dispName, 14, Enum.Font.SourceSans, Vector2.new(math.huge, 20)).X

				fullNameFrame.TextLabel.Text = dispName
				--fullNameFrame.Position = UDim2.new(0,Properties.EntryIndent*(prop.Depth or 1) + Properties.EntryOffset,0,23*(index-1))
				fullNameFrame.Size = UDim2.new(0, sizeX + 4, 0, 22)
				fullNameFrame.Visible = true
				Properties.FullNameFrameIndex = index
				Properties.FullNameFrameAttach.SetData(fullNameFrame, { Target = nameFrame })
				Properties.FullNameFrameAttach.Enable()
			end
		end)

		nameFrame.PropName.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement and Properties.FullNameFrameIndex == index then
				Properties.FullNameFrame.Visible = false
				Properties.FullNameFrameAttach.Disable()
			end
		end)

		valueFrame.ValueBox.MouseButton1Down:Connect(function()
			local prop = viewList[index + Properties.Index]
			if not prop then return end

			Properties.SetInputProp(prop, index)
		end)

		valueFrame.ColorButton.MouseButton1Down:Connect(function()
			local prop = viewList[index + Properties.Index]
			if not prop then return end

			Properties.SetInputProp(prop, index, "color")
		end)

		valueFrame.RightButton.MouseButton1Click:Connect(function()
			local prop = viewList[index + Properties.Index]
			if not prop then return end

			local fullName = prop.Class .. "." .. prop.Name .. (prop.SubName or "")
			local inputFullName = inputProp and (inputProp.Class .. "." .. inputProp.Name .. (inputProp.SubName or ""))

			if fullName == inputFullName and inputProp.ValueType.Category == "Class" then
				inputProp = nil
				Properties.SetProp(prop, nil)
			else
				Properties.SetInputProp(prop, index, "right")
			end
		end)

		nameFrame.ToggleAttributes.MouseButton1Click:Connect(function()
			Settings.Properties.ShowAttributes = not Settings.Properties.ShowAttributes
			Properties.ShowExplorerProps()
		end)

		-- nameFrame.ToggleTags.MouseButton1Click:Connect(function()
		-- 	Settings.Properties.ShowTags = not Settings.Properties.ShowTags
		-- 	Properties.ShowExplorerProps()
		-- end)

		newEntry.RowButton.MouseButton1Click:Connect(function() Properties.DisplayAddAttributeWindow() end)

		newEntry.EditAttributeButton.MouseButton1Down:Connect(function()
			local prop = viewList[index + Properties.Index]
			if not prop then return end

			Properties.DisplayAttributeContext(prop)
		end)

		valueFrame.SoundPreview.ControlButton.MouseButton1Click:Connect(function()
			if Properties.PreviewSound and Properties.PreviewSound.Playing then
				Properties.SetSoundPreview(false)
			else
				local soundObj = Properties.FindFirstObjWhichIsA("Sound")
				if soundObj then Properties.SetSoundPreview(soundObj) end
			end
		end)

		valueFrame.SoundPreview.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

			local releaseEvent, mouseEvent
			releaseEvent = service.UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				releaseEvent:Disconnect()
				mouseEvent:Disconnect()
			end)

			local timeLine = newEntry.ValueFrame.SoundPreview.TimeLine
			local soundObj = Properties.FindFirstObjWhichIsA("Sound")
			if soundObj then Properties.SetSoundPreview(soundObj, true) end

			local function update(input)
				local sound = Properties.PreviewSound
				if not sound or sound.TimeLength == 0 then return end

				local mouseX = input.Position.X
				local timeLineSize = timeLine.AbsoluteSize
				local relaX = mouseX - timeLine.AbsolutePosition.X

				if timeLineSize.X <= 1 then return end
				if relaX < 0 then
					relaX = 0
				elseif relaX >= timeLineSize.X then
					relaX = timeLineSize.X - 1
				end

				local perc = (relaX / (timeLineSize.X - 1))
				sound.TimePosition = perc * sound.TimeLength
				timeLine.Slider.Position = UDim2.new(perc, -4, 0, -8)
			end
			update(input)

			mouseEvent = service.UserInputService.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
			end)
		end)

		newEntry.Parent = propsFrame

		return {
			Gui = newEntry,
			GuiElems = {
				NameFrame = nameFrame,
				ValueFrame = valueFrame,
				PropName = nameFrame.PropName,
				ValueBox = valueFrame.ValueBox,
				Expand = nameFrame.Expand,
				ColorButton = valueFrame.ColorButton,
				ColorPreview = valueFrame.ColorButton.ColorPreview,
				Gradient = valueFrame.ColorButton.ColorPreview.UIGradient,
				EnumArrow = valueFrame.EnumArrow,
				Checkbox = valueFrame.Checkbox,
				RightButton = valueFrame.RightButton,
				RightButtonIcon = iconFrame,
				RowButton = newEntry.RowButton,
				EditAttributeButton = newEntry.EditAttributeButton,
				ToggleAttributes = nameFrame.ToggleAttributes,
				-- ToggleTags = nameFrame.ToggleTags,
				SoundPreview = valueFrame.SoundPreview,
				SoundPreviewSlider = valueFrame.SoundPreview.TimeLine.Slider,
			},
		}
	end

	Properties.GetSoundPreviewEntry = function()
		for i = 1, #viewList do
			if viewList[i] == Properties.SoundPreviewProp then return propEntries[i - Properties.Index] end
		end
	end

	Properties.SetSoundPreview = function(soundObj, noplay)
		local sound = Properties.PreviewSound
		if not sound then
			sound = Instance.new("Sound")
			sound.Name = "Preview"
			sound.Paused:Connect(function()
				local entry = Properties.GetSoundPreviewEntry()
				if entry then Main.MiscIcons:DisplayByKey(entry.GuiElems.SoundPreview.ControlButton.Icon, "Play") end
			end)
			sound.Resumed:Connect(function() Properties.Refresh() end)
			sound.Ended:Connect(function()
				local entry = Properties.GetSoundPreviewEntry()
				if entry then entry.GuiElems.SoundPreviewSlider.Position = UDim2.new(0, -4, 0, -8) end
				Properties.Refresh()
			end)
			sound.Parent = window.Gui
			Properties.PreviewSound = sound
		end

		if not soundObj then
			sound:Pause()
		else
			local newId = sound.SoundId ~= soundObj.SoundId
			sound.SoundId = soundObj.SoundId
			sound.PlaybackSpeed = soundObj.PlaybackSpeed
			sound.Volume = soundObj.Volume
			if newId then sound.TimePosition = 0 end
			if not noplay then sound:Resume() end

			coroutine.wrap(function()
				local previewTime = os.clock()
				Properties.SoundPreviewTime = previewTime
				while previewTime == Properties.SoundPreviewTime and sound.Playing do
					local entry = Properties.GetSoundPreviewEntry()
					if entry then
						local tl = sound.TimeLength
						local perc = sound.TimePosition / (tl == 0 and 1 or tl)
						entry.GuiElems.SoundPreviewSlider.Position = UDim2.new(perc, -4, 0, -8)
					end
					Lib.FastWait()
				end
			end)()
			Properties.Refresh()
		end
	end

	Properties.DisplayAttributeContext = function(prop)
		local context = Properties.AttributeContext
		if not context then
			context = Lib.ContextMenu.new()
			context.Iconless = true
			context.Width = 80
			Properties.AttributeContext = context
		end

		context:Clear()

		context:Add({ Name = "Edit", OnClick = function() Properties.DisplayAddAttributeWindow(prop) end })
		context:Add({
			Name = "Delete",
			OnClick = function()
				Properties.SetProp(prop, nil, true)
				Properties.ShowExplorerProps()
			end,
		})

		context:Show()
	end

	Properties.DisplayAddAttributeWindow = function(editAttr)
		local win = Properties.AddAttributeWindow
		if not win then
			win = Lib.Window.new()
			win.Alignable = false
			win.Resizable = false
			win:SetTitle("Add Attribute")
			win:SetSize(200, 130)

			local saveButton = Lib.Button.new()
			local nameLabel = Lib.Label.new()
			nameLabel.Text = "Name"
			nameLabel.Position = UDim2.new(0, 30, 0, 10)
			nameLabel.Size = UDim2.new(0, 40, 0, 20)
			win:Add(nameLabel)

			local nameBox = Lib.ViewportTextBox.new()
			nameBox.Position = UDim2.new(0, 75, 0, 10)
			nameBox.Size = UDim2.new(0, 120, 0, 20)
			win:Add(nameBox, "NameBox")
			nameBox.TextBox:GetPropertyChangedSignal("Text"):Connect(function() saveButton:SetDisabled(#nameBox:GetText() == 0) end)

			local typeLabel = Lib.Label.new()
			typeLabel.Text = "Type"
			typeLabel.Position = UDim2.new(0, 30, 0, 40)
			typeLabel.Size = UDim2.new(0, 40, 0, 20)
			win:Add(typeLabel)

			local typeChooser = Lib.DropDown.new()
			typeChooser.CanBeEmpty = false
			typeChooser.Position = UDim2.new(0, 75, 0, 40)
			typeChooser.Size = UDim2.new(0, 120, 0, 20)
			typeChooser:SetOptions(Properties.AllowedAttributeTypes)
			win:Add(typeChooser, "TypeChooser")

			local errorLabel = Lib.Label.new()
			errorLabel.Text = ""
			errorLabel.Position = UDim2.new(0, 5, 1, -45)
			errorLabel.Size = UDim2.new(1, -10, 0, 20)
			errorLabel.TextColor3 = Settings.Theme.Important
			win.ErrorLabel = errorLabel
			win:Add(errorLabel, "Error")

			local cancelButton = Lib.Button.new()
			cancelButton.Text = "Cancel"
			cancelButton.Position = UDim2.new(1, -97, 1, -25)
			cancelButton.Size = UDim2.new(0, 92, 0, 20)
			cancelButton.OnClick:Connect(function() win:Close() end)
			win:Add(cancelButton)

			saveButton.Text = "Save"
			saveButton.Position = UDim2.new(0, 5, 1, -25)
			saveButton.Size = UDim2.new(0, 92, 0, 20)
			saveButton.OnClick:Connect(function()
				local name = nameBox:GetText()
				if #name > 100 then
					errorLabel.Text = "Error: Name over 100 chars"
					return
				elseif name:sub(1, 3) == "RBX" then
					errorLabel.Text = "Error: Name begins with 'RBX'"
					return
				end

				local typ = typeChooser.Selected
				local valType = { Name = Properties.TypeNameConvert[typ] or typ, Category = "DataType" }
				local attrProp = { IsAttribute = true, Name = "ATTR_" .. name, AttributeName = name, DisplayName = name, Class = "Instance", ValueType = valType, Category = "Attributes", Tags = {} }

				Settings.Properties.ShowAttributes = true
				Properties.SetProp(attrProp, Properties.DefaultPropValue[valType.Name], true, Properties.EditingAttribute)
				Properties.ShowExplorerProps()
				win:Close()
			end)
			win:Add(saveButton, "SaveButton")

			Properties.AddAttributeWindow = win
		end

		Properties.EditingAttribute = editAttr
		win:SetTitle(editAttr and "Edit Attribute " .. editAttr.AttributeName or "Add Attribute")
		win.Elements.Error.Text = ""
		win.Elements.NameBox:SetText("")
		win.Elements.SaveButton:SetDisabled(true)
		win.Elements.TypeChooser:SetSelected(1)
		win:Show()
	end

	Properties.IsTextEditable = function(prop)
		local typeData = prop.ValueType
		local typeName = typeData.Name

		return typeName ~= "bool" and typeData.Category ~= "Enum" and typeData.Category ~= "Class" and typeName ~= "BrickColor"
	end

	Properties.DisplayEnumDropdown = function(entryIndex)
		local context = Properties.EnumContext
		if not context then
			context = Lib.ContextMenu.new()
			context.Iconless = true
			context.MaxHeight = 200
			context.ReverseYOffset = 22
			Properties.EnumContext = context
		end

		if not inputProp or inputProp.ValueType.Category ~= "Enum" then return end
		local prop = inputProp

		local entry = propEntries[entryIndex]
		local valueFrame = entry.GuiElems.ValueFrame

		local enum = Enum[prop.ValueType.Name]
		if not enum then return end

		local sorted = {}
		for name, enum in next, enum:GetEnumItems() do
			sorted[#sorted + 1] = enum
		end
		table.sort(sorted, function(a, b) return a.Name < b.Name end)

		context:Clear()

		local function onClick(name)
			if prop ~= inputProp then return end

			local enumItem = enum[name]
			inputProp = nil
			Properties.SetProp(prop, enumItem)
		end

		for i = 1, #sorted do
			local enumItem = sorted[i]
			context:Add({ Name = enumItem.Name, OnClick = onClick })
		end

		context.Width = valueFrame.AbsoluteSize.X
		context:Show(valueFrame.AbsolutePosition.X, valueFrame.AbsolutePosition.Y + 22)
	end

	Properties.DisplayBrickColorEditor = function(prop, entryIndex, col)
		local editor = Properties.BrickColorEditor
		if not editor then
			editor = Lib.BrickColorPicker.new()
			editor.Gui.DisplayOrder = Main.DisplayOrders.Menu
			editor.ReverseYOffset = 22

			editor.OnSelect:Connect(function(col)
				if not editor.CurrentProp or editor.CurrentProp.ValueType.Name ~= "BrickColor" then return end

				if editor.CurrentProp == inputProp then inputProp = nil end
				Properties.SetProp(editor.CurrentProp, BrickColor.new(col))
			end)

			editor.OnMoreColors:Connect(function() -- TODO: Special Case BasePart.BrickColor to BasePart.Color
				editor:Close()
				local colProp
				for i, v in pairs(API.Classes.BasePart.Properties) do
					if v.Name == "Color" then
						colProp = v
						break
					end
				end
				Properties.DisplayColorEditor(colProp, editor.SavedColor.Color)
			end)

			Properties.BrickColorEditor = editor
		end

		local entry = propEntries[entryIndex]
		local valueFrame = entry.GuiElems.ValueFrame

		editor.CurrentProp = prop
		editor.SavedColor = col
		if prop and prop.Class == "BasePart" and prop.Name == "BrickColor" then
			editor:SetMoreColorsVisible(true)
		else
			editor:SetMoreColorsVisible(false)
		end
		editor:Show(valueFrame.AbsolutePosition.X, valueFrame.AbsolutePosition.Y + 22)
	end

	Properties.DisplayColorEditor = function(prop, col)
		local editor = Properties.ColorEditor
		if not editor then
			editor = Lib.ColorPicker.new()

			editor.OnSelect:Connect(function(col)
				if not editor.CurrentProp then return end
				local typeName = editor.CurrentProp.ValueType.Name
				if typeName ~= "Color3" and typeName ~= "BrickColor" then return end

				local colVal = (typeName == "Color3" and col or BrickColor.new(col))

				if editor.CurrentProp == inputProp then inputProp = nil end
				Properties.SetProp(editor.CurrentProp, colVal)
			end)

			Properties.ColorEditor = editor
		end

		editor.CurrentProp = prop
		if col then
			editor:SetColor(col)
		else
			local firstVal = Properties.GetFirstPropVal(prop)
			if firstVal then editor:SetColor(firstVal) end
		end
		editor:Show()
	end

	Properties.DisplayNumberSequenceEditor = function(prop, seq)
		local editor = Properties.NumberSequenceEditor
		if not editor then
			editor = Lib.NumberSequenceEditor.new()

			editor.OnSelect:Connect(function(val)
				if not editor.CurrentProp or editor.CurrentProp.ValueType.Name ~= "NumberSequence" then return end

				if editor.CurrentProp == inputProp then inputProp = nil end
				Properties.SetProp(editor.CurrentProp, val)
			end)

			Properties.NumberSequenceEditor = editor
		end

		editor.CurrentProp = prop
		if seq then
			editor:SetSequence(seq)
		else
			local firstVal = Properties.GetFirstPropVal(prop)
			if firstVal then editor:SetSequence(firstVal) end
		end
		editor:Show()
	end

	Properties.DisplayColorSequenceEditor = function(prop, seq)
		local editor = Properties.ColorSequenceEditor
		if not editor then
			editor = Lib.ColorSequenceEditor.new()

			editor.OnSelect:Connect(function(val)
				if not editor.CurrentProp or editor.CurrentProp.ValueType.Name ~= "ColorSequence" then return end

				if editor.CurrentProp == inputProp then inputProp = nil end
				Properties.SetProp(editor.CurrentProp, val)
			end)

			Properties.ColorSequenceEditor = editor
		end

		editor.CurrentProp = prop
		if seq then
			editor:SetSequence(seq)
		else
			local firstVal = Properties.GetFirstPropVal(prop)
			if firstVal then editor:SetSequence(firstVal) end
		end
		editor:Show()
	end

	Properties.GetFirstPropVal = function(prop)
		local first = Properties.FindFirstObjWhichIsA(prop.Class)
		if first then return Properties.GetPropVal(prop, first) end
	end

	Properties.GetPropVal = function(prop, obj)
		if prop.MultiType then return "<Multiple Types>" end
		if not obj then return end

		local propVal
		if prop.IsAttribute then
			propVal = getAttribute(obj, prop.AttributeName)
			if propVal == nil then return nil end

			local typ = typeof(propVal)
			local currentType = Properties.TypeNameConvert[typ] or typ
			if prop.RootType then
				if prop.RootType.Name ~= currentType then return nil end
			elseif prop.ValueType.Name ~= currentType then
				return nil
			end
		elseif prop.IsTag then
			if not CollectionService:HasTag(obj, prop.AttributeName) then return nil end
			propVal = prop.AttributeName
		else
			propVal = obj[prop.Name]
		end
		if prop.SubName then
			local indexes = string.split(prop.SubName, ".")
			for i = 1, #indexes do
				local indexName = indexes[i]
				if #indexName > 0 and propVal then propVal = propVal[indexName] end
			end
		end

		return propVal
	end

	Properties.SelectObject = function(obj)
		if inputProp and inputProp.ValueType.Category == "Class" then
			local prop = inputProp
			inputProp = nil

			if isa(obj, prop.ValueType.Name) then
				Properties.SetProp(prop, obj)
			else
				Properties.Refresh()
			end

			return true
		end

		return false
	end

	Properties.DisplayProp = function(prop, entryIndex)
		local propName = prop.Name
		local typeData = prop.ValueType
		local typeName = typeData.Name
		local tags = prop.Tags
		local gName = prop.Class .. "." .. prop.Name .. (prop.SubName or "")
		local propObj = autoUpdateObjs[gName]
		local entryData = propEntries[entryIndex]
		local UDim2 = UDim2

		local guiElems = entryData.GuiElems
		local valueFrame = guiElems.ValueFrame
		local valueBox = guiElems.ValueBox
		local colorButton = guiElems.ColorButton
		local colorPreview = guiElems.ColorPreview
		local gradient = guiElems.Gradient
		local enumArrow = guiElems.EnumArrow
		local checkbox = guiElems.Checkbox
		local rightButton = guiElems.RightButton
		local soundPreview = guiElems.SoundPreview

		local propVal = Properties.GetPropVal(prop, propObj)
		local inputFullName = inputProp and (inputProp.Class .. "." .. inputProp.Name .. (inputProp.SubName or ""))

		local offset = 4
		local endOffset = 6

		-- Offsetting the ValueBox for ValueType specific buttons
		if typeName == "Color3" or typeName == "BrickColor" or typeName == "ColorSequence" then
			colorButton.Visible = true
			enumArrow.Visible = false
			if propVal then
				gradient.Color = (typeName == "Color3" and ColorSequence.new(propVal)) or (typeName == "BrickColor" and ColorSequence.new(propVal.Color)) or propVal
			else
				gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
			end
			colorPreview.BorderColor3 = (typeName == "ColorSequence" and Color3.new(1, 1, 1) or Color3.new(0, 0, 0))
			offset = 22
			endOffset = 24 + (typeName == "ColorSequence" and 20 or 0)
		elseif typeData.Category == "Enum" then
			colorButton.Visible = false
			enumArrow.Visible = not prop.Tags.ReadOnly
			endOffset = 22
		elseif (gName == inputFullName and typeData.Category == "Class") or typeName == "NumberSequence" then
			colorButton.Visible = false
			enumArrow.Visible = false
			endOffset = 26
		else
			colorButton.Visible = false
			enumArrow.Visible = false
		end

		valueBox.Position = UDim2.new(0, offset, 0, 0)
		valueBox.Size = UDim2.new(1, -endOffset, 1, 0)

		-- Right button
		if inputFullName == gName and typeData.Category == "Class" then
			Main.MiscIcons:DisplayByKey(guiElems.RightButtonIcon, "Delete")
			guiElems.RightButtonIcon.Visible = true
			rightButton.Text = ""
			rightButton.Visible = true
		elseif typeName == "NumberSequence" or typeName == "ColorSequence" then
			guiElems.RightButtonIcon.Visible = false
			rightButton.Text = "..."
			rightButton.Visible = true
		else
			rightButton.Visible = false
		end

		-- Displays the correct ValueBox for the ValueType, and sets it to the prop value
		if typeName == "bool" or typeName == "PhysicalProperties" then
			valueBox.Visible = false
			checkbox.Visible = true
			soundPreview.Visible = false
			checkboxes[entryIndex].Disabled = tags.ReadOnly
			if typeName == "PhysicalProperties" and autoUpdateObjs[gName] then
				checkboxes[entryIndex]:SetState(propVal and true or false)
			else
				checkboxes[entryIndex]:SetState(propVal)
			end
		elseif typeName == "SoundPlayer" then
			valueBox.Visible = false
			checkbox.Visible = false
			soundPreview.Visible = true
			local playing = Properties.PreviewSound and Properties.PreviewSound.Playing
			Main.MiscIcons:DisplayByKey(soundPreview.ControlButton.Icon, playing and "Pause" or "Play")
		else
			valueBox.Visible = true
			checkbox.Visible = false
			soundPreview.Visible = false

			if propVal ~= nil then
				if typeName == "Color3" then
					valueBox.Text = "[" .. Lib.ColorToBytes(propVal) .. "]"
				elseif typeData.Category == "Enum" then
					valueBox.Text = propVal.Name
				elseif Properties.RoundableTypes[typeName] and Settings.Properties.NumberRounding then
					local rawStr = Properties.ValueToString(prop, propVal)
					valueBox.Text = rawStr:gsub("-?%d+%.%d+", function(num) return tostring(tonumber(("%." .. Settings.Properties.NumberRounding .. "f"):format(num))) end)
				else
					valueBox.Text = Properties.ValueToString(prop, propVal)
				end
			else
				valueBox.Text = ""
			end

			valueBox.TextColor3 = tags.ReadOnly and Settings.Theme.PlaceholderText or Settings.Theme.Text
		end
	end

	Properties.Refresh = function()
		local maxEntries = math.max(math.ceil(propsFrame.AbsoluteSize.Y / 23), 0)
		local maxX = propsFrame.AbsoluteSize.X
		local valueWidth = math.max(Properties.MinInputWidth, maxX - Properties.ViewWidth)
		local inputPropVisible = false
		local isa = game.IsA
		local UDim2 = UDim2
		local stringSplit = string.split
		local scaleType = Settings.Properties.ScaleType

		-- Clear connections
		for i = 1, #propCons do
			propCons[i]:Disconnect()
		end
		table.clear(propCons)

		-- Hide full name viewer
		Properties.FullNameFrame.Visible = false
		Properties.FullNameFrameAttach.Disable()

		for i = 1, maxEntries do
			local entryData = propEntries[i]
			if not propEntries[i] then
				entryData = Properties.NewPropEntry(i)
				propEntries[i] = entryData
			end

			local entry = entryData.Gui
			local guiElems = entryData.GuiElems
			local nameFrame = guiElems.NameFrame
			local propNameLabel = guiElems.PropName
			local valueFrame = guiElems.ValueFrame
			local expand = guiElems.Expand
			local valueBox = guiElems.ValueBox
			local propNameBox = guiElems.PropName
			local rightButton = guiElems.RightButton
			local editAttributeButton = guiElems.EditAttributeButton
			local toggleAttributes = guiElems.ToggleAttributes
			-- local toggleTags = guiElems.ToggleTags

			local prop = viewList[i + Properties.Index]
			if prop then
				local entryXOffset = (scaleType == 0 and scrollH.Index or 0)
				entry.Visible = true
				entry.Position = UDim2.new(0, -entryXOffset, 0, entry.Position.Y.Offset)
				entry.Size = UDim2.new(scaleType == 0 and 0 or 1, scaleType == 0 and Properties.ViewWidth + valueWidth or 0, 0, 22)

				if prop.SpecialRow then
					if prop.SpecialRow == "AddAttribute" then
						nameFrame.Visible = false
						valueFrame.Visible = false
						guiElems.RowButton.Visible = true
					end
				else
					-- Revert special row stuff
					nameFrame.Visible = true
					guiElems.RowButton.Visible = false

					local depth = Properties.EntryIndent * (prop.Depth or 1)
					local leftOffset = depth + Properties.EntryOffset
					nameFrame.Position = UDim2.new(0, leftOffset, 0, 0)
					propNameLabel.Size = UDim2.new(1, -2 - (scaleType == 0 and 0 or 6), 1, 0)

					local gName = (prop.CategoryName and "CAT_" .. prop.CategoryName) or prop.Class .. "." .. prop.Name .. (prop.SubName or "")

					if prop.CategoryName then
						entry.BackgroundColor3 = Settings.Theme.Main1
						valueFrame.Visible = false

						propNameBox.Text = prop.CategoryName
						propNameBox.Font = Enum.Font.SourceSansBold
						expand.Visible = true
						propNameBox.TextColor3 = Settings.Theme.Text
						nameFrame.BackgroundTransparency = 1
						nameFrame.Size = UDim2.new(1, 0, 1, 0)
						editAttributeButton.Visible = false

						local showingAttrs = Settings.Properties.ShowAttributes
						toggleAttributes.Position = UDim2.new(1, -85 - leftOffset, 0, 0)
						toggleAttributes.Text = (showingAttrs and "[Setting: ON]" or "[Setting: OFF]")
						toggleAttributes.TextColor3 = Settings.Theme.Text
						toggleAttributes.Visible = (prop.CategoryName == "Attributes")

						-- local showingTags = Settings.Properties.ShowTags
						-- local showingTagsText = (showingTags and "[Setting: ON]" or "[Setting: OFF]")
						-- toggleTags.Position = UDim2.new(1, -85 - leftOffset, 0, entry.Position.Y.Offset)
						-- toggleTags.Text = showingTagsText
						-- toggleTags.TextColor3 = Settings.Theme.Text
						-- toggleTags.Visible = (prop.CategoryName == "Tags")
					else
						local propName = prop.Name
						local typeData = prop.ValueType
						local typeName = typeData.Name
						local tags = prop.Tags
						local propObj = autoUpdateObjs[gName]

						local attributeOffset = (prop.IsAttribute and 20 or 0)
						editAttributeButton.Visible = (prop.IsAttribute and not prop.RootType)
						toggleAttributes.Visible = false
						-- toggleTags.Visible = false

						-- Moving around the frames
						if scaleType == 0 then
							nameFrame.Size = UDim2.new(0, Properties.ViewWidth - leftOffset - 1, 1, 0)
							valueFrame.Position = UDim2.new(0, Properties.ViewWidth, 0, 0)
							valueFrame.Size = UDim2.new(0, valueWidth - attributeOffset, 1, 0)
						else
							nameFrame.Size = UDim2.new(0.5, -leftOffset - 1, 1, 0)
							valueFrame.Position = UDim2.new(0.5, 0, 0, 0)
							valueFrame.Size = UDim2.new(0.5, -attributeOffset, 1, 0)
						end

						local nameArr = stringSplit(gName, ".")
						propNameBox.Text = prop.DisplayName or nameArr[#nameArr]
						propNameBox.Font = Enum.Font.SourceSans
						entry.BackgroundColor3 = Settings.Theme.Main2
						valueFrame.Visible = true

						expand.Visible = typeData.Category == "DataType" and Properties.ExpandableTypes[typeName] or Properties.ExpandableProps[gName]
						propNameBox.TextColor3 = tags.ReadOnly and Settings.Theme.PlaceholderText or Settings.Theme.Text

						-- Display property value
						Properties.DisplayProp(prop, i)
						if propObj then
							if prop.IsAttribute then
								propCons[#propCons + 1] = getAttributeChangedSignal(propObj, prop.AttributeName):Connect(function() Properties.DisplayProp(prop, i) end)
							elseif prop.IsTag then
								propCons[#propCons + 1] = CollectionService:GetInstanceAddedSignal(prop.AttributeName):Connect(function() Properties.DisplayProp(prop, i) end)
								propCons[#propCons + 1] = CollectionService:GetInstanceRemovedSignal(prop.AttributeName):Connect(function() Properties.DisplayProp(prop, i) end)
							else
								propCons[#propCons + 1] = getPropChangedSignal(propObj, propName):Connect(function() Properties.DisplayProp(prop, i) end)
							end
						end

						-- Position and resize Input Box
						local beforeVisible = valueBox.Visible
						local inputFullName = inputProp and (inputProp.Class .. "." .. inputProp.Name .. (inputProp.SubName or ""))
						if gName == inputFullName then
							nameFrame.BackgroundColor3 = Settings.Theme.ListSelection
							nameFrame.BackgroundTransparency = 0
							if typeData.Category == "Class" or typeData.Category == "Enum" or typeName == "BrickColor" then
								valueFrame.BackgroundColor3 = Settings.Theme.TextBox
								valueFrame.BackgroundTransparency = 0
								valueBox.Visible = true
							else
								inputPropVisible = true
								local scale = (scaleType == 0 and 0 or 0.5)
								local offset = (scaleType == 0 and Properties.ViewWidth - scrollH.Index or 0)
								local endOffset = 0

								if typeName == "Color3" or typeName == "ColorSequence" then offset = offset + 22 end

								if typeName == "NumberSequence" or typeName == "ColorSequence" then endOffset = 20 end

								inputBox.Position = UDim2.new(scale, offset, 0, entry.Position.Y.Offset)
								inputBox.Size = UDim2.new(1 - scale, -offset - endOffset - attributeOffset, 0, 22)
								inputBox.Visible = true
								valueBox.Visible = false
							end
						else
							nameFrame.BackgroundColor3 = Settings.Theme.Main1
							nameFrame.BackgroundTransparency = 1
							valueFrame.BackgroundColor3 = Settings.Theme.Main1
							valueFrame.BackgroundTransparency = 1
							valueBox.Visible = beforeVisible
						end
					end

					-- Expand
					if prop.CategoryName or Properties.ExpandableTypes[prop.ValueType and prop.ValueType.Name] or Properties.ExpandableProps[gName] then
						if Lib.CheckMouseInGui(expand) then
							Main.MiscIcons:DisplayByKey(expand.Icon, expanded[gName] and "Collapse_Over" or "Expand_Over")
						else
							Main.MiscIcons:DisplayByKey(expand.Icon, expanded[gName] and "Collapse" or "Expand")
						end
						expand.Visible = true
					else
						expand.Visible = false
					end
				end
				entry.Visible = true
			else
				entry.Visible = false
			end
		end

		if not inputPropVisible then inputBox.Visible = false end

		for i = maxEntries + 1, #propEntries do
			propEntries[i].Gui:Destroy()
			propEntries[i] = nil
			checkboxes[i] = nil
		end
	end

	Properties.SetProp = function(prop, val, noupdate, prevAttribute)
		local sList = Explorer.Selection.List
		local propName = prop.Name
		local subName = prop.SubName
		local propClass = prop.Class
		local typeData = prop.ValueType
		local typeName = typeData.Name
		local attributeName = prop.AttributeName
		local rootTypeData = prop.RootType
		local rootTypeName = rootTypeData and rootTypeData.Name
		local fullName = prop.Class .. "." .. prop.Name .. (prop.SubName or "")
		local Vector3 = Vector3

		for i = 1, #sList do
			local node = sList[i]
			local obj = node.Obj

			if isa(obj, propClass) then
				pcall(function()
					local setVal = val
					local root
					if prop.IsAttribute then
						root = getAttribute(obj, attributeName)
					elseif prop.IsTag then
						root = CollectionService:HasTag(obj, attributeName) and attributeName or nil
					else
						root = obj[propName]
					end

					if prevAttribute then
						if prevAttribute.ValueType.Name == typeName then setVal = getAttribute(obj, prevAttribute.AttributeName) or setVal end
						setAttribute(obj, prevAttribute.AttributeName, nil)
					end

					if rootTypeName then
						if rootTypeName == "Vector2" then
							setVal = Vector2.new((subName == ".X" and setVal) or root.X, (subName == ".Y" and setVal) or root.Y)
						elseif rootTypeName == "Vector3" then
							setVal = Vector3.new((subName == ".X" and setVal) or root.X, (subName == ".Y" and setVal) or root.Y, (subName == ".Z" and setVal) or root.Z)
						elseif rootTypeName == "UDim" then
							setVal = UDim.new((subName == ".Scale" and setVal) or root.Scale, (subName == ".Offset" and setVal) or root.Offset)
						elseif rootTypeName == "UDim2" then
							local rootX, rootY = root.X, root.Y
							local X_UDim = (subName == ".X" and setVal) or UDim.new((subName == ".X.Scale" and setVal) or rootX.Scale, (subName == ".X.Offset" and setVal) or rootX.Offset)
							local Y_UDim = (subName == ".Y" and setVal) or UDim.new((subName == ".Y.Scale" and setVal) or rootY.Scale, (subName == ".Y.Offset" and setVal) or rootY.Offset)
							setVal = UDim2.new(X_UDim, Y_UDim)
						elseif rootTypeName == "CFrame" then
							local rootPos, rootRight, rootUp, rootLook = root.Position, root.RightVector, root.UpVector, root.LookVector
							local pos = (subName == ".Position" and setVal) or Vector3.new((subName == ".Position.X" and setVal) or rootPos.X, (subName == ".Position.Y" and setVal) or rootPos.Y, (subName == ".Position.Z" and setVal) or rootPos.Z)
							local rightV = (subName == ".RightVector" and setVal) or Vector3.new((subName == ".RightVector.X" and setVal) or rootRight.X, (subName == ".RightVector.Y" and setVal) or rootRight.Y, (subName == ".RightVector.Z" and setVal) or rootRight.Z)
							local upV = (subName == ".UpVector" and setVal) or Vector3.new((subName == ".UpVector.X" and setVal) or rootUp.X, (subName == ".UpVector.Y" and setVal) or rootUp.Y, (subName == ".UpVector.Z" and setVal) or rootUp.Z)
							local lookV = (subName == ".LookVector" and setVal) or Vector3.new((subName == ".LookVector.X" and setVal) or rootLook.X, (subName == ".LookVector.Y" and setVal) or rootLook.Y, (subName == ".LookVector.Z" and setVal) or rootLook.Z)
							-- fromMatrix derives the back vector from Right x Up, so a LookVector edit rebuilds the rotation
							if string.sub(subName, 1, 11) == ".LookVector" then
								setVal = CFrame.lookAt(pos, pos + lookV, rootUp)
							else
								setVal = CFrame.fromMatrix(pos, rightV, upV)
							end
						elseif rootTypeName == "Rect" then
							local rootMin, rootMax = root.Min, root.Max
							local min = Vector2.new((subName == ".Min.X" and setVal) or rootMin.X, (subName == ".Min.Y" and setVal) or rootMin.Y)
							local max = Vector2.new((subName == ".Max.X" and setVal) or rootMax.X, (subName == ".Max.Y" and setVal) or rootMax.Y)
							setVal = Rect.new(min, max)
						elseif rootTypeName == "PhysicalProperties" then
							local rootProps = PhysicalProperties.new(obj.Material)
							local density = (subName == ".Density" and setVal) or (root and root.Density) or rootProps.Density
							local friction = (subName == ".Friction" and setVal) or (root and root.Friction) or rootProps.Friction
							local elasticity = (subName == ".Elasticity" and setVal) or (root and root.Elasticity) or rootProps.Elasticity
							local frictionWeight = (subName == ".FrictionWeight" and setVal) or (root and root.FrictionWeight) or rootProps.FrictionWeight
							local elasticityWeight = (subName == ".ElasticityWeight" and setVal) or (root and root.ElasticityWeight) or rootProps.ElasticityWeight
							setVal = PhysicalProperties.new(density, friction, elasticity, frictionWeight, elasticityWeight)
						elseif rootTypeName == "Ray" then
							local rootOrigin, rootDirection = root.Origin, root.Direction
							local origin = (subName == ".Origin" and setVal) or Vector3.new((subName == ".Origin.X" and setVal) or rootOrigin.X, (subName == ".Origin.Y" and setVal) or rootOrigin.Y, (subName == ".Origin.Z" and setVal) or rootOrigin.Z)
							local direction = (subName == ".Direction" and setVal) or Vector3.new((subName == ".Direction.X" and setVal) or rootDirection.X, (subName == ".Direction.Y" and setVal) or rootDirection.Y, (subName == ".Direction.Z" and setVal) or rootDirection.Z)
							setVal = Ray.new(origin, direction)
						elseif rootTypeName == "Faces" then
							local faces = {}
							local faceList = { "Back", "Bottom", "Front", "Left", "Right", "Top" }
							for _, face in pairs(faceList) do
								local val
								if subName == "." .. face then
									val = setVal
								else
									val = root[face]
								end
								if val then faces[#faces + 1] = Enum.NormalId[face] end
							end
							setVal = Faces.new(unpack(faces))
						elseif rootTypeName == "Axes" then
							local axes = {}
							local axesList = { "X", "Y", "Z" }
							for _, axe in pairs(axesList) do
								local val
								if subName == "." .. axe then
									val = setVal
								else
									val = root[axe]
								end
								if val then axes[#axes + 1] = Enum.Axis[axe] end
							end
							setVal = Axes.new(unpack(axes))
						elseif rootTypeName == "NumberRange" then
							setVal = NumberRange.new(subName == ".Min" and setVal or root.Min, subName == ".Max" and setVal or root.Max)
						end
					end

					if typeName == "PhysicalProperties" and setVal then setVal = root or PhysicalProperties.new(obj.Material) end

					if prop.IsAttribute then
						setAttribute(obj, attributeName, setVal)
					else
						obj[propName] = setVal
					end
				end)
			end
		end

		if not noupdate then Properties.ComputeConflicts(prop) end
	end

	Properties.InitInputBox = function()
		inputBox = create({
			{ 1, "Frame", { BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204), BorderSizePixel = 0, Name = "InputBox", Size = UDim2.new(0, 200, 0, 22), Visible = false, ZIndex = 2 } },
			{
				2,
				"TextBox",
				{
					BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.new(0.062745101749897, 0.51764708757401, 1),
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					Font = 3,
					Parent = { 1 },
					PlaceholderColor3 = Color3.new(0.69803923368454, 0.69803923368454, 0.69803923368454),
					Position = UDim2.new(0, 3, 0, 0),
					Size = UDim2.new(1, -6, 1, 0),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextXAlignment = 0,
					ZIndex = 2,
				},
			},
		})
		inputTextBox = inputBox.TextBox
		inputBox.BackgroundColor3 = Settings.Theme.TextBox
		inputBox.Parent = Properties.Window.GuiElems.Content.List

		inputTextBox.FocusLost:Connect(function()
			if not inputProp then return end

			local prop = inputProp
			inputProp = nil
			local val = Properties.StringToValue(prop, inputTextBox.Text)
			if val then
				Properties.SetProp(prop, val)
			else
				Properties.Refresh()
			end
		end)

		inputTextBox.Focused:Connect(function()
			inputTextBox.SelectionStart = 1
			inputTextBox.CursorPosition = #inputTextBox.Text + 1
		end)

		Lib.ViewportTextBox.convert(inputTextBox)
	end

	Properties.SetInputProp = function(prop, entryIndex, special)
		local typeData = prop.ValueType
		local typeName = typeData.Name
		local fullName = prop.Class .. "." .. prop.Name .. (prop.SubName or "")
		local propObj = autoUpdateObjs[fullName]
		local propVal = Properties.GetPropVal(prop, propObj)

		if prop.Tags.ReadOnly then return end

		inputProp = prop
		if special then
			if special == "color" then
				if typeName == "Color3" then
					inputTextBox.Text = propVal and Properties.ValueToString(prop, propVal) or ""
					Properties.DisplayColorEditor(prop, propVal)
				elseif typeName == "BrickColor" then
					Properties.DisplayBrickColorEditor(prop, entryIndex, propVal)
				elseif typeName == "ColorSequence" then
					inputTextBox.Text = propVal and Properties.ValueToString(prop, propVal) or ""
					Properties.DisplayColorSequenceEditor(prop, propVal)
				end
			elseif special == "right" then
				if typeName == "NumberSequence" then
					inputTextBox.Text = propVal and Properties.ValueToString(prop, propVal) or ""
					Properties.DisplayNumberSequenceEditor(prop, propVal)
				elseif typeName == "ColorSequence" then
					inputTextBox.Text = propVal and Properties.ValueToString(prop, propVal) or ""
					Properties.DisplayColorSequenceEditor(prop, propVal)
				end
			end
		else
			if Properties.IsTextEditable(prop) then
				inputTextBox.Text = propVal and Properties.ValueToString(prop, propVal) or ""
				inputTextBox:CaptureFocus()
			elseif typeData.Category == "Enum" then
				Properties.DisplayEnumDropdown(entryIndex)
			elseif typeName == "BrickColor" then
				Properties.DisplayBrickColorEditor(prop, entryIndex, propVal)
			end
		end
		Properties.Refresh()
	end

	Properties.InitSearch = function()
		local searchBox = Properties.GuiElems.ToolBar.SearchFrame.SearchBox

		Lib.ViewportTextBox.convert(searchBox)

		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			Properties.SearchText = searchBox.Text
			Properties.Update()
			Properties.Refresh()
		end)
	end

	Properties.InitEntryStuff = function()
		Properties.EntryTemplate = create({
			{
				1,
				"TextButton",
				{
					AutoButtonColor = false,
					BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799),
					BorderColor3 = Color3.new(0.1294117718935, 0.1294117718935, 0.1294117718935),
					Font = 3,
					Name = "Entry",
					Position = UDim2.new(0, 1, 0, 1),
					Size = UDim2.new(0, 250, 0, 22),
					Text = "",
					TextSize = 14,
				},
			},
			{
				2,
				"Frame",
				{
					BackgroundColor3 = Color3.new(0.04313725605607, 0.35294118523598, 0.68627452850342),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.new(0.33725491166115, 0.49019610881805, 0.73725491762161),
					BorderSizePixel = 0,
					Name = "NameFrame",
					Parent = { 1 },
					Position = UDim2.new(0, 20, 0, 0),
					Size = UDim2.new(1, -40, 1, 0),
				},
			},
			{
				3,
				"TextLabel",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Font = 3,
					Name = "PropName",
					Parent = { 2 },
					Position = UDim2.new(0, 2, 0, 0),
					Size = UDim2.new(1, -2, 1, 0),
					Text = "Anchored",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextTransparency = 0.10000000149012,
					TextTruncate = 1,
					TextXAlignment = 0,
				},
			},
			{ 4, "TextButton", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Font = 3, Name = "Expand", Parent = { 2 }, Position = UDim2.new(0, -20, 0, 1), Size = UDim2.new(0, 20, 0, 20), Text = "", TextSize = 14, Visible = false } },
			{
				5,
				"ImageLabel",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Image = "rbxassetid://5642383285",
					ImageRectOffset = Vector2.new(144, 16),
					ImageRectSize = Vector2.new(16, 16),
					Name = "Icon",
					Parent = { 4 },
					Position = UDim2.new(0, 2, 0, 2),
					ScaleType = 4,
					Size = UDim2.new(0, 16, 0, 16),
				},
			},
			{
				6,
				"TextButton",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = 4,
					Name = "ToggleAttributes",
					Parent = { 2 },
					Position = UDim2.new(1, -85, 0, 0),
					Size = UDim2.new(0, 85, 0, 22),
					Text = "[SETTING: OFF]",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextTransparency = 0.10000000149012,
					Visible = false,
				},
			},
			-- {
			-- 	7,
			-- 	"TextButton",
			-- 	{
			-- 		BackgroundColor3 = Color3.new(1, 1, 1),
			-- 		BackgroundTransparency = 1,
			-- 		BorderSizePixel = 0,
			-- 		Font = 4,
			-- 		Name = "ToggleTags",
			-- 		Parent = { 2 },
			-- 		Position = UDim2.new(1, -85, 0, 0),
			-- 		Size = UDim2.new(0, 85, 0, 22),
			-- 		Text = "[SETTING: OFF]",
			-- 		TextColor3 = Color3.new(1, 1, 1),
			-- 		TextSize = 14,
			-- 		TextTransparency = 0.10000000149012,
			-- 		Visible = false,
			-- 	},
			-- },
			{
				8,
				"Frame",
				{
					BackgroundColor3 = Color3.new(0.04313725605607, 0.35294118523598, 0.68627452850342),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.new(0.33725491166115, 0.49019607901573, 0.73725491762161),
					BorderSizePixel = 0,
					Name = "ValueFrame",
					Parent = { 1 },
					Position = UDim2.new(1, -100, 0, 0),
					Size = UDim2.new(0, 80, 1, 0),
				},
			},
			{
				9,
				"Frame",
				{
					BackgroundColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462),
					BorderColor3 = Color3.new(0.33725491166115, 0.49019610881805, 0.73725491762161),
					BorderSizePixel = 0,
					Name = "Line",
					Parent = { 7 },
					Position = UDim2.new(0, -1, 0, 0),
					Size = UDim2.new(0, 1, 1, 0),
				},
			},
			{ 10, "TextButton", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "ColorButton", Parent = { 8 }, Size = UDim2.new(0, 20, 0, 22), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Visible = false } },
			{ 11, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderColor3 = Color3.new(0, 0, 0), Name = "ColorPreview", Parent = { 10 }, Position = UDim2.new(0, 5, 0, 6), Size = UDim2.new(0, 10, 0, 10) } },
			{ 12, "UIGradient", { Parent = { 11 } } },
			{ 13, "Frame", { BackgroundTransparency = 1, Name = "EnumArrow", Parent = { 8 }, Position = UDim2.new(1, -16, 0, 3), Size = UDim2.new(0, 16, 0, 16), Visible = false } },
			{ 14, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 13 }, Position = UDim2.new(0, 8, 0, 9), Size = UDim2.new(0, 1, 0, 1) } },
			{ 15, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 13 }, Position = UDim2.new(0, 7, 0, 8), Size = UDim2.new(0, 3, 0, 1) } },
			{ 16, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 13 }, Position = UDim2.new(0, 6, 0, 7), Size = UDim2.new(0, 5, 0, 1) } },
			{
				17,
				"TextButton",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Font = 3,
					Name = "ValueBox",
					Parent = { 8 },
					Position = UDim2.new(0, 4, 0, 0),
					Size = UDim2.new(1, -8, 1, 0),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextTransparency = 0.10000000149012,
					TextTruncate = 1,
					TextXAlignment = 0,
				},
			},
			{
				18,
				"TextButton",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = 3,
					Name = "RightButton",
					Parent = { 8 },
					Position = UDim2.new(1, -20, 0, 0),
					Size = UDim2.new(0, 20, 0, 22),
					Text = "...",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					Visible = false,
				},
			},
			{
				19,
				"TextButton",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = 3,
					Name = "SettingsButton",
					Parent = { 8 },
					Position = UDim2.new(1, -20, 0, 0),
					Size = UDim2.new(0, 20, 0, 22),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					Visible = false,
				},
			},
			{ 20, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Name = "SoundPreview", Parent = { 8 }, Size = UDim2.new(1, 0, 1, 0), Visible = false } },
			{ 21, "TextButton", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "ControlButton", Parent = { 20 }, Size = UDim2.new(0, 20, 0, 22), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14 } },
			{
				22,
				"ImageLabel",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Image = "rbxassetid://5642383285",
					ImageRectOffset = Vector2.new(144, 16),
					ImageRectSize = Vector2.new(16, 16),
					Name = "Icon",
					Parent = { 21 },
					Position = UDim2.new(0, 2, 0, 3),
					ScaleType = 4,
					Size = UDim2.new(0, 16, 0, 16),
				},
			},
			{ 23, "Frame", { BackgroundColor3 = Color3.new(0.3137255012989, 0.3137255012989, 0.3137255012989), BorderSizePixel = 0, Name = "TimeLine", Parent = { 20 }, Position = UDim2.new(0, 26, 0.5, -1), Size = UDim2.new(1, -34, 0, 2) } },
			{
				24,
				"Frame",
				{ BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236), BorderColor3 = Color3.new(0.1294117718935, 0.1294117718935, 0.1294117718935), Name = "Slider", Parent = { 23 }, Position = UDim2.new(0, -4, 0, -8), Size = UDim2.new(0, 8, 0, 18) },
			},
			{
				25,
				"TextButton",
				{ BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "EditAttributeButton", Parent = { 1 }, Position = UDim2.new(1, -20, 0, 0), Size = UDim2.new(0, 20, 0, 22), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14 },
			},
			{ 26, "ImageLabel", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Image = "rbxassetid://5034718180", ImageTransparency = 0.20000000298023, Name = "Icon", Parent = { 25 }, Position = UDim2.new(0, 2, 0, 3), Size = UDim2.new(0, 16, 0, 16) } },
			{
				27,
				"TextButton",
				{
					AutoButtonColor = false,
					BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
					BorderSizePixel = 0,
					Font = 3,
					Name = "RowButton",
					Parent = { 1 },
					Size = UDim2.new(1, 0, 1, 0),
					Text = "Add Attribute",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextTransparency = 0.10000000149012,
					Visible = false,
				},
			},
		})

		local fullNameFrame = Lib.Frame.new()
		local label = Lib.Label.new()
		label.Parent = fullNameFrame.Gui
		label.Position = UDim2.new(0, 2, 0, 0)
		label.Size = UDim2.new(1, -4, 1, 0)
		fullNameFrame.Visible = false
		fullNameFrame.Parent = window.Gui

		Properties.FullNameFrame = fullNameFrame
		Properties.FullNameFrameAttach = Lib.AttachTo(fullNameFrame)
	end

	Properties.Init = function() -- TODO: MAKE BETTER
		local guiItems = create({
			{ 1, "Folder", { Name = "Items" } },
			{ 2, "Frame", { BackgroundColor3 = Color3.new(0.20392157137394, 0.20392157137394, 0.20392157137394), BorderSizePixel = 0, Name = "ToolBar", Parent = { 1 }, Size = UDim2.new(1, 0, 0, 22) } },
			{
				3,
				"Frame",
				{
					BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
					BorderColor3 = Color3.new(0.1176470592618, 0.1176470592618, 0.1176470592618),
					BorderSizePixel = 0,
					Name = "SearchFrame",
					Parent = { 2 },
					Position = UDim2.new(0, 3, 0, 1),
					Size = UDim2.new(1, -6, 0, 18),
				},
			},
			{
				4,
				"TextBox",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					Font = 3,
					Name = "SearchBox",
					Parent = { 3 },
					PlaceholderColor3 = Color3.new(0.39215689897537, 0.39215689897537, 0.39215689897537),
					PlaceholderText = "Search properties",
					Position = UDim2.new(0, 4, 0, 0),
					Size = UDim2.new(1, -24, 0, 18),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextXAlignment = 0,
				},
			},
			{ 5, "UICorner", { CornerRadius = UDim.new(0, 2), Parent = { 3 } } },
			{
				6,
				"TextButton",
				{
					AutoButtonColor = false,
					BackgroundColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = 3,
					Name = "Reset",
					Parent = { 3 },
					Position = UDim2.new(1, -17, 0, 1),
					Size = UDim2.new(0, 16, 0, 16),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
				},
			},
			{ 7, "ImageLabel", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Image = "rbxassetid://5034718129", ImageColor3 = Color3.new(0.39215686917305, 0.39215686917305, 0.39215686917305), Parent = { 6 }, Size = UDim2.new(0, 16, 0, 16) } },
			{
				8,
				"TextButton",
				{
					AutoButtonColor = false,
					BackgroundColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = 3,
					Name = "Refresh",
					Parent = { 2 },
					Position = UDim2.new(1, -20, 0, 1),
					Size = UDim2.new(0, 18, 0, 18),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					Visible = false,
				},
			},
			{ 9, "ImageLabel", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Image = "rbxassetid://5642310344", Parent = { 8 }, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0, 12, 0, 12) } },
			{ 10, "Frame", { BackgroundColor3 = Color3.new(0.15686275064945, 0.15686275064945, 0.15686275064945), BorderSizePixel = 0, Name = "ScrollCorner", Parent = { 1 }, Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 16, 0, 16), Visible = false } },
			{ 11, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Name = "List", Parent = { 1 }, Position = UDim2.new(0, 0, 0, 23), Size = UDim2.new(1, 0, 1, -23) } },
		})

		-- Vars
		categoryOrder = API.CategoryOrder
		for category, _ in next, categoryOrder do
			if not Properties.CollapsedCategories[category] then expanded["CAT_" .. category] = true end
		end
		expanded["Sound.SoundId"] = true

		-- Init window
		window = Lib.Window.new()
		Properties.Window = window
		window:SetTitle("Properties")

		toolBar = guiItems.ToolBar
		propsFrame = guiItems.List

		Properties.GuiElems.ToolBar = toolBar
		Properties.GuiElems.PropsFrame = propsFrame

		Properties.InitEntryStuff()

		-- Window events
		window.GuiElems.Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if Properties.Window:IsContentVisible() then
				Properties.UpdateView()
				Properties.Refresh()
			end
		end)
		window.OnActivate:Connect(function()
			Properties.UpdateView()
			Properties.Update()
			Properties.Refresh()
		end)
		window.OnRestore:Connect(function()
			Properties.UpdateView()
			Properties.Update()
			Properties.Refresh()
		end)

		-- Init scrollbars
		scrollV = Lib.ScrollBar.new()
		scrollV.WheelIncrement = 3
		scrollV.Gui.Position = UDim2.new(1, -16, 0, 23)
		scrollV:SetScrollFrame(propsFrame)
		scrollV.Scrolled:Connect(function()
			Properties.Index = scrollV.Index
			Properties.Refresh()
		end)

		scrollH = Lib.ScrollBar.new(true)
		scrollH.Increment = 5
		scrollH.WheelIncrement = 20
		scrollH.Gui.Position = UDim2.new(0, 0, 1, -16)
		scrollH.Scrolled:Connect(function() Properties.Refresh() end)

		-- Setup Gui
		window.GuiElems.Line.Position = UDim2.new(0, 0, 0, 22)
		toolBar.Parent = window.GuiElems.Content
		propsFrame.Parent = window.GuiElems.Content
		guiItems.ScrollCorner.Parent = window.GuiElems.Content
		scrollV.Gui.Parent = window.GuiElems.Content
		scrollH.Gui.Parent = window.GuiElems.Content
		Properties.InitInputBox()
		Properties.InitSearch()
	end

	return Properties
end

return { InitAfterMain = initAfterMain, Main = main }
end function __DARKDEX_MODULES.s()local v=__DARKDEX_MODULES.cache.s if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.s=v end return v.c end end do local function __modImpl()--[[
	ScriptViewer App Module

	Shows decompiled scripts with copy, save and function dump tools.
]]


local Context = __DARKDEX_MODULES.a()

local Lib = Context.Lib
local env = Context.env

local BUTTON_HEIGHT = 20

-- Function Dumper originally made by King.Kevin
local function dumpFunctions(scr)	
local getgc = getgc or get_gc_objects
	local getupvalues = (debug and debug.getupvalues) or getupvalues or getupvals
	local getconstants = (debug and debug.getconstants) or getconstants or getconsts
	local islclosure = islclosure or is_l_closure
	if not (getgc and getupvalues and getconstants) then return "-- Function dump needs getgc, getupvalues and getconstants" end

	local scriptPath = scr:GetFullName()
	local nameSuffix = "." .. scr.Name
	local output = { `\n-- // Function Dumper made by King.Kevin\n-- // Script Path: {scriptPath}\n\n--[[` }
	local seenTables = {}
	local dumpedAny = false

	local function add(text, indent) table.insert(output, string.rep("    ", math.max(0, indent)) .. text) end

	local function functionName(func)		
local name = debug.info(func, "n")
		return (name and name ~= "") and name or "Unknown Name"
	end

	local dumpValue

	local function dumpTable(value, indent, key)
		add(`{tostring(key)} [{typeof(value)}] {tostring(value)}`, indent - 1)
		local count = 0
		for _, item in value do
			count += 1
			dumpValue(count, item, indent)
		end
	end

	function dumpValue(key, value, indent)
		if type(value) == "function" then
			add(`{key} [function] = {functionName(value)}`, indent)
		elseif type(value) == "table" then
			if seenTables[value] then
				add(`{key} [table] (Recursive table detected)`, indent)
			else
				seenTables[value] = true
				add(`{key} [table]:`, indent)
				dumpTable(value, indent + 1, key)
			end
		else
			add(`{key} [{typeof(value)}] = {tostring(value)}`, indent)
		end
	end

	local function belongsToScript(func)		
if islclosure and not islclosure(func) then return false end
		-- Cheap source check first: getfenv on every gc function would deoptimize the game scripts.
		-- The chunk name is the path at load time, so a moved script still matches by name.
		local source = debug.info(func, "s")
		if source ~= scriptPath and string.sub(source, -#nameSuffix) ~= nameSuffix then return false end
		local success, fenv = pcall(getfenv, func)
		return success and rawget(fenv, "script") == scr
	end

	for _, func in getgc() do
		if type(func) == "function" and belongsToScript(func) then
			dumpedAny = true
			local name = functionName(func)
			add(`\nFunction Dump: {name}`, 0)
			add(`\nFunction Upvalues: {name}`, 0)
			for index, upvalue in getupvalues(func) do
				dumpValue(index, upvalue, 1)
			end
			add(`\nFunction Constants: {name}`, 0)
			for index, constant in getconstants(func) do
				dumpValue(index, constant, 1)
			end
			add("\n" .. string.rep("=", 100), 0)
		end
	end

	if not dumpedAny then return nil end
	table.insert(output, "]]")
	return table.concat(output, "\n")
end

local function createButton(parent, text, index, count)	
local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Position = UDim2.new((index - 1) / count, 0, 0, 0)
	button.Size = UDim2.new(1 / count, 0, 0, BUTTON_HEIGHT)
	button.Font = Enum.Font.SourceSans
	button.TextSize = 14
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = parent
	return button
end

local function sanitizeFileName(name)return (string.gsub(name, "[^%w%-_ ]", "_")) end

local function initAfterMain() end

local function main()
	local ScriptViewer = {}
	local window, codeFrame
	local currentScript
	
function ScriptViewer.ViewScript(scr)
		local source
		if not env.decompile then
			source = "-- DarkDex: this executor has no decompile function"
		else
			local success, result = pcall(env.decompile, scr)
			if success and type(result) == "string" then
				source = result
			else
				source = `-- DarkDex: failed to decompile {scr:GetFullName()}\n-- {tostring(result)}`
			end
		end

		currentScript = scr

		window:SetTitle(`Script Viewer - {scr.Name}`)
		-- Null bytes break the TextLabel rendering
		codeFrame:SetText((string.gsub(source, "\0", "\\0")))
		window:Show()
	end

	-- Shows generated text, such as tool results, instead of a script
	function ScriptViewer.ShowText(title, text)
		currentScript = nil
		window:SetTitle(`Script Viewer - {title}`)
		codeFrame:SetText(text)
		window:Show()
	end

	function ScriptViewer.Init()
		window = Lib.Window.new()
		window:SetTitle("Script Viewer")
		window:Resize(500, 400)
		ScriptViewer.Window = window

		local content = window.GuiElems.Content

		codeFrame = Lib.CodeFrame.new()
		codeFrame.Frame.Position = UDim2.new(0, 0, 0, BUTTON_HEIGHT)
		codeFrame.Frame.Size = UDim2.new(1, 0, 1, -BUTTON_HEIGHT)
		codeFrame.Frame.Parent = content

		local copyButton = createButton(content, "Copy to Clipboard", 1, 3)
		local saveButton = createButton(content, "Save to File", 2, 3)
		local dumpButton = createButton(content, "Dump Functions", 3, 3)

		copyButton.MouseButton1Click:Connect(function()
			if env.setclipboard then env.setclipboard(codeFrame:GetText()) end
		end)

		saveButton.MouseButton1Click:Connect(function()
			if not env.writefile then return end

			local name = currentScript and sanitizeFileName(currentScript.Name) or "Script"
			local fileName = `dex/saved/Place_{game.PlaceId}_{name}_{os.time()}.lua`
			local success, err = pcall(env.writefile, fileName, codeFrame:GetText())
			if not success then warn(`[DarkDex] Failed to save {fileName}: {err}`) end
		end)

		dumpButton.MouseButton1Click:Connect(function()
			if not currentScript then return end

			local success, dump = pcall(dumpFunctions, currentScript)
			if not success then
				warn(`[DarkDex] Function dump failed: {dump}`)
				return
			end
			if dump then codeFrame:SetText(codeFrame:GetText() .. dump) end
		end)
	end

	return ScriptViewer
end

return { InitAfterMain = initAfterMain, Main = main }
end function __DARKDEX_MODULES.t()local v=__DARKDEX_MODULES.cache.t if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.t=v end return v.c end end do local function __modImpl()



















local function disconnect(connection)
	if not connection.Connected then return end
	connection.Connected = false

	local connections = connection.Signal.Connections
	local index = table.find(connections, connection)
	if index then table.remove(connections, index) end
end

local methods = {}

function methods.Connect(self, func)	
assert(type(func) == "function", "Attempt to connect a non-function")

	local connection= {
		Signal = self,
		Func = func,
		Connected = true,
		Disconnect = disconnect,
	}
	table.insert(self.Connections, connection)
	return connection
end

function methods.Fire(self, ...)
	-- Handlers may disconnect while firing, so iterate over a snapshot
	for _, connection in table.clone(self.Connections) do
		if connection.Connected then task.spawn(connection.Func, ...) end
	end
end

function methods.DisconnectAll(self)
	for _, connection in self.Connections do
		connection.Connected = false
	end
	table.clear(self.Connections)
end

local metatable = {
	__index = methods,
	__tostring = function(self) return `Signal: {#self.Connections} Connections` end,
}

local function new()return (setmetatable({ Connections = {} }, metatable) )end

return { new = new }
end function __DARKDEX_MODULES.u()local v=__DARKDEX_MODULES.cache.u if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.u=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()

local Lib = Context.Lib

local funcs = {}

funcs.Add = function(self, obj)
	if self.Map[obj] then return end

	local list = self.List
	list[#list + 1] = obj
	self.Map[obj] = true
	self.Changed:Fire()
end

funcs.AddTable = function(self, t)
	local changed
	local list, map = self.List, self.Map
	for i = 1, #t do
		local elem = t[i]
		if not map[elem] then
			list[#list + 1] = elem
			map[elem] = true
			changed = true
		end
	end
	if changed then self.Changed:Fire() end
end

funcs.Remove = function(self, obj)
	if not self.Map[obj] then return end

	local list = self.List
	local pos = table.find(list, obj)
	if pos then table.remove(list, pos) end
	self.Map[obj] = nil
	self.Changed:Fire()
end

funcs.RemoveTable = function(self, t)
	local changed
	local list, map = self.List, self.Map
	local removeSet = {}
	for i = 1, #t do
		local elem = t[i]
		map[elem] = nil
		removeSet[elem] = true
	end

	for i = #list, 1, -1 do
		local elem = list[i]
		if removeSet[elem] then
			table.remove(list, i)
			changed = true
		end
	end
	if changed then self.Changed:Fire() end
end

funcs.Set = function(self, obj)
	if #self.List == 1 and self.List[1] == obj then return end

	self.List = { obj }
	self.Map = { [obj] = true }
	self.Changed:Fire()
end

funcs.SetTable = function(self, t)
	local newList, newMap = {}, {}
	self.List, self.Map = newList, newMap
	table.move(t, 1, #t, 1, newList)
	for i = 1, #t do
		newMap[t[i] ] = true
	end
	self.Changed:Fire()
end

funcs.Clear = function(self)
	if #self.List == 0 then return end
	self.List = {}
	self.Map = {}
	self.Changed:Fire()
end

local mt = { __index = funcs }

local function new()
	local obj = setmetatable({
		List = {},
		Map = {},
		Changed = Lib.Signal.new(),
	}, mt)

	return obj
end

return { new = new }
end function __DARKDEX_MODULES.v()local v=__DARKDEX_MODULES.cache.v if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.v=v end return v.c end end do local function __modImpl()
local funcs = {}

funcs.GetLabel = function(self)
	local label = Instance.new("ImageLabel")
	self:SetupLabel(label)
	return label
end

funcs.SetupLabel = function(self, obj)
	obj.BackgroundTransparency = 1
	obj.ImageRectOffset = Vector2.new(0, 0)
	obj.ImageRectSize = Vector2.new(self.IconSizeX, self.IconSizeY)
	obj.ScaleType = Enum.ScaleType.Crop
	obj.Size = UDim2.new(0, self.IconSizeX, 0, self.IconSizeY)
end

funcs.Display = function(self, obj, index)
	obj.Image = self.MapId
	if not self.NumX then
		obj.ImageRectOffset = Vector2.new(self.IconSizeX * index, 0)
	else
		obj.ImageRectOffset = Vector2.new(self.IconSizeX * (index % self.NumX), self.IconSizeY * math.floor(index / self.NumX))
	end
end

funcs.DisplayByKey = function(self, obj, key)
	if self.IndexDict[key] then self:Display(obj, self.IndexDict[key]) end
end

funcs.SetDict = function(self, dict) self.IndexDict = dict end

local mt = {}
mt.__index = funcs

local function new(mapId, mapSizeX, mapSizeY, iconSizeX, iconSizeY)
	local obj = setmetatable({
		MapId = mapId,
		MapSizeX = mapSizeX,
		MapSizeY = mapSizeY,
		IconSizeX = iconSizeX,
		IconSizeY = iconSizeY,
		NumX = mapSizeX / iconSizeX,
		IndexDict = {},
	}, mt)
	return obj
end

local function newLinear(mapId, iconSizeX, iconSizeY)
	local obj = setmetatable({
		MapId = mapId,
		IconSizeX = iconSizeX,
		IconSizeY = iconSizeY,
		IndexDict = {},
	}, mt)
	return obj
end

return { new = new, newLinear = newLinear }
end function __DARKDEX_MODULES.w()local v=__DARKDEX_MODULES.cache.w if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.w=v end return v.c end end do local function __modImpl()--[[
	Scroll bar measured in items: Index is the first visible item, VisibleSpace the
	number of visible items and TotalSpace the item count. Scrolled fires on changes.
]]


local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

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
















local methods = {}

local function isMouseButton1(input)return input.UserInputType == Enum.UserInputType.MouseButton1 end

-- Calls onRelease once when the left mouse button is released
local function onMouseRelease(onRelease)
	local connection
	connection = UserInputService.InputEnded:Connect(function(input)
		if not isMouseButton1(input) then return end
		connection:Disconnect()
		onRelease()
	end)
	return connection
end

local function drawThumb(self)
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

local function createArrowButton(parent, name, position, direction)	
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
local function bindArrowButton(self, button, canScroll, scroll)
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

local function bindThumb(self, thumb, thumbFrame)
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

local function createFrame(self)	
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

local function setLinesTransparency(lines, transparency)
	for _, line in lines do
		line.BackgroundTransparency = transparency
	end
end

function methods.Update(self)
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

function methods.ScrollTo(self, index, noCallback)
	self.Index = index
	self:Update()
	if not noCallback then self.Scrolled:Fire() end
end

function methods.ScrollUp(self)
	self.Index -= self.Increment
	self:Update()
end

function methods.ScrollDown(self)
	self.Index += self.Increment
	self:Update()
end

function methods.CanScrollUp(self)return self.Index > 0 end

function methods.CanScrollDown(self)return self.Index + self.VisibleSpace < self.TotalSpace end

function methods.GetScrollPercent(self)	
local scrollable = self.TotalSpace - self.VisibleSpace
	return scrollable > 0 and self.Index / scrollable or 0
end

function methods.SetScrollPercent(self, percent)
	self.Index = math.floor(percent * (self.TotalSpace - self.VisibleSpace))
	self:Update()
end

function methods.Texture(self, data)
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
function methods.SetScrollFrame(self, frame)
	if self.ScrollUpEvent then self.ScrollUpEvent:Disconnect() end
	if self.ScrollDownEvent then self.ScrollDownEvent:Disconnect() end

	self.ScrollUpEvent = frame.MouseWheelForward:Connect(function() self:ScrollTo(self.Index - self.WheelIncrement) end)
	self.ScrollDownEvent = frame.MouseWheelBackward:Connect(function() self:ScrollTo(self.Index + self.WheelIncrement) end)
end

local metatable = { __index = methods }

local function new(isHorizontal)	
local self = (setmetatable({
		Index = 0,
		VisibleSpace = 0,
		TotalSpace = 0,
		Increment = 1,
		WheelIncrement = 1,
		GuiElems = {},
		Horizontal = isHorizontal == true,
		Scrolled = Lib.Signal.new(),
	}, metatable) )
	
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
end function __DARKDEX_MODULES.x()local v=__DARKDEX_MODULES.cache.x if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.x=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Main = Context.Main
local Lib = Context.Lib
local service = Context.service
local plr = Context.plr
local create = Create.create

local funcs = {}
local static = { MinWidth = 200, FreeWidth = 200 }
local mouse = plr:GetMouse()
local sidesGui, alignIndicator
local visibleWindows = {}
local leftSide = { Width = 300, Windows = {}, ResizeCons = {}, Hidden = true }
local rightSide = { Width = 300, Windows = {}, ResizeCons = {}, Hidden = true }

local displayOrderStart
local sideDisplayOrder
local sideTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweens = {}
local isA = game.IsA

local theme = {
	MainColor1 = Color3.fromRGB(52, 52, 52),
	MainColor2 = Color3.fromRGB(45, 45, 45),
	Button = Color3.fromRGB(60, 60, 60),
}

local function stopTweens()
	for i = 1, #tweens do
		tweens[i]:Cancel()
	end
	tweens = {}
end

local function resizeHook(self, resizer, dir)
	local guiMain = self.GuiElems.Main
	resizer.InputBegan:Connect(function(input)
		if not self.Dragging and not self.Resizing and self.Resizable and self.ResizableInternal then
			local isH = dir:find("[WE]") and true
			local isV = dir:find("[NS]") and true
			local signX = dir:find("W", 1, true) and -1 or 1
			local signY = dir:find("N", 1, true) and -1 or 1

			if self.Minimized and isV then return end

			if input.UserInputType == Enum.UserInputType.MouseMovement then
				resizer.BackgroundTransparency = 0.5
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				local releaseEvent, mouseEvent

				local offX = mouse.X - resizer.AbsolutePosition.X
				local offY = mouse.Y - resizer.AbsolutePosition.Y

				self.Resizing = resizer
				resizer.BackgroundTransparency = 1

				releaseEvent = service.UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						releaseEvent:Disconnect()
						mouseEvent:Disconnect()
						self.Resizing = false
						resizer.BackgroundTransparency = 1
					end
				end)

				mouseEvent = service.UserInputService.InputChanged:Connect(function(input)
					if self.Resizable and self.ResizableInternal and input.UserInputType == Enum.UserInputType.MouseMovement then
						self:StopTweens()
						local deltaX = input.Position.X - resizer.AbsolutePosition.X - offX
						local deltaY = input.Position.Y - resizer.AbsolutePosition.Y - offY

						if guiMain.AbsoluteSize.X + deltaX * signX < self.MinX then deltaX = signX * (self.MinX - guiMain.AbsoluteSize.X) end
						if guiMain.AbsoluteSize.Y + deltaY * signY < self.MinY then deltaY = signY * (self.MinY - guiMain.AbsoluteSize.Y) end
						if signY < 0 and guiMain.AbsolutePosition.Y + deltaY < 0 then deltaY = -guiMain.AbsolutePosition.Y end

						guiMain.Position = guiMain.Position + UDim2.new(0, (signX < 0 and deltaX or 0), 0, (signY < 0 and deltaY or 0))
						self.SizeX = self.SizeX + (isH and deltaX * signX or 0)
						self.SizeY = self.SizeY + (isV and deltaY * signY or 0)
						guiMain.Size = UDim2.new(0, self.SizeX, 0, self.Minimized and 20 or self.SizeY)

						--if isH then self.SizeX = guiMain.AbsoluteSize.X end
						--if isV then self.SizeY = guiMain.AbsoluteSize.Y end
					end
				end)
			end
		end
	end)

	resizer.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.Resizing ~= resizer then resizer.BackgroundTransparency = 1 end
	end)
end

local updateWindows

local function moveToTop(window)
	local found = table.find(visibleWindows, window)
	if found then
		table.remove(visibleWindows, found)
		table.insert(visibleWindows, 1, window)
		updateWindows()
	end
end

local function sideHasRoom(side, neededSize)
	local maxY = sidesGui.AbsoluteSize.Y - (math.max(0, #side.Windows - 1) * 4)
	local inc = 0
	for i, v in pairs(side.Windows) do
		inc = inc + (v.MinY or 100)
		if inc > maxY - neededSize then return false end
	end

	return true
end

local function getSideInsertPos(side, curY)
	local pos = #side.Windows + 1
	local range = { 0, sidesGui.AbsoluteSize.Y }

	for i, v in pairs(side.Windows) do
		local midPos = v.PosY + v.SizeY / 2
		if curY <= midPos then
			pos = i
			range[2] = midPos
			break
		else
			range[1] = midPos
		end
	end

	return pos, range
end

local function focusInput(self, obj)
	if isA(obj, "GuiButton") then
		obj.MouseButton1Down:Connect(function() moveToTop(self) end)
	elseif isA(obj, "TextBox") then
		obj.Focused:Connect(function() moveToTop(self) end)
	end
end

local createGui = function(self)
	local gui = create({
		{ 1, "ScreenGui", { Name = "Window" } },
		{ 2, "Frame", { Active = true, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Main", Parent = { 1 }, Position = UDim2.new(0.40000000596046, 0, 0.40000000596046, 0), Size = UDim2.new(0, 300, 0, 300) } },
		{ 3, "Frame", { BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799), BorderSizePixel = 0, Name = "Content", Parent = { 2 }, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 1, -20), ClipsDescendants = true } },
		{ 4, "Frame", { BackgroundColor3 = Color3.fromRGB(33, 33, 33), BorderSizePixel = 0, Name = "Line", Parent = { 3 }, Size = UDim2.new(1, 0, 0, 1) } },
		{ 5, "Frame", { BackgroundColor3 = Color3.new(0.20392157137394, 0.20392157137394, 0.20392157137394), BorderSizePixel = 0, Name = "TopBar", Parent = { 2 }, Size = UDim2.new(1, 0, 0, 20) } },
		{
			6,
			"TextLabel",
			{ BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Font = 3, Name = "Title", Parent = { 5 }, Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -10, 0, 20), Text = "Window", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = 0 },
		},
		{
			7,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "Close",
				Parent = { 5 },
				Position = UDim2.new(1, -18, 0, 2),
				Size = UDim2.new(0, 16, 0, 16),
				Text = "",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
			},
		},
		{ 8, "ImageLabel", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Image = "rbxassetid://5054663650", Parent = { 7 }, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0, 10, 0, 10) } },
		{ 9, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 7 } } },
		{
			10,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "Minimize",
				Parent = { 5 },
				Position = UDim2.new(1, -36, 0, 2),
				Size = UDim2.new(0, 16, 0, 16),
				Text = "",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
			},
		},
		{ 11, "ImageLabel", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Image = "rbxassetid://5034768003", Parent = { 10 }, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0, 10, 0, 10) } },
		{ 12, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 10 } } },
		{
			13,
			"ImageLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = "rbxassetid://1427967925",
				Name = "Outlines",
				Parent = { 2 },
				Position = UDim2.new(0, -5, 0, -5),
				ScaleType = 1,
				Size = UDim2.new(1, 10, 1, 10),
				SliceCenter = Rect.new(6, 6, 25, 25),
				TileSize = UDim2.new(0, 20, 0, 20),
			},
		},
		{ 14, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Name = "ResizeControls", Parent = { 2 }, Position = UDim2.new(0, -5, 0, -5), Size = UDim2.new(1, 10, 1, 10) } },
		{
			15,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.27450981736183, 0.27450981736183, 0.27450981736183),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "North",
				Parent = { 14 },
				Position = UDim2.new(0, 5, 0, 0),
				Size = UDim2.new(1, -10, 0, 5),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{
			16,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.27450981736183, 0.27450981736183, 0.27450981736183),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "South",
				Parent = { 14 },
				Position = UDim2.new(0, 5, 1, -5),
				Size = UDim2.new(1, -10, 0, 5),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{
			17,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.27450981736183, 0.27450981736183, 0.27450981736183),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "NorthEast",
				Parent = { 14 },
				Position = UDim2.new(1, -5, 0, 0),
				Size = UDim2.new(0, 5, 0, 5),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{
			18,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.27450981736183, 0.27450981736183, 0.27450981736183),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "East",
				Parent = { 14 },
				Position = UDim2.new(1, -5, 0, 5),
				Size = UDim2.new(0, 5, 1, -10),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{
			19,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.27450981736183, 0.27450981736183, 0.27450981736183),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "West",
				Parent = { 14 },
				Position = UDim2.new(0, 0, 0, 5),
				Size = UDim2.new(0, 5, 1, -10),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{
			20,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.27450981736183, 0.27450981736183, 0.27450981736183),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "SouthEast",
				Parent = { 14 },
				Position = UDim2.new(1, -5, 1, -5),
				Size = UDim2.new(0, 5, 0, 5),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{
			21,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.27450981736183, 0.27450981736183, 0.27450981736183),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "NorthWest",
				Parent = { 14 },
				Size = UDim2.new(0, 5, 0, 5),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{
			22,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.27450981736183, 0.27450981736183, 0.27450981736183),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "SouthWest",
				Parent = { 14 },
				Position = UDim2.new(0, 0, 1, -5),
				Size = UDim2.new(0, 5, 0, 5),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
	})

	local guiMain = gui.Main
	local guiTopBar = guiMain.TopBar
	local guiResizeControls = guiMain.ResizeControls

	self.GuiElems.Main = guiMain
	self.GuiElems.TopBar = guiMain.TopBar
	self.GuiElems.Content = guiMain.Content
	self.GuiElems.Line = guiMain.Content.Line
	self.GuiElems.Outlines = guiMain.Outlines
	self.GuiElems.Title = guiTopBar.Title
	self.GuiElems.Close = guiTopBar.Close
	self.GuiElems.Minimize = guiTopBar.Minimize
	self.GuiElems.ResizeControls = guiResizeControls
	self.ContentPane = guiMain.Content

	guiTopBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.Draggable then
			local releaseEvent, mouseEvent

			local maxX = sidesGui.AbsoluteSize.X
			local initX = guiMain.AbsolutePosition.X
			local initY = guiMain.AbsolutePosition.Y
			local offX = mouse.X - initX
			local offY = mouse.Y - initY

			local alignInsertPos, alignInsertSide

			self.Dragging = true

			releaseEvent = service.UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					releaseEvent:Disconnect()
					mouseEvent:Disconnect()
					self.Dragging = false
					alignIndicator.Parent = nil
					if alignInsertSide then
						local targetSide = (alignInsertSide == "left" and leftSide) or (alignInsertSide == "right" and rightSide)
						self:AlignTo(targetSide, alignInsertPos)
					end
				end
			end)

			mouseEvent = service.UserInputService.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement and self.Draggable and not self.Closed then
					if self.Aligned then
						if leftSide.Resizing or rightSide.Resizing then return end
						local posX, posY = input.Position.X - offX, input.Position.Y - offY
						local delta = math.sqrt((posX - initX) ^ 2 + (posY - initY) ^ 2)
						if delta >= 5 then self:SetAligned(false) end
					else
						local inputX, inputY = input.Position.X, input.Position.Y
						local posX, posY = inputX - offX, inputY - offY
						if posY < 0 then posY = 0 end
						guiMain.Position = UDim2.new(0, posX, 0, posY)

						if self.Resizable and self.Alignable then
							if inputX < 25 then
								if sideHasRoom(leftSide, self.MinY or 100) then
									local insertPos, range = getSideInsertPos(leftSide, inputY)
									alignIndicator.Indicator.Position = UDim2.new(0, -15, 0, range[1])
									alignIndicator.Indicator.Size = UDim2.new(0, 40, 0, range[2] - range[1])
									Lib.ShowGui(alignIndicator)
									alignInsertPos = insertPos
									alignInsertSide = "left"
									return
								end
							elseif inputX >= maxX - 25 then
								if sideHasRoom(rightSide, self.MinY or 100) then
									local insertPos, range = getSideInsertPos(rightSide, inputY)
									alignIndicator.Indicator.Position = UDim2.new(0, maxX - 25, 0, range[1])
									alignIndicator.Indicator.Size = UDim2.new(0, 40, 0, range[2] - range[1])
									Lib.ShowGui(alignIndicator)
									alignInsertPos = insertPos
									alignInsertSide = "right"
									return
								end
							end
						end
						alignIndicator.Parent = nil
						alignInsertPos = nil
						alignInsertSide = nil
					end
				end
			end)
		end
	end)

	guiTopBar.Close.MouseButton1Click:Connect(function()
		if self.Closed then return end
		self:Close()
	end)

	guiTopBar.Minimize.MouseButton1Click:Connect(function()
		if self.Closed then return end
		if self.Aligned then
			self:SetAligned(false)
		else
			self:SetMinimized()
		end
	end)

	guiTopBar.Minimize.MouseButton2Click:Connect(function()
		if self.Closed then return end
		if not self.Aligned then
			self:SetMinimized(nil, 2)
			guiTopBar.Minimize.BackgroundTransparency = 1
		end
	end)

	guiMain.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not self.Aligned and not self.Closed then moveToTop(self) end
	end)

	guiMain:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		local absPos = guiMain.AbsolutePosition
		self.PosX = absPos.X
		self.PosY = absPos.Y
	end)

	resizeHook(self, guiResizeControls.North, "N")
	resizeHook(self, guiResizeControls.NorthEast, "NE")
	resizeHook(self, guiResizeControls.East, "E")
	resizeHook(self, guiResizeControls.SouthEast, "SE")
	resizeHook(self, guiResizeControls.South, "S")
	resizeHook(self, guiResizeControls.SouthWest, "SW")
	resizeHook(self, guiResizeControls.West, "W")
	resizeHook(self, guiResizeControls.NorthWest, "NW")

	guiMain.Size = UDim2.new(0, self.SizeX, 0, self.SizeY)

	gui.DescendantAdded:Connect(function(obj) focusInput(self, obj) end)
	local descs = gui:GetDescendants()
	for i = 1, #descs do
		focusInput(self, descs[i])
	end

	self.MinimizeAnim = Lib.ButtonAnim(guiTopBar.Minimize)
	self.CloseAnim = Lib.ButtonAnim(guiTopBar.Close)

	return gui
end

local function updateSideFrames(noTween)
	stopTweens()
	leftSide.Frame.Size = UDim2.new(0, leftSide.Width, 1, 0)
	rightSide.Frame.Size = UDim2.new(0, rightSide.Width, 1, 0)
	leftSide.Frame.Resizer.Position = UDim2.new(0, leftSide.Width, 0, 0)
	rightSide.Frame.Resizer.Position = UDim2.new(0, -5, 0, 0)

	--leftSide.Frame.Visible = (#leftSide.Windows > 0)
	--rightSide.Frame.Visible = (#rightSide.Windows > 0)

	--[[if #leftSide.Windows > 0 and leftSide.Frame.Position == UDim2.new(0,-leftSide.Width-5,0,0) then
				leftSide.Frame:TweenPosition(UDim2.new(0,0,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)
			elseif #leftSide.Windows == 0 and leftSide.Frame.Position == UDim2.new(0,0,0,0) then
				leftSide.Frame:TweenPosition(UDim2.new(0,-leftSide.Width-5,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)
			end
			local rightTweenPos = (#rightSide.Windows == 0 and UDim2.new(1,5,0,0) or UDim2.new(1,-rightSide.Width,0,0))
			rightSide.Frame:TweenPosition(rightTweenPos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)]]
	local leftHidden = #leftSide.Windows == 0 or leftSide.Hidden
	local rightHidden = #rightSide.Windows == 0 or rightSide.Hidden
	local leftPos = (leftHidden and UDim2.new(0, -leftSide.Width - 10, 0, 0) or UDim2.new(0, 0, 0, 0))
	local rightPos = (rightHidden and UDim2.new(1, 10, 0, 0) or UDim2.new(1, -rightSide.Width, 0, 0))

	sidesGui.LeftToggle.Text = leftHidden and ">" or "<"
	sidesGui.RightToggle.Text = rightHidden and "<" or ">"

	if not noTween then
		local function insertTween(...)
			local tween = service.TweenService:Create(...)
			tweens[#tweens + 1] = tween
			tween:Play()
		end
		insertTween(leftSide.Frame, sideTweenInfo, { Position = leftPos })
		insertTween(rightSide.Frame, sideTweenInfo, { Position = rightPos })
		insertTween(sidesGui.LeftToggle, sideTweenInfo, { Position = UDim2.new(0, #leftSide.Windows == 0 and -16 or 0, 0, -36) })
		insertTween(sidesGui.RightToggle, sideTweenInfo, { Position = UDim2.new(1, #rightSide.Windows == 0 and 0 or -16, 0, -36) })
	else
		leftSide.Frame.Position = leftPos
		rightSide.Frame.Position = rightPos
		sidesGui.LeftToggle.Position = UDim2.new(0, #leftSide.Windows == 0 and -16 or 0, 0, -36)
		sidesGui.RightToggle.Position = UDim2.new(1, #rightSide.Windows == 0 and 0 or -16, 0, -36)
	end
end

local function getSideFramePos(side)
	local leftHidden = #leftSide.Windows == 0 or leftSide.Hidden
	local rightHidden = #rightSide.Windows == 0 or rightSide.Hidden
	if side == leftSide then
		return (leftHidden and UDim2.new(0, -leftSide.Width - 10, 0, 0) or UDim2.new(0, 0, 0, 0))
	else
		return (rightHidden and UDim2.new(1, 10, 0, 0) or UDim2.new(1, -rightSide.Width, 0, 0))
	end
end

local function sideResized(side)
	local currentPos = 0
	local sideFramePos = getSideFramePos(side)
	for i, v in pairs(side.Windows) do
		v.SizeX = side.Width
		v.GuiElems.Main.Size = UDim2.new(0, side.Width, 0, v.SizeY)
		v.GuiElems.Main.Position = UDim2.new(sideFramePos.X.Scale, sideFramePos.X.Offset, 0, currentPos)
		currentPos = currentPos + v.SizeY + 4
	end
end

local function sideResizerHook(resizer, dir, side, pos)
	local mouse = Main.Mouse
	local windows = side.Windows

	resizer.InputBegan:Connect(function(input)
		if not side.Resizing then
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				resizer.BackgroundColor3 = theme.MainColor2
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				local releaseEvent, mouseEvent

				local offX = mouse.X - resizer.AbsolutePosition.X
				local offY = mouse.Y - resizer.AbsolutePosition.Y

				side.Resizing = resizer
				resizer.BackgroundColor3 = theme.MainColor2

				releaseEvent = service.UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						releaseEvent:Disconnect()
						mouseEvent:Disconnect()
						side.Resizing = false
						resizer.BackgroundColor3 = theme.Button
					end
				end)

				mouseEvent = service.UserInputService.InputChanged:Connect(function(input)
					if not resizer.Parent then
						releaseEvent:Disconnect()
						mouseEvent:Disconnect()
						side.Resizing = false
						return
					end
					if input.UserInputType == Enum.UserInputType.MouseMovement then
						if dir == "V" then
							local delta = input.Position.Y - resizer.AbsolutePosition.Y - offY

							if delta > 0 then
								local neededSize = delta
								for i = pos + 1, #windows do
									local window = windows[i]
									local newSize = math.max(window.SizeY - neededSize, (window.MinY or 100))
									neededSize = neededSize - (window.SizeY - newSize)
									window.SizeY = newSize
								end
								windows[pos].SizeY = windows[pos].SizeY + math.max(0, delta - neededSize)
							else
								local neededSize = -delta
								for i = pos, 1, -1 do
									local window = windows[i]
									local newSize = math.max(window.SizeY - neededSize, (window.MinY or 100))
									neededSize = neededSize - (window.SizeY - newSize)
									window.SizeY = newSize
								end
								windows[pos + 1].SizeY = windows[pos + 1].SizeY + math.max(0, -delta - neededSize)
							end

							updateSideFrames()
							sideResized(side)
						elseif dir == "H" then
							local maxWidth = math.max(300, sidesGui.AbsoluteSize.X - static.FreeWidth)
							local otherSide = (side == leftSide and rightSide or leftSide)
							local delta = input.Position.X - resizer.AbsolutePosition.X - offX
							delta = (side == leftSide and delta or -delta)

							local proposedSize = math.max(static.MinWidth, side.Width + delta)
							if proposedSize + otherSide.Width <= maxWidth then
								side.Width = proposedSize
							else
								local newOtherSize = maxWidth - proposedSize
								if newOtherSize >= static.MinWidth then
									side.Width = proposedSize
									otherSide.Width = newOtherSize
								else
									side.Width = maxWidth - static.MinWidth
									otherSide.Width = static.MinWidth
								end
							end

							updateSideFrames(true)
							sideResized(side)
							sideResized(otherSide)
						end
					end
				end)
			end
		end
	end)

	resizer.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and side.Resizing ~= resizer then resizer.BackgroundColor3 = theme.Button end
	end)
end

local function renderSide(side, noTween) -- TODO: Use existing resizers
	local currentPos = 0
	local sideFramePos = getSideFramePos(side)
	local template = side.WindowResizer:Clone()
	for i, v in pairs(side.ResizeCons) do
		v:Disconnect()
	end
	for i, v in pairs(side.Frame:GetChildren()) do
		if v.Name == "WindowResizer" then v:Destroy() end
	end
	side.ResizeCons = {}
	side.Resizing = nil

	for i, v in pairs(side.Windows) do
		v.SidePos = i
		local isEnd = i == #side.Windows
		local size = UDim2.new(0, side.Width, 0, v.SizeY)
		local pos = UDim2.new(sideFramePos.X.Scale, sideFramePos.X.Offset, 0, currentPos)
		Lib.ShowGui(v.Gui)
		--v.GuiElems.Main:TweenSizeAndPosition(size,pos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)
		if noTween then
			v.GuiElems.Main.Size = size
			v.GuiElems.Main.Position = pos
		else
			local tween = service.TweenService:Create(v.GuiElems.Main, sideTweenInfo, { Size = size, Position = pos })
			tweens[#tweens + 1] = tween
			tween:Play()
		end
		currentPos = currentPos + v.SizeY + 4

		if not isEnd then
			local newTemplate = template:Clone()
			newTemplate.Position = UDim2.new(1, -side.Width, 0, currentPos - 4)
			side.ResizeCons[#side.ResizeCons + 1] = v.Gui.Main:GetPropertyChangedSignal("Size"):Connect(function() newTemplate.Position = UDim2.new(1, -side.Width, 0, v.GuiElems.Main.Position.Y.Offset + v.GuiElems.Main.Size.Y.Offset) end)
			side.ResizeCons[#side.ResizeCons + 1] = v.Gui.Main:GetPropertyChangedSignal("Position"):Connect(function() newTemplate.Position = UDim2.new(1, -side.Width, 0, v.GuiElems.Main.Position.Y.Offset + v.GuiElems.Main.Size.Y.Offset) end)
			sideResizerHook(newTemplate, "V", side, i)
			newTemplate.Parent = side.Frame
		end
	end

	--side.Frame.Back.Position = UDim2.new(0,0,0,0)
	--side.Frame.Back.Size = UDim2.new(0,side.Width,1,0)
end

local function updateSide(side, noTween)
	local oldHeight = 0
	local currentPos = 0
	local neededSize = 0
	local windows = side.Windows
	local height = sidesGui.AbsoluteSize.Y - (math.max(0, #windows - 1) * 4)

	for i, v in pairs(windows) do
		oldHeight = oldHeight + v.SizeY
	end
	for i, v in pairs(windows) do
		if i == #windows then
			v.SizeY = height - currentPos
			neededSize = math.max(0, (v.MinY or 100) - v.SizeY)
		else
			v.SizeY = math.max(math.floor(v.SizeY / oldHeight * height), v.MinY or 100)
		end
		currentPos = currentPos + v.SizeY
	end

	if neededSize > 0 then
		for i = #windows - 1, 1, -1 do
			local window = windows[i]
			local newSize = math.max(window.SizeY - neededSize, (window.MinY or 100))
			neededSize = neededSize - (window.SizeY - newSize)
			window.SizeY = newSize
		end
		local lastWindow = windows[#windows]
		lastWindow.SizeY = (lastWindow.MinY or 100) - neededSize
	end
	renderSide(side, noTween)
end

updateWindows = function(noTween)
	updateSideFrames(noTween)
	updateSide(leftSide, noTween)
	updateSide(rightSide, noTween)
	local count = 0
	for i = #visibleWindows, 1, -1 do
		visibleWindows[i].Gui.DisplayOrder = displayOrderStart + count
		Lib.ShowGui(visibleWindows[i].Gui)
		count = count + 1
	end

	--[[local leftTweenPos = (#leftSide.Windows == 0 and UDim2.new(0,-leftSide.Width-5,0,0) or UDim2.new(0,0,0,0))
			leftSide.Frame:TweenPosition(leftTweenPos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)
			local rightTweenPos = (#rightSide.Windows == 0 and UDim2.new(1,5,0,0) or UDim2.new(1,-rightSide.Width,0,0))
			rightSide.Frame:TweenPosition(rightTweenPos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)]]
end

funcs.SetMinimized = function(self, set, mode)
	local oldVal = self.Minimized
	local newVal
	if set == nil then
		newVal = not self.Minimized
	else
		newVal = set
	end
	self.Minimized = newVal
	if not mode then mode = 1 end

	local resizeControls = self.GuiElems.ResizeControls
	local minimizeControls = { "North", "NorthEast", "NorthWest", "South", "SouthEast", "SouthWest" }
	for i = 1, #minimizeControls do
		local control = resizeControls:FindFirstChild(minimizeControls[i])
		if control then control.Visible = not newVal end
	end

	if mode == 1 or mode == 2 then
		self:StopTweens()
		if mode == 1 then
			self.GuiElems.Main:TweenSize(UDim2.new(0, self.SizeX, 0, newVal and 20 or self.SizeY), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
		else
			local maxY = sidesGui.AbsoluteSize.Y
			local newPos = UDim2.new(0, self.PosX, 0, newVal and math.min(maxY - 20, self.PosY + self.SizeY - 20) or math.max(0, self.PosY - self.SizeY + 20))

			self.GuiElems.Main:TweenPosition(newPos, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
			self.GuiElems.Main:TweenSize(UDim2.new(0, self.SizeX, 0, newVal and 20 or self.SizeY), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
		end
		self.GuiElems.Minimize.ImageLabel.Image = newVal and "rbxassetid://5060023708" or "rbxassetid://5034768003"
	end

	if oldVal ~= newVal then
		if newVal then
			self.OnMinimize:Fire()
		else
			self.OnRestore:Fire()
		end
	end
end

funcs.Resize = function(self, sizeX, sizeY)
	self.SizeX = sizeX or self.SizeX
	self.SizeY = sizeY or self.SizeY
	self.GuiElems.Main.Size = UDim2.new(0, self.SizeX, 0, self.SizeY)
end

funcs.SetSize = funcs.Resize

funcs.SetTitle = function(self, title) self.GuiElems.Title.Text = title end

funcs.SetResizable = function(self, val)
	self.Resizable = val
	self.GuiElems.ResizeControls.Visible = self.Resizable and self.ResizableInternal
end

funcs.SetResizableInternal = function(self, val)
	self.ResizableInternal = val
	self.GuiElems.ResizeControls.Visible = self.Resizable and self.ResizableInternal
end

funcs.SetAligned = function(self, val)
	self.Aligned = val
	self:SetResizableInternal(not val)
	self.GuiElems.Main.Active = not val
	self.GuiElems.Main.Outlines.Visible = not val
	if not val then
		for i, v in pairs(leftSide.Windows) do
			if v == self then
				table.remove(leftSide.Windows, i)
				break
			end
		end
		for i, v in pairs(rightSide.Windows) do
			if v == self then
				table.remove(rightSide.Windows, i)
				break
			end
		end
		if not table.find(visibleWindows, self) then table.insert(visibleWindows, 1, self) end
		self.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5034768003"
		self.Side = nil
		updateWindows()
	else
		self:SetMinimized(false, 3)
		for i, v in pairs(visibleWindows) do
			if v == self then
				table.remove(visibleWindows, i)
				break
			end
		end
		self.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5448127505"
	end
end

funcs.Add = function(self, obj, name)
	if type(obj) == "table" and obj.Gui and obj.Gui:IsA("GuiObject") then
		obj.Gui.Parent = self.ContentPane
	else
		obj.Parent = self.ContentPane
	end
	if name then self.Elements[name] = obj end
end

funcs.GetElement = function(self, obj, name) return self.Elements[name] end

funcs.AlignTo = function(self, side, pos, size, silent)
	if table.find(side.Windows, self) or self.Closed then return end

	size = size or self.SizeY
	if size > 0 and size <= 1 then
		local totalSideHeight = 0
		for i, v in pairs(side.Windows) do
			totalSideHeight = totalSideHeight + v.SizeY
		end
		self.SizeY = (totalSideHeight > 0 and totalSideHeight * size * 2) or size
	else
		self.SizeY = (size > 0 and size or 100)
	end

	self:SetAligned(true)
	self.Side = side
	self.SizeX = side.Width
	self.Gui.DisplayOrder = sideDisplayOrder + 1
	for i, v in pairs(side.Windows) do
		v.Gui.DisplayOrder = sideDisplayOrder
	end
	pos = math.min(#side.Windows + 1, pos or 1)
	self.SidePos = pos
	table.insert(side.Windows, pos, self)

	if not silent then side.Hidden = false end
	-- updateWindows(silent)
end

funcs.Close = function(self)
	self.Closed = true
	self:SetResizableInternal(false)

	Lib.FindAndRemove(leftSide.Windows, self)
	Lib.FindAndRemove(rightSide.Windows, self)
	Lib.FindAndRemove(visibleWindows, self)

	self.MinimizeAnim.Disable()
	self.CloseAnim.Disable()
	self.ClosedSide = self.Side
	self.Side = nil
	self.OnDeactivate:Fire()

	if not self.Aligned then
		self:StopTweens()
		local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local closeTime = os.clock()
		self.LastClose = closeTime

		self:DoTween(self.GuiElems.Main, ti, { Size = UDim2.new(0, self.SizeX, 0, 20) })
		self:DoTween(self.GuiElems.Title, ti, { TextTransparency = 1 })
		self:DoTween(self.GuiElems.Minimize.ImageLabel, ti, { ImageTransparency = 1 })
		self:DoTween(self.GuiElems.Close.ImageLabel, ti, { ImageTransparency = 1 })
		Lib.FastWait(0.2)
		if closeTime ~= self.LastClose then return end

		self:DoTween(self.GuiElems.TopBar, ti, { BackgroundTransparency = 1 })
		self:DoTween(self.GuiElems.Outlines, ti, { ImageTransparency = 1 })
		Lib.FastWait(0.2)
		if closeTime ~= self.LastClose then return end
	end

	self.Aligned = false
	self.Gui.Parent = nil
	updateWindows(true)
end

funcs.Hide = funcs.Close

funcs.IsVisible = function(self) return not self.Closed and ((self.Side and not self.Side.Hidden) or not self.Side) end

funcs.IsContentVisible = function(self) return self:IsVisible() and not self.Minimized end

funcs.Focus = function(self) moveToTop(self) end

funcs.MoveInBoundary = function(self)
	local posX, posY = self.PosX, self.PosY
	local maxX, maxY = sidesGui.AbsoluteSize.X, sidesGui.AbsoluteSize.Y
	posX = math.min(posX, maxX - self.SizeX)
	posY = math.min(posY, maxY - 20)
	self.GuiElems.Main.Position = UDim2.new(0, posX, 0, posY)
end

funcs.DoTween = function(self, ...)
	local tween = service.TweenService:Create(...)
	self.Tweens[#self.Tweens + 1] = tween
	tween:Play()
end

funcs.StopTweens = function(self)
	for i, v in pairs(self.Tweens) do
		v:Cancel()
	end
	self.Tweens = {}
end

funcs.Show = function(self, data) return static.ShowWindow(self, data) end

funcs.ShowAndFocus = function(self, data)
	static.ShowWindow(self, data)
	service.RunService.RenderStepped:Wait()
	self:Focus()
end

static.ShowWindow = function(window, data)
	data = data or {}
	local align = data.Align
	local pos = data.Pos
	local size = data.Size
	local targetSide = (align == "left" and leftSide) or (align == "right" and rightSide)

	if not window.Closed then
		if not window.Aligned then
			window:SetMinimized(false)
		elseif window.Side and not data.Silent then
			static.SetSideVisible(window.Side, true)
		end
		return
	end

	window.Closed = false
	window.LastClose = os.clock()
	window.GuiElems.Title.TextTransparency = 0
	window.GuiElems.Minimize.ImageLabel.ImageTransparency = 0
	window.GuiElems.Close.ImageLabel.ImageTransparency = 0
	window.GuiElems.TopBar.BackgroundTransparency = 0
	window.GuiElems.Outlines.ImageTransparency = 0
	window.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5034768003"
	window.GuiElems.Main.Active = true
	window.GuiElems.Main.Outlines.Visible = true
	window:SetMinimized(false, 3)
	window:SetResizableInternal(true)
	window.MinimizeAnim.Enable()
	window.CloseAnim.Enable()

	if align then
		window:AlignTo(targetSide, pos, size, data.Silent)
	else
		if align == nil and window.ClosedSide then -- Regular open
			window:AlignTo(window.ClosedSide, window.SidePos, size, true)
			static.SetSideVisible(window.ClosedSide, true)
		else
			if table.find(visibleWindows, window) then return end

			-- TODO: make better
			window.GuiElems.Main.Size = UDim2.new(0, window.SizeX, 0, 20)
			local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			window:StopTweens()
			window:DoTween(window.GuiElems.Main, ti, { Size = UDim2.new(0, window.SizeX, 0, window.SizeY) })

			window.SizeY = size or window.SizeY
			table.insert(visibleWindows, 1, window)
			updateWindows()
		end
	end

	window.ClosedSide = nil
	window.OnActivate:Fire()
end

static.ToggleSide = function(name)
	local side = (name == "left" and leftSide or rightSide)
	side.Hidden = not side.Hidden
	for i, v in pairs(side.Windows) do
		if side.Hidden then
			v.OnDeactivate:Fire()
		else
			v.OnActivate:Fire()
		end
	end
	updateWindows()
end

static.SetSideVisible = function(s, vis)
	local side = (type(s) == "table" and s) or (s == "left" and leftSide or rightSide)
	side.Hidden = not vis
	for i, v in pairs(side.Windows) do
		if side.Hidden then
			v.OnDeactivate:Fire()
		else
			v.OnActivate:Fire()
		end
	end
	updateWindows()
end

static.Init = function()
	displayOrderStart = Main.DisplayOrders.Window
	sideDisplayOrder = Main.DisplayOrders.SideWindow

	sidesGui = Instance.new("ScreenGui")
	local leftFrame = create({
		{ 1, "Frame", { Active = true, Name = "LeftSide", BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799), BorderSizePixel = 0 } },
		{
			2,
			"TextButton",
			{ AutoButtonColor = false, BackgroundColor3 = Color3.new(0.2549019753933, 0.2549019753933, 0.2549019753933), BorderSizePixel = 0, Font = 3, Name = "Resizer", Parent = { 1 }, Size = UDim2.new(0, 5, 1, 0), Text = "", TextColor3 = Color3.new(0, 0, 0), TextSize = 14 },
		},
		{ 3, "Frame", { BackgroundColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462), BorderSizePixel = 0, Name = "Line", Parent = { 2 }, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0) } },
		{
			4,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2549019753933, 0.2549019753933, 0.2549019753933),
				BorderSizePixel = 0,
				Font = 3,
				Name = "WindowResizer",
				Parent = { 1 },
				Position = UDim2.new(1, -300, 0, 0),
				Size = UDim2.new(1, 0, 0, 4),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{ 5, "Frame", { BackgroundColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462), BorderSizePixel = 0, Name = "Line", Parent = { 4 }, Size = UDim2.new(1, 0, 0, 1) } },
	})
	leftSide.Frame = leftFrame
	leftFrame.Position = UDim2.new(0, -leftSide.Width - 10, 0, 0)
	leftSide.WindowResizer = leftFrame.WindowResizer
	leftFrame.WindowResizer.Parent = nil
	leftFrame.Parent = sidesGui

	local rightFrame = create({
		{ 1, "Frame", { Active = true, Name = "RightSide", BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799), BorderSizePixel = 0 } },
		{
			2,
			"TextButton",
			{ AutoButtonColor = false, BackgroundColor3 = Color3.new(0.2549019753933, 0.2549019753933, 0.2549019753933), BorderSizePixel = 0, Font = 3, Name = "Resizer", Parent = { 1 }, Size = UDim2.new(0, 5, 1, 0), Text = "", TextColor3 = Color3.new(0, 0, 0), TextSize = 14 },
		},
		{ 3, "Frame", { BackgroundColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462), BorderSizePixel = 0, Name = "Line", Parent = { 2 }, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(0, 1, 1, 0) } },
		{
			4,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2549019753933, 0.2549019753933, 0.2549019753933),
				BorderSizePixel = 0,
				Font = 3,
				Name = "WindowResizer",
				Parent = { 1 },
				Position = UDim2.new(1, -300, 0, 0),
				Size = UDim2.new(1, 0, 0, 4),
				Text = "",
				TextColor3 = Color3.new(0, 0, 0),
				TextSize = 14,
			},
		},
		{ 5, "Frame", { BackgroundColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462), BorderSizePixel = 0, Name = "Line", Parent = { 4 }, Size = UDim2.new(1, 0, 0, 1) } },
	})
	rightSide.Frame = rightFrame
	rightFrame.Position = UDim2.new(1, 10, 0, 0)
	rightSide.WindowResizer = rightFrame.WindowResizer
	rightFrame.WindowResizer.Parent = nil
	rightFrame.Parent = sidesGui

	sideResizerHook(leftFrame.Resizer, "H", leftSide)
	sideResizerHook(rightFrame.Resizer, "H", rightSide)

	alignIndicator = Instance.new("ScreenGui")
	alignIndicator.DisplayOrder = Main.DisplayOrders.Core
	local indicator = Instance.new("Frame")
	indicator.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	indicator.BorderSizePixel = 0
	indicator.BackgroundTransparency = 0.8
	indicator.Name = "Indicator"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = indicator
	indicator.Parent = alignIndicator

	local leftToggle = create({
		{
			1,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.20392157137394, 0.20392157137394, 0.20392157137394),
				BorderColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462),
				BorderMode = 2,
				Font = 10,
				Name = "LeftToggle",
				Position = UDim2.new(0, 0, 0, -36),
				Size = UDim2.new(0, 16, 0, 36),
				Text = "<",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
			},
		},
	})
	local rightToggle = leftToggle:Clone()
	rightToggle.Name = "RightToggle"
	rightToggle.Position = UDim2.new(1, -16, 0, -36)
	Lib.ButtonAnim(leftToggle, { Mode = 2, PressColor = Color3.fromRGB(32, 32, 32) })
	Lib.ButtonAnim(rightToggle, { Mode = 2, PressColor = Color3.fromRGB(32, 32, 32) })

	leftToggle.MouseButton1Click:Connect(function() static.ToggleSide("left") end)

	rightToggle.MouseButton1Click:Connect(function() static.ToggleSide("right") end)

	leftToggle.Parent = sidesGui
	rightToggle.Parent = sidesGui

	sidesGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local maxWidth = math.max(300, sidesGui.AbsoluteSize.X - static.FreeWidth)
		leftSide.Width = math.max(static.MinWidth, math.min(leftSide.Width, maxWidth - rightSide.Width))
		rightSide.Width = math.max(static.MinWidth, math.min(rightSide.Width, maxWidth - leftSide.Width))
		for i = 1, #visibleWindows do
			visibleWindows[i]:MoveInBoundary()
		end
		updateWindows(true)
	end)

	sidesGui.DisplayOrder = sideDisplayOrder - 1
	Lib.ShowGui(sidesGui)
	updateSideFrames()
end

local mt = { __index = funcs }
static.new = function()
	local obj = setmetatable({
		Minimized = false,
		Dragging = false,
		Resizing = false,
		Aligned = false,
		Draggable = true,
		Resizable = true,
		ResizableInternal = true,
		Alignable = true,
		Closed = true,
		SizeX = 300,
		SizeY = 300,
		MinX = 200,
		MinY = 200,
		PosX = 0,
		PosY = 0,
		GuiElems = {},
		Tweens = {},
		Elements = {},
		OnActivate = Lib.Signal.new(),
		OnDeactivate = Lib.Signal.new(),
		OnMinimize = Lib.Signal.new(),
		OnRestore = Lib.Signal.new(),
	}, mt)
	obj.Gui = createGui(obj)
	return obj
end

return static
end function __DARKDEX_MODULES.y()local v=__DARKDEX_MODULES.cache.y if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.y=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Main = Context.Main
local Lib = Context.Lib
local Settings = Context.Settings
local service = Context.service
local create = Create.create

local funcs = {}
local mouse

local function createGui(self)
	local contextGui = create({
		{ 1, "ScreenGui", { DisplayOrder = 1000000, Name = "Context", ZIndexBehavior = 1 } },
		{
			2,
			"Frame",
			{
				Active = true,
				BackgroundColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462),
				BorderColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462),
				Name = "Main",
				Parent = { 1 },
				Position = UDim2.new(0.5, -100, 0.5, -150),
				Size = UDim2.new(0, 200, 0, 100),
			},
		},
		{ 3, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 2 } } },
		{ 4, "Frame", { BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799), Name = "Container", Parent = { 2 }, Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2) } },
		{ 5, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 4 } } },
		{
			6,
			"ScrollingFrame",
			{
				Active = true,
				BackgroundColor3 = Color3.new(0.20392157137394, 0.20392157137394, 0.20392157137394),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				Name = "List",
				Parent = { 4 },
				Position = UDim2.new(0, 2, 0, 2),
				ScrollBarImageColor3 = Color3.new(0, 0, 0),
				ScrollBarThickness = 4,
				Size = UDim2.new(1, -4, 1, -4),
				VerticalScrollBarInset = 1,
			},
		},
		{ 7, "UIListLayout", { Parent = { 6 }, SortOrder = 2 } },
		{ 8, "Frame", { BackgroundColor3 = Color3.new(0.20392157137394, 0.20392157137394, 0.20392157137394), BorderSizePixel = 0, Name = "SearchFrame", Parent = { 4 }, Size = UDim2.new(1, 0, 0, 24), Visible = false } },
		{
			9,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.1176470592618, 0.1176470592618, 0.1176470592618),
				BorderSizePixel = 0,
				Name = "SearchContainer",
				Parent = { 8 },
				Position = UDim2.new(0, 3, 0, 3),
				Size = UDim2.new(1, -6, 0, 18),
			},
		},
		{
			10,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "SearchBox",
				Parent = { 9 },
				PlaceholderColor3 = Color3.new(0.39215689897537, 0.39215689897537, 0.39215689897537),
				PlaceholderText = "Search",
				Position = UDim2.new(0, 4, 0, 0),
				Size = UDim2.new(1, -8, 0, 18),
				Text = "",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{ 11, "UICorner", { CornerRadius = UDim.new(0, 2), Parent = { 9 } } },
		{ 12, "Frame", { BackgroundColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462), BorderSizePixel = 0, Name = "Line", Parent = { 8 }, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1) } },
		{
			13,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.20392157137394, 0.20392157137394, 0.20392157137394),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.33725491166115, 0.49019610881805, 0.73725491762161),
				BorderSizePixel = 0,
				Font = 3,
				Name = "Entry",
				Parent = { 1 },
				Size = UDim2.new(1, 0, 0, 22),
				Text = "",
				TextSize = 14,
				Visible = false,
			},
		},
		{
			14,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "EntryName",
				Parent = { 13 },
				Position = UDim2.new(0, 24, 0, 0),
				Size = UDim2.new(1, -24, 1, 0),
				Text = "Duplicate",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{
			15,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Shortcut",
				Parent = { 13 },
				Position = UDim2.new(0, 24, 0, 0),
				Size = UDim2.new(1, -30, 1, 0),
				Text = "Ctrl+D",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{
			16,
			"ImageLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				ImageRectOffset = Vector2.new(304, 0),
				ImageRectSize = Vector2.new(16, 16),
				Name = "Icon",
				Parent = { 13 },
				Position = UDim2.new(0, 2, 0, 3),
				ScaleType = 4,
				Size = UDim2.new(0, 16, 0, 16),
			},
		},
		{ 17, "UICorner", { CornerRadius = UDim.new(0, 4), Parent = { 13 } } },
		{ 18, "Frame", { BackgroundColor3 = Color3.new(0.21568629145622, 0.21568629145622, 0.21568629145622), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Divider", Parent = { 1 }, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 7), Visible = false } },
		{ 19, "Frame", { BackgroundColor3 = Color3.new(0.20392157137394, 0.20392157137394, 0.20392157137394), BorderSizePixel = 0, Name = "Line", Parent = { 18 }, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1) } },
		{
			20,
			"TextLabel",
			{
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = 3,
				Name = "DividerName",
				Parent = { 18 },
				Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.new(1, -4, 1, 0),
				Text = "Objects",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				TextTransparency = 0.60000002384186,
				TextXAlignment = 0,
				Visible = false,
			},
		},
	})
	self.GuiElems.Main = contextGui.Main
	self.GuiElems.List = contextGui.Main.Container.List
	self.GuiElems.Entry = contextGui.Entry
	self.GuiElems.Divider = contextGui.Divider
	self.GuiElems.SearchFrame = contextGui.Main.Container.SearchFrame
	self.GuiElems.SearchBar = self.GuiElems.SearchFrame.SearchContainer.SearchBox
	Lib.ViewportTextBox.convert(self.GuiElems.SearchBar)

	self.GuiElems.SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
		local lower, find = string.lower, string.find
		local searchText = lower(self.GuiElems.SearchBar.Text)
		local items = self.Items
		local map = self.ItemToEntryMap

		if searchText ~= "" then
			local results = {}
			local count = 1
			for i = 1, #items do
				local item = items[i]
				local entry = map[item]
				if entry then
					if not item.Divider and find(lower(item.Name), searchText, 1, true) then
						results[count] = item
						count = count + 1
					else
						entry.Visible = false
					end
				end
			end
			table.sort(results, function(a, b) return a.Name < b.Name end)
			for i = 1, #results do
				local entry = map[results[i] ]
				entry.LayoutOrder = i
				entry.Visible = true
			end
		else
			for i = 1, #items do
				local entry = map[items[i] ]
				if entry then
					entry.LayoutOrder = i
					entry.Visible = true
				end
			end
		end

		local toSize = self.GuiElems.List.UIListLayout.AbsoluteContentSize.Y + 6
		self.GuiElems.List.CanvasSize = UDim2.new(0, 0, 0, toSize - 6)
	end)

	return contextGui
end

funcs.Add = function(self, item)
	local newItem = {
		Name = item.Name or "Item",
		Icon = item.Icon or "",
		Shortcut = item.Shortcut or "",
		OnClick = item.OnClick,
		OnHover = item.OnHover,
		Disabled = item.Disabled or false,
		DisabledIcon = item.DisabledIcon or "",
		IconMap = item.IconMap,
		OnRightClick = item.OnRightClick,
		NoHide = item.NoHide,
	}
	if self.QueuedDivider then
		local text = self.QueuedDividerText and #self.QueuedDividerText > 0 and self.QueuedDividerText
		self:AddDivider(text)
	end
	self.Items[#self.Items + 1] = newItem
	self.Updated = nil
end

funcs.AddRegistered = function(self, name, disabled)
	if not self.Registered[name] then error(name .. " is not registered") end

	if self.QueuedDivider then
		local text = self.QueuedDividerText and #self.QueuedDividerText > 0 and self.QueuedDividerText
		self:AddDivider(text)
	end
	self.Registered[name].Disabled = disabled
	self.Items[#self.Items + 1] = self.Registered[name]
	self.Updated = nil
end

funcs.Register = function(self, name, item)
	self.Registered[name] = {
		Name = item.Name or "Item",
		Icon = item.Icon or "",
		Shortcut = item.Shortcut or "",
		OnClick = item.OnClick,
		OnHover = item.OnHover,
		DisabledIcon = item.DisabledIcon or "",
		IconMap = item.IconMap,
		OnRightClick = item.OnRightClick,
	}
end

funcs.UnRegister = function(self, name) self.Registered[name] = nil end

funcs.AddDivider = function(self, text)
	self.QueuedDivider = false
	local textWidth = text and service.TextService:GetTextSize(text, 14, Enum.Font.SourceSans, Vector2.new(999999999, 20)).X or nil
	table.insert(self.Items, { Divider = true, Text = text, TextSize = textWidth and textWidth + 4 })
	self.Updated = nil
end

funcs.QueueDivider = function(self, text)
	self.QueuedDivider = true
	self.QueuedDividerText = text or ""
end

funcs.Clear = function(self)
	self.Items = {}
	self.Updated = nil
end

funcs.Refresh = function(self)
	for i, v in pairs(self.GuiElems.List:GetChildren()) do
		if not v:IsA("UIListLayout") then v:Destroy() end
	end
	local map = {}
	self.ItemToEntryMap = map

	local dividerFrame = self.GuiElems.Divider
	local contextList = self.GuiElems.List
	local entryFrame = self.GuiElems.Entry
	local items = self.Items

	for i = 1, #items do
		local item = items[i]
		if item.Divider then
			local newDivider = dividerFrame:Clone()
			newDivider.Line.BackgroundColor3 = self.Theme.DividerColor
			if item.Text then
				newDivider.Size = UDim2.new(1, 0, 0, 20)
				newDivider.Line.Position = UDim2.new(0, item.TextSize, 0.5, 0)
				newDivider.Line.Size = UDim2.new(1, -item.TextSize, 0, 1)
				newDivider.DividerName.TextColor3 = self.Theme.TextColor
				newDivider.DividerName.Text = item.Text
				newDivider.DividerName.Visible = true
			end
			newDivider.Visible = true
			map[item] = newDivider
			newDivider.Parent = contextList
		else
			local newEntry = entryFrame:Clone()
			newEntry.BackgroundColor3 = self.Theme.HighlightColor
			newEntry.EntryName.TextColor3 = self.Theme.TextColor
			newEntry.EntryName.Text = item.Name
			newEntry.Shortcut.Text = item.Shortcut
			if item.Disabled then
				newEntry.EntryName.TextColor3 = Color3.new(150 / 255, 150 / 255, 150 / 255)
				newEntry.Shortcut.TextColor3 = Color3.new(150 / 255, 150 / 255, 150 / 255)
			end

			if self.Iconless then
				newEntry.EntryName.Position = UDim2.new(0, 2, 0, 0)
				newEntry.EntryName.Size = UDim2.new(1, -4, 0, 20)
				newEntry.Icon.Visible = false
			else
				local iconIndex = item.Disabled and item.DisabledIcon or item.Icon
				if item.IconMap then
					if type(iconIndex) == "number" then
						item.IconMap:Display(newEntry.Icon, iconIndex)
					elseif type(iconIndex) == "string" then
						item.IconMap:DisplayByKey(newEntry.Icon, iconIndex)
					end
				elseif type(iconIndex) == "string" then
					newEntry.Icon.Image = iconIndex
				end
			end

			if not item.Disabled then
				if item.OnClick then newEntry.MouseButton1Click:Connect(function()
					item.OnClick(item.Name)
					if not item.NoHide then self:Hide() end
				end) end

				if item.OnRightClick then newEntry.MouseButton2Click:Connect(function()
					item.OnRightClick(item.Name)
					if not item.NoHide then self:Hide() end
				end) end
			end

			newEntry.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then newEntry.BackgroundTransparency = 0 end
			end)

			newEntry.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then newEntry.BackgroundTransparency = 1 end
			end)

			newEntry.Visible = true
			map[item] = newEntry
			newEntry.Parent = contextList
		end
	end
	self.Updated = true
end

funcs.Show = function(self, x, y)
	-- Initialize Gui
	local elems = self.GuiElems
	elems.SearchFrame.Visible = self.SearchEnabled
	elems.List.Position = UDim2.new(0, 2, 0, 2 + (self.SearchEnabled and 24 or 0))
	elems.List.Size = UDim2.new(1, -4, 1, -4 - (self.SearchEnabled and 24 or 0))
	if self.SearchEnabled and self.ClearSearchOnShow then elems.SearchBar.Text = "" end
	self.GuiElems.List.CanvasPosition = Vector2.new(0, 0)

	if not self.Updated then
		self:Refresh() -- Create entries
	end

	-- Vars
	local reverseY = false
	local x, y = x or mouse.X, y or mouse.Y
	local maxX, maxY = mouse.ViewSizeX, mouse.ViewSizeY

	-- Position and show
	if x + self.Width > maxX then x = self.ReverseX and x - self.Width or maxX - self.Width end
	elems.Main.Position = UDim2.new(0, x, 0, y)
	elems.Main.Size = UDim2.new(0, self.Width, 0, 0)
	self.Gui.DisplayOrder = Main.DisplayOrders.Menu
	Lib.ShowGui(self.Gui)

	-- Size adjustment
	local toSize = elems.List.UIListLayout.AbsoluteContentSize.Y + 6 -- Padding
	if self.MaxHeight and toSize > self.MaxHeight then
		elems.List.CanvasSize = UDim2.new(0, 0, 0, toSize - 6)
		toSize = self.MaxHeight
	else
		elems.List.CanvasSize = UDim2.new(0, 0, 0, toSize - 6)
	end
	if y + toSize > maxY then reverseY = true end

	-- Close event
	local closable
	if self.CloseEvent then self.CloseEvent:Disconnect() end
	self.CloseEvent = service.UserInputService.InputBegan:Connect(function(input)
		if not closable or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		if not Lib.CheckMouseInGui(elems.Main) then self:Hide() end
	end)

	-- Resize
	if reverseY then
		elems.Main.Position = UDim2.new(0, x, 0, y - (self.ReverseYOffset or 0))
		local newY = y - toSize - (self.ReverseYOffset or 0)
		y = newY >= 0 and newY or 0
		elems.Main:TweenSizeAndPosition(UDim2.new(0, self.Width, 0, toSize), UDim2.new(0, x, 0, y), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
	else
		elems.Main:TweenSize(UDim2.new(0, self.Width, 0, toSize), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
	end

	-- Close debounce
	Lib.FastWait()
	if self.SearchEnabled and self.FocusSearchOnShow then elems.SearchBar:CaptureFocus() end
	closable = true
end

funcs.Hide = function(self)
	if self.CloseEvent then
		self.CloseEvent:Disconnect()
		self.CloseEvent = nil
	end
	self.Gui.Parent = nil
end

funcs.ApplyTheme = function(self, data)
	local theme = self.Theme
	theme.ContentColor = data.ContentColor or Settings.Theme.Menu
	theme.OutlineColor = data.OutlineColor or Settings.Theme.Menu
	theme.DividerColor = data.DividerColor or Settings.Theme.Outline2
	theme.TextColor = data.TextColor or Settings.Theme.Text
	theme.HighlightColor = data.HighlightColor or Settings.Theme.Main1

	self.GuiElems.Main.BackgroundColor3 = theme.OutlineColor
	self.GuiElems.Main.Container.BackgroundColor3 = theme.ContentColor
end

local mt = { __index = funcs }
local function new()
	if not mouse then mouse = Main.Mouse or service.Players.LocalPlayer:GetMouse() end

	local obj = setmetatable({
		Width = 200,
		MaxHeight = nil,
		Iconless = false,
		SearchEnabled = false,
		ClearSearchOnShow = true,
		FocusSearchOnShow = true,
		Updated = false,
		QueuedDivider = false,
		QueuedDividerText = "",
		Items = {},
		Registered = {},
		GuiElems = {},
		Theme = {},
	}, mt)
	obj.Gui = createGui(obj)
	obj:ApplyTheme({})
	return obj
end

return { new = new }
end function __DARKDEX_MODULES.z()local v=__DARKDEX_MODULES.cache.z if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.z=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Lib = Context.Lib
local Settings = Context.Settings
local env = Context.env
local service = Context.service
local plr = Context.plr

local create = Create.create

local funcs = {}

local typeMap = {
	[1] = "String",
	[2] = "String",
	[3] = "String",
	[4] = "Comment",
	[5] = "Operator",
	[6] = "Number",
	[7] = "Keyword",
	[8] = "BuiltIn",
	[9] = "LocalMethod",
	[10] = "LocalProperty",
	[11] = "Nil",
	[12] = "Bool",
	[13] = "Function",
	[14] = "Local",
	[15] = "Self",
	[16] = "FunctionName",
	[17] = "Bracket",
}

local specialKeywordsTypes = {
	["nil"] = 11,
	["true"] = 12,
	["false"] = 12,
	["function"] = 13,
	["local"] = 14,
	["self"] = 15,
}

local keywords = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
	["plugin"] = true,
}

local builtIns = {
	["delay"] = true,
	["elapsedTime"] = true,
	["require"] = true,
	["spawn"] = true,
	["tick"] = true,
	["time"] = true,
	["typeof"] = true,
	["UserSettings"] = true,
	["wait"] = true,
	["warn"] = true,
	["game"] = true,
	["shared"] = true,
	["script"] = true,
	["workspace"] = true,
	["assert"] = true,
	["collectgarbage"] = true,
	["error"] = true,
	["getfenv"] = true,
	["getmetatable"] = true,
	["ipairs"] = true,
	["loadstring"] = true,
	["newproxy"] = true,
	["next"] = true,
	["pairs"] = true,
	["pcall"] = true,
	["print"] = true,
	["rawequal"] = true,
	["rawget"] = true,
	["rawset"] = true,
	["select"] = true,
	["setfenv"] = true,
	["setmetatable"] = true,
	["tonumber"] = true,
	["tostring"] = true,
	["type"] = true,
	["unpack"] = true,
	["xpcall"] = true,
	["_G"] = true,
	["_VERSION"] = true,
	["coroutine"] = true,
	["debug"] = true,
	["math"] = true,
	["os"] = true,
	["string"] = true,
	["table"] = true,
	["bit32"] = true,
	["utf8"] = true,
	["Axes"] = true,
	["BrickColor"] = true,
	["CFrame"] = true,
	["Color3"] = true,
	["ColorSequence"] = true,
	["ColorSequenceKeypoint"] = true,
	["DockWidgetPluginGuiInfo"] = true,
	["Enum"] = true,
	["Faces"] = true,
	["Instance"] = true,
	["NumberRange"] = true,
	["NumberSequence"] = true,
	["NumberSequenceKeypoint"] = true,
	["PathWaypoint"] = true,
	["PhysicalProperties"] = true,
	["Random"] = true,
	["Ray"] = true,
	["Rect"] = true,
	["Region3"] = true,
	["Region3int16"] = true,
	["TweenInfo"] = true,
	["UDim"] = true,
	["UDim2"] = true,
	["Vector2"] = true,
	["Vector2int16"] = true,
	["Vector3"] = true,
	["Vector3int16"] = true,
}

local builtInInited = false

local richReplace = {
	["'"] = "&apos;",
	['"'] = "&quot;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	["&"] = "&amp;",
}

local tabSub = "\205"
local tabReplacement = (" %s%s "):format(tabSub, tabSub)

local tabJumps = {
	[("[^%s] %s"):format(tabSub, tabSub)] = 0,
	[(" %s%s"):format(tabSub, tabSub)] = -1,
	[("%s%s "):format(tabSub, tabSub)] = 2,
	[("%s [^%s]"):format(tabSub, tabSub)] = 1,
}

local tweenService = service.TweenService

local function initBuiltIn()
	local env = getfenv()
	local type = type
	local tostring = tostring
	for name, _ in next, builtIns do
		local envVal = env[name]
		if type(envVal) == "table" then
			local items = {}
			for i, v in next, envVal do
				items[i] = true
			end
			builtIns[name] = items
		end
	end

	local enumEntries = {}
	local enums = Enum:GetEnums()
	for i = 1, #enums do
		enumEntries[tostring(enums[i])] = true
	end
	builtIns["Enum"] = enumEntries

	builtInInited = true
end

local function setupEditBox(obj)
	local editBox = obj.GuiElems.EditBox

	editBox.Focused:Connect(function()
		obj:ConnectEditBoxEvent()
		obj.Editing = true
	end)

	editBox.FocusLost:Connect(function()
		obj:DisconnectEditBoxEvent()
		obj.Editing = false
	end)

	editBox:GetPropertyChangedSignal("Text"):Connect(function()
		local text = editBox.Text
		if #text == 0 or obj.EditBoxCopying then return end
		editBox.Text = ""
		obj:AppendText(text)
	end)
end

local function setupMouseSelection(obj)
	local mouse = plr:GetMouse()
	local codeFrame = obj.GuiElems.LinesFrame
	local lines = obj.Lines

	codeFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local fontSizeX, fontSizeY = math.ceil(obj.FontSize / 2), obj.FontSize

			local relX = mouse.X - codeFrame.AbsolutePosition.X
			local relY = mouse.Y - codeFrame.AbsolutePosition.Y
			local selX = math.round(relX / fontSizeX) + obj.ViewX
			local selY = math.floor(relY / fontSizeY) + obj.ViewY
			local releaseEvent, mouseEvent, scrollEvent
			local scrollPowerV, scrollPowerH = 0, 0
			selY = math.min(#lines - 1, selY)
			local relativeLine = lines[selY + 1] or ""
			selX = math.min(#relativeLine, selX + obj:TabAdjust(selX, selY))

			obj.SelectionRange = { { -1, -1 }, { -1, -1 } }
			obj:MoveCursor(selX, selY)
			obj.FloatCursorX = selX

			local function updateSelection()
				local relX = mouse.X - codeFrame.AbsolutePosition.X
				local relY = mouse.Y - codeFrame.AbsolutePosition.Y
				local sel2X = math.max(0, math.round(relX / fontSizeX) + obj.ViewX)
				local sel2Y = math.max(0, math.floor(relY / fontSizeY) + obj.ViewY)

				sel2Y = math.min(#lines - 1, sel2Y)
				local relativeLine = lines[sel2Y + 1] or ""
				sel2X = math.min(#relativeLine, sel2X + obj:TabAdjust(sel2X, sel2Y))

				if sel2Y < selY or (sel2Y == selY and sel2X < selX) then
					obj.SelectionRange = { { sel2X, sel2Y }, { selX, selY } }
				else
					obj.SelectionRange = { { selX, selY }, { sel2X, sel2Y } }
				end

				obj:MoveCursor(sel2X, sel2Y)
				obj.FloatCursorX = sel2X
				obj:Refresh()
			end

			releaseEvent = service.UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					releaseEvent:Disconnect()
					mouseEvent:Disconnect()
					scrollEvent:Disconnect()
					obj:SetCopyableSelection()
					--updateSelection()
				end
			end)

			mouseEvent = service.UserInputService.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					local upDelta = mouse.Y - codeFrame.AbsolutePosition.Y
					local downDelta = mouse.Y - codeFrame.AbsolutePosition.Y - codeFrame.AbsoluteSize.Y
					local leftDelta = mouse.X - codeFrame.AbsolutePosition.X
					local rightDelta = mouse.X - codeFrame.AbsolutePosition.X - codeFrame.AbsoluteSize.X
					scrollPowerV = 0
					scrollPowerH = 0
					if downDelta > 0 then
						scrollPowerV = math.floor(downDelta * 0.05) + 1
					elseif upDelta < 0 then
						scrollPowerV = math.ceil(upDelta * 0.05) - 1
					end
					if rightDelta > 0 then
						scrollPowerH = math.floor(rightDelta * 0.05) + 1
					elseif leftDelta < 0 then
						scrollPowerH = math.ceil(leftDelta * 0.05) - 1
					end
					updateSelection()
				end
			end)

			scrollEvent = service.RunService.RenderStepped:Connect(function()
				if scrollPowerV ~= 0 or scrollPowerH ~= 0 then
					obj:ScrollDelta(scrollPowerH, scrollPowerV)
					updateSelection()
				end
			end)

			obj:Refresh()
		end
	end)
end

local function makeFrame(obj)
	local frame = create({
		{ 1, "Frame", { BackgroundColor3 = Color3.new(0.15686275064945, 0.15686275064945, 0.15686275064945), BorderSizePixel = 0, Position = UDim2.new(0.5, -300, 0.5, -200), Size = UDim2.new(0, 600, 0, 400) } },
	})
	local elems = {}

	local linesFrame = Instance.new("Frame")
	linesFrame.Name = "Lines"
	linesFrame.BackgroundTransparency = 1
	linesFrame.Size = UDim2.new(1, 0, 1, 0)
	linesFrame.ClipsDescendants = true
	linesFrame.Parent = frame

	local lineNumbersLabel = Instance.new("TextLabel")
	lineNumbersLabel.Name = "LineNumbers"
	lineNumbersLabel.BackgroundTransparency = 1
	lineNumbersLabel.Font = Enum.Font.Code
	lineNumbersLabel.TextXAlignment = Enum.TextXAlignment.Right
	lineNumbersLabel.TextYAlignment = Enum.TextYAlignment.Top
	lineNumbersLabel.ClipsDescendants = true
	lineNumbersLabel.RichText = true
	lineNumbersLabel.Parent = frame

	local cursor = Instance.new("Frame")
	cursor.Name = "Cursor"
	cursor.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
	cursor.BorderSizePixel = 0
	cursor.Parent = frame

	local editBox = Instance.new("TextBox")
	editBox.Name = "EditBox"
	editBox.MultiLine = true
	editBox.Visible = false
	editBox.Parent = frame

	-- Per editor: a shared table made every editor blink the last created cursor
	obj.CursorTweens = {
		Invis = tweenService:Create(cursor, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }),
		Vis = tweenService:Create(cursor, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }),
	}

	elems.LinesFrame = linesFrame
	elems.LineNumbersLabel = lineNumbersLabel
	elems.Cursor = cursor
	elems.EditBox = editBox
	elems.ScrollCorner = create({ { 1, "Frame", { BackgroundColor3 = Color3.new(0.15686275064945, 0.15686275064945, 0.15686275064945), BorderSizePixel = 0, Name = "ScrollCorner", Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 16, 0, 16), Visible = false } } })

	elems.ScrollCorner.Parent = frame
	linesFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then obj:SetEditing(true, input) end
	end)

	obj.Frame = frame
	obj.Gui = frame
	obj.GuiElems = elems
	setupEditBox(obj)
	setupMouseSelection(obj)

	return frame
end

funcs.GetSelectionText = function(self)
	if not self:IsValidRange() then return "" end

	local selectionRange = self.SelectionRange
	local selX, selY = selectionRange[1][1], selectionRange[1][2]
	local sel2X, sel2Y = selectionRange[2][1], selectionRange[2][2]
	local deltaLines = sel2Y - selY
	local lines = self.Lines

	if not lines[selY + 1] or not lines[sel2Y + 1] then return "" end

	if deltaLines == 0 then return self:ConvertText(lines[selY + 1]:sub(selX + 1, sel2X), false) end

	local parts = { lines[selY + 1]:sub(selX + 1) }
	for i = selY + 1, sel2Y - 1 do
		table.insert(parts, lines[i + 1])
	end
	table.insert(parts, lines[sel2Y + 1]:sub(1, sel2X))

	return self:ConvertText(table.concat(parts, "\n"), false)
end

funcs.SetCopyableSelection = function(self)
	local text = self:GetSelectionText()
	local editBox = self.GuiElems.EditBox

	self.EditBoxCopying = true
	editBox.Text = text
	editBox.SelectionStart = 1
	editBox.CursorPosition = #editBox.Text + 1
	self.EditBoxCopying = false
end

funcs.ConnectEditBoxEvent = function(self)
	if self.EditBoxEvent then self.EditBoxEvent:Disconnect() end

	self.EditBoxEvent = service.UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		local keycodes = Enum.KeyCode
		local keycode = input.KeyCode

		local function setupMove(key, func)
			local endCon, finished
			endCon = service.UserInputService.InputEnded:Connect(function(input)
				if input.KeyCode ~= key then return end
				endCon:Disconnect()
				finished = true
			end)
			func()
			Lib.FastWait(0.5)
			while not finished do
				func()
				Lib.FastWait(0.03)
			end
		end

		if keycode == keycodes.Down then
			setupMove(keycodes.Down, function()
				self.CursorX = self.FloatCursorX
				self.CursorY = self.CursorY + 1
				self:UpdateCursor()
				self:JumpToCursor()
			end)
		elseif keycode == keycodes.Up then
			setupMove(keycodes.Up, function()
				self.CursorX = self.FloatCursorX
				self.CursorY = self.CursorY - 1
				self:UpdateCursor()
				self:JumpToCursor()
			end)
		elseif keycode == keycodes.Left then
			setupMove(keycodes.Left, function()
				local line = self.Lines[self.CursorY + 1] or ""
				self.CursorX = self.CursorX - 1 - (line:sub(self.CursorX - 3, self.CursorX) == tabReplacement and 3 or 0)
				if self.CursorX < 0 then
					self.CursorY = self.CursorY - 1
					local line2 = self.Lines[self.CursorY + 1] or ""
					self.CursorX = #line2
				end
				self.FloatCursorX = self.CursorX
				self:UpdateCursor()
				self:JumpToCursor()
			end)
		elseif keycode == keycodes.Right then
			setupMove(keycodes.Right, function()
				local line = self.Lines[self.CursorY + 1] or ""
				self.CursorX = self.CursorX + 1 + (line:sub(self.CursorX + 1, self.CursorX + 4) == tabReplacement and 3 or 0)
				if self.CursorX > #line then
					self.CursorY = self.CursorY + 1
					self.CursorX = 0
				end
				self.FloatCursorX = self.CursorX
				self:UpdateCursor()
				self:JumpToCursor()
			end)
		elseif keycode == keycodes.Backspace then
			setupMove(keycodes.Backspace, function()
				local startRange, endRange
				if self:IsValidRange() then
					startRange = self.SelectionRange[1]
					endRange = self.SelectionRange[2]
				else
					endRange = { self.CursorX, self.CursorY }
				end

				if not startRange then
					local line = self.Lines[self.CursorY + 1] or ""
					self.CursorX = self.CursorX - 1 - (line:sub(self.CursorX - 3, self.CursorX) == tabReplacement and 3 or 0)
					if self.CursorX < 0 then
						self.CursorY = self.CursorY - 1
						local line2 = self.Lines[self.CursorY + 1] or ""
						self.CursorX = #line2
					end
					self.FloatCursorX = self.CursorX
					self:UpdateCursor()

					startRange = startRange or { self.CursorX, self.CursorY }
				end

				self:DeleteRange({ startRange, endRange }, false, true)
				self:ResetSelection(true)
				self:JumpToCursor()
			end)
		elseif keycode == keycodes.Delete then
			setupMove(keycodes.Delete, function()
				local startRange, endRange
				if self:IsValidRange() then
					startRange = self.SelectionRange[1]
					endRange = self.SelectionRange[2]
				else
					startRange = { self.CursorX, self.CursorY }
				end

				if not endRange then
					local line = self.Lines[self.CursorY + 1] or ""
					local endCursorX = self.CursorX + 1 + (line:sub(self.CursorX + 1, self.CursorX + 4) == tabReplacement and 3 or 0)
					local endCursorY = self.CursorY
					if endCursorX > #line then
						endCursorY = endCursorY + 1
						endCursorX = 0
					end
					self:UpdateCursor()

					endRange = endRange or { endCursorX, endCursorY }
				end

				self:DeleteRange({ startRange, endRange }, false, true)
				self:ResetSelection(true)
				self:JumpToCursor()
			end)
		elseif Lib.IsCtrlDown() then
			if keycode == keycodes.A then
				self.SelectionRange = { { 0, 0 }, { #self.Lines[#self.Lines], #self.Lines - 1 } }
				self:SetCopyableSelection()
				self:Refresh()
			end
		end
	end)
end

funcs.DisconnectEditBoxEvent = function(self)
	if self.EditBoxEvent then self.EditBoxEvent:Disconnect() end
end

funcs.ResetSelection = function(self, norefresh)
	self.SelectionRange = { { -1, -1 }, { -1, -1 } }
	if not norefresh then self:Refresh() end
end

funcs.IsValidRange = function(self, range)
	local selectionRange = range or self.SelectionRange
	local selX, selY = selectionRange[1][1], selectionRange[1][2]
	local sel2X, sel2Y = selectionRange[2][1], selectionRange[2][2]

	if selX == -1 or (selX == sel2X and selY == sel2Y) then return false end

	return true
end

funcs.DeleteRange = function(self, range, noprocess, updatemouse)
	range = range or self.SelectionRange
	if not self:IsValidRange(range) then return end

	local lines = self.Lines
	local selX, selY = range[1][1], range[1][2]
	local sel2X, sel2Y = range[2][1], range[2][2]
	local deltaLines = sel2Y - selY

	if not lines[selY + 1] or not lines[sel2Y + 1] then return end

	local leftSub = lines[selY + 1]:sub(1, selX)
	local rightSub = lines[sel2Y + 1]:sub(sel2X + 1)
	lines[selY + 1] = leftSub .. rightSub

	local remove = table.remove
	for i = 1, deltaLines do
		remove(lines, selY + 2)
	end

	if range == self.SelectionRange then self.SelectionRange = { { -1, -1 }, { -1, -1 } } end
	if updatemouse then
		self.CursorX = selX
		self.CursorY = selY
		self:UpdateCursor()
	end

	if not noprocess then self:ProcessTextChange() end
end

funcs.AppendText = function(self, text)
	self:DeleteRange(nil, true, true)
	local lines, cursorX, cursorY = self.Lines, self.CursorX, self.CursorY
	local line = lines[cursorY + 1]
	local before = line:sub(1, cursorX)
	local after = line:sub(cursorX + 1)

	text = text:gsub("\r\n", "\n")
	text = self:ConvertText(text, true) -- Tab Convert

	local textLines = text:split("\n")
	local insert = table.insert

	for i = 1, #textLines do
		local linePos = cursorY + i
		if i > 1 then insert(lines, linePos, "") end

		local textLine = textLines[i]
		local newBefore = (i == 1 and before or "")
		local newAfter = (i == #textLines and after or "")

		lines[linePos] = newBefore .. textLine .. newAfter
	end

	if #textLines > 1 then cursorX = 0 end

	self:ProcessTextChange()
	self.CursorX = cursorX + #textLines[#textLines]
	self.CursorY = cursorY + #textLines - 1
	self:UpdateCursor()
end

funcs.ScrollDelta = function(self, x, y)
	self.ScrollV:ScrollTo(self.ScrollV.Index + y)
	self.ScrollH:ScrollTo(self.ScrollH.Index + x)
end

-- x and y starts at 0
funcs.TabAdjust = function(self, x, y)
	local lines = self.Lines
	local line = lines[y + 1]
	x = x + 1

	if line then
		local left = line:sub(x - 1, x - 1)
		local middle = line:sub(x, x)
		local right = line:sub(x + 1, x + 1)
		local selRange = (#left > 0 and left or " ") .. (#middle > 0 and middle or " ") .. (#right > 0 and right or " ")

		for i, v in pairs(tabJumps) do
			if selRange:find(i) then return v end
		end
	end
	return 0
end

funcs.SetEditing = function(self, on, input)
	self:UpdateCursor(input)

	if on then
		if self.Editable then
			self.GuiElems.EditBox.Text = ""
			self.GuiElems.EditBox:CaptureFocus()
		end
	else
		self.GuiElems.EditBox:ReleaseFocus()
	end
end

funcs.CursorAnim = function(self, on)
	local cursor = self.GuiElems.Cursor
	local tweens = self.CursorTweens
	local animId = (self.CursorAnimId or 0) + 1
	self.CursorAnimId = animId

	if not on then return end

	tweens.Invis:Cancel()
	tweens.Vis:Cancel()
	cursor.BackgroundTransparency = 0

	-- A newer call replaces this loop by changing CursorAnimId
	task.spawn(function()
		while self.Editable and cursor.Parent do
			task.wait(0.5)
			if self.CursorAnimId ~= animId then return end
			tweens.Invis:Play()
			task.wait(0.4)
			if self.CursorAnimId ~= animId then return end
			tweens.Vis:Play()
			task.wait(0.2)
		end
	end)
end

funcs.MoveCursor = function(self, x, y)
	self.CursorX = x
	self.CursorY = y
	self:UpdateCursor()
	self:JumpToCursor()
end

funcs.JumpToCursor = function(self) self:Refresh() end

funcs.UpdateCursor = function(self, input)
	local linesFrame = self.GuiElems.LinesFrame
	local cursor = self.GuiElems.Cursor
	local hSize = math.max(0, linesFrame.AbsoluteSize.X)
	local vSize = math.max(0, linesFrame.AbsoluteSize.Y)
	local maxLines = math.ceil(vSize / self.FontSize)
	local maxCols = math.ceil(hSize / math.ceil(self.FontSize / 2))
	local viewX, viewY = self.ViewX, self.ViewY
	local totalLinesStr = tostring(#self.Lines)
	local fontWidth = math.ceil(self.FontSize / 2)
	local linesOffset = #totalLinesStr * fontWidth + 4 * fontWidth

	if input then
		local linesFrame = self.GuiElems.LinesFrame
		local frameX, frameY = linesFrame.AbsolutePosition.X, linesFrame.AbsolutePosition.Y
		local mouseX, mouseY = input.Position.X, input.Position.Y
		local fontSizeX, fontSizeY = math.ceil(self.FontSize / 2), self.FontSize

		self.CursorX = self.ViewX + math.round((mouseX - frameX) / fontSizeX)
		self.CursorY = self.ViewY + math.floor((mouseY - frameY) / fontSizeY)
	end

	local cursorX, cursorY = self.CursorX, self.CursorY

	local line = self.Lines[cursorY + 1] or ""
	if cursorX > #line then
		cursorX = #line
	elseif cursorX < 0 then
		cursorX = 0
	end

	if cursorY >= #self.Lines then
		cursorY = math.max(0, #self.Lines - 1)
	elseif cursorY < 0 then
		cursorY = 0
	end

	cursorX = cursorX + self:TabAdjust(cursorX, cursorY)

	-- Update modified
	self.CursorX = cursorX
	self.CursorY = cursorY

	local cursorVisible = (cursorX >= viewX) and (cursorY >= viewY) and (cursorX <= viewX + maxCols) and (cursorY <= viewY + maxLines)
	if cursorVisible then
		local offX = (cursorX - viewX)
		local offY = (cursorY - viewY)
		cursor.Position = UDim2.new(0, linesOffset + offX * math.ceil(self.FontSize / 2) - 1, 0, offY * self.FontSize)
		cursor.Size = UDim2.new(0, 1, 0, self.FontSize + 2)
		cursor.Visible = true
		self:CursorAnim(true)
	else
		cursor.Visible = false
	end
end

funcs.MapNewLines = function(self)
	local newLines = {}
	local count = 1
	local text = self.Text
	local find = string.find
	local init = 1

	local pos = find(text, "\n", init, true)
	while pos do
		newLines[count] = pos
		count = count + 1
		init = pos + 1
		pos = find(text, "\n", init, true)
	end

	self.NewLines = newLines
end

funcs.PreHighlight = function(self)
	local text = self.Text:gsub("\\\\", "  ")
	local textLen = #text
	local found = {}
	local foundMap = {}
	local extras = {}
	local find = string.find
	local sub = string.sub
	self.ColoredLines = {}

	local function findAll(str, pattern, typ, raw)
		local count = #found + 1
		local init = 1
		local x, y, extra = find(str, pattern, init, raw)
		while x do
			found[count] = x
			foundMap[x] = typ
			if extra then extras[x] = extra end

			count = count + 1
			init = y + 1
			x, y, extra = find(str, pattern, init, raw)
		end
	end
	findAll(text, '"', 1, true)
	findAll(text, "'", 2, true)
	findAll(text, "%[(=*)%[", 3)
	findAll(text, "--", 4, true)
	table.sort(found)

	local newLines = self.NewLines
	local curLine = 0
	local lineTableCount = 1
	local lineStart = 0
	local lineEnd = 0
	local lastEnding = 0
	local foundHighlights = {}

	for i = 1, #found do
		local pos = found[i]
		if pos <= lastEnding then continue end

		local ending = pos
		local typ = foundMap[pos]
		if typ == 1 then
			ending = find(text, '"', pos + 1, true)
			while ending and sub(text, ending - 1, ending - 1) == "\\" do
				ending = find(text, '"', ending + 1, true)
			end
			if not ending then ending = textLen end
		elseif typ == 2 then
			ending = find(text, "'", pos + 1, true)
			while ending and sub(text, ending - 1, ending - 1) == "\\" do
				ending = find(text, "'", ending + 1, true)
			end
			if not ending then ending = textLen end
		elseif typ == 3 then
			_, ending = find(text, "]" .. extras[pos] .. "]", pos + 1, true)
			if not ending then ending = textLen end
		elseif typ == 4 then
			local ahead = foundMap[pos + 2]

			if ahead == 3 then
				_, ending = find(text, "]" .. extras[pos + 2] .. "]", pos + 1, true)
				if not ending then ending = textLen end
			else
				ending = find(text, "\n", pos + 1, true) or textLen
			end
		end

		while pos > lineEnd do
			curLine = curLine + 1
			--lineTableCount = 1
			lineEnd = newLines[curLine] or textLen + 1
		end
		while true do
			local lineTable = foundHighlights[curLine]
			if not lineTable then
				lineTable = {}
				foundHighlights[curLine] = lineTable
			end
			lineTable[pos] = { typ, ending }
			--lineTableCount = lineTableCount + 1

			if ending > lineEnd then
				curLine = curLine + 1
				lineEnd = newLines[curLine] or textLen + 1
			else
				break
			end
		end

		lastEnding = ending
		--if i < 200 then print(curLine) end
	end
	self.PreHighlights = foundHighlights
end

funcs.HighlightLine = function(self, line)
	local cached = self.ColoredLines[line]
	if cached then return cached end

	local sub = string.sub
	local find = string.find
	local match = string.match
	local highlights = {}
	local preHighlights = self.PreHighlights[line] or {}
	local lineText = self.Lines[line] or ""
	local lineLen = #lineText
	local lastEnding = 0
	local currentType = 0
	local lastWord = nil
	local wordBeginsDotted = false
	local funcStatus = 0
	local lineStart = self.NewLines[line - 1] or 0

	local preHighlightMap = {}
	for pos, data in next, preHighlights do
		local relativePos = pos - lineStart
		if relativePos < 1 then
			currentType = data[1]
			lastEnding = data[2] - lineStart
			--warn(pos,data[2])
		else
			preHighlightMap[relativePos] = { data[1], data[2] - lineStart }
		end
	end

	for col = 1, #lineText do
		if col <= lastEnding then
			highlights[col] = currentType
			continue
		end

		local pre = preHighlightMap[col]
		if pre then
			currentType = pre[1]
			lastEnding = pre[2]
			highlights[col] = currentType
			wordBeginsDotted = false
			lastWord = nil
			funcStatus = 0
		else
			local char = sub(lineText, col, col)
			if find(char, "[%a_]") then
				local word = match(lineText, "[%a%d_]+", col)
				local wordType = (keywords[word] and 7) or (builtIns[word] and 8)

				lastEnding = col + #word - 1

				if wordType ~= 7 then
					if wordBeginsDotted then
						local prevBuiltIn = lastWord and builtIns[lastWord]
						wordType = (prevBuiltIn and type(prevBuiltIn) == "table" and prevBuiltIn[word] and 8) or 10
					end

					if wordType ~= 8 then
						local x, y, br = find(lineText, "^%s*([%({\"'])", lastEnding + 1)
						if x then
							wordType = (funcStatus > 0 and br == "(" and 16) or 9
							funcStatus = 0
						end
					end
				else
					wordType = specialKeywordsTypes[word] or wordType
					funcStatus = (word == "function" and 1 or 0)
				end

				lastWord = word
				wordBeginsDotted = false
				if funcStatus > 0 then funcStatus = 1 end

				if wordType then
					currentType = wordType
					highlights[col] = currentType
				else
					currentType = nil
				end
			elseif find(char, "%p") then
				local isDot = (char == ".")
				local isNum = isDot and find(sub(lineText, col + 1, col + 1), "%d")
				highlights[col] = (isNum and 6 or 5)

				if not isNum then
					local dotStr = isDot and match(lineText, "%.%.?%.?", col)
					if dotStr and #dotStr > 1 then
						currentType = 5
						lastEnding = col + #dotStr - 1
						wordBeginsDotted = false
						lastWord = nil
						funcStatus = 0
					else
						if isDot then
							if wordBeginsDotted then
								lastWord = nil
							else
								wordBeginsDotted = true
							end
						else
							wordBeginsDotted = false
							lastWord = nil
						end

						funcStatus = ((isDot or char == ":") and funcStatus == 1 and 2) or 0
					end
				end
			elseif find(char, "%d") then
				local _, endPos = find(lineText, "%x+", col)
				local endPart = sub(lineText, endPos, endPos + 1)
				if (endPart == "e+" or endPart == "e-") and find(sub(lineText, endPos + 2, endPos + 2), "%d") then endPos = endPos + 1 end
				currentType = 6
				lastEnding = endPos
				highlights[col] = 6
				wordBeginsDotted = false
				lastWord = nil
				funcStatus = 0
			else
				highlights[col] = currentType
				local _, endPos = find(lineText, "%s+", col)
				if endPos then lastEnding = endPos end
			end
		end
	end

	self.ColoredLines[line] = highlights
	return highlights
end

funcs.Refresh = function(self)
	local linesFrame = self.Frame.Lines
	local hSize = math.max(0, linesFrame.AbsoluteSize.X)
	local vSize = math.max(0, linesFrame.AbsoluteSize.Y)
	local maxLines = math.ceil(vSize / self.FontSize)
	local maxCols = math.ceil(hSize / math.ceil(self.FontSize / 2))
	local gsub = string.gsub
	local sub = string.sub

	local viewX, viewY = self.ViewX, self.ViewY

	local lineNumberStr = ""

	for row = 1, maxLines do
		local lineFrame = self.LineFrames[row]
		if not lineFrame then
			lineFrame = Instance.new("Frame")
			lineFrame.Name = "Line"
			lineFrame.Position = UDim2.new(0, 0, 0, (row - 1) * self.FontSize)
			lineFrame.Size = UDim2.new(1, 0, 0, self.FontSize)
			lineFrame.BorderSizePixel = 0
			lineFrame.BackgroundTransparency = 1

			local selectionHighlight = Instance.new("Frame")
			selectionHighlight.Name = "SelectionHighlight"
			selectionHighlight.BorderSizePixel = 0
			selectionHighlight.BackgroundColor3 = Settings.Theme.Syntax.SelectionBack
			selectionHighlight.Parent = lineFrame

			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Code
			label.TextSize = self.FontSize
			label.Size = UDim2.new(1, 0, 0, self.FontSize)
			label.RichText = true
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = self.Colors.Text
			label.ZIndex = 2
			label.Parent = lineFrame

			lineFrame.Parent = linesFrame
			self.LineFrames[row] = lineFrame
		end

		local relaY = viewY + row
		local lineText = self.Lines[relaY] or ""
		local resText = ""
		local highlights = self:HighlightLine(relaY)
		local colStart = viewX + 1

		local richTemplates = self.RichTemplates
		local textTemplate = richTemplates.Text
		local selectionTemplate = richTemplates.Selection
		local curType = highlights[colStart]
		local curTemplate = richTemplates[typeMap[curType] ] or textTemplate

		-- Selection Highlight
		local selectionRange = self.SelectionRange
		local selPos1 = selectionRange[1]
		local selPos2 = selectionRange[2]
		local selRow, selColumn = selPos1[2], selPos1[1]
		local sel2Row, sel2Column = selPos2[2], selPos2[1]
		local selRelaX, selRelaY = viewX, relaY - 1

		if selRelaY >= selPos1[2] and selRelaY <= selPos2[2] then
			local fontSizeX = math.ceil(self.FontSize / 2)
			local posX = (selRelaY == selPos1[2] and selPos1[1] or 0) - viewX
			local sizeX = (selRelaY == selPos2[2] and selPos2[1] - posX - viewX or maxCols + viewX)

			lineFrame.SelectionHighlight.Position = UDim2.new(0, posX * fontSizeX, 0, 0)
			lineFrame.SelectionHighlight.Size = UDim2.new(0, sizeX * fontSizeX, 1, 0)
			lineFrame.SelectionHighlight.Visible = true
		else
			lineFrame.SelectionHighlight.Visible = false
		end

		-- Selection Text Color for first char
		local inSelection = selRelaY >= selRow and selRelaY <= sel2Row and (selRelaY == selRow and viewX >= selColumn or selRelaY ~= selRow) and (selRelaY == sel2Row and viewX < sel2Column or selRelaY ~= sel2Row)
		if inSelection then
			curType = -999
			curTemplate = selectionTemplate
		end

		for col = 2, maxCols do
			local relaX = viewX + col
			local selRelaX = relaX - 1
			local posType = highlights[relaX]

			-- Selection Text Color
			local inSelection = selRelaY >= selRow and selRelaY <= sel2Row and (selRelaY == selRow and selRelaX >= selColumn or selRelaY ~= selRow) and (selRelaY == sel2Row and selRelaX < sel2Column or selRelaY ~= sel2Row)
			if inSelection then posType = -999 end

			if posType ~= curType then
				local template = (inSelection and selectionTemplate) or richTemplates[typeMap[posType] ] or textTemplate

				if template ~= curTemplate then
					local nextText = gsub(sub(lineText, colStart, relaX - 1), "['\"<>&]", richReplace)
					resText = resText .. (curTemplate ~= textTemplate and (curTemplate .. nextText .. "</font>") or nextText)
					colStart = relaX
					curTemplate = template
				end
				curType = posType
			end
		end

		local lastText = gsub(sub(lineText, colStart, viewX + maxCols), "['\"<>&]", richReplace)
		--warn("SUB",colStart,viewX+maxCols-1)
		if #lastText > 0 then resText = resText .. (curTemplate ~= textTemplate and (curTemplate .. lastText .. "</font>") or lastText) end

		if self.Lines[relaY] then lineNumberStr = lineNumberStr .. (relaY == self.CursorY and ("<b>" .. relaY .. "</b>\n") or relaY .. "\n") end

		lineFrame.Label.Text = resText
	end

	for i = maxLines + 1, #self.LineFrames do
		self.LineFrames[i]:Destroy()
		self.LineFrames[i] = nil
	end

	self.Frame.LineNumbers.Text = lineNumberStr
	self:UpdateCursor()
end

funcs.UpdateView = function(self)
	local totalLinesStr = tostring(#self.Lines)
	local fontWidth = math.ceil(self.FontSize / 2)
	local linesOffset = #totalLinesStr * fontWidth + 4 * fontWidth

	local linesFrame = self.Frame.Lines
	local hSize = linesFrame.AbsoluteSize.X
	local vSize = linesFrame.AbsoluteSize.Y
	local maxLines = math.ceil(vSize / self.FontSize)
	local totalWidth = self.MaxTextCols * fontWidth
	local scrollV = self.ScrollV
	local scrollH = self.ScrollH

	scrollV.VisibleSpace = maxLines
	scrollV.TotalSpace = #self.Lines + 1
	scrollH.VisibleSpace = math.ceil(hSize / fontWidth)
	scrollH.TotalSpace = self.MaxTextCols + 1

	scrollV.Gui.Visible = #self.Lines + 1 > maxLines
	scrollH.Gui.Visible = totalWidth > hSize

	local oldOffsets = self.FrameOffsets
	self.FrameOffsets = Vector2.new(scrollV.Gui.Visible and -16 or 0, scrollH.Gui.Visible and -16 or 0)
	if oldOffsets ~= self.FrameOffsets then
		self:UpdateView()
	else
		scrollV:ScrollTo(self.ViewY, true)
		scrollH:ScrollTo(self.ViewX, true)

		if scrollV.Gui.Visible and scrollH.Gui.Visible then
			scrollV.Gui.Size = UDim2.new(0, 16, 1, -16)
			scrollH.Gui.Size = UDim2.new(1, -16, 0, 16)
			self.GuiElems.ScrollCorner.Visible = true
		else
			scrollV.Gui.Size = UDim2.new(0, 16, 1, 0)
			scrollH.Gui.Size = UDim2.new(1, 0, 0, 16)
			self.GuiElems.ScrollCorner.Visible = false
		end

		self.ViewY = scrollV.Index
		self.ViewX = scrollH.Index
		self.Frame.Lines.Position = UDim2.new(0, linesOffset, 0, 0)
		self.Frame.Lines.Size = UDim2.new(1, -linesOffset + oldOffsets.X, 1, oldOffsets.Y)
		self.Frame.LineNumbers.Position = UDim2.new(0, fontWidth, 0, 0)
		self.Frame.LineNumbers.Size = UDim2.new(0, #totalLinesStr * fontWidth, 1, oldOffsets.Y)
		self.Frame.LineNumbers.TextSize = self.FontSize
	end
end

funcs.ProcessTextChange = function(self)
	local maxCols = 0
	local lines = self.Lines

	for i = 1, #lines do
		local lineLen = #lines[i]
		if lineLen > maxCols then maxCols = lineLen end
	end

	self.MaxTextCols = maxCols
	self:UpdateView()
	self.Text = table.concat(self.Lines, "\n")
	self:MapNewLines()
	self:PreHighlight()
	self:Refresh()
	--self.TextChanged:Fire()
end

-- Tabs are shown as tabReplacement in the editor so the cursor can step over them
funcs.ConvertText = function(self, text, toEditor)
	if toEditor then return (string.gsub(text, "\t", tabReplacement)) end
	return (string.gsub(text, tabReplacement, "\t"))
end

funcs.GetText = function(self) return self:ConvertText(table.concat(self.Lines, "\n"), false) end

funcs.SetText = function(self, txt)
	txt = string.gsub(txt, "\r\n?", "\n")
	txt = self:ConvertText(txt, true)

	local lines = self.Lines
	local split = string.split(txt, "\n")
	table.clear(lines)
	table.move(split, 1, #split, 1, lines)

	self:ProcessTextChange()
end

funcs.MakeRichTemplates = function(self)
	local floor = math.floor
	local templates = {}

	for name, color in pairs(self.Colors) do
		templates[name] = ('<font color="rgb(%s,%s,%s)">'):format(floor(color.R * 255), floor(color.G * 255), floor(color.B * 255))
	end

	self.RichTemplates = templates
end

funcs.ApplyTheme = function(self)
	local colors = Settings.Theme.Syntax
	self.Colors = colors
	self.Frame.LineNumbers.TextColor3 = colors.Text
	self.Frame.BackgroundColor3 = colors.Background
end

local mt = { __index = funcs }

local function new()
	if not builtInInited then initBuiltIn() end

	local scrollV = Lib.ScrollBar.new()
	local scrollH = Lib.ScrollBar.new(true)
	scrollH.Gui.Position = UDim2.new(0, 0, 1, -16)
	local obj = setmetatable({
		FontSize = 15,
		ViewX = 0,
		ViewY = 0,
		Colors = Settings.Theme.Syntax,
		ColoredLines = {},
		Lines = { "" },
		LineFrames = {},
		Editable = true,
		Editing = false,
		CursorX = 0,
		CursorY = 0,
		FloatCursorX = 0,
		Text = "",
		PreHighlights = {},
		SelectionRange = { { -1, -1 }, { -1, -1 } },
		NewLines = {},
		FrameOffsets = Vector2.new(0, 0),
		MaxTextCols = 0,
		ScrollV = scrollV,
		ScrollH = scrollH,
	}, mt)

	scrollV.WheelIncrement = 3
	scrollH.Increment = 2
	scrollH.WheelIncrement = 7

	scrollV.Scrolled:Connect(function()
		obj.ViewY = scrollV.Index
		obj:Refresh()
	end)

	scrollH.Scrolled:Connect(function()
		obj.ViewX = scrollH.Index
		obj:Refresh()
	end)

	makeFrame(obj)
	obj:MakeRichTemplates()
	obj:ApplyTheme()
	scrollV:SetScrollFrame(obj.Frame.Lines)
	scrollV.Gui.Parent = obj.Frame
	scrollH.Gui.Parent = obj.Frame

	obj:UpdateView()
	obj.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		obj:UpdateView()
		obj:Refresh()
	end)

	return obj
end

return { new = new }
end function __DARKDEX_MODULES.A()local v=__DARKDEX_MODULES.cache.A if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.A=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Lib = Context.Lib
local service = Context.service
local create = Create.create

local funcs = {}
local c3 = Color3.fromRGB
local v2 = Vector2.new
local ud2s = UDim2.fromScale
local ud2o = UDim2.fromOffset
local ud = UDim.new
local max = math.max
local new = Instance.new
local TweenSize = new("Frame").TweenSize
local ti = TweenInfo.new

local function ripple(object, color)
	local circle = new("Frame")
	circle.BackgroundColor3 = color
	circle.BackgroundTransparency = 0.75
	circle.BorderSizePixel = 0
	circle.AnchorPoint = v2(0.5, 0.5)
	circle.Size = ud2o()
	circle.Position = ud2s(0.5, 0.5)
	circle.Parent = object
	local rounding = new("UICorner")
	rounding.CornerRadius = ud(1)
	rounding.Parent = circle

	local abssz = object.AbsoluteSize
	local size = max(abssz.X, abssz.Y) * 5 / 3

	TweenSize(circle, ud2o(size, size), "Out", "Quart", 0.4)
	service.TweenService:Create(circle, ti(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()

	service.Debris:AddItem(circle, 0.4)
end

local function initGui(self, frame)
	local checkbox = frame
		or create({
			{ 1, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Checkbox", Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0, 16, 0, 16) } },
			{ 2, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ripples", Parent = { 1 }, Size = UDim2.new(1, 0, 1, 0) } },
			{ 3, "Frame", { BackgroundColor3 = Color3.new(0.10196078568697, 0.10196078568697, 0.10196078568697), BorderSizePixel = 0, Name = "outline", Parent = { 1 }, Size = UDim2.new(0, 16, 0, 16) } },
			{ 4, "Frame", { BackgroundColor3 = Color3.new(0.14117647707462, 0.14117647707462, 0.14117647707462), BorderSizePixel = 0, Name = "filler", Parent = { 3 }, Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(0, 14, 0, 14) } },
			{ 5, "Frame", { BackgroundColor3 = Color3.new(0.90196084976196, 0.90196084976196, 0.90196084976196), BorderSizePixel = 0, Name = "top", Parent = { 4 }, Size = UDim2.new(0, 16, 0, 0) } },
			{ 6, "Frame", { AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.new(0.90196084976196, 0.90196084976196, 0.90196084976196), BorderSizePixel = 0, Name = "bottom", Parent = { 4 }, Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(0, 16, 0, 0) } },
			{ 7, "Frame", { BackgroundColor3 = Color3.new(0.90196084976196, 0.90196084976196, 0.90196084976196), BorderSizePixel = 0, Name = "left", Parent = { 4 }, Size = UDim2.new(0, 0, 0, 16) } },
			{ 8, "Frame", { AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.new(0.90196084976196, 0.90196084976196, 0.90196084976196), BorderSizePixel = 0, Name = "right", Parent = { 4 }, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0, 0, 0, 16) } },
			{
				9,
				"Frame",
				{ AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Name = "checkmark", Parent = { 4 }, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 20) },
			},
			{
				10,
				"ImageLabel",
				{
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = "rbxassetid://6234266378",
					Parent = { 9 },
					Position = UDim2.new(0.5, 0, 0.5, 0),
					ScaleType = 3,
					Size = UDim2.new(0, 15, 0, 11),
				},
			},
			{
				11,
				"ImageLabel",
				{
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Image = "rbxassetid://6401617475",
					ImageColor3 = Color3.new(0.20784313976765, 0.69803923368454, 0.98431372642517),
					Name = "checkmark2",
					Parent = { 4 },
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Size = UDim2.new(0, 12, 0, 12),
					Visible = false,
				},
			},
			{
				12,
				"ImageLabel",
				{
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					Image = "rbxassetid://6425281788",
					ImageTransparency = 0.20000000298023,
					Name = "middle",
					Parent = { 4 },
					ScaleType = 2,
					Size = UDim2.new(1, 0, 1, 0),
					TileSize = UDim2.new(0, 2, 0, 2),
					Visible = false,
				},
			},
			{ 13, "UICorner", { CornerRadius = UDim.new(0, 2), Parent = { 3 } } },
		})
	local outline = checkbox.outline
	local filler = outline.filler
	local checkmark = filler.checkmark
	local ripples_container = checkbox.ripples

	-- walls
	local top, bottom, left, right = filler.top, filler.bottom, filler.left, filler.right

	self.Gui = checkbox
	self.GuiElems = {
		Top = top,
		Bottom = bottom,
		Left = left,
		Right = right,
		Outline = outline,
		Filler = filler,
		Checkmark = checkmark,
		Checkmark2 = filler.checkmark2,
		Middle = filler.middle,
	}

	checkbox.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			local release
			release = service.UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					release:Disconnect()

					if Lib.CheckMouseInGui(checkbox) then
						if self.Style == 0 then ripple(ripples_container, self.Disabled and self.Colors.Disabled or self.Colors.Primary) end

						if not self.Disabled then
							self:SetState(not self.Toggled, true)
						else
							self:Paint()
						end

						self.OnInput:Fire()
					end
				end
			end)
		end
	end)

	self:Paint()
end

funcs.Collapse = function(self, anim)
	local guiElems = self.GuiElems
	if anim then
		TweenSize(guiElems.Top, ud2o(14, 14), "In", "Quart", 4 / 15, true)
		TweenSize(guiElems.Bottom, ud2o(14, 14), "In", "Quart", 4 / 15, true)
		TweenSize(guiElems.Left, ud2o(14, 14), "In", "Quart", 4 / 15, true)
		TweenSize(guiElems.Right, ud2o(14, 14), "In", "Quart", 4 / 15, true)
	else
		guiElems.Top.Size = ud2o(14, 14)
		guiElems.Bottom.Size = ud2o(14, 14)
		guiElems.Left.Size = ud2o(14, 14)
		guiElems.Right.Size = ud2o(14, 14)
	end
end

funcs.Expand = function(self, anim)
	local guiElems = self.GuiElems
	if anim then
		TweenSize(guiElems.Top, ud2o(14, 0), "InOut", "Quart", 4 / 15, true)
		TweenSize(guiElems.Bottom, ud2o(14, 0), "InOut", "Quart", 4 / 15, true)
		TweenSize(guiElems.Left, ud2o(0, 14), "InOut", "Quart", 4 / 15, true)
		TweenSize(guiElems.Right, ud2o(0, 14), "InOut", "Quart", 4 / 15, true)
	else
		guiElems.Top.Size = ud2o(14, 0)
		guiElems.Bottom.Size = ud2o(14, 0)
		guiElems.Left.Size = ud2o(0, 14)
		guiElems.Right.Size = ud2o(0, 14)
	end
end

funcs.Paint = function(self)
	local guiElems = self.GuiElems

	if self.Style == 0 then
		local color_base = self.Disabled and self.Colors.Disabled
		guiElems.Outline.BackgroundColor3 = color_base or (self.Toggled and self.Colors.Primary) or self.Colors.Secondary
		local walls_color = color_base or self.Colors.Primary
		guiElems.Top.BackgroundColor3 = walls_color
		guiElems.Bottom.BackgroundColor3 = walls_color
		guiElems.Left.BackgroundColor3 = walls_color
		guiElems.Right.BackgroundColor3 = walls_color
	else
		guiElems.Outline.BackgroundColor3 = self.Disabled and self.Colors.Disabled or self.Colors.Secondary
		guiElems.Filler.BackgroundColor3 = self.Disabled and self.Colors.DisabledBackground or self.Colors.Background
		guiElems.Checkmark2.ImageColor3 = self.Disabled and self.Colors.DisabledCheck or self.Colors.Primary
	end
end

funcs.SetState = function(self, val, anim)
	self.Toggled = val

	if self.OutlineColorTween then self.OutlineColorTween:Cancel() end
	local setStateTime = os.clock()
	self.LastSetStateTime = setStateTime

	if self.Toggled then
		if self.Style == 0 then
			if anim then
				self.OutlineColorTween = service.TweenService:Create(self.GuiElems.Outline, ti(4 / 15, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), { BackgroundColor3 = self.Colors.Primary })
				self.OutlineColorTween:Play()
				task.delay(0.15, function()
					if setStateTime ~= self.LastSetStateTime then return end
					self:Paint()
					TweenSize(self.GuiElems.Checkmark, ud2o(14, 20), "Out", "Bounce", 2 / 15, true)
				end)
			else
				self.GuiElems.Outline.BackgroundColor3 = self.Colors.Primary
				self:Paint()
				self.GuiElems.Checkmark.Size = ud2o(14, 20)
			end
			self:Collapse(anim)
		else
			self:Paint()
			self.GuiElems.Checkmark2.Visible = true
			self.GuiElems.Middle.Visible = false
		end
	else
		if self.Style == 0 then
			if anim then
				self.OutlineColorTween = service.TweenService:Create(self.GuiElems.Outline, ti(4 / 15, Enum.EasingStyle.Circular, Enum.EasingDirection.In), { BackgroundColor3 = self.Colors.Secondary })
				self.OutlineColorTween:Play()
				task.delay(0.15, function()
					if setStateTime ~= self.LastSetStateTime then return end
					self:Paint()
					TweenSize(self.GuiElems.Checkmark, ud2o(0, 20), "Out", "Quad", 1 / 15, true)
				end)
			else
				self.GuiElems.Outline.BackgroundColor3 = self.Colors.Secondary
				self:Paint()
				self.GuiElems.Checkmark.Size = ud2o(0, 20)
			end
			self:Expand(anim)
		else
			self:Paint()
			self.GuiElems.Checkmark2.Visible = false
			self.GuiElems.Middle.Visible = self.Toggled == nil
		end
	end
end

local mt = { __index = funcs }

local function new(style)
	local obj = setmetatable({
		Toggled = false,
		Disabled = false,
		OnInput = Lib.Signal.new(),
		Style = style or 0,
		Colors = {
			Background = c3(36, 36, 36),
			Primary = c3(49, 176, 230),
			Secondary = c3(25, 25, 25),
			Disabled = c3(64, 64, 64),
			DisabledBackground = c3(52, 52, 52),
			DisabledCheck = c3(80, 80, 80),
		},
	}, mt)
	initGui(obj)
	return obj
end

return { new = new }
end function __DARKDEX_MODULES.B()local v=__DARKDEX_MODULES.cache.B if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.B=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Lib = Context.Lib
local service = Context.service
local create = Create.create

local funcs = {}
local mouse = service.Players.LocalPlayer:GetMouse()
local hexStartX = 4
local hexSizeX = 27
local hexTriangleStart = 1
local hexTriangleSize = 8

local bottomColors = {
	Color3.fromRGB(17, 17, 17),
	Color3.fromRGB(99, 95, 98),
	Color3.fromRGB(163, 162, 165),
	Color3.fromRGB(205, 205, 205),
	Color3.fromRGB(223, 223, 222),
	Color3.fromRGB(237, 234, 234),
	Color3.fromRGB(27, 42, 53),
	Color3.fromRGB(91, 93, 105),
	Color3.fromRGB(159, 161, 172),
	Color3.fromRGB(202, 203, 209),
	Color3.fromRGB(231, 231, 236),
	Color3.fromRGB(248, 248, 248),
}

local function isMouseInHexagon(hex)
	local relativeX = mouse.X - hex.AbsolutePosition.X
	local relativeY = mouse.Y - hex.AbsolutePosition.Y
	if relativeX >= hexStartX and relativeX < hexStartX + hexSizeX then
		relativeX = relativeX - 4
		local relativeWidth = (13 - math.min(relativeX, 26 - relativeX)) / 13
		if relativeY >= hexTriangleStart + hexTriangleSize * relativeWidth and relativeY < hex.AbsoluteSize.Y - hexTriangleStart - hexTriangleSize * relativeWidth then return true end
	end

	return false
end

local function hexInput(self, hex, color)
	hex.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and isMouseInHexagon(hex) then
			self.OnSelect:Fire(color)
			self:Close()
		end
	end)

	hex.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and isMouseInHexagon(hex) then self.OnPreview:Fire(color) end
	end)
end

local function createGui(self)
	local gui = create({
		{ 1, "ScreenGui", { Name = "BrickColor" } },
		{
			2,
			"Frame",
			{
				Active = true,
				BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799),
				BorderColor3 = Color3.new(0.1294117718935, 0.1294117718935, 0.1294117718935),
				Parent = { 1 },
				Position = UDim2.new(0.40000000596046, 0, 0.40000000596046, 0),
				Size = UDim2.new(0, 337, 0, 380),
			},
		},
		{
			3,
			"TextButton",
			{
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				BorderSizePixel = 0,
				Font = 3,
				Name = "MoreColors",
				Parent = { 2 },
				Position = UDim2.new(0, 5, 1, -30),
				Size = UDim2.new(1, -10, 0, 25),
				Text = "More Colors",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
			},
		},
		{
			4,
			"ImageLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = "rbxassetid://1281023007",
				ImageColor3 = Color3.new(0.33333334326744, 0.33333334326744, 0.49803924560547),
				Name = "Hex",
				Parent = { 2 },
				Size = UDim2.new(0, 35, 0, 35),
				Visible = false,
			},
		},
	})
	local colorFrame = gui.Frame
	local hex = colorFrame.Hex
	local paletteCount = 0

	for row = 1, 13 do
		local columns = math.min(row, 14 - row) + 6
		for column = 1, columns do
			local nextColor = BrickColor.palette(paletteCount).Color
			local newHex = hex:Clone()
			newHex.Position = UDim2.new(0, (column - 1) * 25 - (columns - 7) * 13 + 3 * 26 + 1, 0, (row - 1) * 23 + 4)
			newHex.ImageColor3 = nextColor
			newHex.Visible = true
			hexInput(self, newHex, nextColor)
			newHex.Parent = colorFrame
			paletteCount = paletteCount + 1
		end
	end

	for column = 1, 12 do
		local nextColor = bottomColors[column]
		local newHex = hex:Clone()
		newHex.Position = UDim2.new(0, (column - 1) * 25 - (12 - 7) * 13 + 3 * 26 + 3, 0, 308)
		newHex.ImageColor3 = nextColor
		newHex.Visible = true
		hexInput(self, newHex, nextColor)
		newHex.Parent = colorFrame
		paletteCount = paletteCount + 1
	end

	colorFrame.MoreColors.MouseButton1Click:Connect(function()
		self.OnMoreColors:Fire()
		self:Close()
	end)

	self.Gui = gui
end

funcs.SetMoreColorsVisible = function(self, vis)
	local colorFrame = self.Gui.Frame
	colorFrame.Size = UDim2.new(0, 337, 0, 380 - (not vis and 33 or 0))
	colorFrame.MoreColors.Visible = vis
end

funcs.Show = function(self, x, y, prevColor)
	self.PrevColor = prevColor or self.PrevColor

	local reverseY = false

	local x, y = x or mouse.X, y or mouse.Y
	local maxX, maxY = mouse.ViewSizeX, mouse.ViewSizeY
	Lib.ShowGui(self.Gui)
	local sizeX, sizeY = self.Gui.Frame.AbsoluteSize.X, self.Gui.Frame.AbsoluteSize.Y

	if x + sizeX > maxX then x = self.ReverseX and x - sizeX or maxX - sizeX end
	if y + sizeY > maxY then reverseY = true end

	local closable = false
	if self.CloseEvent then self.CloseEvent:Disconnect() end
	self.CloseEvent = service.UserInputService.InputBegan:Connect(function(input)
		if not closable or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		if not Lib.CheckMouseInGui(self.Gui.Frame) then self:Close() end
	end)

	if reverseY then
		local newY = y - sizeY - (self.ReverseYOffset or 0)
		y = newY >= 0 and newY or 0
	end

	self.Gui.Frame.Position = UDim2.new(0, x, 0, y)

	Lib.FastWait()
	closable = true
end

funcs.Close = function(self)
	if self.CloseEvent then
		self.CloseEvent:Disconnect()
		self.CloseEvent = nil
	end
	self.Gui.Parent = nil

	self.OnCancel:Fire()
end

local mt = { __index = funcs }

local function new()
	local obj = setmetatable({
		OnPreview = Lib.Signal.new(),
		OnSelect = Lib.Signal.new(),
		OnCancel = Lib.Signal.new(),
		OnMoreColors = Lib.Signal.new(),
		PrevColor = Color3.new(0, 0, 0),
	}, mt)
	createGui(obj)
	return obj
end

return { new = new }
end function __DARKDEX_MODULES.C()local v=__DARKDEX_MODULES.cache.C if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.C=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Lib = Context.Lib
local service = Context.service
local create = Create.create

-- TODO: Convert to newer class model
local funcs = {}

local function new()
	local newMt = setmetatable({}, {})

	newMt.OnSelect = Lib.Signal.new()
	newMt.OnCancel = Lib.Signal.new()
	newMt.OnPreview = Lib.Signal.new()

	local guiContents = create({
		{ 1, "Frame", { BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799), BorderSizePixel = 0, ClipsDescendants = true, Name = "Content", Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 1, -20) } },
		{ 2, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Name = "BasicColors", Parent = { 1 }, Position = UDim2.new(0, 5, 0, 5), Size = UDim2.new(0, 180, 0, 200) } },
		{
			3,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 2 },
				Position = UDim2.new(0, 0, 0, -5),
				Size = UDim2.new(1, 0, 0, 26),
				Text = "Basic Colors",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{
			4,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Blue",
				Parent = { 1 },
				Position = UDim2.new(1, -63, 0, 255),
				Size = UDim2.new(0, 52, 0, 16),
			},
		},
		{
			5,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				Font = 3,
				Name = "Input",
				Parent = { 4 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 50, 0, 16),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{ 6, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ArrowFrame", Parent = { 5 }, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0) } },
		{ 7, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Up", Parent = { 6 }, Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 8, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 7 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 9, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 8 }, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(0, 1, 0, 1) } },
		{ 10, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 8 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 11, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 8 }, Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 5, 0, 1) } },
		{ 12, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Down", Parent = { 6 }, Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 13, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 12 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 14, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 13 }, Position = UDim2.new(0, 8, 0, 5), Size = UDim2.new(0, 1, 0, 1) } },
		{ 15, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 13 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 16, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 13 }, Position = UDim2.new(0, 6, 0, 3), Size = UDim2.new(0, 5, 0, 1) } },
		{
			17,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 4 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Blue:",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{ 18, "Frame", { BackgroundColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506), BorderSizePixel = 0, ClipsDescendants = true, Name = "ColorSpaceFrame", Parent = { 1 }, Position = UDim2.new(1, -261, 0, 4), Size = UDim2.new(0, 222, 0, 202) } },
		{
			19,
			"ImageLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				BorderSizePixel = 0,
				Image = "rbxassetid://1072518406",
				Name = "ColorSpace",
				Parent = { 18 },
				Position = UDim2.new(0, 1, 0, 1),
				Size = UDim2.new(0, 220, 0, 200),
			},
		},
		{ 20, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Scope", Parent = { 19 }, Position = UDim2.new(0, 210, 0, 190), Size = UDim2.new(0, 20, 0, 20) } },
		{ 21, "Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Name = "Line", Parent = { 20 }, Position = UDim2.new(0, 9, 0, 0), Size = UDim2.new(0, 2, 0, 20) } },
		{ 22, "Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Name = "Line", Parent = { 20 }, Position = UDim2.new(0, 0, 0, 9), Size = UDim2.new(0, 20, 0, 2) } },
		{ 23, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Name = "CustomColors", Parent = { 1 }, Position = UDim2.new(0, 5, 0, 210), Size = UDim2.new(0, 180, 0, 90) } },
		{
			24,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 23 },
				Size = UDim2.new(1, 0, 0, 20),
				Text = "Custom Colors (RC = Set)",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{
			25,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Green",
				Parent = { 1 },
				Position = UDim2.new(1, -63, 0, 233),
				Size = UDim2.new(0, 52, 0, 16),
			},
		},
		{
			26,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				Font = 3,
				Name = "Input",
				Parent = { 25 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 50, 0, 16),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{ 27, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ArrowFrame", Parent = { 26 }, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0) } },
		{ 28, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Up", Parent = { 27 }, Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 29, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 28 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 30, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 29 }, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(0, 1, 0, 1) } },
		{ 31, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 29 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 32, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 29 }, Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 5, 0, 1) } },
		{ 33, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Down", Parent = { 27 }, Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 34, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 33 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 35, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 34 }, Position = UDim2.new(0, 8, 0, 5), Size = UDim2.new(0, 1, 0, 1) } },
		{ 36, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 34 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 37, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 34 }, Position = UDim2.new(0, 6, 0, 3), Size = UDim2.new(0, 5, 0, 1) } },
		{
			38,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 25 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Green:",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{
			39,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Hue",
				Parent = { 1 },
				Position = UDim2.new(1, -180, 0, 211),
				Size = UDim2.new(0, 52, 0, 16),
			},
		},
		{
			40,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				Font = 3,
				Name = "Input",
				Parent = { 39 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 50, 0, 16),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{ 41, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ArrowFrame", Parent = { 40 }, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0) } },
		{ 42, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Up", Parent = { 41 }, Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 43, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 42 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 44, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 43 }, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(0, 1, 0, 1) } },
		{ 45, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 43 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 46, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 43 }, Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 5, 0, 1) } },
		{ 47, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Down", Parent = { 41 }, Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 48, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 47 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 49, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 48 }, Position = UDim2.new(0, 8, 0, 5), Size = UDim2.new(0, 1, 0, 1) } },
		{ 50, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 48 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 51, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 48 }, Position = UDim2.new(0, 6, 0, 3), Size = UDim2.new(0, 5, 0, 1) } },
		{
			52,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 39 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Hue:",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{ 53, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506), Name = "Preview", Parent = { 1 }, Position = UDim2.new(1, -260, 0, 211), Size = UDim2.new(0, 35, 1, -245) } },
		{
			54,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Red",
				Parent = { 1 },
				Position = UDim2.new(1, -63, 0, 211),
				Size = UDim2.new(0, 52, 0, 16),
			},
		},
		{
			55,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				Font = 3,
				Name = "Input",
				Parent = { 54 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 50, 0, 16),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{ 56, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ArrowFrame", Parent = { 55 }, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0) } },
		{ 57, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Up", Parent = { 56 }, Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 58, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 57 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 59, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 58 }, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(0, 1, 0, 1) } },
		{ 60, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 58 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 61, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 58 }, Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 5, 0, 1) } },
		{ 62, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Down", Parent = { 56 }, Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 63, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 62 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 64, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 63 }, Position = UDim2.new(0, 8, 0, 5), Size = UDim2.new(0, 1, 0, 1) } },
		{ 65, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 63 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 66, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 63 }, Position = UDim2.new(0, 6, 0, 3), Size = UDim2.new(0, 5, 0, 1) } },
		{
			67,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 54 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Red:",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{
			68,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Sat",
				Parent = { 1 },
				Position = UDim2.new(1, -180, 0, 233),
				Size = UDim2.new(0, 52, 0, 16),
			},
		},
		{
			69,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				Font = 3,
				Name = "Input",
				Parent = { 68 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 50, 0, 16),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{ 70, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ArrowFrame", Parent = { 69 }, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0) } },
		{ 71, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Up", Parent = { 70 }, Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 72, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 71 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 73, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 72 }, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(0, 1, 0, 1) } },
		{ 74, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 72 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 75, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 72 }, Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 5, 0, 1) } },
		{ 76, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Down", Parent = { 70 }, Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 77, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 76 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 78, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 77 }, Position = UDim2.new(0, 8, 0, 5), Size = UDim2.new(0, 1, 0, 1) } },
		{ 79, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 77 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 80, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 77 }, Position = UDim2.new(0, 6, 0, 3), Size = UDim2.new(0, 5, 0, 1) } },
		{
			81,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 68 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Sat:",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{
			82,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Val",
				Parent = { 1 },
				Position = UDim2.new(1, -180, 0, 255),
				Size = UDim2.new(0, 52, 0, 16),
			},
		},
		{
			83,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				Font = 3,
				Name = "Input",
				Parent = { 82 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 50, 0, 16),
				Text = "255",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{ 84, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ArrowFrame", Parent = { 83 }, Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0) } },
		{ 85, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Up", Parent = { 84 }, Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 86, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 85 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 87, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 86 }, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(0, 1, 0, 1) } },
		{ 88, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 86 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 89, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 86 }, Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 5, 0, 1) } },
		{ 90, "TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = 3, Name = "Down", Parent = { 84 }, Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 8), Text = "", TextSize = 14 } },
		{ 91, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 90 }, Size = UDim2.new(0, 16, 0, 8) } },
		{ 92, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 91 }, Position = UDim2.new(0, 8, 0, 5), Size = UDim2.new(0, 1, 0, 1) } },
		{ 93, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 91 }, Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(0, 3, 0, 1) } },
		{ 94, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 91 }, Position = UDim2.new(0, 6, 0, 3), Size = UDim2.new(0, 5, 0, 1) } },
		{
			95,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 82 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Val:",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{
			96,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				Font = 3,
				Name = "Cancel",
				Parent = { 1 },
				Position = UDim2.new(1, -105, 1, -28),
				Size = UDim2.new(0, 100, 0, 25),
				Text = "Cancel",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
			},
		},
		{
			97,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				Font = 3,
				Name = "Ok",
				Parent = { 1 },
				Position = UDim2.new(1, -210, 1, -28),
				Size = UDim2.new(0, 100, 0, 25),
				Text = "OK",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
			},
		},
		{
			98,
			"ImageLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				Image = "rbxassetid://1072518502",
				Name = "ColorStrip",
				Parent = { 1 },
				Position = UDim2.new(1, -30, 0, 5),
				Size = UDim2.new(0, 13, 0, 200),
			},
		},
		{ 99, "Frame", { BackgroundColor3 = Color3.new(0.3137255012989, 0.3137255012989, 0.3137255012989), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "ArrowFrame", Parent = { 1 }, Position = UDim2.new(1, -16, 0, 1), Size = UDim2.new(0, 5, 0, 208) } },
		{ 100, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 99 }, Position = UDim2.new(0, -2, 0, -4), Size = UDim2.new(0, 8, 0, 16) } },
		{ 101, "Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = { 100 }, Position = UDim2.new(0, 2, 0, 8), Size = UDim2.new(0, 1, 0, 1) } },
		{ 102, "Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = { 100 }, Position = UDim2.new(0, 3, 0, 7), Size = UDim2.new(0, 1, 0, 3) } },
		{ 103, "Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = { 100 }, Position = UDim2.new(0, 4, 0, 6), Size = UDim2.new(0, 1, 0, 5) } },
		{ 104, "Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = { 100 }, Position = UDim2.new(0, 5, 0, 5), Size = UDim2.new(0, 1, 0, 7) } },
		{ 105, "Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = { 100 }, Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(0, 1, 0, 9) } },
	})
	local window = Lib.Window.new()
	window.Resizable = false
	window.Alignable = false
	window:SetTitle("Color Picker")
	window:Resize(450, 330)
	for i, v in pairs(guiContents:GetChildren()) do
		v.Parent = window.GuiElems.Content
	end
	newMt.Window = window
	newMt.Gui = window.Gui
	local pickerGui = window.Gui.Main
	local pickerTopBar = pickerGui.TopBar
	local pickerFrame = pickerGui.Content
	local colorSpace = pickerFrame.ColorSpaceFrame.ColorSpace
	local colorStrip = pickerFrame.ColorStrip
	local previewFrame = pickerFrame.Preview
	local basicColorsFrame = pickerFrame.BasicColors
	local customColorsFrame = pickerFrame.CustomColors
	local okButton = pickerFrame.Ok
	local cancelButton = pickerFrame.Cancel
	local closeButton = pickerTopBar.Close

	local colorScope = colorSpace.Scope
	local colorArrow = pickerFrame.ArrowFrame.Arrow

	local hueInput = pickerFrame.Hue.Input
	local satInput = pickerFrame.Sat.Input
	local valInput = pickerFrame.Val.Input

	local redInput = pickerFrame.Red.Input
	local greenInput = pickerFrame.Green.Input
	local blueInput = pickerFrame.Blue.Input

	local user = service.UserInputService
	local mouse = service.Players.LocalPlayer:GetMouse()

	local hue, sat, val = 0, 0, 1
	local red, green, blue = 1, 1, 1
	local chosenColor = Color3.new(0, 0, 0)

	local basicColors = {
		Color3.new(0, 0, 0),
		Color3.new(0.66666668653488, 0, 0),
		Color3.new(0, 0.33333334326744, 0),
		Color3.new(0.66666668653488, 0.33333334326744, 0),
		Color3.new(0, 0.66666668653488, 0),
		Color3.new(0.66666668653488, 0.66666668653488, 0),
		Color3.new(0, 1, 0),
		Color3.new(0.66666668653488, 1, 0),
		Color3.new(0, 0, 0.49803924560547),
		Color3.new(0.66666668653488, 0, 0.49803924560547),
		Color3.new(0, 0.33333334326744, 0.49803924560547),
		Color3.new(0.66666668653488, 0.33333334326744, 0.49803924560547),
		Color3.new(0, 0.66666668653488, 0.49803924560547),
		Color3.new(0.66666668653488, 0.66666668653488, 0.49803924560547),
		Color3.new(0, 1, 0.49803924560547),
		Color3.new(0.66666668653488, 1, 0.49803924560547),
		Color3.new(0, 0, 1),
		Color3.new(0.66666668653488, 0, 1),
		Color3.new(0, 0.33333334326744, 1),
		Color3.new(0.66666668653488, 0.33333334326744, 1),
		Color3.new(0, 0.66666668653488, 1),
		Color3.new(0.66666668653488, 0.66666668653488, 1),
		Color3.new(0, 1, 1),
		Color3.new(0.66666668653488, 1, 1),
		Color3.new(0.33333334326744, 0, 0),
		Color3.new(1, 0, 0),
		Color3.new(0.33333334326744, 0.33333334326744, 0),
		Color3.new(1, 0.33333334326744, 0),
		Color3.new(0.33333334326744, 0.66666668653488, 0),
		Color3.new(1, 0.66666668653488, 0),
		Color3.new(0.33333334326744, 1, 0),
		Color3.new(1, 1, 0),
		Color3.new(0.33333334326744, 0, 0.49803924560547),
		Color3.new(1, 0, 0.49803924560547),
		Color3.new(0.33333334326744, 0.33333334326744, 0.49803924560547),
		Color3.new(1, 0.33333334326744, 0.49803924560547),
		Color3.new(0.33333334326744, 0.66666668653488, 0.49803924560547),
		Color3.new(1, 0.66666668653488, 0.49803924560547),
		Color3.new(0.33333334326744, 1, 0.49803924560547),
		Color3.new(1, 1, 0.49803924560547),
		Color3.new(0.33333334326744, 0, 1),
		Color3.new(1, 0, 1),
		Color3.new(0.33333334326744, 0.33333334326744, 1),
		Color3.new(1, 0.33333334326744, 1),
		Color3.new(0.33333334326744, 0.66666668653488, 1),
		Color3.new(1, 0.66666668653488, 1),
		Color3.new(0.33333334326744, 1, 1),
		Color3.new(1, 1, 1),
	}
	local customColors = {}

	local function updateColor(noupdate)
		local relativeX, relativeY, relativeStripY = 219 - hue * 219, 199 - sat * 199, 199 - val * 199
		local hsvColor = Color3.fromHSV(hue, sat, val)

		if noupdate == 2 or not noupdate then
			hueInput.Text = tostring(math.ceil(359 * hue))
			satInput.Text = tostring(math.ceil(255 * sat))
			valInput.Text = tostring(math.floor(255 * val))
		end
		if noupdate == 1 or not noupdate then
			redInput.Text = tostring(math.floor(255 * red))
			greenInput.Text = tostring(math.floor(255 * green))
			blueInput.Text = tostring(math.floor(255 * blue))
		end

		chosenColor = Color3.new(red, green, blue)

		colorScope.Position = UDim2.new(0, relativeX - 9, 0, relativeY - 9)
		colorStrip.ImageColor3 = Color3.fromHSV(hue, sat, 1)
		colorArrow.Position = UDim2.new(0, -2, 0, relativeStripY - 4)
		previewFrame.BackgroundColor3 = chosenColor

		newMt.Color = chosenColor
		newMt.OnPreview:Fire(chosenColor)
	end

	local function colorSpaceInput()
		local relativeX = mouse.X - colorSpace.AbsolutePosition.X
		local relativeY = mouse.Y - colorSpace.AbsolutePosition.Y

		if relativeX < 0 then
			relativeX = 0
		elseif relativeX > 219 then
			relativeX = 219
		end
		if relativeY < 0 then
			relativeY = 0
		elseif relativeY > 199 then
			relativeY = 199
		end

		hue = (219 - relativeX) / 219
		sat = (199 - relativeY) / 199

		local hsvColor = Color3.fromHSV(hue, sat, val)
		red, green, blue = hsvColor.R, hsvColor.G, hsvColor.B

		updateColor()
	end

	local function colorStripInput()
		local relativeY = mouse.Y - colorStrip.AbsolutePosition.Y

		if relativeY < 0 then
			relativeY = 0
		elseif relativeY > 199 then
			relativeY = 199
		end

		val = (199 - relativeY) / 199

		local hsvColor = Color3.fromHSV(hue, sat, val)
		red, green, blue = hsvColor.R, hsvColor.G, hsvColor.B

		updateColor()
	end

	local function hookButtons(frame, func)
		frame.ArrowFrame.Up.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				frame.ArrowFrame.Up.BackgroundTransparency = 0.5
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				local releaseEvent, runEvent

				local startTime = os.clock()
				local pressing = true
				local startNum = tonumber(frame.Text)

				if not startNum then return end

				releaseEvent = user.InputEnded:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					releaseEvent:Disconnect()
					pressing = false
				end)

				startNum = startNum + 1
				func(startNum)
				while pressing do
					if os.clock() - startTime > 0.3 then
						startNum = startNum + 1
						func(startNum)
					end
					task.wait(0.1)
				end
			end
		end)

		frame.ArrowFrame.Up.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then frame.ArrowFrame.Up.BackgroundTransparency = 1 end
		end)

		frame.ArrowFrame.Down.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				frame.ArrowFrame.Down.BackgroundTransparency = 0.5
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				local releaseEvent, runEvent

				local startTime = os.clock()
				local pressing = true
				local startNum = tonumber(frame.Text)

				if not startNum then return end

				releaseEvent = user.InputEnded:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					releaseEvent:Disconnect()
					pressing = false
				end)

				startNum = startNum - 1
				func(startNum)
				while pressing do
					if os.clock() - startTime > 0.3 then
						startNum = startNum - 1
						func(startNum)
					end
					task.wait(0.1)
				end
			end
		end)

		frame.ArrowFrame.Down.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then frame.ArrowFrame.Down.BackgroundTransparency = 1 end
		end)
	end

	colorSpace.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local releaseEvent, mouseEvent

			releaseEvent = user.InputEnded:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				releaseEvent:Disconnect()
				mouseEvent:Disconnect()
			end)

			mouseEvent = user.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then colorSpaceInput() end
			end)

			colorSpaceInput()
		end
	end)

	colorStrip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local releaseEvent, mouseEvent

			releaseEvent = user.InputEnded:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				releaseEvent:Disconnect()
				mouseEvent:Disconnect()
			end)

			mouseEvent = user.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then colorStripInput() end
			end)

			colorStripInput()
		end
	end)

	local function updateHue(str)
		local num = tonumber(str)
		if num then
			hue = math.clamp(math.floor(num), 0, 359) / 359
			local hsvColor = Color3.fromHSV(hue, sat, val)
			red, green, blue = hsvColor.R, hsvColor.G, hsvColor.B
			hueInput.Text = tostring(hue * 359)
			updateColor(1)
		end
	end
	hueInput.FocusLost:Connect(function() updateHue(hueInput.Text) end)
	hookButtons(hueInput, updateHue)

	local function updateSat(str)
		local num = tonumber(str)
		if num then
			sat = math.clamp(math.floor(num), 0, 255) / 255
			local hsvColor = Color3.fromHSV(hue, sat, val)
			red, green, blue = hsvColor.R, hsvColor.G, hsvColor.B
			satInput.Text = tostring(sat * 255)
			updateColor(1)
		end
	end
	satInput.FocusLost:Connect(function() updateSat(satInput.Text) end)
	hookButtons(satInput, updateSat)

	local function updateVal(str)
		local num = tonumber(str)
		if num then
			val = math.clamp(math.floor(num), 0, 255) / 255
			local hsvColor = Color3.fromHSV(hue, sat, val)
			red, green, blue = hsvColor.R, hsvColor.G, hsvColor.B
			valInput.Text = tostring(val * 255)
			updateColor(1)
		end
	end
	valInput.FocusLost:Connect(function() updateVal(valInput.Text) end)
	hookButtons(valInput, updateVal)

	local function updateRed(str)
		local num = tonumber(str)
		if num then
			red = math.clamp(math.floor(num), 0, 255) / 255
			local newColor = Color3.new(red, green, blue)
			hue, sat, val = Color3.toHSV(newColor)
			redInput.Text = tostring(red * 255)
			updateColor(2)
		end
	end
	redInput.FocusLost:Connect(function() updateRed(redInput.Text) end)
	hookButtons(redInput, updateRed)

	local function updateGreen(str)
		local num = tonumber(str)
		if num then
			green = math.clamp(math.floor(num), 0, 255) / 255
			local newColor = Color3.new(red, green, blue)
			hue, sat, val = Color3.toHSV(newColor)
			greenInput.Text = tostring(green * 255)
			updateColor(2)
		end
	end
	greenInput.FocusLost:Connect(function() updateGreen(greenInput.Text) end)
	hookButtons(greenInput, updateGreen)

	local function updateBlue(str)
		local num = tonumber(str)
		if num then
			blue = math.clamp(math.floor(num), 0, 255) / 255
			local newColor = Color3.new(red, green, blue)
			hue, sat, val = Color3.toHSV(newColor)
			blueInput.Text = tostring(blue * 255)
			updateColor(2)
		end
	end
	blueInput.FocusLost:Connect(function() updateBlue(blueInput.Text) end)
	hookButtons(blueInput, updateBlue)

	local colorChoice = Instance.new("TextButton")
	colorChoice.Name = "Choice"
	colorChoice.Size = UDim2.new(0, 25, 0, 18)
	colorChoice.BorderColor3 = Color3.fromRGB(55, 55, 55)
	colorChoice.Text = ""
	colorChoice.AutoButtonColor = false

	local row = 0
	local column = 0
	for i, v in pairs(basicColors) do
		local newColor = colorChoice:Clone()
		newColor.BackgroundColor3 = v
		newColor.Position = UDim2.new(0, 1 + 30 * column, 0, 21 + 23 * row)

		newColor.MouseButton1Click:Connect(function()
			red, green, blue = v.R, v.G, v.B
			local newColor = Color3.new(red, green, blue)
			hue, sat, val = Color3.toHSV(newColor)
			updateColor()
		end)

		newColor.Parent = basicColorsFrame
		column = column + 1
		if column == 6 then
			row = row + 1
			column = 0
		end
	end

	row = 0
	column = 0
	for i = 1, 12 do
		local color = customColors[i] or Color3.new(0, 0, 0)
		local newColor = colorChoice:Clone()
		newColor.BackgroundColor3 = color
		newColor.Position = UDim2.new(0, 1 + 30 * column, 0, 20 + 23 * row)

		newColor.MouseButton1Click:Connect(function()
			local curColor = customColors[i] or Color3.new(0, 0, 0)
			red, green, blue = curColor.R, curColor.G, curColor.B
			hue, sat, val = Color3.toHSV(curColor)
			updateColor()
		end)

		newColor.MouseButton2Click:Connect(function()
			customColors[i] = chosenColor
			newColor.BackgroundColor3 = chosenColor
		end)

		newColor.Parent = customColorsFrame
		column = column + 1
		if column == 6 then
			row = row + 1
			column = 0
		end
	end

	okButton.MouseButton1Click:Connect(function()
		newMt.OnSelect:Fire(chosenColor)
		window:Close()
	end)
	okButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then okButton.BackgroundTransparency = 0.4 end
	end)
	okButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then okButton.BackgroundTransparency = 0 end
	end)

	cancelButton.MouseButton1Click:Connect(function()
		newMt.OnCancel:Fire()
		window:Close()
	end)
	cancelButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then cancelButton.BackgroundTransparency = 0.4 end
	end)
	cancelButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then cancelButton.BackgroundTransparency = 0 end
	end)

	updateColor()

	newMt.SetColor = function(self, color)
		red, green, blue = color.R, color.G, color.B
		hue, sat, val = Color3.toHSV(color)
		updateColor()
	end

	newMt.Show = function(self) self.Window:Show() end

	return newMt
end

return { new = new }
end function __DARKDEX_MODULES.D()local v=__DARKDEX_MODULES.cache.D if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.D=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Lib = Context.Lib
local service = Context.service
local create = Create.create

local function new() -- TODO: Convert to newer class model
	local newMt = setmetatable({}, {})
	newMt.OnSelect = Lib.Signal.new()
	newMt.OnCancel = Lib.Signal.new()
	newMt.OnPreview = Lib.Signal.new()

	local guiContents = create({
		{ 1, "Frame", { BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799), BorderSizePixel = 0, ClipsDescendants = true, Name = "Content", Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 1, -20) } },
		{
			2,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Time",
				Parent = { 1 },
				Position = UDim2.new(0, 40, 0, 210),
				Size = UDim2.new(0, 60, 0, 20),
			},
		},
		{
			3,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				ClipsDescendants = true,
				Font = 3,
				Name = "Input",
				Parent = { 2 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 58, 0, 20),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{
			4,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 2 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Time",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{
			5,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				Font = 3,
				Name = "Close",
				Parent = { 1 },
				Position = UDim2.new(1, -90, 0, 210),
				Size = UDim2.new(0, 80, 0, 20),
				Text = "Close",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
			},
		},
		{
			6,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				Font = 3,
				Name = "Reset",
				Parent = { 1 },
				Position = UDim2.new(1, -180, 0, 210),
				Size = UDim2.new(0, 80, 0, 20),
				Text = "Reset",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
			},
		},
		{
			7,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				Font = 3,
				Name = "Delete",
				Parent = { 1 },
				Position = UDim2.new(0, 380, 0, 210),
				Size = UDim2.new(0, 80, 0, 20),
				Text = "Delete",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
			},
		},
		{
			8,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				Name = "NumberLineOutlines",
				Parent = { 1 },
				Position = UDim2.new(0, 10, 0, 20),
				Size = UDim2.new(1, -20, 0, 170),
			},
		},
		{
			9,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				Name = "NumberLine",
				Parent = { 1 },
				Position = UDim2.new(0, 10, 0, 20),
				Size = UDim2.new(1, -20, 0, 170),
			},
		},
		{
			10,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Value",
				Parent = { 1 },
				Position = UDim2.new(0, 170, 0, 210),
				Size = UDim2.new(0, 60, 0, 20),
			},
		},
		{
			11,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 10 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Value",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{
			12,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				ClipsDescendants = true,
				Font = 3,
				Name = "Input",
				Parent = { 10 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 58, 0, 20),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{
			13,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Envelope",
				Parent = { 1 },
				Position = UDim2.new(0, 300, 0, 210),
				Size = UDim2.new(0, 60, 0, 20),
			},
		},
		{
			14,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				ClipsDescendants = true,
				Font = 3,
				Name = "Input",
				Parent = { 13 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 58, 0, 20),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{
			15,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 13 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Envelope",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
	})
	local window = Lib.Window.new()
	window.Resizable = false
	window:Resize(680, 265)
	window:SetTitle("NumberSequence Editor")
	newMt.Window = window
	newMt.Gui = window.Gui
	for i, v in pairs(guiContents:GetChildren()) do
		v.Parent = window.GuiElems.Content
	end
	local gui = window.Gui
	local pickerGui = gui.Main
	local pickerTopBar = pickerGui.TopBar
	local pickerFrame = pickerGui.Content
	local numberLine = pickerFrame.NumberLine
	local numberLineOutlines = pickerFrame.NumberLineOutlines
	local timeBox = pickerFrame.Time.Input
	local valueBox = pickerFrame.Value.Input
	local envelopeBox = pickerFrame.Envelope.Input
	local deleteButton = pickerFrame.Delete
	local resetButton = pickerFrame.Reset
	local closeButton = pickerFrame.Close
	local topClose = pickerTopBar.Close

	local points = { { 1, 0, 3 }, { 8, 0.05, 1 }, { 5, 0.6, 2 }, { 4, 0.7, 4 }, { 6, 1, 4 } }
	local lines = {}
	local eLines = {}
	local beginPoint = points[1]
	local endPoint = points[#points]
	local currentlySelected = nil
	local currentPoint = nil
	local resetSequence = nil

	local user = service.UserInputService
	local mouse = service.Players.LocalPlayer:GetMouse()

	for i = 2, 10 do
		local newLine = Instance.new("Frame")
		newLine.BackgroundTransparency = 0.5
		newLine.BackgroundColor3 = Color3.new(96 / 255, 96 / 255, 96 / 255)
		newLine.BorderSizePixel = 0
		newLine.Size = UDim2.new(0, 1, 1, 0)
		newLine.Position = UDim2.new((i - 1) / (11 - 1), 0, 0, 0)
		newLine.Parent = numberLineOutlines
	end

	for i = 2, 4 do
		local newLine = Instance.new("Frame")
		newLine.BackgroundTransparency = 0.5
		newLine.BackgroundColor3 = Color3.new(96 / 255, 96 / 255, 96 / 255)
		newLine.BorderSizePixel = 0
		newLine.Size = UDim2.new(1, 0, 0, 1)
		newLine.Position = UDim2.new(0, 0, (i - 1) / (5 - 1), 0)
		newLine.Parent = numberLineOutlines
	end

	local lineTemp = Instance.new("Frame")
	lineTemp.BackgroundColor3 = Color3.new(0, 0, 0)
	lineTemp.BorderSizePixel = 0
	lineTemp.Size = UDim2.new(0, 1, 0, 1)

	local sequenceLine = Instance.new("Frame")
	sequenceLine.BackgroundColor3 = Color3.new(0, 0, 0)
	sequenceLine.BorderSizePixel = 0
	sequenceLine.Size = UDim2.new(0, 1, 0, 0)

	for i = 1, numberLine.AbsoluteSize.X do
		local line = sequenceLine:Clone()
		eLines[i] = line
		line.Name = "E" .. tostring(i)
		line.BackgroundTransparency = 0.5
		line.BackgroundColor3 = Color3.new(199 / 255, 44 / 255, 28 / 255)
		line.Position = UDim2.new(0, i - 1, 0, 0)
		line.Parent = numberLine
	end

	for i = 1, numberLine.AbsoluteSize.X do
		local line = sequenceLine:Clone()
		lines[i] = line
		line.Name = tostring(i)
		line.Position = UDim2.new(0, i - 1, 0, 0)
		line.Parent = numberLine
	end

	local envelopeDrag = Instance.new("Frame")
	envelopeDrag.BackgroundTransparency = 1
	envelopeDrag.BackgroundColor3 = Color3.new(0, 0, 0)
	envelopeDrag.BorderSizePixel = 0
	envelopeDrag.Size = UDim2.new(0, 7, 0, 20)
	envelopeDrag.Visible = false
	envelopeDrag.ZIndex = 2
	local envelopeDragLine = Instance.new("Frame")
	envelopeDragLine.Name = "Line"
	envelopeDragLine.BackgroundColor3 = Color3.new(0, 0, 0)
	envelopeDragLine.BorderSizePixel = 0
	envelopeDragLine.Position = UDim2.new(0, 3, 0, 0)
	envelopeDragLine.Size = UDim2.new(0, 1, 0, 20)
	envelopeDragLine.ZIndex = 2
	envelopeDragLine.Parent = envelopeDrag

	local envelopeDragTop, envelopeDragBottom = envelopeDrag:Clone(), envelopeDrag:Clone()
	envelopeDragTop.Parent = numberLine
	envelopeDragBottom.Parent = numberLine

	local function buildSequence()
		local newPoints = {}
		for i, v in pairs(points) do
			table.insert(newPoints, NumberSequenceKeypoint.new(v[2], v[1], v[3]))
		end
		newMt.Sequence = NumberSequence.new(newPoints)
		newMt.OnSelect:Fire(newMt.Sequence)
	end

	local function round(num, places)
		local multi = 10 ^ places
		return math.floor(num * multi + 0.5) / multi
	end

	local function updateInputs(point)
		if point then
			currentPoint = point
			local rawT, rawV, rawE = point[2], point[1], point[3]
			timeBox.Text = round(rawT, (rawT < 0.01 and 5) or (rawT < 0.1 and 4) or 3)
			valueBox.Text = round(rawV, (rawV < 0.01 and 5) or (rawV < 0.1 and 4) or (rawV < 1 and 3) or 2)
			envelopeBox.Text = round(rawE, (rawE < 0.01 and 5) or (rawE < 0.1 and 4) or (rawV < 1 and 3) or 2)

			local envelopeDistance = numberLine.AbsoluteSize.Y * (point[3] / 10)
			envelopeDragTop.Position = UDim2.new(0, point[4].Position.X.Offset - 1, 0, point[4].Position.Y.Offset - envelopeDistance - 17)
			envelopeDragTop.Visible = true
			envelopeDragBottom.Position = UDim2.new(0, point[4].Position.X.Offset - 1, 0, point[4].Position.Y.Offset + envelopeDistance + 2)
			envelopeDragBottom.Visible = true
		end
	end

	envelopeDragTop.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not currentPoint or Lib.CheckMouseInGui(currentPoint[4].Select) then return end
		local mouseEvent, releaseEvent
		local maxSize = numberLine.AbsoluteSize.Y

		local mouseDelta = math.abs(envelopeDragTop.AbsolutePosition.Y - mouse.Y)

		envelopeDragTop.Line.Position = UDim2.new(0, 2, 0, 0)
		envelopeDragTop.Line.Size = UDim2.new(0, 3, 0, 20)

		releaseEvent = user.InputEnded:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			mouseEvent:Disconnect()
			releaseEvent:Disconnect()
			envelopeDragTop.Line.Position = UDim2.new(0, 3, 0, 0)
			envelopeDragTop.Line.Size = UDim2.new(0, 1, 0, 20)
		end)

		mouseEvent = user.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local topDiff = (currentPoint[4].AbsolutePosition.Y + 2) - (mouse.Y - mouseDelta) - 19
				local newEnvelope = 10 * (math.max(topDiff, 0) / maxSize)
				local maxEnvelope = math.min(currentPoint[1], 10 - currentPoint[1])
				currentPoint[3] = math.min(newEnvelope, maxEnvelope)
				newMt:Redraw()
				buildSequence()
				updateInputs(currentPoint)
			end
		end)
	end)

	envelopeDragBottom.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not currentPoint or Lib.CheckMouseInGui(currentPoint[4].Select) then return end
		local mouseEvent, releaseEvent
		local maxSize = numberLine.AbsoluteSize.Y

		local mouseDelta = math.abs(envelopeDragBottom.AbsolutePosition.Y - mouse.Y)

		envelopeDragBottom.Line.Position = UDim2.new(0, 2, 0, 0)
		envelopeDragBottom.Line.Size = UDim2.new(0, 3, 0, 20)

		releaseEvent = user.InputEnded:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			mouseEvent:Disconnect()
			releaseEvent:Disconnect()
			envelopeDragBottom.Line.Position = UDim2.new(0, 3, 0, 0)
			envelopeDragBottom.Line.Size = UDim2.new(0, 1, 0, 20)
		end)

		mouseEvent = user.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local bottomDiff = (mouse.Y + (20 - mouseDelta)) - (currentPoint[4].AbsolutePosition.Y + 2) - 19
				local newEnvelope = 10 * (math.max(bottomDiff, 0) / maxSize)
				local maxEnvelope = math.min(currentPoint[1], 10 - currentPoint[1])
				currentPoint[3] = math.min(newEnvelope, maxEnvelope)
				newMt:Redraw()
				buildSequence()
				updateInputs(currentPoint)
			end
		end)
	end)

	local function placePoint(point)
		local newPoint = Instance.new("Frame")
		newPoint.Name = "Point"
		newPoint.BorderSizePixel = 0
		newPoint.Size = UDim2.new(0, 5, 0, 5)
		newPoint.Position = UDim2.new(0, math.floor((numberLine.AbsoluteSize.X - 1) * point[2]) - 2, 0, numberLine.AbsoluteSize.Y * (10 - point[1]) / 10 - 2)
		newPoint.BackgroundColor3 = Color3.new(0, 0, 0)

		local newSelect = Instance.new("Frame")
		newSelect.Name = "Select"
		newSelect.BackgroundTransparency = 1
		newSelect.BackgroundColor3 = Color3.new(199 / 255, 44 / 255, 28 / 255)
		newSelect.Position = UDim2.new(0, -2, 0, -2)
		newSelect.Size = UDim2.new(0, 9, 0, 9)
		newSelect.Parent = newPoint

		newPoint.Parent = numberLine

		newSelect.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				for i, v in pairs(points) do
					v[4].Select.BackgroundTransparency = 1
				end
				newSelect.BackgroundTransparency = 0
				updateInputs(point)
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not currentlySelected then
				currentPoint = point
				local mouseEvent, releaseEvent
				currentlySelected = true
				newSelect.BackgroundColor3 = Color3.new(249 / 255, 191 / 255, 59 / 255)

				local oldEnvelope = point[3]

				releaseEvent = user.InputEnded:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					mouseEvent:Disconnect()
					releaseEvent:Disconnect()
					currentlySelected = nil
					newSelect.BackgroundColor3 = Color3.new(199 / 255, 44 / 255, 28 / 255)
				end)

				mouseEvent = user.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement then
						local maxX = numberLine.AbsoluteSize.X - 1
						local relativeX = mouse.X - numberLine.AbsolutePosition.X
						if relativeX < 0 then relativeX = 0 end
						if relativeX > maxX then relativeX = maxX end
						local maxY = numberLine.AbsoluteSize.Y - 1
						local relativeY = mouse.Y - numberLine.AbsolutePosition.Y
						if relativeY < 0 then relativeY = 0 end
						if relativeY > maxY then relativeY = maxY end
						if point ~= beginPoint and point ~= endPoint then point[2] = relativeX / maxX end
						point[1] = 10 - (relativeY / maxY) * 10
						local maxEnvelope = math.min(point[1], 10 - point[1])
						point[3] = math.min(oldEnvelope, maxEnvelope)
						newMt:Redraw()
						updateInputs(point)
						for i, v in pairs(points) do
							v[4].Select.BackgroundTransparency = 1
						end
						newSelect.BackgroundTransparency = 0
						buildSequence()
					end
				end)
			end
		end)

		return newPoint
	end

	local function placePoints()
		for i, v in pairs(points) do
			v[4] = placePoint(v)
		end
	end

	local function redraw(self)
		local numberLineSize = numberLine.AbsoluteSize
		table.sort(points, function(a, b) return a[2] < b[2] end)
		for i, v in pairs(points) do
			v[4].Position = UDim2.new(0, math.floor((numberLineSize.X - 1) * v[2]) - 2, 0, (numberLineSize.Y - 1) * (10 - v[1]) / 10 - 2)
		end
		lines[1].Size = UDim2.new(0, 1, 0, 0)
		for i = 1, #points - 1 do
			local fromPoint = points[i]
			local toPoint = points[i + 1]
			local deltaY = toPoint[4].Position.Y.Offset - fromPoint[4].Position.Y.Offset
			local deltaX = toPoint[4].Position.X.Offset - fromPoint[4].Position.X.Offset
			local slope = deltaY / deltaX

			local fromEnvelope = fromPoint[3]
			local nextEnvelope = toPoint[3]

			local currentRise = math.abs(slope)
			local totalRise = 0
			local maxRise = math.abs(toPoint[4].Position.Y.Offset - fromPoint[4].Position.Y.Offset)

			for lineCount = math.min(fromPoint[4].Position.X.Offset + 1, toPoint[4].Position.X.Offset), toPoint[4].Position.X.Offset do
				if deltaX == 0 and deltaY == 0 then return end
				local riseNow = math.floor(currentRise)
				local line = lines[lineCount + 3]
				if line then
					if totalRise + riseNow > maxRise then riseNow = maxRise - totalRise end
					if math.sign(slope) == -1 then
						line.Position = UDim2.new(0, lineCount + 2, 0, fromPoint[4].Position.Y.Offset + -(totalRise + riseNow) + 2)
					else
						line.Position = UDim2.new(0, lineCount + 2, 0, fromPoint[4].Position.Y.Offset + totalRise + 2)
					end
					line.Size = UDim2.new(0, 1, 0, math.max(riseNow, 1))
				end
				totalRise = totalRise + riseNow
				currentRise = currentRise - riseNow + math.abs(slope)

				local envPercent = (lineCount - fromPoint[4].Position.X.Offset) / (toPoint[4].Position.X.Offset - fromPoint[4].Position.X.Offset)
				local envLerp = fromEnvelope + (nextEnvelope - fromEnvelope) * envPercent
				local relativeSize = (envLerp / 10) * numberLineSize.Y

				local line = eLines[lineCount + 3]
				if line then
					line.Position = UDim2.new(0, lineCount + 2, 0, lines[lineCount + 3].Position.Y.Offset - math.floor(relativeSize))
					line.Size = UDim2.new(0, 1, 0, math.floor(relativeSize * 2))
				end
			end
		end
	end
	newMt.Redraw = redraw

	local function loadSequence(self, seq)
		resetSequence = seq
		for i, v in pairs(points) do
			if v[4] then v[4]:Destroy() end
		end
		points = {}
		for i, v in pairs(seq.Keypoints) do
			local maxEnvelope = math.min(v.Value, 10 - v.Value)
			local newPoint = { v.Value, v.Time, math.min(v.Envelope, maxEnvelope) }
			newPoint[4] = placePoint(newPoint)
			table.insert(points, newPoint)
		end
		beginPoint = points[1]
		endPoint = points[#points]
		currentlySelected = nil
		redraw()
		envelopeDragTop.Visible = false
		envelopeDragBottom.Visible = false
	end
	newMt.SetSequence = loadSequence

	timeBox.FocusLost:Connect(function()
		local point = currentPoint
		local num = tonumber(timeBox.Text)
		if point and num and point ~= beginPoint and point ~= endPoint then
			num = math.clamp(num, 0, 1)
			point[2] = num
			redraw()
			buildSequence()
			updateInputs(point)
		end
	end)

	valueBox.FocusLost:Connect(function()
		local point = currentPoint
		local num = tonumber(valueBox.Text)
		if point and num then
			local oldEnvelope = point[3]
			num = math.clamp(num, 0, 10)
			point[1] = num
			local maxEnvelope = math.min(point[1], 10 - point[1])
			point[3] = math.min(oldEnvelope, maxEnvelope)
			redraw()
			buildSequence()
			updateInputs(point)
		end
	end)

	envelopeBox.FocusLost:Connect(function()
		local point = currentPoint
		local num = tonumber(envelopeBox.Text)
		if point and num then
			num = math.clamp(num, 0, 5)
			local maxEnvelope = math.min(point[1], 10 - point[1])
			point[3] = math.min(num, maxEnvelope)
			redraw()
			buildSequence()
			updateInputs(point)
		end
	end)

	local function buttonAnimations(button, inverse)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then button.BackgroundTransparency = (inverse and 0.5 or 0.4) end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then button.BackgroundTransparency = (inverse and 1 or 0) end
		end)
	end

	numberLine.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and #points < 20 then
			if Lib.CheckMouseInGui(envelopeDragTop) or Lib.CheckMouseInGui(envelopeDragBottom) then return end
			for i, v in pairs(points) do
				if Lib.CheckMouseInGui(v[4].Select) then return end
			end
			local maxX = numberLine.AbsoluteSize.X - 1
			local relativeX = mouse.X - numberLine.AbsolutePosition.X
			if relativeX < 0 then relativeX = 0 end
			if relativeX > maxX then relativeX = maxX end
			local maxY = numberLine.AbsoluteSize.Y - 1
			local relativeY = mouse.Y - numberLine.AbsolutePosition.Y
			if relativeY < 0 then relativeY = 0 end
			if relativeY > maxY then relativeY = maxY end

			local raw = relativeX / maxX
			local newPoint = { 10 - (relativeY / maxY) * 10, raw, 0 }
			newPoint[4] = placePoint(newPoint)
			table.insert(points, newPoint)
			redraw()
			buildSequence()
		end
	end)

	deleteButton.MouseButton1Click:Connect(function()
		if currentPoint and currentPoint ~= beginPoint and currentPoint ~= endPoint then
			for i, v in pairs(points) do
				if v == currentPoint then
					v[4]:Destroy()
					table.remove(points, i)
					break
				end
			end
			currentlySelected = nil
			redraw()
			buildSequence()
			updateInputs(points[1])
		end
	end)

	resetButton.MouseButton1Click:Connect(function()
		if resetSequence then
			newMt:SetSequence(resetSequence)
			buildSequence()
		end
	end)

	closeButton.MouseButton1Click:Connect(function() window:Close() end)

	buttonAnimations(deleteButton)
	buttonAnimations(resetButton)
	buttonAnimations(closeButton)

	placePoints()
	redraw()

	newMt.Show = function(self) window:Show() end

	return newMt
end

return { new = new }
end function __DARKDEX_MODULES.E()local v=__DARKDEX_MODULES.cache.E if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.E=v end return v.c end end do local function __modImpl()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Lib = Context.Lib
local service = Context.service
local create = Create.create

-- TODO: Convert to newer class model
local function new()
	local newMt = setmetatable({}, {})
	newMt.OnSelect = Lib.Signal.new()
	newMt.OnCancel = Lib.Signal.new()
	newMt.OnPreview = Lib.Signal.new()
	newMt.OnPickColor = Lib.Signal.new()

	local guiContents = create({
		{ 1, "Frame", { BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799), BorderSizePixel = 0, ClipsDescendants = true, Name = "Content", Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 1, -20) } },
		{
			2,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.17647059261799, 0.17647059261799, 0.17647059261799),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				Name = "ColorLine",
				Parent = { 1 },
				Position = UDim2.new(0, 10, 0, 5),
				Size = UDim2.new(1, -20, 0, 70),
			},
		},
		{ 3, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Gradient", Parent = { 2 }, Size = UDim2.new(1, 0, 1, 0) } },
		{ 4, "UIGradient", { Parent = { 3 } } },
		{ 5, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Name = "Arrows", Parent = { 1 }, Position = UDim2.new(0, 1, 0, 73), Size = UDim2.new(1, -2, 0, 16) } },
		{ 6, "Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Name = "Cursor", Parent = { 1 }, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 1, 0, 80) } },
		{
			7,
			"Frame",
			{
				BackgroundColor3 = Color3.new(0.14901961386204, 0.14901961386204, 0.14901961386204),
				BorderColor3 = Color3.new(0.12549020349979, 0.12549020349979, 0.12549020349979),
				Name = "Time",
				Parent = { 1 },
				Position = UDim2.new(0, 40, 0, 95),
				Size = UDim2.new(0, 100, 0, 20),
			},
		},
		{
			8,
			"TextBox",
			{
				BackgroundColor3 = Color3.new(0.25098040699959, 0.25098040699959, 0.25098040699959),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.new(0.37647062540054, 0.37647062540054, 0.37647062540054),
				ClipsDescendants = true,
				Font = 3,
				Name = "Input",
				Parent = { 7 },
				Position = UDim2.new(0, 2, 0, 0),
				Size = UDim2.new(0, 98, 0, 20),
				Text = "0",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 0,
			},
		},
		{
			9,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 7 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Time",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{ 10, "Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506), Name = "ColorBox", Parent = { 1 }, Position = UDim2.new(0, 220, 0, 95), Size = UDim2.new(0, 20, 0, 20) } },
		{
			11,
			"TextLabel",
			{
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Font = 3,
				Name = "Title",
				Parent = { 10 },
				Position = UDim2.new(0, -40, 0, 0),
				Size = UDim2.new(0, 34, 1, 0),
				Text = "Color",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
				TextXAlignment = 1,
			},
		},
		{
			12,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				BorderSizePixel = 0,
				Font = 3,
				Name = "Close",
				Parent = { 1 },
				Position = UDim2.new(1, -90, 0, 95),
				Size = UDim2.new(0, 80, 0, 20),
				Text = "Close",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
			},
		},
		{
			13,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				BorderSizePixel = 0,
				Font = 3,
				Name = "Reset",
				Parent = { 1 },
				Position = UDim2.new(1, -180, 0, 95),
				Size = UDim2.new(0, 80, 0, 20),
				Text = "Reset",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
			},
		},
		{
			14,
			"TextButton",
			{
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0.2352941185236, 0.2352941185236, 0.2352941185236),
				BorderColor3 = Color3.new(0.21568627655506, 0.21568627655506, 0.21568627655506),
				BorderSizePixel = 0,
				Font = 3,
				Name = "Delete",
				Parent = { 1 },
				Position = UDim2.new(0, 280, 0, 95),
				Size = UDim2.new(0, 80, 0, 20),
				Text = "Delete",
				TextColor3 = Color3.new(0.86274516582489, 0.86274516582489, 0.86274516582489),
				TextSize = 14,
			},
		},
		{ 15, "Frame", { BackgroundTransparency = 1, Name = "Arrow", Parent = { 1 }, Size = UDim2.new(0, 16, 0, 16), Visible = false } },
		{ 16, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 15 }, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(0, 1, 0, 2) } },
		{ 17, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 15 }, Position = UDim2.new(0, 7, 0, 5), Size = UDim2.new(0, 3, 0, 2) } },
		{ 18, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 15 }, Position = UDim2.new(0, 6, 0, 7), Size = UDim2.new(0, 5, 0, 2) } },
		{ 19, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 15 }, Position = UDim2.new(0, 5, 0, 9), Size = UDim2.new(0, 7, 0, 2) } },
		{ 20, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 15 }, Position = UDim2.new(0, 4, 0, 11), Size = UDim2.new(0, 9, 0, 2) } },
	})
	local window = Lib.Window.new()
	window.Resizable = false
	window:Resize(650, 150)
	window:SetTitle("ColorSequence Editor")
	newMt.Window = window
	newMt.Gui = window.Gui
	for i, v in pairs(guiContents:GetChildren()) do
		v.Parent = window.GuiElems.Content
	end
	local gui = window.Gui
	local pickerGui = gui.Main
	local pickerTopBar = pickerGui.TopBar
	local pickerFrame = pickerGui.Content
	local colorLine = pickerFrame.ColorLine
	local gradient = colorLine.Gradient.UIGradient
	local arrowFrame = pickerFrame.Arrows
	local arrow = pickerFrame.Arrow
	local cursor = pickerFrame.Cursor
	local timeBox = pickerFrame.Time.Input
	local colorBox = pickerFrame.ColorBox
	local deleteButton = pickerFrame.Delete
	local resetButton = pickerFrame.Reset
	local closeButton = pickerFrame.Close
	local topClose = pickerTopBar.Close

	local user = service.UserInputService
	local mouse = service.Players.LocalPlayer:GetMouse()

	local colors = { { Color3.new(1, 0, 1), 0 }, { Color3.new(0.2, 0.9, 0.2), 0.2 }, { Color3.new(0.4, 0.5, 0.9), 0.7 }, { Color3.new(0.6, 1, 1), 1 } }
	local resetSequence = nil

	local beginPoint = colors[1]
	local endPoint = colors[#colors]

	local currentlySelected = nil
	local currentPoint = nil

	local sequenceLine = Instance.new("Frame")
	sequenceLine.BorderSizePixel = 0
	sequenceLine.Size = UDim2.new(0, 1, 1, 0)

	newMt.Sequence = ColorSequence.new(Color3.new(1, 1, 1))
	local function buildSequence(noupdate)
		local newPoints = {}
		table.sort(colors, function(a, b) return a[2] < b[2] end)
		for i, v in pairs(colors) do
			table.insert(newPoints, ColorSequenceKeypoint.new(v[2], v[1]))
		end
		newMt.Sequence = ColorSequence.new(newPoints)
		if not noupdate then newMt.OnSelect:Fire(newMt.Sequence) end
	end

	local function round(num, places)
		local multi = 10 ^ places
		return math.floor(num * multi + 0.5) / multi
	end

	local function updateInputs(point)
		if point then
			currentPoint = point
			local raw = point[2]
			timeBox.Text = round(raw, (raw < 0.01 and 5) or (raw < 0.1 and 4) or 3)
			colorBox.BackgroundColor3 = point[1]
		end
	end

	local function placeArrow(ind, point)
		local newArrow = arrow:Clone()
		newArrow.Position = UDim2.new(0, ind - 1, 0, 0)
		newArrow.Visible = true
		newArrow.Parent = arrowFrame

		newArrow.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				cursor.Visible = true
				cursor.Position = UDim2.new(0, 9 + newArrow.Position.X.Offset, 0, 0)
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				updateInputs(point)
				if point == beginPoint or point == endPoint or currentlySelected then return end

				local mouseEvent, releaseEvent
				currentlySelected = true

				releaseEvent = user.InputEnded:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					mouseEvent:Disconnect()
					releaseEvent:Disconnect()
					currentlySelected = nil
					cursor.Visible = false
				end)

				mouseEvent = user.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement then
						local maxSize = colorLine.AbsoluteSize.X - 1
						local relativeX = mouse.X - colorLine.AbsolutePosition.X
						if relativeX < 0 then relativeX = 0 end
						if relativeX > maxSize then relativeX = maxSize end
						local raw = relativeX / maxSize
						point[2] = relativeX / maxSize
						updateInputs(point)
						cursor.Visible = true
						cursor.Position = UDim2.new(0, 9 + newArrow.Position.X.Offset, 0, 0)
						buildSequence()
						newMt:Redraw()
					end
				end)
			end
		end)

		newArrow.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then cursor.Visible = false end
		end)

		return newArrow
	end

	local function placeArrows()
		for i, v in pairs(colors) do
			v[3] = placeArrow(math.floor((colorLine.AbsoluteSize.X - 1) * v[2]) + 1, v)
		end
	end

	local function redraw(self)
		gradient.Color = newMt.Sequence or ColorSequence.new(Color3.new(1, 1, 1))

		for i = 2, #colors do
			local nextColor = colors[i]
			local endPos = math.floor((colorLine.AbsoluteSize.X - 1) * nextColor[2]) + 1
			nextColor[3].Position = UDim2.new(0, endPos, 0, 0)
		end
	end
	newMt.Redraw = redraw

	local function loadSequence(self, seq)
		resetSequence = seq
		for i, v in pairs(colors) do
			if v[3] then v[3]:Destroy() end
		end
		colors = {}
		currentlySelected = nil
		for i, v in pairs(seq.Keypoints) do
			local newPoint = { v.Value, v.Time }
			newPoint[3] = placeArrow(v.Time, newPoint)
			table.insert(colors, newPoint)
		end
		beginPoint = colors[1]
		endPoint = colors[#colors]
		currentlySelected = nil
		updateInputs(colors[1])
		buildSequence(true)
		redraw()
	end
	newMt.SetSequence = loadSequence

	local function buttonAnimations(button, inverse)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then button.BackgroundTransparency = (inverse and 0.5 or 0.4) end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then button.BackgroundTransparency = (inverse and 1 or 0) end
		end)
	end

	colorLine.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and #colors < 20 then
			local maxSize = colorLine.AbsoluteSize.X - 1
			local relativeX = mouse.X - colorLine.AbsolutePosition.X
			if relativeX < 0 then relativeX = 0 end
			if relativeX > maxSize then relativeX = maxSize end

			local raw = relativeX / maxSize
			local fromColor = nil
			local toColor = nil
			for i, col in pairs(colors) do
				if col[2] >= raw then
					fromColor = colors[math.max(i - 1, 1)]
					toColor = colors[i]
					break
				end
			end
			local lerpColor = fromColor[1]:lerp(toColor[1], (raw - fromColor[2]) / (toColor[2] - fromColor[2]))
			local newPoint = { lerpColor, raw }
			newPoint[3] = placeArrow(newPoint[2], newPoint)
			table.insert(colors, newPoint)
			updateInputs(newPoint)
			buildSequence()
			redraw()
		end
	end)

	colorLine.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local maxSize = colorLine.AbsoluteSize.X - 1
			local relativeX = mouse.X - colorLine.AbsolutePosition.X
			if relativeX < 0 then relativeX = 0 end
			if relativeX > maxSize then relativeX = maxSize end
			cursor.Visible = true
			cursor.Position = UDim2.new(0, 10 + relativeX, 0, 0)
		end
	end)

	colorLine.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local inArrow = false
			for i, v in pairs(colors) do
				if Lib.CheckMouseInGui(v[3]) then inArrow = v[3] end
			end
			cursor.Visible = inArrow and true or false
			if inArrow then cursor.Position = UDim2.new(0, 9 + inArrow.Position.X.Offset, 0, 0) end
		end
	end)

	timeBox:GetPropertyChangedSignal("Text"):Connect(function()
		local point = currentPoint
		local num = tonumber(timeBox.Text)
		if point and num and point ~= beginPoint and point ~= endPoint then
			num = math.clamp(num, 0, 1)
			point[2] = num
			buildSequence()
			redraw()
		end
	end)

	colorBox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local editor = newMt.ColorPicker
			if not editor then
				editor = Lib.ColorPicker.new()
				editor.Window:SetTitle("ColorSequence Color Picker")

				editor.OnSelect:Connect(function(col)
					if currentPoint then currentPoint[1] = col end
					buildSequence()
					redraw()
				end)

				newMt.ColorPicker = editor
			end

			editor.Window:ShowAndFocus()
		end
	end)

	deleteButton.MouseButton1Click:Connect(function()
		if currentPoint and currentPoint ~= beginPoint and currentPoint ~= endPoint then
			for i, v in pairs(colors) do
				if v == currentPoint then
					v[3]:Destroy()
					table.remove(colors, i)
					break
				end
			end
			currentlySelected = nil
			updateInputs(colors[1])
			buildSequence()
			redraw()
		end
	end)

	resetButton.MouseButton1Click:Connect(function()
		if resetSequence then newMt:SetSequence(resetSequence) end
	end)

	closeButton.MouseButton1Click:Connect(function() window:Close() end)

	topClose.MouseButton1Click:Connect(function() window:Close() end)

	buttonAnimations(deleteButton)
	buttonAnimations(resetButton)
	buttonAnimations(closeButton)

	placeArrows()
	redraw()

	newMt.Show = function(self) window:Show() end

	return newMt
end

return { new = new }
end function __DARKDEX_MODULES.F()local v=__DARKDEX_MODULES.cache.F if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.F=v end return v.c end end do local function __modImpl()--[[
	Helpers for the component classes.

	A component declares its default properties in a table. initObj deep-copies it
	for each instance, replacing SIGNAL markers with new signals. PH marks a value
	that the constructor must replace.
]]


local Context = __DARKDEX_MODULES.a()

local Lib = Context.Lib

local Class = {}

Class.PH = newproxy()
Class.SIGNAL = newproxy()

-- Usually for classes that work with a Roblox Object
function Class.initObj(props, metatable)
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
function Class.getGuiMT(props, funcs)
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
end function __DARKDEX_MODULES.G()local v=__DARKDEX_MODULES.cache.G if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.G=v end return v.c end end do local function __modImpl()
local Class = __DARKDEX_MODULES.G()
local Context = __DARKDEX_MODULES.a()

local Settings = Context.Settings
local service = Context.service

local initObj = Class.initObj
local getGuiMT = Class.getGuiMT
local PH = Class.PH

local textService = service.TextService

local props = {
	OffsetX = 0,
	TextBox = PH,
	CursorPos = -1,
	Gui = PH,
	View = PH,
}
local funcs = {}
funcs.Update = function(self)
	local cursorPos = self.CursorPos or -1
	local text = self.TextBox.Text
	if text == "" then
		self.TextBox.Position = UDim2.new(0, 0, 0, 0)
		return
	end
	if cursorPos == -1 then return end

	local cursorText = text:sub(1, cursorPos - 1)
	local pos = nil
	local leftEnd = -self.TextBox.Position.X.Offset
	local rightEnd = leftEnd + self.View.AbsoluteSize.X

	local totalTextSize = textService:GetTextSize(text, self.TextBox.TextSize, self.TextBox.Font, Vector2.new(999999999, 100)).X
	local cursorTextSize = textService:GetTextSize(cursorText, self.TextBox.TextSize, self.TextBox.Font, Vector2.new(999999999, 100)).X

	if cursorTextSize > rightEnd then
		pos = math.max(-1, cursorTextSize - self.View.AbsoluteSize.X + 2)
	elseif cursorTextSize < leftEnd then
		pos = math.max(-1, cursorTextSize - 2)
	elseif totalTextSize < rightEnd then
		pos = math.max(-1, totalTextSize - self.View.AbsoluteSize.X + 2)
	end

	if pos then
		self.TextBox.Position = UDim2.new(0, -pos, 0, 0)
		self.TextBox.Size = UDim2.new(1, pos, 1, 0)
	end
end

funcs.GetText = function(self) return self.TextBox.Text end

funcs.SetText = function(self, text) self.TextBox.Text = text end

local mt = getGuiMT(props, funcs)

local function convert(textbox)
	local obj = initObj(props, mt)

	local view = Instance.new("Frame")
	view.BackgroundTransparency = textbox.BackgroundTransparency
	view.BackgroundColor3 = textbox.BackgroundColor3
	view.BorderSizePixel = textbox.BorderSizePixel
	view.BorderColor3 = textbox.BorderColor3
	view.Position = textbox.Position
	view.Size = textbox.Size
	view.ClipsDescendants = true
	view.Name = textbox.Name
	textbox.BackgroundTransparency = 1
	textbox.Position = UDim2.new(0, 0, 0, 0)
	textbox.Size = UDim2.new(1, 0, 1, 0)
	textbox.TextXAlignment = Enum.TextXAlignment.Left
	textbox.Name = "Input"

	obj.TextBox = textbox
	obj.View = view
	obj.Gui = view

	local function onChanged()
		local cursorPos = textbox.CursorPosition
		if cursorPos ~= -1 then obj.CursorPos = cursorPos end
		obj:Update()
	end
	textbox:GetPropertyChangedSignal("Text"):Connect(onChanged)
	textbox:GetPropertyChangedSignal("CursorPosition"):Connect(onChanged)
	textbox:GetPropertyChangedSignal("AbsoluteSize"):Connect(onChanged)

	obj:Update()

	view.Parent = textbox.Parent
	textbox.Parent = view

	return obj
end

local function new()
	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(0, 100, 0, 20)
	textBox.BackgroundColor3 = Settings.Theme.TextBox
	textBox.BorderColor3 = Settings.Theme.Outline3
	textBox.ClearTextOnFocus = false
	textBox.TextColor3 = Settings.Theme.Text
	textBox.Font = Enum.Font.SourceSans
	textBox.TextSize = 14
	textBox.Text = ""
	return convert(textBox)
end

return { new = new, convert = convert }
end function __DARKDEX_MODULES.H()local v=__DARKDEX_MODULES.cache.H if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.H=v end return v.c end end do local function __modImpl()
local Class = __DARKDEX_MODULES.G()
local Context = __DARKDEX_MODULES.a()

local Settings = Context.Settings
local getGuiMT = Class.getGuiMT

local props, funcs = {}, {}

local mt = getGuiMT(props, funcs)

local function new()
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Settings.Theme.Text
	label.TextTransparency = 0.1
	label.Size = UDim2.new(0, 100, 0, 20)
	label.Font = Enum.Font.SourceSans
	label.TextSize = 14

	local obj = setmetatable({
		Gui = label,
	}, mt)
	return obj
end

return { new = new }
end function __DARKDEX_MODULES.I()local v=__DARKDEX_MODULES.cache.I if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.I=v end return v.c end end do local function __modImpl()
local Class = __DARKDEX_MODULES.G()
local Context = __DARKDEX_MODULES.a()

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
end function __DARKDEX_MODULES.J()local v=__DARKDEX_MODULES.cache.J if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.J=v end return v.c end end do local function __modImpl()
local Class = __DARKDEX_MODULES.G()
local Context = __DARKDEX_MODULES.a()

local Lib = Context.Lib
local Settings = Context.Settings
local initObj = Class.initObj
local getGuiMT = Class.getGuiMT
local PH = Class.PH
local SIGNAL = Class.SIGNAL

local props = {
	Gui = PH,
	Anim = PH,
	Disabled = false,
	OnClick = SIGNAL,
	OnDown = SIGNAL,
	OnUp = SIGNAL,
	AllowedButtons = { 1 },
}
local funcs = {}
local tableFind = table.find

funcs.Trigger = function(self, event, button)
	if not self.Disabled and tableFind(self.AllowedButtons, button) then self["On" .. event]:Fire(button) end
end

funcs.SetDisabled = function(self, dis)
	self.Disabled = dis

	if dis then
		self.Anim:Disable()
		self.Gui.TextTransparency = 0.5
	else
		self.Anim.Enable()
		self.Gui.TextTransparency = 0
	end
end

local mt = getGuiMT(props, funcs)

local function new()
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.TextColor3 = Settings.Theme.Text
	b.TextTransparency = 0.1
	b.Size = UDim2.new(0, 100, 0, 20)
	b.Font = Enum.Font.SourceSans
	b.TextSize = 14
	b.BackgroundColor3 = Settings.Theme.Button
	b.BorderColor3 = Settings.Theme.Outline2

	local obj = initObj(props, mt)
	obj.Gui = b
	obj.Anim = Lib.ButtonAnim(b, { Mode = 2, StartColor = Settings.Theme.Button, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline2 })

	b.MouseButton1Click:Connect(function() obj:Trigger("Click", 1) end)
	b.MouseButton1Down:Connect(function() obj:Trigger("Down", 1) end)
	b.MouseButton1Up:Connect(function() obj:Trigger("Up", 1) end)

	b.MouseButton2Click:Connect(function() obj:Trigger("Click", 2) end)
	b.MouseButton2Down:Connect(function() obj:Trigger("Down", 2) end)
	b.MouseButton2Up:Connect(function() obj:Trigger("Up", 2) end)

	return obj
end

return { new = new }
end function __DARKDEX_MODULES.K()local v=__DARKDEX_MODULES.cache.K if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.K=v end return v.c end end do local function __modImpl()
local Class = __DARKDEX_MODULES.G()
local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

local Lib = Context.Lib
local Settings = Context.Settings
local create = Create.create
local initObj = Class.initObj
local getGuiMT = Class.getGuiMT
local PH = Class.PH
local SIGNAL = Class.SIGNAL

local props = {
	Gui = PH,
	Anim = PH,
	Context = PH,
	Selected = PH,
	Disabled = false,
	CanBeEmpty = true,
	Options = {},
	GuiElems = {},
	OnSelect = SIGNAL,
}
local funcs = {}

funcs.Update = function(self)
	local options = self.Options

	if #options > 0 then
		if not self.Selected then
			if not self.CanBeEmpty then
				self.Selected = options[1]
				self.GuiElems.Label.Text = options[1]
			else
				self.GuiElems.Label.Text = "- Select -"
			end
		else
			self.GuiElems.Label.Text = self.Selected
		end
	else
		self.GuiElems.Label.Text = "- Select -"
	end
end

funcs.ShowOptions = function(self)
	local context = self.Context

	context.Width = self.Gui.AbsoluteSize.X
	context.ReverseYOffset = self.Gui.AbsoluteSize.Y
	context:Show(self.Gui.AbsolutePosition.X, self.Gui.AbsolutePosition.Y + context.ReverseYOffset)
end

funcs.SetOptions = function(self, opts)
	self.Options = opts

	local context = self.Context
	local options = self.Options
	context:Clear()

	local onClick = function(option)
		self.Selected = option
		self.OnSelect:Fire(option)
		self:Update()
	end

	if self.CanBeEmpty then context:Add({
		Name = "- Select -",
		OnClick = function()
			self.Selected = nil
			self.OnSelect:Fire(nil)
			self:Update()
		end,
	}) end

	for i = 1, #options do
		context:Add({ Name = options[i], OnClick = onClick })
	end

	self:Update()
end

funcs.SetSelected = function(self, opt)
	self.Selected = type(opt) == "number" and self.Options[opt] or opt
	self:Update()
end

local mt = getGuiMT(props, funcs)

local function new()
	local f = Instance.new("TextButton")
	f.AutoButtonColor = false
	f.Text = ""
	f.Size = UDim2.new(0, 100, 0, 20)
	f.BackgroundColor3 = Settings.Theme.TextBox
	f.BorderColor3 = Settings.Theme.Outline3

	local label = Lib.Label.new()
	label.Position = UDim2.new(0, 2, 0, 0)
	label.Size = UDim2.new(1, -22, 1, 0)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = f
	local arrow = create({
		{ 1, "Frame", { BackgroundTransparency = 1, Name = "EnumArrow", Position = UDim2.new(1, -16, 0, 2), Size = UDim2.new(0, 16, 0, 16) } },
		{ 2, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 1 }, Position = UDim2.new(0, 8, 0, 9), Size = UDim2.new(0, 1, 0, 1) } },
		{ 3, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 1 }, Position = UDim2.new(0, 7, 0, 8), Size = UDim2.new(0, 3, 0, 1) } },
		{ 4, "Frame", { BackgroundColor3 = Color3.new(0.86274510622025, 0.86274510622025, 0.86274510622025), BorderSizePixel = 0, Parent = { 1 }, Position = UDim2.new(0, 6, 0, 7), Size = UDim2.new(0, 5, 0, 1) } },
	})
	arrow.Parent = f

	local obj = initObj(props, mt)
	obj.Gui = f
	obj.Anim = Lib.ButtonAnim(f, { Mode = 2, StartColor = Settings.Theme.TextBox, LerpTo = Settings.Theme.Button, LerpDelta = 0.15 })
	obj.Context = Lib.ContextMenu.new()
	obj.Context.Iconless = true
	obj.Context.MaxHeight = 200
	obj.Selected = nil
	obj.GuiElems = { Label = label }
	f.MouseButton1Down:Connect(function() obj:ShowOptions() end)
	obj:Update()
	return obj
end

return { new = new }
end function __DARKDEX_MODULES.L()local v=__DARKDEX_MODULES.cache.L if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.L=v end return v.c end end do local function __modImpl()
local Class = __DARKDEX_MODULES.G()
local Context = __DARKDEX_MODULES.a()

local Lib = Context.Lib
local service = Context.service
local initObj = Class.initObj
local PH = Class.PH
local SIGNAL = Class.SIGNAL

local props = {
	LastItem = PH,
	OnDown = SIGNAL,
	OnRelease = SIGNAL,
	AllowedButtons = { 1 },
	Combo = 0,
	MaxCombo = 2,
	ComboTime = 0.5,
	Items = {},
	ItemCons = {},
	ClickId = -1,
	LastButton = "",
}
local funcs = {}

funcs.Trigger = function(self, item, button)
	if table.find(self.AllowedButtons, button) then
		if self.LastButton ~= button or self.LastItem ~= item or self.Combo == self.MaxCombo or os.clock() - self.ClickId > self.ComboTime then
			self.Combo = 0
			self.LastButton = button
			self.LastItem = item
		end
		self.Combo = self.Combo + 1
		self.ClickId = os.clock()

		local release
		release = service.UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType["MouseButton" .. button] then
				release:Disconnect()
				if Lib.CheckMouseInGui(item) and self.LastButton == button and self.LastItem == item then self["OnRelease"]:Fire(item, self.Combo, button) end
			end
		end)

		self["OnDown"]:Fire(item, self.Combo, button)
	end
end

funcs.Add = function(self, item)
	if table.find(self.Items, item) then return end

	local cons = {}
	cons[1] = item.MouseButton1Down:Connect(function() self:Trigger(item, 1) end)
	cons[2] = item.MouseButton2Down:Connect(function() self:Trigger(item, 2) end)

	self.ItemCons[item] = cons
	self.Items[#self.Items + 1] = item
end

funcs.Remove = function(self, item)
	local ind = table.find(self.Items, item)
	if not ind then return end

	for i, v in pairs(self.ItemCons[item]) do
		v:Disconnect()
	end
	self.ItemCons[item] = nil
	table.remove(self.Items, ind)
end

local mt = { __index = funcs }

local function new()
	local obj = initObj(props, mt)

	return obj
end

return { new = new }
end function __DARKDEX_MODULES.M()local v=__DARKDEX_MODULES.cache.M if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.M=v end return v.c end end do local function __modImpl()--[[
	Lib: shared helpers and UI component classes.

	Components are required inside Main (not at load time) because some of them read
	settings and services when they are created.
]]


local Context = __DARKDEX_MODULES.a()
local Create = __DARKDEX_MODULES.e()

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

		return function(str)return (string.gsub(str, '["\\\0-\31\127-\255]', escapes)) end
	end)()

	Lib.CheckMouseInGui = function(gui)		
if gui == nil then return false end

		local mouse = Main.Mouse
		local position = gui.AbsolutePosition
		local size = gui.AbsoluteSize
		return mouse.X >= position.X and mouse.X < position.X + size.X and mouse.Y >= position.Y and mouse.Y < position.Y + size.Y
	end

	Lib.IsShiftDown = function()return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) end

	Lib.IsCtrlDown = function()return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) end

	-- Builds a pixel arrow from lines of growing length
	Lib.CreateArrow = function(size, lineCount, direction)		
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
	Lib.FastWait = function(seconds)
		if not seconds then return RenderStepped:Wait() end

		local start = os.clock()
		while os.clock() - start < seconds do
			RenderStepped:Wait()
		end
		return nil
	end

	Lib.DeferFunc = function(callback, ...)
		RenderStepped:Wait()
		return callback(...)
	end

	-- Mode 1 fades the background, mode 2 tints it with hover/press colors
	Lib.ButtonAnim = function(button, data)
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

	Lib.FindAndRemove = function(list, item)
		local index = table.find(list, item)
		if index then table.remove(list, index) end
	end

	-- Keeps obj positioned (and optionally sized) relative to data.Target
	Lib.AttachTo = function(obj, data)
		local target, posOffX, posOffY, sizeOffX, sizeOffY, resize
		local connections= {}
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

	Lib.ShowGui = function(gui) Main.ShowGui(gui) end

	Lib.ColorToBytes = function(color)return string.format("%d, %d, %d", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255)) end
end

local LibModule = {}

function LibModule.Main()
	installHelpers()

	-- Order matters: later components use the earlier ones while being created
	Lib.Signal = __DARKDEX_MODULES.u()
	Lib.Set = __DARKDEX_MODULES.v()
	Lib.IconMap = __DARKDEX_MODULES.w()
	Lib.ScrollBar = __DARKDEX_MODULES.x()
	Lib.Window = __DARKDEX_MODULES.y()
	Lib.ContextMenu = __DARKDEX_MODULES.z()
	Lib.CodeFrame = __DARKDEX_MODULES.A()
	Lib.Checkbox = __DARKDEX_MODULES.B()
	Lib.BrickColorPicker = __DARKDEX_MODULES.C()
	Lib.ColorPicker = __DARKDEX_MODULES.D()
	Lib.NumberSequenceEditor = __DARKDEX_MODULES.E()
	Lib.ColorSequenceEditor = __DARKDEX_MODULES.F()
	Lib.ViewportTextBox = __DARKDEX_MODULES.H()
	Lib.Label = __DARKDEX_MODULES.I()
	Lib.Frame = __DARKDEX_MODULES.J()
	Lib.Button = __DARKDEX_MODULES.K()
	Lib.DropDown = __DARKDEX_MODULES.L()
	Lib.ClickSystem = __DARKDEX_MODULES.M()

	return Lib
end

return LibModule
end function __DARKDEX_MODULES.N()local v=__DARKDEX_MODULES.cache.N if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.N=v end return v.c end end do local function __modImpl()--[[
	Startup and shutdown of DarkDex.

	Init loads the library, the reflection data and the apps, then builds the main
	menu. Destroy removes every GUI and tracked connection so the script can be
	executed again without restarting the game.
]]


local ClassImages = __DARKDEX_MODULES.c()
local Context = __DARKDEX_MODULES.a()
local Env = __DARKDEX_MODULES.d()
local Intro = __DARKDEX_MODULES.f()
local MainMenu = __DARKDEX_MODULES.h()
local PrettyPrint = __DARKDEX_MODULES.i()
local ReflectionData = __DARKDEX_MODULES.m()
local SettingsStore = __DARKDEX_MODULES.g()

local Main = Context.Main
local Apps = Context.Apps
local env = Context.env
local service = Context.service
local plr = Context.plr

local FOLDERS = { "dex", "dex/assets", "dex/saved", "dex/plugins", "dex/ModuleCache" }
local APP_MODULES = {
	{ Name = "Explorer", Module = __DARKDEX_MODULES.r() },
	{ Name = "Properties", Module = __DARKDEX_MODULES.s() },
	{ Name = "ScriptViewer", Module = __DARKDEX_MODULES.t() },
}
local LibModule = __DARKDEX_MODULES.N()

Main.Version = "1.0.0"
Main.Elevated = false
Main.Destroyed = false
Main.Mouse = plr:GetMouse()
Main.MenuApps = {}
Main.Apps = Apps
Main.DisplayOrders = {
	SideWindow = 8,
	Window = 10,
	Menu = 100000,
	Core = 101000,
}

local trackedConnections= {}
-- Weak keys: guis destroyed while running must not be kept alive by this set
local shownGuis= (setmetatable({}, { __mode = "k" }) )
-- Keeps a connection to a global signal so Destroy can disconnect it

function Main.Track(connection)	
table.insert(trackedConnections, connection)
	return connection
end

function Main.ShowGui(gui)
	-- Called on every window update, so only the first call protects and parents the gui
	if shownGuis[gui] and gui.Parent then return end
	shownGuis[gui] = true

	if env.gethui then
		gui.Parent = env.gethui()
		return
	end

	if env.protectgui then env.protectgui(gui) end
	gui.Parent = Main.GuiHolder
end

function Main.Destroy()
	if Main.Destroyed then return end
	Main.Destroyed = true

	for _, connection in trackedConnections do
		connection:Disconnect()
	end
	table.clear(trackedConnections)

	for _, app in Apps do
		if type(app) == "table" and app.Destroy then pcall(app.Destroy) end
	end

	for gui in shownGuis do
		gui:Destroy()
	end
	table.clear(shownGuis)
end

Main.CreateApp = MainMenu.CreateApp

local function setupFilesystem()
	if not env.makefolder then return end

	for _, folder in FOLDERS do
		local exists = env.isfolder and env.isfolder(folder)
		if not exists then pcall(env.makefolder, folder) end
	end
end

local function loadApps()
	for _, entry in APP_MODULES do
		Apps[entry.Name] = entry.Module.Main()
	end

	for _, entry in APP_MODULES do
		entry.Module.InitAfterMain()
	end
end

local function createIcons()
	Main.MiscIcons = Context.Lib.IconMap.new("rbxassetid://6511490623", 256, 256, 16, 16)
	Main.MiscIcons:SetDict({
		Reference = 0,
		Cut = 1,
		Cut_Disabled = 2,
		Copy = 3,
		Copy_Disabled = 4,
		Paste = 5,
		Paste_Disabled = 6,
		Delete = 7,
		Delete_Disabled = 8,
		Group = 9,
		Group_Disabled = 10,
		Ungroup = 11,
		Ungroup_Disabled = 12,
		TeleportTo = 13,
		Rename = 14,
		JumpToParent = 15,
		ExploreData = 16,
		Save = 17,
		CallFunction = 18,
		CallRemote = 19,
		Undo = 20,
		Undo_Disabled = 21,
		Redo = 22,
		Redo_Disabled = 23,
		Expand_Over = 24,
		Expand = 25,
		Collapse_Over = 26,
		Collapse = 27,
		SelectChildren = 28,
		SelectChildren_Disabled = 29,
		InsertObject = 30,
		ViewScript = 31,
		AddStar = 32,
		RemoveStar = 33,
		Script_Disabled = 34,
		LocalScript_Disabled = 35,
		Play = 36,
		Pause = 37,
		Rename_Disabled = 38,
	})

	Main.LargeIcons = Context.Lib.IconMap.new("rbxassetid://6579106223", 256, 256, 32, 32)
	Main.LargeIcons:SetDict({
		Explorer = 0,
		Properties = 1,
		Script_Viewer = 2,
	})
end

function Main.Init()
	Main.Elevated = pcall(function() return Context.service.CoreGui:GetFullName() end)
	Main.GuiHolder = Main.Elevated and service.CoreGui or plr:FindFirstChildWhichIsA("PlayerGui")

	Env.init()
	SettingsStore.reset()
	SettingsStore.load()
	setupFilesystem()
	PrettyPrint.install()

	local intro = Intro.create("Initializing Library")
	LibModule.Main()
	createIcons()

	intro.SetProgress("Loading class icons", 0.2)
	Main.ClassImages = ClassImages.resolve()

	ReflectionData.load(intro.SetProgress)

	intro.SetProgress("Loading Modules", 0.75)
	loadApps()

	intro.SetProgress("Initializing Modules", 0.9)
	Apps.Explorer.Init()
	Apps.Properties.Init()
	Apps.ScriptViewer.Init()

	intro.SetProgress("Complete", 1)
	task.delay(1.25, intro.Close)

	local Lib = Context.Lib
	Lib.Window.Init()
	MainMenu.create()
	Apps.Explorer.Window:Show({ Align = "right", Pos = 1, Size = 0.5, Silent = true })
	Apps.Properties.Window:Show({ Align = "right", Pos = 2, Size = 0.5, Silent = true })
	Lib.DeferFunc(function() Lib.Window.ToggleSide("right") end)
end

return Main
end function __DARKDEX_MODULES.O()local v=__DARKDEX_MODULES.cache.O if not v then v={c=__modImpl()}__DARKDEX_MODULES.cache.O=v end return v.c end end end--[[
	DarkDex
	Debugging suite for Roblox, based on New Dex by Moon (LorekeeperZinnia).
	https://github.com/LorekeeperZinnia/Dex
]]


local Main = __DARKDEX_MODULES.O()

-- selene: allow(global_usage)
local genv = getgenv and getgenv() or _G

-- Executing again replaces the running instance
local previous = genv.DarkDex
if type(previous) == "table" and type(previous.Destroy) == "function" then pcall(previous.Destroy) end

genv.DarkDex = Main
Main.Init()
