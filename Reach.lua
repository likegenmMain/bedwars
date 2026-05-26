-- REACH - Увеличение дальности ударов (активация по V)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- НАСТРОЙКИ
local Settings = {
    Enabled = true,           -- Включен по умолчанию
    Distance = 18,            -- Максимальная дальность удара (студий)
    FOV = 36,                 -- Угол обзора (0-180, меньше = точнее)
    Cooldown = 0.12,          -- Задержка между ударами (сек)
    WallCheck = false,        -- Проверять ли стены
    SpoofDistance = 14,       -- На какую дистанцию обманывать сервер
    ToggleKey = Enum.KeyCode.V
}

-- GUI ИНДИКАТОР
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ReachIndicator"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 100, 0, 30)
indicator.Position = UDim2.new(1, -110, 0, 210)
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
statusText.Text = "REACH ON"
statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 11
statusText.Parent = indicator

local function UpdateIndicator()
    if Settings.Enabled then
        statusText.Text = "REACH ON"
        statusText.TextColor3 = Color3.new(0.4, 1, 0.4)
        indicator.BackgroundColor3 = Color3.new(0, 0.5, 0)
    else
        statusText.Text = "REACH OFF"
        statusText.TextColor3 = Color3.new(1, 0.4, 0.4)
        indicator.BackgroundColor3 = Color3.new(0.5, 0, 0)
    end
end

-- ПОИСК REMOTE
local SwordHitRemote = nil

local function GetSwordRemote()
    if SwordHitRemote and SwordHitRemote.Parent then return SwordHitRemote end
    
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

-- ПОЛУЧЕНИЕ ОРУЖИЯ
local function GetWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local handInv = char:FindFirstChild("HandInvItem")
    if handInv and handInv.Value then
        return handInv.Value
    end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local name = tool.Name:lower()
        if name:find("sword") or name:find("blade") or name:find("scythe") then
            return tool
        end
    end
    
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local name = v.Name:lower()
            if name:find("sword") or name:find("blade") then
                return v
            end
        end
    end
    
    return nil
end

-- ПРОВЕРКА ЛИНИИ ОБЗОРА
local function HasLineOfSight(targetChar)
    if not Settings.WallCheck then return true end
    
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

-- ПРОВЕРКА FOV
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
    local dot = lookVector:Dot(dirToTarget)
    local angle = math.deg(math.acos(dot))
    
    return angle <= (Settings.FOV / 2)
end

-- ПОИСК БЛИЖАЙШЕЙ ЦЕЛИ
local function GetClosestTarget()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local closestTarget = nil
    local closestDist = Settings.Distance
    
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

-- АТАКА
local lastHitTime = 0

local function PerformReach()
    if not Settings.Enabled then return end
    
    local now = tick()
    if now - lastHitTime < Settings.Cooldown then return end
    
    local remote = GetSwordRemote()
    if not remote then return end
    
    local weapon = GetWeapon()
    if not weapon then return end
    
    local target, dist = GetClosestTarget()
    if not target then return end
    
    local targetHrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not targetHrp then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    lastHitTime = now
    
    local direction = (targetHrp.Position - hrp.Position).Unit
    local spoofedSelfPos = hrp.Position
    
    if dist > Settings.SpoofDistance then
        spoofedSelfPos = targetHrp.Position - (direction * Settings.SpoofDistance)
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

-- ОТСЛЕЖИВАНИЕ КЛИКА ЛКМ
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not Settings.Enabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        PerformReach()
    end
end)

-- ВКЛ/ВЫКЛ ПО КЛАВИШЕ
local function Toggle()
    Settings.Enabled = not Settings.Enabled
    UpdateIndicator()
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Settings.ToggleKey then
        Toggle()
    end
end)

UpdateIndicator()
