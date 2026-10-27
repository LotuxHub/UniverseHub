-- ===============================================================
--   Universe Hub  |  Steal An Egg  |  Auto-Farm Script
--   Auto Steal · Auto Hatch · Anti-AFK · ESP
-- ===============================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace      = workspace
local LocalPlayer    = Players.LocalPlayer
local Character      = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid       = Character:WaitForChild("Humanoid")

-- ─── State ────────────────────────────────────────────────────
local _G.UniverseSAE = _G.UniverseSAE or {
    AutoSteal  = false,
    AutoHatch  = false,
    AntiAFK    = false,
    EggESP     = false,
    StealDelay = 0.15,
    HatchDelay = 0.20,
}
local cfg = _G.UniverseSAE
local connections = {}

-- ─── Helpers ──────────────────────────────────────────────────
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
    local root = getRoot()
    if root then root.CFrame = CFrame.new(pos) end
end

local function fireRemote(name, ...)
    local rem = ReplicatedStorage:FindFirstChild(name, true)
        or Workspace:FindFirstChild(name, true)
    if rem and rem:IsA("RemoteEvent") then
        rem:FireServer(...)
    elseif rem and rem:IsA("RemoteFunction") then
        rem:InvokeServer(...)
    end
end

-- ─── Auto Steal ───────────────────────────────────────────────
local function startAutoSteal()
    connections.steal = RunService.Heartbeat:Connect(function()
        if not cfg.AutoSteal then return end
        -- Find egg models in workspace
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:lower():find("egg") or obj.Name:lower():find("ovo")) then
                local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if primary then
                    local dist = (getRoot().Position - primary.Position).Magnitude
                    if dist < 50 then
                        tpTo(primary.Position + Vector3.new(0, 3, 0))
                        task.wait(cfg.StealDelay)
                        -- Try common steal remotes
                        fireRemote("StealEgg", obj)
                        fireRemote("Steal", obj)
                        fireRemote("CollectEgg", obj)
                        fireRemote("PickupEgg", obj)
                        -- Proximity prompt fallback
                        for _, pp in ipairs(obj:GetDescendants()) do
                            if pp:IsA("ProximityPrompt") then
                                pcall(function() fireproximityprompt(pp) end)
                            end
                        end
                    end
                end
            end
        end
        task.wait(cfg.StealDelay)
    end)
end

-- ─── Auto Hatch ───────────────────────────────────────────────
local function startAutoHatch()
    connections.hatch = RunService.Heartbeat:Connect(function()
        if not cfg.AutoHatch then return end
        -- Find hatch spots / incubators
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local n = obj.Name:lower()
            if obj:IsA("BasePart") and (n:find("hatch") or n:find("incubat") or n:find("nest")) then
                local dist = (getRoot().Position - obj.Position).Magnitude
                if dist < 40 then
                    tpTo(obj.Position + Vector3.new(0, 3, 0))
                    task.wait(cfg.HatchDelay)
                    fireRemote("HatchEgg")
                    fireRemote("Hatch")
                    for _, pp in ipairs(obj:GetDescendants()) do
                        if pp:IsA("ProximityPrompt") then
                            pcall(function() fireproximityprompt(pp) end)
                        end
                    end
                end
            end
        end
        task.wait(cfg.HatchDelay)
    end)
end

-- ─── Anti-AFK ─────────────────────────────────────────────────
local function startAntiAFK()
    connections.afk = RunService.Heartbeat:Connect(function()
        if not cfg.AntiAFK then return end
    end)
    -- Override idle kick
    local VU = game:GetService("VirtualUser")
    connections.afkTimer = task.spawn(function()
        while task.wait(60) do
            if cfg.AntiAFK then
                VU:Button2Down(Vector2.new(0,0), CFrame.new())
                task.wait(0.1)
                VU:Button2Up(Vector2.new(0,0), CFrame.new())
            end
        end
    end)
end

-- ─── Egg ESP ──────────────────────────────────────────────────
local function refreshESP()
    -- Remove old highlights
    for _, h in ipairs(Workspace:GetDescendants()) do
        if h:IsA("Highlight") and h.Name == "UniverseESP_Egg" then
            h:Destroy()
        end
    end
    if not cfg.EggESP then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:lower():find("egg") or obj.Name:lower():find("ovo")) then
            local hl = Instance.new("Highlight")
            hl.Name = "UniverseESP_Egg"
            hl.FillColor = Color3.fromRGB(255, 220, 50)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.4
            hl.OutlineTransparency = 0
            hl.Adornee = obj
            hl.Parent = obj
        end
    end
end

local function startEggESP()
    connections.esp = RunService.Heartbeat:Connect(function()
        if cfg.EggESP then
            refreshESP()
        end
        task.wait(2)
    end)
end

-- ─── GUI ──────────────────────────────────────────────────────
local function buildGUI()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    if PlayerGui:FindFirstChild("UniverseHub_SAE") then
        PlayerGui.UniverseHub_SAE:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "UniverseHub_SAE"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = PlayerGui

    -- Main panel
    local Panel = Instance.new("Frame")
    Panel.Name = "Panel"
    Panel.Size = UDim2.new(0, 280, 0, 320)
    Panel.Position = UDim2.new(0, 20, 0.5, -160)
    Panel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    Panel.BorderSizePixel = 0
    Panel.Parent = ScreenGui
    Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 12)

    local Stroke = Instance.new("UIStroke", Panel)
    Stroke.Color = Color3.fromRGB(100, 60, 220)
    Stroke.Thickness = 1.5

    -- Header
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 44)
    Header.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
    Header.BorderSizePixel = 0
    Header.Parent = Panel
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

    local HeaderFix = Instance.new("Frame", Header)
    HeaderFix.Size = UDim2.new(1, 0, 0, 12)
    HeaderFix.Position = UDim2.new(0, 0, 1, -12)
    HeaderFix.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
    HeaderFix.BorderSizePixel = 0

    local Title = Instance.new("TextLabel", Header)
    Title.Size = UDim2.new(1, -16, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🥚  Universe Hub  •  Steal An Egg"
    Title.TextColor3 = Color3.fromRGB(220, 210, 255)
    Title.TextSize = 13
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local Divider = Instance.new("Frame", Panel)
    Divider.Size = UDim2.new(1, -24, 0, 1)
    Divider.Position = UDim2.new(0, 12, 0, 44)
    Divider.BackgroundColor3 = Color3.fromRGB(100, 60, 220)
    Divider.BackgroundTransparency = 0.6
    Divider.BorderSizePixel = 0

    -- Toggle factory
    local function makeToggle(labelText, yPos, cfgKey)
        local Row = Instance.new("Frame", Panel)
        Row.Size = UDim2.new(1, -24, 0, 40)
        Row.Position = UDim2.new(0, 12, 0, yPos)
        Row.BackgroundTransparency = 1

        local Lbl = Instance.new("TextLabel", Row)
        Lbl.Size = UDim2.new(1, -60, 1, 0)
        Lbl.BackgroundTransparency = 1
        Lbl.Text = labelText
        Lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
        Lbl.TextSize = 13
        Lbl.Font = Enum.Font.GothamSemibold
        Lbl.TextXAlignment = Enum.TextXAlignment.Left

        local Btn = Instance.new("TextButton", Row)
        Btn.Size = UDim2.new(0, 48, 0, 24)
        Btn.Position = UDim2.new(1, -48, 0.5, -12)
        Btn.BackgroundColor3 = cfg[cfgKey] and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 80)
        Btn.Text = cfg[cfgKey] and "ON" or "OFF"
        Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        Btn.TextSize = 11
        Btn.Font = Enum.Font.GothamBold
        Btn.BorderSizePixel = 0
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

        Btn.MouseButton1Click:Connect(function()
            cfg[cfgKey] = not cfg[cfgKey]
            Btn.BackgroundColor3 = cfg[cfgKey] and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 80)
            Btn.Text = cfg[cfgKey] and "ON" or "OFF"
            if cfgKey == "EggESP" and not cfg.EggESP then refreshESP() end
        end)
    end

    makeToggle("🥚  Auto Steal",  56,  "AutoSteal")
    makeToggle("🐣  Auto Hatch",  104, "AutoHatch")
    makeToggle("⏰  Anti-AFK",    152, "AntiAFK")
    makeToggle("🔍  Egg ESP",     200, "EggESP")

    -- Credits
    local Credits = Instance.new("TextLabel", Panel)
    Credits.Size = UDim2.new(1, 0, 0, 28)
    Credits.Position = UDim2.new(0, 0, 1, -28)
    Credits.BackgroundTransparency = 1
    Credits.Text = "Universe Hub  •  Steal An Egg"
    Credits.TextColor3 = Color3.fromRGB(100, 90, 140)
    Credits.TextSize = 11
    Credits.Font = Enum.Font.Gotham

    -- Drag
    local dragging, dragInput, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    Header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            Panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Animate in
    Panel.Position = UDim2.new(0, -300, 0.5, -160)
    TweenService:Create(Panel,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 20, 0.5, -160) }
    ):Play()
end

-- ─── Init ─────────────────────────────────────────────────────
buildGUI()
startAutoSteal()
startAutoHatch()
startAntiAFK()
startEggESP()

-- Respawn reconnect
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
end)

print("[Universe Hub] Steal An Egg carregado!")
