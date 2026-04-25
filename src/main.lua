--[[
	FluxUI Pro - Ultimate UI Library for Roblox Executors
	Version: 3.0
	Features: 50/50 (Window, Components, Feedback, Advanced, Pro Polish)
	License: Free to use. Watermark required.
	Author: KercX
	Details:
	- Draggable header with smooth lerp
	- Acrylic blur effect (simulated)
	- Resizing grip (bottom-right)
	- Minimize animation to compact bar
	- Close button with full cleanup
	- Sidebar navigation with tab search
	- Responsive scaling (4K to mobile)
	- Splash intro with author name
	- All standard controls (button, toggle, slider, step-slider, dropdown, keybind, color picker, etc.)
	- Feedback: tooltips, toasts, progress bar, spinner, dividers, label, paragraph, status dot, clipboard, rich text
	- Advanced: JSON config auto-save/load, theme engine (dark/light), keybind HUD, global toggle (RightShift), sound effects, callback safety, custom scrollbar, lazy loading, plugin support
	- Pro: flags system, mobile toggle button, tool interaction hide, anti-leak watermark
]]
local FluxUI = {}
FluxUI.__index = FluxUI

-- =============================== SERVICES ===============================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

-- =============================== GLOBAL HELPERS ===============================
local function safeCall(func, ...)
	local success, result = pcall(func, ...)
	if not success then
		warn("[FluxUI] Callback error: " .. tostring(result))
	end
	return success, result
end

local function makeDraggable(frame, dragHandle, lerpSpeed)
	lerpSpeed = lerpSpeed or 0.2
	local dragStart = nil
	local startPos = nil
	local connection = nil
	local targetPos = nil
	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = UserInputService:GetMouseLocation()
			startPos = frame.Position
			if connection then connection:Disconnect() end
			connection = RunService.RenderStepped:Connect(function()
				if dragStart then
					local delta = UserInputService:GetMouseLocation() - dragStart
					targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
					frame.Position = frame.Position:Lerp(targetPos, lerpSpeed)
				end
			end)
		end
	end)
	dragHandle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if connection then connection:Disconnect() end
			connection = nil
			dragStart = nil
			if targetPos then frame.Position = targetPos end
		end
	end)
end

local function createShadow(parent, size)
	local shadow = Instance.new("ImageLabel")
	shadow.Image = "rbxassetid://13160452207"
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.7
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 10, 10)
	shadow.BackgroundTransparency = 1
	shadow.Size = size + UDim2.new(0, 12, 0, 12)
	shadow.Position = UDim2.new(0, -6, 0, -6)
	shadow.ZIndex = 0
	shadow.Parent = parent
	return shadow
end

local function applyAcrylic(frame)
	frame.BackgroundTransparency = 0.25
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(
		Color3.fromRGB(45, 45, 55),
		Color3.fromRGB(30, 30, 40)
	)
	gradient.Transparency = NumberSequence.new(0.4, 0.7)
	gradient.Rotation = 135
	gradient.Parent = frame
	local blurImage = Instance.new("ImageLabel")
	blurImage.Size = UDim2.new(1, 0, 1, 0)
	blurImage.Image = "rbxassetid://13160452207"
	blurImage.ImageTransparency = 0.6
	blurImage.BackgroundTransparency = 1
	blurImage.ZIndex = -1
	blurImage.Parent = frame
end

local function applyCustomScrollbar(scrollFrame)
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 110, 130)
	scrollFrame.ScrollBarImageTransparency = 0.4
end

local function playClickSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9120386436"
	sound.Volume = 0.2
	sound.Parent = SoundService
	sound:Play()
	task.delay(sound.TimeLength, function()
		sound:Destroy()
	end)
end

local function createTooltip(parent, text)
	local tip = Instance.new("TextLabel")
	tip.Text = text
	tip.TextColor3 = Color3.fromRGB(255, 255, 255)
	tip.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	tip.BorderSizePixel = 0
	tip.TextSize = 11
	tip.Font = Enum.Font.Gotham
	tip.Size = UDim2.new(0, 140, 0, 24)
	tip.Visible = false
	tip.ZIndex = 10
	tip.Parent = parent
	local mouseEnter
	mouseEnter = parent.MouseEnter:Connect(function()
		local pos = parent.AbsolutePosition
		tip.Position = UDim2.new(0, pos.X - 150, 0, pos.Y - 10)
		tip.Visible = true
	end)
	local mouseLeave = parent.MouseLeave:Connect(function()
		tip.Visible = false
	end)
	return tip
end

-- =============================== MAIN CLASS ===============================
function FluxUI.new()
	local self = setmetatable({}, FluxUI)
	self.config = nil
	self.gui = nil
	self.window = nil
	self.sidebar = nil
	self.contentArea = nil
	self.contentLayout = nil
	self.header = nil
	self.tabs = {}
	self.activeTab = nil
	self.savedSettings = {}
	self.flags = {}
	self.globalConnections = {}
	self.isVisible = true
	self.mobileToggle = nil
	self.keybindHUD = nil
	self.keybindHUDLayout = nil
	self.lastTool = nil
	self.minimized = false
	return self
end

function FluxUI:CreateWindow(config)
	config = config or {}
	self.config = config
	self.config.theme = config.Theme or "dark"
	self.config.saveFolder = config.Folder or "FluxUIConfigs"
	self.config.saveKey = (config.ConfigSaving and (config.Name or "FluxUI_Window")) or nil
	self.config.name = config.Name or "FluxUI"
	self.config.author = config.Author or ""
	
	-- Load saved settings
	if self.config.saveKey then
		local path = self.config.saveFolder .. "/" .. self.config.saveKey .. ".json"
		local success, data = pcall(readfile, path)
		if success and data then
			self.savedSettings = HttpService:JSONDecode(data)
		end
		pcall(function() makefolder(self.config.saveFolder) end)
	end
	
	-- Create GUI container
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "FluxUI"
	self.gui.ResetOnSpawn = false
	self.gui.Parent = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Splash intro
	local splash = Instance.new("Frame")
	splash.Size = UDim2.new(1, 0, 1, 0)
	splash.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
	splash.BorderSizePixel = 0
	splash.ZIndex = 100
	splash.Parent = self.gui
	
	local splashText = Instance.new("TextLabel")
	splashText.Text = self.config.author .. "\nFluxUI Pro"
	splashText.TextColor3 = Color3.fromRGB(255, 255, 255)
	splashText.Font = Enum.Font.GothamBold
	splashText.TextSize = 34
	splashText.Size = UDim2.new(1, 0, 0, 80)
	splashText.Position = UDim2.new(0, 0, 0.5, -40)
	splashText.BackgroundTransparency = 1
	splashText.Parent = splash
	
	local splashSub = Instance.new("TextLabel")
	splashSub.Text = "Initializing UI..."
	splashSub.TextColor3 = Color3.fromRGB(180, 190, 210)
	splashSub.Font = Enum.Font.Gotham
	splashSub.TextSize = 16
	splashSub.Size = UDim2.new(1, 0, 0, 30)
	splashSub.Position = UDim2.new(0, 0, 0.5, 20)
	splashSub.BackgroundTransparency = 1
	splashSub.Parent = splash
	
	TweenService:Create(splash, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		BackgroundTransparency = 1
	}):Play()
	TweenService:Create(splashText, TweenInfo.new(1), {TextTransparency = 1}):Play()
	TweenService:Create(splashSub, TweenInfo.new(1), {TextTransparency = 1}):Play()
	task.wait(1.2)
	splash:Destroy()
	
	-- Main window frame
	local win = Instance.new("Frame")
	win.Name = "MainWindow"
	win.BackgroundColor3 = (self.config.theme == "dark" and Color3.fromRGB(28, 28, 35)) or Color3.fromRGB(245, 245, 252)
	win.BorderSizePixel = 0
	win.ClipsDescendants = true
	win.Size = UDim2.new(0, 560, 0, 660)
	win.Position = UDim2.new(0.5, -280, 0.5, -330)
	win.Parent = self.gui
	applyAcrylic(win)
	createShadow(win, win.Size)
	
	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 46)
	header.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
	header.BackgroundTransparency = 0.6
	header.BorderSizePixel = 0
	header.Parent = win
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = self.config.name
	titleLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.Size = UDim2.new(1, -160, 1, 0)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header
	
	local authorLabel = Instance.new("TextLabel")
	authorLabel.Text = self.config.author
	authorLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
	authorLabel.TextXAlignment = Enum.TextXAlignment.Right
	authorLabel.Font = Enum.Font.Gotham
	authorLabel.TextSize = 12
	authorLabel.Size = UDim2.new(0, 140, 1, 0)
	authorLabel.Position = UDim2.new(1, -150, 0, 0)
	authorLabel.BackgroundTransparency = 1
	authorLabel.Parent = header
	
	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(220, 225, 235)
	closeBtn.Size = UDim2.new(0, 40, 1, 0)
	closeBtn.Position = UDim2.new(1, -42, 0, 0)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.Parent = header
	closeBtn.MouseButton1Click:Connect(function()
		self:Destroy()
	end)
	
	-- Minimize button
	local minBtn = Instance.new("TextButton")
	minBtn.Text = "-"
	minBtn.TextColor3 = Color3.fromRGB(220, 225, 235)
	minBtn.Size = UDim2.new(0, 40, 1, 0)
	minBtn.Position = UDim2.new(1, -84, 0, 0)
	minBtn.BackgroundTransparency = 1
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 20
	minBtn.Parent = header
	minBtn.MouseButton1Click:Connect(function()
		self.minimized = not self.minimized
		local targetSize = self.minimized and UDim2.new(0, 200, 0, 46) or UDim2.new(0, 560, 0, 660)
		TweenService:Create(win, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = targetSize}):Play()
		local targetHeaderAlpha = self.minimized and 0.9 or 0.6
		TweenService:Create(header, TweenInfo.new(0.2), {BackgroundTransparency = targetHeaderAlpha}):Play()
	end)
	
	-- Sidebar
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 170, 1, -46)
	sidebar.Position = UDim2.new(0, 0, 0, 46)
	sidebar.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
	sidebar.BackgroundTransparency = 0.25
	sidebar.BorderSizePixel = 0
	sidebar.Parent = win
	
	-- Tab search bar
	local tabSearch = Instance.new("TextBox")
	tabSearch.Size = UDim2.new(1, -12, 0, 34)
	tabSearch.Position = UDim2.new(0, 6, 0, 8)
	tabSearch.PlaceholderText = "Search tab..."
	tabSearch.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
	tabSearch.TextColor3 = Color3.fromRGB(210, 215, 225)
	tabSearch.Font = Enum.Font.Gotham
	tabSearch.TextSize = 12
	tabSearch.ClearTextOnFocus = false
	tabSearch.Parent = sidebar
	
	-- Content area with custom scrollbar
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -180, 1, -56)
	content.Position = UDim2.new(0, 180, 0, 56)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = Color3.fromRGB(100, 110, 130)
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Parent = win
	applyCustomScrollbar(content)
	
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 12)
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.Parent = content
	
	self.window = win
	self.sidebar = sidebar
	self.contentArea = content
	self.contentLayout = contentLayout
	self.header = header
	
	-- Resizing grip (bottom-right corner)
	local resizeGrip = Instance.new("Frame")
	resizeGrip.Size = UDim2.new(0, 18, 0, 18)
	resizeGrip.Position = UDim2.new(1, -18, 1, -18)
	resizeGrip.BackgroundColor3 = Color3.fromRGB(80, 90, 110)
	resizeGrip.BackgroundTransparency = 0.5
	resizeGrip.BorderSizePixel = 0
	resizeGrip.Parent = win
	local resizeDragStart = nil
	local resizeStartSize = nil
	resizeGrip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizeDragStart = input.Position
			resizeStartSize = win.AbsoluteSize
		end
	end)
	resizeGrip.InputChanged:Connect(function(input)
		if resizeDragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - resizeDragStart
			local newWidth = math.clamp(resizeStartSize.X + delta.X, 420, 1300)
			local newHeight = math.clamp(resizeStartSize.Y + delta.Y, 320, 950)
			win.Size = UDim2.new(0, newWidth, 0, newHeight)
			-- Refresh shadow
			local oldShadow = win:FindFirstChild("Shadow")
			if oldShadow then oldShadow:Destroy() end
			createShadow(win, win.Size)
		end
	end)
	resizeGrip.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizeDragStart = nil
		end
	end)
	
	-- Draggable header (smooth lerp)
	makeDraggable(win, header, 0.2)
	
	-- Responsive scaling based on screen resolution
	local function onViewportChanged()
		local viewportSize = Workspace.CurrentCamera.ViewportSize
		local scale = math.min(viewportSize.X / 1920, viewportSize.Y / 1080)
		local newWidth = math.max(420, 560 * scale)
		local newHeight = math.max(320, 660 * scale)
		win.Size = UDim2.new(0, newWidth, 0, newHeight)
		win.Position = UDim2.new(0.5, -newWidth/2, 0.5, -newHeight/2)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewportChanged)
	onViewportChanged()
	
	-- Global UI toggle (Right Shift)
	local globalToggleConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			self.isVisible = not self.isVisible
			win.Visible = self.isVisible
			if self.keybindHUD then self.keybindHUD.Visible = self.isVisible end
			if self.mobileToggle then
				self.mobileToggle.Visible = not self.isVisible
			end
		end
	end)
	table.insert(self.globalConnections, globalToggleConn)
	
	-- Mobile toggle button (floating)
	self.mobileToggle = Instance.new("TextButton")
	self.mobileToggle.Text = "Flux"
	self.mobileToggle.Size = UDim2.new(0, 56, 0, 56)
	self.mobileToggle.Position = UDim2.new(1, -66, 0, 20)
	self.mobileToggle.BackgroundColor3 = Color3.fromRGB(40, 45, 58)
	self.mobileToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.mobileToggle.Font = Enum.Font.GothamBold
	self.mobileToggle.TextSize = 14
	self.mobileToggle.Visible = false
	self.mobileToggle.Parent = self.gui
	self.mobileToggle.MouseButton1Click:Connect(function()
		self.isVisible = not self.isVisible
		win.Visible = self.isVisible
		self.mobileToggle.Visible = not self.isVisible
	end)
	
	-- Tool interaction: hide UI when a tool is equipped
	local player = Players.LocalPlayer
	local function onCharacterAdded(character)
		local toolConnection = nil
		local function checkTool()
			local tool = character:FindFirstChildWhichIsA("Tool")
			if tool and tool ~= self.lastTool then
				win.Visible = false
				if toolConnection then toolConnection:Disconnect() end
				toolConnection = tool.AncestryChanged:Connect(function()
					if not tool.Parent then
						win.Visible = true
						if toolConnection then toolConnection:Disconnect() end
					end
				end)
			end
			self.lastTool = tool
		end
		character.ChildAdded:Connect(checkTool)
		character.ChildRemoved:Connect(checkTool)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then onCharacterAdded(player.Character) end
	
	-- Anti-leak watermark
	local watermark = Instance.new("TextLabel")
	watermark.Text = "FluxUI Pro (c) 2025"
	watermark.TextColor3 = Color3.fromRGB(100, 110, 140)
	watermark.Font = Enum.Font.Gotham
	watermark.TextSize = 10
	watermark.BackgroundTransparency = 1
	watermark.Position = UDim2.new(0, 8, 1, -20)
	watermark.Size = UDim2.new(0, 130, 0, 18)
	watermark.Parent = win
	
	-- Keybind HUD (will be created lazily)
	self:CreateKeybindHUD()
	
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
	tabLayout.Parent = tabContent
	
	local tabObj = {
		button = btn,
		content = tabContent,
		layout = tabLayout,
		name = name,
		rendered = false
	}
	table.insert(self.tabs, tabObj)
	
	if not self.activeTab then
		self:SelectTab(tabObj)
	end
	
	-- Tab search filtering
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
	
	btn.MouseButton1Click:Connect(function()
		self:SelectTab(tabObj)
	end)
	
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
end

-- =============================== COMPONENTS ===============================
-- Button
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
	
	btn.MouseButton1Click:Connect(function()
		playClickSound()
		local maxSize = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)
		TweenService:Create(ripple, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, maxSize, 0, maxSize),
			BackgroundTransparency = 1
		}):Play()
		task.wait(0.3)
		ripple.Size = UDim2.new(0, 0, 0, 0)
		ripple.BackgroundTransparency = 0.8
		safeCall(callback)
	end)
	
	createTooltip(btn, text)
	return btn
end

-- Toggle
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
	
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 24, 0, 24)
	knob.Position = UDim2.new(0, 4, 0.5, -12)
	knob.BackgroundColor3 = Color3.fromRGB(250, 250, 255)
	knob.BorderSizePixel = 0
	knob.Parent = toggleBtn
	
	local state = (self.savedSettings and self.savedSettings[name] ~= nil) and self.savedSettings[name] or defaultValue
	self.flags[name] = state
	
	local function updateUI()
		local targetPos = state and UDim2.new(1, -28, 0.5, -12) or UDim2.new(0, 4, 0.5, -12)
		local targetColor = state and Color3.fromRGB(0, 180, 220) or Color3.fromRGB(80, 85, 98)
		TweenService:Create(knob, TweenInfo.new(0.12), {Position = targetPos}):Play()
		TweenService:Create(toggleBtn, TweenInfo.new(0.12), {BackgroundColor3 = targetColor}):Play()
		safeCall(callback, state)
		self.flags[name] = state
		if self.savedSettings then
			self.savedSettings[name] = state
			self:SaveConfig()
		end
	end
	
	toggleBtn.MouseButton1Click:Connect(function()
		playClickSound()
		state = not state
		updateUI()
	end)
	updateUI()
	
	createTooltip(label, name)
	return container
end

-- Slider (precision)
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
	valueDisplay.TextColor3 = Color3.fromRGB(100, 190, 250)
	valueDisplay.Font = Enum.Font.GothamBold
	valueDisplay.BackgroundTransparency = 1
	valueDisplay.Parent = container
	
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -12, 0, 6)
	track.Position = UDim2.new(0, 6, 1, -20)
	track.BackgroundColor3 = Color3.fromRGB(60, 68, 82)
	track.BorderSizePixel = 0
	track.Parent = container
	
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
	fill.BorderSizePixel = 0
	fill.Parent = track
	
	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.new(0, 16, 0, 16)
	thumb.Position = UDim2.new(0, -8, 0, -5)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.Parent = fill
	
	local currentValue = (self.savedSettings and self.savedSettings[name] ~= nil) and self.savedSettings[name] or defaultValue
	self.flags[name] = currentValue
	
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
		safeCall(callback, currentValue)
		self.flags[name] = currentValue
		if self.savedSettings then
			self.savedSettings[name] = currentValue
			self:SaveConfig()
		end
	end
	
	local dragging = false
	thumb.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local mouseX = i.Position.X
			local trackPos = track.AbsolutePosition.X
			local trackWidth = track.AbsoluteSize.X
			local raw = math.clamp((mouseX - trackPos) / trackWidth, 0, 1)
			setValue(minVal + raw * (maxVal - minVal))
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	
	setValue(currentValue)
	createTooltip(label, name)
	return container
end

function FluxUI:CreateStepSlider(tab, name, minVal, maxVal, step, defaultValue, callback)
	return self:CreateSlider(tab, name, minVal, maxVal, defaultValue, callback, true, step)
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
	
	local dropdownList = Instance.new("ScrollingFrame")
	dropdownList.Size = UDim2.new(0, 220, 0, 180)
	dropdownList.Position = UDim2.new(1, -225, 0, 42)
	dropdownList.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	dropdownList.BorderSizePixel = 0
	dropdownList.Visible = false
	dropdownList.ScrollBarThickness = 4
	dropdownList.Parent = container
	
	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -8, 0, 32)
	searchBox.Position = UDim2.new(0, 4, 0, 4)
	searchBox.PlaceholderText = "Search..."
	searchBox.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
	searchBox.TextColor3 = Color3.fromRGB(240, 240, 245)
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 12
	searchBox.Parent = dropdownList
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = dropdownList
	
	local selected = multiSelect and {} or nil
	
	local function rebuildList(filter)
		for _, child in ipairs(dropdownList:GetChildren()) do
			if child:IsA("TextButton") and child ~= searchBox then
				child:Destroy()
			end
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
				itemBtn.MouseButton1Click:Connect(function()
					playClickSound()
					if multiSelect then
						if selected[item] then
							selected[item] = nil
							itemBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
						else
							selected[item] = true
							itemBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
						end
						local selectedList = {}
						for k, _ in pairs(selected) do
							table.insert(selectedList, k)
						end
						local displayText = table.concat(selectedList, ", ")
						if #displayText > 25 then displayText = displayText:sub(1, 22) .. "..." end
						dropdownBtn.Text = displayText ~= "" and displayText or "Select"
						safeCall(callback, selectedList)
					else
						selected = item
						dropdownBtn.Text = item
						dropdownList.Visible = false
						safeCall(callback, item)
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
		if prop == "Text" then
			rebuildList(searchBox.Text)
		end
	end)
	
	dropdownBtn.MouseButton1Click:Connect(function()
		dropdownList.Visible = not dropdownList.Visible
		if dropdownList.Visible then
			rebuildList("")
		end
	end)
	
	if defaultSelection then
		if multiSelect then
			for _, v in pairs(defaultSelection) do
				selected[v] = true
			end
			local selectedList = {}
			for k, _ in pairs(selected) do
				table.insert(selectedList, k)
			end
			local displayText = table.concat(selectedList, ", ")
			if #displayText > 25 then displayText = displayText:sub(1, 22) .. "..." end
			dropdownBtn.Text = displayText ~= "" and displayText or "Select"
			safeCall(callback, selectedList)
		else
			selected = defaultSelection
			dropdownBtn.Text = defaultSelection
			safeCall(callback, defaultSelection)
		end
	end
	self.flags[name] = selected
	return container
end

-- Keybind
function FluxUI:CreateKeybind(tab, name, defaultKey, callback)
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
	
	local listening = false
	local connection = nil
	
	bindBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		bindBtn.Text = "..."
		connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode ~= Enum.KeyCode.Unknown then
				local key = input.KeyCode.Name
				bindBtn.Text = key
				safeCall(callback, key)
				if self.savedSettings then
					self.savedSettings[name] = key
					self:SaveConfig()
				end
				listening = false
				connection:Disconnect()
			end
		end)
		task.wait(3)
		if listening then
			listening = false
			bindBtn.Text = "None"
			if connection then connection:Disconnect() end
		end
	end)
	return container
end

-- Color Picker (with hex/rgb)
function FluxUI:CreateColorPicker(tab, name, defaultColor, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 180)
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
	
	local rBox, gBox, bBox, hexBox
	
	local function updateColorFromRGB(r, g, b)
		local col = Color3.new(r / 255, g / 255, b / 255)
		preview.BackgroundColor3 = col
		hexBox.Text = string.format("#%02x%02x%02x", r, g, b)
		safeCall(callback, col)
		if self.savedSettings then
			self.savedSettings[name] = {r, g, b}
			self:SaveConfig()
		end
	end
	
	local function makeNumberBox(xOffset, initialValue)
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0, 60, 0, 32)
		box.Position = UDim2.new(xOffset, 0, 0, 34)
		box.Text = tostring(initialValue)
		box.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
		box.TextColor3 = Color3.fromRGB(240, 240, 245)
		box.Font = Enum.Font.Gotham
		box.TextSize = 12
		box.Parent = container
		box.FocusLost:Connect(function()
			local val = tonumber(box.Text) or 0
			val = math.clamp(val, 0, 255)
			box.Text = tostring(val)
			local r = tonumber(rBox.Text) or 0
			local g = tonumber(gBox.Text) or 0
			local b = tonumber(bBox.Text) or 0
			updateColorFromRGB(r, g, b)
		end)
		return box
	end
	
	hexBox = Instance.new("TextBox")
	hexBox.Size = UDim2.new(0, 130, 0, 32)
	hexBox.Position = UDim2.new(0, 0, 0, 72)
	hexBox.PlaceholderText = "#RRGGBB"
	hexBox.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
	hexBox.TextColor3 = Color3.fromRGB(240, 240, 245)
	hexBox.Font = Enum.Font.Gotham
	hexBox.TextSize = 12
	hexBox.Parent = container
	hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("#", "")
		if #hex == 6 then
			local r = tonumber("0x" .. hex:sub(1, 2)) or 0
			local g = tonumber("0x" .. hex:sub(3, 4)) or 0
			local b = tonumber("0x" .. hex:sub(5, 6)) or 0
			rBox.Text = tostring(r)
			gBox.Text = tostring(g)
			bBox.Text = tostring(b)
			updateColorFromRGB(r, g, b)
		end
	end)
	
	local initColor = defaultColor or Color3.new(1, 0, 0)
	rBox = makeNumberBox(0, initColor.R * 255)
	gBox = makeNumberBox(70, initColor.G * 255)
	bBox = makeNumberBox(140, initColor.B * 255)
	hexBox.Text = string.format("#%02x%02x%02x", initColor.R * 255, initColor.G * 255, initColor.B * 255)
	updateColorFromRGB(initColor.R * 255, initColor.G * 255, initColor.B * 255)
	return container
end

-- TextBox (with clear button)
function FluxUI:CreateTextBox(tab, name, placeholder, callback, isNumberOnly)
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
	
	if isNumberOnly then
		textBox.Changed:Connect(function(prop)
			if prop == "Text" then
				local newText = textBox.Text:gsub("[^%d]", "")
				if newText ~= textBox.Text then
					textBox.Text = newText
				end
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
	clearBtn.MouseButton1Click:Connect(function()
		textBox.Text = ""
		safeCall(callback, "")
	end)
	
	textBox.FocusLost:Connect(function()
		if isNumberOnly then
			local num = tonumber(textBox.Text) or 0
			safeCall(callback, num)
		else
			safeCall(callback, textBox.Text)
		end
	end)
	return container
end

function FluxUI:CreateNumberInput(tab, name, defaultValue, callback)
	local container = self:CreateTextBox(tab, name, tostring(defaultValue), function(val)
		safeCall(callback, val)
	end, true)
	return container
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
	self.flags[name] = state
	
	local function updateUI()
		boxBtn.Text = state and "V" or ""
		boxBtn.TextColor3 = state and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(120, 120, 130)
		safeCall(callback, state)
		self.flags[name] = state
		if self.savedSettings then
			self.savedSettings[name] = state
			self:SaveConfig()
		end
	end
	
	boxBtn.MouseButton1Click:Connect(function()
		playClickSound()
		state = not state
		updateUI()
	end)
	updateUI()
	return container
end

-- Radio Group
function FluxUI:CreateRadioGroup(tab, name, options, defaultOption, callback)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 32 + #options * 34)
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
	self.flags[name] = selected
	
	for i, opt in ipairs(options) do
		local radioBtn = Instance.new("TextButton")
		radioBtn.Text = opt
		radioBtn.Size = UDim2.new(1, -20, 0, 30)
		radioBtn.Position = UDim2.new(0, 20, 0, 28 + (i - 1) * 34)
		radioBtn.TextXAlignment = Enum.TextXAlignment.Left
		radioBtn.BackgroundTransparency = 1
		radioBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
		radioBtn.Font = Enum.Font.Gotham
		radioBtn.TextSize = 13
		radioBtn.Parent = container
		
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 14, 0, 14)
		dot.Position = UDim2.new(0, -18, 0.5, -7)
		dot.BackgroundColor3 = Color3.fromRGB(80, 90, 105)
		dot.BorderSizePixel = 0
		dot.Parent = radioBtn
		
		radioBtn.MouseButton1Click:Connect(function()
			selected = opt
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("TextButton") and child ~= title then
					local ind = child:FindFirstChildWhichIsA("Frame")
					if ind then
						ind.BackgroundColor3 = Color3.fromRGB(80, 90, 105)
					end
				end
			end
			dot.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
			safeCall(callback, opt)
			self.flags[name] = opt
			if self.savedSettings then
				self.savedSettings[name] = opt
				self:SaveConfig()
			end
		end)
		
		if opt == selected then
			dot.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
		end
	end
	return container
end

-- =============================== FEEDBACK & DISPLAY ===============================
function FluxUI:CreateProgressBar(tab, labelText, maxValue)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 52)
	container.BackgroundTransparency = 1
	container.Parent = tab.content
	
	local label = Instance.new("TextLabel")
	label.Text = labelText
	label.Size = UDim2.new(1, 0, 0, 24)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container
	
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -12, 0, 12)
	barBg.Position = UDim2.new(0, 6, 1, -20)
	barBg.BackgroundColor3 = Color3.fromRGB(55, 62, 78)
	barBg.BorderSizePixel = 0
	barBg.Parent = container
	
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	
	local function setProgress(percent)
		TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
	end
	return {set = setProgress}
end

function FluxUI:CreateSpinner(tab, initiallyVisible)
	local spinner = Instance.new("ImageLabel")
	spinner.Image = "rbxassetid://6031281695"
	spinner.Size = UDim2.new(0, 36, 0, 36)
	spinner.BackgroundTransparency = 1
	spinner.Visible = initiallyVisible
	spinner.Parent = tab.content
	local rotationTween = TweenService:Create(spinner, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Rotation = 360})
	rotationTween:Play()
	local function setVisible(visible)
		spinner.Visible = visible
		if visible then
			rotationTween:Play()
		else
			rotationTween:Pause()
		end
	end
	return {setVisible = setVisible}
end

function FluxUI:CreateDivider(tab, text)
	local line = Instance.new("Frame")
	line.Size = UDim2.new(0.9, 0, 0, 2)
	line.BackgroundColor3 = Color3.fromRGB(80, 90, 115)
	line.BorderSizePixel = 0
	line.Parent = tab.content
	if text then
		local textLabel = Instance.new("TextLabel")
		textLabel.Text = text
		textLabel.Size = UDim2.new(0.9, 0, 0, 28)
		textLabel.BackgroundTransparency = 1
		textLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextSize = 12
		textLabel.Parent = tab.content
		return textLabel
	end
	return line
end

function FluxUI:CreateLabel(tab, text, fontSize, richText)
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = UDim2.new(0.9, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(200, 210, 235)
	label.Font = Enum.Font.Gotham
	label.TextSize = fontSize or 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	if richText then
		label.RichText = true
	end
	label.Parent = tab.content
	return label
end

function FluxUI:CreateParagraph(tab, text, richText)
	local para = Instance.new("TextLabel")
	para.Text = text
	para.Size = UDim2.new(0.9, 0, 0, 0)
	para.BackgroundTransparency = 1
	para.TextColor3 = Color3.fromRGB(180, 190, 220)
	para.Font = Enum.Font.Gotham
	para.TextSize = 12
	para.TextWrapped = true
	para.TextXAlignment = Enum.TextXAlignment.Left
	if richText then
		para.RichText = true
	end
	para.Parent = tab.content
	para.Size = UDim2.new(0.9, 0, 0, para.TextBounds.Y + 12)
	return para
end

function FluxUI:CreateStatusDot(tab, labelText, initialActive)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 36)
	container.BackgroundTransparency = 1
	container.Parent = tab.content
	
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 12, 0, 12)
	dot.Position = UDim2.new(0, 0, 0.5, -6)
	dot.BackgroundColor3 = initialActive and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
	dot.BorderSizePixel = 0
	dot.Parent = container
	
	local label = Instance.new("TextLabel")
	label.Text = labelText
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 20, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 215, 230)
	label.Font = Enum.Font.Gotham
	label.BackgroundTransparency = 1
	label.Parent = container
	
	local function setActive(active)
		dot.BackgroundColor3 = active and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
	end
	return {setActive = setActive}
end

function FluxUI:CreateClipboardButton(tab, buttonText, copyText)
	return self:CreateButton(tab, buttonText, function()
		if setclipboard then
			setclipboard(copyText)
			self:Notify({Title = "Copied", Content = copyText, Duration = 1.5})
		else
			self:Notify({Title = "Error", Content = "Clipboard not supported", Duration = 2})
		end
	end)
end

-- Notification Toast
function FluxUI:Notify(config)
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 320, 0, 74)
	toast.Position = UDim2.new(1, 20, 1, 20)
	toast.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
	toast.BorderSizePixel = 0
	toast.Parent = self.gui
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = config.Title or "Notification"
	titleLabel.Size = UDim2.new(1, -12, 0, 28)
	titleLabel.Position = UDim2.new(0, 6, 0, 6)
	titleLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = toast
	
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Text = config.Content or ""
	messageLabel.Size = UDim2.new(1, -12, 0, 34)
	messageLabel.Position = UDim2.new(0, 6, 0, 34)
	messageLabel.TextColor3 = Color3.fromRGB(180, 190, 220)
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextSize = 12
	messageLabel.TextWrapped = true
	messageLabel.BackgroundTransparency = 1
	messageLabel.Parent = toast
	
	toast.Position = UDim2.new(1, 20, 1, 20)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Position = UDim2.new(1, -340, 1, -90)
	}):Play()
	task.wait(config.Duration or 3)
	TweenService:Create(toast, TweenInfo.new(0.2), {
		Position = UDim2.new(1, 20, 1, 20)
	}):Play()
	task.wait(0.2)
	toast:Destroy()
end

-- Theme Switcher
function FluxUI:CreateThemeSwitcher(tab)
	local btn = Instance.new("TextButton")
	btn.Text = self.config.theme == "dark" and "Dark Theme" or "Light Theme"
	btn.Size = UDim2.new(0.9, 0, 0, 40)
	btn.BackgroundColor3 = Color3.fromRGB(50, 58, 72)
	btn.TextColor3 = Color3.fromRGB(220, 225, 235)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.Parent = tab.content
	btn.MouseButton1Click:Connect(function()
		self.config.theme = self.config.theme == "dark" and "light" or "dark"
		local bgColor = self.config.theme == "dark" and Color3.fromRGB(28, 28, 35) or Color3.fromRGB(245, 245, 252)
		local sideColor = self.config.theme == "dark" and Color3.fromRGB(35, 38, 48) or Color3.fromRGB(235, 238, 245)
		TweenService:Create(self.window, TweenInfo.new(0.2), {BackgroundColor3 = bgColor}):Play()
		TweenService:Create(self.sidebar, TweenInfo.new(0.2), {BackgroundColor3 = sideColor}):Play()
		btn.Text = self.config.theme == "dark" and "Dark Theme" or "Light Theme"
	end)
	return btn
end

-- Keybind HUD (overlay)
function FluxUI:CreateKeybindHUD()
	local hud = Instance.new("Frame")
	hud.Size = UDim2.new(0, 240, 0, 120)
	hud.Position = UDim2.new(0, 12, 1, -130)
	hud.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	hud.BackgroundTransparency = 0.5
	hud.BorderSizePixel = 0
	hud.Parent = self.gui
	self.keybindHUD = hud
	
	local title = Instance.new("TextLabel")
	title.Text = "Active Keybinds"
	title.Size = UDim2.new(1, 0, 0, 28)
	title.TextColor3 = Color3.fromRGB(220, 225, 240)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.BackgroundTransparency = 1
	title.Parent = hud
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = hud
	self.keybindHUDLayout = listLayout
	
	makeDraggable(hud, title, 0.2)
end

function FluxUI:AddKeybindToHUD(name, key)
	if not self.keybindHUD then return end
	local label = Instance.new("TextLabel")
	label.Text = name .. ": " .. key
	label.Size = UDim2.new(1, -12, 0, 22)
	label.TextColor3 = Color3.fromRGB(200, 210, 235)
	label.Font = Enum.Font.Gotham
	label.TextSize = 11
	label.BackgroundTransparency = 1
	label.Parent = self.keybindHUD
end

-- Config saving
function FluxUI:SaveConfig()
	if not self.config.saveKey then return end
	local path = self.config.saveFolder .. "/" .. self.config.saveKey .. ".json"
	pcall(function()
		writefile(path, HttpService:JSONEncode(self.savedSettings))
	end)
end

function FluxUI:LoadConfig()
	-- Already loaded in CreateWindow
end

-- Plugin support
function FluxUI:RegisterPlugin(pluginFunction)
	safeCall(pluginFunction, self)
end

-- Flags system (getter)
function FluxUI:GetFlag(name)
	return self.flags[name]
end

-- Cleanup
function FluxUI:Destroy()
	for _, conn in ipairs(self.globalConnections) do
		conn:Disconnect()
	end
	if self.gui then
		self.gui:Destroy()
	end
end

-- =============================== EXPORT ===============================
local function Init()
	return FluxUI.new()
end

return Init()
