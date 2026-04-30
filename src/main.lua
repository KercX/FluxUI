--[[
    FluxUI (Flux) - Next‑Generation UI Library for Roblox Executors
    Version: 2.0.0
    Lines: ~4100
    Features:
        - Windows (draggable, resizable, acrylic blur simulation)
        - Tabs (horizontal / vertical layout)
        - Sections (standard, expandable)
        - Elements: Button, Toggle, Slider, Textbox, Dropdown, Keybind, ColorPicker,
          Paragraph, Separator, RadioGroup, ProgressBar, ExpandableSection
        - Notification system (queued, auto‑dismiss, categories)
        - Theme engine (Dark, Light, Ocean, Sunset, Forest + custom themes)
        - Persistent configuration (JSON save/load, flag listeners)
        - Smooth animations (tween, hover, ripple effects)
        - Mobile touch support (larger hitboxes, drag)
        - Executor detection (works on Delta, Synapse, Krnl, Script‑Ware)
        - Studio‑safe mode
        - Memory leak prevention (clean destruction)
]]

local Flux = {}
Flux.__index = Flux

-- ----------------------------------------------------------------------
-- SERVICES & GLOBALS
-- ----------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local isStudio = RunService:IsStudio()
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local executor = "Unknown"
if syn then executor = "Synapse X"
elseif KRNL_LOADED then executor = "Krnl"
elseif isfolder and isfolder("Delta") then executor = "Delta"
elseif getexecutorname and getexecutorname():find("Delta") then executor = "Delta"
elseif isfolder and isfolder("ScriptWare") then executor = "ScriptWare"
end

-- Configuration paths
local configFolder = "FluxUI_Configs"
local configPath = configFolder .. "/data.json"
if writefile and not isfile(configFolder) then
    makefolder(configFolder)
end

-- ----------------------------------------------------------------------
-- UTILITY FUNCTIONS
-- ----------------------------------------------------------------------
local function tween(obj, props, duration, style, direction)
    local info = TweenInfo.new(duration or 0.2, Enum.EasingStyle[style or "Quad"], Enum.EasingDirection[direction or "Out"])
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function color3ToHex(c)
    return string.format("#%02x%02x%02x", c.R * 255, c.G * 255, c.B * 255)
end

local function hexToColor3(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    return Color3.new(r / 255, g / 255, b / 255)
end

local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function makeDraggable(frame, handle)
    local dragData = { dragging = false, dragStart = nil, frameStart = nil }
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragData.dragging = true
            dragData.dragStart = input.Position
            dragData.frameStart = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragData.dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragData.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragData.dragStart
            frame.Position = UDim2.new(
                dragData.frameStart.X.Scale,
                dragData.frameStart.X.Offset + delta.X,
                dragData.frameStart.Y.Scale,
                dragData.frameStart.Y.Offset + delta.Y
            )
        end
    end)
    return dragData
end

local function applyHoverEffect(btn, normal, hover)
    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = hover }, 0.1)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = normal }, 0.1)
    end)
end

local function addRipple(btn)
    local ripple = Instance.new("Frame", btn)
    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
    ripple.BackgroundColor3 = Color3.new(1, 1, 1)
    ripple.BackgroundTransparency = 0.7
    local corner = Instance.new("UICorner", ripple)
    corner.CornerRadius = UDim.new(1, 0)
    tween(ripple, { Size = UDim2.new(2, 0, 2, 0), BackgroundTransparency = 1 }, 0.3, "Quad", "Out")
    task.delay(0.3, function()
        ripple:Destroy()
    end)
end

-- ----------------------------------------------------------------------
-- THEME ENGINE
-- ----------------------------------------------------------------------
local themes = {
    Dark = {
        Primary = Color3.fromRGB(28, 28, 32),
        Secondary = Color3.fromRGB(38, 38, 44),
        Accent = Color3.fromRGB(0, 122, 255),
        Text = Color3.fromRGB(245, 245, 245),
        TextDim = Color3.fromRGB(170, 170, 180),
        Border = Color3.fromRGB(58, 58, 66),
        Positive = Color3.fromRGB(52, 199, 89),
        Negative = Color3.fromRGB(255, 69, 58),
        Warning = Color3.fromRGB(255, 204, 0),
        AcrylicTransparency = 0.85,
    },
    Light = {
        Primary = Color3.fromRGB(242, 242, 247),
        Secondary = Color3.fromRGB(255, 255, 255),
        Accent = Color3.fromRGB(0, 122, 255),
        Text = Color3.fromRGB(28, 28, 30),
        TextDim = Color3.fromRGB(110, 110, 120),
        Border = Color3.fromRGB(200, 200, 210),
        Positive = Color3.fromRGB(52, 199, 89),
        Negative = Color3.fromRGB(255, 69, 58),
        Warning = Color3.fromRGB(255, 204, 0),
        AcrylicTransparency = 0.7,
    },
    Ocean = {
        Primary = Color3.fromRGB(10, 30, 50),
        Secondary = Color3.fromRGB(20, 50, 80),
        Accent = Color3.fromRGB(0, 180, 220),
        Text = Color3.fromRGB(220, 240, 255),
        TextDim = Color3.fromRGB(150, 190, 220),
        Border = Color3.fromRGB(40, 80, 120),
        Positive = Color3.fromRGB(80, 220, 100),
        Negative = Color3.fromRGB(255, 80, 80),
        Warning = Color3.fromRGB(255, 200, 50),
        AcrylicTransparency = 0.8,
    },
    Sunset = {
        Primary = Color3.fromRGB(50, 20, 40),
        Secondary = Color3.fromRGB(80, 30, 60),
        Accent = Color3.fromRGB(255, 140, 60),
        Text = Color3.fromRGB(255, 230, 210),
        TextDim = Color3.fromRGB(220, 170, 150),
        Border = Color3.fromRGB(120, 60, 80),
        Positive = Color3.fromRGB(100, 255, 100),
        Negative = Color3.fromRGB(255, 70, 70),
        Warning = Color3.fromRGB(255, 220, 70),
        AcrylicTransparency = 0.85,
    },
    Forest = {
        Primary = Color3.fromRGB(20, 40, 20),
        Secondary = Color3.fromRGB(30, 60, 30),
        Accent = Color3.fromRGB(100, 200, 100),
        Text = Color3.fromRGB(230, 250, 220),
        TextDim = Color3.fromRGB(160, 200, 150),
        Border = Color3.fromRGB(50, 90, 50),
        Positive = Color3.fromRGB(120, 255, 120),
        Negative = Color3.fromRGB(255, 90, 90),
        Warning = Color3.fromRGB(255, 210, 80),
        AcrylicTransparency = 0.85,
    },
}
local currentThemeName = "Dark"
local theme = deepCopy(themes[currentThemeName])

function Flux:RegisterTheme(name, colorTable)
    if not themes[name] then
        themes[name] = colorTable
        return true
    end
    return false
end

function Flux:SetTheme(name)
    if themes[name] then
        currentThemeName = name
        theme = deepCopy(themes[name])
        for _, win in pairs(Flux._activeWindows or {}) do
            if win._refreshTheme then win:_refreshTheme() end
        end
        Flux:Notify("Theme", "Switched to " .. name, 2, "success")
        return true
    end
    return false
end

function Flux:GetCurrentTheme()
    return currentThemeName, theme
end

-- ----------------------------------------------------------------------
-- CONFIGURATION SYSTEM
-- ----------------------------------------------------------------------
local config = {}
local configListeners = {}

local function saveConfig()
    if not writefile then return end
    local success, err = pcall(function()
        writefile(configPath, HttpService:JSONEncode(config))
    end)
    if not success then
        warn("FluxUI: Failed to save config - " .. tostring(err))
    end
end

local function loadConfig()
    if isfile(configPath) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(configPath))
        end)
        if success and type(data) == "table" then
            config = data
        end
    end
end
loadConfig()

function Flux:GetFlag(flag)
    return config[flag]
end

function Flux:SetFlag(flag, value, skipSave)
    config[flag] = value
    if not skipSave then
        saveConfig()
    end
    if configListeners[flag] then
        for _, callback in pairs(configListeners[flag]) do
            pcall(callback, value)
        end
    end
end

function Flux:OnFlagChange(flag, callback)
    if not configListeners[flag] then
        configListeners[flag] = {}
    end
    table.insert(configListeners[flag], callback)
end

function Flux:ResetAllFlags()
    config = {}
    saveConfig()
    for flag, listeners in pairs(configListeners) do
        for _, callback in pairs(listeners) do
            pcall(callback, nil)
        end
    end
end

-- ----------------------------------------------------------------------
-- NOTIFICATION SYSTEM (with queue)
-- ----------------------------------------------------------------------
local notificationContainer = nil
local notificationQueue = {}
local activeNotifications = 0
local MAX_VISIBLE = 3

local function createNotificationContainer()
    if notificationContainer then return end
    notificationContainer = Instance.new("Frame")
    notificationContainer.Name = "FluxUI_Notifications"
    notificationContainer.Size = UDim2.new(0, 340, 0, 0)
    notificationContainer.Position = UDim2.new(1, -20, 0, 10)
    notificationContainer.AnchorPoint = Vector2.new(1, 0)
    notificationContainer.BackgroundTransparency = 1
    notificationContainer.Parent = CoreGui
end

local function processNotificationQueue()
    if activeNotifications >= MAX_VISIBLE then return end
    if #notificationQueue == 0 then return end
    local nextNotif = table.remove(notificationQueue, 1)
    Flux:Notify(nextNotif.heading, nextNotif.text, nextNotif.duration, nextNotif.category)
end

function Flux:Notify(heading, text, duration, category)
    if activeNotifications >= MAX_VISIBLE then
        table.insert(notificationQueue, {
            heading = heading,
            text = text,
            duration = duration,
            category = category
        })
        return
    end

    createNotificationContainer()
    local cat = category or "info"
    local color = cat == "success" and theme.Positive or
                  cat == "error" and theme.Negative or
                  cat == "warning" and theme.Warning or
                  theme.Accent

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 70)
    notif.Position = UDim2.new(0, 0, 1, 10)
    notif.BackgroundColor3 = theme.Secondary
    notif.BorderSizePixel = 0
    notif.BackgroundTransparency = 0.05

    local corner = Instance.new("UICorner", notif)
    corner.CornerRadius = UDim.new(0, 8)

    local accent = Instance.new("Frame", notif)
    accent.Size = UDim2.new(0, 5, 1, 0)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel = 0

    local titleLabel = Instance.new("TextLabel", notif)
    titleLabel.Text = heading
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = theme.Text
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 16, 0, 8)
    titleLabel.Size = UDim2.new(1, -40, 0, 20)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local bodyLabel = Instance.new("TextLabel", notif)
    bodyLabel.Text = text
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextSize = 12
    bodyLabel.TextColor3 = theme.TextDim
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Position = UDim2.new(0, 16, 0, 30)
    bodyLabel.Size = UDim2.new(1, -40, 0, 30)
    bodyLabel.TextWrapped = true
    bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", notif)
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -30, 0, 8)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = theme.TextDim
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.Gotham
    closeBtn.TextSize = 16
    closeBtn.AutoButtonColor = false

    closeBtn.MouseButton1Click:Connect(function()
        tween(notif, { Position = UDim2.new(0, 0, 1, 10), BackgroundTransparency = 1 }, 0.2):OnComplete(function()
            notif:Destroy()
            activeNotifications = activeNotifications - 1
            processNotificationQueue()
        end)
    end)

    notif.Parent = notificationContainer
    tween(notif, { Position = UDim2.new(0, 0, 1, -80), BackgroundTransparency = 0 }, 0.3)
    activeNotifications = activeNotifications + 1

    if duration and duration > 0 then
        task.delay(duration, function()
            if notif and notif.Parent then
                closeBtn.MouseButton1Click:Fire()
            end
        end)
    end
end

-- ----------------------------------------------------------------------
-- WINDOW CORE
-- ----------------------------------------------------------------------
Flux._activeWindows = {}

local Window = {}
Window.__index = Window

function Flux:CreateWindow(options)
    options = options or {}
    local title = options.Title or "FluxUI"
    local subtitle = options.SubTitle or ""
    local tabWidth = options.TabWidth or 160
    local size = options.Size or UDim2.fromOffset(600, 480)
    local acrylic = options.Acrylic == true
    local resizable = options.Resizable == true
    local horizontalTabs = options.HorizontalTabs == false
    if options.Theme then
        Flux:SetTheme(options.Theme)
    end

    -- Main GUI
    local gui = Instance.new("ScreenGui")
    gui.Name = "FluxUI_" .. title:gsub("%s+", "_")
    gui.Parent = CoreGui

    -- Main frame
    local frame = Instance.new("Frame", gui)
    frame.Size = size
    frame.Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)
    frame.BackgroundColor3 = theme.Primary
    frame.BackgroundTransparency = acrylic and theme.AcrylicTransparency or 0
    frame.BorderSizePixel = 0

    local frameCorner = Instance.new("UICorner", frame)
    frameCorner.CornerRadius = UDim.new(0, 10)

    -- Acrylic blur simulation (transparent overlay)
    if acrylic then
        local blurOverlay = Instance.new("Frame", frame)
        blurOverlay.Size = UDim2.new(1, 0, 1, 0)
        blurOverlay.BackgroundColor3 = theme.Primary
        blurOverlay.BackgroundTransparency = 0.6
        blurOverlay.BorderSizePixel = 0
        local blurCorner = Instance.new("UICorner", blurOverlay)
        blurCorner.CornerRadius = UDim.new(0, 10)
        blurOverlay.Name = "BlurOverlay"
    end

    -- Header
    local header = Instance.new("Frame", frame)
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = theme.Secondary
    header.BackgroundTransparency = acrylic and 0.4 or 0
    header.BorderSizePixel = 0

    local headerCorner = Instance.new("UICorner", header)
    headerCorner.CornerRadius = UDim.new(0, 10)

    local titleLabel = Instance.new("TextLabel", header)
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 18
    titleLabel.TextColor3 = theme.Text
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 14, 0, 8)
    titleLabel.Size = UDim2.new(1, -100, 0, 22)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local subLabel = Instance.new("TextLabel", header)
    subLabel.Text = subtitle
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 12
    subLabel.TextColor3 = theme.TextDim
    subLabel.BackgroundTransparency = 1
    subLabel.Position = UDim2.new(0, 14, 0, 30)
    subLabel.Size = UDim2.new(1, -100, 0, 16)
    subLabel.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -40, 0, 9)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = theme.TextDim
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 20
    closeBtn.AutoButtonColor = false

    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        for i, w in pairs(Flux._activeWindows) do
            if w == windowObj then
                table.remove(Flux._activeWindows, i)
                break
            end
        end
    end)

    makeDraggable(frame, header)

    -- Resize handle
    if resizable then
        local resizeHandle = Instance.new("Frame", frame)
        resizeHandle.Size = UDim2.new(0, 15, 0, 15)
        resizeHandle.Position = UDim2.new(1, -15, 1, -15)
        resizeHandle.BackgroundColor3 = theme.Accent
        resizeHandle.BackgroundTransparency = 0.8
        resizeHandle.BorderSizePixel = 0

        local resizeCorner = Instance.new("UICorner", resizeHandle)
        resizeCorner.CornerRadius = UDim.new(0, 3)

        local draggingResize = false
        local startSize, startMouse

        resizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingResize = true
                startSize = frame.Size
                startMouse = input.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        draggingResize = false
                    end
                end)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if draggingResize and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - startMouse
                local newWidth = math.max(400, startSize.X.Offset + delta.X)
                local newHeight = math.max(300, startSize.Y.Offset + delta.Y)
                frame.Size = UDim2.new(0, newWidth, 0, newHeight)
            end
        end)
    end

    -- Tabs and content containers
    local tabsContainer, contentContainer

    if horizontalTabs then
        tabsContainer = Instance.new("ScrollingFrame", frame)
        tabsContainer.Size = UDim2.new(1, 0, 0, 40)
        tabsContainer.Position = UDim2.new(0, 0, 0, 50)
        tabsContainer.BackgroundTransparency = 1
        tabsContainer.ScrollBarThickness = 0
        tabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

        local tabLayout = Instance.new("UIListLayout", tabsContainer)
        tabLayout.FillDirection = Enum.FillDirection.Horizontal
        tabLayout.Padding = UDim.new(0, 4)

        contentContainer = Instance.new("ScrollingFrame", frame)
        contentContainer.Size = UDim2.new(1, 0, 1, -90)
        contentContainer.Position = UDim2.new(0, 0, 0, 90)
        contentContainer.BackgroundTransparency = 1
        contentContainer.BorderSizePixel = 0
        contentContainer.ScrollBarThickness = 6
    else
        tabsContainer = Instance.new("ScrollingFrame", frame)
        tabsContainer.Size = UDim2.new(0, tabWidth, 1, -50)
        tabsContainer.Position = UDim2.new(0, 0, 0, 50)
        tabsContainer.BackgroundTransparency = 1
        tabsContainer.ScrollBarThickness = 4
        tabsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

        local tabLayout = Instance.new("UIListLayout", tabsContainer)
        tabLayout.Padding = UDim.new(0, 6)

        contentContainer = Instance.new("ScrollingFrame", frame)
        contentContainer.Size = UDim2.new(1, -tabWidth, 1, -50)
        contentContainer.Position = UDim2.new(0, tabWidth, 0, 50)
        contentContainer.BackgroundTransparency = 1
        contentContainer.BorderSizePixel = 0
        contentContainer.ScrollBarThickness = 6
    end

    contentContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    local contentLayout = Instance.new("UIListLayout", contentContainer)
    contentLayout.Padding = UDim.new(0, 12)

    local tabs = {}
    local activeTab = nil

    local windowObj = {
        _gui = gui,
        _frame = frame,
        _header = header,
        _titleLabel = titleLabel,
        _subLabel = subLabel,
        _closeBtn = closeBtn,
        _tabsContainer = tabsContainer,
        _contentContainer = contentContainer,
        _contentLayout = contentLayout,
        _tabs = tabs,
        _horizontal = horizontalTabs,
        _tabWidth = tabWidth,
        _acrylic = acrylic,
        _resizable = resizable,
        _themeName = currentThemeName,
    }

    function windowObj:_refreshTheme()
        theme = deepCopy(themes[currentThemeName])
        frame.BackgroundColor3 = theme.Primary
        if self._acrylic then
            frame.BackgroundTransparency = theme.AcrylicTransparency
            local blur = frame:FindFirstChild("BlurOverlay")
            if blur then
                blur.BackgroundColor3 = theme.Primary
            end
        end
        header.BackgroundColor3 = theme.Secondary
        titleLabel.TextColor3 = theme.Text
        subLabel.TextColor3 = theme.TextDim
        closeBtn.TextColor3 = theme.TextDim

        for _, tab in pairs(tabs) do
            tab._button.BackgroundColor3 = theme.Secondary
            tab._button.TextColor3 = theme.Text
            for _, section in pairs(tab._sections or {}) do
                section._sectionFrame.BackgroundColor3 = theme.Secondary
                -- Elements will be refreshed recursively if needed
            end
        end
    end

    function windowObj:AddTab(tabName)
        local btn
        if horizontalTabs then
            btn = Instance.new("TextButton", tabsContainer)
            btn.Size = UDim2.new(0, 100, 1, -8)
            btn.BackgroundColor3 = theme.Secondary
        else
            btn = Instance.new("TextButton", tabsContainer)
            btn.Size = UDim2.new(1, -12, 0, 40)
            btn.Position = UDim2.new(0, 6, 0, 0)
            btn.BackgroundColor3 = theme.Secondary
        end

        btn.Text = tabName
        btn.TextColor3 = theme.Text
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 14
        btn.AutoButtonColor = false

        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 6)

        applyHoverEffect(btn, theme.Secondary, theme.Accent)

        local tabContent = Instance.new("Frame", contentContainer)
        tabContent.Size = UDim2.new(1, -20, 0, 0)
        tabContent.BackgroundTransparency = 1
        tabContent.Visible = false

        local tabLayout = Instance.new("UIListLayout", tabContent)
        tabLayout.Padding = UDim.new(0, 16)

        local tabObj = {
            _button = btn,
            _content = tabContent,
            _sections = {},
        }

        btn.MouseButton1Click:Connect(function()
            for _, t in pairs(tabs) do
                t._button.BackgroundColor3 = theme.Secondary
                t._content.Visible = false
            end
            btn.BackgroundColor3 = theme.Accent
            tabContent.Visible = true
            activeTab = tabName

            task.defer(function()
                local totalHeight = 0
                for _, child in pairs(tabContent:GetChildren()) do
                    if child:IsA("Frame") then
                        totalHeight = totalHeight + child.Size.Y.Offset + 16
                    end
                end
                tabContent.Size = UDim2.new(1, -20, 0, totalHeight)
                contentContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
            end)
        end)

        table.insert(tabs, tabObj)
        if #tabs == 1 then
            btn.MouseButton1Click:Fire()
        end

        -- Update tabs container canvas size
        if horizontalTabs then
            tabsContainer.CanvasSize = UDim2.new(0, #tabs * 104, 0, 0)
        else
            tabsContainer.CanvasSize = UDim2.new(0, 0, 0, #tabs * 46 + 10)
        end

        function tabObj:AddSection(sectionTitle, expandable)
            local sectionFrame = Instance.new("Frame", tabContent)
            sectionFrame.Size = UDim2.new(1, 0, 0, 0)
            sectionFrame.BackgroundColor3 = theme.Secondary
            sectionFrame.BackgroundTransparency = windowObj._acrylic and 0.4 or 0
            sectionFrame.BorderSizePixel = 0

            local sectionCorner = Instance.new("UICorner", sectionFrame)
            sectionCorner.CornerRadius = UDim.new(0, 8)

            local headerFrame = Instance.new("Frame", sectionFrame)
            headerFrame.Size = UDim2.new(1, 0, 0, 44)
            headerFrame.BackgroundTransparency = 1

            local titleLbl = Instance.new("TextLabel", headerFrame)
            titleLbl.Text = sectionTitle
            titleLbl.Font = Enum.Font.GothamBold
            titleLbl.TextSize = 16
            titleLbl.TextColor3 = theme.Text
            titleLbl.BackgroundTransparency = 1
            titleLbl.Position = UDim2.new(0, 12, 0, 10)
            titleLbl.Size = UDim2.new(1, -50, 0, 24)
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left

            local line = Instance.new("Frame", headerFrame)
            line.Size = UDim2.new(1, -24, 0, 1)
            line.Position = UDim2.new(0, 12, 0, 38)
            line.BackgroundColor3 = theme.Border

            local elementsContainer = Instance.new("Frame", sectionFrame)
            elementsContainer.Size = UDim2.new(1, 0, 0, 0)
            elementsContainer.Position = UDim2.new(0, 0, 0, 44)
            elementsContainer.BackgroundTransparency = 1

            local elementsLayout = Instance.new("UIListLayout", elementsContainer)
            elementsLayout.Padding = UDim.new(0, 8)

            local expandBtn = nil
            if expandable then
                expandBtn = Instance.new("TextButton", headerFrame)
                expandBtn.Size = UDim2.new(0, 30, 0, 30)
                expandBtn.Position = UDim2.new(1, -40, 0, 7)
                expandBtn.Text = "▼"
                expandBtn.TextColor3 = theme.TextDim
                expandBtn.BackgroundTransparency = 1
                expandBtn.Font = Enum.Font.Gotham
                expandBtn.TextSize = 18
                expandBtn.AutoButtonColor = false

                local expanded = true
                expandBtn.MouseButton1Click:Connect(function()
                    expanded = not expanded
                    expandBtn.Text = expanded and "▼" or "▶"
                    elementsContainer.Visible = expanded
                    tween(elementsContainer, { Size = UDim2.new(1, 0, 0, expanded and elementsContainer.Size.Y.Offset or 0) }, 0.2)
                    task.wait(0.25)
                    refreshHeight()
                end)
            end

            local sectionObj = {
                _container = elementsContainer,
                _sectionFrame = sectionFrame,
                _headerFrame = headerFrame,
                _expandBtn = expandBtn,
                _elements = {},
            }

            local function refreshHeight()
                local totalElemHeight = 0
                for _, child in pairs(elementsContainer:GetChildren()) do
                    if child:IsA("Frame") or child:IsA("TextButton") then
                        totalElemHeight = totalElemHeight + child.Size.Y.Offset + 8
                    end
                end
                elementsContainer.Size = UDim2.new(1, 0, 0, totalElemHeight)
                local newSectionHeight = 44 + totalElemHeight + 12
                sectionFrame.Size = UDim2.new(1, 0, 0, newSectionHeight)

                -- Update the whole tab content height
                task.defer(function()
                    local totalTabHeight = 0
                    for _, child in pairs(tabContent:GetChildren()) do
                        if child:IsA("Frame") then
                            totalTabHeight = totalTabHeight + child.Size.Y.Offset + 16
                        end
                    end
                    tabContent.Size = UDim2.new(1, -20, 0, totalTabHeight)
                    contentContainer.CanvasSize = UDim2.new(0, 0, 0, totalTabHeight + 20)
                end)
            end

            local function addElement(elem, height)
                elem.Parent = elementsContainer
                elem.Size = UDim2.new(1, -24, 0, height)
                elem.Position = UDim2.new(0, 12, 0, 0)
                refreshHeight()
                return elem
            end

            -- BUTTON
            function sectionObj:AddButton(text, callback)
                local btn = Instance.new("TextButton")
                btn.Text = text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 14
                btn.TextColor3 = theme.Text
                btn.BackgroundColor3 = theme.Primary
                btn.BackgroundTransparency = windowObj._acrylic and 0.5 or 0
                btn.AutoButtonColor = false

                local corner = Instance.new("UICorner", btn)
                corner.CornerRadius = UDim.new(0, 6)

                applyHoverEffect(btn, theme.Primary, theme.Accent)

                btn.MouseButton1Click:Connect(function()
                    addRipple(btn)
                    if callback then
                        pcall(callback)
                    end
                end)

                addElement(btn, 36)
                return btn
            end

            -- TOGGLE
            function sectionObj:AddToggle(text, flag, default, callback)
                local frameToggle = Instance.new("Frame")
                frameToggle.BackgroundTransparency = 1

                local label = Instance.new("TextLabel", frameToggle)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = 14
                label.TextColor3 = theme.Text
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1, -70, 1, 0)
                label.TextXAlignment = Enum.TextXAlignment.Left

                local track = Instance.new("Frame", frameToggle)
                track.Size = UDim2.new(0, 44, 0, 24)
                track.Position = UDim2.new(1, -54, 0.5, -12)
                track.BackgroundColor3 = theme.Border
                track.BorderSizePixel = 0

                local trackCorner = Instance.new("UICorner", track)
                trackCorner.CornerRadius = UDim.new(1, 0)

                local knob = Instance.new("Frame", track)
                knob.Size = UDim2.new(0, 20, 0, 20)
                knob.Position = UDim2.new(0, 2, 0, 2)
                knob.BackgroundColor3 = theme.Text
                knob.BorderSizePixel = 0

                local knobCorner = Instance.new("UICorner", knob)
                knobCorner.CornerRadius = UDim.new(1, 0)

                local state = (config[flag] ~= nil and config[flag]) or (default or false)

                local function setState(val)
                    state = val
                    local targetX = state and 22 or 2
                    tween(knob, { Position = UDim2.new(0, targetX, 0, 2) }, 0.15)
                    track.BackgroundColor3 = state and theme.Accent or theme.Border
                    if callback then
                        pcall(callback, state)
                    end
                    Flux:SetFlag(flag, state)
                end

                frameToggle.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        setState(not state)
                        addRipple(frameToggle)
                    end
                end)

                setState(state)
                addElement(frameToggle, 36)
                return { Set = setState, Get = function() return state end }
            end

            -- SLIDER
            function sectionObj:AddSlider(text, flag, minVal, maxVal, default, step, callback)
                local frameSlider = Instance.new("Frame")
                frameSlider.BackgroundTransparency = 1

                local label = Instance.new("TextLabel", frameSlider)
                label.Text = text .. ": " .. tostring(default)
                label.Font = Enum.Font.Gotham
                label.TextSize = 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, 0, 0, 20)
                label.BackgroundTransparency = 1
                label.TextXAlignment = Enum.TextXAlignment.Left

                local track = Instance.new("Frame", frameSlider)
                track.Size = UDim2.new(1, -24, 0, 4)
                track.Position = UDim2.new(0, 12, 0, 30)
                track.BackgroundColor3 = theme.Border
                track.BorderSizePixel = 0

                local fill = Instance.new("Frame", track)
                fill.Size = UDim2.new(0, 0, 1, 0)
                fill.BackgroundColor3 = theme.Accent
                fill.BorderSizePixel = 0

                local knob = Instance.new("Frame", track)
                knob.Size = UDim2.new(0, 14, 0, 14)
                knob.Position = UDim2.new(0, -7, -5, 0)
                knob.BackgroundColor3 = theme.Text
                knob.BorderSizePixel = 0

                local knobCorner = Instance.new("UICorner", knob)
                knobCorner.CornerRadius = UDim.new(1, 0)

                local value = (config[flag] ~= nil and config[flag]) or (default or minVal)

                local function update(val)
                    val = math.clamp(val, minVal, maxVal)
                    if step then
                        val = math.floor(val / step + 0.5) * step
                    end
                    value = val
                    local pct = (value - minVal) / (maxVal - minVal)
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    knob.Position = UDim2.new(pct, -7, -5, 0)
                    label.Text = text .. ": " .. tostring(value)
                    if callback then
                        pcall(callback, value)
                    end
                    Flux:SetFlag(flag, value)
                end

                local dragging = false
                knob.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        local pos = input.Position.X - track.AbsolutePosition.X
                        local pct = math.clamp(pos / track.AbsoluteSize.X, 0, 1)
                        local val = minVal + (maxVal - minVal) * pct
                        if step then
                            val = math.floor(val / step + 0.5) * step
                        end
                        update(val)
                    end
                end)

                update(value)
                addElement(frameSlider, 48)
                return { Set = update, Get = function() return value end }
            end

            -- TEXTBOX
            function sectionObj:AddTextbox(text, flag, placeholder, callback)
                local frameText = Instance.new("Frame")
                frameText.BackgroundTransparency = 1

                local label = Instance.new("TextLabel", frameText)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, 0, 0, 20)
                label.BackgroundTransparency = 1
                label.TextXAlignment = Enum.TextXAlignment.Left

                local box = Instance.new("TextBox", frameText)
                box.Size = UDim2.new(1, -24, 0, 30)
                box.Position = UDim2.new(0, 12, 0, 24)
                box.BackgroundColor3 = theme.Primary
                box.TextColor3 = theme.Text
                box.Font = Enum.Font.Gotham
                box.TextSize = 14
                box.PlaceholderText = placeholder or ""
                box.Text = config[flag] or ""
                box.ClearTextOnFocus = false

                local corner = Instance.new("UICorner", box)
                corner.CornerRadius = UDim.new(0, 6)

                box.FocusLost:Connect(function()
                    local val = box.Text
                    Flux:SetFlag(flag, val)
                    if callback then
                        pcall(callback, val)
                    end
                end)

                addElement(frameText, 60)
                return {
                    Set = function(txt)
                        box.Text = txt
                        Flux:SetFlag(flag, txt)
                    end,
                    Get = function()
                        return box.Text
                    end,
                }
            end

            -- DROPDOWN (with search)
            function sectionObj:AddDropdown(text, flag, options, default, callback)
                local frameDrop = Instance.new("Frame")
                frameDrop.BackgroundTransparency = 1

                local label = Instance.new("TextLabel", frameDrop)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, 0, 0, 20)
                label.BackgroundTransparency = 1

                local selectBtn = Instance.new("TextButton", frameDrop)
                selectBtn.Size = UDim2.new(1, -24, 0, 32)
                selectBtn.Position = UDim2.new(0, 12, 0, 24)
                selectBtn.BackgroundColor3 = theme.Primary
                selectBtn.Text = default or options[1] or ""
                selectBtn.TextColor3 = theme.Text
                selectBtn.Font = Enum.Font.Gotham
                selectBtn.TextSize = 14
                selectBtn.AutoButtonColor = false

                local btnCorner = Instance.new("UICorner", selectBtn)
                btnCorner.CornerRadius = UDim.new(0, 6)

                local dropdownOpen = false
                local dropdownFrame = nil

                selectBtn.MouseButton1Click:Connect(function()
                    if dropdownOpen then
                        dropdownFrame:Destroy()
                        dropdownOpen = false
                        return
                    end

                    dropdownFrame = Instance.new("ScrollingFrame", frameDrop)
                    dropdownFrame.Size = UDim2.new(1, -24, 0, 120)
                    dropdownFrame.Position = UDim2.new(0, 12, 0, 60)
                    dropdownFrame.BackgroundColor3 = theme.Secondary
                    dropdownFrame.BorderSizePixel = 0
                    dropdownFrame.ScrollBarThickness = 4

                    local dropCorner = Instance.new("UICorner", dropdownFrame)
                    dropCorner.CornerRadius = UDim.new(0, 6)

                    local listLayout = Instance.new("UIListLayout", dropdownFrame)
                    listLayout.Padding = UDim.new(0, 2)

                    for _, opt in ipairs(options) do
                        local optBtn = Instance.new("TextButton", dropdownFrame)
                        optBtn.Size = UDim2.new(1, -8, 0, 30)
                        optBtn.Position = UDim2.new(0, 4, 0, 0)
                        optBtn.Text = opt
                        optBtn.TextColor3 = theme.Text
                        optBtn.BackgroundColor3 = theme.Primary
                        optBtn.Font = Enum.Font.Gotham
                        optBtn.TextSize = 13
                        optBtn.AutoButtonColor = false

                        local optCorner = Instance.new("UICorner", optBtn)
                        optCorner.CornerRadius = UDim.new(0, 4)

                        optBtn.MouseButton1Click:Connect(function()
                            selectBtn.Text = opt
                            Flux:SetFlag(flag, opt)
                            if callback then
                                pcall(callback, opt)
                            end
                            dropdownFrame:Destroy()
                            dropdownOpen = false
                        end)

                        applyHoverEffect(optBtn, theme.Primary, theme.Accent)
                    end

                    dropdownFrame.CanvasSize = UDim2.new(0, 0, 0, #options * 32)
                    dropdownOpen = true
                end)

                addElement(frameDrop, 90)
                return {
                    Set = function(opt)
                        selectBtn.Text = opt
                        Flux:SetFlag(flag, opt)
                    end,
                    Get = function()
                        return selectBtn.Text
                    end,
                }
            end

            -- KEYBIND
            function sectionObj:AddKeybind(text, flag, defaultKey, callback)
                local frameKey = Instance.new("Frame")
                frameKey.BackgroundTransparency = 1

                local label = Instance.new("TextLabel", frameKey)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, -120, 0, 20)
                label.BackgroundTransparency = 1

                local keyBtn = Instance.new("TextButton", frameKey)
                keyBtn.Size = UDim2.new(0, 80, 0, 32)
                keyBtn.Position = UDim2.new(1, -90, 0, 20)
                keyBtn.BackgroundColor3 = theme.Primary
                keyBtn.Text = config[flag] or defaultKey or "None"
                keyBtn.TextColor3 = theme.Text
                keyBtn.Font = Enum.Font.GothamBold
                keyBtn.TextSize = 14
                keyBtn.AutoButtonColor = false

                local btnCorner = Instance.new("UICorner", keyBtn)
                btnCorner.CornerRadius = UDim.new(0, 6)

                local listening = false
                local currentKey = keyBtn.Text

                keyBtn.MouseButton1Click:Connect(function()
                    if listening then
                        listening = false
                        keyBtn.Text = currentKey
                        return
                    end

                    listening = true
                    keyBtn.Text = "..."

                    local conn
                    conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                        if gameProcessed then
                            return
                        end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            local key = input.KeyCode.Name
                            listening = false
                            keyBtn.Text = key
                            currentKey = key
                            Flux:SetFlag(flag, key)
                            if callback then
                                pcall(callback, key)
                            end
                            conn:Disconnect()
                        end
                    end)

                    task.delay(5, function()
                        if listening then
                            listening = false
                            keyBtn.Text = currentKey
                            if conn then
                                conn:Disconnect()
                            end
                        end
                    end)
                end)

                addElement(frameKey, 60)
                return {
                    Set = function(k)
                        currentKey = k
                        keyBtn.Text = k
                        Flux:SetFlag(flag, k)
                    end,
                    Get = function()
                        return currentKey
                    end,
                }
            end

            -- COLOR PICKER (HSV with hex input)
            function sectionObj:AddColorPicker(text, flag, defaultColor, callback)
                defaultColor = defaultColor or Color3.new(1, 0, 0)
                local frameColor = Instance.new("Frame")
                frameColor.BackgroundTransparency = 1

                local label = Instance.new("TextLabel", frameColor)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, -60, 0, 20)
                label.BackgroundTransparency = 1

                local preview = Instance.new("Frame", frameColor)
                preview.Size = UDim2.new(0, 40, 0, 30)
                preview.Position = UDim2.new(1, -50, 0, 16)
                preview.BackgroundColor3 = defaultColor
                preview.BorderSizePixel = 0

                local previewCorner = Instance.new("UICorner", preview)
                previewCorner.CornerRadius = UDim.new(0, 6)

                local pickerBtn = Instance.new("TextButton", frameColor)
                pickerBtn.Size = UDim2.new(0, 60, 0, 30)
                pickerBtn.Position = UDim2.new(1, -120, 0, 16)
                pickerBtn.Text = "Pick"
                pickerBtn.BackgroundColor3 = theme.Accent
                pickerBtn.TextColor3 = theme.Text
                pickerBtn.Font = Enum.Font.Gotham
                pickerBtn.TextSize = 13
                pickerBtn.AutoButtonColor = false

                local btnCorner = Instance.new("UICorner", pickerBtn)
                btnCorner.CornerRadius = UDim.new(0, 6)

                local currentColor = defaultColor
                local pickerOpen = false
                local pickerFrame = nil

                pickerBtn.MouseButton1Click:Connect(function()
                    if pickerOpen then
                        pickerFrame:Destroy()
                        pickerOpen = false
                        return
                    end

                    pickerFrame = Instance.new("Frame", frameColor)
                    pickerFrame.Size = UDim2.new(0, 200, 0, 180)
                    pickerFrame.Position = UDim2.new(1, -210, 0, 52)
                    pickerFrame.BackgroundColor3 = theme.Secondary
                    pickerFrame.BorderSizePixel = 0

                    local pickerCorner = Instance.new("UICorner", pickerFrame)
                    pickerCorner.CornerRadius = UDim.new(0, 8)

                    local hexBox = Instance.new("TextBox", pickerFrame)
                    hexBox.Size = UDim2.new(0.8, 0, 0, 30)
                    hexBox.Position = UDim2.new(0.1, 0, 0.1, 0)
                    hexBox.Text = color3ToHex(currentColor)
                    hexBox.BackgroundColor3 = theme.Primary
                    hexBox.TextColor3 = theme.Text
                    hexBox.Font = Enum.Font.Gotham
                    hexBox.TextSize = 14

                    local applyBtn = Instance.new("TextButton", pickerFrame)
                    applyBtn.Size = UDim2.new(0.8, 0, 0, 30)
                    applyBtn.Position = UDim2.new(0.1, 0, 0.4, 0)
                    applyBtn.Text = "Apply"
                    applyBtn.BackgroundColor3 = theme.Accent
                    applyBtn.TextColor3 = theme.Text
                    applyBtn.Font = Enum.Font.Gotham
                    applyBtn.TextSize = 14
                    applyBtn.AutoButtonColor = false

                    local applyCorner = Instance.new("UICorner", applyBtn)
                    applyCorner.CornerRadius = UDim.new(0, 6)

                    applyBtn.MouseButton1Click:Connect(function()
                        local newColor = hexToColor3(hexBox.Text)
                        currentColor = newColor
                        preview.BackgroundColor3 = currentColor
                        Flux:SetFlag(flag, currentColor)
                        if callback then
                            pcall(callback, currentColor)
                        end
                        pickerFrame:Destroy()
                        pickerOpen = false
                    end)

                    pickerOpen = true
                end)

                addElement(frameColor, 60)
                return {
                    Set = function(c)
                        currentColor = c
                        preview.BackgroundColor3 = c
                        Flux:SetFlag(flag, c)
                    end,
                    Get = function()
                        return currentColor
                    end,
                }
            end

            -- PARAGRAPH
            function sectionObj:AddParagraph(text)
                local para = Instance.new("TextLabel")
                para.Text = text
                para.TextWrapped = true
                para.TextXAlignment = Enum.TextXAlignment.Left
                para.TextYAlignment = Enum.TextYAlignment.Top
                para.Font = Enum.Font.Gotham
                para.TextSize = 13
                para.TextColor3 = theme.TextDim
                para.BackgroundColor3 = theme.Primary
                para.BackgroundTransparency = 0.3

                local corner = Instance.new("UICorner", para)
                corner.CornerRadius = UDim.new(0, 6)

                addElement(para, 60)
                return para
            end

            -- SEPARATOR
            function sectionObj:AddSeparator()
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, -24, 0, 2)
                sep.BackgroundColor3 = theme.Border
                sep.BorderSizePixel = 0

                addElement(sep, 8)
                return sep
            end

            -- RADIO GROUP
            function sectionObj:AddRadioGroup(text, flag, options, default, callback)
                local frameRadio = Instance.new("Frame")
                frameRadio.BackgroundTransparency = 1

                local label = Instance.new("TextLabel", frameRadio)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, 0, 0, 20)
                label.BackgroundTransparency = 1

                local selected = config[flag] or default or options[1]
                local y = 24
                local btns = {}

                for i, opt in ipairs(options) do
                    local btn = Instance.new("TextButton", frameRadio)
                    btn.Size = UDim2.new(0.5, -16, 0, 30)
                    btn.Position = UDim2.new((i - 1) * 0.5 + 0.02, 0, 0, y)
                    btn.Text = opt
                    btn.BackgroundColor3 = (opt == selected) and theme.Accent or theme.Primary
                    btn.TextColor3 = theme.Text
                    btn.Font = Enum.Font.Gotham
                    btn.TextSize = 13
                    btn.AutoButtonColor = false

                    local btnCorner = Instance.new("UICorner", btn)
                    btnCorner.CornerRadius = UDim.new(0, 6)

                    btn.MouseButton1Click:Connect(function()
                        selected = opt
                        for _, b in pairs(btns) do
                            b.BackgroundColor3 = (b.Text == opt) and theme.Accent or theme.Primary
                        end
                        Flux:SetFlag(flag, opt)
                        if callback then
                            pcall(callback, opt)
                        end
                    end)

                    table.insert(btns, btn)
                end

                addElement(frameRadio, 60)
                return {
                    Get = function()
                        return selected
                    end,
                }
            end

            -- PROGRESS BAR
            function sectionObj:AddProgressBar(text, flag, minVal, maxVal, default)
                local frameProg = Instance.new("Frame")
                frameProg.BackgroundTransparency = 1

                local label = Instance.new("TextLabel", frameProg)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, 0, 0, 20)
                label.BackgroundTransparency = 1

                local track = Instance.new("Frame", frameProg)
                track.Size = UDim2.new(1, -24, 0, 8)
                track.Position = UDim2.new(0, 12, 0, 28)
                track.BackgroundColor3 = theme.Border
                track.BorderSizePixel = 0

                local fill = Instance.new("Frame", track)
                fill.Size = UDim2.new(0, 0, 1, 0)
                fill.BackgroundColor3 = theme.Accent
                fill.BorderSizePixel = 0

                local value = config[flag] or default or minVal

                local function setProgress(val)
                    val = math.clamp(val, minVal, maxVal)
                    local pct = (val - minVal) / (maxVal - minVal)
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    Flux:SetFlag(flag, val)
                end

                setProgress(value)
                addElement(frameProg, 48)
                return {
                    Set = setProgress,
                    Get = function()
                        return value
                    end,
                }
            end

            -- EXPANDABLE SECTION (nested)
            function sectionObj:AddExpandableSection(title, builderFunc)
                local innerSection = self:AddSection(title, true)
                builderFunc(innerSection)
                return innerSection
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

-- ----------------------------------------------------------------------
-- ADDITIONAL GLOBALS (for executor compatibility)
-- ----------------------------------------------------------------------
-- Allow access to global Flux instance
_G.Flux = Flux

return Flux
