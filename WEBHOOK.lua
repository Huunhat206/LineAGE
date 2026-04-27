local Players        = game:GetService("Players")
local HttpService    = game:GetService("HttpService")
local LocalPlayer    = Players.LocalPlayer

local Config = {
    WebhookURL  = "https://discord.com/api/webhooks/1498346586219090002/R0u0sUJ6p5X0Bx5AVjwRDME9dQ_tgt4wZNwZo8B3I0Y5HUpWPD6aOboSNYtQPqgzSA3a"
}

local LOGO_URL = "https://static.wikia.nocookie.net/blineage/images/e/e6/Site-logo.png/revision/latest?cb=20260310145648"

-- Chờ Data của nhân vật load xong
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
            footer = { text = "Nthuc Hub  •  Silent Autoexec", icon_url = LOGO_URL },
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

-- Chờ 5 giây sau khi load script/game để đảm bảo mọi thứ đã tải xong rồi gửi Webhook
task.spawn(function()
    task.wait(5)
    SendWebhook()
end)
