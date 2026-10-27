local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Alive = Workspace:FindFirstChild("Alive") or Workspace:WaitForChild("Alive")
local Runtime = Workspace:FindFirstChild("Runtime") or Workspace:WaitForChild("Runtime")

local Connections = getgenv().UniverseConnections or {}
getgenv().UniverseConnections = Connections

local LIB_URL = "https://raw.githubusercontent.com/LotuxHub/UniverseHub/refs/heads/main/Library/Library.lua"
if not redzlib then
    local ok, lib = pcall(function() return loadstring(game:HttpGet(LIB_URL))() end)
    if ok and lib then redzlib = lib end
end
assert(redzlib, "[Universe Bladeball] Failed to load redzlib")

local function notify(title, desc, dur, kind)
    pcall(function()
        redzlib:Notify({Title = title, Description = desc, Duration = dur or 2, Type = kind or "Info"})
    end)
end

local IS_MOBILE = UIS.TouchEnabled and not UIS.MouseEnabled
getgenv().UniverseMobile = IS_MOBILE

local _PARRY_PATCH = {
    tokenFn = nil, tokenReady = false,
    keyTable = nil, transformFn = nil, parryHash = nil,
    parryRemote = nil, capturedArgs = nil,
    ready = false, method = nil,
    _lastFire = 0,
}

local function _rand_delay()
    return math.random(42, 138) / 1000
end

local function _jitter_float(base, range)
    return base + (math.random() * range * 2 - range)
end

task.spawn(function()
    pcall(function()
        local Controllers = ReplicatedStorage:WaitForChild("Controllers", 15)
        if not Controllers then return end
        local SC
        for _, c in ipairs(Controllers:GetChildren()) do
            if c.Name:sub(1, 16) == "SwordsController" then SC = c; break end
        end
        if not SC then return end
        local PRY = SC:WaitForChild("PRY", 15)
        if not PRY then return end
        local PF = require(PRY)
        local gup = debug.getupvalues or getupvalues
        if not gup then return end
        local ups = gup(PF)
        if not ups or #ups < 8 then return end
        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.parryHash   = ups[8]
        _PARRY_PATCH.method = "keytable"
    end)
end)

task.spawn(function()
    task.wait(2)
    pcall(function()
        if type(getgc) ~= "function" then return end
        if _PARRY_PATCH.tokenReady then return end
        local limit = 0
        for _, fn in getgc(true) do
            if type(fn) ~= "function" then continue end
            limit += 1
            if limit > 40000 then break end
            local ok, src = pcall(function() return debug.info(fn, "s") end)
            if not ok or not src then continue end
            if not tostring(src):find("PRY", 1, true) then continue end
            local ok2, ups = pcall(function() return debug.getupvalues(fn) end)
            if not ok2 or type(ups) ~= "table" then continue end
            for _, val in pairs(ups) do
                if type(val) == "function" then
                    _PARRY_PATCH.tokenFn = val
                    _PARRY_PATCH.tokenReady = true
                    _PARRY_PATCH.method = "getgc"
                    return
                end
            end
        end
    end)
end)

local _canHook = (type(getrawmetatable) == "function" and type(setreadonly) == "function")
local _hooked = {}

local function _is_valid(args)
    return #args == 8
        and type(args[2]) == "string" and type(args[3]) == "string"
        and type(args[4]) == "number" and typeof(args[5]) == "CFrame"
        and type(args[6]) == "table" and type(args[7]) == "table"
        and type(args[8]) == "boolean"
end

local function _hook(remote)
    if not _canHook then return end
    local mt = getrawmetatable(remote)
    if not mt or _hooked[mt] then return end
    _hooked[mt] = true
    setreadonly(mt, false)
    local _old = mt.__index
    mt.__index = newcclosure(function(self, key)
        if (key == "FireServer" and self:IsA("RemoteEvent"))
            or (key == "InvokeServer" and self:IsA("RemoteFunction")) then
            return newcclosure(function(_, ...)
                local a = {...}
                if _is_valid(a) and not _PARRY_PATCH.ready then
                    _PARRY_PATCH.parryRemote = self
                    _PARRY_PATCH.capturedArgs = a
                    _PARRY_PATCH.ready = true
                end
                return _old(self, key)(_, unpack(a))
            end)
        end
        return _old(self, key)
    end)
    setreadonly(mt, true)
end

if _canHook then
    for _, r in pairs(ReplicatedStorage:GetDescendants()) do
        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
            pcall(_hook, r)
        end
    end
end

local function _tokenize_getgc(uid)
    if not _PARRY_PATCH.tokenFn then return nil end
    local ok, key = pcall(_PARRY_PATCH.tokenFn, uid, "TIME")
    if not ok or type(key) ~= "string" or #key == 0 then
        ok, key = pcall(_PARRY_PATCH.tokenFn, uid)
        if not ok or type(key) ~= "string" or #key == 0 then return nil end
    end
    local time = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local chars = table.create(#time)
    for i = 1, #time do
        chars[i] = string.char(bit32.bxor(
            (string.byte(time, i) + i) % 256,
            string.byte(key, (i - 1) % #key + 1)
        ))
    end
    return table.concat(chars)
end

local function _tokenize_keytable()
    local kt = _PARRY_PATCH.keyTable
    if not kt then return nil, nil end
    local ki = kt[1]
    local curKey = kt[2] and kt[2][ki]
    if not curKey then return nil, nil end
    local ok, transformed = pcall(_PARRY_PATCH.transformFn, curKey, "TIME")
    if not ok or type(transformed) ~= "string" then
        ok, transformed = pcall(_PARRY_PATCH.transformFn, curKey)
        if not ok or type(transformed) ~= "string" then return nil, nil end
    end
    local timeStr = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local tc = {}
    for i = 1, #timeStr do
        local kix = (i - 1) % #transformed + 1
        tc[i] = string.char(bit32.bxor(
            (string.byte(timeStr, i) + i) % 256,
            string.byte(transformed, kix)
        ))
    end
    return curKey, table.concat(tc)
end

function _PARRY_PATCH.fire(curveCF, sp, ml)
    if not _PARRY_PATCH.ready or not _PARRY_PATCH.parryRemote or not _PARRY_PATCH.capturedArgs then return false end

    local now = tick()
    local minGap = math.random(35, 75) / 1000
    if (now - _PARRY_PATCH._lastFire) < minGap then return false end
    _PARRY_PATCH._lastFire = now

    local args = _PARRY_PATCH.capturedArgs
    local uid = args[2]
    local accuracy_jitter = _jitter_float(args[4], 0.08)

    if _PARRY_PATCH.tokenReady and uid then
        local token = _tokenize_getgc(uid)
        if token then
            local ok = pcall(function()
                _PARRY_PATCH.parryRemote:FireServer(
                    args[1], uid, token,
                    accuracy_jitter,
                    curveCF, sp, ml, false
                )
            end)
            if ok then return true end
        end
    end

    local ck, token = _tokenize_keytable()
    if ck and token then
        local ok = pcall(function()
            _PARRY_PATCH.parryRemote:FireServer(
                _PARRY_PATCH.parryHash, ck, token,
                accuracy_jitter,
                curveCF, sp, ml, false
            )
        end)
        if ok then return true end
    end

    return false
end

local System = {
    __properties = {
        __autoparry_enabled=false, __triggerbot_enabled=false,
        __manual_spam_enabled=false, __auto_spam_enabled=false,
        __curve_mode=1, __accuracy=50, __divisor_multiplier=1.1,
        __parried=false, __training_parried=false, __spam_threshold=1,
        __parries=0, __tornado_time=tick(), __connections={},
        __spam_accumulator=0, __spam_rate=1000,
        __infinity_active=false, __deathslash_active=false,
        __timehole_active=false, __slashesoffury_active=false,
        __slashesoffury_count=0,
        __humanizer_enabled=false, __humanizer_min_accuracy=1,
        __humanizer_max_accuracy=50, __humanizer_last_update=0,
        __humanizer_next_change=0.8,
        __is_mobile = IS_MOBILE,
        __last_parry_time = 0,
    },
    __config = {
        __curve_names = {'Camera','Random','Accelerated','Backwards','Slow','High','Normal','Speed','Down','Left','Right'},
        __detections = { __infinity=false, __deathslash=false, __timehole=false, __slashesoffury=false, __phantom=false, __dribble=false },
    },
    __triggerbot = { __enabled=false, __is_parrying=false, __parries=0, __max_parries=10000, __parry_delay=0.5 },
}

System.ball = {}
System.player = {}
System.curve = {}
System.parry = {}
System.manual_spam = {}
System.auto_spam = {}
System.autoparry = {}
System.triggerbot = System.__triggerbot

local maxParryCount = 36
local parryDelay = 0.05
local Closest_Entity = nil

function System.ball.get()
    local b = Workspace:FindFirstChild("Balls"); if not b then return nil end
    for _, ball in pairs(b:GetChildren()) do
        if ball:GetAttribute("realBall") then ball.CanCollide = false; return ball end
    end
end

function System.ball.get_all()
    local t = {}; local b = Workspace:FindFirstChild("Balls"); if not b then return t end
    for _, ball in pairs(b:GetChildren()) do
        if ball:GetAttribute("realBall") then ball.CanCollide = false; table.insert(t, ball) end
    end
    return t
end

function System.player.get_closest()
    local md, closest = math.huge, nil
    if not Alive then return nil end
    for _, e in pairs(Alive:GetChildren()) do
        if e ~= LocalPlayer.Character and e.PrimaryPart then
            local d = LocalPlayer:DistanceFromCharacter(e.PrimaryPart.Position)
            if d < md then md, closest = d, e end
        end
    end
    Closest_Entity = closest; return closest
end

function System.player.get_closest_to_cursor()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local closest, min_dot = nil, -math.huge
    local cam = workspace.CurrentCamera
    local ok, m = pcall(function() return UIS:GetMouseLocation() end); if not ok then return nil end
    local ray = cam:ScreenPointToRay(m.X, m.Y)
    local pointer = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
    for _, p in pairs(Alive:GetChildren()) do
        if p == LocalPlayer.Character or not p:FindFirstChild("HumanoidRootPart") then continue end
        local dir = (p.HumanoidRootPart.Position - cam.CFrame.Position).Unit
        local dot = pointer.LookVector:Dot(dir)
        if dot > min_dot then min_dot, closest = dot, p end
    end
    return closest
end

function System.curve.get_cframe()
    local cam = workspace.CurrentCamera
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return cam.CFrame end
    local t = System.player.get_closest_to_cursor()
    local tp = t and t:FindFirstChild("HumanoidRootPart") and t.HumanoidRootPart.Position
        or (root.Position + cam.CFrame.LookVector * 100)
    local mode = System.__config.__curve_names[System.__properties.__curve_mode]
    if mode == "Normal" then return CFrame.new(root.Position, root.Position + root.CFrame.LookVector) end
    if mode == "Speed"  then return CFrame.new(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.UpVector * 5) end
    if mode == "Down"   then return CFrame.new(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.UpVector * -9e9) end
    if mode == "Left"   then return CFrame.new(cam.CFrame.Position, cam.CFrame.Position - cam.CFrame.RightVector * 9e9) end
    if mode == "Right"  then return CFrame.new(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.RightVector * 9e9) end
    local fns = {
        function() return cam.CFrame end,
        function()
            local dir = (tp - root.Position).Unit
            local off, i = nil, 0
            repeat
                off = Vector3.new(math.random(-4000,4000), math.random(-4000,4000), math.random(-4000,4000))
                i += 1
            until dir:Dot((tp + off - root.Position).Unit) < 0.95 or i > 10
            return CFrame.new(root.Position, tp + off)
        end,
        function() return CFrame.new(root.Position, tp + Vector3.new(0, 5, 0)) end,
        function() return CFrame.new(cam.CFrame.Position, root.Position + (root.Position - tp).Unit * 10000 + Vector3.new(0, 1000, 0)) end,
        function() return CFrame.new(root.Position, tp + Vector3.new(0, -9e18, 0)) end,
        function() return CFrame.new(root.Position, tp + Vector3.new(0,  9e18, 0)) end,
        function() return CFrame.new(root.Position, root.Position - cam.CFrame.RightVector * 10000) end,
        function() return CFrame.new(root.Position, root.Position + cam.CFrame.RightVector * 10000) end,
    }
    return fns[System.__properties.__curve_mode]() or cam.CFrame
end

function System.parry.execute()
    if System.__properties.__parries > 10000 or not LocalPlayer.Character then return end
    if not _PARRY_PATCH.ready then return end
    local now = tick()
    local minInterval = math.random(30, 80) / 1000
    if (now - System.__properties.__last_parry_time) < minInterval then return end
    System.__properties.__last_parry_time = now
    local cam = workspace.CurrentCamera
    local ok, mouse = pcall(function() return UIS:GetMouseLocation() end); if not ok then return end
    local sp = {}
    if Alive then
        for _, e in pairs(Alive:GetChildren()) do
            if e.PrimaryPart then
                local ok2, p = pcall(function() return cam:WorldToScreenPoint(e.PrimaryPart.Position) end)
                if ok2 then sp[e.Name] = p end
            end
        end
    end
    local cf = System.curve.get_cframe()
    local ml = IS_MOBILE and {cam.ViewportSize.X/2, cam.ViewportSize.Y/2} or {mouse.X, mouse.Y}
    task.spawn(function()
        task.wait(_rand_delay())
        _PARRY_PATCH.fire(cf, sp, ml)
    end)
    System.__properties.__parries += 1
    task.delay(0.5, function()
        if System.__properties.__parries > 0 then System.__properties.__parries -= 1 end
    end)
end

function System.parry.keypress()
    if PF then pcall(PF) end
    System.__properties.__parries += 1
    task.delay(0.5, function()
        if System.__properties.__parries > 0 then System.__properties.__parries -= 1 end
    end)
end

function System.parry.execute_action() System.parry.execute() end

local function update_divisor()
    System.__properties.__divisor_multiplier = 0.7 + (System.__properties.__accuracy - 1) * 0.0035353535353535
end

local function update_randomized_accuracy()
    if not System.__properties.__humanizer_enabled then return end
    local p = System.__properties
    local now = os.clock()
    if now < p.__humanizer_last_update + p.__humanizer_next_change then return end
    p.__humanizer_last_update = now
    local ps = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    local ping = tonumber(ps:match("%d+")) or 0
    local mn = math.clamp(p.__humanizer_min_accuracy, 1, 50)
    local mx = math.clamp(p.__humanizer_max_accuracy, 1, 50)
    if mn > mx then mn, mx = mx, mn end
    local cur = math.clamp(p.__accuracy, mn, mx)
    local roll = math.random(1, 100); local nv
    if ping >= 90 then nv = math.clamp(cur + math.random(-1, 1), mn, mx)
    elseif roll <= 45 then nv = math.clamp(cur + math.random(-2, 2), mn, mx)
    elseif roll <= 80 then
        local drift = math.random(2, math.max(3, math.floor((mx - mn) * 0.2)))
        nv = math.clamp(cur + (math.random() < 0.5 and -drift or drift), mn, mx)
    else nv = math.random(mn, mx) end
    p.__accuracy = nv
    p.__humanizer_next_change = math.random(70, 140) / 100 / (ping >= 90 and 0.75 or (ping <= 50 and 1.25 or 1))
    update_divisor()
end

task.spawn(function()
    while task.wait(0.1) do
        if System.__properties.__humanizer_enabled then pcall(update_randomized_accuracy) end
    end
end)

System.detection = { __ball_properties = { __aerodynamic_time=tick(), __last_warping=tick(), __lerp_radians=0, __curving=tick() } }

function System.detection.is_curved()
    local bp = System.detection.__ball_properties
    local ball = System.ball.get(); if not ball then return false end
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local z = ball:FindFirstChild("zoomies"); if not z then return false end
    local v = z.VectorVelocity or Vector3.new(); local sp = v.Magnitude; if sp == 0 then return false end
    local bd = v.Unit
    local dv = LocalPlayer.Character.PrimaryPart.Position - ball.Position
    if dv.Magnitude == 0 then return false end
    local dir = dv.Unit; local dot = dir:Dot(bd)
    local sp_thr = math.min(sp / 100, 40)
    local dd = bd - v; local ds = dd.Magnitude > 0 and dir:Dot(dd.Unit) or 0
    local dot_diff = dot - ds; local dist = dv.Magnitude
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    local dot_thr = 0.5 - (ping / 1000)
    local reach = dist / sp - (ping / 1000)
    local bdt = 15 - math.min(dist / 1000, 15) + sp_thr
    local cr = math.clamp(dot, -1, 1); local rad = math.rad(math.asin(cr))
    bp.__lerp_radians = bp.__lerp_radians + (rad - bp.__lerp_radians) * 0.8
    if sp > 0 and reach > ping / 10 then bdt = math.max(bdt - 15, 15) end
    if dist < bdt then return false end
    if dot_diff < dot_thr then return true end
    if bp.__lerp_radians < 0.018 then bp.__last_warping = tick() end
    if (tick() - bp.__last_warping) < (reach / 1.5) then return true end
    if (tick() - bp.__curving) < (reach / 1.5) then return true end
    return dot < dot_thr
end

pcall(function()
    ReplicatedStorage.Remotes.DeathBall.OnClientEvent:Connect(function(_, d)
        System.__properties.__deathslash_active = d or false
    end)
    ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(_, b)
        System.__properties.__infinity_active = b or false
    end)
end)
pcall(function()
    local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net
    net["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
        local p = ({...})[1]
        if p == LocalPlayer or p == LocalPlayer.Name or (p and p.Name == LocalPlayer.Name) then
            System.__properties.__timehole_active = true
        end
    end)
    net["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function()
        System.__properties.__timehole_active = false
    end)
    net["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
        local p = ({...})[1]
        if p == LocalPlayer or p == LocalPlayer.Name or (p and p.Name == LocalPlayer.Name) then
            System.__properties.__slashesoffury_active = true
            System.__properties.__slashesoffury_count = 0
        end
    end)
    net["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
        System.__properties.__slashesoffury_active = false
        System.__properties.__slashesoffury_count = 0
    end)
    net["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function()
        System.__properties.__slashesoffury_count += 1
    end)
end)

function System.triggerbot.trigger(ball)
    if System.__triggerbot.__is_parrying then return end
    if System.__triggerbot.__parries > System.__triggerbot.__max_parries then return end
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart
        and LocalPlayer.Character.PrimaryPart:FindFirstChild("SingularityCape") then return end
    System.__triggerbot.__is_parrying = true
    System.__triggerbot.__parries += 1
    task.spawn(function()
        task.wait(_rand_delay())
        System.parry.execute()
    end)
    task.delay(System.__triggerbot.__parry_delay, function()
        if System.__triggerbot.__parries > 0 then System.__triggerbot.__parries -= 1 end
    end)
    task.spawn(function()
        local t = tick()
        repeat RunService.Heartbeat:Wait()
        until (tick() - t >= 1 or not System.__triggerbot.__is_parrying)
        System.__triggerbot.__is_parrying = false
    end)
end

function System.triggerbot.loop()
    if not System.__triggerbot.__enabled then return end
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart
        and LocalPlayer.Character.PrimaryPart:FindFirstChild("SingularityCape") then return end
    local balls = Workspace:FindFirstChild("Balls"); if not balls then return end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:IsA("BasePart") and ball:GetAttribute("target") == LocalPlayer.Name then
            System.triggerbot.trigger(ball); break
        end
    end
end

function System.triggerbot.enable(enabled)
    System.__triggerbot.__enabled = enabled
    if enabled then
        if not System.__properties.__connections.__triggerbot then
            System.__properties.__connections.__triggerbot = RunService.Heartbeat:Connect(System.triggerbot.loop)
        end
    else
        if System.__properties.__connections.__triggerbot then
            System.__properties.__connections.__triggerbot:Disconnect()
            System.__properties.__connections.__triggerbot = nil
        end
        System.__triggerbot.__is_parrying = false
        System.__triggerbot.__parries = 0
    end
end

function System.autoparry.start()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
    end
    System.__properties.__connections.__autoparry = RunService.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled then return end
        if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
        local balls = System.ball.get_all()
        local one_ball = System.ball.get()
        for _, ball in pairs(balls) do
            if System.__triggerbot.__enabled then return end
            local z = ball:FindFirstChild("zoomies"); if not z then continue end
            if System.__properties.__parried then continue end
            local bt = ball:GetAttribute("target")
            local v = z.VectorVelocity
            local dist = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude
            local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
            local pt = math.clamp(ping / 10, 5, 17)
            local sp = v.Magnitude
            local cp = math.min(math.max(sp - 9.5, 0), 650)
            local sd = (2.4 + cp * 0.002) * System.__properties.__divisor_multiplier
            local pa = pt + math.max(sp / sd, 9.5)
            local curved = System.detection.is_curved()
            if ball:FindFirstChild("AeroDynamicSlashVFX") then
                ball.AeroDynamicSlashVFX:Destroy()
                System.__properties.__tornado_time = tick()
            end
            if Runtime:FindFirstChild("Tornado") then
                if (tick() - System.__properties.__tornado_time)
                    < (Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159 then continue end
            end
            if one_ball and one_ball:GetAttribute("target") == LocalPlayer.Name and curved then continue end
            if ball:FindFirstChild("ComboCounter") then continue end
            if LocalPlayer.Character.PrimaryPart:FindFirstChild("SingularityCape") then continue end
            if System.__config.__detections.__infinity and System.__properties.__infinity_active then continue end
            if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then continue end
            if System.__config.__detections.__timehole and System.__properties.__timehole_active then continue end
            if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then continue end
            if bt == LocalPlayer.Name and dist <= pa then
                if getgenv().AutoParryMode == "Keypress" then
                    System.parry.keypress()
                else
                    System.parry.execute_action()
                end
                System.__properties.__parried = true
            end
            local t = tick()
            repeat RunService.Stepped:Wait()
            until (tick() - t) >= 1 or not System.__properties.__parried
            System.__properties.__parried = false
        end
    end)
end

function System.autoparry.stop()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
        System.__properties.__connections.__autoparry = nil
    end
end

local function get_manual_spam_interval()
    return 1 / math.clamp(getgenv().ManualSpamCPS or 20, 1, 2000)
end

function System.manual_spam.start()
    if System.__properties.__connections.__manual_spam then
        System.__properties.__connections.__manual_spam:Disconnect()
    end
    System.__properties.__manual_spam_enabled = true
    local acc = 0
    System.__properties.__connections.__manual_spam = RunService.Heartbeat:Connect(function(dt)
        if not System.__properties.__manual_spam_enabled then return end
        if not LocalPlayer.Character or LocalPlayer.Character.Parent ~= Alive then return end
        acc += dt
        local iv = getgenv().ManualSpamCPSEnabled
            and get_manual_spam_interval()
            or (1 / math.max(1, System.__properties.__spam_rate or 100))
        if acc < iv then return end
        acc = 0
        task.spawn(function()
            task.wait(_rand_delay())
            System.parry.execute()
        end)
    end)
end

function System.manual_spam.stop()
    System.__properties.__manual_spam_enabled = false
    if System.__properties.__connections.__manual_spam then
        System.__properties.__connections.__manual_spam:Disconnect()
        System.__properties.__connections.__manual_spam = nil
    end
end

function System.auto_spam.start()
    if System.__properties.__connections.__auto_spam then
        System.__properties.__connections.__auto_spam:Disconnect()
    end
    System.__properties.__auto_spam_enabled = true
    System.__properties.__connections.__auto_spam = RunService.PreSimulation:Connect(function()
        local ball = System.ball.get(); if not ball then return end
        local z = ball:FindFirstChild("zoomies"); if not z then return end
        if z.VectorVelocity.Magnitude == 0 then return end
        local e = System.player.get_closest()
        if not e or not e.PrimaryPart then return end
        if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
        local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
        local pt = math.clamp(ping / 10, 5, 17)
        local sp = z.VectorVelocity.Magnitude
        local cp = math.min(math.max(sp - 9.5, 0), 650)
        local sd = (2.4 + cp * 0.002) * System.__properties.__divisor_multiplier
        local pa = pt + math.max(sp / sd, 9.5)
        local dist = LocalPlayer:DistanceFromCharacter(ball.Position)
        local td = LocalPlayer:DistanceFromCharacter(e.PrimaryPart.Position)
        if td > pa or dist > pa then return end
        if LocalPlayer.Character:GetAttribute("Pulsed") then return end
        if ball:GetAttribute("target") == LocalPlayer.Name and dist <= pa and td <= pa then
            if getgenv().AutoSpamMode == "Keypress" then
                if PF then PF() end
            else
                task.spawn(function()
                    task.wait(_rand_delay())
                    System.parry.execute()
                    if getgenv().AutoSpamAnimationFix and PF then PF() end
                end)
            end
        end
    end)
end

function System.auto_spam.stop()
    System.__properties.__auto_spam_enabled = false
    if System.__properties.__connections.__auto_spam then
        System.__properties.__connections.__auto_spam:Disconnect()
        System.__properties.__connections.__auto_spam = nil
    end
end

local SwordSkin = { enabled=false, module=nil, info=nil, conn_char=nil, conn_loop=nil }
getgenv().swordModel      = getgenv().swordModel      or ""
getgenv().swordAnimations = getgenv().swordAnimations or ""
getgenv().swordFX         = getgenv().swordFX         or ""
getgenv().slashName       = getgenv().slashName       or "SlashEffect"

local function sword_get_module()
    if SwordSkin.module then return SwordSkin.module end
    local ok, mod = pcall(function()
        local sh = ReplicatedStorage:WaitForChild("Shared", 10)
        local ri = sh and sh:WaitForChild("ReplicatedInstances", 10)
        local sw = ri and ri:WaitForChild("Swords", 10)
        return sw and require(sw)
    end)
    if ok and mod then SwordSkin.module = mod end
    return SwordSkin.module
end

local function sword_get_info()
    if SwordSkin.info then return SwordSkin.info end
    pcall(function()
        if not getconnections or not ReplicatedStorage.Remotes.FireSwordInfo then return end
        for _, c in ipairs(getconnections(ReplicatedStorage.Remotes.FireSwordInfo.OnClientEvent)) do
            if c.Function and islclosure and islclosure(c.Function) then
                local ok, ups = pcall(getupvalues, c.Function)
                if ok and ups and #ups == 1 and type(ups[1]) == "table" then
                    SwordSkin.info = ups[1]; break
                end
            end
        end
    end)
    return SwordSkin.info
end

local function sword_set()
    if not SwordSkin.enabled or not LocalPlayer.Character then return end
    local mod = sword_get_module(); if not mod then return end
    pcall(function()
        local f = rawget(mod, "EquipSwordTo")
        if type(f) == "function" and type(getupvalues) == "function" and type(setupvalue) == "function" then
            local ups = getupvalues(f)
            for i = 1, #ups do
                if type(ups[i]) == "boolean" then setupvalue(f, i, false); break end
            end
        end
    end)
    pcall(function() mod:EquipSwordTo(LocalPlayer.Character, getgenv().swordModel) end)
    local info = sword_get_info()
    if info then pcall(function() info:SetSword(getgenv().swordAnimations) end) end
end

local function sword_update()
    if not SwordSkin.enabled then return end
    local mod = sword_get_module()
    if mod then
        local ok, sw = pcall(function() return mod:GetSword(getgenv().swordFX) end)
        getgenv().slashName = ok and sw and sw.SlashName or "SlashEffect"
    end
    sword_set()
end

local function sword_start()
    if SwordSkin.enabled then return end
    SwordSkin.enabled = true
    if not SwordSkin.conn_loop then
        task.spawn(function()
            while SwordSkin.enabled do
                task.wait(1)
                if SwordSkin.enabled and getgenv().swordModel ~= "" then
                    local c = LocalPlayer.Character
                    if c and LocalPlayer:GetAttribute("CurrentlyEquippedSword") ~= getgenv().swordModel then
                        sword_set()
                    end
                end
            end
        end)
    end
    if LocalPlayer.Character then sword_set() end
end

local function sword_stop()
    SwordSkin.enabled = false
end
getgenv().updateSword = sword_update

getgenv().AutoParryMode            = getgenv().AutoParryMode            or "Remote"
getgenv().AutoParryNotify          = getgenv().AutoParryNotify          or false
getgenv().CooldownProtection       = getgenv().CooldownProtection       or false
getgenv().AutoAbility              = getgenv().AutoAbility              or false
getgenv().TriggerbotNotify         = getgenv().TriggerbotNotify         or false
getgenv().HotkeyParryType          = getgenv().HotkeyParryType          or false
getgenv().HotkeyParryTypeNotify    = getgenv().HotkeyParryTypeNotify    or false
getgenv().InfinityNotify           = getgenv().InfinityNotify           or false
getgenv().DribbleNotify            = getgenv().DribbleNotify            or false
getgenv().ManualSpamNotify         = getgenv().ManualSpamNotify         or false
getgenv().ManualSpamCPSEnabled     = getgenv().ManualSpamCPSEnabled     or false
getgenv().ManualSpamCPS            = getgenv().ManualSpamCPS            or 20
getgenv().AutoSpamNotify           = getgenv().AutoSpamNotify           or false
getgenv().AutoSpamMode             = getgenv().AutoSpamMode             or "Remote"
getgenv().AutoSpamAnimationFix     = getgenv().AutoSpamAnimationFix     or false
getgenv().CameraEnabled            = getgenv().CameraEnabled            or false
getgenv().CameraFOV                = getgenv().CameraFOV                or 70
getgenv().FlySpeed                 = getgenv().FlySpeed                 or 50
getgenv().StrafeSpeed              = getgenv().StrafeSpeed              or 36
getgenv().guilibraryVisible        = getgenv().guilibraryVisible        or false
getgenv().BallStats                = getgenv().BallStats                or false
getgenv().Visualiser               = getgenv().Visualiser               or false
getgenv().VisualiserRainbow        = getgenv().VisualiserRainbow        or false
getgenv().VisualiserHue            = getgenv().VisualiserHue            or 0
getgenv().BallTrailEnabled         = getgenv().BallTrailEnabled         or false
getgenv().BallTrailRainbowEnabled  = getgenv().BallTrailRainbowEnabled  or false
getgenv().BallTrailParticleEnabled = getgenv().BallTrailParticleEnabled or false
getgenv().BallTrailGlowEnabled     = getgenv().BallTrailGlowEnabled     or false
getgenv().BallTrailColor           = getgenv().BallTrailColor           or Color3.new(1,1,1)
getgenv().BallTrailHue             = getgenv().BallTrailHue             or 0
getgenv().sound_controller         = getgenv().sound_controller         or false
getgenv().LoopSong                 = getgenv().LoopSong                 or false
getgenv().SoundControllerVolume    = getgenv().SoundControllerVolume    or 3
getgenv().SelectedSound            = getgenv().SelectedSound            or "Eeyuh"
getgenv().AnnouncerText            = getgenv().AnnouncerText            or "discord.gg/HkB97N772p"
getgenv().CustomAnnouncer          = getgenv().CustomAnnouncer          or false
getgenv().No_Render                = getgenv().No_Render                or false
getgenv().HeadlessKorbloxEnabled   = getgenv().HeadlessKorbloxEnabled   or false
getgenv().AbilityESP               = getgenv().AbilityESP               or false
getgenv().AutoPlayDirection            = getgenv().AutoPlayDirection            or 1
getgenv().AutoPlayOffsetFactor         = getgenv().AutoPlayOffsetFactor         or 0.4
getgenv().AutoPlayMovementDuration     = getgenv().AutoPlayMovementDuration     or 0.75
getgenv().AutoPlayGenerationThreshold  = getgenv().AutoPlayGenerationThreshold  or 0.25
getgenv().AutoPlayDoubleJumpPercentage = getgenv().AutoPlayDoubleJumpPercentage or 10
getgenv().AutoPlayDistance             = getgenv().AutoPlayDistance             or 30
getgenv().AutoPlayMultiplierThreshold  = getgenv().AutoPlayMultiplierThreshold  or 70
getgenv().AutoPlayTransversing         = getgenv().AutoPlayTransversing         or 25
getgenv().AutoPlayJumpPercentage       = getgenv().AutoPlayJumpPercentage       or 50

update_divisor()

local IMG = "rbxassetid://111672166073808"
local windows = redzlib:MakeWindow({Title = "Universe Hub", SubTitle = "Blade Ball v2", SaveFolder = "Universe Hub\\" .. LocalPlayer.Name})

local HomeTab = windows:MakeTab({Title = "Home", Icon = "home"})
HomeTab:AddSection("Welcome To Universe Hub | Blade Ball")
HomeTab:AddSection("Discord Server")
HomeTab:AddDiscordInvite({Title = "Universe Hub", Desc = "Join our Discord community!", Logo = IMG, Invite = "https://discord.gg/HkB97N772p"})

local MainTab = windows:MakeTab({Title = "Main", Icon = "sword"})
MainTab:AddSection("Auto Parry")
MainTab:AddToggle({Title = "Auto Parry", Description = "Automatically parry the ball", Default = false, Flag = "AutoParryModule",
    Callback = function(state)
        System.__properties.__autoparry_enabled = state
        if state then
            System.autoparry.start()
            if getgenv().AutoParryNotify then notify("Auto Parry", "Enabled", 2, "Success") end
        else
            System.autoparry.stop()
            if getgenv().AutoParryNotify then notify("Auto Parry", "Disabled", 2, "Error") end
        end
    end})
MainTab:AddDropdown({Title = "Parry Mode", Options = {"Remote", "Keypress"}, Default = "Remote", Flag = "ParryMode",
    Callback = function(v) getgenv().AutoParryMode = (typeof(v) == "table" and v[1]) or v end})
MainTab:AddDropdown({Title = "Mode Curve", Options = System.__config.__curve_names, Default = "Camera", Flag = "ModeCurve",
    Callback = function(v)
        local val = (typeof(v) == "table" and v[1]) or v
        for i, n in ipairs(System.__config.__curve_names) do
            if n == val then System.__properties.__curve_mode = i; break end
        end
    end})
MainTab:AddToggle({Title = "Random Curve", Default = false, Flag = "RandomCurve",
    Callback = function(state)
        if state then
            if System.__properties.__connections.__rc then System.__properties.__connections.__rc:Disconnect() end
            System.__properties.__connections.__rc = RunService.PreSimulation:Connect(function()
                System.__properties.__curve_mode = math.random(1, #System.__config.__curve_names)
            end)
            notify("Random Curve", "ON", 2, "Success")
        else
            if System.__properties.__connections.__rc then
                System.__properties.__connections.__rc:Disconnect()
                System.__properties.__connections.__rc = nil
            end
            notify("Random Curve", "OFF", 2, "Info")
        end
    end})
MainTab:AddSlider({Title = "Parry Accuracy", Min = 1, Max = 50, Default = 50, Flag = "ParryAccuracy",
    Callback = function(v)
        if not System.__properties.__humanizer_enabled then
            System.__properties.__accuracy = v; update_divisor()
        end
    end})
MainTab:AddToggle({Title = "Cooldown Protection", Default = false, Flag = "CooldownProtection",
    Callback = function(s) getgenv().CooldownProtection = s end})
MainTab:AddToggle({Title = "Auto Ability", Default = false, Flag = "AutoAbility",
    Callback = function(s) getgenv().AutoAbility = s end})
MainTab:AddToggle({Title = "Notify", Default = false, Flag = "AutoParryNotify",
    Callback = function(s) getgenv().AutoParryNotify = s end})

MainTab:AddSection("Humanizer")
MainTab:AddToggle({Title = "Enable Humanizer", Default = false, Flag = "HumanizerModule",
    Callback = function(s)
        System.__properties.__humanizer_enabled = s
        if s then pcall(update_randomized_accuracy) end
    end})
MainTab:AddSlider({Title = "Humanizer Min", Min = 1, Max = 50, Default = 1, Flag = "HumanizerMin",
    Callback = function(v) System.__properties.__humanizer_min_accuracy = v end})
MainTab:AddSlider({Title = "Humanizer Max", Min = 1, Max = 50, Default = 50, Flag = "HumanizerMax",
    Callback = function(v) System.__properties.__humanizer_max_accuracy = v end})

MainTab:AddSection("PC Curve Hotkey")
local hotkey_conn
MainTab:AddToggle({Title = "Enable Hotkeys", Description = "Press 1-9 to switch curve mode", Default = false, Flag = "HotkeysModule",
    Callback = function(state)
        getgenv().HotkeyParryType = state
        if state then
            if hotkey_conn then hotkey_conn:Disconnect() end
            hotkey_conn = UIS.InputBegan:Connect(function(input, gpe)
                if gpe or not getgenv().HotkeyParryType then return end
                local map = {
                    [Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,
                    [Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,
                    [Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8,[Enum.KeyCode.Nine]=9,
                }
                local idx = map[input.KeyCode]; if not idx then return end
                if idx <= #System.__config.__curve_names then
                    System.__properties.__curve_mode = idx
                    if getgenv().HotkeyParryTypeNotify then
                        notify("Curve", System.__config.__curve_names[idx], 1.5, "Info")
                    end
                end
            end)
        else
            if hotkey_conn then hotkey_conn:Disconnect(); hotkey_conn = nil end
        end
    end})
MainTab:AddToggle({Title = "Hotkey Notify", Default = false, Flag = "HotkeyParryTypeNotify",
    Callback = function(s) getgenv().HotkeyParryTypeNotify = s end})

MainTab:AddSection("Triggerbot")
MainTab:AddToggle({Title = "Triggerbot", Default = false, Flag = "TriggerbotModule",
    Callback = function(state)
        System.__properties.__triggerbot_enabled = state
        System.triggerbot.enable(state)
        if getgenv().TriggerbotNotify then
            notify("Triggerbot", state and "Enabled" or "Disabled", 2, state and "Success" or "Error")
        end
    end})
MainTab:AddToggle({Title = "Triggerbot Notify", Default = false, Flag = "TriggerbotNotify",
    Callback = function(s) getgenv().TriggerbotNotify = s end})

local BlatantTab = windows:MakeTab({Title = "Blatant", Icon = "zap"})
BlatantTab:AddSection("Fly")
local FlyState = {}
local function stop_fly()
    if FlyState.conn then FlyState.conn:Disconnect(); FlyState.conn = nil end
    if FlyState.ragdoll then FlyState.ragdoll:Disconnect(); FlyState.ragdoll = nil end
    if FlyState.reset then FlyState.reset:Disconnect(); FlyState.reset = nil end
    local c = LocalPlayer.Character
    if c then
        local h = c:FindFirstChild("Humanoid"); local hrp = c:FindFirstChild("HumanoidRootPart")
        if h then h.PlatformStand = false end
        if hrp then
            for _, v in ipairs(hrp:GetChildren()) do
                if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then v:Destroy() end
            end
        end
    end
end
local function start_fly()
    local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = c:WaitForChild("HumanoidRootPart"); local h = c:WaitForChild("Humanoid")
    local gyro = Instance.new("BodyGyro"); gyro.P = 90000; gyro.MaxTorque = Vector3.new(9e9,9e9,9e9); gyro.Parent = hrp
    local vel = Instance.new("BodyVelocity"); vel.Velocity = Vector3.zero; vel.MaxForce = Vector3.new(9e9,9e9,9e9); vel.Parent = hrp
    h.PlatformStand = true
    FlyState.ragdoll = h.StateChanged:Connect(function(_, ns)
        if getgenv().FlyEnabled and (ns == Enum.HumanoidStateType.Physics or ns == Enum.HumanoidStateType.Ragdoll) then
            task.defer(function()
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
                h:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end)
    FlyState.reset = RunService.Heartbeat:Connect(function()
        if not getgenv().FlyEnabled then return end
        if gyro.Parent then gyro.MaxTorque = Vector3.new(9e9,9e9,9e9) end
        if vel.Parent then vel.MaxForce = Vector3.new(9e9,9e9,9e9) end
        h.PlatformStand = true
    end)
    FlyState.conn = RunService.RenderStepped:Connect(function()
        if not getgenv().FlyEnabled then return end
        local cam = workspace.CurrentCamera.CFrame; local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.E) then dir += Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.Q) then dir -= Vector3.yAxis end
        if dir.Magnitude > 0 then dir = dir.Unit end
        vel.Velocity = dir * (getgenv().FlySpeed or 50)
        gyro.CFrame = cam
    end)
end
BlatantTab:AddToggle({Title = "Fly", Default = false, Flag = "Fly",
    Callback = function(s) getgenv().FlyEnabled = s; if s then start_fly() else stop_fly() end end})
BlatantTab:AddSlider({Title = "Fly Speed", Min = 10, Max = 200, Default = 50, Flag = "Fly_Speed",
    Callback = function(v) getgenv().FlySpeed = v end})

BlatantTab:AddSection("Character Speed")
BlatantTab:AddToggle({Title = "Character Speed", Default = false, Flag = "Strafe",
    Callback = function(state)
        if state then
            if getgenv().StrafeConnection then getgenv().StrafeConnection:Disconnect() end
            getgenv().StrafeConnection = RunService.PreSimulation:Connect(function()
                local c = LocalPlayer.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
                if h then h.WalkSpeed = getgenv().StrafeSpeed or 36 end
            end)
        else
            local c = LocalPlayer.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = 36 end
            if getgenv().StrafeConnection then getgenv().StrafeConnection:Disconnect(); getgenv().StrafeConnection = nil end
        end
    end})
BlatantTab:AddSlider({Title = "Speed Value", Min = 36, Max = 200, Default = 36, Flag = "Strafe_Speed",
    Callback = function(v) getgenv().StrafeSpeed = v end})

local SpamTab = windows:MakeTab({Title = "Spam", Icon = "repeat"})
SpamTab:AddSection("Manual Spam")
SpamTab:AddToggle({Title = "Manual Spam", Default = false, Flag = "Manual_Spam_Parry",
    Callback = function(state)
        if getgenv().ManualSpamNotify then
            notify("Manual Spam", state and "Enabled" or "Disabled", 2, state and "Success" or "Error")
        end
        if state then System.manual_spam.start() else System.manual_spam.stop() end
    end})
SpamTab:AddToggle({Title = "Enable CPS", Default = false, Flag = "Manual_Spam_CPS_Enabled",
    Callback = function(s) getgenv().ManualSpamCPSEnabled = s end})
SpamTab:AddSlider({Title = "CPS", Min = 1, Max = 2000, Default = 20, Flag = "Manual_Spam_CPS",
    Callback = function(v) getgenv().ManualSpamCPS = v end})
SpamTab:AddToggle({Title = "Notify", Default = false, Flag = "Manual_Spam_Parry_Notify",
    Callback = function(s) getgenv().ManualSpamNotify = s end})

SpamTab:AddSection("Auto Spam")
SpamTab:AddToggle({Title = "Auto Spam", Default = false, Flag = "AutoSpamModule",
    Callback = function(state)
        if state then
            System.auto_spam.start()
            if getgenv().AutoSpamNotify then notify("Auto Spam", "Enabled", 2, "Success") end
        else
            System.auto_spam.stop()
            if getgenv().AutoSpamNotify then notify("Auto Spam", "Disabled", 2, "Error") end
        end
    end})
SpamTab:AddToggle({Title = "Notify", Default = false, Flag = "AutoSpamNotify",
    Callback = function(s) getgenv().AutoSpamNotify = s end})
SpamTab:AddDropdown({Title = "Mode", Options = {"Remote", "Keypress"}, Default = "Remote", Flag = "AutoSpamMode",
    Callback = function(v) getgenv().AutoSpamMode = (typeof(v) == "table" and v[1]) or v end})
SpamTab:AddToggle({Title = "Animation Fix", Default = false, Flag = "AutoSpamAnimationFix",
    Callback = function(s) getgenv().AutoSpamAnimationFix = s end})
SpamTab:AddSlider({Title = "Parry Threshold", Min = 1, Max = 3, Default = 1, Flag = "ParryThreshold",
    Callback = function(v) System.__properties.__spam_threshold = v end})

local DetectionTab = windows:MakeTab({Title = "Detection", Icon = "shield"})
DetectionTab:AddSection("Ball Detections")
DetectionTab:AddToggle({Title = "Infinity Detection", Default = false, Flag = "InfinityModule",
    Callback = function(s)
        System.__config.__detections.__infinity = s
        if getgenv().InfinityNotify then notify("Infinity", s and "ON" or "OFF", 2, s and "Success" or "Error") end
    end})
DetectionTab:AddToggle({Title = "Infinity Notify", Default = false, Flag = "InfinityNotify",
    Callback = function(s) getgenv().InfinityNotify = s end})
DetectionTab:AddToggle({Title = "Death Slash Detection", Default = false, Flag = "DeathSlashModule",
    Callback = function(s) System.__config.__detections.__deathslash = s end})
DetectionTab:AddToggle({Title = "Time Hole Detection", Default = false, Flag = "TimeHoleModule",
    Callback = function(s) System.__config.__detections.__timehole = s end})
DetectionTab:AddToggle({Title = "Slashes Of Fury Detection", Default = false, Flag = "SlashesModule",
    Callback = function(s) System.__config.__detections.__slashesoffury = s end})
DetectionTab:AddSlider({Title = "Parry Delay (Fury)", Min = 0.05, Max = 0.25, Default = 0.05, Flag = "ParryDelay",
    Callback = function(v) parryDelay = v end})
DetectionTab:AddSlider({Title = "Max Parry (Fury)", Min = 1, Max = 36, Default = 36, Flag = "MaxParryCount",
    Callback = function(v) maxParryCount = v end})
DetectionTab:AddToggle({Title = "Dribble Detection", Default = false, Flag = "DribbleDetectionModule",
    Callback = function(s)
        getgenv().DribbleDetection = s; System.__config.__detections.__dribble = s
        if getgenv().DribbleNotify then notify("Dribble", s and "ON" or "OFF", 2, s and "Success" or "Error") end
    end})
DetectionTab:AddToggle({Title = "Dribble Notify", Default = false, Flag = "DribbleNotify",
    Callback = function(s) getgenv().DribbleNotify = s end})
DetectionTab:AddToggle({Title = "Anti-Phantom", Default = false, Flag = "PhantomModule",
    Callback = function(s) System.__config.__detections.__phantom = s end})

DetectionTab:AddSection("Staff Detection")
local GROUP_ID = 12836673; local MIN_RANK = 10
local modActionMode = "Notification"; local modMonitorConnection = nil; local detectedMods = {}
local function getPlayerRank(p)
    local ok, r = pcall(function() return p:GetRankInGroup(GROUP_ID) end); return ok and r or 0
end
local function showModNotification(player)
    local n = Instance.new("ScreenGui"); n.Name = "UniverseModNotif"; n.ResetOnSpawn = false; n.Parent = CoreGui
    local f = Instance.new("Frame"); f.Size = UDim2.new(0,350,0,60); f.Position = UDim2.new(0.5,-175,0.2,0)
    f.BackgroundColor3 = Color3.fromRGB(200,50,50); f.BackgroundTransparency = 0.15; f.BorderSizePixel = 0; f.Parent = n
    local t = Instance.new("TextLabel"); t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1
    t.Text = "! Staff Joined: " .. player.Name; t.TextColor3 = Color3.new(1,1,1)
    t.TextSize = 18; t.Font = Enum.Font.GothamBold; t.Parent = f
    task.delay(5, function() if n.Parent then n:Destroy() end end)
end
local function checkModPlayers()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not detectedMods[p.UserId] then
            if getPlayerRank(p) >= MIN_RANK then
                detectedMods[p.UserId] = true
                if modActionMode == "Notification" then showModNotification(p) end
            end
        end
    end
end
DetectionTab:AddToggle({Title = "Staff Detection", Default = false, Flag = "ModDetectionModule",
    Callback = function(state)
        if state then
            if modMonitorConnection then modMonitorConnection:Disconnect() end
            checkModPlayers()
            modMonitorConnection = RunService.Heartbeat:Connect(checkModPlayers)
        else
            if modMonitorConnection then modMonitorConnection:Disconnect(); modMonitorConnection = nil end
            detectedMods = {}
        end
    end})
DetectionTab:AddDropdown({Title = "Staff Action", Options = {"Notification"}, Default = "Notification", Flag = "ModActionMode",
    Callback = function(v) modActionMode = (typeof(v) == "table" and v[1]) or v end})

local PlayerTab = windows:MakeTab({Title = "Player", Icon = "user"})
PlayerTab:AddSection("Camera")
PlayerTab:AddToggle({Title = "FOV", Default = false, Flag = "FOVModule",
    Callback = function(state)
        getgenv().CameraEnabled = state
        local Cam = workspace.CurrentCamera
        if state then
            getgenv().CameraFOV = getgenv().CameraFOV or 70; Cam.FieldOfView = getgenv().CameraFOV
            if not getgenv().FOVLoop then
                getgenv().FOVLoop = RunService.RenderStepped:Connect(function()
                    if getgenv().CameraEnabled then Cam.FieldOfView = getgenv().CameraFOV end
                end)
            end
        else
            Cam.FieldOfView = 70
            if getgenv().FOVLoop then getgenv().FOVLoop:Disconnect(); getgenv().FOVLoop = nil end
        end
    end})
PlayerTab:AddSlider({Title = "Camera FOV", Min = 50, Max = 120, Default = 70, Flag = "CameraFOV",
    Callback = function(v)
        getgenv().CameraFOV = v
        if getgenv().CameraEnabled then workspace.CurrentCamera.FieldOfView = v end
    end})

PlayerTab:AddSection("Headless + Korblox")
PlayerTab:AddToggle({Title = "Headless + Korblox", Default = false, Flag = "Player_Cosmetics",
    Callback = function(state)
        getgenv().HeadlessKorbloxEnabled = state
        local cleanup = {}
        local function applyKorblox(ch)
            if not ch then return end
            local leg = ch:FindFirstChild("Right Leg") or ch:FindFirstChild("RightLeg")
            if not leg or leg:FindFirstChild("KorbloxMesh") then return end
            for _, c in ipairs(leg:GetChildren()) do if c:IsA("SpecialMesh") then c:Destroy() end end
            local m = Instance.new("SpecialMesh"); m.Name = "KorbloxMesh"
            m.MeshId = "rbxassetid://902942096"; m.TextureId = "rbxassetid://902843398"
            m.Offset = Vector3.new(0, 0.7, 0); m.Parent = leg
        end
        local function restoreKorblox(ch)
            local leg = ch and (ch:FindFirstChild("Right Leg") or ch:FindFirstChild("RightLeg"))
            if leg then for _, c in ipairs(leg:GetChildren()) do if c:IsA("SpecialMesh") then c:Destroy() end end end
        end
        local function applyHeadless(ch)
            if not ch then return end
            local head = ch:FindFirstChild("Head"); if not head then return end
            if cleanup.headTransparency == nil then cleanup.headTransparency = head.Transparency end
            local face = head:FindFirstChildOfClass("Decal"); if face then cleanup.faceDecalId = face.Texture end
            head.Transparency = 1
            for _, c in ipairs(head:GetChildren()) do
                if c:IsA("Decal") then c.Transparency = 1
                elseif c:IsA("SpecialMesh") and not c:GetAttribute("OrigScale") then
                    c:SetAttribute("OrigScale", c.Scale); c.Scale = Vector3.zero
                end
            end
        end
        local function restoreHeadless(ch)
            local head = ch and ch:FindFirstChild("Head"); if not head then return end
            if cleanup.headTransparency ~= nil then head.Transparency = cleanup.headTransparency end
            if cleanup.faceDecalId then
                local d = head:FindFirstChildOfClass("Decal") or Instance.new("Decal", head)
                d.Texture = cleanup.faceDecalId; d.Face = Enum.NormalId.Front
            end
            for _, c in ipairs(head:GetChildren()) do
                if c:IsA("Decal") then c.Transparency = 0
                elseif c:IsA("SpecialMesh") then
                    local o = c:GetAttribute("OrigScale")
                    if o then c.Scale = o; c:SetAttribute("OrigScale", nil) end
                end
            end
        end
        if state then
            if LocalPlayer.Character then applyKorblox(LocalPlayer.Character); applyHeadless(LocalPlayer.Character) end
            cleanup.conn = LocalPlayer.CharacterAdded:Connect(function(c)
                task.wait(0.5); applyKorblox(c); applyHeadless(c)
            end)
            getgenv()._UniverseCosmeticsCleanup = cleanup
        else
            if cleanup.conn then cleanup.conn:Disconnect() end
            if LocalPlayer.Character then restoreKorblox(LocalPlayer.Character); restoreHeadless(LocalPlayer.Character) end
            getgenv()._UniverseCosmeticsCleanup = nil
        end
    end})

PlayerTab:AddSection("Auto Play")
local AutoPlayState = { enabled=false, connection=nil, charConn=nil, elapsed=0, control=nil, dj=false, ball=nil }
local function ap_get_ball()
    local b = Workspace:FindFirstChild("Balls"); if not b then return nil end
    for _, ball in pairs(b:GetChildren()) do
        if ball:GetAttribute("realBall") then ball.CanCollide = false; return ball end
    end
end
local function ap_get_floor()
    local f = Workspace:FindFirstChild("FLOOR"); if f then return f end
    for _, p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("BasePart") and p.Size.X > 50 and p.Size.Z > 50 and p.Position.Y < 5 then return p end
    end
end
local function ap_curve(a, b, dt)
    AutoPlayState.elapsed += dt
    local t = math.clamp(AutoPlayState.elapsed / (getgenv().AutoPlayMovementDuration or 0.8), 0, 1)
    if t >= 1 then AutoPlayState.elapsed = 0; AutoPlayState.control = nil; return b end
    if not AutoPlayState.control then
        local mid = (a + b) * 0.5; local diff = a - b
        if diff.Magnitude < 5 then return b end
        local th = math.atan2(diff.Z, diff.X)
        local ol = diff.Magnitude * (getgenv().AutoPlayOffsetFactor or 0.7)
        local c1 = mid + Vector3.new(math.cos(th + math.pi/2), 0, math.sin(th + math.pi/2)) * ol
        local c2 = mid + Vector3.new(math.cos(th - math.pi/2), 0, math.sin(th - math.pi/2)) * ol
        AutoPlayState.control = ((c1 - mid):Dot(a - mid) < 0 and c1) or c2
    end
    local l1 = a + (AutoPlayState.control - a) * t
    local l2 = AutoPlayState.control + (b - AutoPlayState.control) * t
    return l1 + (l2 - l1) * t
end
local function ap_target()
    local floor = ap_get_floor(); local ball = ap_get_ball() or AutoPlayState.ball
    local c = LocalPlayer.Character; local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not floor or not ball or not hrp then return nil end
    AutoPlayState.ball = ball
    local dir = (hrp.Position - ball.Position).Unit; local sp = 0
    pcall(function()
        if ball.zoomies and ball.zoomies.VectorVelocity then sp = ball.zoomies.VectorVelocity.Magnitude end
    end)
    local st = math.min(sp / 10, getgenv().AutoPlayMultiplierThreshold or 70)
    local d = (getgenv().AutoPlayDistance or 30) + st
    local off = dir * d * (getgenv().AutoPlayDirection or 1)
    local now = os.time() / 1.2
    local s = math.sin(now) * (getgenv().AutoPlayTransversing or 25)
    local co = math.cos(now) * (getgenv().AutoPlayTransversing or 25)
    return floor.Position + off + Vector3.new(s, 0, co)
end
local function ap_step()
    if not AutoPlayState.enabled then return end
    local c = LocalPlayer.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not h or not hrp or h.Health <= 0 then return end
    if h.FloorMaterial ~= Enum.Material.Air then AutoPlayState.dj = false end
    local tp = ap_target(); if tp then h:MoveTo(ap_curve(hrp.Position, tp, 0.016)) end
    if getgenv().AutoPlayJumpingEnabled and math.random(100) <= (getgenv().AutoPlayJumpPercentage or 50) then
        if h.FloorMaterial ~= Enum.Material.Air then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        elseif not AutoPlayState.dj and math.random(100) <= (getgenv().AutoPlayDoubleJumpPercentage or 50) then
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.Velocity = Vector3.new(0, 80, 0); bv.Parent = hrp
            Debris:AddItem(bv, 0.1); AutoPlayState.dj = true
        end
    end
end
PlayerTab:AddToggle({Title = "Auto Play", Default = false, Flag = "AutoPlay",
    Callback = function(state)
        AutoPlayState.enabled = state
        if AutoPlayState.connection then AutoPlayState.connection:Disconnect(); AutoPlayState.connection = nil end
        if AutoPlayState.charConn then AutoPlayState.charConn:Disconnect(); AutoPlayState.charConn = nil end
        if state then
            AutoPlayState.connection = RunService.RenderStepped:Connect(ap_step)
            AutoPlayState.charConn = LocalPlayer.CharacterAdded:Connect(function()
                AutoPlayState.dj = false; AutoPlayState.ball = nil
                AutoPlayState.control = nil; AutoPlayState.elapsed = 0
            end)
        end
    end})
PlayerTab:AddToggle({Title = "Anti AFK", Default = false, Flag = "AutoPlayAntiAFK",
    Callback = function(state)
        if state then
            if not Connections["AntiAFK"] then
                Connections["AntiAFK"] = LocalPlayer.Idled:Connect(function()
                    VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        else
            if Connections["AntiAFK"] then Connections["AntiAFK"]:Disconnect(); Connections["AntiAFK"] = nil end
        end
    end})
PlayerTab:AddToggle({Title = "Enable Jumping", Default = false, Flag = "AutoPlayJumpingEnabled",
    Callback = function(s) getgenv().AutoPlayJumpingEnabled = s end})
PlayerTab:AddToggle({Title = "Auto Vote", Default = false, Flag = "AutoVote",
    Callback = function(s) getgenv().AutoVote = s end})
PlayerTab:AddSlider({Title = "Distance From Ball", Min = 5, Max = 100, Default = 18, Flag = "default_distance",
    Callback = function(v) getgenv().AutoPlayDistance = v end})
PlayerTab:AddSlider({Title = "Speed Multiplier", Min = 10, Max = 200, Default = 45, Flag = "multiplier_threshold",
    Callback = function(v) getgenv().AutoPlayMultiplierThreshold = v end})
PlayerTab:AddSlider({Title = "Transversing", Min = 0, Max = 100, Default = 8, Flag = "traversing",
    Callback = function(v) getgenv().AutoPlayTransversing = v end})
PlayerTab:AddSlider({Title = "Jump Chance", Min = 0, Max = 100, Default = 20, Flag = "jump_percentage",
    Callback = function(v) getgenv().AutoPlayJumpPercentage = v end})
PlayerTab:AddSlider({Title = "Direction", Min = -1, Max = 1, Default = 1, Flag = "Direction",
    Callback = function(v) getgenv().AutoPlayDirection = v end})
PlayerTab:AddSlider({Title = "Offset Factor", Min = 0.1, Max = 1, Default = 0.4, Flag = "OffsetFactor",
    Callback = function(v) getgenv().AutoPlayOffsetFactor = v end})
PlayerTab:AddSlider({Title = "Movement Duration", Min = 0.1, Max = 1, Default = 0.75, Flag = "MovementDuration",
    Callback = function(v) getgenv().AutoPlayMovementDuration = v end})
PlayerTab:AddSlider({Title = "Generation Threshold", Min = 0.1, Max = 0.5, Default = 0.25, Flag = "GenerationThreshold",
    Callback = function(v) getgenv().AutoPlayGenerationThreshold = v end})
PlayerTab:AddSlider({Title = "Double Jump Chance", Min = 0, Max = 100, Default = 10, Flag = "double_jump_percentage",
    Callback = function(v) getgenv().AutoPlayDoubleJumpPercentage = v end})

local VisualTab = windows:MakeTab({Title = "Visual", Icon = "eye"})
VisualTab:AddSection("Ball Trail")
local ballTrailState = {}
local rainbowHue = 0
local function clear_ball_trail(ball)
    if not ball then return end
    for _, n in ipairs({"Trail","ParticleEmitter","BallGlow","Attachment0","Attachment1"}) do
        local e = ball:FindFirstChild(n); if e then e:Destroy() end
    end
    ballTrailState[ball] = nil
end
local function apply_ball_trail(ball)
    if not ball then return end
    if not getgenv().BallTrailEnabled then clear_ball_trail(ball); return end
    if ballTrailState[ball] then
        local t = ball:FindFirstChild("Trail")
        if t then
            if getgenv().BallTrailRainbowEnabled then
                local c = Color3.fromHSV(rainbowHue/360, 1, 1)
                t.Color = ColorSequence.new(c); getgenv().BallTrailColor = c
            else t.Color = ColorSequence.new(getgenv().BallTrailColor or Color3.new(1,1,1)) end
        end
        return
    end
    ballTrailState[ball] = true
    local tr = Instance.new("Trail"); tr.Name = "Trail"
    local a0 = Instance.new("Attachment"); a0.Name = "Attachment0"; a0.Position = Vector3.new(0, ball.Size.Y/2, 0); a0.Parent = ball
    local a1 = Instance.new("Attachment"); a1.Name = "Attachment1"; a1.Position = Vector3.new(0, -ball.Size.Y/2, 0); a1.Parent = ball
    tr.Attachment0 = a0; tr.Attachment1 = a1; tr.Lifetime = 0.4; tr.WidthScale = NumberSequence.new(0.5)
    tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
    tr.Color = ColorSequence.new(getgenv().BallTrailColor or Color3.new(1,1,1))
    tr.Parent = ball
    if getgenv().BallTrailParticleEnabled then
        local pe = Instance.new("ParticleEmitter"); pe.Name = "ParticleEmitter"; pe.Rate = 100
        pe.Lifetime = NumberRange.new(0.5, 1); pe.Speed = NumberRange.new(0, 1)
        pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.5), NumberSequenceKeypoint.new(1,0)})
        pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
        pe.Parent = ball
    end
    if getgenv().BallTrailGlowEnabled then
        local gl = Instance.new("PointLight"); gl.Name = "BallGlow"; gl.Range = 15; gl.Brightness = 2; gl.Parent = ball
    end
end
RunService.Heartbeat:Connect(function()
    if not getgenv().BallTrailEnabled then return end
    rainbowHue = (rainbowHue + 1) % 360
    local b = ap_get_ball()
    if b then apply_ball_trail(b) end
    local bf = Workspace:FindFirstChild("Balls")
    if bf then for _, eb in ipairs(bf:GetChildren()) do apply_ball_trail(eb) end end
end)
VisualTab:AddToggle({Title = "Ball Trail", Default = false, Flag = "Ball_Trail",
    Callback = function(s) getgenv().BallTrailEnabled = s end})
VisualTab:AddSlider({Title = "Ball Trail Hue", Min = 0, Max = 360, Default = 0, Flag = "Ball_Trail_Hue",
    Callback = function(v)
        if not getgenv().BallTrailRainbowEnabled then getgenv().BallTrailColor = Color3.fromHSV(v/360, 1, 1) end
        getgenv().BallTrailHue = v
    end})
VisualTab:AddToggle({Title = "Rainbow Trail", Default = false, Flag = "Ball_Trail_Rainbow",
    Callback = function(s) getgenv().BallTrailRainbowEnabled = s end})
VisualTab:AddToggle({Title = "Particle Emitter", Default = false, Flag = "Ball_Trail_Particle",
    Callback = function(s) getgenv().BallTrailParticleEnabled = s end})
VisualTab:AddToggle({Title = "Glow Effect", Default = false, Flag = "Ball_Trail_Glow",
    Callback = function(s) getgenv().BallTrailGlowEnabled = s end})

VisualTab:AddSection("Ball Stats")
local BallStatsState = { gui=nil, vlog=nil, plog=nil, conn=nil, peak=0 }
local function destroy_ball_stats()
    if BallStatsState.conn then BallStatsState.conn:Disconnect() end
    if BallStatsState.gui then BallStatsState.gui:Destroy() end
    BallStatsState = { gui=nil, vlog=nil, plog=nil, conn=nil, peak=0 }
end
local function create_ball_stats()
    if BallStatsState.gui then return end
    local g = Instance.new("ScreenGui"); g.Name = "UniverseBallStats"; g.ResetOnSpawn = false
    g.IgnoreGuiInset = true; g.DisplayOrder = 99; g.Parent = CoreGui
    local p = Instance.new("Frame"); p.Size = UDim2.new(0, 190, 0, 94); p.Position = UDim2.new(0, 20, 0.5, -47)
    p.BackgroundColor3 = Color3.fromRGB(12,12,12); p.BorderSizePixel = 0; p.Active = true; p.Parent = g
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, 12)
    local ps = Instance.new("UIStroke", p); ps.Color = Color3.fromRGB(38,38,38); ps.Thickness = 1
    local tl = Instance.new("TextLabel", p); tl.Size = UDim2.new(1,0,0,20); tl.Position = UDim2.new(0,0,0,6)
    tl.BackgroundTransparency = 1; tl.Text = "BALL STATS"; tl.TextColor3 = Color3.new(1,1,1)
    tl.TextSize = 12; tl.Font = Enum.Font.GothamBold
    local ch = Instance.new("Frame", p); ch.BackgroundTransparency = 1
    ch.Position = UDim2.new(0,10,0,32); ch.Size = UDim2.new(1,-20,0,56)
    local cl = Instance.new("UIListLayout", ch); cl.FillDirection = Enum.FillDirection.Horizontal
    cl.HorizontalAlignment = Enum.HorizontalAlignment.Center; cl.VerticalAlignment = Enum.VerticalAlignment.Center
    cl.Padding = UDim.new(0,8)
    local function mk(tag)
        local c = Instance.new("Frame", ch); c.Size = UDim2.new(0, 82, 0, 44)
        c.BackgroundColor3 = Color3.fromRGB(20,20,20); c.BorderSizePixel = 0
        Instance.new("UICorner", c).CornerRadius = UDim.new(0, 10)
        local cs = Instance.new("UIStroke", c); cs.Color = Color3.fromRGB(35,35,35); cs.Thickness = 1
        local t = Instance.new("TextLabel", c); t.Size = UDim2.new(1,-6,0,11); t.Position = UDim2.new(0,4,0,5)
        t.BackgroundTransparency = 1; t.Text = tag; t.TextColor3 = Color3.new(1,1,1)
        t.TextSize = 9; t.Font = Enum.Font.GothamBold
        local v = Instance.new("TextLabel", c); v.Size = UDim2.new(1,0,0,20); v.Position = UDim2.new(0,0,0,20)
        v.BackgroundTransparency = 1; v.Text = "--"; v.TextColor3 = Color3.new(1,1,1)
        v.TextSize = 16; v.Font = Enum.Font.GothamBold
        return v
    end
    BallStatsState.vlog = mk("SPEED")
    BallStatsState.plog = mk("PEAK"); BallStatsState.plog.TextColor3 = Color3.fromRGB(100,220,130)
    BallStatsState.gui = g
end
VisualTab:AddToggle({Title = "Ball Stats", Default = false, Flag = "Ball_Stats",
    Callback = function(state)
        getgenv().BallStats = state
        if state then
            create_ball_stats()
            if BallStatsState.conn then BallStatsState.conn:Disconnect() end
            BallStatsState.conn = RunService.RenderStepped:Connect(function()
                if not BallStatsState.vlog then return end
                local b = ap_get_ball(); local sp = 0
                if b then local v = b.AssemblyLinearVelocity; if typeof(v) == "Vector3" then sp = v.Magnitude end end
                BallStatsState.vlog.Text = string.format("%.1f", sp)
                if sp > BallStatsState.peak then
                    BallStatsState.peak = sp
                    BallStatsState.plog.Text = string.format("%.1f", BallStatsState.peak)
                end
            end)
        else destroy_ball_stats() end
    end})

VisualTab:AddSection("Parry Range Visualiser")
local vis_model, vis_edges = nil, {}
local function destroy_visualiser()
    if Connections["Visualiser"] then Connections["Visualiser"]:Disconnect(); Connections["Visualiser"] = nil end
    if vis_model then vis_model:Destroy(); vis_model = nil end
    vis_edges = {}
end
VisualTab:AddToggle({Title = "Visualiser", Default = false, Flag = "Visualiser",
    Callback = function(state)
        getgenv().Visualiser = state
        if state then
            if not vis_model then
                vis_model = Instance.new("Model"); vis_model.Name = "UniverseVisualiser"; vis_model.Parent = Workspace
                for i = 1, 128 do
                    local e = Instance.new("Part")
                    e.Name = "Edge"..i; e.Anchored = true; e.CanCollide = false; e.CastShadow = false
                    e.Material = Enum.Material.Neon; e.Color = Color3.new(1,1,1); e.Transparency = 0.25
                    e.Size = Vector3.new(0.08, 0.08, 0.18); e.Parent = vis_model
                    vis_edges[i] = e
                end
            end
            Connections["Visualiser"] = RunService.RenderStepped:Connect(function()
                local c = LocalPlayer.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if getgenv().VisualiserRainbow then
                    local hue = (tick() % 5) / 5
                    for _, e in pairs(vis_edges) do e.Color = Color3.fromHSV(hue, 1, 1) end
                else
                    local hue = (getgenv().VisualiserHue or 0) / 360
                    for _, e in pairs(vis_edges) do e.Color = Color3.fromHSV(hue, 1, 1) end
                end
                local sp = 0
                local bf = Workspace:FindFirstChild("Balls")
                if bf then
                    for _, b in pairs(bf:GetChildren()) do
                        if b and b:FindFirstChild("zoomies") then
                            sp = math.min(b.AssemblyLinearVelocity.Magnitude, 350) / 6.5; break
                        end
                    end
                end
                local size = math.max(sp, 6.5); local r = size * 0.5
                local seg = #vis_edges; local sl = math.max(0.25, (2 * math.pi * r) / seg)
                for i, e in ipairs(vis_edges) do
                    if e and hrp then
                        local a = (i - 1) * (2 * math.pi / seg)
                        e.Size = Vector3.new(0.05, 0.05, sl)
                        e.CFrame = hrp.CFrame * CFrame.new(math.cos(a)*r, -3.0, math.sin(a)*r) * CFrame.Angles(0, a + math.pi/2, 0)
                    end
                end
            end)
        else destroy_visualiser() end
    end})
VisualTab:AddToggle({Title = "Visualiser Rainbow", Default = false, Flag = "VisualiserRainbow",
    Callback = function(s) getgenv().VisualiserRainbow = s end})
VisualTab:AddSlider({Title = "Visualiser Hue", Min = 0, Max = 360, Default = 0, Flag = "VisualiserHue",
    Callback = function(v) getgenv().VisualiserHue = v end})

VisualTab:AddSection("Ability ESP")
local abilityEspBillboards = {}
local abilityEspConnections = {}
local abilityEspPlayerAddedConn = nil
local function create_ability_esp_for_player(player)
    task.spawn(function()
        local character = player.Character
        while not character or not character.Parent do task.wait(); character = player.Character end
        local head = character:WaitForChild("Head", 10)
        if not head or not getgenv().AbilityESP then return end
        local existing = head:FindFirstChild("AbilityESPGui"); if existing then existing:Destroy() end
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "AbilityESPGui"; billboard.Adornee = head
        billboard.Size = UDim2.new(0, 220, 0, 60); billboard.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop = true; billboard.Parent = head
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0); label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255,255,255); label.TextSize = 14
        label.TextStrokeTransparency = 0; label.Font = Enum.Font.Roboto; label.RichText = true
        label.TextXAlignment = Enum.TextXAlignment.Center; label.TextYAlignment = Enum.TextYAlignment.Center
        label.Parent = billboard; label.Visible = false
        abilityEspBillboards[player] = label
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
        local heartbeatConn
        heartbeatConn = RunService.Heartbeat:Connect(function()
            if not (character and character.Parent) then
                if heartbeatConn then heartbeatConn:Disconnect() end
                pcall(function() billboard:Destroy() end)
                abilityEspBillboards[player] = nil
                abilityEspConnections[player] = nil
                return
            end
            if getgenv().AbilityESP then
                label.Visible = true
                local ab = player:GetAttribute("EquippedAbility")
                label.Text = ab and ("<b>"..player.DisplayName.." ["..ab.."]</b>") or ("<b>"..player.DisplayName.."</b>")
            else label.Visible = false end
        end)
        abilityEspConnections[player] = heartbeatConn
    end)
end
local function add_ability_esp_player(player)
    if player == LocalPlayer then return end
    if abilityEspConnections[player] then
        pcall(function() abilityEspConnections[player]:Disconnect() end)
        abilityEspConnections[player] = nil
    end
    player.CharacterAdded:Connect(function() create_ability_esp_for_player(player) end)
    if player.Character then task.spawn(function() create_ability_esp_for_player(player) end) end
end
local function start_ability_esp()
    if abilityEspPlayerAddedConn and next(abilityEspConnections) then return end
    getgenv().AbilityESP = true
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then add_ability_esp_player(p) end
    end
    if not abilityEspPlayerAddedConn then
        abilityEspPlayerAddedConn = Players.PlayerAdded:Connect(function(p)
            if getgenv().AbilityESP then add_ability_esp_player(p) end
        end)
    end
end
local function stop_ability_esp()
    if not getgenv().AbilityESP then return end
    getgenv().AbilityESP = false
    if abilityEspPlayerAddedConn then abilityEspPlayerAddedConn:Disconnect(); abilityEspPlayerAddedConn = nil end
    for _, c in pairs(abilityEspConnections) do pcall(function() c:Disconnect() end) end
    abilityEspConnections = {}
    for _, l in pairs(abilityEspBillboards) do
        pcall(function() if l and l.Parent then l.Parent:Destroy() end end)
    end
    abilityEspBillboards = {}
end
VisualTab:AddToggle({Title = "Ability ESP", Default = false, Flag = "AbilityESPModule",
    Callback = function(state) if state then start_ability_esp() else stop_ability_esp() end end})

VisualTab:AddSection("Custom Announcer")
local announcerConn, announcerWinnerConn
local function apply_announcer(gui)
    if not gui then return end
    local w = gui:FindFirstChild("Winner")
    if w and w:IsA("TextLabel") then w.Text = getgenv().AnnouncerText or "discord.gg/HkB97N772p" end
end
local function start_custom_announcer()
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
    local announcerGui = pg:FindFirstChild("announcer")
    apply_announcer(announcerGui)
    if announcerGui and not announcerWinnerConn then
        announcerWinnerConn = announcerGui.ChildAdded:Connect(function(child)
            if child.Name == "Winner" then
                child.Changed:Connect(function(prop)
                    if prop == "Text" and getgenv().CustomAnnouncer then
                        child.Text = getgenv().AnnouncerText or "discord.gg/HkB97N772p"
                    end
                end)
                if getgenv().CustomAnnouncer then
                    child.Text = getgenv().AnnouncerText or "discord.gg/HkB97N772p"
                end
            end
        end)
    end
    if not announcerConn then
        announcerConn = pg.ChildAdded:Connect(function(child)
            if child.Name == "announcer" then task.wait(0.2); apply_announcer(child) end
        end)
    end
end
local function stop_custom_announcer()
    if announcerConn then announcerConn:Disconnect(); announcerConn = nil end
    if announcerWinnerConn then announcerWinnerConn:Disconnect(); announcerWinnerConn = nil end
end
VisualTab:AddToggle({Title = "Custom Announcer", Default = false, Flag = "Custom_Announcer",
    Callback = function(state)
        getgenv().CustomAnnouncer = state
        if state then start_custom_announcer() else stop_custom_announcer() end
    end})
VisualTab:AddTextBox({Title = "Announcement Text", PlaceholderText = "Enter custom announcement...",
    Default = getgenv().AnnouncerText or "", Flag = "announcer_text",
    Callback = function(text)
        getgenv().AnnouncerText = text
        if getgenv().CustomAnnouncer then
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            apply_announcer(pg and pg:FindFirstChild("announcer"))
        end
    end})

VisualTab:AddSection("Stats Overlay")
local StatsOverlay = { gui=nil, fpsVal=nil, pingVal=nil, conn=nil, fpsConn=nil }
VisualTab:AddToggle({Title = "FPS & Ping", Default = false, Flag = "StatsOverlayModule",
    Callback = function(state)
        if state then
            if not StatsOverlay.gui then
                local g = Instance.new("ScreenGui"); g.Name = "UniverseStats"; g.ResetOnSpawn = false
                g.IgnoreGuiInset = true; g.DisplayOrder = 99; g.Parent = CoreGui
                local p = Instance.new("Frame"); p.Size = UDim2.new(0, 178, 0, 86); p.Position = UDim2.new(0, 20, 0.5, -43)
                p.BackgroundColor3 = Color3.fromRGB(12,12,12); p.BorderSizePixel = 0; p.Active = true; p.Parent = g
                Instance.new("UICorner", p).CornerRadius = UDim.new(0, 12)
                local ps2 = Instance.new("UIStroke", p); ps2.Color = Color3.fromRGB(70,70,70); ps2.Thickness = 1
                local tl = Instance.new("TextLabel", p); tl.Size = UDim2.new(1,0,0,18); tl.Position = UDim2.new(0,0,0,6)
                tl.BackgroundTransparency = 1; tl.Text = "FPS & PING"; tl.TextColor3 = Color3.fromRGB(220,220,220)
                tl.TextSize = 10; tl.Font = Enum.Font.GothamBold
                local ch = Instance.new("Frame", p); ch.BackgroundTransparency = 1
                ch.Position = UDim2.new(0,10,0,26); ch.Size = UDim2.new(1,-20,0,44)
                local cl = Instance.new("UIListLayout", ch); cl.FillDirection = Enum.FillDirection.Horizontal
                cl.HorizontalAlignment = Enum.HorizontalAlignment.Center; cl.VerticalAlignment = Enum.VerticalAlignment.Center
                cl.Padding = UDim.new(0,6)
                local function mk(tag)
                    local c = Instance.new("Frame", ch); c.Size = UDim2.new(0,70,0,36)
                    c.BackgroundColor3 = Color3.fromRGB(24,24,24); c.BorderSizePixel = 0
                    Instance.new("UICorner", c).CornerRadius = UDim.new(0,10)
                    local cs = Instance.new("UIStroke", c); cs.Color = Color3.fromRGB(60,60,60); cs.Thickness = 1
                    local d = Instance.new("Frame", c); d.Size = UDim2.new(0,4,0,4); d.Position = UDim2.new(0,6,0,5)
                    d.BackgroundColor3 = Color3.fromRGB(100,220,130); d.BorderSizePixel = 0
                    Instance.new("UICorner", d).CornerRadius = UDim.new(1,0)
                    local t = Instance.new("TextLabel", c); t.Size = UDim2.new(1,-8,0,9); t.Position = UDim2.new(0,4,0,3)
                    t.BackgroundTransparency = 1; t.Text = tag; t.TextColor3 = Color3.fromRGB(180,180,180)
                    t.TextSize = 8; t.Font = Enum.Font.GothamBold
                    local v = Instance.new("TextLabel", c); v.Size = UDim2.new(1,0,0,16); v.Position = UDim2.new(0,0,0,16)
                    v.BackgroundTransparency = 1; v.Text = "--"; v.TextColor3 = Color3.fromRGB(240,240,240)
                    v.TextSize = 13; v.Font = Enum.Font.GothamBold
                    return v, d
                end
                StatsOverlay.fpsVal, StatsOverlay.fpsDot = mk("FPS")
                StatsOverlay.pingVal, StatsOverlay.pingDot = mk("PING")
                StatsOverlay.gui = g
            end
            StatsOverlay.gui.Enabled = true
            local fc, el, sf = 0, 0, 0
            StatsOverlay.fpsConn = RunService.RenderStepped:Connect(function(dt)
                fc += 1; el += dt
                if el >= 0.5 then sf = math.round(fc / el); fc = 0; el = 0 end
            end)
            StatsOverlay.conn = task.spawn(function()
                while StatsOverlay.gui do
                    pcall(function()
                        local fps = sf
                        local fc3 = fps >= 55 and Color3.fromRGB(100,220,130) or fps >= 30 and Color3.fromRGB(230,200,80) or Color3.fromRGB(220,80,80)
                        StatsOverlay.fpsVal.Text = tostring(fps); StatsOverlay.fpsVal.TextColor3 = fc3; StatsOverlay.fpsDot.BackgroundColor3 = fc3
                        local ping = math.round(LocalPlayer:GetNetworkPing() * 1000)
                        local pc3 = ping <= 80 and Color3.fromRGB(100,220,130) or ping <= 150 and Color3.fromRGB(230,200,80) or Color3.fromRGB(220,80,80)
                        StatsOverlay.pingVal.Text = tostring(ping); StatsOverlay.pingVal.TextColor3 = pc3; StatsOverlay.pingDot.BackgroundColor3 = pc3
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if StatsOverlay.gui then StatsOverlay.gui:Destroy(); StatsOverlay.gui = nil end
            if StatsOverlay.conn then pcall(task.cancel, StatsOverlay.conn); StatsOverlay.conn = nil end
            if StatsOverlay.fpsConn then StatsOverlay.fpsConn:Disconnect(); StatsOverlay.fpsConn = nil end
            StatsOverlay = { gui=nil, fpsVal=nil, pingVal=nil, conn=nil, fpsConn=nil }
        end
    end})

VisualTab:AddSection("Ping Spoofer")
local ping_conn
VisualTab:AddToggle({Title = "Ping Spoofer", Default = false, Flag = "ping_spoofer",
    Callback = function(state)
        if state then
            if not ping_conn then
                ping_conn = RunService.RenderStepped:Connect(function()
                    local fake = tostring(math.floor(tonumber(getgenv().FakePing) or 999))
                    local rg = CoreGui:FindFirstChild("RobloxGui")
                    if rg then
                        local pss = rg:FindFirstChild("PerformanceStats")
                        if pss then
                            for _, d in ipairs(pss:GetDescendants()) do
                                if d:IsA("TextLabel") and d.Text:match("%d+ ms") then d.Text = fake.." ms" end
                            end
                        end
                    end
                end)
            end
        else
            if ping_conn then ping_conn:Disconnect(); ping_conn = nil end
        end
    end})
VisualTab:AddTextBox({Title = "Ping Value", PlaceholderText = "Enter fake ping", Default = "999", Flag = "ping_text",
    Callback = function(v) getgenv().FakePing = v end})

VisualTab:AddSection("Sound Controller")
local soundOptions = {
    Eeyuh = "rbxassetid://16190782181",
    ["Sour Grapes"] = "rbxassetid://117820392172291",
    Erwachen = "rbxassetid://124853612881772",
    ["Grasp the Light"] = "rbxassetid://89549155689397",
    ["Beyond the Shadows"] = "rbxassetid://120729792529978",
    ["Rise to the Horizon"] = "rbxassetid://72573266268313",
    ["Lo-fi Chill A"] = "rbxassetid://9043887091",
    ["Lo-fi Ambient"] = "rbxassetid://129775776987523",
    ["Tears in the Rain"] = "rbxassetid://129710845038263",
}
local soundOptionNames = {"Eeyuh","Sour Grapes","Erwachen","Grasp the Light","Beyond the Shadows","Rise to the Horizon","Lo-fi Chill A","Lo-fi Ambient","Tears in the Rain"}
local currentSound = Instance.new("Sound")
currentSound.Volume = getgenv().SoundControllerVolume or 3
currentSound.Looped = getgenv().LoopSong or false
currentSound.Parent = game:GetService("SoundService")
VisualTab:AddToggle({Title = "Sound Controller", Default = false, Flag = "sound_controller",
    Callback = function(state)
        getgenv().sound_controller = state
        if state then
            currentSound:Stop()
            currentSound.SoundId = soundOptions[getgenv().SelectedSound] or soundOptions.Eeyuh
            currentSound:Play()
        else currentSound:Stop() end
    end})
VisualTab:AddToggle({Title = "Loop Song", Default = false, Flag = "LoopSong",
    Callback = function(s) currentSound.Looped = s end})
VisualTab:AddSlider({Title = "Volume", Min = 1, Max = 10, Default = 3, Flag = "SoundControllerVolume",
    Callback = function(v) currentSound.Volume = v end})
VisualTab:AddDropdown({Title = "Select Sound", Options = soundOptionNames, Default = "Eeyuh", Flag = "sound_selection",
    Callback = function(value)
        local v = (typeof(value) == "table" and value[1]) or value
        getgenv().SelectedSound = v
        if getgenv().sound_controller then
            currentSound:Stop()
            currentSound.SoundId = soundOptions[v] or soundOptions.Eeyuh
            currentSound:Play()
        end
    end})

local MiscTab = windows:MakeTab({Title = "Misc", Icon = "settings"})
MiscTab:AddSection("FPS Boost")
local fps_boost_conn, fps_boost_enabled = nil, false
local function apply_fps_boost(state)
    fps_boost_enabled = state
    if fps_boost_conn then fps_boost_conn:Disconnect(); fps_boost_conn = nil end
    if not state then
        pcall(function() Lighting.FogEnd = 9e9; Lighting.FogStart = 9e9 end)
        pcall(function()
            for _, v in ipairs(Lighting:GetDescendants()) do if v:IsA("PostEffect") then v.Enabled = true end end
        end)
        return
    end
    pcall(function() Lighting.FogEnd = math.huge; Lighting.FogStart = math.huge end)
    pcall(function()
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("PostEffect") then pcall(function() v.Enabled = false end) end
        end
    end)
    fps_boost_conn = RunService.Heartbeat:Connect(function()
        if not fps_boost_enabled then return end
        for _, obj in pairs(Workspace:GetDescendants()) do
            pcall(function()
                local lc = LocalPlayer.Character
                if lc and obj:IsDescendantOf(lc) then return end
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
                    or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                elseif obj:IsA("Part") then
                    obj.CastShadow = false
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end)
        end
    end)
end
MiscTab:AddToggle({Title = "FPS Booster", Default = false, Flag = "FPSBooster", Callback = apply_fps_boost})
MiscTab:AddToggle({Title = "Low Graphics", Default = false, Flag = "LowGraphics",
    Callback = function(state)
        if state then
            pcall(function()
                getgenv()._universeQuality = settings().Rendering.QualityLevel
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            pcall(function() Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9 end)
        else
            pcall(function()
                if getgenv()._universeQuality then settings().Rendering.QualityLevel = getgenv()._universeQuality end
            end)
            pcall(function() Lighting.GlobalShadows = true end)
        end
    end})
MiscTab:AddSection("Rendering")
MiscTab:AddToggle({Title = "No Render", Default = false, Flag = "No_Render",
    Callback = function(state)
        getgenv().No_Render = state
        local ps2 = LocalPlayer:FindFirstChild("PlayerScripts")
        local es = ps2 and ps2:FindFirstChild("EffectScripts")
        local cf = es and es:FindFirstChild("ClientFX")
        if cf then cf.Disabled = state end
        if state then
            if not Connections["No_Render"] then
                local rt = Workspace:FindFirstChild("Runtime")
                if rt then Connections["No_Render"] = rt.ChildAdded:Connect(function(v) Debris:AddItem(v, 0) end) end
            end
        else
            if Connections["No_Render"] then Connections["No_Render"]:Disconnect(); Connections["No_Render"] = nil end
        end
    end})

local WorldTab = windows:MakeTab({Title = "World", Icon = "globe"})
local function ensure_color_correction()
    local cc = Lighting:FindFirstChild("UniverseColorCorrection")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect"); cc.Name = "UniverseColorCorrection"; cc.Parent = Lighting
    end
    return cc
end
local function apply_filter()
    if not getgenv().FilterEnabled then
        local ca = Lighting:FindFirstChild("UniverseAtmosphere"); if ca then ca:Destroy() end
        local cc = ensure_color_correction(); cc.TintColor = Color3.new(1,1,1); cc.Saturation = 0; return
    end
    if getgenv().AtmosphereEnabled then
        local a = Lighting:FindFirstChild("UniverseAtmosphere")
        if not a then a = Instance.new("Atmosphere"); a.Name = "UniverseAtmosphere"; a.Parent = Lighting end
        a.Density = getgenv().AtmosphereDensity or 0.5
    else
        local a = Lighting:FindFirstChild("UniverseAtmosphere"); if a then a:Destroy() end
    end
    local cc = ensure_color_correction()
    cc.Saturation = getgenv().SaturationEnabled and (getgenv().SaturationLevel or 0) or 0
    cc.TintColor = getgenv().HueEnabled and Color3.fromHSV(getgenv().HueShift or 0, 1, 1) or Color3.new(1,1,1)
end
WorldTab:AddSection("World Filter")
WorldTab:AddToggle({Title = "Filter", Default = false, Flag = "Filter", Callback = function(s) getgenv().FilterEnabled = s; apply_filter() end})
WorldTab:AddToggle({Title = "Enable Atmosphere", Default = false, Flag = "World_Filter_Atmosphere", Callback = function(s) getgenv().AtmosphereEnabled = s; apply_filter() end})
WorldTab:AddSlider({Title = "Atmosphere Density", Min = 0, Max = 1, Default = 0.5, Flag = "World_Filter_Atmosphere_Slider",
    Callback = function(v) getgenv().AtmosphereDensity = v; if getgenv().FilterEnabled then apply_filter() end end})
WorldTab:AddToggle({Title = "Enable Saturation", Default = false, Flag = "World_Filter_Saturation", Callback = function(s) getgenv().SaturationEnabled = s; apply_filter() end})
WorldTab:AddSlider({Title = "Saturation Level", Min = -1, Max = 1, Default = 0, Flag = "World_Filter_Saturation_Slider",
    Callback = function(v) getgenv().SaturationLevel = v; if getgenv().FilterEnabled then apply_filter() end end})
WorldTab:AddToggle({Title = "Enable Hue", Default = false, Flag = "World_Filter_Hue", Callback = function(s) getgenv().HueEnabled = s; apply_filter() end})
WorldTab:AddSlider({Title = "Hue Shift", Min = -1, Max = 1, Default = 0, Flag = "World_Filter_Hue_Slider",
    Callback = function(v) getgenv().HueShift = v; if getgenv().FilterEnabled then apply_filter() end end})

local GuiTab = windows:MakeTab({Title = "GUI", Icon = "sliders"})
GuiTab:AddSection("Interface")
GuiTab:AddToggle({Title = "GUI Visible", Default = false, Flag = "guilibraryvisible",
    Callback = function(state) getgenv().guilibraryvisible = state end})
GuiTab:AddParagraph({Title = "Mobile Reopen", Text = "On mobile, use the ☰ button in the bottom-right corner to reopen the UI."})

local ExplosionChanger = { enabled=false, conn_dead=nil, conn_char=nil, conn_child=nil }
getgenv().explosionFX = getgenv().explosionFX or ""
local function norm_name(v) return tostring(v or ""):lower():gsub("[^%w]", "") end
local function get_explosion_folder()
    local sh = ReplicatedStorage:FindFirstChild("Shared")
    local ri = sh and sh:FindFirstChild("ReplicatedInstances")
    return ri and ri:FindFirstChild("Explosions")
end
local function is_playable_template(obj)
    if typeof(obj) ~= "Instance" then return false end
    if obj:IsA("Configuration") or obj:IsA("ModuleScript") or obj:IsA("Script")
        or obj:IsA("LocalScript") or obj:IsA("BindableFunction") or obj:IsA("BindableEvent") then return false end
    return obj:IsA("Folder") or obj:IsA("Model") or obj:IsA("BasePart")
        or obj:FindFirstChildWhichIsA("BasePart", true) ~= nil
        or obj:FindFirstChildWhichIsA("ParticleEmitter", true) ~= nil
end
local function find_explosion_template(name)
    local folder = get_explosion_folder()
    if not folder or not name or name == "" then return nil end
    local direct = folder:FindFirstChild(name, true)
    if direct and is_playable_template(direct) then return direct end
    local want = norm_name(name)
    for _, child in ipairs(folder:GetDescendants()) do
        if is_playable_template(child) and norm_name(child.Name) == want then return child end
    end
    return nil
end
local function activate_local_explosion(root)
    local items = {root}
    for _, d in ipairs(root:GetDescendants()) do items[#items+1] = d end
    for _, obj in ipairs(items) do
        if obj:IsA("BasePart") then
            obj.Anchored = true; obj.CanCollide = false; obj.CanTouch = false; obj.CanQuery = false
        elseif obj:IsA("ParticleEmitter") then
            pcall(function() obj:Emit(tonumber(obj:GetAttribute("EmitCount")) or 30) end)
        elseif obj:IsA("Beam") or obj:IsA("Trail") then obj.Enabled = true
        elseif obj:IsA("Light") then obj.Enabled = true
        elseif obj:IsA("Sound") then pcall(function() obj:Play() end) end
    end
end
local function play_local_explosion(position)
    if not ExplosionChanger.enabled then return end
    local name = getgenv().explosionFX; if not name or name == "" then return end
    local template = find_explosion_template(name); if not template then return end
    local clone = template:Clone()
    clone.Name = "UniverseExplosion_" .. name
    local parent = Workspace:FindFirstChild("Runtime") or Workspace
    local cf = CFrame.new(position or Vector3.zero)
    if clone:IsA("Model") then pcall(function() clone:PivotTo(cf) end)
    elseif clone:IsA("BasePart") then clone.CFrame = cf
    elseif clone:IsA("Folder") or clone:IsA("Attachment") then
        local anchor = Instance.new("Part"); anchor.Name = "UniverseExplosionAnchor"
        anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false
        anchor.Transparency = 1; anchor.Size = Vector3.new(1,1,1); anchor.CFrame = cf
        if clone:IsA("Attachment") then
            anchor.Parent = parent; clone.Parent = anchor; clone = anchor
        else
            anchor.Parent = clone
            local base = clone:FindFirstChildWhichIsA("BasePart", true)
            if base then
                local offset = cf.Position - base.Position
                for _, p in ipairs(clone:GetDescendants()) do
                    if p:IsA("BasePart") then p.CFrame = p.CFrame + offset end
                end
            end
        end
    end
    if not clone.Parent then clone.Parent = parent end
    activate_local_explosion(clone)
    task.delay(6, function() if clone and clone.Parent then clone:Destroy() end end)
end
local function hook_dead_folder()
    if ExplosionChanger.conn_dead then ExplosionChanger.conn_dead:Disconnect() end
    local dead = Workspace:FindFirstChild("Dead"); if not dead then return end
    ExplosionChanger.conn_dead = dead.ChildAdded:Connect(function(character)
        if not ExplosionChanger.enabled then return end
        task.wait(0.05)
        if character == LocalPlayer.Character then return end
        local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart; if not root then return end
        local creator = character:FindFirstChild("creator", true) or character:FindFirstChild("Creator", true)
        local is_local = creator and (creator.Value == LocalPlayer or creator.Value == LocalPlayer.Name)
        if is_local then play_local_explosion(root.Position) end
    end)
end
local function explosion_start()
    if ExplosionChanger.enabled then return end
    ExplosionChanger.enabled = true
    hook_dead_folder()
    if not ExplosionChanger.conn_char then
        ExplosionChanger.conn_char = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.3); if ExplosionChanger.enabled then hook_dead_folder() end
        end)
    end
    if not ExplosionChanger.conn_child then
        ExplosionChanger.conn_child = Workspace.ChildAdded:Connect(function(c)
            if c.Name == "Dead" and ExplosionChanger.enabled then task.defer(hook_dead_folder) end
        end)
    end
end
local function explosion_stop()
    ExplosionChanger.enabled = false
    if ExplosionChanger.conn_dead then ExplosionChanger.conn_dead:Disconnect(); ExplosionChanger.conn_dead = nil end
    if ExplosionChanger.conn_char then ExplosionChanger.conn_char:Disconnect(); ExplosionChanger.conn_char = nil end
    if ExplosionChanger.conn_child then ExplosionChanger.conn_child:Disconnect(); ExplosionChanger.conn_child = nil end
end

local EmoteState = { catalog={}, by_name={}, favorites={}, destroying=false, wheel_conn=nil }
local function emote_asset_id(v) return tostring(v or ""):match("%d+") end
do
    local FAV_FILE = "Universe Hub/emote_favorites.json"
    pcall(function()
        if isfile and isfile(FAV_FILE) then
            local decoded = HttpService:JSONDecode(readfile(FAV_FILE))
            if type(decoded) == "table" then
                for _, n in ipairs(decoded) do
                    if type(n) == "string" and n ~= "" then EmoteState.favorites[n] = true end
                end
            end
        end
    end)
    EmoteState.save_favs = function()
        pcall(function()
            if isfolder and makefolder and not isfolder("Universe Hub") then makefolder("Universe Hub") end
            if writefile then
                local list = {}
                for n in pairs(EmoteState.favorites) do list[#list+1] = n end
                table.sort(list)
                writefile(FAV_FILE, HttpService:JSONEncode(list))
            end
        end)
    end
end
local function find_emotes_folder()
    local folders = {}
    local misc = ReplicatedStorage:FindFirstChild("Misc")
    local e1 = misc and misc:FindFirstChild("Emotes")
    if e1 then folders[#folders+1] = e1 end
    local sh = ReplicatedStorage:FindFirstChild("Shared")
    local ri = ReplicatedStorage:FindFirstChild("ReplicatedInstances") or (sh and sh:FindFirstChild("ReplicatedInstances"))
    local e2 = ri and ri:FindFirstChild("Emotes")
    if e2 and not table.find(folders, e2) then folders[#folders+1] = e2 end
    if #folders == 0 then
        for _, c in ipairs(ReplicatedStorage:GetDescendants()) do
            if c:IsA("Folder") and c.Name == "Emotes" then folders[#folders+1] = c end
        end
    end
    return folders
end
local function refresh_catalog()
    table.clear(EmoteState.catalog); table.clear(EmoteState.by_name)
    local folders = find_emotes_folder()
    for _, f in ipairs(folders) do
        for _, obj in ipairs(f:GetDescendants()) do
            if obj:IsA("Animation") then
                local name = obj:GetAttribute("EmoteName") or obj.Name
                if type(name) == "string" and name ~= "" and not EmoteState.by_name[name] then
                    local entry = { Name=name, Id=obj.Name, Animation=obj, Attributes=obj:GetAttributes() }
                    EmoteState.catalog[#EmoteState.catalog+1] = entry
                    EmoteState.by_name[name] = entry
                end
            end
        end
    end
    table.sort(EmoteState.catalog, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return #EmoteState.catalog
end
local function get_wheel_contents()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui"); if not pg then return {} end
    local wheel = pg:FindFirstChild("EmoteWheel", true); if not wheel then return {} end
    local list = wheel:FindFirstChild("List", true)
    local content = list and list:FindFirstChild("Content", true)
    return content and {content} or {}
end
local function get_entry_image(entry)
    for _, key in ipairs({"Icon","Image","ImageId","Thumbnail","EmoteIcon"}) do
        local v = entry.Attributes and entry.Attributes[key]
        if v and tostring(v) ~= "" then
            local s = tostring(v)
            if s:find("rbxassetid://", 1, true) then return s end
            local id = emote_asset_id(s); return id and ("rbxassetid://"..id) or nil
        end
    end
    return nil
end
local function apply_emote_wheel()
    if EmoteState.destroying then return end
    local contents = get_wheel_contents(); if #contents == 0 then return end
    for _, content in ipairs(contents) do
        local sig = tostring(#EmoteState.catalog)
        if content:GetAttribute("UniverseSignature") == sig then
            local count = 0
            for _, c in ipairs(content:GetChildren()) do
                if c:GetAttribute("UniverseEmoteCard") then count += 1 end
            end
            if count >= #EmoteState.catalog then continue end
        end
        for _, c in ipairs(content:GetChildren()) do
            if c:IsA("GuiObject") and c:GetAttribute("UniverseEmoteCard") then pcall(function() c:Destroy() end) end
        end
        local grid = content:FindFirstChildOfClass("UIGridLayout")
        if not grid then grid = Instance.new("UIGridLayout"); grid.Parent = content end
        grid.CellSize = UDim2.fromOffset(118, 118); grid.CellPadding = UDim2.fromOffset(8, 8)
        grid.SortOrder = Enum.SortOrder.LayoutOrder; grid.FillDirection = Enum.FillDirection.Horizontal
        grid.HorizontalAlignment = Enum.HorizontalAlignment.Center; grid.FillDirectionMaxCells = 2
        for i, entry in ipairs(EmoteState.catalog) do
            local card = Instance.new("TextButton")
            card.Name = "UniverseEmote_"..i; card:SetAttribute("UniverseEmoteCard", true)
            card:SetAttribute("EmoteName", entry.Name)
            if entry.Animation then card:SetAttribute("AnimationId", entry.Animation.AnimationId) end
            card.LayoutOrder = i; card.Size = UDim2.fromOffset(118, 118)
            card.BackgroundColor3 = Color3.fromRGB(16, 24, 55)
            card.BorderSizePixel = 0; card.AutoButtonColor = false; card.Text = ""; card.ClipsDescendants = true
            card.Parent = content
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
            local icon = get_entry_image(entry)
            if icon then
                local img = Instance.new("ImageLabel"); img.BackgroundTransparency = 1
                img.Size = UDim2.fromScale(0.84, 0.62); img.Position = UDim2.fromScale(0.08, 0.06)
                img.Image = icon; img.ScaleType = Enum.ScaleType.Fit; img.Parent = card
            end
            local nameLabel = Instance.new("TextLabel"); nameLabel.BackgroundTransparency = 1
            nameLabel.Position = UDim2.fromScale(0.04, 0.64); nameLabel.Size = UDim2.fromScale(0.92, 0.33)
            nameLabel.Font = Enum.Font.GothamBold; nameLabel.Text = entry.Name
            nameLabel.TextColor3 = Color3.fromRGB(255,255,255); nameLabel.TextWrapped = true
            nameLabel.TextScaled = true; nameLabel.ZIndex = 5; nameLabel.Parent = card
            local lim = Instance.new("UITextSizeConstraint")
            lim.MinTextSize = 10; lim.MaxTextSize = 18; lim.Parent = nameLabel
            local star = Instance.new("TextButton"); star.BackgroundTransparency = 1
            star.Position = UDim2.new(1,-28,0,4); star.Size = UDim2.new(0,24,0,24)
            star.Font = Enum.Font.GothamBold; star.TextSize = 22; star.TextStrokeTransparency = 0
            star.ZIndex = 10; star.Parent = card
            local function update_star()
                if EmoteState.favorites[entry.Name] then
                    star.Text = "★"; star.TextColor3 = Color3.fromRGB(255, 215, 0)
                else star.Text = "☆"; star.TextColor3 = Color3.fromRGB(200, 200, 200) end
            end
            update_star()
            star.MouseButton1Click:Connect(function()
                if EmoteState.favorites[entry.Name] then EmoteState.favorites[entry.Name] = nil
                else
                    local count = 0; for _ in pairs(EmoteState.favorites) do count += 1 end
                    if count < 8 then EmoteState.favorites[entry.Name] = true
                    else notify("Favorites", "Limit 8 reached", 2, "Warning") end
                end
                update_star(); EmoteState.save_favs()
            end)
            card.MouseEnter:Connect(function() card.BackgroundColor3 = Color3.fromRGB(26, 38, 85) end)
            card.MouseLeave:Connect(function() card.BackgroundColor3 = Color3.fromRGB(16, 24, 55) end)
            card.MouseButton1Click:Connect(function()
                getgenv().SelectedEmote = entry.Name
                if getgenv().playEmote then pcall(getgenv().playEmote, entry.Name) end
            end)
        end
        content:SetAttribute("UniverseSignature", sig)
    end
end
getgenv().playEmote = function(name)
    local entry = EmoteState.by_name[name]; if not entry then return false end
    local fired = false
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            for _, rname in ipairs({"PlayEmote","RequestPlayEmote","EmotePlay","EquipEmote"}) do
                local r = remotes:FindFirstChild(rname)
                if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
                    if r:IsA("RemoteEvent") then r:FireServer(entry.Id or entry.Name)
                    else r:InvokeServer(entry.Id or entry.Name) end
                    fired = true
                end
            end
        end
    end)
    return fired
end
local function emote_start()
    if not EmoteState.destroying and #EmoteState.catalog > 0 then return end
    EmoteState.destroying = false
    task.spawn(function()
        refresh_catalog(); task.wait(0.3); apply_emote_wheel()
        if not EmoteState.wheel_conn then
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pg then
                EmoteState.wheel_conn = pg.ChildAdded:Connect(function(c)
                    if c.Name == "EmoteWheel" then
                        task.wait(0.8); if not EmoteState.destroying then apply_emote_wheel() end
                    end
                end)
            end
        end
        while not EmoteState.destroying do
            task.wait(3)
            local contents = get_wheel_contents()
            if #contents > 0 then apply_emote_wheel() end
        end
    end)
end
local function emote_stop()
    EmoteState.destroying = true
    if EmoteState.wheel_conn then EmoteState.wheel_conn:Disconnect(); EmoteState.wheel_conn = nil end
end

local UnlockTab = windows:MakeTab({Title = "Unlock", Icon = "unlock"})
UnlockTab:AddSection("Sword Skin Changer")
UnlockTab:AddToggle({Title = "Enable Sword Changer", Default = false, Flag = "SwordChangerEnable",
    Callback = function(s) if s then sword_start() else sword_stop() end end})
UnlockTab:AddTextBox({Title = "Sword Model", PlaceholderText = "Exact sword name",
    Default = getgenv().swordModel ~= "" and getgenv().swordModel or "", Flag = "SwordModelName",
    Callback = function(text)
        getgenv().swordModel = text; getgenv().swordAnimations = text; getgenv().swordFX = text
        if SwordSkin.enabled then sword_update() end
    end})
UnlockTab:AddButton({Title = "Apply Sword", Callback = function() if SwordSkin.enabled then sword_update() end end})
UnlockTab:AddSection("Explosion Changer")
UnlockTab:AddToggle({Title = "Enable Explosion Changer", Default = false, Flag = "ExplosionChangerEnable",
    Callback = function(s) if s then explosion_start() else explosion_stop() end end})
UnlockTab:AddTextBox({Title = "Explosion Name", PlaceholderText = "Exact explosion name",
    Default = getgenv().explosionFX or "", Flag = "ExplosionName",
    Callback = function(text) getgenv().explosionFX = text end})
UnlockTab:AddButton({Title = "Test Explosion",
    Callback = function()
        local c = LocalPlayer.Character; local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then play_local_explosion(hrp.Position + hrp.CFrame.LookVector * 8) end
    end})
UnlockTab:AddSection("Emote Unlocker")
UnlockTab:AddToggle({Title = "Unlock All Emotes", Default = false, Flag = "EmoteUnlockerEnable",
    Callback = function(state)
        if state then
            emote_start()
            task.delay(2, function() notify("Emotes", tostring(#EmoteState.catalog).." emotes found", 3, "Success") end)
        else emote_stop() end
    end})
UnlockTab:AddButton({Title = "Refresh Emote Catalog",
    Callback = function() local n = refresh_catalog(); notify("Emotes", tostring(n).." emotes cached", 2, "Info") end})
UnlockTab:AddButton({Title = "Reinstall Emote Wheel",
    Callback = function()
        if #EmoteState.catalog == 0 then refresh_catalog() end
        apply_emote_wheel()
    end})

local MobilePanels = {}
local function make_mobile_button(cfg)
    cfg = cfg or {}
    local id = cfg.id or ("btn"..tostring(math.random(100000, 999999)))
    if MobilePanels[id] then pcall(function() MobilePanels[id].gui:Destroy() end); MobilePanels[id] = nil end
    local gui = Instance.new("ScreenGui"); gui.Name = "UniverseMobile_"..id; gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true; gui.DisplayOrder = 200
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = CoreGui
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.Position = UDim2.new(0, cfg.x or 20, 0, cfg.y or 100)
    frame.Size = UDim2.new(0, cfg.width or 150, 0, cfg.height or 66)
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    frame.BackgroundTransparency = 0.02; frame.BorderSizePixel = 0; frame.Active = true; frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    local st = Instance.new("UIStroke", frame); st.Color = Color3.fromRGB(38,38,38); st.Thickness = 1
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 18); title.Position = UDim2.new(0, 0, 0, 6)
    title.BackgroundTransparency = 1; title.Text = cfg.label or id
    title.TextColor3 = Color3.fromRGB(230,230,230); title.TextSize = 13; title.Font = Enum.Font.GothamBold
    local mainBtn = Instance.new("TextButton", frame)
    mainBtn.Size = UDim2.new(1, -20, 0, 32); mainBtn.Position = UDim2.new(0, 10, 0, 28)
    mainBtn.BackgroundColor3 = Color3.fromRGB(24,24,24); mainBtn.Text = cfg.offText or "OFF"
    mainBtn.TextColor3 = Color3.fromRGB(255,255,255); mainBtn.TextSize = 14; mainBtn.Font = Enum.Font.GothamBold
    mainBtn.BorderSizePixel = 0; mainBtn.AutoButtonColor = false
    Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 8)
    local mbs = Instance.new("UIStroke", mainBtn); mbs.Color = Color3.fromRGB(38,38,38); mbs.Thickness = 1
    local state = false
    local function render()
        if state then
            mainBtn.Text = cfg.onText or "ON"; mainBtn.TextColor3 = Color3.fromRGB(18,18,18)
            mainBtn.BackgroundColor3 = Color3.fromRGB(100,220,130); mbs.Color = Color3.fromRGB(100,220,130)
        else
            mainBtn.Text = cfg.offText or "OFF"; mainBtn.TextColor3 = Color3.fromRGB(255,255,255)
            mainBtn.BackgroundColor3 = Color3.fromRGB(24,24,24); mbs.Color = Color3.fromRGB(38,38,38)
        end
    end
    render()
    local dragging, dragStart, startPos, moved, downTick
    local function startDrag(input) dragging = true; dragStart = input.Position; startPos = frame.Position; moved = false; downTick = tick() end
    local function updateDrag(input)
        if not dragging then return end
        local d = input.Position - dragStart
        if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then moved = true end
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then startDrag(i) end
    end)
    title.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then updateDrag(i) end
    end)
    UIS.InputChanged:Connect(function(i) if dragging then updateDrag(i) end end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    mainBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            moved = false; downTick = tick()
        end
    end)
    mainBtn.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.Touch and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if moved then return end
        if tick() - (downTick or 0) > 0.5 then return end
        state = not state; render()
        if cfg.onToggle then pcall(cfg.onToggle, state) end
    end)
    MobilePanels[id] = {
        gui = gui, frame = frame, button = mainBtn,
        setState = function(v) state = v; render() end,
        getState = function() return state end
    }
    return MobilePanels[id]
end

if IS_MOBILE then
    make_mobile_button({id = "AutoParry", label = "Auto Parry", x = 20, y = 100,
        onToggle = function(state)
            System.__properties.__autoparry_enabled = state
            if state then System.autoparry.start() else System.autoparry.stop() end
            if getgenv().AutoParryNotify then
                notify("Auto Parry", state and "ON" or "OFF", 1.5, state and "Success" or "Error")
            end
        end})
    make_mobile_button({id = "Triggerbot", label = "6xTB", x = 20, y = 172,
        onToggle = function(state)
            System.__properties.__triggerbot_enabled = state
            System.triggerbot.enable(state)
            if getgenv().TriggerbotNotify then
                notify("Triggerbot", state and "ON" or "OFF", 1.5, state and "Success" or "Error")
            end
        end})
    make_mobile_button({id = "ManualSpam", label = "6xMS", x = 20, y = 244,
        onToggle = function(state)
            if state then System.manual_spam.start() else System.manual_spam.stop() end
        end})
    make_mobile_button({id = "Panic", label = "PANIC", x = 20, y = 316, width = 110, height = 60,
        onText = "RESET", offText = "STOP ALL",
        onToggle = function(state)
            if not state then return end
            System.__properties.__autoparry_enabled = false
            System.__properties.__triggerbot_enabled = false
            System.__properties.__manual_spam_enabled = false
            System.__properties.__auto_spam_enabled = false
            pcall(function() System.autoparry.stop() end)
            pcall(function() System.triggerbot.enable(false) end)
            pcall(function() System.manual_spam.stop() end)
            pcall(function() System.auto_spam.stop() end)
            if MobilePanels.AutoParry then MobilePanels.AutoParry.setState(false) end
            if MobilePanels.Triggerbot then MobilePanels.Triggerbot.setState(false) end
            if MobilePanels.ManualSpam then MobilePanels.ManualSpam.setState(false) end
            notify("Panic", "All systems disabled", 2, "Warning")
            task.delay(1, function() if MobilePanels.Panic then MobilePanels.Panic.setState(false) end end)
        end})

    local curveGui = Instance.new("ScreenGui")
    curveGui.Name = "UniverseCurveSelector"; curveGui.ResetOnSpawn = false
    curveGui.IgnoreGuiInset = true; curveGui.DisplayOrder = 210; curveGui.Parent = CoreGui
    local curveFab = Instance.new("TextButton", curveGui)
    curveFab.AnchorPoint = Vector2.new(1, 0); curveFab.Position = UDim2.new(1, -20, 0, 100)
    curveFab.Size = UDim2.new(0, 130, 0, 44); curveFab.BackgroundColor3 = Color3.fromRGB(12,12,12)
    curveFab.Text = "Curve"; curveFab.TextColor3 = Color3.fromRGB(240,240,240)
    curveFab.TextSize = 12; curveFab.Font = Enum.Font.GothamBold
    curveFab.BorderSizePixel = 0; curveFab.AutoButtonColor = false
    Instance.new("UICorner", curveFab).CornerRadius = UDim.new(0, 12)
    local cfs = Instance.new("UIStroke", curveFab); cfs.Color = Color3.fromRGB(60,60,60); cfs.Thickness = 1
    local scrim = Instance.new("TextButton", curveGui)
    scrim.Size = UDim2.new(1,0,1,0); scrim.BackgroundColor3 = Color3.new(0,0,0)
    scrim.BackgroundTransparency = 1; scrim.Text = ""; scrim.AutoButtonColor = false; scrim.Visible = false
    local sheet = Instance.new("Frame", curveGui)
    sheet.AnchorPoint = Vector2.new(0.5, 1); sheet.Position = UDim2.new(0.5, 0, 1, 260)
    sheet.Size = UDim2.new(0.9, 0, 0, 220); sheet.BackgroundColor3 = Color3.fromRGB(12,12,12)
    sheet.BorderSizePixel = 0; sheet.Visible = false
    Instance.new("UICorner", sheet).CornerRadius = UDim.new(0, 16)
    local shs = Instance.new("UIStroke", sheet); shs.Color = Color3.fromRGB(80,80,80); shs.Thickness = 1
    local stl = Instance.new("TextLabel", sheet)
    stl.Size = UDim2.new(1,-32,0,20); stl.Position = UDim2.new(0,16,0,18)
    stl.BackgroundTransparency = 1; stl.Text = "CURVE MODE"
    stl.TextColor3 = Color3.fromRGB(160,160,160); stl.TextSize = 11
    stl.Font = Enum.Font.GothamBold; stl.TextXAlignment = Enum.TextXAlignment.Left
    local gridHolder = Instance.new("Frame", sheet)
    gridHolder.BackgroundTransparency = 1; gridHolder.Position = UDim2.new(0,14,0,44)
    gridHolder.Size = UDim2.new(1,-28,1,-58)
    local grid = Instance.new("UIGridLayout", gridHolder)
    grid.CellSize = UDim2.new(0.333, -8, 0, 44); grid.CellPadding = UDim2.new(0, 8, 0, 8)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    local pills = {}
    local function refresh_pills()
        for name, pill in pairs(pills) do
            local isActive = System.__config.__curve_names[System.__properties.__curve_mode] == name
            pill.BackgroundColor3 = isActive and Color3.fromRGB(160,160,160) or Color3.fromRGB(24,24,24)
            pill.TextColor3 = isActive and Color3.fromRGB(255,255,255) or Color3.fromRGB(220,220,220)
        end
        local cur = System.__config.__curve_names[System.__properties.__curve_mode] or "Camera"
        curveFab.Text = "Curve: "..cur
    end
    local function open_sheet()
        scrim.Visible = true; sheet.Visible = true; refresh_pills()
        TweenService:Create(sheet, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5,0,1,-60) }):Play()
        TweenService:Create(scrim, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
    end
    local function close_sheet()
        TweenService:Create(sheet, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5,0,1,260) }):Play()
        TweenService:Create(scrim, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
        task.delay(0.3, function() scrim.Visible = false; sheet.Visible = false end)
    end
    for i, name in ipairs(System.__config.__curve_names) do
        local pill = Instance.new("TextButton", gridHolder)
        pill.LayoutOrder = i; pill.BackgroundColor3 = Color3.fromRGB(24,24,24)
        pill.Text = name; pill.TextColor3 = Color3.fromRGB(220,220,220)
        pill.TextSize = 12; pill.Font = Enum.Font.GothamBold
        pill.BorderSizePixel = 0; pill.AutoButtonColor = false
        Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 10)
        local pst = Instance.new("UIStroke", pill); pst.Color = Color3.fromRGB(60,60,60); pst.Thickness = 1
        pill.MouseButton1Click:Connect(function()
            System.__properties.__curve_mode = i
            refresh_pills(); notify("Curve", name, 1.2, "Info"); close_sheet()
        end)
        pills[name] = pill
    end
    curveFab.MouseButton1Click:Connect(open_sheet)
    scrim.MouseButton1Click:Connect(close_sheet)
    refresh_pills()

    task.defer(function()
        task.wait(0.5)
        local rg = Instance.new("ScreenGui"); rg.Name = "UniverseReopen"; rg.ResetOnSpawn = false
        rg.IgnoreGuiInset = true; rg.DisplayOrder = 150; rg.Parent = CoreGui
        local btn = Instance.new("TextButton", rg)
        btn.AnchorPoint = Vector2.new(1, 1); btn.Position = UDim2.new(1, -20, 1, -20)
        btn.Size = UDim2.new(0, 50, 0, 50); btn.BackgroundColor3 = Color3.fromRGB(12,12,12)
        btn.Text = "☰"; btn.TextColor3 = Color3.fromRGB(240,240,240); btn.TextSize = 22
        btn.Font = Enum.Font.GothamBold; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 25)
        local rs = Instance.new("UIStroke", btn); rs.Color = Color3.fromRGB(60,60,60); rs.Thickness = 1
        btn.MouseButton1Click:Connect(function()
            pcall(function()
                local gui = CoreGui:FindFirstChild("redz Library V5")
                if gui then
                    local hub = gui:FindFirstChild("Hub")
                    if hub then hub.Visible = not hub.Visible end
                end
            end)
        end)
    end)
end

notify("Universe Hub", "Blade Ball loaded", 3, "Success")
print("[Universe Hub] Bladeball loaded. Method:", _PARRY_PATCH.method or "unknown")

return redzlib