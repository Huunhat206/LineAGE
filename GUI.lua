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
-- 3. TẢI CÁC MODULE (Autofarm.lua...)
-- ==========================================
local githubRepo = "https://raw.githubusercontent.com/Huunhat206/LineAGE/main/"
local Modules = {
    "Autofarm.lua"
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

-- Vẽ các nút Config cơ bản của Fluent
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- Thêm mục cấu hình Nâng cao: AUTO SAVE
local SectionAdvanced = Tabs.Settings:AddSection("Cài đặt Nâng cao")

local isAutoSaving = false
local AutoSaveToggle = Tabs.Settings:AddToggle("Toggle_AutoSave", {
    Title = "Tự động lưu Config (Auto Save)",
    Description = "Tự động lưu lại cài đặt hiện tại mỗi 30 giây",
    Default = false,
    Callback = function(Value)
        isAutoSaving = Value
        if Value then
            Fluent:Notify({ Title = "Nthuc Hub", Content = "Đã bật Auto Save!", Duration = 3 })
        end
    end
})

-- Luồng chạy ngầm tự động lưu mỗi 30 giây
task.spawn(function()
    while task.wait(30) do
        if isAutoSaving then
            -- Nếu bạn đã tạo và chọn 1 file config trước đó, nó sẽ lưu đè lên file đó.
            -- Nếu bạn chưa tạo file nào, nó sẽ tự động tạo một file tên là "AutoSave_Default"
            local configName = SaveManager.CurrentConfig
            if not configName or configName == "" then
                configName = "AutoSave_Default"
            end
            
            pcall(function()
                SaveManager:Save(configName)
            end)
        end
    end
end)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
