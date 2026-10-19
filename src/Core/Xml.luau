--[[
	Minimal XML parser, only used for the ReflectionMetadata.
	Based on https://github.com/jonathanpoelen/xmlparser (entities are not expanded).
]]

export type Node = {
	tag: string?,
	attrs: { [string]: string }?,
	children: { Node }?,
	text: string?,
}

local SLASH_BYTE = string.byte("/")

local Xml = {}

function Xml.parse(source: string): { children: { Node } }
	source = string.gsub(source, "<!%-%-(.-)%-%->", "")

	local current: { Node } = {}
	local stack: { { Node } } = {}

	local function addText(text: string)
		text = string.match(text, "^%s*(.*%S)") or ""
		if #text ~= 0 then table.insert(current, { text = text }) end
	end

	for kind, name, closed, text in string.gmatch(source, "<([?!/]?)([-:_%w]+)%s*(/?>?)([^<]*)") do
		if kind == "" then
			local attrs = {}
			if closed == "" then
				local length = 0
				for all, attrName, _, value, startText in string.gmatch(text, "(.-([-_%w]+)%s*=%s*(.)(.-)%3%s*(/?>?))") do
					length += #all
					attrs[attrName] = value
					if #startText ~= 0 then
						text = string.sub(text, length + 1)
						closed = startText
						break
					end
				end
			end

			local node = { tag = name, attrs = attrs, children = {} }
			table.insert(current, node)

			if string.byte(closed, 1) ~= SLASH_BYTE then
				table.insert(stack, current)
				current = node.children
			end

			addText(text)
		elseif kind == "/" then
			current = table.remove(stack) or current
			addText(text)
		end
	end

	return { children = current }
end

return Xml
