-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Camera = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local ConfigFile = "KSFB_Config.json"

local DefaultConfig = {
    AutoKillNPC         = false,
    AutoKillDelay       = 0.9,
    SimRadius           = 111,

    AutoKickEnabled     = false,
    TrustedPlayers      = {},

    WebhookBlockEnabled = false,
    WebhookDelete       = false,

    AutoCakesEnabled    = false,
    CakeFireCount       = 10000,
    CakeInterval        = 2,
    CakePromptEnabled   = false,

    AutoHakariEnabled   = false,

    ESPEnabled          = false,
    ESPNames            = true,
    ESPMaxDistance      = 1000,
    ESPBoxColor         = {r = 255, g = 50, b = 50},

    SpeedEnabled        = false,
    SpeedValue          = 16,
    JumpEnabled         = false,
    JumpValue           = 50,
    FlyEnabled          = false,
    FlySpeed            = 50,
    NoClipEnabled       = false,
    InfiniteJumpEnabled = false,

    AntiAFKEnabled      = false,

    HitboxEnabled       = false,
    HitboxSize          = 10,

    SecondaryGUIEnabled = false,
}

local Config = {}

local function LoadConfig()
    if isfile(ConfigFile) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFile))
        end)
        if ok and type(data) == "table" then
            for k, v in pairs(DefaultConfig) do
                if data[k] == nil then data[k] = v end
            end
            Config = data
        else
            Config = table.clone(DefaultConfig)
        end
    else
        Config = table.clone(DefaultConfig)
    end
end

local function SaveConfig()
    pcall(function()
        writefile(ConfigFile, HttpService:JSONEncode(Config))
    end)
end

LoadConfig()

-- ============================================================
-- STATE
-- ============================================================
local State = {
    AutoKillRunning       = false,
    AutoKickRunning       = false,
    AutoCakesRunning      = false,
    AutoHakariRunning     = false,
    HakariMainLoopRunning = false,
    WebhookHooked         = false,
    CakePromptLoopRunning = false,
    ESPRunning            = false,
    FlyRunning            = false,
    NoClipRunning         = false,
    AntiAFKRunning        = false,
    HitboxRunning         = false,
    SecondaryGUIRunning   = false,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function GetCharacter() return LocalPlayer.Character end

local function GetHumanoid()
    local c = GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetPlayerDistance(player)
    local myRoot = GetRootPart()
    local tc = player.Character
    if not myRoot or not tc then return math.huge end
    local tr = tc:FindFirstChild("HumanoidRootPart")
    if not tr then return math.huge end
    return (myRoot.Position - tr.Position).Magnitude
end

local function ApplySpeed()
    local h = GetHumanoid()
    if h then
        h.WalkSpeed = Config.SpeedEnabled and Config.SpeedValue or 16
    end
end

local function ApplyJump()
    local h = GetHumanoid()
    if h then
        h.JumpPower  = Config.JumpEnabled and Config.JumpValue or 50
        h.JumpHeight = Config.JumpEnabled and (Config.JumpValue * 0.04) or 2.0
    end
end

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name                  = "KSFB Hub",
    LoadingTitle          = "KSFB Hub",
    LoadingSubtitle       = "by KSFB",
    Theme                 = "Default",
    DisableRayfieldPrompts  = false,
    DisableBuildWarnings  = false,
    ConfigurationSaving   = { Enabled = false },
    Discord               = { Enabled = false },
    KeySystem             = false,
})

-- ============================================================
-- TABS
-- ============================================================
local TabKill    = Window:CreateTab("Kill NPC",  4483362458)
local TabKick    = Window:CreateTab("Auto Kick", 4483362458)
local TabESP     = Window:CreateTab("ESP",       4483362458)
local TabPlayer  = Window:CreateTab("Player",    4483362458)
local TabCombat  = Window:CreateTab("Combat",    4483362458)
local TabEvents  = Window:CreateTab("Events",    4483362458)
local TabWebhook = Window:CreateTab("Webhook",   4483362458)
local TabUtils   = Window:CreateTab("Utils",     4483362458)

-- ============================================================
-- KILL NPC
-- ============================================================
do
    TabKill:CreateSection("Auto Kill NPC")

    TabKill:CreateToggle({
        Name         = "Enable Auto Kill NPC",
        CurrentValue = Config.AutoKillNPC,
        Flag         = "AutoKillNPC",
        Callback     = function(val)
            Config.AutoKillNPC    = val
            State.AutoKillRunning = val
            SaveConfig()
            if val then
                getgenv().G = true
                task.spawn(function()
                    while State.AutoKillRunning and getgenv().G do
                        task.wait(Config.AutoKillDelay)
                        pcall(function()
                            sethiddenproperty(LocalPlayer, "SimulationRadius",    Config.SimRadius)
                            sethiddenproperty(LocalPlayer, "MaxSimulationRadius", Config.SimRadius)
                        end)
                        for _, d in pairs(Workspace:GetDescendants()) do
                            if d.ClassName == "Humanoid"
                            and d.Parent
                            and d.Parent.Name ~= LocalPlayer.Name then
                                pcall(function() d.Health = 0 end)
                            end
                        end
                    end
                end)
            else
                getgenv().G = false
            end
        end,
    })

    TabKill:CreateSlider({
        Name         = "Kill Delay (s)",
        Range        = {0.1, 5},
        Increment    = 0.1,
        Suffix       = "s",
        CurrentValue = Config.AutoKillDelay,
        Flag         = "AutoKillDelay",
        Callback     = function(val) Config.AutoKillDelay = val SaveConfig() end,
    })

    TabKill:CreateSlider({
        Name         = "Simulation Radius",
        Range        = {1, 1000},
        Increment    = 1,
        CurrentValue = Config.SimRadius,
        Flag         = "SimRadius",
        Callback     = function(val) Config.SimRadius = val SaveConfig() end,
    })

    TabKill:CreateSection("Kill Players")

    TabKill:CreateButton({
        Name     = "Kill All Players",
        Callback = function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    pcall(function()
                        local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                        if h then h.Health = 0 end
                    end)
                end
            end
            Rayfield:Notify({ Title = "Kill All", Content = "Attempted to kill all players.", Duration = 3 })
        end,
    })

    TabKill:CreateInput({
        Name                     = "Kill Specific Player",
        PlaceholderText          = "Enter player name",
        RemoveTextAfterFocusLost = true,
        Callback                 = function(text)
            if text == "" then return end
            local target = Players:FindFirstChild(text)
            if target and target.Character then
                local h = target.Character:FindFirstChildOfClass("Humanoid")
                if h then
                    h.Health = 0
                    Rayfield:Notify({ Title = "Killed", Content = text, Duration = 3 })
                    return
                end
            end
            Rayfield:Notify({ Title = "Not Found", Content = text, Duration = 3 })
        end,
    })
end

-- ============================================================
-- AUTO KICK
-- ============================================================
do
    local TrustedSet = {}
    TrustedSet[LocalPlayer.Name] = true
    for _, name in ipairs(Config.TrustedPlayers or {}) do
        TrustedSet[name] = true
    end

    local KickConn        = nil
    local TrustedDropdown = nil

    local function BuildPlayerOptions()
        local opts = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(opts, p.Name)
            end
        end
        if #opts == 0 then table.insert(opts, "(No players)") end
        return opts
    end

    local function UpdatePlayerList()
        if TrustedDropdown then
            TrustedDropdown:Set(BuildPlayerOptions())
        end
    end

    local function StartAutoKick()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and not TrustedSet[p.Name] then
                LocalPlayer:Kick("Untrusted player: " .. p.Name)
                return
            end
        end
        KickConn = Players.PlayerAdded:Connect(function(p)
            if not State.AutoKickRunning then return end
            if p == LocalPlayer then return end
            if not TrustedSet[p.Name] then
                LocalPlayer:Kick("Untrusted player joined: " .. p.Name)
            end
        end)
    end

    local function StopAutoKick()
        if KickConn then KickConn:Disconnect() KickConn = nil end
    end

    TabKick:CreateSection("Auto Kick")

    TabKick:CreateToggle({
        Name         = "Enable Auto Kick",
        CurrentValue = Config.AutoKickEnabled,
        Flag         = "AutoKickEnabled",
        Callback     = function(val)
            Config.AutoKickEnabled = val
            State.AutoKickRunning  = val
            SaveConfig()
            if val then StartAutoKick() else StopAutoKick() end
        end,
    })

    TabKick:CreateSection("Trusted Players")
    TabKick:CreateLabel("Selected players will not trigger kick.")

    TrustedDropdown = TabKick:CreateDropdown({
        Name            = "Select Trusted Players",
        Options         = BuildPlayerOptions(),
        CurrentOption   = Config.TrustedPlayers,
        MultipleOptions = true,
        Flag            = "TrustedDropdown",
        Callback        = function(selected)
            Config.TrustedPlayers = {}
            for k in pairs(TrustedSet) do
                if k ~= LocalPlayer.Name then TrustedSet[k] = nil end
            end
            for _, name in ipairs(selected) do
                if name ~= "(No players)" then
                    TrustedSet[name] = true
                    table.insert(Config.TrustedPlayers, name)
                end
            end
            SaveConfig()
            Rayfield:Notify({
                Title   = "Trusted Updated",
                Content = #Config.TrustedPlayers .. " players trusted.",
                Duration = 2,
            })
        end,
    })

    TabKick:CreateButton({
        Name     = "Clear Trusted List",
        Callback = function()
            Config.TrustedPlayers = {}
            for k in pairs(TrustedSet) do
                if k ~= LocalPlayer.Name then TrustedSet[k] = nil end
            end
            SaveConfig()
            Rayfield:Notify({ Title = "Cleared", Content = "Trusted list cleared.", Duration = 3 })
        end,
    })

    Players.PlayerAdded:Connect(UpdatePlayerList)
    Players.PlayerRemoving:Connect(UpdatePlayerList)
end

-- ============================================================
-- ESP
-- ============================================================
do
    local ESPData = {}

    local function NewLine()
        local l = Drawing.new("Line")
        l.Thickness = 1.5
        l.Color     = Color3.fromRGB(255, 50, 50)
        l.Visible   = false
        l.ZIndex    = 5
        return l
    end

    local function NewText()
        local t = Drawing.new("Text")
        t.Size         = 13
        t.Center       = true
        t.Outline      = true
        t.Color        = Color3.fromRGB(255, 255, 255)
        t.OutlineColor = Color3.fromRGB(0, 0, 0)
        t.Visible      = false
        t.ZIndex       = 6
        return t
    end

    local function CreateESP(player)
        if player == LocalPlayer or ESPData[player] then return end
        ESPData[player] = {
            lines    = { NewLine(), NewLine(), NewLine(), NewLine() },
            nameText = NewText(),
        }
    end

    local function RemoveESP(player)
        local d = ESPData[player]
        if not d then return end
        for _, l in ipairs(d.lines) do l:Remove() end
        d.nameText:Remove()
        ESPData[player] = nil
    end

    local function GetBoundingBox(char)
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local cf = root.CFrame
        local sx, sy = 2.5, 5
        local pts = {
            cf * Vector3.new(-sx,  sy, 0),
            cf * Vector3.new( sx,  sy, 0),
            cf * Vector3.new(-sx, -sy, 0),
            cf * Vector3.new( sx, -sy, 0),
        }
        local minX, minY =  math.huge,  math.huge
        local maxX, maxY = -math.huge, -math.huge
        for _, v in ipairs(pts) do
            local sp, vis = Camera:WorldToViewportPoint(v)
            if not vis then return nil end
            if sp.X < minX then minX = sp.X end
            if sp.Y < minY then minY = sp.Y end
            if sp.X > maxX then maxX = sp.X end
            if sp.Y > maxY then maxY = sp.Y end
        end
        return {
            tl = Vector2.new(minX, minY),
            tr = Vector2.new(maxX, minY),
            bl = Vector2.new(minX, maxY),
            br = Vector2.new(maxX, maxY),
            cx = (minX + maxX) / 2,
            ty = minY,
        }
    end

    local function UpdateESP()
        local col = Color3.fromRGB(
            Config.ESPBoxColor.r,
            Config.ESPBoxColor.g,
            Config.ESPBoxColor.b
        )
        for player, d in pairs(ESPData) do
            local function hide()
                for _, l in ipairs(d.lines) do l.Visible = false end
                d.nameText.Visible = false
            end

            if not Config.ESPEnabled then hide() continue end

            local char = player.Character
            if not char then hide() continue end

            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then hide() continue end

            local dist = GetPlayerDistance(player)
            if dist > Config.ESPMaxDistance then hide() continue end

            local bb = GetBoundingBox(char)
            if not bb then hide() continue end

            d.lines[1].From = bb.tl d.lines[1].To = bb.tr
            d.lines[2].From = bb.bl d.lines[2].To = bb.br
            d.lines[3].From = bb.tl d.lines[3].To = bb.bl
            d.lines[4].From = bb.tr d.lines[4].To = bb.br
            for _, l in ipairs(d.lines) do l.Color = col l.Visible = true end

            if Config.ESPNames then
                d.nameText.Text     = player.Name
                d.nameText.Position = Vector2.new(bb.cx, bb.ty - 18)
                d.nameText.Visible  = true
            else
                d.nameText.Visible = false
            end
        end
    end

    local ESPConn = nil

    local function StartESP()
        for _, p in ipairs(Players:GetPlayers()) do CreateESP(p) end
        Players.PlayerAdded:Connect(function(p)
            if State.ESPRunning then CreateESP(p) end
        end)
        Players.PlayerRemoving:Connect(RemoveESP)
        ESPConn = RunService.RenderStepped:Connect(function()
            if State.ESPRunning then UpdateESP() end
        end)
    end

    local function StopESP()
        for p in pairs(ESPData) do RemoveESP(p) end
        if ESPConn then ESPConn:Disconnect() ESPConn = nil end
    end

    TabESP:CreateSection("ESP")

    TabESP:CreateToggle({
        Name         = "Enable ESP",
        CurrentValue = Config.ESPEnabled,
        Flag         = "ESPEnabled",
        Callback     = function(val)
            Config.ESPEnabled = val
            State.ESPRunning  = val
            SaveConfig()
            if val then StartESP() else StopESP() end
        end,
    })

    TabESP:CreateToggle({
        Name         = "Show Names",
        CurrentValue = Config.ESPNames,
        Flag         = "ESPNames",
        Callback     = function(val) Config.ESPNames = val SaveConfig() end,
    })

    TabESP:CreateSlider({
        Name         = "Max Distance",
        Range        = {50, 5000},
        Increment    = 50,
        Suffix       = "m",
        CurrentValue = Config.ESPMaxDistance,
        Flag         = "ESPMaxDistance",
        Callback     = function(val) Config.ESPMaxDistance = val SaveConfig() end,
    })

    TabESP:CreateSection("Box Color")

    TabESP:CreateSlider({
        Name         = "Red",
        Range        = {0, 255},
        Increment    = 1,
        CurrentValue = Config.ESPBoxColor.r,
        Flag         = "ESPColorR",
        Callback     = function(val) Config.ESPBoxColor.r = val SaveConfig() end,
    })

    TabESP:CreateSlider({
        Name         = "Green",
        Range        = {0, 255},
        Increment    = 1,
        CurrentValue = Config.ESPBoxColor.g,
        Flag         = "ESPColorG",
        Callback     = function(val) Config.ESPBoxColor.g = val SaveConfig() end,
    })

    TabESP:CreateSlider({
        Name         = "Blue",
        Range        = {0, 255},
        Increment    = 1,
        CurrentValue = Config.ESPBoxColor.b,
        Flag         = "ESPColorB",
        Callback     = function(val) Config.ESPBoxColor.b = val SaveConfig() end,
    })
end

-- ============================================================
-- PLAYER
-- ============================================================
do
    TabPlayer:CreateSection("Speed")

    TabPlayer:CreateToggle({
        Name         = "Enable Speed Hack",
        CurrentValue = Config.SpeedEnabled,
        Flag         = "SpeedEnabled",
        Callback     = function(val)
            Config.SpeedEnabled = val
            SaveConfig()
            ApplySpeed()
        end,
    })

    TabPlayer:CreateSlider({
        Name         = "Walk Speed",
        Range        = {1, 500},
        Increment    = 1,
        CurrentValue = Config.SpeedValue,
        Flag         = "SpeedValue",
        Callback     = function(val)
            Config.SpeedValue = val
            SaveConfig()
            if Config.SpeedEnabled then ApplySpeed() end
        end,
    })

    TabPlayer:CreateSection("Jump")

    TabPlayer:CreateToggle({
        Name         = "Enable Jump Hack",
        CurrentValue = Config.JumpEnabled,
        Flag         = "JumpEnabled",
        Callback     = function(val)
            Config.JumpEnabled = val
            SaveConfig()
            ApplyJump()
        end,
    })

    TabPlayer:CreateSlider({
        Name         = "Jump Power",
        Range        = {1, 500},
        Increment    = 1,
        CurrentValue = Config.JumpValue,
        Flag         = "JumpValue",
        Callback     = function(val)
            Config.JumpValue = val
            SaveConfig()
            if Config.JumpEnabled then ApplyJump() end
        end,
    })

    TabPlayer:CreateToggle({
        Name         = "Infinite Jump",
        CurrentValue = Config.InfiniteJumpEnabled,
        Flag         = "InfiniteJumpEnabled",
        Callback     = function(val)
            Config.InfiniteJumpEnabled = val
            SaveConfig()
            if val then
                UserInputService.JumpRequest:Connect(function()
                    if not Config.InfiniteJumpEnabled then return end
                    local h = GetHumanoid()
                    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
                end)
            end
        end,
    })

    TabPlayer:CreateSection("Fly")

    TabPlayer:CreateToggle({
        Name         = "Enable Fly",
        CurrentValue = Config.FlyEnabled,
        Flag         = "FlyEnabled",
        Callback     = function(val)
            Config.FlyEnabled = val
            State.FlyRunning  = val
            SaveConfig()

            if val then
                task.spawn(function()
                    local char = GetCharacter()
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if not hrp or not hum then return end

                    hum.PlatformStand = true

                    local bv = Instance.new("BodyVelocity")
                    bv.Velocity  = Vector3.zero
                    bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
                    bv.Parent    = hrp

                    local bg = Instance.new("BodyGyro")
                    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
                    bg.P         = 1e4
                    bg.CFrame    = hrp.CFrame
                    bg.Parent    = hrp

                    while State.FlyRunning do
                        task.wait()
                        if not hrp or not hrp.Parent then break end
                        local dir = Vector3.zero
                        local cf  = Camera.CFrame
                        if UserInputService:IsKeyDown(Enum.KeyCode.W)           then dir += cf.LookVector        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S)           then dir -= cf.LookVector        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A)           then dir -= cf.RightVector       end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D)           then dir += cf.RightVector       end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir += Vector3.new(0,1,0)   end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0)   end
                        bv.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * Config.FlySpeed
                        bg.CFrame   = cf
                    end

                    pcall(function() bv:Destroy() end)
                    pcall(function() bg:Destroy() end)
                    if hum then hum.PlatformStand = false end
                end)
            else
                State.FlyRunning = false
                local char = GetCharacter()
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.PlatformStand = false end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local b1 = hrp:FindFirstChildOfClass("BodyVelocity")
                        local b2 = hrp:FindFirstChildOfClass("BodyGyro")
                        if b1 then b1:Destroy() end
                        if b2 then b2:Destroy() end
                    end
                end
            end
        end,
    })

    TabPlayer:CreateSlider({
        Name         = "Fly Speed",
        Range        = {1, 300},
        Increment    = 1,
        CurrentValue = Config.FlySpeed,
        Flag         = "FlySpeed",
        Callback     = function(val) Config.FlySpeed = val SaveConfig() end,
    })

    TabPlayer:CreateSection("NoClip")

    TabPlayer:CreateToggle({
        Name         = "Enable NoClip",
        CurrentValue = Config.NoClipEnabled,
        Flag         = "NoClipEnabled",
        Callback     = function(val)
            Config.NoClipEnabled = val
            State.NoClipRunning  = val
            SaveConfig()

            if val then
                task.spawn(function()
                    local conn = RunService.Stepped:Connect(function()
                        if not State.NoClipRunning then return end
                        local char = GetCharacter()
                        if not char then return end
                        for _, p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide = false end
                        end
                    end)
                    while State.NoClipRunning do task.wait(0.05) end
                    conn:Disconnect()
                    local char = GetCharacter()
                    if char then
                        for _, p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide = true end
                        end
                    end
                end)
            end
        end,
    })

    TabPlayer:CreateSection("Anti-AFK")

    TabPlayer:CreateToggle({
        Name         = "Enable Anti-AFK",
        CurrentValue = Config.AntiAFKEnabled,
        Flag         = "AntiAFKEnabled",
        Callback     = function(val)
            Config.AntiAFKEnabled = val
            State.AntiAFKRunning  = val
            SaveConfig()

            if val then
                task.spawn(function()
                    local VU = game:GetService("VirtualUser")
                    while State.AntiAFKRunning do
                        task.wait(55)
                        if State.AntiAFKRunning then
                            pcall(function()
                                VU:CaptureController()
                                VU:ClickButton2(Vector2.new())
                            end)
                        end
                    end
                end)
            end
        end,
    })

    task.spawn(function()
        task.wait(0.5)
        ApplySpeed()
        ApplyJump()
    end)

    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        local h = char:WaitForChild("Humanoid", 5)
        if not h then return end
        if Config.SpeedEnabled then h.WalkSpeed  = Config.SpeedValue end
        if Config.JumpEnabled  then
            h.JumpPower  = Config.JumpValue
            h.JumpHeight = Config.JumpValue * 0.04
        end
    end)
end

-- ============================================================
-- COMBAT  (Hitbox Expander + Omni Portal + Secondary Visible)
-- ============================================================
do
    -- ──────────────────────────────────────────────
    -- DELETE OMNI PORTAL
    -- ──────────────────────────────────────────────
    TabCombat:CreateSection("Omni Portal")

    TabCombat:CreateButton({
        Name     = "Delete Ruins Portal",
        Callback = function()
            local ok, err = pcall(function()
                local portal = Workspace:FindFirstChild("Ruins Portal")
                if portal then
                    portal:Destroy()
                    Rayfield:Notify({
                        Title   = "Portal Deleted",
                        Content = "Ruins Portal was removed from Workspace.",
                        Duration = 3,
                    })
                else
                    Rayfield:Notify({
                        Title   = "Not Found",
                        Content = "Ruins Portal does not exist in Workspace.",
                        Duration = 3,
                    })
                end
            end)
            if not ok then
                Rayfield:Notify({ Title = "Error", Content = tostring(err), Duration = 4 })
            end
        end,
    })

    -- ──────────────────────────────────────────────
    -- SECONDARY GUI VISIBLE
    -- ──────────────────────────────────────────────
    TabCombat:CreateSection("Secondary GUI")
    TabCombat:CreateLabel("Принудительно показывает SecondaryGUI.")

    -- Connections хранятся здесь чтобы можно было отключить
    local SecondaryConn      = nil  -- PropertyChanged connection
    local SecondaryLoopAlive = false

    local function StartSecondaryGUI()
        State.SecondaryGUIRunning = true
        SecondaryLoopAlive        = true

        task.spawn(function()
            -- Ищем GUI (ждём до 10 секунд)
            local playerGui    = LocalPlayer:WaitForChild("PlayerGui", 10)
            if not playerGui then
                Rayfield:Notify({
                    Title   = "SecondaryGUI",
                    Content = "PlayerGui не найден.",
                    Duration = 4,
                })
                State.SecondaryGUIRunning = false
                SecondaryLoopAlive        = false
                return
            end

            local secondaryGUI = playerGui:WaitForChild("SecondaryGUI", 10)
            if not secondaryGUI then
                Rayfield:Notify({
                    Title   = "SecondaryGUI",
                    Content = "SecondaryGUI не найден в PlayerGui.",
                    Duration = 4,
                })
                State.SecondaryGUIRunning = false
                SecondaryLoopAlive        = false
                return
            end

            -- Сразу включаем
            pcall(function() secondaryGUI.Enabled = true end)

            -- Следим за изменением свойства
            SecondaryConn = secondaryGUI:GetPropertyChangedSignal("Enabled"):Connect(function()
                if State.SecondaryGUIRunning and not secondaryGUI.Enabled then
                    pcall(function() secondaryGUI.Enabled = true end)
                end
            end)

            -- Резервный цикл раз в секунду
            while SecondaryLoopAlive do
                task.wait(1)
                if State.SecondaryGUIRunning then
                    pcall(function()
                        if not secondaryGUI.Enabled then
                            secondaryGUI.Enabled = true
                        end
                    end)
                end
            end
        end)
    end

    local function StopSecondaryGUI()
        State.SecondaryGUIRunning = false
        SecondaryLoopAlive        = false
        if SecondaryConn then
            SecondaryConn:Disconnect()
            SecondaryConn = nil
        end
    end

    TabCombat:CreateToggle({
        Name         = "Secondary GUI Visible",
        CurrentValue = Config.SecondaryGUIEnabled,
        Flag         = "SecondaryGUIEnabled",
        Callback     = function(val)
            Config.SecondaryGUIEnabled = val
            SaveConfig()
            if val then
                StartSecondaryGUI()
                Rayfield:Notify({
                    Title   = "SecondaryGUI",
                    Content = "Принудительное отображение включено.",
                    Duration = 3,
                })
            else
                StopSecondaryGUI()
                Rayfield:Notify({
                    Title   = "SecondaryGUI",
                    Content = "Отключено.",
                    Duration = 2,
                })
            end
        end,
    })

    -- ──────────────────────────────────────────────
    -- HITBOX EXPANDER
    -- ──────────────────────────────────────────────
    TabCombat:CreateSection("Hitbox Expander")
    TabCombat:CreateLabel("Авто-определяет меч (Tool с Handle) в персонаже.")

    local OriginalSizes = {}

    local function FindSwordHandle()
        local char = GetCharacter()
        local bp   = LocalPlayer:FindFirstChild("Backpack")

        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    local handle = tool:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        return handle, tool
                    end
                end
            end
        end

        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                if tool:IsA("Tool") then
                    local handle = tool:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        return handle, tool
                    end
                end
            end
        end

        return nil, nil
    end

    local function ApplyHitbox(handle, size)
        if not handle or not handle.Parent then return end

        if not OriginalSizes[handle] then
            OriginalSizes[handle] = handle.Size
        end

        local s = size or Config.HitboxSize

        -- Удаляем Mesh
        for _, child in ipairs(handle:GetChildren()) do
            if child:IsA("SpecialMesh")
            or child:IsA("BlockMesh")
            or child:IsA("CylinderMesh") then
                pcall(function() child:Destroy() end)
            end
        end

        -- Massless
        pcall(function() handle.Massless = true end)

        -- Полностью невидимый
        pcall(function()
            handle.Transparency = 1
            handle.CastShadow   = false
        end)

        -- Размер
        pcall(function() handle.Size = Vector3.new(s, s, s) end)
    end

    local function RestoreHandle(handle)
        if not handle or not handle.Parent then return end
        local orig = OriginalSizes[handle]
        if orig then
            pcall(function() handle.Size = orig end)
        end
        pcall(function()
            handle.Transparency = 0
            handle.CastShadow   = true
            handle.Massless     = false
        end)
    end

    local HitboxConn = nil

    local function StartHitbox()
        State.HitboxRunning = true
        HitboxConn = RunService.Heartbeat:Connect(function()
            if not State.HitboxRunning then return end
            local handle = FindSwordHandle()
            if handle then
                ApplyHitbox(handle, Config.HitboxSize)
            end
        end)
    end

    local function StopHitbox()
        State.HitboxRunning = false
        if HitboxConn then
            HitboxConn:Disconnect()
            HitboxConn = nil
        end
        for handle in pairs(OriginalSizes) do
            RestoreHandle(handle)
        end
        OriginalSizes = {}
    end

    TabCombat:CreateToggle({
        Name         = "Enable Hitbox Expander",
        CurrentValue = Config.HitboxEnabled,
        Flag         = "HitboxEnabled",
        Callback     = function(val)
            Config.HitboxEnabled = val
            SaveConfig()
            if val then
                StartHitbox()
                Rayfield:Notify({
                    Title   = "Hitbox Expander",
                    Content = "Активен. Размер: " .. Config.HitboxSize,
                    Duration = 3,
                })
            else
                StopHitbox()
                Rayfield:Notify({
                    Title   = "Hitbox Expander",
                    Content = "Выключен и восстановлен.",
                    Duration = 3,
                })
            end
        end,
    })

    -- Ползунок до 5000
    TabCombat:CreateSlider({
        Name         = "Hitbox Size",
        Range        = {1, 5000},
        Increment    = 1,
        Suffix       = " studs",
        CurrentValue = Config.HitboxSize,
        Flag         = "HitboxSize",
        Callback     = function(val)
            Config.HitboxSize = val
            SaveConfig()
            if State.HitboxRunning then
                local handle = FindSwordHandle()
                if handle then
                    ApplyHitbox(handle, val)
                end
            end
        end,
    })

    TabCombat:CreateButton({
        Name     = "Apply Hitbox Now",
        Callback = function()
            local handle, tool = FindSwordHandle()
            if handle then
                ApplyHitbox(handle, Config.HitboxSize)
                Rayfield:Notify({
                    Title   = "Hitbox Applied",
                    Content = (tool and tool.Name or "Unknown") .. " → " .. Config.HitboxSize .. " studs",
                    Duration = 3,
                })
            else
                Rayfield:Notify({
                    Title   = "Инструмент не найден",
                    Content = "Возьмите или держите оружие с Handle.",
                    Duration = 3,
                })
            end
        end,
    })

    TabCombat:CreateButton({
        Name     = "Restore Hitbox",
        Callback = function()
            local handle = FindSwordHandle()
            if handle then
                RestoreHandle(handle)
                OriginalSizes[handle] = nil
                Rayfield:Notify({
                    Title   = "Восстановлен",
                    Content = "Handle сброшен до оригинального размера.",
                    Duration = 3,
                })
            else
                Rayfield:Notify({
                    Title   = "Инструмент не найден",
                    Content = "Нечего восстанавливать.",
                    Duration = 3,
                })
            end
        end,
    })

    -- Восстанавливаем после respawn
    LocalPlayer.CharacterAdded:Connect(function()
        if Config.HitboxEnabled and not State.HitboxRunning then
            task.wait(1)
            StartHitbox()
        end
        -- SecondaryGUI тоже переподключаем после respawn если был включён
        if Config.SecondaryGUIEnabled and not State.SecondaryGUIRunning then
            StartSecondaryGUI()
        end
    end)
end

-- ============================================================
-- EVENTS  (Cakes + Hakari)
-- ============================================================
do
    TabEvents:CreateSection("Cake Prompt Protection")

    TabEvents:CreateToggle({
        Name         = "Enable Prompt Protection",
        CurrentValue = Config.CakePromptEnabled,
        Flag         = "CakePromptEnabled",
        Callback     = function(val)
            Config.CakePromptEnabled    = val
            State.CakePromptLoopRunning = val
            SaveConfig()

            if val then
                task.spawn(function()
                    local function ensureEnabled()
                        pcall(function()
                            local cake = Workspace:FindFirstChild("Cake")
                            if not cake then return end
                            local info = cake:FindFirstChild("InfoPart")
                            if not info then return end
                            local att = info:FindFirstChild("Attachment")
                            if not att then return end
                            local prompt = att:FindFirstChild("ProximityPrompt")
                            if prompt then prompt.Enabled = true end
                        end)
                    end

                    pcall(function()
                        local prompt = Workspace
                            :WaitForChild("Cake",            10)
                            :WaitForChild("InfoPart",        10)
                            :WaitForChild("Attachment",      10)
                            :WaitForChild("ProximityPrompt", 10)
                        if prompt then
                            prompt.Enabled = true
                            prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                                if Config.CakePromptEnabled and not prompt.Enabled then
                                    prompt.Enabled = true
                                end
                            end)
                        end
                    end)

                    while State.CakePromptLoopRunning do
                        task.wait(Config.CakeInterval)
                        ensureEnabled()
                    end
                end)
            end
        end,
    })

    TabEvents:CreateSlider({
        Name         = "Check Interval (s)",
        Range        = {0.5, 10},
        Increment    = 0.5,
        Suffix       = "s",
        CurrentValue = Config.CakeInterval,
        Flag         = "CakeInterval",
        Callback     = function(val) Config.CakeInterval = val SaveConfig() end,
    })

    TabEvents:CreateSection("Fire Cake Prompt")

    TabEvents:CreateSlider({
        Name         = "Fire Count",
        Range        = {100, 50000},
        Increment    = 100,
        Suffix       = "x",
        CurrentValue = Config.CakeFireCount,
        Flag         = "CakeFireCount",
        Callback     = function(val) Config.CakeFireCount = val SaveConfig() end,
    })

    TabEvents:CreateToggle({
        Name         = "Auto Cakes",
        CurrentValue = Config.AutoCakesEnabled,
        Flag         = "AutoCakesEnabled",
        Callback     = function(val)
            Config.AutoCakesEnabled = val
            State.AutoCakesRunning  = val
            SaveConfig()
        end,
    })

    local function FireCakes()
        task.spawn(function()
            local ok, err = pcall(function()
                local prompt = Workspace
                    :WaitForChild("Cake",            5)
                    :WaitForChild("InfoPart",        5)
                    :WaitForChild("Attachment",      5)
                    :WaitForChild("ProximityPrompt", 5)
                if not prompt then
                    Rayfield:Notify({ Title = "Error", Content = "ProximityPrompt not found.", Duration = 3 })
                    return
                end
                for _ = 1, Config.CakeFireCount do
                    prompt:InputHoldBegin(Enum.KeyCode.Unknown)
                    prompt:InputHoldEnd(Enum.KeyCode.Unknown)
                end
                Rayfield:Notify({ Title = "Cakes", Content = "Fired " .. Config.CakeFireCount .. "x", Duration = 3 })
            end)
            if not ok then
                Rayfield:Notify({ Title = "Error", Content = tostring(err), Duration = 4 })
            end
        end)
    end

    TabEvents:CreateButton({ Name = "Fire Cake Prompt", Callback = FireCakes })

    TabEvents:CreateSection("Auto Hakari")

    TabEvents:CreateToggle({
        Name         = "Enable Auto Hakari",
        CurrentValue = Config.AutoHakariEnabled,
        Flag         = "AutoHakariEnabled",
        Callback     = function(val)
            Config.AutoHakariEnabled = val
            State.AutoHakariRunning  = val
            SaveConfig()

            if val then
                task.spawn(function()
                    local EquipEv = ReplicatedStorage:FindFirstChild("EquipSecondary")
                    if not EquipEv then
                        Rayfield:Notify({ Title = "Hakari", Content = "EquipSecondary not found!", Duration = 5 })
                        State.AutoHakariRunning  = false
                        Config.AutoHakariEnabled = false
                        SaveConfig()
                        return
                    end

                    local function log(m)
                        print(("[%s][Hakari] %s"):format(os.date("%H:%M:%S"), tostring(m)))
                    end

                    local function FindBag()
                        local char = LocalPlayer.Character
                        if char and char:FindFirstChild("Candy Bag") then
                            return char:FindFirstChild("Candy Bag"), "character"
                        end
                        local bp = LocalPlayer:FindFirstChild("Backpack")
                        if bp and bp:FindFirstChild("Candy Bag") then
                            return bp:FindFirstChild("Candy Bag"), "backpack"
                        end
                        return nil, "none"
                    end

                    local function WaitTooltip(bag, cond, timeout)
                        if not bag or not bag.Parent then return false end
                        local done = false
                        local conn
                        local s = tick()
                        conn = bag:GetPropertyChangedSignal("ToolTip"):Connect(function()
                            if cond(bag.ToolTip or "") then
                                done = true
                                if conn.Connected then conn:Disconnect() end
                            end
                        end)
                        repeat task.wait(0.05)
                        until done
                            or not State.AutoHakariRunning
                            or not bag.Parent
                            or (tick() - s > (timeout or 10))
                        if conn and conn.Connected then conn:Disconnect() end
                        return done
                    end

                    local function HandleLife()
                        log("New life")
                        local char = LocalPlayer.Character
                        if not char then return end
                        local hum = char:WaitForChild("Humanoid", 5)
                        if not hum or hum.Health <= 0 then return end

                        local alive = true
                        local dc = hum.Died:Connect(function() alive = false end)

                        if State.AutoHakariRunning and alive then
                            EquipEv:FireServer("Candy Bag")
                            log("Requested Candy Bag")
                        else
                            dc:Disconnect()
                            return
                        end

                        local bag, loc
                        local ws = tick()
                        repeat
                            task.wait(0.07)
                            bag, loc = FindBag()
                        until not State.AutoHakariRunning
                            or not alive
                            or bag
                            or (tick() - ws > 6)

                        if not (bag and State.AutoHakariRunning and alive) then
                            log("No bag found")
                            dc:Disconnect()
                            return
                        end
                        log("Bag from: " .. loc)

                        while State.AutoHakariRunning and alive do
                            bag, loc = FindBag()
                            if not bag then break end
                            if loc == "backpack" then
                                hum:EquipTool(bag)
                                task.wait(0.2)
                            elseif loc == "character" then
                                bag:Activate()
                                task.wait(0.25)
                                local tt = bag.ToolTip or ""
                                if tt:find("160%%") then
                                    bag:Activate()
                                    task.wait(1.5)
                                    break
                                elseif tt:find("On Cooldown") then
                                    WaitTooltip(bag, function(t) return not t:find("On Cooldown") end, 15)
                                elseif tt:find("%%") then
                                    local old = tt
                                    WaitTooltip(bag, function(t) return t ~= old end, 8)
                                else
                                    task.wait(0.3)
                                end
                            else
                                task.wait(0.3)
                            end
                        end

                        dc:Disconnect()
                        log("Life ended")
                    end

                    if not State.HakariMainLoopRunning then
                        State.HakariMainLoopRunning = true

                        if LocalPlayer.Character then
                            task.spawn(function() pcall(HandleLife) end)
                        end

                        local cc = LocalPlayer.CharacterAdded:Connect(function()
                            if not State.AutoHakariRunning then return end
                            task.wait(0.05)
                            pcall(HandleLife)
                        end)

                        while State.AutoHakariRunning do task.wait(1) end

                        cc:Disconnect()
                        State.HakariMainLoopRunning = false
                        log("Loop stopped")
                    end
                end)

                Rayfield:Notify({ Title = "Auto Hakari", Content = "Started.", Duration = 3 })
            else
                State.AutoHakariRunning = false
                Rayfield:Notify({ Title = "Auto Hakari", Content = "Stopped.", Duration = 2 })
            end
        end,
    })
end

-- ============================================================
-- WEBHOOK
-- ============================================================
do
    TabWebhook:CreateSection("Webhook Blocker")

    TabWebhook:CreateToggle({
        Name         = "Enable Webhook Blocker",
        CurrentValue = Config.WebhookBlockEnabled,
        Flag         = "WebhookBlockEnabled",
        Callback     = function(val)
            Config.WebhookBlockEnabled = val
            SaveConfig()

            if val and not State.WebhookHooked then
                State.WebhookHooked = true
                task.spawn(function()
                    local reqFunc = http_request or request or (syn and syn.request)
                    if not reqFunc then
                        Rayfield:Notify({ Title = "Webhook", Content = "No request function found.", Duration = 4 })
                        return
                    end

                    local logFile = ("wh_log_%d_%.0f.txt"):format(LocalPlayer.UserId, tick())
                    local orig    = reqFunc

                    local success = pcall(function()
                        reqFunc = hookfunction(reqFunc, newcclosure(function(data)
                            if not Config.WebhookBlockEnabled then
                                return orig(data)
                            end
                            local url = tostring(data.Url or "")
                            local low = url:lower()
                            if low:find("discord") and (low:find("webhook") or low:find("websec")) then
                                pcall(function() rconsoleprint("BLOCKED: " .. url .. "\n") end)
                                pcall(function()
                                    writefile(
                                        logFile,
                                        "Webhook: " .. url .. "\nBody: " .. tostring(data.Body or "nil")
                                    )
                                end)
                                if Config.WebhookDelete then
                                    pcall(function()
                                        orig({
                                            Url     = url,
                                            Method  = "DELETE",
                                            Headers = { ["Content-Type"] = "application/json" },
                                        })
                                    end)
                                end
                                Rayfield:Notify({ Title = "Webhook Blocked", Content = url:sub(1, 50), Duration = 4 })
                                return
                            end
                            return orig(data)
                        end))
                    end)

                    if not success then
                        Rayfield:Notify({ Title = "Webhook", Content = "hookfunction not supported.", Duration = 4 })
                    end
                end)
            end

            Rayfield:Notify({
                Title   = "Webhook Blocker",
                Content = val and "Active" or "Disabled (hook remains).",
                Duration = 3,
            })
        end,
    })

    TabWebhook:CreateToggle({
        Name         = "Delete Webhook on Block",
        CurrentValue = Config.WebhookDelete,
        Flag         = "WebhookDelete",
        Callback     = function(val) Config.WebhookDelete = val SaveConfig() end,
    })

    TabWebhook:CreateSection("Universal Viewer")

    TabWebhook:CreateButton({
        Name     = "Load Universal Viewer",
        Callback = function()
            task.spawn(function()
                local ok, err = pcall(function()
                    loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/sinret/rbxscript.com-scripts-reuploads-/main/UNVIew",
                        true
                    ))()
                end)
                Rayfield:Notify({
                    Title    = "Universal Viewer",
                    Content  = ok and "Loaded." or "Error: " .. tostring(err),
                    Duration = ok and 3 or 5,
                })
            end)
        end,
    })
end

-- ============================================================
-- UTILS
-- ============================================================
do
    TabUtils:CreateSection("Debug")

    TabUtils:CreateButton({
        Name     = "Print States",
        Callback = function()
            print("=== STATES ===")
            for k, v in pairs(State) do print(k .. " = " .. tostring(v)) end
            print("=== CONFIG ===")
            for k, v in pairs(Config) do
                print(k .. " = " .. (type(v) == "table" and "[table]" or tostring(v)))
            end
            Rayfield:Notify({ Title = "Debug", Content = "Printed to console.", Duration = 2 })
        end,
    })

    TabUtils:CreateButton({
        Name     = "Executor Features",
        Callback = function()
            local list = {
                "hookfunction: "      .. tostring(hookfunction      ~= nil),
                "getrawmetatable: "   .. tostring(getrawmetatable   ~= nil),
                "sethiddenproperty: " .. tostring(sethiddenproperty ~= nil),
                "Drawing: "           .. tostring(Drawing           ~= nil),
                "isfile: "            .. tostring(isfile            ~= nil),
                "writefile: "         .. tostring(writefile         ~= nil),
                "setclipboard: "      .. tostring(setclipboard      ~= nil),
            }
            print("=== EXECUTOR ===")
            for _, f in ipairs(list) do print(f) end
            Rayfield:Notify({ Title = "Executor", Content = "Printed to console.", Duration = 3 })
        end,
    })

    TabUtils:CreateSection("Info")
    TabUtils:CreateLabel("KSFB Hub")
end

-- ============================================================
-- INIT
-- ============================================================
Rayfield:Notify({
    Title    = "KSFB Hub",
    Content  = "Loaded. Players: " .. #Players:GetPlayers(),
    Duration = 4,
})

LocalPlayer.AncestryChanged:Connect(function() SaveConfig() end)

print("KSFB Hub loaded.")
