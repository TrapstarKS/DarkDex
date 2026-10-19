--[[
	Default settings and persistence of the user toggles.

	Settings is filled in place (Context.Settings) because modules hold a reference to
	it. Only the keys in PERSISTED_KEYS are written to disk.
]]

local Context = require("@core/Context")

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
