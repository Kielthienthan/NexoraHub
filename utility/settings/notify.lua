local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "NexoraNotify"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999

local ok = pcall(function()
	gui.Parent = game:GetService("CoreGui")
end)
if not ok or not gui.Parent then
	gui.Parent = Player:WaitForChild("PlayerGui")
end

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(1, 1)
holder.Position = UDim2.new(1, -20, 1, -20)
holder.Size = UDim2.new(0, 280, 1, -40)
holder.BackgroundTransparency = 1
holder.Parent = gui

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = holder

local function fitHolder()
	local w = gui.AbsoluteSize.X - 40
	if w > 280 then w = 280 end
	if w < 100 then w = 100 end
	holder.Size = UDim2.new(0, w, 1, -40)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHolder)
task.defer(fitHolder)

local BG_COLOR = Color3.fromRGB(20, 16, 20)
local STROKE_COLOR = Color3.fromRGB(244, 143, 177)
local STROKE_HOVER = Color3.fromRGB(240, 150, 175)
local ACCENT_COLOR = Color3.fromRGB(235, 199, 246)
local TEXT_COLOR = Color3.fromRGB(233, 229, 234)
local MUTED_COLOR = Color3.fromRGB(138, 127, 139)
local GLOW_COLOR = Color3.fromRGB(226, 218, 230)
local TRACK_COLOR = Color3.fromRGB(42, 36, 43)
local OK_COLOR = Color3.fromRGB(150, 220, 170)
local WARN_COLOR = Color3.fromRGB(240, 176, 108)
local ERR_COLOR = Color3.fromRGB(240, 120, 120)

local SHADOW_IMG = "rbxassetid://6014261993"
local GLOW_IMG = "rbxassetid://8992230677"

local fReg, fMed, fBold
local gotFont = pcall(function()
	local p = "rbxasset://fonts/families/BuilderSans.json"
	fReg = Font.new(p, Enum.FontWeight.Regular)
	fMed = Font.new(p, Enum.FontWeight.Medium)
	fBold = Font.new(p, Enum.FontWeight.SemiBold)
end)
if not gotFont then
	fReg = Enum.Font.Gotham
	fMed = Enum.Font.GothamMedium
	fBold = Enum.Font.GothamBold
end

local function tween(obj, goal, dur, style, dir)
	dur = dur or 0.2
	if dur <= 0 then
		for k, v in pairs(goal) do
			obj[k] = v
		end
		return
	end
	style = style or Enum.EasingStyle.Quart
	dir = dir or Enum.EasingDirection.Out
	local t = TweenService:Create(obj, TweenInfo.new(dur, style, dir), goal)
	t:Play()
	return t
end

local toastId = 0
local liveToasts = {}
local MAX_TOASTS = 4

local function notify(opts)
	opts = opts or {}
	local dur = opts.Duration or 4
	local kind = opts.Type or "Info"

	local accent = STROKE_COLOR
	if kind == "Warning" then
		accent = WARN_COLOR
	elseif kind == "Error" then
		accent = ERR_COLOR
	end

	toastId = toastId + 1

	local box = Instance.new("Frame")
	box.Name = "Toast"
	box.Size = UDim2.new(1, 0, 0, 0)
	box.BackgroundTransparency = 1
	box.LayoutOrder = toastId
	box.Parent = holder

	local slider = Instance.new("Frame")
	slider.Position = UDim2.fromOffset(320, 0)
	slider.Size = UDim2.new(1, 0, 0, 0)
	slider.AutomaticSize = Enum.AutomaticSize.Y
	slider.BackgroundTransparency = 1
	slider.Parent = box

	local shadow = Instance.new("ImageLabel")
	shadow.Position = UDim2.fromOffset(-20, -20)
	shadow.Size = UDim2.new(1, 40, 1, 40)
	shadow.BackgroundTransparency = 1
	shadow.Image = SHADOW_IMG
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = 1
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(49, 49, 450, 450)
	shadow.ZIndex = 0
	shadow.Parent = slider

	local card = Instance.new("CanvasGroup")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = BG_COLOR
	card.BorderSizePixel = 0
	card.GroupTransparency = 1
	card.Parent = slider

	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = card

	local outline = Instance.new("UIStroke")
	outline.Color = STROKE_COLOR
	outline.Transparency = 0
	outline.Thickness = 1.5
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = card

	local tint = Instance.new("Frame")
	tint.Position = UDim2.fromOffset(0, 0)
	tint.Size = UDim2.new(1, 0, 0, 1)
	tint.BackgroundColor3 = Color3.new(1, 1, 1)
	tint.BackgroundTransparency = 0.93
	tint.BorderSizePixel = 0
	tint.ZIndex = 0
	tint.Parent = card

	local glow = Instance.new("ImageLabel")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(1, -10, 0, -10)
	glow.Size = UDim2.fromOffset(260, 120)
	glow.BackgroundTransparency = 1
	glow.Image = GLOW_IMG
	glow.ImageColor3 = GLOW_COLOR
	glow.ImageTransparency = 0.86
	glow.ZIndex = 0
	glow.Parent = card

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), ACCENT_COLOR)
	grad.Rotation = 90
	grad.Parent = glow

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 24)
	pad.Parent = content

	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(0, 14)
	bar.Size = UDim2.new(0, 2, 1, -28)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = card

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = bar

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.new(1, -28, 0, 16)
	title.BackgroundTransparency = 1
	title.Text = opts.Title or "Notification"
	title.TextSize = 14
	title.TextColor3 = TEXT_COLOR
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextTruncate = Enum.TextTruncate.AtEnd
	if typeof(fMed) == "EnumItem" then
		title.Font = fMed
	else
		title.FontFace = fMed
	end
	title.Parent = content

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 6, 0, -5)
	close.Size = UDim2.fromOffset(24, 24)
	close.BackgroundTransparency = 1
	close.Text = "×"
	close.TextColor3 = MUTED_COLOR
	close.TextSize = 22
	close.AutoButtonColor = false
	if typeof(fBold) == "EnumItem" then
		close.Font = fBold
	else
		close.FontFace = fBold
	end
	close.Parent = content

	close.MouseEnter:Connect(function()
		tween(close, {TextColor3 = TEXT_COLOR}, 0.15)
	end)
	close.MouseLeave:Connect(function()
		tween(close, {TextColor3 = MUTED_COLOR}, 0.2)
	end)

	if opts.Content then
		local body = Instance.new("TextLabel")
		body.Position = UDim2.fromOffset(0, 21)
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.BackgroundTransparency = 1
		body.Text = opts.Content
		body.TextSize = 13
		body.TextColor3 = MUTED_COLOR
		body.TextWrapped = true
		body.TextTruncate = Enum.TextTruncate.None
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		if typeof(fReg) == "EnumItem" then
			body.Font = fReg
		else
			body.FontFace = fReg
		end
		body.Parent = content
	end

	local progBg = Instance.new("Frame")
	progBg.AnchorPoint = Vector2.new(0, 1)
	progBg.Position = UDim2.new(0, 16, 1, -8)
	progBg.Size = UDim2.new(1, -32, 0, 3)
	progBg.BackgroundColor3 = TRACK_COLOR
	progBg.BorderSizePixel = 0
	progBg.Parent = card

	local pbc = Instance.new("UICorner")
	pbc.CornerRadius = UDim.new(1, 0)
	pbc.Parent = progBg

	local progFill = Instance.new("Frame")
	progFill.Size = UDim2.fromScale(1, 1)
	progFill.BackgroundColor3 = accent
	progFill.BorderSizePixel = 0
	progFill.Parent = progBg

	local pfc = Instance.new("UICorner")
	pfc.CornerRadius = UDim.new(1, 0)
	pfc.Parent = progFill

	task.defer(function()
		if box.Parent and card.Parent then
			tween(box, {Size = UDim2.new(1, 0, 0, card.AbsoluteSize.Y)}, 0.3, Enum.EasingStyle.Quint)
		end
	end)
	tween(slider, {Position = UDim2.fromOffset(0, 0)}, 0.5, Enum.EasingStyle.Back)
	tween(card, {GroupTransparency = 0}, 0.3)
	tween(shadow, {ImageTransparency = 0.6}, 0.4)
	tween(progFill, {Size = UDim2.fromScale(0, 1)}, dur, Enum.EasingStyle.Linear)

	local dead = false
	local function dismiss()
		if dead then return end
		dead = true

		for i, v in ipairs(liveToasts) do
			if v == dismiss then
				table.remove(liveToasts, i)
				break
			end
		end

		tween(slider, {Position = UDim2.fromOffset(320, 0)}, 0.3, Enum.EasingStyle.Quint)
		tween(card, {GroupTransparency = 1}, 0.2)
		tween(outline, {Transparency = 1}, 0.15)
		tween(shadow, {ImageTransparency = 1}, 0.2)

		task.delay(0.22, function()
			box.ClipsDescendants = true
			tween(box, {Size = UDim2.new(1, 0, 0, -4)}, 0.22, Enum.EasingStyle.Quint)
			task.delay(0.24, function()
				box:Destroy()
			end)
		end)
	end

	task.delay(dur, dismiss)
	close.MouseButton1Click:Connect(dismiss)

	table.insert(liveToasts, dismiss)

	while #liveToasts > MAX_TOASTS do
		local oldest = table.remove(liveToasts, 1)
		oldest()
	end

	return { Dismiss = dismiss }
end

_G.NexoraNotify = notify

return {
	Notify = notify,
}
