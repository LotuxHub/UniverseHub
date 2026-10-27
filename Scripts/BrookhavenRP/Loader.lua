local Players           = game:GetService("Players")
local UIS               = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = workspace
local LocalPlayer       = Players.LocalPlayer
local Mouse             = LocalPlayer:GetMouse()
local IMG     = "rbxassetid://111672166073808" 
local LIB_URL = "https://raw.githubusercontent.com/UniverseHub/UniverseHub/refs/heads/main/Library/UniverseLibrary.lua"
if not redzlib then
    local ok, lib = pcall(function() return loadstring(game:HttpGet(LIB_URL))() end)
    if ok and lib then redzlib = lib end
end
assert(redzlib, "[Universe Brookhaven] Nao foi possivel carregar redzlib")

local function notify(title, desc, dur, kind)
    pcall(function()
        redzlib:Notify({
            Title = title, Description = desc,
            Duration = dur or 2, Image = img, Type = kind or "Info",
        })
    end)
end

local IS_MOBILE = UIS.TouchEnabled and not UIS.MouseEnabled
getgenv().UniverseMobile = IS_MOBILE

local RS = ReplicatedStorage
local RemoteEvents = RS:WaitForChild("RemoteEvents", 10)

local function fireRemote(remoteName, ...)
    if not RemoteEvents then return false end
    local remote = RemoteEvents:FindFirstChild(remoteName)
    if not remote then
        warn("[Universe BH] Remote nao encontrado:", remoteName)
        return false
    end
    local args = table.pack(...)
    local ok = pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
    return ok
end

local function invokeRemote(remoteName, ...)
    if not RemoteEvents then return false end
    local remote = RemoteEvents:FindFirstChild(remoteName)
    if not remote then return false end
    local args = table.pack(...)
    local ok = pcall(function()
        remote:InvokeServer(table.unpack(args, 1, args.n))
    end)
    return ok
end

local LagLoop = false

local function startLagServer()
    LagLoop = true
    task.spawn(function()
        local carRemote = RemoteEvents:FindFirstChild("Car")
        if not carRemote then return end
        local cars = {
            "RV","FordGT","FoodTruck","CopSUV","Van","FireTruck","Ambulance",
            "Bus","CopUnderCoverSUV","QuadStock","Challenger","Jeep","CopChallenger",
            "Cadillac","GolfCart","NPHarleyDavison","Horse","ScooterVehicle","SmartCar",
        }
        while LagLoop do
            for _, car in ipairs(cars) do
                if not LagLoop then break end
                pcall(function() carRemote:FireServer("PickingCar", car) end)
            end
        end
    end)
end

local function stopLagServer() LagLoop = false end

local function zeroGravityUnanchored()
    local function zeroGrav(part)
        if part:FindFirstChild("BodyForce") then return end
        local temp = Instance.new("BodyForce")
        temp.Force = part:GetMass() * Vector3.new(0, workspace.Gravity, 0)
        temp.Parent = part
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Part") and not v.Anchored then
            if not (LocalPlayer.Character and v:IsDescendantOf(LocalPlayer.Character)) then
                pcall(zeroGrav, v)
            end
        end
    end
    workspace.DescendantAdded:Connect(function(part)
        if part:IsA("Part") and not part.Anchored then
            if not (LocalPlayer.Character and part:IsDescendantOf(LocalPlayer.Character)) then
                pcall(zeroGrav, part)
            end
        end
    end)
end

local BringBricksConn = nil

local function startBringBricks()
    if BringBricksConn then return end
    local Folder = Instance.new("Folder", workspace)
    local Part = Instance.new("Part", Folder)
    local Attachment1 = Instance.new("Attachment", Part)
    Part.Anchored = true
    Part.CanCollide = false
    Part.Transparency = 1

    local Updated = Mouse.Hit + Vector3.new(0, 5, 0)

    task.spawn(function()
        pcall(function() settings().Physics.AllowSleep = false end)
        while BringBricksConn do
            RunService.RenderStepped:Wait()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    pcall(function()
                        p.MaximumSimulationRadius = 0
                        sethiddenproperty(p, "SimulationRadius", 0)
                    end)
                end
            end
            pcall(function()
                LocalPlayer.MaximumSimulationRadius = math.huge
                setsimulationradius(math.huge)
            end)
        end
    end)

    local function ForcePart(v)
        if v:IsA("Part") and not v.Anchored
            and (not v.Parent or (not v.Parent:FindFirstChild("Humanoid") and not v.Parent:FindFirstChild("Head")))
            and v.Name ~= "Handle" then
            Mouse.TargetFilter = v
            for _, x in next, v:GetChildren() do
                if x:IsA("BodyAngularVelocity") or x:IsA("BodyForce") or x:IsA("BodyGyro")
                    or x:IsA("BodyPosition") or x:IsA("BodyThrust") or x:IsA("BodyVelocity")
                    or x:IsA("RocketPropulsion") then
                    x:Destroy()
                end
            end
            local att = v:FindFirstChild("Attachment"); if att then att:Destroy() end
            local ap = v:FindFirstChild("AlignPosition"); if ap then ap:Destroy() end
            local tq = v:FindFirstChild("Torque"); if tq then tq:Destroy() end
            v.CanCollide = false
            local Torque = Instance.new("Torque", v)
            Torque.Torque = Vector3.new(100000, 100000, 100000)
            local AlignPosition = Instance.new("AlignPosition", v)
            local Attachment2 = Instance.new("Attachment", v)
            Torque.Attachment0 = Attachment2
            AlignPosition.MaxForce = 9999999999999999
            AlignPosition.MaxVelocity = math.huge
            AlignPosition.Responsiveness = 200
            AlignPosition.Attachment0 = Attachment2
            AlignPosition.Attachment1 = Attachment1
        end
    end

    for _, v in next, workspace:GetDescendants() do ForcePart(v) end
    workspace.DescendantAdded:Connect(ForcePart)

    UIS.InputBegan:Connect(function(key, chat)
        if not chat and key.KeyCode == Enum.KeyCode.E then
            Updated = Mouse.Hit + Vector3.new(0, 5, 0)
        end
    end)

    task.spawn(function()
        while BringBricksConn do
            RunService.RenderStepped:Wait()
            Attachment1.WorldCFrame = Updated
        end
    end)

    BringBricksConn = true
end

local function stopBringBricks() BringBricksConn = nil end

local BrickSpamToggle = false

local function brickSpam()
    task.spawn(function()
        while BrickSpamToggle do
            local char = LocalPlayer.Character
            local backpack = LocalPlayer.Backpack
            if char and backpack then
                for _, v in ipairs(backpack:GetChildren()) do
                    if not BrickSpamToggle then break end
                    pcall(function()
                        char.Humanoid:EquipTool(v)
                        local handle = v:FindFirstChild("Handle")
                        local mesh = handle and handle:FindFirstChild("Mesh")
                        if mesh then mesh:Destroy() end
                        v.Parent = workspace
                    end)
                end
            end
            task.wait()
        end
    end)
end

local function toolKillPlayer(targetName)
    if not targetName or targetName == "" then return end
    task.spawn(function()
        local target = Players:FindFirstChild(targetName)
        if not target or not target.Character then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetHrp then return end
        local oldPos = hrp.Position

        hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 5.5)
        task.wait()
        invokeRemote("Tools", "PickingTools", "Stretcher")
        task.wait()
        local backpack = LocalPlayer.Backpack
        if backpack and backpack:FindFirstChild("Stretcher") then
            hum:EquipTool(backpack.Stretcher)
        end
        task.wait(3)
        hum:UnequipTools()
        task.wait(0.1)
        hrp.CFrame = CFrame.new(-13612, 444, -2855)
        task.wait(1)
        if backpack and backpack:FindFirstChild("Stretcher") then
            hum:EquipTool(backpack.Stretcher)
        end
        task.wait(0.1)
        invokeRemote("Tools", "PickingTools", "Stretcher")
        task.wait(0.2)
        hrp.CFrame = CFrame.new(oldPos)
    end)
end

local function toolBringPlayer(targetName)
    if not targetName or targetName == "" then return end
    task.spawn(function()
        local target = Players:FindFirstChild(targetName)
        if not target or not target.Character then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetHrp then return end
        local oldPos = hrp.Position

        hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 5.5)
        task.wait()
        invokeRemote("Tools", "PickingTools", "Stretcher")
        task.wait()
        local backpack = LocalPlayer.Backpack
        if backpack and backpack:FindFirstChild("Stretcher") then
            hum:EquipTool(backpack.Stretcher)
        end
        task.wait(3)
        hum:UnequipTools()
        task.wait(0.1)
        hrp.CFrame = CFrame.new(oldPos)
        task.wait(0.1)
        if backpack and backpack:FindFirstChild("Stretcher") then
            hum:EquipTool(backpack.Stretcher)
        end
        task.wait(0.3)
        hum:UnequipTools()
    end)
end

local function gunPlaySong(soundId)
    if not soundId or soundId == "" then return end
    task.spawn(function()
        invokeRemote("Tools", "PickingTools", "Sniper")
        task.wait(0.1)
        local char = LocalPlayer.Character
        local backpack = LocalPlayer.Backpack
        if not char or not backpack then return end
        if backpack:FindFirstChild("Sniper") then
            char.Humanoid:EquipTool(backpack.Sniper)
        end
        task.wait(0.1)
        local handle = char:FindFirstChild("Sniper")
            and char.Sniper:FindFirstChild("Handle")
        if handle then
            local gunSounds = RS:FindFirstChild("GunSounds")
            if gunSounds then
                pcall(function() gunSounds:FireServer(handle, soundId, 1) end)
            end
        end
    end)
end

local function housePlaySong(soundId)
    if not soundId or soundId == "" then return end
    fireRemote("PlayersHouse", "PickingHouseMusicText", soundId)
end

local LoopJumpAll = false
local LoopTeleport = false

local function jumpPlayer(name)
    local target = Players:FindFirstChild(name)
    if not target then return end
    fireRemote("PlayerTriggerEvent", "DropButtonStopAll", target)
end

local function jumpAll()
    for _, p in ipairs(Players:GetPlayers()) do
        fireRemote("PlayerTriggerEvent", "DropButtonStopAll", p)
    end
end

local function killAll()
    task.spawn(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
            LocalPlayer.Character.Head:Destroy()
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                fireRemote("PlayerTriggerEvent", "Client2Client", "Request: Piggyback!", p)
                fireRemote("PlayerTriggerEvent", "BothWantPiggyBackRide", p)
            end
        end
    end)
end

local function killPlayer(name)
    local target = Players:FindFirstChild(name)
    if not target then return end
    task.spawn(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
            LocalPlayer.Character.Head:Destroy()
        end
        fireRemote("PlayerTriggerEvent", "Client2Client", "Request: Piggyback!", LocalPlayer)
        fireRemote("PlayerTriggerEvent", "BothWantPiggyBackRide", target)
    end)
end

local function freezePlayer(name)
    local target = Players:FindFirstChild(name)
    if not target then return end
    task.spawn(function()
        fireRemote("PlayerTriggerEvent", "Client2Client", "Request: Piggyback!", LocalPlayer)
        task.wait()
        for _ = 1, 2 do
            fireRemote("PlayerTriggerEvent", "BothWantPiggyBackRide", target)
            task.wait()
        end
        fireRemote("PlayerTriggerEvent", "DropButtonStopAll", target)
        task.wait()
        fireRemote("PlayerTriggerEvent", "BothWantPiggyBackRide", LocalPlayer)
        task.wait()
        fireRemote("PlayerTriggerEvent", "DropButtonStopAll", LocalPlayer)
        task.wait(0.1)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.Anchored = true
        end
    end)
end

local function skydivePlayer(name)
    local target = Players:FindFirstChild(name)
    if not target then return end
    task.spawn(function()
        fireRemote("PlayerTriggerEvent", "Client2Client", "Request: Carry!", LocalPlayer)
        task.wait()
        for _ = 1, 2 do
            fireRemote("PlayerTriggerEvent", "BothWantCarryHurt", target)
            task.wait()
        end
        fireRemote("PlayerTriggerEvent", "DropButtonStopAll", target)
        task.wait()
        fireRemote("PlayerTriggerEvent", "BothWantCarryHurt", LocalPlayer)
        task.wait()
        fireRemote("PlayerTriggerEvent", "DropButtonStopAll", LocalPlayer)
        task.wait(0.1)
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = true
            task.wait(0.025)
            hrp.Anchored = false
            task.wait(0.1)
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum:Destroy() end
            task.wait(0.1)
            if char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, 20000, 0)
            end
        end
    end)
end

local function bringPlayer(name)
    local target = Players:FindFirstChild(name)
    if not target then return end
    task.spawn(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local oldPos = hrp.Position
        fireRemote("PlayerTriggerEvent", "Client2Client", "Request: Carry!", LocalPlayer)
        task.wait()
        for _ = 1, 2 do
            fireRemote("PlayerTriggerEvent", "BothWantCarryHurt", target)
            task.wait()
        end
        fireRemote("PlayerTriggerEvent", "DropButtonStopAll", target)
        task.wait()
        fireRemote("PlayerTriggerEvent", "BothWantCarryHurt", LocalPlayer)
        task.wait()
        fireRemote("PlayerTriggerEvent", "DropButtonStopAll", LocalPlayer)
        task.wait(0.1)
        hrp.Anchored = true
        task.wait(0.05)
        hrp.Anchored = false
        task.wait(0.1)
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum:Destroy() end
        task.wait(0.1)
        if char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(oldPos)
        end
    end)
end

local function startRainbow(remoteName, toggleFn)
    task.spawn(function()
        local colors = {
            Color3.new(1, 0, 0.053),
            Color3.new(1, 0, 0.724),
            Color3.new(0.529, 0, 1),
            Color3.new(0, 0.192, 1),
            Color3.new(0.069, 1, 0.953),
            Color3.new(0, 1, 0.189),
            Color3.new(1, 0.969, 0.064),
        }
        while toggleFn() do
            for _, c in ipairs(colors) do
                if not toggleFn() then break end
                local suffix = remoteName == "PlayersHouse" and "HouseColor" or "CarColor"
                fireRemote(remoteName, "Picking" .. suffix, c)
                task.wait(0.1)
            end
        end
    end)
end

local CAR_LIST = {
    "Scooter","NPHarleyDavison","Cadillac","CopChallenger","Challenger",
    "Bus","Jeep","FireTruck","CopUnderCoverSUV","GolfCart","Van",
    "FordGT","CopSUV","RV","FoodTruck","Ambulance",
    "QuadStock","Horse","SmartCar",
}

local TOOL_LIST = {
    "Iphone","Camcorder","BabyBoy","BabyGirl","Wagon","Sign","Syringe","Ear",
    "Trophy","Taser","SWATShield","Cuffs","Glock","Shotgun","Assault","Sniper",
    "Bomb","DuffleBagMoney","Money","CreditCardBoy","CreditCardGirl","Umbrella",
    "Roses","Present","SoccerBall","Apple","Chips","Bloxaide","Milk",
}

local GIVE_TO_ALL = {
    { name = "Money Bag",       id = "4535110571", tool = "Money" },
    { name = "Big Money Bag",   id = "4587924680", tool = "DuffleBagMoney" },
    { name = "Coca Cola",       id = "4548052009", tool = "Coke" },
    { name = "Stroller",        id = "4529218345", tool = "Stroller" },
    { name = "Hairbrush",       id = "5480682123", tool = "Hairbrush" },
    { name = "Sign",            id = "6001822792", tool = "Sign" },
    { name = "Rose",            id = "5211788490", tool = "Roses" },
    { name = "Soccer Ball",     id = "4598172149", tool = "SoccerBall" },
    { name = "Gun",             id = "4529288610", tool = "Assault" },
    { name = "C4",              id = "4587924290", tool = "Bomb" },
    { name = "Shovel",          id = "4617189079", tool = "Shovel" },
}

local TAG_LIST = {
    { name = "Admin Tag 1",         id = "782790468" },
    { name = "Admin Tag 2",         id = "105095367" },
    { name = "Normal VIP",          id = "1292335373" },
    { name = "Mega VIP",            id = "1255544221" },
    { name = "Ultra VIP",           id = "1292342698" },
    { name = "VIP",                 id = "32578003" },
    { name = "Moderator",           id = "415986666" },
    { name = "Owner",               id = "2980546857" },
    { name = "Creator",             id = "2497143214" },
    { name = "Brookhaven Logo",     id = "6336646536" },
    { name = "Pikachu",             id = "1473416194" },
    { name = "Hacker Face",         id = "3284478282" },
    { name = "Scary Pikachu",       id = "127039538" },
    { name = "HD",                  id = "2821573888" },
    { name = "Old Roblox Logo",     id = "148012526" },
    { name = "Roblox Admin Logo",   id = "1151106808" },
    { name = "Diamond",             id = "4424298" },
    { name = "Hacking",             id = "626372353" },
    { name = "Nascar Car",          id = "463277467" },
    { name = "Girl Face",           id = "555878469" },
    { name = "Wall",                id = "1844422643" },
    { name = "Meme",                id = "261677904" },
    { name = "Coffee Meme",         id = "261676710" },
    { name = "Scary Face",          id = "1243374078" },
    { name = "2 Eye",               id = "5839301773" },
    { name = "Scary",               id = "2120834873" },
    { name = "Smiley Face",         id = "333476199" },
    { name = "Scary Dog",           id = "5817435822" },
    { name = "Scary Cat",           id = "23355113" },
}

local IMG = "rbxassetid://111672166073808"

local windows = redzlib:MakeWindow({
    Title = "Universe Hub",
    SubTitle = "Brookhaven",
    SaveFolder = "Universe Hub\\" .. LocalPlayer.Name,
})

local HomeTab = windows:MakeTab({ Title = "Home", Icon = "home" })
HomeTab:AddSection("Welcome To Universe Hub | Brookhaven")
HomeTab:AddSection("Discord Server")
HomeTab:AddDiscordInvite({
    Title = "Universe Hub",
    Desc = "Join our Discord community for updates and support!",
    Logo = IMG,
    Invite = "https://discord.gg/HkB97N772p",
})

local FunTab = windows:MakeTab({ Title = "Fun", Icon = "zap" })
FunTab:AddSection("Lag")

FunTab:AddToggle({
    Title = "Lag Server [RISKY]",
    Description = "Spams all car remotes - will lag the whole game",
    Default = false, Flag = "bh_lag",
    Callback = function(state)
        if state then
            startLagServer()
            notify("Lag", "ON — cuidado com kick", 2, "Warning")
        else
            stopLagServer()
            notify("Lag", "OFF", 2, "Info")
        end
    end,
})

FunTab:AddSection("Physics")
FunTab:AddButton({
    Title = "Zero Gravity (unanchored parts)",
    Description = "Removes gravity from all loose parts in the map",
    Callback = function()
        zeroGravityUnanchored()
        notify("Zero G", "Applied to unanchored parts", 2, "Success")
    end,
})

FunTab:AddToggle({
    Title = "Bring Unanchored Bricks [E]",
    Description = "Drags all loose parts to your cursor. Press E to reposition",
    Default = false, Flag = "bh_bricks",
    Callback = function(state)
        if state then
            startBringBricks()
            notify("Bring Bricks", "Hold E to move", 3, "Success")
        else
            stopBringBricks()
            notify("Bring Bricks", "OFF", 2, "Info")
        end
    end,
})

FunTab:AddSection("Tool Fun")
FunTab:AddToggle({
    Title = "Brick Spam [RISKY]",
    Description = "Drops all tools from backpack to the ground continuously",
    Default = false, Flag = "bh_brickspam",
    Callback = function(state)
        BrickSpamToggle = state
        if state then brickSpam() end
    end,
})

FunTab:AddButton({
    Title = "Spawn Taser Spam [RISKY]",
    Description = "Continuously spam-spawns Taser",
    Callback = function()
        task.spawn(function()
            for _ = 1, 50 do
                invokeRemote("Tools", "PickingTools", "Taser")
                task.wait(0.05)
            end
            notify("Taser Spam", "Sent 50 requests", 2, "Info")
        end)
    end,
})

local ToolsTab = windows:MakeTab({ Title = "Tools", Icon = "wrench" })

ToolsTab:AddSection("Player Actions (via Stretcher)")
ToolsTab:AddTextBox({
    Title = "Target Name", PlaceholderText = "Player username",
    Default = "", Flag = "bh_tool_target",
    Callback = function(t) getgenv().bh_tool_target = t end,
})
ToolsTab:AddButton({
    Title = "Tool Kill Player [RISKY]",
    Description = "Kills target using stretcher exploit",
    Callback = function()
        local t = getgenv().bh_tool_target
        if not t or t == "" then
            notify("Tool Kill", "Insert a target name", 2, "Warning")
            return
        end
        toolKillPlayer(t)
        notify("Tool Kill", "Executing on " .. t, 3, "Warning")
    end,
})
ToolsTab:AddButton({
    Title = "Tool Bring Player",
    Description = "Brings target to your position",
    Callback = function()
        local t = getgenv().bh_tool_target
        if not t or t == "" then
            notify("Tool Bring", "Insert a target name", 2, "Warning")
            return
        end
        toolBringPlayer(t)
        notify("Tool Bring", "Executing on " .. t, 3, "Info")
    end,
})

ToolsTab:AddSection("Music (global)")
ToolsTab:AddTextBox({
    Title = "Gun Song ID", PlaceholderText = "Roblox sound ID",
    Default = "", Flag = "bh_gunsong",
    Callback = function(t) getgenv().bh_gunsong = t end,
})
ToolsTab:AddButton({
    Title = "Play via Sniper",
    Description = "Plays the song through sniper gun sounds",
    Callback = function()
        local s = getgenv().bh_gunsong
        if not s or s == "" then
            notify("Gun Song", "Insert a sound ID", 2, "Warning")
            return
        end
        gunPlaySong(s)
        notify("Gun Song", "Playing!", 2, "Success")
    end,
})
ToolsTab:AddTextBox({
    Title = "House Song ID", PlaceholderText = "Roblox sound ID",
    Default = "", Flag = "bh_housesong",
    Callback = function(t) getgenv().bh_housesong = t end,
})
ToolsTab:AddButton({
    Title = "Play via House",
    Description = "Plays music through your house speaker",
    Callback = function()
        local s = getgenv().bh_housesong
        if not s or s == "" then
            notify("House Song", "Insert a sound ID", 2, "Warning")
            return
        end
        housePlaySong(s)
        notify("House Song", "Playing!", 2, "Success")
    end,
})

local AdminTab = windows:MakeTab({ Title = "Admin", Icon = "shield" })

AdminTab:AddSection("Jump")
AdminTab:AddButton({
    Title = "Jump All",
    Description = "Force everyone to jump once",
    Callback = function() jumpAll(); notify("Jump All", "Sent", 2, "Info") end,
})
AdminTab:AddToggle({
    Title = "Loop Jump All",
    Description = "Everyone jumps non-stop",
    Default = false, Flag = "bh_loopjump",
    Callback = function(state)
        LoopJumpAll = state
        if state then
            task.spawn(function()
                while LoopJumpAll do
                    jumpAll()
                    task.wait(0.15)
                end
            end)
        end
    end,
})
AdminTab:AddTextBox({
    Title = "Jump Target", PlaceholderText = "Player name",
    Default = "", Flag = "bh_jumptarget",
    Callback = function(t) getgenv().bh_jumptarget = t end,
})
AdminTab:AddButton({
    Title = "Jump Player",
    Callback = function()
        local t = getgenv().bh_jumptarget
        if t and t ~= "" then
            jumpPlayer(t)
            notify("Jump", "Sent to " .. t, 2, "Info")
        end
    end,
})
AdminTab:AddButton({
    Title = "Mega Jump Player",
    Callback = function()
        local t = getgenv().bh_jumptarget
        if not t or t == "" then return end
        for _ = 1, 5 do
            jumpPlayer(t)
            task.wait(0.1)
        end
        notify("Mega Jump", "Sent to " .. t, 2, "Info")
    end,
})

AdminTab:AddSection("Kill / Freeze [VERY RISKY]")
AdminTab:AddButton({
    Title = "Kill All [VERY RISKY]",
    Description = "Mass kill exploit — will get you reported",
    Callback = function() killAll(); notify("Kill All", "Executed", 3, "Error") end,
})
AdminTab:AddTextBox({
    Title = "Kill Target", PlaceholderText = "Player name",
    Default = "", Flag = "bh_killtarget",
    Callback = function(t) getgenv().bh_killtarget = t end,
})
AdminTab:AddButton({
    Title = "Kill Any Player [RISKY]",
    Callback = function()
        local t = getgenv().bh_killtarget
        if t and t ~= "" then
            killPlayer(t)
            notify("Kill", "Executed on " .. t, 3, "Warning")
        end
    end,
})
AdminTab:AddButton({
    Title = "Freeze Player [RISKY]",
    Callback = function()
        local t = getgenv().bh_killtarget
        if t and t ~= "" then
            freezePlayer(t)
            notify("Freeze", "Executed on " .. t, 3, "Warning")
        end
    end,
})
AdminTab:AddButton({
    Title = "Skydive Player [RISKY]",
    Callback = function()
        local t = getgenv().bh_killtarget
        if t and t ~= "" then
            skydivePlayer(t)
            notify("Skydive", "Executed on " .. t, 3, "Warning")
        end
    end,
})
AdminTab:AddButton({
    Title = "Bring Player [RISKY]",
    Callback = function()
        local t = getgenv().bh_killtarget
        if t and t ~= "" then
            bringPlayer(t)
            notify("Bring", "Executed on " .. t, 3, "Warning")
        end
    end,
})

AdminTab:AddSection("Rainbow")
AdminTab:AddToggle({
    Title = "Rainbow House",
    Default = false, Flag = "bh_rainbowh",
    Callback = function(state)
        getgenv().bh_rainbowh = state
        if state then startRainbow("PlayersHouse", function() return getgenv().bh_rainbowh end) end
    end,
})
AdminTab:AddToggle({
    Title = "Rainbow Car",
    Default = false, Flag = "bh_rainbowc",
    Callback = function(state)
        getgenv().bh_rainbowc = state
        if state then startRainbow("PlayersCar", function() return getgenv().bh_rainbowc end) end
    end,
})

local LPTab = windows:MakeTab({ Title = "Local Player", Icon = "user" })
LPTab:AddSection("Movement")

LPTab:AddSlider({
    Title = "Walkspeed", Min = 16, Max = 120, Default = 16, Flag = "bh_ws",
    Callback = function(v)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})
LPTab:AddSlider({
    Title = "JumpPower", Min = 50, Max = 300, Default = 50, Flag = "bh_jp",
    Callback = function(v)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v end
    end,
})

LPTab:AddSection("Misc")
LPTab:AddToggle({
    Title = "Noclip",
    Description = "Walk through walls (E key also toggles)",
    Default = false, Flag = "bh_noclip",
    Callback = function(state)
        getgenv().bh_noclip = state
        if state then
            task.spawn(function()
                while getgenv().bh_noclip do
                    RunService.Stepped:Wait()
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Physics) end
                end
            end)
        end
    end,
})
LPTab:AddButton({
    Title = "Reset Character",
    Callback = function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:Destroy() end
    end,
})
LPTab:AddButton({
    Title = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end,
})
LPTab:AddButton({
    Title = "FE Clown Head",
    Description = "Server-side clown head",
    Callback = function()
        fireRemote("UpdateAvatar", "wear", 4272833564)
        notify("Avatar", "Clown head equipped", 2, "Success")
    end,
})

local VehTab = windows:MakeTab({ Title = "Vehicles", Icon = "car" })
VehTab:AddSection("Spawn Car")

for _, carName in ipairs(CAR_LIST) do
    VehTab:AddButton({
        Title = carName,
        Callback = function() fireRemote("Car", "PickingCar", carName) end,
    })
end

local GiveTab = windows:MakeTab({ Title = "Give", Icon = "gift" })

GiveTab:AddSection("Give To Yourself")
GiveTab:AddDropdown({
    Title = "Select Tool",
    Description = "Gives you the tool directly",
    Options = TOOL_LIST,
    Default = TOOL_LIST[1], Flag = "bh_give_self",
    Callback = function(value)
        local v = (typeof(value) == "table" and value[1]) or value
        invokeRemote("Tools", "PickingTools", v)
        notify("Give Tool", "Given: " .. v, 2, "Success")
    end,
})

GiveTab:AddSection("Give To ALL [VERY RISKY]")
GiveTab:AddParagraph({
    Title = "Aviso",
    Text = "Dar tool pra todo mundo = report na certa. Use só em servidor vazio ou com amigos.",
})
for _, item in ipairs(GIVE_TO_ALL) do
    GiveTab:AddButton({
        Title = "Give " .. item.name .. " [ALL]",
        Callback = function()
            for _, p in ipairs(Players:GetPlayers()) do
                fireRemote("PlayerTriggerEvent", "ToolGiveToServer",
                    p, "http://www.roblox.com/asset/?id=" .. item.id, item.tool)
            end
            notify("Give All", item.name .. " sent", 2, "Warning")
        end,
    })
end

local TagTab = windows:MakeTab({ Title = "Tags", Icon = "star" })
TagTab:AddSection("Server-Side Tags")

for _, tag in ipairs(TAG_LIST) do
    TagTab:AddButton({
        Title = tag.name,
        Callback = function()
            fireRemote("Jobs", "GiveJobUIMenu", tag.id, "Universe Hub", true)
        end,
    })
end

TagTab:AddSection("Custom")
TagTab:AddTextBox({
    Title = "Custom Image ID",
    PlaceholderText = "Roblox asset ID",
    Default = "", Flag = "bh_custom_tag",
    Callback = function(t) getgenv().bh_custom_tag = t end,
})
TagTab:AddButton({
    Title = "Apply Custom Tag",
    Callback = function()
        local id = getgenv().bh_custom_tag
        if id and id ~= "" then
            fireRemote("Jobs", "GiveJobUIMenu", id, "Universe Hub", true)
            notify("Tag", "Custom tag applied", 2, "Success")
        end
    end,
})

notify("Universe Hub", IMG, "Brookhaven loaded", 3, "Success")

return redzlib