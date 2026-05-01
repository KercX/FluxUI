--[[
    FluxUI (Flux) - Mobile‑Optimised UI Library
    Version: 2.2 (FluentUI‑style Color Picker)
    Features: Window, Tabs, Sections, Button, Toggle, Slider, Textbox, Dropdown,
              Keybind, ColorPicker (HSV + RGB + Hex), Paragraph, Separator,
              RadioGroup, ProgressBar, ExpandableSection, Notifications,
              Theme Engine (Dark/Light/Ocean/Sunset/Forest), Config Persistence,
              Automatic mobile scaling.
]]

local Flux = {}
Flux.__index = Flux

-- Services & globals
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local isStudio = RunService:IsStudio()
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera.ViewportSize

-- Mobile scale factors
local MOBILE_SCALE = isMobile and 1.4 or 1.0
local MOBILE_PADDING = isMobile and 8 or 4
local isMobile = isMobile  -- for inline checks

-- Config
local configFolder = "FluxUI_Configs"
local configPath = configFolder .. "/data.json"
if writefile and not isfile(configFolder) then makefolder(configFolder) end

-- Utilities
local function tween(obj, props, duration, style, direction)
    local info = TweenInfo.new(duration or 0.2, Enum.EasingStyle[style or "Quad"], Enum.EasingDirection[direction or "Out"])
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function color3ToHex(c)
    return string.format("#%02x%02x%02x", c.R*255, c.G*255, c.B*255)
end

local function hexToColor3(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1,2), 16) or 0
    local g = tonumber(hex:sub(3,4), 16) or 0
    local b = tonumber(hex:sub(5,6), 16) or 0
    return Color3.new(r/255, g/255, b/255)
end

-- HSV <-> RGB conversion
local function rgbToHsv(r, g, b)
    r, g, b = r/255, g/255, b/255
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, v = max, 0, max
    local d = max - min
    s = max == 0 and 0 or d / max
    if max == min then
        h = 0
    else
        if max == r then
            h = (g - b) / d
            if g < b then h = h + 6 end
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h*360, s, v
end

local function hsvToRgb(h, s, v)
    h = (h % 360) / 360
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return Color3.new(r, g, b)
end

-- Deep copy
local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then copy[k] = deepCopy(v) else copy[k] = v end
    end
    return copy
end

-- Dragging
local function makeDraggable(frame, handle)
    local dragData = { dragging = false, dragStart = nil, frameStart = nil }
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragData.dragging = true
            dragData.dragStart = input.Position
            dragData.frameStart = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragData.dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragData.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragData.dragStart
            frame.Position = UDim2.new(dragData.frameStart.X.Scale, dragData.frameStart.X.Offset + delta.X, dragData.frameStart.Y.Scale, dragData.frameStart.Y.Offset + delta.Y)
        end
    end)
    return dragData
end

local function applyHoverEffect(btn, normal, hover)
    if isMobile then return end
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = hover}, 0.1) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = normal}, 0.1) end)
end

local function addRipple(btn)
    local ripple = Instance.new("Frame", btn)
    ripple.Size = UDim2.new(0,0,0,0)
    ripple.Position = UDim2.new(0.5,0,0.5,0)
    ripple.BackgroundColor3 = Color3.new(1,1,1)
    ripple.BackgroundTransparency = 0.7
    local corner = Instance.new("UICorner", ripple)
    corner.CornerRadius = UDim.new(1,0)
    tween(ripple, {Size = UDim2.new(2,0,2,0), BackgroundTransparency = 1}, 0.3, "Quad", "Out")
    task.delay(0.3, function() ripple:Destroy() end)
end

-- THEMES (same as before, omitted for brevity but included in final code)
local themes = {
    Dark = { Primary = Color3.fromRGB(28,28,32), Secondary = Color3.fromRGB(38,38,44), Accent = Color3.fromRGB(0,122,255), Text = Color3.fromRGB(245,245,245), TextDim = Color3.fromRGB(170,170,180), Border = Color3.fromRGB(58,58,66), Positive = Color3.fromRGB(52,199,89), Negative = Color3.fromRGB(255,69,58), Warning = Color3.fromRGB(255,204,0), AcrylicTransparency = 0.85 },
    Light = { Primary = Color3.fromRGB(242,242,247), Secondary = Color3.fromRGB(255,255,255), Accent = Color3.fromRGB(0,122,255), Text = Color3.fromRGB(28,28,30), TextDim = Color3.fromRGB(110,110,120), Border = Color3.fromRGB(200,200,210), Positive = Color3.fromRGB(52,199,89), Negative = Color3.fromRGB(255,69,58), Warning = Color3.fromRGB(255,204,0), AcrylicTransparency = 0.7 },
    Ocean = { Primary = Color3.fromRGB(10,30,50), Secondary = Color3.fromRGB(20,50,80), Accent = Color3.fromRGB(0,180,220), Text = Color3.fromRGB(220,240,255), TextDim = Color3.fromRGB(150,190,220), Border = Color3.fromRGB(40,80,120), Positive = Color3.fromRGB(80,220,100), Negative = Color3.fromRGB(255,80,80), Warning = Color3.fromRGB(255,200,50), AcrylicTransparency = 0.8 },
    Sunset = { Primary = Color3.fromRGB(50,20,40), Secondary = Color3.fromRGB(80,30,60), Accent = Color3.fromRGB(255,140,60), Text = Color3.fromRGB(255,230,210), TextDim = Color3.fromRGB(220,170,150), Border = Color3.fromRGB(120,60,80), Positive = Color3.fromRGB(100,255,100), Negative = Color3.fromRGB(255,70,70), Warning = Color3.fromRGB(255,220,70), AcrylicTransparency = 0.85 },
    Forest = { Primary = Color3.fromRGB(20,40,20), Secondary = Color3.fromRGB(30,60,30), Accent = Color3.fromRGB(100,200,100), Text = Color3.fromRGB(230,250,220), TextDim = Color3.fromRGB(160,200,150), Border = Color3.fromRGB(50,90,50), Positive = Color3.fromRGB(120,255,120), Negative = Color3.fromRGB(255,90,90), Warning = Color3.fromRGB(255,210,80), AcrylicTransparency = 0.85 },
}
local currentThemeName = "Dark"
local theme = deepCopy(themes[currentThemeName])

function Flux:RegisterTheme(name, colorTable) if not themes[name] then themes[name] = colorTable; return true end return false end
function Flux:SetTheme(name) if themes[name] then currentThemeName = name; theme = deepCopy(themes[name]); for _, win in pairs(Flux._activeWindows or {}) do if win._refreshTheme then win:_refreshTheme() end end; Flux:Notify("Theme", "Switched to " .. name, 2, "success"); return true end return false end
function Flux:GetCurrentTheme() return currentThemeName, theme end

-- Config
local config, configListeners = {}, {}
local function saveConfig() if writefile then pcall(function() writefile(configPath, HttpService:JSONEncode(config)) end) end end
local function loadConfig() if isfile(configPath) then local suc, data = pcall(function() return HttpService:JSONDecode(readfile(configPath)) end); if suc and type(data)=="table" then config = data end end end
loadConfig()
function Flux:GetFlag(flag) return config[flag] end
function Flux:SetFlag(flag, value, skipSave) config[flag] = value; if not skipSave then saveConfig() end; if configListeners[flag] then for _, cb in pairs(configListeners[flag]) do pcall(cb, value) end end end
function Flux:OnFlagChange(flag, callback) if not configListeners[flag] then configListeners[flag] = {} end; table.insert(configListeners[flag], callback) end
function Flux:ResetAllFlags() config = {}; saveConfig(); for flag, listeners in pairs(configListeners) do for _, cb in pairs(listeners) do pcall(cb, nil) end end end

-- Notifications (mobile aware)
local notificationContainer, notificationQueue, activeNotifications = nil, {}, 0
local MAX_VISIBLE = isMobile and 2 or 3
local function createNotificationContainer() if notificationContainer then return end; notificationContainer = Instance.new("Frame"); notificationContainer.Name = "FluxUI_Notifications"; notificationContainer.Size = UDim2.new(0, isMobile and 300 or 340, 0, 0); notificationContainer.Position = UDim2.new(1, -20, 0, 10); notificationContainer.AnchorPoint = Vector2.new(1,0); notificationContainer.BackgroundTransparency = 1; notificationContainer.Parent = CoreGui end
local function processNotificationQueue() if activeNotifications >= MAX_VISIBLE then return end; if #notificationQueue == 0 then return end; local next = table.remove(notificationQueue, 1); Flux:Notify(next.heading, next.text, next.duration, next.category) end
function Flux:Notify(heading, text, duration, category)
    if activeNotifications >= MAX_VISIBLE then table.insert(notificationQueue, {heading=heading, text=text, duration=duration, category=category}); return end
    createNotificationContainer()
    local cat = category or "info"
    local color = cat=="success" and theme.Positive or cat=="error" and theme.Negative or cat=="warning" and theme.Warning or theme.Accent
    local notif = Instance.new("Frame")
    local h = isMobile and 80 or 70
    notif.Size = UDim2.new(1,0,0,h)
    notif.Position = UDim2.new(0,0,1,10)
    notif.BackgroundColor3 = theme.Secondary
    notif.BorderSizePixel = 0
    notif.BackgroundTransparency = 0.05
    local corner = Instance.new("UICorner", notif); corner.CornerRadius = UDim.new(0,8)
    local accent = Instance.new("Frame", notif); accent.Size = UDim2.new(0,5,1,0); accent.BackgroundColor3 = color
    local titleLbl = Instance.new("TextLabel", notif); titleLbl.Text = heading; titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = isMobile and 15 or 14; titleLbl.TextColor3 = theme.Text; titleLbl.BackgroundTransparency = 1; titleLbl.Position = UDim2.new(0,16,0,8); titleLbl.Size = UDim2.new(1,-40,0,22); titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    local bodyLbl = Instance.new("TextLabel", notif); bodyLbl.Text = text; bodyLbl.Font = Enum.Font.Gotham; bodyLbl.TextSize = isMobile and 13 or 12; bodyLbl.TextColor3 = theme.TextDim; bodyLbl.BackgroundTransparency = 1; bodyLbl.Position = UDim2.new(0,16,0,32); bodyLbl.Size = UDim2.new(1,-40,0,38); bodyLbl.TextWrapped = true; bodyLbl.TextYAlignment = Enum.TextYAlignment.Top
    local close = Instance.new("TextButton", notif); close.Size = UDim2.new(0,28,0,28); close.Position = UDim2.new(1,-34,0,8); close.Text = "✕"; close.TextColor3 = theme.TextDim; close.BackgroundTransparency = 1; close.Font = Enum.Font.Gotham; close.TextSize = isMobile and 18 or 16; close.AutoButtonColor = false
    close.MouseButton1Click:Connect(function() tween(notif, {Position = UDim2.new(0,0,1,10), BackgroundTransparency = 1}, 0.2):OnComplete(function() notif:Destroy(); activeNotifications = activeNotifications - 1; processNotificationQueue() end) end)
    notif.Parent = notificationContainer
    tween(notif, {Position = UDim2.new(0,0,1,-h-10), BackgroundTransparency = 0}, 0.3)
    activeNotifications = activeNotifications + 1
    if duration and duration > 0 then task.delay(duration, function() if notif.Parent then close.MouseButton1Click:Fire() end end) end
end

-- Window class (mobile-aware)
Flux._activeWindows = {}
local Window = {}
Window.__index = Window

function Flux:CreateWindow(options)
    options = options or {}
    local title = options.Title or "FluxUI"
    local subtitle = options.SubTitle or ""
    local tabWidth = options.TabWidth or (isMobile and 140 or 160)
    local defaultSize = isMobile and UDim2.fromOffset(screenSize.X - 40, screenSize.Y - 80) or UDim2.fromOffset(600, 480)
    local size = options.Size or defaultSize
    local acrylic = options.Acrylic == true
    local resizable = options.Resizable == true and not isMobile
    local horizontalTabs = options.HorizontalTabs == false
    if options.Theme then Flux:SetTheme(options.Theme) end
    if isMobile then size = UDim2.fromOffset(math.min(size.X.Offset, screenSize.X-20), math.min(size.Y.Offset, screenSize.Y-60)) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FluxUI_" .. title:gsub("%s+", "_")
    gui.Parent = CoreGui

    local frame = Instance.new("Frame", gui)
    frame.Size = size
    frame.Position = UDim2.new(0.5, -size.X.Offset/2, 0.5, -size.Y.Offset/2)
    frame.BackgroundColor3 = theme.Primary
    frame.BackgroundTransparency = acrylic and theme.AcrylicTransparency or 0
    frame.BorderSizePixel = 0
    local frameCorner = Instance.new("UICorner", frame); frameCorner.CornerRadius = UDim.new(0,10)
    if acrylic then local blur = Instance.new("Frame", frame); blur.Size = UDim2.new(1,0,1,0); blur.BackgroundColor3 = theme.Primary; blur.BackgroundTransparency = 0.6; blur.BorderSizePixel=0; local blurCorner = Instance.new("UICorner", blur); blurCorner.CornerRadius = UDim.new(0,10); blur.Name = "BlurOverlay" end

    local headerHeight = isMobile and 60 or 50
    local header = Instance.new("Frame", frame); header.Size = UDim2.new(1,0,0,headerHeight); header.BackgroundColor3 = theme.Secondary; header.BackgroundTransparency = acrylic and 0.4 or 0; header.BorderSizePixel=0; local headerCorner = Instance.new("UICorner", header); headerCorner.CornerRadius = UDim.new(0,10)
    local titleLbl = Instance.new("TextLabel", header); titleLbl.Text = title; titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = isMobile and 20 or 18; titleLbl.TextColor3 = theme.Text; titleLbl.BackgroundTransparency=1; titleLbl.Position = UDim2.new(0,14,0,isMobile and 12 or 8); titleLbl.Size = UDim2.new(1,-100,0,26); titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    local subLbl = Instance.new("TextLabel", header); subLbl.Text = subtitle; subLbl.Font = Enum.Font.Gotham; subLbl.TextSize = isMobile and 14 or 12; subLbl.TextColor3 = theme.TextDim; subLbl.BackgroundTransparency=1; subLbl.Position = UDim2.new(0,14,0,isMobile and 38 or 30); subLbl.Size = UDim2.new(1,-100,0,18); subLbl.TextXAlignment = Enum.TextXAlignment.Left
    local closeBtn = Instance.new("TextButton", header); closeBtn.Size = UDim2.new(0,40,0,40); closeBtn.Position = UDim2.new(1,-48,0,isMobile and 10 or 5); closeBtn.Text = "✕"; closeBtn.TextColor3 = theme.TextDim; closeBtn.BackgroundTransparency=1; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = isMobile and 24 or 20; closeBtn.AutoButtonColor=false
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy(); for i,w in pairs(Flux._activeWindows) do if w==windowObj then table.remove(Flux._activeWindows,i) break end end end)
    makeDraggable(frame, header)

    if resizable then
        local resize = Instance.new("Frame", frame); resize.Size = UDim2.new(0,15,0,15); resize.Position = UDim2.new(1,-15,1,-15); resize.BackgroundColor3 = theme.Accent; resize.BackgroundTransparency=0.8; local resizeCorner = Instance.new("UICorner", resize); resizeCorner.CornerRadius = UDim.new(0,3)
        local draggingResize, startSize, startMouse = false
        resize.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then draggingResize=true; startSize=frame.Size; startMouse=inp.Position; inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then draggingResize=false end end) end end)
        UserInputService.InputChanged:Connect(function(inp) if draggingResize and inp.UserInputType == Enum.UserInputType.MouseMovement then local delta = inp.Position - startMouse; frame.Size = UDim2.new(0, math.max(400, startSize.X.Offset+delta.X), 0, math.max(300, startSize.Y.Offset+delta.Y)) end end)
    end

    local tabsContainer, contentContainer
    if horizontalTabs then
        tabsContainer = Instance.new("ScrollingFrame", frame); tabsContainer.Size = UDim2.new(1,0,0,isMobile and 50 or 40); tabsContainer.Position = UDim2.new(0,0,0,headerHeight); tabsContainer.BackgroundTransparency=1; tabsContainer.ScrollBarThickness=0; tabsContainer.CanvasSize = UDim2.new(0,0,0,0)
        local tabLayout = Instance.new("UIListLayout", tabsContainer); tabLayout.FillDirection = Enum.FillDirection.Horizontal; tabLayout.Padding = UDim.new(0, isMobile and 8 or 4)
        contentContainer = Instance.new("ScrollingFrame", frame); contentContainer.Size = UDim2.new(1,0,1,-headerHeight-(isMobile and 50 or 40)-(isMobile and 10 or 0)); contentContainer.Position = UDim2.new(0,0,0,headerHeight+(isMobile and 50 or 40)); contentContainer.BackgroundTransparency=1; contentContainer.ScrollBarThickness = isMobile and 8 or 6
    else
        tabsContainer = Instance.new("ScrollingFrame", frame); tabsContainer.Size = UDim2.new(0, tabWidth, 1, -headerHeight); tabsContainer.Position = UDim2.new(0,0,0,headerHeight); tabsContainer.BackgroundTransparency=1; tabsContainer.ScrollBarThickness = isMobile and 6 or 4; tabsContainer.CanvasSize = UDim2.new(0,0,0,0)
        local tabLayout = Instance.new("UIListLayout", tabsContainer); tabLayout.Padding = UDim.new(0, isMobile and 8 or 6)
        contentContainer = Instance.new("ScrollingFrame", frame); contentContainer.Size = UDim2.new(1, -tabWidth, 1, -headerHeight); contentContainer.Position = UDim2.new(0, tabWidth, 0, headerHeight); contentContainer.BackgroundTransparency=1; contentContainer.ScrollBarThickness = isMobile and 8 or 6
    end
    contentContainer.CanvasSize = UDim2.new(0,0,0,0)
    local contentLayout = Instance.new("UIListLayout", contentContainer); contentLayout.Padding = UDim.new(0, isMobile and 16 or 12)

    local tabs = {}
    local windowObj = { _gui=gui, _frame=frame, _header=header, _tabsContainer=tabsContainer, _contentContainer=contentContainer, _tabs=tabs, _horizontal=horizontalTabs, _acrylic=acrylic, _themeName=currentThemeName }
    function windowObj:_refreshTheme() theme = deepCopy(themes[currentThemeName]); frame.BackgroundColor3 = theme.Primary; if self._acrylic then frame.BackgroundTransparency = theme.AcrylicTransparency; local blur=frame:FindFirstChild("BlurOverlay"); if blur then blur.BackgroundColor3=theme.Primary end end; header.BackgroundColor3=theme.Secondary; titleLbl.TextColor3=theme.Text; subLbl.TextColor3=theme.TextDim; closeBtn.TextColor3=theme.TextDim; for _,tab in pairs(tabs) do tab._button.BackgroundColor3=theme.Secondary; tab._button.TextColor3=theme.Text; for _,sec in pairs(tab._sections or {}) do sec._sectionFrame.BackgroundColor3=theme.Secondary end end end

    function windowObj:AddTab(tabName)
        local btn
        if horizontalTabs then
            btn = Instance.new("TextButton", tabsContainer); btn.Size = UDim2.new(0, isMobile and 120 or 100, 1, -8); btn.BackgroundColor3 = theme.Secondary
        else
            btn = Instance.new("TextButton", tabsContainer); btn.Size = UDim2.new(1, -12, 0, isMobile and 50 or 40); btn.Position = UDim2.new(0,6,0,0); btn.BackgroundColor3 = theme.Secondary
        end
        btn.Text = tabName; btn.TextColor3 = theme.Text; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = isMobile and 15 or 14; btn.AutoButtonColor = false
        local btnCorner = Instance.new("UICorner", btn); btnCorner.CornerRadius = UDim.new(0,6)
        applyHoverEffect(btn, theme.Secondary, theme.Accent)

        local tabContent = Instance.new("Frame", contentContainer); tabContent.Size = UDim2.new(1,-20,0,0); tabContent.BackgroundTransparency=1; tabContent.Visible=false
        local tabLayout = Instance.new("UIListLayout", tabContent); tabLayout.Padding = UDim.new(0, isMobile and 20 or 16)

        local tabObj = { _button=btn, _content=tabContent, _sections={} }
        btn.MouseButton1Click:Connect(function()
            for _,t in pairs(tabs) do t._button.BackgroundColor3=theme.Secondary; t._content.Visible=false end
            btn.BackgroundColor3=theme.Accent; tabContent.Visible=true
            task.defer(function() local total=0; for _,ch in pairs(tabContent:GetChildren()) do if ch:IsA("Frame") then total=total+ch.Size.Y.Offset+(isMobile and 20 or 16) end end; tabContent.Size=UDim2.new(1,-20,0,total); contentContainer.CanvasSize=UDim2.new(0,0,0,total+20) end)
        end)
        table.insert(tabs, tabObj); if #tabs==1 then btn.MouseButton1Click:Fire() end
        if horizontalTabs then tabsContainer.CanvasSize = UDim2.new(0, #tabs*(isMobile and 128 or 108), 0,0) else tabsContainer.CanvasSize = UDim2.new(0,0,0, #tabs*(isMobile and 58 or 46)+10) end

        function tabObj:AddSection(sectionTitle, expandable)
            local sectionFrame = Instance.new("Frame", tabContent); sectionFrame.Size = UDim2.new(1,0,0,0); sectionFrame.BackgroundColor3 = theme.Secondary; sectionFrame.BackgroundTransparency = windowObj._acrylic and 0.4 or 0; sectionFrame.BorderSizePixel=0
            local sectionCorner = Instance.new("UICorner", sectionFrame); sectionCorner.CornerRadius = UDim.new(0,8)
            local headerFrame = Instance.new("Frame", sectionFrame); headerFrame.Size = UDim2.new(1,0,0,isMobile and 54 or 44); headerFrame.BackgroundTransparency=1
            local titleLbl = Instance.new("TextLabel", headerFrame); titleLbl.Text = sectionTitle; titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = isMobile and 18 or 16; titleLbl.TextColor3 = theme.Text; titleLbl.BackgroundTransparency=1; titleLbl.Position = UDim2.new(0,12,0,isMobile and 12 or 10); titleLbl.Size = UDim2.new(1,-50,0,28); titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            local line = Instance.new("Frame", headerFrame); line.Size = UDim2.new(1,-24,0,1); line.Position = UDim2.new(0,12,0,isMobile and 46 or 38); line.BackgroundColor3 = theme.Border
            local elementsContainer = Instance.new("Frame", sectionFrame); elementsContainer.Size = UDim2.new(1,0,0,0); elementsContainer.Position = UDim2.new(0,0,0,isMobile and 54 or 44); elementsContainer.BackgroundTransparency=1
            local elementsLayout = Instance.new("UIListLayout", elementsContainer); elementsLayout.Padding = UDim.new(0, isMobile and 12 or 8)
            local expandBtn = nil
            if expandable then
                expandBtn = Instance.new("TextButton", headerFrame); expandBtn.Size = UDim2.new(0,36,0,36); expandBtn.Position = UDim2.new(1,-44,0,isMobile and 9 or 4); expandBtn.Text = "▼"; expandBtn.TextColor3 = theme.TextDim; expandBtn.BackgroundTransparency=1; expandBtn.Font=Enum.Font.Gotham; expandBtn.TextSize=isMobile and 22 or 18; expandBtn.AutoButtonColor=false
                local expanded = true
                expandBtn.MouseButton1Click:Connect(function() expanded = not expanded; expandBtn.Text = expanded and "▼" or "▶"; elementsContainer.Visible = expanded; tween(elementsContainer, {Size = UDim2.new(1,0,0, expanded and elementsContainer.Size.Y.Offset or 0)}, 0.2); task.wait(0.25); refreshHeight() end)
            end
            local sectionObj = { _container=elementsContainer, _sectionFrame=sectionFrame, _expandBtn=expandBtn }
            local function refreshHeight()
                local total=0; for _,ch in pairs(elementsContainer:GetChildren()) do if ch:IsA("Frame") or ch:IsA("TextButton") then total=total+ch.Size.Y.Offset+(isMobile and 12 or 8) end end
                elementsContainer.Size = UDim2.new(1,0,0,total)
                sectionFrame.Size = UDim2.new(1,0,0, (isMobile and 54 or 44) + total + (isMobile and 16 or 12))
                task.defer(function() local tabTotal=0; for _,ch in pairs(tabContent:GetChildren()) do if ch:IsA("Frame") then tabTotal=tabTotal+ch.Size.Y.Offset+(isMobile and 20 or 16) end end; tabContent.Size=UDim2.new(1,-20,0,tabTotal); contentContainer.CanvasSize=UDim2.new(0,0,0,tabTotal+20) end)
            end
            local function addElement(elem, height) elem.Parent = elementsContainer; elem.Size = UDim2.new(1,-24,0,height); elem.Position = UDim2.new(0,12,0,0); refreshHeight(); return elem end

            -- Button
            function sectionObj:AddButton(text, callback)
                local btn = Instance.new("TextButton"); btn.Text = text; btn.Font = Enum.Font.Gotham; btn.TextSize = isMobile and 16 or 14; btn.TextColor3 = theme.Text; btn.BackgroundColor3 = theme.Primary; btn.BackgroundTransparency = windowObj._acrylic and 0.5 or 0; btn.AutoButtonColor = false
                local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,6)
                applyHoverEffect(btn, theme.Primary, theme.Accent)
                btn.MouseButton1Click:Connect(function() addRipple(btn); if callback then pcall(callback) end end)
                addElement(btn, isMobile and 50 or 36)
                return btn
            end

            -- Toggle
            function sectionObj:AddToggle(text, flag, default, callback)
                local f = Instance.new("Frame"); f.BackgroundTransparency=1
                local label = Instance.new("TextLabel", f); label.Text = text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 16 or 14; label.TextColor3=theme.Text; label.BackgroundTransparency=1; label.Size=UDim2.new(1,-90,1,0); label.TextXAlignment=Enum.TextXAlignment.Left
                local trackW = isMobile and 56 or 44; local trackH = isMobile and 30 or 24
                local track = Instance.new("Frame", f); track.Size = UDim2.new(0,trackW,0,trackH); track.Position = UDim2.new(1,-trackW-10,0.5,-trackH/2); track.BackgroundColor3=theme.Border; track.BorderSizePixel=0
                local trackCorner = Instance.new("UICorner", track); trackCorner.CornerRadius = UDim.new(1,0)
                local knobSize = isMobile and 26 or 20
                local knob = Instance.new("Frame", track); knob.Size = UDim2.new(0,knobSize,0,knobSize); knob.Position = UDim2.new(0,2,0,(trackH-knobSize)/2); knob.BackgroundColor3=theme.Text; knob.BorderSizePixel=0
                local knobCorner = Instance.new("UICorner", knob); knobCorner.CornerRadius = UDim.new(1,0)
                local state = (config[flag]~=nil and config[flag]) or (default or false)
                local function setState(v) state=v; local targetX = state and (trackW-knobSize-2) or 2; tween(knob, {Position=UDim2.new(0,targetX,0,(trackH-knobSize)/2)}, 0.15); track.BackgroundColor3 = state and theme.Accent or theme.Border; if callback then pcall(callback,state) end; Flux:SetFlag(flag,state) end
                f.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then setState(not state); addRipple(f) end end)
                setState(state); addElement(f, isMobile and 56 or 36); return {Set=setState, Get=function() return state end}
            end

            -- Slider (simplified but mobile-friendly)
            function sectionObj:AddSlider(text, flag, minVal, maxVal, default, step, callback)
                local f = Instance.new("Frame"); f.BackgroundTransparency=1
                local label = Instance.new("TextLabel", f); label.Text = text..": "..tostring(default); label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24); label.BackgroundTransparency=1; label.TextXAlignment=Enum.TextXAlignment.Left
                local track = Instance.new("Frame", f); track.Size = UDim2.new(1,-24,0,isMobile and 8 or 4); track.Position = UDim2.new(0,12,0,isMobile and 40 or 30); track.BackgroundColor3=theme.Border; track.BorderSizePixel=0
                local fill = Instance.new("Frame", track); fill.Size = UDim2.new(0,0,1,0); fill.BackgroundColor3=theme.Accent; fill.BorderSizePixel=0
                local knobSize = isMobile and 24 or 14
                local knob = Instance.new("Frame", track); knob.Size = UDim2.new(0,knobSize,0,knobSize); knob.Position = UDim2.new(0,-knobSize/2,0,-(knobSize-track.Size.Y.Offset)/2); knob.BackgroundColor3=theme.Text; knob.BorderSizePixel=0; local knobCorner = Instance.new("UICorner", knob); knobCorner.CornerRadius = UDim.new(1,0)
                local value = (config[flag]~=nil and config[flag]) or (default or minVal)
                local function update(v) v=math.clamp(v,minVal,maxVal); if step then v=math.floor(v/step+0.5)*step end; value=v; local pct=(value-minVal)/(maxVal-minVal); fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,-knobSize/2,0,-(knobSize-track.Size.Y.Offset)/2); label.Text=text..": "..tostring(value); if callback then pcall(callback,value) end; Flux:SetFlag(flag,value) end
                local dragging=false
                knob.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=true end end)
                UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
                UserInputService.InputChanged:Connect(function(inp) if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then local pos=inp.Position.X-track.AbsolutePosition.X; local pct=math.clamp(pos/track.AbsoluteSize.X,0,1); local v=minVal+(maxVal-minVal)*pct; if step then v=math.floor(v/step+0.5)*step end; update(v) end end)
                update(value); addElement(f, isMobile and 70 or 48); return {Set=update, Get=function() return value end}
            end

            -- Textbox
            function sectionObj:AddTextbox(text, flag, placeholder, callback)
                local f = Instance.new("Frame"); f.BackgroundTransparency=1
                local label = Instance.new("TextLabel", f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24); label.TextXAlignment=Enum.TextXAlignment.Left
                local box = Instance.new("TextBox", f); box.Size = UDim2.new(1,-24,0,isMobile and 40 or 30); box.Position = UDim2.new(0,12,0,isMobile and 30 or 24); box.BackgroundColor3=theme.Primary; box.TextColor3=theme.Text; box.Font=Enum.Font.Gotham; box.TextSize=isMobile and 16 or 14; box.PlaceholderText=placeholder or ""; box.Text=config[flag] or ""; box.ClearTextOnFocus=false
                local corner = Instance.new("UICorner", box); corner.CornerRadius=UDim.new(0,6)
                box.FocusLost:Connect(function() local val=box.Text; Flux:SetFlag(flag,val); if callback then pcall(callback,val) end end)
                addElement(f, isMobile and 80 or 60); return {Set=function(t) box.Text=t; Flux:SetFlag(flag,t) end, Get=function() return box.Text end}
            end

            -- Dropdown
            function sectionObj:AddDropdown(text, flag, options, default, callback)
                local f = Instance.new("Frame"); f.BackgroundTransparency=1
                local label = Instance.new("TextLabel", f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24)
                local select = Instance.new("TextButton", f); select.Size = UDim2.new(1,-24,0,isMobile and 44 or 32); select.Position = UDim2.new(0,12,0,isMobile and 30 or 24); select.BackgroundColor3=theme.Primary; select.Text=default or options[1] or ""; select.TextColor3=theme.Text; select.Font=Enum.Font.Gotham; select.TextSize=isMobile and 16 or 14; select.AutoButtonColor=false
                local btnCorner = Instance.new("UICorner", select); btnCorner.CornerRadius=UDim.new(0,6)
                local open=false; local dropFrame=nil
                select.MouseButton1Click:Connect(function()
                    if open then dropFrame:Destroy(); open=false; return end
                    dropFrame = Instance.new("ScrollingFrame", f); local dropH=math.min(150, #options*(isMobile and 48 or 32)+10); dropFrame.Size=UDim2.new(1,-24,0,dropH); dropFrame.Position=UDim2.new(0,12,0,isMobile and 80 or 60); dropFrame.BackgroundColor3=theme.Secondary; dropFrame.ScrollBarThickness=isMobile and 8 or 4; local dropCorner=Instance.new("UICorner", dropFrame); dropCorner.CornerRadius=UDim.new(0,6)
                    local layout = Instance.new("UIListLayout", dropFrame); layout.Padding=UDim.new(0,isMobile and 4 or 2)
                    for _,opt in ipairs(options) do
                        local optBtn = Instance.new("TextButton", dropFrame); optBtn.Size=UDim2.new(1,-8,0,isMobile and 44 or 30); optBtn.Position=UDim2.new(0,4,0,0); optBtn.Text=opt; optBtn.TextColor3=theme.Text; optBtn.BackgroundColor3=theme.Primary; optBtn.Font=Enum.Font.Gotham; optBtn.TextSize=isMobile and 15 or 13; optBtn.AutoButtonColor=false
                        local optCorner = Instance.new("UICorner", optBtn); optCorner.CornerRadius=UDim.new(0,4)
                        optBtn.MouseButton1Click:Connect(function() select.Text=opt; Flux:SetFlag(flag,opt); if callback then pcall(callback,opt) end; dropFrame:Destroy(); open=false end)
                        applyHoverEffect(optBtn, theme.Primary, theme.Accent)
                    end
                    dropFrame.CanvasSize = UDim2.new(0,0,0, #options*(isMobile and 48 or 32)); open=true
                end)
                addElement(f, isMobile and 110 or 90); return {Set=function(opt) select.Text=opt; Flux:SetFlag(flag,opt) end, Get=function() return select.Text end}
            end

            -- Keybind
            function sectionObj:AddKeybind(text, flag, defaultKey, callback)
                local f = Instance.new("Frame"); f.BackgroundTransparency=1
                local label = Instance.new("TextLabel", f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,-140,0,24)
                local keyBtn = Instance.new("TextButton", f); keyBtn.Size=UDim2.new(0,isMobile and 100 or 80,0,isMobile and 40 or 32); keyBtn.Position=UDim2.new(1,-isMobile and 110 or 90,0,isMobile and 16 or 20); keyBtn.BackgroundColor3=theme.Primary; keyBtn.Text=config[flag] or defaultKey or "None"; keyBtn.TextColor3=theme.Text; keyBtn.Font=Enum.Font.GothamBold; keyBtn.TextSize=isMobile and 15 or 14; keyBtn.AutoButtonColor=false
                local btnCorner=Instance.new("UICorner", keyBtn); btnCorner.CornerRadius=UDim.new(0,6)
                local listening=false; local current=keyBtn.Text
                keyBtn.MouseButton1Click:Connect(function()
                    if listening then listening=false; keyBtn.Text=current; return end
                    listening=true; keyBtn.Text="..."
                    local conn; conn=UserInputService.InputBegan:Connect(function(inp,gp) if gp then return end; if inp.UserInputType==Enum.UserInputType.Keyboard then local k=inp.KeyCode.Name; listening=false; keyBtn.Text=k; current=k; Flux:SetFlag(flag,k); if callback then pcall(callback,k) end; conn:Disconnect() end end)
                    task.delay(5,function() if listening then listening=false; keyBtn.Text=current; if conn then conn:Disconnect() end end end)
                end)
                addElement(f, isMobile and 80 or 60); return {Set=function(k) current=k; keyBtn.Text=k; Flux:SetFlag(flag,k) end, Get=function() return current end}
            end

            -- ========== ENHANCED COLOR PICKER (FluentUI style) ==========
            function sectionObj:AddColorPicker(text, flag, defaultColor, callback)
                defaultColor = defaultColor or Color3.new(1,0,0)
                local frameColor = Instance.new("Frame")
                frameColor.BackgroundTransparency = 1

                -- Label
                local label = Instance.new("TextLabel", frameColor)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = isMobile and 14 or 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, -80, 0, 24)
                label.BackgroundTransparency = 1

                -- Preview box
                local preview = Instance.new("Frame", frameColor)
                preview.Size = UDim2.new(0, isMobile and 50 or 40, 0, isMobile and 38 or 30)
                preview.Position = UDim2.new(1, -isMobile and 60 or 50, 0, isMobile and 16 or 16)
                preview.BackgroundColor3 = defaultColor
                preview.BorderSizePixel = 0
                local previewCorner = Instance.new("UICorner", preview)
                previewCorner.CornerRadius = UDim.new(0, 6)

                -- Open picker button
                local pickerBtn = Instance.new("TextButton", frameColor)
                pickerBtn.Size = UDim2.new(0, isMobile and 70 or 60, 0, isMobile and 38 or 30)
                pickerBtn.Position = UDim2.new(1, -isMobile and 130 or 120, 0, isMobile and 16 or 16)
                pickerBtn.Text = "Pick"
                pickerBtn.BackgroundColor3 = theme.Accent
                pickerBtn.TextColor3 = theme.Text
                pickerBtn.Font = Enum.Font.Gotham
                pickerBtn.TextSize = isMobile and 15 or 13
                pickerBtn.AutoButtonColor = false
                local btnCorner = Instance.new("UICorner", pickerBtn)
                btnCorner.CornerRadius = UDim.new(0, 6)

                local currentColor = defaultColor
                local hsv = {rgbToHsv(currentColor.R*255, currentColor.G*255, currentColor.B*255)}
                local hue = hsv[1] or 0
                local sat = hsv[2] or 0.5
                local val = hsv[3] or 1

                local pickerOpen = false
                local pickerFrame = nil

                -- Function to update everything
                local function updateColorFromHSV(h, s, v)
                    hue = h % 360
                    sat = math.clamp(s, 0, 1)
                    val = math.clamp(v, 0, 1)
                    local newColor = hsvToRgb(hue, sat, val)
                    currentColor = newColor
                    preview.BackgroundColor3 = currentColor
                    Flux:SetFlag(flag, currentColor)
                    if callback then pcall(callback, currentColor) end
                    -- Update picker UI if open
                    if pickerOpen and pickerFrame then
                        local hexBox = pickerFrame:FindFirstChild("HexBox")
                        if hexBox then hexBox.Text = color3ToHex(currentColor) end
                        local rBox = pickerFrame:FindFirstChild("RBox")
                        local gBox, bBox, hBox, sBox, vBox
                        if rBox then
                            rBox.Text = tostring(math.floor(currentColor.R*255))
                            gBox = pickerFrame:FindFirstChild("GBox")
                            bBox = pickerFrame:FindFirstChild("BBox")
                            if gBox then gBox.Text = tostring(math.floor(currentColor.G*255)) end
                            if bBox then bBox.Text = tostring(math.floor(currentColor.B*255)) end
                        end
                        hBox = pickerFrame:FindFirstChild("HBox")
                        sBox = pickerFrame:FindFirstChild("SBox")
                        vBox = pickerFrame:FindFirstChild("VBox")
                        if hBox then hBox.Text = tostring(math.floor(hue)) end
                        if sBox then sBox.Text = string.format("%.2f", sat) end
                        if vBox then vBox.Text = string.format("%.2f", val) end
                        -- Update hue slider fill
                        local hueFill = pickerFrame:FindFirstChild("HueFill")
                        if hueFill then hueFill.Size = UDim2.new(hue/360,0,1,0) end
                        -- Update SV picker position
                        local svKnob = pickerFrame:FindFirstChild("SVKnob")
                        if svKnob then
                            svKnob.Position = UDim2.new(sat, -6, 1-val, -6)
                        end
                    end
                end

                pickerBtn.MouseButton1Click:Connect(function()
                    if pickerOpen then
                        pickerFrame:Destroy()
                        pickerOpen = false
                        return
                    end

                    pickerFrame = Instance.new("Frame", frameColor)
                    pickerFrame.Size = UDim2.new(0, isMobile and 320 or 280, 0, isMobile and 320 or 280)
                    pickerFrame.Position = UDim2.new(1, -isMobile and 330 or 290, 0, isMobile and 80 or 60)
                    pickerFrame.BackgroundColor3 = theme.Secondary
                    pickerFrame.BorderSizePixel = 0
                    local pickerCorner = Instance.new("UICorner", pickerFrame)
                    pickerCorner.CornerRadius = UDim.new(0, 8)

                    -- Hue slider (vertical or horizontal? We'll use horizontal for simplicity)
                    local hueTrack = Instance.new("Frame", pickerFrame)
                    hueTrack.Size = UDim2.new(0.8, 0, 0, isMobile and 20 or 16)
                    hueTrack.Position = UDim2.new(0.1, 0, 0.75, 0)
                    hueTrack.BackgroundColor3 = Color3.new(1,1,1)
                    hueTrack.BorderSizePixel = 0
                    -- Gradient for hue (rainbow)
                    local hueGradient = Instance.new("UIGradient", hueTrack)
                    hueGradient.Rotation = 0
                    -- We'll simulate by using a ColorSequence
                    local colors = {}
                    for i=0,1,0.05 do
                        table.insert(colors, ColorSequenceKeypoint.new(i, hsvToRgb(i*360,1,1)))
                    end
                    hueGradient.Color = ColorSequence.new(colors)
                    local hueCorner = Instance.new("UICorner", hueTrack)
                    hueCorner.CornerRadius = UDim.new(1,0)
                    local hueFill = Instance.new("Frame", hueTrack)
                    hueFill.Size = UDim2.new(hue/360,0,1,0)
                    hueFill.BackgroundColor3 = Color3.new(1,1,1)
                    hueFill.BackgroundTransparency = 0.5
                    hueFill.BorderSizePixel = 0
                    local hueKnob = Instance.new("Frame", hueTrack)
                    local knobSizeH = isMobile and 12 or 8
                    hueKnob.Size = UDim2.new(0, knobSizeH*2, 0, knobSizeH*2)
                    hueKnob.Position = UDim2.new(hue/360, -knobSizeH, -knobSizeH/2, 0)
                    hueKnob.BackgroundColor3 = Color3.new(1,1,1)
                    local hueKnobCorner = Instance.new("UICorner", hueKnob)
                    hueKnobCorner.CornerRadius = UDim.new(1,0)

                    -- Saturation/Value square
                    local svFrame = Instance.new("Frame", pickerFrame)
                    svFrame.Size = UDim2.new(0.8, 0, 0.6, 0)
                    svFrame.Position = UDim2.new(0.1, 0, 0.08, 0)
                    svFrame.BackgroundColor3 = hsvToRgb(hue, 1, 1)
                    svFrame.BorderSizePixel = 0
                    local svCorner = Instance.new("UICorner", svFrame)
                    svCorner.CornerRadius = UDim.new(0, 6)

                    -- Gradient overlay: left-to-right white->transparent, bottom-to-top transparent->black
                    local satGradient = Instance.new("UIGradient", svFrame)
                    satGradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                        ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
                    })
                    satGradient.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1)
                    })
                    satGradient.Rotation = 0
                    local valGradient = Instance.new("UIGradient", svFrame)
                    valGradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
                        ColorSequenceKeypoint.new(1, Color3.new(0,0,0))
                    })
                    valGradient.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0)
                    })
                    valGradient.Rotation = 90

                    local svKnob = Instance.new("Frame", svFrame)
                    svKnob.Size = UDim2.new(0, 12, 0, 12)
                    svKnob.Position = UDim2.new(sat, -6, 1-val, -6)
                    svKnob.BackgroundColor3 = Color3.new(1,1,1)
                    svKnob.BorderSizePixel = 0
                    local svKnobCorner = Instance.new("UICorner", svKnob)
                    svKnobCorner.CornerRadius = UDim.new(1,0)

                    -- Hex input
                    local hexBox = Instance.new("TextBox", pickerFrame)
                    hexBox.Name = "HexBox"
                    hexBox.Size = UDim2.new(0.35, 0, 0, isMobile and 36 or 30)
                    hexBox.Position = UDim2.new(0.1, 0, 0.85, 0)
                    hexBox.Text = color3ToHex(currentColor)
                    hexBox.BackgroundColor3 = theme.Primary
                    hexBox.TextColor3 = theme.Text
                    hexBox.Font = Enum.Font.Gotham
                    hexBox.TextSize = isMobile and 14 or 12
                    local hexCorner = Instance.new("UICorner", hexBox)
                    hexCorner.CornerRadius = UDim.new(0, 4)

                    -- RGB sliders (optional, but can add numeric readouts)
                    local rLabel = Instance.new("TextLabel", pickerFrame)
                    rLabel.Text = "R:"
                    rLabel.Size = UDim2.new(0.1, 0, 0, isMobile and 24 or 20)
                    rLabel.Position = UDim2.new(0.1, 0, 0.86, isMobile and 40 or 30)
                    rLabel.TextColor3 = theme.TextDim
                    rLabel.Font = Enum.Font.Gotham
                    rLabel.TextSize = isMobile and 12 or 10
                    rLabel.BackgroundTransparency = 1
                    local rBox = Instance.new("TextBox", pickerFrame)
                    rBox.Name = "RBox"
                    rBox.Size = UDim2.new(0.15, 0, 0, isMobile and 30 or 24)
                    rBox.Position = UDim2.new(0.2, 0, 0.86, isMobile and 40 or 30)
                    rBox.Text = tostring(math.floor(currentColor.R*255))
                    rBox.BackgroundColor3 = theme.Primary
                    rBox.TextColor3 = theme.Text
                    rBox.Font = Enum.Font.Gotham
                    rBox.TextSize = isMobile and 14 or 12
                    local rCorner = Instance.new("UICorner", rBox)
                    rCorner.CornerRadius = UDim.new(0, 4)

                    local gLabel = Instance.new("TextLabel", pickerFrame)
                    gLabel.Text = "G:"
                    gLabel.Size = UDim2.new(0.1, 0, 0, isMobile and 24 or 20)
                    gLabel.Position = UDim2.new(0.4, 0, 0.86, isMobile and 40 or 30)
                    gLabel.TextColor3 = theme.TextDim
                    gLabel.Font = Enum.Font.Gotham
                    gLabel.TextSize = isMobile and 12 or 10
                    gLabel.BackgroundTransparency = 1
                    local gBox = Instance.new("TextBox", pickerFrame)
                    gBox.Name = "GBox"
                    gBox.Size = UDim2.new(0.15, 0, 0, isMobile and 30 or 24)
                    gBox.Position = UDim2.new(0.5, 0, 0.86, isMobile and 40 or 30)
                    gBox.Text = tostring(math.floor(currentColor.G*255))
                    gBox.BackgroundColor3 = theme.Primary
                    gBox.TextColor3 = theme.Text
                    gBox.Font = Enum.Font.Gotham
                    gBox.TextSize = isMobile and 14 or 12
                    local gCorner = Instance.new("UICorner", gBox)
                    gCorner.CornerRadius = UDim.new(0, 4)

                    local bLabel = Instance.new("TextLabel", pickerFrame)
                    bLabel.Text = "B:"
                    bLabel.Size = UDim2.new(0.1, 0, 0, isMobile and 24 or 20)
                    bLabel.Position = UDim2.new(0.7, 0, 0.86, isMobile and 40 or 30)
                    bLabel.TextColor3 = theme.TextDim
                    bLabel.Font = Enum.Font.Gotham
                    bLabel.TextSize = isMobile and 12 or 10
                    bLabel.BackgroundTransparency = 1
                    local bBox = Instance.new("TextBox", pickerFrame)
                    bBox.Name = "BBox"
                    bBox.Size = UDim2.new(0.15, 0, 0, isMobile and 30 or 24)
                    bBox.Position = UDim2.new(0.8, 0, 0.86, isMobile and 40 or 30)
                    bBox.Text = tostring(math.floor(currentColor.B*255))
                    bBox.BackgroundColor3 = theme.Primary
                    bBox.TextColor3 = theme.Text
                    bBox.Font = Enum.Font.Gotham
                    bBox.TextSize = isMobile and 14 or 12
                    local bCorner = Instance.new("UICorner", bBox)
                    bCorner.CornerRadius = UDim.new(0, 4)

                    -- HSV readouts (optional)
                    local hLabel = Instance.new("TextLabel", pickerFrame)
                    hLabel.Text = "H:"
                    hLabel.Size = UDim2.new(0.1, 0, 0, isMobile and 20 or 16)
                    hLabel.Position = UDim2.new(0.1, 0, 0.92, 0)
                    hLabel.TextColor3 = theme.TextDim
                    hLabel.Font = Enum.Font.Gotham
                    hLabel.TextSize = isMobile and 10 or 8
                    hLabel.BackgroundTransparency = 1
                    local hBox = Instance.new("TextBox", pickerFrame)
                    hBox.Name = "HBox"
                    hBox.Size = UDim2.new(0.2, 0, 0, isMobile and 24 or 20)
                    hBox.Position = UDim2.new(0.2, 0, 0.92, 0)
                    hBox.Text = tostring(math.floor(hue))
                    hBox.BackgroundColor3 = theme.Primary
                    hBox.TextColor3 = theme.Text
                    hBox.Font = Enum.Font.Gotham
                    hBox.TextSize = isMobile and 12 or 10

                    local sLabel = Instance.new("TextLabel", pickerFrame)
                    sLabel.Text = "S:"
                    sLabel.Size = UDim2.new(0.1, 0, 0, isMobile and 20 or 16)
                    sLabel.Position = UDim2.new(0.45, 0, 0.92, 0)
                    sLabel.TextColor3 = theme.TextDim
                    sLabel.Font = Enum.Font.Gotham
                    sLabel.TextSize = isMobile and 10 or 8
                    sLabel.BackgroundTransparency = 1
                    local sBox = Instance.new("TextBox", pickerFrame)
                    sBox.Name = "SBox"
                    sBox.Size = UDim2.new(0.2, 0, 0, isMobile and 24 or 20)
                    sBox.Position = UDim2.new(0.55, 0, 0.92, 0)
                    sBox.Text = string.format("%.2f", sat)
                    sBox.BackgroundColor3 = theme.Primary
                    sBox.TextColor3 = theme.Text
                    sBox.Font = Enum.Font.Gotham
                    sBox.TextSize = isMobile and 12 or 10

                    local vLabel = Instance.new("TextLabel", pickerFrame)
                    vLabel.Text = "V:"
                    vLabel.Size = UDim2.new(0.1, 0, 0, isMobile and 20 or 16)
                    vLabel.Position = UDim2.new(0.8, 0, 0.92, 0)
                    vLabel.TextColor3 = theme.TextDim
                    vLabel.Font = Enum.Font.Gotham
                    vLabel.TextSize = isMobile and 10 or 8
                    vLabel.BackgroundTransparency = 1
                    local vBox = Instance.new("TextBox", pickerFrame)
                    vBox.Name = "VBox"
                    vBox.Size = UDim2.new(0.15, 0, 0, isMobile and 24 or 20)
                    vBox.Position = UDim2.new(0.9, 0, 0.92, 0)
                    vBox.Text = string.format("%.2f", val)
                    vBox.BackgroundColor3 = theme.Primary
                    vBox.TextColor3 = theme.Text
                    vBox.Font = Enum.Font.Gotham
                    vBox.TextSize = isMobile and 12 or 10

                    -- Apply button
                    local applyBtn = Instance.new("TextButton", pickerFrame)
                    applyBtn.Size = UDim2.new(0.25, 0, 0, isMobile and 36 or 30)
                    applyBtn.Position = UDim2.new(0.7, 0, 0.94, 0)
                    applyBtn.Text = "Apply"
                    applyBtn.BackgroundColor3 = theme.Accent
                    applyBtn.TextColor3 = theme.Text
                    applyBtn.Font = Enum.Font.Gotham
                    applyBtn.TextSize = isMobile and 14 or 12
                    local applyCorner = Instance.new("UICorner", applyBtn)
                    applyCorner.CornerRadius = UDim.new(0, 6)

                    -- Interaction: hue slider
                    local draggingHue = false
                    hueTrack.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                            draggingHue = true
                            local pos = math.clamp((inp.Position.X - hueTrack.AbsolutePosition.X) / hueTrack.AbsoluteSize.X, 0, 1)
                            local newHue = pos * 360
                            updateColorFromHSV(newHue, sat, val)
                            svFrame.BackgroundColor3 = hsvToRgb(newHue, 1, 1)
                            hueKnob.Position = UDim2.new(pos, -knobSizeH, -knobSizeH/2, 0)
                        end
                    end)
                    UserInputService.InputChanged:Connect(function(inp)
                        if draggingHue and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                            local pos = math.clamp((inp.Position.X - hueTrack.AbsolutePosition.X) / hueTrack.AbsoluteSize.X, 0, 1)
                            local newHue = pos * 360
                            updateColorFromHSV(newHue, sat, val)
                            svFrame.BackgroundColor3 = hsvToRgb(newHue, 1, 1)
                            hueKnob.Position = UDim2.new(pos, -knobSizeH, -knobSizeH/2, 0)
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(inp)
                        if draggingHue then draggingHue = false end
                    end)

                    -- Interaction: SV square
                    local draggingSV = false
                    svFrame.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                            draggingSV = true
                            local x = math.clamp((inp.Position.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
                            local y = math.clamp((inp.Position.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
                            local newSat = x
                            local newVal = 1 - y
                            updateColorFromHSV(hue, newSat, newVal)
                            svKnob.Position = UDim2.new(newSat, -6, 1-newVal, -6)
                        end
                    end)
                    UserInputService.InputChanged:Connect(function(inp)
                        if draggingSV and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                            local x = math.clamp((inp.Position.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
                            local y = math.clamp((inp.Position.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
                            local newSat = x
                            local newVal = 1 - y
                            updateColorFromHSV(hue, newSat, newVal)
                            svKnob.Position = UDim2.new(newSat, -6, 1-newVal, -6)
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(inp)
                        if draggingSV then draggingSV = false end
                    end)

                    -- Manual input handlers
                    hexBox.FocusLost:Connect(function()
                        local newColor = hexToColor3(hexBox.Text)
                        local r,g,b = newColor.R*255, newColor.G*255, newColor.B*255
                        local h2,s2,v2 = rgbToHsv(r,g,b)
                        updateColorFromHSV(h2, s2, v2)
                        svFrame.BackgroundColor3 = hsvToRgb(h2, 1, 1)
                        hueKnob.Position = UDim2.new(h2/360, -knobSizeH, -knobSizeH/2, 0)
                        svKnob.Position = UDim2.new(s2, -6, 1-v2, -6)
                    end)

                    local function updateFromRGB()
                        local r = tonumber(rBox.Text) or 0
                        local g = tonumber(gBox.Text) or 0
                        local b = tonumber(bBox.Text) or 0
                        r = math.clamp(r, 0, 255)
                        g = math.clamp(g, 0, 255)
                        b = math.clamp(b, 0, 255)
                        local h2,s2,v2 = rgbToHsv(r,g,b)
                        updateColorFromHSV(h2, s2, v2)
                        svFrame.BackgroundColor3 = hsvToRgb(h2, 1, 1)
                        hueKnob.Position = UDim2.new(h2/360, -knobSizeH, -knobSizeH/2, 0)
                        svKnob.Position = UDim2.new(s2, -6, 1-v2, -6)
                        hexBox.Text = color3ToHex(hsvToRgb(h2,s2,v2))
                    end
                    rBox.FocusLost:Connect(updateFromRGB)
                    gBox.FocusLost:Connect(updateFromRGB)
                    bBox.FocusLost:Connect(updateFromRGB)

                    local function updateFromHSV()
                        local h = tonumber(hBox.Text) or 0
                        local s = tonumber(sBox.Text) or 0.5
                        local v = tonumber(vBox.Text) or 1
                        updateColorFromHSV(h, s, v)
                        svFrame.BackgroundColor3 = hsvToRgb(h, 1, 1)
                        hueKnob.Position = UDim2.new(h/360, -knobSizeH, -knobSizeH/2, 0)
                        svKnob.Position = UDim2.new(s, -6, 1-v, -6)
                        hexBox.Text = color3ToHex(currentColor)
                        rBox.Text = tostring(math.floor(currentColor.R*255))
                        gBox.Text = tostring(math.floor(currentColor.G*255))
                        bBox.Text = tostring(math.floor(currentColor.B*255))
                    end
                    hBox.FocusLost:Connect(updateFromHSV)
                    sBox.FocusLost:Connect(updateFromHSV)
                    vBox.FocusLost:Connect(updateFromHSV)

                    applyBtn.MouseButton1Click:Connect(function()
                        pickerFrame:Destroy()
                        pickerOpen = false
                    end)

                    pickerOpen = true
                end)

                addElement(frameColor, isMobile and 80 or 60)
                return {
                    Set = function(c)
                        currentColor = c
                        preview.BackgroundColor3 = c
                        Flux:SetFlag(flag, c)
                        local r,g,b = c.R*255, c.G*255, c.B*255
                        local h2,s2,v2 = rgbToHsv(r,g,b)
                        hue = h2; sat = s2; val = v2
                    end,
                    Get = function() return currentColor end
                }
            end

            -- Paragraph
            function sectionObj:AddParagraph(text)
                local para = Instance.new("TextLabel")
                para.Text = text
                para.TextWrapped = true
                para.TextXAlignment = Enum.TextXAlignment.Left
                para.TextYAlignment = Enum.TextYAlignment.Top
                para.Font = Enum.Font.Gotham
                para.TextSize = isMobile and 15 or 13
                para.TextColor3 = theme.TextDim
                para.BackgroundColor3 = theme.Primary
                para.BackgroundTransparency = 0.3
                local corner = Instance.new("UICorner", para)
                corner.CornerRadius = UDim.new(0, 6)
                addElement(para, isMobile and 80 or 60)
                return para
            end

            -- Separator
            function sectionObj:AddSeparator()
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, -24, 0, isMobile and 4 or 2)
                sep.BackgroundColor3 = theme.Border
                sep.BorderSizePixel = 0
                addElement(sep, isMobile and 12 or 8)
                return sep
            end

            -- RadioGroup
            function sectionObj:AddRadioGroup(text, flag, options, default, callback)
                local f = Instance.new("Frame"); f.BackgroundTransparency=1
                local label = Instance.new("TextLabel", f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24)
                local selected = config[flag] or default or options[1]
                local y = isMobile and 30 or 24
                local btns = {}
                for i,opt in ipairs(options) do
                    local btn = Instance.new("TextButton", f)
                    btn.Size = UDim2.new(0.5, -16, 0, isMobile and 40 or 30)
                    btn.Position = UDim2.new((i-1)*0.5+0.02,0,0,y)
                    btn.Text = opt
                    btn.BackgroundColor3 = (opt==selected) and theme.Accent or theme.Primary
                    btn.TextColor3 = theme.Text
                    btn.Font = Enum.Font.Gotham
                    btn.TextSize = isMobile and 15 or 13
                    btn.AutoButtonColor = false
                    local btnCorner = Instance.new("UICorner", btn); btnCorner.CornerRadius = UDim.new(0,6)
                    btn.MouseButton1Click:Connect(function()
                        selected = opt
                        for _,b in pairs(btns) do b.BackgroundColor3 = (b.Text==opt) and theme.Accent or theme.Primary end
                        Flux:SetFlag(flag, opt)
                        if callback then pcall(callback, opt) end
                    end)
                    table.insert(btns, btn)
                end
                addElement(f, isMobile and 80 or 60)
                return { Get = function() return selected end }
            end

            -- ProgressBar
            function sectionObj:AddProgressBar(text, flag, minVal, maxVal, default)
                local f = Instance.new("Frame"); f.BackgroundTransparency=1
                local label = Instance.new("TextLabel", f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24)
                local track = Instance.new("Frame", f); track.Size = UDim2.new(1,-24,0,isMobile and 12 or 8); track.Position = UDim2.new(0,12,0,isMobile and 32 or 28); track.BackgroundColor3=theme.Border; track.BorderSizePixel=0
                local fill = Instance.new("Frame", track); fill.Size = UDim2.new(0,0,1,0); fill.BackgroundColor3=theme.Accent; fill.BorderSizePixel=0
                local value = config[flag] or default or minVal
                local function setProgress(v) v=math.clamp(v,minVal,maxVal); local pct=(v-minVal)/(maxVal-minVal); fill.Size=UDim2.new(pct,0,1,0); Flux:SetFlag(flag,v) end
                setProgress(value)
                addElement(f, isMobile and 70 or 48)
                return { Set = setProgress, Get = function() return value end }
            end

            -- ExpandableSection
            function sectionObj:AddExpandableSection(title, builderFunc)
                local inner = self:AddSection(title, true)
                builderFunc(inner)
                return inner
            end

            table.insert(tabObj._sections, sectionObj)
            refreshHeight()
            return sectionObj
        end
        return tabObj
    end

    table.insert(Flux._activeWindows, windowObj)
    return windowObj
end

_G.Flux = Flux
return Flux
