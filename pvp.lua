
local Players    = game:GetService("Players")
local TweenSvc   = game:GetService("TweenService")
local HttpSvc    = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ── ANTI-AFK NGẦM (CHỐNG KICK 20 PHÚT) ────────────────────────────────────────
-- Chạy tự động ngay khi execute script, tự giả lập click khi game báo rảnh rỗi
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("💤 [Anti-AFK] Đã giả lập hoạt động để chống văng game!")
end)

-- ── Camera lock system (SMART RAYCAST VIEW) ───────────────────────────────────
local camLockConn    = nil
local camLockEnabled = false
local fixedCamCF     = nil   

local function StartCameraLock(board, boardCF)
    if not camLockEnabled then return end
    if camLockConn then camLockConn:Disconnect() camLockConn = nil end

    local boardCenter = boardCF.Position + Vector3.new(0, 1.5, 0)
    local bestCamPos = boardCenter + Vector3.new(0, 15, 0) 

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {LocalPlayer.Character}
    if board then table.insert(ignoreList, board) end
    params.FilterDescendantsInstances = ignoreList

    local offsets = {
        boardCF.LookVector * 12 + Vector3.new(0, 10, 0),    
        -boardCF.LookVector * 12 + Vector3.new(0, 10, 0),   
        boardCF.RightVector * 12 + Vector3.new(0, 10, 0),   
        -boardCF.RightVector * 12 + Vector3.new(0, 10, 0),  
        Vector3.new(10, 12, 10),                            
        Vector3.new(-10, 12, 10),                           
        Vector3.new(10, 12, -10),                           
        Vector3.new(-10, 12, -10)                           
    }

    for _, offset in ipairs(offsets) do
        local testPos = boardCenter + offset
        local ray = workspace:Raycast(boardCenter, testPos - boardCenter, params)
        if not ray then
            bestCamPos = testPos
            break 
        end
    end

    fixedCamCF = CFrame.lookAt(bestCamPos, boardCenter)
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
local Cfg = { MainActive = false, AltActive = false, TargetName = "" }

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
                Cfg.TargetName = d.TargetName or ""
            end
        end
    end)
end
LoadCfg()

-- ── Hệ thống Reset & Thông báo (Săn Mục Tiêu / Né Lỗi) ───────────────────────
local StatusLabel 
local function SetStatus(text, color)
    if StatusLabel then
        StatusLabel.Text      = text
        StatusLabel.TextColor3 = color or Color3.fromRGB(180, 165, 220)
    end
end

local function ResetCharacter()
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            hum.Health = 0
        end
    end)
end

local globalNotifConn = nil

local function HandleNotification(child)
    if not Cfg.MainActive and not Cfg.AltActive then return end

    task.delay(0.15, function()
        local text = child.Name
        local lbl = child:FindFirstChild("title")
        if lbl and lbl:IsA("TextLabel") then text = lbl.Text end

        if text:find("already in an active mission", 1, true) then
            SetStatus("⚠️ Lỗi kẹt Queue -> Reset!", Color3.fromRGB(255, 80, 80))
            ResetCharacter()
            return
        end

        local oppMatch = text:match("Your opponent is <font.->(.-)</font>")
        if oppMatch then
            if Cfg.TargetName ~= "" and string.lower(oppMatch) ~= string.lower(Cfg.TargetName) then
                SetStatus("⚠️ Gặp người lạ: " .. oppMatch .. " -> Né!", Color3.fromRGB(255, 80, 80))
                ResetCharacter()
            else
                SetStatus("⚔️ Đụng độ: " .. oppMatch, Color3.fromRGB(100, 255, 100))
            end
        end
    end)
end

task.spawn(function()
    while true do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local notifGui = pg and pg:FindFirstChild("Notifications")
        local holder = notifGui and notifGui:FindFirstChild("holder")

        if holder then
            if not globalNotifConn then
                globalNotifConn = holder.ChildAdded:Connect(HandleNotification)
            end
        else
            if globalNotifConn then globalNotifConn:Disconnect(); globalNotifConn = nil end
        end
        task.wait(2)
    end
end)

-- ── Hệ thống tìm & Blacklist Bảng ─────────────────────────────────────────────
local currentBoard = nil
local blacklistedBoards = {}

local function GetClosestBoard()
    if currentBoard and currentBoard.Parent and not blacklistedBoards[currentBoard] then
        return currentBoard
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local closest = nil
    local minDist = math.huge
    local searchArea = workspace:FindFirstChild("Map") or workspace

    for _, obj in ipairs(searchArea:GetDescendants()) do
        if obj.Name == "PvP Mission Board" and (obj:IsA("Model") or obj:IsA("BasePart")) then
            if not blacklistedBoards[obj] then
                local cf = obj:IsA("Model") and obj:GetPivot() or obj.CFrame
                local dist = (root.Position - cf.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = obj
                end
            end
        end
    end

    if not closest then
        blacklistedBoards = {}
        return nil
    end
    currentBoard = closest
    return closest
end

local function GetBoardCFrame(board)
    if board:IsA("Model")    then return board:GetPivot() end
    if board:IsA("BasePart") then return board.CFrame     end
    return nil
end

-- ── Teleport + kích ProximityPrompt ───────────────────────────────────────────
local function PressBoard(board, rootPart)
    local cf = GetBoardCFrame(board)
    if not cf then return end

    if (rootPart.Position - cf.Position).Magnitude > 5 then
        rootPart.CFrame = cf * CFrame.new(0, 0, 0)
        rootPart.Velocity = Vector3.new(0, 0, 0)
        task.wait(0.3)
    end

    local prompt = board:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then return end

    if fireproximityprompt then
        pcall(fireproximityprompt, prompt)
        task.wait(0.3)
        return
    end

    local oldHold = prompt.HoldDuration
    local oldDist = prompt.MaxActivationDistance

    pcall(function()
        prompt.HoldDuration          = 0
        prompt.MaxActivationDistance = 32
    end)

    task.wait()
    pcall(function() prompt:InputHoldBegin() end)
    task.wait()
    pcall(function() prompt:InputHoldEnd()   end)

    pcall(function()
        prompt.HoldDuration          = oldHold
        prompt.MaxActivationDistance = oldDist
    end)
    task.wait(0.3)
end

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
        if not root or not hum or hum.Health <= 0 then task.wait(1) continue end

        local board = GetClosestBoard()
        if not board then
            SetStatus("❌ Không tìm thấy Board", Color3.fromRGB(220, 80, 80))
            task.wait(3)
            continue
        end
        local boardCF = GetBoardCFrame(board)

        if board and boardCF then StartCameraLock(board, boardCF) end

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
            if not root or not root.Parent or hum.Health <= 0 then break end 
            attempt = attempt + 1
            if attempt > 8 then
                SetStatus("⚠️ Bảng bị lỗi, đổi bảng khác...", Color3.fromRGB(220, 150, 80))
                blacklistedBoards[board] = true
                currentBoard = nil
                task.wait(1)
                break
            end

            SetStatus(string.format("🔄 Main: ấn E... (lần %d)", attempt), Color3.fromRGB(180, 160, 220))
            PressBoard(board, root)
            
            local w = 0
            while w < 3 and not joined do 
                if hum.Health <= 0 then break end
                local d = (root.Position - boardCF.Position).Magnitude
                if d > 10 and d < 50 then
                    root.CFrame = boardCF * CFrame.new(0, 0, 0)
                    root.Velocity = Vector3.zero
                end
                task.wait(0.1) 
                w = w + 0.1 
            end
        end
        if joinConn then joinConn:Disconnect() end

        if hum.Health <= 0 or (not joined and attempt > 8) then
            continue
        end

        if not Cfg.MainActive then StopCameraLock() break end

        StopCameraLock()
        SetStatus("✅ Main: đã vào hàng!", Color3.fromRGB(80, 210, 130))

        local left      = false
        local stopWatch = WatchLeft(function() left = true end)

        local queueElapsed = 0
        while Cfg.MainActive and not left do
            if not root or not root.Parent or hum.Health <= 0 then break end
            local dist = (root.Position - boardCF.Position).Magnitude
            if dist > 50 then
                left = true 
            elseif dist > 10 then
                root.CFrame = boardCF * CFrame.new(0, 0, 0)
                root.Velocity = Vector3.zero
            end
            task.wait(0.5)
            queueElapsed = queueElapsed + 0.5
            
            if queueElapsed > 120 then
                SetStatus("⚠️ Treo Queue quá lâu -> Reset để thử lại!", Color3.fromRGB(255, 80, 80))
                ResetCharacter()
                break
            end
        end

        stopWatch()
        if hum.Health > 0 then
            SetStatus("↩️ Main: chờ rồi lặp lại...", Color3.fromRGB(160, 140, 200))
            task.wait(2)
        end
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
        if not root or not hum or hum.Health <= 0 then task.wait(1) continue end

        local board = GetClosestBoard()
        if not board then
            SetStatus("❌ Không tìm thấy Board", Color3.fromRGB(220, 80, 80))
            task.wait(3)
            continue
        end
        local boardCF = GetBoardCFrame(board)

        if board and boardCF then StartCameraLock(board, boardCF) end

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
            if not root or not root.Parent or hum.Health <= 0 then break end
            attempt2 = attempt2 + 1
            if attempt2 > 8 then
                SetStatus("⚠️ Bảng bị lỗi, đổi bảng khác...", Color3.fromRGB(220, 150, 80))
                blacklistedBoards[board] = true
                currentBoard = nil
                task.wait(1)
                break
            end

            SetStatus(string.format("🔄 Alt: ấn E... (lần %d)", attempt2), Color3.fromRGB(220, 160, 140))
            PressBoard(board, root)
            
            local w = 0
            while w < 3 and not joined do 
                if hum.Health <= 0 then break end
                local d = (root.Position - boardCF.Position).Magnitude
                if d > 10 and d < 50 then
                    root.CFrame = boardCF * CFrame.new(0, 0, 0)
                    root.Velocity = Vector3.zero
                end
                task.wait(0.1) 
                w = w + 0.1 
            end
        end
        if joinConn2 then joinConn2:Disconnect() end

        if hum.Health <= 0 or (not joined and attempt2 > 8) then
            continue
        end

        if not Cfg.AltActive then StopCameraLock() break end

        StopCameraLock()
        SetStatus("✅ Alt: đã vào hàng!", Color3.fromRGB(220, 120, 80))

        local teleported = false
        local elapsed    = 0
        
        while Cfg.AltActive and not teleported and elapsed < 120 do
            if not root or not root.Parent or hum.Health <= 0 then break end
            local dist = (root.Position - boardCF.Position).Magnitude
            if dist > 50 then
                teleported = true 
            elseif dist > 10 then
                root.CFrame = boardCF * CFrame.new(0, 0, 0)
                root.Velocity = Vector3.zero
            end
            task.wait(0.5)
            elapsed = elapsed + 0.5
        end

        if teleported and Cfg.AltActive and hum.Health > 0 then
            SetStatus("💀 Alt: thua → respawn...", Color3.fromRGB(220, 80, 80))
            task.wait(3) 
            ResetCharacter()
            LocalPlayer.CharacterAdded:Wait()
            task.wait(2)
        elseif elapsed >= 120 then
            SetStatus("⚠️ Treo Queue quá lâu -> Reset để thử lại!", Color3.fromRGB(255, 80, 80))
            ResetCharacter()
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

local W, H = 270, 285
local Frame = Instance.new("Frame")
Frame.Size             = UDim2.new(0, W, 0, H)
Frame.Position         = UDim2.new(0.5, -W/2, 0, 24)
Frame.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
Frame.Active           = true
Frame.Draggable        = true
Frame.ClipsDescendants = false 
Frame.Parent           = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 16)

local bgGrad = Instance.new("UIGradient")
bgGrad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(14, 10, 28)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(8,  6, 16)),
})
bgGrad.Rotation = 120
bgGrad.Parent   = Frame

local outerStroke = Instance.new("UIStroke")
outerStroke.Color     = Color3.fromRGB(90, 60, 160)
outerStroke.Thickness = 1.5
outerStroke.Parent    = Frame

local Header = Instance.new("Frame")
Header.Size             = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Color3.fromRGB(22, 14, 45)
Header.ZIndex           = 2
Header.Parent           = Frame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

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

local CloseGui = Instance.new("TextButton")
CloseGui.Size             = UDim2.new(0, 26, 0, 26)
CloseGui.AnchorPoint      = Vector2.new(1, 0.5)
CloseGui.Position         = UDim2.new(1, -10, 0.5, 0)
CloseGui.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseGui.Text             = "X"
CloseGui.Font             = Enum.Font.GothamBold
CloseGui.TextSize         = 13
CloseGui.TextColor3       = Color3.fromRGB(255, 255, 255)
CloseGui.ZIndex           = 5
CloseGui.Parent           = Header
Instance.new("UICorner", CloseGui).CornerRadius = UDim.new(0, 6)
CloseGui.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

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

    Btn.MouseButton1Click:Connect(function() SetActive(not active) end)
    if initState then SetActive(true, true) end
    return SetActive
end

local setMain = MakeToggle("Main", 74, Color3.fromRGB(80, 210, 130), Color3.fromRGB(50, 80, 55),
    Cfg.MainActive,
    function(val)
        Cfg.MainActive = val; SaveCfg()
        if val then mainThread = task.spawn(MainLoop)
        else
            if mainThread then task.cancel(mainThread) mainThread = nil end
            SetStatus("⏹️  Main tắt", Color3.fromRGB(120, 110, 150))
        end
    end
)

local setAlt = MakeToggle("Alt", 132, Color3.fromRGB(220, 90, 90), Color3.fromRGB(80, 40, 40),
    Cfg.AltActive,
    function(val)
        Cfg.AltActive = val; SaveCfg()
        if val then altThread = task.spawn(AltLoop)
        else
            if altThread then task.cancel(altThread) altThread = nil end
            SetStatus("⏹️  Alt tắt", Color3.fromRGB(120, 110, 150))
        end
    end
)

-- ── Dropdown Target Name & Refresh ────────────────────────────────────────────
local TargetRow = Instance.new("Frame")
TargetRow.Size             = UDim2.new(1, -20, 0, 32)
TargetRow.Position         = UDim2.new(0, 10, 0, 190)
TargetRow.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
TargetRow.ZIndex           = 2
TargetRow.Parent           = Frame
Instance.new("UICorner", TargetRow).CornerRadius = UDim.new(0, 9)

local targetStroke = Instance.new("UIStroke")
targetStroke.Color     = Color3.fromRGB(55, 40, 90)
targetStroke.Thickness = 1
targetStroke.Parent    = TargetRow

local TargetIcon = Instance.new("TextLabel")
TargetIcon.Size               = UDim2.new(0, 24, 1, 0)
TargetIcon.Position           = UDim2.new(0, 8, 0, 0)
TargetIcon.BackgroundTransparency = 1
TargetIcon.Text               = "🎯"
TargetIcon.TextSize           = 14
TargetIcon.Font               = Enum.Font.GothamBold
TargetIcon.ZIndex             = 3
TargetIcon.Parent             = TargetRow

local TargetBtn = Instance.new("TextButton")
TargetBtn.Size = UDim2.new(1, -66, 1, 0)
TargetBtn.Position = UDim2.new(0, 36, 0, 0)
TargetBtn.BackgroundTransparency = 1
TargetBtn.Font = Enum.Font.GothamBold
TargetBtn.TextSize = 11
TargetBtn.TextColor3 = Color3.fromRGB(200, 190, 220)
TargetBtn.TextXAlignment = Enum.TextXAlignment.Left
TargetBtn.Text = Cfg.TargetName == "" and "Mục tiêu: Ai cũng bắn" or "Mục tiêu: " .. Cfg.TargetName
TargetBtn.ZIndex = 3
TargetBtn.Parent = TargetRow

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 24, 0, 24)
RefreshBtn.Position = UDim2.new(1, -28, 0.5, -12)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
RefreshBtn.Text = "🔄"
RefreshBtn.Font = Enum.Font.Gotham
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshBtn.ZIndex = 4
RefreshBtn.Parent = TargetRow
Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 6)

local TargetScroll = Instance.new("ScrollingFrame")
TargetScroll.Size = UDim2.new(1, 0, 0, 130)
TargetScroll.Position = UDim2.new(0, 0, 1, 4)
TargetScroll.BackgroundColor3 = Color3.fromRGB(30, 22, 45)
TargetScroll.BorderSizePixel = 0
TargetScroll.Visible = false
TargetScroll.ZIndex = 10
TargetScroll.ScrollBarThickness = 4
TargetScroll.Parent = TargetRow
Instance.new("UICorner", TargetScroll).CornerRadius = UDim.new(0, 6)
local TLayout = Instance.new("UIListLayout")
TLayout.Parent = TargetScroll
TLayout.Padding = UDim.new(0, 2)

local function UpdatePlayerList()
    for _, c in ipairs(TargetScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    
    local function addP(name, txt)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 26)
        b.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
        b.BorderSizePixel = 0
        b.Text = "  " .. txt
        b.Font = Enum.Font.Gotham
        b.TextSize = 11
        b.TextColor3 = Color3.fromRGB(220, 220, 220)
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.ZIndex = 11
        b.Parent = TargetScroll
        b.MouseButton1Click:Connect(function()
            Cfg.TargetName = name
            TargetBtn.Text = name == "" and "Mục tiêu: Ai cũng bắn" or "Mục tiêu: " .. name
            SaveCfg()
            TargetScroll.Visible = false
        end)
    end
    
    addP("", "Ai cũng bắn (Bỏ qua tên)")
    local count = 1
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            addP(p.Name, p.Name)
            count = count + 1
        end
    end
    TargetScroll.CanvasSize = UDim2.new(0, 0, 0, count * 28)
end

RefreshBtn.MouseButton1Click:Connect(UpdatePlayerList)
TargetBtn.MouseButton1Click:Connect(function()
    UpdatePlayerList()
    TargetScroll.Visible = not TargetScroll.Visible
end)

-- ── Nút nhỏ: Lock Camera ──────────────────────────────────────────────────────
local CamRow = Instance.new("TextButton")
CamRow.Size             = UDim2.new(1, -20, 0, 32)
CamRow.Position         = UDim2.new(0, 10, 0, 230)
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
        local board = GetClosestBoard()
        local cf    = board and GetBoardCFrame(board)
        if board and cf then StartCameraLock(board, cf) end
    end
end)

if Cfg.MainActive then mainThread = task.spawn(MainLoop) end
if Cfg.AltActive  then altThread  = task.spawn(AltLoop)  end
