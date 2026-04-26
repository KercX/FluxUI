--!strict
--[[
	FluxUI - Advanced Roblox UI Library for Executors
	Version: 8.0
	Repository: https://github.com/KercX/FluxUI
	Author: KercX / 
	License: MIT (watermark required)
]]
local FluxUI = {}
FluxUI.__index = FluxUI
FluxUI.VERSION = "8.0"
FluxUI.Flags = {}			-- Flag system
FluxUI.Signals = {}			-- Custom event signals

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local LocalizationService = game:GetService("LocalizationService")
local GuiService = game:GetService("GuiService")
local Clipboard = (setclipboard or function() end)

-- =============================== UTILITIES ===============================
local function safeCall(func, ...)
	local ok, res = pcall(func, ...)
	if not ok then warn("[FluxUI] Callback error:", res) end
	return ok, res
end

local function roundCorners(frame, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = frame
end

local function applyPadding(frame, padding)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, padding or 12)
	pad.PaddingRight = UDim.new(0, padding or 12)
	pad.PaddingTop = UDim.new(0, padding or 12)
	pad.PaddingBottom = UDim.new(0, padding or 12)
	pad.Parent = frame
end

-- Smooth draggable (with boundary)
local function makeDraggable(frame, dragHandle, lerpSpeed)
	lerpSpeed = lerpSpeed or 0.2
	local dragStart = nil
	local startPos = nil
	local connection = nil
	local targetPos = nil
	local screenSize = Workspace.CurrentCamera.ViewportSize

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = UserInputService:GetMouseLocation()
			startPos = frame.Position
			if connection then connection:Disconnect() end
			connection = RunService.RenderStepped:Connect(function()
				if dragStart then
					local delta = UserInputService:GetMouseLocation() - dragStart
					local newX = startPos.X.Offset + delta.X
					local newY = startPos.Y.Offset + delta.Y
					-- boundary clamp
					local maxX = screenSize.X - frame.AbsoluteSize.X
					local maxY = screenSize.Y - frame.AbsoluteSize.Y
					newX = math.clamp(newX, 0, maxX)
					newY = math.clamp(newY, 0, maxY)
					targetPos = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
					frame.Position = frame.Position:Lerp(targetPos, lerpSpeed)
				end
			end)
		end
	end)

	dragHandle.InputEnded:Connect(function()
		if connection then connection:Disconnect() end
		connection = nil
		dragStart = nil
		if targetPos then frame.Position = targetPos end
	end)
end

-- Acrylic blur + glassmorphism
local function applyAcrylic(frame, intensity)
	intensity = intensity or 12
	frame.BackgroundTransparency = 0.15
	local blurOverlay = Instance.new("ImageLabel")
	blurOverlay.Size = UDim2.new(1, 0, 1, 0)
	blurOverlay.Image = "rbxassetid://13160452207"
	blurOverlay.ImageTransparency = 0.6
	blurOverlay.BackgroundTransparency = 1
	blurOverlay.ZIndex = -1
	blurOverlay.Parent = frame
end

local function addShadow(parent, size)
	local shadow = Instance.new("ImageLabel")
	shadow.Image = "rbxassetid://13160452207"
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.7
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 10, 10)
	shadow.BackgroundTransparency = 1
	shadow.Size = size + UDim2.new(0, 16, 0, 16)
	shadow.Position = UDim2.new(0, -8, 0, -8)
	shadow.ZIndex = 0
	shadow.Parent = parent
	roundCorners(shadow, 16)
	return shadow
end

-- Custom scrollbar (modern)
local function setupScrollbar(scrollFrame)
	scrollFrame.ScrollBarThickness = 5
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 110, 130)
	scrollFrame.ScrollBarImageTransparency = 0.5
    scrollFrame.ElasticBehavior = Enum.ElasticBehavior.Never
end

-- Sound effects
local function playClick()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9120386436"
	sound.Volume = 0.1
	sound.Parent = SoundService
	sound:Play()
	task.delay(sound.TimeLength, function() sound:Destroy() end)
end

local function playHover()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9120386437"
	sound.Volume = 0.05
	sound.Parent = SoundService
	sound:Play()
	task.delay(sound.TimeLength, function() sound:Destroy() end)
end

-- Tooltip
local function attachTooltip(parent, text)
	local tip = Instance.new("TextLabel")
	tip.Text = text
	tip.TextColor3 = Color3.fromRGB(255, 255, 255)
	tip.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	tip.BorderSizePixel = 0
	tip.TextSize = 11
	tip.Font = Enum.Font.Gotham
	tip.Size = UDim2.new(0, 150, 0, 24)
	tip.Visible = false
	tip.ZIndex = 10
	tip.Parent = parent
	parent.MouseEnter:Connect(function()
		local pos = parent.AbsolutePosition
		tip.Position = UDim2.new(0, pos.X - 160, 0, pos.Y - 10)
		tip.Visible = true
	end)
	parent.MouseLeave:Connect(function() tip.Visible = false end)
	return tip
end

-- =============================== MAIN CLASS ===============================
function FluxUI.new()
	return setmetatable({}, FluxUI)
end

local instances = {}
local defaultTheme = {
	background = Color3.fromRGB(28, 28, 36),
	sidebar = Color3.fromRGB(35, 38, 48),
	primary = Color3.fromRGB(0, 180, 220),
	text = Color3.fromRGB(210, 215, 230),
	textDark = Color3.fromRGB(40, 45, 58),
	button = Color3.fromRGB(60, 68, 82),
	accent = "aqua"
}

function FluxUI:CreateWindow(config)
	config = config or {}
	self.config = config
	self.config.theme = config.Theme or "dark"
	self.config.accent = config.Accent or "aqua"
	self.config.saveFolder = config.Folder or "FluxUIConfigs"
	self.config.saveKey = (config.ConfigSaving and (config.Name or "FluxUI_Window")) or nil
	self.tabs = {}
	self.activeTab = nil
	self.savedSettings = {}
	self.flags = {}
	self.globalConnections = {}
	self.isVisible = true
	self.minimized = false
	self.mobileToggle = nil
	self.keybindHUD = nil
	self.performanceMode = false
	self.notificationQueue = {}
	self.notificationActive = false

	-- Load config
	if self.config.saveKey then
		local path = self.config.saveFolder .. "/" .. self.config.saveKey .. ".json"
		local success, data = pcall(readfile, path)
		if success and data then
			self.savedSettings = HttpService:JSONDecode(data)
		end
		pcall(function() makefolder(self.config.saveFolder) end)
	end

	-- Detect device
	self.deviceType = "PC"
	local platform = UserInputService:GetPlatform()
	if platform == Enum.Platform.Android or platform == Enum.Platform.IOS then
		self.deviceType = "Mobile"
		-- larger touch targets
	elseif GuiService:IsTenFootInterface() then
		self.deviceType = "Console"
	end

	-- GUI
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "FluxUI_" .. (#instances + 1)
	self.gui.ResetOnSpawn = false
	self.gui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(instances, self)

	-- Input shield (for blocking game input)
	self.inputShield = Instance.new("Frame")
	self.inputShield.Size = UDim2.new(1, 0, 1, 0)
	self.inputShield.BackgroundTransparency = 1
	self.inputShield.ZIndex = 999
	self.inputShield.Parent = self.gui
	self.inputShield.Active = true
	self.inputShield.Visible = false  -- only active during modals

	-- Intro splash
	local splash = Instance.new("Frame")
	splash.Size = UDim2.new(1, 0, 1, 0)
	splash.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	splash.BorderSizePixel = 0
	splash.ZIndex = 100
	splash.Parent = self.gui
	local logo = Instance.new("ImageLabel")
	logo.Size = UDim2.new(0, 200, 0, 200)
	logo.Position = UDim2.new(0.5, -100, 0.5, -100)
	logo.Image = "rbxassetid://13160452207"  -- placeholder
	logo.BackgroundTransparency = 1
	logo.Parent = splash
	roundCorners(logo, 100)
	local splashText = Instance.new("TextLabel")
	splashText.Text = (config.Author or "KercX") .. "\nFlux UI v" .. FluxUI.VERSION
	splashText.TextColor3 = Color3.fromRGB(255, 255, 255)
	splashText.Font = Enum.Font.GothamBold
	splashText.TextSize = 34
	splashText.Size = UDim2.new(1, 0, 0, 80)
	splashText.Position = UDim2.new(0, 0, 1, -100)
	splashText.BackgroundTransparency = 1
	splashText.Parent = splash

	local introTween = TweenService:Create(logo, TweenInfo.new(1, Enum.EasingStyle.Quad), {ImageTransparency = 1})
	local textTween = TweenService:Create(splashText, TweenInfo.new(1, Enum.EasingStyle.Quad), {TextTransparency = 1})
	introTween:Play()
	textTween:Play()
	task.wait(1.2)
	splash:Destroy()

	-- Main window
	local win = Instance.new("Frame")
	win.Name = "MainWindow"
	win.BackgroundColor3 = (self.config.theme == "dark" and defaultTheme.background) or Color3.fromRGB(245, 245, 252)
	win.BorderSizePixel = 0
	win.ClipsDescendants = true
	win.Size = UDim2.new(0, 560, 0, 660)
	win.Position = UDim2.new(0.5, -280, 0.5, -330)
	win.Parent = self.gui
	applyAcrylic(win, 12)
	addShadow(win, win.Size)
	roundCorners(win, 12)

	-- Header (draggable)
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 46)
	header.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
	header.BackgroundTransparency = 0.6
	header.BorderSizePixel = 0
	header.Parent = win
	roundCorners(header, 12)
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = config.Name or "Flux UI"
	titleLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.Size = UDim2.new(1, -160, 1, 0)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header

	local authorLabel = Instance.new("TextLabel")
	authorLabel.Text = config.Author or ""
	authorLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
	authorLabel.TextXAlignment = Enum.TextXAlignment.Right
	authorLabel.Font = Enum.Font.Gotham
	authorLabel.TextSize = 12
	authorLabel.Size = UDim2.new(0, 140, 1, 0)
	authorLabel.Position = UDim2.new(1, -150, 0, 0)
	authorLabel.BackgroundTransparency = 1
	authorLabel.Parent = header

	-- Minimize to tray (floating icon)
	local trayButton = Instance.new("TextButton")
	trayButton.Text = "●"
	trayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	trayButton.Size = UDim2.new(0, 36, 0, 36)
	trayButton.Position = UDim2.new(1, -40, 0, 10)
	trayButton.BackgroundColor3 = Color3.fromRGB(40, 45, 58)
	trayButton.BackgroundTransparency = 0.8
	trayButton.Font = Enum.Font.GothamBold
	trayButton.TextSize = 20
	trayButton.Parent = header
	roundCorners(trayButton, 18)
	trayButton.MouseButton1Click:Connect(function()
		self.minimized = not self.minimized
		local targetSize = self.minimized and UDim2.new(0, 46, 0, 46) or UDim2.new(0, 560, 0, 660)
		local targetPos = self.minimized and UDim2.new(1, -56, 0, 10) or UDim2.new(0.5, -280, 0.5, -330)
		TweenService:Create(win, TweenInfo.new(0.3), {Size = targetSize, Position = targetPos}):Play()
	end)

	-- Close
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(220, 225, 235)
	closeBtn.Size = UDim2.new(0, 40, 1, 0)
	closeBtn.Position = UDim2.new(1, -42, 0, 0)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.Parent = header
	closeBtn.MouseButton1Click:Connect(function() self:Destroy() end)

	-- Sidebar + tab search
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 170, 1, -46)
	sidebar.Position = UDim2.new(0, 0, 0, 46)
	sidebar.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
	sidebar.BackgroundTransparency = 0.3
	sidebar.BorderSizePixel = 0
	sidebar.Parent = win

	local tabSearch = Instance.new("TextBox")
	tabSearch.Size = UDim2.new(1, -12, 0, 34)
	tabSearch.Position = UDim2.new(0, 6, 0, 8)
	tabSearch.PlaceholderText = "Search tab..."
	tabSearch.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
	tabSearch.TextColor3 = Color3.fromRGB(210, 215, 230)
	tabSearch.Font = Enum.Font.Gotham
	tabSearch.TextSize = 12
	tabSearch.ClearTextOnFocus = false
	tabSearch.Parent = sidebar
	roundCorners(tabSearch, 6)
	applyPadding(tabSearch, 8)

	-- Content area (ScrollingFrame)
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -180, 1, -56)
	content.Position = UDim2.new(0, 180, 0, 56)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 5
	content.ScrollBarImageColor3 = Color3.fromRGB(100, 110, 130)
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Parent = win
	setupScrollbar(content)

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 12)
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content

	self.window = win
	self.sidebar = sidebar
	self.contentArea = content
	self.contentLayout = contentLayout

	-- Resize grip (corner)
	local resizeGrip = Instance.new("Frame")
	resizeGrip.Size = UDim2.new(0, 18, 0, 18)
	resizeGrip.Position = UDim2.new(1, -18, 1, -18)
	resizeGrip.BackgroundColor3 = Color3.fromRGB(80, 90, 110)
	resizeGrip.BackgroundTransparency = 0.6
	resizeGrip.BorderSizePixel = 0
	resizeGrip.Parent = win
	roundCorners(resizeGrip, 4)
	local resizeStart = nil
	local startSize = nil
	resizeGrip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizeStart = input.Position
			startSize = win.AbsoluteSize
		end
	end)
	resizeGrip.InputChanged:Connect(function(input)
		if resizeStart and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - resizeStart
			local newW = math.clamp(startSize.X + delta.X, 400, 1300)
			local newH = math.clamp(startSize.Y + delta.Y, 320, 950)
			win.Size = UDim2.new(0, newW, 0, newH)
			local old = win:FindFirstChild("Shadow")
			if old then old:Destroy() end
			addShadow(win, win.Size)
		end
	end)
	resizeGrip.InputEnded:Connect(function() resizeStart = nil end)

	-- Drag window
	makeDraggable(win, header, 0.2)

	-- Window snapping (to edges)
	local snapDistance = 50
	local function checkSnap()
		local pos = win.AbsolutePosition
		local size = win.AbsoluteSize
		local screen = Workspace.CurrentCamera.ViewportSize
		local newPos = win.Position
		if pos.X < snapDistance then
			newPos = UDim2.new(0, 0, newPos.Y.Scale, newPos.Y.Offset)
		elseif pos.X + size.X > screen.X - snapDistance then
			newPos = UDim2.new(1, -size.X, newPos.Y.Scale, newPos.Y.Offset)
		end
		if pos.Y < snapDistance then
			newPos = UDim2.new(newPos.X.Scale, newPos.X.Offset, 0, 0)
		elseif pos.Y + size.Y > screen.Y - snapDistance then
			newPos = UDim2.new(newPos.X.Scale, newPos.X.Offset, 1, -size.Y)
		end
		if newPos ~= win.Position then
			TweenService:Create(win, TweenInfo.new(0.2), {Position = newPos}):Play()
		end
	end
	win:GetPropertyChangedSignal("Position"):Connect(checkSnap)

	-- Responsive scaling
	local function onViewportChange()
		local viewport = Workspace.CurrentCamera.ViewportSize
		local scale = math.min(viewport.X / 1920, viewport.Y / 1080)
		local newW = math.max(400, 560 * scale)
		local newH = math.max(320, 660 * scale)
		win.Size = UDim2.new(0, newW, 0, newH)
		win.Position = UDim2.new(0.5, -newW/2, 0.5, -newH/2)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewportChange)
	onViewportChange()

	-- Global UI toggle (Right Shift)
	local toggleConn = UserInputService.InputBegan:Connect(function(input, gameProc)
		if gameProc then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			self.isVisible = not self.isVisible
			win.Visible = self.isVisible
			if self.keybindHUD then self.keybindHUD.Visible = self.isVisible end
			if self.mobileToggle then self.mobileToggle.Visible = not self.isVisible end
		end
	end)
	table.insert(self.globalConnections, toggleConn)

	-- Mobile toggle button (floating)
	if self.deviceType == "Mobile" then
		self.mobileToggle = Instance.new("TextButton")
		self.mobileToggle.Text = "Flux"
		self.mobileToggle.Size = UDim2.new(0, 56, 0, 56)
		self.mobileToggle.Position = UDim2.new(1, -66, 0, 20)
		self.mobileToggle.BackgroundColor3 = Color3.fromRGB(40, 45, 58)
		self.mobileToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
		self.mobileToggle.Font = Enum.Font.GothamBold
		self.mobileToggle.TextSize = 14
		self.mobileToggle.Parent = self.gui
		roundCorners(self.mobileToggle, 28)
		self.mobileToggle.MouseButton1Click:Connect(function()
			self.isVisible = not self.isVisible
			win.Visible = self.isVisible
			self.mobileToggle.Visible = not self.isVisible
		end)
	end

	-- Auto‑hide when tool equipped
	local player = Players.LocalPlayer
	local function onCharAdded(char)
		local toolConn = nil
		local function checkTool()
			local tool = char:FindFirstChildWhichIsA("Tool")
			if tool and tool ~= self.lastTool then
				win.Visible = false
				if toolConn then toolConn:Disconnect() end
				toolConn = tool.AncestryChanged:Connect(function()
					if not tool.Parent then win.Visible = true end
				end)
			end
			self.lastTool = tool
		end
		char.ChildAdded:Connect(checkTool)
		char.ChildRemoved:Connect(checkTool)
	end
	player.CharacterAdded:Connect(onCharAdded)
	if player.Character then onCharAdded(player.Character) end

	-- Status bar (bottom)
	local statusBar = Instance.new("Frame")
	statusBar.Size = UDim2.new(1, 0, 0, 24)
	statusBar.Position = UDim2.new(0, 0, 1, -24)
	statusBar.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
	statusBar.BackgroundTransparency = 0.5
	statusBar.Parent = win
	local statusText = Instance.new("TextLabel")
	statusText.Text = "Ready"
	statusText.Size = UDim2.new(1, -10, 1, 0)
	statusText.Position = UDim2.new(0, 5, 0, 0)
	statusText.TextColor3 = Color3.fromRGB(180, 190, 210)
	statusText.Font = Enum.Font.Gotham
	statusText.TextSize = 10
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	statusText.BackgroundTransparency = 1
	statusText.Parent = statusBar
	self.statusText = statusText

	-- Version tag
	local versionTag = Instance.new("TextLabel")
	versionTag.Text = "v" .. FluxUI.VERSION
	versionTag.Size = UDim2.new(0, 50, 1, 0)
	versionTag.Position = UDim2.new(1, -55, 0, 0)
	versionTag.TextColor3 = Color3.fromRGB(120, 130, 160)
	versionTag.Font = Enum.Font.Gotham
	versionTag.TextSize = 10
	versionTag.TextXAlignment = Enum.TextXAlignment.Right
	versionTag.BackgroundTransparency = 1
	versionTag.Parent = statusBar
	self.versionTag = versionTag

	-- Watermark
	local watermark = Instance.new("TextLabel")
	watermark.Text = "Flux UI © 2025"
	watermark.TextColor3 = Color3.fromRGB(100, 110, 140)
	watermark.Font = Enum.Font.Gotham
	watermark.TextSize = 10
	watermark.BackgroundTransparency = 1
	watermark.Position = UDim2.new(0, 8, 1, -20)
	watermark.Size = UDim2.new(0, 130, 0, 18)
	watermark.Parent = win

	-- Keybind HUD
	self:CreateKeybindHUD()

	-- Auto-update check
	self:CheckForUpdates()

	return self
end

-- =============================== TAB MANAGEMENT ===============================
function FluxUI:CreateTab(name, iconId)
	local btn = Instance.new("TextButton")
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(200, 205, 220)
	btn.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(1, -12, 0, 42)
	btn.Position = UDim2.new(0, 6, 0, 48 + (#self.tabs * 46))
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.Parent = self.sidebar
	roundCorners(btn, 6)
	btn.MouseEnter:Connect(function() playHover() end)

	if iconId then
		local icon = Instance.new("ImageLabel")
		icon.Image = iconId
		icon.Size = UDim2.new(0, 20, 0, 20)
		icon.Position = UDim2.new(0, 8, 0.5, -10)
		icon.BackgroundTransparency = 1
		icon.Parent = btn
		btn.Text = "   " .. name
	end

	local tabContent = Instance.new("Frame")
	tabContent.Name = name .. "Tab"
	tabContent.Size = UDim2.new(1, -12, 0, 0)
	tabContent.BackgroundTransparency = 1
	tabContent.Visible = false
	tabContent.Parent = self.contentArea

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Padding = UDim.new(0, 12)
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabContent

	local tabObj = {button = btn, content = tabContent, layout = tabLayout, name = name}
	table.insert(self.tabs, tabObj)

	if not self.activeTab then self:SelectTab(tabObj) end

	-- Global search filter
	local searchBox = self.sidebar:FindFirstChildWhichIsA("TextBox")
	if searchBox then
		searchBox.Changed:Connect(function(prop)
			if prop == "Text" then
				local filter = searchBox.Text:lower()
				for _, t in ipairs(self.tabs) do
					t.button.Visible = filter == "" or string.find(t.name:lower(), filter)
				end
			end
		end)
	end

	btn.MouseButton1Click:Connect(function() self:SelectTab(tabObj) end)
	return tabObj
end

function FluxUI:SelectTab(tab)
	for _, t in ipairs(self.tabs) do
		t.content.Visible = false
		t.button.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
		t.button.TextColor3 = Color3.fromRGB(200, 205, 220)
	end
	tab.content.Visible = true
	tab.button.BackgroundColor3 = Color3.fromRGB(70, 85, 110)
	tab.button.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.activeTab = tab
	self.statusText.Text = "Tab: " .. tab.name
end

-- =============================== COMPONENT CREATORS ===============================
-- Standard Button
function FluxUI:CreateButton(tab, text, callback, iconId)
	local btn = Instance.new("TextButton")
	btn.Text = text
	btn.Size = UDim2.new(0.9, 0, 0, 42)
	btn.BackgroundColor3 = Color3.fromRGB(60, 68, 82)
	btn.BackgroundTransparency = 0.3
	btn.TextColor3 = Color3.fromRGB(235, 240, 255)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.BorderSizePixel = 0
	btn.Parent = tab.content
	roundCorners(btn, 8)
	btn.MouseEnter:Connect(function() playHover() end)

	if iconId then
		local icon = Instance.new("ImageLabel")
		icon.Image = iconId
		icon.Size = UDim2.new(0, 22, 0, 22)
		icon.Position = UDim2.new(0, 12, 0.5, -11)
		icon.BackgroundTransparency = 1
		icon.Parent = btn
		btn.Text = "   " .. text
	end

	local ripple = Instance.new("Frame")
	ripple.Size = UDim2.new(0, 0, 0, 0)
	ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ripple.BackgroundTransparency = 0.8
	ripple.BorderSizePixel = 0
	ripple.Parent = btn
	roundCorners(ripple, 8)

	btn.MouseButton1Click:Connect(function()
		playClick()
		local maxSize = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)
		TweenService:Create(ripple, TweenInfo.new(0.3), {
			Size = UDim2.new(0, maxSize, 0, maxSize),
			BackgroundTransparency = 1
		}):Play()
		task.wait(0.3)
		ripple.Size = UDim2.new(0, 0, 0, 0)
		ripple.BackgroundTransparency = 0.8
		safeCall(callback)
	end)
	attachTooltip(btn, text)
	return btn
end

-- Toggle (animated)
function FluxUI:CreateToggle(tab, name, defaultValue, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 40)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.65, 0, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.BackgroundTransparency = 1
	label.Parent = container

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 54, 0, 28)
	toggleBtn.Position = UDim2.new(1, -60, 0.5, -14)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 85, 98)
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Parent = container
	roundCorners(toggleBtn, 14)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 24, 0, 24)
	knob.Position = UDim2.new(0, 4, 0.5, -12)
	knob.BackgroundColor3 = Color3.fromRGB(250, 250, 255)
	knob.BorderSizePixel = 0
	knob.Parent = toggleBtn
	roundCorners(knob, 12)

	local state = (self.savedSettings and self.savedSettings[name] ~= nil) and self.savedSettings[name] or defaultValue
	FluxUI.Flags[name] = state

	local function updateUI()
		local targetPos = state and UDim2.new(1, -28, 0.5, -12) or UDim2.new(0, 4, 0.5, -12)
		local targetColor = state and defaultTheme.primary or Color3.fromRGB(80, 85, 98)
		TweenService:Create(knob, TweenInfo.new(0.1), {Position = targetPos}):Play()
		TweenService:Create(toggleBtn, TweenInfo.new(0.1), {BackgroundColor3 = targetColor}):Play()
		safeCall(callback, state)
		FluxUI.Flags[name] = state
		if self.savedSettings then
			self.savedSettings[name] = state
			self:SaveConfig()
		end
	end

	toggleBtn.MouseButton1Click:Connect(function()
		playClick()
		state = not state
		updateUI()
	end)
	updateUI()
	attachTooltip(label, name)
	return container
end

-- Slider (int/float with callback throttling)
function FluxUI:CreateSlider(tab, name, minVal, maxVal, defaultValue, callback, isStep, stepValue)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 58)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(1, -80, 0, 26)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.BackgroundTransparency = 1
	label.Parent = container

	local valueDisplay = Instance.new("TextLabel")
	valueDisplay.Text = tostring(defaultValue)
	valueDisplay.Size = UDim2.new(0, 70, 0, 26)
	valueDisplay.Position = UDim2.new(1, -75, 0, 0)
	valueDisplay.TextColor3 = defaultTheme.primary
	valueDisplay.Font = Enum.Font.GothamBold
	valueDisplay.BackgroundTransparency = 1
	valueDisplay.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -12, 0, 6)
	track.Position = UDim2.new(0, 6, 1, -20)
	track.BackgroundColor3 = Color3.fromRGB(60, 68, 82)
	track.BorderSizePixel = 0
	track.Parent = container
	roundCorners(track, 3)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = defaultTheme.primary
	fill.BorderSizePixel = 0
	fill.Parent = track
	roundCorners(fill, 3)

	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.new(0, 16, 0, 16)
	thumb.Position = UDim2.new(0, -8, 0, -5)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.Parent = fill
	roundCorners(thumb, 8)

	local currentValue = (self.savedSettings and self.savedSettings[name] ~= nil) and self.savedSettings[name] or defaultValue
	FluxUI.Flags[name] = currentValue
	local lastCallbackTime = 0
	local throttleDelay = 0.016  -- ~60fps

	local function setValue(newVal)
		if isStep and stepValue then
			newVal = math.floor((newVal - minVal) / stepValue + 0.5) * stepValue + minVal
		end
		newVal = math.clamp(newVal, minVal, maxVal)
		currentValue = newVal
		local percent = (currentValue - minVal) / (maxVal - minVal)
		fill.Size = UDim2.new(percent, 0, 1, 0)
		local display = isStep and tostring(math.floor(currentValue)) or string.format("%.2f", currentValue)
		valueDisplay.Text = display
		FluxUI.Flags[name] = currentValue
		if self.savedSettings then
			self.savedSettings[name] = currentValue
			self:SaveConfig()
		end
		local now = tick()
		if now - lastCallbackTime >= throttleDelay then
			lastCallbackTime = now
			safeCall(callback, currentValue)
		end
	end

	local dragging = false
	local mouseConn = nil
	local endConn = nil

	thumb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			mouseConn = UserInputService.InputChanged:Connect(function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					local mouseX = input.Position.X
					local trackPos = track.AbsolutePosition.X
					local trackWidth = track.AbsoluteSize.X
					local raw = math.clamp((mouseX - trackPos) / trackWidth, 0, 1)
					setValue(minVal + raw * (maxVal - minVal))
				end
			end)
			endConn = UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
					if mouseConn then mouseConn:Disconnect() end
					if endConn then endConn:Disconnect() end
				end
			end)
		end
	end)

	setValue(currentValue)
	attachTooltip(label, name)
	return container
end

function FluxUI:CreateStepSlider(tab, name, minVal, maxVal, step, defaultValue, callback)
	return self:CreateSlider(tab, name, minVal, maxVal, defaultValue, callback, true, step)
end

-- Dual Slider (min-max range)
function FluxUI:CreateDualSlider(tab, name, minVal, maxVal, defaultMin, defaultMax, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 80)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(1, 0, 0, 22)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local minDisp = Instance.new("TextLabel")
	minDisp.Text = tostring(defaultMin)
	minDisp.Size = UDim2.new(0, 60, 0, 22)
	minDisp.Position = UDim2.new(0, 10, 0, 24)
	minDisp.TextColor3 = defaultTheme.primary
	minDisp.Font = Enum.Font.GothamBold
	minDisp.BackgroundTransparency = 1
	minDisp.Parent = container

	local maxDisp = Instance.new("TextLabel")
	maxDisp.Text = tostring(defaultMax)
	maxDisp.Size = UDim2.new(0, 60, 0, 22)
	maxDisp.Position = UDim2.new(1, -70, 0, 24)
	maxDisp.TextColor3 = defaultTheme.primary
	maxDisp.Font = Enum.Font.GothamBold
	maxDisp.BackgroundTransparency = 1
	maxDisp.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -12, 0, 6)
	track.Position = UDim2.new(0, 6, 0.6, 0)
	track.BackgroundColor3 = Color3.fromRGB(60, 68, 82)
	track.BorderSizePixel = 0
	track.Parent = container
	roundCorners(track, 3)

	local rangeFill = Instance.new("Frame")
	rangeFill.Size = UDim2.new(0, 0, 1, 0)
	rangeFill.BackgroundColor3 = defaultTheme.primary
	rangeFill.BorderSizePixel = 0
	rangeFill.Parent = track
	roundCorners(rangeFill, 3)

	local minThumb = Instance.new("Frame")
	minThumb.Size = UDim2.new(0, 14, 0, 14)
	minThumb.Position = UDim2.new(0, -7, 0, -4)
	minThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	minThumb.BorderSizePixel = 0
	minThumb.Parent = track
	roundCorners(minThumb, 7)

	local maxThumb = Instance.new("Frame")
	maxThumb.Size = UDim2.new(0, 14, 0, 14)
	maxThumb.Position = UDim2.new(1, -7, 0, -4)
	maxThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	maxThumb.BorderSizePixel = 0
	maxThumb.Parent = track
	roundCorners(maxThumb, 7)

	local currentMin = defaultMin
	local currentMax = defaultMax

	local function updateUI()
		local minP = (currentMin - minVal) / (maxVal - minVal)
		local maxP = (currentMax - minVal) / (maxVal - minVal)
		rangeFill.Size = UDim2.new(maxP - minP, 0, 1, 0)
		rangeFill.Position = UDim2.new(minP, 0, 0, 0)
		minThumb.Position = UDim2.new(minP, -7, 0, -4)
		maxThumb.Position = UDim2.new(maxP, -7, 0, -4)
		minDisp.Text = tostring(math.floor(currentMin))
		maxDisp.Text = tostring(math.floor(currentMax))
		safeCall(callback, currentMin, currentMax)
		FluxUI.Flags[name .. "_Min"] = currentMin
		FluxUI.Flags[name .. "_Max"] = currentMax
	end

	local draggingMin = false
	local draggingMax = false
	local mouseConn, endConn

	local function startDrag(isMin)
		return function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if isMin then draggingMin = true else draggingMax = true end
				mouseConn = UserInputService.InputChanged:Connect(function(input)
					if (draggingMin or draggingMax) and input.UserInputType == Enum.UserInputType.MouseMovement then
						local mouseX = input.Position.X
						local trackPos = track.AbsolutePosition.X
						local trackWidth = track.AbsoluteSize.X
						local raw = math.clamp((mouseX - trackPos) / trackWidth, 0, 1)
						local newVal = minVal + raw * (maxVal - minVal)
						if draggingMin then
							currentMin = math.clamp(newVal, minVal, currentMax - 1)
						else
							currentMax = math.clamp(newVal, currentMin + 1, maxVal)
						end
						updateUI()
					end
				end)
				endConn = UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						draggingMin = false
						draggingMax = false
						if mouseConn then mouseConn:Disconnect() end
						if endConn then endConn:Disconnect() end
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

-- Dropdown (single, multi, searchable)
function FluxUI:CreateDropdown(tab, name, items, multiSelect, defaultSelection, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 50)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.5, 0, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local dropdownBtn = Instance.new("TextButton")
	dropdownBtn.Size = UDim2.new(0, 160, 0, 36)
	dropdownBtn.Position = UDim2.new(1, -165, 0.5, -18)
	dropdownBtn.Text = "Select"
	dropdownBtn.BackgroundColor3 = Color3.fromRGB(55, 62, 78)
	dropdownBtn.TextColor3 = Color3.fromRGB(220, 225, 235)
	dropdownBtn.Font = Enum.Font.Gotham
	dropdownBtn.TextSize = 12
	dropdownBtn.Parent = container
	roundCorners(dropdownBtn, 6)

	local dropdownList = Instance.new("ScrollingFrame")
	dropdownList.Size = UDim2.new(0, 220, 0, 180)
	dropdownList.Position = UDim2.new(1, -225, 0, 42)
	dropdownList.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	dropdownList.BorderSizePixel = 0
	dropdownList.Visible = false
	dropdownList.ScrollBarThickness = 4
	dropdownList.Parent = container
	roundCorners(dropdownList, 6)
	dropdownList.ZIndex = 15  -- ensure on top

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -8, 0, 32)
	searchBox.Position = UDim2.new(0, 4, 0, 4)
	searchBox.PlaceholderText = "Search..."
	searchBox.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
	searchBox.TextColor3 = Color3.fromRGB(240, 240, 245)
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 12
	searchBox.Parent = dropdownList
	roundCorners(searchBox, 4)

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = dropdownList

	local selected = multiSelect and {} or nil

	local function rebuildList(filter)
		for _, child in ipairs(dropdownList:GetChildren()) do
			if child:IsA("TextButton") and child ~= searchBox then child:Destroy() end
		end
		for _, item in ipairs(items) do
			if not filter or string.find(string.lower(item), string.lower(filter)) then
				local itemBtn = Instance.new("TextButton")
				itemBtn.Text = item
				itemBtn.Size = UDim2.new(1, -8, 0, 34)
				itemBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
				itemBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
				itemBtn.Font = Enum.Font.Gotham
				itemBtn.TextSize = 12
				itemBtn.Parent = dropdownList
				roundCorners(itemBtn, 4)
				itemBtn.MouseButton1Click:Connect(function()
					playClick()
					if multiSelect then
						if selected[item] then
							selected[item] = nil
							itemBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
						else
							selected[item] = true
							itemBtn.BackgroundColor3 = defaultTheme.primary
						end
						local selectedList = {}
						for k,_ in pairs(selected) do table.insert(selectedList, k) end
						local displayText = table.concat(selectedList, ", ")
						if #displayText > 25 then displayText = displayText:sub(1,22).."..."
						dropdownBtn.Text = displayText ~= "" and displayText or "Select"
						safeCall(callback, selectedList)
						FluxUI.Flags[name] = selectedList
					else
						selected = item
						dropdownBtn.Text = item
						dropdownList.Visible = false
						safeCall(callback, item)
						FluxUI.Flags[name] = item
					end
					if self.savedSettings then
						self.savedSettings[name] = selected
						self:SaveConfig()
					end
				end)
			end
		end
	end

	searchBox.Changed:Connect(function(prop)
		if prop == "Text" then rebuildList(searchBox.Text) end
	end)

	dropdownBtn.MouseButton1Click:Connect(function()
		dropdownList.Visible = not dropdownList.Visible
		if dropdownList.Visible then rebuildList("") end
	end)

	if defaultSelection then
		if multiSelect then
			for _, v in pairs(defaultSelection) do selected[v] = true end
			local selectedList = {}
			for k,_ in pairs(selected) do table.insert(selectedList, k) end
			local displayText = table.concat(selectedList, ", ")
			if #displayText > 25 then displayText = displayText:sub(1,22).."..."
			dropdownBtn.Text = displayText ~= "" and displayText or "Select"
			safeCall(callback, selectedList)
			FluxUI.Flags[name] = selectedList
		else
			selected = defaultSelection
			dropdownBtn.Text = defaultSelection
			safeCall(callback, defaultSelection)
			FluxUI.Flags[name] = defaultSelection
		end
	end
	return container
end

-- Keybind (fully working with HUD integration)
function FluxUI:CreateKeybind(tab, name, defaultKey, callback, iconId)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 44)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local bindBtn = Instance.new("TextButton")
	bindBtn.Size = UDim2.new(0, 120, 0, 34)
	bindBtn.Position = UDim2.new(1, -125, 0.5, -17)
	bindBtn.Text = defaultKey or "None"
	bindBtn.BackgroundColor3 = Color3.fromRGB(55, 62, 78)
	bindBtn.TextColor3 = Color3.fromRGB(220, 225, 235)
	bindBtn.Font = Enum.Font.Gotham
	bindBtn.TextSize = 12
	bindBtn.Parent = container
	roundCorners(bindBtn, 6)

	if iconId then
		local icon = Instance.new("ImageLabel")
		icon.Image = iconId
		icon.Size = UDim2.new(0, 18, 0, 18)
		icon.Position = UDim2.new(0, 6, 0.5, -9)
		icon.BackgroundTransparency = 1
		icon.Parent = bindBtn
		bindBtn.Text = "   " .. (defaultKey or "None")
	end

	local listening = false
	local conn = nil
	local storedKey = defaultKey or "None"

	local function setBinding(key)
		storedKey = key
		bindBtn.Text = key
		safeCall(callback, key)
		FluxUI.Flags[name] = key
		if self.savedSettings then
			self.savedSettings[name] = key
			self:SaveConfig()
		end
	end

	bindBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		bindBtn.Text = "..."
		conn = UserInputService.InputBegan:Connect(function(input, gameProc)
			if gameProc then return end
			if input.KeyCode ~= Enum.KeyCode.Unknown then
				local newKey = input.KeyCode.Name
				setBinding(newKey)
				listening = false
				conn:Disconnect()
				conn = nil
			end
		end)
		task.delay(3, function()
			if listening then
				listening = false
				bindBtn.Text = storedKey
				if conn then conn:Disconnect() end
				conn = nil
			end
		end)
	end)

	if self.savedSettings and self.savedSettings[name] then
		setBinding(self.savedSettings[name])
	end
	return container
end

-- Color Picker (HSV + Alpha)
function FluxUI:CreateColorPicker(tab, name, defaultColor, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 200)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(1, 0, 0, 26)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local preview = Instance.new("Frame")
	preview.Size = UDim2.new(0, 48, 0, 48)
	preview.Position = UDim2.new(1, -52, 0, 30)
	preview.BackgroundColor3 = defaultColor or Color3.new(1, 0, 0)
	preview.BorderSizePixel = 0
	preview.Parent = container
	roundCorners(preview, 8)

	local rBox, gBox, bBox, aBox, hexBox

	local function updateFromRGBA(r, g, b, a)
		local col = Color3.new(r/255, g/255, b/255)
		preview.BackgroundColor3 = col
		preview.BackgroundTransparency = 1 - a
		hexBox.Text = string.format("#%02x%02x%02x", r, g, b)
		safeCall(callback, col, a)
		FluxUI.Flags[name] = {Color = col, Alpha = a}
		if self.savedSettings then
			self.savedSettings[name] = {r, g, b, a}
			self:SaveConfig()
		end
	end

	local function makeNumBox(xOffset, initVal)
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0, 55, 0, 32)
		box.Position = UDim2.new(xOffset, 0, 0, 34)
		box.Text = tostring(initVal)
		box.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
		box.TextColor3 = Color3.fromRGB(240, 240, 245)
		box.Font = Enum.Font.Gotham
		box.TextSize = 12
		box.Parent = container
		roundCorners(box, 4)
		box.FocusLost:Connect(function()
			local val = tonumber(box.Text) or 0
			val = math.clamp(val, 0, 255)
			box.Text = tostring(val)
			local r = tonumber(rBox.Text) or 0
			local g = tonumber(gBox.Text) or 0
			local b = tonumber(bBox.Text) or 0
			local a = tonumber(aBox.Text) or 1
			updateFromRGBA(r, g, b, a)
		end)
		return box
	end

	hexBox = Instance.new("TextBox")
	hexBox.Size = UDim2.new(0, 100, 0, 32)
	hexBox.Position = UDim2.new(0, 0, 0, 72)
	hexBox.PlaceholderText = "#RRGGBB"
	hexBox.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
	hexBox.TextColor3 = Color3.fromRGB(240, 240, 245)
	hexBox.Font = Enum.Font.Gotham
	hexBox.TextSize = 12
	hexBox.Parent = container
	roundCorners(hexBox, 4)
	hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("#", "")
		if #hex == 6 then
			local r = tonumber("0x"..hex:sub(1,2)) or 0
			local g = tonumber("0x"..hex:sub(3,4)) or 0
			local b = tonumber("0x"..hex:sub(5,6)) or 0
			rBox.Text = tostring(r)
			gBox.Text = tostring(g)
			bBox.Text = tostring(b)
			updateFromRGBA(r, g, b, tonumber(aBox.Text) or 1)
		end
	end)

	aBox = Instance.new("TextBox")
	aBox.Size = UDim2.new(0, 55, 0, 32)
	aBox.Position = UDim2.new(0, 110, 0, 72)
	aBox.Text = "1"
	aBox.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
	aBox.TextColor3 = Color3.fromRGB(240, 240, 245)
	aBox.Font = Enum.Font.Gotham
	aBox.TextSize = 12
	aBox.Parent = container
	roundCorners(aBox, 4)
	aBox.FocusLost:Connect(function()
		local val = tonumber(aBox.Text) or 1
		val = math.clamp(val, 0, 1)
		aBox.Text = tostring(val)
		local r = tonumber(rBox.Text) or 0
		local g = tonumber(gBox.Text) or 0
		local b = tonumber(bBox.Text) or 0
		updateFromRGBA(r, g, b, val)
	end)

	local initCol = defaultColor or Color3.new(1,0,0)
	rBox = makeNumBox(0, initCol.R*255)
	gBox = makeNumBox(60, initCol.G*255)
	bBox = makeNumBox(120, initCol.B*255)
	aBox.Text = "1"
	hexBox.Text = string.format("#%02x%02x%02x", initCol.R*255, initCol.G*255, initCol.B*255)
	updateFromRGBA(initCol.R*255, initCol.G*255, initCol.B*255, 1)
	return container
end

-- TextBox (with clear, number, secure)
function FluxUI:CreateTextBox(tab, name, placeholder, callback, isNumberOnly, isSecure)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 50)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.4, 0, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(0.5, -40, 0, 36)
	textBox.Position = UDim2.new(0.5, 0, 0.5, -18)
	textBox.PlaceholderText = placeholder
	textBox.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
	textBox.TextColor3 = Color3.fromRGB(240, 240, 245)
	textBox.Font = Enum.Font.Gotham
	textBox.TextSize = 13
	textBox.ClearTextOnFocus = false
	textBox.Parent = container
	roundCorners(textBox, 6)

	if isSecure then
		textBox.Text = "••••••"
		textBox.PlaceholderText = "••••••"
	end

	if isNumberOnly then
		textBox.Changed:Connect(function(prop)
			if prop == "Text" then
				local newText = textBox.Text:gsub("[^%d]", "")
				if newText ~= textBox.Text then textBox.Text = newText end
			end
		end)
	end

	local clearBtn = Instance.new("TextButton")
	clearBtn.Text = "X"
	clearBtn.Size = UDim2.new(0, 34, 0, 36)
	clearBtn.Position = UDim2.new(1, -38, 0.5, -18)
	clearBtn.BackgroundColor3 = Color3.fromRGB(70, 78, 92)
	clearBtn.TextColor3 = Color3.fromRGB(220, 225, 235)
	clearBtn.Font = Enum.Font.Gotham
	clearBtn.TextSize = 14
	clearBtn.Parent = container
	roundCorners(clearBtn, 6)
	clearBtn.MouseButton1Click:Connect(function()
		textBox.Text = ""
		safeCall(callback, "")
	end)

	textBox.FocusLost:Connect(function()
		if isNumberOnly then
			local num = tonumber(textBox.Text) or 0
			safeCall(callback, num)
			FluxUI.Flags[name] = num
		else
			safeCall(callback, textBox.Text)
			FluxUI.Flags[name] = textBox.Text
		end
	end)
	attachTooltip(label, name)
	return container
end

function FluxUI:CreateNumberInput(tab, name, defaultValue, callback)
	return self:CreateTextBox(tab, name, tostring(defaultValue), function(val) safeCall(callback, val) end, true)
end

function FluxUI:CreateSecureTextBox(tab, name, placeholder, callback)
	return self:CreateTextBox(tab, name, placeholder, callback, false, true)
end

-- Checkbox
function FluxUI:CreateCheckbox(tab, name, defaultValue, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 38)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local boxBtn = Instance.new("TextButton")
	boxBtn.Size = UDim2.new(0, 22, 0, 22)
	boxBtn.Position = UDim2.new(0, 0, 0.5, -11)
	boxBtn.BackgroundColor3 = Color3.fromRGB(60, 68, 82)
	boxBtn.BorderSizePixel = 0
	boxBtn.Text = ""
	boxBtn.Parent = container
	roundCorners(boxBtn, 4)

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(1, -30, 1, 0)
	label.Position = UDim2.new(0, 28, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local state = (self.savedSettings and self.savedSettings[name] ~= nil) and self.savedSettings[name] or defaultValue
	FluxUI.Flags[name] = state

	local function updateUI()
		boxBtn.Text = state and "✓" or ""
		boxBtn.TextColor3 = state and Color3.fromRGB(0,200,0) or Color3.fromRGB(120,120,130)
		safeCall(callback, state)
		FluxUI.Flags[name] = state
		if self.savedSettings then
			self.savedSettings[name] = state
			self:SaveConfig()
		end
	end

	boxBtn.MouseButton1Click:Connect(function()
		playClick()
		state = not state
		updateUI()
	end)
	updateUI()
	attachTooltip(label, name)
	return container
end

-- Radio Group
function FluxUI:CreateRadioGroup(tab, name, options, defaultOption, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 32 + #options*34)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local title = Instance.new("TextLabel")
	title.Text = name
	title.Size = UDim2.new(1, 0, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(210, 215, 230)
	title.Font = Enum.Font.GothamBold
	title.BackgroundTransparency = 1
	title.Parent = container

	local selected = (self.savedSettings and self.savedSettings[name]) or defaultOption
	FluxUI.Flags[name] = selected

	for i, opt in ipairs(options) do
		local radioBtn = Instance.new("TextButton")
		radioBtn.Text = opt
		radioBtn.Size = UDim2.new(1, -20, 0, 30)
		radioBtn.Position = UDim2.new(0, 20, 0, 28 + (i-1)*34)
		radioBtn.TextXAlignment = Enum.TextXAlignment.Left
		radioBtn.BackgroundTransparency = 1
		radioBtn.TextColor3 = Color3.fromRGB(200,205,220)
		radioBtn.Font = Enum.Font.Gotham
		radioBtn.TextSize = 13
		radioBtn.Parent = container

		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 14, 0, 14)
		dot.Position = UDim2.new(0, -18, 0.5, -7)
		dot.BackgroundColor3 = Color3.fromRGB(80,90,105)
		dot.BorderSizePixel = 0
		dot.Parent = radioBtn
		roundCorners(dot, 7)

		radioBtn.MouseButton1Click:Connect(function()
			selected = opt
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("TextButton") and child ~= title then
					local ind = child:FindFirstChildWhichIsA("Frame")
					if ind then ind.BackgroundColor3 = Color3.fromRGB(80,90,105) end
				end
			end
			dot.BackgroundColor3 = defaultTheme.primary
			safeCall(callback, opt)
			FluxUI.Flags[name] = opt
			if self.savedSettings then
				self.savedSettings[name] = opt
				self:SaveConfig()
			end
		end)

		if opt == selected then
			dot.BackgroundColor3 = defaultTheme.primary
		end
	end
	return container
end

-- Progress Bar
function FluxUI:CreateProgressBar(tab, labelText, maxVal)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 52)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local label = Instance.new("TextLabel")
	label.Text = labelText
	label.Size = UDim2.new(1, 0, 0, 24)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -12, 0, 12)
	barBg.Position = UDim2.new(0, 6, 1, -20)
	barBg.BackgroundColor3 = Color3.fromRGB(55,62,78)
	barBg.BorderSizePixel = 0
	barBg.Parent = container
	roundCorners(barBg, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = defaultTheme.primary
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	roundCorners(fill, 6)

	local function setProgress(percent)
		TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
	end
	return {set = setProgress}
end

-- Circular Progress
function FluxUI:CreateCircularProgress(tab, radius, initialPercent)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, radius*2, 0, radius*2)
	container.BackgroundTransparency = 1
	container.Parent = tab.content
	local arc = Instance.new("Frame")
	arc.Size = UDim2.new(1, 0, 1, 0)
	arc.BackgroundColor3 = defaultTheme.primary
	arc.BackgroundTransparency = 0.8
	arc.Parent = container
	roundCorners(arc, radius)
	local function setPercent(p)
		TweenService:Create(arc, TweenInfo.new(0.2), {BackgroundTransparency = 1 - p}):Play()
	end
	setPercent(initialPercent)
	return {set = setPercent}
end

-- Spinner
function FluxUI:CreateSpinner(tab, visible)
	local spin = Instance.new("ImageLabel")
	spin.Image = "rbxassetid://6031281695"
	spin.Size = UDim2.new(0, 36, 0, 36)
	spin.BackgroundTransparency = 1
	spin.Visible = visible
	spin.Parent = tab.content
	local rot = TweenService:Create(spin, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Rotation = 360})
	rot:Play()
	local function setVisible(v)
		spin.Visible = v
		if v then rot:Play() else rot:Pause() end
	end
	return {setVisible = setVisible}
end

-- Divider
function FluxUI:CreateDivider(tab)
	local line = Instance.new("Frame")
	line.Size = UDim2.new(0.9, 0, 0, 2)
	line.BackgroundColor3 = Color3.fromRGB(80,90,115)
	line.BorderSizePixel = 0
	line.Parent = tab.content
	return line
end

-- Label (rich text supported)
function FluxUI:CreateLabel(tab, text, fontSize, richText)
	local lbl = Instance.new("TextLabel")
	lbl.Text = text
	lbl.Size = UDim2.new(0.9, 0, 0, 30)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(200,210,235)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = fontSize or 14
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	if richText then lbl.RichText = true end
	lbl.Parent = tab.content
	return lbl
end

-- Paragraph (auto-wrapping)
function FluxUI:CreateParagraph(tab, text, richText)
	local para = Instance.new("TextLabel")
	para.Text = text
	para.Size = UDim2.new(0.9, 0, 0, 0)
	para.BackgroundTransparency = 1
	para.TextColor3 = Color3.fromRGB(180,190,220)
	para.Font = Enum.Font.Gotham
	para.TextSize = 12
	para.TextWrapped = true
	para.TextXAlignment = Enum.TextXAlignment.Left
	if richText then para.RichText = true end
	para.Parent = tab.content
	para.Size = UDim2.new(0.9, 0, 0, para.TextBounds.Y + 12)
	return para
end

-- Status Dot
function FluxUI:CreateStatusDot(tab, labelText, initialActive)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 36)
	container.BackgroundTransparency = 1
	container.Parent = tab.content

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 12, 0, 12)
	dot.Position = UDim2.new(0, 0, 0.5, -6)
	dot.BackgroundColor3 = initialActive and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,0,0)
	dot.BorderSizePixel = 0
	dot.Parent = container
	roundCorners(dot, 6)

	local label = Instance.new("TextLabel")
	label.Text = labelText
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 20, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210,215,230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container

	local function setActive(active)
		dot.BackgroundColor3 = active and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,0,0)
	end
	return {setActive = setActive}
end

-- Clipboard Button
function FluxUI:CreateClipboardButton(tab, buttonText, copyText)
	return self:CreateButton(tab, buttonText, function()
		Clipboard(copyText)
		self:Notify({Title = "Copied", Content = copyText, Duration = 1.5})
	end)
end

-- Image Display
function FluxUI:CreateImageDisplay(tab, imageId, size)
	local img = Instance.new("ImageLabel")
	img.Image = imageId
	img.Size = size
	img.BackgroundTransparency = 1
	img.Parent = tab.content
	roundCorners(img, 8)
	return img
end

-- Badge (small indicator)
function FluxUI:CreateBadge(tab, text, color)
	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 50, 0, 24)
	badge.BackgroundColor3 = color or Color3.fromRGB(200, 50, 50)
	badge.Parent = tab.content
	roundCorners(badge, 12)
	local lbl = Instance.new("TextLabel")
	lbl.Text = text
	lbl.Size = UDim2.new(1,0,1,0)
	lbl.TextColor3 = Color3.fromRGB(255,255,255)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.BackgroundTransparency = 1
	lbl.Parent = badge
	return badge
end

-- Modal Popup (with blur)
function FluxUI:CreateModal(title, contentText, onConfirm, onCancel)
	self.inputShield.Visible = true
	local modalBg = Instance.new("Frame")
	modalBg.Size = UDim2.new(1,0,1,0)
	modalBg.BackgroundColor3 = Color3.fromRGB(0,0,0)
	modalBg.BackgroundTransparency = 0.6
	modalBg.BorderSizePixel = 0
	modalBg.ZIndex = 200
	modalBg.Parent = self.gui
	-- Blur effect on background
	local blur = Instance.new("BlurEffect")
	blur.Size = 8
	blur.Parent = modalBg

	local modal = Instance.new("Frame")
	modal.Size = UDim2.new(0, 400, 0, 220)
	modal.Position = UDim2.new(0.5, -200, 0.5, -110)
	modal.BackgroundColor3 = Color3.fromRGB(30,32,42)
	modal.BorderSizePixel = 0
	modal.Parent = modalBg
	roundCorners(modal, 12)
	addShadow(modal, modal.Size)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Text = title
	titleLbl.Size = UDim2.new(1,0,0,36)
	titleLbl.TextColor3 = Color3.fromRGB(255,255,255)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 16
	titleLbl.BackgroundTransparency = 1
	titleLbl.Parent = modal

	local contentLbl = Instance.new("TextLabel")
	contentLbl.Text = contentText
	contentLbl.Size = UDim2.new(1, -20, 0, 80)
	contentLbl.Position = UDim2.new(0,10,0,46)
	contentLbl.TextColor3 = Color3.fromRGB(200,210,230)
	contentLbl.Font = Enum.Font.Gotham
	contentLbl.TextSize = 12
	contentLbl.TextWrapped = true
	contentLbl.BackgroundTransparency = 1
	contentLbl.Parent = modal

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Text = "Confirm"
	confirmBtn.Size = UDim2.new(0, 120, 0, 36)
	confirmBtn.Position = UDim2.new(0.5, -130, 1, -46)
	confirmBtn.BackgroundColor3 = defaultTheme.primary
	confirmBtn.TextColor3 = Color3.fromRGB(255,255,255)
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.TextSize = 14
	confirmBtn.Parent = modal
	roundCorners(confirmBtn, 6)
	confirmBtn.MouseButton1Click:Connect(function()
		if onConfirm then safeCall(onConfirm) end
		modalBg:Destroy()
		self.inputShield.Visible = false
	end)

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Text = "Cancel"
	cancelBtn.Size = UDim2.new(0, 120, 0, 36)
	cancelBtn.Position = UDim2.new(0.5, 10, 1, -46)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(80,85,98)
	cancelBtn.TextColor3 = Color3.fromRGB(220,225,235)
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.TextSize = 14
	cancelBtn.Parent = modal
	roundCorners(cancelBtn, 6)
	cancelBtn.MouseButton1Click:Connect(function()
		if onCancel then safeCall(onCancel) end
		modalBg:Destroy()
		self.inputShield.Visible = false
	end)
end

-- Notification Toast (queued)
function FluxUI:Notify(config)
	local function show(toastConfig)
		local toast = Instance.new("Frame")
		toast.Size = UDim2.new(0, 320, 0, 74)
		toast.Position = UDim2.new(1, 20, 1, 20)
		toast.BackgroundColor3 = Color3.fromRGB(35,40,50)
		toast.BorderSizePixel = 0
		toast.Parent = self.gui
		roundCorners(toast, 10)
		toast.ZIndex = 1000

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Text = toastConfig.Title or "Notification"
		titleLabel.Size = UDim2.new(1, -12, 0, 28)
		titleLabel.Position = UDim2.new(0, 6, 0, 6)
		titleLabel.TextColor3 = Color3.fromRGB(240,245,255)
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 14
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.BackgroundTransparency = 1
		titleLabel.Parent = toast

		local messageLabel = Instance.new("TextLabel")
		messageLabel.Text = toastConfig.Content or ""
		messageLabel.Size = UDim2.new(1, -12, 0, 34)
		messageLabel.Position = UDim2.new(0, 6, 0, 34)
		messageLabel.TextColor3 = Color3.fromRGB(180,190,220)
		messageLabel.Font = Enum.Font.Gotham
		messageLabel.TextSize = 12
		messageLabel.TextWrapped = true
		messageLabel.BackgroundTransparency = 1
		messageLabel.Parent = toast

		toast.Position = UDim2.new(1, 20, 1, 20)
		local tweenIn = TweenService:Create(toast, TweenInfo.new(0.3), {Position = UDim2.new(1, -340, 1, -90)})
		tweenIn:Play()
		task.wait(toastConfig.Duration or 3)
		local tweenOut = TweenService:Create(toast, TweenInfo.new(0.2), {Position = UDim2.new(1, 20, 1, 20)})
		tweenOut:Play()
		tweenOut.Completed:Wait()
		toast:Destroy()
		self.notificationActive = false
		if #self.notificationQueue > 0 then
			local next = table.remove(self.notificationQueue, 1)
			self.notificationActive = true
			show(next)
		end
	end

	if self.notificationActive then
		table.insert(self.notificationQueue, config)
	else
		self.notificationActive = true
		show(config)
	end
end

-- Theme Switcher (dark/light + accent)
function FluxUI:CreateThemeSwitcher(tab)
	local btn = Instance.new("TextButton")
	btn.Text = self.config.theme == "dark" and "Dark Theme" or "Light Theme"
	btn.Size = UDim2.new(0.9, 0, 0, 40)
	btn.BackgroundColor3 = Color3.fromRGB(50,58,72)
	btn.TextColor3 = Color3.fromRGB(220,225,235)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.Parent = tab.content
	roundCorners(btn, 8)
	btn.MouseButton1Click:Connect(function()
		self.config.theme = self.config.theme == "dark" and "light" or "dark"
		local bgCol = self.config.theme == "dark" and defaultTheme.background or Color3.fromRGB(245,245,252)
		local sideCol = self.config.theme == "dark" and defaultTheme.sidebar or Color3.fromRGB(235,238,245)
		TweenService:Create(self.window, TweenInfo.new(0.2), {BackgroundColor3 = bgCol}):Play()
		TweenService:Create(self.sidebar, TweenInfo.new(0.2), {BackgroundColor3 = sideCol}):Play()
		btn.Text = self.config.theme == "dark" and "Dark Theme" or "Light Theme"
	end)
	return btn
end

-- Keybind HUD (draggable)
function FluxUI:CreateKeybindHUD()
	local hud = Instance.new("Frame")
	hud.Size = UDim2.new(0, 240, 0, 120)
	hud.Position = UDim2.new(0, 12, 1, -130)
	hud.BackgroundColor3 = Color3.fromRGB(20,22,30)
	hud.BackgroundTransparency = 0.5
	hud.BorderSizePixel = 0
	hud.Parent = self.gui
	roundCorners(hud, 10)
	self.keybindHUD = hud

	local title = Instance.new("TextLabel")
	title.Text = "Active Keybinds"
	title.Size = UDim2.new(1, 0, 0, 28)
	title.TextColor3 = Color3.fromRGB(220,225,240)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.BackgroundTransparency = 1
	title.Parent = hud
	makeDraggable(hud, title, 0.2)

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = hud
	self.hudList = listLayout
end

function FluxUI:AddKeybindToHUD(name, key)
	if not self.keybindHUD then return end
	local lbl = Instance.new("TextLabel")
	lbl.Text = name .. ": " .. key
	lbl.Size = UDim2.new(1, -12, 0, 22)
	lbl.TextColor3 = Color3.fromRGB(200,210,235)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.BackgroundTransparency = 1
	lbl.Parent = self.keybindHUD
end

-- Config Reset
function FluxUI:ResetConfig()
	if self.config.saveKey then
		local path = self.config.saveFolder .. "/" .. self.config.saveKey .. ".json"
		pcall(function() writefile(path, "") end)
		self.savedSettings = {}
		self:Notify({Title = "Config Reset", Content = "Settings have been reset to default.", Duration = 2})
	end
end

-- Export/Import Theme
function FluxUI:ExportTheme()
	local themeData = {
		theme = self.config.theme,
		accent = self.config.accent,
		background = self.window.BackgroundColor3,
		sidebar = self.sidebar.BackgroundColor3
	}
	return HttpService:JSONEncode(themeData)
end

function FluxUI:ImportTheme(themeJson)
	local success, data = pcall(HttpService.JSONDecode, HttpService, themeJson)
	if success then
		self.config.theme = data.theme or self.config.theme
		self.config.accent = data.accent or self.config.accent
		local bgCol = (self.config.theme == "dark" and defaultTheme.background) or Color3.fromRGB(245,245,252)
		local sideCol = (self.config.theme == "dark" and defaultTheme.sidebar) or Color3.fromRGB(235,238,245)
		self.window.BackgroundColor3 = bgCol
		self.sidebar.BackgroundColor3 = sideCol
		self:Notify({Title = "Theme Imported", Content = "Theme applied successfully.", Duration = 2})
	else
		self:Notify({Title = "Error", Content = "Invalid theme data.", Duration = 2})
	end
end

-- Performance Mode
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

-- Auto-Update Check
function FluxUI:CheckForUpdates()
	local current = FluxUI.VERSION
	task.spawn(function()
		local success, res = pcall(function()
			return game:HttpGet("https://raw.githubusercontent.com/KercX/FluxUI/refs/heads/main/version.txt")
		end)
		if success and res then
			local latest = res:match("%d+%.%d+")
			if latest and latest ~= current then
				self:Notify({Title = "Update Available", Content = "Flux UI " .. latest .. " is out!", Duration = 5})
				self.statusText.Text = "Update available: v" .. latest
			else
				self.statusText.Text = "Up to date"
			end
		end
	end)
end

-- Save Config
function FluxUI:SaveConfig()
	if not self.config.saveKey then return end
	local path = self.config.saveFolder .. "/" .. self.config.saveKey .. ".json"
	pcall(function() writefile(path, HttpService:JSONEncode(self.savedSettings)) end)
end

-- Plugin Support
function FluxUI:RegisterPlugin(pluginFunc)
	safeCall(pluginFunc, self)
end

-- Help Tab (built-in)
function FluxUI:CreateHelpTab(parentTab)
	self:CreateParagraph(parentTab, "Flux UI Help\n\n- Drag the header to move the window.\n- Resize from the bottom-right corner.\n- Press Right Shift to hide/show the UI.\n- All settings are automatically saved.\n- Use Flags: FluxUI.Flags['ComponentName']\n- Right-click any component for options (coming soon).", true)
end

-- Destroy (full cleanup)
function FluxUI:Destroy()
	-- Ending sequence: fade out
	local fade = TweenService:Create(self.window, TweenInfo.new(0.3), {BackgroundTransparency = 1})
	fade:Play()
	fade.Completed:Wait()
	for _, conn in ipairs(self.globalConnections) do
		conn:Disconnect()
	end
	if self.gui then self.gui:Destroy() end
	for i, inst in ipairs(instances) do
		if inst == self then table.remove(instances, i) break end
	end
end

function FluxUI:DestroyAll()
	for _, inst in ipairs(instances) do
		inst:Destroy()
	end
	instances = {}
end

-- Export constructor
local function Init()
	return FluxUI.new()
end

return Init()
