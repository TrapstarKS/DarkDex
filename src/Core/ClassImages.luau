--[[
	Source of the explorer class icons (16x16 strip indexed by the RMD ExplorerImageIndex).

	The client ships the same strip that the ReflectionMetadata indexes, so it is used
	first. When it cannot be loaded, a copy from the client tracker is cached in the
	workspace and loaded through getcustomasset. The old androssy.net mirror is gone.
]]

local Context = require("@core/Context")
local Http = require("@core/Http")

local env = Context.env
local service = Context.service

local CLIENT_ASSET = "rbxasset://textures/ClassImages.PNG"
local MIRROR_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/textures/ClassImages.PNG"
local CACHE_PATH = "dex/assets/ClassImages.png"
local PNG_SIGNATURE = "\137PNG\r\n\26\n"

local function isPng(data: string): boolean return string.sub(data, 1, #PNG_SIGNATURE) == PNG_SIGNATURE end

local function canLoad(contentId: string): boolean
	local loaded = false
	local success = pcall(service.ContentProvider.PreloadAsync, service.ContentProvider, { contentId }, function(_, status) loaded = status == Enum.AssetFetchStatus.Success end)
	return success and loaded
end

local function readCache(): string?
	local success, data = pcall(function() return env.isfile(CACHE_PATH) and env.readfile(CACHE_PATH) end)
	if success and type(data) == "string" and isPng(data) then return data end
	return nil
end

local function loadCustomAsset(): string?
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

function ClassImages.resolve(): string
	if canLoad(CLIENT_ASSET) then return CLIENT_ASSET end
	return loadCustomAsset() or CLIENT_ASSET
end

return ClassImages
