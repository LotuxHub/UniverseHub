local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local LIB_URL = "https://raw.githubusercontent.com/LotuxHub/UniverseHub/refs/heads/main/Library/Library.lua"
if not redzlib then
    local ok, lib = pcall(function() return loadstring(game:HttpGet(LIB_URL))() end)
    if ok and lib then redzlib = lib end
end
assert(redzlib, "[Universe BloxFruits] Failed to load redzlib")

local function notify(title, desc, dur, kind)
    pcall(function()
        redzlib:Notify({Title = title, Description = desc, Duration = dur or 2, Type = kind or "Info"})
    end)
end

local IS_MOBILE = UIS.TouchEnabled and not UIS.MouseEnabled

--// Helpers
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isAlive(plr)
    local c = plr.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

--// Detecção
local function getEnemies()
    local list = {}
    local myRoot = getRoot()
    if not myRoot then return list end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0
                and obj ~= LocalPlayer.Character
                and not Players:GetPlayerFromCharacter(obj) then
                table.insert(list, {
                    Model = obj, Humanoid = hum, RootPart = hrp,
                    Distance = (hrp.Position - myRoot.Position).Magnitude
                })
            end
        end
    end
    table.sort(list, function(a, b) return a.Distance < b.Distance end)
    return list
end

local function getChests()
    local list = {}
    local myRoot = getRoot()
    if not myRoot then return list end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local n = obj.Name:lower()
            if n:find("chest") or n:find("baú") or n:find("bau") then
                local pos = obj:IsA("BasePart") and obj.Position
                    or (obj.PrimaryPart and obj.PrimaryPart.Position)
                    or (obj:FindFirstChildWhichIsA("BasePart") and obj:FindFirstChildWhichIsA("BasePart").Position)
                if pos then
                    table.insert(list, {
                        Object = obj, Position = pos,
                        Distance = (pos - myRoot.Position).Magnitude
                    })
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.Distance < b.Distance end)
    return list
end

local FRUIT_NAMES = {
    "Rocket","Spin","Chop","Spring","Bomb","Smoke","Spike","Flame","Falcon",
    "Ice","Sand","Dark","Diamond","Light","Rubber","Barrier","Ghost","Magma",
    "Door","Quake","Human","Buddha","Love","Creation","Spider","Sound","Phoenix",
    "Rumble","Pain","Blizzard","Gravity","Mammoth","T-Rex","Dough","Shadow",
    "Venom","Control","Spirit","Dragon","Leopard","Kitsune","Yeti","Gas",
}

local function getFruits()
    local list = {}
    local myRoot = getRoot()
    if not myRoot then return list end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") or obj:IsA("Model") then
            local n = obj.Name:lower()
            for _, fn in ipairs(FRUIT_NAMES) do
                if n:find(fn:lower(), 1, true) then
                    local pos = obj:IsA("BasePart") and obj.Position
                        or (obj.PrimaryPart and obj.PrimaryPart.Position)
                        or (obj:FindFirstChildWhichIsA("BasePart") and obj:FindFirstChildWhichIsA("BasePart").Position)
                    if pos then
                        table.insert(list, {
                            Object = obj, Name = obj.Name, Position = pos,
                            Distance = (pos - myRoot.Position).Magnitude
                        })
                    end
                    break
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.Distance < b.Distance end)
    return list
end

--// ESP
local ESPState = {
    enabled = false, showName = true, showDist = true,
    showMobs = true, showFruits = false, showChests = false,
    maxDist = 500, tracked = {}, connections = {},
}

local function clearESP()
    for _, entry in pairs(ESPState.tracked) do
        if entry.highlight then entry.highlight:Destroy() end
        if entry.billboard then entry.billboard:Destroy() end
        for _, c in ipairs(entry.connections) do c:Disconnect() end
    end
    ESPState.tracked = {}
end

local function buildESPForModel(model, color, displayName)
    if not model or not model.Parent then return end
    if ESPState.tracked[model] then return end
    local entry = {connections = {}, highlight = nil, billboard = nil, label = nil}
    ESPState.tracked[model] = entry
    local function attach()
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if not head then return end
        if entry.highlight then entry.highlight:Destroy() end
        if entry.billboard then entry.billboard:Destroy() end
        local hl = Instance.new("Highlight")
        hl.Adornee = model
        hl.FillColor = color
        hl.OutlineColor = Color3.new(1,1,1)
        hl.FillTransparency = 0.65
        hl.OutlineTransparency = 0.15
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = CoreGui
        entry.highlight = hl
        local bb = Instance.new("BillboardGui")
        bb.Adornee = head
        bb.Size = UDim2.new(0, 220, 0, 34)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = CoreGui
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.new(1,1,1)
        lbl.TextStrokeTransparency = 0
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Text = displayName or model.Name
        lbl.Parent = bb
        entry.billboard = bb
        entry.label = lbl
    end
    attach()
    table.insert(entry.connections, model.AncestryChanged:Connect(function()
        if not model:IsDescendantOf(Workspace) then
            if entry.highlight then entry.highlight:Destroy() end
            if entry.billboard then entry.billboard:Destroy() end
        end
    end))
end

local function startESP()
    if #ESPState.connections > 0 then return end
    table.insert(ESPState.connections, RunService.RenderStepped:Connect(function()
        if not ESPState.enabled then return end
        local myRoot = getRoot()
        if not myRoot then return end

        -- Players
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and isAlive(plr) then
                buildESPForModel(plr.Character, Color3.fromRGB(255, 60, 60), plr.DisplayName)
            end
        end

        -- Mobs
        if ESPState.showMobs then
            for _, e in ipairs(getEnemies()) do
                buildESPForModel(e.Model, Color3.fromRGB(255, 160, 60), e.Model.Name)
            end
        end

        -- Fruits
        if ESPState.showFruits then
            for _, f in ipairs(getFruits()) do
                buildESPForModel(f.Object, Color3.fromRGB(160, 90, 255), f.Name)
            end
        end

        -- Chests
        if ESPState.showChests then
            for _, c in ipairs(getChests()) do
                buildESPForModel(c.Object, Color3.fromRGB(255, 215, 0), "Chest")
            end
        end

        -- Atualiza distâncias + visibilidade
        for model, entry in pairs(ESPState.tracked) do
            if not model.Parent then
                if entry.highlight then entry.highlight:Destroy() end
                if entry.billboard then entry.billboard:Destroy() end
                for _, c in ipairs(entry.connections) do c:Disconnect() end
                ESPState.tracked[model] = nil
            elseif entry.billboard and entry.label then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - myRoot.Position).Magnitude
                    local visible = dist <= ESPState.maxDist and ESPState.enabled
                    local parts = {}
                    if ESPState.showName then
                        local plr = Players:GetPlayerFromCharacter(model)
                        table.insert(parts, plr and plr.DisplayName or model.Name)
                    end
                    if ESPState.showDist then table.insert(parts, string.format("%.0fm", dist)) end
                    entry.label.Text = table.concat(parts, " | ")
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
    clearESP()
end

--// Aimbot
local AimbotState = {
    enabled = false, targetPart = "Head", fov = 200, smoothness = 0.35,
    teamCheck = true, visibleCheck = false, conn = nil,
}

local function isEnemy(plr)
    if not AimbotState.teamCheck then return true end
    if plr.Team and LocalPlayer.Team then return plr.Team ~= LocalPlayer.Team end
    return true
end

local function getAimbotTarget()
    local myRoot = getRoot()
    if not myRoot then return nil end
    local mouse = UIS:GetMouseLocation()
    local best, bestDot = nil, -math.huge
    local ray = Camera:ScreenPointToRay(mouse.X, mouse.Y)
    local pointer = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) and isEnemy(plr) then
            local part = plr.Character:FindFirstChild(AimbotState.targetPart)
            if part then
                local sp, onScreen = Camera:WorldToScreenPoint(part.Position)
                if onScreen then
                    local d2d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                    if d2d <= AimbotState.fov then
                        if AimbotState.visibleCheck then
                            local origin = Camera.CFrame.Position
                            local dir = part.Position - origin
                            local rp = RaycastParams.new()
                            rp.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                            rp.FilterType = Enum.RaycastFilterType.Exclude
                            local res = Workspace:Raycast(origin, dir, rp)
                            if not (res and not res.Instance:IsDescendantOf(plr.Character)) then
                                local dot = pointer.LookVector:Dot((part.Position - Camera.CFrame.Position).Unit)
                                if dot > bestDot then bestDot = dot; best = part end
                            end
                        else
                            local dot = pointer.LookVector:Dot((part.Position - Camera.CFrame.Position).Unit)
                            if dot > bestDot then bestDot = dot; best = part end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function startAimbot()
    if AimbotState.conn then return end
    AimbotState.conn = RunService.RenderStepped:Connect(function()
        if not AimbotState.enabled then return end
        local part = getAimbotTarget()
        if not part then return end
        local newCF = CFrame.new(Camera.CFrame.Position, part.Position)
        Camera.CFrame = Camera.CFrame:Lerp(newCF, math.clamp(AimbotState.smoothness, 0.05, 1))
    end)
end

local function stopAimbot()
    if AimbotState.conn then AimbotState.conn:Disconnect(); AimbotState.conn = nil end
end

--// FOV Circle
local FOVCircle = {gui = nil, frame = nil, enabled = false, conn = nil}

local function startFOVCircle()
    if not FOVCircle.gui then
        local g = Instance.new("ScreenGui")
        g.Name = "UniverseFOV"; g.ResetOnSpawn = false; g.IgnoreGuiInset = true
        g.DisplayOrder = 5; g.Parent = CoreGui
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5,0.5); f.Position = UDim2.new(0.5,0,0.5,0)
        f.BackgroundTransparency = 1; f.Parent = g
        local c = Instance.new("ImageLabel")
        c.Size = UDim2.fromScale(1,1); c.BackgroundTransparency = 1
        c.Image = "rbxassetid://3570695787"; c.ImageColor3 = Color3.fromRGB(255,60,60)
        c.ImageTransparency = 0.4; c.ScaleType = Enum.ScaleType.Fit; c.Parent = f
        FOVCircle.gui = g; FOVCircle.frame = f
    end
    FOVCircle.gui.Enabled = true
    if FOVCircle.conn then FOVCircle.conn:Disconnect() end
    FOVCircle.conn = RunService.RenderStepped:Connect(function()
        if not FOVCircle.enabled then return end
        FOVCircle.frame.Size = UDim2.fromOffset(AimbotState.fov * 2, AimbotState.fov * 2)
    end)
end

local function stopFOVCircle()
    if FOVCircle.gui then FOVCircle.gui.Enabled = false end
    if FOVCircle.conn then FOVCircle.conn:Disconnect(); FOVCircle.conn = nil end
end

--// Auto Farm
local FarmState = {
    enabled = false, method = "Nearest", range = 150,
    chestEnabled = false, conn = nil, chestConn = nil,
}

local function attackMob(enemy)
    local root = getRoot()
    local hum = getHumanoid()
    if not root or not hum or not enemy.RootPart then return end
    if enemy.Distance > FarmState.range then return end
    local behind = enemy.RootPart.CFrame * CFrame.new(0, 0, 3)
    root.CFrame = CFrame.new(behind.Position, enemy.RootPart.Position)
    local tool = hum:FindFirstChildWhichIsA("Tool")
    if tool then pcall(function() tool:Activate() end) end
    local char = getCharacter()
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then pcall(function() v:Activate() end); break end
    end
end

local function startFarm()
    if FarmState.conn then return end
    FarmState.conn = RunService.Heartbeat:Connect(function()
        if not FarmState.enabled then return end
        local enemies = getEnemies()
        if #enemies == 0 then return end
        if FarmState.method == "Nearest" then
            attackMob(enemies[1])
        else
            local myLevel = LocalPlayer:GetAttribute("Level") or 1
            local bestEnemy, bestDiff = enemies[1], math.huge
            for _, e in ipairs(enemies) do
                local lvl = e.Humanoid:GetAttribute("Level") or 1
                local diff = math.abs(myLevel - lvl)
                if diff < bestDiff then bestDiff = diff; bestEnemy = e end
            end
            attackMob(bestEnemy)
        end
    end)
end

local function stopFarm()
    if FarmState.conn then FarmState.conn:Disconnect(); FarmState.conn = nil end
end

local function startChestFarm()
    if FarmState.chestConn then return end
    FarmState.chestConn = RunService.Heartbeat:Connect(function()
        if not FarmState.chestEnabled then return end
        local chests = getChests()
        local root = getRoot()
        if not root then return end
        for _, c in ipairs(chests) do
            if c.Distance <= 300 then
                root.CFrame = CFrame.new(c.Position + Vector3.new(0, 3, 0))
                task.wait(0.1)
            end
        end
    end)
end

local function stopChestFarm()
    if FarmState.chestConn then FarmState.chestConn:Disconnect(); FarmState.chestConn = nil end
end

--// Auto Stats
local AutoStats = {enabled = false, stat = "Melee", points = 1, conn = nil}

local function startAutoStats()
    if AutoStats.conn then return end
    AutoStats.conn = RunService.Heartbeat:Connect(function()
        if not AutoStats.enabled then return end
        local remote = ReplicatedStorage:FindFirstChild("Remotes")
        if remote then
            local statRemote = remote:FindFirstChild("CommF_")
            if statRemote then
                pcall(function() statRemote:InvokeServer("AddPoint", AutoStats.stat, AutoStats.points) end)
            end
        end
        task.wait(0.5)
    end)
end

local function stopAutoStats()
    if AutoStats.conn then AutoStats.conn:Disconnect(); AutoStats.conn = nil end
end

--// Fruit Sniper
local FruitSniper = {enabled = false, selected = {}, conn = nil, maxDist = 500}

local function startFruitSniper()
    if FruitSniper.conn then return end
    FruitSniper.conn = RunService.Heartbeat:Connect(function()
        if not FruitSniper.enabled then return end
        local fruits = getFruits()
        for _, f in ipairs(fruits) do
            if f.Distance <= FruitSniper.maxDist then
                local ok = FruitSniper.selected[f.Name]
                if ok ~= false then
                    local root = getRoot()
                    if root then root.CFrame = CFrame.new(f.Position + Vector3.new(0,3,0)) end
                    task.wait(0.2)
                end
            end
        end
    end)
end

local function stopFruitSniper()
    if FruitSniper.conn then FruitSniper.conn:Disconnect(); FruitSniper.conn = nil end
end

--// Movement
local MoveState = {speed = 16, jump = 50, speedOn = false, jumpOn = false, conn = nil}

local function startMoveLoop()
    if MoveState.conn then return end
    MoveState.conn = RunService.Heartbeat:Connect(function()
        local hum = getHumanoid()
        if not hum then return end
        if MoveState.speedOn then hum.WalkSpeed = MoveState.speed end
        if MoveState.jumpOn then hum.JumpPower = MoveState.jump end
    end)
end

--// Noclip
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

--// Fly
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
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
end

--// Fullbright
local FullbrightState = {enabled = false, old = {}}

local function startFullbright()
    FullbrightState.old = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, Ambient = Lighting.Ambient, Brightness = Lighting.Brightness}
    Lighting.FogEnd = 1e9; Lighting.FogStart = 1e9
    Lighting.Ambient = Color3.new(1,1,1); Lighting.Brightness = 2.5
end

local function stopFullbright()
    for k, v in pairs(FullbrightState.old) do pcall(function() Lighting[k] = v end) end
end

--// Infinite Jump
local IJState = {enabled = false, conn = nil}

local function startIJ()
    if IJState.conn then return end
    IJState.conn = UIS.JumpRequest:Connect(function()
        if not IJState.enabled then return end
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function stopIJ()
    if IJState.conn then IJState.conn:Disconnect(); IJState.conn = nil end
end

--// Server Hop
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

--// Islands
local ISLANDS = {
    ["Ilha Inicial"]      = CFrame.new(1070, 15, 1560),
    ["Bandit Camp"]       = CFrame.new(1050, 15, 1300),
    ["Frozen Village"]    = CFrame.new(1140, 15, -1160),
    ["Marine Fort"]       = CFrame.new(-2500, 20, -3200),
    ["Skypiea"]           = CFrame.new(-4800, 800, -2400),
    ["Punk Hazard"]       = CFrame.new(-5800, 50, -5000),
    ["Sea 3 - Castelo"]   = CFrame.new(-12400, 400, -7400),
    ["Dressrosa"]         = CFrame.new(-1350, 100, 3500),
    ["Zou"]               = CFrame.new(-1650, 50, 2500),
}

--// GUI
local IMG = "rbxassetid://111672166073808"
local windows = redzlib:MakeWindow({Title = "Universe Hub", SubTitle = "Blox Fruits", SaveFolder = "Universe Hub\\" .. LocalPlayer.Name})

local HomeTab = windows:MakeTab({Title = "Home", Icon = "home"})
HomeTab:AddSection("Welcome To Universe Hub | Blox Fruits")
HomeTab:AddSection("Discord Server")
HomeTab:AddDiscordInvite({Title = "Universe Hub", Desc = "Join our Discord for updates!", Logo = IMG, Invite = "https://discord.gg/HkB97N772p"})
HomeTab:AddSection("Aviso")
HomeTab:AddParagraph({
    Title = "Uso responsável",
    Text = "Este script é open source e foi criado do zero seguindo a estrutura do Universe Hub.\nUse por sua conta e risco — prefira contas secundárias."
})

-- Farm
local FarmTab = windows:MakeTab({Title = "Farm", Icon = "zap"})
FarmTab:AddSection("Auto Farm")
FarmTab:AddToggle({Title = "Auto Farm", Description = "Ataca mobs automaticamente", Default = false, Flag = "bf_farm",
    Callback = function(state)
        FarmState.enabled = state
        if state then startFarm() notify("Auto Farm", "ON", 2, "Success")
        else stopFarm() notify("Auto Farm", "OFF", 2, "Info") end
    end})
FarmTab:AddDropdown({Title = "Farm Method", Options = {"Nearest", "Level"}, Default = "Nearest", Flag = "bf_farm_method",
    Callback = function(v) FarmState.method = (typeof(v) == "table" and v[1]) or v end})
FarmTab:AddSlider({Title = "Farm Range", Min = 50, Max = 500, Default = 150, Flag = "bf_farm_range",
    Callback = function(v) FarmState.range = v end})
FarmTab:AddSection("Auto Chest")
FarmTab:AddToggle({Title = "Auto Chest", Description = "Teleporta em baús próximos", Default = false, Flag = "bf_chest",
    Callback = function(state)
        FarmState.chestEnabled = state
        if state then startChestFarm() notify("Auto Chest", "ON", 2, "Success")
        else stopChestFarm() notify("Auto Chest", "OFF", 2, "Info") end
    end})
FarmTab:AddSection("Auto Stats")
FarmTab:AddToggle({Title = "Auto Stats", Description = "Distribui pontos automaticamente", Default = false, Flag = "bf_stats",
    Callback = function(state)
        AutoStats.enabled = state
        if state then startAutoStats() notify("Auto Stats", "ON", 2, "Success")
        else stopAutoStats() notify("Auto Stats", "OFF", 2, "Info") end
    end})
FarmTab:AddDropdown({Title = "Stat", Options = {"Melee","Defense","Sword","Gun","Demon Fruit"}, Default = "Melee", Flag = "bf_stat_type",
    Callback = function(v) AutoStats.stat = (typeof(v) == "table" and v[1]) or v end})
FarmTab:AddSlider({Title = "Pontos por Vez", Min = 1, Max = 10, Default = 1, Flag = "bf_stat_pts",
    Callback = function(v) AutoStats.points = v end})

-- ESP
local EspTab = windows:MakeTab({Title = "ESP", Icon = "eye"})
EspTab:AddSection("Player ESP")
EspTab:AddToggle({Title = "Enable ESP", Default = false, Flag = "bf_esp",
    Callback = function(state)
        ESPState.enabled = state
        if state then startESP() notify("ESP", "ON", 2, "Success")
        else stopESP() notify("ESP", "OFF", 2, "Info") end
    end})
EspTab:AddToggle({Title = "Show Name", Default = true, Flag = "bf_esp_name",
    Callback = function(s) ESPState.showName = s end})
EspTab:AddToggle({Title = "Show Distance", Default = true, Flag = "bf_esp_dist",
    Callback = function(s) ESPState.showDist = s end})
EspTab:AddSlider({Title = "Max Distance", Min = 50, Max = 2000, Default = 500, Flag = "bf_esp_maxd",
    Callback = function(v) ESPState.maxDist = v end})
EspTab:AddSection("World ESP")
EspTab:AddToggle({Title = "Mob ESP", Default = true, Flag = "bf_esp_mobs",
    Callback = function(s) ESPState.showMobs = s end})
EspTab:AddToggle({Title = "Fruit ESP", Default = false, Flag = "bf_esp_fruits",
    Callback = function(s) ESPState.showFruits = s end})
EspTab:AddToggle({Title = "Chest ESP", Default = false, Flag = "bf_esp_chests",
    Callback = function(s) ESPState.showChests = s end})

-- Aimbot
local AimTab = windows:MakeTab({Title = "Aimbot", Icon = "crosshair"})
AimTab:AddSection("Aimbot")
AimTab:AddToggle({Title = "Enable Aimbot", Default = false, Flag = "bf_aim",
    Callback = function(state)
        AimbotState.enabled = state
        if state then startAimbot() notify("Aimbot", "ON", 2, "Success")
        else stopAimbot() notify("Aimbot", "OFF", 2, "Info") end
    end})
AimTab:AddDropdown({Title = "Aim Part", Options = {"Head","HumanoidRootPart","UpperTorso"}, Default = "Head", Flag = "bf_aim_part",
    Callback = function(v) AimbotState.targetPart = (typeof(v) == "table" and v[1]) or v end})
AimTab:AddSlider({Title = "FOV", Min = 50, Max = 800, Default = 200, Flag = "bf_aim_fov",
    Callback = function(v) AimbotState.fov = v end})
AimTab:AddSlider({Title = "Smoothness", Min = 0.05, Max = 1, Default = 0.35, Flag = "bf_aim_smooth",
    Callback = function(v) AimbotState.smoothness = v end})
AimTab:AddToggle({Title = "Team Check", Default = true, Flag = "bf_aim_team",
    Callback = function(s) AimbotState.teamCheck = s end})
AimTab:AddToggle({Title = "Visible Check", Default = false, Flag = "bf_aim_vis",
    Callback = function(s) AimbotState.visibleCheck = s end})
AimTab:AddToggle({Title = "Show FOV Circle", Default = false, Flag = "bf_aim_fovc",
    Callback = function(state)
        FOVCircle.enabled = state
        if state then startFOVCircle() else stopFOVCircle() end
    end})

-- Fruit Sniper
local FruitTab = windows:MakeTab({Title = "Fruit Sniper", Icon = "star"})
FruitTab:AddSection("Fruit Sniper")
FruitTab:AddToggle({Title = "Enable Fruit Sniper", Description = "Teleporta para frutas spawnadas", Default = false, Flag = "bf_sniper",
    Callback = function(state)
        FruitSniper.enabled = state
        if state then startFruitSniper() notify("Fruit Sniper", "ON", 2, "Success")
        else stopFruitSniper() notify("Fruit Sniper", "OFF", 2, "Info") end
    end})
FruitTab:AddSlider({Title = "Max Distance", Min = 100, Max = 2000, Default = 500, Flag = "bf_sniper_maxd",
    Callback = function(v) FruitSniper.maxDist = v end})

-- Player / Movement
local PlayerTab = windows:MakeTab({Title = "Player", Icon = "user"})
PlayerTab:AddSection("Speed")
PlayerTab:AddToggle({Title = "Walkspeed", Default = false, Flag = "bf_ws",
    Callback = function(s) MoveState.speedOn = s; if s then startMoveLoop() end end})
PlayerTab:AddSlider({Title = "Walkspeed Value", Min = 16, Max = 200, Default = 40, Flag = "bf_ws_val",
    Callback = function(v) MoveState.speed = v end})
PlayerTab:AddToggle({Title = "JumpPower", Default = false, Flag = "bf_jp",
    Callback = function(s) MoveState.jumpOn = s; if s then startMoveLoop() end end})
PlayerTab:AddSlider({Title = "JumpPower Value", Min = 50, Max = 300, Default = 100, Flag = "bf_jp_val",
    Callback = function(v) MoveState.jump = v end})
PlayerTab:AddSection("Physics")
PlayerTab:AddToggle({Title = "Infinite Jump", Default = false, Flag = "bf_ij",
    Callback = function(s) IJState.enabled = s; if s then startIJ() else stopIJ() end end})
PlayerTab:AddToggle({Title = "Noclip", Default = false, Flag = "bf_noclip",
    Callback = function(s) NoclipState.enabled = s; if s then startNoclip() else stopNoclip() end end})
PlayerTab:AddToggle({Title = "Fly", Default = false, Flag = "bf_fly",
    Callback = function(s) FlyState.enabled = s; if s then startFly() else stopFly() end end})
PlayerTab:AddSlider({Title = "Fly Speed", Min = 20, Max = 200, Default = 60, Flag = "bf_fly_speed",
    Callback = function(v) FlyState.speed = v end})

-- Teleports
local TPTab = windows:MakeTab({Title = "Teleports", Icon = "map-pin"})
TPTab:AddSection("Islands")
for name, cf in pairs(ISLANDS) do
    TPTab:AddButton({Title = name,
        Callback = function()
            local root = getRoot()
            if root then
                root.CFrame = cf
                notify("Teleport", "Indo para " .. name, 2, "Success")
            end
        end})
end
TPTab:AddSection("Player")
TPTab:AddTextBox({Title = "Target Name", PlaceholderText = "Player username", Default = "", Flag = "bf_tp_target",
    Callback = function(t) getgenv().bf_tp_target = t end})
TPTab:AddButton({Title = "TP to Player",
    Callback = function()
        local t = getgenv().bf_tp_target
        if not t or t == "" then notify("TP", "Insira um nome", 2, "Warning"); return end
        local plr = Players:FindFirstChild(t)
        if plr and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local root = getRoot()
            if hrp and root then
                root.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 3))
                notify("TP", "Teleportado para " .. t, 2, "Success")
            end
        else
            notify("TP", "Jogador não encontrado", 2, "Warning")
        end
    end})

-- Misc
local MiscTab = windows:MakeTab({Title = "Misc", Icon = "settings"})
MiscTab:AddSection("Lighting")
MiscTab:AddToggle({Title = "Fullbright", Default = false, Flag = "bf_fb",
    Callback = function(s) FullbrightState.enabled = s; if s then startFullbright() else stopFullbright() end end})
MiscTab:AddSection("Anti-AFK")
MiscTab:AddToggle({Title = "Anti-AFK", Default = false, Flag = "bf_afk",
    Callback = function(state)
        if state then
            if not getgenv()._bfAFK then
                getgenv()._bfAFK = LocalPlayer.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        else
            if getgenv()._bfAFK then getgenv()._bfAFK:Disconnect(); getgenv()._bfAFK = nil end
        end
    end})
MiscTab:AddSection("Server")
MiscTab:AddButton({Title = "Rejoin Server",
    Callback = function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end})
MiscTab:AddButton({Title = "Server Hop", Callback = function() serverHop() end})

-- Panic
MiscTab:AddSection("Emergência")
MiscTab:AddButton({Title = "PANIC — Desligar tudo",
    Callback = function()
        FarmState.enabled = false; FarmState.chestEnabled = false
        ESPState.enabled = false; AimbotState.enabled = false
        FruitSniper.enabled = false; AutoStats.enabled = false
        MoveState.speedOn = false; MoveState.jumpOn = false
        NoclipState.enabled = false; FlyState.enabled = false
        IJState.enabled = false; FullbrightState.enabled = false
        pcall(stopFarm); pcall(stopChestFarm); pcall(stopESP)
        pcall(stopAimbot); pcall(stopFruitSniper); pcall(stopAutoStats)
        pcall(stopNoclip); pcall(stopFly); pcall(stopIJ)
        pcall(stopFullbright); pcall(stopFOVCircle)
        notify("PANIC", "Todas as funções desligadas", 3, "Warning")
    end})

notify("Universe Hub", "Blox Fruits loaded", 3, "Success")
print("[Universe Hub] Blox Fruits loader loaded.")
return redzlib