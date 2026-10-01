-- MM2 Pentest Script v6 - Part 1/3
-- Services, Drawing wrapper, language, config, roles, ESP

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ==================== SAFE DRAWING WRAPPER ====================
local DrawingAvailable = (type(Drawing) == "table" and type(Drawing.new) == "function")

local function NewDrawing(class, props)
    if not DrawingAvailable then return nil end
    local ok, obj = pcall(function() return Drawing.new(class) end)
    if not ok or not obj then return nil end
    if props then
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    return obj
end

local function SafeSet(obj, prop, value)
    if not obj then return end
    pcall(function() obj[prop] = value end)
end

local function SafeRemove(obj)
    if not obj then return end
    pcall(function() obj:Remove() end)
end

-- ==================== LANGUAGE ====================
local Lang = "RU"
local Strings = {
    EN = {
        title="PENTEST", show="SHOW",
        tab_visual="VISUAL", tab_aimbot="AIMBOT", tab_movement="MOVEMENT",
        tab_players="PLAYERS", tab_settings="SETTINGS",
        esp="ESP", tracers="Tracers", highlight="3D Highlight",
        names="Names", roles="Roles",
        aimbot="Aimbot", aimbot_btn="AIM BUTTON", target="Target",
        smoothness="Smoothness", fov="FOV", wallcheck="Wall Check",
        show_fov="Show FOV Circle",
        noclip="Noclip", tp_gun="TP to Gun", tp_player="TP to Player",
        bring_player="Bring Player", keybind="Keybind",
        language="Language", murderer="Murderer", sheriff="Sheriff",
        innocent="Innocent", all="All",
        click_cycle="tap to cycle", press_key="Press key...",
        on="ON", off="OFF"
    },
    RU = {
        title="ПЕНТЕСТ", show="ПОКАЗ",
        tab_visual="ВИЗУАЛ", tab_aimbot="АИМ", tab_movement="ДВИЖЕНИЕ",
        tab_players="ИГРОКИ", tab_settings="НАСТРОЙКИ",
        esp="ЕСП", tracers="Линии", highlight="3D Обводка",
        names="Ники", roles="Роли",
        aimbot="Аимбот", aimbot_btn="КНОПКА АИМА", target="Цель",
        smoothness="Плавность", fov="ФОВ", wallcheck="Проверка стен",
        show_fov="Показ ФОВ",
        noclip="Ноклип", tp_gun="ТП к пистолету", tp_player="ТП к игроку",
        bring_player="Игрока ко мне", keybind="Кнопка",
        language="Язык", murderer="Маньяк", sheriff="Шериф",
        innocent="Мирный", all="Все",
        click_cycle="тап для смены", press_key="Нажми клавишу...",
        on="ВКЛ", off="ВЫКЛ"
    }
}
local function T(k) return (Strings[Lang] and Strings[Lang][k]) or k end
local function RoleName(r)
    if r=="Murderer" then return T("murderer") end
    if r=="Sheriff" then return T("sheriff") end
    if r=="Innocent" then return T("innocent") end
    if r=="All" then return T("all") end
    return r
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

local ESPObjects = {}
local TracerLines = {}
local FOVCircle = nil
local ActiveTarget = nil
local UIRefs = {}
local MobileAimbotBtn = nil
local LastRoleCache = {}
local NoclipConn = nil

-- ==================== ROLE DETECTION (substring, lowercase) ====================
local function toolMatches(tool, patterns)
    if not tool or not tool.Name then return false end
    local n = string.lower(tool.Name)
    for _, p in ipairs(patterns) do
        if string.find(n, p, 1, true) then return true end
    end
    return false
end

local function playerHasTool(player, patterns)
    if not player then return false end
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")

    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if toolMatches(tool, patterns) then return true end
        end
    end
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if toolMatches(tool, patterns) then return true end
        end
    end
    return false
end

local function GetPlayerRole(player)
    if not player or not player.Parent then return "Innocent" end
    if not player.Character then return "Innocent" end

    if playerHasTool(player, {"knife", "knifestand", "dagger", "blade"}) then
        return "Murderer"
    end
    if playerHasTool(player, {"gun", "revolver", "colt", "pistol", "handgun"}) then
        return "Sheriff"
    end
    return "Innocent"
end

local function GetRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255,0,0) end
    if role == "Sheriff" then return Color3.fromRGB(0,100,255) end
    return Color3.fromRGB(0,255,0)
end

-- ==================== ESP ====================
local function CleanupPlayer(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            if typeof(obj) == "Instance" and obj.Parent then obj:Destroy() end
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

    local cacheKey = string.format("%s|%s|%s|%s|%s",
        role,
        tostring(Config.HighlightEnabled),
        tostring(Config.NamesEnabled),
        tostring(Config.RolesEnabled),
        tostring(player.DisplayName)
    )

    if ESPObjects[player] and ESPObjects[player]._cacheKey == cacheKey then
        return
    end

    CleanupPlayer(player)
    ESPObjects[player] = { _cacheKey = cacheKey }

    if Config.HighlightEnabled then
        local h = Instance.new("Highlight")
        h.Name = "PentestHL"
        h.Adornee = char
        h.FillColor = color
        h.OutlineColor = color
        h.FillTransparency = 0.7
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = char
        table.insert(ESPObjects[player], h)
    end

    if Config.NamesEnabled or Config.RolesEnabled then
        local bb = Instance.new("BillboardGui")
        bb.Name = "PentestBB"
        bb.Adornee = head
        bb.Size = UDim2.new(0, 200, 0, 40)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head

        local text = ""
        if Config.NamesEnabled then text = player.DisplayName end
        if Config.RolesEnabled then
            if text ~= "" then text = text .. " " end
            text = text .. "[" .. RoleName(role) .. "]"
        end

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,1,0)
        label.BackgroundTransparency = 1
        label.TextColor3 = color
        label.TextStrokeColor3 = Color3.new(0,0,0)
        label.TextStrokeTransparency = 0.3
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.Text = text
        label.Parent = bb
        table.insert(ESPObjects[player], bb)
    end
end

local function UpdateAllESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then pcall(ApplyESP, p) end
    end
end

local function ForceRefreshESP()
    for p in pairs(ESPObjects) do CleanupPlayer(p) end
    LastRoleCache = {}
    UpdateAllESP()
end
-- MM2 Pentest Script v6 - Part 2/3
-- Tracers, FOV circle, aimbot, teleports, noclip

-- ==================== TRACERS ====================
local function UpdateTracers()
    if not DrawingAvailable then return end

    if not Config.TracersEnabled or not Config.ESPEnabled then
        for _, line in pairs(TracerLines) do SafeSet(line, "Visible", false) end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

            if hrp and humanoid and humanoid.Health > 0 then
                if not TracerLines[player] then
                    TracerLines[player] = NewDrawing("Line", {
                        Thickness = 1.5,
                        Transparency = 1,
                        Visible = false
                    })
                end

                local line = TracerLines[player]
                if line then
                    local role = GetPlayerRole(player)
                    local color = GetRoleColor(role)
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

                    if onScreen then
                        SafeSet(line, "From", Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y))
                        SafeSet(line, "To", Vector2.new(screenPos.X, screenPos.Y))
                        SafeSet(line, "Color", color)
                        SafeSet(line, "Visible", true)
                    else
                        SafeSet(line, "Visible", false)
                    end
                end
            else
                if TracerLines[player] then SafeSet(TracerLines[player], "Visible", false) end
            end
        end
    end
end

-- ==================== FOV CIRCLE ====================
local function CreateFOVCircle()
    if not DrawingAvailable then return end
    if FOVCircle then SafeRemove(FOVCircle) end
    FOVCircle = NewDrawing("Circle", {
        Thickness = 2,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0.6,
        NumSides = 64,
        Radius = Config.AimbotFOV,
        Filled = false,
        Visible = false
    })
end

-- ==================== AIMBOT ====================
local function HasLineOfSight(targetChar)
    if not Config.AimbotWallCheck then return true end
    if not targetChar then return false end
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
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    local head = player.Character:FindFirstChild("Head")
    if not hum or not head or not head.Parent then return false end
    if hum.Health <= 0 then return false end

    local role = GetPlayerRole(player)
    if Config.AimbotRole ~= "All" and Config.AimbotRole ~= role then return false end

    local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then return false end

    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
    if dist > Config.AimbotFOV then return false end

    if not HasLineOfSight(player.Character) then return false end
    return true
end

local function GetClosestTarget()
    local closest, closestDist = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, p in ipairs(Players:GetPlayers()) do
        if IsValidTarget(p) then
            local head = p.Character and p.Character:FindFirstChild("Head")
            if head and head.Parent then
                local sp = Camera:WorldToViewportPoint(head.Position)
                local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if dist < closestDist then closestDist = dist closest = p end
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
        if head and head.Parent then
            local targetCF = CFrame.new(Camera.CFrame.Position, head.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, Config.AimbotSmoothness)
        end
    end
end

-- ==================== TELEPORT ====================
local function TeleportToPlayer(tp)
    if not tp or not tp.Character then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    local tHRP = tp.Character:FindFirstChild("HumanoidRootPart")
    if myHRP and tHRP then myHRP.CFrame = tHRP.CFrame * CFrame.new(0,0,2) end
end

local function TeleportToGun()
    local found = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") then
            local n = string.lower(obj.Name)
            if string.find(n, "gun", 1, true)
                or string.find(n, "revolver", 1, true)
                or string.find(n, "colt", 1, true)
                or string.find(n, "pistol", 1, true)
                or string.find(n, "handgun", 1, true) then
                found = obj
                break
            end
        end
    end

    if found then
        local handle = found:FindFirstChild("Handle") or found:FindFirstChildWhichIsA("BasePart", true)
        if handle then
            local myChar = LocalPlayer.Character
            if myChar then
                local myHRP = myChar:FindFirstChild("HumanoidRootPart")
                if myHRP then myHRP.CFrame = handle.CFrame * CFrame.new(0,2,0) end
            end
        end
    end
end

local function TeleportPlayerToMe(tp)
    if not tp or not tp.Character then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local tHRP = tp.Character:FindFirstChild("HumanoidRootPart")
    if tHRP then tHRP.CFrame = myHRP.CFrame * CFrame.new(0,0,-3) end
end

-- ==================== NOCLIP ====================
local function ApplyNoclipStep()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

local function DisconnectNoclip()
    if NoclipConn then
        NoclipConn:Disconnect()
        NoclipConn = nil
    end
end

local function ToggleNoclip(state)
    Config.NoclipEnabled = state
    DisconnectNoclip()
    if state then
        NoclipConn = RunService.Stepped:Connect(function()
            pcall(ApplyNoclipStep)
        end)
        pcall(ApplyNoclipStep)
    end
end
-- MM2 Pentest Script v6 - Part 3/3
-- GUI, input, loops, init

-- ==================== GUI ====================
local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MM2PentestGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 300, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
    MainFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,150,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0,0,0))
    })
    Gradient.Rotation = 90
    Gradient.Parent = MainFrame

    local MC = Instance.new("UICorner")
    MC.CornerRadius = UDim.new(0,8)
    MC.Parent = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1,0,0,35)
    TitleBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
    TitleBar.BackgroundTransparency = 0.4
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1,-70,1,0)
    Title.Position = UDim2.new(0,10,0,0)
    Title.BackgroundTransparency = 1
    Title.Text = T("title")
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0,30,1,0)
    MinBtn.Position = UDim2.new(1,-35,0,0)
    MinBtn.BackgroundColor3 = Color3.fromRGB(255,165,0)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.new(1,1,1)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 18
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TitleBar

    local MnC = Instance.new("UICorner")
    MnC.CornerRadius = UDim.new(0,6)
    MnC.Parent = MinBtn

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1,-16,1,-50)
    ContentFrame.Position = UDim2.new(0,8,0,42)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame

    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(1,0,0,28)
    TabContainer.BackgroundTransparency = 1
    TabContainer.Parent = ContentFrame

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.Padding = UDim.new(0,3)
    TabLayout.Parent = TabContainer

    local Tabs = {"tab_visual","tab_aimbot","tab_movement","tab_players","tab_settings"}
    local TabFrames = {}
    local TabButtons = {}

    for _, tk in ipairs(Tabs) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.19,0,1,0)
        b.BackgroundColor3 = Color3.fromRGB(30,30,30)
        b.Text = T(tk)
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 9
        b.BorderSizePixel = 0
        b.Parent = TabContainer

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0,4)
        c.Parent = b

        TabButtons[tk] = b

        b.MouseButton1Click:Connect(function()
            for k, f in pairs(TabFrames) do f.Visible = (k == tk) end
            for k, bb in pairs(TabButtons) do
                bb.BackgroundColor3 = (k == tk) and Color3.fromRGB(0,120,200) or Color3.fromRGB(30,30,30)
            end
        end)
    end
    TabButtons["tab_visual"].BackgroundColor3 = Color3.fromRGB(0,120,200)

    for _, tk in ipairs(Tabs) do
        local F = Instance.new("ScrollingFrame")
        F.Size = UDim2.new(1,0,1,-32)
        F.Position = UDim2.new(0,0,0,32)
        F.BackgroundTransparency = 1
        F.BorderSizePixel = 0
        F.ScrollBarThickness = 4
        F.CanvasSize = UDim2.new(0,0,0,0)
        F.AutomaticCanvasSize = Enum.AutomaticSize.Y
        F.Visible = (tk == "tab_visual")
        F.Parent = ContentFrame

        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0,6)
        lay.Parent = F

        TabFrames[tk] = F
    end

    local TextWidgets = {}
    local function RegisterText(fn) table.insert(TextWidgets, fn) end

    local function CreateToggle(parent, key, initial, cb)
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(1,0,0,34)
        B.BackgroundColor3 = initial and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
        B.TextColor3 = Color3.new(1,1,1)
        B.Font = Enum.Font.Gotham
        B.TextSize = 12
        B.BorderSizePixel = 0
        B.Parent = parent

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0,4)
        c.Parent = B

        local state = initial
        local ref = {}
        local function refresh()
            B.BackgroundColor3 = state and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
            B.Text = T(key) .. ": " .. (state and T("on") or T("off"))
        end
        ref.updateState = function(s) state = s refresh() end
        ref.refresh = refresh
        refresh()
        RegisterText(refresh)

        B.MouseButton1Click:Connect(function()
            state = not state
            refresh()
            if cb then cb(state) end
        end)
        return ref
    end

    local function CreateSlider(parent, key, mn, mx, initial, cb)
        local C = Instance.new("Frame")
        C.Size = UDim2.new(1,0,0,48)
        C.BackgroundTransparency = 1
        C.Parent = parent

        local L = Instance.new("TextLabel")
        L.Size = UDim2.new(1,0,0,20)
        L.BackgroundTransparency = 1
        L.TextColor3 = Color3.new(1,1,1)
        L.Font = Enum.Font.Gotham
        L.TextSize = 11
        L.TextXAlignment = Enum.TextXAlignment.Left
        L.Parent = C

        local Bg = Instance.new("Frame")
        Bg.Size = UDim2.new(1,0,0,22)
        Bg.Position = UDim2.new(0,0,0,24)
        Bg.BackgroundColor3 = Color3.fromRGB(50,50,50)
        Bg.BorderSizePixel = 0
        Bg.Parent = C

        local bcg = Instance.new("UICorner")
        bcg.CornerRadius = UDim.new(0,4)
        bcg.Parent = Bg

        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((initial-mn)/(mx-mn),0,1,0)
        Fill.BackgroundColor3 = Color3.fromRGB(0,150,255)
        Fill.BorderSizePixel = 0
        Fill.Parent = Bg

        local fcg = Instance.new("UICorner")
        fcg.CornerRadius = UDim.new(0,4)
        fcg.Parent = Fill

        local val = initial
        local function refresh() L.Text = T(key) .. ": " .. string.format("%.2f", val) end
        refresh()
        RegisterText(refresh)

        local dragging = false
        local function upd(input)
            local pos = math.clamp((input.Position.X - Bg.AbsolutePosition.X) / Bg.AbsoluteSize.X, 0, 1)
            val = mn + (mx-mn)*pos
            Fill.Size = UDim2.new(pos,0,1,0)
            refresh()
            if cb then cb(val) end
        end

        Bg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                upd(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                upd(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    local function CreateAction(parent, key, cb)
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(1,0,0,34)
        B.BackgroundColor3 = Color3.fromRGB(30,30,30)
        B.TextColor3 = Color3.new(1,1,1)
        B.Font = Enum.Font.Gotham
        B.TextSize = 12
        B.BorderSizePixel = 0
        B.Parent = parent

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0,4)
        c.Parent = B

        local ref = {}
        ref.setText = function(txt) B.Text = txt end
        ref.refresh = function() B.Text = T(key) end
        ref.refresh()
        RegisterText(ref.refresh)

        B.MouseButton1Click:Connect(function() if cb then cb(ref) end end)
        return ref
    end

    -- VISUAL
    local V = TabFrames["tab_visual"]
    CreateToggle(V, "esp", Config.ESPEnabled, function(v) Config.ESPEnabled = v ForceRefreshESP() end)
    CreateToggle(V, "tracers", Config.TracersEnabled, function(v) Config.TracersEnabled = v end)
    CreateToggle(V, "highlight", Config.HighlightEnabled, function(v) Config.HighlightEnabled = v ForceRefreshESP() end)
    CreateToggle(V, "names", Config.NamesEnabled, function(v) Config.NamesEnabled = v ForceRefreshESP() end)
    CreateToggle(V, "roles", Config.RolesEnabled, function(v) Config.RolesEnabled = v ForceRefreshESP() end)

    -- AIMBOT
    local A = TabFrames["tab_aimbot"]
    UIRefs.aimbotToggle = CreateToggle(A, "aimbot", Config.AimbotEnabled, function(v)
        Config.AimbotEnabled = v
        if MobileAimbotBtn then
            MobileAimbotBtn.BackgroundColor3 = v and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
        end
    end)
    CreateToggle(A, "aimbot_btn", Config.MobileAimbotBtn, function(v)
        Config.MobileAimbotBtn = v
        if MobileAimbotBtn then MobileAimbotBtn.Visible = v end
    end)

    local RoleBtn = CreateAction(A, "target", function(ref)
        local list = {"Murderer","Sheriff","Innocent","All"}
        local idx = 1
        for i, r in ipairs(list) do if r == Config.AimbotRole then idx = i break end end
        idx = idx % #list + 1
        Config.AimbotRole = list[idx]
        ref.setText(T("target") .. ": " .. RoleName(Config.AimbotRole))
    end)
    RoleBtn.setText(T("target") .. ": " .. RoleName(Config.AimbotRole))
    RegisterText(function() RoleBtn.setText(T("target") .. ": " .. RoleName(Config.AimbotRole)) end)

    CreateSlider(A, "smoothness", 0.01, 1, Config.AimbotSmoothness, function(v) Config.AimbotSmoothness = v end)
    CreateSlider(A, "fov", 10, 500, Config.AimbotFOV, function(v) Config.AimbotFOV = v end)
    CreateToggle(A, "wallcheck", Config.AimbotWallCheck, function(v) Config.AimbotWallCheck = v end)
    CreateToggle(A, "show_fov", Config.ShowFOV, function(v) Config.ShowFOV = v end)

    -- MOVEMENT
    local M = TabFrames["tab_movement"]
    CreateToggle(M, "noclip", Config.NoclipEnabled, function(v) ToggleNoclip(v) end)
    CreateAction(M, "tp_gun", function() TeleportToGun() end)

    -- PLAYERS
    local P = TabFrames["tab_players"]
    local function OtherPlayers()
        local l = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(l, p) end end
        return l
    end

    local TPRef = CreateAction(P, "tp_player", function(ref)
        local l = OtherPlayers()
        if #l == 0 then return end
        ref._idx = ((ref._idx or 0) % #l) + 1
        local t = l[ref._idx]
        ref.setText(T("tp_player") .. ": " .. t.DisplayName)
        TeleportToPlayer(t)
    end)
    TPRef.setText(T("tp_player") .. " (" .. T("click_cycle") .. ")")

    local BrRef = CreateAction(P, "bring_player", function(ref)
        local l = OtherPlayers()
        if #l == 0 then return end
        ref._idx = ((ref._idx or 0) % #l) + 1
        local t = l[ref._idx]
        ref.setText(T("bring_player") .. ": " .. t.DisplayName)
        TeleportPlayerToMe(t)
    end)
    BrRef.setText(T("bring_player") .. " (" .. T("click_cycle") .. ")")

    -- SETTINGS
    local S = TabFrames["tab_settings"]
    local LangRef = CreateAction(S, "language", function()
        Lang = (Lang == "EN") and "RU" or "EN"
        RefreshAllTexts()
    end)
    RegisterText(function() LangRef.setText(T("language") .. ": " .. (Lang == "RU" and "РУССКИЙ" or "ENGLISH")) end)

    function RefreshAllTexts()
        Title.Text = T("title")
        for _, tk in ipairs(Tabs) do TabButtons[tk].Text = T(tk) end
        for _, fn in ipairs(TextWidgets) do pcall(fn) end
        ForceRefreshESP()
    end
    RefreshAllTexts()

    local ShowBtn = Instance.new("TextButton")
    ShowBtn.Size = UDim2.new(0,80,0,32)
    ShowBtn.Position = UDim2.new(0.5,-40,0,10)
    ShowBtn.BackgroundColor3 = Color3.fromRGB(0,150,255)
    ShowBtn.Text = T("show")
    ShowBtn.TextColor3 = Color3.new(1,1,1)
    ShowBtn.Font = Enum.Font.GothamBold
    ShowBtn.TextSize = 12
    ShowBtn.BorderSizePixel = 0
    ShowBtn.Visible = false
    ShowBtn.Active = true
    ShowBtn.Parent = ScreenGui

    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0,6)
    sc.Parent = ShowBtn
    RegisterText(function() ShowBtn.Text = T("show") end)

    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        ShowBtn.Visible = true
    end)
    ShowBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        ShowBtn.Visible = false
    end)

    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local ab = Instance.new("TextButton")
    ab.Size = UDim2.new(0,70,0,70)
    ab.Position = UDim2.new(1,-90,0,150)
    ab.BackgroundColor3 = Config.AimbotEnabled and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
    ab.Text = "AIM"
    ab.TextColor3 = Color3.new(1,1,1)
    ab.Font = Enum.Font.GothamBold
    ab.TextSize = 16
    ab.BorderSizePixel = 0
    ab.Active = true
    ab.Draggable = true
    ab.Visible = Config.MobileAimbotBtn
    ab.Parent = ScreenGui

    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(0,35)
    ac.Parent = ab

    ab.MouseButton1Click:Connect(function()
        Config.AimbotEnabled = not Config.AimbotEnabled
        ab.BackgroundColor3 = Config.AimbotEnabled and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
        if UIRefs.aimbotToggle and UIRefs.aimbotToggle.updateState then
            UIRefs.aimbotToggle.updateState(Config.AimbotEnabled)
        end
    end)

    MobileAimbotBtn = ab
end

-- ==================== INPUT ====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.AimbotBind then
        Config.AimbotEnabled = not Config.AimbotEnabled
        if UIRefs.aimbotToggle and UIRefs.aimbotToggle.updateState then
            UIRefs.aimbotToggle.updateState(Config.AimbotEnabled)
        end
        if MobileAimbotBtn then
            MobileAimbotBtn.BackgroundColor3 = Config.AimbotEnabled and Color3.fromRGB(0,180,0) or Color3.fromRGB(180,0,0)
        end
    end
    if input.KeyCode == Config.NoclipBind then
        ToggleNoclip(not Config.NoclipEnabled)
    end
end)

-- ==================== LOOPS ====================
task.spawn(function()
    while task.wait(0.4) do
        if Config.ESPEnabled then UpdateAllESP() end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local r = GetPlayerRole(p)
                if LastRoleCache[p] ~= r then
                    LastRoleCache[p] = r
                    if Config.ESPEnabled then pcall(ApplyESP, p) end
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(UpdateTracers)
    if FOVCircle then
        SafeSet(FOVCircle, "Position", Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2))
        SafeSet(FOVCircle, "Radius", Config.AimbotFOV)
        SafeSet(FOVCircle, "Visible", Config.ShowFOV)
    end
    UpdateAimbot()
end)

-- ==================== INIT ====================
pcall(CreateFOVCircle)
pcall(CreateGUI)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        LastRoleCache[p] = nil
        if Config.ESPEnabled then pcall(ApplyESP, p) end
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    CleanupPlayer(p)
    LastRoleCache[p] = nil
    if TracerLines[p] then SafeRemove(TracerLines[p]) TracerLines[p] = nil end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            LastRoleCache[p] = nil
            if Config.ESPEnabled then pcall(ApplyESP, p) end
        end)
        if p.Character then pcall(ApplyESP, p) end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.NoclipEnabled then ToggleNoclip(true) end
    ForceRefreshESP()
end)

workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
        task.wait(0.3)
        if Config.NoclipEnabled then pcall(ApplyNoclipStep) end
    end
end)

task.delay(1, function() pcall(ForceRefreshESP) end)
task.delay(3, function() pcall(ForceRefreshESP) end)
