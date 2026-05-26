local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local enabled = false
local lastAttackTime = 0
local lastCheckTime = 0
local isSimulatingClick = false

local RANGE = 25
local CHECK_DELAY = 0.01
local WALL_CHECK = false
local REQUIRE_AIM = false
local AUTO_CLICK = true
local HIT_CHANCE = 100
local FOV = 360

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KillauraIndicator"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 100, 0, 30)
indicator.Position = UDim2.new(1, -110, 0, 10)
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
statusText.Text = "KILLAURA OFF"
statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 12
statusText.Parent = indicator

local function UpdateIndicator()
    if enabled then
        statusText.Text = "KILLAURA ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "KILLAURA OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

local SwordHitRemote = nil

local function GetSwordRemote()
    if SwordHitRemote and SwordHitRemote.Parent then 
        return SwordHitRemote 
    end
    
    local remote = ReplicatedStorage:FindFirstChild("SwordHit")
    if remote then
        SwordHitRemote = remote
        return remote
    end
    
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            local name = child.Name:lower()
            if name == "swordhit" or name == "attackentity" then
                SwordHitRemote = child
                return child
            end
        end
    end
    
    return nil
end

local function GetWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local handInv = char:FindFirstChild("HandInvItem")
    if handInv and handInv.Value then
        return handInv.Value
    end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        return tool
    end
    
    return nil
end

local function HasLineOfSight(targetChar)
    if not WALL_CHECK then return true end
    
    local char = LocalPlayer.Character
    if not char then return false end
    
    local origin = char:FindFirstChild("Head")
    if not origin then
        origin = char:FindFirstChild("HumanoidRootPart")
    end
    
    local target = targetChar:FindFirstChild("Head")
    if not target then
        target = targetChar:FindFirstChild("HumanoidRootPart")
    end
    
    if not origin or not target then return false end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, targetChar}
    params.IgnoreWater = true
    
    local direction = target.Position - origin.Position
    local result = Workspace:Raycast(origin.Position, direction, params)
    
    if result and result.Instance and result.Instance.CanCollide then
        return false
    end
    
    return true
end

local function IsInFOV(targetChar)
    local camera = Workspace.CurrentCamera
    if not camera then return true end
    
    local char = LocalPlayer.Character
    if not char then return false end
    
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    local targetHead = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    
    if not head or not targetHead then return false end
    
    local lookVector = camera.CFrame.LookVector
    local dirToTarget = (targetHead.Position - head.Position).Unit
    local dotProduct = lookVector:Dot(dirToTarget)
    local angle = math.deg(math.acos(dotProduct))
    
    return angle <= FOV
end

local function GetClosestTarget()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, 999 end
    
    local closestTarget = nil
    local closestDist = RANGE
    
    local players = Players:GetPlayers()
    for i = 1, #players do
        local player = players[i]
        if player ~= LocalPlayer then
            
            local playerTeam = player.Team
            local myTeam = LocalPlayer.Team
            if myTeam and playerTeam and myTeam == playerTeam then
            else
                local targetChar = player.Character
                if targetChar then
                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    local humanoid = targetChar:FindFirstChild("Humanoid")
                    
                    if targetHrp and humanoid and humanoid.Health > 0 then
                        local dist = (hrp.Position - targetHrp.Position).Magnitude
                        if dist < closestDist then
                            local inFOV = IsInFOV(targetChar)
                            local canSee = true
                            if WALL_CHECK then
                                canSee = HasLineOfSight(targetChar)
                            end
                            if inFOV and canSee then
                                closestDist = dist
                                closestTarget = targetChar
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestTarget, closestDist
end

local function Attack(target, dist)
    local remote = GetSwordRemote()
    if not remote then return end
    
    local weapon = GetWeapon()
    if not weapon then return end
    
    local targetHrp = target:FindFirstChild("HumanoidRootPart")
    if not targetHrp then targetHrp = target.PrimaryPart end
    if not targetHrp then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local direction = (targetHrp.Position - hrp.Position).Unit
    local spoofedSelfPos = hrp.Position
    
    if dist > 14 then
        spoofedSelfPos = targetHrp.Position - (direction * 13.5)
    end
    
    local args = {
        {
            chargedAttack = { chargeRatio = 0 },
            entityInstance = target,
            validate = {
                targetPosition = { value = Vector3.new(targetHrp.Position.X, targetHrp.Position.Y, targetHrp.Position.Z) },
                selfPosition = { value = Vector3.new(spoofedSelfPos.X, spoofedSelfPos.Y, spoofedSelfPos.Z) },
                raycast = {
                    cameraPosition = { value = Vector3.new(spoofedSelfPos.X, spoofedSelfPos.Y + 3, spoofedSelfPos.Z) },
                    cursorDirection = { value = Vector3.new(direction.X, direction.Y, direction.Z) }
                }
            },
            weapon = weapon
        }
    }
    
    local success, err = pcall(function()
        remote:FireServer(unpack(args))
    end)
    
    if not success then
        pcall(function()
            remote:FireServer(target)
        end)
    end
    
    if AUTO_CLICK then
        task.spawn(function()
            if isSimulatingClick then return end
            isSimulatingClick = true
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
            isSimulatingClick = false
        end)
    end
end

local connection = nil

local function StartKillaura()
    if connection then return end
    
    connection = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        
        local now = tick()
        if now - lastCheckTime < CHECK_DELAY then return end
        lastCheckTime = now
        
        if math.random(1, 100) > HIT_CHANCE then return end
        
        local target, dist = GetClosestTarget()
        if target then
            Attack(target, dist)
        end
    end)
end

local function StopKillaura()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

local function Toggle()
    enabled = not enabled
    UpdateIndicator()
    
    if enabled then
        StartKillaura()
    else
        StopKillaura()
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Z then
        Toggle()
    end
end)

UpdateIndicator()
print("BedWars Killaura - Press Z")
