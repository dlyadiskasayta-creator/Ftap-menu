local Players = game.Players
local LocalPlayer = Players.LocalPlayer
local UserInputService = game.UserInputService
local RunService = game.RunService

-- ⚙ Настройки
local MenuSize = UDim2.new(0.3, 0, 0.4, 0) -- Размер меню (30% по ширине)
local SpeedValues = {1, 5, 10, 15, 20, 25, 30, 40, 50} -- Доступные значения скорости

-----------------------------------
--- Функции работы с UI ---
-----------------------------------

-- Создаёт прозрачную кнопку
local function CreateButton(parent, text, posY, callback)
    local button = Instance.new("TextButton")
    button.Name = "Btn_" .. text
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BackgroundTransparency = 0.8
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Position = UDim2.new(0, 0, posY, 0)
    button.Size = UDim2.new(1, 0, 0.1, 0)
    button.AutoButtonColor = false
    button.Parent = parent
    
    if callback then
        button.Activated:Connect(callback)
    end
end

-- Показывает или скрывает панель
local function TogglePanel(panel, visible)
    panel.Visible = visible
    for _, btn in ipairs(panel:GetChildren()) do
        if btn.ClassName == 'TextButton' then
            btn.Visible = visible
        end
    end
end

-----------------------------------
--- Логика изменения скорости ---
-----------------------------------

-- Функция установки скорости персонажа
local function SetWalkSpeed(speed)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = char and char:FindFirstChildOfClass('Humanoid')
    if humanoid then
        humanoid.WalkSpeed = speed
    else
        warn("[SPEED MENU] Humanoid not found!")
    end
end

-- Обработчик клика по кнопке выбора скорости
local function OnSpeedClick(btn)
    local speed = tonumber(string.match(btn.Name, "%d+"))
    if speed then
        SetWalkSpeed(speed)
        TogglePanel(SpeedMenu, false)
    end
end

-----------------------------------
--- Создание интерфейса ---
-----------------------------------

local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainMenu = Instance.new("Frame", ScreenGui)
MainMenu.AnchorPoint = Vector2.new(0.5, 0.5)
MainMenu.Position = UDim2.new(0.5, 0, 0.5, 0)
MainMenu.Size = MenuSize
MainMenu.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MainMenu.BackgroundTransparency = 0.7
TogglePanel(MainMenu, false) -- Скрываем при старте

CreateButton(MainMenu, "Speed", 0.1, function() 
    TogglePanel(SpeedMenu, true) 
end)
CreateButton(MainMenu, "Exit", 0.9, function() 
    ScreenGui:Destroy() 
end)

-- Меню выбора скорости
local SpeedMenu = Instance.new("Frame", ScreenGui)
SpeedMenu.AnchorPoint = Vector2.new(0.5, 0.5)
SpeedMenu.Position = UDim2.new(0.5, 0, 0.5, 0)
SpeedMenu.Size = MenuSize
SpeedMenu.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
SpeedMenu.BackgroundTransparency = 0.7
TogglePanel(SpeedMenu, false) -- Скрываем при старте

for i, value in ipairs(SpeedValues) do
    CreateButton(
        SpeedMenu,
        tostring(value),
        (i - 1) / #SpeedValues + 0.05,
        OnSpeedClick
    )
end

-----------------------------------
--- Управление через тапы ---
-----------------------------------

UserInputService.TouchTap:Connect(function(hitPos, gameProcessedEvent)
    if gameProcessedEvent then return end

    -- Проверяем, попал ли игрок за пределы меню
    local hitX = hitPos.X / workspace.CurrentCamera.ViewportSize.X
    local hitY = hitPos.Y / workspace.CurrentCamera.ViewportSize.Y

    local isInMenuArea = math.abs(hitX - 0.5) <= MenuSize.X.Scale/2
                     and math.abs(hitY - 0.5) <= MenuSize.Y.Scale/2

    if not isInMenuArea then
        -- Если кликнули вне меню — закрываем всё
        TogglePanel(MainMenu, false)
        TogglePanel(SpeedMenu, false)
    end
end)

RunService.RenderStepped:Connect(function()
    -- Автоматически прячем меню, если игра свернута
    if UserInputService.GamepadEnabled or UserInputService.MouseEnabled then
        ScreenGui.Enabled = false
    else
        ScreenGui.Enabled = true
    end
end)
