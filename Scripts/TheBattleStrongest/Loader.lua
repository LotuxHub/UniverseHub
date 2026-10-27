local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local LIB_URL = "https://raw.githubusercontent.com/UniverseHub/UniverseHub/refs/heads/main/Library/UniverseLibrary.lua"
if not redzlib then
    local ok, lib = pcall(function() return loadstring(game:HttpGet(LIB_URL))() end)
    if ok and lib then redzlib = lib end
end
assert(redzlib, "[Universe TSB] Failed to load redzlib")

local function notify(title, desc, dur, kind)
    pcall(function()
        redzlib:Notify({Title = title, Description = desc, Duration = dur or 2, Type = kind or "Info"})
    end)
end

local IS_MOBILE = UIS.TouchEnabled and not UIS.MouseEnabled

local function getValidTargets()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                table.insert(list, {player = player, character = player.Character, hum = hum, hrp = hrp})
            end
        end
    end
    return list
end

local ESPState = {enabled = false, showName = true, showHealth = true, showDistance = true, maxDist = 500, tracked = {}, connections = {}}

local function buildESP(player)
    if player == LocalPlayer then return end
    if ESPState.tracked[player] then return end
    local entry = {connections = {}, highlight = nil, billboard = nil, label = nil}
    ESPState.tracked[player] = entry
    local function attach(char)
        if not char then return end
        local head = char:WaitForChild("Head", 5)
        if not head then return end
        if entry.highlight then entry.highlight:Destroy() end
        if entry.billboard then entry.billboard:Destroy() end
        local hl = Instance.new("Highlight")
        hl.Adornee = char
        hl.FillColor = Color3.fromRGB(255, 60, 60)
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.65
        hl.OutlineTransparency = 0.15
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = CoreGui
        entry.highlight = hl
        local bb = Instance.new("BillboardGui")
        bb.Adornee = head
        bb.Size = UDim2.new(0, 240, 0, 44)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Parent = CoreGui
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextStrokeTransparency = 0
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Parent = bb
        entry.billboard = bb
        entry.label = label
    end
    if player.Character then attach(player.Character) end
    table.insert(entry.connections, player.CharacterAdded:Connect(attach))
end

local function startESP()
    for _, p in ipairs(Players:GetPlayers()) do buildESP(p) end
    table.insert(ESPState.connections, Players.PlayerAdded:Connect(buildESP))
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
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if myHrp and hrp then
                    local dist = (hrp.Position - myHrp.Position).Magnitude
                    local visible = dist <= ESPState.maxDist and ESPState.enabled
                    local parts = {}
                    if ESPState.showName then table.insert(parts, player.DisplayName) end
                    if ESPState.showHealth and hum then table.insert(parts, string.format("%.0f HP", hum.Health)) end
                    if ESPState.showDistance then table.insert(parts, string.format("%.0fm", dist)) end
                    entry.label.Text = table.concat(parts, "  |  ")
                    entry.billboard.Enabled = visible
                    if entry.highlight then entry.highlight.Enabled = visible end
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

local AimbotState = {enabled = false, targetPart = "Head", fov = 180, smoothness = 0.35, visibleCheck = true, teamCheck = false, conn = nil}

local function pickTarget()
    local mouse = UIS:GetMouseLocation()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local best, bestDist = nil, math.huge
    for _, t in ipairs(getValidTargets()) do
        local part = t.character:FindFirstChild(AimbotState.targetPart)
        if not part then continue end
        local sp, onScreen = Camera:WorldToScreenPoint(part.Position)
        if not onScreen then continue end
        local d2d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
        if d2d > AimbotState.fov or d2d >= bestDist then continue end
        if AimbotState.visibleCheck then
            local origin = Camera.CFrame.Position
            local dir = part.Position - origin
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {myChar, Camera}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local result = Workspace:Raycast(origin, dir, rp)
            if result and not result.Instance:IsDescendantOf(t.character) then continue end
        end
        bestDist = d2d
        best = part
    end
    return best
end

local function startAimbot()
    if AimbotState.conn then return end
    AimbotState.conn = RunService.RenderStepped:Connect(function()
        if not AimbotState.enabled then return end
        local part = pickTarget()
        if not part then return end
        local newCF = CFrame.new(Camera.CFrame.Position, part.Position)
        Camera.CFrame = Camera.CFrame:Lerp(newCF, math.clamp(AimbotState.smoothness, 0.05, 1))
    end)
end

local function stopAimbot()
    if AimbotState.conn then AimbotState.conn:Disconnect(); AimbotState.conn = nil end
end

local FOVCircle = {gui = nil, frame = nil, enabled = false, conn = nil}

local function startFOVCircle()
    if not FOVCircle.gui then
        local g = Instance.new("ScreenGui")
        g.Name = "UniverseFOV"; g.ResetOnSpawn = false; g.IgnoreGuiInset = true; g.DisplayOrder = 5; g.Parent = CoreGui
        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Position = UDim2.new(0.5, 0, 0.5, 0); frame.BackgroundTransparency = 1; frame.Parent = g
        local circle = Instance.new("ImageLabel")
        circle.Size = UDim2.fromScale(1, 1); circle.BackgroundTransparency = 1
        circle.Image = "rbxassetid://3570695787"; circle.ImageColor3 = Color3.fromRGB(255, 60, 60)
        circle.ImageTransparency = 0.4; circle.ScaleType = Enum.ScaleType.Fit; circle.Parent = frame
        FOVCircle.gui = g; FOVCircle.frame = frame
    end
    FOVCircle.gui.Enabled = true
    FOVCircle.conn = RunService.RenderStepped:Connect(function()
        if not FOVCircle.enabled then return end
        FOVCircle.frame.Size = UDim2.fromOffset(AimbotState.fov * 2, AimbotState.fov * 2)
    end)
end

local function stopFOVCircle()
    if FOVCircle.gui then FOVCircle.gui.Enabled = false end
    if FOVCircle.conn then FOVCircle.conn:Disconnect(); FOVCircle.conn = nil end
end

local HitboxState = {enabled = false, size = 12, original = {}, conn = nil}

local function startHitbox()
    if HitboxState.conn then return end
    HitboxState.conn = RunService.Heartbeat:Connect(function()
        if not HitboxState.enabled then return end
        for _, t in ipairs(getValidTargets()) do
            local hrp = t.hrp
            if hrp then
                if not HitboxState.original[hrp] then HitboxState.original[hrp] = hrp.Size end
                hrp.Size = Vector3.new(HitboxState.size, HitboxState.size, HitboxState.size)
                hrp.Transparency = 0.7
                hrp.CanCollide = false
                hrp.Massless = true
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

local AutoComboState = {enabled = false, delay = 0.08, conn = nil}

local function getComboRemote()
    local remotes = Workspace:FindFirstChild("Remotes") or game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if remotes then
        for _, r in ipairs(remotes:GetDescendants()) do
            if r:IsA("RemoteEvent") and (r.Name:lower():find("punch") or r.Name:lower():find("combo") or r.Name:lower():find("attack") or r.Name:lower():find("hit")) then
                return r
            end
        end
    end
    return nil
end

local function startAutoCombo()
    if AutoComboState.conn then return end
    AutoComboState.conn = RunService.Heartbeat:Connect(function()
        if not AutoComboState.enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local targets = getValidTargets()
        if #targets == 0 then return end
        table.sort(targets, function(a, b)
            local myHrp = char:FindFirstChild("HumanoidRootPart")
            if not myHrp then return false end
            return (a.hrp.Position - myHrp.Position).Magnitude < (b.hrp.Position - myHrp.Position).Magnitude
        end)
        local target = targets[1]
        local myHrp = char:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end
        local dist = (target.hrp.Position - myHrp.Position).Magnitude
        if dist > 8 then return end
        local remote = getComboRemote()
        if remote then
            pcall(function() remote:FireServer(target.hrp.Position) end)
        end
    end)
end

local function stopAutoCombo()
    if AutoComboState.conn then AutoComboState.conn:Disconnect(); AutoComboState.conn = nil end
end

local TeleportState = {enabled = false, target = nil, dist = 4, conn = nil}

local function startTeleportBehind()
    if TeleportState.conn then return end
    TeleportState.conn = RunService.Heartbeat:Connect(function()
        if not TeleportState.enabled then return end
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end
        local targets = getValidTargets()
        if #targets == 0 then return end
        table.sort(targets, function(a, b)
            return (a.hrp.Position - myHrp.Position).Magnitude < (b.hrp.Position - myHrp.Position).Magnitude
        end)
        local t = targets[1]
        local behindPos = t.hrp.CFrame * CFrame.new(0, 0, TeleportState.dist)
        myHrp.CFrame = CFrame.new(behindPos.Position, t.hrp.Position)
    end)
end

local function stopTeleportBehind()
    if TeleportState.conn then TeleportState.conn:Disconnect(); TeleportState.conn = nil end
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
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
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
    gyro.P = 90000; gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9); gyro.Parent = hrp
    local vel = Instance.new("BodyVelocity")
    vel.Velocity = Vector3.zero; vel.MaxForce = Vector3.new(9e9, 9e9, 9e9); vel.Parent = hrp
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
    Lighting.FogEnd = 1e9; Lighting.FogStart = 1e9; Lighting.Ambient = Color3.new(1, 1, 1); Lighting.Brightness = 2.5
end

local function stopFullbright()
    for k, v in pairs(FullbrightState.old) do pcall(function() Lighting[k] = v end) end
end

local IJState = {enabled = false, conn = nil}

local function startIJ()
    if IJState.conn then return end
    IJState.conn = UIS.JumpRequest:Connect(function()
        if not IJState.enabled then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function stopIJ()
    if IJState.conn then IJState.conn:Disconnect(); IJState.conn = nil end
end

local AntiLagState = {enabled = false, conn = nil}

local function startAntiLag()
    if AntiLagState.conn then return end
    AntiLagState.conn = RunService.Heartbeat:Connect(function()
        if not AntiLagState.enabled then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                pcall(function() p.MaximumSimulationRadius = 0 end)
            end
        end
        pcall(function() LocalPlayer.MaximumSimulationRadius = math.huge end)
    end)
end

local function stopAntiLag()
    if AntiLagState.conn then AntiLagState.conn:Disconnect(); AntiLagState.conn = nil end
end

local function serverHop()
    local ts = game:GetService("TeleportService")
    local http = game:GetService("HttpService")
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = http:JSONDecode(game:HttpGet(url))
        for _, s in ipairs(res.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                ts:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                return
            end
        end
    end)
end

local IMG = "rbxassetid://111672166073808"

local windows = redzlib:MakeWindow({Title = "Universe Hub", SubTitle = "The Strongest Battlegrounds", SaveFolder = "Universe Hub\\" .. LocalPlayer.Name})

local HomeTab = windows:MakeTab({Title = "Home", Icon = "home"})
HomeTab:AddSection("Welcome To Universe Hub | TSB")
HomeTab:AddSection("Discord Server")
HomeTab:AddDiscordInvite({Title = "Universe Hub", Desc = "Join our Discord for updates!", Logo = IMG, Invite = "https://discord.gg/HkB97N772p"})

local AimTab = windows:MakeTab({Title = "Aimbot", Icon = "crosshair"})
AimTab:AddSection("Aimbot")
AimTab:AddToggle({Title = "Enable Aimbot", Default = false, Flag = "tsb_aim",
    Callback = function(state)
        AimbotState.enabled = state
        if state then startAimbot() notify("Aimbot", "ON", 2, "Success")
        else stopAimbot() notify("Aimbot", "OFF", 2, "Info") end
    end})
AimTab:AddDropdown({Title = "Aim Part", Options = {"Head", "HumanoidRootPart", "UpperTorso"}, Default = "Head", Flag = "tsb_aim_part",
    Callback = function(v) AimbotState.targetPart = (typeof(v) == "table" and v[1]) or v end})
AimTab:AddSlider({Title = "FOV", Min = 50, Max = 800, Default = 180, Flag = "tsb_fov",
    Callback = function(v) AimbotState.fov = v end})
AimTab:AddSlider({Title = "Smoothness", Min = 0.05, Max = 1, Default = 0.35, Flag = "tsb_smooth",
    Callback = function(v) AimbotState.smoothness = v end})
AimTab:AddToggle({Title = "Visible Check", Default = true, Flag = "tsb_vis", Callback = function(s) AimbotState.visibleCheck = s end})
AimTab:AddSection("Visual")
AimTab:AddToggle({Title = "Show FOV Circle", Default = false, Flag = "tsb_fov_circle",
    Callback = function(state)
        FOVCircle.enabled = state
        if state then startFOVCircle() else stopFOVCircle() end
    end})
AimTab:AddSection("Hitbox")
AimTab:AddToggle({Title = "Hitbox Expander", Default = false, Flag = "tsb_hitbox",
    Callback = function(state)
        HitboxState.enabled = state
        if state then startHitbox() else stopHitbox() end
        notify("Hitbox", state and "ON" or "OFF", 2, state and "Success" or "Info")
    end})
AimTab:AddSlider({Title = "Hitbox Size", Min = 5, Max = 40, Default = 12, Flag = "tsb_hitbox_size",
    Callback = function(v) HitboxState.size = v end})

local EspTab = windows:MakeTab({Title = "ESP", Icon = "eye"})
EspTab:AddSection("Player ESP")
EspTab:AddToggle({Title = "Enable ESP", Default = false, Flag = "tsb_esp",
    Callback = function(state)
        ESPState.enabled = state
        if state then startESP() notify("ESP", "ON", 2, "Success")
        else stopESP() notify("ESP", "OFF", 2, "Info") end
    end})
EspTab:AddToggle({Title = "Show Name", Default = true, Flag = "tsb_esp_name", Callback = function(s) ESPState.showName = s end})
EspTab:AddToggle({Title = "Show Health", Default = true, Flag = "tsb_esp_hp", Callback = function(s) ESPState.showHealth = s end})
EspTab:AddToggle({Title = "Show Distance", Default = true, Flag = "tsb_esp_dist", Callback = function(s) ESPState.showDistance = s end})
EspTab:AddSlider({Title = "Max Distance", Min = 50, Max = 2000, Default = 500, Flag = "tsb_esp_maxd",
    Callback = function(v) ESPState.maxDist = v end})

local ComboTab = windows:MakeTab({Title = "Combat", Icon = "sword"})
ComboTab:AddSection("Auto Combo")
ComboTab:AddToggle({Title = "Auto Combo", Description = "Fires punch remote on nearest enemy in range", Default = false, Flag = "tsb_combo",
    Callback = function(state)
        AutoComboState.enabled = state
        if state then startAutoCombo() notify("Auto Combo", "ON", 2, "Success")
        else stopAutoCombo() notify("Auto Combo", "OFF", 2, "Info") end
    end})
ComboTab:AddSlider({Title = "Combo Delay (s)", Min = 0.05, Max = 0.5, Default = 0.08, Flag = "tsb_combo_delay",
    Callback = function(v) AutoComboState.delay = v end})

ComboTab:AddSection("Teleport Behind")
ComboTab:AddToggle({Title = "Teleport Behind Enemy", Description = "Continuously TP behind nearest player", Default = false, Flag = "tsb_tpbehind",
    Callback = function(state)
        TeleportState.enabled = state
        if state then startTeleportBehind() notify("TP Behind", "ON", 2, "Success")
        else stopTeleportBehind() notify("TP Behind", "OFF", 2, "Info") end
    end})
ComboTab:AddSlider({Title = "TP Distance", Min = 1, Max = 8, Default = 4, Flag = "tsb_tpdist",
    Callback = function(v) TeleportState.dist = v end})

ComboTab:AddSection("Teleport")
ComboTab:AddButton({Title = "TP to Nearest Enemy",
    Callback = function()
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end
        local targets = getValidTargets()
        if #targets == 0 then notify("TP", "No targets found", 2, "Warning"); return end
        table.sort(targets, function(a, b)
            return (a.hrp.Position - myHrp.Position).Magnitude < (b.hrp.Position - myHrp.Position).Magnitude
        end)
        local t = targets[1]
        myHrp.CFrame = CFrame.new(t.hrp.Position + Vector3.new(0, 3, 3), t.hrp.Position)
        notify("TP", "Teleported to " .. t.player.Name, 2, "Success")
    end})

local MoveTab = windows:MakeTab({Title = "Movement", Icon = "user"})
MoveTab:AddSection("Speed")
MoveTab:AddToggle({Title = "Walkspeed", Default = false, Flag = "tsb_ws",
    Callback = function(state) MoveState.speedOn = state; if state then startMoveLoop() end end})
MoveTab:AddSlider({Title = "Walkspeed Value", Min = 16, Max = 200, Default = 50, Flag = "tsb_ws_val",
    Callback = function(v) MoveState.speed = v end})
MoveTab:AddToggle({Title = "JumpPower", Default = false, Flag = "tsb_jp",
    Callback = function(state) MoveState.jumpOn = state; if state then startMoveLoop() end end})
MoveTab:AddSlider({Title = "JumpPower Value", Min = 50, Max = 300, Default = 100, Flag = "tsb_jp_val",
    Callback = function(v) MoveState.jump = v end})
MoveTab:AddSection("Physics")
MoveTab:AddToggle({Title = "Infinite Jump", Default = false, Flag = "tsb_ij",
    Callback = function(state)
        IJState.enabled = state
        if state then startIJ() else stopIJ() end
    end})
MoveTab:AddToggle({Title = "Noclip", Default = false, Flag = "tsb_noclip",
    Callback = function(state)
        NoclipState.enabled = state
        if state then startNoclip() else stopNoclip() end
    end})
MoveTab:AddToggle({Title = "Fly", Default = false, Flag = "tsb_fly",
    Callback = function(state)
        FlyState.enabled = state
        if state then startFly() else stopFly() end
    end})
MoveTab:AddSlider({Title = "Fly Speed", Min = 20, Max = 300, Default = 60, Flag = "tsb_fly_speed",
    Callback = function(v) FlyState.speed = v end})

local MiscTab = windows:MakeTab({Title = "Misc", Icon = "settings"})
MiscTab:AddSection("Lighting")
MiscTab:AddToggle({Title = "Fullbright", Default = false, Flag = "tsb_fb",
    Callback = function(state)
        FullbrightState.enabled = state
        if state then startFullbright() else stopFullbright() end
    end})
MiscTab:AddSection("Performance")
MiscTab:AddToggle({Title = "Anti-Lag (Reduce Simulation)", Default = false, Flag = "tsb_antilag",
    Callback = function(state)
        AntiLagState.enabled = state
        if state then startAntiLag() notify("Anti-Lag", "ON", 2, "Success")
        else stopAntiLag() notify("Anti-Lag", "OFF", 2, "Info") end
    end})
MiscTab:AddSection("Utility")
MiscTab:AddToggle({Title = "Anti-AFK", Default = false, Flag = "tsb_afk",
    Callback = function(state)
        if state then
            if not getgenv()._tsbAFK then
                getgenv()._tsbAFK = LocalPlayer.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        else
            if getgenv()._tsbAFK then getgenv()._tsbAFK:Disconnect(); getgenv()._tsbAFK = nil end
        end
    end})
MiscTab:AddButton({Title = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end})
MiscTab:AddButton({Title = "Server Hop", Callback = function() serverHop() end})

notify("Universe Hub", "TSB loaded", 3, "Success")
print("[Universe Hub] The Strongest Battlegrounds loader loaded.")

return redzlib