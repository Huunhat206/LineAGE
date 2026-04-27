-- ==========================================
-- 1. TỰ TẮT BẢNG CŨ (TRÁNH CHỒNG CHÉO)
-- ==========================================
if getgenv().NthucHub_UI then
    pcall(function() getgenv().NthucHub_UI:Destroy() end)
end

-- ==========================================
-- 2. LOAD THƯ VIỆN & TẠO KHUNG GUI
-- ==========================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

getgenv().NthucHub_UI = Fluent

local Window = Fluent:CreateWindow({
    Title = "Nthuc Hub",
    SubTitle = "by Nthuc",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark"
})

local Tabs = {
    Settings = Window:AddTab({ Title = "Cài Đặt Hub", Icon = "settings" })
}

-- ==========================================
-- 3. NÚT NỔI TẮT/MỞ UI (ĐÃ CHUYỂN LÊN ĐẦU)
-- ==========================================
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

if getgenv().NthucHub_ToggleButton then
    pcall(function() getgenv().NthucHub_ToggleButton:Destroy() end)
end

local guiTarget = nil
pcall(function() guiTarget = gethui() end)
if not guiTarget then pcall(function() guiTarget = game:GetService("CoreGui") end) end
if not guiTarget then guiTarget = Players.LocalPlayer:WaitForChild("PlayerGui") end

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "NthucHub_Toggle"
ToggleGui.ResetOnSpawn = false
ToggleGui.DisplayOrder = 999999
ToggleGui.Parent = guiTarget
getgenv().NthucHub_ToggleButton = ToggleGui

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0, 45, 0, 45)
Btn.Position = UDim2.new(0.85, 0, 0.15, 0)
Btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Btn.Text = "N"
Btn.Font = Enum.Font.GothamBold
Btn.TextSize = 22
Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn.AutoButtonColor = true
Btn.Parent = ToggleGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = Btn
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(150, 150, 150)
stroke.Thickness = 1.5
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = Btn

local dragging, dragInput, dragStart, startPos
Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Btn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

Btn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local clickTime = 0
Btn.MouseButton1Down:Connect(function() clickTime = tick() end)
Btn.MouseButton1Up:Connect(function()
    if tick() - clickTime < 0.2 then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
    end
end)

-- ==========================================
-- 5. TẢI CÁC MODULE (Autofarm, Autoraid...)
-- ==========================================
local githubRepo = "https://raw.githubusercontent.com/Huunhat206/LineAGE/main/"
local Modules = {
    "Autofarm.lua"
    -- Thêm các file khác vào đây sau này...
}

for _, fileName in ipairs(Modules) do
    local fileUrl = githubRepo .. fileName .. "?t=" .. tostring(tick())
    local success, sourceCode = pcall(function() return game:HttpGet(fileUrl) end)

    if success and not sourceCode:match("404: Not Found") then
        local func = loadstring(sourceCode)
        if func then
            pcall(function() func(Fluent, Window) end)
        end
    else
        warn("[Nthuc Hub] Không thể tải: " .. fileName)
    end
end

-- ==========================================
-- 6. SETUP HỆ THỐNG LƯU CONFIG
-- ==========================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("NthucHub")
SaveManager:SetFolder("NthucHub/GameConfig")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

local SectionAdvanced = Tabs.Settings:AddSection("Cài đặt Nâng cao")
local isAutoSaving = false
Tabs.Settings:AddToggle("Toggle_AutoSave", {
    Title = "Tự động lưu Config (Auto Save)",
    Description = "Lưu lại cài đặt hiện tại mỗi 30 giây",
    Default = false,
    Callback = function(Value)
        isAutoSaving = Value
        if Value then Fluent:Notify({ Title = "Nthuc Hub", Content = "Đã bật Auto Save!", Duration = 3 }) end
    end
})

task.spawn(function()
    while task.wait(30) do
        if isAutoSaving then
            local configName = SaveManager.CurrentConfig
            if not configName or configName == "" then configName = "AutoSave_Default" end
            pcall(function() SaveManager:Save(configName) end)
        end
    end
end)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
