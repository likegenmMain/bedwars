-- Anti-Knockback - Автономная версия (активация по V)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Настройки
local Settings = {
    Enabled = false,
    Strength = 0  -- 0 = нет отбрасывания, 100 = полное
}

-- GUI индикатор
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiKbIndicator"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 100, 0, 30)
indicator.Position = UDim2.new(1, -110, 0, 130)
indicator.BackgroundColor3 = Color3.new(0, 0, 0)
indicator.BackgroundTransparency = 0.3
indicator.BorderSizePixel = 0
indicator.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = indicator

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, 0, 1, 0)
statusText.BackgroundTransparency = 1
statusText.Text = "ANTI-KB OFF"
statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 11
statusText.Parent = indicator

local function UpdateIndicator()
    if Settings.Enabled then
        statusText.Text = "ANTI-KB ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "ANTI-KB OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

-- Белый список разрешённых объектов (от чита)
local allowedNames = {
    "VapeFlyVelocity",
    "VapeFlyGyro",
    "AntiVoidBV",
    "BedNukeBypass",
    "NoFallVelocity",
    "ScaffoldBV"
}

-- Хук контроллеров отбрасывания в BedWars
local function HookKnockbackControllers()
    pcall(function()
        local TS = ReplicatedStorage:FindFirstChild("TS")
        if not TS then return end
        
        local combat = TS:FindFirstChild("combat")
        if combat then
            local kbController = combat:FindFirstChild("knockback-controller")
            if kbController then
                local module = require(kbController)
                if module and module.KnockbackController then
                    local original = module.KnockbackController.applyKnockback
                    if original then
                        module.KnockbackController.applyKnockback = function(self, dir, multiplier, ...)
                            if Settings.Enabled then
                                local strength = Settings.Strength / 100
                                if strength == 0 then return end
                                return original(self, dir, multiplier * strength, ...)
                            end
                            return original(self, dir, multiplier, ...)
                        end
                    end
                end
            end
        end
        
        local statefulEntity = TS:FindFirstChild("stateful-entity")
        if statefulEntity then
            local entityKb = statefulEntity:FindFirstChild("stateful-entity-knockback-controller")
            if entityKb then
                local module = require(entityKb)
                if module and module.StatefulEntityKnockbackController then
                    local original = module.StatefulEntityKnockbackController.applyKnockback
                    if original then
                        module.StatefulEntityKnockbackController.applyKnockback = function(self, dir, multiplier, ...)
                            if Settings.Enabled then
                                local strength = Settings.Strength / 100
                                if strength == 0 then return end
                                return original(self, dir, multiplier * strength, ...)
                            end
                            return original(self, dir, multiplier, ...)
                        end
                    end
                end
            end
        end
    end)
end

-- Физический фикс (удаление сил отдачи)
local function PhysicsAntiKB()
    if not Settings.Enabled then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    -- Удаляем объекты отдачи (кроме разрешённых)
    for _, obj in pairs(hrp:GetChildren()) do
        if obj:IsA("BodyVelocity") or obj:IsA("LinearVelocity") or obj:IsA("BodyForce") or 
           obj:IsA("BodyPosition") or obj:IsA("VectorForce") or obj:IsA("AlignPosition") then
            
            local allowed = false
            for _, name in ipairs(allowedNames) do
                if obj.Name == name then
                    allowed = true
                    break
                end
            end
            
            if not allowed then
                pcall(function() obj:Destroy() end)
            end
        end
    end
    
    -- Гасим лишнюю горизонтальную скорость
    local currentVel = hrp.AssemblyLinearVelocity
    local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
    local walkSpeed = hum.WalkSpeed
    
    if horizontalVel.Magnitude > walkSpeed + 1 then
        local strengthMultiplier = Settings.Strength / 100
        local targetDir = hum.MoveDirection * walkSpeed
        
        local newHorizontal = horizontalVel:Lerp(targetDir, 1 - strengthMultiplier)
        hrp.AssemblyLinearVelocity = Vector3.new(newHorizontal.X, currentVel.Y, newHorizontal.Z)
    end
end

-- Запуск хуков при загрузке
task.spawn(function()
    task.wait(2)
    HookKnockbackControllers()
end)

-- Циклы
local steppedConnection = nil
local heartbeatConnection = nil

local function StartAntiKB()
    if steppedConnection then return end
    steppedConnection = RunService.Stepped:Connect(PhysicsAntiKB)
    heartbeatConnection = RunService.Heartbeat:Connect(PhysicsAntiKB)
end

local function StopAntiKB()
    if steppedConnection then
        steppedConnection:Disconnect()
        steppedConnection = nil
    end
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
end

local function Toggle()
    Settings.Enabled = not Settings.Enabled
    UpdateIndicator()
    
    if Settings.Enabled then
        StartAntiKB()
        print("[AntiKB] Включен (сила: " .. Settings.Strength .. "%)")
    else
        StopAntiKB()
        print("[AntiKB] Выключен")
    end
end

-- Клавиша V
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.V then
        Toggle()
    end
end)

-- Настройка силы (по желанию, можно менять через консоль)
-- Пример: Settings.Strength = 50 (50% отбрасывания)

UpdateIndicator()
print("[AntiKB] Загружен! Нажми V для включения/выключения")
print("[AntiKB] Сила отбрасывания: " .. Settings.Strength .. "% (0 = нет отбрасывания)")
