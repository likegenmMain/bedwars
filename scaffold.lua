-- Scaffold - Стройка под ногами (активация по X)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Настройки
local Settings = {
    GridSize = 3,
    Delay = 0.05,
    YOffset = -3.5,
    Predict = 0.15
}

-- GUI индикатор
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScaffoldIndicator"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 100, 0, 30)
indicator.Position = UDim2.new(1, -110, 0, 50)
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
statusText.Text = "SCAFFOLD OFF"
statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 12
statusText.Parent = indicator

local enabled = false

local function UpdateIndicator()
    if enabled then
        statusText.Text = "SCAFFOLD ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "SCAFFOLD OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

-- Поиск Remote для установки блока
local PlaceBlockRemote = nil

local function FindPlaceBlockRemote()
    local success, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("rbxts_include", 5):WaitForChild("node_modules"):WaitForChild("@easy-games"):WaitForChild("block-engine"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("PlaceBlock")
    end)
    if success then return remote end
    return nil
end

task.spawn(function()
    while not PlaceBlockRemote do
        PlaceBlockRemote = FindPlaceBlockRemote()
        if not PlaceBlockRemote then task.wait(2) end
    end
end)

local function getWoolName()
    local inv = ReplicatedStorage:FindFirstChild("Inventories") and ReplicatedStorage.Inventories:FindFirstChild(LocalPlayer.Name)
    if inv then
        for _, item in pairs(inv:GetChildren()) do
            if item.Name:find("wool") then return item.Name end
        end
    end
    return nil
end

local function snapToGrid(v3)
    local gridSize = Settings.GridSize
    return Vector3.new(
        math.floor(v3.X / gridSize + 0.5) * gridSize,
        math.floor(v3.Y / gridSize + 0.5) * gridSize,
        math.floor(v3.Z / gridSize + 0.5) * gridSize
    )
end

local lastPlaceTime = 0
local connection = nil

local function ScaffoldLoop()
    if not enabled then return end
    if not PlaceBlockRemote then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local now = tick()
    if now - lastPlaceTime < Settings.Delay then return end
    
    local wool = getWoolName()
    if not wool then return end
    
    local moveDir = hrp.Velocity * Vector3.new(1, 0, 1)
    local predictPos = hrp.Position + (moveDir * Settings.Predict)
    local targetPos = predictPos + Vector3.new(0, Settings.YOffset, 0)
    local gridPos = snapToGrid(targetPos)
    
    local gridSize = Settings.GridSize
    local bx = math.floor(gridPos.X / gridSize)
    local by = math.floor(gridPos.Y / gridSize)
    local bz = math.floor(gridPos.Z / gridSize)
    
    local args = {{
        ["position"] = Vector3.new(bx, by, bz),
        ["blockType"] = wool,
        ["blockData"] = 0,
        ["mouseBlockInfo"] = {
            ["target"] = {
                ["blockRef"] = { ["blockPosition"] = Vector3.new(bx, by - 1, bz) },
                ["hitPosition"] = Vector3.new(gridPos.X, gridPos.Y, gridPos.Z),
                ["hitNormal"] = Vector3.new(0, 1, 0)
            },
            ["placementPosition"] = Vector3.new(bx, by, bz)
        }
    }}
    
    task.spawn(function()
        pcall(function()
            PlaceBlockRemote:InvokeServer(unpack(args))
        end)
    end)
    
    lastPlaceTime = now
end

local function StartScaffold()
    if connection then return end
    connection = RunService.Heartbeat:Connect(ScaffoldLoop)
end

local function StopScaffold()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

local function Toggle()
    enabled = not enabled
    UpdateIndicator()
    
    if enabled then
        StartScaffold()
    else
        StopScaffold()
    end
end

-- Клавиша X
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.X then
        Toggle()
    end
end)

UpdateIndicator()
print("[Scaffold] Загружен! Нажми X для включения/выключения")
