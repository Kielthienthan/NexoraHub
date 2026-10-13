local URL = "https://api.xhider.xyz/files/v4/loaders/2c6490bdd9a4f62f6088f1f3cd62f729.lua"

local ok, err = pcall(function()
    local source = game:HttpGet(URL)
    local script = assert(loadstring(source))
    script()
end)

if not ok then
    warn("[Nexora] Loader Error: " .. tostring(err))
end
