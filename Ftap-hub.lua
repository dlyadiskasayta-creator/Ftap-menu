-- // FTAP | HUB
-- // Fly, Noclip, Fling, Anti-Grab, Aura, TP

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ========== ANTI-GRAB (MODULE) ==========
local success, ApiFTAP = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Oxwoey/FTAP-Module/refs/heads/main/Module/ModuleFTAP"))()
end)

-- ========== НАСТРОЙКИ ==========
local Settings = {
    FlyEnabled = false,
    FlySpeed = 50,
    NoclipEnabled = false,
    AntiGrab = true,
    FlingEnabled = false,
    FlingStrength = 470,
    AuraEnabled = false,
    AuraRadius = 10,
    AuraForce = 50000
}

local HeldPlayers = {}

-- ========== FLY ==========
local flyActive = false
local bv, bg

local function StartFly()
    if flyActive then return end
    flyActive = true
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then flyActive = false; return end
    local hrp = char.HumanoidRootPart
    bv = Instance.new("BodyVelocity", hrp)
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.zero
    bg = Instance.new("BodyGyro", hrp)
    bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bg.P = 10000
    bg.D = 500
end

local function StopFly()
    flyActive = false
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    bv, bg = nil, nil
end

RunService.Heartbeat:Connect(function()
    if not flyActive or not bv or not bg then return end
    if not Settings.FlyEnabled then StopFly(); return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then StopFly(); return end
    local hrp = char.HumanoidRootPart
    local cam = workspace.CurrentCamera
    local moveDir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
    bv.Velocity = moveDir * Settings.FlySpeed
    bg.CFrame = cam.CFrame
end)

-- ========== NOCLIP ==========
RunService.Stepped:Connect(function()
    if not Settings.NoclipEnabled then return end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- ========== FLING ==========
Workspace.ChildAdded:Connect(function(model)
    if model.Name == "GrabParts" then
        local partInfo = model:FindFirstChild("GrabPart")
        if not partInfo then return end
        local weld = partInfo:FindFirstChild("WeldConstraint")
        if not weld or not weld.Part1 then return end
        local part = weld.Part1
        local velocity = Instance.new("BodyVelocity", part)
        model:GetPropertyChangedSignal("Parent"):Connect(function()
            if not model.Parent and Settings.FlingEnabled then
                velocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                velocity.Velocity = Workspace.CurrentCamera.CFrame.LookVector * Settings.FlingStrength
                game:GetService("Debris"):AddItem(velocity, 1)
            end
        end)
    end
end)

-- ========== AURA (тянет врагов к тебе) ==========
local function ApplyAuraToPlayer(player)
    if player == LocalPlayer then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local attach1 = Instance.new("Attachment", hrp)
    attach1.Name = "AuraAttachment"

    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
    local myHrp = myChar.HumanoidRootPart
    local attach0 = Instance.new("Attachment", myHrp)
    attach0.Name = "AuraAttachmentSelf"

    local align = Instance.new("AlignPosition")
    align.Attachment0 = attach1
    align.Attachment1 = attach0
    align.MaxForce = Settings.AuraForce
    align.Responsiveness = 50
    align.Parent = hrp

    local alignOrient = Instance.new("AlignOrientation")
    alignOrient.Attachment0 = attach1
    alignOrient.Attachment1 = attach0
    alignOrient.MaxTorque = 50000
    alignOrient.Responsiveness = 50
    alignOrient.Parent = hrp

    HeldPlayers[player] = {align = align, alignOrient = alignOrient, attach0 = attach0, attach1 = attach1}
end

local function RemoveAuraFromPlayer(player)
    if HeldPlayers[player] then
        for _, obj in pairs(HeldPlayers[player]) do
            if obj and obj.Destroy then obj:Destroy() end
        end
        HeldPlayers[player] = nil
    end
end

RunService.Heartbeat:Connect(function()
    if not Settings.AuraEnabled then
        for player, _ in pairs(HeldPlayers) do
            RemoveAuraFromPlayer(player)
        end
        return
    end

    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
    local myRoot = myChar.HumanoidRootPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = player.Character.HumanoidRootPart
            local distance = (targetRoot.Position - myRoot.Position).Magnitude

            if distance <= Settings.AuraRadius + 10 then
                if not HeldPlayers[player] then
                    ApplyAuraToPlayer(player)
                end
            else
                if HeldPlayers[player] then
                    RemoveAuraFromPlayer(player)
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(RemoveAuraFromPlayer)

-- ========== МЕНЮ ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FTAP_Hub"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

-- Главное меню (сразу видно, без подтверждения)
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 300, 0, 380)
Main.Position = UDim2.new(0.5, -150, 0.5, -190)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
})
MainGradient.Rotation = 90
MainGradient.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(70, 50, 120)
Title.Text = "⚡ HUB"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.Position = UDim2.new(1, -62, 0, 6)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = Title
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -30, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Title
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(1, -20, 0, 35)
TabFrame.Position = UDim2.new(0, 10, 0, 45)
TabFrame.BackgroundTransparency = 1
TabFrame.Parent = Main

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -20, 0, 295)
ContentFrame.Position = UDim2.new(0, 10, 0, 85)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = Main

local function ClearContent()
      for _, child in ipairs(ContentFrame:GetChildren()) do child:Destroy() end
end

local function CreateToggle(parent, text, y, state, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Position = UDim2.new(0, 0, 0, y)
    btn.BackgroundColor3 = state and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(160, 50, 50)
    btn.Text = text .. (state and ": ВКЛ" or ": ВЫКЛ")
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local s = state
    btn.MouseButton1Click:Connect(function()
        s = not s
        btn.Text = text .. (s and ": ВКЛ" or ": ВЫКЛ")
        btn.BackgroundColor3 = s and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(160, 50, 50)
        callback(s)
    end)
end

local function CreateSlider(parent, text, y, min, max, default, callback)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.Position = UDim2.new(0, 0, 0, y)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default)
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 8)
    slider.Position = UDim2.new(0, 0, 0, y + 20)
    slider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    slider.BorderSizePixel = 0
    slider.Parent = parent
    Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(120, 80, 220)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * rel)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        label.Text = text .. ": " .. tostring(value)
        callback(value)
    end
    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    slider.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function ShowMovementTab()
    ClearContent()
    CreateToggle(ContentFrame, "FLY", 0, Settings.FlyEnabled, function(s)
        Settings.FlyEnabled = s
        if s then StartFly() else StopFly() end
    end)
    CreateSlider(ContentFrame, "Скорость полёта", 45, 10, 200, Settings.FlySpeed, function(v) Settings.FlySpeed = v end)
    CreateToggle(ContentFrame, "NOCLIP", 95, Settings.NoclipEnabled, function(s) Settings.NoclipEnabled = s end)
    CreateToggle(ContentFrame, "FLING", 135, Settings.FlingEnabled, function(s) Settings.FlingEnabled = s end)
    CreateSlider(ContentFrame, "Сила броска", 180, 100, 1000, Settings.FlingStrength, function(v) Settings.FlingStrength = v end)
    CreateToggle(ContentFrame, "ANTI-GRAB", 230, Settings.AntiGrab, function(s)
        Settings.AntiGrab = s
        if ApiFTAP and ApiFTAP.AntiGrab then ApiFTAP.AntiGrab(s) end
    end)
end

local function ShowAuraTab()
    ClearContent()
    CreateToggle(ContentFrame, "AURA", 0, Settings.AuraEnabled, function(s) Settings.AuraEnabled = s end)
    CreateSlider(ContentFrame, "Радиус", 45, 5, 30, Settings.AuraRadius, function(v) Settings.AuraRadius = v end)
    CreateSlider(ContentFrame, "Сила притяжения", 95, 10000, 200000, Settings.AuraForce, function(v) Settings.AuraForce = v end)
end

local SelectedPlayer = nil
local PlayerList = {}

local function UpdatePlayerList()
    PlayerList = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(PlayerList, p.Name)
        end
    end
end

local function ShowPlayersTab()
    ClearContent()

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 0, 150)
    scroll.Position = UDim2.new(0, 0, 0, 0)
    scroll.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = ContentFrame
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.Padding = UDim.new(0, 2)

    UpdatePlayerList()
    for _, name in ipairs(PlayerList) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.AutoButtonColor = false
        btn.Parent = scroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            SelectedPlayer = name
            for _, other in ipairs(scroll:GetChildren()) do
                if other:IsA("TextButton") then
                    other.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
                end
            end
            btn.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
        end)
    end

    local tpToBtn = Instance.new("TextButton")
    tpToBtn.Size = UDim2.new(0.48, 0, 0, 30)
    tpToBtn.Position = UDim2.new(0, 0, 0, 160)
    tpToBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
    tpToBtn.Text = "ТП к нему"
    tpToBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpToBtn.Font = Enum.Font.GothamBold
    tpToBtn.TextSize = 11
    tpToBtn.AutoButtonColor = false
    tpToBtn.Parent = ContentFrame
    Instance.new("UICorner", tpToBtn).CornerRadius = UDim.new(0, 6)

    local tpToMeBtn = Instance.new("TextButton")
    tpToMeBtn.Size = UDim2.new(0.48, 0, 0, 30)
    tpToMeBtn.Position = UDim2.new(0.52, 0, 0, 160)
    tpToMeBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    tpToMeBtn.Text = "ТП ко мне"
    tpToMeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpToMeBtn.Font = Enum.Font.GothamBold
    tpToMeBtn.TextSize = 11
    tpToMeBtn.AutoButtonColor = false
    tpToMeBtn.Parent = ContentFrame
    Instance.new("UICorner", tpToMeBtn).CornerRadius = UDim.new(0, 6)

    tpToBtn.MouseButton1Click:Connect(function()
        if SelectedPlayer then
            local target = Players:FindFirstChild(SelectedPlayer)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    myChar.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                end
            end
        end
    end)

    tpToMeBtn.MouseButton1Click:Connect(function()
        if SelectedPlayer then
            local target = Players:FindFirstChild(SelectedPlayer)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    target.Character.HumanoidRootPart.CFrame = myChar.HumanoidRootPart.CFrame + Vector3.new(0, 3, 3)
                end
            end
        end
    end)
end

local MovementTabBtn = Instance.new("TextButton")
MovementTabBtn.Size = UDim2.new(0, 90, 1, 0)
MovementTabBtn.Position = UDim2.new(0, 0, 0, 0)
MovementTabBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
MovementTabBtn.Text = "ДВИЖЕНИЕ"
MovementTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MovementTabBtn.Font = Enum.Font.GothamBold
MovementTabBtn.TextSize = 11
MovementTabBtn.AutoButtonColor = false
MovementTabBtn.Parent = TabFrame
Instance.new("UICorner", MovementTabBtn).CornerRadius = UDim.new(0, 6)

local AuraTabBtn = Instance.new("TextButton")
AuraTabBtn.Size = UDim2.new(0, 90, 1, 0)
AuraTabBtn.Position = UDim2.new(0, 95, 0, 0)
AuraTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
AuraTabBtn.Text = "АУРА"
AuraTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
AuraTabBtn.Font = Enum.Font.GothamBold
AuraTabBtn.TextSize = 11
AuraTabBtn.AutoButtonColor = false
AuraTabBtn.Parent = TabFrame
Instance.new("UICorner", AuraTabBtn).CornerRadius = UDim.new(0, 6)

local PlayersTabBtn = Instance.new("TextButton")
PlayersTabBtn.Size = UDim2.new(0, 90, 1, 0)
PlayersTabBtn.Position = UDim2.new(0, 190, 0, 0)
PlayersTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
PlayersTabBtn.Text = "ИГРОКИ"
PlayersTabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
PlayersTabBtn.Font = Enum.Font.GothamBold
PlayersTabBtn.TextSize = 11
PlayersTabBtn.AutoButtonColor = false
PlayersTabBtn.Parent = TabFrame
Instance.new("UICorner", PlayersTabBtn).CornerRadius = UDim.new(0, 6)

MovementTabBtn.MouseButton1Click:Connect(function()
    MovementTabBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
    AuraTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    PlayersTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    ShowMovementTab()
end)

AuraTabBtn.MouseButton1Click:Connect(function()
    AuraTabBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
    MovementTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    PlayersTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    ShowAuraTab()
end)

PlayersTabBtn.MouseButton1Click:Connect(function()
    PlayersTabBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
    MovementTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    AuraTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    ShowPlayersTab()
end)

local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 120, 0, 30)
OpenBtn.Position = UDim2.new(0.5, -60, 0, 10)
OpenBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
OpenBtn.Text = "⚡ ОТКРЫТЬ"
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextSize = 12
OpenBtn.AutoButtonColor = false
OpenBtn.Visible = false
OpenBtn.Parent = ScreenGui
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 6)

MinimizeBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    OpenBtn.Visible = true
end)
OpenBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    OpenBtn.Visible = false
end)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = false
end)

ShowMovementTab()
