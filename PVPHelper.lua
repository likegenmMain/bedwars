local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local enabled = true
local lastAttackTime = 0
local isManualAttacking = false
local clickTriggered = false

local RANGE = 25
local DELAY = 0.05
local WALL_CHECK = false
local REQUIRE_AIM = false
local HIT_CHANCE = 100
local FOV = 360
local EXTRA_DAMAGE = true
local EXTRA_KNOCKBACK = true

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PVPHelperIndicator"
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
statusText.Text = "PVP HELPER ON"
statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 11
statusText.Parent = indicator

local function UpdateIndicator()
    if enabled then
        statusText.Text = "PVP HELPER ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "PVP HELPER OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

local function HasSwordInHand()
    local char = LocalPlayer.Character
    if not char then return false end
    
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local name = v.Name:lower()
            if name:find("sword") or name:find("blade") or name:find("scythe") or name:find("melee") then
                return true
            end
        end
    end
    
    return false
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not enabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if HasSwordInHand() then
            clickTriggered = true
            isManualAttacking = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isManualAttacking = false
    end
end)

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
    
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local name = v.Name:lower()
            if name:find("sword") or name:find("blade") or name:find("scythe") then
                return v
            end
        end
    end
    
    return nil
end

local function HasLineOfSight(targetChar)
    if not WALL_CHECK then return true end
    
    local char = LocalPlayer.Character
    if not char then return false end
    
    local origin = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    local target = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    if not origin or not target then return false end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, targetChar}
    params.IgnoreWater = true
    
    local result = Workspace:Raycast(origin.Position, target.Position - origin.Position, params)
    return not (result and result.Instance and result.Instance.CanCollide)
end

local function IsInFOV(targetChar)
    if not REQUIRE_AIM then return true end
    
    local camera = Workspace.CurrentCamera
    if not camera then return true end
    
    local char = LocalPlayer.Character
    if not char then return false end
    
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    local targetHead = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    if not head or not targetHead then return false end
    
    local lookVector = camera.CFrame.LookVector
    local dirToTarget = (targetHead.Position - head.Position).Unit
    local angle = math.deg(math.acos(lookVector:Dot(dirToTarget)))
    return angle <= FOV
end

local function GetClosestTarget()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, 999 end
    
    local closestTarget = nil
    local closestDist = RANGE
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local myTeam = LocalPlayer.Team
            local playerTeam = player.Team
            if myTeam and playerTeam and myTeam == playerTeam then
            else
                local targetChar = player.Character
                if targetChar then
                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    local humanoid = targetChar:FindFirstChild("Humanoid")
                    
                    if targetHrp and humanoid and humanoid.Health > 0 then
                        local dist = (hrp.Position - targetHrp.Position).Magnitude
                        if dist < closestDist and IsInFOV(targetChar) and HasLineOfSight(targetChar) then
                            closestDist = dist
                            closestTarget = targetChar
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
    
    local targetHrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not targetHrp then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if math.random(1, 100) > HIT_CHANCE then return end
    
    local direction = (targetHrp.Position - hrp.Position).Unit
    local spoofedSelfPos = hrp.Position
    
    if dist > 14 then
        spoofedSelfPos = targetHrp.Position - (direction * 13.5)
    end
    
    local args = {
        {
            chargedAttack = { chargeRatio = EXTRA_DAMAGE and 1 or 0 },
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
    
    if EXTRA_KNOCKBACK then
        args[1].extraKnockback = true
    end
    
    pcall(function()
        remote:FireServer(unpack(args))
    end)
end

local connection = nil

local function Start()
    if connection then return end
    connection = RunService.Heartbeat:Connect(function()
        if not enabled then return end
        if not isManualAttacking and not clickTriggered then return end
        if not HasSwordInHand() then return end
        
        local now = tick()
        if now - lastAttackTime < DELAY then return end
        
        local target, dist = GetClosestTarget()
        if target then
            lastAttackTime = now
            Attack(target, dist)
            clickTriggered = false
        end
    end)
end

local function Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

local function Toggle()
    enabled = not enabled
    UpdateIndicator()
    if enabled then Start() else Stop() end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Z then
        Toggle()
    end
end)

Start()
UpdateIndicator()
