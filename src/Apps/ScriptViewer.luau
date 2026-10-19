--[[
	ScriptViewer App Module

	Shows decompiled scripts with copy, save and function dump tools.
]]

local Context = require("@core/Context")

local Lib = Context.Lib
local env = Context.env

local BUTTON_HEIGHT = 20

-- Function Dumper originally made by King.Kevin
local function dumpFunctions(scr: LuaSourceContainer): string?
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

	local function add(text: string, indent: number) table.insert(output, string.rep("    ", math.max(0, indent)) .. text) end

	local function functionName(func): string
		local name = debug.info(func, "n")
		return (name and name ~= "") and name or "Unknown Name"
	end

	local dumpValue

	local function dumpTable(value, indent: number, key)
		add(`{tostring(key)} [{typeof(value)}] {tostring(value)}`, indent - 1)
		local count = 0
		for _, item in value do
			count += 1
			dumpValue(count, item, indent)
		end
	end

	function dumpValue(key, value, indent: number)
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

	local function belongsToScript(func): boolean
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

local function createButton(parent: Instance, text: string, index: number, count: number): TextButton
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

local function sanitizeFileName(name: string): string return (string.gsub(name, "[^%w%-_ ]", "_")) end

local function initAfterMain() end

local function main()
	local ScriptViewer = {}
	local window, codeFrame
	local currentScript: LuaSourceContainer?

	function ScriptViewer.ViewScript(scr: LuaSourceContainer)
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
	function ScriptViewer.ShowText(title: string, text: string)
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
