-- AntiVoid - Радужная платформа под игроком
-- Активация: V (вкл/выкл)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    PlatformY = 50,
    LaunchPower = 100,
    PlatformSize = Vector3.new(2048, 5, 2048),
    ToggleKey = Enum.KeyCode.V,
    RainbowSpeed = 0.002
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiVoidIndicator"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 100, 0, 30)
indicator.Position = UDim2.new(1, -110, 0, 330)
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
statusText.Text = "ANTIVOID OFF"
statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 11
statusText.Parent = indicator

local function UpdateIndicator()
    if Settings.Enabled then
        statusText.Text = "ANTIVOID ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "ANTIVOID OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

local platform = nil
local updateConnection = nil
local touchedConnection = nil
local colorConnection = nil
local hue = 0

local function UpdateRainbow()
    if not platform then return end
    
    hue = (hue + Settings.RainbowSpeed) % 1
    local color = Color3.fromHSV(hue, 1, 1)
    platform.Color = color
end

local function CreatePlatform()
    if platform then
        platform:Destroy()
    end
    
    platform = Instance.new("Part")
    platform.Name = "AntiVoidPlatform"
    platform.Size = Settings.PlatformSize
    platform.Position = Vector3.new(0, Settings.PlatformY, 0)
    platform.Anchored = true
    platform.CanCollide = false
    platform.Transparency = 0.3
    platform.CastShadow = false
    platform.CanQuery = false
    platform.Material = Enum.Material.Neon
    platform.Parent = Workspace
    
    if touchedConnection then
        touchedConnection:Disconnect()
    end
    
    touchedConnection = platform.Touched:Connect(function(hit)
        local char = LocalPlayer.Character
        if not char then return end
        
        local humanoid = char:FindFirstChild("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart and hit.Parent == char then
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, Settings.LaunchPower, rootPart.Velocity.Z)
        end
    end)
    
    if colorConnection then
        colorConnection:Disconnect()
    end
    
    colorConnection = RunService.Heartbeat:Connect(UpdateRainbow)
end

local function UpdatePlatform()
    if not Settings.Enabled then return end
    
    if not platform or not platform.Parent then
        CreatePlatform()
    end
end

local function StartAntiVoid()
    if updateConnection then return end
    
    CreatePlatform()
    updateConnection = RunService.Heartbeat:Connect(UpdatePlatform)
end

local function StopAntiVoid()
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end
    
    if touchedConnection then
        touchedConnection:Disconnect()
        touchedConnection = nil
    end
    
    if colorConnection then
        colorConnection:Disconnect()
        colorConnection = nil
    end
    
    if platform then
        platform:Destroy()
        platform = nil
    end
end

local function Toggle()
    Settings.Enabled = not Settings.Enabled
    UpdateIndicator()
    
    if Settings.Enabled then
        StartAntiVoid()
    else
        StopAntiVoid()
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Settings.ToggleKey then
        Toggle()
    end
end)

UpdateIndicator()
print("[AntiVoid] Радужная версия загружена! Нажми V для включения")
