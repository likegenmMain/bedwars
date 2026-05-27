-- TRIGGER BOT - Авто-атака когда прицел на враге
-- Активация: T

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    Delay = 0.05,
    ToggleKey = Enum.KeyCode.T
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TriggerBotIndicator"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 100, 0, 30)
indicator.Position = UDim2.new(1, -110, 0, 450)
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
statusText.Text = "TRIGGER OFF"
statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 11
statusText.Parent = indicator

local function UpdateIndicator()
    if Settings.Enabled then
        statusText.Text = "TRIGGER ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "TRIGGER OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

local SwordHitRemote = nil

local function GetSwordRemote()
    if SwordHitRemote and SwordHitRemote.Parent then 
        return SwordHitRemote 
    end
    
    SwordHitRemote = ReplicatedStorage:FindFirstChild("SwordHit")
    if not SwordHitRemote then
        for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
            if child:IsA("RemoteEvent") and (child.Name:lower() == "swordhit" or child.Name:lower() == "attackentity") then
                SwordHitRemote = child
                break
            end
        end
    end
    
    return SwordHitRemote
end

local function GetWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local handInv = char:FindFirstChild("HandInvItem")
    if handInv and handInv.Value then
        return handInv.Value
    end
    
    return nil
end

local function GetTargetUnderCrosshair()
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    
    local mouse = LocalPlayer:GetMouse()
    local target = mouse.Target
    
    if target then
        local character = target.Parent
        if character and character:FindFirstChild("Humanoid") then
            local player = Players:GetPlayerFromCharacter(character)
            if player and player ~= LocalPlayer then
                local myTeam = LocalPlayer.Team
                local playerTeam = player.Team
                if not (myTeam and playerTeam and myTeam == playerTeam) then
                    return character
                end
            end
        end
    end
    
    return nil
end

local lastAttackTime = 0
local connection = nil

local function Attack(target)
    local remote = GetSwordRemote()
    if not remote then return end
    
    local weapon = GetWeapon()
    if not weapon then return end
    
    local targetHrp = target:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local direction = (targetHrp.Position - hrp.Position).Unit
    local dist = (targetHrp.Position - hrp.Position).Magnitude
    local spoofedSelfPos = hrp.Position
    
    if dist > 14 then
        spoofedSelfPos = targetHrp.Position - (direction * 13.5)
    end
    
    local args = {
        {
            chargedAttack = { chargeRatio = 0 },
            entityInstance = target,
            validate = {
                targetPosition = { value = targetHrp.Position },
                selfPosition = { value = spoofedSelfPos },
                raycast = {
                    cameraPosition = { value = spoofedSelfPos + Vector3.new(0, 3, 0) },
                    cursorDirection = { value = direction }
                }
            },
            weapon = weapon
        }
    }
    
    pcall(function()
        remote:FireServer(unpack(args))
    end)
end

local function TriggerLoop()
    if not Settings.Enabled then return end
    
    local now = tick()
    if now - lastAttackTime < Settings.Delay then return end
    
    local target = GetTargetUnderCrosshair()
    if target then
        lastAttackTime = now
        Attack(target)
    end
end

local function StartTrigger()
    if connection then return end
    connection = RunService.Heartbeat:Connect(TriggerLoop)
end

local function StopTrigger()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

local function Toggle()
    Settings.Enabled = not Settings.Enabled
    UpdateIndicator()
    
    if Settings.Enabled then
        StartTrigger()
    else
        StopTrigger()
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Settings.ToggleKey then
        Toggle()
    end
end)

UpdateIndicator()
print("[TriggerBot] Загружен! Нажми T для включения")
