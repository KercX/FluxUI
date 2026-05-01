--[[
    FluxUI (Flux) - Complete UI Library with Whitelist, Keybind Mapper, Mobile Support
    Version: 3.1
    Includes:
        - Full UI components (Button, Toggle, Slider, Textbox, Dropdown, Keybind, ColorPicker, etc.)
        - Whitelist system (player list, icons, per‑player color picker, per‑player keybinds, per‑player text)
        - Key name mapping (your custom Keys table)
        - Persistent config
        - Mobile‑optimised
]]

local Flux = {}
Flux.__index = Flux

-- Services
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local isStudio = RunService:IsStudio()
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local screenSize = workspace.CurrentCamera.ViewportSize

-- Mobile scaling
local MOBILE_SCALE = isMobile and 1.4 or 1.0
local isMobile = isMobile

-- Config paths
local configFolder = "FluxUI_Configs"
local configPath = configFolder .. "/data.json"
if writefile and not isfile(configFolder) then makefolder(configFolder) end

-- ========== YOUR KEY MAPPING TABLE ==========
local Keys = {
    ["Unknown"] = "?",
    ["Backspace"] = "Back",
    ["Tab"] = "Tab",
    ["Clear"] = "Clear",
    ["Return"] = "Enter",
    ["Pause"] = "Pause",
    ["Escape"] = "Esc",
    ["Space"] = "Space",
    ["QuotedDouble"] = '"',
    ["Hash"] = "#",
    ["Dollar"] = "$",
    ["Percent"] = "%",
    ["Ampersand"] = "&",
    ["Quote"] = "'",
    ["LeftParenthesis"] = "(",
    ["RightParenthesis"] = ")",
    ["Asterisk"] = "*",
    ["Plus"] = "+",
    ["Comma"] = ",",
    ["Minus"] = "-",
    ["Period"] = ".",
    ["Slash"] = "/",
    ["Three"] = "3",
    ["Seven"] = "7",
    ["Eight"] = "8",
    ["Colon"] = ":",
    ["Semicolon"] = ";",
    ["LessThan"] = "<",
    ["GreaterThan"] = ">",
    ["Question"] = "?",
    ["Equals"] = "=",
    ["At"] = "@",
    ["LeftBracket"] = "[",
    ["RightBracket"] = "]",
    ["BackSlash"] = "\\",
    ["Caret"] = "^",
    ["Underscore"] = "_",
    ["Backquote"] = "`",
    ["LeftCurly"] = "{",
    ["Pipe"] = "|",
    ["RightCurly"] = "}",
    ["Tilde"] = "~",
    ["Delete"] = "Del",
    ["End"] = "End",
    ["KeypadZero"] = "Num0",
    ["KeypadOne"] = "Num1",
    ["KeypadTwo"] = "Num2",
    ["KeypadThree"] = "Num3",
    ["KeypadFour"] = "Num4",
    ["KeypadFive"] = "Num5",
    ["KeypadSix"] = "Num6",
    ["KeypadSeven"] = "Num7",
    ["KeypadEight"] = "Num8",
    ["KeypadNine"] = "Num9",
    ["KeypadPeriod"] = "Num.",
    ["KeypadDivide"] = "Num/",
    ["KeypadMultiply"] = "Num*",
    ["KeypadMinus"] = "Num-",
    ["KeypadPlus"] = "Num+",
    ["KeypadEnter"] = "NumEnter",
    ["KeypadEquals"] = "Num=",
    ["Insert"] = "Ins",
    ["Home"] = "Home",
    ["PageUp"] = "PgUp",
    ["PageDown"] = "PgDn",
    ["RightShift"] = "RShift",
    ["LeftShift"] = "LShift",
    ["RightControl"] = "RCtrl",
    ["LeftControl"] = "LCtrl",
    ["LeftAlt"] = "LAlt",
    ["RightAlt"] = "RAlt"
}

-- Helper to get display name for a key
local function getKeyDisplayName(keyCodeName)
    return Keys[keyCodeName] or keyCodeName
end

-- Whitelist data structure
local whitelistData = {}
local function saveWhitelist()
    if writefile then
        pcall(function() writefile(configPath, HttpService:JSONEncode(whitelistData)) end)
    end
end
local function loadWhitelist()
    if isfile(configPath) then
        local suc, data = pcall(function() return HttpService:JSONDecode(readfile(configPath)) end)
        if suc and type(data) == "table" then
            whitelistData = data
        end
    end
end
loadWhitelist()

-- Utility functions
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

local function rgbToHsv(r,g,b)
    r,g,b = r/255, g/255, b/255
    local max, min = math.max(r,g,b), math.min(r,g,b)
    local h,s,v = max, max, max
    local d = max - min
    s = max == 0 and 0 or d / max
    if max == min then h = 0
    elseif max == r then h = (g - b) / d; if g < b then h = h + 6 end
    elseif max == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    h = h / 6
    return h*360, s, v
end

local function hsvToRgb(h,s,v)
    h = (h % 360) / 360
    local r,g,b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r,g,b = v,t,p
    elseif i == 1 then r,g,b = q,v,p
    elseif i == 2 then r,g,b = p,v,t
    elseif i == 3 then r,g,b = p,q,v
    elseif i == 4 then r,g,b = t,p,v
    else r,g,b = v,p,q end
    return Color3.new(r,g,b)
end

local function deepCopy(t) local c={} for k,v in pairs(t) do if type(v)=="table" then c[k]=deepCopy(v) else c[k]=v end end return c end

local function makeDraggable(frame, handle)
    local drag = { dragging=false, dragStart=nil, frameStart=nil }
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            drag.dragging = true
            drag.dragStart = inp.Position
            drag.frameStart = frame.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then drag.dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag.dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - drag.dragStart
            frame.Position = UDim2.new(drag.frameStart.X.Scale, drag.frameStart.X.Offset+delta.X, drag.frameStart.Y.Scale, drag.frameStart.Y.Offset+delta.Y)
        end
    end)
    return drag
end

local function applyHoverEffect(btn, normal, hover) if isMobile then return end btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3=hover}, 0.1) end) btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3=normal}, 0.1) end) end
local function addRipple(btn) local ripple=Instance.new("Frame", btn) ripple.Size=UDim2.new(0,0,0,0) ripple.Position=UDim2.new(0.5,0,0.5,0) ripple.BackgroundColor3=Color3.new(1,1,1) ripple.BackgroundTransparency=0.7; local corner=Instance.new("UICorner", ripple); corner.CornerRadius=UDim.new(1,0); tween(ripple,{Size=UDim2.new(2,0,2,0), BackgroundTransparency=1},0.3,"Quad","Out"); task.delay(0.3,function() ripple:Destroy() end) end

-- THEMES
local themes = {
    Dark = { Primary=Color3.fromRGB(28,28,32), Secondary=Color3.fromRGB(38,38,44), Accent=Color3.fromRGB(0,122,255), Text=Color3.fromRGB(245,245,245), TextDim=Color3.fromRGB(170,170,180), Border=Color3.fromRGB(58,58,66), Positive=Color3.fromRGB(52,199,89), Negative=Color3.fromRGB(255,69,58), Warning=Color3.fromRGB(255,204,0), AcrylicTransparency=0.85 },
    Light = { Primary=Color3.fromRGB(242,242,247), Secondary=Color3.fromRGB(255,255,255), Accent=Color3.fromRGB(0,122,255), Text=Color3.fromRGB(28,28,30), TextDim=Color3.fromRGB(110,110,120), Border=Color3.fromRGB(200,200,210), Positive=Color3.fromRGB(52,199,89), Negative=Color3.fromRGB(255,69,58), Warning=Color3.fromRGB(255,204,0), AcrylicTransparency=0.7 },
    Ocean = { Primary=Color3.fromRGB(10,30,50), Secondary=Color3.fromRGB(20,50,80), Accent=Color3.fromRGB(0,180,220), Text=Color3.fromRGB(220,240,255), TextDim=Color3.fromRGB(150,190,220), Border=Color3.fromRGB(40,80,120), Positive=Color3.fromRGB(80,220,100), Negative=Color3.fromRGB(255,80,80), Warning=Color3.fromRGB(255,200,50), AcrylicTransparency=0.8 },
    Sunset = { Primary=Color3.fromRGB(50,20,40), Secondary=Color3.fromRGB(80,30,60), Accent=Color3.fromRGB(255,140,60), Text=Color3.fromRGB(255,230,210), TextDim=Color3.fromRGB(220,170,150), Border=Color3.fromRGB(120,60,80), Positive=Color3.fromRGB(100,255,100), Negative=Color3.fromRGB(255,70,70), Warning=Color3.fromRGB(255,220,70), AcrylicTransparency=0.85 },
    Forest = { Primary=Color3.fromRGB(20,40,20), Secondary=Color3.fromRGB(30,60,30), Accent=Color3.fromRGB(100,200,100), Text=Color3.fromRGB(230,250,220), TextDim=Color3.fromRGB(160,200,150), Border=Color3.fromRGB(50,90,50), Positive=Color3.fromRGB(120,255,120), Negative=Color3.fromRGB(255,90,90), Warning=Color3.fromRGB(255,210,80), AcrylicTransparency=0.85 },
}
local currentThemeName = "Dark"
local theme = deepCopy(themes[currentThemeName])

function Flux:RegisterTheme(name, t) if not themes[name] then themes[name]=t; return true end return false end
function Flux:SetTheme(name) if themes[name] then currentThemeName=name; theme=deepCopy(themes[name]); for _,win in pairs(Flux._activeWindows or {}) do if win._refreshTheme then win:_refreshTheme() end end; Flux:Notify("Theme","Switched to "..name,2,"success"); return true end return false end

-- Notifications (mobile)
local notifContainer, notifQueue, activeNotifs = nil, {}, 0
local MAX_VISIBLE = isMobile and 2 or 3
local function createNotifContainer() if notifContainer then return end; notifContainer=Instance.new("Frame"); notifContainer.Name="FluxUI_Notifications"; notifContainer.Size=UDim2.new(0,isMobile and 300 or 340,0,0); notifContainer.Position=UDim2.new(1,-20,0,10); notifContainer.AnchorPoint=Vector2.new(1,0); notifContainer.BackgroundTransparency=1; notifContainer.Parent=CoreGui end
local function processQueue() if activeNotifs>=MAX_VISIBLE then return end; if #notifQueue==0 then return end; local n=table.remove(notifQueue,1); Flux:Notify(n.heading,n.text,n.duration,n.category) end
function Flux:Notify(heading,text,duration,category)
    if activeNotifs>=MAX_VISIBLE then table.insert(notifQueue,{heading=heading,text=text,duration=duration,category=category}); return end
    createNotifContainer()
    local cat=category or "info"
    local color=cat=="success" and theme.Positive or cat=="error" and theme.Negative or cat=="warning" and theme.Warning or theme.Accent
    local notif=Instance.new("Frame")
    local h=isMobile and 80 or 70
    notif.Size=UDim2.new(1,0,0,h)
    notif.Position=UDim2.new(0,0,1,10)
    notif.BackgroundColor3=theme.Secondary
    notif.BorderSizePixel=0
    notif.BackgroundTransparency=0.05
    local corner=Instance.new("UICorner",notif); corner.CornerRadius=UDim.new(0,8)
    local accent=Instance.new("Frame",notif); accent.Size=UDim2.new(0,5,1,0); accent.BackgroundColor3=color
    local titleLbl=Instance.new("TextLabel",notif); titleLbl.Text=heading; titleLbl.Font=Enum.Font.GothamBold; titleLbl.TextSize=isMobile and 15 or 14; titleLbl.TextColor3=theme.Text; titleLbl.BackgroundTransparency=1; titleLbl.Position=UDim2.new(0,16,0,8); titleLbl.Size=UDim2.new(1,-40,0,22); titleLbl.TextXAlignment=Enum.TextXAlignment.Left
    local bodyLbl=Instance.new("TextLabel",notif); bodyLbl.Text=text; bodyLbl.Font=Enum.Font.Gotham; bodyLbl.TextSize=isMobile and 13 or 12; bodyLbl.TextColor3=theme.TextDim; bodyLbl.BackgroundTransparency=1; bodyLbl.Position=UDim2.new(0,16,0,32); bodyLbl.Size=UDim2.new(1,-40,0,38); bodyLbl.TextWrapped=true; bodyLbl.TextYAlignment=Enum.TextYAlignment.Top
    local close=Instance.new("TextButton",notif); close.Size=UDim2.new(0,28,0,28); close.Position=UDim2.new(1,-34,0,8); close.Text="✕"; close.TextColor3=theme.TextDim; close.BackgroundTransparency=1; close.Font=Enum.Font.Gotham; close.TextSize=isMobile and 18 or 16; close.AutoButtonColor=false
    close.MouseButton1Click:Connect(function() tween(notif,{Position=UDim2.new(0,0,1,10), BackgroundTransparency=1},0.2):OnComplete(function() notif:Destroy(); activeNotifs=activeNotifs-1; processQueue() end) end)
    notif.Parent=notifContainer
    tween(notif,{Position=UDim2.new(0,0,1,-h-10), BackgroundTransparency=0},0.3)
    activeNotifs=activeNotifs+1
    if duration and duration>0 then task.delay(duration,function() if notif.Parent then close.MouseButton1Click:Fire() end end) end
end

-- Whitelist API
function Flux:GetWhitelist() return whitelistData end
function Flux:AddToWhitelist(userId, playerName)
    if not whitelistData[userId] then
        whitelistData[userId] = {
            name = playerName,
            color = Color3.new(1,1,1),
            keybinds = {},
            text = "",
            whitelisted = true
        }
        saveWhitelist()
        Flux:Notify("Whitelist", playerName.." added", 2, "success")
        return true
    end
    return false
end
function Flux:RemoveFromWhitelist(userId)
    if whitelistData[userId] then
        whitelistData[userId] = nil
        saveWhitelist()
        Flux:Notify("Whitelist", "User removed", 2, "info")
        return true
    end
    return false
end
function Flux:IsWhitelisted(userId) return whitelistData[userId] and whitelistData[userId].whitelisted or false end
function Flux:SetWhitelistColor(userId, color)
    if whitelistData[userId] then whitelistData[userId].color = color; saveWhitelist() end
end
function Flux:GetWhitelistColor(userId) return whitelistData[userId] and whitelistData[userId].color or Color3.new(1,1,1) end
function Flux:SetWhitelistKeybind(userId, action, key)
    if whitelistData[userId] then
        if not whitelistData[userId].keybinds then whitelistData[userId].keybinds = {} end
        whitelistData[userId].keybinds[action] = key
        saveWhitelist()
    end
end
function Flux:GetWhitelistKeybind(userId, action) return whitelistData[userId] and whitelistData[userId].keybinds and whitelistData[userId].keybinds[action] or nil end
function Flux:SetWhitelistText(userId, text)
    if whitelistData[userId] then whitelistData[userId].text = text; saveWhitelist() end
end
function Flux:GetWhitelistText(userId) return whitelistData[userId] and whitelistData[userId].text or "" end

-- Avatar icon utility
local function getAvatarIcon(userId)
    return "https://www.roblox.com/headshot-thumbnail/image?userId="..userId.."&width=48&height=48&format=png"
end

-- Window class
Flux._activeWindows = {}
local Window = {}
Window.__index = Window

function Flux:CreateWindow(options)
    options = options or {}
    local title = options.Title or "FluxUI"
    local subtitle = options.SubTitle or ""
    local tabWidth = options.TabWidth or (isMobile and 140 or 160)
    local defaultSize = isMobile and UDim2.fromOffset(screenSize.X-40, screenSize.Y-80) or UDim2.fromOffset(700, 550)
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
    if acrylic then local blur=Instance.new("Frame",frame); blur.Size=UDim2.new(1,0,1,0); blur.BackgroundColor3=theme.Primary; blur.BackgroundTransparency=0.6; blur.BorderSizePixel=0; local blurCorner=Instance.new("UICorner",blur); blurCorner.CornerRadius=UDim.new(0,10); blur.Name="BlurOverlay" end

    local headerHeight = isMobile and 60 or 50
    local header = Instance.new("Frame", frame); header.Size=UDim2.new(1,0,0,headerHeight); header.BackgroundColor3=theme.Secondary; header.BackgroundTransparency=acrylic and 0.4 or 0; header.BorderSizePixel=0
    local headerCorner=Instance.new("UICorner",header); headerCorner.CornerRadius=UDim.new(0,10)
    local titleLbl=Instance.new("TextLabel",header); titleLbl.Text=title; titleLbl.Font=Enum.Font.GothamBold; titleLbl.TextSize=isMobile and 20 or 18; titleLbl.TextColor3=theme.Text; titleLbl.BackgroundTransparency=1; titleLbl.Position=UDim2.new(0,14,0,isMobile and 12 or 8); titleLbl.Size=UDim2.new(1,-100,0,26); titleLbl.TextXAlignment=Enum.TextXAlignment.Left
    local subLbl=Instance.new("TextLabel",header); subLbl.Text=subtitle; subLbl.Font=Enum.Font.Gotham; subLbl.TextSize=isMobile and 14 or 12; subLbl.TextColor3=theme.TextDim; subLbl.BackgroundTransparency=1; subLbl.Position=UDim2.new(0,14,0,isMobile and 38 or 30); subLbl.Size=UDim2.new(1,-100,0,18); subLbl.TextXAlignment=Enum.TextXAlignment.Left
    local closeBtn=Instance.new("TextButton",header); closeBtn.Size=UDim2.new(0,40,0,40); closeBtn.Position=UDim2.new(1,-48,0,isMobile and 10 or 5); closeBtn.Text="✕"; closeBtn.TextColor3=theme.TextDim; closeBtn.BackgroundTransparency=1; closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=isMobile and 24 or 20; closeBtn.AutoButtonColor=false
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy(); for i,w in pairs(Flux._activeWindows) do if w==windowObj then table.remove(Flux._activeWindows,i) break end end end)
    makeDraggable(frame,header)

    if resizable then
        local resize=Instance.new("Frame",frame); resize.Size=UDim2.new(0,15,0,15); resize.Position=UDim2.new(1,-15,1,-15); resize.BackgroundColor3=theme.Accent; resize.BackgroundTransparency=0.8; local resizeCorner=Instance.new("UICorner",resize); resizeCorner.CornerRadius=UDim.new(0,3)
        local dragging,startSize,startMouse=false
        resize.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; startSize=frame.Size; startMouse=inp.Position; inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end) end end)
        UserInputService.InputChanged:Connect(function(inp) if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then local delta=inp.Position-startMouse; frame.Size=UDim2.new(0,math.max(400,startSize.X.Offset+delta.X),0,math.max(300,startSize.Y.Offset+delta.Y)) end end)
    end

    local tabsContainer, contentContainer
    if horizontalTabs then
        tabsContainer=Instance.new("ScrollingFrame",frame); tabsContainer.Size=UDim2.new(1,0,0,isMobile and 50 or 40); tabsContainer.Position=UDim2.new(0,0,0,headerHeight); tabsContainer.BackgroundTransparency=1; tabsContainer.ScrollBarThickness=0; tabsContainer.CanvasSize=UDim2.new(0,0,0,0)
        local tabLayout=Instance.new("UIListLayout",tabsContainer); tabLayout.FillDirection=Enum.FillDirection.Horizontal; tabLayout.Padding=UDim.new(0,isMobile and 8 or 4)
        contentContainer=Instance.new("ScrollingFrame",frame); contentContainer.Size=UDim2.new(1,0,1,-headerHeight-(isMobile and 50 or 40)-(isMobile and 10 or 0)); contentContainer.Position=UDim2.new(0,0,0,headerHeight+(isMobile and 50 or 40)); contentContainer.BackgroundTransparency=1; contentContainer.ScrollBarThickness=isMobile and 8 or 6
    else
        tabsContainer=Instance.new("ScrollingFrame",frame); tabsContainer.Size=UDim2.new(0,tabWidth,1,-headerHeight); tabsContainer.Position=UDim2.new(0,0,0,headerHeight); tabsContainer.BackgroundTransparency=1; tabsContainer.ScrollBarThickness=isMobile and 6 or 4; tabsContainer.CanvasSize=UDim2.new(0,0,0,0)
        local tabLayout=Instance.new("UIListLayout",tabsContainer); tabLayout.Padding=UDim.new(0,isMobile and 8 or 6)
        contentContainer=Instance.new("ScrollingFrame",frame); contentContainer.Size=UDim2.new(1,-tabWidth,1,-headerHeight); contentContainer.Position=UDim2.new(0,tabWidth,0,headerHeight); contentContainer.BackgroundTransparency=1; contentContainer.ScrollBarThickness=isMobile and 8 or 6
    end
    contentContainer.CanvasSize=UDim2.new(0,0,0,0)
    local contentLayout=Instance.new("UIListLayout",contentContainer); contentLayout.Padding=UDim.new(0,isMobile and 16 or 12)

    local tabs={}
    local windowObj={_gui=gui,_frame=frame,_header=header,_tabsContainer=tabsContainer,_contentContainer=contentContainer,_tabs=tabs,_horizontal=horizontalTabs,_acrylic=acrylic,_themeName=currentThemeName}
    function windowObj:_refreshTheme() theme=deepCopy(themes[currentThemeName]); frame.BackgroundColor3=theme.Primary; if self._acrylic then frame.BackgroundTransparency=theme.AcrylicTransparency; local blur=frame:FindFirstChild("BlurOverlay"); if blur then blur.BackgroundColor3=theme.Primary end end; header.BackgroundColor3=theme.Secondary; titleLbl.TextColor3=theme.Text; subLbl.TextColor3=theme.TextDim; closeBtn.TextColor3=theme.TextDim; for _,tab in pairs(tabs) do tab._button.BackgroundColor3=theme.Secondary; tab._button.TextColor3=theme.Text; for _,sec in pairs(tab._sections or {}) do sec._sectionFrame.BackgroundColor3=theme.Secondary end end end

    function windowObj:AddTab(tabName)
        local btn
        if horizontalTabs then btn=Instance.new("TextButton",tabsContainer); btn.Size=UDim2.new(0,isMobile and 120 or 100,1,-8); btn.BackgroundColor3=theme.Secondary
        else btn=Instance.new("TextButton",tabsContainer); btn.Size=UDim2.new(1,-12,0,isMobile and 50 or 40); btn.Position=UDim2.new(0,6,0,0); btn.BackgroundColor3=theme.Secondary end
        btn.Text=tabName; btn.TextColor3=theme.Text; btn.Font=Enum.Font.GothamSemibold; btn.TextSize=isMobile and 15 or 14; btn.AutoButtonColor=false
        local btnCorner=Instance.new("UICorner",btn); btnCorner.CornerRadius=UDim.new(0,6)
        applyHoverEffect(btn,theme.Secondary,theme.Accent)

        local tabContent=Instance.new("Frame",contentContainer); tabContent.Size=UDim2.new(1,-20,0,0); tabContent.BackgroundTransparency=1; tabContent.Visible=false
        local tabLayout=Instance.new("UIListLayout",tabContent); tabLayout.Padding=UDim.new(0,isMobile and 20 or 16)

        local tabObj={_button=btn,_content=tabContent,_sections={}}
        btn.MouseButton1Click:Connect(function() for _,t in pairs(tabs) do t._button.BackgroundColor3=theme.Secondary; t._content.Visible=false end; btn.BackgroundColor3=theme.Accent; tabContent.Visible=true; task.defer(function() local total=0; for _,ch in pairs(tabContent:GetChildren()) do if ch:IsA("Frame") then total=total+ch.Size.Y.Offset+(isMobile and 20 or 16) end end; tabContent.Size=UDim2.new(1,-20,0,total); contentContainer.CanvasSize=UDim2.new(0,0,0,total+20) end) end)
        table.insert(tabs,tabObj); if #tabs==1 then btn.MouseButton1Click:Fire() end
        if horizontalTabs then tabsContainer.CanvasSize=UDim2.new(0,#tabs*(isMobile and 128 or 108),0,0) else tabsContainer.CanvasSize=UDim2.new(0,0,0,#tabs*(isMobile and 58 or 46)+10) end

        function tabObj:AddSection(sectionTitle, expandable)
            local sectionFrame=Instance.new("Frame",tabContent); sectionFrame.Size=UDim2.new(1,0,0,0); sectionFrame.BackgroundColor3=theme.Secondary; sectionFrame.BackgroundTransparency=windowObj._acrylic and 0.4 or 0; sectionFrame.BorderSizePixel=0
            local sectionCorner=Instance.new("UICorner",sectionFrame); sectionCorner.CornerRadius=UDim.new(0,8)
            local headerFrame=Instance.new("Frame",sectionFrame); headerFrame.Size=UDim2.new(1,0,0,isMobile and 54 or 44); headerFrame.BackgroundTransparency=1
            local titleLbl=Instance.new("TextLabel",headerFrame); titleLbl.Text=sectionTitle; titleLbl.Font=Enum.Font.GothamBold; titleLbl.TextSize=isMobile and 18 or 16; titleLbl.TextColor3=theme.Text; titleLbl.BackgroundTransparency=1; titleLbl.Position=UDim2.new(0,12,0,isMobile and 12 or 10); titleLbl.Size=UDim2.new(1,-50,0,28); titleLbl.TextXAlignment=Enum.TextXAlignment.Left
            local line=Instance.new("Frame",headerFrame); line.Size=UDim2.new(1,-24,0,1); line.Position=UDim2.new(0,12,0,isMobile and 46 or 38); line.BackgroundColor3=theme.Border
            local elementsContainer=Instance.new("Frame",sectionFrame); elementsContainer.Size=UDim2.new(1,0,0,0); elementsContainer.Position=UDim2.new(0,0,0,isMobile and 54 or 44); elementsContainer.BackgroundTransparency=1
            local elementsLayout=Instance.new("UIListLayout",elementsContainer); elementsLayout.Padding=UDim.new(0,isMobile and 12 or 8)
            local expandBtn=nil
            if expandable then
                expandBtn=Instance.new("TextButton",headerFrame); expandBtn.Size=UDim2.new(0,36,0,36); expandBtn.Position=UDim2.new(1,-44,0,isMobile and 9 or 4); expandBtn.Text="▼"; expandBtn.TextColor3=theme.TextDim; expandBtn.BackgroundTransparency=1; expandBtn.Font=Enum.Font.Gotham; expandBtn.TextSize=isMobile and 22 or 18; expandBtn.AutoButtonColor=false
                local expanded=true
                expandBtn.MouseButton1Click:Connect(function() expanded=not expanded; expandBtn.Text=expanded and "▼" or "▶"; elementsContainer.Visible=expanded; tween(elementsContainer,{Size=UDim2.new(1,0,0,expanded and elementsContainer.Size.Y.Offset or 0)},0.2); task.wait(0.25); refreshHeight() end)
            end
            local sectionObj={_container=elementsContainer,_sectionFrame=sectionFrame,_expandBtn=expandBtn}
            local function refreshHeight()
                local total=0; for _,ch in pairs(elementsContainer:GetChildren()) do if ch:IsA("Frame") or ch:IsA("TextButton") then total=total+ch.Size.Y.Offset+(isMobile and 12 or 8) end end
                elementsContainer.Size=UDim2.new(1,0,0,total)
                sectionFrame.Size=UDim2.new(1,0,0,(isMobile and 54 or 44)+total+(isMobile and 16 or 12))
                task.defer(function() local tabTotal=0; for _,ch in pairs(tabContent:GetChildren()) do if ch:IsA("Frame") then tabTotal=tabTotal+ch.Size.Y.Offset+(isMobile and 20 or 16) end end; tabContent.Size=UDim2.new(1,-20,0,tabTotal); contentContainer.CanvasSize=UDim2.new(0,0,0,tabTotal+20) end)
            end
            local function addElement(elem,height) elem.Parent=elementsContainer; elem.Size=UDim2.new(1,-24,0,height); elem.Position=UDim2.new(0,12,0,0); refreshHeight(); return elem end

            -- Standard UI elements (simplified)
            function sectionObj:AddButton(text,cb) local btn=Instance.new("TextButton"); btn.Text=text; btn.Font=Enum.Font.Gotham; btn.TextSize=isMobile and 16 or 14; btn.TextColor3=theme.Text; btn.BackgroundColor3=theme.Primary; btn.BackgroundTransparency=windowObj._acrylic and 0.5 or 0; btn.AutoButtonColor=false; local corner=Instance.new("UICorner",btn); corner.CornerRadius=UDim.new(0,6); applyHoverEffect(btn,theme.Primary,theme.Accent); btn.MouseButton1Click:Connect(function() addRipple(btn); if cb then pcall(cb) end end); addElement(btn,isMobile and 50 or 36); return btn end
            
            function sectionObj:AddToggle(text,flag,default,cb) local f=Instance.new("Frame"); f.BackgroundTransparency=1; local label=Instance.new("TextLabel",f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 16 or 14; label.TextColor3=theme.Text; label.BackgroundTransparency=1; label.Size=UDim2.new(1,-90,1,0); label.TextXAlignment=Enum.TextXAlignment.Left; local trackW=isMobile and 56 or 44; local trackH=isMobile and 30 or 24; local track=Instance.new("Frame",f); track.Size=UDim2.new(0,trackW,0,trackH); track.Position=UDim2.new(1,-trackW-10,0.5,-trackH/2); track.BackgroundColor3=theme.Border; track.BorderSizePixel=0; local trackCorner=Instance.new("UICorner",track); trackCorner.CornerRadius=UDim.new(1,0); local knobSize=isMobile and 26 or 20; local knob=Instance.new("Frame",track); knob.Size=UDim2.new(0,knobSize,0,knobSize); knob.Position=UDim2.new(0,2,0,(trackH-knobSize)/2); knob.BackgroundColor3=theme.Text; knob.BorderSizePixel=0; local knobCorner=Instance.new("UICorner",knob); knobCorner.CornerRadius=UDim.new(1,0); local state=(whitelistData[flag]~=nil and whitelistData[flag]) or (default or false); local function setState(v) state=v; local targetX=state and (trackW-knobSize-2) or 2; tween(knob,{Position=UDim2.new(0,targetX,0,(trackH-knobSize)/2)},0.15); track.BackgroundColor3=state and theme.Accent or theme.Border; if cb then pcall(cb,state) end; whitelistData[flag]=state; saveWhitelist() end; f.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then setState(not state); addRipple(f) end end); setState(state); addElement(f,isMobile and 56 or 36); return {Set=setState, Get=function() return state end} end

            -- KEYBIND with your Keys mapping
            function sectionObj:AddKeybind(text, flag, defaultKey, callback)
                local f = Instance.new("Frame")
                f.BackgroundTransparency = 1
                local label = Instance.new("TextLabel", f)
                label.Text = text
                label.Font = Enum.Font.Gotham
                label.TextSize = isMobile and 14 or 12
                label.TextColor3 = theme.TextDim
                label.Size = UDim2.new(1, -140, 0, 24)
                label.BackgroundTransparency = 1

                local keyBtn = Instance.new("TextButton", f)
                keyBtn.Size = UDim2.new(0, isMobile and 100 or 80, 0, isMobile and 40 or 32)
                keyBtn.Position = UDim2.new(1, -isMobile and 110 or 90, 0, isMobile and 16 or 20)
                keyBtn.BackgroundColor3 = theme.Primary
                local savedKey = whitelistData[flag] or defaultKey or "None"
                keyBtn.Text = getKeyDisplayName(savedKey)
                keyBtn.TextColor3 = theme.Text
                keyBtn.Font = Enum.Font.GothamBold
                keyBtn.TextSize = isMobile and 15 or 14
                keyBtn.AutoButtonColor = false
                local btnCorner = Instance.new("UICorner", keyBtn)
                btnCorner.CornerRadius = UDim.new(0, 6)

                local listening = false
                local currentKey = savedKey

                keyBtn.MouseButton1Click:Connect(function()
                    if listening then
                        listening = false
                        keyBtn.Text = getKeyDisplayName(currentKey)
                        return
                    end
                    listening = true
                    keyBtn.Text = "..."
                    local conn
                    conn = UserInputService.InputBegan:Connect(function(inp, gp)
                        if gp then return end
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            local key = inp.KeyCode.Name
                            listening = false
                            currentKey = key
                            keyBtn.Text = getKeyDisplayName(key)
                            whitelistData[flag] = key
                            saveWhitelist()
                            if callback then pcall(callback, key) end
                            conn:Disconnect()
                        end
                    end)
                    task.delay(5, function()
                        if listening then
                            listening = false
                            keyBtn.Text = getKeyDisplayName(currentKey)
                            if conn then conn:Disconnect() end
                        end
                    end)
                end)

                addElement(f, isMobile and 80 or 60)
                return {
                    Set = function(k)
                        currentKey = k
                        keyBtn.Text = getKeyDisplayName(k)
                        whitelistData[flag] = k
                        saveWhitelist()
                    end,
                    Get = function() return currentKey end
                }
            end

            -- Simplified placeholder for other elements (Slider, Textbox, Dropdown, ColorPicker)
            function sectionObj:AddSlider(text, flag, minVal, maxVal, default, step, cb) local f=Instance.new("Frame"); f.BackgroundTransparency=1; local label=Instance.new("TextLabel",f); label.Text=text..": "..tostring(default); label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24); label.TextXAlignment=Enum.TextXAlignment.Left; local track=Instance.new("Frame",f); track.Size=UDim2.new(1,-24,0,isMobile and 8 or 4); track.Position=UDim2.new(0,12,0,isMobile and 40 or 30); track.BackgroundColor3=theme.Border; track.BorderSizePixel=0; local fill=Instance.new("Frame",track); fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=theme.Accent; local knobSize=isMobile and 24 or 14; local knob=Instance.new("Frame",track); knob.Size=UDim2.new(0,knobSize,0,knobSize); knob.Position=UDim2.new(0,-knobSize/2,0,-(knobSize-track.Size.Y.Offset)/2); knob.BackgroundColor3=theme.Text; local knobCorner=Instance.new("UICorner",knob); knobCorner.CornerRadius=UDim.new(1,0); local value=whitelistData[flag] or default or minVal; local function update(v) v=math.clamp(v,minVal,maxVal); if step then v=math.floor(v/step+0.5)*step end; value=v; local pct=(value-minVal)/(maxVal-minVal); fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,-knobSize/2,0,-(knobSize-track.Size.Y.Offset)/2); label.Text=text..": "..tostring(value); if cb then pcall(cb,value) end; whitelistData[flag]=value; saveWhitelist() end; local dragging=false; knob.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=true end end); UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end end); UserInputService.InputChanged:Connect(function(inp) if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then local pos=inp.Position.X-track.AbsolutePosition.X; local pct=math.clamp(pos/track.AbsoluteSize.X,0,1); local v=minVal+(maxVal-minVal)*pct; if step then v=math.floor(v/step+0.5)*step end; update(v) end end); update(value); addElement(f,isMobile and 70 or 48); return {Set=update, Get=function() return value end} end

            function sectionObj:AddTextbox(text, flag, placeholder, cb) local f=Instance.new("Frame"); f.BackgroundTransparency=1; local label=Instance.new("TextLabel",f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24); label.TextXAlignment=Enum.TextXAlignment.Left; local box=Instance.new("TextBox",f); box.Size=UDim2.new(1,-24,0,isMobile and 40 or 30); box.Position=UDim2.new(0,12,0,isMobile and 30 or 24); box.BackgroundColor3=theme.Primary; box.TextColor3=theme.Text; box.Font=Enum.Font.Gotham; box.TextSize=isMobile and 16 or 14; box.PlaceholderText=placeholder or ""; box.Text=whitelistData[flag] or ""; box.ClearTextOnFocus=false; local corner=Instance.new("UICorner",box); corner.CornerRadius=UDim.new(0,6); box.FocusLost:Connect(function() local val=box.Text; whitelistData[flag]=val; saveWhitelist(); if cb then pcall(cb,val) end end); addElement(f,isMobile and 80 or 60); return {Set=function(t) box.Text=t; whitelistData[flag]=t; saveWhitelist() end, Get=function() return box.Text end} end

            function sectionObj:AddDropdown(text, flag, options, default, cb) local f=Instance.new("Frame"); f.BackgroundTransparency=1; local label=Instance.new("TextLabel",f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24); local select=Instance.new("TextButton",f); select.Size=UDim2.new(1,-24,0,isMobile and 44 or 32); select.Position=UDim2.new(0,12,0,isMobile and 30 or 24); select.BackgroundColor3=theme.Primary; select.Text=default or options[1] or ""; select.TextColor3=theme.Text; select.Font=Enum.Font.Gotham; select.TextSize=isMobile and 16 or 14; select.AutoButtonColor=false; local btnCorner=Instance.new("UICorner",select); btnCorner.CornerRadius=UDim.new(0,6); local open=false; local dropFrame=nil; select.MouseButton1Click:Connect(function() if open then dropFrame:Destroy(); open=false; return end; dropFrame=Instance.new("ScrollingFrame",f); local dropH=math.min(150, #options*(isMobile and 48 or 32)+10); dropFrame.Size=UDim2.new(1,-24,0,dropH); dropFrame.Position=UDim2.new(0,12,0,isMobile and 80 or 60); dropFrame.BackgroundColor3=theme.Secondary; dropFrame.ScrollBarThickness=isMobile and 8 or 4; local dropCorner=Instance.new("UICorner",dropFrame); dropCorner.CornerRadius=UDim.new(0,6); local layout=Instance.new("UIListLayout",dropFrame); layout.Padding=UDim.new(0,isMobile and 4 or 2); for _,opt in ipairs(options) do local optBtn=Instance.new("TextButton",dropFrame); optBtn.Size=UDim2.new(1,-8,0,isMobile and 44 or 30); optBtn.Position=UDim2.new(0,4,0,0); optBtn.Text=opt; optBtn.TextColor3=theme.Text; optBtn.BackgroundColor3=theme.Primary; optBtn.Font=Enum.Font.Gotham; optBtn.TextSize=isMobile and 15 or 13; optBtn.AutoButtonColor=false; local optCorner=Instance.new("UICorner",optBtn); optCorner.CornerRadius=UDim.new(0,4); optBtn.MouseButton1Click:Connect(function() select.Text=opt; whitelistData[flag]=opt; saveWhitelist(); if cb then pcall(cb,opt) end; dropFrame:Destroy(); open=false end); applyHoverEffect(optBtn,theme.Primary,theme.Accent) end; dropFrame.CanvasSize=UDim2.new(0,0,0,#options*(isMobile and 48 or 32)); open=true end); addElement(f,isMobile and 110 or 90); return {Set=function(opt) select.Text=opt; whitelistData[flag]=opt; saveWhitelist() end, Get=function() return select.Text end} end

            -- ColorPicker (simplified)
            function sectionObj:AddColorPicker(text, flag, defaultColor, cb) local f=Instance.new("Frame"); f.BackgroundTransparency=1; local label=Instance.new("TextLabel",f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,-80,0,24); local preview=Instance.new("Frame",f); preview.Size=UDim2.new(0,isMobile and 50 or 40,0,isMobile and 38 or 30); preview.Position=UDim2.new(1,-isMobile and 60 or 50,0,isMobile and 16 or 16); preview.BackgroundColor3=defaultColor; preview.BorderSizePixel=0; local previewCorner=Instance.new("UICorner",preview); previewCorner.CornerRadius=UDim.new(0,6); local pickerBtn=Instance.new("TextButton",f); pickerBtn.Size=UDim2.new(0,isMobile and 70 or 60,0,isMobile and 38 or 30); pickerBtn.Position=UDim2.new(1,-isMobile and 130 or 120,0,isMobile and 16 or 16); pickerBtn.Text="Pick"; pickerBtn.BackgroundColor3=theme.Accent; pickerBtn.TextColor3=theme.Text; pickerBtn.Font=Enum.Font.Gotham; pickerBtn.TextSize=isMobile and 15 or 13; pickerBtn.AutoButtonColor=false; local btnCorner=Instance.new("UICorner",pickerBtn); btnCorner.CornerRadius=UDim.new(0,6); local currentColor=defaultColor; local open=false; local pickerFrame=nil; pickerBtn.MouseButton1Click:Connect(function() if open then pickerFrame:Destroy(); open=false; return end; pickerFrame=Instance.new("Frame",f); pickerFrame.Size=UDim2.new(0,isMobile and 260 or 200,0,isMobile and 220 or 180); pickerFrame.Position=UDim2.new(1,-isMobile and 270 or 210,0,isMobile and 70 or 52); pickerFrame.BackgroundColor3=theme.Secondary; local pickerCorner=Instance.new("UICorner",pickerFrame); pickerCorner.CornerRadius=UDim.new(0,8); local hexBox=Instance.new("TextBox",pickerFrame); hexBox.Size=UDim2.new(0.8,0,0,isMobile and 40 or 30); hexBox.Position=UDim2.new(0.1,0,0.1,0); hexBox.Text=color3ToHex(currentColor); hexBox.BackgroundColor3=theme.Primary; hexBox.TextColor3=theme.Text; hexBox.Font=Enum.Font.Gotham; hexBox.TextSize=isMobile and 16 or 14; local applyBtn=Instance.new("TextButton",pickerFrame); applyBtn.Size=UDim2.new(0.8,0,0,isMobile and 40 or 30); applyBtn.Position=UDim2.new(0.1,0,0.4,0); applyBtn.Text="Apply"; applyBtn.BackgroundColor3=theme.Accent; applyBtn.TextColor3=theme.Text; applyBtn.Font=Enum.Font.Gotham; applyBtn.TextSize=isMobile and 16 or 14; applyBtn.AutoButtonColor=false; local applyCorner=Instance.new("UICorner",applyBtn); applyCorner.CornerRadius=UDim.new(0,6); applyBtn.MouseButton1Click:Connect(function() local newColor=hexToColor3(hexBox.Text); currentColor=newColor; preview.BackgroundColor3=currentColor; whitelistData[flag]=currentColor; saveWhitelist(); if cb then pcall(cb,currentColor) end; pickerFrame:Destroy(); open=false end); open=true end); addElement(f,isMobile and 80 or 60); return {Set=function(c) currentColor=c; preview.BackgroundColor3=c; whitelistData[flag]=c; saveWhitelist() end, Get=function() return currentColor end} end

            function sectionObj:AddParagraph(text) local para=Instance.new("TextLabel"); para.Text=text; para.TextWrapped=true; para.TextXAlignment=Enum.TextXAlignment.Left; para.TextYAlignment=Enum.TextYAlignment.Top; para.Font=Enum.Font.Gotham; para.TextSize=isMobile and 15 or 13; para.TextColor3=theme.TextDim; para.BackgroundColor3=theme.Primary; para.BackgroundTransparency=0.3; local corner=Instance.new("UICorner",para); corner.CornerRadius=UDim.new(0,6); addElement(para,isMobile and 80 or 60); return para end
            function sectionObj:AddSeparator() local sep=Instance.new("Frame"); sep.Size=UDim2.new(1,-24,0,isMobile and 4 or 2); sep.BackgroundColor3=theme.Border; sep.BorderSizePixel=0; addElement(sep,isMobile and 12 or 8); return sep end
            function sectionObj:AddRadioGroup(text,flag,options,default,cb) local f=Instance.new("Frame"); f.BackgroundTransparency=1; local label=Instance.new("TextLabel",f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24); local selected=whitelistData[flag] or default or options[1]; local y=isMobile and 30 or 24; local btns={}; for i,opt in ipairs(options) do local btn=Instance.new("TextButton",f); btn.Size=UDim2.new(0.5,-16,0,isMobile and 40 or 30); btn.Position=UDim2.new((i-1)*0.5+0.02,0,0,y); btn.Text=opt; btn.BackgroundColor3=(opt==selected) and theme.Accent or theme.Primary; btn.TextColor3=theme.Text; btn.Font=Enum.Font.Gotham; btn.TextSize=isMobile and 15 or 13; btn.AutoButtonColor=false; local btnCorner=Instance.new("UICorner",btn); btnCorner.CornerRadius=UDim.new(0,6); btn.MouseButton1Click:Connect(function() selected=opt; for _,b in pairs(btns) do b.BackgroundColor3=(b.Text==opt) and theme.Accent or theme.Primary end; whitelistData[flag]=opt; saveWhitelist(); if cb then pcall(cb,opt) end end); table.insert(btns,btn) end; addElement(f,isMobile and 80 or 60); return {Get=function() return selected end} end
            function sectionObj:AddProgressBar(text,flag,minVal,maxVal,default) local f=Instance.new("Frame"); f.BackgroundTransparency=1; local label=Instance.new("TextLabel",f); label.Text=text; label.Font=Enum.Font.Gotham; label.TextSize=isMobile and 14 or 12; label.TextColor3=theme.TextDim; label.Size=UDim2.new(1,0,0,24); local track=Instance.new("Frame",f); track.Size=UDim2.new(1,-24,0,isMobile and 12 or 8); track.Position=UDim2.new(0,12,0,isMobile and 32 or 28); track.BackgroundColor3=theme.Border; track.BorderSizePixel=0; local fill=Instance.new("Frame",track); fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=theme.Accent; local value=whitelistData[flag] or default or minVal; local function setProgress(v) v=math.clamp(v,minVal,maxVal); local pct=(v-minVal)/(maxVal-minVal); fill.Size=UDim2.new(pct,0,1,0); whitelistData[flag]=v; saveWhitelist() end; setProgress(value); addElement(f,isMobile and 70 or 48); return {Set=setProgress, Get=function() return value end} end
            function sectionObj:AddExpandableSection(title,builder) local inner=self:AddSection(title,true); builder(inner); return inner end

            -- WHITELIST PANEL (Player list with icons)
            function sectionObj:AddWhitelistPanel()
                local panel = Instance.new("Frame")
                panel.Size = UDim2.new(1, -24, 0, isMobile and 400 or 350)
                panel.BackgroundColor3 = theme.Primary
                panel.BackgroundTransparency = 0.3
                local panelCorner = Instance.new("UICorner", panel)
                panelCorner.CornerRadius = UDim.new(0, 8)

                local scroll = Instance.new("ScrollingFrame", panel)
                scroll.Size = UDim2.new(1, -20, 1, -40)
                scroll.Position = UDim2.new(0, 10, 0, 10)
                scroll.BackgroundTransparency = 1
                scroll.ScrollBarThickness = isMobile and 8 or 6
                scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

                local listLayout = Instance.new("UIListLayout", scroll)
                listLayout.Padding = UDim.new(0, 8)

                local function refreshPlayerList()
                    for _, child in pairs(scroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
                    local players = Players:GetPlayers()
                    local yOffset = 0
                    for _, plr in ipairs(players) do
                        if plr ~= LocalPlayer then
                            local userId = plr.UserId
                            local isWhitelisted = Flux:IsWhitelisted(userId)
                            local plrColor = Flux:GetWhitelistColor(userId)

                            local row = Instance.new("Frame", scroll)
                            row.Size = UDim2.new(1, 0, 0, isMobile and 70 or 60)
                            row.BackgroundColor3 = theme.Secondary
                            row.BackgroundTransparency = 0.2
                            local rowCorner = Instance.new("UICorner", row)
                            rowCorner.CornerRadius = UDim.new(0, 6)

                            local icon = Instance.new("ImageLabel", row)
                            icon.Size = UDim2.new(0, isMobile and 50 or 40, 0, isMobile and 50 or 40)
                            icon.Position = UDim2.new(0, 8, 0.5, - (isMobile and 25 or 20))
                            icon.Image = getAvatarIcon(userId)
                            icon.BackgroundColor3 = theme.Border
                            local iconCorner = Instance.new("UICorner", icon)
                            iconCorner.CornerRadius = UDim.new(1, 0)

                            local nameLbl = Instance.new("TextLabel", row)
                            nameLbl.Text = plr.Name
                            nameLbl.Font = Enum.Font.GothamBold
                            nameLbl.TextSize = isMobile and 16 or 14
                            nameLbl.TextColor3 = isWhitelisted and plrColor or theme.TextDim
                            nameLbl.BackgroundTransparency = 1
                            nameLbl.Position = UDim2.new(0, isMobile and 70 or 56, 0, isMobile and 10 or 8)
                            nameLbl.Size = UDim2.new(0.4, 0, 0, 24)
                            nameLbl.TextXAlignment = Enum.TextXAlignment.Left

                            local whitelistBtn = Instance.new("TextButton", row)
                            whitelistBtn.Size = UDim2.new(0, isMobile and 80 or 70, 0, isMobile and 40 or 34)
                            whitelistBtn.Position = UDim2.new(0.5, - (isMobile and 40 or 35), 0.5, - (isMobile and 20 or 17))
                            whitelistBtn.Text = isWhitelisted and "★ Whitelisted" or "☆ Add"
                            whitelistBtn.BackgroundColor3 = isWhitelisted and theme.Accent or theme.Primary
                            whitelistBtn.TextColor3 = theme.Text
                            whitelistBtn.Font = Enum.Font.Gotham
                            whitelistBtn.TextSize = isMobile and 12 or 11
                            local btnCorner = Instance.new("UICorner", whitelistBtn)
                            btnCorner.CornerRadius = UDim.new(0, 6)

                            whitelistBtn.MouseButton1Click:Connect(function()
                                if isWhitelisted then
                                    Flux:RemoveFromWhitelist(userId)
                                    isWhitelisted = false
                                    whitelistBtn.Text = "☆ Add"
                                    whitelistBtn.BackgroundColor3 = theme.Primary
                                    nameLbl.TextColor3 = theme.TextDim
                                else
                                    Flux:AddToWhitelist(userId, plr.Name)
                                    isWhitelisted = true
                                    whitelistBtn.Text = "★ Whitelisted"
                                    whitelistBtn.BackgroundColor3 = theme.Accent
                                    nameLbl.TextColor3 = plrColor
                                end
                                refreshPlayerList()
                            end)

                            if isWhitelisted then
                                local colorBtn = Instance.new("TextButton", row)
                                colorBtn.Size = UDim2.new(0, isMobile and 50 or 40, 0, isMobile and 36 or 30)
                                colorBtn.Position = UDim2.new(0.8, 0, 0.5, - (isMobile and 18 or 15))
                                colorBtn.Text = "🎨"
                                colorBtn.TextColor3 = theme.Text
                                colorBtn.BackgroundColor3 = plrColor
                                colorBtn.Font = Enum.Font.Gotham
                                colorBtn.TextSize = isMobile and 16 or 14
                                local colorCorner = Instance.new("UICorner", colorBtn)
                                colorCorner.CornerRadius = UDim.new(0, 6)
                                colorBtn.MouseButton1Click:Connect(function()
                                    local newColor = Color3.new(math.random(), math.random(), math.random())
                                    Flux:SetWhitelistColor(userId, newColor)
                                    colorBtn.BackgroundColor3 = newColor
                                    nameLbl.TextColor3 = newColor
                                    Flux:Notify("Color", "Updated color for "..plr.Name, 2, "info")
                                end)
                            end

                            row.Parent = scroll
                            yOffset = yOffset + (isMobile and 78 or 68)
                        end
                    end
                    scroll.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
                end

                refreshPlayerList()
                Players.PlayerAdded:Connect(refreshPlayerList)
                Players.PlayerRemoving:Connect(refreshPlayerList)

                addElement(panel, isMobile and 420 or 380)
                return panel
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
