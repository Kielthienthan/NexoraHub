local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local UserSettings = game:GetService("UserSettings")
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

pcall(function()
    Lighting.GlobalShadows = false
    Lighting.ShadowSoftness = 0
    UserSettings.Rendering.QualityLevel = Enum.QualityLevel.Level01
end)

local function disableEffect(instance)
    if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
        instance.Enabled = false
    elseif instance:IsA("BlurEffect") or instance:IsA("SunRaysEffect") or instance:IsA("DepthOfFieldEffect") or instance:IsA("BloomEffect") or instance:IsA("ColorCorrectionEffect") then
        instance.Enabled = false
    end
end

for _, child in ipairs(Lighting:GetChildren()) do
    pcall(disableEffect, child)
end
for _, descendant in ipairs(workspace:GetDescendants()) do
    pcall(disableEffect, descendant)
end

workspace.DescendantAdded:Connect(function(descendant) pcall(disableEffect, descendant) end)
Lighting.DescendantAdded:Connect(function(descendant) pcall(disableEffect, descendant) end)

local FieldOfViewSize = 150
local TeamCheckEnabled = true
local WallCheckEnabled = true
local AlwaysAiming = false

local IsTouching = false
UserInputService.TouchStarted:Connect(function() IsTouching = true end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        IsTouching = false
    end
end)

local FieldOfViewCircle = Drawing.new("Circle")
FieldOfViewCircle.Thickness = 2
FieldOfViewCircle.Filled = false
FieldOfViewCircle.Transparency = 1
FieldOfViewCircle.NumSides = 64
FieldOfViewCircle.Radius = FieldOfViewSize
FieldOfViewCircle.Color = Color3.fromRGB(255, 255, 255)
FieldOfViewCircle.ZIndex = 2
FieldOfViewCircle.Visible = true

local function getScreenCenter()
    local screenPoint = CurrentCamera:WorldToViewportPoint(CurrentCamera.CFrame.Position + CurrentCamera.CFrame.LookVector * 100)
    return Vector2.new(screenPoint.X, screenPoint.Y)
end

local function isTeammate(player)
    if player == LocalPlayer then return true end
    if not TeamCheckEnabled then return false end
    if not LocalPlayer.Team or not player.Team then return false end
    return LocalPlayer.Team == player.Team
end

local function hasLineOfSight(targetPart)
    if not WallCheckEnabled then return true end

    local rayOrigin = CurrentCamera.CFrame.Position
    local rayDirection = targetPart.Position - rayOrigin

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { LocalPlayer.Character }

    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if not raycastResult then return true end
    return raycastResult.Instance:IsDescendantOf(targetPart.Parent)
end

local function findTarget(screenCenter)
    local closestTarget = nil
    local closestDistance = FieldOfViewSize

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not isTeammate(player) then
            local character = player.Character
            local head = character and character:FindFirstChild("Head")

            if head then
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if humanoid and humanoid.Health > 0 then
                    local screenPosition, isOnScreen = CurrentCamera:WorldToViewportPoint(head.Position)

                    if isOnScreen then
                        local screenDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - screenCenter).Magnitude

                        if screenDistance < closestDistance and hasLineOfSight(head) then
                            closestDistance = screenDistance
                            closestTarget = head
                        end
                    end
                end
            end
        end
    end

    return closestTarget
end

local function applyHighlight(player)
    local character = player.Character
    if not character then return end

    if player == LocalPlayer or isTeammate(player) then
        local existingHighlight = character:FindFirstChild("NexoraHighlight")
        if existingHighlight then
            existingHighlight:Destroy()
        end
        return
    end

    local highlight = character:FindFirstChild("NexoraHighlight")

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "NexoraHighlight"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = character
    end

    highlight.FillColor = Color3.fromRGB(255, 60, 60)
    highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
end

local function clearHighlight(player)
    local character = player.Character

    if character then
        local highlight = character:FindFirstChild("NexoraHighlight")
        if highlight then
            highlight:Destroy()
        end
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            task.wait(0.3)
            applyHighlight(player)
        end)
        applyHighlight(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.3)
        applyHighlight(player)
    end)
end)

Players.PlayerRemoving:Connect(clearHighlight)

RunService.RenderStepped:Connect(function()
    local screenCenter = getScreenCenter()
    FieldOfViewCircle.Position = screenCenter
    FieldOfViewCircle.Radius = FieldOfViewSize

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if isTeammate(player) then
                clearHighlight(player)
            else
                applyHighlight(player)
            end
        end
    end

    local shouldAim

    if AlwaysAiming then
        shouldAim = true
    elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        shouldAim = IsTouching
    else
        shouldAim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    if shouldAim then
        local target = findTarget(screenCenter)

        if target then
            CurrentCamera.CFrame = CFrame.new(CurrentCamera.CFrame.Position, target.Position)
        end
    end
end)
