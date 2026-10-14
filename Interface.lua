local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AirFlow = {}
AirFlow.Flags = {}
AirFlow.Windows = {}

local function normalize(input, defaults)
    local out = {}
    if type(input) == "string" then
        out.Name = input
    elseif type(input) == "table" then
        for k, v in pairs(input) do out[k] = v end
    end
    for from, to in pairs(defaults or {}) do
        if out[to] == nil and out[from] ~= nil then out[to] = out[from] end
    end
    if out.Range then
        out.Min = out.Min or out.Range[1]
        out.Max = out.Max or out.Range[2]
    end
    return out
end

local setupElementMethods

local function register(tab, config, state, frame, elementType, callbackKey)
    state._type = elementType
    state._frame = frame
    state._listeners = state._listeners or {}
    local window = tab and tab.Window

    if config.Flag then
        AirFlow.Flags[config.Flag] = state
        if window then
            window.Flags[config.Flag] = state
            callbackKey = callbackKey or "Callback"
            local original = config[callbackKey]
            config[callbackKey] = function(...)
                if type(original) == "function" then original(...) end
                window:_autoSave()
            end
        end
    end

    function state:Destroy()
        if state._destroyed then return end
        state._destroyed = true
        for _, listener in ipairs(state._listeners) do listener() end
        state._listeners = {}
        if config.Flag then
            if AirFlow.Flags[config.Flag] == state then AirFlow.Flags[config.Flag] = nil end
            if window and window.Flags[config.Flag] == state then window.Flags[config.Flag] = nil end
        end
        if window then window._controlsDirty = true end
        if frame then frame:Destroy() end
    end

    if frame then setupElementMethods(state, frame, config) end
    return state
end

local THEME_KEYS = {
    "Background","Surface","Surface2","Surface3","Stroke","StrokeHover",
    "Accent","AccentDark","Text","Muted","Glow","Warning","Success","Error"
}

local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end

local statusColors = {
    Warning = rgb(240,176,108),
    Success = rgb(150,220,170),
    Error   = rgb(240,120,120)
}

local function withStatus(theme)
    for k,v in pairs(statusColors) do
        if theme[k] == nil then theme[k] = v end
    end
    return theme
end

AirFlow.Themes = {
    Default = withStatus {
        Background = rgb(20,16,20),
        Surface = rgb(24,19,24),
        Surface2 = rgb(28,22,28),
        Surface3 = rgb(42,36,43),
        Stroke = rgb(40,32,41),
        StrokeHover = rgb(88,70,90),
        Accent = rgb(235,199,246),
        AccentDark = rgb(24,18,26),
        Text = rgb(233,229,234),
        Muted = rgb(138,127,139),
        Glow = rgb(226,218,230)
    },
    Midnight = withStatus {
        Background = rgb(14,16,22),
        Surface = rgb(18,21,28),
        Surface2 = rgb(22,25,34),
        Surface3 = rgb(36,41,54),
        Stroke = rgb(32,36,48),
        StrokeHover = rgb(70,80,104),
        Accent = rgb(150,180,255),
        AccentDark = rgb(12,16,28),
        Text = rgb(226,230,240),
        Muted = rgb(122,131,153),
        Glow = rgb(210,220,240)
    },
    Moss = withStatus {
        Background = rgb(15,18,15),
        Surface = rgb(19,23,19),
        Surface2 = rgb(23,28,23),
        Surface3 = rgb(37,44,37),
        Stroke = rgb(33,40,33),
        StrokeHover = rgb(72,88,72),
        Accent = rgb(176,222,170),
        AccentDark = rgb(14,22,14),
        Text = rgb(228,234,227),
        Muted = rgb(121,136,119),
        Glow = rgb(214,230,212)
    },
    Ember = withStatus {
        Background = rgb(20,16,13),
        Surface = rgb(25,20,16),
        Surface2 = rgb(30,24,19),
        Surface3 = rgb(46,37,30),
        Stroke = rgb(42,34,27),
        StrokeHover = rgb(96,76,58),
        Accent = rgb(255,190,140),
        AccentDark = rgb(28,18,10),
        Text = rgb(240,232,226),
        Muted = rgb(146,129,113),
        Glow = rgb(240,222,208)
    },
    Rose = withStatus {
        Background = rgb(21,14,17),
        Surface = rgb(26,18,21),
        Surface2 = rgb(31,21,25),
        Surface3 = rgb(48,34,40),
        Stroke = rgb(44,30,36),
        StrokeHover = rgb(100,66,80),
        Accent = rgb(255,170,195),
        AccentDark = rgb(30,12,18),
        Text = rgb(240,228,232),
        Muted = rgb(149,124,133),
        Glow = rgb(240,214,222)
    },
    Mono = withStatus {
        Background = rgb(16,16,17),
        Surface = rgb(20,20,21),
        Surface2 = rgb(24,24,26),
        Surface3 = rgb(40,40,43),
        Stroke = rgb(36,36,39),
        StrokeHover = rgb(80,80,86),
        Accent = rgb(230,230,235),
        AccentDark = rgb(18,18,20),
        Text = rgb(232,232,236),
        Muted = rgb(130,130,136),
        Glow = rgb(220,220,226)
    }
}

AirFlow.Theme = table.clone(AirFlow.Themes.Default)
AirFlow.ThemeName = "Default"
AirFlow.Assets = {
    Shadow = "rbxassetid://6014261993",
    Glow = "rbxassetid://8992230677",
    Logo = "rbxassetid://103859712365480"
}

local lucideCache
local function loadLucide()
    if lucideCache ~= nil then return lucideCache end
    local ok, icons = pcall(function()
        local src = game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua")
        return loadstring(src)()
    end)
    if ok and type(icons) == "table" then
        lucideCache = icons
    else
        lucideCache = false
        warn("[AirFlow] lucide icons unavailable: " .. tostring(icons))
    end
    return lucideCache
end

local fontPresets = {
    ValleySans = {
        Regular = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-Regular.ttf",
        Medium = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-Medium.ttf",
        SemiBold = "https://raw.githubusercontent.com/HelsinkiTypeStudio/valley-sans/main/fonts/ttf/ValleySans-SemiBold.ttf"
    }
}

local weightMeta = {
    Regular = {400, Enum.FontWeight.Regular},
    Medium = {500, Enum.FontWeight.Medium},
    SemiBold = {600, Enum.FontWeight.SemiBold},
    Bold = {700, Enum.FontWeight.Bold}
}

function AirFlow:LoadFont(opts)
    opts = normalize(opts, {})
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[AirFlow] custom fonts need writefile, isfile and getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    local weights = opts.Weights or fontPresets[name]
    if type(weights) ~= "table" then
        warn("[AirFlow] no font weights for " .. name)
        return false
    end
    local folder = opts.Folder or "AirFlowFonts"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
            makefolder(folder)
        end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local meta = weightMeta[weightName]
        if meta then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then
                ok = pcall(function() writefile(path, game:HttpGet(url)) end)
            end
            if ok then
                table.insert(faces, {
                    name = weightName,
                    weight = meta[1],
                    style = "normal",
                    assetId = getcustomasset(path)
                })
            else
                warn("[AirFlow] could not download " .. weightName .. " weight of " .. name)
            end
        end
    end
    if #faces == 0 then return false end
    local jsonPath = folder .. "/" .. name .. ".json"
    local wrote = pcall(function()
        writefile(jsonPath, HttpService:JSONEncode{name = name, faces = faces})
    end)
    if not wrote then return false end
    local asset = getcustomasset(jsonPath)
    local function pick(weightName, fallback)
        local meta = weightMeta[weightName]
        if meta and weights[weightName] then return Font.new(asset, meta[2]) end
        return fallback
    end
    AirFlow.Fonts.Regular = pick("Regular", AirFlow.Fonts.Regular)
    AirFlow.Fonts.Medium = pick("Medium", pick("Regular", AirFlow.Fonts.Medium))
    AirFlow.Fonts.Bold = pick("SemiBold", pick("Bold", AirFlow.Fonts.Bold))
    return true
end

function AirFlow:PreloadIcons()
    return loadLucide() ~= false
end

local function resolveIcon(icon)
    if typeof(icon) == "table" then
        return icon.Image, icon.RectOffset, icon.RectSize
    end
    if type(icon) ~= "string" then return nil end
    if icon:find("^rbxassetid://") or icon:find("^rbxasset://") or icon:find("^http") then
        return icon
    end
    local name = icon:gsub("^lucide:", "")
    local icons = loadLucide()
    if not icons then return nil end
    local data = (icons.Icons and icons.Icons[name]) or icons[name]
    if type(data) == "table" then
        local img = data.Image
        if type(img) == "number" then img = "rbxassetid://" .. tostring(img) end
        local sheet = (icons.Spritesheets and icons.Spritesheets[tostring(img)]) or img
        return sheet, data.ImageRectPosition, data.ImageRectSize
    elseif type(data) == "string" then
        return data
    end
    warn("[AirFlow] unknown lucide icon: " .. name)
    return nil
end

local fontPath = "rbxasset://fonts/families/BuilderSans.json"
AirFlow.Fonts = {
    Regular = Font.new(fontPath, Enum.FontWeight.Regular),
    Medium = Font.new(fontPath, Enum.FontWeight.Medium),
    Bold = Font.new(fontPath, Enum.FontWeight.SemiBold)
}

local Theme = AirFlow.Theme
local Assets = AirFlow.Assets
local Fonts = AirFlow.Fonts

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
AirFlow.Touch = isTouch
local ROW = isTouch and 54 or 48
local ROW_DESC = isTouch and 70 or 64
local ITEM_H = isTouch and 40 or 34
local CHIP_H = isTouch and 34 or 28

local tweenCache = {}
local function tween(obj, goal, duration, style, direction)
    duration = duration or 0.2
    if duration <= 0 then
        for k,v in pairs(goal) do obj[k] = v end
        return nil
    end
    style = style or Enum.EasingStyle.Quart
    direction = direction or Enum.EasingDirection.Out
    local key = duration .. style.Name .. direction.Name
    local info = tweenCache[key]
    if not info then
        info = TweenInfo.new(duration, style, direction)
        tweenCache[key] = info
    end
    local t = TweenService:Create(obj, info, goal)
    t:Play()
    return t
end

local function create(class, props, children)
    local inst = Instance.new(class)
    for prop, value in pairs(props) do
        if prop ~= "Parent" then inst[prop] = value end
    end
    if children then
        for _, child in ipairs(children) do child.Parent = inst end
    end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local function corner(parent, radius)
    return create("UICorner", {CornerRadius = radius or UDim.new(0,8), Parent = parent})
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or Theme.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

local function pad(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent
    })
end

local function textLabel(props)
    local defaults = {
        BackgroundTransparency = 1,
        TextColor3 = Theme.Text,
        TextSize = 14,
        FontFace = Fonts.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd
    }
    for k,v in pairs(props) do defaults[k] = v end
    return create("TextLabel", defaults)
end

local function glowLayer(parent, size, position, transparency, rotation)
    local img = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Theme.Glow,
        ImageTransparency = transparency,
        ZIndex = 0,
        Parent = parent
    })
    create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255,255,255), Theme.Accent),
        Rotation = rotation or 90,
        Parent = img
    })
    return img
end

local function tintOverlay(parent)
    return create("Frame", {
        Position = UDim2.fromOffset(0,0),
        Size = UDim2.new(1,0,0,1),
        BackgroundColor3 = Color3.new(1,1,1),
        BackgroundTransparency = 0.93,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = parent
    })
end

local function applyIcon(imageLabel, icon)
    local img, rectOffset, rectSize = resolveIcon(icon)
    if not img then return end
    imageLabel.Image = img
    imageLabel.ImageRectOffset = rectOffset or Vector2.zero
    imageLabel.ImageRectSize = rectSize or Vector2.zero
end

local function getHui()
    local hui
    pcall(function()
        if typeof(gethui) == "function" then hui = gethui() end
    end)
    if typeof(hui) == "Instance" then return hui end
    local ok = pcall(function()
        local core = game:GetService("CoreGui")
        local probe = Instance.new("Folder")
        probe.Parent = core
        probe:Destroy()
    end)
    if ok then return game:GetService("CoreGui") end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local insetTime, insetVec = nil, Vector2.zero
local function mousePos()
    local now = time()
    if insetTime ~= now then
        insetTime = now
        insetVec = GuiService:GetGuiInset()
    end
    return UserInputService:GetMouseLocation() - insetVec
end

local function isClick(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function iconFrame(parent, icon, color, position)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(0,0.5),
        Position = position,
        Size = UDim2.fromOffset(16,16),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local img = create("ImageLabel", {
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        ImageColor3 = color,
        ScaleType = Enum.ScaleType.Fit,
        Parent = holder
    })
    applyIcon(img, icon)
    return holder, img
end

local function makeChevron(parent, anchorX, offsetX)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(anchorX,0.5),
        Position = UDim2.new(anchorX, offsetX, 0.5, 0),
        Size = UDim2.fromOffset(18,18),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local api = {}
    local arrow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.fromScale(0.5,0.5),
        Size = UDim2.fromOffset(16,16),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ScaleType = Enum.ScaleType.Fit,
        Parent = holder
    })
    applyIcon(arrow, "chevron-down")
    if arrow.Image ~= "" then
        function api:Set(open)
            tween(arrow, {
                Rotation = open and 180 or 0,
                ImageColor3 = open and Theme.Accent or Theme.Muted
            }, 0.3, Enum.EasingStyle.Quint)
        end
        return api
    end
    arrow:Destroy()
    local function makeArrow(rotation, transparency)
        return textLabel {
            AnchorPoint = Vector2.new(0.5,0.5),
            Position = UDim2.fromScale(0.5,0.5),
            Size = UDim2.fromOffset(18,18),
            Text = "›",
            TextSize = 22,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextColor3 = Theme.Muted,
            TextTransparency = transparency,
            Rotation = rotation,
            Parent = holder
        }
    end
    local right = makeArrow(90, 0)
    local down = makeArrow(270, 1)
    function api:Set(open)
        tween(right, {TextTransparency = open and 1 or 0}, 0.2)
        tween(down, {
            TextTransparency = open and 0 or 1,
            TextColor3 = open and Theme.Accent or Theme.Muted
        }, 0.2)
    end
    return api
end

local ripplePool = {}
local function ripple(target, color)
    local click = mousePos()
    local size = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y) * 2.2
    local r = table.remove(ripplePool)
    if not r then
        r = create("Frame", {AnchorPoint = Vector2.new(0.5,0.5), BorderSizePixel = 0})
        corner(r, UDim.new(1,0))
    end
    r.BackgroundColor3 = color or Theme.Accent
    r.Position = UDim2.fromOffset(click.X - target.AbsolutePosition.X, click.Y - target.AbsolutePosition.Y)
    r.Size = UDim2.fromOffset(0,0)
    r.BackgroundTransparency = 0.82
    r.ZIndex = target.ZIndex + 1
    r.Parent = target
    tween(r, {Size = UDim2.fromOffset(size,size), BackgroundTransparency = 1}, 0.55)
    task.delay(0.55, function()
        if r.Parent ~= target then return end
        r.Parent = nil
        if #ripplePool < 4 then
            table.insert(ripplePool, r)
        else
            r:Destroy()
        end
    end)
end

local function flash(s)
    if not s then return end
    tween(s, {Color = Theme.Accent, Transparency = 0.2}, 0.08)
    task.delay(0.12, function()
        tween(s, {Color = Theme.Stroke, Transparency = 0}, 0.35)
    end)
end

local function attachHover(btn, s)
    btn.MouseEnter:Connect(function() tween(s, {Color = Theme.StrokeHover}, 0.12) end)
    btn.MouseLeave:Connect(function() tween(s, {Color = Theme.Stroke}, 0.25) end)
end

local keyNames = {
    [Enum.KeyCode.LeftControl] = "LCtrl",
    [Enum.KeyCode.RightControl] = "RCtrl",
    [Enum.KeyCode.LeftShift] = "LShift",
    [Enum.KeyCode.RightShift] = "RShift",
    [Enum.KeyCode.LeftAlt] = "LAlt",
    [Enum.KeyCode.RightAlt] = "RAlt",
    [Enum.KeyCode.Return] = "Enter",
    [Enum.KeyCode.Escape] = "Esc",
    [Enum.KeyCode.Backspace] = "Backspace"
}

local function keyToName(key)
    if key == nil then return "None" end
    return keyNames[key] or key.Name
end

local function nameToKey(name)
    if typeof(name) == "EnumItem" then return name end
    if type(name) ~= "string" or name == "" or name == "None" then return nil end
    local ok, key = pcall(function() return Enum.KeyCode[name] end)
    if ok then return key end
    warn("[AirFlow] unknown key name: " .. name)
    return nil
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[AirFlow] callback error: " .. tostring(err)) end
end

local function makeStep(min, max, step)
    if max < min then min, max = max, min end
    if not step or step <= 0 then step = 1 end
    local decimals = 0
    while decimals < 6 do
        local scaled = step * 10 ^ decimals
        if math.abs(scaled - math.floor(scaled + 0.5)) < 1e-9 then break end
        decimals += 1
    end
    local fmt = "%." .. decimals .. "f"
    return {
        snap = function(value)
            value = math.floor(value / step + 0.5) * step
            value = tonumber(string.format(fmt, value)) or value
            return math.clamp(value, min, max)
        end,
        format = function(value)
            return string.format(fmt, value)
        end
    }
end

local function buildRow(tab, class, height, config)
    local props = {
        Size = UDim2.new(1,0,0,height),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = tab:_nextOrder(),
        Parent = tab.List
    }
    if class == "TextButton" then
        props.AutoButtonColor = false
        props.Text = ""
    end
    local frame = create(class, props)
    frame:SetAttribute("NoDrag", true)
    corner(frame)
    local s = stroke(frame, Theme.Stroke)
    return frame, s
end

local function buildTitleDesc(parent, name, desc, rightInset)
    local title, descLabel
    if desc then
        local y = (ROW_DESC - 38) / 2
        title = textLabel {
            Name = "Title",
            Position = UDim2.fromOffset(14, y),
            Size = UDim2.new(1, -(14 + rightInset), 0, 18),
            Text = name,
            Parent = parent
        }
        descLabel = textLabel {
            Name = "Desc",
            Position = UDim2.fromOffset(14, y + 20),
            Size = UDim2.new(1, -(14 + rightInset), 0, 17),
            Text = desc,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = parent
        }
    else
        title = textLabel {
            Name = "Title",
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -(14 + rightInset), 1, 0),
            Text = name,
            Parent = parent
        }
    end
    return title, descLabel
end

local function buildElement(tab, config, defaults, class, heightOverride, fallbackName)
    config = normalize(config, defaults)
    local height = config.Desc and ROW_DESC or heightOverride or ROW
    local frame, s = buildRow(tab, class or "Frame", height, config)
    attachHover(frame, s)
    local title, descLabel
    if class == "TextButton" or config.Name then
        title, descLabel = buildTitleDesc(frame, config.Name or fallbackName, config.Desc, class == "TextButton" and 30 or 0)
    end
    return config, frame, s, height, title, descLabel
end

local function shrinkLabels(title, desc, rightInset)
    if title then
        title.Size = UDim2.new(1, -(14 + rightInset), title.Size.Y.Scale, title.Size.Y.Offset)
    end
    if desc then
        desc.Size = UDim2.new(1, -(14 + rightInset), 0, desc.Size.Y.Offset)
    end
end

setupElementMethods = function(state, frame, config)
    local function find(name) return frame:FindFirstChild(name, true) end

    if state.SetTitle == nil then
        function state:SetTitle(value)
            local label = find("Title")
            if label then label.Text = tostring(value) end
        end
    end

    if state.SetDesc == nil then
        function state:SetDesc(value)
            local label = find("Desc")
            if label then
                label.Text = tostring(value)
            else
                warn("[AirFlow] SetDesc needs the element to be created with a Desc")
            end
        end
    end

    state.Visible = true
    function state:SetVisible(value)
        state.Visible = value ~= false
        frame.Visible = state.Visible
    end

    state.Locked = false
    local lockOverlay, lockLabel

    function state:SetLocked(locked, reason)
        state.Locked = locked == true
        if state.Locked and type(state.SetOpen) == "function" then
            state:SetOpen(false)
        end
        if not lockOverlay then
            if not state.Locked then return end
            lockOverlay = create("TextButton", {
                Name = "Lock",
                Size = UDim2.fromScale(1,1),
                BackgroundColor3 = Theme.Background,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 20,
                Parent = frame
            })
            corner(lockOverlay)
            local chip = create("Frame", {
                AnchorPoint = Vector2.new(1,0.5),
                Position = UDim2.new(1,-10,0.5,0),
                Size = UDim2.fromOffset(0, CHIP_H),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel = 0,
                ZIndex = 21,
                Parent = lockOverlay
            })
            corner(chip, UDim.new(0,6))
            stroke(chip)
            pad(chip, 8, 10)
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0,6),
                Parent = chip
            })
            local lockIcon = create("ImageLabel", {
                Size = UDim2.fromOffset(14,14),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.Muted,
                ScaleType = Enum.ScaleType.Fit,
                LayoutOrder = 1,
                ZIndex = 22,
                Parent = chip
            })
            applyIcon(lockIcon, "lock")
            lockLabel = textLabel {
                Size = UDim2.new(0,0,1,0),
                AutomaticSize = Enum.AutomaticSize.X,
                TextSize = 12,
                TextColor3 = Theme.Muted,
                TextTruncate = Enum.TextTruncate.None,
                LayoutOrder = 2,
                ZIndex = 22,
                Parent = chip
            }
        end
        lockLabel.Text = reason or "Locked"
        lockOverlay.Visible = state.Locked
        lockOverlay.BackgroundTransparency = state.Locked and 0.35 or 1
    end

    if config.Locked then state:SetLocked(true, config.LockedReason) end
    if config.Visible == false then state:SetVisible(false) end
end

local Tab = {}
Tab.__index = Tab

function Tab:_nextOrder()
    self._order += 1
    return self._order
end

function Tab:Section(name)
    if type(name) == "table" then name = name.Name or name.Title or "" end
    local container = create("Frame", {
        Size = UDim2.new(1,0,0,28),
        BackgroundTransparency = 1,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List
    })
    local label = textLabel {
        Position = UDim2.fromOffset(2,8),
        Size = UDim2.new(0,0,0,16),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = string.upper(name),
        TextSize = 12,
        TextColor3 = Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        Parent = container
    }
    local line = create("Frame", {
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,0,0,16),
        Size = UDim2.new(1,-12,0,1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = container
    })
    local window = self.Window
    local function update()
        line.Size = UDim2.new(1, -(label.AbsoluteSize.X / window.Scale.Scale + 14), 0, 1)
    end
    label:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
    task.defer(update)
    return register(self, {}, {
        Set = function(_, value) label.Text = string.upper(value) end
    }, container, "Section")
end

function Tab:Divider()
    local line = create("Frame", {
        Size = UDim2.new(1,0,0,1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List
    })
    return register(self, {}, {}, line, "Divider")
end

function Tab:Label(config)
    config = normalize(config, {Name = "Text", Title = "Text"})
    local label = textLabel {
        Size = UDim2.new(1,0,0,18),
        Text = config.Text or "",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = config.Color or Theme.Muted,
        LayoutOrder = self:_nextOrder(),
        Parent = self.List
    }
    pad(label, 2)
    local state = {
        Set = function(_, value) label.Text = tostring(value) end,
        Get = function() return label.Text end
    }
    if type(config.Update) == "function" then
        local rate = math.max(tonumber(config.UpdateRate) or 1, 0.05)
        local active = true
        state._listeners = state._listeners or {}
        table.insert(state._listeners, function() active = false end)
        task.spawn(function()
            while active and label.Parent do
                local ok, result = pcall(config.Update)
                if ok and result ~= nil then
                    label.Text = tostring(result)
                elseif not ok then
                    warn("[AirFlow] label update error: " .. tostring(result))
                end
                task.wait(rate)
            end
        end)
        function state:SetUpdateRate(v)
            rate = math.max(tonumber(v) or rate, 0.05)
        end
    end
    return register(self, config, state, label, "Label")
end

function Tab:Paragraph(config)
    config = normalize(config, {Title = "Name"})
    local container = buildRow(self, "Frame", 0, config)
    container.AutomaticSize = Enum.AutomaticSize.Y
    pad(container, 14, 14, 11, 12)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0,4),
        Parent = container
    })
    textLabel {
        Name = "Title",
        Size = UDim2.new(1,0,0,14),
        Text = config.Name or "",
        LayoutOrder = 1,
        Parent = container
    }
    local content = textLabel {
        Name = "Content",
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = config.Content or "",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2,
        Parent = container
    }
    return register(self, config, {
        Set = function(_, value) content.Text = tostring(value) end,
        Get = function() return content.Text end
    }, container, "Paragraph")
end

local STYLE_MAP = {Primary = "Accent", Danger = "Error"}

function Tab:Button(config)
    config = normalize(config, {Title = "Name", Description = "Desc"})
    local styleKey = STYLE_MAP[config.Style]
    local styled = styleKey ~= nil
    local height = config.Desc and ROW_DESC or ROW
    local button, s = buildRow(self, "TextButton", height, config)
    button.ClipsDescendants = true
    if styled then
        button.BackgroundColor3 = Theme[styleKey]
        button.BackgroundTransparency = 0.12
        s.Color = Theme[styleKey]
        s.Transparency = 0.4
        button.MouseEnter:Connect(function()
            tween(button, {BackgroundTransparency = 0}, 0.12)
            tween(s, {Transparency = 0}, 0.12)
        end)
        button.MouseLeave:Connect(function()
            tween(button, {BackgroundTransparency = 0.12}, 0.25)
            tween(s, {Transparency = 0.4}, 0.25)
        end)
    else
        attachHover(button, s)
    end
    local textColor = styled and Theme.AccentDark or Theme.Text
    local iconPad = 0
    if config.Icon then
        iconFrame(button, config.Icon, styled and Theme.AccentDark or Theme.Accent, UDim2.new(0,14,0.5,0))
        iconPad = 26
    end
    local title, descLabel = buildTitleDesc(button, config.Name or "Button", config.Desc, 30)
    if iconPad > 0 then
        for _, child in ipairs(button:GetChildren()) do
            if child:IsA("TextLabel") then
                child.Position += UDim2.fromOffset(iconPad, 0)
                child.Size -= UDim2.fromOffset(iconPad, 0)
            end
        end
    end
    if styled then
        for _, child in ipairs(button:GetChildren()) do
            if child:IsA("TextLabel") then child.TextColor3 = textColor end
        end
    end
    iconFrame(button, "chevron-right", styled and Theme.AccentDark or Theme.Muted, UDim2.new(1,-30,0.5,0))
    button.MouseButton1Click:Connect(function()
        ripple(button, styled and Theme.AccentDark or Theme.Accent)
        safeCall(config.Callback)
    end)
    local state = {}
    function state:SetText(value) title.Text = tostring(value) end
    state.SetTitle = state.SetText
    return register(self, config, state, button, "Button")
end

function Tab:Toggle(config)
    local row, s, height, title
    config, row, s, height, title = buildElement(self, config, {
        Title = "Name", Description = "Desc", CurrentValue = "Default", Value = "Default"
    }, "TextButton", 56, "Toggle")

    local track = create("Frame", {
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,-14,0.5,0),
        Size = isTouch and UDim2.fromOffset(44,24) or UDim2.fromOffset(36,20),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = row
    })
    corner(track, UDim.new(1,0))
    stroke(track, Theme.Stroke)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0,0.5),
        Position = UDim2.new(0,3,0.5,0),
        Size = isTouch and UDim2.fromOffset(18,18) or UDim2.fromOffset(14,14),
        BackgroundColor3 = Theme.Muted,
        BorderSizePixel = 0,
        Parent = track
    })
    corner(knob, UDim.new(1,0))

    local glow = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.fromScale(0.5,0.5),
        Size = UDim2.new(1,24,1,24),
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Theme.Accent,
        ImageTransparency = 1,
        ZIndex = 0,
        Parent = track
    })

    local state = {Value = config.Default == true}

    local function render(animated)
        local on = state.Value
        local speed = animated and 0.25 or 0
        local knobSize = isTouch and 18 or 14
        local trackW = isTouch and 44 or 36
        tween(track, {BackgroundColor3 = on and Theme.Accent or Theme.Surface3}, speed)
        tween(glow, {ImageTransparency = on and 0.75 or 1}, speed)
        tween(knob, {
            Position = on and UDim2.new(0, trackW - 3 - knobSize, 0.5, 0) or UDim2.new(0,3,0.5,0)
        }, speed, Enum.EasingStyle.Back)
        tween(knob, {BackgroundColor3 = on and Theme.AccentDark or Theme.Muted}, speed)
        if animated then
            tween(knob, {Size = UDim2.fromOffset(knobSize + 4, knobSize - 2)}, 0.08)
            task.delay(0.08, function()
                tween(knob, {Size = UDim2.fromOffset(knobSize, knobSize)}, 0.2, Enum.EasingStyle.Back)
            end)
        end
    end

    local internal = false
    function state:Set(value, silent)
        value = value == true
        if value == state.Value then return end
        state.Value = value
        render(true)
        if not internal then flash(s) end
        if not silent then safeCall(config.Callback, value) end
    end
    function state:Get() return state.Value end

    render(false)
    row.MouseButton1Click:Connect(function()
        internal = true
        state:Set(not state.Value)
        internal = false
    end)

    local element = register(self, config, state, row, "Toggle")
    if state.Value then safeCall(config.Callback, true) end
    return element
end

function Tab:Slider(config)
    config = normalize(config, {
        Title = "Name", Description = "Desc",
        CurrentValue = "Default", Value = "Default", Increment = "Step"
    })
    local minV = math.min(config.Min or 0, config.Max or 100)
    local maxV = math.max(config.Min or 0, config.Max or 100)
    local step = config.Step or 1
    local suffix = config.Suffix or ""
    local fmt = makeStep(minV, maxV, step)
    local rowHeight = ROW_DESC + (config.Desc and 18 or 0)
    local row, s = buildRow(self, "Frame", rowHeight, config)
    attachHover(row, s)

    textLabel {
        Name = "Title",
        Position = UDim2.fromOffset(14,12),
        Size = UDim2.new(1,-120,0,18),
        Text = config.Name or "Slider",
        Parent = row
    }
    if config.Desc then
        textLabel {
            Name = "Desc",
            Position = UDim2.fromOffset(14,31),
            Size = UDim2.new(1,-28,0,17),
            Text = config.Desc,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = row
        }
    end

    local valueBox = create("Frame", {
        AnchorPoint = Vector2.new(1,0),
        Position = UDim2.new(1,-10,0,9),
        Size = UDim2.fromOffset(40,24),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = row
    })
    corner(valueBox, UDim.new(0,6))
    local valueStroke = stroke(valueBox)

    local valueLabel = textLabel {
        Size = UDim2.new(1,0,1,0),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = valueBox
    }

    local inputField = create("TextBox", {
        Position = UDim2.fromOffset(9,0),
        Size = UDim2.new(0,0,1,0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Visible = false,
        Parent = valueBox
    })
    create("UISizeConstraint", {MinSize = Vector2.new(14,0), Parent = inputField})

    local suffixLabel = textLabel {
        Size = UDim2.new(0,0,1,0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = suffix,
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextTruncate = Enum.TextTruncate.None,
        Visible = false,
        Parent = valueBox
    }

    local clickRegion = create("TextButton", {
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
        Parent = valueBox
    })
    local editing = false

    local function resize(instant)
        local width
        if editing then
            width = 9 + inputField.AbsoluteSize.X / self.Window.Scale.Scale + suffixLabel.TextBounds.X + 9
            suffixLabel.Position = UDim2.fromOffset(9 + inputField.AbsoluteSize.X / self.Window.Scale.Scale, 0)
        else
            width = valueLabel.TextBounds.X + 18
        end
        width = math.max(width, 36)
        if instant then
            valueBox.Size = UDim2.fromOffset(width, 24)
        else
            tween(valueBox, {Size = UDim2.fromOffset(width, 24)}, 0.2)
        end
    end

    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        if not editing then resize(false) end
    end)
    inputField:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if editing then resize(false) end
    end)

    local trackBg = create("Frame", {
        Position = UDim2.new(0,14,0,rowHeight - 18),
        Size = UDim2.new(1,-28,0,5),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = row
    })
    corner(trackBg, UDim.new(1,0))

    local trackFill = create("Frame", {
        Size = UDim2.new(0,0,1,0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = trackBg
    })
    corner(trackFill, UDim.new(1,0))

    local glowDot = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0,0,0.5,0),
        Size = UDim2.fromOffset(28,28),
        BackgroundTransparency = 1,
        Image = Assets.Glow,
        ImageColor3 = Theme.Accent,
        ImageTransparency = 0.85,
        ZIndex = 2,
        Parent = trackBg
    })

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0,0,0.5,0),
        Size = UDim2.fromOffset(12,12),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = trackBg
    })
    corner(knob, UDim.new(1,0))

    local hit = create("TextButton", {
        Position = UDim2.new(0,8,0,rowHeight - (isTouch and 37 or 31)),
        Size = UDim2.new(1,-16,0,isTouch and 40 or 28),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
        Parent = row
    })

    local state = {Value = math.clamp(config.Default or minV, minV, maxV)}
    local dragging = false

    clickRegion.MouseEnter:Connect(function() tween(valueStroke, {Color = Theme.StrokeHover}, 0.12) end)
    clickRegion.MouseLeave:Connect(function()
        if not inputField:IsFocused() then tween(valueStroke, {Color = Theme.Stroke}, 0.2) end
    end)

    clickRegion.MouseButton1Click:Connect(function()
        editing = true
        inputField.Text = fmt.format(state.Value)
        valueLabel.Visible = false
        inputField.Visible = true
        suffixLabel.Visible = suffix ~= ""
        clickRegion.Visible = false
        tween(valueStroke, {Color = Theme.StrokeHover}, 0.12)
        inputField:CaptureFocus()
        task.defer(resize, false)
    end)

    inputField.FocusLost:Connect(function()
        local n = tonumber(inputField.Text)
        editing = false
        inputField.Visible = false
        suffixLabel.Visible = false
        valueLabel.Visible = true
        clickRegion.Visible = true
        tween(valueStroke, {Color = Theme.Stroke}, 0.2)
        if n then state:Set(n) end
        resize(false)
    end)

    hit.MouseEnter:Connect(function()
        if not dragging then
            tween(glowDot, {ImageTransparency = 0.78, Size = UDim2.fromOffset(34,34)}, 0.15)
        end
    end)
    hit.MouseLeave:Connect(function()
        if not dragging then
            tween(glowDot, {ImageTransparency = 0.85, Size = UDim2.fromOffset(28,28)}, 0.2)
        end
    end)

    local function ratio()
        if maxV - minV == 0 then return 0 end
        return (state.Value - minV) / (maxV - minV)
    end

    local function visualize(pos, duration, easing)
        easing = easing or Enum.EasingStyle.Linear
        tween(trackFill, {Size = UDim2.new(pos,0,1,0)}, duration, easing)
        tween(knob, {Position = UDim2.new(pos,0,0.5,0)}, duration, easing)
        tween(glowDot, {Position = UDim2.new(pos,0,0.5,0)}, duration, easing)
    end

    local function refreshText()
        visualize(ratio())
        valueLabel.Text = fmt.format(state.Value) .. suffix
    end

    local function bump(prev)
        local current = ratio()
        local width = math.max(trackBg.AbsoluteSize.X, 1)
        local delta = (current >= prev and 1 or -1) * (5 / width)
        visualize(math.clamp(current + delta, 0, 1), 0.22, Enum.EasingStyle.Quint)
        task.delay(0.22, function()
            if not dragging then visualize(ratio(), 0.18, Enum.EasingStyle.Quint) end
        end)
        valueLabel.Text = fmt.format(state.Value) .. suffix
    end

    local function bounce()
        tween(knob, {Size = UDim2.fromOffset(14,12)}, 0.08)
        tween(glowDot, {Size = UDim2.fromOffset(32,32), ImageTransparency = 0.78}, 0.12)
        task.delay(0.1, function()
            tween(knob, {Size = UDim2.fromOffset(12,12)}, 0.25, Enum.EasingStyle.Quint)
            tween(glowDot, {Size = UDim2.fromOffset(28,28), ImageTransparency = 0.85}, 0.25)
        end)
    end

    function state:Set(value, silent)
        value = fmt.snap(tonumber(value) or minV)
        if value == state.Value then return end
        local prev = ratio()
        state.Value = value
        if dragging then
            refreshText()
        else
            bump(prev)
            bounce()
            flash(s)
        end
        if not silent then safeCall(config.Callback, value) end
    end
    function state:Get() return state.Value end

    local function updateFromX(x)
        local width = trackBg.AbsoluteSize.X
        if width <= 0 then return end
        local pct = math.clamp((x - trackBg.AbsolutePosition.X) / width, 0, 1)
        state:Set(minV + (maxV - minV) * pct)
    end

    hit.InputBegan:Connect(function(input)
        if isClick(input) then
            dragging = true
            tween(knob, {Size = UDim2.fromOffset(16,16)}, 0.15, Enum.EasingStyle.Back)
            tween(glowDot, {Size = UDim2.fromOffset(44,44), ImageTransparency = 0.7}, 0.15)
            updateFromX(mousePos().X)
        end
    end)

    self.Window:_listen("Changed", function(input)
        if dragging and isMove(input) then updateFromX(mousePos().X) end
    end, state)

    self.Window:_listen("Ended", function(input)
        if dragging and isClick(input) then
            dragging = false
            tween(knob, {Size = UDim2.fromOffset(12,12)}, 0.2)
            tween(glowDot, {Size = UDim2.fromOffset(28,28), ImageTransparency = 0.85}, 0.2)
            safeCall(config.OnRelease, state.Value)
        end
    end, state)

    state.Value = fmt.snap(state.Value)
    refreshText()
    task.defer(resize, true)

    return register(self, config, state, row, "Slider")
end

function Tab:Dropdown(config)
    config = normalize(config, {
        Title = "Name", Description = "Desc",
        CurrentOption = "Default", Value = "Default",
        MultipleOptions = "Multi", Values = "Options"
    })
    if config.Multi and type(config.Default) ~= "table" and config.Default ~= nil then
        config.Default = {config.Default}
    elseif not config.Multi and type(config.Default) == "table" then
        config.Default = config.Default[1]
    end
    local multi = config.Multi == true
    local options = config.Options or {}

    local row, s, height
    row, s, height = buildElement(self, config, {}, "Frame", nil, nil)
    row.ClipsDescendants = true

    local header = create("TextButton", {
        Size = UDim2.new(1,0,0,height),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = row
    })

    local titleLabel, descLabel = buildTitleDesc(header, config.Name or "Dropdown", config.Desc, 180)

    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,-10,0.5,0),
        Size = UDim2.fromOffset(60, CHIP_H),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = header
    })
    corner(pill, UDim.new(0,6))
    local pillStroke = stroke(pill)

    local pillLabel = textLabel {
        Position = UDim2.fromOffset(10,0),
        Size = UDim2.new(1,-34,1,0),
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent = pill
    }
    local chev = makeChevron(pill, 1, -6)

    local measure = textLabel {
        Size = UDim2.fromOffset(0, CHIP_H),
        AutomaticSize = Enum.AutomaticSize.X,
        TextSize = 13,
        Visible = false,
        Parent = pill
    }
    local displayText = ""

    local function truncate(text)
        measure.Text = text
        if measure.TextBounds.X <= 146 then return text end
        local len = utf8.len(text)
        local function slice(n)
            if not len then return text:sub(1, n) end
            return text:sub(1, (utf8.offset(text, n + 1) or #text + 1) - 1)
        end
        local lo, hi = 0, (len or #text) - 1
        while lo < hi do
            local mid = math.ceil((lo + hi) / 2)
            measure.Text = slice(mid) .. ".."
            if measure.TextBounds.X <= 146 then lo = mid else hi = mid - 1 end
        end
        return slice(lo) .. ".."
    end

    local function fitPill(instant)
        local w = math.clamp(pillLabel.TextBounds.X + 10 + 34, 60, 190)
        shrinkLabels(titleLabel, descLabel, w + 20)
        if instant then
            pill.Size = UDim2.fromOffset(w, CHIP_H)
        else
            tween(pill, {Size = UDim2.fromOffset(w, CHIP_H)}, 0.2)
        end
    end

    pillLabel:GetPropertyChangedSignal("TextBounds"):Connect(function() fitPill(false) end)

    local itemsHolder = create("Frame", {
        Position = UDim2.new(0,10,0,height),
        Size = UDim2.new(1,-20,0,0),
        BackgroundTransparency = 1,
        Parent = row
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0,4),
        Parent = itemsHolder
    })

    local api = {Open = false}
    local itemFrames = {}
    local state = {}
    local query = ""
    local searchAfter = config.SearchAfter or 6
    local placeholder = config.Placeholder or "None"

    local searchBox = create("Frame", {
        Size = UDim2.new(1,0,0, ITEM_H),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 0,
        Visible = false,
        Parent = itemsHolder
    })
    corner(searchBox, UDim.new(0,6))
    local searchStroke = stroke(searchBox, Theme.Stroke, 1)

    local searchInput = create("TextBox", {
        Position = UDim2.fromOffset(12,0),
        Size = UDim2.new(1,-20,1,0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextTransparency = 1,
        Parent = searchBox
    })

    local function matches(value)
        return query == "" or string.find(string.lower(tostring(value)), query, 1, true) ~= nil
    end

    if multi then
        for _, v in ipairs(config.Default or {}) do state[v] = true end
    elseif config.Default ~= nil then
        state[config.Default] = true
    end

    local function getSelection()
        if multi then
            local list = {}
            for _, v in ipairs(options) do
                if state[v] then table.insert(list, v) end
            end
            return list
        end
        for _, v in ipairs(options) do
            if state[v] then return v end
        end
        return nil
    end

    local function refreshLabel()
        local sel = getSelection()
        if multi then
            local strings = {}
            for i, v in ipairs(sel) do strings[i] = tostring(v) end
            displayText = #strings > 0 and table.concat(strings, ", ") or placeholder
        else
            displayText = sel ~= nil and tostring(sel) or placeholder
        end
        pillLabel.Text = truncate(displayText)
        for option, entry in pairs(itemFrames) do
            local on = state[option] == true
            if entry.On ~= on then
                entry.On = on
                tween(entry.Label, {TextColor3 = on and Theme.Text or Theme.Muted}, 0.15)
                if api.Open then
                    tween(entry.Check, {ImageTransparency = on and 0 or 1}, 0.15)
                    tween(entry.CheckScale, {Scale = on and 1 or 0.6},
                        on and 0.3 or 0.15,
                        on and Enum.EasingStyle.Back or Enum.EasingStyle.Quint)
                end
            end
        end
    end

    local function countVisible()
        local n = 0
        for _, v in ipairs(options) do
            if matches(v) then n += 1 end
        end
        return n
    end

    local function applyFilter()
        for option, entry in pairs(itemFrames) do
            entry.Frame.Visible = matches(option)
        end
    end

    local function targetHeight()
        local visible = countVisible() + (searchBox.Visible and 1 or 0)
        return height + visible * (ITEM_H + 4) + 8
    end

    local function setOpen(open)
        api.Open = open
        searchBox.Visible = #options > searchAfter
        if not open then
            query = ""
            searchInput.Text = ""
            applyFilter()
        end
        tween(row, {Size = UDim2.new(1,0,0, open and targetHeight() or height)}, 0.3, Enum.EasingStyle.Quint)
        tween(searchBox, {BackgroundTransparency = open and 0 or 1}, 0.2)
        tween(searchStroke, {Transparency = open and 0 or 1}, 0.2)
        tween(searchInput, {TextTransparency = open and 0 or 1}, 0.2)
        chev:Set(open)
        tween(pillStroke, {Color = open and Theme.StrokeHover or Theme.Stroke}, 0.2)

        local function animateEntry(entry, open2)
            if not entry.Stroke then entry.Stroke = stroke(entry.Frame, Theme.Stroke, 1) end
            local on = open2 and entry.On
            tween(entry.Check, {ImageTransparency = on and 0 or 1}, 0.18)
            entry.CheckScale.Scale = on and 1 or 0.6
            tween(entry.Label, {TextTransparency = open2 and 0 or 1}, 0.18)
            tween(entry.Stroke, {Transparency = open2 and 0 or 1}, 0.18)
            tween(entry.Frame, {BackgroundTransparency = open2 and 0 or 1}, 0.18)
        end

        if open then
            local gen = (api._gen or 0) + 1
            api._gen = gen
            task.spawn(function()
                local first = true
                for _, v in ipairs(options) do
                    local entry = itemFrames[v]
                    if entry and entry.Frame.Visible then
                        if not first then
                            task.wait(0.025)
                            if api._gen ~= gen or not api.Open then return end
                        end
                        first = false
                        animateEntry(entry, true)
                    end
                end
            end)
        else
            local gen = (api._gen or 0) + 1
            api._gen = gen
            local list = {}
            for _, v in ipairs(options) do
                local entry = itemFrames[v]
                if entry and entry.Frame.Visible then table.insert(list, entry) end
            end
            task.spawn(function()
                for i = #list, 1, -1 do
                    animateEntry(list[i], false)
                    if i > 1 then
                        task.wait(0.015)
                        if api._gen ~= gen or api.Open then return end
                    end
                end
            end)
        end
    end

    local function rebuild()
        local indexed = {}
        for i, v in ipairs(options) do indexed[v] = i end
        for option, entry in pairs(itemFrames) do
            if not indexed[option] then
                entry.Frame:Destroy()
                itemFrames[option] = nil
            end
        end
        for order, value in ipairs(options) do
            local existing = itemFrames[value]
            if existing then
                existing.Frame.LayoutOrder = order
                continue
            end
            local btn = create("TextButton", {
                Size = UDim2.new(1,0,0,ITEM_H),
                BackgroundColor3 = Theme.Surface,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = order,
                Parent = itemsHolder
            })
            corner(btn, UDim.new(0,6))
            local check = create("ImageLabel", {
                AnchorPoint = Vector2.new(1,0.5),
                Position = UDim2.new(1,-10,0.5,0),
                Size = UDim2.fromOffset(14,14),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.Accent,
                ImageTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
                Parent = btn
            })
            applyIcon(check, "check")
            local checkScale = create("UIScale", {Scale = 0.6, Parent = check})
            local label = textLabel {
                Position = UDim2.fromOffset(12,-1),
                Size = UDim2.new(1,-36,1,0),
                Text = tostring(value),
                TextSize = 13,
                TextColor3 = Theme.Muted,
                TextTransparency = 1,
                Parent = btn
            }
            btn.MouseEnter:Connect(function()
                tween(label, {TextColor3 = Theme.Text}, 0.15)
                local entry = itemFrames[value]
                if entry and entry.Stroke then
                    tween(entry.Stroke, {Color = Theme.StrokeHover}, 0.12)
                end
            end)
            btn.MouseLeave:Connect(function()
                tween(label, {TextColor3 = state[value] and Theme.Text or Theme.Muted}, 0.2)
                local entry = itemFrames[value]
                if entry and entry.Stroke then
                    tween(entry.Stroke, {Color = Theme.Stroke}, 0.2)
                end
            end)
            btn.MouseButton1Click:Connect(function()
                if state[value] then
                    state[value] = nil
                else
                    if not multi then state = {} end
                    state[value] = true
                end
                refreshLabel()
                safeCall(config.Callback, getSelection())
                if not multi and state[value] then setOpen(false) end
            end)
            itemFrames[value] = {
                Frame = btn, Label = label, Check = check,
                CheckScale = checkScale, Stroke = nil, On = nil
            }
        end
        applyFilter()
        if api.Open then
            row.Size = UDim2.new(1,0,0,targetHeight())
        end
    end

    function state:Set(value, silent)
        state = {}
        if multi then
            local list = type(value) == "table" and value or {value}
            for _, v in ipairs(list) do state[v] = true end
        elseif value ~= nil then
            state[value] = true
        end
        refreshLabel()
        flash(pillStroke)
        if not silent then safeCall(config.Callback, getSelection()) end
    end
    function state:Get() return getSelection() end
    function state:Refresh(newOptions, keep)
        options = newOptions or {}
        if not keep then state = {} end
        rebuild()
        refreshLabel()
        if api.Open then setOpen(true) end
    end
    function state:SetOpen(value) setOpen(value == true) end

    header.MouseButton1Click:Connect(function() setOpen(not api.Open) end)

    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        query = string.lower(searchInput.Text)
        applyFilter()
        if api.Open then
            tween(row, {Size = UDim2.new(1,0,0,targetHeight())}, 0.2, Enum.EasingStyle.Quint)
        end
    end)

    rebuild()
    refreshLabel()
    task.defer(fitPill, true)

    return register(self, config, state, row, "Dropdown")
end

function Tab:Input(config)
    local row, s, height, title
    row, s, height, title = buildElement(self, config, {
        Title = "Name", Description = "Desc",
        PlaceholderText = "Placeholder",
        CurrentValue = "Default", Value = "Default"
    }, "Frame", 160, "Input")

    local fieldBox = create("Frame", {
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,-10,0.5,0),
        Size = UDim2.fromOffset(170,30),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = row
    })
    corner(fieldBox, UDim.new(0,6))
    local fieldStroke = stroke(fieldBox)

    local iconOffset = 8
    if config.Icon then
        iconFrame(fieldBox, config.Icon, Theme.Muted, UDim2.new(0,8,0.5,0))
        iconOffset = 30
    end

    local maxLen = tonumber(config.MaxLength)
    local function clampLen(text)
        text = tostring(text or "")
        if maxLen and #text > maxLen then return text:sub(1, maxLen) end
        return text
    end

    local inputField = create("TextBox", {
        Position = UDim2.fromOffset(iconOffset, 0),
        Size = UDim2.new(1, iconOffset == 30 and -38 or -16, 1, 0),
        BackgroundTransparency = 1,
        Text = clampLen(config.Default),
        PlaceholderText = config.Placeholder or "",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 14,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = config.ClearOnFocus == true,
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent = fieldBox
    })
    fieldBox.ClipsDescendants = true

    local focused = false
    local padLeft = (config.Icon and 30 or 8) + 8

    local function resize(instant)
        local avail = row.AbsoluteSize.X / self.Window.Scale.Scale
        local maxBox = math.clamp(avail - 14 - 110 - 20, 100, 200)
        local textLen = inputField.Text
        local textWidth = inputField.TextBounds.X
        if #textLen == 0 then textWidth = math.min(inputField.TextBounds.X, 90) end
        local target = math.clamp(textWidth + padLeft + 12, 90, maxBox) + (focused and 8 or 0)
        target = math.min(target, maxBox + 8)
        shrinkLabels(title, nil, target + 20)
        if instant then
            fieldBox.Size = UDim2.fromOffset(target, 30)
        else
            tween(fieldBox, {Size = UDim2.fromOffset(target, 30)}, 0.18)
        end
    end

    row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() resize(true) end)

    inputField:GetPropertyChangedSignal("Text"):Connect(function()
        local clamped = clampLen(inputField.Text)
        if clamped ~= inputField.Text then
            inputField.Text = clamped
            return
        end
        resize(false)
        if inputField:IsFocused() then
            safeCall(config.OnChanged, inputField.Text)
        end
    end)
    inputField:GetPropertyChangedSignal("TextBounds"):Connect(function() resize(false) end)
    task.defer(resize, true)

    inputField.Focused:Connect(function()
        focused = true
        tween(fieldStroke, {Color = Theme.StrokeHover}, 0.15)
        resize(false)
    end)
    inputField.FocusLost:Connect(function(enterPressed)
        focused = false
        tween(fieldStroke, {Color = Theme.Stroke}, 0.15)
        resize(false)
        if config.Numeric and not tonumber(inputField.Text) then
            inputField.Text = ""
            return
        end
        safeCall(config.Callback, inputField.Text, enterPressed)
    end)

    local state = {}
    function state:Set(value, silent)
        inputField.Text = clampLen(value)
        flash(fieldStroke)
        if not silent then safeCall(config.Callback, inputField.Text, false) end
    end
    function state:Get() return inputField.Text end
    function state:SetPlaceholder(text) inputField.PlaceholderText = tostring(text) end

    return register(self, config, state, row, "Input")
end

function Tab:Keybind(config)
    local row, s, height, title
    row, s, height, title = buildElement(self, config, {
        Title = "Name", Description = "Desc",
        CurrentKeybind = "Default", Value = "Default"
    }, "Frame", 110, "Keybind")

    config.Default = nameToKey(config.Default)
    local isHold = config.Mode == "Hold"

    local keyButton = create("TextButton", {
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,-10,0.5,0),
        Size = UDim2.fromOffset(44, CHIP_H),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = row
    })
    corner(keyButton, UDim.new(0,6))
    local keyStroke = stroke(keyButton)

    local keyLabel = textLabel {
        Size = UDim2.new(1,0,1,0),
        TextSize = 13,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        Parent = keyButton
    }

    local state = {Value = config.Default, Listening = false, Held = false}

    local function fit(instant)
        local w = math.max(keyLabel.TextBounds.X + 20, isTouch and 44 or 36)
        shrinkLabels(nil, nil, w + 20)
        if instant then
            keyButton.Size = UDim2.fromOffset(w, CHIP_H)
        else
            tween(keyButton, {Size = UDim2.fromOffset(w, CHIP_H)}, 0.2)
        end
    end

    keyLabel:GetPropertyChangedSignal("TextBounds"):Connect(function() fit(false) end)

    local function render()
        keyLabel.Text = state.Listening and "..." or keyToName(state.Value)
        tween(keyStroke, {Color = state.Listening and Theme.StrokeHover or Theme.Stroke}, 0.15)
        tween(keyLabel, {TextColor3 = state.Listening and Theme.Accent or Theme.Muted}, 0.15)
    end

    local function releaseHold()
        if state.Held then
            state.Held = false
            safeCall(config.Callback, false)
        end
    end

    function state:Set(value, silent)
        local wasListening = state.Listening
        releaseHold()
        value = nameToKey(value)
        state.Value = value
        state.Listening = false
        render()
        if not wasListening then flash(keyStroke) end
        if not silent then safeCall(config.OnChanged, value) end
    end

    keyButton.MouseButton1Click:Connect(function()
        state.Listening = not state.Listening
        render()
    end)

    self.Window:_listen("Began", function(input, processed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if state.Listening and UserInputService:GetFocusedTextBox() then
            state.Listening = false
            render()
            return
        end
        if state.Listening then
            self.Window._consumedKey = input.KeyCode
            self.Window._consumedAt = os.clock()
            if input.KeyCode == Enum.KeyCode.Escape then
                state.Listening = false
                render()
            elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                state:Set(nil)
            else
                state:Set(input.KeyCode)
            end
            return
        end
        if processed or state.Locked or state.Value == nil or input.KeyCode ~= state.Value then return end
        if isHold then
            state.Held = true
            safeCall(config.Callback, true)
        else
            safeCall(config.Callback, input.KeyCode)
        end
    end, state)

    if isHold then
        self.Window:_listen("Ended", function(input)
            if input.KeyCode == state.Value then releaseHold() end
        end, state)
    end

    render()
    task.defer(fit, true)
    function state:Get() return state.Value end

    return register(self, config, state, row, "Keybind", "OnChanged")
end

function Tab:ColorPicker(config)
    local row, s, height, title
    row, s, height, title = buildElement(self, config, {
        Title = "Name", Description = "Desc",
        Color = "Default", CurrentValue = "Default", Value = "Default"
    }, "Frame", nil, nil)
    row.ClipsDescendants = true

    local header = create("TextButton", {
        Size = UDim2.new(1,0,0,height),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = row
    })
    buildTitleDesc(header, config.Name or "Color", config.Desc, 90)

    local preview = create("Frame", {
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,-34,0.5,0),
        Size = UDim2.fromOffset(36,20),
        BorderSizePixel = 0,
        Parent = header
    })
    preview:SetAttribute("AirflowNoTheme", true)
    corner(preview, UDim.new(0,6))
    stroke(preview, Theme.Stroke)

    local chev = makeChevron(header, 1, -12)

    local picker = create("Frame", {
        Position = UDim2.fromOffset(14, height + 2),
        Size = UDim2.new(1,-28,0,156),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = row
    })

    local svSquare = create("TextButton", {
        Size = UDim2.new(1,-30,0,110),
        BackgroundColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = picker
    })
    corner(svSquare, UDim.new(0,6))
    local hueGrad = create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,0,0)),
        Parent = svSquare
    })
    local satOverlay = create("Frame", {
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = Color3.new(0,0,0),
        BorderSizePixel = 0,
        Parent = svSquare
    })
    create("UIGradient", {
        Transparency = NumberSequence.new {
            NumberSequenceKeypoint.new(0,1),
            NumberSequenceKeypoint.new(1,0)
        },
        Rotation = 90,
        Parent = satOverlay
    })

    local svDot = create("Frame", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Size = UDim2.fromOffset(10,10),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = svSquare
    })
    corner(svDot, UDim.new(1,0))
    stroke(svDot, Color3.new(1,1,1), 0, 2)

    local hueStrip = create("TextButton", {
        AnchorPoint = Vector2.new(1,0),
        Position = UDim2.new(1,0,0,0),
        Size = UDim2.fromOffset(14,110),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = picker
    })
    corner(hueStrip, UDim.new(0,6))
    create("UIGradient", {
        Color = ColorSequence.new {
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
            ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255,255,0)),
            ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0,255,0)),
            ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0,255,255)),
            ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0,0,255)),
            ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255,0,255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))
        },
        Rotation = 90,
        Parent = hueStrip
    })

    local hueKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5,0,0,0),
        Size = UDim2.fromOffset(18,5),
        BackgroundColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = hueStrip
    })
    corner(hueKnob, UDim.new(1,0))
    stroke(hueKnob, Theme.AccentDark, 0.4)

    local hexBox = create("Frame", {
        Position = UDim2.fromOffset(6,122),
        Size = UDim2.fromOffset(118,28),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = picker
    })
    corner(hexBox, UDim.new(0,6))
    local hexStroke = stroke(hexBox)

    local hexInput = create("TextBox", {
        Position = UDim2.fromOffset(14,0),
        Size = UDim2.new(1,-24,1,0),
        BackgroundTransparency = 1,
        Text = "",
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = false,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = hexBox
    })

    local rgbLabel = textLabel {
        Position = UDim2.fromOffset(134,122),
        Size = UDim2.new(1,-134,0,28),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = picker
    }

    local api = {Open = false}
    local initial = config.Default
    if type(initial) == "string" then
        local ok, c = pcall(Color3.fromHex, initial)
        initial = ok and c or nil
    end
    if typeof(initial) ~= "Color3" then initial = Theme.Accent end

    local h, sat, v = Color3.toHSV(initial)
    local dragMode

    local function toHex(color)
        return string.format("#%02X%02X%02X",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function apply(duration)
        local color = Color3.fromHSV(h, sat, v)
        api.Value = color
        preview.BackgroundColor3 = color
        hueGrad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(h, 1, 1))
        tween(svDot, {Position = UDim2.fromScale(sat, 1 - v)}, duration, Enum.EasingStyle.Linear)
        tween(hueKnob, {Position = UDim2.new(0.5, 0, h, 0)}, duration, Enum.EasingStyle.Linear)
        if not hexInput:IsFocused() then hexInput.Text = toHex(color) end
        rgbLabel.Text = string.format("RGB %d, %d, %d",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5))
    end

    local function commit(duration, silent)
        apply(duration)
        if not silent then safeCall(config.Callback, api.Value) end
    end

    function api:Set(color, silent)
        if type(color) == "string" then
            local ok, parsed = pcall(Color3.fromHex, color)
            color = ok and parsed or nil
        end
        if typeof(color) ~= "Color3" then
            warn("[AirFlow] ColorPicker:Set expects a Color3 or hex string")
            return
        end
        h, sat, v = Color3.toHSV(color)
        commit(0.25, silent)
        flash(s)
    end
    function api:Get() return api.Value end

    local function setOpen(open)
        api.Open = open
        tween(row, {Size = UDim2.new(1,0,0, open and height + 168 or height)}, 0.35, Enum.EasingStyle.Quint)
        chev:Set(open)
        if open then
            picker.Visible = true
        else
            task.delay(0.35, function()
                if not api.Open then picker.Visible = false end
            end)
        end
    end

    function api:SetOpen(open) setOpen(open == true) end

    header.MouseButton1Click:Connect(function() setOpen(not api.Open) end)

    local function updateSV(pos)
        sat = math.clamp((pos.X - svSquare.AbsolutePosition.X) / svSquare.AbsoluteSize.X, 0, 1)
        v = 1 - math.clamp((pos.Y - svSquare.AbsolutePosition.Y) / svSquare.AbsoluteSize.Y, 0, 1)
        commit(0.04)
    end

    local function updateHue(pos)
        h = math.clamp((pos.Y - hueStrip.AbsolutePosition.Y) / hueStrip.AbsoluteSize.Y, 0, 0.999)
        commit(0.04)
    end

    svSquare.InputBegan:Connect(function(input)
        if isClick(input) then
            dragMode = "sv"
            tween(svDot, {Size = UDim2.fromOffset(14,14)}, 0.15, Enum.EasingStyle.Back)
            updateSV(mousePos())
        end
    end)
    hueStrip.InputBegan:Connect(function(input)
        if isClick(input) then
            dragMode = "hue"
            tween(hueKnob, {Size = UDim2.fromOffset(20,7)}, 0.15, Enum.EasingStyle.Back)
            updateHue(mousePos())
        end
    end)

    self.Window:_listen("Changed", function(input)
        if not dragMode or not isMove(input) then return end
        local pos = mousePos()
        if dragMode == "sv" then updateSV(pos) else updateHue(pos) end
    end, api)

    self.Window:_listen("Ended", function(input)
        if dragMode and isClick(input) then
            dragMode = nil
            tween(svDot, {Size = UDim2.fromOffset(10,10)}, 0.2)
            tween(hueKnob, {Size = UDim2.fromOffset(18,5)}, 0.2)
        end
    end, api)

    hexInput.Focused:Connect(function() tween(hexStroke, {Color = Theme.StrokeHover}, 0.15) end)
    hexInput.FocusLost:Connect(function()
        tween(hexStroke, {Color = Theme.Stroke}, 0.15)
        local r, g, b = hexInput.Text:match("^%s*#?(%x%x)(%x%x)(%x%x)%s*$")
        if r then
            api:Set(Color3.fromRGB(tonumber(r,16), tonumber(g,16), tonumber(b,16)))
        else
            hexInput.Text = toHex(api.Value)
        end
    end)

    apply(0)
    return register(self, config, api, row, "ColorPicker")
end

function Tab:Stepper(config)
    local row, s, height, title
    row, s, height, title = buildElement(self, config, {
        Title = "Name", Description = "Desc",
        CurrentValue = "Default", Value = "Default", Increment = "Step"
    }, "Frame", 150, "Stepper")

    local minV = math.min(config.Min or 0, config.Max or 100)
    local maxV = math.max(config.Min or 0, config.Max or 100)
    local step = config.Step or 1
    local suffix = config.Suffix or ""
    local fmt = makeStep(minV, maxV, step)

    local strip = create("Frame", {
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,-10,0.5,0),
        Size = UDim2.fromOffset(0, CHIP_H),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = row
    })
    corner(strip, UDim.new(0,6))
    local stripStroke = stroke(strip)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = strip
    })

    local function stepBtn(text, order)
        local btn = create("TextButton", {
            Size = UDim2.fromOffset(CHIP_H, CHIP_H),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Theme.Muted,
            TextSize = 18,
            FontFace = Fonts.Medium,
            AutoButtonColor = false,
            LayoutOrder = order,
            Parent = strip
        })
        btn.MouseEnter:Connect(function() tween(btn, {TextColor3 = Theme.Accent}, 0.12) end)
        btn.MouseLeave:Connect(function() tween(btn, {TextColor3 = Theme.Muted}, 0.2) end)
        return btn
    end

    local dec = stepBtn("−", 1)
    local valueLabel = textLabel {
        Size = UDim2.new(0,30,1,0),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 2,
        Parent = strip
    }
    local inc = stepBtn("+", 3)

    local function fitStrip(instant)
        local w = math.max(valueLabel.TextBounds.X + 12, 30)
        if instant then
            valueLabel.Size = UDim2.new(0,w,1,0)
        else
            tween(valueLabel, {Size = UDim2.new(0,w,1,0)}, 0.2)
        end
    end

    valueLabel:GetPropertyChangedSignal("TextBounds"):Connect(function() fitStrip(false) end)
    strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        shrinkLabels(title, nil, strip.AbsoluteSize.X / self.Window.Scale.Scale + 20)
    end)

    local state = {Value = math.clamp(config.Default or minV, minV, maxV)}
    local isEditing = false
    local snap = fmt.snap

    local function render()
        valueLabel.Text = fmt.format(state.Value) .. suffix
        tween(dec, {TextTransparency = state.Value <= minV and 0.6 or 0}, 0.15)
        tween(inc, {TextTransparency = state.Value >= maxV and 0.6 or 0}, 0.15)
    end

    function state:Set(value, silent)
        value = snap(tonumber(value) or minV)
        if value == state.Value then return end
        state.Value = value
        render()
        if not isEditing then flash(stripStroke) end
        if not silent then safeCall(config.Callback, value) end
    end
    function state:Get() return state.Value end

    local function stepVal(dir)
        isEditing = true
        state:Set(state.Value + dir * step)
        isEditing = false
        tween(stripStroke, {Color = Theme.StrokeHover}, 0.08)
        task.delay(0.12, function()
            tween(stripStroke, {Color = Theme.Stroke}, 0.2)
        end)
    end

    local HOLD_DELAY, HOLD_REPEAT = 0.4, 0.07

    local function bindStep(button, dir)
        local presses, held = 0, false
        button.InputBegan:Connect(function(input)
            if not isClick(input) then return end
            presses += 1
            local mine = presses
            held = true
            stepVal(dir)
            task.delay(HOLD_DELAY, function()
                while held and presses == mine and not state.Locked and not state._destroyed and button.Parent do
                    stepVal(dir)
                    task.wait(HOLD_REPEAT)
                end
            end)
        end)
        button.InputEnded:Connect(function(input)
            if isClick(input) then held = false end
        end)
        button.MouseLeave:Connect(function() held = false end)
    end

    bindStep(dec, -1)
    bindStep(inc, 1)
    render()
    task.defer(fitStrip, true)

    return register(self, config, state, row, "Stepper")
end

function Tab:Progress(config)
    config = normalize(config, {
        Title = "Name", Description = "Desc",
        CurrentValue = "Default", Value = "Default"
    })
    local row, s = buildRow(self, "Frame", config.Desc and ROW_DESC + 10 or ROW + 10, config)
    attachHover(row, s)
    local yPos = config.Desc and (ROW_DESC - 38) / 2 - 2 or 12

    textLabel {
        Name = "Title",
        Position = UDim2.fromOffset(14, yPos),
        Size = UDim2.new(1,-110,0,18),
        Text = config.Name or "Progress",
        Parent = row
    }
    if config.Desc then
        textLabel {
            Name = "Desc",
            Position = UDim2.fromOffset(14, yPos + 20),
            Size = UDim2.new(1,-110,0,17),
            Text = config.Desc,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = row
        }
    end

    local percentLabel = textLabel {
        AnchorPoint = Vector2.new(1,0),
        Position = UDim2.new(1,-14,0,yPos),
        Size = UDim2.fromOffset(90,18),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = 13,
        TextColor3 = Theme.Accent,
        Parent = row
    }

    local barBg = create("Frame", {
        Position = UDim2.new(0,14,1,-16),
        Size = UDim2.new(1,-28,0,5),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = row
    })
    corner(barBg, UDim.new(1,0))

    local barFill = create("Frame", {
        Size = UDim2.new(0,0,1,0),
        BackgroundColor3 = config.Color or Theme.Accent,
        BorderSizePixel = 0,
        Parent = barBg
    })
    corner(barFill, UDim.new(1,0))

    local state = {Value = math.clamp(config.Default or 0, 0, 1)}
    local fmt = config.Format

    local function render(duration)
        local value = state.Value
        tween(barFill, {Size = UDim2.new(value,0,1,0)}, duration, Enum.EasingStyle.Quint)
        if type(fmt) == "function" then
            percentLabel.Text = tostring(fmt(value))
        else
            percentLabel.Text = string.format("%d%%", math.floor(value * 100 + 0.5))
        end
    end

    function state:Set(value, silent)
        value = math.clamp(tonumber(value) or 0, 0, 1)
        if value == state.Value then return end
        state.Value = value
        render(0.35)
        if not silent then safeCall(config.Callback, value) end
    end
    function state:Get() return state.Value end
    function state:SetColor(color) barFill.BackgroundColor3 = color end

    render(0)
    return register(self, config, state, row, "Progress")
end

function Tab:ConfigManager(config)
    config = normalize(config, {})
    local window = self.Window
    local api = {}

    self:Section(config.Name or "Configs")

    local nameInput = self:Input {
        Name = "Config name",
        Placeholder = window.ConfigName,
        Callback = function(value, enter)
            if enter and #value > 0 then api:Save(value) end
        end
    }

    local saved = self:Dropdown {
        Name = "Saved configs",
        Options = window:ListConfigs(),
        Default = window.ConfigName,
        Callback = function(value)
            if value then nameInput:Set(value, true) end
        end
    }

    function api:Refresh()
        saved:Refresh(window:ListConfigs(), true)
    end

    function api:Save(name)
        name = name or saved:Get() or window.ConfigName
        local ok, err = window:SaveConfig(name)
        api:Refresh()
        if ok then saved:Set(window.ConfigName, true) end
        window:Notify {
            Title = ok and "Config saved" or "Save failed",
            Content = ok and window.ConfigName or tostring(err),
            Type = ok and "Success" or "Error",
            Duration = 3
        }
    end

    function api:Load(name)
        name = name or saved:Get()
        if not name then return end
        local ok, err = window:LoadConfig(name)
        window:Notify {
            Title = ok and "Config loaded" or "Load failed",
            Content = ok and name or tostring(err),
            Type = ok and "Success" or "Error",
            Duration = 3
        }
    end

    function api:Delete(name)
        name = name or saved:Get()
        if not name then return end
        local ok, err = window:DeleteConfig(name)
        api:Refresh()
        window:Notify {
            Title = ok and "Config deleted" or "Delete failed",
            Content = ok and name or tostring(err),
            Type = ok and "Info" or "Error",
            Duration = 3
        }
    end

    self:Button {
        Name = "Save",
        Desc = "Writes every flagged element to the selected name",
        Icon = "save",
        Style = "Primary",
        Callback = function()
            local n = nameInput:Get()
            api:Save(#n > 0 and n or nil)
        end
    }

    self:Button {
        Name = "Load",
        Icon = "folder-open",
        Callback = function() api:Load() end
    }

    self:Button {
        Name = "Delete",
        Icon = "trash-2",
        Callback = function()
            local n = saved:Get()
            if not n then return end
            window:Confirm {
                Title = "Delete config",
                Content = "Remove " .. n .. "? This cannot be undone.",
                Icon = "trash-2",
                ConfirmText = "Delete",
                Callback = function() api:Delete(n) end
            }
        end
    }

    self:Toggle {
        Name = "Auto save",
        Desc = "Save whenever a flagged element changes",
        Default = window._autoSaveEnabled,
        Callback = function(v) window:SetAutoSave(v) end
    }

    return api
end

function Tab:ThemePicker(config)
    config = normalize(config, {Title = "Name", Description = "Desc"})
    local userCb = config.Callback
    return self:Dropdown {
        Name = config.Name or "Theme",
        Desc = config.Desc,
        Options = AirFlow:GetThemes(),
        Default = AirFlow.ThemeName,
        Flag = config.Flag,
        Callback = function(value)
            if value then AirFlow:SetTheme(value) end
            safeCall(userCb, value)
        end
    }
end

local noAlias = {Select = true}
function Tab:Select()
    self.Window:SelectTab(self)
end

for name, method in pairs(table.clone(Tab)) do
    if type(method) == "function"
        and name:sub(1,1) ~= "_"
        and name:sub(1,6) ~= "Create"
        and not noAlias[name]
    then
        Tab["Create" .. name] = method
    end
end

local function getExecutorName()
    local name
    pcall(function()
        if typeof(identifyexecutor) == "function" then
            name = identifyexecutor()
        elseif typeof(getexecutorname) == "function" then
            name = getexecutorname()
        end
    end)
    if type(name) == "string" and #name > 0 then return name end
    return RunService:IsStudio() and "Studio" or "Unknown"
end

local function getGameName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and type(info) == "table" and info.Name then return info.Name end
    return "Unknown game"
end

local countryNames = {
    US = "United States", GB = "United Kingdom", DE = "Germany",
    FR = "France", NL = "Netherlands", SG = "Singapore",
    JP = "Japan", AU = "Australia", BR = "Brazil",
    IN = "India", HK = "Hong Kong", CA = "Canada"
}

local function fetchRegion(callback)
    task.spawn(function()
        local requestFn = request or http_request or (syn and syn.request) or (http and http.request)
        local region
        if type(requestFn) == "function" then
            pcall(function()
                local response = requestFn {Url = "https://ipinfo.io/json", Method = "GET"}
                local body = type(response) == "table" and (response.Body or response.body) or nil
                if type(body) == "string" then
                    local data = HttpService:JSONDecode(body)
                    if type(data) == "table" and data.country then
                        local country = countryNames[data.country] or data.country
                        region = data.city and (data.city .. ", " .. country) or country
                    end
                end
            end)
        end
        callback(region or "Unavailable")
    end)
end

local NOTIFY_COLORS = {
    Info = "Accent", Success = "Success", Warning = "Warning", Error = "Error"
}

local Window = {}
Window.__index = Window

function AirFlow.Window(windowConfig)
    local defaultName = "AirflowUI"
    windowConfig = normalize(windowConfig, {
        Name = "Title",
        LoadingSubtitle = "Subtitle",
        ToggleUIKeybind = "Keybind"
    })

    if windowConfig.Theme ~= nil then
        AirFlow:SetTheme(windowConfig.Theme)
    end

    local size = windowConfig.Size or UDim2.fromOffset(640, 480)
    local keybind = nameToKey(windowConfig.Keybind) or Enum.KeyCode.RightControl

    local self = setmetatable({
        Tabs = {},
        Flags = {},
        CurrentTab = nil,
        Open = true,
        Keybind = keybind,
        _connections = {},
        _controls = {},
        _inputListeners = {Began = {}, Changed = {}, Ended = {}, Render = {}},
        _frameSteps = {},
        _destroyed = false
    }, Window)

    local function makeDispatcher(key)
        return function(...)
            for _, listener in ipairs(self._inputListeners[key]) do
                listener(...)
            end
        end
    end

    local renderDispatch = makeDispatcher("Render")

    table.insert(self._connections, RunService.RenderStepped:Connect(function(dt)
        renderDispatch(dt)
        for _, fn in ipairs(self._frameSteps) do fn(dt) end
    end))
    table.insert(self._connections, UserInputService.InputBegan:Connect(makeDispatcher("Began")))
    table.insert(self._connections, UserInputService.InputChanged:Connect(makeDispatcher("Changed")))
    table.insert(self._connections, UserInputService.InputEnded:Connect(makeDispatcher("Ended")))

    local screenGui = create("ScreenGui", {
        Name = windowConfig.Name or defaultName,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    self.Gui = screenGui

    local root = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.fromScale(0.5,0.5),
        Size = size,
        BackgroundTransparency = 1,
        Parent = screenGui
    })
    self.Root = root

    local scale = create("UIScale", {Parent = root})
    self.Scale = scale

    local shadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-25,-25),
        Size = UDim2.new(1,50,1,50),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0,0,0),
        ImageTransparency = 0.6,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49,49,450,450),
        Parent = root
    })
    self.Shadow = shadow

    local body = create("CanvasGroup", {
        Name = "Body",
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = root
    })
    self.Body = body
    corner(body, UDim.new(0,10))
    self.BodyStroke = stroke(body, Theme.Stroke)
    tintOverlay(body)
    glowLayer(body, UDim2.fromOffset(500,180), UDim2.new(0.5,0,1,8), 0.86, 270)
    glowLayer(body, UDim2.fromOffset(130,60), UDim2.new(0,-10,1,-10), 0.75, 90)
    glowLayer(body, UDim2.fromOffset(520,240), UDim2.new(1,-14,0,10), 0.92, 90)

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0,170,1,0),
        BackgroundTransparency = 1,
        Parent = body
    })

    create("Frame", {
        Position = UDim2.new(0,170,0,28),
        Size = UDim2.new(0,1,1,-56),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = body
    })

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1,0,0,72),
        BackgroundTransparency = 1,
        Parent = sidebar
    })

    local logo = create("ImageLabel", {
        Position = UDim2.fromOffset(22,27),
        Size = UDim2.fromOffset(30,28),
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        Parent = header
    })
    applyIcon(logo, windowConfig.Icon or Assets.Logo)
    self._logo = logo

    self._titleLabel = textLabel {
        Position = UDim2.fromOffset(60,25),
        Size = UDim2.new(1,-70,0,20),
        Text = windowConfig.Title or "Airflow",
        TextSize = 20,
        Parent = header
    }
    self._subtitleLabel = textLabel {
        Position = UDim2.fromOffset(60,45),
        Size = UDim2.new(1,-70,0,14),
        Text = windowConfig.Subtitle or "",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = header
    }

    local tabList = create("ScrollingFrame", {
        Name = "Tabs",
        Position = UDim2.fromOffset(0,80),
        Size = UDim2.new(1,0,1,-116),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = sidebar
    })
    self.TabList = tabList
    if isTouch then tabList:SetAttribute("NoDrag", true) end
    pad(tabList, 16, 16, 4, 4)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0,4),
        Parent = tabList
    })

    local indicator = create("Frame", {
        AnchorPoint = Vector2.new(0,0.5),
        Position = UDim2.fromOffset(6,0),
        Size = UDim2.fromOffset(3,18),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
        Parent = sidebar
    })
    corner(indicator, UDim.new(1,0))
    self.Indicator = indicator

    local lastCanvasY = tabList.CanvasPosition.Y
    table.insert(self._frameSteps, function()
        local canvasY = tabList.CanvasPosition.Y
        if canvasY == lastCanvasY or not self.CurrentTab or not self._introDone then return end
        lastCanvasY = canvasY
        local targetY = self:_indicatorY(self.CurrentTab)
        local top = tabList.Position.Y.Offset
        local bottom = top + tabList.AbsoluteSize.Y / self.Scale.Scale
        indicator.Visible = targetY > top and targetY < bottom
        indicator.Position = UDim2.fromOffset(6, targetY)
    end)

    local shortcut = create("Frame", {
        Position = UDim2.new(0,22,1,-36),
        Size = UDim2.new(1,-44,0,22),
        BackgroundTransparency = 1,
        Parent = sidebar
    })

    local chip = create("Frame", {
        Size = UDim2.fromOffset(0,22),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = shortcut
    })
    corner(chip, UDim.new(0,5))
    stroke(chip)
    pad(chip, 7, 7)

    local keyChip = textLabel {
        Size = UDim2.new(0,0,1,0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = keyToName(keybind),
        TextSize = 11,
        TextColor3 = Theme.Muted,
        TextTruncate = Enum.TextTruncate.None,
        Parent = chip
    }
    self._keyChipLabel = keyChip

    local hint = textLabel {
        Size = UDim2.new(1,0,1,0),
        Text = isTouch and "or tap the pill" or "to hide",
        TextSize = 12,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = shortcut
    }
    local function positionHint()
        hint.Position = UDim2.fromOffset(chip.AbsoluteSize.X / self.Scale.Scale + 8, 0)
    end
    chip:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionHint)
    task.defer(positionHint)

    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(171,0),
        Size = UDim2.new(1,-171,1,0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = body
    })
    self.Content = content

    self._outLayer = create("CanvasGroup", {
        Name = "TransitionOut",
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 2,
        Parent = content
    })
    self._inLayer = create("CanvasGroup", {
        Name = "TransitionIn",
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 3,
        Parent = content
    })

    local closeBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1,0),
        Position = UDim2.new(1,-14,0,14),
        Size = UDim2.fromOffset(34,34),
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 28,
        FontFace = Fonts.Bold,
        AutoButtonColor = false,
        ZIndex = 5,
        Parent = content
    })
    pad(closeBtn, 0, 0, 1, 0)
    corner(closeBtn, UDim.new(0,8))
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, {BackgroundTransparency = 0, TextColor3 = Theme.Text}, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, {BackgroundTransparency = 1, TextColor3 = Theme.Muted}, 0.2)
    end)
    closeBtn.MouseButton1Click:Connect(function() self:Toggle(false) end)

    local notifyHolder = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1,1),
        Position = UDim2.new(1,-20,1,-20),
        Size = UDim2.new(0,280,1,-40),
        BackgroundTransparency = 1,
        Parent = screenGui
    })
    local function fitNotify()
        notifyHolder.Size = UDim2.new(0, math.min(280, screenGui.AbsoluteSize.X - 40), 1, -40)
    end
    table.insert(self._connections, screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitNotify))
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0,4),
        Parent = notifyHolder
    })
    self.NotifyHolder = notifyHolder
    self._notifyOrder = 0
    self._toasts = {}
    self.MaxNotifications = windowConfig.MaxNotifications or 4
    self._controlsDirty = true

    table.insert(self._connections, body.DescendantAdded:Connect(function() self._controlsDirty = true end))
    table.insert(self._connections, body.DescendantRemoving:Connect(function() self._controlsDirty = true end))

    self:_enableDrag()
    self.MaxSize = windowConfig.MaxSize
    self.KeepOnScreen = windowConfig.KeepOnScreen ~= false
    self:_enableResize(windowConfig.MinSize or Vector2.new(480,360))

    local configSave = windowConfig.ConfigurationSaving
    if type(configSave) == "table" and configSave.Enabled ~= false then
        self.ConfigFolder = configSave.FolderName or defaultName
        self.ConfigName = configSave.FileName or "default"
        self._autoSaveEnabled = configSave.AutoSave == true
    else
        self.ConfigFolder = defaultName
        self.ConfigName = "default"
        self._autoSaveEnabled = false
    end

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.Escape and self._dialog and self._dialog.Dismissable then
            self._dialog.Cancel()
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self.Keybind then
            task.defer(function()
                local consumed = self._consumedKey == input.KeyCode
                    and os.clock() - (self._consumedAt or 0) < 0.2
                self._consumedKey = nil
                if not consumed and not self._destroyed then
                    self:Toggle(not self.Open)
                end
            end)
        end
    end))

    pcall(function()
        if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(screenGui)
        end
    end)

    screenGui.Parent = windowConfig.Parent or getHui()
    scale.Scale = 0.9
    body.GroupTransparency = 1
    shadow.ImageTransparency = 1
    self.BodyStroke.Transparency = 1
    root.Visible = false
    self:_fitToScreen(true)

    table.insert(self._connections, screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_fitToScreen()
        self:_clampToScreen()
    end))

    if (windowConfig.OpenButton ~= nil and windowConfig.OpenButton ~= false)
        or (windowConfig.OpenButton == nil and isTouch)
    then
        self:_createOpenButton(type(windowConfig.OpenButton) == "table" and windowConfig.OpenButton or {})
    end

    self._introDone = false
    table.insert(AirFlow.Windows, self)

    if windowConfig.Home then
        self:_buildHome(type(windowConfig.Home) == "table" and windowConfig.Home or {})
    end

    local loading = windowConfig.Loading
    if type(loading) == "table" then
        windowConfig.LoadingDuration = loading.Duration or windowConfig.LoadingDuration
        windowConfig.LoadingText = loading.Text or loading.Subtitle or windowConfig.LoadingText
        windowConfig.LoadingSteps = loading.Steps or windowConfig.LoadingSteps
        windowConfig.LoadingTitle = loading.Title or windowConfig.LoadingTitle
        loading = loading.Enabled ~= false
    end

    if loading == false then
        task.defer(function() self:_playIntro() end)
    else
        self:_showLoader(windowConfig)
    end

    return self
end

AirFlow.CreateWindow = AirFlow.Window

local function swapColor(inst, prop, map)
    local hex = inst[prop]:ToHex()
    local newColor = map[hex]
    if newColor then inst[prop] = newColor end
end

local function swapGradient(grad, map)
    local changed = false
    local keys = {}
    for i, kp in ipairs(grad.Color.Keypoints) do
        local newColor = map[kp.Value:ToHex()]
        if newColor then changed = true end
        keys[i] = ColorSequenceKeypoint.new(kp.Time, newColor or kp.Value)
    end
    if changed then grad.Color = ColorSequence.new(keys) end
end

local function recolor(inst, map)
    if inst:GetAttribute("AirflowNoTheme") then return end
    if inst:IsA("GuiObject") then swapColor(inst, "BackgroundColor3", map) end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        swapColor(inst, "TextColor3", map)
    end
    if inst:IsA("TextBox") then swapColor(inst, "PlaceholderColor3", map) end
    if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
        swapColor(inst, "ImageColor3", map)
    end
    if inst:IsA("ScrollingFrame") then swapColor(inst, "ScrollBarImageColor3", map) end
    if inst:IsA("UIStroke") then
        swapColor(inst, "Color", map)
    elseif inst:IsA("UIGradient") then
        swapGradient(inst, map)
    end
end

local function recolorAll(map)
    for _, window in ipairs(AirFlow.Windows) do
        if window.Gui and window.Gui.Parent then
            for _, desc in ipairs(window.Gui:GetDescendants()) do
                recolor(desc, map)
            end
        end
    end
end

local function resolveTheme(theme)
    if type(theme) == "string" then
        local t = AirFlow.Themes[theme]
        if not t then
            warn("[AirFlow] unknown theme: " .. theme)
            return nil
        end
        return table.clone(t), theme
    elseif type(theme) == "table" then
        local base = AirFlow.Themes[theme.Base or "Default"] or AirFlow.Themes.Default
        local merged = table.clone(base)
        for _, key in ipairs(THEME_KEYS) do
            if typeof(theme[key]) == "Color3" then merged[key] = theme[key] end
        end
        return merged, theme.Name or "Custom"
    end
    warn("[AirFlow] SetTheme expects a theme name or a table of colours")
    return nil
end

function AirFlow:GetThemes()
    local list = {}
    for name in pairs(AirFlow.Themes) do
        if name ~= "Default" then table.insert(list, name) end
    end
    table.sort(list)
    table.insert(list, 1, "Default")
    return list
end

function AirFlow:AddTheme(name, theme)
    assert(type(name) == "string" and name ~= "", "AddTheme needs a name")
    local resolved = resolveTheme(theme)
    if resolved then AirFlow.Themes[name] = resolved end
    return resolved ~= nil
end

local themeGen = 0
function AirFlow:SetTheme(theme)
    local resolved, name = resolveTheme(theme)
    if not resolved then return false end
    local colorMap = {}
    local newColors = {}
    for _, key in ipairs(THEME_KEYS) do
        newColors[resolved[key]:ToHex()] = true
    end
    for _, key in ipairs(THEME_KEYS) do
        local oldColor = Theme[key]
        local newColor = resolved[key]
        local hex = oldColor:ToHex()
        if oldColor ~= newColor and colorMap[hex] == nil then
            colorMap[hex] = newColor
        end
    end
    for _, key in ipairs(THEME_KEYS) do Theme[key] = resolved[key] end
    AirFlow.ThemeName = name
    recolorAll(colorMap)
    themeGen += 1
    local myGen = themeGen
    local reverse = {}
    for hex, color in pairs(colorMap) do
        if not newColors[hex] then reverse[hex] = color end
    end
    task.delay(0.6, function()
        if myGen == themeGen then recolorAll(reverse) end
    end)
    return true
end

function AirFlow:Notify(config)
    local win = AirFlow.Windows[#AirFlow.Windows]
    if win then return win:Notify(config) end
end

function AirFlow:Confirm(config)
    local win = AirFlow.Windows[#AirFlow.Windows]
    if win then return win:Confirm(config) end
end

function AirFlow:Dialog(config)
    local win = AirFlow.Windows[#AirFlow.Windows]
    if win then return win:Dialog(config) end
end

local function rectContains(pos, obj)
    local tl = obj.AbsolutePosition
    local sz = obj.AbsoluteSize
    return pos.X >= tl.X and pos.X <= tl.X + sz.X
        and pos.Y >= tl.Y and pos.Y <= tl.Y + sz.Y
end

local function visibleThrough(ctrl, stopAt, pos)
    local cur = ctrl
    while cur and cur ~= stopAt and cur:IsA("GuiObject") do
        if not cur.Visible then return false end
        local parent = cur.Parent
        if parent and parent ~= stopAt and parent:IsA("GuiObject")
            and (parent.ClipsDescendants or parent:IsA("ScrollingFrame"))
            and not rectContains(pos, parent)
        then
            return false
        end
        cur = parent
    end
    return true
end

function Window:_refreshControls()
    local list = {}
    for _, desc in ipairs(self.Body:GetDescendants()) do
        if desc:IsA("GuiButton") or desc:IsA("TextBox") or desc:GetAttribute("NoDrag") then
            table.insert(list, desc)
        end
    end
    self._controls = list
    self._controlsDirty = false
end

function Window:_overControl(pos)
    if self._dialog then return true end
    if self._controlsDirty then self:_refreshControls() end
    for _, ctrl in ipairs(self._controls) do
        if ctrl.Parent and rectContains(pos, ctrl) and visibleThrough(ctrl, self.Body, pos) then
            return true
        end
    end
    return false
end

function Window:_overOverlay(pos)
    if self._grip and rectContains(pos, self._grip) then return true end
    if self.OpenButton and self.OpenButton.Visible and rectContains(pos, self.OpenButton) then return true end
    for _, child in ipairs(self.NotifyHolder:GetChildren()) do
        if child:IsA("GuiObject") and rectContains(pos, child) then return true end
    end
    return false
end

function Window:_enableDrag()
    local dragging = false
    local dragOffset = Vector2.zero
    local targetPos

    local function currentCenter()
        local r = self.Root
        return r.AbsolutePosition + r.AbsoluteSize * r.AnchorPoint - self.Gui.AbsolutePosition
    end

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input)
        if not isClick(input) then return end
        if not self.Open or not self.Root.Visible then return end
        local pos = mousePos()
        if not rectContains(pos, self.Body) or self:_overControl(pos) or self:_overOverlay(pos) then return end
        dragging = true
        dragOffset = pos - currentCenter()
    end))

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if isClick(input) then
            dragging = false
            targetPos = nil
            self:_clampToScreen()
        end
    end))

    table.insert(self._frameSteps, function(dt)
        if not dragging then return end
        targetPos = mousePos() - dragOffset
        local center = currentCenter()
        local alpha = 1 - math.exp(-dt * 45)
        local next = center:Lerp(targetPos, alpha)
        self.Root.Position = UDim2.fromOffset(next.X, next.Y)
    end)
end

local function revealInstance(gui, delay, immediate)
    if not gui.Visible and not immediate then return end
    gui.Visible = false
    task.delay(delay, function()
        if not gui.Parent then return end
        local s = create("UIScale", {Scale = 0.94, Parent = gui})
        gui.Visible = true
        tween(s, {Scale = 1}, 0.4, Enum.EasingStyle.Back)
        task.delay(0.4, function() s:Destroy() end)
    end)
end

function Window:_revealCards(tab, baseDelay)
    if tab._revealed then return end
    tab._revealed = true
    local i = 0
    for _, child in ipairs(tab.List:GetChildren()) do
        if child:IsA("GuiObject") then
            revealInstance(child, (baseDelay or 0) + i * 0.035)
            i += 1
        end
    end
end

function Window:_playIntro(isResize)
    if self._introDone then return end
    self._introDone = true
    task.delay(1, function() self._autoSaveReady = true end)

    local root, body, shadow, scale = self.Root, self.Body, self.Shadow, self.Scale
    if self.CurrentTab then
        self:_revealCards(self.CurrentTab, isResize and 0.15 or 0.25)
    end
    root.Visible = true

    if isResize then
        scale.Scale = self._fitScale or 1
        root.Position = UDim2.fromScale(0.5,0.5)
        tween(body, {GroupTransparency = 0}, 0.3)
        tween(self.BodyStroke, {Transparency = 0}, 0.3)
        tween(shadow, {ImageTransparency = 0.6}, 0.3)
    else
        root.Position = UDim2.new(0.5,0,0.5,24)
        tween(scale, {Scale = self._fitScale or 1}, 0.5, Enum.EasingStyle.Back)
        tween(root, {Position = UDim2.fromScale(0.5,0.5)}, 0.5, Enum.EasingStyle.Quint)
        tween(body, {GroupTransparency = 0}, 0.35)
        tween(self.BodyStroke, {Transparency = 0}, 0.35)
        tween(shadow, {ImageTransparency = 0.6}, 0.5)
    end

    for i, tab in ipairs(self.Tabs) do
        revealInstance(tab._button, 0.1 + i * 0.05, true)
    end
    self.Indicator.Visible = false
    task.delay(0.15 + #self.Tabs * 0.05, function()
        if self.CurrentTab then self:_placeIndicator(self.CurrentTab) end
    end)
end

function Window:_showLoader(cfg)
    local loader = create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5,0,0.5,16),
        Size = UDim2.fromOffset(300,132),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 10,
        Parent = self.Gui
    })
    local loaderCorner = corner(loader, UDim.new(0,12))
    local loaderStroke = stroke(loader, Theme.Stroke, 1)
    tintOverlay(loader)
    glowLayer(loader, UDim2.fromOffset(320,140), UDim2.new(1,-20,0,-20), 0.85, 90)
    glowLayer(loader, UDim2.fromOffset(240,100), UDim2.new(0,10,1,10), 0.9, 270)

    local loaderScale = create("UIScale", {Scale = 0.92, Parent = loader})
    local loaderShadow = create("ImageLabel", {
        Position = UDim2.fromOffset(-25,-25),
        Size = UDim2.new(1,50,1,50),
        BackgroundTransparency = 1,
        Image = Assets.Shadow,
        ImageColor3 = Color3.new(0,0,0),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49,49,450,450),
        ZIndex = 0,
        Parent = loader
    })

    local iconHolder = create("Frame", {
        Position = UDim2.fromOffset(24,26),
        Size = UDim2.fromOffset(40,40),
        BackgroundTransparency = 1,
        Parent = loader
    })
    local loaderIcon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.fromScale(0.5,0.5),
        Size = UDim2.fromScale(0.5,0.5),
        Rotation = -14,
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        Parent = iconHolder
    })
    applyIcon(loaderIcon, cfg.Icon or Assets.Logo)
    task.delay(0.15, function()
        tween(loaderIcon, {Size = UDim2.fromScale(0.85,0.85), Rotation = 0}, 0.6, Enum.EasingStyle.Back)
        tween(loaderIcon, {ImageTransparency = 0}, 0.4)
    end)

    textLabel {
        Position = UDim2.fromOffset(78,30),
        Size = UDim2.new(1,-100,0,22),
        Text = cfg.LoadingTitle or cfg.Title or "Airflow",
        TextSize = 20,
        Parent = loader
    }

    local statusText = textLabel {
        Position = UDim2.fromOffset(78,52),
        Size = UDim2.new(1,-100,0,16),
        Text = cfg.LoadingText or cfg.Subtitle or "Loading",
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = loader
    }

    local barBg = create("Frame", {
        Position = UDim2.new(0,24,1,-30),
        Size = UDim2.new(1,-48,0,4),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = loader
    })
    corner(barBg, UDim.new(1,0))

    local barFill = create("Frame", {
        Size = UDim2.fromScale(0,1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = barBg
    })
    corner(barFill, UDim.new(1,0))

    local shimmer = create("Frame", {
        Position = UDim2.fromScale(-0.4,0),
        Size = UDim2.fromScale(0.4,1),
        BackgroundColor3 = Color3.new(1,1,1),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = barBg
    })
    create("UIGradient", {
        Transparency = NumberSequence.new {
            NumberSequenceKeypoint.new(0,1),
            NumberSequenceKeypoint.new(0.5,0),
            NumberSequenceKeypoint.new(1,1)
        },
        Parent = shimmer
    })

    local duration = cfg.LoadingDuration or 1.6

    tween(loader, {GroupTransparency = 0, Position = UDim2.fromScale(0.5,0.5)}, 0.4, Enum.EasingStyle.Quint)
    tween(loaderScale, {Scale = 1}, 0.5, Enum.EasingStyle.Back)
    tween(loaderShadow, {ImageTransparency = 0.6}, 0.4)

    local shimmerTween = TweenService:Create(shimmer,
        TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1),
        {Position = UDim2.fromScale(1,0)})
    shimmerTween:Play()

    tween(barFill, {Size = UDim2.fromScale(0.85,1)}, duration * 0.8, Enum.EasingStyle.Quart)
    task.spawn(loadLucide)

    local steps = cfg.LoadingSteps or {"Preparing interface", "Loading icons", "Almost there"}
    for i, step in ipairs(steps) do
        task.delay(duration * (i - 1) / #steps, function()
            if loader.Parent then statusText.Text = step end
        end)
    end

    task.delay(duration, function()
        tween(barFill, {Size = UDim2.fromScale(1,1)}, 0.25, Enum.EasingStyle.Quint)
        task.delay(0.25, function()
            shimmerTween:Cancel()
            for _, child in ipairs(loader:GetChildren()) do
                if child:IsA("TextLabel") then tween(child, {TextTransparency = 1}, 0.15) end
            end
            for _, child in ipairs(iconHolder:GetChildren()) do
                tween(child, {ImageTransparency = 1}, 0.15)
            end
            tween(barBg, {BackgroundTransparency = 1}, 0.15)
            tween(barFill, {BackgroundTransparency = 1}, 0.15)
            tween(shimmer, {BackgroundTransparency = 1}, 0.1)

            local scale = self._fitScale or 1
            local s = self.Root.Size
            tween(loader, {
                Size = UDim2.fromOffset(s.X.Offset * scale, s.Y.Offset * scale),
                Position = UDim2.fromScale(0.5,0.5)
            }, 0.5, Enum.EasingStyle.Quint)
            tween(loaderCorner, {CornerRadius = UDim.new(0,10)}, 0.5, Enum.EasingStyle.Quint)
            tween(loaderScale, {Scale = 1}, 0.5, Enum.EasingStyle.Quint)

            task.delay(0.28, function()
                self:_playIntro(true)
                tween(loader, {GroupTransparency = 1}, 0.25)
                tween(loaderStroke, {Transparency = 1}, 0.2)
                tween(loaderShadow, {ImageTransparency = 1}, 0.2)
            end)

            task.delay(0.6, function() loader:Destroy() end)
        end)
    end)
end

function Window:_fitToScreen(instant)
    local guiSize = self.Gui.AbsoluteSize
    if guiSize.X == 0 or guiSize.Y == 0 then return end
    local base = self.Root.Size
    local fitScale = math.min(1,
        (guiSize.X - 24) / math.max(base.X.Offset, 1),
        (guiSize.Y - 24) / math.max(base.Y.Offset, 1))
    self._fitScale = math.max(fitScale, 0.45)
    if self._introDone and self.Open then
        if instant then
            self.Scale.Scale = self._fitScale
        else
            tween(self.Scale, {Scale = self._fitScale}, 0.2)
        end
    end
end

function Window:_clampToScreen()
    if not self.KeepOnScreen then return end
    local guiSize = self.Gui.AbsoluteSize
    local root = self.Root
    local half = root.AbsoluteSize / 2
    local center = root.AbsolutePosition + half - self.Gui.AbsolutePosition
    local clamped = Vector2.new(
        math.clamp(center.X, math.min(half.X, guiSize.X / 2), math.max(guiSize.X - half.X, guiSize.X / 2)),
        math.clamp(center.Y, math.min(half.Y, guiSize.Y / 2), math.max(guiSize.Y - half.Y, guiSize.Y / 2))
    )
    if (clamped - center).Magnitude > 0.5 then
        tween(root, {Position = UDim2.fromOffset(clamped.X, clamped.Y)}, 0.25, Enum.EasingStyle.Quint)
    end
end

function Window:_createOpenButton(cfg)
    local gui = self.Gui
    local pill = create("TextButton", {
        AnchorPoint = Vector2.new(0.5,0),
        Position = UDim2.new(0.5,0,0,14),
        Size = UDim2.fromOffset(0,40),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 30,
        Parent = gui
    })
    corner(pill, UDim.new(1,0))
    stroke(pill, Theme.Stroke)
    pad(pill, 12, 16)

    local icon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0,0.5),
        Position = UDim2.new(0,0,0.5,0),
        Size = UDim2.fromOffset(20,20),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 31,
        Parent = pill
    })
    applyIcon(icon, cfg.Icon or Assets.Logo)

    textLabel {
        Position = UDim2.fromOffset(28,0),
        Size = UDim2.new(0,0,1,0),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = cfg.Title or "Airflow",
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.None,
        ZIndex = 31,
        Parent = pill
    }

    self.OpenButton = pill
    local pressing, dragging = false, false
    local pressOffset, pressStart = Vector2.zero, Vector2.zero

    pill.InputBegan:Connect(function(input)
        if isClick(input) then
            pressing = true
            dragging = false
            pressStart = mousePos()
            pressOffset = pressStart - pill.AbsolutePosition
        end
    end)

    table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
        if not pressing then return end
        if not isMove(input) then return end
        local pos = mousePos()
        if (pos - pressStart).Magnitude > 4 then dragging = true end
        if not dragging then return end
        local newPos = pos - pressOffset - gui.AbsolutePosition
        pill.AnchorPoint = Vector2.new(0,0)
        pill.Position = UDim2.fromOffset(
            math.clamp(newPos.X, 0, math.max(gui.AbsoluteSize.X - pill.AbsoluteSize.X, 0)),
            math.clamp(newPos.Y, 0, math.max(gui.AbsoluteSize.Y - pill.AbsoluteSize.Y, 0))
        )
    end))

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if pressing and isClick(input) then
            pressing = false
            if not dragging then self:Toggle() end
        end
    end))
end

function Window:_enableResize(minSize)
    local maxSize = self.MaxSize or Vector2.new(math.huge, math.huge)
    local grip = create("Frame", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(1,4,1,4),
        Size = UDim2.fromOffset(32,32),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 20,
        Parent = self.Root
    })
    self._grip = grip
    local gripIcon = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5,-16,0.5,-16),
        Size = UDim2.fromOffset(96,96),
        BackgroundTransparency = 1,
        Image = "rbxassetid://120997033468887",
        ImageColor3 = Theme.Accent,
        ImageTransparency = 0.8,
        ZIndex = 20,
        Parent = grip
    })

    local dragging = false
    local startSize = self.Root.Size
    local startMouse = Vector2.zero
    local newSize

    grip.InputBegan:Connect(function(input)
        if isClick(input) then
            dragging = true
            startSize = self.Root.Size
            startMouse = mousePos()
            tween(gripIcon, {ImageTransparency = 0.35}, 0.1)
        end
    end)
    grip.MouseEnter:Connect(function()
        if not dragging then tween(gripIcon, {ImageTransparency = 0.35}, 0.1) end
    end)
    grip.MouseLeave:Connect(function()
        if not dragging then tween(gripIcon, {ImageTransparency = 0.8}, 0.17) end
    end)

    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
        if dragging and isClick(input) then
            dragging = false
            tween(gripIcon, {ImageTransparency = 0.8}, 0.17)
            if newSize then
                self.Root.Size = UDim2.fromOffset(newSize.X, newSize.Y)
                newSize = nil
            end
            self:_fitToScreen()
            self:_clampToScreen()
        end
    end))

    table.insert(self._frameSteps, function(dt)
        if not dragging then return end
        local delta = (mousePos() - startMouse) / self.Scale.Scale
        newSize = Vector2.new(
            math.clamp(startSize.X.Offset + delta.X * 2, minSize.X, maxSize.X),
            math.clamp(startSize.Y.Offset + delta.Y * 2, minSize.Y, maxSize.Y)
        )
        local current = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset)
        local alpha = 1 - math.exp(-dt * 35)
        local target = current:Lerp(newSize, alpha)
        target = Vector2.new(math.floor(target.X + 0.5), math.floor(target.Y + 0.5))
        if target ~= current then
            self.Root.Size = UDim2.fromOffset(target.X, target.Y)
        end
    end)
end

local function sanitize(name)
    name = tostring(name or "")
        :gsub("[%c/\\:%*%?\"<>|]", "")
        :gsub("%.%.+", ".")
        :gsub("^[%s%.]+", "")
        :gsub("[%s%.]+$", "")
    if name == "" then return nil end
    return name
end

local function buildPath(window, name)
    local clean = sanitize(name)
    if not clean then return nil, "invalid config name" end
    return window.ConfigFolder .. "/" .. clean .. ".json", clean
end

local function hasFileApi()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

local function ensureFolder(folder)
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
        makefolder(folder)
    end
end

local function serialize(element)
    local t = element._type
    local v = element:Get()
    if t == "Keybind" then
        return {Type = t, Value = v and v.Name or nil}
    elseif t == "ColorPicker" then
        return {Type = t, Value = {v.R, v.G, v.B}}
    end
    return {Type = t, Value = v}
end

local function restore(element, data, silent)
    local t = element._type
    local v = data.Value
    if t == "Keybind" then
        element:Set(nameToKey(v), silent)
    elseif t == "ColorPicker" then
        if type(v) == "table" then
            element:Set(Color3.new(v[1], v[2], v[3]), silent)
        end
    elseif v ~= nil then
        element:Set(v, silent)
    end
end

function Window:SaveConfig(name)
    if not hasFileApi() then return false, "file API unavailable" end
    local path, clean = buildPath(self, name or self.ConfigName)
    if not path then return false, clean end
    local data = {}
    for flag, element in pairs(self.Flags) do
        if element._type and type(element.Get) == "function" then
            data[flag] = serialize(element)
        end
    end
    local ok, err = pcall(function()
        ensureFolder(self.ConfigFolder)
        writefile(path, HttpService:JSONEncode(data))
    end)
    if ok then self.ConfigName = clean end
    return ok, err
end

function Window:LoadConfig(name, silent)
    if not hasFileApi() then return false, "file API unavailable" end
    local path, clean = buildPath(self, name or self.ConfigName)
    if not path then return false, clean end
    name = clean
    if not isfile(path) then return false, "no config named " .. name end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false, "config is not valid JSON" end
    local prev = self._autoSaveEnabled
    self._autoSaveEnabled = false
    for flag, entry in pairs(data) do
        local element = self.Flags[flag]
        if element and type(element.Set) == "function"
            and type(entry) == "table" and entry.Type == element._type
        then
            local ok2, err = pcall(restore, element, entry, silent == true)
            if not ok2 then
                warn("[AirFlow] could not load flag " .. tostring(flag) .. ": " .. tostring(err))
            end
        end
    end
    self._autoSaveEnabled = prev
    self._autoSaveReady = true
    self.ConfigName = name
    return true
end

function Window:DeleteConfig(name)
    if not hasFileApi() or type(delfile) ~= "function" then
        return false, "file API unavailable"
    end
    local path, clean = buildPath(self, name)
    if not path then return false, clean end
    if not isfile(path) then return false, "no config named " .. clean end
    local ok, err = pcall(delfile, path)
    return ok, err
end

function Window:ListConfigs()
    local result = {}
    if type(listfiles) ~= "function" or type(isfolder) ~= "function" or not isfolder(self.ConfigFolder) then
        return result
    end
    for _, path in ipairs(listfiles(self.ConfigFolder)) do
        local name = path:match("([^/\\]+)%.json$")
        if name then table.insert(result, name) end
    end
    table.sort(result)
    return result
end

function Window:SetAutoSave(value)
    self._autoSaveEnabled = value == true
end

function Window:_autoSave()
    if not self._autoSaveEnabled or self._destroyed or not self._autoSaveReady then return end
    if self._autoSavePending then return end
    self._autoSavePending = true
    task.delay(0.5, function()
        self._autoSavePending = false
        if not self._destroyed then self:SaveConfig(self.ConfigName) end
    end)
end

local function makeEmptyState(parent, icon, text)
    local container = create("Frame", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5,0,0.5,-10),
        Size = UDim2.fromOffset(200,70),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local iconLabel = create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5,0),
        Position = UDim2.new(0.5,0,0,0),
        Size = UDim2.fromOffset(26,26),
        BackgroundTransparency = 1,
        ImageColor3 = Theme.Muted,
        ImageTransparency = 0.15,
        ScaleType = Enum.ScaleType.Fit,
        Parent = container
    })
    applyIcon(iconLabel, icon)
    local label = textLabel {
        Position = UDim2.fromOffset(0,36),
        Size = UDim2.new(1,0,0,16),
        Text = text,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = container
    }
    return container, label, iconLabel
end

local function buildStatCard(parent, order, icon, label)
    local card = create("Frame", {
        Size = UDim2.new(0.5,-4,0,62),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = order,
        Parent = parent
    })
    corner(card)
    stroke(card)
    card:SetAttribute("NoDrag", true)
    if icon then
        iconFrame(card, icon, Theme.Muted, UDim2.new(0,14,0,21))
    end
    textLabel {
        Position = UDim2.fromOffset(icon and 36 or 14, 12),
        Size = UDim2.new(1, -(icon and 50 or 28), 0, 16),
        Text = label,
        TextSize = 12,
        TextColor3 = Theme.Muted,
        Parent = card
    }
    local value = textLabel {
        Position = UDim2.fromOffset(14,34),
        Size = UDim2.new(1,-28,0,18),
        Text = "…",
        TextSize = 15,
        Parent = card
    }
    return value
end

local fadeOrigins = setmetatable({}, {__mode = "k"})

local function fadeCard(root)
    local records = {}
    local function record(inst, prop)
        local cached = fadeOrigins[inst]
        if cached == nil then
            cached = inst[prop]
            fadeOrigins[inst] = cached
        end
        table.insert(records, {inst, prop, cached})
    end
    local function walk(node)
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                record(child, "TextTransparency")
            elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                record(child, "ImageTransparency")
            elseif child:IsA("UIStroke") then
                record(child, "Transparency")
            elseif child:IsA("Frame") then
                record(child, "BackgroundTransparency")
            end
            walk(child)
        end
    end
    if root:IsA("Frame") then record(root, "BackgroundTransparency") end
    walk(root)
    for _, rec in ipairs(records) do
        rec[1][rec[2]] = 1
        tween(rec[1], {[rec[2]] = rec[3]}, 0.28)
    end
end

local function slideIn(layer, offsetY)
    offsetY = offsetY or 0
    layer.GroupTransparency = 1
    layer.Position = UDim2.fromOffset(0, offsetY + 14)
    layer.Visible = true
    tween(layer, {
        GroupTransparency = 0,
        Position = UDim2.fromOffset(0, offsetY)
    }, 0.32, Enum.EasingStyle.Quint)
end

function Window:_buildHome(cfg)
    local homeTab = self:Tab {
        Name = cfg.Name or "Home",
        Desc = cfg.Desc,
        Icon = cfg.Icon or "house"
    }
    local list = homeTab.List
    local pages = cfg.Pages or cfg.Tabs
    local pageList = {}

    local tabRow
    if type(pages) == "table" and #pages > 0 then
        tabRow = create("Frame", {
            Size = UDim2.new(1,0,0,32),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = list
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0,6),
            Parent = tabRow
        })
    end

    local greeting = cfg.Greeting
    if greeting == nil then
        local hour = tonumber(os.date("%H")) or 12
        local part = hour < 12 and "morning" or (hour < 18 and "afternoon" or "evening")
        greeting = "Good " .. part .. "."
    end

    local hero = create("Frame", {
        Size = UDim2.new(1,0,0,58),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Parent = list
    })
    hero:SetAttribute("NoDrag", true)
    corner(hero)
    stroke(hero)

    local avatar = create("ImageLabel", {
        Position = UDim2.fromOffset(12,11),
        Size = UDim2.fromOffset(36,36),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = hero
    })
    corner(avatar, UDim.new(0,8))
    stroke(avatar)

    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and url then avatar.Image = url end
    end)

    textLabel {
        Position = UDim2.fromOffset(58,11),
        Size = UDim2.new(1,-72,0,18),
        Text = (cfg.Welcome or "Hello, ") .. LocalPlayer.DisplayName,
        TextSize = 15,
        Parent = hero
    }
    textLabel {
        Position = UDim2.fromOffset(58,30),
        Size = UDim2.new(1,-72,0,16),
        Text = greeting,
        TextSize = 13,
        FontFace = Fonts.Regular,
        TextColor3 = Theme.Muted,
        Parent = hero
    }

    local stack = create("Frame", {
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = list
    })
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0,8),
        Parent = stack
    })

    if cfg.Sections ~= false then
        local headerRow = create("Frame", {
            Size = UDim2.new(1,0,0,24),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = stack
        })
        local title = textLabel {
            Position = UDim2.fromOffset(2,6),
            Size = UDim2.new(0,0,0,16),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = string.upper(cfg.SectionName or "System info"),
            TextSize = 12,
            TextColor3 = Theme.Muted,
            TextTruncate = Enum.TextTruncate.None,
            Parent = headerRow
        }
        local line = create("Frame", {
            AnchorPoint = Vector2.new(1,0.5),
            Position = UDim2.new(1,0,0,14),
            Size = UDim2.new(1,-12,0,1),
            BackgroundColor3 = Theme.Stroke,
            BorderSizePixel = 0,
            Parent = headerRow
        })
        local function update()
            line.Size = UDim2.new(1, -(title.AbsoluteSize.X / self.Scale.Scale + 14), 0, 1)
        end
        title:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
        task.defer(update)
    end

    local statsGrid = create("Frame", {
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = stack
    })
    create("UIGridLayout", {
        CellSize = UDim2.new(0.5,-4,0,62),
        CellPadding = UDim2.fromOffset(8,8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = statsGrid
    })

    local statNames = cfg.Stats or {"FPS","Ping","Executor","Game","Region","Time"}
    local enabled = {}
    for _, name in ipairs(statNames) do enabled[name] = true end
    local order = 0
    local function addStat(key, icon, label)
        if not enabled[key] then return nil end
        order += 1
        return buildStatCard(statsGrid, order, icon, label)
    end

    local fpsVal = addStat("FPS", "activity", "FPS")
    local pingVal = addStat("Ping", "wifi", "Ping")
    local execVal = addStat("Executor", "terminal", "Executor")
    local gameVal = addStat("Game", "gamepad-2", "Game")
    local regionVal = addStat("Region", "globe", "Server region")
    local timeVal = addStat("Time", "clock", "Time of day")
    local playersVal = addStat("Players", "users", "Players")
    local uptimeVal = addStat("Uptime", "timer", "Session")

    if execVal then execVal.Text = getExecutorName() end
    if gameVal then
        gameVal.Text = "Loading"
        task.spawn(function() gameVal.Text = getGameName() end)
    end
    if regionVal then
        regionVal.Text = "Loading"
        fetchRegion(function(region) regionVal.Text = region end)
    end

    local frameCount = 0
    local startTime = os.clock()
    self:_listen("Render", function() frameCount += 1 end)

    task.spawn(function()
        while not self._destroyed and homeTab.List.Parent and homeTab._page.Parent do
            if not self.Open or self.CurrentTab ~= homeTab then
                frameCount = 0
                task.wait(1)
                continue
            end
            if fpsVal then fpsVal.Text = tostring(frameCount) end
            frameCount = 0
            if pingVal then
                local ok, ping = pcall(function()
                    return math.floor(LocalPlayer:GetNetworkPing() * 1000)
                end)
                pingVal.Text = (ok and ping or 0) .. " ms"
            end
            if timeVal then timeVal.Text = os.date(cfg.TimeFormat or "%H:%M") end
            if playersVal then playersVal.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers end
            if uptimeVal then
                local s = math.floor(os.clock() - startTime)
                uptimeVal.Text = string.format("%d:%02d", math.floor(s / 60), s % 60)
            end
            task.wait(1)
        end
    end)

    table.insert(pageList, {
        Title = cfg.SectionName or "Details",
        Icon = cfg.TabIcon or "layout-grid",
        Frame = stack
    })

    if tabRow then
        for _, page in ipairs(pages) do
            local container = create("Frame", {
                Size = UDim2.new(1,0,0,0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Visible = false,
                LayoutOrder = 3,
                Parent = list
            })
            create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0,8),
                Parent = container
            })

            if type(page.Content) == "string" then
                local card = create("Frame", {
                    Size = UDim2.new(1,0,0,0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Surface2,
                    BorderSizePixel = 0,
                    LayoutOrder = 1,
                    Parent = container
                })
                card:SetAttribute("NoDrag", true)
                corner(card)
                stroke(card)
                pad(card, 14, 14, 12, 14)
                textLabel {
                    Size = UDim2.new(1,0,0,0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Text = page.Content,
                    TextSize = 13,
                    FontFace = Fonts.Regular,
                    TextColor3 = Theme.Muted,
                    TextWrapped = true,
                    TextTruncate = Enum.TextTruncate.None,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Parent = card
                }
            end

            if type(page.Entries) == "table" then
                for index, entry in ipairs(page.Entries) do
                    local card = create("Frame", {
                        Size = UDim2.new(1,0,0,0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundColor3 = Theme.Surface2,
                        BorderSizePixel = 0,
                        LayoutOrder = index,
                        Parent = container
                    })
                    card:SetAttribute("NoDrag", true)
                    corner(card)
                    stroke(card)
                    pad(card, 14, 14, 12, 14)
                    create("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0,4),
                        Parent = card
                    })
                    local headerRow = create("Frame", {
                        Size = UDim2.new(1,0,0,18),
                        BackgroundTransparency = 1,
                        LayoutOrder = 1,
                        Parent = card
                    })
                    textLabel {
                        Size = UDim2.new(1,-70,1,0),
                        Text = entry.Title or entry.Version or "Update",
                        TextSize = 14,
                        Parent = headerRow
                    }
                    if entry.Date or entry.Tag then
                        local chip = create("Frame", {
                            AnchorPoint = Vector2.new(1,0.5),
                            Position = UDim2.new(1,0,0.5,0),
                            Size = UDim2.fromOffset(0,20),
                            AutomaticSize = Enum.AutomaticSize.X,
                            BackgroundColor3 = Theme.Surface,
                            BorderSizePixel = 0,
                            Parent = headerRow
                        })
                        corner(chip, UDim.new(0,5))
                        stroke(chip)
                        pad(chip, 8, 8)
                        textLabel {
                            Size = UDim2.new(0,0,1,0),
                            AutomaticSize = Enum.AutomaticSize.X,
                            Text = entry.Tag or entry.Date,
                            TextSize = 11,
                            TextColor3 = Theme.Muted,
                            TextTruncate = Enum.TextTruncate.None,
                            Parent = chip
                        }
                    end
                    local body = entry.Content or entry.Body
                    if type(entry.Changes) == "table" then
                        body = "• " .. table.concat(entry.Changes, "\n• ")
                    end
                    if body then
                        textLabel {
                            Size = UDim2.new(1,0,0,0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            Text = body,
                            TextSize = 13,
                            FontFace = Fonts.Regular,
                            TextColor3 = Theme.Muted,
                            TextWrapped = true,
                            TextTruncate = Enum.TextTruncate.None,
                            TextYAlignment = Enum.TextYAlignment.Top,
                            LayoutOrder = 2,
                            Parent = card
                        }
                    end
                end
            end

            if type(page.Build) == "function" then
                safeCall(page.Build, container)
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("GuiObject") then child:SetAttribute("NoDrag", true) end
                end
            end

            table.insert(pageList, {
                Title = page.Name or page.Title or "Page",
                Icon = page.Icon,
                Frame = container
            })
        end
    end

    local tabButtons = {}
    local function selectPage(index, noAnimate)
        local changed = self._homeIndex ~= index
        self._homeIndex = index
        hero.Visible = index == 1
        if index == 1 and changed and not noAnimate then fadeCard(hero) end
        for i, page in ipairs(pageList) do
            local active = i == index
            page.Frame.Visible = active
            if active and changed and not noAnimate then
                for _, child in ipairs(page.Frame:GetChildren()) do
                    if child:IsA("GuiObject") then fadeCard(child) end
                end
            end
            local entry = tabButtons[i]
            if entry then
                tween(entry.Frame, {BackgroundTransparency = active and 0 or 1}, 0.15)
                tween(entry.Stroke, {Transparency = active and 0 or 1}, 0.15)
                tween(entry.Label, {TextColor3 = active and Theme.Text or Theme.Muted}, 0.15)
                if entry.Icon then
                    tween(entry.Icon, {ImageColor3 = active and Theme.Accent or Theme.Muted}, 0.15)
                end
            end
        end
    end

    for order, page in ipairs(pageList) do
        local btn = create("TextButton", {
            Size = UDim2.fromOffset(0,32),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Theme.Surface2,
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = order,
            Parent = tabRow
        })
        corner(btn, UDim.new(0,7))
        local btnStroke = stroke(btn, Theme.Stroke, 1)
        pad(btn, 12, 12)

        local btnIcon
        if page.Icon then
            btnIcon = create("ImageLabel", {
                AnchorPoint = Vector2.new(0,0.5),
                Position = UDim2.new(0,0,0.5,0),
                Size = UDim2.fromOffset(14,14),
                BackgroundTransparency = 1,
                ImageColor3 = Theme.Muted,
                ScaleType = Enum.ScaleType.Fit,
                Parent = btn
            })
            applyIcon(btnIcon, page.Icon)
        end

        local btnLabel = textLabel {
            Position = UDim2.fromOffset(btnIcon and 20 or 0, 0),
            Size = UDim2.new(0,0,1,0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = page.Title,
            TextSize = 13,
            TextColor3 = Theme.Muted,
            TextTruncate = Enum.TextTruncate.None,
            Parent = btn
        }

        tabButtons[order] = {Frame = btn, Stroke = btnStroke, Label = btnLabel, Icon = btnIcon}

        btn.MouseEnter:Connect(function()
            if self._homeIndex ~= order then
                tween(btn, {BackgroundTransparency = 0.4}, 0.12)
                tween(btnStroke, {Transparency = 0.5}, 0.12)
            end
        end)
        btn.MouseLeave:Connect(function()
            if self._homeIndex ~= order then
                tween(btn, {BackgroundTransparency = 1}, 0.2)
                tween(btnStroke, {Transparency = 1}, 0.2)
            end
        end)
        btn.MouseButton1Click:Connect(function() selectPage(order) end)
    end

    selectPage(1)
    homeTab._order = 10
    self.Home = homeTab
    return homeTab
end

function Window:Tab(config, iconArg)
    config = normalize(config, {Title = "Name", Description = "Desc"})
    if iconArg ~= nil and config.Icon == nil then config.Icon = iconArg end

    local tab = setmetatable({
        Name = config.Name or "Tab",
        Window = self,
        _order = 0
    }, Tab)

    local btn = create("TextButton", {
        Size = UDim2.new(1,0,0,38),
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = #self.Tabs + 1,
        Parent = self.TabList
    })
    corner(btn)
    local btnStroke = stroke(btn, Theme.Stroke, 1)
    tab._button = btn

    local hasIcon = config.Icon ~= nil
    if hasIcon then
        local icon = create("ImageLabel", {
            AnchorPoint = Vector2.new(0,0.5),
            Position = UDim2.new(0,12,0.5,0),
            Size = UDim2.fromOffset(16,16),
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Muted,
            ScaleType = Enum.ScaleType.Fit,
            Parent = btn
        })
        applyIcon(icon, config.Icon)
        tab._icon = icon
    end

    tab._label = textLabel {
        Position = UDim2.fromOffset(hasIcon and 36 or 14, 0),
        Size = UDim2.new(1, -(hasIcon and 44 or 22), 1, 0),
        Text = tab.Name,
        TextColor3 = Theme.Muted,
        Parent = btn
    }

    local page = create("Frame", {
        Name = tab.Name,
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.Content
    })
    tab._page = page

    textLabel {
        Position = UDim2.fromOffset(24,20),
        Size = UDim2.new(1,-72,0,24),
        Text = tab.Name,
        TextSize = 22,
        Parent = page
    }
    if config.Desc then
        textLabel {
            Position = UDim2.fromOffset(24,44),
            Size = UDim2.new(1,-72,0,16),
            Text = config.Desc,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            Parent = page
        }
    end

    local listTop = config.Desc and 70 or 58
    local list = create("ScrollingFrame", {
        Position = UDim2.fromOffset(0,listTop),
        Size = UDim2.new(1,0,1,-listTop),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.5,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = page
    })
    pad(list, 24, 24, 2, 24)
    if isTouch then list:SetAttribute("NoDrag", true) end
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0,8),
        Parent = list
    })
    tab.List = list

    local emptyHolder = makeEmptyState(page, config.Icon or "layout-grid", config.EmptyText or "Nothing here yet")
    local childCount = 0

    list.ChildAdded:Connect(function(child)
        if child:IsA("GuiObject") then
            childCount += 1
            emptyHolder.Visible = false
        end
    end)
    list.ChildRemoved:Connect(function(child)
        if child:IsA("GuiObject") then
            childCount = math.max(childCount - 1, 0)
            emptyHolder.Visible = childCount <= 0
        end
    end)
    emptyHolder.Visible = true

    btn.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then
            tween(btn, {BackgroundTransparency = 0.4}, 0.12)
            tween(btnStroke, {Transparency = 0.5}, 0.12)
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then
            tween(btn, {BackgroundTransparency = 1}, 0.2)
            tween(btnStroke, {Transparency = 1}, 0.2)
        end
    end)
    btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

    tab._stroke = btnStroke
    if not self._introDone then btn.Visible = false end

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then
        task.defer(function()
            if not self.CurrentTab then self:SelectTab(tab) end
        end)
    end

    return tab
end

Window.CreateTab = Window.Tab

function Window:Dialog(config)
    config = normalize(config, {Text = "Content", Message = "Content"})
    if self._dialog then self._dialog.Close() end

    local PAD = 18
    local backdrop = create("TextButton", {
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 40,
        Parent = self.Body
    })
    local card = create("TextButton", {
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5,0,0.5,10),
        Size = UDim2.fromOffset(300,120),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 41,
        Parent = backdrop
    })
    corner(card, UDim.new(0,10))
    local cardStroke = stroke(card, Theme.Stroke, 1)
    local cardScale = create("UIScale", {Scale = 0.94, Parent = card})

    local animated = {}
    local iconOffset = 0

    if config.Icon then
        local holder, img = iconFrame(card, config.Icon, Theme.Accent, UDim2.new(0, PAD, 0, PAD + 9))
        img.ImageTransparency = 1
        holder.ZIndex = 42
        img.ZIndex = 42
        table.insert(animated, {img, "ImageTransparency", 0})
        iconOffset = 24
    end

    local title = textLabel {
        Position = UDim2.fromOffset(PAD + iconOffset, PAD),
        Size = UDim2.new(1, -(PAD * 2 + iconOffset), 0, 18),
        Text = config.Title or "Are you sure?",
        TextSize = 15,
        TextTransparency = 1,
        ZIndex = 42,
        Parent = card
    }
    table.insert(animated, {title, "TextTransparency", 0})

    local bodyHeight = 0
    if config.Content then
        local body = textLabel {
            Position = UDim2.fromOffset(PAD, PAD + 24),
            Size = UDim2.new(1, -PAD * 2, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = config.Content,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTransparency = 1,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 42,
            Parent = card
        }
        table.insert(animated, {body, "TextTransparency", 0})
        bodyHeight = math.max(body.TextBounds.Y, 16) + 6
        body:GetPropertyChangedSignal("TextBounds"):Connect(function()
            local newHeight = math.max(body.TextBounds.Y, 16) + 6
            if newHeight ~= bodyHeight then
                bodyHeight = newHeight
                card.Size = UDim2.fromOffset(300, PAD + 24 + bodyHeight + 12 + 34 + PAD)
                local row = card:FindFirstChild("ButtonRow")
                if row then
                    row.Position = UDim2.fromOffset(PAD, PAD + 24 + bodyHeight + 12)
                end
            end
        end)
    end

    local buttonRow = create("Frame", {
        Name = "ButtonRow",
        Position = UDim2.fromOffset(PAD, PAD + 24 + bodyHeight + 12),
        Size = UDim2.new(1, -PAD * 2, 0, 34),
        BackgroundTransparency = 1,
        ZIndex = 42,
        Parent = card
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0,8),
        Parent = buttonRow
    })
    card.Size = UDim2.fromOffset(300, PAD + 24 + bodyHeight + 12 + 34 + PAD)

    local dialog = {}
    local closing = false

    function dialog.Close()
        if closing then return end
        closing = true
        if self._dialog == dialog then self._dialog = nil end
        tween(backdrop, {BackgroundTransparency = 1}, 0.18)
        tween(card, {BackgroundTransparency = 1, Position = UDim2.new(0.5,0,0.5,8)}, 0.18, Enum.EasingStyle.Quint)
        tween(cardScale, {Scale = 0.96}, 0.18, Enum.EasingStyle.Quint)
        tween(cardStroke, {Transparency = 1}, 0.12)
        for _, rec in ipairs(animated) do
            tween(rec[1], {[rec[2]] = 1}, 0.12)
        end
        task.delay(0.2, function() backdrop:Destroy() end)
    end

    for order, btnCfg in ipairs(config.Buttons or {}) do
        local primary = btnCfg.Variant == "Primary"
        local btn = create("TextButton", {
            Size = UDim2.fromOffset(0,34),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = primary and Theme.Accent or Theme.Surface2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = order,
            ZIndex = 43,
            Parent = buttonRow
        })
        corner(btn, UDim.new(0,7))
        local btnStroke = stroke(btn, primary and Theme.Accent or Theme.Stroke, 1)
        pad(btn, 14, 14)

        local label = textLabel {
            Size = UDim2.new(0,0,1,0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = btnCfg.Title or btnCfg.Name or "OK",
            TextSize = 13,
            TextColor3 = primary and Theme.AccentDark or Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 1,
            ZIndex = 44,
            Parent = btn
        }

        local restT = primary and 0.12 or 0
        local restST = primary and 0.4 or 0
        table.insert(animated, {btn, "BackgroundTransparency", restT})
        table.insert(animated, {btnStroke, "Transparency", restST})
        table.insert(animated, {label, "TextTransparency", 0})

        btn.MouseEnter:Connect(function()
            if closing then return end
            if primary then
                tween(btn, {BackgroundTransparency = 0}, 0.12)
                tween(btnStroke, {Transparency = 0}, 0.12)
            else
                tween(btnStroke, {Color = Theme.StrokeHover}, 0.12)
            end
        end)
        btn.MouseLeave:Connect(function()
            if closing then return end
            if primary then
                tween(btn, {BackgroundTransparency = restT}, 0.2)
                tween(btnStroke, {Transparency = restST}, 0.2)
            else
                tween(btnStroke, {Color = Theme.Stroke}, 0.2)
            end
        end)
        btn.MouseButton1Click:Connect(function()
            dialog.Close()
            safeCall(btnCfg.Callback)
        end)
    end

    function dialog.Cancel()
        if closing then return end
        dialog.Close()
        safeCall(config.OnCancel)
    end

    dialog.Dismissable = config.CloseOnBackdrop ~= false
    if dialog.Dismissable then
        backdrop.MouseButton1Click:Connect(dialog.Cancel)
    end

    self._dialog = dialog
    tween(backdrop, {BackgroundTransparency = 0.45}, 0.25)
    tween(card, {BackgroundTransparency = 0, Position = UDim2.fromScale(0.5,0.5)}, 0.3, Enum.EasingStyle.Quint)
    tween(cardStroke, {Transparency = 0}, 0.25)
    tween(cardScale, {Scale = 1}, 0.4, Enum.EasingStyle.Back)
    for _, rec in ipairs(animated) do
        tween(rec[1], {[rec[2]] = rec[3]}, 0.25)
    end

    return dialog
end

function Window:Confirm(config)
    config = normalize(config, {Text = "Content", Message = "Content"})
    return self:Dialog {
        Title = config.Title or "Are you sure?",
        Content = config.Content,
        Icon = config.Icon,
        OnCancel = config.OnCancel,
        Buttons = {
            {Title = config.CancelText or "Cancel", Callback = config.OnCancel},
            {Title = config.ConfirmText or "Confirm", Variant = "Primary", Callback = config.Callback}
        }
    }
end

function Window:_listen(eventName, callback, owner)
    local bucket = self._inputListeners[eventName]
    table.insert(bucket, callback)
    local function remover()
        for i, fn in ipairs(bucket) do
            if fn == callback then
                table.remove(bucket, i)
                break
            end
        end
    end
    if owner then
        owner._listeners = owner._listeners or {}
        table.insert(owner._listeners, remover)
    end
    return remover
end

function Window:_indicatorY(tab)
    local list = self.TabList
    local s = self.Scale.Scale
    return (tab._button.AbsolutePosition.Y - list.AbsolutePosition.Y + tab._button.AbsoluteSize.Y / 2) / s
        + list.Position.Y.Offset
end

function Window:_placeIndicator(tab)
    local indicator = self.Indicator
    local y = self:_indicatorY(tab)
    if not indicator.Visible then
        indicator.Visible = true
        indicator.Position = UDim2.fromOffset(6, y)
        indicator.Size = UDim2.fromOffset(3, 0)
    end
    tween(indicator, {
        Position = UDim2.fromOffset(6, y),
        Size = UDim2.fromOffset(3, 18)
    }, 0.35, Enum.EasingStyle.Back)
end

function Window:SelectTab(tab)
    if type(tab) == "string" then
        for _, candidate in ipairs(self.Tabs) do
            if candidate.Name == tab then
                tab = candidate
                break
            end
        end
    end
    if type(tab) ~= "table" or self.CurrentTab == tab then return end

    local previous = self.CurrentTab
    self.CurrentTab = tab
    self:_settleTransition()

    local gen = (self._transitionGeneration or 0) + 1
    self._transitionGeneration = gen

    if previous then
        tween(previous._button, {BackgroundTransparency = 1}, 0.2)
        tween(previous._stroke, {Transparency = 1}, 0.2)
        tween(previous._label, {TextColor3 = Theme.Muted}, 0.2)
        if previous._icon then tween(previous._icon, {ImageColor3 = Theme.Muted}, 0.2) end
        local outLayer = self._outLayer
        previous._page.Parent = outLayer
        self._outPage = previous._page
        outLayer.GroupTransparency = 0
        outLayer.Position = UDim2.fromOffset(0,0)
        outLayer.Visible = true
        tween(outLayer, {
            GroupTransparency = 1,
            Position = UDim2.fromOffset(0,-10)
        }, 0.18)
        task.delay(0.18, function()
            if self._transitionGeneration == gen then self:_settleOut() end
        end)
    end

    tween(tab._button, {BackgroundTransparency = 0}, 0.2)
    tween(tab._stroke, {Transparency = 0}, 0.2)
    tween(tab._label, {TextColor3 = Theme.Text}, 0.2)
    if tab._icon then tween(tab._icon, {ImageColor3 = Theme.Accent}, 0.2) end

    self:_placeIndicator(tab)

    local page = tab._page
    page.Position = UDim2.fromOffset(0,0)
    page.Visible = true
    page.Parent = self._inLayer
    self._inPage = page
    slideIn(self._inLayer)

    task.delay(0.32, function()
        if self._transitionGeneration == gen then self:_settleIn() end
    end)
end

function Window:_settleOut()
    local out = self._outPage
    if out then
        out.Parent = self.Content
        out.Visible = false
        self._outPage = nil
    end
    self._outLayer.Visible = false
end

function Window:_settleIn()
    local inPage = self._inPage
    if inPage then
        inPage.Parent = self.Content
        inPage.Position = UDim2.fromOffset(0,0)
        self._inPage = nil
    end
    self._inLayer.Visible = false
end

function Window:_settleTransition()
    self:_settleOut()
    self:_settleIn()
end

function Window:Toggle(state)
    if not self._introDone then return end
    if state == nil then state = not self.Open end
    if state == self.Open then return end
    self.Open = state

    if state then
        self.Root.Visible = true
        tween(self.Scale, {Scale = self._fitScale or 1}, 0.4, Enum.EasingStyle.Back)
        tween(self.Body, {GroupTransparency = 0}, 0.25)
        tween(self.BodyStroke, {Transparency = 0}, 0.25)
        tween(self.Shadow, {ImageTransparency = 0.6}, 0.3)
    else
        tween(self.Scale, {Scale = (self._fitScale or 1) * 0.94}, 0.2, Enum.EasingStyle.Quint)
        tween(self.Body, {GroupTransparency = 1}, 0.16)
        tween(self.BodyStroke, {Transparency = 1}, 0.12)
        tween(self.Shadow, {ImageTransparency = 1}, 0.16)
        task.delay(0.2, function()
            if not self.Open then self.Root.Visible = false end
        end)
    end
end

function Window:SetKeepOnScreen(value)
    self.KeepOnScreen = value ~= false
    if self.KeepOnScreen then self:_clampToScreen() end
end

function Window:SetKeybind(key)
    key = nameToKey(key)
    if not key then return end
    self.Keybind = key
    self._keyChipLabel.Text = keyToName(key)
end

function Window:SetTitle(title)
    self._titleLabel.Text = tostring(title)
end

function Window:SetSubtitle(subtitle)
    self._subtitleLabel.Text = tostring(subtitle)
end

function Window:SetIcon(icon)
    applyIcon(self._logo, icon)
end

function Window:Notify(config)
    config = normalize(config, {Text = "Content", Message = "Content", Image = "Icon"})

    local duration = config.Duration or 4
    local typeKey = NOTIFY_COLORS[config.Type]
    local accent = typeKey and Theme[typeKey] or Theme.Accent
    local titleCol = typeKey and config.Type ~= "Info" and accent or Theme.Text

    self._notifyOrder += 1
    local container = create("Frame", {
        Size = UDim2.new(1,0,0,0),
        BackgroundTransparency = 1,
        LayoutOrder = self._notifyOrder,
        Parent = self.NotifyHolder
    })
    local scroller = create("Frame", {
        Position = UDim2.fromOffset(320,0),
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = container
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
        Parent = scroller
    })
    local card = create("CanvasGroup", {
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Parent = scroller
    })
    corner(card, UDim.new(0,10))
    local cardStroke = stroke(card, Theme.Stroke)
    tintOverlay(card)
    glowLayer(card, UDim2.fromOffset(260,120), UDim2.new(1,-10,0,-10), 0.86, 90)

    local inner = create("Frame", {
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card
    })
    pad(inner, 16, 16, 14, 24)

    local iconOffset = 0
    local bar = create("Frame", {
        Position = UDim2.fromOffset(0,14),
        Size = UDim2.new(0,2,1,-28),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = card
    })
    corner(bar, UDim.new(1,0))

    if config.Icon then
        iconFrame(inner, config.Icon, accent, UDim2.new(0,0,0,8))
        iconOffset = 24
    end

    textLabel {
        Position = UDim2.fromOffset(iconOffset, 0),
        Size = UDim2.new(1, -28 - iconOffset, 0, 16),
        Text = config.Title or "Notification",
        TextSize = 14,
        TextColor3 = titleCol,
        Parent = inner
    }

    local close = create("TextButton", {
        AnchorPoint = Vector2.new(1,0),
        Position = UDim2.new(1,6,0,-5),
        Size = UDim2.fromOffset(24,24),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 22,
        FontFace = Fonts.Bold,
        AutoButtonColor = false,
        Parent = inner
    })
    close.MouseEnter:Connect(function() tween(close, {TextColor3 = Theme.Text}, 0.15) end)
    close.MouseLeave:Connect(function() tween(close, {TextColor3 = Theme.Muted}, 0.2) end)

    if config.Content then
        textLabel {
            Position = UDim2.fromOffset(iconOffset, 21),
            Size = UDim2.new(1, -iconOffset, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = config.Content,
            TextSize = 13,
            FontFace = Fonts.Regular,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = inner
        }
    end

    local progBg = create("Frame", {
        AnchorPoint = Vector2.new(0,1),
        Position = UDim2.new(0,16,1,-8),
        Size = UDim2.new(1,-32,0,3),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Parent = card
    })
    corner(progBg, UDim.new(1,0))
    local progFill = create("Frame", {
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = progBg
    })
    corner(progFill, UDim.new(1,0))

    task.defer(function()
        if container.Parent then
            tween(container, {Size = UDim2.new(1,0,0, card.AbsoluteSize.Y)}, 0.3, Enum.EasingStyle.Quint)
        end
    end)
    tween(scroller, {Position = UDim2.fromOffset(0,0)}, 0.5, Enum.EasingStyle.Back)
    tween(card, {GroupTransparency = 0}, 0.3)
    tween(shadow, {ImageTransparency = 0.6}, 0.4)
    tween(progFill, {Size = UDim2.fromScale(0,1)}, duration, Enum.EasingStyle.Linear)

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        for i, fn in ipairs(self._toasts) do
            if fn == dismiss then
                table.remove(self._toasts, i)
                break
            end
        end
        tween(scroller, {Position = UDim2.fromOffset(320,0)}, 0.3, Enum.EasingStyle.Quint)
        tween(card, {GroupTransparency = 1}, 0.2)
        tween(cardStroke, {Transparency = 1}, 0.15)
        tween(shadow, {ImageTransparency = 1}, 0.2)
        task.delay(0.22, function()
            container.ClipsDescendants = true
            tween(container, {Size = UDim2.new(1,0,0,-4)}, 0.22, Enum.EasingStyle.Quint)
            task.delay(0.24, function() container:Destroy() end)
        end)
    end

    task.delay(duration, dismiss)
    close.MouseButton1Click:Connect(dismiss)
    table.insert(self._toasts, dismiss)
    while #self._toasts > self.MaxNotifications do
        local oldest = table.remove(self._toasts, 1)
        oldest()
    end

    return {Dismiss = dismiss}
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    for i, win in ipairs(AirFlow.Windows) do
        if win == self then
            table.remove(AirFlow.Windows, i)
            break
        end
    end
    for _, conn in ipairs(self._connections) do conn:Disconnect() end
    self._connections = {}
    for flag, element in pairs(self.Flags) do
        if AirFlow.Flags[flag] == element then AirFlow.Flags[flag] = nil end
    end
    self.Flags = {}
    tween(self.Scale, {Scale = 0.9}, 0.2)
    tween(self.Body, {GroupTransparency = 1}, 0.2)
    tween(self.BodyStroke, {Transparency = 1}, 0.12)
    tween(self.Shadow, {ImageTransparency = 1}, 0.2)
    task.delay(0.22, function() self.Gui:Destroy() end)
end

return AirFlow
