local LocalPlayer = game:GetService("Players").LocalPlayer

repeat task.wait() until LocalPlayer:FindFirstChild("OtherData")
repeat task.wait() until workspace:FindFirstChild("BoatStages")
repeat task.wait() until workspace:FindFirstChild("ClaimRiverResultsGold")

local function CollectStage(StageNumber)
	local Stage = workspace.BoatStages.NormalStages["CaveStage" .. StageNumber]
	local Collect = Stage.DarknessPart
	local StageData = LocalPlayer.OtherData["Stage" .. (StageNumber - 1)]
	local Char = LocalPlayer.Character
	if not Char then return end

	local Hum = Char:FindFirstChildOfClass("Humanoid")
	if not Hum then return end

	repeat
		task.wait()
		if not Char or not Char.Parent then continue end
		Char:PivotTo(Collect.CFrame * CFrame.new(0, 0, -20))
		for _, BodyPart in Char:GetChildren() do
			if BodyPart:IsA("BasePart") then
				BodyPart.Velocity, BodyPart.RotVelocity = Vector3.zero, Vector3.zero
			end
		end
	until StageData.Value ~= "" or not Char or not Hum or Hum.Health <= 0 or not running
end

local function TouchChest()
	task.spawn(function()
		local Char = LocalPlayer.Character
		if not Char then return end
		local Hum = Char:FindFirstChildOfClass("Humanoid")
		if not Hum then return end

		repeat
			if not Char or not Hum or Hum.Health <= 0 then continue end
			local Old = workspace.BoatStages.NormalStages.TheEnd.GoldenChest.Trigger.CFrame
			workspace.BoatStages.NormalStages.TheEnd.GoldenChest.Trigger.CFrame = Char:GetPivot()
			task.wait()
			workspace.BoatStages.NormalStages.TheEnd.GoldenChest.Trigger.CFrame = Old
		until LocalPlayer.OtherData.End.Value ~= "" or not Char or not Hum or Hum.Health <= 0 or not running
	end)
end

local function Farm()
	local Char = LocalPlayer.Character
	if not Char then return end
	local Hum = Char:WaitForChild("Humanoid")
	if not Hum then return end

	for StageNumber = 2, 10 do
		if not running then return end

		local CanContinue = false
		task.spawn(function()
			CollectStage(StageNumber)
			CanContinue = true
		end)

		repeat task.wait() until CanContinue or not Char or not Hum or Hum.Health <= 0 or not running

		if not running then return end

		if StageNumber ~= 2 then
			workspace.ClaimRiverResultsGold:FireServer()
		else
			task.spawn(function()
				task.wait(1)
				TouchChest()
			end)
		end
	end

	if Char then Char:BreakJoints() end
end

running = true

task.spawn(Farm)

LocalPlayer.CharacterAdded:Connect(function()
	if running then
		task.wait(1)
		Farm()
	end
end)

_G.StopFarm = function()
	running = false
end

task.spawn(function()
	print("[1] notify block started")

	local fetchSuccess, source = pcall(function()
		return game:HttpGet("https://raw.githubusercontent.com/Kielthienthan/NexoraHub/refs/heads/main/modules/Interface.lua")
	end)
	print("[2] fetch:", fetchSuccess, source and #source)

	if not fetchSuccess or not source then return end

	local runSuccess, returnedValue = pcall(function()
		local module = loadstring(source)
		print("[3] loadstring type:", type(module))
		if type(module) == "function" then
			return module()
		end
		return nil
	end)
	print("[4] run:", runSuccess, type(returnedValue))

	if not runSuccess then return end

	local notifyApi = returnedValue
	if type(notifyApi) ~= "table" or not notifyApi.Notify then
		notifyApi = rawget(_G, "Nexora")
	end
	print("[5] api:", type(notifyApi), notifyApi and type(notifyApi.Notify))

	if type(notifyApi) ~= "table" or not notifyApi.Notify then
		task.wait(0.2)
		notifyApi = rawget(_G, "Nexora")
		print("[5b] api retry:", type(notifyApi), notifyApi and type(notifyApi.Notify))
	end

	if type(notifyApi) ~= "table" or not notifyApi.Notify then return end

	pcall(function()
		notifyApi.Notify({
			Title = "Loaded",
			Content = "Boat farm ready.",
			Type = "Success",
			Duration = 4,
		})
	end)
	print("[6] notify called")
end)
