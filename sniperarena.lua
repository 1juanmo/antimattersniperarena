-- Load Wind UI Library
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/silencedevs/SilenceScripts/refs/heads/main/libraries/windui/windui.luau"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

local Settings = {
    Enabled = false,
    TargetPart = "Head",
    FOVRadius = 150,
    WallCheck = false,
    AutoShoot = false,
    FireRate = 0.05,
    ESP_Enabled = false,
    ESP_IncludeNPCs = false,
}

-- Create Wind UI Window
local Window = WindUI:CreateWindow({
    Title = "AntiMatter - Sniper Arena",
    Author = "by xamo @neoxamo",
    Icon = "solar:lock-bold",
    IconSize = 26,
    Theme = "Violet",
    NewElements = true,
    Size = UDim2.fromOffset(450, 320),
    Folder = "AntiMatter/SniperArena/" .. tostring(LocalPlayer.UserId),
    KeySystem = false,
})

-- Create Tabs
local MainTab = Window:Tab({ Title = "Aimbot", Icon = "crosshair" })
local ESPTab = Window:Tab({ Title = "Visuals (ESP)", Icon = "eye" })
local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })

-- Aimbot Section
local AimbotSection = MainTab:Section({ Title = "Combat Settings", TextXAlignment = "Left" })

AimbotSection:Toggle({
    Title = "Enable Silent Aim",
    Default = Settings.Enabled,
    Callback = function(Value)
        Settings.Enabled = Value
    end
})

AimbotSection:Dropdown({
    Title = "Target Part",
    Values = { "Head", "HumanoidRootPart", "Torso", "Random" },
    Default = Settings.TargetPart,
    Callback = function(Value)
        Settings.TargetPart = Value
    end
})

AimbotSection:Input({
    Title = "Custom FOV Radius",
    Default = tostring(Settings.FOVRadius),
    Placeholder = "Enter FOV (e.g. 150)",
    Callback = function(Value)
        local num = tonumber(Value)
        if num then
            Settings.FOVRadius = math.clamp(num, 10, 2000)
        end
    end
})

AimbotSection:Toggle({
    Title = "Auto Shoot",
    Default = Settings.AutoShoot,
    Callback = function(Value)
        Settings.AutoShoot = Value
    end
})

AimbotSection:Toggle({
    Title = "Wall Check",
    Default = Settings.WallCheck,
    Callback = function(Value)
        Settings.WallCheck = Value
    end
})

-- ESP Section
local ESPSection = ESPTab:Section({ Title = "ESP Settings", TextXAlignment = "Left" })

ESPSection:Toggle({
    Title = "Enable ESP",
    Default = Settings.ESP_Enabled,
    Callback = function(Value)
        Settings.ESP_Enabled = Value
    end
})

ESPSection:Toggle({
    Title = "Include NPCs",
    Default = Settings.ESP_IncludeNPCs,
    Callback = function(Value)
        Settings.ESP_IncludeNPCs = Value
    end
})

-- Info Section
local InfoSection = InfoTab:Section({ Title = "Info", TextXAlignment = "Left" })

InfoTab:Paragraph({ Title = "Made by xamo" })
InfoTab:Paragraph({ Title = "Any issues? Create a Ticket on Discord" })

InfoTab:Button({
    Title = "Copy Invite",
    Callback = function()
        local success = type(setclipboard) == "function" and pcall(setclipboard, "https://discord.gg/aeZ44NsWV6")
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = success and "Link Copied!" or "Error!",
                Text = success and "You can continue to Discord now." or "Clipboard not Supported.",
                Duration = 3
            })
        end)
    end
})

InfoTab:Space()
InfoTab:Section({ Title = "Contributors:", TextSize = 17, Box = false })
InfoTab:Paragraph({ Title = "- xamo @neoxamo" })
InfoTab:Space()
InfoTab:Space()
InfoTab:Section({ Title = "Sniper Arena[V1.0.0] [PRE RELEASE]", TextSize = 20, Box = false })

-- ESP Core Logic
local RAINBOW_SPEED = 0.5
local HEALTH_BG_COLOR = Color3.fromRGB(50, 0, 0)
local HEALTH_GOOD_COLOR = Color3.fromRGB(0, 255, 0)
local HEALTH_LOW_COLOR = Color3.fromRGB(255, 0, 0)

local R15_BONE_PAIRS = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local R6_BONE_PAIRS = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function getCharacterBounds(character)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local onScreenAny = false

    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            local cframe, size = part.CFrame, part.Size
            local halfSize = size / 2
            local vertices = {
                cframe * Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
                cframe * Vector3.new(halfSize.X, -halfSize.Y, -halfSize.Z),
                cframe * Vector3.new(-halfSize.X, halfSize.Y, -halfSize.Z),
                cframe * Vector3.new(halfSize.X, halfSize.Y, -halfSize.Z),
                cframe * Vector3.new(-halfSize.X, -halfSize.Y, halfSize.Z),
                cframe * Vector3.new(halfSize.X, -halfSize.Y, halfSize.Z),
                cframe * Vector3.new(-halfSize.X, halfSize.Y, halfSize.Z),
                cframe * Vector3.new(halfSize.X, halfSize.Y, halfSize.Z)
            }
            for _, vertex in ipairs(vertices) do
                local screenPos, onScreen = Camera:WorldToViewportPoint(vertex)
                if onScreen then
                    onScreenAny = true
                    if screenPos.X < minX then minX = screenPos.X end
                    if screenPos.X > maxX then maxX = screenPos.X end
                    if screenPos.Y < minY then minY = screenPos.Y end
                    if screenPos.Y > maxY then maxY = screenPos.Y end
                end
            end
        end
    end

    return onScreenAny, Vector2.new(minX, minY), Vector2.new(maxX, maxY)
end

local trackedCharacters = {}

local function createModelESP(character)
    if not character or trackedCharacters[character] then return end
    if LocalPlayer.Character and character == LocalPlayer.Character then return end

    trackedCharacters[character] = true

    local tracer = Drawing.new("Line")
    local box = Drawing.new("Square")
    local healthBarBg = Drawing.new("Line")
    local healthBar = Drawing.new("Line")

    tracer.Thickness = 1
    box.Thickness = 1
    box.Filled = false
    healthBarBg.Thickness = 2
    healthBarBg.Color = HEALTH_BG_COLOR
    healthBar.Thickness = 2

    local skeletonLines = {}
    for i = 1, #R15_BONE_PAIRS do
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.Visible = false
        table.insert(skeletonLines, line)
    end

    local function cleanup()
        tracer:Remove()
        box:Remove()
        healthBarBg:Remove()
        healthBar:Remove()
        for _, line in ipairs(skeletonLines) do
            line:Remove()
        end
        trackedCharacters[character] = nil
    end

    local function setAllVisibility(visible)
        tracer.Visible = visible
        box.Visible = visible
        healthBarBg.Visible = visible
        healthBar.Visible = visible
        for _, line in ipairs(skeletonLines) do
            line.Visible = visible
        end
    end

    local connection
    connection = RunService.RenderStepped:Connect(function()
        local isPlayerChar = Players:GetPlayerFromCharacter(character) ~= nil

        if not Settings.ESP_Enabled or (not isPlayerChar and not Settings.ESP_IncludeNPCs) then
            setAllVisibility(false)
            return
        end

        if not character or not character:IsDescendantOf(workspace) or not LocalPlayer.Character then
            setAllVisibility(false)
            cleanup()
            connection:Disconnect()
            return
        end

        local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if rootPart and humanoid and humanoid.Health > 0 then
            local isValid, topLeft, bottomRight = getCharacterBounds(character)

            if isValid then
                local hue = (tick() * RAINBOW_SPEED) % 1
                local rainbowColor = Color3.fromHSV(hue, 1, 1)

                box.Color = rainbowColor
                tracer.Color = rainbowColor

                local boxWidth = bottomRight.X - topLeft.X
                local boxHeight = bottomRight.Y - topLeft.Y

                box.Size = Vector2.new(boxWidth + 4, boxHeight + 4)
                box.Position = Vector2.new(topLeft.X - 2, topLeft.Y - 2)
                box.Visible = true

                tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                tracer.To = Vector2.new(topLeft.X + (boxWidth / 2), bottomRight.Y + 2)
                tracer.Visible = true

                local healthPercentage = humanoid.Health / humanoid.MaxHealth
                local healthBarX = topLeft.X - 6

                healthBarBg.From = Vector2.new(healthBarX, bottomRight.Y + 2)
                healthBarBg.To = Vector2.new(healthBarX, topLeft.Y - 2)
                healthBarBg.Visible = true

                local healthHeight = (boxHeight + 4) * math.clamp(healthPercentage, 0, 1)
                healthBar.From = Vector2.new(healthBarX, bottomRight.Y + 2)
                healthBar.To = Vector2.new(healthBarX, (bottomRight.Y + 2) - healthHeight)
                healthBar.Color = HEALTH_LOW_COLOR:Lerp(HEALTH_GOOD_COLOR, math.clamp(healthPercentage, 0, 1))
                healthBar.Visible = true

                local isR15 = (humanoid.RigType == Enum.HumanoidRigType.R15)
                local activeBones = isR15 and R15_BONE_PAIRS or R6_BONE_PAIRS

                for i, bonePair in ipairs(activeBones) do
                    local p1 = character:FindFirstChild(bonePair[1])
                    local p2 = character:FindFirstChild(bonePair[2])
                    local line = skeletonLines[i]

                    if p1 and p2 and line then
                        line.Color = rainbowColor
                        local pos1, os1 = Camera:WorldToViewportPoint(p1.Position)
                        local pos2, os2 = Camera:WorldToViewportPoint(p2.Position)

                        if os1 and os2 then
                            line.From = Vector2.new(pos1.X, pos1.Y)
                            line.To = Vector2.new(pos2.X, pos2.Y)
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    elseif line then
                        line.Visible = false
                    end
                end

                if not isR15 then
                    for i = #R6_BONE_PAIRS + 1, #skeletonLines do
                        skeletonLines[i].Visible = false
                    end
                end
            else
                setAllVisibility(false)
            end
        else
            setAllVisibility(false)
            if humanoid and humanoid.Health <= 0 then
                cleanup()
                connection:Disconnect()
            end
        end
    end)
end

-- Scan workspace
local function scanWorkspaceForEntities()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            createModelESP(obj)
        end
    end
end

workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Humanoid") then
        local parentModel = descendant.Parent
        if parentModel and parentModel:IsA("Model") then
            createModelESP(parentModel)
        end
    end
end)

scanWorkspaceForEntities()

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = 1.5
FOVCircle.Radius = Settings.FOVRadius
FOVCircle.Transparency = 0.7
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Filled = false
FOVCircle.NumSides = 64

-- Safely require modules
local RemoteFolder = ReplicatedStorage:WaitForChild("Remote", 10)
local EntityService = RemoteFolder and require(RemoteFolder:WaitForChild("EntityService", 10))

local ClientFolder = ReplicatedStorage:WaitForChild("Client", 10)
local CombatController = ClientFolder and ClientFolder:WaitForChild("CombatController", 10)
local ClientComponent = CombatController and CombatController:WaitForChild("ClientComponent", 10)
local ClientShootableComponent = ClientComponent and require(ClientComponent:WaitForChild("ClientShootableComponent", 10))

local function IsInMatch()
    local char = LocalPlayer.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    if EntityService and EntityService.GetLocalEntity then
        local LocalEntity = EntityService.GetLocalEntity()
        if not LocalEntity or not LocalEntity:IsAlive() then return false end
    end

    return true
end

local function IsVisible(TargetPart)
    if not Camera or not TargetPart then return false end

    local LocalChar = LocalPlayer.Character
    if not LocalChar then return false end

    local RaycastParamsInstance = RaycastParams.new()
    RaycastParamsInstance.FilterType = Enum.RaycastFilterType.Exclude
    RaycastParamsInstance.FilterDescendantsInstances = {LocalChar, TargetPart.Parent}
    RaycastParamsInstance.IgnoreWater = true

    local Origin = Camera.CFrame.Position
    local Direction = TargetPart.Position - Origin
    local Result = workspace:Raycast(Origin, Direction, RaycastParamsInstance)

    return Result == nil
end

-- Strictly dynamic part fetching
local function GetEntityTargetPart(CharacterModel)
    if not CharacterModel then return nil end

    local selected = Settings.TargetPart
    local targetPart = nil

    if selected == "Head" then
        targetPart = CharacterModel:FindFirstChild("Head")
    elseif selected == "HumanoidRootPart" then
        targetPart = CharacterModel:FindFirstChild("HumanoidRootPart")
    elseif selected == "Torso" then
        targetPart = CharacterModel:FindFirstChild("UpperTorso") 
            or CharacterModel:FindFirstChild("Torso")
    elseif selected == "Random" then
        local available = {}
        for _, pName in ipairs({"Head", "UpperTorso", "Torso", "HumanoidRootPart"}) do
            local found = CharacterModel:FindFirstChild(pName)
            if found then table.insert(available, found) end
        end
        if #available > 0 then
            targetPart = available[math.random(1, #available)]
        end
    end

    -- Fallback if specific part wasn't found in character
    if not targetPart then
        targetPart = CharacterModel:FindFirstChild("Head") 
            or CharacterModel:FindFirstChild("HumanoidRootPart")
    end

    return targetPart
end

local function IsInFOV(WorldPosition)
    if not Camera then return false, math.huge end

    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(WorldPosition)
    if not OnScreen then return false, math.huge end

    local MousePos = UserInputService:GetMouseLocation()
    local Distance = (Vector2.new(ScreenPos.X, ScreenPos.Y) - MousePos).Magnitude

    return Distance <= Settings.FOVRadius, Distance
end

local function GetClosestEnemyInFOV()
    if not EntityService or not EntityService.GetLocalEntity then return nil end

    local LocalEntity = EntityService.GetLocalEntity()
    if not LocalEntity or not LocalEntity.World or not LocalEntity.World.EntitiesByTeam then
        return nil
    end

    local ClosestTarget = nil
    local ClosestDistance = math.huge

    for _, TeamDict in pairs(LocalEntity.World.EntitiesByTeam) do
        local Items = TeamDict._items or TeamDict

        for _, Entity in pairs(Items) do
            if not EntityService.IsLocalEntity(Entity) and Entity:IsAlive() then
                local Inst = Entity.Instance
                local Character = (Inst and Inst:IsA("Player")) and Inst.Character or Inst

                if Character then
                    local Humanoid = Character:FindFirstChildOfClass("Humanoid")

                    if Humanoid and Humanoid.Health > 0 then
                        local Part = GetEntityTargetPart(Character)

                        if Part then
                            local Position = Part.Position
                            local InFOV, Distance = IsInFOV(Position)

                            if InFOV and Distance < ClosestDistance then
                                if not Settings.WallCheck or IsVisible(Part) then
                                    ClosestTarget = { Part = Part, Position = Position }
                                    ClosestDistance = Distance
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return ClosestTarget
end

local SilentTarget = nil

RunService.RenderStepped:Connect(function()
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Radius = Settings.FOVRadius
    FOVCircle.Visible = Settings.Enabled
end)

task.spawn(function()
    while true do
        task.wait(Settings.FireRate)

        if Settings.Enabled and Settings.AutoShoot and IsInMatch() then
            local Target = GetClosestEnemyInFOV()

            if Target then
                local MousePos = UserInputService:GetMouseLocation()
                VirtualInputManager:SendMouseButtonEvent(MousePos.X, MousePos.Y, 0, true, game, 0)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(MousePos.X, MousePos.Y, 0, false, game, 0)
            end
        end
    end
end)

if ClientShootableComponent and ClientShootableComponent.LocalShoot then
    local OrigLocalShoot = ClientShootableComponent.LocalShoot
    local OrigOriginFn, OrigTargetFn

    for i = 1, 20 do
        local success, val = pcall(debug.getupvalue, OrigLocalShoot, i)

        if success and type(val) == "function" then
            local testSuccess, ret1, ret2, ret3 = pcall(val)

            if testSuccess then
                if typeof(ret1) == "CFrame" and typeof(ret3) == "table" then
                    OrigOriginFn = val
                elseif typeof(ret1) == "Vector3" and typeof(ret2) == "Instance" then
                    OrigTargetFn = val
                end
            end
        end
    end

    if OrigOriginFn then
        local OldOriginFn
        OldOriginFn = hookfunction(OrigOriginFn, function(...)
            local cf, pos, meta = OldOriginFn(...)

            if SilentTarget and Settings.Enabled and SilentTarget.Part then
                -- Always refresh live position of the target part
                return CFrame.lookAt(cf.Position, SilentTarget.Part.Position), pos, meta
            end

            return cf, pos, meta
        end)
    end

    if OrigTargetFn then
        local OldTargetFn
        OldTargetFn = hookfunction(OrigTargetFn, function(...)
            if SilentTarget and Settings.Enabled and SilentTarget.Part then
                -- Return target part's current position and instance
                return SilentTarget.Part.Position, SilentTarget.Part
            end

            return OldTargetFn(...)
        end)
    end

    local OldLocalShoot
    OldLocalShoot = hookfunction(ClientShootableComponent.LocalShoot, function(Self, ...)
        if Settings.Enabled then
            SilentTarget = GetClosestEnemyInFOV()
        end

        local Result = OldLocalShoot(Self, ...)
        SilentTarget = nil

        return Result
    end)
end
