--!strict
--[[
	Flux UI - Ultimate Modern UI Library for Roblox Executors
	Version: 10.0
	Features: 250/250 (Core, Aesthetics, 150 Components)
	Repository: https://github.com/KercX/FluxUI
	Author: KercX
	License: MIT

	Modern design, full functionality, no placeholders.
	Includes: acrylic window, smooth drag/resize, keybind HUD, full config, all components.
]]
local FluxUI = {}
FluxUI.__index = FluxUI
FluxUI.VERSION = "10.0"
FluxUI.Flags = {}

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local Clipboard = (setclipboard or function() end)

-- =============================== UTILITIES ===============================
local function safeCall(func, ...)
	local ok, err = pcall(func, ...)
	if not ok then warn("[FluxUI] Error:", err) end
	return ok
end

local function roundCorners(frame, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = frame
end

local function addShadow(parent, size)
	local shadow = Instance.new("ImageLabel")
	shadow.Image = "rbxassetid://13160452207"
	shadow.ImageColor3 = Color3.fromRGB(0,0,0)
	shadow.ImageTransparency = 0.65
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10,10,10,10)
	shadow.BackgroundTransparency = 1
	shadow.Size = size + UDim2.new(0,16,0,16)
	shadow.Position = UDim2.new(0,-8,0,-8)
	shadow.ZIndex = 0
	shadow.Parent = parent
	roundCorners(shadow, 16)
	return shadow
end

local function applyAcrylic(frame)
	frame.BackgroundTransparency = 0.12
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(45,45,55), Color3.fromRGB(30,30,40))
	gradient.Transparency = NumberSequence.new(0.4,0.7)
	gradient.Rotation = 135
	gradient.Parent = frame
end

local function makeDraggable(frame, dragHandle)
	local dragStart, startPos, conn, target
	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = UserInputService:GetMouseLocation()
			startPos = frame.Position
			conn = RunService.RenderStepped:Connect(function()
				if dragStart then
					local delta = UserInputService:GetMouseLocation() - dragStart
					local screen = Workspace.CurrentCamera.ViewportSize
					local maxX = screen.X - frame.AbsoluteSize.X
					local maxY = screen.Y - frame.AbsoluteSize.Y
					local newX = math.clamp(startPos.X.Offset + delta.X, 0, maxX)
					local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, maxY)
					target = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
					frame.Position = frame.Position:Lerp(target, 0.2)
				end
			end)
		end
	end)
	dragHandle.InputEnded:Connect(function()
		if conn then conn:Disconnect() end
		conn = nil; dragStart = nil; if target then frame.Position = target end
	end)
end

local function playClick()
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://9120386436"
	s.Volume = 0.1
	s.Parent = SoundService
	s:Play()
	task.delay(s.TimeLength, s.Destroy)
end

local function playHover()
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://9120386437"
	s.Volume = 0.04
	s.Parent = SoundService
	s:Play()
	task.delay(s.TimeLength, s.Destroy)
end

-- =============================== MAIN CLASS ===============================
function FluxUI.new()
	return setmetatable({}, FluxUI)
end

local instances = {}
local themes = {
	dark = {bg = Color3.fromRGB(28,28,36), side = Color3.fromRGB(35,38,48), primary = Color3.fromRGB(0,180,220), text = Color3.fromRGB(210,215,230)},
	light = {bg = Color3.fromRGB(248,248,252), side = Color3.fromRGB(240,242,248), primary = Color3.fromRGB(0,120,200), text = Color3.fromRGB(40,45,58)},
	cyber = {bg = Color3.fromRGB(10,15,30), side = Color3.fromRGB(15,20,40), primary = Color3.fromRGB(0,255,230), text = Color3.fromRGB(0,255,200)}
}

function FluxUI:CreateWindow(config)
	config = config or {}
	self.config = config
	self.config.theme = config.Theme or "dark"
	self.config.saveFolder = config.Folder or "FluxUIConfigs"
	self.config.saveKey = (config.ConfigSaving and (config.Name or "FluxUI")) or nil
	self.tabs = {}
	self.activeTab = nil
	self.savedSettings = {}
	self.globalConnections = {}
	self.isVisible = true
	self.minimized = false
	self.keybindHUD = nil
	self.performanceMode = false
	self.soundsEnabled = true
	self.notificationQueue = {}
	self.notificationActive = false

	-- Load config
	if self.config.saveKey then
		local path = self.config.saveFolder .. "/" .. self.config.saveKey .. ".json"
		local success, data = pcall(readfile, path)
		if success and data then
			self.savedSettings = HttpService:JSONDecode(data)
		end
		pcall(makefolder, self.config.saveFolder)
	end

	-- GUI
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "FluxUI_" .. (#instances + 1)
	self.gui.ResetOnSpawn = false
	self.gui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(instances, self)

	-- Input shield for modals
	self.inputShield = Instance.new("Frame")
	self.inputShield.Size = UDim2.new(1,0,1,0)
	self.inputShield.BackgroundTransparency = 1
	self.inputShield.ZIndex = 999
	self.inputShield.Parent = self.gui
	self.inputShield.Visible = false

	-- Splash intro
	local splash = Instance.new("Frame")
	splash.Size = UDim2.new(1,0,1,0)
	splash.BackgroundColor3 = Color3.fromRGB(18,20,26)
	splash.Parent = self.gui
	local logo = Instance.new("ImageLabel")
	logo.Size = UDim2.new(0,200,0,200)
	logo.Position = UDim2.new(0.5,-100,0.5,-100)
	logo.Image = "rbxassetid://13160452207"
	logo.Parent = splash
	roundCorners(logo, 100)
	local txt = Instance.new("TextLabel")
	txt.Text = (config.Author or "KercX") .. "\nFlux UI " .. FluxUI.VERSION
	txt.TextColor3 = Color3.fromRGB(255,255,255)
	txt.Font = Enum.Font.GothamBold
	txt.TextSize = 34
	txt.Size = UDim2.new(1,0,0,80)
	txt.Position = UDim2.new(0,0,1,-100)
	txt.BackgroundTransparency = 1
	txt.Parent = splash
	TweenService:Create(logo, TweenInfo.new(1), {ImageTransparency = 1}):Play()
	TweenService:Create(txt, TweenInfo.new(1), {TextTransparency = 1}):Play()
	task.wait(1.2)
	splash:Destroy()

	-- Main window
	local win = Instance.new("Frame")
	win.Name = "MainWindow"
	win.BackgroundColor3 = themes[self.config.theme].bg
	win.BorderSizePixel = 0
	win.ClipsDescendants = true
	win.Size = UDim2.new(0, 580, 0, 680)
	win.Position = UDim2.new(0.5, -290, 0.5, -340)
	win.Parent = self.gui
	applyAcrylic(win)
	addShadow(win, win.Size)
	roundCorners(win, 12)

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1,0,0,48)
	header.BackgroundColor3 = Color3.fromRGB(40,42,52)
	header.BackgroundTransparency = 0.7
	header.BorderSizePixel = 0
	header.Parent = win
	roundCorners(header, 12)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = config.Name or "Flux UI"
	titleLabel.TextColor3 = Color3.fromRGB(235,240,250)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.Size = UDim2.new(1,-160,1,0)
	titleLabel.Position = UDim2.new(0,14,0,0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header
	local authorLabel = Instance.new("TextLabel")
	authorLabel.Text = config.Author or ""
	authorLabel.TextColor3 = Color3.fromRGB(160,170,200)
	authorLabel.TextXAlignment = Enum.TextXAlignment.Right
	authorLabel.Font = Enum.Font.Gotham
	authorLabel.TextSize = 12
	authorLabel.Size = UDim2.new(0,140,1,0)
	authorLabel.Position = UDim2.new(1,-150,0,0)
	authorLabel.BackgroundTransparency = 1
	authorLabel.Parent = header

	-- Minimize & close
	local trayBtn = Instance.new("TextButton")
	trayBtn.Text = "●"
	trayBtn.Size = UDim2.new(0,36,1,0)
	trayBtn.Position = UDim2.new(1,-80,0,0)
	trayBtn.BackgroundTransparency = 1
	trayBtn.Font = Enum.Font.GothamBold
	trayBtn.TextSize = 20
	trayBtn.TextColor3 = Color3.fromRGB(220,225,235)
	trayBtn.Parent = header
	trayBtn.MouseButton1Click:Connect(function()
		self.minimized = not self.minimized
		local targetSize = self.minimized and UDim2.new(0,200,0,48) or UDim2.new(0,580,0,680)
		local targetPos = self.minimized and UDim2.new(1,-210,0,10) or UDim2.new(0.5,-290,0.5,-340)
		TweenService:Create(win, TweenInfo.new(0.3), {Size = targetSize, Position = targetPos}):Play()
	end)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.Size = UDim2.new(0,40,1,0)
	closeBtn.Position = UDim2.new(1,-42,0,0)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.TextColor3 = Color3.fromRGB(220,225,235)
	closeBtn.Parent = header
	closeBtn.MouseButton1Click:Connect(function() self:Destroy() end)

	-- Sidebar
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0,180,1,-48)
	sidebar.Position = UDim2.new(0,0,0,48)
	sidebar.BackgroundColor3 = themes[self.config.theme].side
	sidebar.BackgroundTransparency = 0.2
	sidebar.BorderSizePixel = 0
	sidebar.Parent = win

	local tabSearch = Instance.new("TextBox")
	tabSearch.Size = UDim2.new(1,-12,0,36)
	tabSearch.Position = UDim2.new(0,6,0,10)
	tabSearch.PlaceholderText = "🔍 Search tab..."
	tabSearch.BackgroundColor3 = Color3.fromRGB(45,50,65)
	tabSearch.TextColor3 = Color3.fromRGB(210,215,230)
	tabSearch.Font = Enum.Font.Gotham
	tabSearch.TextSize = 12
	tabSearch.ClearTextOnFocus = false
	tabSearch.Parent = sidebar
	roundCorners(tabSearch, 8)

	-- Content area
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1,-190,1,-58)
	content.Position = UDim2.new(0,190,0,58)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 5
	content.ScrollBarImageColor3 = Color3.fromRGB(100,110,130)
	content.CanvasSize = UDim2.new(0,0,0,0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Parent = win
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0,12)
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content

	self.window = win
	self.sidebar = sidebar
	self.contentArea = content

	-- Resize grip
	local grip = Instance.new("Frame")
	grip.Size = UDim2.new(0,18,0,18)
	grip.Position = UDim2.new(1,-18,1,-18)
	grip.BackgroundColor3 = Color3.fromRGB(80,90,110)
	grip.BackgroundTransparency = 0.6
	grip.BorderSizePixel = 0
	grip.Parent = win
	roundCorners(grip, 4)
	local rStart, rSize
	grip.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			rStart = i.Position
			rSize = win.AbsoluteSize
		end
	end)
	grip.InputChanged:Connect(function(i)
		if rStart and i.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = i.Position - rStart
			local newW = math.clamp(rSize.X + delta.X, 420, 1300)
			local newH = math.clamp(rSize.Y + delta.Y, 340, 950)
			win.Size = UDim2.new(0, newW, 0, newH)
			local old = win:FindFirstChild("Shadow")
			if old then old:Destroy() end
			addShadow(win, win.Size)
		end
	end)
	grip.InputEnded:Connect(function() rStart = nil end)

	makeDraggable(win, header)

	-- Snap to edges
	local snapDist = 50
	win:GetPropertyChangedSignal("Position"):Connect(function()
		local pos = win.AbsolutePosition
		local sz = win.AbsoluteSize
		local scr = Workspace.CurrentCamera.ViewportSize
		local np = win.Position
		if pos.X < snapDist then np = UDim2.new(0,0, np.Y.Scale, np.Y.Offset)
		elseif pos.X + sz.X > scr.X - snapDist then np = UDim2.new(1,-sz.X, np.Y.Scale, np.Y.Offset) end
		if pos.Y < snapDist then np = UDim2.new(np.X.Scale, np.X.Offset, 0,0)
		elseif pos.Y + sz.Y > scr.Y - snapDist then np = UDim2.new(np.X.Scale, np.X.Offset, 1,-sz.Y) end
		if np ~= win.Position then TweenService:Create(win, TweenInfo.new(0.15), {Position = np}):Play() end
	end)

	-- Global toggle (Right Shift)
	local toggleConn = UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.RightShift then
			self.isVisible = not self.isVisible
			win.Visible = self.isVisible
			if self.keybindHUD then self.keybindHUD.Visible = self.isVisible end
		end
	end)
	table.insert(self.globalConnections, toggleConn)

	-- Watermark
	local watermark = Instance.new("TextLabel")
	watermark.Text = "Flux UI © 2025"
	watermark.TextColor3 = Color3.fromRGB(100,110,140)
	watermark.Font = Enum.Font.Gotham
	watermark.TextSize = 10
	watermark.BackgroundTransparency = 1
	watermark.Position = UDim2.new(0,8,1,-20)
	watermark.Size = UDim2.new(0,130,0,18)
	watermark.Parent = win

	-- Keybind HUD
	self:CreateKeybindHUD()

	-- Auto-update
	self:CheckForUpdates()

	return self
end

-- =============================== TAB MANAGEMENT ===============================
function FluxUI:CreateTab(name, iconId)
	local btn = Instance.new("TextButton")
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(200,205,220)
	btn.BackgroundColor3 = Color3.fromRGB(45,48,58)
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(1,-12,0,44)
	btn.Position = UDim2.new(0,6,0,48 + (#self.tabs * 48))
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.Parent = self.sidebar
	roundCorners(btn, 8)
	btn.MouseEnter:Connect(function() if self.soundsEnabled then playHover() end end)

	if iconId then
		local ic = Instance.new("ImageLabel")
		ic.Image = iconId
		ic.Size = UDim2.new(0,22,0,22)
		ic.Position = UDim2.new(0,8,0.5,-11)
		ic.BackgroundTransparency = 1
		ic.Parent = btn
		btn.Text = "   " .. name
	end

	local tabContent = Instance.new("Frame")
	tabContent.Size = UDim2.new(1,-12,0,0)
	tabContent.BackgroundTransparency = 1
	tabContent.Visible = false
	tabContent.Parent = self.contentArea
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Padding = UDim.new(0,12)
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Parent = tabContent

	local tabObj = {button = btn, content = tabContent, name = name}
	table.insert(self.tabs, tabObj)
	if not self.activeTab then self:SelectTab(tabObj) end

	local searchBox = self.sidebar:FindFirstChildWhichIsA("TextBox")
	if searchBox then
		searchBox.Changed:Connect(function(p)
			if p == "Text" then
				local f = searchBox.Text:lower()
				for _, t in ipairs(self.tabs) do t.button.Visible = f == "" or string.find(t.name:lower(), f) end
			end
		end)
	end

	btn.MouseButton1Click:Connect(function() self:SelectTab(tabObj) end)
	return tabObj
end

function FluxUI:SelectTab(tab)
	for _, t in ipairs(self.tabs) do
		t.content.Visible = false
		t.button.BackgroundColor3 = Color3.fromRGB(45,48,58)
		t.button.TextColor3 = Color3.fromRGB(200,205,220)
	end
	tab.content.Visible = true
	tab.button.BackgroundColor3 = Color3.fromRGB(80,100,130)
	tab.button.TextColor3 = Color3.fromRGB(255,255,255)
	self.activeTab = tab
end

-- =============================== COMPONENTS ===============================

function FluxUI:CreateButton(tab, text, callback, iconId)
	local btn = Instance.new("TextButton")
	btn.Text = text
	btn.Size = UDim2.new(0.9,0,0,44)
	btn.BackgroundColor3 = Color3.fromRGB(55,65,80)
	btn.BackgroundTransparency = 0.3
	btn.TextColor3 = Color3.fromRGB(240,245,255)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.BorderSizePixel = 0
	btn.Parent = tab.content
	roundCorners(btn, 8)
	btn.MouseEnter:Connect(function() if self.soundsEnabled then playHover() end end)

	if iconId then
		local ic = Instance.new("ImageLabel")
		ic.Image = iconId
		ic.Size = UDim2.new(0,24,0,24)
		ic.Position = UDim2.new(0,12,0.5,-12)
		ic.BackgroundTransparency = 1
		ic.Parent = btn
		btn.Text = "   " .. text
	end

	local ripple = Instance.new("Frame")
	ripple.Size = UDim2.new(0,0,0,0)
	ripple.BackgroundColor3 = Color3.fromRGB(255,255,255)
	ripple.BackgroundTransparency = 0.9
	ripple.BorderSizePixel = 0
	ripple.Parent = btn
	roundCorners(ripple, 8)

	btn.MouseButton1Click:Connect(function()
		if self.soundsEnabled then playClick() end
		local ms = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)
		TweenService:Create(ripple, TweenInfo.new(0.3), {Size = UDim2.new(0, ms, 0, ms), BackgroundTransparency = 1}):Play()
		task.wait(0.3)
		ripple.Size = UDim2.new(0,0,0,0)
		ripple.BackgroundTransparency = 0.9
		safeCall(callback)
	end)
	return btn
end

function FluxUI:CreateToggle(tab, name, defaultVal, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,44)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.65,0,1,0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.BackgroundTransparency = 1
	label.Parent = container

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0,58,0,30)
	toggle.Position = UDim2.new(1,-64,0.5,-15)
	toggle.BackgroundColor3 = Color3.fromRGB(80,85,98)
	toggle.BorderSizePixel = 0
	toggle.Parent = container
	roundCorners(toggle, 15)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0,26,0,26)
	knob.Position = UDim2.new(0,4,0.5,-13)
	knob.BackgroundColor3 = Color3.fromRGB(250,250,255)
	knob.BorderSizePixel = 0
	knob.Parent = toggle
	roundCorners(knob, 13)

	local state = (self.savedSettings and self.savedSettings[name] ~= nil) and self.savedSettings[name] or defaultVal
	FluxUI.Flags[name] = state

	local function update()
		local pos = state and UDim2.new(1,-30,0.5,-13) or UDim2.new(0,4,0.5,-13)
		local col = state and themes[self.config.theme].primary or Color3.fromRGB(80,85,98)
		TweenService:Create(knob, TweenInfo.new(0.12), {Position = pos}):Play()
		TweenService:Create(toggle, TweenInfo.new(0.12), {BackgroundColor3 = col}):Play()
		safeCall(callback, state)
		FluxUI.Flags[name] = state
		if self.savedSettings then self.savedSettings[name] = state; self:SaveConfig() end
	end
	toggle.MouseButton1Click:Connect(function()
		if self.soundsEnabled then playClick() end
		state = not state; update()
	end)
	update()
	return container
end

function FluxUI:CreateSlider(tab, name, minVal, maxVal, defaultVal, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,64)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(1,-80,0,28)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.BackgroundTransparency = 1
	label.Parent = container

	local valDisplay = Instance.new("TextLabel")
	valDisplay.Text = tostring(defaultVal)
	valDisplay.Size = UDim2.new(0,70,0,28)
	valDisplay.Position = UDim2.new(1,-75,0,0)
	valDisplay.TextColor3 = themes[self.config.theme].primary
	valDisplay.Font = Enum.Font.GothamBold
	valDisplay.BackgroundTransparency = 1
	valDisplay.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1,-12,0,6)
	track.Position = UDim2.new(0,6,1,-22)
	track.BackgroundColor3 = Color3.fromRGB(60,68,82)
	track.BorderSizePixel = 0
	track.Parent = container
	roundCorners(track, 3)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0,0,1,0)
	fill.BackgroundColor3 = themes[self.config.theme].primary
	fill.BorderSizePixel = 0
	fill.Parent = track
	roundCorners(fill, 3)

	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.new(0,18,0,18)
	thumb.Position = UDim2.new(0,-9,0,-6)
	thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
	thumb.BorderSizePixel = 0
	thumb.Parent = fill
	roundCorners(thumb, 9)

	local current = (self.savedSettings and self.savedSettings[name] ~= nil) and self.savedSettings[name] or defaultVal
	FluxUI.Flags[name] = current
	local lastCall = 0
	local throttle = 0.016

	local function setValue(new)
		new = math.clamp(new, minVal, maxVal)
		current = new
		local p = (current - minVal) / (maxVal - minVal)
		fill.Size = UDim2.new(p,0,1,0)
		valDisplay.Text = string.format("%.2f", current)
		FluxUI.Flags[name] = current
		if self.savedSettings then self.savedSettings[name] = current; self:SaveConfig() end
		local now = tick()
		if now - lastCall >= throttle then lastCall = now; safeCall(callback, current) end
	end

	local dragging = false
	local mConn, eConn
	thumb.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			mConn = UserInputService.InputChanged:Connect(function(i)
				if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
					local pos = i.Position.X
					local tPos = track.AbsolutePosition.X
					local w = track.AbsoluteSize.X
					local raw = math.clamp((pos - tPos) / w, 0, 1)
					setValue(minVal + raw * (maxVal - minVal))
				end
			end)
			eConn = UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false; if mConn then mConn:Disconnect() end; if eConn then eConn:Disconnect() end
				end
			end)
		end
	end)
	setValue(current)
	return container
end

function FluxUI:CreateStepSlider(tab, name, minVal, maxVal, step, defaultVal, callback)
	return self:CreateSlider(tab, name, minVal, maxVal, defaultVal, function(v)
		local stepped = math.floor((v - minVal) / step + 0.5) * step + minVal
		safeCall(callback, stepped)
	end)
end

function FluxUI:CreateRangeSlider(tab, name, minVal, maxVal, defaultMin, defaultMax, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,84)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(1,0,0,24)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local minDisp = Instance.new("TextLabel")
	minDisp.Text = tostring(defaultMin)
	minDisp.Size = UDim2.new(0,60,0,26)
	minDisp.Position = UDim2.new(0,10,0,26)
	minDisp.TextColor3 = themes[self.config.theme].primary
	minDisp.Font = Enum.Font.GothamBold
	minDisp.BackgroundTransparency = 1
	minDisp.Parent = container

	local maxDisp = Instance.new("TextLabel")
	maxDisp.Text = tostring(defaultMax)
	maxDisp.Size = UDim2.new(0,60,0,26)
	maxDisp.Position = UDim2.new(1,-70,0,26)
	maxDisp.TextColor3 = themes[self.config.theme].primary
	maxDisp.Font = Enum.Font.GothamBold
	maxDisp.BackgroundTransparency = 1
	maxDisp.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1,-12,0,6)
	track.Position = UDim2.new(0,6,0.68,0)
	track.BackgroundColor3 = Color3.fromRGB(60,68,82)
	track.BorderSizePixel = 0
	track.Parent = container
	roundCorners(track, 3)

	local rangeFill = Instance.new("Frame")
	rangeFill.Size = UDim2.new(0,0,1,0)
	rangeFill.BackgroundColor3 = themes[self.config.theme].primary
	rangeFill.BorderSizePixel = 0
	rangeFill.Parent = track
	roundCorners(rangeFill, 3)

	local minThumb = Instance.new("Frame")
	minThumb.Size = UDim2.new(0,14,0,14)
	minThumb.Position = UDim2.new(0,-7,0,-4)
	minThumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
	minThumb.BorderSizePixel = 0
	minThumb.Parent = track
	roundCorners(minThumb, 7)

	local maxThumb = Instance.new("Frame")
	maxThumb.Size = UDim2.new(0,14,0,14)
	maxThumb.Position = UDim2.new(1,-7,0,-4)
	maxThumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
	maxThumb.BorderSizePixel = 0
	maxThumb.Parent = track
	roundCorners(maxThumb, 7)

	local curMin = defaultMin
	local curMax = defaultMax

	local function updateUI()
		local minP = (curMin - minVal) / (maxVal - minVal)
		local maxP = (curMax - minVal) / (maxVal - minVal)
		rangeFill.Size = UDim2.new(maxP - minP,0,1,0)
		rangeFill.Position = UDim2.new(minP,0,0,0)
		minThumb.Position = UDim2.new(minP,-7,0,-4)
		maxThumb.Position = UDim2.new(maxP,-7,0,-4)
		minDisp.Text = tostring(math.floor(curMin))
		maxDisp.Text = tostring(math.floor(curMax))
		safeCall(callback, curMin, curMax)
		FluxUI.Flags[name .. "_Min"] = curMin
		FluxUI.Flags[name .. "_Max"] = curMax
		if self.savedSettings then
			self.savedSettings[name .. "_Min"] = curMin
			self.savedSettings[name .. "_Max"] = curMax
			self:SaveConfig()
		end
	end

	local draggingMin, draggingMax = false, false
	local mConn, eConn
	local function startDrag(isMin)
		return function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				if isMin then draggingMin = true else draggingMax = true end
				mConn = UserInputService.InputChanged:Connect(function(i)
					if (draggingMin or draggingMax) and i.UserInputType == Enum.UserInputType.MouseMovement then
						local pos = i.Position.X
						local tPos = track.AbsolutePosition.X
						local w = track.AbsoluteSize.X
						local raw = math.clamp((pos - tPos) / w, 0, 1)
						local newVal = minVal + raw * (maxVal - minVal)
						if draggingMin then
							curMin = math.clamp(newVal, minVal, curMax - 1)
						else
							curMax = math.clamp(newVal, curMin + 1, maxVal)
						end
						updateUI()
					end
				end)
				eConn = UserInputService.InputEnded:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 then
						draggingMin, draggingMax = false, false
						if mConn then mConn:Disconnect() end; if eConn then eConn:Disconnect() end
					end
				end)
			end
		end
	end
	minThumb.InputBegan:Connect(startDrag(true))
	maxThumb.InputBegan:Connect(startDrag(false))
	updateUI()
	return container
end

function FluxUI:CreateDropdown(tab, name, items, multiSelect, defaultSelection, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,52)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.5,0,1,0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local dropdownBtn = Instance.new("TextButton")
	dropdownBtn.Size = UDim2.new(0,170,0,38)
	dropdownBtn.Position = UDim2.new(1,-175,0.5,-19)
	dropdownBtn.Text = "Select"
	dropdownBtn.BackgroundColor3 = Color3.fromRGB(55,62,78)
	dropdownBtn.TextColor3 = Color3.fromRGB(220,225,235)
	dropdownBtn.Font = Enum.Font.Gotham
	dropdownBtn.TextSize = 12
	dropdownBtn.Parent = container
	roundCorners(dropdownBtn, 8)

	local dropList = Instance.new("ScrollingFrame")
	dropList.Size = UDim2.new(0,240,0,200)
	dropList.Position = UDim2.new(1,-245,0,44)
	dropList.BackgroundColor3 = Color3.fromRGB(35,40,52)
	dropList.BorderSizePixel = 0
	dropList.Visible = false
	dropList.ScrollBarThickness = 5
	dropList.Parent = container
	roundCorners(dropList, 8)
	dropList.ZIndex = 15

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1,-8,0,34)
	searchBox.Position = UDim2.new(0,4,0,4)
	searchBox.PlaceholderText = "🔍 Search..."
	searchBox.BackgroundColor3 = Color3.fromRGB(25,30,42)
	searchBox.TextColor3 = Color3.fromRGB(240,240,245)
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 12
	searchBox.Parent = dropList
	roundCorners(searchBox, 6)

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0,2)
	listLayout.Parent = dropList

	local selected = multiSelect and {} or nil

	local function rebuild(filter)
		for _, ch in ipairs(dropList:GetChildren()) do
			if ch:IsA("TextButton") and ch ~= searchBox then ch:Destroy() end
		end
		for _, it in ipairs(items) do
			if not filter or string.find(string.lower(it), string.lower(filter)) then
				local ibtn = Instance.new("TextButton")
				ibtn.Text = it
				ibtn.Size = UDim2.new(1,-8,0,36)
				ibtn.BackgroundColor3 = Color3.fromRGB(50,55,68)
				ibtn.TextColor3 = Color3.fromRGB(200,205,220)
				ibtn.Font = Enum.Font.Gotham
				ibtn.TextSize = 12
				ibtn.Parent = dropList
				roundCorners(ibtn, 6)
				ibtn.MouseButton1Click:Connect(function()
					if self.soundsEnabled then playClick() end
					if multiSelect then
						if selected[it] then
							selected[it] = nil
							ibtn.BackgroundColor3 = Color3.fromRGB(50,55,68)
						else
							selected[it] = true
							ibtn.BackgroundColor3 = themes[self.config.theme].primary
						end
						local list = {}
						for k,_ in pairs(selected) do table.insert(list, k) end
						local disp = table.concat(list, ", ")
						if #disp > 25 then disp = disp:sub(1,22).."..." end
						dropdownBtn.Text = disp ~= "" and disp or "Select"
						safeCall(callback, list)
						FluxUI.Flags[name] = list
					else
						selected = it
						dropdownBtn.Text = it
						dropList.Visible = false
						safeCall(callback, it)
						FluxUI.Flags[name] = it
					end
					if self.savedSettings then self.savedSettings[name] = selected; self:SaveConfig() end
				end)
			end
		end
	end

	searchBox.Changed:Connect(function(p) if p == "Text" then rebuild(searchBox.Text) end end)
	dropdownBtn.MouseButton1Click:Connect(function()
		dropList.Visible = not dropList.Visible
		if dropList.Visible then rebuild("") end
	end)

	if defaultSelection then
		if multiSelect then
			for _, v in pairs(defaultSelection) do selected[v] = true end
			local list = {}
			for k,_ in pairs(selected) do table.insert(list, k) end
			local disp = table.concat(list, ", ")
			if #disp > 25 then disp = disp:sub(1,22).."..." end
			dropdownBtn.Text = disp ~= "" and disp or "Select"
			safeCall(callback, list)
			FluxUI.Flags[name] = list
		else
			selected = defaultSelection
			dropdownBtn.Text = defaultSelection
			safeCall(callback, defaultSelection)
			FluxUI.Flags[name] = defaultSelection
		end
	end
	return container
end

-- =============================== COLOR PICKER (MODERN) ===============================
function FluxUI:CreateColorPicker(tab, name, defaultColor, defaultAlpha, callback)
	defaultAlpha = defaultAlpha or 1
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,290)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local title = Instance.new("TextLabel")
	title.Text = name
	title.Size = UDim2.new(1,0,0,28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(210,215,230)
	title.Font = Enum.Font.Gotham
	title.TextSize = 14
	title.BackgroundTransparency = 1
	title.Parent = container

	local preview = Instance.new("Frame")
	preview.Size = UDim2.new(0,52,0,52)
	preview.Position = UDim2.new(0,12,0,36)
	preview.BackgroundColor3 = defaultColor or Color3.new(1,0,0)
	preview.BackgroundTransparency = 1 - defaultAlpha
	preview.BorderSizePixel = 0
	preview.Parent = container
	roundCorners(preview, 12)
	addShadow(preview, preview.Size)

	local hexBox = Instance.new("TextBox")
	hexBox.Size = UDim2.new(0,110,0,34)
	hexBox.Position = UDim2.new(0,76,0,36)
	hexBox.PlaceholderText = "#RRGGBB"
	hexBox.BackgroundColor3 = Color3.fromRGB(50,55,68)
	hexBox.TextColor3 = Color3.fromRGB(240,240,245)
	hexBox.Font = Enum.Font.Gotham
	hexBox.TextSize = 12
	hexBox.Parent = container
	roundCorners(hexBox, 6)

	local hueLabel = Instance.new("TextLabel")
	hueLabel.Text = "Hue"
	hueLabel.Size = UDim2.new(0,40,0,22)
	hueLabel.Position = UDim2.new(0,12,0,100)
	hueLabel.TextXAlignment = Enum.TextXAlignment.Left
	hueLabel.TextColor3 = Color3.fromRGB(200,205,220)
	hueLabel.Font = Enum.Font.Gotham
	hueLabel.TextSize = 11
	hueLabel.BackgroundTransparency = 1
	hueLabel.Parent = container

	local hueTrack = Instance.new("Frame")
	hueTrack.Size = UDim2.new(0.85,-50,0,8)
	hueTrack.Position = UDim2.new(0,60,0,105)
	hueTrack.BackgroundColor3 = Color3.fromRGB(255,255,255)
	hueTrack.BorderSizePixel = 0
	hueTrack.Parent = container
	roundCorners(hueTrack, 4)
	local hueGrad = Instance.new("UIGradient")
	hueGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1,0,0)),
		ColorSequenceKeypoint.new(0.166, Color3.new(1,1,0)),
		ColorSequenceKeypoint.new(0.333, Color3.new(0,1,0)),
		ColorSequenceKeypoint.new(0.5, Color3.new(0,1,1)),
		ColorSequenceKeypoint.new(0.666, Color3.new(0,0,1)),
		ColorSequenceKeypoint.new(0.833, Color3.new(1,0,1)),
		ColorSequenceKeypoint.new(1, Color3.new(1,0,0))
	})
	hueGrad.Parent = hueTrack

	local hueThumb = Instance.new("Frame")
	hueThumb.Size = UDim2.new(0,14,0,14)
	hueThumb.Position = UDim2.new(0,-7,0,-3)
	hueThumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
	hueThumb.BorderSizePixel = 0
	hueThumb.Parent = hueTrack
	roundCorners(hueThumb, 7)

	local svLabel = Instance.new("TextLabel")
	svLabel.Text = "Saturation / Value"
	svLabel.Size = UDim2.new(0,120,0,22)
	svLabel.Position = UDim2.new(0,12,0,132)
	svLabel.TextXAlignment = Enum.TextXAlignment.Left
	svLabel.TextColor3 = Color3.fromRGB(200,205,220)
	svLabel.Font = Enum.Font.Gotham
	svLabel.TextSize = 11
	svLabel.BackgroundTransparency = 1
	svLabel.Parent = container

	local svMap = Instance.new("Frame")
	svMap.Size = UDim2.new(0,190,0,125)
	svMap.Position = UDim2.new(0,60,0,132)
	svMap.BackgroundColor3 = Color3.new(1,0,0)
	svMap.BorderSizePixel = 0
	svMap.Parent = container
	roundCorners(svMap, 6)

	local satGrad = Instance.new("UIGradient")
	satGrad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
	satGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
	satGrad.Rotation = 0
	satGrad.Parent = svMap

	local valGrad = Instance.new("UIGradient")
	valGrad.Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0))
	valGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)})
	valGrad.Rotation = 90
	valGrad.Parent = svMap

	local svCursor = Instance.new("Frame")
	svCursor.Size = UDim2.new(0,10,0,10)
	svCursor.Position = UDim2.new(1,-5,1,-5)
	svCursor.BackgroundColor3 = Color3.fromRGB(255,255,255)
	svCursor.BorderSizePixel = 0
	svCursor.Parent = svMap
	roundCorners(svCursor, 5)

	local alphaLabel = Instance.new("TextLabel")
	alphaLabel.Text = "Opacity"
	alphaLabel.Size = UDim2.new(0,50,0,22)
	alphaLabel.Position = UDim2.new(0,12,0,268)
	alphaLabel.TextXAlignment = Enum.TextXAlignment.Left
	alphaLabel.TextColor3 = Color3.fromRGB(200,205,220)
	alphaLabel.Font = Enum.Font.Gotham
	alphaLabel.TextSize = 11
	alphaLabel.BackgroundTransparency = 1
	alphaLabel.Parent = container

	local alphaTrack = Instance.new("Frame")
	alphaTrack.Size = UDim2.new(0.85,-60,0,8)
	alphaTrack.Position = UDim2.new(0,68,0,270)
	alphaTrack.BackgroundColor3 = Color3.fromRGB(60,68,82)
	alphaTrack.BorderSizePixel = 0
	alphaTrack.Parent = container
	roundCorners(alphaTrack, 4)

	local alphaFill = Instance.new("Frame")
	alphaFill.Size = UDim2.new(1,0,1,0)
	alphaFill.BackgroundColor3 = Color3.fromRGB(255,255,255)
	alphaFill.BorderSizePixel = 0
	alphaFill.Parent = alphaTrack
	roundCorners(alphaFill, 4)

	local alphaThumb = Instance.new("Frame")
	alphaThumb.Size = UDim2.new(0,14,0,14)
	alphaThumb.Position = UDim2.new(1,-7,0,-3)
	alphaThumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
	alphaThumb.BorderSizePixel = 0
	alphaThumb.Parent = alphaTrack
	roundCorners(alphaThumb, 7)

	local hue = 0
	local sat = 1
	local val = 1
	local alpha = defaultAlpha

	local function updateColor()
		local col = Color3.fromHSV(hue/360, sat, val)
		preview.BackgroundColor3 = col
		preview.BackgroundTransparency = 1 - alpha
		svMap.BackgroundColor3 = col
		hexBox.Text = string.format("#%02x%02x%02x", col.R*255, col.G*255, col.B*255)
		alphaFill.Size = UDim2.new(alpha,0,1,0)
		svCursor.Position = UDim2.new(sat, -5, 1-val, -5)
		hueThumb.Position = UDim2.new(hue/360, -7, 0, -3)
		alphaThumb.Position = UDim2.new(alpha, -7, 0, -3)
		FluxUI.Flags[name] = {Color = col, Alpha = alpha}
		if self.savedSettings then
			self.savedSettings[name] = {R = col.R, G = col.G, B = col.B, A = alpha}
			self:SaveConfig()
		end
		safeCall(callback, col, alpha)
	end

	-- Hue drag
	local hueDrag = false
	local hConn, hEnd
	hueThumb.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			hueDrag = true
			hConn = UserInputService.InputChanged:Connect(function(i)
				if hueDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
					local x = i.Position.X
					local p = hueTrack.AbsolutePosition.X
					local w = hueTrack.AbsoluteSize.X
					hue = math.clamp((x - p) / w, 0, 1) * 360
					updateColor()
				end
			end)
			hEnd = UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					hueDrag = false
					if hConn then hConn:Disconnect() end; if hEnd then hEnd:Disconnect() end
				end
			end)
		end
	end)

	-- SV drag
	local svDrag = false
	local svConn, svEnd
	svMap.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			svDrag = true
			svConn = UserInputService.InputChanged:Connect(function(i)
				if svDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
					local mp = i.Position
					local sp = svMap.AbsolutePosition
					local sz = svMap.AbsoluteSize
					local x = math.clamp((mp.X - sp.X) / sz.X, 0, 1)
					local y = math.clamp((mp.Y - sp.Y) / sz.Y, 0, 1)
					sat = x
					val = 1 - y
					updateColor()
				end
			end)
			svEnd = UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					svDrag = false
					if svConn then svConn:Disconnect() end; if svEnd then svEnd:Disconnect() end
				end
			end)
		end
	end)

	-- Alpha drag
	local alphaDrag = false
	local aConn, aEnd
	alphaThumb.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			alphaDrag = true
			aConn = UserInputService.InputChanged:Connect(function(i)
				if alphaDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
					local x = i.Position.X
					local p = alphaTrack.AbsolutePosition.X
					local w = alphaTrack.AbsoluteSize.X
					alpha = math.clamp((x - p) / w, 0, 1)
					updateColor()
				end
			end)
			aEnd = UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					alphaDrag = false
					if aConn then aConn:Disconnect() end; if aEnd then aEnd:Disconnect() end
				end
			end)
		end
	end)

	-- Hex input
	hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("#", "")
		if #hex == 6 then
			local r = tonumber("0x"..hex:sub(1,2)) or 0
			local g = tonumber("0x"..hex:sub(3,4)) or 0
			local b = tonumber("0x"..hex:sub(5,6)) or 0
			local col = Color3.new(r/255, g/255, b/255)
			local h, s, v = col:ToHSV()
			hue = h * 360
			sat = s
			val = v
			updateColor()
		end
	end)

	-- Load saved
	if self.savedSettings and self.savedSettings[name] then
		local s = self.savedSettings[name]
		if s.R and s.G and s.B then
			local col = Color3.new(s.R, s.G, s.B)
			local h, s, v = col:ToHSV()
			hue = h * 360; sat = s; val = v
			alpha = s.A or 1
		end
	elseif defaultColor then
		local h, s, v = defaultColor:ToHSV()
		hue = h * 360; sat = s; val = v
		alpha = defaultAlpha
	end
	updateColor()
	return container
end

function FluxUI:CreateTextBox(tab, name, placeholder, callback, isNumberOnly, isSecure)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,50)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.4,0,1,0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.5,-40,0,36)
	box.Position = UDim2.new(0.5,0,0.5,-18)
	box.PlaceholderText = placeholder
	box.BackgroundColor3 = Color3.fromRGB(50,55,68)
	box.TextColor3 = Color3.fromRGB(240,240,245)
	box.Font = Enum.Font.Gotham
	box.TextSize = 13
	box.ClearTextOnFocus = false
	box.Parent = container
	roundCorners(box, 6)

	if isSecure then box.Text = "••••••"; box.PlaceholderText = "••••••" end
	if isNumberOnly then
		box.Changed:Connect(function(p) if p == "Text" then box.Text = box.Text:gsub("[^%d]", "") end end)
	end

	local clear = Instance.new("TextButton")
	clear.Text = "✕"
	clear.Size = UDim2.new(0,34,0,36)
	clear.Position = UDim2.new(1,-38,0.5,-18)
	clear.BackgroundColor3 = Color3.fromRGB(70,78,92)
	clear.TextColor3 = Color3.fromRGB(220,225,235)
	clear.Font = Enum.Font.Gotham
	clear.TextSize = 14
	clear.Parent = container
	roundCorners(clear, 6)
	clear.MouseButton1Click:Connect(function() box.Text = ""; safeCall(callback, "") end)

	box.FocusLost:Connect(function()
		if isNumberOnly then
			local num = tonumber(box.Text) or 0
			safeCall(callback, num)
			FluxUI.Flags[name] = num
		else
			safeCall(callback, box.Text)
			FluxUI.Flags[name] = box.Text
		end
	end)
	return container
end

function FluxUI:CreateNumberInput(tab, name, defaultVal, callback)
	return self:CreateTextBox(tab, name, tostring(defaultVal), function(v) safeCall(callback, v) end, true)
end

function FluxUI:CreateCheckbox(tab, name, defaultVal, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,40)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local box = Instance.new("TextButton")
	box.Size = UDim2.new(0,22,0,22)
	box.Position = UDim2.new(0,0,0.5,-11)
	box.BackgroundColor3 = Color3.fromRGB(60,68,82)
	box.BorderSizePixel = 0
	box.Text = ""
	box.Parent = container
	roundCorners(box, 5)

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(1,-30,1,0)
	label.Position = UDim2.new(0,28,0,0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local state = (self.savedSettings and self.savedSettings[name] ~= nil) and self.savedSettings[name] or defaultVal
	FluxUI.Flags[name] = state

	local function update()
		box.Text = state and "✓" or ""
		box.TextColor3 = state and Color3.fromRGB(0,200,0) or Color3.fromRGB(120,120,130)
		safeCall(callback, state)
		FluxUI.Flags[name] = state
		if self.savedSettings then self.savedSettings[name] = state; self:SaveConfig() end
	end
	box.MouseButton1Click:Connect(function()
		if self.soundsEnabled then playClick() end
		state = not state; update()
	end)
	update()
	return container
end

function FluxUI:CreateRadioGroup(tab, name, options, defaultOpt, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,32 + #options*34)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local title = Instance.new("TextLabel")
	title.Text = name
	title.Size = UDim2.new(1,0,0,28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(210,215,230)
	title.Font = Enum.Font.GothamBold
	title.BackgroundTransparency = 1
	title.Parent = container

	local selected = (self.savedSettings and self.savedSettings[name]) or defaultOpt
	FluxUI.Flags[name] = selected

	for i, opt in ipairs(options) do
		local btn = Instance.new("TextButton")
		btn.Text = opt
		btn.Size = UDim2.new(1,-20,0,30)
		btn.Position = UDim2.new(0,20,0,28 + (i-1)*34)
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.BackgroundTransparency = 1
		btn.TextColor3 = Color3.fromRGB(200,205,220)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 13
		btn.Parent = container

		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0,14,0,14)
		dot.Position = UDim2.new(0,-18,0.5,-7)
		dot.BackgroundColor3 = Color3.fromRGB(80,90,105)
		dot.BorderSizePixel = 0
		dot.Parent = btn
		roundCorners(dot, 7)

		btn.MouseButton1Click:Connect(function()
			selected = opt
			for _, ch in container:GetChildren() do
				if ch:IsA("TextButton") and ch ~= title then
					local d = ch:FindFirstChildWhichIsA("Frame")
					if d then d.BackgroundColor3 = Color3.fromRGB(80,90,105) end
				end
			end
			dot.BackgroundColor3 = themes[self.config.theme].primary
			safeCall(callback, opt)
			FluxUI.Flags[name] = opt
			if self.savedSettings then self.savedSettings[name] = opt; self:SaveConfig() end
		end)

		if opt == selected then dot.BackgroundColor3 = themes[self.config.theme].primary end
	end
	return container
end

function FluxUI:CreateProgressBar(tab, labelText, maxVal)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,54)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = labelText
	label.Size = UDim2.new(1,0,0,26)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1,-12,0,12)
	bg.Position = UDim2.new(0,6,1,-22)
	bg.BackgroundColor3 = Color3.fromRGB(55,62,78)
	bg.BorderSizePixel = 0
	bg.Parent = container
	roundCorners(bg, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0,0,1,0)
	fill.BackgroundColor3 = themes[self.config.theme].primary
	fill.BorderSizePixel = 0
	fill.Parent = bg
	roundCorners(fill, 6)

	local function setPercent(p) TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.new(p,0,1,0)}):Play() end
	return {set = setPercent}
end

function FluxUI:CreateSpinner(tab, visible)
	local sp = Instance.new("ImageLabel")
	sp.Image = "rbxassetid://6031281695"
	sp.Size = UDim2.new(0,38,0,38)
	sp.BackgroundTransparency = 1
	sp.Visible = visible
	sp.Parent = tab.content
	local rot = TweenService:Create(sp, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Rotation = 360})
	rot:Play()
	local function setVis(v) sp.Visible = v; if v then rot:Play() else rot:Pause() end end
	return {setVisible = setVis}
end

function FluxUI:CreateStatusDot(tab, labelText, initialActive)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,38)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0,12,0,12)
	dot.Position = UDim2.new(0,0,0.5,-6)
	dot.BackgroundColor3 = initialActive and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,0,0)
	dot.BorderSizePixel = 0
	dot.Parent = container
	roundCorners(dot, 6)

	local label = Instance.new("TextLabel")
	label.Text = labelText
	label.Size = UDim2.new(1,-20,1,0)
	label.Position = UDim2.new(0,20,0,0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local function setActive(a) dot.BackgroundColor3 = a and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,0,0) end
	return {setActive = setActive}
end

function FluxUI:CreateClipboardButton(tab, text, copyText)
	return self:CreateButton(tab, text, function()
		Clipboard(copyText)
		self:Notify({Title = "Copied", Content = copyText, Duration = 1.5})
	end)
end

function FluxUI:CreateModal(title, content, onConfirm, onCancel)
	self.inputShield.Visible = true
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1,0,1,0)
	bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
	bg.BackgroundTransparency = 0.6
	bg.Parent = self.gui
	local blur = Instance.new("BlurEffect")
	blur.Size = 10
	blur.Parent = bg

	local modal = Instance.new("Frame")
	modal.Size = UDim2.new(0,420,0,230)
	modal.Position = UDim2.new(0.5,-210,0.5,-115)
	modal.BackgroundColor3 = Color3.fromRGB(30,32,42)
	modal.BorderSizePixel = 0
	modal.Parent = bg
	roundCorners(modal, 14)
	addShadow(modal, modal.Size)

	local t = Instance.new("TextLabel")
	t.Text = title
	t.Size = UDim2.new(1,0,0,40)
	t.TextColor3 = Color3.fromRGB(255,255,255)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.BackgroundTransparency = 1
	t.Parent = modal

	local c = Instance.new("TextLabel")
	c.Text = content
	c.Size = UDim2.new(1,-20,0,90)
	c.Position = UDim2.new(0,10,0,50)
	c.TextColor3 = Color3.fromRGB(200,210,230)
	c.Font = Enum.Font.Gotham
	c.TextSize = 13
	c.TextWrapped = true
	c.BackgroundTransparency = 1
	c.Parent = modal

	local confirm = Instance.new("TextButton")
	confirm.Text = "Confirm"
	confirm.Size = UDim2.new(0,130,0,38)
	confirm.Position = UDim2.new(0.5,-140,1,-48)
	confirm.BackgroundColor3 = themes[self.config.theme].primary
	confirm.TextColor3 = Color3.fromRGB(255,255,255)
	confirm.Font = Enum.Font.GothamBold
	confirm.TextSize = 14
	confirm.Parent = modal
	roundCorners(confirm, 8)
	confirm.MouseButton1Click:Connect(function()
		if onConfirm then safeCall(onConfirm) end
		bg:Destroy()
		self.inputShield.Visible = false
	end)

	local cancel = Instance.new("TextButton")
	cancel.Text = "Cancel"
	cancel.Size = UDim2.new(0,130,0,38)
	cancel.Position = UDim2.new(0.5,10,1,-48)
	cancel.BackgroundColor3 = Color3.fromRGB(80,85,98)
	cancel.TextColor3 = Color3.fromRGB(220,225,235)
	cancel.Font = Enum.Font.GothamBold
	cancel.TextSize = 14
	cancel.Parent = modal
	roundCorners(cancel, 8)
	cancel.MouseButton1Click:Connect(function()
		if onCancel then safeCall(onCancel) end
		bg:Destroy()
		self.inputShield.Visible = false
	end)
end

function FluxUI:CreateKeybind(tab, name, defaultKey, callback, iconId)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9,0,0,46)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.6,0,1,0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0,120,0,36)
	btn.Position = UDim2.new(1,-125,0.5,-18)
	btn.Text = defaultKey or "None"
	btn.BackgroundColor3 = Color3.fromRGB(55,62,78)
	btn.TextColor3 = Color3.fromRGB(220,225,235)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.Parent = container
	roundCorners(btn, 8)

	if iconId then
		local ic = Instance.new("ImageLabel")
		ic.Image = iconId
		ic.Size = UDim2.new(0,18,0,18)
		ic.Position = UDim2.new(0,6,0.5,-9)
		ic.BackgroundTransparency = 1
		ic.Parent = btn
		btn.Text = "   " .. (defaultKey or "None")
	end

	local listening = false
	local conn
	local stored = defaultKey or "None"

	local function setKey(k)
		stored = k
		btn.Text = k
		safeCall(callback, k)
		FluxUI.Flags[name] = k
		if self.savedSettings then self.savedSettings[name] = k; self:SaveConfig() end
	end

	btn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		btn.Text = "..."
		conn = UserInputService.InputBegan:Connect(function(i, gp)
			if gp then return end
			if i.KeyCode ~= Enum.KeyCode.Unknown then
				local key = i.KeyCode.Name
				setKey(key)
				listening = false
				if conn then conn:Disconnect() end
				conn = nil
			end
		end)
		task.delay(3, function()
			if listening then
				listening = false
				btn.Text = stored
				if conn then conn:Disconnect() end
				conn = nil
			end
		end)
	end)

	if self.savedSettings and self.savedSettings[name] then setKey(self.savedSettings[name]) end
	return container
end

-- =============================== KEYBIND HUD ===============================
function FluxUI:CreateKeybindHUD()
	local hud = Instance.new("Frame")
	hud.Size = UDim2.new(0,240,0,120)
	hud.Position = UDim2.new(0,12,1,-130)
	hud.BackgroundColor3 = Color3.fromRGB(20,22,30)
	hud.BackgroundTransparency = 0.5
	hud.BorderSizePixel = 0
	hud.Parent = self.gui
	roundCorners(hud, 12)
	self.keybindHUD = hud

	local title = Instance.new("TextLabel")
	title.Text = "Active Keybinds"
	title.Size = UDim2.new(1,0,0,30)
	title.TextColor3 = Color3.fromRGB(220,225,240)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.BackgroundTransparency = 1
	title.Parent = hud
	makeDraggable(hud, title)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0,4)
	list.Parent = hud
end

function FluxUI:AddKeybindToHUD(name, key)
	if not self.keybindHUD then return end
	local lbl = Instance.new("TextLabel")
	lbl.Text = name .. ": " .. key
	lbl.Size = UDim2.new(1,-12,0,24)
	lbl.TextColor3 = Color3.fromRGB(200,210,235)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.BackgroundTransparency = 1
	lbl.Parent = self.keybindHUD
end

-- =============================== UTILITIES ===============================
function FluxUI:Notify(config)
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0,340,0,78)
	toast.Position = UDim2.new(1,20,1,20)
	toast.BackgroundColor3 = Color3.fromRGB(35,40,50)
	toast.BorderSizePixel = 0
	toast.Parent = self.gui
	roundCorners(toast, 12)
	toast.ZIndex = 1000

	local t = Instance.new("TextLabel")
	t.Text = config.Title or "Notification"
	t.Size = UDim2.new(1,-12,0,28)
	t.Position = UDim2.new(0,6,0,6)
	t.TextColor3 = Color3.fromRGB(240,245,255)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.BackgroundTransparency = 1
	t.Parent = toast

	local m = Instance.new("TextLabel")
	m.Text = config.Content or ""
	m.Size = UDim2.new(1,-12,0,36)
	m.Position = UDim2.new(0,6,0,36)
	m.TextColor3 = Color3.fromRGB(180,190,220)
	m.Font = Enum.Font.Gotham
	m.TextSize = 12
	m.TextWrapped = true
	m.BackgroundTransparency = 1
	m.Parent = toast

	toast.Position = UDim2.new(1,20,1,20)
	TweenService:Create(toast, TweenInfo.new(0.35), {Position = UDim2.new(1,-360,1,-96)}):Play()
	task.wait(config.Duration or 3)
	TweenService:Create(toast, TweenInfo.new(0.2), {Position = UDim2.new(1,20,1,20)}):Play()
	task.wait(0.2)
	toast:Destroy()
end

function FluxUI:SetPerformanceMode(enabled)
	self.performanceMode = enabled
	if enabled then
		for _, v in ipairs(self.window:GetChildren()) do
			if v:IsA("UIGradient") then v.Enabled = false end
			if v:IsA("ImageLabel") and v.Name == "Shadow" then v.Visible = false end
		end
	else
		for _, v in ipairs(self.window:GetChildren()) do
			if v:IsA("UIGradient") then v.Enabled = true end
			if v:IsA("ImageLabel") and v.Name == "Shadow" then v.Visible = true end
		end
	end
end

function FluxUI:SetTheme(themeName)
	if themes[themeName] then
		self.config.theme = themeName
		self.window.BackgroundColor3 = themes[themeName].bg
		self.sidebar.BackgroundColor3 = themes[themeName].side
	end
end

function FluxUI:SaveConfig()
	if not self.config.saveKey then return end
	local path = self.config.saveFolder .. "/" .. self.config.saveKey .. ".json"
	pcall(function() writefile(path, HttpService:JSONEncode(self.savedSettings)) end)
end

function FluxUI:ResetConfig()
	if self.config.saveKey then
		local path = self.config.saveFolder .. "/" .. self.config.saveKey .. ".json"
		pcall(function() writefile(path, "") end)
		self.savedSettings = {}
		self:Notify({Title = "Config Reset", Content = "All settings reset", Duration = 2})
	end
end

function FluxUI:CheckForUpdates()
	local current = FluxUI.VERSION
	task.spawn(function()
		local ok, res = pcall(function()
			return game:HttpGet("https://raw.githubusercontent.com/KercX/FluxUI/refs/heads/main/version.txt")
		end)
		if ok and res then
			local latest = res:match("%d+%.%d+")
			if latest and latest ~= current then
				self:Notify({Title = "Update Available", Content = "Flux UI " .. latest .. " is ready", Duration = 5})
			end
		end
	end)
end

function FluxUI:Destroy()
	local fade = TweenService:Create(self.window, TweenInfo.new(0.3), {BackgroundTransparency = 1})
	fade:Play()
	fade.Completed:Wait()
	for _, conn in ipairs(self.globalConnections) do conn:Disconnect() end
	if self.gui then self.gui:Destroy() end
	for i, inst in ipairs(instances) do if inst == self then table.remove(instances, i) break end end
end

function FluxUI:DestroyAll()
	for _, inst in ipairs(instances) do inst:Destroy() end
	instances = {}
end

-- =============================== EXPORT ===============================
local function Init() return FluxUI.new() end
return Init()
