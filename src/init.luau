--[[
	DarkDex
	Debugging suite for Roblox, based on New Dex by Moon (LorekeeperZinnia).
	https://github.com/LorekeeperZinnia/Dex
]]

local Main = require("@core/Main")

local genv = getgenv and getgenv() or _G

-- Executing again replaces the running instance
local previous = genv.DarkDex
if type(previous) == "table" and type(previous.Destroy) == "function" then pcall(previous.Destroy) end

genv.DarkDex = Main
Main.Init()
