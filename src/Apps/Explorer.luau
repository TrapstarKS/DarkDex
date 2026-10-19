--[[
	Explorer App Module

	The main explorer interface
]]

local Context = require("@core/Context")
local Create = require("@core/Create")
local SaveInstance = require("@core/SaveInstance")
local SearchQuery = require("@core/Search/Query")
local Suggest = require("@core/Search/Suggest")

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
local function shortenPath(path: string): string
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

	Explorer.GetNode = function(obj: Instance) return nodes[obj] end

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
					nilMap[descs[j]] = true
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
	local function addClassMembers(context, nodesList, kind: "Functions" | "Events", showDeprecated: boolean, makeItem)
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
	Explorer.FindReferences = function(target: Instance): string
		local getgc = getgc or get_gc_objects
		if not getgc then return "-- Get Lua References needs getgc" end
		local getupvalues = (debug and debug.getupvalues) or getupvalues

		local lines = { `-- Lua references to {shortenPath(Explorer.GetInstancePath(target))}`, "" }
		local count = 0

		local function add(line: string)
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

	local function setSearchStatus(text: string?) Explorer.Window:SetTitle(text and `Explorer - {text}` or "Explorer") end

	-- Runs a search. A live search keeps the previous results when the query is incomplete.
	Explorer.DoSearch = function(query: string, isLive: boolean?)
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

	Explorer.InitSearchSuggestions = function(searchBox: TextBox)
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

		local function accept(index: number)
			local suggestion = suggestions[index]
			if not suggestion then return end

			searchBox.Text = suggestion.Text
			searchBox:CaptureFocus()
			searchBox.CursorPosition = #suggestion.Text + 1
		end

		local function getRow(index: number): TextButton
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
		expanded[nodes[game]] = true

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
