local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local HttpService    = game:GetService("HttpService")
local TweenService   = game:GetService("TweenService")
local CoreGui        = game:GetService("CoreGui")
local LocalPlayer    = Players.LocalPlayer

local Config = {
    WebhookURL  = "https://discord.com/api/webhooks/1498346586219090002/R0u0sUJ6p5X0Bx5AVjwRDME9dQ_tgt4wZNwZo8B3I0Y5HUpWPD6aOboSNYtQPqgzSA3a", 
    FPSLimit    = 60
}

local LOGO_URL = "https://static.wikia.nocookie.net/blineage/images/e/e6/Site-logo.png/revision/latest?cb=20260310145648"

LocalPlayer:WaitForChild("PlayerData", 9e9)

local function GetPlayerData()
    local data = {
        Name   = LocalPlayer.Name,
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

local function SendWebhook()
    if Config.WebhookURL == "" then return end

    local data = GetPlayerData()
    local tokensStr = ""
    for name, amt in pairs(data.Tokens) do
        tokensStr = tokensStr .. string.format("**%s:** %d\n", name, amt)
    end
    if tokensStr == "" then tokensStr = "*Không có token nào.*" end

    local embedData = {
        username   = "Nthuc Hub Auto",
        avatar_url = LOGO_URL,
        embeds = {{
            title       = "📊 Nthuc Hub · Autoexec Report",
            description = string.format("Tài khoản vừa tham gia máy chủ lúc <t:%d:F>", os.time()),
            color       = 0x7B68EE,
            thumbnail   = { url = LOGO_URL },
            fields = {
                { name = "👤 Tên Người Chơi", value = string.format("`%s`", data.Name),        inline = true  },
                { name = "⭐ Level",          value = string.format("`%s`", tostring(data.Level)), inline = true  },
                { name = "🛡️ Stand",         value = string.format("`%s`", data.Stand),        inline = false },
                { name = "💰 Raid Tokens",     value = tokensStr,                                inline = false }
            },
            footer = { text = "Nthuc Hub  •  AFK Mode", icon_url = LOGO_URL },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if requestFunc then
        pcall(function()
            requestFunc({
                Url     = Config.WebhookURL,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = HttpService:JSONEncode(embedData)
            })
        end)
    end
end

local guiTarget = nil
pcall(function() guiTarget = gethui() end)
if not guiTarget then pcall(function() guiTarget = CoreGui end) end
if not guiTarget then guiTarget = LocalPlayer:WaitForChild("PlayerGui") end

if getgenv().Nthuc_AutoAFK then
    pcall(function() getgenv().Nthuc_AutoAFK:Destroy() end)
end

local BlackScreenGui = Instance.new("ScreenGui")
BlackScreenGui.Name           = "NthucHub_BlackScreen"
BlackScreenGui.DisplayOrder   = 999999
BlackScreenGui.IgnoreGuiInset = true
BlackScreenGui.Parent         = guiTarget
getgenv().Nthuc_AutoAFK       = BlackScreenGui

local BlackBG = Instance.new("Frame")
BlackBG.Size             = UDim2.new(1, 0, 1, 0)
BlackBG.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
BlackBG.Parent           = BlackScreenGui

local bgGradient = Instance.new("UIGradient")
bgGradient.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(8, 8, 18)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(5, 5, 8)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(12, 6, 20))
})
bgGradient.Rotation = 135
bgGradient.Parent   = BlackBG

local Card = Instance.new("Frame")
Card.AnchorPoint      = Vector2.new(0.5, 0.5)
Card.Position         = UDim2.new(0.5, 0, 0.5, 0)
Card.Size             = UDim2.new(0, 320, 0, 440)
Card.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
Card.Parent           = BlackBG

Instance.new("UISizeConstraint", Card).MaxSize = Vector2.new(340, 460)
Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 18)

local cardStroke = Instance.new("UIStroke")
cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
cardStroke.Color           = Color3.fromRGB(110, 80, 200)
cardStroke.Thickness       = 1.5
cardStroke.Parent          = Card

local HeaderBar = Instance.new("Frame")
HeaderBar.Size             = UDim2.new(1, 0, 0, 56)
HeaderBar.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
HeaderBar.Parent           = Card
Instance.new("UICorner", HeaderBar).CornerRadius = UDim.new(0, 18)

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
HeaderTitle.Size               = UDim2.new(1, -50, 1, 0)
HeaderTitle.Position           = UDim2.new(0, 15, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text               = "NTHUC HUB (AFK MODE)"
HeaderTitle.Font               = Enum.Font.GothamBold
HeaderTitle.TextSize           = 14
HeaderTitle.TextColor3         = Color3.fromRGB(220, 200, 255)
HeaderTitle.TextXAlignment     = Enum.TextXAlignment.Left
HeaderTitle.Parent             = HeaderBar

local LiveBadge = Instance.new("Frame")
LiveBadge.Size             = UDim2.new(0, 48, 0, 20)
LiveBadge.AnchorPoint      = Vector2.new(1, 0.5)
LiveBadge.Position         = UDim2.new(1, -45, 0.5, 0)
LiveBadge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
LiveBadge.Parent           = HeaderBar
Instance.new("UICorner", LiveBadge).CornerRadius = UDim.new(0, 6)

local LiveText = Instance.new("TextLabel")
LiveText.Size               = UDim2.new(1, 0, 1, 0)
LiveText.BackgroundTransparency = 1
LiveText.Text               = "● LIVE"
LiveText.Font               = Enum.Font.GothamBold
LiveText.TextSize           = 10
LiveText.TextColor3         = Color3.fromRGB(255, 255, 255)
LiveText.Parent             = LiveBadge

task.spawn(function()
    while BlackScreenGui.Parent do
        TweenService:Create(LiveBadge, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
        task.wait(0.8)
        TweenService:Create(LiveBadge, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = Color3.fromRGB(150, 30, 30)}):Play()
        task.wait(0.8)
    end
end)

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

local InfoText = Instance.new("TextLabel")
InfoText.Size               = UDim2.new(1, -24, 0, 70)
InfoText.Position           = UDim2.new(0, 12, 0, 155)
InfoText.BackgroundTransparency = 1
InfoText.Font               = Enum.Font.GothamSemibold
InfoText.TextSize           = 13
InfoText.TextColor3         = Color3.fromRGB(220, 210, 255)
InfoText.TextYAlignment     = Enum.TextYAlignment.Top
InfoText.RichText           = true
InfoText.Parent             = Card

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
TokensTitle.Size               = UDim2.new(1, -24, 0, 22)
TokensTitle.Position           = UDim2.new(0, 12, 0, 238)
TokensTitle.BackgroundTransparency = 1
TokensTitle.Text               = "💰 RAID TOKENS"
TokensTitle.Font               = Enum.Font.GothamBold
TokensTitle.TextSize           = 11
TokensTitle.TextColor3         = Color3.fromRGB(150, 120, 220)
TokensTitle.TextXAlignment     = Enum.TextXAlignment.Left
TokensTitle.Parent             = Card

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

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.new(0, 28, 0, 28)
CloseBtn.AnchorPoint      = Vector2.new(1, 0)
CloseBtn.Position         = UDim2.new(1, -10, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Text             = "X"
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

CloseBtn.MouseButton1Click:Connect(function()
    BlackScreenGui:Destroy()
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    pcall(function() if setfpscap then setfpscap(0) end end)
end)

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
        lbl.Size               = UDim2.new(1, -18, 1, 0)
        lbl.Position           = UDim2.new(0, 16, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font               = Enum.Font.Gotham
        lbl.TextSize           = 12
        lbl.TextColor3         = Color3.fromRGB(200, 190, 230)
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Text               = string.format("%s: %d", tokenName, amount)
        lbl.Parent             = row
    end

    if not hasTokens then
        local emptyLbl = Instance.new("Frame")
        emptyLbl.Size             = UDim2.new(1, -6, 0, 24)
        emptyLbl.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
        emptyLbl.Parent           = TokenList
        Instance.new("UICorner", emptyLbl).CornerRadius = UDim.new(0, 6)

        local t = Instance.new("TextLabel")
        t.Size               = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Text               = "Không có raid token"
        t.Font               = Enum.Font.Gotham
        t.TextSize           = 12
        t.TextColor3         = Color3.fromRGB(120, 110, 150)
        t.Parent             = emptyLbl
    end

    TokenList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
end

pcall(function() RunService:Set3dRenderingEnabled(false) end)
pcall(function() if setfpscap then setfpscap(Config.FPSLimit) end end)

task.spawn(function()
    while BlackScreenGui.Parent do
        UpdateBlackScreen()
        task.wait(5)
    end
end)

task.spawn(function()
    task.wait(5)
    SendWebhook()
end)
