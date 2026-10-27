local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local LIB_URL = "https://raw.githubusercontent.com/LotuxHub/UniverseHub/refs/heads/main/Library/Library.lua"
if not redzlib then
    local ok, lib = pcall(function() return loadstring(game:HttpGet(LIB_URL))() end)
    if ok and lib then redzlib = lib end
end
assert(redzlib, "[Universe DOORS] Failed to load redzlib")

local function notify(title, desc, dur, kind)
    pcall(function()
        redzlib:Notify({Title = title, Description = desc, Duration = dur or 2, Type = kind or "Info"})
    end)
end

local DOORS_DATA = {
    Entities = {"Rush","Ambush","Screech","Seek","Figure","Hide","Eyes","Dupe","Glitch","Jack","Shadow","Timothy","Snare","Giggle","Grumble","Dread","Halt","Guiding Light"},
    Items = {"Key","Lockpick","Flashlight","Lighter","Battery","Vitamins","Bandage","Crucifix","Candle","Skeleton Key","Gold Coin","GoldBar","Gold Bar"},
}

local function nameMatchesAny(name, list)
    local lower = name:lower()
    for _, target in ipairs(list) do
        if lower:find(target:lower(), 1, true) then return true, target end
    end
    return false, nil
end

local HighlightESP = {
    itemEnabled = false, entityEnabled = false, doorEnabled = false, keyEnabled = false,
    itemColor = Color3.fromRGB(0,200,255), entityColor = Color3.fromRGB(255,60,60),
    doorColor = Color3.fromRGB(255,220,80), keyColor = Color3.fromRGB(0,255,100),
    tracked = {}, conn = nil,
}

local function addHighlight(instance, color)
    if not instance or not instance:IsA("BasePart") then return end
    if HighlightESP.tracked[instance] then
        HighlightESP.tracked[instance].FillColor = color
        return
    end
    local hl = Instance.new("Highlight")
    hl.Name = "UniverseHighlight"
    hl.FillColor = color
    hl.OutlineColor = Color3.new(1,1,1)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = instance
    HighlightESP.tracked[instance] = hl
end

local function clearAllHighlights()
    for instance, hl in pairs(HighlightESP.tracked) do
        if hl and hl.Parent then hl:Destroy() end
    end
    HighlightESP.tracked = {}
end

local function scanForTargets()
    if HighlightESP.itemEnabled or HighlightESP.keyEnabled then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local matched, target = nameMatchesAny(obj.Name, DOORS_DATA.Items)
                if matched then
                    local isKey = target == "Key" or target == "Skeleton Key" or target == "Lockpick"
                    if isKey and HighlightESP.keyEnabled then addHighlight(obj, HighlightESP.keyColor)
                    elseif not isKey and HighlightESP.itemEnabled then addHighlight(obj, HighlightESP.itemColor) end
                end
            end
        end
    end
    if HighlightESP.entityEnabled then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local matched = nameMatchesAny(obj.Name, DOORS_DATA.Entities)
                if matched then
                    local target = obj:IsA("Model") and obj.PrimaryPart or obj
                    if target then addHighlight(target, HighlightESP.entityColor) end
                end
            end
        end
    end
    if HighlightESP.doorEnabled then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("door", 1, true) then
                addHighlight(obj, HighlightESP.doorColor)
            end
        end
    end
end

local function startESPLoop()
    if HighlightESP.conn then return end
    HighlightESP.conn = RunService.Heartbeat:Connect(function()
        if not (HighlightESP.itemEnabled or HighlightESP.entityEnabled or HighlightESP.doorEnabled or HighlightESP.keyEnabled) then
            clearAllHighlights(); return
        end
        pcall(scanForTargets)
    end)
end

local function stopESPLoop()
    if HighlightESP.conn then HighlightESP.conn:Disconnect(); HighlightESP.conn = nil end
    clearAllHighlights()
end

local WarningState = {enabled = false, conn = nil, gui = nil, label = nil, frame = nil}

local function createWarningGui()
    if WarningState.gui then return end
    local g = Instance.new("ScreenGui")
    g.Name = "UniverseDoorsWarning"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 999
    g.Parent = CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(0.5, -150, 0, 80)
    frame.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = g
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = "WARNING"
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 24
    label.Parent = frame
    frame.Visible = false
    WarningState.gui = g
    WarningState.label = label
    WarningState.frame = frame
end

local function showWarning(text)
    if not WarningState.frame then return end
    WarningState.label.Text = text
    WarningState.frame.Visible = true
    task.delay(2, function() if WarningState.frame then WarningState.frame.Visible = false end end)
end

local function startWarningLoop()
    if WarningState.conn then return end
    createWarningGui()
    local shownFor = {}
    WarningState.conn = RunService.Heartbeat:Connect(function()
        if not WarningState.enabled then return end
        for _, obj in ipairs(Workspace:GetChildren()) do
            local name = obj.Name
            if name == "Rush" or name == "Ambush" or name == "Seek" or name == "Figure"
                or name == "Hide" or name == "Eyes" or name == "Dupe" then
                if not shownFor[name] then
                    shownFor[name] = true
                    showWarning(name:upper() .. " INCOMING!")
                    task.delay(10, function() shownFor[name] = nil end)
                end
            end
        end
    end)
end

local function stopWarningLoop()
    if WarningState.conn then WarningState.conn:Disconnect(); WarningState.conn = nil end
    if WarningState.frame then WarningState.frame.Visible = false end
end

local MuteState = {screech = false, jumpscare = false, conn = nil}

local function startMuteLoop()
    if MuteState.conn then return end
    MuteState.conn = RunService.Heartbeat:Connect(function()
        if not (MuteState.screech or MuteState.jumpscare) then return end
        for _, snd in ipairs(SoundService:GetDescendants()) do
            if snd:IsA("Sound") then
                local n = snd.Name:lower()
                if MuteState.screech and n:find("screech", 1, true) then snd.Volume = 0
                elseif MuteState.jumpscare and (n:find("jump", 1, true) or n:find("scare", 1, true)) then snd.Volume = 0 end
            end
        end
    end)
end

local function stopMuteLoop()
    if MuteState.conn then MuteState.conn:Disconnect(); MuteState.conn = nil end
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

local FlyState = {enabled = false, speed = 50, gyro = nil, vel = nil, conn = nil}

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
    FullbrightState.old = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, Ambient = Lighting.Ambient, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime}
    Lighting.FogEnd = 1e9
    Lighting.FogStart = 1e9
    Lighting.Ambient = Color3.new(1,1,1)
    Lighting.Brightness = 3
    Lighting.ClockTime = 14
end

local function stopFullbright()
    for k, v in pairs(FullbrightState.old) do pcall(function() Lighting[k] = v end) end
end

local IMG = "rbxassetid://111672166073808"
local windows = redzlib:MakeWindow({Title = "Universe Hub", SubTitle = "DOORS", SaveFolder = "Universe Hub\\" .. LocalPlayer.Name})

local HomeTab = windows:MakeTab({Title = "Home", Icon = "home"})
HomeTab:AddSection("Welcome To Universe Hub | DOORS")
HomeTab:AddSection("Discord Server")
HomeTab:AddDiscordInvite({Title = "Universe Hub", Desc = "Join our Discord!", Logo = IMG, Invite = "https://discord.gg/HkB97N772p"})

local EspTab = windows:MakeTab({Title = "ESP", Icon = "eye"})
EspTab:AddSection("Highlight ESP")
EspTab:AddToggle({Title = "Item ESP", Description = "Highlight all items", Default = false, Flag = "doors_item_esp",
    Callback = function(state)
        HighlightESP.itemEnabled = state
        if state then startESPLoop() else stopESPLoop() end
        notify("Item ESP", state and "ON" or "OFF", 2, state and "Success" or "Info")
    end})
EspTab:AddToggle({Title = "Key ESP", Default = false, Flag = "doors_key_esp",
    Callback = function(state)
        HighlightESP.keyEnabled = state
        if state then startESPLoop() end
    end})
EspTab:AddToggle({Title = "Entity ESP", Default = false, Flag = "doors_entity_esp",
    Callback = function(state)
        HighlightESP.entityEnabled = state
        if state then startESPLoop() else stopESPLoop() end
        notify("Entity ESP", state and "ON" or "OFF", 2, state and "Success" or "Info")
    end})
EspTab:AddToggle({Title = "Door ESP", Default = false, Flag = "doors_door_esp",
    Callback = function(state)
        HighlightESP.doorEnabled = state
        if state then startESPLoop() else stopESPLoop() end
    end})

local WarnTab = windows:MakeTab({Title = "Warnings", Icon = "alert-triangle"})
WarnTab:AddSection("Entity Alerts")
WarnTab:AddToggle({Title = "Auto-Hide Warning", Default = false, Flag = "doors_warn",
    Callback = function(state)
        WarningState.enabled = state
        if state then startWarningLoop() else stopWarningLoop() end
    end})
WarnTab:AddSection("Audio")
WarnTab:AddToggle({Title = "Anti-Screech", Default = false, Flag = "doors_screech",
    Callback = function(state)
        MuteState.screech = state
        if state then startMuteLoop() else stopMuteLoop() end
    end})
WarnTab:AddToggle({Title = "Anti-Jumpscare", Default = false, Flag = "doors_jumpscare",
    Callback = function(state)
        MuteState.jumpscare = state
        if state then startMuteLoop() else stopMuteLoop() end
    end})

local MoveTab = windows:MakeTab({Title = "Movement", Icon = "user"})
MoveTab:AddSection("Speed")
MoveTab:AddToggle({Title = "Walkspeed", Default = false, Flag = "doors_ws",
    Callback = function(state)
        MoveState.speedOn = state
        if state then startMoveLoop() else stopMoveLoop() end
    end})
MoveTab:AddSlider({Title = "Walkspeed Value", Min = 16, Max = 150, Default = 30, Flag = "doors_ws_val",
    Callback = function(v) MoveState.speed = v end})
MoveTab:AddToggle({Title = "JumpPower", Default = false, Flag = "doors_jp",
    Callback = function(state)
        MoveState.jumpOn = state
        if state then startMoveLoop() else stopMoveLoop() end
    end})
MoveTab:AddSlider({Title = "JumpPower Value", Min = 50, Max = 300, Default = 100, Flag = "doors_jp_val",
    Callback = function(v) MoveState.jump = v end})
MoveTab:AddSection("Physics")
MoveTab:AddToggle({Title = "Noclip", Default = false, Flag = "doors_noclip",
    Callback = function(state)
        NoclipState.enabled = state
        if state then startNoclip() else stopNoclip() end
    end})
MoveTab:AddToggle({Title = "Fly", Default = false, Flag = "doors_fly",
    Callback = function(state)
        FlyState.enabled = state
        if state then startFly() else stopFly() end
    end})
MoveTab:AddSlider({Title = "Fly Speed", Min = 20, Max = 200, Default = 50, Flag = "doors_fly_speed",
    Callback = function(v) FlyState.speed = v end})

local MiscTab = windows:MakeTab({Title = "Misc", Icon = "settings"})
MiscTab:AddSection("Lighting")
MiscTab:AddToggle({Title = "Fullbright", Description = "See in the dark", Default = false, Flag = "doors_fb",
    Callback = function(state)
        FullbrightState.enabled = state
        if state then startFullbright() else stopFullbright() end
    end})
MiscTab:AddSection("Utility")
MiscTab:AddButton({Title = "Clear All ESP",
    Callback = function()
        clearAllHighlights()
        notify("ESP", "Cleared", 2, "Info")
    end})

notify("Universe Hub", "DOORS loaded", 3, "Success")
print("[Universe Hub] DOORS loader loaded.")
return redzlib