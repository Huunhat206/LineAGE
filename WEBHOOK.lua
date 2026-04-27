local Players        = game:GetService("Players")
local HttpService    = game:GetService("HttpService")
local LocalPlayer    = Players.LocalPlayer

local Config = {
    WebhookURL  = "https://discord.com/api/webhooks/1498346586219090002/R0u0sUJ6p5X0Bx5AVjwRDME9dQ_tgt4wZNwZo8B3I0Y5HUpWPD6aOboSNYtQPqgzSA3a"
}

local LOGO_URL = "https://static.wikia.nocookie.net/blineage/images/e/e6/Site-logo.png/revision/latest?cb=20260310145648"

-- Khai báo hàm hệ thống an toàn (phòng trường hợp executor dỏm không hỗ trợ)
local isf = isfile or function() return false end
local rnf = readfile or function() return "{}" end
local wtf = writefile or function() end

-- Chờ Data của nhân vật load xong
LocalPlayer:WaitForChild("PlayerData", 9e9)

local function GetPlayerData()
    local data = {
        Name      = LocalPlayer.Name,
        Level     = 0,
        Stand     = "None",
        Tokens    = {},
        Inventory = {}
    }

    local pData = LocalPlayer:FindFirstChild("PlayerData")
    if pData and pData:FindFirstChild("SlotData") then
        local slot = pData.SlotData

        -- 1. Lấy Level
        if slot:FindFirstChild("Level") then
            data.Level = slot.Level.Value
        end

        -- 2. Lấy Stand
        if slot:FindFirstChild("Stand") then
            local standStr = tostring(slot.Stand.Value)
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, standStr)
            if ok and type(decoded) == "table" and decoded.Name then
                data.Stand = decoded.Name
            else
                data.Stand = string.match(standStr, '"Name"%s*:%s*"([^"]+)"') or "None"
            end
        end

        -- 3. Lấy Raid Tokens
        if slot:FindFirstChild("RaidTokens") then
            local tokenStr = tostring(slot.RaidTokens.Value)
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, tokenStr)
            if ok and type(decoded) == "table" then
                data.Tokens = decoded
            end
        end

        -- 4. Lấy Inventory (Kho đồ)
        if slot:FindFirstChild("Inventory") then
            local invStr = tostring(slot.Inventory.Value)
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, invStr)
            if ok and type(decoded) == "table" then
                -- Quét linh hoạt đề phòng game dùng định dạng Mảng hoặc Dictionary
                for k, v in pairs(decoded) do
                    if type(v) == "number" then
                        data.Inventory[k] = v
                    elseif type(v) == "table" and v.Name and v.Amount then
                        data.Inventory[v.Name] = v.Amount
                    end
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
        -- Lấy file cũ ra đọc
        local ok, savedData = pcall(function() return HttpService:JSONDecode(rnf(fileName)) end)
        if ok and type(savedData) == "table" then
            for itemName, currentAmount in pairs(currentInv) do
                local oldAmount = savedData[itemName] or 0
                -- Nếu số lượng tăng lên, ghi vào báo cáo
                if currentAmount > oldAmount then
                    diffText = diffText .. string.format("• **%s:** `+%d`\n", itemName, currentAmount - oldAmount)
                    newItemsCount = newItemsCount + 1
                end
            end
        end
        if newItemsCount == 0 then
            diffText = "*Không nhận thêm item mới nào.*"
        end
    else
        -- Nếu chưa có file (lần đầu chạy), báo tạo mốc
        diffText = "*Lần đầu khởi chạy! Đã thiết lập mốc dữ liệu gốc.*"
    end

    -- Lưu kho đồ hiện tại đè lên file cũ để làm mốc cho lần sau
    pcall(function()
        wtf(fileName, HttpService:JSONEncode(currentInv))
    end)

    return diffText
end

local function SendWebhook()
    if Config.WebhookURL == "" then return end

    local data = GetPlayerData()
    
    -- Xử lý chuỗi Raid Tokens
    local tokensStr = ""
    for name, amt in pairs(data.Tokens) do
        tokensStr = tokensStr .. string.format("**%s:** %d\n", name, amt)
    end
    if tokensStr == "" then tokensStr = "*Không có token nào.*" end

    -- Xử lý chuỗi Inventory Diff (Đồ mới)
    local newItemsStr = ProcessInventoryDiff(data.Inventory)

    -- Cấu trúc Webhook
    local embedData = {
        username   = "Nthuc Hub Auto",
        avatar_url = LOGO_URL,
        embeds = {{
            title       = "📊 Nthuc Hub · Autoexec Report",
            description = string.format("Báo cáo tài khoản lúc <t:%d:F>", os.time()),
            color       = 0x7B68EE,
            thumbnail   = { url = LOGO_URL },
            fields = {
                { name = "👤 Người Chơi",   value = string.format("`%s`", data.Name),        inline = true  },
                { name = "⭐ Level",        value = string.format("`%s`", tostring(data.Level)), inline = true  },
                { name = "🛡️ Stand",       value = string.format("`%s`", data.Stand),        inline = false },
                { name = "💰 Raid Tokens",   value = tokensStr,                                inline = false },
                { name = "🎁 Items (New)",   value = newItemsStr,                              inline = false }
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
