-- ============================================================
-- KSFB Hub — Custom GUI (no external loader)
-- ============================================================

-- Services
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Camera            = Workspace.CurrentCamera

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
    ESPBoxColor         = {r=255,g=50,b=50},
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
    if isfile and isfile(ConfigFile) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFile))
        end)
        if ok and type(data) == "table" then
            for k,v in pairs(DefaultConfig) do
                if data[k] == nil then data[k] = v end
            end
            Config = data
            return
        end
    end
    Config = table.clone(DefaultConfig)
end

local function SaveConfig()
    pcall(function()
        if writefile then
            writefile(ConfigFile, HttpService:JSONEncode(Config))
        end
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
    if h then h.WalkSpeed = Config.SpeedEnabled and Config.SpeedValue or 16 end
end
local function ApplyJump()
    local h = GetHumanoid()
    if h then
        h.JumpPower  = Config.JumpEnabled and Config.JumpValue or 50
        h.JumpHeight = Config.JumpEnabled and (Config.JumpValue * 0.04) or 2.0
    end
end

-- ============================================================
-- GUI BUILDER
-- ============================================================
local THEME = {
    BG         = Color3.fromRGB(15, 15, 20),
    Panel      = Color3.fromRGB(22, 22, 30),
    Tab        = Color3.fromRGB(30, 30, 42),
    TabActive  = Color3.fromRGB(80, 60, 160),
    Accent     = Color3.fromRGB(100, 80, 200),
    AccentHov  = Color3.fromRGB(120, 100, 220),
    Text       = Color3.fromRGB(230, 230, 240),
    TextDim    = Color3.fromRGB(140, 140, 160),
    Toggle_ON  = Color3.fromRGB(80, 200, 120),
    Toggle_OFF = Color3.fromRGB(60, 60, 80),
    Border     = Color3.fromRGB(50, 50, 70),
    Notify     = Color3.fromRGB(25, 25, 35),
    Section    = Color3.fromRGB(100, 80, 200),
    Slider     = Color3.fromRGB(80, 60, 160),
    SliderBG   = Color3.fromRGB(35, 35, 50),
    Input      = Color3.fromRGB(28, 28, 40),
}

-- ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name             = "KSFBHub"
ScreenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn     = false
ScreenGui.DisplayOrder     = 999

if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game:GetService("CoreGui")
else
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

-- ── Notification system ──────────────────────────────────────
local NotifyHolder = Instance.new("Frame")
NotifyHolder.Name            = "NotifyHolder"
NotifyHolder.BackgroundTransparency = 1
NotifyHolder.Size            = UDim2.new(0, 280, 1, 0)
NotifyHolder.Position        = UDim2.new(1, -290, 0, 0)
NotifyHolder.Parent          = ScreenGui

local NotifyLayout = Instance.new("UIListLayout")
NotifyLayout.FillDirection   = Enum.FillDirection.Vertical
NotifyLayout.VerticalAlignment= Enum.VerticalAlignment.Bottom
NotifyLayout.Padding         = UDim.new(0, 6)
NotifyLayout.Parent          = NotifyHolder

local function Notify(title, content, duration)
    duration = duration or 3
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, 60)
    f.BackgroundColor3 = THEME.Notify
    f.BorderSizePixel  = 0
    f.ClipsDescendants = true
    f.Parent           = NotifyHolder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent       = f

    local stroke = Instance.new("UIStroke")
    stroke.Color     = THEME.Accent
    stroke.Thickness = 1
    stroke.Parent    = f

    local accent = Instance.new("Frame")
    accent.Size             = UDim2.new(0, 3, 1, 0)
    accent.BackgroundColor3 = THEME.Accent
    accent.BorderSizePixel  = 0
    accent.Parent           = f

    local tl = Instance.new("TextLabel")
    tl.Size            = UDim2.new(1, -12, 0, 22)
    tl.Position        = UDim2.new(0, 10, 0, 4)
    tl.BackgroundTransparency = 1
    tl.Text            = title
    tl.TextColor3      = THEME.Text
    tl.Font            = Enum.Font.GothamBold
    tl.TextSize        = 13
    tl.TextXAlignment  = Enum.TextXAlignment.Left
    tl.Parent          = f

    local cl = Instance.new("TextLabel")
    cl.Size            = UDim2.new(1, -12, 0, 28)
    cl.Position        = UDim2.new(0, 10, 0, 26)
    cl.BackgroundTransparency = 1
    cl.Text            = content
    cl.TextColor3      = THEME.TextDim
    cl.Font            = Enum.Font.Gotham
    cl.TextSize        = 11
    cl.TextXAlignment  = Enum.TextXAlignment.Left
    cl.TextWrapped     = true
    cl.Parent          = f

    task.delay(duration, function()
        TweenService:Create(f, TweenInfo.new(0.4), {Size = UDim2.new(1,0,0,0)}):Play()
        task.wait(0.5)
        f:Destroy()
    end)
end

-- ── Main Window ──────────────────────────────────────────────
local MainFrame = Instance.new("Frame")
MainFrame.Name             = "MainFrame"
MainFrame.Size             = UDim2.new(0, 680, 0, 440)
MainFrame.Position         = UDim2.new(0.5, -340, 0.5, -220)
MainFrame.BackgroundColor3 = THEME.BG
MainFrame.BorderSizePixel  = 0
MainFrame.ClipsDescendants = false
MainFrame.Parent           = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent       = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color     = THEME.Border
MainStroke.Thickness = 1
MainStroke.Parent    = MainFrame

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = THEME.Panel
TitleBar.BorderSizePixel  = 0
TitleBar.Parent           = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent       = TitleBar

-- Cover bottom corners of title
local TitleCoverBottom = Instance.new("Frame")
TitleCoverBottom.Size             = UDim2.new(1, 0, 0, 8)
TitleCoverBottom.Position         = UDim2.new(0, 0, 1, -8)
TitleCoverBottom.BackgroundColor3 = THEME.Panel
TitleCoverBottom.BorderSizePixel  = 0
TitleCoverBottom.Parent           = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size            = UDim2.new(1, -80, 1, 0)
TitleLabel.Position        = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text            = "⚡ KSFB Hub"
TitleLabel.TextColor3      = THEME.Text
TitleLabel.Font            = Enum.Font.GothamBold
TitleLabel.TextSize        = 15
TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
TitleLabel.Parent          = TitleBar

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.new(0, 28, 0, 22)
CloseBtn.Position         = UDim2.new(1, -34, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
CloseBtn.BorderSizePixel  = 0
CloseBtn.Text             = "✕"
CloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.TextSize         = 13
CloseBtn.Parent           = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent       = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Minimize button
local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 28, 0, 22)
MinBtn.Position         = UDim2.new(1, -66, 0, 7)
MinBtn.BackgroundColor3 = Color3.fromRGB(220, 160, 40)
MinBtn.BorderSizePixel  = 0
MinBtn.Text             = "─"
MinBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.TextSize         = 13
MinBtn.Parent           = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 4)
MinCorner.Parent       = MinBtn

local ContentVisible = true
local ContentHolder  -- defined below

MinBtn.MouseButton1Click:Connect(function()
    ContentVisible = not ContentVisible
    ContentHolder.Visible = ContentVisible
    MainFrame.Size = ContentVisible
        and UDim2.new(0, 680, 0, 440)
        or  UDim2.new(0, 680, 0, 36)
end)

-- Drag
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = MainFrame.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inp.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Content area
ContentHolder = Instance.new("Frame")
ContentHolder.Name             = "ContentHolder"
ContentHolder.Size             = UDim2.new(1, 0, 1, -36)
ContentHolder.Position         = UDim2.new(0, 0, 0, 36)
ContentHolder.BackgroundTransparency = 1
ContentHolder.Parent           = MainFrame

-- Tab bar (left sidebar)
local TabBar = Instance.new("ScrollingFrame")
TabBar.Name                    = "TabBar"
TabBar.Size                    = UDim2.new(0, 130, 1, 0)
TabBar.BackgroundColor3        = THEME.Panel
TabBar.BorderSizePixel         = 0
TabBar.ScrollBarThickness      = 2
TabBar.ScrollBarImageColor3    = THEME.Accent
TabBar.CanvasSize              = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize     = Enum.AutomaticSize.Y
TabBar.Parent                  = ContentHolder

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 6)
TabBarCorner.Parent       = TabBar

local TabBarCoverRight = Instance.new("Frame")
TabBarCoverRight.Size             = UDim2.new(0, 8, 1, 0)
TabBarCoverRight.Position         = UDim2.new(1, -8, 0, 0)
TabBarCoverRight.BackgroundColor3 = THEME.Panel
TabBarCoverRight.BorderSizePixel  = 0
TabBarCoverRight.Parent           = TabBar

local TabBarLayout = Instance.new("UIListLayout")
TabBarLayout.FillDirection   = Enum.FillDirection.Vertical
TabBarLayout.Padding         = UDim.new(0, 2)
TabBarLayout.Parent          = TabBar

local TabBarPadding = Instance.new("UIPadding")
TabBarPadding.PaddingTop    = UDim.new(0, 6)
TabBarPadding.PaddingLeft   = UDim.new(0, 6)
TabBarPadding.PaddingRight  = UDim.new(0, 6)
TabBarPadding.Parent        = TabBar

-- Tab content area
local TabContent = Instance.new("Frame")
TabContent.Name             = "TabContent"
TabContent.Size             = UDim2.new(1, -138, 1, -8)
TabContent.Position         = UDim2.new(0, 138, 0, 4)
TabContent.BackgroundColor3 = THEME.Panel
TabContent.BorderSizePixel  = 0
TabContent.ClipsDescendants = true
TabContent.Parent           = ContentHolder

local TabContentCorner = Instance.new("UICorner")
TabContentCorner.CornerRadius = UDim.new(0, 6)
TabContentCorner.Parent       = TabContent

-- ── Tab system ───────────────────────────────────────────────
local Tabs         = {}
local ActiveTab    = nil
local TabButtons   = {}

local function CreateTab(name)
    -- Tab button
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = THEME.Tab
    btn.BorderSizePixel  = 0
    btn.Text             = name
    btn.TextColor3       = THEME.TextDim
    btn.Font             = Enum.Font.Gotham
    btn.TextSize         = 12
    btn.Parent           = TabBar

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent       = btn

    -- Tab scroll pane
    local pane = Instance.new("ScrollingFrame")
    pane.Name                  = name
    pane.Size                  = UDim2.new(1, 0, 1, 0)
    pane.BackgroundTransparency= 1
    pane.BorderSizePixel       = 0
    pane.ScrollBarThickness    = 3
    pane.ScrollBarImageColor3  = THEME.Accent
    pane.CanvasSize            = UDim2.new(0, 0, 0, 0)
    pane.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    pane.Visible               = false
    pane.Parent                = TabContent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection  = Enum.FillDirection.Vertical
    layout.Padding        = UDim.new(0, 4)
    layout.Parent         = pane

    local padding = Instance.new("UIPadding")
    padding.PaddingTop    = UDim.new(0, 8)
    padding.PaddingLeft   = UDim.new(0, 8)
    padding.PaddingRight  = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent        = pane

    local tabObj = {
        Pane    = pane,
        Button  = btn,
        Layout  = layout,
    }

    table.insert(Tabs, tabObj)
    TabButtons[name] = {btn = btn, pane = pane, tabObj = tabObj}

    local function Activate()
        if ActiveTab then
            ActiveTab.Pane.Visible        = false
            ActiveTab.Button.BackgroundColor3 = THEME.Tab
            ActiveTab.Button.TextColor3       = THEME.TextDim
            ActiveTab.Button.Font             = Enum.Font.Gotham
        end
        ActiveTab               = tabObj
        pane.Visible            = true
        btn.BackgroundColor3    = THEME.TabActive
        btn.TextColor3          = THEME.Text
        btn.Font                = Enum.Font.GothamBold
    end

    btn.MouseButton1Click:Connect(Activate)
    btn.MouseEnter:Connect(function()
        if ActiveTab ~= tabObj then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.Border}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= tabObj then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.Tab}):Play()
        end
    end)

    -- Activate first tab automatically
    if #Tabs == 1 then Activate() end

    -- ── Widget creators ──────────────────────────────────────
    function tabObj:CreateSection(text)
        local f = Instance.new("Frame")
        f.Size             = UDim2.new(1, 0, 0, 24)
        f.BackgroundColor3 = THEME.BG
        f.BorderSizePixel  = 0
        f.Parent           = pane

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent       = f

        local lbl = Instance.new("TextLabel")
        lbl.Size            = UDim2.new(1, -10, 1, 0)
        lbl.Position        = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text            = "  " .. text:upper()
        lbl.TextColor3      = THEME.Section
        lbl.Font            = Enum.Font.GothamBold
        lbl.TextSize        = 11
        lbl.TextXAlignment  = Enum.TextXAlignment.Left
        lbl.Parent          = f

        local line = Instance.new("Frame")
        line.Size             = UDim2.new(1, -16, 0, 1)
        line.Position         = UDim2.new(0, 8, 1, -1)
        line.BackgroundColor3 = THEME.Section
        line.BackgroundTransparency = 0.6
        line.BorderSizePixel  = 0
        line.Parent           = f
    end

    function tabObj:CreateLabel(text)
        local lbl = Instance.new("TextLabel")
        lbl.Size            = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text            = text
        lbl.TextColor3      = THEME.TextDim
        lbl.Font            = Enum.Font.Gotham
        lbl.TextSize        = 11
        lbl.TextXAlignment  = Enum.TextXAlignment.Left
        lbl.TextWrapped     = true
        lbl.Parent          = pane
    end

    function tabObj:CreateToggle(opts)
        -- opts: Name, CurrentValue, Callback
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = THEME.BG
        row.BorderSizePixel  = 0
        row.Parent           = pane

        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 5)
        rc.Parent       = row

        local lbl = Instance.new("TextLabel")
        lbl.Size            = UDim2.new(1, -56, 1, 0)
        lbl.Position        = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text            = opts.Name
        lbl.TextColor3      = THEME.Text
        lbl.Font            = Enum.Font.Gotham
        lbl.TextSize        = 12
        lbl.TextXAlignment  = Enum.TextXAlignment.Left
        lbl.Parent          = row

        local track = Instance.new("Frame")
        track.Size             = UDim2.new(0, 40, 0, 20)
        track.Position         = UDim2.new(1, -48, 0.5, -10)
        track.BackgroundColor3 = opts.CurrentValue and THEME.Toggle_ON or THEME.Toggle_OFF
        track.BorderSizePixel  = 0
        track.Parent           = row

        local tc2 = Instance.new("UICorner")
        tc2.CornerRadius = UDim.new(1, 0)
        tc2.Parent       = track

        local knob = Instance.new("Frame")
        knob.Size             = UDim2.new(0, 16, 0, 16)
        knob.Position         = opts.CurrentValue
            and UDim2.new(1, -18, 0.5, -8)
            or  UDim2.new(0, 2, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel  = 0
        knob.Parent           = track

        local kc = Instance.new("UICorner")
        kc.CornerRadius = UDim.new(1, 0)
        kc.Parent       = knob

        local value = opts.CurrentValue

        local function Toggle()
            value = not value
            TweenService:Create(track, TweenInfo.new(0.2), {
                BackgroundColor3 = value and THEME.Toggle_ON or THEME.Toggle_OFF
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.2), {
                Position = value
                    and UDim2.new(1, -18, 0.5, -8)
                    or  UDim2.new(0, 2, 0.5, -8)
            }):Play()
            pcall(opts.Callback, value)
        end

        track.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then Toggle() end
        end)
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then Toggle() end
        end)

        return {
            SetValue = function(_, v)
                value = v
                TweenService:Create(track, TweenInfo.new(0.2), {
                    BackgroundColor3 = v and THEME.Toggle_ON or THEME.Toggle_OFF
                }):Play()
                TweenService:Create(knob, TweenInfo.new(0.2), {
                    Position = v
                        and UDim2.new(1, -18, 0.5, -8)
                        or  UDim2.new(0, 2, 0.5, -8)
                }):Play()
            end,
        }
    end

    function tabObj:CreateSlider(opts)
        -- opts: Name, Range, Increment, Suffix, CurrentValue, Callback
        local min  = opts.Range[1]
        local max  = opts.Range[2]
        local inc  = opts.Increment or 1
        local suf  = opts.Suffix or ""
        local val  = opts.CurrentValue or min

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 48)
        row.BackgroundColor3 = THEME.BG
        row.BorderSizePixel  = 0
        row.Parent           = pane

        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 5)
        rc.Parent       = row

        local lbl = Instance.new("TextLabel")
        lbl.Size            = UDim2.new(0.7, 0, 0, 20)
        lbl.Position        = UDim2.new(0, 10, 0, 4)
        lbl.BackgroundTransparency = 1
        lbl.Text            = opts.Name
        lbl.TextColor3      = THEME.Text
        lbl.Font            = Enum.Font.Gotham
        lbl.TextSize        = 12
        lbl.TextXAlignment  = Enum.TextXAlignment.Left
        lbl.Parent          = row

        local valLbl = Instance.new("TextLabel")
        valLbl.Size            = UDim2.new(0.3, -10, 0, 20)
        valLbl.Position        = UDim2.new(0.7, 0, 0, 4)
        valLbl.BackgroundTransparency = 1
        valLbl.Text            = tostring(val) .. suf
        valLbl.TextColor3      = THEME.Accent
        valLbl.Font            = Enum.Font.GothamBold
        valLbl.TextSize        = 12
        valLbl.TextXAlignment  = Enum.TextXAlignment.Right
        valLbl.Parent          = row

        local track = Instance.new("Frame")
        track.Size             = UDim2.new(1, -20, 0, 6)
        track.Position         = UDim2.new(0, 10, 0, 32)
        track.BackgroundColor3 = THEME.SliderBG
        track.BorderSizePixel  = 0
        track.Parent           = row

        local tc3 = Instance.new("UICorner")
        tc3.CornerRadius = UDim.new(1, 0)
        tc3.Parent       = track

        local fill = Instance.new("Frame")
        fill.Size             = UDim2.new((val - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = THEME.Slider
        fill.BorderSizePixel  = 0
        fill.Parent           = track

        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(1, 0)
        fc.Parent       = fill

        local thumb = Instance.new("Frame")
        thumb.Size             = UDim2.new(0, 12, 0, 12)
        thumb.Position         = UDim2.new((val - min) / (max - min), -6, 0.5, -6)
        thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        thumb.BorderSizePixel  = 0
        thumb.Parent           = track

        local thc = Instance.new("UICorner")
        thc.CornerRadius = UDim.new(1, 0)
        thc.Parent       = thumb

        local sliding = false

        local function UpdateSlider(absX)
            local tAbs = track.AbsolutePosition.X
            local tSz  = track.AbsoluteSize.X
            local ratio = math.clamp((absX - tAbs) / tSz, 0, 1)
            local raw = min + ratio * (max - min)
            local snapped = math.round(raw / inc) * inc
            snapped = math.clamp(snapped, min, max)
            snapped = math.round(snapped * 1000) / 1000

            fill.Size  = UDim2.new(ratio, 0, 1, 0)
            thumb.Position = UDim2.new(ratio, -6, 0.5, -6)
            valLbl.Text    = tostring(snapped) .. suf
            val = snapped
            pcall(opts.Callback, snapped)
        end

        track.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                sliding = true
                UpdateSlider(inp.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if sliding and inp.UserInputType == Enum.UserInputType.MouseMovement then
                UpdateSlider(inp.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                sliding = false
            end
        end)
    end

    function tabObj:CreateButton(opts)
        local btn2 = Instance.new("TextButton")
        btn2.Size             = UDim2.new(1, 0, 0, 32)
        btn2.BackgroundColor3 = THEME.Accent
        btn2.BorderSizePixel  = 0
        btn2.Text             = opts.Name
        btn2.TextColor3       = THEME.Text
        btn2.Font             = Enum.Font.GothamBold
        btn2.TextSize         = 12
        btn2.Parent           = pane

        local bc2 = Instance.new("UICorner")
        bc2.CornerRadius = UDim.new(0, 5)
        bc2.Parent       = btn2

        btn2.MouseEnter:Connect(function()
            TweenService:Create(btn2, TweenInfo.new(0.15), {BackgroundColor3 = THEME.AccentHov}):Play()
        end)
        btn2.MouseLeave:Connect(function()
            TweenService:Create(btn2, TweenInfo.new(0.15), {BackgroundColor3 = THEME.Accent}):Play()
        end)
        btn2.MouseButton1Click:Connect(function()
            pcall(opts.Callback)
        end)
    end

    function tabObj:CreateInput(opts)
        -- opts: Name, PlaceholderText, RemoveTextAfterFocusLost, Callback
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 52)
        row.BackgroundColor3 = THEME.BG
        row.BorderSizePixel  = 0
        row.Parent           = pane

        local rc4 = Instance.new("UICorner")
        rc4.CornerRadius = UDim.new(0, 5)
        rc4.Parent       = row

        local lbl2 = Instance.new("TextLabel")
        lbl2.Size            = UDim2.new(1, -10, 0, 20)
        lbl2.Position        = UDim2.new(0, 10, 0, 4)
        lbl2.BackgroundTransparency = 1
        lbl2.Text            = opts.Name
        lbl2.TextColor3      = THEME.Text
        lbl2.Font            = Enum.Font.Gotham
        lbl2.TextSize        = 12
        lbl2.TextXAlignment  = Enum.TextXAlignment.Left
        lbl2.Parent          = row

        local box = Instance.new("TextBox")
        box.Size             = UDim2.new(1, -20, 0, 22)
        box.Position         = UDim2.new(0, 10, 0, 24)
        box.BackgroundColor3 = THEME.Input
        box.BorderSizePixel  = 0
        box.Text             = ""
        box.PlaceholderText  = opts.PlaceholderText or ""
        box.PlaceholderColor3= THEME.TextDim
        box.TextColor3       = THEME.Text
        box.Font             = Enum.Font.Gotham
        box.TextSize         = 12
        box.ClearTextOnFocus = false
        box.Parent           = row

        local bc5 = Instance.new("UICorner")
        bc5.CornerRadius = UDim.new(0, 4)
        bc5.Parent       = box

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.Parent      = box

        box.FocusLost:Connect(function(enter)
            if enter then
                pcall(opts.Callback, box.Text)
                if opts.RemoveTextAfterFocusLost then
                    box.Text = ""
                end
            end
        end)
    end

    function tabObj:CreateDropdown(opts)
        -- opts: Name, Options, CurrentOption, MultipleOptions, Callback
        local selected = {}
        if opts.MultipleOptions and type(opts.CurrentOption) == "table" then
            for _, v in ipairs(opts.CurrentOption) do selected[v] = true end
        end

        local open = false

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = THEME.BG
        row.BorderSizePixel  = 0
        row.ClipsDescendants = false
        row.Parent           = pane

        local rc6 = Instance.new("UICorner")
        rc6.CornerRadius = UDim.new(0, 5)
        rc6.Parent       = row

        local headerBtn = Instance.new("TextButton")
        headerBtn.Size             = UDim2.new(1, 0, 0, 34)
        headerBtn.BackgroundColor3 = THEME.BG
        headerBtn.BorderSizePixel  = 0
        headerBtn.Text             = opts.Name .. "  ▾"
        headerBtn.TextColor3       = THEME.Text
        headerBtn.Font             = Enum.Font.Gotham
        headerBtn.TextSize         = 12
        headerBtn.TextXAlignment   = Enum.TextXAlignment.Left
        headerBtn.Parent           = row

        local hPad = Instance.new("UIPadding")
        hPad.PaddingLeft = UDim.new(0, 10)
        hPad.Parent      = headerBtn

        local hCorner = Instance.new("UICorner")
        hCorner.CornerRadius = UDim.new(0, 5)
        hCorner.Parent       = headerBtn

        -- Dropdown list (appears below)
        local list = Instance.new("Frame")
        list.Size             = UDim2.new(1, 0, 0, 0)
        list.Position         = UDim2.new(0, 0, 1, 2)
        list.BackgroundColor3 = THEME.Input
        list.BorderSizePixel  = 0
        list.ClipsDescendants = true
        list.ZIndex           = 20
        list.Visible          = false
        list.Parent           = row

        local lc = Instance.new("UICorner")
        lc.CornerRadius = UDim.new(0, 5)
        lc.Parent       = list

        local listLayout = Instance.new("UIListLayout")
        listLayout.FillDirection  = Enum.FillDirection.Vertical
        listLayout.Padding        = UDim.new(0, 1)
        listLayout.Parent         = list

        local function RefreshList()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for _, opt in ipairs(opts.Options or {}) do
                local ob = Instance.new("TextButton")
                ob.Size             = UDim2.new(1, 0, 0, 28)
                ob.BackgroundColor3 = selected[opt] and THEME.TabActive or THEME.Input
                ob.BorderSizePixel  = 0
                ob.Text             = "  " .. opt
                ob.TextColor3       = THEME.Text
                ob.Font             = Enum.Font.Gotham
                ob.TextSize         = 11
                ob.TextXAlignment   = Enum.TextXAlignment.Left
                ob.ZIndex           = 21
                ob.Parent           = list

                ob.MouseButton1Click:Connect(function()
                    if opts.MultipleOptions then
                        selected[opt] = not selected[opt]
                        ob.BackgroundColor3 = selected[opt] and THEME.TabActive or THEME.Input
                        local sel = {}
                        for k, v in pairs(selected) do if v then table.insert(sel, k) end end
                        pcall(opts.Callback, sel)
                    else
                        selected = {[opt] = true}
                        list.Visible = false
                        open = false
                        headerBtn.Text = opts.Name .. ": " .. opt .. "  ▾"
                        pcall(opts.Callback, opt)
                        RefreshList()
                    end
                end)
            end
            local count = math.min(#(opts.Options or {}), 5)
            list.Size = UDim2.new(1, 0, 0, count * 29)
        end

        headerBtn.MouseButton1Click:Connect(function()
            open = not open
            RefreshList()
            list.Visible = open
        end)

        -- Return object with Set method
        local dropObj = {
            Set = function(_, newOpts)
                opts.Options = newOpts
                if open then RefreshList() end
            end,
        }
        return dropObj
    end

    return tabObj
end

-- ── Keybind toggle (RightShift) ──────────────────────────────
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

local ToggleHint = Instance.new("TextLabel")
ToggleHint.Size            = UDim2.new(0, 200, 0, 20)
ToggleHint.Position        = UDim2.new(0.5, -100, 0, 4)
ToggleHint.BackgroundTransparency = 1
ToggleHint.Text            = "[RightShift] Toggle GUI"
ToggleHint.TextColor3      = THEME.TextDim
ToggleHint.Font            = Enum.Font.Gotham
ToggleHint.TextSize        = 11
ToggleHint.Parent          = ScreenGui

-- ============================================================
-- CREATE TABS
-- ============================================================
local TabKill    = CreateTab("⚔ Kill NPC")
local TabKick    = CreateTab("🚫 Auto Kick")
local TabESP     = CreateTab("👁 ESP")
local TabPlayer  = CreateTab("🏃 Player")
local TabCombat  = CreateTab("🥊 Combat")
local TabEvents  = CreateTab("🎂 Events")
local TabWebhook = CreateTab("🔗 Webhook")
local TabUtils   = CreateTab("🔧 Utils")

-- ============================================================
-- KILL NPC
-- ============================================================
do
    TabKill:CreateSection("Auto Kill NPC")

    TabKill:CreateToggle({
        Name         = "Enable Auto Kill NPC",
        CurrentValue = Config.AutoKillNPC,
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
        Callback     = function(val) Config.AutoKillDelay = val SaveConfig() end,
    })

    TabKill:CreateSlider({
        Name         = "Simulation Radius",
        Range        = {1, 1000},
        Increment    = 1,
        CurrentValue = Config.SimRadius,
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
            Notify("Kill All", "Attempted to kill all players.", 3)
        end,
    })

    TabKill:CreateInput({
        Name                     = "Kill Specific Player",
        PlaceholderText          = "Enter name → Enter",
        RemoveTextAfterFocusLost = true,
        Callback                 = function(text)
            if text == "" then return end
            local target = Players:FindFirstChild(text)
            if target and target.Character then
                local h = target.Character:FindFirstChildOfClass("Humanoid")
                if h then h.Health = 0 Notify("Killed", text, 3) return end
            end
            Notify("Not Found", text, 3)
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
            if p ~= LocalPlayer then table.insert(opts, p.Name) end
        end
        if #opts == 0 then table.insert(opts, "(No players)") end
        return opts
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
        Callback     = function(val)
            Config.AutoKickEnabled = val
            State.AutoKickRunning  = val
            SaveConfig()
            if val then StartAutoKick() else StopAutoKick() end
        end,
    })

    TabKick:CreateSection("Trusted Players")
    TabKick:CreateLabel("Selected players will NOT trigger kick.")

    TrustedDropdown = TabKick:CreateDropdown({
        Name            = "Trusted Players",
        Options         = BuildPlayerOptions(),
        CurrentOption   = Config.TrustedPlayers,
        MultipleOptions = true,
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
            Notify("Trusted Updated", #Config.TrustedPlayers .. " players trusted.", 2)
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
            Notify("Cleared", "Trusted list cleared.", 3)
        end,
    })

    Players.PlayerAdded:Connect(function()
        if TrustedDropdown then
            TrustedDropdown:Set(BuildPlayerOptions())
        end
    end)
    Players.PlayerRemoving:Connect(function()
        if TrustedDropdown then
            TrustedDropdown:Set(BuildPlayerOptions())
        end
    end)
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
        Callback     = function(val) Config.ESPNames = val SaveConfig() end,
    })

    TabESP:CreateSlider({
        Name         = "Max Distance",
        Range        = {50, 5000},
        Increment    = 50,
        Suffix       = "m",
        CurrentValue = Config.ESPMaxDistance,
        Callback     = function(val) Config.ESPMaxDistance = val SaveConfig() end,
    })

    TabESP:CreateSection("Box Color")
    TabESP:CreateSlider({ Name="Red",   Range={0,255}, Increment=1, CurrentValue=Config.ESPBoxColor.r, Callback=function(v) Config.ESPBoxColor.r=v SaveConfig() end })
    TabESP:CreateSlider({ Name="Green", Range={0,255}, Increment=1, CurrentValue=Config.ESPBoxColor.g, Callback=function(v) Config.ESPBoxColor.g=v SaveConfig() end })
    TabESP:CreateSlider({ Name="Blue",  Range={0,255}, Increment=1, CurrentValue=Config.ESPBoxColor.b, Callback=function(v) Config.ESPBoxColor.b=v SaveConfig() end })
end

-- ============================================================
-- PLAYER
-- ============================================================
do
    TabPlayer:CreateSection("Speed")

    TabPlayer:CreateToggle({
        Name         = "Enable Speed Hack",
        CurrentValue = Config.SpeedEnabled,
        Callback     = function(val) Config.SpeedEnabled = val SaveConfig() ApplySpeed() end,
    })
    TabPlayer:CreateSlider({
        Name="Walk Speed", Range={1,500}, Increment=1, CurrentValue=Config.SpeedValue,
        Callback=function(val)
            Config.SpeedValue = val SaveConfig()
            if Config.SpeedEnabled then ApplySpeed() end
        end,
    })

    TabPlayer:CreateSection("Jump")
    TabPlayer:CreateToggle({
        Name="Enable Jump Hack", CurrentValue=Config.JumpEnabled,
        Callback=function(val) Config.JumpEnabled=val SaveConfig() ApplyJump() end,
    })
    TabPlayer:CreateSlider({
        Name="Jump Power", Range={1,500}, Increment=1, CurrentValue=Config.JumpValue,
        Callback=function(val)
            Config.JumpValue=val SaveConfig()
            if Config.JumpEnabled then ApplyJump() end
        end,
    })
    TabPlayer:CreateToggle({
        Name="Infinite Jump", CurrentValue=Config.InfiniteJumpEnabled,
        Callback=function(val)
            Config.InfiniteJumpEnabled=val SaveConfig()
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
        Name="Enable Fly", CurrentValue=Config.FlyEnabled,
        Callback=function(val)
            Config.FlyEnabled=val State.FlyRunning=val SaveConfig()
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
                    bv.MaxForce  = Vector3.new(1e5,1e5,1e5)
                    bv.Parent    = hrp
                    local bg = Instance.new("BodyGyro")
                    bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
                    bg.P         = 1e4
                    bg.CFrame    = hrp.CFrame
                    bg.Parent    = hrp
                    while State.FlyRunning do
                        task.wait()
                        if not hrp or not hrp.Parent then break end
                        local dir = Vector3.zero
                        local cf  = Camera.CFrame
                        if UserInputService:IsKeyDown(Enum.KeyCode.W)           then dir+=cf.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S)           then dir-=cf.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A)           then dir-=cf.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D)           then dir+=cf.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir+=Vector3.new(0,1,0) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.new(0,1,0) end
                        bv.Velocity = (dir.Magnitude>0 and dir.Unit or Vector3.zero)*Config.FlySpeed
                        bg.CFrame   = cf
                    end
                    pcall(function() bv:Destroy() end)
                    pcall(function() bg:Destroy() end)
                    if hum then hum.PlatformStand=false end
                end)
            else
                State.FlyRunning=false
                local char=GetCharacter()
                if char then
                    local hum=char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.PlatformStand=false end
                    local hrp=char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local b1=hrp:FindFirstChildOfClass("BodyVelocity")
                        local b2=hrp:FindFirstChildOfClass("BodyGyro")
                        if b1 then b1:Destroy() end
                        if b2 then b2:Destroy() end
                    end
                end
            end
        end,
    })
    TabPlayer:CreateSlider({
        Name="Fly Speed", Range={1,300}, Increment=1, CurrentValue=Config.FlySpeed,
        Callback=function(val) Config.FlySpeed=val SaveConfig() end,
    })

    TabPlayer:CreateSection("NoClip")
    TabPlayer:CreateToggle({
        Name="Enable NoClip", CurrentValue=Config.NoClipEnabled,
        Callback=function(val)
            Config.NoClipEnabled=val State.NoClipRunning=val SaveConfig()
            if val then
                task.spawn(function()
                    local conn=RunService.Stepped:Connect(function()
                        if not State.NoClipRunning then return end
                        local char=GetCharacter()
                        if not char then return end
                        for _,p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide=false end
                        end
                    end)
                    while State.NoClipRunning do task.wait(0.05) end
                    conn:Disconnect()
                    local char=GetCharacter()
                    if char then
                        for _,p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide=true end
                        end
                    end
                end)
            end
        end,
    })

    TabPlayer:CreateSection("Anti-AFK")
    TabPlayer:CreateToggle({
        Name="Enable Anti-AFK", CurrentValue=Config.AntiAFKEnabled,
        Callback=function(val)
            Config.AntiAFKEnabled=val State.AntiAFKRunning=val SaveConfig()
            if val then
                task.spawn(function()
                    local VU=game:GetService("VirtualUser")
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

    task.spawn(function() task.wait(0.5) ApplySpeed() ApplyJump() end)
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        local h=char:WaitForChild("Humanoid",5)
        if not h then return end
        if Config.SpeedEnabled then h.WalkSpeed=Config.SpeedValue end
        if Config.JumpEnabled  then h.JumpPower=Config.JumpValue h.JumpHeight=Config.JumpValue*0.04 end
    end)
end

-- ============================================================
-- COMBAT
-- ============================================================
do
    TabCombat:CreateSection("Omni Portal")
    TabCombat:CreateButton({
        Name="Delete Ruins Portal",
        Callback=function()
            local ok,err=pcall(function()
                local portal=Workspace:FindFirstChild("Ruins Portal")
                if portal then
                    portal:Destroy()
                    Notify("Portal Deleted","Ruins Portal removed.",3)
                else
                    Notify("Not Found","Ruins Portal not in Workspace.",3)
                end
            end)
            if not ok then Notify("Error",tostring(err),4) end
        end,
    })

    TabCombat:CreateSection("Secondary GUI")
    TabCombat:CreateLabel("Принудительно показывает SecondaryGUI.")

    local SecondaryConn      = nil
    local SecondaryLoopAlive = false

    local function StartSecondaryGUI()
        State.SecondaryGUIRunning=true SecondaryLoopAlive=true
        task.spawn(function()
            local playerGui=LocalPlayer:WaitForChild("PlayerGui",10)
            if not playerGui then
                Notify("SecondaryGUI","PlayerGui не найден.",4)
                State.SecondaryGUIRunning=false SecondaryLoopAlive=false return
            end
            local secondaryGUI=playerGui:WaitForChild("SecondaryGUI",10)
            if not secondaryGUI then
                Notify("SecondaryGUI","SecondaryGUI не найден.",4)
                State.SecondaryGUIRunning=false SecondaryLoopAlive=false return
            end
            pcall(function() secondaryGUI.Enabled=true end)
            SecondaryConn=secondaryGUI:GetPropertyChangedSignal("Enabled"):Connect(function()
                if State.SecondaryGUIRunning and not secondaryGUI.Enabled then
                    pcall(function() secondaryGUI.Enabled=true end)
                end
            end)
            while SecondaryLoopAlive do
                task.wait(1)
                if State.SecondaryGUIRunning then
                    pcall(function() if not secondaryGUI.Enabled then secondaryGUI.Enabled=true end end)
                end
            end
        end)
    end

    local function StopSecondaryGUI()
        State.SecondaryGUIRunning=false SecondaryLoopAlive=false
        if SecondaryConn then SecondaryConn:Disconnect() SecondaryConn=nil end
    end

    TabCombat:CreateToggle({
        Name="Secondary GUI Visible", CurrentValue=Config.SecondaryGUIEnabled,
        Callback=function(val)
            Config.SecondaryGUIEnabled=val SaveConfig()
            if val then StartSecondaryGUI() Notify("SecondaryGUI","Включено.",3)
            else StopSecondaryGUI() Notify("SecondaryGUI","Отключено.",2) end
        end,
    })

    TabCombat:CreateSection("Hitbox Expander")
    TabCombat:CreateLabel("Авто-определяет меч (Tool с Handle).")

    local OriginalSizes={}

    local function FindSwordHandle()
        local char=GetCharacter()
        local bp=LocalPlayer:FindFirstChild("Backpack")
        if char then
            for _,tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    local handle=tool:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then return handle,tool end
                end
            end
        end
        if bp then
            for _,tool in ipairs(bp:GetChildren()) do
                if tool:IsA("Tool") then
                    local handle=tool:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then return handle,tool end
                end
            end
        end
        return nil,nil
    end

    local function ApplyHitbox(handle,size)
        if not handle or not handle.Parent then return end
        if not OriginalSizes[handle] then OriginalSizes[handle]=handle.Size end
        local s=size or Config.HitboxSize
        for _,child in ipairs(handle:GetChildren()) do
            if child:IsA("SpecialMesh") or child:IsA("BlockMesh") or child:IsA("CylinderMesh") then
                pcall(function() child:Destroy() end)
            end
        end
        pcall(function() handle.Massless=true end)
        pcall(function() handle.Transparency=1 handle.CastShadow=false end)
        pcall(function() handle.Size=Vector3.new(s,s,s) end)
    end

    local function RestoreHandle(handle)
        if not handle or not handle.Parent then return end
        local orig=OriginalSizes[handle]
        if orig then pcall(function() handle.Size=orig end) end
        pcall(function() handle.Transparency=0 handle.CastShadow=true handle.Massless=false end)
    end

    local HitboxConn=nil

    local function StartHitbox()
        State.HitboxRunning=true
        HitboxConn=RunService.Heartbeat:Connect(function()
            if not State.HitboxRunning then return end
            local handle=FindSwordHandle()
            if handle then ApplyHitbox(handle,Config.HitboxSize) end
        end)
    end

    local function StopHitbox()
        State.HitboxRunning=false
        if HitboxConn then HitboxConn:Disconnect() HitboxConn=nil end
        for handle in pairs(OriginalSizes) do RestoreHandle(handle) end
        OriginalSizes={}
    end

    TabCombat:CreateToggle({
        Name="Enable Hitbox Expander", CurrentValue=Config.HitboxEnabled,
        Callback=function(val)
            Config.HitboxEnabled=val SaveConfig()
            if val then
                StartHitbox()
                Notify("Hitbox Expander","Активен. Размер: "..Config.HitboxSize,3)
            else
                StopHitbox()
                Notify("Hitbox Expander","Выключен и восстановлен.",3)
            end
        end,
    })
    TabCombat:CreateSlider({
        Name="Hitbox Size", Range={1,5000}, Increment=1, Suffix=" studs", CurrentValue=Config.HitboxSize,
        Callback=function(val)
            Config.HitboxSize=val SaveConfig()
            if State.HitboxRunning then
                local handle=FindSwordHandle()
                if handle then ApplyHitbox(handle,val) end
            end
        end,
    })
    TabCombat:CreateButton({
        Name="Apply Hitbox Now",
        Callback=function()
            local handle,tool=FindSwordHandle()
            if handle then
                ApplyHitbox(handle,Config.HitboxSize)
                Notify("Hitbox Applied",(tool and tool.Name or "?").." → "..Config.HitboxSize.." studs",3)
            else
                Notify("Не найден","Возьмите оружие с Handle.",3)
            end
        end,
    })
    TabCombat:CreateButton({
        Name="Restore Hitbox",
        Callback=function()
            local handle=FindSwordHandle()
            if handle then
                RestoreHandle(handle) OriginalSizes[handle]=nil
                Notify("Восстановлен","Handle сброшен.",3)
            else
                Notify("Не найден","Нечего восстанавливать.",3)
            end
        end,
    })

    LocalPlayer.CharacterAdded:Connect(function()
        if Config.HitboxEnabled and not State.HitboxRunning then task.wait(1) StartHitbox() end
        if Config.SecondaryGUIEnabled and not State.SecondaryGUIRunning then StartSecondaryGUI() end
    end)
end

-- ============================================================
-- EVENTS
-- ============================================================
do
    TabEvents:CreateSection("Cake Prompt Protection")
    TabEvents:CreateToggle({
        Name="Enable Prompt Protection", CurrentValue=Config.CakePromptEnabled,
        Callback=function(val)
            Config.CakePromptEnabled=val State.CakePromptLoopRunning=val SaveConfig()
            if val then
                task.spawn(function()
                    local function ensureEnabled()
                        pcall(function()
                            local cake=Workspace:FindFirstChild("Cake")
                            if not cake then return end
                            local info=cake:FindFirstChild("InfoPart")
                            if not info then return end
                            local att=info:FindFirstChild("Attachment")
                            if not att then return end
                            local prompt=att:FindFirstChild("ProximityPrompt")
                            if prompt then prompt.Enabled=true end
                        end)
                    end
                    pcall(function()
                        local prompt=Workspace
                            :WaitForChild("Cake",10)
                            :WaitForChild("InfoPart",10)
                            :WaitForChild("Attachment",10)
                            :WaitForChild("ProximityPrompt",10)
                        if prompt then
                            prompt.Enabled=true
                            prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                                if Config.CakePromptEnabled and not prompt.Enabled then
                                    prompt.Enabled=true
                                end
                            end)
                        end
                    end)
                    while State.CakePromptLoopRunning do
                        task.wait(Config.CakeInterval) ensureEnabled()
                    end
                end)
            end
        end,
    })
    TabEvents:CreateSlider({
        Name="Check Interval (s)", Range={0.5,10}, Increment=0.5, Suffix="s", CurrentValue=Config.CakeInterval,
        Callback=function(val) Config.CakeInterval=val SaveConfig() end,
    })

    TabEvents:CreateSection("Fire Cake Prompt")
    TabEvents:CreateSlider({
        Name="Fire Count", Range={100,50000}, Increment=100, Suffix="x", CurrentValue=Config.CakeFireCount,
        Callback=function(val) Config.CakeFireCount=val SaveConfig() end,
    })
    TabEvents:CreateToggle({
        Name="Auto Cakes", CurrentValue=Config.AutoCakesEnabled,
        Callback=function(val) Config.AutoCakesEnabled=val State.AutoCakesRunning=val SaveConfig() end,
    })
    local function FireCakes()
        task.spawn(function()
            local ok,err=pcall(function()
                local prompt=Workspace
                    :WaitForChild("Cake",5)
                    :WaitForChild("InfoPart",5)
                    :WaitForChild("Attachment",5)
                    :WaitForChild("ProximityPrompt",5)
                if not prompt then Notify("Error","ProximityPrompt not found.",3) return end
                for _=1,Config.CakeFireCount do
                    prompt:InputHoldBegin(Enum.KeyCode.Unknown)
                    prompt:InputHoldEnd(Enum.KeyCode.Unknown)
                end
                Notify("Cakes","Fired "..Config.CakeFireCount.."x",3)
            end)
            if not ok then Notify("Error",tostring(err),4) end
        end)
    end
    TabEvents:CreateButton({ Name="Fire Cake Prompt", Callback=FireCakes })

    TabEvents:CreateSection("Auto Hakari")
    TabEvents:CreateToggle({
        Name="Enable Auto Hakari", CurrentValue=Config.AutoHakariEnabled,
        Callback=function(val)
            Config.AutoHakariEnabled=val State.AutoHakariRunning=val SaveConfig()
            if val then
                task.spawn(function()
                    local EquipEv=ReplicatedStorage:FindFirstChild("EquipSecondary")
                    if not EquipEv then
                        Notify("Hakari","EquipSecondary not found!",5)
                        State.AutoHakariRunning=false Config.AutoHakariEnabled=false SaveConfig() return
                    end
                    local function log(m) print(("[%s][Hakari] %s"):format(os.date("%H:%M:%S"),tostring(m))) end
                    local function FindBag()
                        local char=LocalPlayer.Character
                        if char and char:FindFirstChild("Candy Bag") then return char:FindFirstChild("Candy Bag"),"character" end
                        local bp=LocalPlayer:FindFirstChild("Backpack")
                        if bp and bp:FindFirstChild("Candy Bag") then return bp:FindFirstChild("Candy Bag"),"backpack" end
                        return nil,"none"
                    end
                    local function WaitTooltip(bag,cond,timeout)
                        if not bag or not bag.Parent then return false end
                        local done=false local conn local s=tick()
                        conn=bag:GetPropertyChangedSignal("ToolTip"):Connect(function()
                            if cond(bag.ToolTip or "") then done=true if conn.Connected then conn:Disconnect() end end
                        end)
                        repeat task.wait(0.05)
                        until done or not State.AutoHakariRunning or not bag.Parent or (tick()-s>(timeout or 10))
                        if conn and conn.Connected then conn:Disconnect() end
                        return done
                    end
                    local function HandleLife()
                        log("New life")
                        local char=LocalPlayer.Character if not char then return end
                        local hum=char:WaitForChild("Humanoid",5)
                        if not hum or hum.Health<=0 then return end
                        local alive=true local dc=hum.Died:Connect(function() alive=false end)
                        if State.AutoHakariRunning and alive then EquipEv:FireServer("Candy Bag") log("Requested Candy Bag")
                        else dc:Disconnect() return end
                        local bag,loc local ws=tick()
                        repeat task.wait(0.07) bag,loc=FindBag()
                        until not State.AutoHakariRunning or not alive or bag or (tick()-ws>6)
                        if not(bag and State.AutoHakariRunning and alive) then log("No bag") dc:Disconnect() return end
                        log("Bag from: "..loc)
                        while State.AutoHakariRunning and alive do
                            bag,loc=FindBag() if not bag then break end
                            if loc=="backpack" then hum:EquipTool(bag) task.wait(0.2)
                            elseif loc=="character" then
                                bag:Activate() task.wait(0.25)
                                local tt=bag.ToolTip or ""
                                if tt:find("160%%") then bag:Activate() task.wait(1.5) break
                                elseif tt:find("On Cooldown") then WaitTooltip(bag,function(t) return not t:find("On Cooldown") end,15)
                                elseif tt:find("%%") then local old=tt WaitTooltip(bag,function(t) return t~=old end,8)
                                else task.wait(0.3) end
                            else task.wait(0.3) end
                        end
                        dc:Disconnect() log("Life ended")
                    end
                    if not State.HakariMainLoopRunning then
                        State.HakariMainLoopRunning=true
                        if LocalPlayer.Character then task.spawn(function() pcall(HandleLife) end) end
                        local cc=LocalPlayer.CharacterAdded:Connect(function()
                            if not State.AutoHakariRunning then return end
                            task.wait(0.05) pcall(HandleLife)
                        end)
                        while State.AutoHakariRunning do task.wait(1) end
                        cc:Disconnect() State.HakariMainLoopRunning=false log("Loop stopped")
                    end
                end)
                Notify("Auto Hakari","Started.",3)
            else
                State.AutoHakariRunning=false
                Notify("Auto Hakari","Stopped.",2)
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
        Name="Enable Webhook Blocker", CurrentValue=Config.WebhookBlockEnabled,
        Callback=function(val)
            Config.WebhookBlockEnabled=val SaveConfig()
            if val and not State.WebhookHooked then
                State.WebhookHooked=true
                task.spawn(function()
                    local reqFunc=http_request or request or (syn and syn.request)
                    if not reqFunc then Notify("Webhook","No request function.",4) return end
                    local logFile=("wh_log_%d_%.0f.txt"):format(LocalPlayer.UserId,tick())
                    local orig=reqFunc
                    local success=pcall(function()
                        reqFunc=hookfunction(reqFunc,newcclosure(function(data)
                            if not Config.WebhookBlockEnabled then return orig(data) end
                            local url=tostring(data.Url or "")
                            local low=url:lower()
                            if low:find("discord") and (low:find("webhook") or low:find("websec")) then
                                pcall(function() rconsoleprint("BLOCKED: "..url.."\n") end)
                                pcall(function() writefile(logFile,"Webhook: "..url.."\nBody: "..tostring(data.Body or "nil")) end)
                                if Config.WebhookDelete then
                                    pcall(function() orig({Url=url,Method="DELETE",Headers={["Content-Type"]="application/json"}}) end)
                                end
                                Notify("Webhook Blocked",url:sub(1,50),4)
                                return
                            end
                            return orig(data)
                        end))
                    end)
                    if not success then Notify("Webhook","hookfunction not supported.",4) end
                end)
            end
            Notify("Webhook Blocker",val and "Active" or "Disabled.",3)
        end,
    })
    TabWebhook:CreateToggle({
        Name="Delete Webhook on Block", CurrentValue=Config.WebhookDelete,
        Callback=function(val) Config.WebhookDelete=val SaveConfig() end,
    })

    TabWebhook:CreateSection("Universal Viewer")
    TabWebhook:CreateButton({
        Name="Load Universal Viewer",
        Callback=function()
            task.spawn(function()
                local ok,err=pcall(function()
                    loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/sinret/rbxscript.com-scripts-reuploads-/main/UNVIew",true
                    ))()
                end)
                Notify("Universal Viewer",ok and "Loaded." or "Error: "..tostring(err),ok and 3 or 5)
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
        Name="Print States",
        Callback=function()
            print("=== STATES ===")
            for k,v in pairs(State) do print(k.." = "..tostring(v)) end
            print("=== CONFIG ===")
            for k,v in pairs(Config) do print(k.." = "..(type(v)=="table" and "[table]" or tostring(v))) end
            Notify("Debug","Printed to console.",2)
        end,
    })
    TabUtils:CreateButton({
        Name="Executor Features",
        Callback=function()
            local list={
                "hookfunction: "      ..tostring(hookfunction      ~=nil),
                "getrawmetatable: "   ..tostring(getrawmetatable   ~=nil),
                "sethiddenproperty: " ..tostring(sethiddenproperty ~=nil),
                "Drawing: "           ..tostring(Drawing           ~=nil),
                "isfile: "            ..tostring(isfile            ~=nil),
                "writefile: "         ..tostring(writefile         ~=nil),
            }
            print("=== EXECUTOR ===")
            for _,f in ipairs(list) do print(f) end
            Notify("Executor","Printed to console.",3)
        end,
    })
    TabUtils:CreateSection("Info")
    TabUtils:CreateLabel("KSFB Hub | RightShift = Toggle GUI")
end

-- ============================================================
-- INIT
-- ============================================================
Notify("KSFB Hub","Loaded! Players: "..#Players:GetPlayers(),4)
LocalPlayer.AncestryChanged:Connect(function() SaveConfig() end)
print("KSFB Hub loaded.")
