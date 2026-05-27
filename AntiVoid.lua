local player = game.Players.LocalPlayer
local rs = game:GetService("RunService")
local ts = game:GetService("TweenService")

local voidPart = Instance.new("Part")
voidPart.Name = "AntiVoid"
voidPart.Size = Vector3.new(2048, 5, 2048)
voidPart.Anchored = true
voidPart.CanCollide = true
voidPart.Transparency = 0.3
voidPart.Material = Enum.Material.Neon
voidPart.Parent = workspace

for _, v in ipairs(voidPart:GetChildren()) do
    if v:IsA("Decal") or v:IsA("Texture") then
        v:Destroy()
    end
end

rs.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    voidPart.Position = Vector3.new(hrp.Position.X, 50, hrp.Position.Z)
    voidPart.Color = Color3.fromHSV(tick() % 5 / 5, 1, 1)
end)

voidPart.Touched:Connect(function(hit)
    local char = player.Character
    if not char then return end
    if not hit:IsDescendantOf(char) then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local nearestPart, nearestDist = nil, math.huge
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide and part ~= voidPart and not part:IsDescendantOf(char) then
            local dist = (hrp.Position - part.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearestPart = part
            end
        end
    end
    
    if nearestPart then
        local targetPos = nearestPart.Position + Vector3.new(0, 5, 0)
        local tween = ts:Create(hrp, TweenInfo.new(1, Enum.EasingStyle.Quad), {CFrame = CFrame.new(targetPos)})
        tween:Play()
    end
end)
