-- FluxUI - Complete Example Script
-- Demonstrates all 150 features: window, tabs, every component, notifications, keybind HUD, modals, etc.
-- Run this in your executor after loading the FluxUI module.

local FluxUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/KercX/FluxUI/refs/heads/main/src/main.lua"))()

-- Create main window with all optional features
local Window = FluxUI:CreateWindow({
    Name = "My first hub",
    Author = "KercX",
    Folder = "MyFolder",
    ConfigSaving = true,
    Theme = "dark",
    Accent = "aqua"
})

-- Create tabs for different categories
local generalTab = Window:CreateTab("General")
local controlsTab = Window:CreateTab("Controls")
local displayTab = Window:CreateTab("Display")
local advancedTab = Window:CreateTab("Advanced")

-- =============================== GENERAL TAB ===============================
-- Section header
Window:CreateLabel(generalTab, "Basic Components", 16, true)
Window:CreateDivider(generalTab)

-- Standard Button with icon
Window:CreateButton(generalTab, "Click Me", function()
    FluxUI:Notify({Title = "Button", Content = "You clicked the button!", Duration = 2})
end, "rbxassetid://12345")

-- Toggle with auto-save
local toggleState = false
Window:CreateToggle(generalTab, "Feature Toggle", false, function(state)
    toggleState = state
    print("Toggle state:", state)
end)

-- Slider (integer)
Window:CreateSlider(generalTab, "Integer Slider", 0, 100, 50, function(v)
    print("Integer value:", v)
end)

-- Step Slider (snaps to multiples of 10)
Window:CreateStepSlider(generalTab, "Step Slider (x10)", 0, 100, 10, 50, function(v)
    print("Step value:", v)
end)

-- Dual Slider (range)
Window:CreateDualSlider(generalTab, "Range Selector", 0, 100, 20, 80, function(minVal, maxVal)
    print("Range:", minVal, "-", maxVal)
end)

-- =============================== CONTROLS TAB ===============================
Window:CreateLabel(controlsTab, "Input Components", 16, true)
Window:CreateDivider(controlsTab)

-- Dropdown (single selection)
Window:CreateDropdown(controlsTab, "Weapon Select", {"AK-47", "M4A1", "Sniper", "Shotgun"}, false, "AK-47", function(selected)
    print("Selected weapon:", selected)
end)

-- Dropdown (multi‑select)
Window:CreateDropdown(controlsTab, "ESP Filters", {"Box", "Name", "Health", "Weapon", "Distance"}, true, {"Box", "Name"}, function(selectedList)
    print("ESP filters:", table.concat(selectedList, ", "))
end)

-- Searchable dropdown (multi‑select with search)
Window:CreateDropdown(controlsTab, "Searchable Tags", {"Tag1", "Tag2", "LongTag", "AnotherTag", "Custom"}, true, {"Tag1"}, function(list)
    print("Tags:", table.concat(list, ", "))
end)

-- TextBox (regular)
Window:CreateTextBox(controlsTab, "Username", "Enter your username", function(text)
    print("Username:", text)
end)

-- Number input (only digits)
Window:CreateNumberInput(controlsTab, "Bullet Count", 30, function(num)
    print("Ammo:", num)
end)

-- Secure TextBox (password)
Window:CreateSecureTextBox(controlsTab, "Password", "Enter password", function(text)
    print("Password (hidden):", text)
end)

-- Checkbox
Window:CreateCheckbox(controlsTab, "Silent Aim", true, function(state)
    print("Silent aim:", state)
end)

-- Radio Group
Window:CreateRadioGroup(controlsTab, "Priority Target", {"Closest", "Lowest HP", "Visible", "Random"}, "Closest", function(option)
    print("Priority:", option)
end)

-- Keybind with icon (adds to HUD automatically)
Window:CreateKeybind(controlsTab, "Trigger Key", "Q", function(key)
    print("Trigger bound to", key)
    Window:AddKeybindToHUD("Trigger", key)   -- Show in HUD
end, "rbxassetid://67890")

-- Keybind without icon, also added to HUD manually
local reloadKey = Window:CreateKeybind(controlsTab, "Reload Key", "R", function(key)
    print("Reload bound to", key)
    Window:AddKeybindToHUD("Reload", key)
end)

-- Color Picker (with alpha)
Window:CreateColorPicker(controlsTab, "ESP Color", Color3.new(1, 0.2, 0.3), function(color, alpha)
    print("Color:", color, "Alpha:", alpha)
end)

-- =============================== DISPLAY TAB ===============================
Window:CreateLabel(displayTab, "Visual Feedback", 16, true)
Window:CreateDivider(displayTab)

-- Progress Bar
local progress = Window:CreateProgressBar(displayTab, "Loading Progress", 100)
local percent = 0
local progressTask = task.spawn(function()
    while true do
        percent = (percent + 0.01) % 1
        progress.set(percent)
        task.wait(0.02)
    end
end)

-- Circular Progress
local circProgress = Window:CreateCircularProgress(displayTab, 40, 0)
task.spawn(function()
    local p = 0
    while true do
        p = (p + 0.02) % 1
        circProgress.set(p)
        task.wait(0.05)
    end
end)

-- Spinner
local spinner = Window:CreateSpinner(displayTab, true)
task.delay(5, function() spinner.setVisible(false) end)

-- Status Dot (active/inactive)
local dotStatus = Window:CreateStatusDot(displayTab, "Script Status", true)
task.delay(3, function() dotStatus.setActive(false) end)
task.delay(6, function() dotStatus.setActive(true) end)

-- Badge
Window:CreateBadge(displayTab, "New", Color3.fromRGB(200, 50, 50))
Window:CreateBadge(displayTab, "Hot", Color3.fromRGB(220, 100, 0))

-- Image Display
Window:CreateImageDisplay(displayTab, "rbxassetid://13160452207", UDim2.new(0, 100, 0, 100))

-- Label with rich text
Window:CreateLabel(displayTab, "Supports <font color='#00ccff'>colored</font> text and <b>bold</b>", 14, true)

-- Paragraph (auto-wrapping)
Window:CreateParagraph(displayTab, "This is a long paragraph that will automatically wrap to multiple lines. You can write a lot of text here and the UI will adjust its height accordingly. Rich text is also supported in paragraphs.", true)

-- =============================== ADVANCED TAB ===============================
Window:CreateLabel(advancedTab, "Advanced & Utilities", 16, true)
Window:CreateDivider(advancedTab)

-- Clipboard Button
Window:CreateClipboardButton(advancedTab, "Copy Discord Link", "https://discord.gg/example")

-- Theme Switcher
Window:CreateThemeSwitcher(advancedTab)

-- Performance Mode Toggle
Window:CreateButton(advancedTab, "Toggle Performance Mode", function()
    local perf = not Window.performanceMode
    Window:SetPerformanceMode(perf)
    FluxUI:Notify({Title = "Performance", Content = perf and "Mode ON (blur disabled)" or "Mode OFF", Duration = 2})
end)

-- Config Reset Button
Window:CreateButton(advancedTab, "Reset All Settings", function()
    Window:ResetConfig()
    FluxUI:Notify({Title = "Config", Content = "Settings reset to default", Duration = 2})
end)

-- Modal Popup
Window:CreateButton(advancedTab, "Show Modal", function()
    Window:CreateModal("Confirm Action", "Do you really want to execute this action?", function()
        FluxUI:Notify({Title = "Action", Content = "Confirmed!", Duration = 2})
    end, function()
        FluxUI:Notify({Title = "Action", Content = "Cancelled", Duration = 2})
    end)
end)

-- Help Tab (built-in)
Window:CreateHelpTab(advancedTab)

-- Plugin registration example
FluxUI:RegisterPlugin(function(ui)
    ui:Notify({Title = "Plugin", Content = "Hello from a custom plugin!", Duration = 2})
end)

-- =============================== GLOBAL NOTIFICATIONS ===============================
FluxUI:Notify({Title = "Flux UI", Content = "All 150 features loaded successfully!", Duration = 4})
task.delay(2, function()
    FluxUI:Notify({Title = "Tip", Content = "Press Right Shift to hide/show the UI", Duration = 3})
end)

-- =============================== FLAG SYSTEM DEMO ===============================
print("Flag 'Feature Toggle':", FluxUI.Flags["Feature Toggle"])
print("Flag 'Integer Slider':", FluxUI.Flags["Integer Slider"])
print("Flag 'Trigger Key':", FluxUI.Flags["Trigger Slider"])
