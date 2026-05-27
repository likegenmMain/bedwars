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
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
}

local Tabs = {
    Combat = Window:CreateTab{Title = "Combat", Icon = "phosphor-crosshair-bold"},
    Blatant = Window:CreateTab{Title = "Blatant", Icon = "phosphor-wrench-bold"},
    Auto = Window:CreateTab{Title = "Auto", Icon = "phosphor-play-bold"},
    Visual = Window:CreateTab{Title = "Visual", Icon = "phosphor-eye-bold"},
    Settings = Window:CreateTab{Title = "Settings", Icon = "settings"}
}

local Options = Library.Options

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CollectionService = game:GetService("CollectionService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local killauraEnabled = false
local killauraRange = 25
local killauraDelay = 0.01
local killauraWallCheck = false
local killauraRequireAim = false
local killauraHitChance = 100
local killauraFOV = 360
local killauraAutoClick = true
local killauraLastAttack = 0
local killauraLastCheck = 0
local killauraConnection = nil
local isSimulatingClick = false
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
    
    if killauraAutoClick then
        task.spawn(function()
            if isSimulatingClick then return end
            isSimulatingClick = true
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
            isSimulatingClick = false
        end)
    end
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
Tabs.Combat:CreateToggle("KillauraAutoClick", {Title = "Auto Click", Default = true}):OnChanged(function(v) killauraAutoClick = v end)
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
                    if dist < closestDist and HasLineOfSight(targetChar) then
                        closestDist = dist; closestTarget = targetChar
                    end
                end
            end
        end
    end
    return closestTarget, closestDist
end

local function PVPAttack(target, dist)
    local remote = GetSwordRemote()
    if not remote then return end
    local weapon = GetWeapon()
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

local reachEnabled = false
local reachDistance = 18
local reachFOV = 36
local reachCooldown = 0.12
local reachWallCheck = false
local reachSpoofDistance = 14
local reachLastHit = 0

local function ReachGetClosestTarget()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closestTarget = nil
    local closestDist = reachDistance
    local camera = Workspace.CurrentCamera
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
                    if dist < closestDist then
                        if camera then
                            local lookVector = camera.CFrame.LookVector
                            local dirToTarget = (targetHrp.Position - hrp.Position).Unit
                            local angle = math.deg(math.acos(lookVector:Dot(dirToTarget)))
                            if angle <= (reachFOV / 2) then
                                if not reachWallCheck or HasLineOfSight(targetChar) then
                                    closestDist = dist; closestTarget = targetChar
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closestTarget, closestDist
end

local function PerformReach()
    local now = tick()
    if now - reachLastHit < reachCooldown then return end
    local remote = GetSwordRemote()
    if not remote then return end
    local weapon = GetWeapon()
    if not weapon then return end
    local target, dist = ReachGetClosestTarget()
    if not target then return end
    local targetHrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not targetHrp then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    reachLastHit = now
    local direction = (targetHrp.Position - hrp.Position).Unit
    local spoofedSelfPos = hrp.Position
    if dist > reachSpoofDistance then spoofedSelfPos = targetHrp.Position - (direction * reachSpoofDistance) end
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
    pcall(function() remote:FireServer(unpack(args)) end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not reachEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then PerformReach() end
end)

Tabs.Combat:CreateSection("Reach")
Tabs.Combat:CreateToggle("Reach", {Title = "Reach", Default = false}):OnChanged(function(v) reachEnabled = v end)
Tabs.Combat:CreateSlider("ReachDistance", {Title = "Distance", Default = 18, Min = 14, Max = 30, Rounding = 0}):OnChanged(function(v) reachDistance = v end)
Tabs.Combat:CreateSlider("ReachFOV", {Title = "FOV", Default = 36, Min = 10, Max = 180, Rounding = 0}):OnChanged(function(v) reachFOV = v end)
Tabs.Combat:CreateSlider("ReachCooldown", {Title = "Cooldown", Default = 0.12, Min = 0, Max = 1, Rounding = 2}):OnChanged(function(v) reachCooldown = v end)
Tabs.Combat:CreateToggle("ReachWallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) reachWallCheck = v end)
Tabs.Combat:CreateSlider("ReachSpoof", {Title = "Spoof Distance", Default = 14, Min = 10, Max = 20, Rounding = 0}):OnChanged(function(v) reachSpoofDistance = v end)

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

local triggerBotEnabled = false
local triggerBotDelay = 0.05
local triggerBotLastAttack = 0
local triggerBotConnection = nil

local function GetTargetUnderCrosshair()
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

local function TriggerAttack(target)
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
    if dist > 14 then spoofedSelfPos = targetHrp.Position - (direction * 13.5) end
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
    pcall(function() remote:FireServer(unpack(args)) end)
end

local function TriggerLoop()
    if not triggerBotEnabled then return end
    local now = tick()
    if now - triggerBotLastAttack < triggerBotDelay then return end
    local target = GetTargetUnderCrosshair()
    if target then triggerBotLastAttack = now; TriggerAttack(target) end
end

local function StartTriggerBot()
    if triggerBotConnection then return end
    triggerBotConnection = RunService.Heartbeat:Connect(TriggerLoop)
end

local function StopTriggerBot()
    if triggerBotConnection then triggerBotConnection:Disconnect(); triggerBotConnection = nil end
end

Tabs.Combat:CreateSection("Trigger Bot")
Tabs.Combat:CreateToggle("TriggerBot", {Title = "Trigger Bot", Default = false}):OnChanged(function(v) triggerBotEnabled = v; if v then StartTriggerBot() else StopTriggerBot() end end)
Tabs.Combat:CreateSlider("TriggerBotDelay", {Title = "Delay", Default = 0.05, Min = 0, Max = 1, Rounding = 2}):OnChanged(function(v) triggerBotDelay = v end)

local scaffoldEnabled = false
local scaffoldGridSize = 3
local scaffoldDelay = 0.05
local scaffoldYOffset = -3.5
local scaffoldPredict = 0.15
local scaffoldLastPlace = 0
local scaffoldConnection = nil
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
    return Vector3.new(
        math.floor(v3.X / scaffoldGridSize + 0.5) * scaffoldGridSize,
        math.floor(v3.Y / scaffoldGridSize + 0.5) * scaffoldGridSize,
        math.floor(v3.Z / scaffoldGridSize + 0.5) * scaffoldGridSize
    )
end

local function ScaffoldLoop()
    if not scaffoldEnabled then return end
    if not PlaceBlockRemote then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local now = tick()
    if now - scaffoldLastPlace < scaffoldDelay then return end
    local wool = getWoolName()
    if not wool then return end
    local moveDir = hrp.Velocity * Vector3.new(1, 0, 1)
    local predictPos = hrp.Position + (moveDir * scaffoldPredict)
    local targetPos = predictPos + Vector3.new(0, scaffoldYOffset, 0)
    local gridPos = snapToGrid(targetPos)
    local bx = math.floor(gridPos.X / scaffoldGridSize)
    local by = math.floor(gridPos.Y / scaffoldGridSize)
    local bz = math.floor(gridPos.Z / scaffoldGridSize)
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
    task.spawn(function() pcall(function() PlaceBlockRemote:InvokeServer(unpack(args)) end) end)
    scaffoldLastPlace = now
end

local function StartScaffold()
    if scaffoldConnection then return end
    scaffoldConnection = RunService.Heartbeat:Connect(ScaffoldLoop)
end

local function StopScaffold()
    if scaffoldConnection then scaffoldConnection:Disconnect(); scaffoldConnection = nil end
end

Tabs.Blatant:CreateSection("Scaffold")
Tabs.Blatant:CreateToggle("Scaffold", {Title = "Scaffold", Default = false}):OnChanged(function(v) scaffoldEnabled = v; if v then StartScaffold() else StopScaffold() end end)

local speedHackEnabled = false
local speedHackValue = 21
local speedHackConnection = nil

local function SpeedHackLoop()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local look = Camera.CFrame.LookVector
    local right = Camera.CFrame.RightVector
    local mv = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += Vector3.new(look.X, 0, look.Z).Unit end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv -= Vector3.new(look.X, 0, look.Z).Unit end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv -= Vector3.new(right.X, 0, right.Z).Unit end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += Vector3.new(right.X, 0, right.Z).Unit end
    if mv.Magnitude > 0 then
        hrp.Velocity = Vector3.new(mv.X * speedHackValue, hrp.Velocity.Y, mv.Z * speedHackValue)
    end
end

local function StartSpeedHack()
    if speedHackConnection then return end
    speedHackConnection = RunService.Heartbeat:Connect(SpeedHackLoop)
end
local function StopSpeedHack()
    if speedHackConnection then speedHackConnection:Disconnect(); speedHackConnection = nil end
end

Tabs.Blatant:CreateSection("SpeedHack")
Tabs.Blatant:CreateToggle("SpeedHack", {Title = "SpeedHack", Default = false}):OnChanged(function(v) speedHackEnabled = v; if v then StartSpeedHack() else StopSpeedHack() end end)
Tabs.Blatant:CreateSlider("SpeedHackValue", {Title = "Speed", Default = 21, Min = 21, Max = 23, Rounding = 0}):OnChanged(function(v) speedHackValue = v end)

local flyEnabled = false
local flySpeed = 50
local flyConnection = nil

local function FlyLoop()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
    hrp.Velocity = Vector3.new(hrp.Velocity.X, dir.Y * flySpeed, hrp.Velocity.Z)
end

local function StartFly()
    if flyConnection then return end
    workspace.Gravity = 0
    flyConnection = RunService.Heartbeat:Connect(FlyLoop)
end

local function StopFly()
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    workspace.Gravity = 196.2
end

Tabs.Blatant:CreateSection("Fly")
Tabs.Blatant:CreateToggle("Fly", {Title = "Fly", Default = false}):OnChanged(function(v) flyEnabled = v; if v then StartFly() else StopFly() end end)
Tabs.Blatant:CreateSlider("FlySpeed", {Title = "Speed", Default = 50, Min = 30, Max = 200, Rounding = 0}):OnChanged(function(v) flySpeed = v end)

local infJumpsEnabled = false
local infJumpsConnection = nil

local function StartInfJumps()
    if infJumpsConnection then return end
    infJumpsConnection = UserInputService.JumpRequest:Connect(function()
        if not infJumpsEnabled then return end
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, 50, hrp.Velocity.Z)
            end
        end
    end)
end

local function StopInfJumps()
    if infJumpsConnection then infJumpsConnection:Disconnect(); infJumpsConnection = nil end
end

Tabs.Blatant:CreateSection("Inf Jumps")
Tabs.Blatant:CreateToggle("InfJumps", {Title = "Inf Jumps", Default = false}):OnChanged(function(v) infJumpsEnabled = v; if v then StartInfJumps() else StopInfJumps() end end)

local chestStealEnabled = false
local chestStealRange = 30
local chestStealDelay = 0.1
local chestStealLastCheck = 0
local chestStealConnection = nil
local ChestRemote = nil

local function GetChestRemote()
    if ChestRemote then return ChestRemote end
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if child:IsA("RemoteFunction") and child.Name:find("ChestGetItem") then
            ChestRemote = child; return child
        end
    end
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if child:IsA("RemoteFunction") and (child.Name:lower():find("chest") or child.Name:lower():find("loot")) then
            ChestRemote = child; return child
        end
    end
    return nil
end

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
            task.spawn(function() pcall(function() remote:InvokeServer(inventoryFolder, item) end) end)
            task.wait(0.05)
        end
    end
end

local function ChestStealLoop()
    if not chestStealEnabled then return end
    local remote = GetChestRemote()
    if not remote then return end
    local now = tick()
    if now - chestStealLastCheck < chestStealDelay then return end
    chestStealLastCheck = now
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local chests = CollectionService:GetTagged("chest")
    for _, chest in ipairs(chests) do
        if chest:IsA("BasePart") or chest:IsA("Model") then
            local chestPos = chest:IsA("BasePart") and chest.Position or (chest.PrimaryPart and chest.PrimaryPart.Position)
            if chestPos then
                local dist = (chestPos - root.Position).Magnitude
                if dist <= chestStealRange then
                    task.spawn(function() StealFromChest(chest) end)
                end
            end
        end
    end
end

local function StartChestSteal()
    if chestStealConnection then return end
    chestStealConnection = RunService.Heartbeat:Connect(ChestStealLoop)
end

local function StopChestSteal()
    if chestStealConnection then chestStealConnection:Disconnect(); chestStealConnection = nil end
end

Tabs.Blatant:CreateSection("Chest Stealer")
Tabs.Blatant:CreateToggle("ChestSteal", {Title = "Chest Stealer", Default = false}):OnChanged(function(v) chestStealEnabled = v; if v then StartChestSteal() else StopChestSteal() end end)
Tabs.Blatant:CreateSlider("ChestStealRange", {Title = "Range", Default = 30, Min = 5, Max = 50, Rounding = 0}):OnChanged(function(v) chestStealRange = v end)

local antiVoidEnabled = false
local antiVoidHeight = 50
local antiVoidRainbow = true
local antiVoidColor = Color3.fromRGB(255, 0, 0)
local antiVoidTransparency = 0.3
local antiVoidPlatform = nil
local antiVoidConnection = nil
local antiVoidTouched = nil
local antiVoidColorConnection = nil
local antiVoidHue = 0

local function CreateAntiVoidPlatform()
    if antiVoidPlatform then antiVoidPlatform:Destroy() end
    antiVoidPlatform = Instance.new("Part")
    antiVoidPlatform.Name = "AntiVoidPlatform"
    antiVoidPlatform.Size = Vector3.new(2048, 5, 2048)
    antiVoidPlatform.Position = Vector3.new(0, antiVoidHeight, 0)
    antiVoidPlatform.Anchored = true
    antiVoidPlatform.CanCollide = false
    antiVoidPlatform.Transparency = antiVoidTransparency
    antiVoidPlatform.CastShadow = false
    antiVoidPlatform.CanQuery = false
    antiVoidPlatform.Material = Enum.Material.Neon
    antiVoidPlatform.Parent = Workspace
    
    if antiVoidTouched then antiVoidTouched:Disconnect() end
    antiVoidTouched = antiVoidPlatform.Touched:Connect(function(hit)
        local char = LocalPlayer.Character
        if not char then return end
        local humanoid = char:FindFirstChild("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if humanoid and rootPart and hit.Parent == char then
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 100, rootPart.Velocity.Z)
        end
    end)
    
    if antiVoidColorConnection then antiVoidColorConnection:Disconnect() end
    antiVoidColorConnection = RunService.Heartbeat:Connect(function()
        if not antiVoidPlatform then return end
        antiVoidPlatform.Position = Vector3.new(0, antiVoidHeight, 0)
        antiVoidPlatform.Transparency = antiVoidTransparency
        if antiVoidRainbow then
            antiVoidHue = (antiVoidHue + 0.0002) % 1
            antiVoidPlatform.Color = Color3.fromHSV(antiVoidHue, 1, 1)
        else
            antiVoidPlatform.Color = antiVoidColor
        end
    end)
end

local function StartAntiVoid()
    if antiVoidConnection then return end
    CreateAntiVoidPlatform()
    antiVoidConnection = RunService.Heartbeat:Connect(function()
        if not antiVoidEnabled then return end
        if not antiVoidPlatform or not antiVoidPlatform.Parent then CreateAntiVoidPlatform() end
    end)
end

local function StopAntiVoid()
    if antiVoidConnection then antiVoidConnection:Disconnect(); antiVoidConnection = nil end
    if antiVoidTouched then antiVoidTouched:Disconnect(); antiVoidTouched = nil end
    if antiVoidColorConnection then antiVoidColorConnection:Disconnect(); antiVoidColorConnection = nil end
    if antiVoidPlatform then antiVoidPlatform:Destroy(); antiVoidPlatform = nil end
end

Tabs.Blatant:CreateSection("Anti Void")
Tabs.Blatant:CreateToggle("AntiVoid", {Title = "Anti Void", Default = false}):OnChanged(function(v) antiVoidEnabled = v; if v then StartAntiVoid() else StopAntiVoid() end end)
Tabs.Blatant:CreateSlider("AntiVoidHeight", {Title = "Height", Default = 50, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) antiVoidHeight = v end)
Tabs.Blatant:CreateToggle("AntiVoidRainbow", {Title = "Rainbow", Default = true}):OnChanged(function(v) antiVoidRainbow = v end)
Tabs.Blatant:CreateColorpicker("AntiVoidColor", {Title = "Color", Default = Color3.fromRGB(255, 0, 0)}):OnChanged(function(v) antiVoidColor = v end)
Tabs.Blatant:CreateSlider("AntiVoidTransparency", {Title = "Transparency", Default = 0.3, Min = 0, Max = 1, Rounding = 2}):OnChanged(function(v) antiVoidTransparency = v end)

local autoPlayEnabled = false
local autoPlayMode = "queue_16v16"
local autoPlayConnection = nil
local autoPlayRemote = nil
local autoPlayLastJoin = 0

task.spawn(function()
    while not autoPlayRemote do
        pcall(function()
            autoPlayRemote = ReplicatedStorage:WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events", 5):WaitForChild("joinQueue", 5)
        end)
        if not autoPlayRemote then task.wait(5) end
    end
end)

local function isLobby()
    return ReplicatedStorage:FindFirstChild("Lobby") ~= nil or game.PlaceId == 6872265039
end

local function AutoPlayLoop()
    if not autoPlayEnabled then return end
    if tick() - autoPlayLastJoin < 10 then return end
    if isLobby() and autoPlayRemote then
        autoPlayLastJoin = tick()
        local modeMap = {
            ["queue_16v16"] = "bedwars_16v16",
            ["queue_to4"] = "bedwars_to4",
            ["queue_to2"] = "bedwars_duels",
            ["queue_to1"] = "winstreak_1v1",
            ["queue_5v5"] = "bedwars_5v5",
            ["queue_skywars"] = "skywars_to2"
        }
        local args = {{queueType = modeMap[autoPlayMode] or "winstreak_1v1"}}
        pcall(function() autoPlayRemote:FireServer(unpack(args)) end)
    end
end

local function StartAutoPlay()
    if autoPlayConnection then return end
    autoPlayConnection = RunService.Heartbeat:Connect(AutoPlayLoop)
end

local function StopAutoPlay()
    if autoPlayConnection then autoPlayConnection:Disconnect(); autoPlayConnection = nil end
end

Tabs.Auto:CreateSection("Auto Play")
Tabs.Auto:CreateToggle("AutoPlay", {Title = "Auto Play", Default = false}):OnChanged(function(v) autoPlayEnabled = v; if v then StartAutoPlay() else StopAutoPlay() end end)
Tabs.Auto:CreateDropdown("AutoPlayMode", {Title = "Mode", Values = {"queue_16v16", "queue_to4", "queue_to2", "queue_to1", "queue_5v5", "queue_skywars"}, Default = "queue_16v16"}):OnChanged(function(v) autoPlayMode = v end)

local espEnabled = false
local tracersEnabled = false
local fovValue = 120
local nametagsEnabled = false
local metalESPEnabled = false
local espHighlights = {}
local tracerLines = {}
local nametagBGs = {}
local metalESPConnection = nil
local metalRefreshConnection = nil

local function getTeamColor(player)
    local team = player.Team
    if team then return team.TeamColor.Color end
    return Color3.fromRGB(255, 255, 255)
end

local function isShopItem(v)
    if not v then return false end
    if not v:IsDescendantOf(Workspace) then return true end
    if v:FindFirstAncestorOfClass("ViewportFrame") then return true end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg and v:IsDescendantOf(pg) then return true end
    local map = Workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("Shops") and v:IsDescendantOf(map.Shops) then return true end
    return false
end

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
end

local function UpdateMetalESP()
    if not metalESPEnabled then
        for _, m in ipairs(CollectionService:GetTagged("hidden-metal")) do
            pcall(function()
                if m:FindFirstChild("MetalESP_Highlight") then m.MetalESP_Highlight:Destroy() end
            end)
        end
        return
    end
    for _, m in ipairs(CollectionService:GetTagged("hidden-metal")) do
        if not isShopItem(m) then AddMetalESP(m) end
    end
end

local function StartMetalESP()
    if metalESPConnection then return end
    metalESPConnection = CollectionService:GetInstanceAddedSignal("hidden-metal"):Connect(function(m)
        if metalESPEnabled and not isShopItem(m) then AddMetalESP(m) end
    end)
    metalRefreshConnection = RunService.Heartbeat:Connect(function()
        if metalESPEnabled then
            local now = tick()
            if not metalRefreshConnection.lastUpdate or now - metalRefreshConnection.lastUpdate >= 1 then
                metalRefreshConnection.lastUpdate = now
                UpdateMetalESP()
            end
        end
    end)
    UpdateMetalESP()
end

local function StopMetalESP()
    if metalESPConnection then metalESPConnection:Disconnect(); metalESPConnection = nil end
    if metalRefreshConnection then metalRefreshConnection:Disconnect(); metalRefreshConnection = nil end
    UpdateMetalESP()
end

local function updateESP()
    for _, h in pairs(espHighlights) do h:Destroy() end; table.clear(espHighlights)
    for _, l in pairs(tracerLines) do l:Remove() end; table.clear(tracerLines)
    for _, bg in pairs(nametagBGs) do bg:Destroy() end; table.clear(nametagBGs)
    
    if not (espEnabled or tracersEnabled or nametagsEnabled) then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            local color = getTeamColor(player)
            
            if head then
                local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                
                if espEnabled then
                    local hl = Instance.new("Highlight"); hl.Parent = player.Character
                    hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.FillColor = color; hl.Enabled = true
                    espHighlights[player] = hl
                end
                
                if tracersEnabled and onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local line = Drawing.new("Line")
                    line.From = Vector2.new(mousePos.X, mousePos.Y)
                    line.To = Vector2.new(pos.X, pos.Y); line.Color = color
                    line.Thickness = 3; line.Transparency = 0.5; line.Visible = true
                    tracerLines[player] = line
                end
                
                if nametagsEnabled then
                    local bg = Instance.new("BillboardGui"); bg.Size = UDim2.new(0, 100, 0, 30)
                    bg.StudsOffset = Vector3.new(0, 2.5, 0); bg.AlwaysOnTop = true; bg.Parent = head
                    local label = Instance.new("TextLabel"); label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1; label.Text = player.Name
                    label.TextColor3 = Color3.fromRGB(255, 255, 255)
                    label.TextStrokeTransparency = 0; label.TextSize = 14
                    label.Font = Enum.Font.GothamBold; label.Parent = bg
                    nametagBGs[player] = bg
                end
            end
        end
    end
end

Tabs.Visual:CreateSection("ESP")
Tabs.Visual:CreateToggle("ESP", {Title = "ESP", Default = false}):OnChanged(function(v) espEnabled = v end)
Tabs.Visual:CreateSection("Tracers")
Tabs.Visual:CreateToggle("Tracers", {Title = "Tracers", Default = false}):OnChanged(function(v) tracersEnabled = v end)
Tabs.Visual:CreateSection("FOV")
Tabs.Visual:CreateSlider("FOV", {Title = "FOV", Default = 120, Min = 30, Max = 120, Rounding = 0}):OnChanged(function(v) fovValue = v end)
Tabs.Visual:CreateSection("NameTags")
Tabs.Visual:CreateToggle("NameTags", {Title = "NameTags", Default = false}):OnChanged(function(v) nametagsEnabled = v end)
Tabs.Visual:CreateSection("Metal ESP")
Tabs.Visual:CreateToggle("MetalESP", {Title = "Metal ESP", Default = false}):OnChanged(function(v) metalESPEnabled = v; if v then StartMetalESP() else StopMetalESP() end end)

RunService.RenderStepped:Connect(function()
    Camera.FieldOfView = fovValue
    updateESP()
end)

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes{}
InterfaceManager:SetFolder("BedwarsScript | Likegenm")
SaveManager:SetFolder("Bedwars | Likegenm/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab("Blatant")
SaveManager:LoadAutoloadConfig()
