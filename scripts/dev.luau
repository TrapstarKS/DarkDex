--[[
	Development loop.

	lune run scripts/dev          builds on every request and serves the bundle
	lune run scripts/dev build    builds once

	Each build is written to dist/DarkDex.lua and copied to the executor workspaces
	that exist on this machine, so it can also be run with readfile.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local PORT = tonumber(process.env.DARKDEX_PORT) or 7777
local OUTPUT = "dist/DarkDex.lua"
local HOME = process.env.HOME or ""

local WORKSPACES = {
	HOME .. "/Documents/Macsploit Workspace",
	HOME .. "/Library/Containers/com.gloop.deltamobile/Data/Documents/Delta/Workspace",
}

local function build(): (boolean, string)
	local result = process.exec("darklua", { "process", "src/init.luau", OUTPUT, "--config", "darklua.json" })
	if not result.ok then return false, result.stderr .. result.stdout end

	local bundle = fs.readFile(OUTPUT)
	for _, workspace in WORKSPACES do
		if fs.isDir(workspace) then fs.writeFile(workspace .. "/DarkDex.lua", bundle) end
	end

	return true, bundle
end

if process.args[1] == "build" then
	local ok, output = build()
	if not ok then
		print(output)
		process.exit(1)
	end
	print(`Built {OUTPUT} ({#output} bytes)`)
	process.exit(0)
end

net.serve(PORT, {
	address = "http://127.0.0.1",
	handleRequest = function(request)
		if request.path ~= "/DarkDex.lua" then return { status = 404, body = "Not found" } end

		local ok, output = build()
		if not ok then
			print(`[{os.date("%X")}] Build failed:\n{output}`)
			return { status = 200, body = `error({string.format("%q", "DarkDex build failed:\n" .. output)})` }
		end

		print(`[{os.date("%X")}] Served a fresh build ({#output} bytes)`)
		return { status = 200, headers = { ["Content-Type"] = "text/plain" }, body = output }
	end,
})

print(`DarkDex dev server on http://127.0.0.1:{PORT}`)
print(`Executor: loadstring(game:HttpGet("http://127.0.0.1:{PORT}/DarkDex.lua"))()`)
print('Or, without HTTP: loadstring(readfile("DarkDex.lua"))()')
