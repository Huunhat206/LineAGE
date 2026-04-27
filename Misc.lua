local Fluent, Window = ...

-- ==========================================
-- KHỞI TẠO TAB & DỊCH VỤ
-- ==========================================
local Tabs = {
    Misc = Window:AddTab({ Title = "Chức năng Phụ (Misc)", Icon = "box" })
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Config = {
    WebhookURL = "",
    BlackScreen = false
}

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
        
        -- 2. Lấy Tên Stand (Lọc từ chuỗi: Chariot","ID":"...)
        if slot:FindFirstChild("Stand") then
            local standStr = tostring(slot.Stand.Value)
            -- Lấy phần chữ trước ký tự "," đầu tiên và xóa dấu ngoặc kép
            local standName = string.match(standStr, '^"?([^",]+)"?,?')
            if standName then
                data.Stand = standName
            else
                data.Stand = standStr
            end
        end
        
        -- 3. Lấy Raid Tokens (Chuyển từ JSON String sang Table)
        if slot:FindFirstChild("RaidTokens") then
            local tokenStr = slot.RaidTokens.Value
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
-- THIẾT KẾ GIAO DIỆN BLACK SCREEN (TỐI ƯU FPS)
-- ==========================================
local guiTarget = nil
pcall(function() guiTarget = gethui() end)
if not guiTarget then pcall(function() guiTarget = game:GetService("CoreGui") end) end
if not guiTarget then guiTarget = LocalPlayer:WaitForChild("PlayerGui") end

-- Tạo ScreenGui chứa Màn hình đen
local BlackScreenGui = Instance.new("ScreenGui")
BlackScreenGui.Name = "NthucHub_BlackScreen"
BlackScreenGui.DisplayOrder = 999998 -- Nằm dưới nút N nổi một chút
BlackScreenGui.IgnoreGuiInset = true -- Che cả phần Topbar
BlackScreenGui.Enabled = false
BlackScreenGui.Parent = guiTarget

-- Khung Đen toàn màn hình
local BlackBG = Instance.new("Frame")
BlackBG.Name = "Background"
BlackBG.Size = UDim2.new(1, 0, 1, 0)
BlackBG.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BlackBG.Parent = BlackScreenGui

-- Khung Vuông Hiển thị thông tin ở giữa (Hỗ trợ cả PC & Mobile)
local InfoBox = Instance.new("Frame")
InfoBox.Name = "InfoBox"
InfoBox.AnchorPoint = Vector2.new(0.5, 0.5)
InfoBox.Position = UDim2.new(0.5, 0, 0.5, 0)
InfoBox.Size = UDim2.new(0.9, 0, 0.8, 0) -- Rộng 90%, cao 80% màn hình
InfoBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
InfoBox.Parent = BlackBG

local uiConstraint = Instance.new("UISizeConstraint")
uiConstraint.MaxSize = Vector2.new(350, 450) -- Giới hạn size tối đa trên PC
uiConstraint.Parent = InfoBox

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 12)
boxCorner.Parent = InfoBox

local boxStroke = Instance.new("UIStroke")
boxStroke.Color = Color3.fromRGB(100, 100, 100)
boxStroke.Thickness = 2
boxStroke.Parent = InfoBox

-- Nút Tắt (X) góc trên phải
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

-- Ảnh Avatar Nhân vật
local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.new(0, 80, 0, 80)
AvatarImg.Position = UDim2.new(0.5, -40, 0, 20)
AvatarImg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
AvatarImg.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
AvatarImg.Parent = InfoBox
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

-- Tên, Level, Stand
local InfoText = Instance.new("TextLabel")
InfoText.Size = UDim2.new(1, -20, 0, 60)
InfoText.Position = UDim2.new(0, 10, 0, 110)
InfoText.BackgroundTransparency = 1
InfoText.Font = Enum.Font.GothamSemibold
InfoText.TextSize = 14
InfoText.TextColor3 = Color3.fromRGB(255, 255, 255)
InfoText.TextYAlignment = Enum.TextYAlignment.Top
InfoText.Parent = InfoBox

-- Danh sách Tokens (Dùng ScrollingFrame để cuộn nếu có nhiều token)
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

-- Hàm Cập nhật nội dung cho Black Screen
local function UpdateBlackScreen()
    local data = GetPlayerData()
    
    InfoText.Text = string.format("👤 %s\n⭐ Level: %s\n🛡️ Stand: %s", data.Name, tostring(data.Level), data.Stand)
    
    -- Xóa tokens cũ
    for _, child in ipairs(TokenList:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    
    -- Tạo tokens mới
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
    
    -- Tự dãn khung cuộn
    TokenList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end

-- ==========================================
-- GIAO DIỆN NTHUC HUB (TAB MISC)
-- ==========================================
local SectionScreen = Tabs.Misc:AddSection("Tối Ưu Hiệu Năng")

-- Nút Toggle Black Screen
local Toggle_BlackScreen = Tabs.Misc:AddToggle("Toggle_BlackScreen", {
    Title = "Bật Màn Hình Đen (Boost FPS)",
    Description = "Giảm tải đồ họa, phù hợp để treo máy. Tắt bằng nút X đỏ.",
    Default = false,
    Callback = function(Value)
        Config.BlackScreen = Value
        BlackScreenGui.Enabled = Value
        
        if Value then
            UpdateBlackScreen()
            -- Tùy chọn: Ép giảm đồ họa 3D (Nếu executor hỗ trợ)
            pcall(function() RunService:Set3dRenderingEnabled(false) end)
        else
            pcall(function() RunService:Set3dRenderingEnabled(true) end)
        end
    end
})

-- Xử lý nút (X) bên trong Black Screen
CloseBtn.MouseButton1Click:Connect(function()
    Toggle_BlackScreen:SetValue(false) -- Sẽ tự động gọi Callback phía trên
end)

-- Vòng lặp cập nhật thông số khi Black Screen đang bật (Mỗi 5 giây)
task.spawn(function()
    while task.wait(5) do
        if Config.BlackScreen then
            UpdateBlackScreen()
        end
    end
end)

local SectionWebhook = Tabs.Misc:AddSection("Báo Cáo Discord (Webhook)")

-- Ô nhập Webhook (Nhập xong ấn Enter, sẽ được SaveManager ở GUI.lua tự lưu)
local Input_Webhook = Tabs.Misc:AddInput("Input_WebhookURL", {
    Title = "Discord Webhook URL",
    Description = "Nhập link Webhook và ấn Enter để lưu",
    Default = "",
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        Config.WebhookURL = Value
    end
})

-- Hàm gửi Webhook
Tabs.Misc:AddButton({
    Title = "Gửi Báo Cáo Tới Discord",
    Callback = function()
        if Config.WebhookURL == "" then
            Fluent:Notify({ Title = "Lỗi Webhook", Content = "Bạn chưa nhập Link Webhook!", Duration = 3 })
            return
        end
        
        local data = GetPlayerData()
        
        -- Chuyển Table Tokens thành Chuỗi văn bản
        local tokensStr = ""
        for name, amt in pairs(data.Tokens) do
            tokensStr = tokensStr .. string.format("**%s:** %d\n", name, amt)
        end
        if tokensStr == "" then tokensStr = "Không có token nào." end
        
        -- Tạo Data JSON Gửi đi
        local embedData = {
            embeds = {{
                title = "📊 Nthuc Hub - Báo Cáo Nhân Vật",
                color = 8388863, -- Màu Tím vương giả
                fields = {
                    { name = "👤 Tên Người Chơi", value = data.Name, inline = true },
                    { name = "⭐ Level", value = tostring(data.Level), inline = true },
                    { name = "🛡️ Stand Hiện Tại", value = data.Stand, inline = false },
                    { name = "💰 Raid Tokens", value = tokensStr, inline = false }
                },
                footer = { text = "Nthuc Hub - Tự động cập nhật" },
                timestamp = DateTime.now():ToIsoDate()
            }}
        }
        
        -- Gửi Request tương thích nhiều loại Executor
        local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        
        if requestFunc then
            local success, response = pcall(function()
                return requestFunc({
                    Url = Config.WebhookURL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(embedData)
                })
            end)
            
            if success then
                Fluent:Notify({ Title = "Thành công", Content = "Đã gửi báo cáo lên Discord!", Duration = 3 })
            else
                Fluent:Notify({ Title = "Lỗi Gửi", Content = "Không thể gửi dữ liệu, kiểm tra lại Link Webhook.", Duration = 3 })
            end
        else
            Fluent:Notify({ Title = "Lỗi Executor", Content = "Executor của bạn không hỗ trợ Http Request.", Duration = 3 })
        end
    end
})
