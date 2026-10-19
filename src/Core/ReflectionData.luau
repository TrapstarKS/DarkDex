--[[
	Downloads the API dump and ReflectionMetadata, caching both in the workspace.

	The cache is keyed by the running client version, so a cached copy is used without
	any request until Roblox updates.
]]

local Api = require("@core/Api")
local Context = require("@core/Context")
local Http = require("@core/Http")
local Rmd = require("@core/Rmd")

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

local function readFile(path: string): string?
	if not (env.readfile and env.isfile) then return nil end

	local success, contents = pcall(function() return env.isfile(path) and env.readfile(path) end)
	if success and type(contents) == "string" and contents ~= "" then return contents end
	return nil
end

local function writeFile(path: string, contents: string)
	if not env.writefile then return end

	local success, err = pcall(env.writefile, path, contents)
	if not success then warn(`[DarkDex] Failed to write {path}: {err}`) end
end

local function getClientVersion(): string
	-- GetRobloxVersion needs a RobloxScript capability that some executors do not have
	local RunService = Context.service.RunService
	local success, clientVersion = pcall(RunService.GetRobloxVersion, RunService)
	if not success then
		success, clientVersion = pcall(version)
	end
	return success and clientVersion or "unknown"
end

local function fetchStudioVersion(): string?
	for _, url in STUDIO_VERSION_URLS do
		local body = Http.get(url)
		local studioVersion = body and string.match(body, "version%-%x+")
		if studioVersion then return studioVersion end
	end
	return nil
end

local function isJsonObject(body: string): boolean return string.sub(body, 1, 1) == "{" end

local function isXml(body: string): boolean return string.find(body, "<roblox", 1, true) ~= nil end

local function fetchApi(): string
	local studioVersion = fetchStudioVersion()
	local urls = studioVersion and { string.format(API_URL, studioVersion), API_FALLBACK_URL } or { API_FALLBACK_URL }
	return Http.getFirst(urls, isJsonObject) or error("Could not download the API dump")
end

local function fetchRmd(): string return Http.get(RMD_URL, isXml) or error("Could not download the ReflectionMetadata") end

local ReflectionData = {}

-- onProgress(status, fraction) is called before each slow step
function ReflectionData.load(onProgress: (string, number) -> ())
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
