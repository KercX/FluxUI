local Flux = loadstring(game:HttpGet("https://raw.githubusercontent.com/KercX/FluxUI/refs/heads/main/src/main.lua"))()  -- replace with your raw URL

-- Create main window with Ocean theme
local window = Flux:CreateWindow({
    Title = "FluxUI Demo",
    SubTitle = "All Elements Showcase",
    TabWidth = 180,
    Size = UDim2.fromOffset(700, 550),
    Acrylic = true,          -- glass effect
    Resizable = true,
    Theme = "Ocean"          -- Ocean / Sunset / Forest / Dark / Light
})

-- ===========================
-- TAB: COMBAT
-- ===========================
local combatTab = window:AddTab("Combat")

-- Section: Weapons
local weaponsSec = combatTab:AddSection("Weapons")
weaponsSec:AddButton("Swing Sword", function()
    print("Sword swung!")
    Flux:Notify("Combat", "You swung your sword", 2, "info")
end)

weaponsSec:AddButton("Shoot Bow", function()
    print("Arrow shot!")
    Flux:Notify("Combat", "Arrow fired", 1.5, "success")
end)

-- Toggle example
local autoSwing = weaponsSec:AddToggle("Auto Swing", "auto_swing", true, function(state)
    print("Auto swing enabled:", state)
end)

-- Slider example
weaponsSec:AddSlider("Swing Speed", "swing_speed", 0.5, 3, 1.2, 0.1, function(value)
    print("Swing speed set to:", value)
end)

-- Section: Targeting
local targetSec = combatTab:AddSection("Targeting")
targetSec:AddDropdown("Target Priority", "target_mode", {"Nearest", "Lowest HP", "Random"}, "Lowest HP", function(selected)
    print("Target mode:", selected)
end)

targetSec:AddKeybind("Lock Target", "lock_key", "Q", function(key)
    print("Lock target key set to:", key)
end)

targetSec:AddColorPicker("ESP Color", "esp_color", Color3.new(0, 1, 0), function(color)
    print("ESP color changed to:", color)
end)

-- ===========================
-- TAB: VISUALS
-- ===========================
local visualsTab = window:AddTab("Visuals")

-- Section: ESP Settings
local espSec = visualsTab:AddSection("ESP")
espSec:AddToggle("Player ESP", "esp_enabled", true, function(val)
    print("ESP enabled:", val)
end)

espSec:AddToggle("Show Names", "esp_names", true)
espSec:AddToggle("Show Distance", "esp_distance", false)

espSec:AddSlider("ESP Transparency", "esp_trans", 0, 1, 0.3, 0.05, function(val)
    print("Transparency:", val)
end)

espSec:AddParagraph("ESP will highlight enemies through walls. Adjust colors above.")

-- Section: Misc Visuals
local visMisc = visualsTab:AddSection("Misc")
visMisc:AddProgressBar("Render Quality", "render_quality", 0, 100, 75)
visMisc:AddSeparator()
visMisc:AddRadioGroup("UI Style", "ui_style", {"Modern", "Classic", "Minimal"}, "Modern", function(style)
    print("UI style selected:", style)
end)

-- ===========================
-- TAB: UTILITIES
-- ===========================
local utilsTab = window:AddTab("Utilities")

-- Section: Text Input
local textSec = utilsTab:AddSection("Text Input")
local textbox = textSec:AddTextbox("Player Message", "message", "Hello!", function(msg)
    print("Message changed:", msg)
end)

textSec:AddButton("Send Message", function()
    local msg = textbox.Get()
    print("Sending:", msg)
    Flux:Notify("Message", "Sent: " .. msg, 2, "info")
end)

-- Section: Expandable Example
local advSec = utilsTab:AddExpandableSection("Advanced Settings", function(inner)
    inner:AddButton("Reset All Config", function()
        Flux:ResetAllFlags()
        Flux:Notify("Config", "All flags reset to defaults", 2, "warning")
    end)
    inner:AddToggle("Debug Mode", "debug_mode", false, function(state)
        print("Debug mode:", state)
    end)
    inner:AddSlider("Max FPS", "max_fps", 30, 240, 60, 1)
end)

-- ===========================
-- TAB: THEMES
-- ===========================
local themeTab = window:AddTab("Themes")

local themeSec = themeTab:AddSection("Switch Theme")
themeSec:AddButton("Ocean", function()
    Flux:SetTheme("Ocean")
end)
themeSec:AddButton("Sunset", function()
    Flux:SetTheme("Sunset")
end)
themeSec:AddButton("Forest", function()
    Flux:SetTheme("Forest")
end)
themeSec:AddButton("Dark", function()
    Flux:SetTheme("Dark")
end)
themeSec:AddButton("Light", function()
    Flux:SetTheme("Light")
end)

-- Section: Custom Theme Registration (example)
local customSec = themeTab:AddSection("Custom Theme")
customSec:AddButton("Register Neon Theme", function()
    Flux:RegisterTheme("Neon", {
        Primary = Color3.fromRGB(20, 20, 40),
        Secondary = Color3.fromRGB(40, 40, 70),
        Accent = Color3.fromRGB(255, 50, 150),
        Text = Color3.fromRGB(255, 255, 255),
        TextDim = Color3.fromRGB(200, 200, 210),
        Border = Color3.fromRGB(80, 80, 120),
        Positive = Color3.fromRGB(0, 255, 100),
        Negative = Color3.fromRGB(255, 50, 50),
        Warning = Color3.fromRGB(255, 200, 0),
        AcrylicTransparency = 0.85,
    })
    Flux:SetTheme("Neon")
    Flux:Notify("Theme", "Neon theme applied", 2, "success")
end)

-- ===========================
-- NOTIFICATION EXAMPLES
-- ===========================
-- Show welcome notification
Flux:Notify("FluxUI", "All elements loaded successfully!", 3, "success")

-- You can also call notifications from anywhere:
task.delay(2, function()
    Flux:Notify("Tip", "Try clicking the buttons and toggles", 4, "info")
end)
