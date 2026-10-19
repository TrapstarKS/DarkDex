-- lune run tests/parser.spec
local Parser = require("../src/Core/Search/Parser")

local function show(node): string
	if node == nil then return "nil" end
	local kind = node.kind
	if kind == "and" or kind == "or" then return `({show(node.left)} {kind} {show(node.right)})` end
	if kind == "not" then return `not {show(node.expr)}` end
	if kind == "name" then return `name[{node.value}]` end
	if kind == "keyword" then return `{node.keyword}[{node.value}]` end
	if kind == "property" then return `prop[{table.concat(node.path, ".")}{node.op}{node.value}]` end
	if kind == "path" then return `path[{table.concat(node.segments, "/")}]` end
	if kind == "command" then return `cmd[{node.name}{node.arg and (" " .. node.arg) or ""}]` end
	return "?"
end

local cases = {
	{ "Dog", "name[Dog]" },
	{ '"Red Team Spawn"', "name[Red Team Spawn]" },
	{ "is:Accessory", "is[Accessory]" },
	{ "IS:BasePart", "is[BasePart]" },
	{ "c:Part", "class[Part]" },
	{ 'tag:"Light Source"', "tag[Light Source]" },
	{ "Anchored=true", "prop[Anchored=true]" },
	{ "Locked == t", "prop[Locked=t]" },
	{ 'is:PackageLink .Status~="Up To Date"', "(is[PackageLink] and prop[Status~=Up To Date])" },
	{ "Position.X >= 10", "prop[Position.X>=10]" },
	{ "meshId=", "prop[meshId=]" },
	{ "Health != 100", "prop[Health~=100]" },
	{ "Cat or Dog", "(name[Cat] or name[Dog])" },
	{ "(Anchored=true CanCollide=true) or (Anchored=false CanCollide=false)", "((prop[Anchored=true] and prop[CanCollide=true]) or (prop[Anchored=false] and prop[CanCollide=false]))" },
	{ "workspace.Model.*", "path[workspace/Model/*]" },
	{ "model.** visible=true", "(path[model/**] and prop[visible=true])" },
	{ "not is:Script && !Dog || Cat", "((not is[Script] and not name[Dog]) or name[Cat])" },
	{ "/remotes", "cmd[remotes]" },
	{ "/rad 50", "cmd[rad 50]" },
	{ "/isa Part", "is[Part]" },
	{ "1.5", "name[1.5]" },
	{ "foo:Bar", "name[foo:Bar]" },
}

local failures = 0
for _, case in cases do
	local node, err = Parser.parse(case[1])
	local got = err and ("error: " .. err) or show(node)
	if got ~= case[2] then
		failures += 1
		print(`FAIL {case[1]}\n  expected {case[2]}\n  got      {got}`)
	end
end

local errorCases = { { '"open', "Unclosed quote" }, { "(a b", "Unclosed parenthesis" }, { "is:", "Missing value after is:" }, { "a )", 'Unexpected ")"' } }
for _, case in errorCases do
	local _, err = Parser.parse(case[1])
	if err ~= case[2] then
		failures += 1
		print(`FAIL error {case[1]}: expected {case[2]}, got {tostring(err)}`)
	end
end

assert(Parser.parse("") == nil and select(2, Parser.parse("")) == nil, "empty query")
print(failures == 0 and `ok: {#cases + #errorCases} cases` or `{failures} failures`)
if failures > 0 then error("parser tests failed") end
