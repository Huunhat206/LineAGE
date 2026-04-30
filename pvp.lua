local Players    = game:GetService("Players")
local TweenSvc   = game:GetService("TweenService")
local HttpSvc    = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ── CONFIG SAVE/LOAD ──────────────────────────────────────────────────────────
local CFG_FILE = "NthucHub_PvP.json"
local Cfg = { MainActive = false, AltActive = false, TargetName = "" }

local function SaveCfg() pcall(function() writefile(CFG_FILE, HttpSvc:JSONEncode(Cfg)) end) end
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

-- ── ANTI-AFK ────────────────────────────────────────────────────────────────
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("💤 [Anti-AFK] Đã giả lập hoạt động để chống văng game!")
end)

-- ── CAMERA LOCK SYSTEM (ORIGINAL LOGIC) ──────────────────────────────────────
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

-- ── UTILITIES ────────────────────────────────────────────────────────────────
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
        if hum and hum.Health > 0 then hum.Health = 0 end
    end)
end

-- ── BOARD SYSTEM ─────────────────────────────────────────────────────────────
local currentBoard = nil
local blacklistedBoards = {}

local function GetBoardCFrame(board)
    if board:IsA("Model")    then return board:GetPivot() end
    if board:IsA("BasePart") then return board.CFrame     end
    return nil
end

local function GetClosestBoard()
    if currentBoard and currentBoard.Parent and not blacklistedBoards[currentBoard] then
        return currentBoard
    end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local closest = nil
    local minDist = math.huge
    local searchArea = workspace:FindFirstChild("Map") or workspace
    for _, obj in ipairs(searchArea:GetDescendants()) do
        if obj.Name == "PvP Mission Board" and (obj:IsA("Model") or obj:IsA("BasePart")) then
            if not blacklistedBoards[obj] then
                local cf = GetBoardCFrame(obj)
                if cf then
                    local dist = (root.Position - cf.Position).Magnitude
                    if dist < minDist then minDist = dist; closest = obj end
                end
            end
        end
    end
    currentBoard = closest
    return closest
end

local function PressBoard(board, rootPart)
    local cf = GetBoardCFrame(board)
    if not cf then return end
    if (rootPart.Position - cf.Position).Magnitude > 5 then
        rootPart.CFrame = cf * CFrame.new(0, 0, 0)
        rootPart.Velocity = Vector3.zero
        task.wait(0.3)
    end
    local prompt = board:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then return end
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt); task.wait(0.3)
    else
        local oldH, oldD = prompt.HoldDuration, prompt.MaxActivationDistance
        pcall(function() prompt.HoldDuration = 0; prompt.MaxActivationDistance = 32 end)
        task.wait(); pcall(function() prompt:InputHoldBegin() end); task.wait(); pcall(function() prompt:InputHoldEnd() end)
        pcall(function() prompt.HoldDuration = oldH; prompt.MaxActivationDistance = oldD end)
    end
end

-- ── CORE LOOP (OPTIMIZED) ────────────────────────────────────────────────────
local function ProcessQueue(mode)
    local color = (mode == "Main") and Color3.fromRGB(160, 140, 200) or Color3.fromRGB(200, 140, 140)
    while (mode == "Main" and Cfg.MainActive) or (mode == "Alt" and Cfg.AltActive) do
        SetStatus("⚙️ " .. mode .. ": chuẩn bị...", color)
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart", 10)
        local hum  = char:WaitForChild("Humanoid", 10)
        if not root or not hum or hum.Health <= 0 then task.wait(1) continue end
        local board = GetClosestBoard()
        if not board then SetStatus("❌ Không tìm thấy Board", Color3.fromRGB(220, 80, 80)); task.wait(3) continue end
        local boardCF = GetBoardCFrame(board)
        if board and boardCF then StartCameraLock(board, boardCF) end

        local joined = false
        local conn
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local holder = pg and pg:FindFirstChild("Notifications") and pg.Notifications:FindFirstChild("holder")
        if holder then
            conn = holder.ChildAdded:Connect(function(child)
                local text = child.Name
                local lbl = child:FindFirstChild("title")
                if lbl and lbl:IsA("TextLabel") then text = lbl.Text end
                if text:find("Joined PvP", 1, true) then joined = true end
                if text:find("already in an active mission", 1, true) then ResetCharacter() end
                if Cfg.TargetName ~= "" and text:match("Your opponent is <font.->(.-)</font>") then
                    local opp = text:match("Your opponent is <font.->(.-)</font>")
                    if string.lower(opp) ~= string.lower(Cfg.TargetName) then ResetCharacter() end
                end
            end)
        end

        local attempt = 0
        while (mode == "Main" and Cfg.MainActive or mode == "Alt" and Cfg.AltActive) and not joined do
            if not root or hum.Health <= 0 then break end
            attempt = attempt + 1
            if attempt > 8 then
                SetStatus("⚠️ Bảng lỗi, đổi bảng khác...", Color3.fromRGB(220, 150, 80))
                blacklistedBoards[board] = true; currentBoard = nil; break
            end
            SetStatus(string.format("🔄 %s: ấn E... (lần %d)", mode, attempt), color)
            PressBoard(board, root); task.wait(0.5)
        end
        if conn then conn:Disconnect() end
        StopCameraLock()
        if not joined then continue end
        SetStatus("✅ " .. mode .. ": đã vào hàng!", Color3.fromRGB(80, 210, 130))

        local left = false
        local stopConn = (holder and holder.ChildAdded:Connect(function(child)
            local text = child.Name
            local lbl = child:FindFirstChild("title")
            if lbl and lbl:IsA("TextLabel") then text = lbl.Text end
            if text:find("Left PvP", 1, true) then left = true end
        end))

        local elapsed = 0
        while (mode == "Main" and Cfg.MainActive or mode == "Alt" and Cfg.AltActive) and not left do
            if not root or hum.Health <= 0 then break end
            if (root.Position - boardCF.Position).Magnitude > 50 then left = true end
            task.wait(0.5); elapsed = elapsed + 0.5
            if elapsed > 120 then ResetCharacter(); break end
        end
        if stopConn then stopConn:Disconnect() end
        if mode == "Alt" and left then
            SetStatus("💀 Alt: thua → respawn...", Color3.fromRGB(220, 80, 80))
            task.wait(3); ResetCharacter()
        end
        task.wait(2)
    end
end

-- ── GUI SYSTEM (ORIGINAL LAYOUT) ──────────────────────────────────────────────
local guiParent = LocalPlayer.PlayerGui
pcall(function() if gethui then guiParent = gethui() end end)
pcall(function() if not guiParent or guiParent == LocalPlayer.PlayerGui then guiParent = game:GetService("CoreGui") end end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NthucHub_PvPGui"; ScreenGui.DisplayOrder = 999999; ScreenGui.IgnoreGuiInset = true; ScreenGui.ResetOnSpawn = false; ScreenGui.Parent = guiParent

local W, H = 270, 285
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, W, 0, H); Frame.Position = UDim2.new(0.5, -W/2, 0, 24); Frame.BackgroundColor3 = Color3.fromRGB(10, 8, 18); Frame.Active = true; Frame.Draggable = true; Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 16)
local outerStroke = Instance.new("UIStroke", Frame); outerStroke.Color = Color3.fromRGB(90, 60, 160); outerStroke.Thickness = 1.5

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44); Header.BackgroundColor3 = Color3.fromRGB(22, 14, 45); Header.Parent = Frame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -16, 1, 0); TitleLbl.Position = UDim2.new(0, 12, 0, 0); TitleLbl.BackgroundTransparency = 1; TitleLbl.Text = "⚔️  PvP Auto Queue"; TitleLbl.Font = Enum.Font.GothamBold; TitleLbl.TextSize = 14; TitleLbl.TextColor3 = Color3.fromRGB(210, 190, 255); TitleLbl.TextXAlignment = Enum.TextXAlignment.Left; TitleLbl.Parent = Header

local CloseGui = Instance.new("TextButton")
CloseGui.Size = UDim2.new(0, 26, 0, 26); CloseGui.AnchorPoint = Vector2.new(1, 0.5); CloseGui.Position = UDim2.new(1, -10, 0.5, 0); CloseGui.BackgroundColor3 = Color3.fromRGB(200, 50, 50); CloseGui.Text = "X"; CloseGui.Font = Enum.Font.GothamBold; CloseGui.TextSize = 13; CloseGui.TextColor3 = Color3.fromRGB(255, 255, 255); CloseGui.Parent = Header
Instance.new("UICorner", CloseGui).CornerRadius = UDim.new(0, 6)
CloseGui.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -16, 0, 22); StatusLabel.Position = UDim2.new(0, 8, 0, 48); StatusLabel.BackgroundTransparency = 1; StatusLabel.Text = "⏹️  Chờ bật..."; StatusLabel.Font = Enum.Font.Gotham; StatusLabel.TextSize = 11; StatusLabel.TextColor3 = Color3.fromRGB(130, 120, 160); StatusLabel.TextXAlignment = Enum.TextXAlignment.Center; StatusLabel.Parent = Frame

local function MakeToggle(label, yPos, activeCol, inactiveCol, initState, onToggle)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -20, 0, 50); Btn.Position = UDim2.new(0, 10, 0, yPos); Btn.BackgroundColor3 = Color3.fromRGB(16, 12, 28); Btn.Text = ""; Btn.Parent = Frame
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 12)
    local btnStroke = Instance.new("UIStroke", Btn); btnStroke.Color = Color3.fromRGB(55, 40, 90); btnStroke.Thickness = 1
    local Icon = Instance.new("Frame")
    Icon.Size = UDim2.new(0, 36, 0, 36); Icon.AnchorPoint = Vector2.new(0, 0.5); Icon.Position = UDim2.new(0, 8, 0.5, 0); Icon.BackgroundColor3 = inactiveCol; Icon.Parent = Btn
    Instance.new("UICorner", Icon).CornerRadius = UDim.new(0, 10)
    local IconTxt = Instance.new("TextLabel")
    IconTxt.Size = UDim2.new(1, 0, 1, 0); IconTxt.BackgroundTransparency = 1; IconTxt.Text = label == "Main" and "🏆" or "💀"; IconTxt.TextSize = 18; IconTxt.Font = Enum.Font.GothamBold; IconTxt.Parent = Icon
    local NameLbl = Instance.new("TextLabel")
    NameLbl.Size = UDim2.new(1, -110, 0, 18); NameLbl.Position = UDim2.new(0, 54, 0, 7); NameLbl.BackgroundTransparency = 1; NameLbl.Text = label == "Main" and "Main  (Bên Thắng)" or "Alt  (Bên Thua)"; NameLbl.Font = Enum.Font.GothamBold; NameLbl.TextSize = 13; NameLbl.TextColor3 = Color3.fromRGB(200, 185, 235); NameLbl.TextXAlignment = Enum.TextXAlignment.Left; NameLbl.Parent = Btn
    local PillBg = Instance.new("Frame")
    PillBg.Size = UDim2.new(0, 44, 0, 22); PillBg.AnchorPoint = Vector2.new(1, 0.5); PillBg.Position = UDim2.new(1, -10, 0.5, 0); PillBg.BackgroundColor3 = Color3.fromRGB(40, 30, 60); PillBg.Parent = Btn
    Instance.new("UICorner", PillBg).CornerRadius = UDim.new(1, 0)
    local PillDot = Instance.new("Frame")
    PillDot.Size = UDim2.new(0, 16, 0, 16); PillDot.AnchorPoint = Vector2.new(0, 0.5); PillDot.Position = UDim2.new(0, 3, 0.5, 0); PillDot.BackgroundColor3 = Color3.fromRGB(90, 75, 130); PillDot.Parent = PillBg
    Instance.new("UICorner", PillDot).CornerRadius = UDim.new(1, 0)
    local active = false
    local function SetActive(val)
        active = val
        local col = val and activeCol or inactiveCol
        local dotX = val and UDim2.new(0, 25, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        TweenSvc:Create(PillDot, TweenInfo.new(0.2), { Position = dotX, BackgroundColor3 = col }):Play()
        TweenSvc:Create(btnStroke, TweenInfo.new(0.2), { Color = val and col or Color3.fromRGB(55, 40, 90) }):Play()
        onToggle(val)
    end
    Btn.MouseButton1Click:Connect(function() SetActive(not active) end)
    if initState then SetActive(true) end
end

MakeToggle("Main", 74, Color3.fromRGB(80, 210, 130), Color3.fromRGB(50, 80, 55), Cfg.MainActive, function(val)
    Cfg.MainActive = val; SaveCfg()
    if val then task.spawn(ProcessQueue, "Main") else SetStatus("⏹️ Main tắt") end
end)

MakeToggle("Alt", 132, Color3.fromRGB(220, 90, 90), Color3.fromRGB(80, 40, 40), Cfg.AltActive, function(val)
    Cfg.AltActive = val; SaveCfg()
    if val then task.spawn(ProcessQueue, "Alt") else SetStatus("⏹️ Alt tắt") end
end)

-- ── TARGET GUI (FIXED) ─────────────────────────────────────────────────────────
local TargetRow = Instance.new("Frame")
TargetRow.Size = UDim2.new(1, -20, 0, 32); TargetRow.Position = UDim2.new(0, 10, 0, 190); TargetRow.BackgroundColor3 = Color3.fromRGB(16, 12, 28); TargetRow.Parent = Frame
Instance.new("UICorner", TargetRow).CornerRadius = UDim.new(0, 9)
local ts = Instance.new("UIStroke", TargetRow); ts.Color = Color3.fromRGB(55, 40, 90); ts.Thickness = 1

local TargetBtn = Instance.new("TextButton")
TargetBtn.Size = UDim2.new(1, -66, 1, 0); TargetBtn.Position = UDim2.new(0, 36, 0, 0); TargetBtn.BackgroundTransparency = 1; TargetBtn.Font = Enum.Font.GothamBold; TargetBtn.TextSize = 11; TargetBtn.TextColor3 = Color3.fromRGB(200, 190, 220); TargetBtn.TextXAlignment = Enum.TextXAlignment.Left; TargetBtn.Text = Cfg.TargetName == "" and "Mục tiêu: Ai cũng bắn" or "Mục tiêu: " .. Cfg.TargetName; TargetBtn.Parent = TargetRow

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 24, 0, 24); RefreshBtn.Position = UDim2.new(1, -28, 0.5, -12); RefreshBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 80); RefreshBtn.Text = "🔄"; RefreshBtn.TextColor3 = Color3.new(1,1,1); RefreshBtn.Parent = TargetRow
Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 6)

local TargetScroll = Instance.new("ScrollingFrame")
TargetScroll.Size = UDim2.new(1, 0, 0, 130); TargetScroll.Position = UDim2.new(0, 0, 1, 4); TargetScroll.BackgroundColor3 = Color3.fromRGB(30, 22, 45); TargetScroll.Visible = false; TargetScroll.ZIndex = 15; TargetScroll.Parent = TargetRow
Instance.new("UICorner", TargetScroll).CornerRadius = UDim.new(0, 6)
local TLayout = Instance.new("UIListLayout", TargetScroll); TLayout.Padding = UDim.new(0, 2)

local function UpdatePlayerList()
    for _, c in ipairs(TargetScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local function addP(name, txt)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 26); b.BackgroundColor3 = Color3.fromRGB(40, 30, 60); b.Text = "  " .. txt; b.TextColor3 = Color3.new(1,1,1); b.TextXAlignment = Enum.TextXAlignment.Left; b.ZIndex = 16; b.Parent = TargetScroll
        b.MouseButton1Click:Connect(function()
            Cfg.TargetName = name
            TargetBtn.Text = name == "" and "Mục tiêu: Ai cũng bắn" or "Mục tiêu: " .. name
            SaveCfg(); TargetScroll.Visible = false
        end)
    end
    addP("", "Ai cũng bắn (Bỏ qua tên)")
    local pList = Players:GetPlayers()
    for _, p in ipairs(pList) do if p ~= LocalPlayer then addP(p.Name, p.Name) end end
    TargetScroll.CanvasSize = UDim2.new(0, 0, 0, (#pList + 1) * 28)
end
RefreshBtn.MouseButton1Click:Connect(UpdatePlayerList)
TargetBtn.MouseButton1Click:Connect(function() UpdatePlayerList(); TargetScroll.Visible = not TargetScroll.Visible end)

-- ── CAM LOCK GUI ────────────────────────────────────────────────────────────
local CamRow = Instance.new("TextButton")
CamRow.Size = UDim2.new(1, -20, 0, 32); CamRow.Position = UDim2.new(0, 10, 0, 230); CamRow.BackgroundColor3 = Color3.fromRGB(16, 12, 28); CamRow.Text = ""; CamRow.Parent = Frame
Instance.new("UICorner", CamRow).CornerRadius = UDim.new(0, 9)
local cs = Instance.new("UIStroke", CamRow); cs.Color = Color3.fromRGB(55, 40, 90); cs.Thickness = 1

local CamLbl = Instance.new("TextLabel")
CamLbl.Size = UDim2.new(1, -80, 1, 0); CamLbl.Position = UDim2.new(0, 36, 0, 0); CamLbl.BackgroundTransparency = 1; CamLbl.Text = "Lock Camera vào Board"; CamLbl.Font = Enum.Font.Gotham; CamLbl.TextSize = 11; CamLbl.TextColor3 = Color3.fromRGB(150, 140, 175); CamLbl.TextXAlignment = Enum.TextXAlignment.Left; CamLbl.Parent = CamRow

local CamPillBg = Instance.new("Frame")
CamPillBg.Size = UDim2.new(0, 36, 0, 18); CamPillBg.AnchorPoint = Vector2.new(1, 0.5); CamPillBg.Position = UDim2.new(1, -10, 0.5, 0); CamPillBg.BackgroundColor3 = Color3.fromRGB(40, 30, 60); CamPillBg.Parent = CamRow
Instance.new("UICorner", CamPillBg).CornerRadius = UDim.new(1, 0)

local CamPillDot = Instance.new("Frame")
CamPillDot.Size = UDim2.new(0, 12, 0, 12); CamPillDot.AnchorPoint = Vector2.new(0, 0.5); CamPillDot.Position = UDim2.new(0, 3, 0.5, 0); CamPillDot.BackgroundColor3 = Color3.fromRGB(90, 75, 130); CamPillDot.Parent = CamPillBg
Instance.new("UICorner", CamPillDot).CornerRadius = UDim.new(1, 0)

CamRow.MouseButton1Click:Connect(function()
    camLockEnabled = not camLockEnabled
    local col = camLockEnabled and Color3.fromRGB(80, 160, 220) or Color3.fromRGB(90, 75, 130)
    local dotX = camLockEnabled and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    TweenSvc:Create(CamPillDot, TweenInfo.new(0.2), { Position = dotX, BackgroundColor3 = col }):Play()
    CamLbl.TextColor3 = camLockEnabled and Color3.fromRGB(200, 220, 240) or Color3.fromRGB(150, 140, 175)
    if not camLockEnabled then StopCameraLock() else 
        local board = GetClosestBoard()
        local cf    = board and GetBoardCFrame(board)
        if board and cf then StartCameraLock(board, cf) end
    end
end)

-- START ───────────────────────────────────────────────────────────────────────
if Cfg.MainActive then task.spawn(ProcessQueue, "Main") end
if Cfg.AltActive  then task.spawn(ProcessQueue, "Alt")  end
