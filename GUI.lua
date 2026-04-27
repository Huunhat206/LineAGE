-- ==========================================
-- 1. TỰ TẮT BẢNG CŨ (TRÁNH CHỒNG CHÉO)
-- ==========================================
if getgenv().NthucHub_UI then
    pcall(function()
        getgenv().NthucHub_UI:Destroy()
    end)
end

-- ==========================================
-- 2. LOAD THƯ VIỆN & ADDONS
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
-- 3. TẢI CÁC MODULE (Autofarm, Autoraid...)
-- ==========================================
local githubRepo = "https://raw.githubusercontent.com/Huunhat206/LineAGE/main/"
local Modules = {
    "Autofarm.lua"
    -- Thêm các file khác vào đây: "Autoraid.lua", "Misc.lua"...
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
        warn("[Nthuc Hub] Không thể kết nối tới Github để tải: " .. fileName)
    end
end

-- ==========================================
-- 4. SETUP HỆ THỐNG LƯU CẤU HÌNH & AUTO SAVE
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
        if Value then
            Fluent:Notify({ Title = "Nthuc Hub", Content = "Đã bật Auto Save!", Duration = 3 })
        end
    end
})

task.spawn(function()
    while task.wait(30) do
        if isAutoSaving then
            local configName = SaveManager.CurrentConfig
            if not configName or configName == "" then
                configName = "AutoSave_Default"
            end
            pcall(function() SaveManager:Save(configName) end)
        end
    end
end)

-- ==========================================
-- 5. FIX LỖI MẤT CHUỘT (Ấn LEFT ALT)
-- ==========================================
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local isMouseForced = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        isMouseForced = not isMouseForced
        if getgenv().NthucHub_UI then
            getgenv().NthucHub_UI:Notify({
                Title = "Hệ thống Chuột",
                Content = isMouseForced and "Đã MỞ khóa chuột!" or "Đã KHÓA chuột theo game!",
                Duration = 2
            })
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if isMouseForced then
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

-- ==========================================
-- 6. NÚT NỔI TẮT/MỞ UI (Kéo Thả Được)
-- ==========================================
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

if getgenv().NthucHub_ToggleButton then
    pcall(function() getgenv().NthucHub_ToggleButton:Destroy() end)
end

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "NthucHub_Toggle"
ToggleGui.Parent = CoreGui
getgenv().NthucHub_ToggleButton = ToggleGui

local Btn = Instance.new("TextButton")
Btn.Name = "ToggleBtn"
Btn.Parent = ToggleGui
Btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Btn.Position = UDim2.new(0.9, 0, 0.4, 0)
Btn.Size = UDim2.new(0, 45, 0, 45)
Btn.Font = Enum.Font.GothamBold
Btn.Text = "N"
Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn.TextSize = 22
Btn.AutoButtonColor = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Btn

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(150, 150, 150)
UIStroke.Thickness = 1.5
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UIStroke.Parent = Btn

local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    Btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Btn.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
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
        update(input)
    end
end)

local clickTime = 0
Btn.MouseButton1Down:Connect(function()
    clickTime = tick()
end)

Btn.MouseButton1Up:Connect(function()
    if tick() - clickTime < 0.2 then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
    end
end)

-- ==========================================
-- HOÀN TẤT & TẢI CONFIG CŨ
-- ==========================================
Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
