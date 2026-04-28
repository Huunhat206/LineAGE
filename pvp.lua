-- ============================================================
--  NTHUC HUB  ·  PvP Auto Queue
--  Main  = ấn E đến khi Joined, chờ Left/teleport rồi lặp
--  Alt   = ấn E đến khi Joined, chờ teleport → kill respawn → lặp
--  Auto-save: bật/tắt sẽ giữ nguyên khi re-execute
-- ============================================================

local Players    = game:GetService("Players")
local TweenSvc   = game:GetService("TweenService")
local HttpSvc    = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ── Camera lock system ────────────────────────────────────────────────────────
local camLockConn    = nil
local camLockEnabled = false
local fixedCamCF     = nil   -- CFrame cố định trong world space

local function StartCameraLock(boardCF)
    if not camLockEnabled then return end
    -- Disconnect loop cũ nếu có
    if camLockConn then camLockConn:Disconnect() camLockConn = nil end

    local boardPos = boardCF.Position

    -- Lấy hướng từ board đến nhân vật → camera đứng cùng phía với player nhìn vào board
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    local camDir
    if root then
        local toPlayer = root.Position - boardPos
        local flat = Vector3.new(toPlayer.X, 0, toPlayer.Z)
        camDir = flat.Magnitude > 0.5 and flat.Unit or Vector3.new(0, 0, 1)
    else
        -- Fallback: dùng ngược LookVector flatten
        local fwd = boardCF.LookVector
        local flat = Vector3.new(fwd.X, 0, fwd.Z)
        camDir = flat.Magnitude > 0.1 and -flat.Unit or Vector3.new(0, 0, 1)
    end

    -- Camera đứng sau nhân vật một chút, ngang tầm mắt, nhìn thẳng vào board
    local camPos = boardPos + camDir * 10 + Vector3.new(0, 2, 0)
    fixedCamCF = CFrame.lookAt(camPos, boardPos + Vector3.new(0, 2, 0))

    -- Set một lần → free cam, không bị force mỗi frame, không ảnh hưởng bởi character
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame     = fixedCamCF
end

local function StopCameraLock()
    if camLockConn then
        camLockConn:Disconnect()
        camLockConn = nil
    end
    fixedCamCF = nil
    Camera.CameraType = Enum.CameraType.Custom
end

-- ── Config save/load ──────────────────────────────────────────────────────────
local CFG_FILE = "NthucHub_PvP.json"
local Cfg = { MainActive = false, AltActive = false }

local function SaveCfg()
    pcall(function() writefile(CFG_FILE, HttpSvc:JSONEncode(Cfg)) end)
end
local function LoadCfg()
    pcall(function()
        if isfile and isfile(CFG_FILE) then
            local d = HttpSvc:JSONDecode(readfile(CFG_FILE))
            if d then
                Cfg.MainActive = d.MainActive or false
                Cfg.AltActive  = d.AltActive  or false
            end
        end
    end)
end
LoadCfg()

-- ── Lấy PvP Mission Board ─────────────────────────────────────────────────────
local function GetBoard()
    local map    = workspace:FindFirstChild("Map")
    local boards = map and map:FindFirstChild("Mission Boards")
    local pvp    = boards and boards:FindFirstChild("PvP")
    return pvp and pvp:FindFirstChild("PvP Mission Board")
end

local function GetBoardCFrame(board)
    if board:IsA("Model")    then return board:GetPivot() end
    if board:IsA("BasePart") then return board.CFrame     end
    return nil
end

-- ── Teleport + kích ProximityPrompt (INSTANT - tương thích Solara) ───────────
local function PressBoard(board, rootPart)
    local cf = GetBoardCFrame(board)
    if not cf then return end

    rootPart.CFrame = cf * CFrame.new(0, 0, 2)
    task.wait(0.3)

    local prompt = board:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then return end

    -- ── Method 1: fireproximityprompt (Synapse / Script-Ware) ────────────────
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt)
        task.wait(0.3)
        return
    end

    -- ── Method 2: Solara & hầu hết executor còn lại ──────────────────────────
    -- Ép HoldDuration = 0 → InputHoldBegin + InputHoldEnd trong 1 frame = instant
    local oldHold = prompt.HoldDuration
    local oldDist = prompt.MaxActivationDistance

    pcall(function()
        prompt.HoldDuration          = 0
        prompt.MaxActivationDistance = 32   -- đảm bảo trong tầm kích hoạt
    end)

    task.wait()   -- đợi 1 frame để property áp dụng

    pcall(function() prompt:InputHoldBegin() end)
    task.wait()   -- 1 frame
    pcall(function() prompt:InputHoldEnd()   end)

    -- Khôi phục giá trị gốc
    pcall(function()
        prompt.HoldDuration          = oldHold
        prompt.MaxActivationDistance = oldDist
    end)

    task.wait(0.3)
end

-- ── Theo dõi notification từ PlayerGui.Notifications.holder ──────────────────
--   Trả về true nếu tìm thấy keyword trong khoảng timeout (giây)
local function WaitNotification(keyword, timeout)
    -- Path: PlayerGui → Notifications → holder → [tên notify].title
    local pg       = LocalPlayer:FindFirstChild("PlayerGui")
    local notifGui = pg and pg:FindFirstChild("Notifications")
    local holder   = notifGui and notifGui:FindFirstChild("holder")
    if not holder then
        -- thử đợi
        pcall(function()
            notifGui = pg:WaitForChild("Notifications", 5)
            holder   = notifGui and notifGui:WaitForChild("holder", 5)
        end)
    end
    if not holder then return false end

    local found = false
    local conn  = holder.ChildAdded:Connect(function(child)
        -- tên child thường chính là text thông báo (VD: "Joined PvP Mission Queue.")
        if child.Name:find(keyword, 1, true) then
            found = true
            return
        end
        -- dự phòng: check TextLabel .title sau 0.1s (để game kịp set text)
        task.delay(0.15, function()
            local lbl = child:FindFirstChild("title")
            if lbl and lbl:IsA("TextLabel") and lbl.Text:find(keyword, 1, true) then
                found = true
            end
        end)
    end)

    local elapsed = 0
    while not found and elapsed < timeout do
        task.wait(0.25)
        elapsed = elapsed + 0.25
    end

    conn:Disconnect()
    return found
end

-- ── Theo dõi "Left PvP" qua notification ─────────────────────────────────────
local function WatchLeft(onLeft)
    local pg       = LocalPlayer:FindFirstChild("PlayerGui")
    local notifGui = pg and pg:FindFirstChild("Notifications")
    local holder   = notifGui and notifGui:FindFirstChild("holder")
    if not holder then return function() end end

    local conn = holder.ChildAdded:Connect(function(child)
        local function check()
            if child.Name:find("Left PvP", 1, true) then onLeft() return end
            task.delay(0.15, function()
                local lbl = child:FindFirstChild("title")
                if lbl and lbl:IsA("TextLabel") and lbl.Text:find("Left PvP", 1, true) then
                    onLeft()
                end
            end)
        end
        check()
    end)

    return function() conn:Disconnect() end
end

-- ── Trạng thái hiển thị lên GUI label ─────────────────────────────────────────
local StatusLabel -- sẽ gán sau khi tạo GUI

local function SetStatus(text, color)
    if StatusLabel then
        StatusLabel.Text      = text
        StatusLabel.TextColor3 = color or Color3.fromRGB(180, 165, 220)
    end
end

-- ============================================================
--  MAIN LOOP  (bên thắng)
-- ============================================================
local mainThread = nil

local function MainLoop()
    while Cfg.MainActive do
        SetStatus("⚙️ Main: chuẩn bị...", Color3.fromRGB(160, 140, 200))
        local char    = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root    = char:WaitForChild("HumanoidRootPart", 10)
        local hum     = char:WaitForChild("Humanoid", 10)
        if not root or not hum then task.wait(1) continue end

        local board = GetBoard()
        if not board then
            SetStatus("❌ Không tìm thấy Board", Color3.fromRGB(220, 80, 80))
            task.wait(3)
            continue
        end
        local boardCF = GetBoardCFrame(board)

        -- 🎥 Lock camera nhìn vào board khi đang ấn E
        if boardCF then StartCameraLock(boardCF) end

        -- Lắng nghe Joined notification song song, ấn lại mỗi lần nếu chưa được
        local joined = false
        local pg2    = LocalPlayer:FindFirstChild("PlayerGui")
        local ng2    = pg2 and pg2:FindFirstChild("Notifications")
        local hd2    = ng2 and ng2:FindFirstChild("holder")
        if not hd2 then pcall(function()
            ng2 = pg2:WaitForChild("Notifications", 5)
            hd2 = ng2 and ng2:WaitForChild("holder", 5)
        end) end

        local joinConn
        if hd2 then
            joinConn = hd2.ChildAdded:Connect(function(child)
                if child.Name:find("Joined PvP", 1, true) then joined = true return end
                task.delay(0.2, function()
                    local lbl = child:FindFirstChild("title")
                    if lbl and lbl:IsA("TextLabel") and lbl.Text:find("Joined PvP", 1, true) then
                        joined = true
                    end
                end)
            end)
        end

        local attempt = 0
        while Cfg.MainActive and not joined do
            attempt = attempt + 1
            SetStatus(string.format("🔄 Main: ấn E... (lần %d)", attempt), Color3.fromRGB(180, 160, 220))
            PressBoard(board, root)
            local w = 0
            while w < 3 and not joined do task.wait(0.25) w = w + 0.25 end
        end
        if joinConn then joinConn:Disconnect() end

        if not Cfg.MainActive then StopCameraLock() break end

        -- 🎥 Đã vào hàng → trả camera về bình thường
        StopCameraLock()
        SetStatus("✅ Main: đã vào hàng!", Color3.fromRGB(80, 210, 130))

        -- Chờ Left notification hoặc teleport khỏi board
        local left      = false
        local stopWatch = WatchLeft(function() left = true end)

        while Cfg.MainActive and not left do
            if not root or not root.Parent or hum.Health <= 0 then break end
            if boardCF and (root.Position - boardCF.Position).Magnitude > 50 then
                left = true
            end
            task.wait(0.5)
        end

        stopWatch()
        SetStatus("↩️ Main: chờ rồi lặp lại...", Color3.fromRGB(160, 140, 200))
        task.wait(2)
    end
    StopCameraLock()
    SetStatus("⏹️ Main: đã tắt", Color3.fromRGB(120, 110, 150))
end

-- ============================================================
--  ALT LOOP  (bên thua)
-- ============================================================
local altThread = nil

local function AltLoop()
    while Cfg.AltActive do
        SetStatus("⚙️ Alt: chuẩn bị...", Color3.fromRGB(200, 140, 140))
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart", 10)
        local hum  = char:WaitForChild("Humanoid", 10)
        if not root or not hum then task.wait(1) continue end

        local board = GetBoard()
        if not board then
            SetStatus("❌ Không tìm thấy Board", Color3.fromRGB(220, 80, 80))
            task.wait(3)
            continue
        end
        local boardCF = GetBoardCFrame(board)

        -- 🎥 Lock camera nhìn vào board khi đang ấn E
        if boardCF then StartCameraLock(boardCF) end

        -- Lắng nghe Joined notification song song
        local joined = false
        local pg3    = LocalPlayer:FindFirstChild("PlayerGui")
        local ng3    = pg3 and pg3:FindFirstChild("Notifications")
        local hd3    = ng3 and ng3:FindFirstChild("holder")
        if not hd3 then pcall(function()
            ng3 = pg3:WaitForChild("Notifications", 5)
            hd3 = ng3 and ng3:WaitForChild("holder", 5)
        end) end

        local joinConn2
        if hd3 then
            joinConn2 = hd3.ChildAdded:Connect(function(child)
                if child.Name:find("Joined PvP", 1, true) then joined = true return end
                task.delay(0.2, function()
                    local lbl = child:FindFirstChild("title")
                    if lbl and lbl:IsA("TextLabel") and lbl.Text:find("Joined PvP", 1, true) then
                        joined = true
                    end
                end)
            end)
        end

        local attempt2 = 0
        while Cfg.AltActive and not joined do
            attempt2 = attempt2 + 1
            SetStatus(string.format("🔄 Alt: ấn E... (lần %d)", attempt2), Color3.fromRGB(220, 160, 140))
            PressBoard(board, root)
            local w = 0
            while w < 3 and not joined do task.wait(0.25) w = w + 0.25 end
        end
        if joinConn2 then joinConn2:Disconnect() end

        if not Cfg.AltActive then StopCameraLock() break end

        -- 🎥 Đã vào hàng → trả camera về bình thường
        StopCameraLock()
        SetStatus("✅ Alt: đã vào hàng!", Color3.fromRGB(220, 120, 80))

        -- Chờ bị teleport vào map (dist > 50)
        local teleported = false
        local elapsed    = 0
        while Cfg.AltActive and not teleported and elapsed < 90 do
            if not root or not root.Parent or hum.Health <= 0 then break end
            if boardCF and (root.Position - boardCF.Position).Magnitude > 50 then
                teleported = true
            end
            task.wait(0.5)
            elapsed = elapsed + 0.5
        end

        if teleported and Cfg.AltActive then
            SetStatus("💀 Alt: thua → respawn...", Color3.fromRGB(220, 80, 80))
            -- Chờ vào map rồi mới kill (tránh kill ngay lúc loading)
            task.wait(3)
            local c2  = LocalPlayer.Character
            local h2  = c2 and c2:FindFirstChildOfClass("Humanoid")
            if h2 then h2.Health = 0 end
            LocalPlayer.CharacterAdded:Wait()
            task.wait(2)
        else
            task.wait(1)
        end
    end
    StopCameraLock()
    SetStatus("⏹️ Alt: đã tắt", Color3.fromRGB(120, 110, 150))
end

-- ============================================================
--  GUI
-- ============================================================
-- Xoá GUI cũ nếu re-execute
for _, v in ipairs({ LocalPlayer.PlayerGui, game:GetService("CoreGui") }) do
    pcall(function()
        local old = v:FindFirstChild("NthucHub_PvPGui")
        if old then old:Destroy() end
    end)
end

local guiParent = LocalPlayer.PlayerGui
pcall(function()
    local gh = gethui()
    if gh then guiParent = gh end
end)
pcall(function()
    if not guiParent or guiParent == LocalPlayer.PlayerGui then
        guiParent = game:GetService("CoreGui")
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "NthucHub_PvPGui"
ScreenGui.DisplayOrder   = 999999
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn   = false
ScreenGui.Parent         = guiParent

-- ── Frame chính ──────────────────────────────────────────────────────────────
local W, H = 270, 244
local Frame = Instance.new("Frame")
Frame.Size             = UDim2.new(0, W, 0, H)
Frame.Position         = UDim2.new(0.5, -W/2, 0, 24)
Frame.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
Frame.Active           = true
Frame.Draggable        = true
Frame.ClipsDescendants = true
Frame.Parent           = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 16)

-- Gradient nền
local bgGrad = Instance.new("UIGradient")
bgGrad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(14, 10, 28)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(8,  6, 16)),
})
bgGrad.Rotation = 120
bgGrad.Parent   = Frame

-- Viền ngoài
local outerStroke = Instance.new("UIStroke")
outerStroke.Color     = Color3.fromRGB(90, 60, 160)
outerStroke.Thickness = 1.5
outerStroke.Parent    = Frame

-- ── Header ───────────────────────────────────────────────────────────────────
local Header = Instance.new("Frame")
Header.Size             = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Color3.fromRGB(22, 14, 45)
Header.ZIndex           = 2
Header.Parent           = Frame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

-- Patch góc dưới header
local hp = Instance.new("Frame")
hp.Size             = UDim2.new(1, 0, 0, 16)
hp.Position         = UDim2.new(0, 0, 1, -16)
hp.BackgroundColor3 = Color3.fromRGB(22, 14, 45)
hp.BorderSizePixel  = 0
hp.ZIndex           = 2
hp.Parent           = Header

local hGrad = Instance.new("UIGradient")
hGrad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(70, 40, 160)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(22, 14,  45)),
})
hGrad.Rotation = 90
hGrad.Parent   = Header

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size               = UDim2.new(1, -16, 1, 0)
TitleLbl.Position           = UDim2.new(0, 12, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text               = "⚔️  PvP Auto Queue"
TitleLbl.Font               = Enum.Font.GothamBold
TitleLbl.TextSize           = 14
TitleLbl.TextColor3         = Color3.fromRGB(210, 190, 255)
TitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
TitleLbl.ZIndex             = 3
TitleLbl.Parent             = Header

-- Nút đóng GUI
local CloseGui = Instance.new("TextButton")
CloseGui.Size             = UDim2.new(0, 24, 0, 24)
CloseGui.AnchorPoint      = Vector2.new(1, 0.5)
CloseGui.Position         = UDim2.new(1, -10, 0.5, 0)
CloseGui.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
CloseGui.Text             = "✕"
CloseGui.Font             = Enum.Font.GothamBold
CloseGui.TextSize         = 11
CloseGui.TextColor3       = Color3.fromRGB(255, 255, 255)
CloseGui.ZIndex           = 5
CloseGui.Parent           = Header
Instance.new("UICorner", CloseGui).CornerRadius = UDim.new(0, 7)
CloseGui.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- ── Status label ─────────────────────────────────────────────────────────────
StatusLabel = Instance.new("TextLabel")
StatusLabel.Size               = UDim2.new(1, -16, 0, 22)
StatusLabel.Position           = UDim2.new(0, 8, 0, 48)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text               = "⏹️  Chờ bật..."
StatusLabel.Font               = Enum.Font.Gotham
StatusLabel.TextSize           = 11
StatusLabel.TextColor3         = Color3.fromRGB(130, 120, 160)
StatusLabel.TextXAlignment     = Enum.TextXAlignment.Center
StatusLabel.ZIndex             = 2
StatusLabel.Parent             = Frame

-- ── Toggle Button Factory ─────────────────────────────────────────────────────
local function MakeToggle(label, yPos, activeCol, inactiveCol, initState, onToggle)
    local Btn = Instance.new("TextButton")
    Btn.Size             = UDim2.new(1, -20, 0, 50)
    Btn.Position         = UDim2.new(0, 10, 0, yPos)
    Btn.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
    Btn.Text             = ""
    Btn.ZIndex           = 2
    Btn.Parent           = Frame
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 12)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color     = Color3.fromRGB(55, 40, 90)
    btnStroke.Thickness = 1
    btnStroke.Parent    = Btn

    -- Icon / badge bên trái
    local Icon = Instance.new("Frame")
    Icon.Size             = UDim2.new(0, 36, 0, 36)
    Icon.AnchorPoint      = Vector2.new(0, 0.5)
    Icon.Position         = UDim2.new(0, 8, 0.5, 0)
    Icon.BackgroundColor3 = inactiveCol
    Icon.ZIndex           = 3
    Icon.Parent           = Btn
    Instance.new("UICorner", Icon).CornerRadius = UDim.new(0, 10)

    local IconGrad = Instance.new("UIGradient")
    IconGrad.Color    = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180,180,180)),
    })
    IconGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 0.8),
    })
    IconGrad.Rotation = -45
    IconGrad.Parent   = Icon

    local IconTxt = Instance.new("TextLabel")
    IconTxt.Size               = UDim2.new(1, 0, 1, 0)
    IconTxt.BackgroundTransparency = 1
    IconTxt.Text               = label == "Main" and "🏆" or "💀"
    IconTxt.TextSize           = 18
    IconTxt.Font               = Enum.Font.GothamBold
    IconTxt.ZIndex             = 4
    IconTxt.Parent             = Icon

    -- Tên & mô tả
    local NameLbl = Instance.new("TextLabel")
    NameLbl.Size               = UDim2.new(1, -110, 0, 18)
    NameLbl.Position           = UDim2.new(0, 54, 0, 7)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Text               = label == "Main" and "Main  (Bên Thắng)" or "Alt  (Bên Thua)"
    NameLbl.Font               = Enum.Font.GothamBold
    NameLbl.TextSize           = 13
    NameLbl.TextColor3         = Color3.fromRGB(200, 185, 235)
    NameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    NameLbl.ZIndex             = 3
    NameLbl.Parent             = Btn

    local DescLbl = Instance.new("TextLabel")
    DescLbl.Size               = UDim2.new(1, -110, 0, 16)
    DescLbl.Position           = UDim2.new(0, 54, 0, 26)
    DescLbl.BackgroundTransparency = 1
    DescLbl.Text               = label == "Main" and "Ấn E → Joined → chờ Left → lặp" or "Ấn E → Joined → thua → kill → lặp"
    DescLbl.Font               = Enum.Font.Gotham
    DescLbl.TextSize           = 10
    DescLbl.TextColor3         = Color3.fromRGB(110, 100, 140)
    DescLbl.TextXAlignment     = Enum.TextXAlignment.Left
    DescLbl.ZIndex             = 3
    DescLbl.Parent             = Btn

    -- Pill toggle bên phải
    local PillBg = Instance.new("Frame")
    PillBg.Size             = UDim2.new(0, 44, 0, 22)
    PillBg.AnchorPoint      = Vector2.new(1, 0.5)
    PillBg.Position         = UDim2.new(1, -10, 0.5, 0)
    PillBg.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
    PillBg.ZIndex           = 3
    PillBg.Parent           = Btn
    Instance.new("UICorner", PillBg).CornerRadius = UDim.new(1, 0)

    local PillDot = Instance.new("Frame")
    PillDot.Size             = UDim2.new(0, 16, 0, 16)
    PillDot.AnchorPoint      = Vector2.new(0, 0.5)
    PillDot.Position         = UDim2.new(0, 3, 0.5, 0)
    PillDot.BackgroundColor3 = Color3.fromRGB(90, 75, 130)
    PillDot.ZIndex           = 4
    PillDot.Parent           = PillBg
    Instance.new("UICorner", PillDot).CornerRadius = UDim.new(1, 0)

    -- Hàm set trạng thái
    local active = false
    local function SetActive(val, skipCallback)
        active = val
        local col  = val and activeCol or inactiveCol
        local dotX = val and UDim2.new(0, 25, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        local bgC  = val and Color3.fromRGB(30, 22, 52) or Color3.fromRGB(40, 30, 60)

        TweenSvc:Create(PillDot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = dotX, BackgroundColor3 = col }):Play()
        TweenSvc:Create(PillBg,  TweenInfo.new(0.2), { BackgroundColor3 = bgC }):Play()
        TweenSvc:Create(Icon,    TweenInfo.new(0.2), { BackgroundColor3 = val and col or inactiveCol }):Play()
        TweenSvc:Create(btnStroke, TweenInfo.new(0.2), { Color = val and col or Color3.fromRGB(55, 40, 90) }):Play()

        if not skipCallback then onToggle(val) end
    end

    Btn.MouseButton1Click:Connect(function()
        SetActive(not active)
    end)

    -- Khởi tạo theo saved config
    if initState then
        SetActive(true, true) -- chỉ đổi màu, không trigger callback (callback sẽ gọi sau)
    end

    return SetActive
end

-- ── Tạo 2 nút toggle ─────────────────────────────────────────────────────────
local setMain = MakeToggle("Main", 74, Color3.fromRGB(80, 210, 130), Color3.fromRGB(50, 80, 55),
    Cfg.MainActive,
    function(val)
        Cfg.MainActive = val
        SaveCfg()
        if val then
            mainThread = task.spawn(MainLoop)
        else
            if mainThread then task.cancel(mainThread) mainThread = nil end
            SetStatus("⏹️  Main tắt", Color3.fromRGB(120, 110, 150))
        end
    end
)

local setAlt = MakeToggle("Alt", 132, Color3.fromRGB(220, 90, 90), Color3.fromRGB(80, 40, 40),
    Cfg.AltActive,
    function(val)
        Cfg.AltActive = val
        SaveCfg()
        if val then
            altThread = task.spawn(AltLoop)
        else
            if altThread then task.cancel(altThread) altThread = nil end
            SetStatus("⏹️  Alt tắt", Color3.fromRGB(120, 110, 150))
        end
    end
)

-- ── Nút nhỏ: Lock Camera ──────────────────────────────────────────────────────

local CamRow = Instance.new("TextButton")
CamRow.Size             = UDim2.new(1, -20, 0, 32)
CamRow.Position         = UDim2.new(0, 10, 0, 190)
CamRow.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
CamRow.Text             = ""
CamRow.ZIndex           = 2
CamRow.Parent           = Frame
Instance.new("UICorner", CamRow).CornerRadius = UDim.new(0, 9)

local camRowStroke = Instance.new("UIStroke")
camRowStroke.Color     = Color3.fromRGB(55, 40, 90)
camRowStroke.Thickness = 1
camRowStroke.Parent    = CamRow

local CamIcon = Instance.new("TextLabel")
CamIcon.Size               = UDim2.new(0, 24, 1, 0)
CamIcon.Position           = UDim2.new(0, 8, 0, 0)
CamIcon.BackgroundTransparency = 1
CamIcon.Text               = "🎥"
CamIcon.TextSize           = 14
CamIcon.Font               = Enum.Font.GothamBold
CamIcon.ZIndex             = 3
CamIcon.Parent             = CamRow

local CamLbl = Instance.new("TextLabel")
CamLbl.Size               = UDim2.new(1, -80, 1, 0)
CamLbl.Position           = UDim2.new(0, 36, 0, 0)
CamLbl.BackgroundTransparency = 1
CamLbl.Text               = "Lock Camera vào Board"
CamLbl.Font               = Enum.Font.Gotham
CamLbl.TextSize           = 11
CamLbl.TextColor3         = Color3.fromRGB(150, 140, 175)
CamLbl.TextXAlignment     = Enum.TextXAlignment.Left
CamLbl.ZIndex             = 3
CamLbl.Parent             = CamRow

-- Mini pill
local CamPillBg = Instance.new("Frame")
CamPillBg.Size             = UDim2.new(0, 36, 0, 18)
CamPillBg.AnchorPoint      = Vector2.new(1, 0.5)
CamPillBg.Position         = UDim2.new(1, -10, 0.5, 0)
CamPillBg.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
CamPillBg.ZIndex           = 3
CamPillBg.Parent           = CamRow
Instance.new("UICorner", CamPillBg).CornerRadius = UDim.new(1, 0)

local CamPillDot = Instance.new("Frame")
CamPillDot.Size             = UDim2.new(0, 12, 0, 12)
CamPillDot.AnchorPoint      = Vector2.new(0, 0.5)
CamPillDot.Position         = UDim2.new(0, 3, 0.5, 0)
CamPillDot.BackgroundColor3 = Color3.fromRGB(90, 75, 130)
CamPillDot.ZIndex           = 4
CamPillDot.Parent           = CamPillBg
Instance.new("UICorner", CamPillDot).CornerRadius = UDim.new(1, 0)

local CAM_COLOR = Color3.fromRGB(80, 160, 220)
CamRow.MouseButton1Click:Connect(function()
    camLockEnabled = not camLockEnabled
    local col = camLockEnabled and CAM_COLOR or Color3.fromRGB(90, 75, 130)
    local dotX = camLockEnabled and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    TweenSvc:Create(CamPillDot, TweenInfo.new(0.2), { Position = dotX, BackgroundColor3 = col }):Play()
    CamLbl.TextColor3 = camLockEnabled and Color3.fromRGB(200, 220, 240) or Color3.fromRGB(150, 140, 175)

    if not camLockEnabled then
        StopCameraLock()
    else
        -- Thử lock ngay nếu đang active
        local board = GetBoard()
        local cf    = board and GetBoardCFrame(board)
        if cf then StartCameraLock(cf) end
    end
end)

-- ── Khởi động lại nếu config đã lưu = true ───────────────────────────────────
if Cfg.MainActive then mainThread = task.spawn(MainLoop) end
if Cfg.AltActive  then altThread  = task.spawn(AltLoop)  end
