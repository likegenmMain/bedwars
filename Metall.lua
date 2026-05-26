-- Metal ESP - Автономная версия (только подсветка, активация по B)

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Настройки
local Settings = {
    Enabled = false,
    ESP = true
}

-- GUI индикатор
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MetalESPIndicator"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 100, 0, 30)
indicator.Position = UDim2.new(1, -110, 0, 170)
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
statusText.Text = "METAL ESP OFF"
statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 11
statusText.Parent = indicator

local function UpdateIndicator()
    if Settings.Enabled then
        statusText.Text = "METAL ESP ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "METAL ESP OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

-- Фильтрация объектов магазинов/GUI
local function isShopItem(v)
    if not v then return false end
    if not v:IsDescendantOf(Workspace) then return true end
    if v:FindFirstAncestorOfClass("ViewportFrame") then return true end
    
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg and v:IsDescendantOf(pg) then return true end
    
    local map = Workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("Shops") and v:IsDescendantOf(map.Shops) then
        return true
    end
    
    return false
end

-- Добавление ESP для металла
local function AddMetalESP(model)
    if not model:IsA("Model") or isShopItem(model) then return end
    if model:FindFirstChild("MetalESP_Highlight") then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "MetalESP_Highlight"
    highlight.FillColor = Color3.fromRGB(255, 170, 0)
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Adornee = model
    highlight.Parent = model
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MetalESP_Text"
    billboard.Adornee = model
    billboard.Size = UDim2.new(0, 40, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = model
    
    local image = Instance.new("ImageLabel")
    image.BackgroundTransparency = 1
    image.Size = UDim2.new(1, 0, 1, 0)
    image.Image = "rbxassetid://6850537969"
    image.Parent = billboard
end

-- Обновление ESP (каждую секунду)
local function UpdateMetalESP()
    if not Settings.Enabled or not Settings.ESP then
        for _, m in ipairs(CollectionService:GetTagged("hidden-metal")) do
            pcall(function()
                if m:FindFirstChild("MetalESP_Highlight") then m.MetalESP_Highlight:Destroy() end
                if m:FindFirstChild("MetalESP_Text") then m.MetalESP_Text:Destroy() end
            end)
        end
        return
    end
    
    for _, m in ipairs(CollectionService:GetTagged("hidden-metal")) do
        if not isShopItem(m) then
            AddMetalESP(m)
        end
    end
end

-- Обработчик появления новых металлов
local metalAddedConnection = nil

local function StartMetalESP()
    if metalAddedConnection then return end
    
    metalAddedConnection = CollectionService:GetInstanceAddedSignal("hidden-metal"):Connect(function(m)
        if Settings.Enabled and Settings.ESP and not isShopItem(m) then
            AddMetalESP(m)
        end
    end)
    
    UpdateMetalESP()
end

local function StopMetalESP()
    if metalAddedConnection then
        metalAddedConnection:Disconnect()
        metalAddedConnection = nil
    end
    UpdateMetalESP()
end

-- Запускаем обновление каждую секунду
local refreshConnection = nil

local function StartRefreshLoop()
    if refreshConnection then return end
    refreshConnection = RunService.Heartbeat:Connect(function()
        if Settings.Enabled then
            -- Обновляем ESP каждую секунду
            local now = tick()
            if not refreshConnection.lastUpdate or now - refreshConnection.lastUpdate >= 1 then
                refreshConnection.lastUpdate = now
                UpdateMetalESP()
            end
        end
    end)
end

local function StopRefreshLoop()
    if refreshConnection then
        refreshConnection:Disconnect()
        refreshConnection = nil
    end
end

local function Toggle()
    Settings.Enabled = not Settings.Enabled
    UpdateIndicator()
    
    if Settings.Enabled then
        StartMetalESP()
        StartRefreshLoop()
        print("[MetalESP] Включен (обновление каждую секунду)")
    else
        StopMetalESP()
        StopRefreshLoop()
        print("[MetalESP] Выключен")
    end
end

-- Клавиша B
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.B then
        Toggle()
    end
end)

UpdateIndicator()
print("[MetalESP] Загружен! Нажми B для включения/выключения (обновление каждую секунду)")
