--[[
	Autocomplete for the Explorer search box.

	get(text) looks at the token being typed and returns completions that replace it:
	suggested filters for an empty box, classes after is:/c:, tags after tag:, property
	names, and enum or boolean values after a property operator.
]]

local Context = require("@core/Context")

local service = Context.service

export type Suggestion = {
	Text: string, -- full search text after accepting
	Label: string,
	ClassIcon: string?, -- class name whose explorer icon is shown
}

local MAX_SUGGESTIONS = 50

local SUGGESTED_FILTERS = { "anchored=", "locked=", "transparency=", "material=", "meshId=", "textureId=", "tag:", "is:" }
local CLASS_KEYWORDS = { is = true, c = true, classname = true }
local KEYWORDS = { "is:", "c:", "classname:", "tag:", "name:" }

type PropertyInfo = { Name: string, ValueType: { Name: string, Category: string? } }

local propertyIndex: { [string]: PropertyInfo }?
local propertyNames: { string }?
local classList: { string }?

local function getPropertyIndex(): ({ [string]: PropertyInfo }, { string })
	if propertyIndex and propertyNames then return propertyIndex, propertyNames end

	local index, names = {}, {}
	for _, class in Context.API.Classes do
		for _, property in class.Properties do
			local lower = string.lower(property.Name)
			-- Studio settings classes have names with spaces that cannot be typed as a filter
			if not index[lower] and string.find(property.Name, "^[%a_][%w_]*$") then
				index[lower] = property
				table.insert(names, property.Name)
			end
		end
	end
	table.sort(names)

	propertyIndex, propertyNames = index, names
	return index, names
end

local function getClassList(): { string }
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
local function filterByQuery(items: { string }, query: string, limit: number): { string }
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

local function quoteIfNeeded(value: string): string
	if string.find(value, "^[%w_%-%.]+$") then return value end
	return `"{string.gsub(value, '"', '\\"')}"`
end

-- Splits the text into the part before the token being typed and the token itself
local function splitCurrentToken(text: string): (string, string, boolean)
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

function Suggest.get(text: string): ({ Suggestion }, string?)
	local results: { Suggestion } = {}
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
			local success, enum = pcall(function() return (Enum :: any)[valueType.Name] end)
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
