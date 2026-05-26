local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Bedwars",
    SubTitle = "by Likegenm",
    TabWidth = 160,
    Size = UDim2.fromOffset(830, 525),
    Resize = true,
    MinSize = Vector2.new(470, 380),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
}

local Tabs = {
    Combat = Window:CreateTab{Title = "Combat", Icon = "phosphor-crosshair-bold"},
    Settings = Window:CreateTab{Title = "Settings", Icon = "settings"}
}

local Options = Library.Options

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local killauraEnabled = false
local killauraRange = 25
local killauraDelay = 0.01
local killauraWallCheck = false
local killauraRequireAim = false
local killauraHitChance = 100
local killauraFOV = 360
local killauraLastAttack = 0
local killauraLastCheck = 0
local killauraConnection = nil
local SwordHitRemote = nil

local function GetSwordRemote()
    if SwordHitRemote and SwordHitRemote.Parent then return SwordHitRemote end
    local remote = ReplicatedStorage:FindFirstChild("SwordHit")
    if remote then SwordHitRemote = remote; return remote end
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            local name = child.Name:lower()
            if name == "swordhit" or name == "attackentity" then
                SwordHitRemote = child; return child
            end
        end
    end
    return nil
end

local function GetWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    local handInv = char:FindFirstChild("HandInvItem")
    if handInv and handInv.Value then return handInv.Value end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    return nil
end

local function HasLineOfSight(targetChar)
    if not killauraWallCheck then return true end
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
    if not killauraRequireAim then return true end
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
    return angle <= killauraFOV
end

local function GetClosestTarget()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, 999 end
    local closestTarget = nil
    local closestDist = killauraRange
    local myTeam = LocalPlayer.Team
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if myTeam and player.Team and myTeam == player.Team then continue end
            local targetChar = player.Character
            if targetChar then
                local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                local humanoid = targetChar:FindFirstChild("Humanoid")
                if targetHrp and humanoid and humanoid.Health > 0 then
                    local dist = (hrp.Position - targetHrp.Position).Magnitude
                    if dist < closestDist and IsInFOV(targetChar) and HasLineOfSight(targetChar) then
                        closestDist = dist; closestTarget = targetChar
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
    local now = tick()
    if now - killauraLastAttack < killauraDelay then return end
    killauraLastAttack = now
    if math.random(1, 100) > killauraHitChance then return end
    local direction = (targetHrp.Position - hrp.Position).Unit
    local spoofedSelfPos = hrp.Position
    if dist > 14 then spoofedSelfPos = targetHrp.Position - (direction * 13.5) end
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
    pcall(function() remote:FireServer(unpack(args)) end)
end

local function StartKillaura()
    if killauraConnection then return end
    killauraConnection = RunService.Heartbeat:Connect(function()
        if not killauraEnabled then return end
        local now = tick()
        if now - killauraLastCheck < 0.01 then return end
        killauraLastCheck = now
        local target, dist = GetClosestTarget()
        if target then Attack(target, dist) end
    end)
end

local function StopKillaura()
    if killauraConnection then killauraConnection:Disconnect(); killauraConnection = nil end
end

Tabs.Combat:CreateSection("Killaura")
Tabs.Combat:CreateToggle("Killaura", {Title = "Killaura", Default = false}):OnChanged(function(v) killauraEnabled = v; if v then StartKillaura() else StopKillaura() end end)
Tabs.Combat:CreateSlider("KillauraRange", {Title = "Range", Default = 25, Min = 5, Max = 50, Rounding = 0}):OnChanged(function(v) killauraRange = v end)
Tabs.Combat:CreateSlider("KillauraDelay", {Title = "Delay", Default = 0.01, Min = 0, Max = 1, Rounding = 2}):OnChanged(function(v) killauraDelay = v end)
Tabs.Combat:CreateSlider("KillauraHitChance", {Title = "Hit Chance", Default = 100, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) killauraHitChance = v end)
Tabs.Combat:CreateSlider("KillauraFOV", {Title = "FOV", Default = 360, Min = 30, Max = 360, Rounding = 0}):OnChanged(function(v) killauraFOV = v end)
Tabs.Combat:CreateToggle("KillauraWallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) killauraWallCheck = v end)
Tabs.Combat:CreateToggle("KillauraRequireAim", {Title = "Require Aim", Default = false}):OnChanged(function(v) killauraRequireAim = v end)

local pvpHelperEnabled = false
local pvpHelperRange = 25
local pvpHelperDelay = 0.05
local pvpHelperWallCheck = false
local pvpHelperRequireAim = false
local pvpHelperHitChance = 100
local pvpHelperFOV = 360
local pvpHelperExtraDamage = true
local pvpHelperExtraKnockback = true
local pvpHelperLastAttack = 0
local isManualAttacking = false
local clickTriggered = false
local pvpHelperConnection = nil

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
    if not pvpHelperEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if HasSwordInHand() then clickTriggered = true; isManualAttacking = true end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isManualAttacking = false end
end)

local function PVPGetSwordRemote()
    if SwordHitRemote and SwordHitRemote.Parent then return SwordHitRemote end
    local remote = ReplicatedStorage:FindFirstChild("SwordHit")
    if remote then SwordHitRemote = remote; return remote end
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            local name = child.Name:lower()
            if name == "swordhit" or name == "attackentity" then
                SwordHitRemote = child; return child
            end
        end
    end
    return nil
end

local function PVPGetWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local name = v.Name:lower()
            if name:find("sword") or name:find("blade") or name:find("scythe") then return v end
        end
    end
    return nil
end

local function PVPHasLineOfSight(targetChar)
    if not pvpHelperWallCheck then return true end
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

local function PVPIsInFOV(targetChar)
    if not pvpHelperRequireAim then return true end
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
    return angle <= pvpHelperFOV
end

local function PVPGetClosestTarget()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, 999 end
    local closestTarget = nil
    local closestDist = pvpHelperRange
    local myTeam = LocalPlayer.Team
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if myTeam and player.Team and myTeam == player.Team then continue end
            local targetChar = player.Character
            if targetChar then
                local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                local humanoid = targetChar:FindFirstChild("Humanoid")
                if targetHrp and humanoid and humanoid.Health > 0 then
                    local dist = (hrp.Position - targetHrp.Position).Magnitude
                    if dist < closestDist and PVPIsInFOV(targetChar) and PVPHasLineOfSight(targetChar) then
                        closestDist = dist; closestTarget = targetChar
                    end
                end
            end
        end
    end
    return closestTarget, closestDist
end

local function PVPAttack(target, dist)
    local remote = PVPGetSwordRemote()
    if not remote then return end
    local weapon = PVPGetWeapon()
    if not weapon then return end
    local targetHrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not targetHrp then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if math.random(1, 100) > pvpHelperHitChance then return end
    local direction = (targetHrp.Position - hrp.Position).Unit
    local spoofedSelfPos = hrp.Position
    if dist > 14 then spoofedSelfPos = targetHrp.Position - (direction * 13.5) end
    local args = {
        {
            chargedAttack = { chargeRatio = pvpHelperExtraDamage and 1 or 0 },
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
    if pvpHelperExtraKnockback then args[1].extraKnockback = true end
    pcall(function() remote:FireServer(unpack(args)) end)
end

local function StartPVPHelper()
    if pvpHelperConnection then return end
    pvpHelperConnection = RunService.Heartbeat:Connect(function()
        if not pvpHelperEnabled then return end
        if not isManualAttacking and not clickTriggered then return end
        if not HasSwordInHand() then return end
        local now = tick()
        if now - pvpHelperLastAttack < pvpHelperDelay then return end
        local target, dist = PVPGetClosestTarget()
        if target then pvpHelperLastAttack = now; PVPAttack(target, dist); clickTriggered = false end
    end)
end

local function StopPVPHelper()
    if pvpHelperConnection then pvpHelperConnection:Disconnect(); pvpHelperConnection = nil end
end

Tabs.Combat:CreateSection("PVP Helper")
Tabs.Combat:CreateToggle("PVPHelper", {Title = "PVP Helper", Default = false}):OnChanged(function(v) pvpHelperEnabled = v; if v then StartPVPHelper() else StopPVPHelper() end end)
Tabs.Combat:CreateSlider("PVPHelperRange", {Title = "Range", Default = 25, Min = 5, Max = 50, Rounding = 0}):OnChanged(function(v) pvpHelperRange = v end)
Tabs.Combat:CreateSlider("PVPHelperDelay", {Title = "Delay", Default = 0.05, Min = 0, Max = 1, Rounding = 2}):OnChanged(function(v) pvpHelperDelay = v end)
Tabs.Combat:CreateSlider("PVPHelperHitChance", {Title = "Hit Chance", Default = 100, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) pvpHelperHitChance = v end)
Tabs.Combat:CreateSlider("PVPHelperFOV", {Title = "FOV", Default = 360, Min = 30, Max = 360, Rounding = 0}):OnChanged(function(v) pvpHelperFOV = v end)
Tabs.Combat:CreateToggle("PVPHelperWallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) pvpHelperWallCheck = v end)
Tabs.Combat:CreateToggle("PVPHelperRequireAim", {Title = "Require Aim", Default = false}):OnChanged(function(v) pvpHelperRequireAim = v end)
Tabs.Combat:CreateToggle("PVPHelperExtraDamage", {Title = "Extra Damage", Default = true}):OnChanged(function(v) pvpHelperExtraDamage = v end)
Tabs.Combat:CreateToggle("PVPHelperExtraKnockback", {Title = "Extra Knockback", Default = true}):OnChanged(function(v) pvpHelperExtraKnockback = v end)

local antiKBEnabled = false
local antiKBStrength = 0
local antiKBStepped = nil
local antiKBHeartbeat = nil

local allowedNames = {"VapeFlyVelocity", "VapeFlyGyro", "AntiVoidBV", "BedNukeBypass", "NoFallVelocity", "ScaffoldBV"}

local function PhysicsAntiKB()
    if not antiKBEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    for _, obj in pairs(hrp:GetChildren()) do
        if obj:IsA("BodyVelocity") or obj:IsA("LinearVelocity") or obj:IsA("BodyForce") or obj:IsA("BodyPosition") or obj:IsA("VectorForce") or obj:IsA("AlignPosition") then
            local allowed = false
            for _, name in ipairs(allowedNames) do
                if obj.Name == name then allowed = true; break end
            end
            if not allowed then pcall(function() obj:Destroy() end) end
        end
    end
    local currentVel = hrp.AssemblyLinearVelocity
    local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
    local walkSpeed = hum.WalkSpeed
    if horizontalVel.Magnitude > walkSpeed + 1 then
        local strengthMultiplier = antiKBStrength / 100
        local targetDir = hum.MoveDirection * walkSpeed
        local newHorizontal = horizontalVel:Lerp(targetDir, 1 - strengthMultiplier)
        hrp.AssemblyLinearVelocity = Vector3.new(newHorizontal.X, currentVel.Y, newHorizontal.Z)
    end
end

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
                            if antiKBEnabled then
                                local strength = antiKBStrength / 100
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
                            if antiKBEnabled then
                                local strength = antiKBStrength / 100
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

task.spawn(function() task.wait(2); HookKnockbackControllers() end)

local function StartAntiKB()
    if antiKBStepped then return end
    antiKBStepped = RunService.Stepped:Connect(PhysicsAntiKB)
    antiKBHeartbeat = RunService.Heartbeat:Connect(PhysicsAntiKB)
end

local function StopAntiKB()
    if antiKBStepped then antiKBStepped:Disconnect(); antiKBStepped = nil end
    if antiKBHeartbeat then antiKBHeartbeat:Disconnect(); antiKBHeartbeat = nil end
end

Tabs.Combat:CreateSection("Anti-Knockback")
Tabs.Combat:CreateToggle("AntiKB", {Title = "Anti-Knockback", Default = false}):OnChanged(function(v) antiKBEnabled = v; if v then StartAntiKB() else StopAntiKB() end end)
Tabs.Combat:CreateSlider("AntiKBStrength", {Title = "Strength", Default = 0, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) antiKBStrength = v end)

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes{}
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
