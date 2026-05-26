-- CHEST STEAL - Авто-грабёж сундуков (активация по B)
-- Забирает все предметы из сундуков в радиусе 30 студий

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    Range = 30,
    Delay = 0.1,
    ToggleKey = Enum.KeyCode.B
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChestStealIndicator"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 100, 0, 30)
indicator.Position = UDim2.new(1, -110, 0, 290)
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
statusText.Text = "CHEST STEAL OFF"
statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 11
statusText.Parent = indicator

local function UpdateIndicator()
    if Settings.Enabled then
        statusText.Text = "CHEST STEAL ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "CHEST STEAL OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

local ChestRemote = nil

local function GetChestRemote()
    if ChestRemote then return ChestRemote end
    
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if child:IsA("RemoteFunction") and child.Name:find("ChestGetItem") then
            ChestRemote = child
            return child
        end
    end
    
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if child:IsA("RemoteFunction") and (child.Name:lower():find("chest") or child.Name:lower():find("loot")) then
            ChestRemote = child
            return child
        end
    end
    
    return nil
end

local lastCheck = 0
local connection = nil

local function StealFromChest(chest)
    local remote = GetChestRemote()
    if not remote then return end
    
    local chestFolder = chest:FindFirstChild("ChestFolderValue")
    if not chestFolder then return end
    
    local inventoryFolder = chestFolder.Value
    if not inventoryFolder then return end
    
    local items = inventoryFolder:GetChildren()
    
    for _, item in ipairs(items) do
        if item:IsA("Accessory") or item:IsA("Tool") or item:IsA("Clothing") then
            task.spawn(function()
                pcall(function()
                    remote:InvokeServer(inventoryFolder, item)
                end)
            end)
            task.wait(0.05)
        end
    end
end

local function ChestStealLoop()
    if not Settings.Enabled then return end
    
    local remote = GetChestRemote()
    if not remote then return end
    
    local now = tick()
    if now - lastCheck < Settings.Delay then return end
    lastCheck = now
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local chests = CollectionService:GetTagged("chest")
    
    for _, chest in ipairs(chests) do
        if chest:IsA("BasePart") or chest:IsA("Model") then
            local chestPos = chest:IsA("BasePart") and chest.Position or (chest.PrimaryPart and chest.PrimaryPart.Position)
            if chestPos then
                local dist = (chestPos - root.Position).Magnitude
                if dist <= Settings.Range then
                    task.spawn(function()
                        StealFromChest(chest)
                    end)
                end
            end
        end
    end
end

local function StartSteal()
    if connection then return end
    connection = RunService.Heartbeat:Connect(ChestStealLoop)
end

local function StopSteal()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

local function Toggle()
    Settings.Enabled = not Settings.Enabled
    UpdateIndicator()
    
    if Settings.Enabled then
        StartSteal()
    else
        StopSteal()
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Settings.ToggleKey then
        Toggle()
    end
end)

UpdateIndicator()
print("[ChestSteal] Загружен! Нажми B для включения/выключения")
