local scripts = {
	[136599248168660] = "https://raw.githubusercontent.com/KielKeyHandler/Util/refs/heads/main/SoloHunter.lua",
	[75992362647444] = "https://raw.githubusercontent.com/KielKeyHandler/Util/refs/heads/main/TapTapSimulator.lua",
	[74260430392611] = "https://raw.githubusercontent.com/KielKeyHandler/Util/refs/heads/main/RebirthChampionUlti.lua",
	[994732206] = "https://raw.githubusercontent.com/KielKeyHandler/Util/refs/heads/main/Centudox.lua",
	[130247632398296] = "https://raw.githubusercontent.com/KielKeyHandler/Util/refs/heads/main/Afse.lua",
}

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

local url = scripts[game.PlaceId]

if not url then
	warn("[Loader] unsupported place " .. game.PlaceId .. " / " .. executor())
	return
end

local ok, err = pcall(function()
	local fn, e = loadstring(fetch(url))
	assert(fn, e)
	fn()
end)

if not ok then
	warn("[Loader] " .. tostring(err) .. " / " .. executor())
end
