local Fluent, Window = ...

-- ==========================================
-- KHỞI TẠO TAB, DỊCH VỤ & CẤU HÌNH
-- ==========================================
local Tabs = {
    Misc = Window:AddTab({ Title = "Misc", Icon = "box" })
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Config = {
    WebhookURL = "",
    BlackScreen = false,
    AutoWebhook = false,
    WebhookInterval = 5 -- Mặc định 5 phút
}
local lastAutoSend = 0

-- ==========================================
-- HÀM XỬ LÝ LẤY DỮ LIỆU TỪ GAME
-- ==========================================
local function GetPlayerData()
    local data = {
        Name = LocalPlayer.Name,
        Level = 0,
        Stand = "None",
        Tokens = {}
    }
    
    local pData = LocalPlayer:FindFirstChild("PlayerData")
    if pData and pData:FindFirstChild("SlotData") then
        local slot = pData.SlotData
        
        -- 1. Lấy Level
        if slot:FindFirstChild("Level") then
            data.Level = slot.Level.Value
        end
        
        -- 2. Lấy Tên Stand
        if slot:FindFirstChild("Stand") then
            local standStr = tostring(slot.Stand.Value)
            local success, decoded = pcall(function()
                return HttpService:JSONDecode(standStr)
            end)
            
            if success and type(decoded) == "table" and decoded.Name then
                data.Stand = decoded.Name
            else
                local matchName = string.match(standStr, '"Name"%s*:%s*"([^"]+)"')
                data.Stand = matchName or "None"
            end
        end
        
        -- 3. Lấy Raid Tokens
        if slot:FindFirstChild("RaidTokens") then
            local tokenStr = tostring(slot.RaidTokens.Value)
            local success, decoded = pcall(function()
                return HttpService:JSONDecode(tokenStr)
            end)
            if success and type(decoded) == "table" then
                data.Tokens = decoded
            end
        end
    end
    
    return data
end

-- ==========================================
-- THIẾT KẾ GIAO DIỆN BLACK SCREEN
-- ==========================================
local guiTarget = nil
pcall(function() guiTarget = gethui() end)
if not guiTarget then pcall(function() guiTarget = game:GetService("CoreGui") end) end
if not guiTarget then guiTarget = LocalPlayer:WaitForChild("PlayerGui") end

local BlackScreenGui = Instance.new("ScreenGui")
BlackScreenGui.Name = "NthucHub_BlackScreen"
BlackScreenGui.DisplayOrder = 999998
BlackScreenGui.IgnoreGuiInset = true
BlackScreenGui.Enabled = false
BlackScreenGui.Parent = guiTarget

local BlackBG = Instance.new("Frame")
BlackBG.Name = "Background"
BlackBG.Size = UDim2.new(1, 0, 1, 0)
BlackBG.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BlackBG.Parent = BlackScreenGui

local InfoBox = Instance.new("Frame")
InfoBox.Name = "InfoBox"
InfoBox.AnchorPoint = Vector2.new(0.5, 0.5)
InfoBox.Position = UDim2.new(0.5, 0, 0.5, 0)
InfoBox.Size = UDim2.new(0.9, 0, 0.8, 0)
InfoBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
InfoBox.Parent = BlackBG

local uiConstraint = Instance.new("UISizeConstraint")
uiConstraint.MaxSize = Vector2.new(350, 450)
uiConstraint.Parent = InfoBox

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 12)
boxCorner.Parent = InfoBox

local boxStroke = Instance.new("UIStroke")
boxStroke.Color = Color3.fromRGB(100, 100, 100)
boxStroke.Thickness = 2
boxStroke.Parent = InfoBox

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.AnchorPoint = Vector2.new(1, 0)
CloseBtn.Position = UDim2.new(1, -10, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 16
CloseBtn.Parent = InfoBox
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.new(0, 80, 0, 80)
AvatarImg.Position = UDim2.new(0.5, -40, 0, 20)
AvatarImg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
AvatarImg.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
AvatarImg.Parent = InfoBox
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

local InfoText = Instance.new("TextLabel")
InfoText.Size = UDim2.new(1, -20, 0, 60)
InfoText.Position = UDim2.new(0, 10, 0, 110)
InfoText.BackgroundTransparency = 1
InfoText.Font = Enum.Font.GothamSemibold
InfoText.TextSize = 14
InfoText.TextColor3 = Color3.fromRGB(255, 255, 255)
InfoText.TextYAlignment = Enum.TextYAlignment.Top
InfoText.Parent = InfoBox

local TokenList = Instance.new("ScrollingFrame")
TokenList.Size = UDim2.new(1, -20, 1, -190)
TokenList.Position = UDim2.new(0, 10, 0, 180)
TokenList.BackgroundTransparency = 1
TokenList.ScrollBarThickness = 4
TokenList.Parent = InfoBox

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = TokenList

local function UpdateBlackScreen()
    local data = GetPlayerData()
    
    InfoText.Text = string.format("👤 %s\n⭐ Level: %s\n🛡️ Stand: %s", data.Name, tostring(data.Level), data.Stand)
    
    for _, child in ipairs(TokenList:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    
    for tokenName, amount in pairs(data.Tokens) do
        local tkText = Instance.new("TextLabel")
        tkText.Size = UDim2.new(1, 0, 0, 25)
        tkText.BackgroundTransparency = 1
        tkText.Font = Enum.Font.Gotham
        tkText.TextSize = 13
        tkText.TextColor3 = Color3.fromRGB(200, 200, 200)
        tkText.TextXAlignment = Enum.TextXAlignment.Left
        tkText.Text = string.format("• %s: %d", tokenName, amount)
        tkText.Parent = TokenList
    end
    
    TokenList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end

-- ==========================================
-- HÀM GỬI WEBHOOK
-- ==========================================
local function SendWebhookReport()
    if Config.WebhookURL == "" or not Config.WebhookURL:find("http") then
        return false
    end
    
    local data = GetPlayerData()
    local tokensStr = ""
    for name, amt in pairs(data.Tokens) do
        tokensStr = tokensStr .. string.format("• **%s:** %d\n", name, amt)
    end
    if tokensStr == "" then tokensStr = "Không có token nào." end
    
    local embedData = {
        embeds = {{
            title = "📊 Nthuc Hub - Báo Cáo Nhân Vật",
            description = "Trạng thái nhân vật hiện tại trong game.",
            color = 8388863,
            thumbnail = {
                url = "https://static.wikia.nocookie.net/blineage/images/e/e6/Site-logo.png/revision/latest?cb=20260310145648"
            },
            fields = {
                { name = "👤 Người Chơi", value = "```" .. data.Name .. "```", inline = true },
                { name = "⭐ Cấp Độ", value = "```" .. tostring(data.Level) .. "```", inline = true },
                { name = "🛡️ Stand", value = "```" .. data.Stand .. "```", inline = false },
                { name = "💰 Raid Tokens", value = tokensStr, inline = false }
            },
            footer = { text = "Nthuc Hub • Tự động cập nhật • " .. os.date("%X") },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
    
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if requestFunc then
        local success, _ = pcall(function()
            return requestFunc({
                Url = Config.WebhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(embedData)
            })
        end)
        return success
    end
    return false
end

-- ==========================================
-- GIAO DIỆN NTHUC HUB (TAB MISC)
-- ==========================================
local SectionScreen = Tabs.Misc:AddSection("Tối Ưu Hiệu Năng")

local Toggle_BlackScreen = Tabs.Misc:AddToggle("Toggle_BlackScreen", {
    Title = "Bật Màn Hình Đen (Boost FPS)",
    Description = "Giảm tải đồ họa, phù hợp để treo máy. Tắt bằng nút X đỏ.",
    Default = false,
    Callback = function(Value)
        Config.BlackScreen = Value
        BlackScreenGui.Enabled = Value
        
        if Value then
            UpdateBlackScreen()
            pcall(function() RunService:Set3dRenderingEnabled(false) end)
        else
            pcall(function() RunService:Set3dRenderingEnabled(true) end)
        end
    end
})

CloseBtn.MouseButton1Click:Connect(function()
    Toggle_BlackScreen:SetValue(false)
end)

local SectionWebhook = Tabs.Misc:AddSection("Báo Cáo Discord (Webhook)")

local Input_Webhook = Tabs.Misc:AddInput("Input_WebhookURL", {
    Title = "Discord Webhook URL",
    Description = "Dán link Webhook vào đây",
    Default = Config.WebhookURL,
    Finished = true,
    Callback = function(Value)
        Config.WebhookURL = Value
    end
})

local Toggle_AutoWebhook = Tabs.Misc:AddToggle("Toggle_AutoWebhook", {
    Title = "Tự Động Gửi Webhook",
    Description = "Gửi báo cáo định kỳ theo thời gian chọn bên dưới.",
    Default = false,
    Callback = function(Value)
        Config.AutoWebhook = Value
    end
})

local Slider_Interval = Tabs.Misc:AddSlider("WebhookInterval", {
    Title = "Thời Gian Gửi (Phút)",
    Description = "Khoảng cách giữa mỗi lần gửi báo cáo.",
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value)
        Config.WebhookInterval = Value
    end
})

Tabs.Misc:AddButton({
    Title = "Gửi Thử Ngay Bây Giờ",
    Callback = function()
        if Config.WebhookURL == "" then
            Fluent:Notify({ Title = "Lỗi", Content = "Bạn chưa nhập Link Webhook!", Duration = 3 })
            return
        end
        
        if SendWebhookReport() then
            Fluent:Notify({ Title = "Thành công", Content = "Đã gửi báo cáo lên Discord!", Duration = 3 })
        else
            Fluent:Notify({ Title = "Thất bại", Content = "Kiểm tra lại Link Webhook hoặc Executor.", Duration = 3 })
        end
    end
})

-- ==========================================
-- HỆ THỐNG TỰ ĐỘNG CHẠY NGẦM (LOOPS)
-- ==========================================

-- Cập nhật Black Screen
task.spawn(function()
    while task.wait(5) do
        if Config.BlackScreen then
            UpdateBlackScreen()
        end
    end
end)

-- Gửi Webhook ngay khi load Script (hoặc Rejoin)
task.spawn(function()
    task.wait(5) -- Đợi game load xong dữ liệu
    if Config.WebhookURL ~= "" then
        SendWebhookReport()
    end
end)

-- Vòng lặp gửi Webhook định kỳ
task.spawn(function()
    while task.wait(10) do -- Kiểm tra mỗi 10 giây
        if Config.AutoWebhook and Config.WebhookURL ~= "" then
            local now = os.time()
            if (now - lastAutoSend) >= (Config.WebhookInterval * 60) then
                SendWebhookReport()
                lastAutoSend = now
            end
        end
    end
end)
