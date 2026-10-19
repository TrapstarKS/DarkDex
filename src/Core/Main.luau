--[[
	Startup and shutdown of DarkDex.

	Init loads the library, the reflection data and the apps, then builds the main
	menu. Destroy removes every GUI and tracked connection so the script can be
	executed again without restarting the game.
]]

local ClassImages = require("@core/ClassImages")
local Context = require("@core/Context")
local Env = require("@core/Env")
local Intro = require("@core/Intro")
local MainMenu = require("@core/MainMenu")
local PrettyPrint = require("@core/PrettyPrint")
local ReflectionData = require("@core/ReflectionData")
local SettingsStore = require("@core/Settings")

local Main = Context.Main
local Apps = Context.Apps
local env = Context.env
local service = Context.service
local plr = Context.plr

local FOLDERS = { "dex", "dex/assets", "dex/saved", "dex/plugins", "dex/ModuleCache" }
local APP_MODULES = {
	{ Name = "Explorer", Module = require("@apps/Explorer") },
	{ Name = "Properties", Module = require("@apps/Properties") },
	{ Name = "ScriptViewer", Module = require("@apps/ScriptViewer") },
}
local LibModule = require("@lib")

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

local trackedConnections: { RBXScriptConnection } = {}
local shownGuis: { ScreenGui } = {}

-- Keeps a connection to a global signal so Destroy can disconnect it
function Main.Track(connection: RBXScriptConnection): RBXScriptConnection
	table.insert(trackedConnections, connection)
	return connection
end

function Main.ShowGui(gui: ScreenGui)
	table.insert(shownGuis, gui)

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

	for _, gui in shownGuis do
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
	Main.Elevated = pcall(function() return Context.cloneref(game:GetService("CoreGui")):GetFullName() end)
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
