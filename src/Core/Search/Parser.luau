--[[
	Parser for the Explorer search language, compatible with the Studio Explorer filter:

		Dog                       name contains "Dog" (case insensitive)
		"Red Team Spawn"          quoted name
		is:BasePart               IsA
		classname:Part, c:Part    exact class
		tag:Interactable          CollectionService tag
		name:Dog                  name contains
		Anchored=true             property query, also .Anchored=true
		Position.X >= 10          property field, operators = == ~= != > < >= <=
		Color = "255, 0, 0"       whole value
		workspace.Model.*         ancestry path, * one level, ** any depth
		a b, a and b, a && b      all must match
		a or b, a || b            any must match
		not a, !a                 negation, ( ) groups

	DarkDex extras: /remotes, /bindables, /players, /loadedmodules, /rad <studs>.
	Pure Luau, no Roblox APIs, so it is testable outside the game.
]]

export type Operator = "=" | "~=" | ">" | "<" | ">=" | "<="

export type Node =
	{ kind: "and", left: Node, right: Node }
	| { kind: "or", left: Node, right: Node }
	| { kind: "not", expr: Node }
	| { kind: "name", value: string }
	| { kind: "keyword", keyword: string, value: string }
	| { kind: "property", path: { string }, op: Operator, value: string }
	| { kind: "path", segments: { string } }
	| { kind: "command", name: string, arg: string? }

type Token = { type: "word" | "string" | "op" | "lparen" | "rparen" | "and" | "or" | "not", value: string }

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

function Parser.tokenize(query: string): ({ Token }?, string?)
	local tokens: { Token } = {}
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
					table.insert(tokens, { type = lower :: any, value = word })
				else
					table.insert(tokens, { type = "word", value = word })
				end
				index = wordEnd + 1
			end
		end
	end

	return tokens, nil
end

local function isPath(word: string): boolean
	-- A number such as 1.5 is a name, not a path
	return string.find(word, ".", 1, true) ~= nil and tonumber(word) == nil and not string.find(word, "^%.") and not string.find(word, "%.$")
end

function Parser.parse(query: string): (Node?, string?)
	local tokens, tokenizeError = Parser.tokenize(query)
	if not tokens then return nil, tokenizeError end
	if #tokens == 0 then return nil, nil end

	local position = 1

	local function peek(): Token? return tokens[position] end

	local function advance(): Token
		local token = tokens[position]
		position += 1
		return token
	end

	local function isValueToken(token: Token?): boolean return token ~= nil and (token.type == "word" or token.type == "string") end

	local parseOr

	local function parsePrimary(): Node
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
			return { kind = "property", path = string.split(propertyName, "."), op = nextToken.value :: Operator, value = value }
		end

		if isPath(word) then return { kind = "path", segments = string.split(word, ".") } end

		return { kind = "name", value = word }
	end

	local function parseUnary(): Node
		local token = peek()
		if token and token.type == "not" then
			advance()
			return { kind = "not", expr = parseUnary() }
		end
		return parsePrimary()
	end

	local function parseAnd(): Node
		local left = parseUnary()
		while true do
			local token = peek()
			if not token or token.type == "rparen" or token.type == "or" then break end
			if token.type == "and" then advance() end
			left = { kind = "and", left = left, right = parseUnary() }
		end
		return left
	end

	function parseOr(): Node
		local left = parseAnd()
		while peek() and (peek() :: Token).type == "or" do
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
