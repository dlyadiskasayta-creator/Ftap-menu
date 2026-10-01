-- MM2 Pentest Script v3 - Delta Executor (Android)
-- Fixed: auto language update, top-center show button, auto-refresh ESP roles

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ==================== LANGUAGE ====================
local Lang = "RU"

local Strings = {
    EN = {
        title = "PENTEST", show = "SHOW",
        tab_visual = "VISUAL", tab_aimbot = "AIMBOT", tab_movement = "MOVEMENT",
        tab_players = "PLAYERS", tab_settings = "SETTINGS",
        esp = "ESP", tracers = "Tracers", highlight = "3D Highlight",
        names = "Names", roles = "Roles",
        aimbot = "Aimbot", aimbot_btn = "AIM BUTTON", target = "Target",
        smoothness = "Smoothness", fov = "FOV", wallcheck = "Wall Check",
        show_fov = "Show FOV Circle",
        noclip = "Noclip", tp_gun = "TP to Gun", tp_player = "TP to Player",
        bring_player = "Bring Player", keybind = "Keybind",
        language = "Language", murderer = "Murderer", sheriff = "Sheriff",
        innocent = "Innocent", all = "All",
        click_cycle = "tap to cycle", press_key = "Press key...",
        on = "ON", off = "OFF"
    },
    RU = {
        title = "ПЕНТЕСТ", show = "ПОКАЗ",
        tab_visual = "ВИЗУАЛ", tab_aimbot = "АИМ", tab_movement = "ДВИЖЕНИЕ",
        tab_players = "ИГРОКИ", tab_settings = "НАСТРОЙКИ",
        esp = "ЕСП", tracers = "Линии", highlight = "3D Обводка",
        names = "Ники", roles = "Роли",
        aimbot = "Аимбот", aimbot_btn = "КНОПКА АИМА", target = "Цель",
        smoothness = "Плавность", fov = "ФОВ", wallcheck = "Проверка стен",
        show_fov = "Показ ФОВ",
        noclip = "Ноклип", tp_gun = "ТП к пистолету", tp_player = "ТП к игроку",
        bring_player = "Игрока ко мне", keybind = "Кнопка",
        language = "Язык", murderer = "Маньяк", sheriff = "Шериф",
        innocent = "Мирный", all = "Все",
        click_cycle = "тап для смены", press_key = "Нажми клавишу...",
        on = "ВКЛ", off = "ВЫКЛ"
    }
}

local function T(k) return (Strings[Lang] and Strings[Lang][k]) or k end

local function RoleName(role)
    if role == "Murderer" then return T("murderer") end
    if role == "Sheriff" then return T("sheriff") end
    if role == "Innocent" then return T("innocent") end
    if role == "All" then return T("all") end
    return role
end

-- ==================== CONFIG ====================
local Config = {
    ESPEnabled = true,
    TracersEnabled = true,
    HighlightEnabled = true,
    NamesEnabled = true,
    RolesEnabled = true,
    AimbotEnabled = false,
    AimbotRole = "Murderer",
    AimbotSmoothness = 0.3,
    AimbotFOV = 150,
    AimbotWallCheck = true,
    ShowFOV = true,
    NoclipEnabled = false,
    NoclipBind = Enum.KeyCode.N,
    AimbotBind = Enum.KeyCode.L,
    MobileAimbotBtn = true
}

-- ==================== STATE ====================
local ESPObjects = {}
local TracerLines = {}
local FOVCircle = nil
local ActiveTarget = nil
local UIRefs = {}
local MobileAimbotBtn = nil
local LastRoleCache = {}

-- ==================== ROLE DETECTION ====================
local function GetPlayerRole(player)
    if not player or not player.Parent then return "Innocent" end
    local char = player.Character
    if not char then return "Innocent" end
    
    local function checkTool(name)
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool.Name == name then return true end
            end
        end
        for _, tool in ipairs(char:GetChildren()) do
            if tool.Name == name then return true end
        end
        return false
    end
    
    if checkTool("Knife") or checkTool("KnifeStand") then return "Murderer" end
    if checkTool("Gun") or checkTool("Revolver") or checkTool("Colt") then return "Sheriff" end
    return "Innocent"
end

local function GetRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 0, 0) end
    if role == "Sheriff" then return Color3.fromRGB(0, 100, 255) end
    return Color3.fromRGB(0, 255, 0)
end

-- ==================== ESP ====================
local function CleanupPlayer(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            if obj and obj.Parent then obj:Destroy() end
        end
        ESPObjects[player] = nil
    end
end

local function ApplyESP(player)
    if player == LocalPlayer then return end
    if not player.Character then return end
    
    local char = player.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    
    if not humanoid or not head then return end
    if humanoid.Health <= 0 then CleanupPlayer(player) return end
    
    local role = GetPlayerRole(player)
    local color = GetRoleColor(role)
    local cacheKey = role .. "|" .. tostring(Config.HighlightEnabled) .. "|" .. tostring(Config.NamesEnabled) .. "|" .. tostring(Config.RolesEnabled)
    
    -- Skip rebuild if nothing changed
    if ESPObjects[player] and ESPObjects[player]._cacheKey == cacheKey then
        return
    end
    
    CleanupPlayer(player)
    ESPObjects[player] = { _cacheKey = cacheKey }
    
    if Config.HighlightEnabled then
        local highlight = Instance.new("Highlight")
        highlight.Name = "PentestHL"
        highlight.Adornee = char
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = 0.7
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = char
        table.insert(ESPObjects[player], highlight)
    end
    
    if Config.NamesEnabled or Config.RolesEnabled then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "PentestBB"
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 200, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head
        
        local text = ""
        if Config.NamesEnabled then text = player.DisplayName end
        if Config.RolesEnabled then
            if text ~= "" then text = text .. " " end
            text = text .. "[" .. RoleName(role) .. "]"
        end
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = color
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextStrokeTransparency = 0.3
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.Text = text
        label.Parent = billboard
        table.insert(ESPObjects[player], billboard)
    end
end

local function UpdateAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            pcall(ApplyESP, player)
        end
    end
end

local function ForceRefreshESP()
    for player in pairs(ESPObjects) do
        CleanupPlayer(player)
    end
    LastRoleCache = {}
    UpdateAllESP()
end

-- ==================== TRACERS ====================
local function UpdateTracers()
    if not Config.TracersEnabled or not Config.ESPEnabled then
        for _, line in pairs(TracerLines) do
            if line then line.Visible = false end
        end
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            
            if hrp and humanoid and humanoid.Health > 0 then
                if not TracerLines[player] then
                    local line = Drawing.new("Line")
                    line.Thickness = 1.5
                    line.Transparency = 1
                    line.Visible = false
                    TracerLines[player] = line
                end
                
                local role = GetPlayerRole(player)
                local color = GetRoleColor(role)
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                
                if onScreen then
                    TracerLines[player].From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    TracerLines[player].To = Vector2.new(screenPos.X, screenPos.Y)
                    TracerLines[player].Color = color
                    TracerLines[player].Visible = true
                else
                    TracerLines[player].Visible = false
                end
            else
                if TracerLines[player] then TracerLines[player].Visible = false end
            end
        end
    end
end

-- ==================== FOV CIRCLE ====================
local function CreateFOVCircle()
    if FOVCircle then FOVCircle:Remove() end
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 2
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.Transparency = 0.6
    FOVCircle.NumSides = 64
    FOVCircle.Radius = Config.AimbotFOV
    FOVCircle.Filled = false
    FOVCircle.Visible = false
end

-- ==================== AIMBOT ====================
local function HasLineOfSight(targetChar)
    if not Config.AimbotWallCheck then return true end
    local head = targetChar:FindFirstChild("Head")
    if not head then return false end
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    local origin = Camera.CFrame.Position
    local direction = head.Position - origin
    local result = workspace:Raycast(origin, direction, params)
    
    if result == nil then return true end
    return result.Instance:IsDescendantOf(targetChar)
end

local function IsValidTarget(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local head = player.Character:FindFirstChild("Head")
    if not humanoid or not head then return false end
    if humanoid.Health <= 0 then return false end
    
    local role = GetPlayerRole(player)
    if Config.AimbotRole ~= "All" and Config.AimbotRole ~= role then return false end
    
    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then return false end
    
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    if dist > Config.AimbotFOV then return false end
    
    if not HasLineOfSight(player.Character) then return false end
    return true
end

local function GetClosestTarget()
    local closest, closestDist = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if IsValidTarget(player) then
            local head = player.Character:FindFirstChild("Head")
            local screenPos = Camera:WorldToViewportPoint(head.Position)
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = player
            end
        end
    end
    return closest
end

local function UpdateAimbot()
    if not Config.AimbotEnabled then
        ActiveTarget = nil
        return
    end
    local target = GetClosestTarget()
    ActiveTarget = target
    if target and target.Character then
        local head = target.Character:FindFirstChild("Head")
        if head then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, head.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.AimbotSmoothness)
        end
    end
end

-- ==================== TELEPORT ====================
local function TeleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if myHRP and targetHRP then
        myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 2)
    end
end

local function TeleportToGun()
    local gun = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name == "Revolver" or obj.Name == "Colt") then
            gun = obj break
        end
    end
    if gun and gun:FindFirstChild("Handle") then
        local myChar = LocalPlayer.Character
        if myChar then
            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
            if myHRP then
                myHRP.CFrame = gun.Handle.CFrame * CFrame.new(0, 2, 0)
            end
        end
    end
end

local function TeleportPlayerToMe(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if targetHRP then
        targetHRP.CFrame = myHRP.CFrame * CFrame.new(0, 0, -3)
    end
end

-- ==================== NOCLIP ====================
local NoclipConnection = nil
local function ToggleNoclip(state)
    Config.NoclipEnabled = state
    if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
    if state then
        NoclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
end

-- ==================== GUI ====================
local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MM2PentestGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    ScreenGui.IgnoreGuiInset = true
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 300, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
    MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 150, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    })
    Gradient.Rotation = 90
    Gradient.Parent = MainFrame
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = MainFrame
    
    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 35)
    TitleBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    TitleBar.BackgroundTransparency = 0.4
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -70, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = T("title")
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar
    
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 30, 1, 0)
    MinBtn.Position = UDim2.new(1, -35, 0, 0)
    MinBtn.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.new(1, 1, 1)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 18
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TitleBar
    
    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn
    
    -- Content
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, -16, 1, -50)
    ContentFrame.Position = UDim2.new(0, 8, 0, 42)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame
    
    -- Tab bar
    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(1, 0, 0, 28)
    TabContainer.BackgroundTransparency = 1
    TabContainer.Parent = ContentFrame
    
    local TabLayout = Instance.new("UIListLayout")
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.Padding = UDim.new(0, 3)
    TabLayout.Parent = TabContainer
    
    local Tabs = {"tab_visual", "tab_aimbot", "tab_movement", "tab_players", "tab_settings"}
    local TabFrames = {}
    local TabButtons = {}
    local CurrentTab = "tab_visual"
    
    for _, tabKey in ipairs(Tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.19, 0, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        btn.Text = T(tabKey)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        btn.Parent = TabContainer
        
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn
        
        TabButtons[tabKey] = btn
        
        btn.MouseButton1Click:Connect(function()
            CurrentTab = tabKey
            for k, f in pairs(TabFrames) do f.Visible = (k == tabKey) end
            for k, b in pairs(TabButtons) do
                b.BackgroundColor3 = (k == tabKey) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(30, 30, 30)
            end
        end)
    end
    TabButtons["tab_visual"].BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    
    for _, tabKey in ipairs(Tabs) do
        local Frame = Instance.new("ScrollingFrame")
        Frame.Size = UDim2.new(1, 0, 1, -32)
        Frame.Position = UDim2.new(0, 0, 0, 32)
        Frame.BackgroundTransparency = 1
        Frame.BorderSizePixel = 0
        Frame.ScrollBarThickness = 4
        Frame.CanvasSize = UDim2.new(0, 0, 0, 0)
        Frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        Frame.Visible = (tabKey == "tab_visual")
        Frame.Parent = ContentFrame
        
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.Parent = Frame
        
        TabFrames[tabKey] = Frame
    end
    
    -- Registered text widgets for language refresh
    local TextWidgets = {}
    
    local function RegisterText(widget, keyFn)
        table.insert(TextWidgets, { widget = widget, keyFn = keyFn })
    end
    
    -- Helpers
    local function CreateToggle(parent, textKey, initialState, callback)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 34)
        Btn.BackgroundColor3 = initialState and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
        Btn.TextColor3 = Color3.new(1, 1, 1)
        Btn.Font = Enum.Font.Gotham
        Btn.TextSize = 12
        Btn.BorderSizePixel = 0
        Btn.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = Btn
        
        local state = initialState
        local ref = {}
        
        local function refresh()
            Btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
            Btn.Text = T(textKey) .. ": " .. (state and T("on") or T("off"))
        end
        
        ref.updateState = function(s)
            state = s
            refresh()
        end
        ref.getState = function() return state end
        ref.refresh = refresh
        
        refresh()
        RegisterText(Btn, refresh)
        
        Btn.MouseButton1Click:Connect(function()
            state = not state
            refresh()
            if callback then callback(state) end
        end)
        
        return ref
    end
    
    local function CreateSlider(parent, textKey, min, max, initial, callback)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, 0, 0, 48)
        Container.BackgroundTransparency = 1
        Container.Parent = parent
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 0, 20)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Color3.new(1, 1, 1)
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 11
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Container
        
        local SliderBg = Instance.new("Frame")
        SliderBg.Size = UDim2.new(1, 0, 0, 22)
        SliderBg.Position = UDim2.new(0, 0, 0, 24)
        SliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        SliderBg.BorderSizePixel = 0
        SliderBg.Parent = Container
        
        local sc = Instance.new("UICorner")
        sc.CornerRadius = UDim.new(0, 4)
        sc.Parent = SliderBg
        
        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((initial - min) / (max - min), 0, 1, 0)
        Fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        Fill.BorderSizePixel = 0
        Fill.Parent = SliderBg
        
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(0, 4)
        fc.Parent = Fill
        
        local currentValue = initial
        
        local function refreshLabel()
            Label.Text = T(textKey) .. ": " .. string.format("%.2f", currentValue)
        end
        refreshLabel()
        RegisterText(Label, refreshLabel)
        
        local dragging = false
        local function UpdateSlider(input)
            local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
            currentValue = min + (max - min) * pos
            Fill.Size = UDim2.new(pos, 0, 1, 0)
            refreshLabel()
            if callback then callback(currentValue) end
        end
        
        SliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                UpdateSlider(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateSlider(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end
    
    local function CreateActionButton(parent, textKey, callback)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 34)
        Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        Btn.TextColor3 = Color3.new(1, 1, 1)
        Btn.Font = Enum.Font.Gotham
        Btn.TextSize = 12
        Btn.BorderSizePixel = 0
        Btn.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = Btn
        
        local ref = {}
        ref.setText = function(txt) Btn.Text = txt end
        ref.refresh = function() Btn.Text = T(textKey) end
        ref.refresh()
        RegisterText(Btn, ref.refresh)
        
        Btn.MouseButton1Click:Connect(function()
            if callback then callback(ref) end
        end)
        
        return ref
    end
    
    -- ===== VISUAL =====
    local V = TabFrames["tab_visual"]
    CreateToggle(V, "esp", Config.ESPEnabled, function(v) Config.ESPEnabled = v; ForceRefreshESP() end)
    CreateToggle(V, "tracers", Config.TracersEnabled, function(v) Config.TracersEnabled = v end)
    CreateToggle(V, "highlight", Config.HighlightEnabled, function(v) Config.HighlightEnabled = v; ForceRefreshESP() end)
    CreateToggle(V, "names", Config.NamesEnabled, function(v) Config.NamesEnabled = v; ForceRefreshESP() end)
    CreateToggle(V, "roles", Config.RolesEnabled, function(v) Config.RolesEnabled = v; ForceRefreshESP() end)
    
    -- ===== AIMBOT =====
    local A = TabFrames["tab_aimbot"]
    UIRefs.aimbotToggle = CreateToggle(A, "aimbot", Config.AimbotEnabled, function(v)
        Config.AimbotEnabled = v
        if MobileAimbotBtn then
            MobileAimbotBtn.BackgroundColor3 = v and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
        end
    end)
    
    CreateToggle(A, "aimbot_btn", Config.MobileAimbotBtn, function(v)
        Config.MobileAimbotBtn = v
        if MobileAimbotBtn then MobileAimbotBtn.Visible = v end
    end)
    
    local RoleBtnRef = CreateActionButton(A, "target", function(ref)
        local rolesList = {"Murderer", "Sheriff", "Innocent", "All"}
        local idx = 1
        for i, r in ipairs(rolesList) do if r == Config.AimbotRole then idx = i break end end
        idx = idx % #rolesList + 1
        Config.AimbotRole = rolesList[idx]
        ref.setText(T("target") .. ": " .. RoleName(Config.AimbotRole))
    end)
    RoleBtnRef.setText(T("target") .. ": " .. RoleName(Config.AimbotRole))
    table.insert(TextWidgets, { widget = RoleBtnRef, keyFn = function()
        RoleBtnRef.setText(T("target") .. ": " .. RoleName(Config.AimbotRole))
    end })
    
    CreateSlider(A, "smoothness", 0.01, 1, Config.AimbotSmoothness, function(v) Config.AimbotSmoothness = v end)
    CreateSlider(A, "fov", 10, 500, Config.AimbotFOV, function(v) Config.AimbotFOV = v end)
    CreateToggle(A, "wallcheck", Config.AimbotWallCheck, function(v) Config.AimbotWallCheck = v end)
    CreateToggle(A, "show_fov", Config.ShowFOV, function(v) Config.ShowFOV = v end)
    
    -- Keybind
    local KeybindBtn = Instance.new("TextButton")
    KeybindBtn.Size = UDim2.new(1, 0, 0, 34)
    KeybindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    KeybindBtn.TextColor3 = Color3.new(1, 1, 1)
    KeybindBtn.Font = Enum.Font.Gotham
    KeybindBtn.TextSize = 12
    KeybindBtn.BorderSizePixel = 0
    KeybindBtn.Parent = A
    
    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(0, 4)
    kc.Parent = KeybindBtn
    
    local waitingForKey = false
    local function refreshKeybind()
        if waitingForKey then
            KeybindBtn.Text = T("press_key")
        else
            KeybindBtn.Text = T("keybind") .. ": " .. Config.AimbotBind.Name
        end
    end
    refreshKeybind()
    RegisterText(KeybindBtn, refreshKeybind)
    
    KeybindBtn.MouseButton1Click:Connect(function()
        waitingForKey = true
        refreshKeybind()
    end)
    
    UserInputService.InputBegan:Connect(function(input, gp)
        if waitingForKey and input.UserInputType == Enum.UserInputType.Keyboard then
            Config.AimbotBind = input.KeyCode
            waitingForKey = false
            refreshKeybind()
        end
    end)
    
    -- ===== MOVEMENT =====
    local M = TabFrames["tab_movement"]
    CreateToggle(M, "noclip", Config.NoclipEnabled, function(v) ToggleNoclip(v) end)
    CreateActionButton(M, "tp_gun", function() TeleportToGun() end)
    
    -- ===== PLAYERS =====
    local P = TabFrames["tab_players"]
    
    local function GetOtherPlayers()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(list, p) end
        end
        return list
    end
    
    local TPRef = CreateActionButton(P, "tp_player", function(ref)
        local list = GetOtherPlayers()
        if #list == 0 then return end
        ref._idx = ((ref._idx or 0) % #list) + 1
        local target = list[ref._idx]
        ref.setText(T("tp_player") .. ": " .. target.DisplayName)
        TeleportToPlayer(target)
    end)
    TPRef.setText(T("tp_player") .. " (" .. T("click_cycle") .. ")")
    
    local BringRef = CreateActionButton(P, "bring_player", function(ref)
        local list = GetOtherPlayers()
        if #list == 0 then return end
        ref._idx = ((ref._idx or 0) % #list) + 1
        local target = list[ref._idx]
        ref.setText(T("bring_player") .. ": " .. target.DisplayName)
        TeleportPlayerToMe(target)
    end)
    BringRef.setText(T("bring_player") .. " (" .. T("click_cycle") .. ")")
    
    -- ===== SETTINGS =====
    local S = TabFrames["tab_settings"]
    
    local LangRef = CreateActionButton(S, "language", function(ref)
        Lang = (Lang == "EN") and "RU" or "EN"
        RefreshAllTexts()
    end)
    
    local function refreshLangBtn()
        LangRef.setText(T("language") .. ": " .. (Lang == "RU" and "РУССКИЙ" or "ENGLISH"))
    end
    refreshLangBtn()
    table.insert(TextWidgets, { widget = LangRef, keyFn = refreshLangBtn })
    
    -- ===== Refresh all =====    function RefreshAllTexts()
        Title.Text = T("title")
        for _, tabKey in ipairs(Tabs) do
            TabButtons[tabKey].Text = T(tabKey)
        end
        for _, entry in ipairs(TextWidgets) do
            pcall(entry.keyFn)
        end
        ForceRefreshESP()
    end
    
    -- ===== MINIMIZE / SHOW =====
    local ShowBtn = Instance.new("TextButton")
    ShowBtn.Name = "ShowBtn"
    ShowBtn.Size = UDim2.new(0, 80, 0, 32)
    -- Top center
    ShowBtn.Position = UDim2.new(0.5, -40, 0, 10)
    ShowBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    ShowBtn.Text = T("show")
    ShowBtn.TextColor3 = Color3.new(1, 1, 1)
    ShowBtn.Font = Enum.Font.GothamBold
    ShowBtn.TextSize = 12
    ShowBtn.BorderSizePixel = 0
    ShowBtn.Visible = false
    ShowBtn.Active = true
    ShowBtn.Parent = ScreenGui
    
    local sc2 = Instance.new("UICorner")
    sc2.CornerRadius = UDim.new(0, 6)
    sc2.Parent = ShowBtn
    
    RegisterText(ShowBtn, function() ShowBtn.Text = T("show") end)
    
    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        ShowBtn.Visible = true
    end)
    
    ShowBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        ShowBtn.Visible = false
    end)
    
    -- Mobile dragging
    local dragging = false
    local dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    -- ===== Mobile Aimbot Button =====
    local btn = Instance.new("TextButton")
    btn.Name = "MobileAimbotBtn"
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.Position = UDim2.new(1, -90, 0, 150)
    btn.BackgroundColor3 = Config.AimbotEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
    btn.Text = "AIM"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.BorderSizePixel = 0
    btn.Active = true
    btn.Draggable = true
    btn.Visible = Config.MobileAimbotBtn
    btn.Parent = ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 35)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        Config.AimbotEnabled = not Config.AimbotEnabled
        btn.BackgroundColor3 = Config.AimbotEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
        if UIRefs.aimbotToggle and UIRefs.aimbotToggle.updateState then
            UIRefs.aimbotToggle.updateState(Config.AimbotEnabled)
        end
    end)
    
    MobileAimbotBtn = btn
end

-- ==================== INPUT ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.AimbotBind then
        Config.AimbotEnabled = not Config.AimbotEnabled
        if UIRefs.aimbotToggle and UIRefs.aimbotToggle.updateState then
            UIRefs.aimbotToggle.updateState(Config.AimbotEnabled)
        end
        if MobileAimbotBtn then
            MobileAimbotBtn.BackgroundColor3 = Config.AimbotEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
        end
    end
    if input.KeyCode == Config.NoclipBind then
        ToggleNoclip(not Config.NoclipEnabled)
    end
end)

-- ==================== LOOPS ====================
task.spawn(function()
    while task.wait(0.35) do
        if Config.ESPEnabled then UpdateAllESP() end
    end
end)

-- Auto-role tracker: monitor tools change and refresh ESP immediately
task.spawn(function()
    while task.wait(0.5) do
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local role = GetPlayerRole(player)
                if LastRoleCache[player] ~= role then
                    LastRoleCache[player] = role
                    if Config.ESPEnabled then
                        pcall(ApplyESP, player)
                    end
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    UpdateTracers()
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = Config.AimbotFOV
        FOVCircle.Visible = Config.ShowFOV and Config.AimbotEnabled
    end
    UpdateAimbot()
end)

-- ==================== INIT ====================
CreateFOVCircle()
CreateGUI()

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        LastRoleCache[player] = nil
        if Config.ESPEnabled then ApplyESP(player) end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    CleanupPlayer(player)
    LastRoleCache[player] = nil
    if TracerLines[player] then
        TracerLines[player]:Remove()
        TracerLines[player] = nil
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            LastRoleCache[player] = nil
            if Config.ESPEnabled then ApplyESP(player) end
        end)
        if player.Character then ApplyESP(player) end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.NoclipEnabled then ToggleNoclip(true) end
    ForceRefreshESP()
end)

-- Force initial refresh after round starts
task.delay(2, function() ForceRefreshESP() end)
task.delay(5, function() ForceRefreshESP() end)