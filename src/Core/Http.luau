--[[
	HTTP helpers.

	Some executors return an error page or an empty string instead of throwing,
	so a response only counts when it passes the caller's validation.
]]

local Http = {}

function Http.get(url: string, isValid: ((string) -> boolean)?): string?
	local success, body = pcall(game.HttpGet, game, url)
	if not success then
		warn(`[DarkDex] GET {url} failed: {body}`)
		return nil
	end

	if type(body) ~= "string" or body == "" or (isValid and not isValid(body)) then
		warn(`[DarkDex] GET {url} returned an invalid response`)
		return nil
	end

	return body
end

-- Tries each url in order and returns the first valid response
function Http.getFirst(urls: { string }, isValid: ((string) -> boolean)?): string?
	for _, url in urls do
		local body = Http.get(url, isValid)
		if body then return body end
	end
	return nil
end

return Http
