local Fluent, Window = ...

-- ==========================================
-- KHỞI TẠO TAB & DỊCH VỤ
-- ==========================================
local Tabs = {
    Misc = Window:AddTab({ Title = "Chức năng Phụ (Misc)", Icon = "box" })
}

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local HttpService    = game:GetService("HttpService")
local TweenService   = game:GetService("TweenService")
local LocalPlayer    = Players.LocalPlayer

local Config = {
    WebhookURL    = "",
    BlackScreen   = false,
    AutoWebhook   = false,
    AutoInterval  = 5,   -- phút
    -- Player
    FPSLimit      = 60,
    WalkSpeed     = 16,
    JumpSpeed     = 50,
    InfJump       = false,
}

local LOGO_URL = "https://static.wikia.nocookie.net/blineage/images/e/e6/Site-logo.png/revision/latest?cb=20260310145648"

-- ==========================================
-- HÀM LẤY DỮ LIỆU NHÂN VẬT
-- ==========================================
local function GetPlayerData()
    local data = {
        Name   = LocalPlayer.Name,
        UserId = LocalPlayer.UserId,
        Level  = 0,
        Stand  = "None",
        Tokens = {}
    }

    local pData = LocalPlayer:FindFirstChild("PlayerData")
    if pData and pData:FindFirstChild("SlotData") then
        local slot = pData.SlotData

        if slot:FindFirstChild("Level") then
            data.Level = slot.Level.Value
        end

        if slot:FindFirstChild("Stand") then
            local standStr = tostring(slot.Stand.Value)
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, standStr)
            if ok and type(decoded) == "table" and decoded.Name then
                data.Stand = decoded.Name
            else
                data.Stand = string.match(standStr, '"Name"%s*:%s*"([^"]+)"') or "None"
            end
        end

        if slot:FindFirstChild("RaidTokens") then
            local tokenStr = tostring(slot.RaidTokens.Value)
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, tokenStr)
            if ok and type(decoded) == "table" then
                data.Tokens = decoded
            end
        end
    end

    return data
end

-- ==========================================
-- HÀM GỬI WEBHOOK
-- ==========================================
local function SendWebhook(silent)
    if Config.WebhookURL == "" then
        if not silent then
            Fluent:Notify({ Title = "Lỗi Webhook", Content = "Bạn chưa nhập Link Webhook!", Duration = 3 })
        end
        return
    end

    local data = GetPlayerData()

    local tokensStr = ""
    for name, amt in pairs(data.Tokens) do
        tokensStr = tokensStr .. string.format("**%s:** %d\n", name, amt)
    end
    if tokensStr == "" then tokensStr = "*Không có token nào.*" end

    local embedData = {
        username   = "Nthuc Hub",
        avatar_url = LOGO_URL,
        embeds = {{
            title       = "📊 Nthuc Hub · Báo Cáo Nhân Vật",
            description = string.format("Dữ liệu được gửi lúc <t:%d:F>", os.time()),
            color       = 0x7B68EE,
            thumbnail   = { url = LOGO_URL },
            fields = {
                { name = "👤 Tên Người Chơi", value = string.format("`%s`", data.Name),         inline = true  },
                { name = "⭐ Level",           value = string.format("`%s`", tostring(data.Level)), inline = true  },
                { name = "🛡️ Stand",          value = string.format("`%s`", data.Stand),        inline = false },
                { name = "💰 Raid Tokens",     value = tokensStr,                                 inline = false }
            },
            footer = {
                text     = "Nthuc Hub  •  Auto Reporter",
                icon_url = LOGO_URL
            },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    local requestFunc = (syn and syn.request)
        or (http and http.request)
        or http_request
        or (fluxus and fluxus.request)
        or request

    if requestFunc then
        local ok, _ = pcall(function()
            return requestFunc({
                Url     = Config.WebhookURL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = HttpService:JSONEncode(embedData)
            })
        end)
        if not silent then
            if ok then
                Fluent:Notify({ Title = "✅ Thành công", Content = "Đã gửi báo cáo lên Discord!", Duration = 3 })
            else
                Fluent:Notify({ Title = "❌ Lỗi Gửi", Content = "Kiểm tra lại Webhook URL.", Duration = 4 })
            end
        end
    else
        if not silent then
            Fluent:Notify({ Title = "Lỗi Executor", Content = "Executor không hỗ trợ Http Request.", Duration = 3 })
        end
    end
end

-- ==========================================
-- GỬI TỰ ĐỘNG KHI LOAD SCRIPT
-- ==========================================
task.delay(3, function()
    -- Chờ 3s để script/game ổn định rồi mới gửi
    SendWebhook(true)
end)

-- ==========================================
-- XÂY DỰNG GIAO DIỆN BLACK SCREEN XỊN XÒ
-- ==========================================
local guiTarget = nil
pcall(function() guiTarget = gethui() end)
if not guiTarget then pcall(function() guiTarget = game:GetService("CoreGui") end) end
if not guiTarget then guiTarget = LocalPlayer:WaitForChild("PlayerGui") end

local BlackScreenGui = Instance.new("ScreenGui")
BlackScreenGui.Name           = "NthucHub_BlackScreen"
BlackScreenGui.DisplayOrder   = 999998
BlackScreenGui.IgnoreGuiInset = true
BlackScreenGui.Enabled        = false
BlackScreenGui.Parent         = guiTarget

-- ── Nền tối ──────────────────────────────────────────────────────────────────
local BlackBG = Instance.new("Frame")
BlackBG.Name            = "Background"
BlackBG.Size            = UDim2.new(1, 0, 1, 0)
BlackBG.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
BlackBG.Parent          = BlackScreenGui

-- Gradient nền nhẹ
local bgGradient = Instance.new("UIGradient")
bgGradient.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(8, 8, 18)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(5, 5, 8)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(12, 6, 20))
})
bgGradient.Rotation = 135
bgGradient.Parent   = BlackBG

-- ── Card trung tâm ────────────────────────────────────────────────────────────
local Card = Instance.new("Frame")
Card.Name             = "Card"
Card.AnchorPoint      = Vector2.new(0.5, 0.5)
Card.Position         = UDim2.new(0.5, 0, 0.5, 0)
Card.Size             = UDim2.new(0, 320, 0, 440)
Card.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
Card.Parent           = BlackBG

local cardConstraint = Instance.new("UISizeConstraint")
cardConstraint.MaxSize = Vector2.new(340, 460)
cardConstraint.Parent  = Card

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 18)
cardCorner.Parent       = Card

-- Viền gradient màu
local cardStroke = Instance.new("UIStroke")
cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
cardStroke.Color            = Color3.fromRGB(110, 80, 200)
cardStroke.Thickness        = 1.5
cardStroke.Parent           = Card

-- Shimmer trên cùng card
local HeaderBar = Instance.new("Frame")
HeaderBar.Size             = UDim2.new(1, 0, 0, 56)
HeaderBar.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
HeaderBar.Parent           = Card

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 18)
headerCorner.Parent       = HeaderBar

-- Patch để corner chỉ bo góc trên
local headerPatch = Instance.new("Frame")
headerPatch.Size             = UDim2.new(1, 0, 0.5, 0)
headerPatch.Position         = UDim2.new(0, 0, 0.5, 0)
headerPatch.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
headerPatch.BorderSizePixel  = 0
headerPatch.Parent           = HeaderBar

local headerGrad = Instance.new("UIGradient")
headerGrad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 50, 180)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(30, 20, 55))
})
headerGrad.Rotation = 90
headerGrad.Parent   = HeaderBar

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size                = UDim2.new(1, -50, 1, 0)
HeaderTitle.Position            = UDim2.new(0, 15, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text                = "✦ NTHUC HUB"
HeaderTitle.Font                = Enum.Font.GothamBold
HeaderTitle.TextSize            = 16
HeaderTitle.TextColor3          = Color3.fromRGB(220, 200, 255)
HeaderTitle.TextXAlignment      = Enum.TextXAlignment.Left
HeaderTitle.Parent              = HeaderBar

-- Badge "LIVE"
local LiveBadge = Instance.new("Frame")
LiveBadge.Size             = UDim2.new(0, 48, 0, 20)
LiveBadge.AnchorPoint      = Vector2.new(1, 0.5)
LiveBadge.Position         = UDim2.new(1, -12, 0.5, 0)
LiveBadge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
LiveBadge.Parent           = HeaderBar
Instance.new("UICorner", LiveBadge).CornerRadius = UDim.new(0, 6)

local LiveText = Instance.new("TextLabel")
LiveText.Size                   = UDim2.new(1, 0, 1, 0)
LiveText.BackgroundTransparency = 1
LiveText.Text                   = "● LIVE"
LiveText.Font                   = Enum.Font.GothamBold
LiveText.TextSize               = 10
LiveText.TextColor3             = Color3.fromRGB(255, 255, 255)
LiveText.Parent                 = LiveBadge

-- Nhấp nháy LIVE
task.spawn(function()
    while BlackScreenGui.Enabled do
        TweenService:Create(LiveBadge, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundColor3 = Color3.fromRGB(255, 80, 80)
        }):Play()
        task.wait(0.8)
        TweenService:Create(LiveBadge, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundColor3 = Color3.fromRGB(150, 30, 30)
        }):Play()
        task.wait(0.8)
    end
end)

-- ── Avatar ───────────────────────────────────────────────────────────────────
local AvatarRing = Instance.new("Frame")
AvatarRing.Size             = UDim2.new(0, 86, 0, 86)
AvatarRing.AnchorPoint      = Vector2.new(0.5, 0)
AvatarRing.Position         = UDim2.new(0.5, 0, 0, 62)
AvatarRing.BackgroundColor3 = Color3.fromRGB(110, 80, 200)
AvatarRing.Parent           = Card
Instance.new("UICorner", AvatarRing).CornerRadius = UDim.new(1, 0)

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size             = UDim2.new(0, 78, 0, 78)
AvatarImg.AnchorPoint      = Vector2.new(0.5, 0.5)
AvatarImg.Position         = UDim2.new(0.5, 0, 0.5, 0)
AvatarImg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
AvatarImg.Image            = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
AvatarImg.Parent           = AvatarRing
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

-- ── Thông tin nhân vật ───────────────────────────────────────────────────────
local InfoText = Instance.new("TextLabel")
InfoText.Size                   = UDim2.new(1, -24, 0, 70)
InfoText.Position               = UDim2.new(0, 12, 0, 155)
InfoText.BackgroundTransparency = 1
InfoText.Font                   = Enum.Font.GothamSemibold
InfoText.TextSize               = 13
InfoText.TextColor3             = Color3.fromRGB(220, 210, 255)
InfoText.TextYAlignment         = Enum.TextYAlignment.Top
InfoText.RichText               = true
InfoText.Parent                 = Card

-- Divider
local Divider = Instance.new("Frame")
Divider.Size             = UDim2.new(1, -24, 0, 1)
Divider.Position         = UDim2.new(0, 12, 0, 230)
Divider.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
Divider.Parent           = Card

local dividerGrad = Instance.new("UIGradient")
dividerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 80, 200)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 0, 0))
})
dividerGrad.Parent = Divider

local TokensTitle = Instance.new("TextLabel")
TokensTitle.Size                   = UDim2.new(1, -24, 0, 22)
TokensTitle.Position               = UDim2.new(0, 12, 0, 238)
TokensTitle.BackgroundTransparency = 1
TokensTitle.Text                   = "💰 RAID TOKENS"
TokensTitle.Font                   = Enum.Font.GothamBold
TokensTitle.TextSize               = 11
TokensTitle.TextColor3             = Color3.fromRGB(150, 120, 220)
TokensTitle.TextXAlignment         = Enum.TextXAlignment.Left
TokensTitle.Parent                 = Card

-- ── Token List (scroll) ──────────────────────────────────────────────────────
local TokenList = Instance.new("ScrollingFrame")
TokenList.Size                 = UDim2.new(1, -24, 0, 148)
TokenList.Position             = UDim2.new(0, 12, 0, 264)
TokenList.BackgroundColor3     = Color3.fromRGB(20, 16, 32)
TokenList.ScrollBarThickness   = 3
TokenList.ScrollBarImageColor3 = Color3.fromRGB(110, 80, 200)
TokenList.Parent               = Card
Instance.new("UICorner", TokenList).CornerRadius = UDim.new(0, 8)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding   = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent    = TokenList

local listPadding = Instance.new("UIPadding")
listPadding.PaddingLeft   = UDim.new(0, 8)
listPadding.PaddingTop    = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.Parent        = TokenList

-- ── Nút đóng ────────────────────────────────────────────────────────────────
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.new(0, 28, 0, 28)
CloseBtn.AnchorPoint      = Vector2.new(1, 0)
CloseBtn.Position         = UDim2.new(1, -10, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Text             = "✕"
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize         = 13
CloseBtn.ZIndex           = 10
CloseBtn.Parent           = Card
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(220, 60, 60) }):Play()
end)
CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(180, 40, 40) }):Play()
end)

-- ── Cập nhật nội dung ────────────────────────────────────────────────────────
local function UpdateBlackScreen()
    local data = GetPlayerData()

    InfoText.Text = string.format(
        '<font color="#a78bfa"><b>%s</b></font>\n⭐ <font color="#c4b5fd">Level</font> %s\n🛡️ <font color="#c4b5fd">Stand</font> %s',
        data.Name, tostring(data.Level), data.Stand
    )

    for _, child in ipairs(TokenList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local hasTokens = false
    for tokenName, amount in pairs(data.Tokens) do
        hasTokens = true
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, -6, 0, 24)
        row.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
        row.Parent           = TokenList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local dot = Instance.new("Frame")
        dot.Size             = UDim2.new(0, 6, 0, 6)
        dot.AnchorPoint      = Vector2.new(0, 0.5)
        dot.Position         = UDim2.new(0, 6, 0.5, 0)
        dot.BackgroundColor3 = Color3.fromRGB(130, 100, 220)
        dot.Parent           = row
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, -18, 1, 0)
        lbl.Position               = UDim2.new(0, 16, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font                   = Enum.Font.Gotham
        lbl.TextSize               = 12
        lbl.TextColor3             = Color3.fromRGB(200, 190, 230)
        lbl.TextXAlignment         = Enum.TextXAlignment.Left
        lbl.Text                   = string.format("%s: %d", tokenName, amount)
        lbl.Parent                 = row
    end

    if not hasTokens then
        local emptyLbl = Instance.new("Frame")
        emptyLbl.Size             = UDim2.new(1, -6, 0, 24)
        emptyLbl.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
        emptyLbl.Parent           = TokenList
        Instance.new("UICorner", emptyLbl).CornerRadius = UDim.new(0, 6)

        local t = Instance.new("TextLabel")
        t.Size                   = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Text                   = "Không có raid token"
        t.Font                   = Enum.Font.Gotham
        t.TextSize               = 12
        t.TextColor3             = Color3.fromRGB(120, 110, 150)
        t.Parent                 = emptyLbl
    end

    TokenList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
end

-- ==========================================
-- GIAO DIỆN NTHUC HUB (TAB MISC)
-- ==========================================

-- ── SECTION: Hiệu Năng ──────────────────────────────────────────────────────
Tabs.Misc:AddSection("⚡ Tối Ưu Hiệu Năng")

local Toggle_BlackScreen = Tabs.Misc:AddToggle("Toggle_BlackScreen", {
    Title       = "Bật Màn Hình Đen (Boost FPS)",
    Description = "Tắt render 3D, giảm tải GPU. Nhấn X đỏ để đóng.",
    Default     = false,
    Callback    = function(Value)
        Config.BlackScreen = Value
        if Value then
            UpdateBlackScreen()
            BlackScreenGui.Enabled = true
            pcall(function() RunService:Set3dRenderingEnabled(false) end)
        else
            BlackScreenGui.Enabled = false
            pcall(function() RunService:Set3dRenderingEnabled(true) end)
        end
    end
})

CloseBtn.MouseButton1Click:Connect(function()
    Toggle_BlackScreen:SetValue(false)
end)

-- Cập nhật Black Screen định kỳ
task.spawn(function()
    while task.wait(5) do
        if Config.BlackScreen then
            UpdateBlackScreen()
        end
    end
end)

-- ── SECTION: Webhook ─────────────────────────────────────────────────────────
Tabs.Misc:AddSection("📡 Báo Cáo Discord (Webhook)")

Tabs.Misc:AddInput("Input_WebhookURL", {
    Title       = "Discord Webhook URL",
    Description = "Nhập link Webhook rồi nhấn Enter để lưu",
    Default     = "",
    Numeric     = false,
    Finished    = true,
    Callback    = function(Value)
        Config.WebhookURL = Value
    end
})

-- Nút gửi thủ công
Tabs.Misc:AddButton({
    Title       = "📤 Gửi Báo Cáo Ngay",
    Description = "Gửi thông tin nhân vật lên Discord ngay lập tức",
    Callback    = function()
        SendWebhook(false)
    end
})

-- ── SECTION: Auto Webhook ────────────────────────────────────────────────────
Tabs.Misc:AddSection("🔁 Tự Động Gửi Webhook")

local Slider_Interval = Tabs.Misc:AddSlider("Slider_AutoInterval", {
    Title   = "Khoảng Thời Gian Gửi",
    Description = "Chọn chu kỳ tự động gửi webhook (phút)",
    Default = 5,
    Min     = 1,
    Max     = 10,
    Rounding = 0,
    Suffix  = " phút",
    Callback = function(Value)
        Config.AutoInterval = Value
    end
})

local Toggle_AutoWebhook = Tabs.Misc:AddToggle("Toggle_AutoWebhook", {
    Title       = "Bật Tự Động Gửi Webhook",
    Description = "Tự động gửi báo cáo theo chu kỳ đã chọn ở trên",
    Default     = false,
    Callback    = function(Value)
        Config.AutoWebhook = Value
        if Value then
            Fluent:Notify({
                Title   = "✅ Auto Webhook",
                Content = string.format("Đã bật! Gửi mỗi %d phút.", Config.AutoInterval),
                Duration = 3
            })
        else
            Fluent:Notify({ Title = "⏹️ Auto Webhook", Content = "Đã tắt tự động gửi.", Duration = 2 })
        end
    end
})

-- Vòng lặp auto webhook
task.spawn(function()
    local elapsed = 0
    while task.wait(1) do
        if Config.AutoWebhook then
            elapsed = elapsed + 1
            if elapsed >= Config.AutoInterval * 60 then
                elapsed = 0
                SendWebhook(true)
                Fluent:Notify({
                    Title   = "📡 Auto Webhook",
                    Content = "Đã tự động gửi báo cáo lên Discord.",
                    Duration = 2
                })
            end
        else
            elapsed = 0
        end
    end
end)

-- ==========================================
-- SECTION: FPS BOOST
-- ==========================================
Tabs.Misc:AddSection("🚀 FPS & Hiệu Năng")

-- ── Hàm áp dụng FPS Boost toàn diện ────────────────────────────────────────
local fpsBoostActive = false
local savedLOD       = Enum.QualityLevel.Automatic
local savedShadow    = true

local function ApplyFPSBoost(enable)
    fpsBoostActive = enable

    -- 1. Giới hạn FPS (dùng setfpscap nếu executor hỗ trợ)
    pcall(function()
        if setfpscap then
            setfpscap(enable and Config.FPSLimit or 0)
        end
    end)

    -- 2. Tắt/bật shadow toàn map
    pcall(function()
        local lighting = game:GetService("Lighting")
        if enable then
            savedShadow = lighting.GlobalShadows
            lighting.GlobalShadows = false
            lighting.FogEnd        = 1e9
            lighting.Brightness    = 1
        else
            lighting.GlobalShadows = savedShadow
        end
    end)

    -- 3. Chất lượng texture
    pcall(function()
        if enable then
            savedLOD = settings().Rendering.QualityLevel
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        else
            settings().Rendering.QualityLevel = savedLOD
        end
    end)

    -- 4. Tắt tất cả PostProcessing effects trên Lighting
    pcall(function()
        local lighting = game:GetService("Lighting")
        for _, v in ipairs(lighting:GetChildren()) do
            if v:IsA("PostEffect") or v:IsA("Sky") then
                v.Enabled = not enable
            end
        end
    end)

    -- 5. Tắt particle / beam / trail trên toàn workspace (nhẹ hơn đáng kể)
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = not enable
            end
        end
    end)

    Fluent:Notify({
        Title   = enable and "🚀 FPS Boost BẬT" or "🔄 FPS Boost TẮT",
        Content = enable
            and string.format("Đã tối ưu! FPS cap: %d", Config.FPSLimit)
            or  "Đã khôi phục cài đặt đồ họa.",
        Duration = 3
    })
end

-- Slider chọn FPS cap
Tabs.Misc:AddSlider("Slider_FPSCap", {
    Title       = "Giới Hạn FPS",
    Description = "Chọn FPS tối đa khi FPS Boost bật (cần executor hỗ trợ setfpscap)",
    Default     = 60,
    Min         = 30,
    Max         = 240,
    Rounding    = 0,
    Suffix      = " FPS",
    Callback    = function(Value)
        Config.FPSLimit = Value
        if fpsBoostActive then
            pcall(function()
                if setfpscap then setfpscap(Value) end
            end)
        end
    end
})

-- Toggle FPS Boost
Tabs.Misc:AddToggle("Toggle_FPSBoost", {
    Title       = "Bật FPS Boost",
    Description = "Tắt shadow, particle, texture thấp → tăng FPS mạnh",
    Default     = false,
    Callback    = function(Value)
        ApplyFPSBoost(Value)
    end
})

-- ==========================================
-- SECTION: PLAYER MOVEMENT
-- ==========================================
Tabs.Misc:AddSection("🏃 Nhân Vật (Player)")

-- ── Hàm lấy Humanoid an toàn ─────────────────────────────────────────────────
local function GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ── WalkSpeed ────────────────────────────────────────────────────────────────
Tabs.Misc:AddSlider("Slider_WalkSpeed", {
    Title       = "Walk Speed",
    Description = "Tốc độ di chuyển (mặc định: 16)",
    Default     = 16,
    Min         = 1,
    Max         = 500,
    Rounding    = 0,
    Suffix      = "",
    Callback    = function(Value)
        Config.WalkSpeed = Value
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = Value end
    end
})

-- Giữ WalkSpeed khi respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.WalkSpeed  = Config.WalkSpeed
        hum.JumpHeight = Config.JumpSpeed
    end
end)

-- Giữ WalkSpeed liên tục (một số game reset)
task.spawn(function()
    while task.wait(0.5) do
        local hum = GetHumanoid()
        if hum then
            if Config.WalkSpeed ~= 16 then
                hum.WalkSpeed = Config.WalkSpeed
            end
            if Config.JumpSpeed ~= 50 then
                hum.JumpHeight = Config.JumpSpeed
            end
        end
    end
end)

-- ── JumpSpeed (JumpHeight) ───────────────────────────────────────────────────
Tabs.Misc:AddSlider("Slider_JumpSpeed", {
    Title       = "Jump Speed / Height",
    Description = "Độ cao nhảy (mặc định: 50)",
    Default     = 50,
    Min         = 1,
    Max         = 500,
    Rounding    = 0,
    Suffix      = "",
    Callback    = function(Value)
        Config.JumpSpeed = Value
        local hum = GetHumanoid()
        if hum then hum.JumpHeight = Value end
    end
})

-- ── Infinite Jump ────────────────────────────────────────────────────────────
local infJumpConn = nil

Tabs.Misc:AddToggle("Toggle_InfJump", {
    Title       = "Infinite Jump",
    Description = "Nhảy vô hạn trên không",
    Default     = false,
    Callback    = function(Value)
        Config.InfJump = Value

        if Value then
            -- Kết nối UserInputService để bắt Space/Jump
            local UIS = game:GetService("UserInputService")
            infJumpConn = UIS.JumpRequest:Connect(function()
                local hum = GetHumanoid()
                if hum and Config.InfJump then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            Fluent:Notify({ Title = "∞ Infinite Jump", Content = "Đã bật!", Duration = 2 })
        else
            if infJumpConn then
                infJumpConn:Disconnect()
                infJumpConn = nil
            end
            Fluent:Notify({ Title = "∞ Infinite Jump", Content = "Đã tắt.", Duration = 2 })
        end
    end
})
