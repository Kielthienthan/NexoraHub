--[[
    AirFlow Notification System (Standalone)
    Extracted from AirFlow UI Library
    Compatible with: PC, Mobile, Tablet, Console
]]

local TweenService    = game:GetService("TweenService")
local Players         = game:GetService("Players")
local UserInputService= game:GetService("UserInputService")

local LocalPlayer     = Players.LocalPlayer
local Touch           = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

--============================================================
-- THEME
--============================================================
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end

local Theme = {
    Background  = rgb(20,16,20),
    Surface     = rgb(24,19,24),
    Surface2    = rgb(28,22,28),
    Surface3    = rgb(42,36,43),
    Stroke      = rgb(40,32,41),
    StrokeHover = rgb(88,70,90),
    Accent      = rgb(235,199,246),
    AccentDark  = rgb(24,18,26),
    Text        = rgb(233,229,234),
    Muted       = rgb(138,127,139),
    Glow        = rgb(226,218,230),
    Warning     = rgb(240,176,108),
    Success     = rgb(150,220,170),
    Error       = rgb(240,120,120),
}

local Assets = {
    Shadow = "rbxassetid://6014261993",
    Glow   = "rbxassetid://8992230677",
}

--============================================================
-- FONTS  (with fallback for older Roblox clients)
--============================================================
local FontRegular, FontMedium, FontBold
local fontOk = pcall(function()
    local path  = "rbxasset://fonts/families/BuilderSans.json"
    FontRegular = Font.new(path, Enum.FontWeight.Regular)
    FontMedium  = Font.new(path, Enum.FontWeight.Medium)
    FontBold    = Font.new(path, Enum.FontWeight.SemiBold)
end)
if not fontOk then
    FontRegular = Enum.Font.Gotham
    FontMedium  = Enum.Font.GothamMedium
    FontBold    = Enum.Font.GothamBold
end

--============================================================
-- INSTANCE HELPERS
--============================================================
local function create(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            if k ~= "Parent" then inst[k] = v end
        end
    end
    if children then
        for _, child in ipairs(children) do child.Parent = inst end
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = radius or UDim.new(0,8),
        Parent = parent,
    })
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or Theme.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, l, r, t, b)
    return create("UIPadding", {
        PaddingLeft   = UDim.new(0, l or 0),
        PaddingRight  = UDim.new(0, r or 0),
        PaddingTop    = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent = parent,
    })
end

local function textLabel(props)
    local d = {
        BackgroundTransparency = 1,
        TextColor3 = Theme.Text,
        TextSize   = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate   = Enum.TextTruncate.AtEnd,
    }
    if typeof(FontMedium) == "EnumItem" then
        d.Font = FontMedium
    else
        d.FontFace = FontMedium
    end
    if props then
        for k,v in pairs(props) do d[k] = v end
    end
    return create("TextLabel", d)
end

local function glow(parent, size, position, transparency, rotation)
    local img = create("ImageLabel", {
        AnchorPoint = Vector2.new(.5,.5),
        Position    = position,
        Size        = size,
        BackgroundTransparency = 1,
        Image       = Assets.Glow,
        ImageColor3 = Theme.Glow,
        ImageTransparency = transparency,
        ZIndex = 0,
        Parent = parent,
    })
    create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1,1,1), Theme.Accent),
        Rotation = rotation or 90,
        Parent = img,
    })
    return img
end

local function noise(parent)
    return create("Frame", {
        Position = UDim2.fromOffset(0,0),
        Size = UDim2.new(1,0,0,1),
        BackgroundColor3 = Color3.new(1,1,1),
        BackgroundTransparency = .93,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = parent,
    })
end

--============================================================
-- TWEEN CACHE
--============================================================
local tweenCache = {}
local function tween(obj, props, duration, style, dir)
    duration = duration or .2
    if duration <= 0 then
        for k,v in pairs(props) do obj[k] = v end
        return nil
    end
    style = style or Enum.EasingStyle.Quart
    dir   = dir   or Enum.EasingDirection.Out
    local key = duration .. style.Name .. dir.Name
    local info = tweenCache[key]
    if not info then
        info = TweenInfo.new(duration, style, dir)
        tweenCache[key] = info
    end
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

--============================================================
-- NOTIFICATION CLASS
--============================================================
local TypeColorMap = {
    Info    = "Accent",
    Success = "Success",
    Warning = "Warning",
    Error   = "Error",
}

local Notifications = {}
Notifications.__index = Notifications

local function makeHolder(gui)
    local holder = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1,1),
        Position    = UDim2.new(1,-20,1,-20),
        Size        = UDim2.new(0,280,1,-40),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0,4),
        Parent = holder,
    })
    local function resize()
        local w = math.min(280, gui.AbsoluteSize.X - 40)
        holder.Size = UDim2.new(0, w, 1, -40)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    task.defer(resize)
    return holder
end

function Notifications.new(gui)
    local self = setmetatable({}, Notifications)
    self.Holder = makeHolder(gui)
    self.Order  = 0
    self.Max    = 4
    self.Toasts = {}
    return self
end

function Notifications:SetTheme(partial)
    for k,v in pairs(partial or {}) do
        if Theme[k] then Theme[k] = v end
    end
end

function Notifications:Notify(opts)
    opts = opts or {}
    local duration  = opts.Duration or 4
    local typeKey   = TypeColorMap[opts.Type]
    local accent    = typeKey and Theme[typeKey] or Theme.Accent
    local titleCol  = (typeKey and opts.Type ~= "Info") and accent or Theme.Text

    self.Order += 1

    -- outer container (size animation)
    local container = create("Frame", {
        Size = UDim2.new(1,0,0,0),
        BackgroundTransparency = 1,
        LayoutOrder = self.Order,
        Parent = self.Holder,
    })

    -- inner scroller (slide in/out)
    local scroller = create("Frame", {
        Position = UDim2.fromOffset(320,0),
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = container,
    })

    local shadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-20,-20),
        Size = UDim2.new(1,40,1,40),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0,0,0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49,49,450,450),
        ZIndex = 0,
        Parent = scroller,
    })

    local card = create("CanvasGroup", {
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = scroller,
    })
    corner(card, UDim.new(0,10))
    local cardStroke = stroke(card, Theme.Stroke)
    noise(card)
    glow(card, UDim2.fromOffset(260,120), UDim2.new(1,-10,0,-10), .86, 90)

    local content = create("Frame", {
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card,
    })
    padding(content, 16,16,14,24)

    -- left accent bar
    local bar = create("Frame", {
        Position = UDim2.fromOffset(0,14),
        Size = UDim2.new(0,2,1,-28),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(bar, UDim.new(1,0))

    -- title
    textLabel({
        Position = UDim2.fromOffset(0,0),
        Size = UDim2.new(1,-28,0,16),
        Text = opts.Title or "Notification",
        TextSize = 14,
        TextColor3 = titleCol,
        Parent = content,
    })

    -- close button (touch friendly)
    local closeBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1,0),
        Position = UDim2.new(1,6,0,-5),
        Size = UDim2.fromOffset(24,24),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 22,
        AutoButtonColor = false,
        Parent = content,
    })
    if typeof(FontBold) == "EnumItem" then
        closeBtn.Font = FontBold
    else
        closeBtn.FontFace = FontBold
    end
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, {TextColor3 = Theme.Text}, .15)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, {TextColor3 = Theme.Muted}, .2)
    end)

    -- body text
    if opts.Content then
        textLabel({
            Position = UDim2.fromOffset(0,21),
            Size = UDim2.new(1,0,0,0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = opts.Content,
            TextSize = 13,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = content,
        })
    end

    -- progress bar
    local progressBg = create("Frame", {
        AnchorPoint = Vector2.new(0,1),
        Position = UDim2.new(0,16,1,-8),
        Size = UDim2.new(1,-32,0,3),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(progressBg, UDim.new(1,0))

    local progressFill = create("Frame", {
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = progressBg,
    })
    corner(progressFill, UDim.new(1,0))

    -- entrance animations
    task.defer(function()
        if container.Parent and card.Parent then
            tween(container, {
                Size = UDim2.new(1,0,0, card.AbsoluteSize.Y)
            }, .3, Enum.EasingStyle.Quint)
        end
    end)
    tween(scroller, {Position = UDim2.fromOffset(0,0)}, .5, Enum.EasingStyle.Back)
    tween(card,     {GroupTransparency = 0}, .3)
    tween(shadow,   {ImageTransparency = .6}, .4)
    tween(progressFill, {Size = UDim2.fromScale(0,1)}, duration, Enum.EasingStyle.Linear)

    -- dismiss
    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        for i,v in ipairs(self.Toasts) do
            if v == dismiss then table.remove(self.Toasts, i) break end
        end
        tween(scroller,  {Position = UDim2.fromOffset(320,0)}, .3, Enum.EasingStyle.Quint)
        tween(card,      {GroupTransparency = 1}, .2)
        tween(cardStroke,{Transparency = 1}, .15)
        tween(shadow,    {ImageTransparency = 1}, .2)
        task.delay(.22, function()
            container.ClipsDescendants = true
            tween(container, {Size = UDim2.new(1,0,0,-4)}, .22, Enum.EasingStyle.Quint)
            task.delay(.24, function() container:Destroy() end)
        end)
    end

    task.delay(duration, dismiss)
    closeBtn.MouseButton1Click:Connect(dismiss)
    table.insert(self.Toasts, dismiss)

    -- cap concurrent notifications
    while #self.Toasts > self.Max do
        local first = table.remove(self.Toasts, 1)
        first()
    end

    return { Dismiss = dismiss }
end

--============================================================
-- AUTO SETUP
--============================================================
local ScreenGui = create("ScreenGui", {
    Name = "AirFlowNotifications",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
})

local ok = pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)
if not ok or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Notifier = Notifications.new(ScreenGui)

-- global shorthand
_G.AirFlowNotify = function(opts) return Notifier:Notify(opts) end

return Notifier
