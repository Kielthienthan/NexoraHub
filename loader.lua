local scripts = {
	[537413528] = "https://raw.githubusercontent.com/Kielthienthan/NexoraHub/refs/heads/main/games/BuildaBoatForTreasure.lua",
}

local universal = "https://raw.githubusercontent.com/Kielthienthan/NexoraHub/refs/heads/main/games/AimbotBlatant.lua"

local function fetch(url)
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and res and #res > 0 then return res end

	if syn and syn.request then
		res = syn.request({ Url = url, Method = "GET" })
		if res and res.Body then return res.Body end
	end

	if http_request then
		res = http_request({ Url = url, Method = "GET" })
		if res and res.Body then return res.Body end
	end

	if request then
		res = request({ Url = url, Method = "GET" })
		if res and res.Body then return res.Body end
	end

	if fluxus and fluxus.request then
		res = fluxus.request({ Url = url, Method = "GET" })
		if res and res.Body then return res.Body end
	end

	if http and http.request then
		res = http.request({ Url = url, Method = "GET" })
		if res and res.Body then return res.Body end
	end

	error("http not available")
end

local function executor()
	if identifyexecutor then return identifyexecutor() end
	if getexecutorname then return getexecutorname() end
	return "unknown"
end

local url = scripts[game.PlaceId] or universal

local ok, err = pcall(function()
	local fn, e = loadstring(fetch(url))
	assert(fn, e)
	fn()
end)

if not ok then
	warn("[Loader] " .. tostring(err) .. " / " .. executor())
end
