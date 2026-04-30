local Players        = game:GetService("Players")
local HttpService    = game:GetService("HttpService")
local LocalPlayer    = Players.LocalPlayer

local Config = {
    WebhookURL  = "https://discord.com/api/webhooks/1498346586219090002/R0u0sUJ6p5X0Bx5AVjwRDME9dQ_tgt4wZNwZo8B3I0Y5HUpWPD6aOboSNYtQPqgzSA3a"
}

local LOGO_URL = "https://static.wikia.nocookie.net/blineage/images/e/e6/Site-logo.png/revision/latest?cb=20260310145648"

local isf = isfile or function() return false end
local rnf = readfile or function() return "{}" end
local wtf = writefile or function() end

LocalPlayer:WaitForChild("PlayerData", 9e9)

local function GetPlayerData()
    local data = { Name = LocalPlayer.Name, Level = 0, Stand = "None", Tokens = {}, Inventory = {} }
    local pData = LocalPlayer:FindFirstChild("PlayerData")
    if pData and pData:FindFirstChild("SlotData") then
        local slot = pData.SlotData
        if slot:FindFirstChild("Level") then data.Level = slot.Level.Value end
        if slot:FindFirstChild("Stand") then
            local standStr = tostring(slot.Stand.Value)
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, standStr)
            data.Stand = (ok and type(decoded) == "table") and decoded.Name or (string.match(standStr, '"Name"%s*:%s*"([^"]+)"') or "None")
        end
        if slot:FindFirstChild("RaidTokens") then
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, tostring(slot.RaidTokens.Value))
            if ok then data.Tokens = decoded end
        end
        if slot:FindFirstChild("Inventory") then
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, tostring(slot.Inventory.Value))
            if ok and type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if type(v) == "number" then data.Inventory[k] = v
                    elseif type(v) == "table" and v.Name then data.Inventory[v.Name] = v.Amount end
                end
            end
        end
    end
    return data
end

local function ProcessInventoryDiff(currentInv)
    local fileName = "NthucHub_Inv_" .. LocalPlayer.Name .. ".json"
    local diffText = ""
    local newItemsCount = 0

    if isf(fileName) then
        local ok, savedData = pcall(function() return HttpService:JSONDecode(rnf(fileName)) end)
        if ok and type(savedData) == "table" then
            for itemName, currentAmount in pairs(currentInv) do
                local oldAmount = savedData[itemName] or 0
                if currentAmount > oldAmount then
                    -- Định dạng kiểu log hệ thống: [+] Item Name ... +Amount
                    diffText = diffText .. string.format("`[+]` **%s** ➔ `%+d`\n", itemName, currentAmount - oldAmount)
                    newItemsCount = newItemsCount + 1
                end
            end
        end
        if newItemsCount == 0 then diffText = "▫️ *No new items detected.*" end
    else
        diffText = "🆕 *First boot: Baseline data established.*"
    end
    pcall(function() wtf(fileName, HttpService:JSONEncode(currentInv)) end)
    return diffText
end

local function SendWebhook()
    if Config.WebhookURL == "" then return end
    local data = GetPlayerData()
    
    -- [NÂNG CẤP] Tạo bảng Token giả lập (Pseudo-Table)
    -- Sử dụng ký tự box-drawing để tạo khung
    local tokensTable = "```\n┌──────┬──────────┐\n│ TOKEN│ AMOUNT  │\n├──────┼──────────┤\n"
    local hasTokens = false
    for name, amt in pairs(data.Tokens) do
        hasTokens = true
        local nameClipped = name:sub(1, 5):ljust(5) -- Cắt tên token để vừa bảng
        tokensTable = tokensTable .. string.format("│ %-5s│ %-8s│\n", nameClipped, tostring(amt))
    end
    
    if not hasTokens then 
        tokensTable = "```\n*No tokens available in storage.*" 
    else 
        tokensTable = tokensTable .. "└──────┴──────────┘\n```"
    end

    local newItemsStr = ProcessInventoryDiff(data.Inventory)

    -- [NÂNG CẤP] Embed Layout siêu sang
    local embedData = {
        username   = "Nthuc Hub | System Logger",
        avatar_url = LOGO_URL,
        embeds = {{
            title       = "💠 SESSION DATA REPORT",
            description = string.format("📡 **Status:** `Online` | **Session:** `S-LOG`\n**Timestamp:** <t:%d:f> (<t:%d:R>)\n━━━━━━━━━━━━━━━━━━━━━━━━━━", os.time(), os.time()),
            color       = 0x7B68EE,
            thumbnail   = { url = LOGO_URL },
            fields = {
                { 
                    name = "👤 USER PROFILE", 
                    value = string.format("```yaml\nName:  %s\nLevel: %s\nStand: %s\n```", data.Name, tostring(data.Level), data.Stand), 
                    inline = false 
                },
                { 
                    name = "💰 RAID TOKENS", 
                    value = tokensTable, 
                    inline = false 
                },
                { 
                    name = "🎁 INVENTORY LOG (NEW)", 
                    value = newItemsStr, 
                    inline = false 
                },
            },
            footer = { 
                text = "Nthuc Hub Premium • Secure Data Transmission", 
                icon_url = LOGO_URL 
            },
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

task.spawn(function()
    task.wait(5)
    SendWebhook()
end)
