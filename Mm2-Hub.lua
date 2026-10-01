-- // MM2 | ESP + AIMBOT + TP + NOCLIP + MENU

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ========== НАСТРОЙКИ ==========
local Settings = {
    ESPEnabled = true,
    ESPBoxSize = 1.0,
    ESPOutline = false,
    ESPLines = false,
    NoclipEnabled = false,
    ShowRoles = true,
    AimbotEnabled = false,
    AimbotSmooth = 0.3,
    AimbotFOV = 200,
    ShowFOV = false,
    WallCheck = true,
    AimbotTarget = "Murderer" -- Murderer / Sheriff / Innocent / All
}

-- ========== ОПРЕДЕЛЕНИЕ РОЛИ ==========
local function GetPlayerRole(player)
    local char = player.Character
    if not char then return "Unknown" end
    local backpack = player:FindFirstChild("Backpack")
    local hasKnife, hasGun = false, false
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") then hasKnife = true
            elseif n:find("gun") or n:find("revolver") or n:find("pistol") then hasGun = true end
        end
    end
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("knife") then hasKnife = true
                elseif n:find("gun") or n:find("revolver") or n:find("pistol") then hasGun = true end
            end
        end
    end
    if hasKnife then return "Murderer"
    elseif hasGun then return "Sheriff"
    else return "Innocent" end
end

local COLORS = {
    Murderer = Color3.fromRGB(255, 0, 0),
    Sheriff = Color3.fromRGB(0, 150, 255),
    Innocent = Color3.fromRGB(0, 255, 0)
}

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

-- ========== 3D ОБВОДКА ==========
local Highlights = {}
local function UpdateHighlight(player, state)
    if player == LocalPlayer then return end
    if state then
        local role = GetPlayerRole(player)
        local color = COLORS[role] or COLORS.Innocent
        if not Highlights[player] then
            local hl = Instance.new("Highlight")
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 0
            Highlights[player] = hl
        end
        Highlights[player].FillColor = color
        Highlights[player].OutlineColor = color
        if player.Character then Highlights[player].Parent = player.Character end
    else
        if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end
    end
end

-- ========== ESP ==========
local ESPObjects = {}
local ESPLines = {}

local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Filled = false
    box.Color = COLORS.Innocent
    box.Visible = false

    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Color = COLORS.Innocent
    line.Visible = false

    ESPObjects[player] = box
    ESPLines[player] = line
end

local function UpdateESP()
    if not Settings.ESPEnabled then
        for _, b in pairs(ESPObjects) do b.Visible = false end
        for _, l in pairs(ESPLines) do l.Visible = false end
        return
    end
    for player, box in pairs(ESPObjects) do
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local root = char.HumanoidRootPart
            local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen then
                local dist = (Camera.CFrame.Position - root.Position).Magnitude
                local h = math.clamp(1000 / dist, 20, 100) * Settings.ESPBoxSize
                local w = h / 2
                box.Size = Vector2.new(w, h)
                box.Position = Vector2.new(sp.X - w/2, sp.Y - h/2)

                local role = Settings.ShowRoles and GetPlayerRole(player) or "Innocent"
                local color = COLORS[role] or COLORS.Innocent
                box.Color = color
                box.Visible = true

                -- Линии
                if Settings.ESPLines then
                    local line = ESPLines[player]
                    line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    line.To = Vector2.new(sp.X, sp.Y + h/2)
                    line.Color = color
                    line.Visible = true
                else
                    ESPLines[player].Visible = false
                end
            else
                box.Visible = false
                ESPLines[player].Visible = false
            end
        else
            box.Visible = false
            ESPLines[player].Visible = false
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do CreateESP(p) end
Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(function(p)
    if ESPObjects[p] then ESPObjects[p]:Destroy(); ESPObjects[p] = nil end
    if ESPLines[p] then ESPLines[p]:Destroy(); ESPLines[p] = nil end
    if Highlights[p] then Highlights[p]:Destroy(); Highlights[p] = nil end
end)
RunService.RenderStepped:Connect(UpdateESP)

-- ========== AIMBOT ==========
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.Color = Color3.fromRGB(0, 255, 0)
fovCircle.Filled = false
fovCircle.Transparency = 0.5
fovCircle.Visible = false

local function IsVisible(targetPart)
    if not Settings.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local ray = Ray.new(origin, direction)
    local hit = workspace:FindPartOnRay(ray, LocalPlayer.Character, false, true)
    if hit then
        if hit:IsDescendantOf(targetPart.Parent) then return true
        else return false end
    end
    return true
end

local function GetClosestTarget()
    local closest = nil
    local shortestDist = Settings.AimbotFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if head and humanoid and humanoid.Health > 0 then
                local role = GetPlayerRole(player)
                local shouldTarget = (Settings.AimbotTarget == "All") or (Settings.AimbotTarget == role)
                if shouldTarget then
                    local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if dist < shortestDist then
                            if IsVisible(head) then
                                shortestDist = dist
                                closest = head
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if Settings.ShowFOV and Settings.AimbotEnabled then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Radius = Settings.AimbotFOV
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end
    if not Settings.AimbotEnabled then return end
    local target = GetClosestTarget()
    if target then
        local targetPos = target.Position
        local camPos = Camera.CFrame.Position
        local goalCFrame = CFrame.new(camPos, targetPos)
        Camera.CFrame = Camera.CFrame:Lerp(goalCFrame, Settings.AimbotSmooth)
    end
end)

-- ========== ТП К ПИСТОЛЕТУ ==========
local function TeleportToGun()
    local gun = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name:lower():find("gun") or obj.Name:lower():find("revolver")) then
            gun = obj
            break
        end
    end
    if gun and gun.Parent and gun.Parent:IsA("Model") then
        local myChar = LocalPlayer.Character
        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
            myChar.HumanoidRootPart.CFrame = gun.Parent:GetModelCFrame() + Vector3.new(0, 3, 0)
        end
    elseif gun and gun.Parent and gun.Parent:IsA("BasePart") then
        local myChar = LocalPlayer.Character
        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
            myChar.HumanoidRootPart.CFrame = gun.Parent.CFrame + Vector3.new(0, 3, 0)
        end
    end
end

-- ========== МЕНЮ ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2_Hub"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 280, 0, 420)
Main.Position = UDim2.new(0.5, -140, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local Gradient = Instance.new("UIGradient")
Gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
})
Gradient.Rotation = 90
Gradient.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(70, 50, 120)
Title.Text = "⚡ MM2 HUB"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -62, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.AutoButtonColor = false
MinBtn.Parent = Title
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

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
ContentFrame.Size = UDim2.new(1, -20, 0, 335)
ContentFrame.Position = UDim2.new(0, 10, 0, 85)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = Main

local function ClearContent()
    for _, c in ipairs(ContentFrame:GetChildren()) do c:Destroy() end
end

local function CreateToggle(text, y, state, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Position = UDim2.new(0, 0, 0, y)
    btn.BackgroundColor3 = state and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(160, 50, 50)
    btn.Text = text .. (state and ": ВКЛ" or ": ВЫКЛ")
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = ContentFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local s = state
    btn.MouseButton1Click:Connect(function()
        s = not s
        btn.Text = text .. (s and ": ВКЛ" or ": ВЫКЛ")
        btn.BackgroundColor3 = s and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(160, 50, 50)
        callback(s)
    end)
end

local function CreateSlider(text, y, min, max, default, callback)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.Position = UDim2.new(0, 0, 0, y)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default)
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = ContentFrame

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 8)
    slider.Position = UDim2.new(0, 0, 0, y + 20)
    slider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    slider.Parent = ContentFrame
    Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min)/(max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(120, 80, 220)
    fill.Parent = slider
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - slider.AbsolutePosition.X)/slider.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max-min)*rel)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        label.Text = text .. ": " .. tostring(v)
        callback(v)
    end
    slider.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i)
        end
    end)
    slider.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i) end
    end)
    slider.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

-- === Вкладка ВИЗУАЛ ===
local function ShowVisualTab()
    ClearContent()
    CreateToggle("ESP", 0, Settings.ESPEnabled, function(s) Settings.ESPEnabled = s end)
    CreateToggle("Роли (цвета)", 40, Settings.ShowRoles, function(s) Settings.ShowRoles = s end)
    CreateToggle("3D ОБВОДКА", 80, Settings.ESPOutline, function(s)
        Settings.ESPOutline = s
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then UpdateHighlight(p, s) end
        end
    end)
    CreateToggle("ЛИНИИ", 120, Settings.ESPLines, function(s) Settings.ESPLines = s end)
    CreateSlider("Размер боксов", 170, 1, 3, Settings.ESPBoxSize, function(v) Settings.ESPBoxSize = v end)
end

-- === Вкладка AIMBOT ===
local function ShowAimbotTab()
    ClearContent()
    CreateToggle("AIMBOT", 0, Settings.AimbotEnabled, function(s) Settings.AimbotEnabled = s end)
    
    -- Выбор роли
    local roleLabel = Instance.new("TextLabel")
    roleLabel.Size = UDim2.new(1, 0, 0, 16)
    roleLabel.Position = UDim2.new(0, 0, 0, 40)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Text = "Целиться по роли: " .. Settings.AimbotTarget
    roleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    roleLabel.Font = Enum.Font.Gotham
    roleLabel.TextSize = 12
    roleLabel.TextXAlignment = Enum.TextXAlignment.Left
    roleLabel.Parent = ContentFrame
    
    local roles = {"Murderer", "Sheriff", "Innocent", "All"}
    local roleIndex = 1
    for i, r in ipairs(roles) do
        if r == Settings.AimbotTarget then roleIndex = i end
    end
    
    local roleBtn = Instance.new("TextButton")
    roleBtn.Size = UDim2.new(1, 0, 0, 28)
    roleBtn.Position = UDim2.new(0, 0, 0, 60)
    roleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    roleBtn.Text = Settings.AimbotTarget
    roleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    roleBtn.Font = Enum.Font.GothamBold
    roleBtn.TextSize = 12
    roleBtn.AutoButtonColor = false
    roleBtn.Parent = ContentFrame
    Instance.new("UICorner", roleBtn).CornerRadius = UDim.new(0, 6)
    roleBtn.MouseButton1Click:Connect(function()
        roleIndex = roleIndex + 1
        if roleIndex > #roles then roleIndex = 1 end
        Settings.AimbotTarget = roles[roleIndex]
        roleBtn.Text = Settings.AimbotTarget
        roleLabel.Text = "Целиться по роли: " .. Settings.AimbotTarget
    end)
    
    CreateSlider("Плавность", 100, 1, 10, math.floor(Settings.AimbotSmooth * 10), function(v) Settings.AimbotSmooth = v / 10 end)
    CreateSlider("FOV (радиус)", 150, 50, 500, Settings.AimbotFOV, function(v) Settings.AimbotFOV = v end)
    CreateToggle("Показывать FOV", 200, Settings.ShowFOV, function(s) Settings.ShowFOV = s end)
    CreateToggle("Проверка стен", 240, Settings.WallCheck, function(s) Settings.WallCheck = s end)
end

-- === Вкладка ДВИЖЕНИЕ ===
local function ShowMoveTab()
    ClearContent()
    CreateToggle("NOCLIP", 0, Settings.NoclipEnabled, function(s) Settings.NoclipEnabled = s end)
end

-- === Вкладка ИГРОКИ ===
local SelectedPlayer = nil
local PlayerList = {}

local function UpdatePlayerList()
    PlayerList = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(PlayerList, p.Name) end
    end
end

local function ShowPlayersTab()
    ClearContent()
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 0, 130)
    scroll.Position = UDim2.new(0, 0, 0, 0)
    scroll.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
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
            for _, o in ipairs(scroll:GetChildren()) do
                if o:IsA("TextButton") then o.BackgroundColor3 = Color3.fromRGB(50, 50, 70) end
            end
            btn.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
        end)
    end

    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(0.48, 0, 0, 30)
    tpBtn.Position = UDim2.new(0, 0, 0, 140)
    tpBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
    tpBtn.Text = "ТП к игроку"
    tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpBtn.Font = Enum.Font.GothamBold
    tpBtn.TextSize = 11
    tpBtn.AutoButtonColor = false
    tpBtn.Parent = ContentFrame
    Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)

    local tpGunBtn = Instance.new("TextButton")
    tpGunBtn.Size = UDim2.new(0.48, 0, 0, 30)
    tpGunBtn.Position = UDim2.new(0.52, 0, 0, 140)
    tpGunBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    tpGunBtn.Text = "ТП к пистолету"
    tpGunBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpGunBtn.Font = Enum.Font.GothamBold
    tpGunBtn.TextSize = 11
    tpGunBtn.AutoButtonColor = false
    tpGunBtn.Parent = ContentFrame
    Instance.new("UICorner", tpGunBtn).CornerRadius = UDim.new(0, 6)

    tpBtn.MouseButton1Click:Connect(function()
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
    
    tpGunBtn.MouseButton1Click:Connect(TeleportToGun)
end

-- Кнопки вкладок
local VisualTabBtn, AimbotTabBtn, MoveTabBtn, PlayersTabBtn

local function SetTabColors(active)
    VisualTabBtn.BackgroundColor3 = active == "visual" and Color3.fromRGB(100, 60, 200) or Color3.fromRGB(45, 45, 65)
    AimbotTabBtn.BackgroundColor3 = active == "aimbot" and Color3.fromRGB(100, 60, 200) or Color3.fromRGB(45, 45, 65)
    MoveTabBtn.BackgroundColor3 = active == "move" and Color3.fromRGB(100, 60, 200) or Color3.fromRGB(45, 45, 65)
    PlayersTabBtn.BackgroundColor3 = active == "players" and Color3.fromRGB(100, 60, 200) or Color3.fromRGB(45, 45, 65)
end

local function CreateTabButton(text, x, width, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 1, 0)
    btn.Position = UDim2.new(0, x, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = TabFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

VisualTabBtn = CreateTabButton("ВИЗУАЛ", 0, 65, function()
    SetTabColors("visual"); ShowVisualTab()
end)
AimbotTabBtn = CreateTabButton("AIMBOT", 70, 65, function()
    SetTabColors("aimbot"); ShowAimbotTab()
end)
MoveTabBtn = CreateTabButton("ДВИЖ", 140, 65, function()
    SetTabColors("move"); ShowMoveTab()
end)
PlayersTabBtn = CreateTabButton("ИГРОКИ", 210, 65, function()
    SetTabColors("players"); ShowPlayersTab()
end)

-- Кнопка сворачивания
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

MinBtn.MouseButton1Click:Connect(function()
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

-- Запуск
ShowVisualTab()
SetTabColors("visual")