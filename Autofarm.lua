local Fluent, Window = ...

-- ==========================================
-- KHỞI TẠO TAB & BIẾN
-- ==========================================
local Tabs = {
    Farm = Window:AddTab({ Title = "Auto Farm", Icon = "swords" })
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local LiveFolder = workspace:WaitForChild("Live", 9e9)
local EffectsFolder = workspace:WaitForChild("Effects", 9e9)

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
    Skills = {} 
}

-- ==========================================
-- HÀM XỬ LÝ TÊN QUÁI VẬT
-- ==========================================
local function GetBaseName(rawName)
    local name = string.gsub(rawName, "^%.", "")
    if #name > 6 then
        name = string.sub(name, 1, -7)
    end
    return name
end

local function GetNpcList()
    local list = {}
    local seen = {}
    for _, npc in ipairs(LiveFolder:GetChildren()) do
        if npc:IsA("Model") and npc.Name ~= "" then
            local baseName = GetBaseName(npc.Name)
            if not seen[baseName] then
                table.insert(list, baseName)
                seen[baseName] = true
            end
        end
    end
    return list
end

-- ==========================================
-- GIAO DIỆN NGƯỜI DÙNG (UI)
-- ==========================================
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

local SectionPos = Tabs.Farm:AddSection("Cài đặt Tọa Độ (Position)")

Tabs.Farm:AddDropdown("Dropdown_Pos", {
    Title = "Vị trí Đứng",
    Values = {"Behind", "Under", "Upper"},
    Multi = false,
    Default = 1,
    Callback = function(Value)
        Config.PositionMode = Value
    end
})

Tabs.Farm:AddSlider("Slider_Distance", { Title = "Khoảng cách (Distance)", Default = 5, Min = 0, Max = 30, Rounding = 1, Callback = function(Value) Config.Distance = Value end })
Tabs.Farm:AddSlider("Slider_OffsetX", { Title = "Offset X", Default = 0, Min = -20, Max = 20, Rounding = 1, Callback = function(Value) Config.OffsetX = Value end })
Tabs.Farm:AddSlider("Slider_OffsetY", { Title = "Offset Y", Default = 0, Min = -20, Max = 20, Rounding = 1, Callback = function(Value) Config.OffsetY = Value end })
Tabs.Farm:AddSlider("Slider_OffsetZ", { Title = "Offset Z", Default = 0, Min = -20, Max = 20, Rounding = 1, Callback = function(Value) Config.OffsetZ = Value end })

local SectionStand = Tabs.Farm:AddSection("Chiến đấu (Combat)")

Tabs.Farm:AddToggle("Toggle_AutoStand", { Title = "Bật Auto Stand", Default = false, Callback = function(Value) Config.AutoStand = Value end })
Tabs.Farm:AddToggle("Toggle_AutoSkill", { Title = "Bật Auto Skill", Default = false, Callback = function(Value) Config.AutoSkill = Value end })

local Dropdown_Skill = Tabs.Farm:AddDropdown("Dropdown_Skill", {
    Title = "Chọn Skill",
    Values = {"E", "R", "Z", "X", "C", "V"},
    Multi = true,
    Default = {},
})

Dropdown_Skill:OnChanged(function(Value)
    Config.Skills = Value
end)

-- ==========================================
-- LOGIC XỬ LÝ CHÍNH
-- ==========================================
local function GetTarget()
    if not Config.SelectedMob then return nil end
    for _, npc in ipairs(LiveFolder:GetChildren()) do
        if npc:IsA("Model") then
            local hrp = npc:FindFirstChild("HumanoidRootPart")
            local humanoid = npc:FindFirstChild("Humanoid")
            
            -- Bỏ qua quái bị giấu dưới gầm map (Y < -500)
            if hrp and humanoid and humanoid.Health > 0 and hrp.Position.Y > -500 then
                local baseName = GetBaseName(npc.Name)
                if baseName == Config.SelectedMob then
                    return npc
                end
            end
        end
    end
    return nil
end

local function CalculateCFrame(targetCFrame)
    local targetPos = targetCFrame.Position
    local offsetCFrame = CFrame.new()
    
    if Config.PositionMode == "Behind" then
        offsetCFrame = CFrame.new(0, 0, Config.Distance)
    elseif Config.PositionMode == "Upper" then
        offsetCFrame = CFrame.new(0, Config.Distance, 0)
    elseif Config.PositionMode == "Under" then
        offsetCFrame = CFrame.new(0, -Config.Distance, 0)
    end
    
    offsetCFrame = offsetCFrame * CFrame.new(Config.OffsetX, Config.OffsetY, Config.OffsetZ)
    local finalPos = (targetCFrame * offsetCFrame).Position
    
    -- Chống lỗi NaN văng map nếu tọa độ trùng nhau
    if (finalPos - targetPos).Magnitude < 0.1 then
        return CFrame.new(finalPos)
    end
    
    return CFrame.lookAt(finalPos, targetPos)
end

-- VÒNG LẶP AUTO FARM VÀ M1
RunService.Heartbeat:Connect(function()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = character.HumanoidRootPart
    local controller = character:FindFirstChild("client_character_controller")
    
    if Config.AutoFarm then
        local target = GetTarget()
        if target then
            if hrp.Anchored then hrp.Anchored = false end 
            
            hrp.CFrame = CalculateCFrame(target.HumanoidRootPart.CFrame)
            
            if controller and controller:FindFirstChild("M1") then
                local args = {true, false}
                controller.M1:FireServer(args[1], args[2])
            end
        else
            -- Hết quái thì đóng băng neo trên không
            hrp.Anchored = true
        end
    else
        -- Tắt Auto thì thả rơi tự do
        if hrp.Anchored then hrp.Anchored = false end
    end
end)

-- VÒNG LẶP AUTO SKILL
task.spawn(function()
    while task.wait(0.5) do
        if Config.AutoFarm and Config.AutoSkill then
            local character = LocalPlayer.Character
            local controller = character and character:FindFirstChild("client_character_controller")
            
            if controller then
                for skillKey, isSelected in pairs(Config.Skills) do
                    if isSelected then
                        local skillRemote = controller:FindFirstChild("Skill")
                        if skillRemote then
                            local args = {skillKey, true}
                            skillRemote:FireServer(args[1], args[2])
                        end
                        task.wait(0.5) 
                    end
                end
            end
        end
    end
end)

-- VÒNG LẶP AUTO STAND
task.spawn(function()
    while task.wait(1.5) do
        if Config.AutoStand then
            local character = LocalPlayer.Character
            if character then
                local controller = character:FindFirstChild("client_character_controller")
                local standModelName = "." .. LocalPlayer.Name .. "'s Stand"
                
                if not EffectsFolder:FindFirstChild(standModelName) then
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
