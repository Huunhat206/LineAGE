-- Nhận biến Fluent và Window từ GUI.lua truyền sang
local Fluent, Window = ...

-- 1. Khởi tạo Tab Auto Farm
local Tabs = {
    Farm = Window:AddTab({ Title = "Auto Farm", Icon = "swords" })
}

-- 2. Khai báo Services và Variables
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local NpcsFolder = workspace:WaitForChild("Npcs", 9e9)
local EffectsFolder = workspace:WaitForChild("Effects", 9e9)

-- Bảng lưu trữ cấu hình (Để truyền dữ liệu giữa UI và Vòng lặp)
local Config = {
    AutoFarm = false,
    SelectedMob = nil,
    PositionMode = "Behind",
    Distance = 5,
    OffsetX = 0,
    OffsetY = 0,
    OffsetZ = 0,
    AutoStand = false,
    AutoSkill = false,
    Skills = {} -- Lưu các skill được chọn
}

-- Hàm quét lấy tên NPC (lọc trùng lặp)
local function GetNpcList()
    local list = {}
    local seen = {}
    for _, npc in ipairs(NpcsFolder:GetChildren()) do
        if npc:IsA("Model") and npc.Name ~= "" and not seen[npc.Name] then
            table.insert(list, npc.Name)
            seen[npc.Name] = true
        end
    end
    return list
end

-- ==========================================
-- GIAO DIỆN NGƯỜI DÙNG (UI)
-- ==========================================

-- [PHẦN 1] Chọn Quái & Auto Farm
local NpcList = GetNpcList()
local Dropdown_Mob = Tabs.Farm:AddDropdown("Dropdown_Mob", {
    Title = "Chọn Quái (Select Mob)",
    Values = NpcList,
    Multi = false,
    Default = 1,
})

Dropdown_Mob:OnChanged(function(Value)
    Config.SelectedMob = Value
end)

Tabs.Farm:AddButton({
    Title = "Làm mới danh sách Quái",
    Callback = function()
        Dropdown_Mob:SetValues(GetNpcList())
    end
})

Tabs.Farm:AddToggle("Toggle_AutoFarm", {
    Title = "Bật Auto Farm",
    Default = false,
    Callback = function(Value)
        Config.AutoFarm = Value
    end
})

-- [PHẦN 2] Cấu hình Tọa Độ (Position)
local SectionPos = Tabs.Farm:AddSection("Cài đặt Tọa Độ (Position Settings)")

Tabs.Farm:AddDropdown("Dropdown_Pos", {
    Title = "Vị trí Đứng",
    Values = {"Behind", "Under", "Upper"},
    Multi = false,
    Default = 1,
    Callback = function(Value)
        Config.PositionMode = Value
    end
})

Tabs.Farm:AddInput("Input_Distance", {
    Title = "Khoảng cách (Distance)",
    Default = "5",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        Config.Distance = tonumber(Value) or 5
    end
})

Tabs.Farm:AddInput("Input_OffsetX", { Title = "Offset X", Default = "0", Numeric = true, Finished = true, Callback = function(Value) Config.OffsetX = tonumber(Value) or 0 end })
Tabs.Farm:AddInput("Input_OffsetY", { Title = "Offset Y", Default = "0", Numeric = true, Finished = true, Callback = function(Value) Config.OffsetY = tonumber(Value) or 0 end })
Tabs.Farm:AddInput("Input_OffsetZ", { Title = "Offset Z", Default = "0", Numeric = true, Finished = true, Callback = function(Value) Config.OffsetZ = tonumber(Value) or 0 end })

-- [PHẦN 3] Auto Stand
local SectionStand = Tabs.Farm:AddSection("Tự động gọi Stand")

Tabs.Farm:AddToggle("Toggle_AutoStand", {
    Title = "Bật Auto Stand",
    Default = false,
    Callback = function(Value)
        Config.AutoStand = Value
    end
})

-- [PHẦN 4] Auto Skill
local SectionSkill = Tabs.Farm:AddSection("Tự động dùng Kỹ năng (Auto Skill)")

Tabs.Farm:AddToggle("Toggle_AutoSkill", {
    Title = "Bật Auto Skill",
    Default = false,
    Callback = function(Value)
        Config.AutoSkill = Value
    end
})

local Dropdown_Skill = Tabs.Farm:AddDropdown("Dropdown_Skill", {
    Title = "Chọn Skill",
    Description = "Có thể chọn nhiều skill cùng lúc (Toggle)",
    Values = {"E", "R", "Z", "X", "C", "V"},
    Multi = true,
    Default = {},
})

Dropdown_Skill:OnChanged(function(Value)
    -- Value trả về dạng bảng: {E = true, Z = true, C = true}
    Config.Skills = Value
end)


-- ==========================================
-- LOGIC XỬ LÝ CHÍNH (BACKEND)
-- ==========================================

-- Hàm tìm quái vật gần nhất/còn sống dựa trên tên đã chọn
local function GetTarget()
    if not Config.SelectedMob then return nil end
    for _, npc in ipairs(NpcsFolder:GetChildren()) do
        if npc.Name == Config.SelectedMob and npc:FindFirstChild("HumanoidRootPart") then
            local humanoid = npc:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                return npc
            end
        end
    end
    return nil
end

-- Hàm tính toán CFrame kết hợp Giữa Mode (Sau/Trên/Dưới), Khoảng cách và Offset X,Y,Z
local function CalculateCFrame(targetCFrame)
    local baseCFrame = targetCFrame
    local dist = Config.Distance
    
    if Config.PositionMode == "Behind" then
        baseCFrame = targetCFrame * CFrame.new(0, 0, dist)
    elseif Config.PositionMode == "Upper" then
        baseCFrame = targetCFrame * CFrame.new(0, dist, 0)
    elseif Config.PositionMode == "Under" then
        baseCFrame = targetCFrame * CFrame.new(0, -dist, 0)
    end
    
    -- Áp dụng thêm Offset X, Y, Z tùy chỉnh
    return baseCFrame * CFrame.new(Config.OffsetX, Config.OffsetY, Config.OffsetZ)
end

-- [VÒNG LẶP CHÍNH] Xử lý Auto Farm, M1 và Skill (Chạy liên tục theo Frame)
RunService.Heartbeat:Connect(function()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = character.HumanoidRootPart
    local controller = character:FindFirstChild("client_character_controller")
    
    if Config.AutoFarm then
        local target = GetTarget()
        if target then
            -- 1. Auto Teleport
            hrp.CFrame = CalculateCFrame(target.HumanoidRootPart.CFrame)
            
            if controller then
                -- 2. Auto M1
                if controller:FindFirstChild("M1") then
                    pcall(function()
                        controller.M1:FireServer(true, false)
                    end)
                end
                
                -- 3. Auto Skill (Vừa đánh vừa xả skill)
                if Config.AutoSkill and controller:FindFirstChild("Skill") then
                    for skillKey, isSelected in pairs(Config.Skills) do
                        if isSelected then
                            pcall(function()
                                controller.Skill:FireServer(skillKey, true)
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- [VÒNG LẶP PHỤ] Xử lý Auto Stand (Chạy chậm hơn để đỡ Lag / Check thi thoảng)
task.spawn(function()
    while task.wait(1.5) do -- Cứ 1.5 giây check 1 lần
        if Config.AutoStand then
            local character = LocalPlayer.Character
            if character then
                local controller = character:FindFirstChild("client_character_controller")
                
                -- Tạo chuỗi tìm tên Stand chính xác theo người chơi
                local standModelName = "." .. LocalPlayer.Name .. "'s Stand"
                
                -- Quét trong workspace.Effects
                if not EffectsFolder:FindFirstChild(standModelName) then
                    -- Nếu không tìm thấy Stand -> Gọi Stand
                    if controller and controller:FindFirstChild("SummonStand") then
                        pcall(function()
                            controller.SummonStand:FireServer()
                        end)
                    end
                end
            end
        end
    end
end)
