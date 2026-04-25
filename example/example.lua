local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/KercX/FluxUI/refs/heads/main/src/main.lua"))()

local MainWindow = Library:CreateWindow({
    Name = "ExampleFluxUI",
    Author = "KercX",
    Folder = "MyConfigs",
    ConfigSaving = true,
    Theme = "dark"
})

local combatTab = MainWindow:CreateTab("Combat")
local visualsTab = MainWindow:CreateTab("Visuals")

MainWindow:CreateButton(combatTab, "Kill All", function()
    print("Executed kill all")
end, "rbxassetid://12345")

MainWindow:CreateToggle(combatTab, "Aimbot", false, function(state)
    print("Aimbot", state)
end)

MainWindow:CreateSlider(combatTab, "Smoothness", 0, 100, 50, function(val)
    print("Smoothness", val)
end)

MainWindow:CreateStepSlider(combatTab, "FOV Step", 10, 120, 10, 50, function(val)
    print("FOV", val)
end)

MainWindow:CreateDropdown(combatTab, "Hitbox", {"Head","Chest","Legs"}, false, "Head", function(sel)
    print("Hitbox", sel)
end)

MainWindow:CreateDropdown(visualsTab, "ESP Elements", {"Box","Name","Health","Weapon"}, true, {"Box","Name"}, function(list)
    print("ESP showing", table.concat(list, ", "))
end)

MainWindow:CreateKeybind(combatTab, "Trigger Key", "Q", function(key)
    print("Trigger key", key)
    MainWindow:AddKeybindToHUD("Trigger", key)
end)

MainWindow:CreateColorPicker(visualsTab, "ESP Color", Color3.new(1,0,0), function(c)
    print("Color", c)
end)

MainWindow:CreateTextBox(visualsTab, "Discord ID", "Enter ID", function(text)
    print("Discord", text)
end)

MainWindow:CreateNumberInput(combatTab, "Bullets", 30, function(num)
    print("Ammo", num)
end)

MainWindow:CreateCheckbox(combatTab, "Silent Aim", true, function(state)
    print("Silent aim", state)
end)

MainWindow:CreateRadioGroup(combatTab, "Priority", {"Closest","Lowest HP","Random"}, "Closest", function(opt)
    print("Priority", opt)
end)

local progress = MainWindow:CreateProgressBar(combatTab, "Loading Script", 100)
progress.set(0.5)

local spinner = MainWindow:CreateSpinner(combatTab, true)
task.wait(2)
spinner.setVisible(false)

MainWindow:CreateDivider(combatTab, "Aimbot Settings")
MainWindow:CreateLabel(visualsTab, "Information", 14, true)
MainWindow:CreateParagraph(visualsTab, "This script is for educational purposes only. Use at your own risk.")

local status = MainWindow:CreateStatusDot(combatTab, "Script Active", true)
status.setActive(true)

MainWindow:CreateClipboardButton(visualsTab, "Copy Discord Link", "https://discord.gg/example")

MainWindow:CreateThemeSwitcher(visualsTab)

MainWindow:Notify({Title = "FluxUI", Content = "Loaded successfully", Duration = 3})

-- Flags example
print("Aimbot state:", Library:GetFlag("Aimbot"))

-- Plugin example
Library:RegisterPlugin(function(ui)
    ui:Notify({Title = "Plugin", Content = "Hello from plugin"})
end)
