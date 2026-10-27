local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local LIB_URL = "https://raw.githubusercontent.com/LotuxHub/LotuxHub/refs/heads/main/Library/Library.lua"
if not redzlib then
    local ok, lib = pcall(function() return loadstring(game:HttpGet(LIB_URL))() end)
    if ok and lib then redzlib = lib end
end
assert(redzlib, "Failed to load redzlib")

local function notify(title, desc, dur, kind)
    pcall(function()
        redzlib:Notify({Title = title, Description = desc, Duration = dur or 2, Type = kind or "Info"})
    end)
end

local function getValidTargets()
    local targets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("Head")
                if hum and hum.Health > 0 and hrp then
                    table.insert(targets, {player = player, character = char, humanoid = hum, hrp = hrp, head = head})
                end
            end
        end
    end
    return targets
end

local ESPState = {enabled = false, showName = true, showDistance = true, boxColor = Color3.fromRGB(255,60,60), tracked = {}, connections = {}}

local function createESP(player)
    if player == LocalPlayer then return end
    if ESPState.tracked[player] then return end
    local entry = {highlight = nil, billboard = nil, label = nil, connections = {}}
    ESPState.tracked[player] = entry
    local function attach(char)
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart", 3)
        local head = char:WaitForChild("Head", 3)
        if not hrp then return end
        if entry.highlight then entry.highlight:Destroy() end
        local hl = Instance.new("Highlight")
        hl.FillColor = ESPState.boxColor
        hl.OutlineColor = Color3.new(1,1,1)
        hl.FillTransparency = 0.65
        hl.OutlineTransparency = 0.15
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = CoreGui
        hl.Adornee = char
        entry.highlight = hl
        if head then
            if entry.billboard then entry.billboard:Destroy() end
            local bb = Instance.new("BillboardGui")
            bb.Adornee = head
            bb.Size = UDim2.new(0, 200, 0, 32)
            bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = true
            bb.Parent = CoreGui
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1,0,1,0)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.new(1,1,1)
            label.TextStrokeTransparency = 0
            label.TextScaled = true
            label.Font = Enum.Font.GothamBold
            label.Text = player.DisplayName
            label.Parent = bb
            entry.billboard = bb
            entry.label = label
        end
    end
    if player.Character then attach(player.Character) end
    table.insert(entry.connections, player.CharacterAdded:Connect(attach))
end

local function startESP()
    for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
    table.insert(ESPState.connections, Players.PlayerAdded:Connect(createESP))
    table.insert(ESPState.connections, RunService.RenderStepped:Connect(function()
        if not ESPState.enabled then return end
        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        for player, entry in pairs(ESPState.tracked) do
            if not player.Parent then
                if entry.highlight then entry.highlight:Destroy() end
                if entry.billboard then entry.billboard:Destroy() end
                for _, c in ipairs(entry.connections) do c:Disconnect() end
                ESPState.tracked[player] = nil
            elseif entry.billboard and entry.label then
                entry.billboard.Enabled = ESPState.enabled
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if myHrp and hrp then
                    local dist = (hrp.Position - myHrp.Position).Magnitude
                    local text = ""
                    if ESPState.showName then text = player.DisplayName end
                    if ESPState.showDistance then
                        text = text .. (text ~= "" and "  |  " or "") .. string.format("%.0fm", dist)
                    end
                    entry.label.Text = text
                end
            end
        end
    end))
end

local function stopESP()
    for _, c in ipairs(ESPState.connections) do c:Disconnect() end
    ESPState.connections = {}
    for _, entry in pairs(ESPState.tracked) do
        if entry.highlight then entry.highlight:Destroy() end
        if entry.billboard then entry.billboard:Destroy() end
        for _, c in ipairs(entry.connections) do c:Disconnect() end
    end
    ESPState.tracked = {}
end

local AimbotState = {enabled = false, targetPart = "Head", fov = 150, smoothness = 0.35, teamCheck = true, wallCheck = false, target = nil, conn = nil}

local function isEnemy(player)
    if not AimbotState.teamCheck then return true end
    return player.Team ~= LocalPlayer.Team
end

local function getClosestToCursor()
    local targets = getValidTargets()
    local best, bestDot = nil, -math.huge
    local mouse = UIS:GetMouseLocation()
    local ray = Camera:ScreenPointToRay(mouse.X, mouse.Y)
    local pointer = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
    local myChar = LocalPlayer.Character
    for _, t in ipairs(targets) do
        if not isEnemy(t.player) then continue end
        local targetPart = t.character:FindFirstChild(AimbotState.targetPart)
        if not targetPart then continue end
        local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
        if not onScreen then continue end
        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude
        if dist2D > AimbotState.fov then continue end
        if AimbotState.wallCheck and myChar then
            local origin = Camera.CFrame.Position
            local dir = (targetPart.Position - origin)
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {myChar, Camera}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local result = Workspace:Raycast(origin, dir, rp)
            if result and not result.Instance:IsDescendantOf(t.character) then continue end
        end
        local dirToTarget = (targetPart.Position - Camera.CFrame.Position).Unit
        local dot = pointer.LookVector:Dot(dirToTarget)
        if dot > bestDot then
            bestDot = dot
            best = t
        end
    end
    return best
end

local function startAimbot()
    if AimbotState.conn then return end
    AimbotState.conn = RunService.RenderStepped:Connect(function()
        if not AimbotState.enabled then return end
        local target = getClosestToCursor()
        AimbotState.target = target
        if not target then return end
        local targetPart = target.character:FindFirstChild(AimbotState.targetPart)
        if not targetPart then return end
        local camPos = Camera.CFrame.Position
        local newCF = CFrame.new(camPos, targetPart.Position)
        local alpha = math.clamp(AimbotState.smoothness, 0.05, 1)
        Camera.CFrame = Camera.CFrame:Lerp(newCF, alpha)
    end)
end

local function stopAimbot()
    if AimbotState.conn then AimbotState.conn:Disconnect(); AimbotState.conn = nil end
    AimbotState.target = nil
end

local FovCircle = {gui = nil, frame = nil, enabled = false, conn = nil}

local function createFovCircle()
    if FovCircle.gui then return end
    local g = Instance.new("ScreenGui")
    g.Name = "LotuxFovCircle"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 5
    g.Parent = CoreGui
    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 1
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.fromOffset(300, 300)
    frame.Parent = g
    local circle = Instance.new("ImageLabel")
    circle.Size = UDim2.fromScale(1, 1)
    circle.BackgroundTransparency = 1
    circle.Image = "rbxassetid://3570695787"
    circle.ImageColor3 = Color3.fromRGB(255, 60, 60)
    circle.ImageTransparency = 0.4
    circle.ScaleType = Enum.ScaleType.Fit
    circle.Parent = frame
    FovCircle.gui = g
    FovCircle.frame = frame
end

local function startFovCircle()
    createFovCircle()
    FovCircle.gui.Enabled = true
    FovCircle.conn = RunService.RenderStepped:Connect(function()
        if not FovCircle.enabled or not FovCircle.frame then return end
        FovCircle.frame.Size = UDim2.fromOffset(AimbotState.fov * 2, AimbotState.fov * 2)
    end)
end

local function stopFovCircle()
    if FovCircle.gui then FovCircle.gui.Enabled = false end
    if FovCircle.conn then FovCircle.conn:Disconnect(); FovCircle.conn = nil end
end

local HitboxState = {enabled = false, size = 15, original = {}, conn = nil}

local function startHitbox()
    if HitboxState.conn then return end
    HitboxState.conn = RunService.Heartbeat:Connect(function()
        if not HitboxState.enabled then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isEnemy(p) then
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if not HitboxState.original[hrp] then HitboxState.original[hrp] = hrp.Size end
                    hrp.Size = Vector3.new(HitboxState.size, HitboxState.size, HitboxState.size)
                    hrp.Transparency = 0.7
                    hrp.CanCollide = false
                    hrp.Massless = true
                end
            end
        end
    end)
end

local function stopHitbox()
    if HitboxState.conn then HitboxState.conn:Disconnect(); HitboxState.conn = nil end
    for hrp, size in pairs(HitboxState.original) do
        if hrp and hrp.Parent then hrp.Size = size; hrp.Transparency = 1 end
    end
    HitboxState.original = {}
end

local MoveState = {speed = 16, jump = 50, speedOn = false, jumpOn = false, conn = nil}

local function startMoveLoop()
    if MoveState.conn then return end
    MoveState.conn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if MoveState.speedOn then hum.WalkSpeed = MoveState.speed end
        if MoveState.jumpOn then hum.JumpPower = MoveState.jump end
    end)
end

local NoclipState = {enabled = false, conn = nil}

local function startNoclip()
    if NoclipState.conn then return end
    NoclipState.conn = RunService.Stepped:Connect(function()
        if not NoclipState.enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

local function stopNoclip()
    if NoclipState.conn then NoclipState.conn:Disconnect(); NoclipState.conn = nil end
end

local FlyState = {enabled = false, speed = 60, gyro = nil, vel = nil, conn = nil}

local function startFly()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    local gyro = Instance.new("BodyGyro")
    gyro.P = 90000; gyro.MaxTorque = Vector3.new(9e9,9e9,9e9); gyro.Parent = hrp
    local vel = Instance.new("BodyVelocity")
    vel.Velocity = Vector3.zero; vel.MaxForce = Vector3.new(9e9,9e9,9e9); vel.Parent = hrp
    hum.PlatformStand = true
    FlyState.gyro = gyro; FlyState.vel = vel
    FlyState.conn = RunService.RenderStepped:Connect(function()
        if not FlyState.enabled then return end
        if not gyro.Parent or not vel.Parent then return end
        local cam = Camera.CFrame
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.E) then dir += Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.Q) then dir -= Vector3.yAxis end
        if dir.Magnitude > 0 then dir = dir.Unit end
        vel.Velocity = dir * FlyState.speed
        gyro.CFrame = cam
    end)
end

local function stopFly()
    if FlyState.conn then FlyState.conn:Disconnect(); FlyState.conn = nil end
    if FlyState.gyro then FlyState.gyro:Destroy(); FlyState.gyro = nil end
    if FlyState.vel then FlyState.vel:Destroy(); FlyState.vel = nil end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
end

local FullbrightState = {enabled = false, old = {}}

local function startFullbright()
    FullbrightState.old = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, Ambient = Lighting.Ambient, Brightness = Lighting.Brightness}
    Lighting.FogEnd = 1e9
    Lighting.FogStart = 1e9
    Lighting.Ambient = Color3.new(1,1,1)
    Lighting.Brightness = 2.5
end

local function stopFullbright()
    for k, v in pairs(FullbrightState.old) do pcall(function() Lighting[k] = v end) end
end

local IMG = "rbxassetid://111672166073808"
local windows = redzlib:MakeWindow({Title = "Universe Hub", SubTitle = "Arsenal", SaveFolder = "Lotux Hub\\" .. LocalPlayer.Name})

local HomeTab = windows:MakeTab({Title = "Home", Icon = "home"})
HomeTab:AddSection("Welcome To Lotux Hub | Arsenal")
HomeTab:AddSection("Discord Server")
HomeTab:AddDiscordInvite({Title = "Lotux Hub", Desc = "Join our Discord!", Logo = IMG, Invite = "https://discord.gg/HkB97N772p"})

local AimTab = windows:MakeTab({Title = "Aimbot", Icon = "crosshair"})
AimTab:AddSection("Aimbot Settings")
AimTab:AddToggle({Title = "Aimbot", Description = "Smooth camera lock", Default = false, Flag = "ars_aim",
    Callback = function(state)
        AimbotState.enabled = state
        if state then startAimbot() notify("Aimbot", "ON", 2, "Success")
        else stopAimbot() notify("Aimbot", "OFF", 2, "Info") end
    end})
AimTab:AddDropdown({Title = "Aim Part", Options = {"Head","HumanoidRootPart","UpperTorso"}, Default = "Head", Flag = "ars_aim_part",
    Callback = function(v) AimbotState.targetPart = (typeof(v) == "table" and v[1]) or v end})
AimTab:AddSlider({Title = "FOV", Min = 30, Max = 500, Default = 150, Flag = "ars_fov",
    Callback = function(v) AimbotState.fov = v end})
AimTab:AddSlider({Title = "Smoothness", Min = 0.05, Max = 1, Default = 0.35, Flag = "ars_smooth",
    Callback = function(v) AimbotState.smoothness = v end})
AimTab:AddToggle({Title = "Team Check", Default = true, Flag = "ars_team",
    Callback = function(s) AimbotState.teamCheck = s end})
AimTab:AddToggle({Title = "Wall Check", Default = false, Flag = "ars_wall",
    Callback = function(s) AimbotState.wallCheck = s end})
AimTab:AddSection("Visual")
AimTab:AddToggle({Title = "Show FOV Circle", Default = false, Flag = "ars_fov_circle",
    Callback = function(state)
        FovCircle.enabled = state
        if state then startFovCircle() else stopFovCircle() end
    end})
AimTab:AddSection("Hitbox")
AimTab:AddToggle({Title = "Hitbox Expander", Default = false, Flag = "ars_hitbox",
    Callback = function(state)
        HitboxState.enabled = state
        if state then startHitbox() else stopHitbox() end
        notify("Hitbox", state and "ON" or "OFF", 2, state and "Success" or "Info")
    end})
AimTab:AddSlider({Title = "Hitbox Size", Min = 5, Max = 40, Default = 15, Flag = "ars_hitbox_size",
    Callback = function(v) HitboxState.size = v end})

local EspTab = windows:MakeTab({Title = "ESP", Icon = "eye"})
EspTab:AddSection("Player ESP")
EspTab:AddToggle({Title = "Enable ESP", Default = false, Flag = "ars_esp",
    Callback = function(state)
        ESPState.enabled = state
        if state then startESP() notify("ESP", "ON", 2, "Success")
        else stopESP() notify("ESP", "OFF", 2, "Info") end
    end})
EspTab:AddToggle({Title = "Show Name", Default = true, Flag = "ars_esp_name",
    Callback = function(state) ESPState.showName = state end})
EspTab:AddToggle({Title = "Show Distance", Default = true, Flag = "ars_esp_dist",
    Callback = function(state) ESPState.showDistance = state end})

local MoveTab = windows:MakeTab({Title = "Movement", Icon = "user"})
MoveTab:AddSection("Speed")
MoveTab:AddToggle({Title = "Walkspeed", Default = false, Flag = "ars_ws",
    Callback = function(state) MoveState.speedOn = state; if state then startMoveLoop() end end})
MoveTab:AddSlider({Title = "Walkspeed Value", Min = 16, Max = 100, Default = 25, Flag = "ars_ws_val",
    Callback = function(v) MoveState.speed = v end})
MoveTab:AddToggle({Title = "JumpPower", Default = false, Flag = "ars_jp",
    Callback = function(state) MoveState.jumpOn = state; if state then startMoveLoop() end end})
MoveTab:AddSlider({Title = "JumpPower Value", Min = 50, Max = 200, Default = 50, Flag = "ars_jp_val",
    Callback = function(v) MoveState.jump = v end})
MoveTab:AddSection("Physics")
MoveTab:AddToggle({Title = "Noclip", Default = false, Flag = "ars_noclip",
    Callback = function(state)
        NoclipState.enabled = state
        if state then startNoclip() else stopNoclip() end
    end})
MoveTab:AddToggle({Title = "Fly", Default = false, Flag = "ars_fly",
    Callback = function(state)
        FlyState.enabled = state
        if state then startFly() else stopFly() end
    end})
MoveTab:AddSlider({Title = "Fly Speed", Min = 20, Max = 200, Default = 60, Flag = "ars_fly_speed",
    Callback = function(v) FlyState.speed = v end})

local MiscTab = windows:MakeTab({Title = "Misc", Icon = "settings"})
MiscTab:AddSection("Lighting")
MiscTab:AddToggle({Title = "Fullbright", Default = false, Flag = "ars_fb",
    Callback = function(state)
        FullbrightState.enabled = state
        if state then startFullbright() else stopFullbright() end
    end})
MiscTab:AddSection("Utility")
MiscTab:AddToggle({Title = "Anti-AFK", Default = false, Flag = "ars_afk",
    Callback = function(state)
        if state then
            if not getgenv()._lotuxArsAFK then
                getgenv()._lotuxArsAFK = LocalPlayer.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        else
            if getgenv()._lotuxArsAFK then getgenv()._lotuxArsAFK:Disconnect(); getgenv()._lotuxArsAFK = nil end
        end
    end})

notify("Lotux Hub", "Arsenal loaded", 3, "Success")
print("[Lotux Hub] Arsenal loader loaded.")
return redzlib