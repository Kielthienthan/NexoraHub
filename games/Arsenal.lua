local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserSettings = game:GetService("UserSettings")
local lp = Players.LocalPlayer

pcall(function()
    Lighting.GlobalShadows = false
    Lighting.ShadowSoftness = 0
    UserSettings.Rendering.QualityLevel = Enum.QualityLevel.Level01
end)

local function killFX(o)
    if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") then
        o.Enabled = false
    elseif o:IsA("BlurEffect") or o:IsA("SunRaysEffect") or o:IsA("DepthOfFieldEffect") or o:IsA("BloomEffect") or o:IsA("ColorCorrectionEffect") then
        o.Enabled = false
    end
end

for _, v in ipairs(Lighting:GetChildren()) do pcall(killFX, v) end
for _, v in ipairs(workspace:GetDescendants()) do pcall(killFX, v) end

workspace.DescendantAdded:Connect(function(o) pcall(killFX, o) end)
Lighting.DescendantAdded:Connect(function(o) pcall(killFX, o) end)

local orig = {}
local charConns = {}

local function isTeammate(plr)
    if plr == lp then return true end
    if not lp.Team or not plr.Team then return false end
    return lp.Team == plr.Team
end

local function expand(plr)
    if plr == lp or isTeammate(plr) then return end
    local char = plr.Character
    if not char then return end

    local head = char:FindFirstChild("Head")
    if head and not orig[plr] then
        orig[plr] = {head.Size, head.Transparency, head.CanCollide}
        head.Size = Vector3.new(10, 10, 10)
        head.Transparency = 0
        head.CanCollide = false
    end

    local hl = char:FindFirstChild("NexoraHighlight")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "NexoraHighlight"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
    end
    hl.FillColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0
end

local function reset(plr)
    local char = plr.Character
    local data = orig[plr]
    if data and char then
        local head = char:FindFirstChild("Head")
        if head then
            head.Size = data[1]
            head.Transparency = data[2]
            head.CanCollide = data[3]
        end
    end
    orig[plr] = nil
    if char then
        local hl = char:FindFirstChild("NexoraHighlight")
        if hl then hl:Destroy() end
    end
end

local function watch(plr)
    if plr == lp then return end
    if charConns[plr] then charConns[plr]:Disconnect() end
    charConns[plr] = plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        expand(plr)
    end)
    if plr.Character then expand(plr) end
end

for _, plr in ipairs(Players:GetPlayers()) do watch(plr) end
Players.PlayerAdded:Connect(watch)

Players.PlayerRemoving:Connect(function(plr)
    if charConns[plr] then
        charConns[plr]:Disconnect()
        charConns[plr] = nil
    end
    orig[plr] = nil
end)

task.spawn(function()
    while task.wait(0.5) do
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp then
                if isTeammate(plr) then
                    reset(plr)
                else
                    expand(plr)
                end
            end
        end
    end
end)
