--[[
    NOVA v5 — Universal GUI
    50+ Features · Clean UI · Radar Minimap
    Toggle: RightCtrl
]]

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local WS = game:GetService("Workspace")
local TPS = game:GetService("TeleportService")
local HTTP = game:GetService("HttpService")
local Cam = WS.CurrentCamera
WS:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Cam = WS.CurrentCamera or WS:FindFirstChildOfClass("Camera")
end)
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()


----------------------------------------------------------------
-- SAFE CLEANUP
----------------------------------------------------------------
if CoreGui:FindFirstChild("Nova5") then CoreGui.Nova5:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "Nova5"; Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.ResetOnSpawn = false; Gui.IgnoreGuiInset = false
pcall(function() Gui.Parent = CoreGui end)
if not Gui.Parent then Gui.Parent = LP:WaitForChild("PlayerGui") end

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local On = {}   -- boolean toggles
local Val = {   -- numeric values
    Speed = 16, Jump = 50, FlySpd = 60,
    FOV = 150, HBSize = 10, AimSmooth = 5,
    Grav = 196, CamFOV = 70, TPDist = 12,
    PlatSize = 8, HeadMul = 1, RadarRange = 200,
    OrbitRad = 15, OrbitSpd = 2, AutoClickSpd = 10,
    ZoomFOV = 15, CarpetH = 5, JumpHeight = 7.2, HipHeight = 2,
    MeleeRange = 15, BhopSpeedMul = 1.0, CrosshairDecal = "", ChatSpamText = "Nova Script",
}
local Conn = {} -- connections (always checked before disconnect)
local ESPCache = {}
local TracerDraw = {}
local CrosshairDraw = {}
local FOVDraw = nil
local RadarDots = {}
local GhostParts = {} -- ghost replay
local HeadDotDraw = {}
local tBtns = {}
local tPages = {}
local curTab = nil

-- Safe disconnect helper
local function disconn(key)
    if Conn[key] then
        pcall(function() Conn[key]:Disconnect() end)
        Conn[key] = nil
    end
end

----------------------------------------------------------------
-- PALETTE
----------------------------------------------------------------
local P = {
    bg        = Color3.fromRGB(11, 11, 16),
    bg2       = Color3.fromRGB(15, 15, 21),
    card      = Color3.fromRGB(20, 20, 28),
    cardH     = Color3.fromRGB(26, 26, 36),
    cardA     = Color3.fromRGB(32, 32, 44),

    accent    = Color3.fromRGB(99, 102, 241),
    accentL   = Color3.fromRGB(129, 132, 255),
    green     = Color3.fromRGB(34, 197, 94),
    red       = Color3.fromRGB(239, 68, 68),
    amber     = Color3.fromRGB(245, 158, 11),
    cyan      = Color3.fromRGB(6, 182, 212),

    text      = Color3.fromRGB(235, 235, 245),
    text2     = Color3.fromRGB(148, 148, 172),
    text3     = Color3.fromRGB(80, 80, 105),

    border    = Color3.fromRGB(32, 32, 44),
    tOff      = Color3.fromRGB(38, 38, 52),
}

local Themes = {
    Indigo = { accent = Color3.fromRGB(99, 102, 241), accentL = Color3.fromRGB(129, 132, 255) },
    Emerald = { accent = Color3.fromRGB(16, 185, 129), accentL = Color3.fromRGB(52, 211, 153) },
    Ruby = { accent = Color3.fromRGB(239, 68, 68), accentL = Color3.fromRGB(248, 113, 113) },
    Amber = { accent = Color3.fromRGB(245, 158, 11), accentL = Color3.fromRGB(251, 191, 36) },
    Turquoise = { accent = Color3.fromRGB(6, 182, 212), accentL = Color3.fromRGB(34, 211, 238) },
    Pink = { accent = Color3.fromRGB(236, 72, 153), accentL = Color3.fromRGB(244, 114, 182) }
}
local ThemeObjects = {}
local function regTheme(obj, prop, ctype, cond, fallback)
    table.insert(ThemeObjects, {obj = obj, prop = prop, ctype = ctype, cond = cond, fallback = fallback})
end
local function setTheme(name)
    local t = Themes[name]
    if t then
        P.accent = t.accent
        P.accentL = t.accentL
        for _, item in ipairs(ThemeObjects) do
            pcall(function()
                if item.cond then
                    if item.cond() then
                        item.obj[item.prop] = (item.ctype == "accent") and P.accent or P.accentL
                    else
                        item.obj[item.prop] = item.fallback
                    end
                else
                    item.obj[item.prop] = (item.ctype == "accent") and P.accent or P.accentL
                end
            end)
        end
    end
end

----------------------------------------------------------------
-- TWEEN
----------------------------------------------------------------
local function tw(inst, props, dur, style)
    local t = TS:Create(inst, TweenInfo.new(dur or 0.18, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play(); return t
end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function chr() return LP.Character or LP.CharacterAdded:Wait() end
local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function rootp()
    local c = LP.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

----------------------------------------------------------------
-- TOAST NOTIFICATIONS (minimal)
----------------------------------------------------------------
local ToastBox = Instance.new("Frame", Gui)
ToastBox.Size = UDim2.new(0, 250, 1, -16)
ToastBox.Position = UDim2.new(1, -258, 0, 8)
ToastBox.BackgroundTransparency = 1; ToastBox.ZIndex = 200

local TLayout = Instance.new("UIListLayout", ToastBox)
TLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
TLayout.Padding = UDim.new(0, 5); TLayout.SortOrder = Enum.SortOrder.LayoutOrder

local tN = 0
local function toast(title, body, dur, kind)
    tN += 1; dur = dur or 3
    local col = P.accent
    if kind == "ok" then col = P.green elseif kind == "err" then col = P.red elseif kind == "warn" then col = P.amber end

    local f = Instance.new("Frame", ToastBox)
    f.Size = UDim2.new(1, 0, 0, 48); f.BackgroundColor3 = P.card
    f.BorderSizePixel = 0; f.LayoutOrder = tN; f.ZIndex = 200; f.ClipsDescendants = true
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", f); s.Color = P.border; s.Thickness = 1; s.Transparency = 0.3

    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(0, 2, 0.6, 0); bar.Position = UDim2.new(0, 5, 0.2, 0)
    bar.BackgroundColor3 = col; bar.BorderSizePixel = 0; bar.ZIndex = 201
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local tl = Instance.new("TextLabel", f)
    tl.Size = UDim2.new(1, -22, 0, 15); tl.Position = UDim2.new(0, 16, 0, 7)
    tl.BackgroundTransparency = 1; tl.Text = title or "Nova"
    tl.TextColor3 = P.text; tl.TextSize = 11; tl.Font = Enum.Font.GothamBold
    tl.TextXAlignment = Enum.TextXAlignment.Left; tl.ZIndex = 201
    tl.TextTruncate = Enum.TextTruncate.AtEnd

    local bl = Instance.new("TextLabel", f)
    bl.Size = UDim2.new(1, -22, 0, 13); bl.Position = UDim2.new(0, 16, 0, 24)
    bl.BackgroundTransparency = 1; bl.Text = body or ""
    bl.TextColor3 = P.text2; bl.TextSize = 10; bl.Font = Enum.Font.Gotham
    bl.TextXAlignment = Enum.TextXAlignment.Left; bl.ZIndex = 201
    bl.TextTruncate = Enum.TextTruncate.AtEnd

    local pg = Instance.new("Frame", f)
    pg.Size = UDim2.new(1, 0, 0, 2); pg.Position = UDim2.new(0, 0, 1, -2)
    pg.BackgroundColor3 = col; pg.BorderSizePixel = 0; pg.ZIndex = 202; pg.BackgroundTransparency = 0.5

    f.Position = UDim2.new(1.05, 0, 0, 0)
    tw(f, {Position = UDim2.new(0, 0, 0, 0)}, 0.3, Enum.EasingStyle.Back)
    tw(pg, {Size = UDim2.new(0, 0, 0, 2)}, dur, Enum.EasingStyle.Linear)
    task.delay(dur, function()
        tw(f, {Position = UDim2.new(1.05, 0, 0, 0)}, 0.25)
        task.delay(0.3, function() f:Destroy() end)
    end)
end

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------
local WW, WH = 550, 440
local origSize = UDim2.fromOffset(WW, WH)
local origPos = UDim2.new(0.5, -WW/2, 0.5, -WH/2)

local Win = Instance.new("Frame", Gui)
Win.Name = "Win"; Win.Size = origSize; Win.Position = origPos
Win.BackgroundColor3 = P.bg; Win.BorderSizePixel = 0; Win.ZIndex = 5; Win.ClipsDescendants = true
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 12)
local winStroke = Instance.new("UIStroke", Win)
winStroke.Color = P.border; winStroke.Thickness = 1

----------------------------------------------------------------
-- TITLE BAR
----------------------------------------------------------------
local TBar = Instance.new("Frame", Win)
TBar.Size = UDim2.new(1, 0, 0, 38); TBar.BackgroundTransparency = 1; TBar.ZIndex = 20

-- separator
local tsep = Instance.new("Frame", TBar)
tsep.Size = UDim2.new(1, -20, 0, 1); tsep.Position = UDim2.new(0, 10, 1, 0)
tsep.BackgroundColor3 = P.border; tsep.BorderSizePixel = 0; tsep.BackgroundTransparency = 0.5; tsep.ZIndex = 20

-- accent dot
local adot = Instance.new("Frame", TBar)
adot.Size = UDim2.fromOffset(7, 7); adot.Position = UDim2.new(0, 14, 0.5, -3)
adot.BackgroundColor3 = P.accent; adot.BorderSizePixel = 0; adot.ZIndex = 21
Instance.new("UICorner", adot).CornerRadius = UDim.new(1, 0)
regTheme(adot, "BackgroundColor3", "accent")

local tTitle = Instance.new("TextLabel", TBar)
tTitle.Size = UDim2.new(0, 60, 1, 0); tTitle.Position = UDim2.new(0, 28, 0, 0)
tTitle.BackgroundTransparency = 1; tTitle.Text = "Nova"; tTitle.TextColor3 = P.text
tTitle.TextSize = 14; tTitle.Font = Enum.Font.GothamBold
tTitle.TextXAlignment = Enum.TextXAlignment.Left; tTitle.ZIndex = 21

local tVer = Instance.new("TextLabel", TBar)
tVer.Size = UDim2.new(0, 20, 1, 0); tVer.Position = UDim2.new(0, 62, 0, 1)
tVer.BackgroundTransparency = 1; tVer.Text = "v5"; tVer.TextColor3 = P.text3
tVer.TextSize = 10; tVer.Font = Enum.Font.Gotham
tVer.TextXAlignment = Enum.TextXAlignment.Left; tVer.ZIndex = 21

-- Active features counter badge
local activeBadge = Instance.new("Frame", TBar)
activeBadge.Size = UDim2.fromOffset(22, 16)
activeBadge.Position = UDim2.new(0, 86, 0.5, -8)
activeBadge.BackgroundColor3 = P.accent; activeBadge.BackgroundTransparency = 0.85
activeBadge.BorderSizePixel = 0; activeBadge.ZIndex = 21
Instance.new("UICorner", activeBadge).CornerRadius = UDim.new(0, 4)
regTheme(activeBadge, "BackgroundColor3", "accent")

local activeCount = Instance.new("TextLabel", activeBadge)
activeCount.Size = UDim2.new(1, 0, 1, 0); activeCount.BackgroundTransparency = 1
activeCount.Text = "0"; activeCount.TextColor3 = P.accentL; activeCount.TextSize = 10
activeCount.Font = Enum.Font.GothamBold; activeCount.ZIndex = 22
regTheme(activeCount, "TextColor3", "accentL")

local function updateActiveCount()
    local c = 0
    for _, v in pairs(On) do if v then c += 1 end end
    activeCount.Text = tostring(c)
end

-- window circles
local function circBtn(x, col, cb)
    local b = Instance.new("TextButton", TBar)
    b.Size = UDim2.fromOffset(11, 11); b.Position = UDim2.new(1, x, 0.5, -5)
    b.BackgroundColor3 = col; b.Text = ""; b.BorderSizePixel = 0
    b.ZIndex = 22; b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    b.MouseEnter:Connect(function() tw(b, {Size = UDim2.fromOffset(13, 13)}, 0.1) end)
    b.MouseLeave:Connect(function() tw(b, {Size = UDim2.fromOffset(11, 11)}, 0.1) end)
    b.MouseButton1Click:Connect(cb)
    return b
end

local bClose = circBtn(-18, P.red, function() end)
local bMin = circBtn(-34, P.amber, function() end)
local bPin = circBtn(-50, P.green, function() toast("Pinned", "Window pinned", 2) end)

-- drag
local dragging, dragIn, dragSt, posSt
TBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragSt = i.Position; posSt = Win.Position
        i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
TBar.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement then dragIn = i end end)
UIS.InputChanged:Connect(function(i)
    if i == dragIn and dragging then
        local d = i.Position - dragSt
        Win.Position = UDim2.new(posSt.X.Scale, posSt.X.Offset + d.X, posSt.Y.Scale, posSt.Y.Offset + d.Y)
    end
end)

----------------------------------------------------------------
-- SIDEBAR
----------------------------------------------------------------
local SBW = 115
local SB = Instance.new("Frame", Win)
SB.Size = UDim2.new(0, SBW, 1, -39); SB.Position = UDim2.new(0, 0, 0, 39)
SB.BackgroundColor3 = P.bg2; SB.BorderSizePixel = 0; SB.ZIndex = 10

local sbLine = Instance.new("Frame", SB)
sbLine.Size = UDim2.new(0, 1, 1, -12); sbLine.Position = UDim2.new(1, 0, 0, 6)
sbLine.BackgroundColor3 = P.border; sbLine.BorderSizePixel = 0; sbLine.BackgroundTransparency = 0.5; sbLine.ZIndex = 11

local tabFrame = Instance.new("Frame", SB)
tabFrame.Size = UDim2.new(1, -10, 1, -10); tabFrame.Position = UDim2.new(0, 5, 0, 6)
tabFrame.BackgroundTransparency = 1; tabFrame.ZIndex = 11
Instance.new("UIListLayout", tabFrame).Padding = UDim.new(0, 1)

-- search bar
local SearchFrame = Instance.new("Frame", Win)
SearchFrame.Size = UDim2.new(1, -SBW - 14, 0, 26)
SearchFrame.Position = UDim2.new(0, SBW + 7, 0, 44)
SearchFrame.BackgroundColor3 = P.card
SearchFrame.BorderSizePixel = 0
SearchFrame.ZIndex = 15
Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 6)
local sfSt = Instance.new("UIStroke", SearchFrame); sfSt.Color = P.border; sfSt.Thickness = 1; sfSt.Transparency = 0.3

local sIcon = Instance.new("TextLabel", SearchFrame)
sIcon.Size = UDim2.fromOffset(26, 26); sIcon.Position = UDim2.new(0, 6, 0, 0)
sIcon.BackgroundTransparency = 1; sIcon.Text = "🔍"; sIcon.TextColor3 = P.text3
sIcon.TextSize = 10; sIcon.Font = Enum.Font.Gotham; sIcon.ZIndex = 16

local sBox = Instance.new("TextBox", SearchFrame)
sBox.Size = UDim2.new(1, -40, 1, 0); sBox.Position = UDim2.new(0, 32, 0, 0)
sBox.BackgroundTransparency = 1; sBox.Text = ""; sBox.PlaceholderText = "Search features..."
sBox.TextColor3 = P.text; sBox.PlaceholderColor3 = P.text3; sBox.TextSize = 11
sBox.Font = Enum.Font.GothamSemibold; sBox.TextXAlignment = Enum.TextXAlignment.Left
sBox.ZIndex = 16

-- content
local Content = Instance.new("Frame", Win)
Content.Size = UDim2.new(1, -SBW - 1, 1, -76)
Content.Position = UDim2.new(0, SBW + 1, 0, 76)
Content.BackgroundTransparency = 1; Content.ClipsDescendants = true; Content.ZIndex = 10

local function filterFeatures(txt)
    local q = txt:lower()
    for _, pg in pairs(tPages) do
        for _, child in ipairs(pg:GetChildren()) do
            if child:IsA("Frame") then
                local lbl = child:FindFirstChildOfClass("TextLabel")
                if lbl then
                    local match = lbl.Text:lower():find(q, 1, true) ~= nil
                    if q == "" then
                        child.Visible = true
                    else
                        child.Visible = match
                    end
                end
            end
        end
    end
end
sBox:GetPropertyChangedSignal("Text"):Connect(function()
    filterFeatures(sBox.Text)
end)

----------------------------------------------------------------
-- TAB SYSTEM
----------------------------------------------------------------
local TABS = {
    {id="player",  name="Player",  o=1},
    {id="visuals", name="Visuals", o=2},
    {id="combat",  name="Combat",  o=3},
    {id="world",   name="World",   o=4},
    {id="teleport",name="Teleport",o=5},
    {id="fun",     name="Fun",     o=6},
    {id="radar",   name="Radar",   o=7},
    {id="misc",    name="Misc",    o=8},
}



local function goTab(id)
    if curTab == id then return end
    if curTab and tBtns[curTab] then
        tw(tBtns[curTab], {BackgroundTransparency = 1}, 0.12)
        tw(tBtns[curTab]:FindFirstChild("Lbl"), {TextColor3 = P.text2}, 0.12)
        local ind = tBtns[curTab]:FindFirstChild("Ind")
        if ind then tw(ind, {Size = UDim2.new(0, 2, 0, 0), BackgroundTransparency = 1}, 0.12) end
        if tPages[curTab] then tPages[curTab].Visible = false end
    end
    curTab = id
    if tBtns[id] then
        tw(tBtns[id], {BackgroundColor3 = P.cardA, BackgroundTransparency = 0.55}, 0.18)
        tw(tBtns[id]:FindFirstChild("Lbl"), {TextColor3 = P.text}, 0.18)
        local ind = tBtns[id]:FindFirstChild("Ind")
        if ind then tw(ind, {Size = UDim2.new(0, 2, 0.5, 0), BackgroundTransparency = 0}, 0.22, Enum.EasingStyle.Back) end
        if tPages[id] then tPages[id].Visible = true end
    end
end

for _, t in ipairs(TABS) do
    local btn = Instance.new("TextButton", tabFrame)
    btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = P.card
    btn.BackgroundTransparency = 1; btn.Text = ""; btn.BorderSizePixel = 0
    btn.ZIndex = 12; btn.LayoutOrder = t.o; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local ind = Instance.new("Frame", btn)
    ind.Name = "Ind"; ind.Size = UDim2.new(0, 2, 0, 0); ind.Position = UDim2.new(0, 1, 0.25, 0)
    ind.BackgroundColor3 = P.accent; ind.BorderSizePixel = 0; ind.BackgroundTransparency = 1; ind.ZIndex = 13
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    regTheme(ind, "BackgroundColor3", "accent")

    local lbl = Instance.new("TextLabel", btn)
    lbl.Name = "Lbl"; lbl.Size = UDim2.new(1, -14, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = t.name; lbl.TextColor3 = P.text2
    lbl.TextSize = 11; lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 13

    btn.MouseEnter:Connect(function() if curTab ~= t.id then tw(btn, {BackgroundTransparency = 0.8, BackgroundColor3 = P.cardH}, 0.1) end end)
    btn.MouseLeave:Connect(function() if curTab ~= t.id then tw(btn, {BackgroundTransparency = 1}, 0.1) end end)
    btn.MouseButton1Click:Connect(function() goTab(t.id) end)

    tBtns[t.id] = btn

    local pg = Instance.new("ScrollingFrame", Content)
    pg.Name = t.id; pg.Size = UDim2.new(1, 0, 1, 0); pg.BackgroundTransparency = 1
    pg.BorderSizePixel = 0; pg.ScrollBarThickness = 2; pg.ScrollBarImageColor3 = P.text3
    pg.ScrollBarImageTransparency = 0.5; pg.Visible = false; pg.ZIndex = 10
    pg.CanvasSize = UDim2.new(0,0,0,0); pg.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local pl = Instance.new("UIListLayout", pg)
    pl.Padding = UDim.new(0, 3); pl.SortOrder = Enum.SortOrder.LayoutOrder

    local pp = Instance.new("UIPadding", pg)
    pp.PaddingLeft = UDim.new(0, 6); pp.PaddingRight = UDim.new(0, 8)
    pp.PaddingTop = UDim.new(0, 4); pp.PaddingBottom = UDim.new(0, 8)

    tPages[t.id] = pg
end

----------------------------------------------------------------
-- COMPONENTS
----------------------------------------------------------------
local ord = 0
local function nxt() ord += 1; return ord end
local function rst() ord = 0 end

local function Section(parent, label)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 24); f.BackgroundTransparency = 1
    f.LayoutOrder = nxt(); f.ZIndex = 11

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -4, 1, 0); l.Position = UDim2.new(0, 4, 0, 0)
    l.BackgroundTransparency = 1; l.Text = string.upper(label)
    l.TextColor3 = P.text3; l.TextSize = 9; l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 12
end

local function Toggle(parent, label, key, cb)
    On[key] = On[key] or false

    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 32); f.BackgroundColor3 = P.card
    f.BorderSizePixel = 0; f.LayoutOrder = nxt(); f.ZIndex = 11
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -56, 1, 0); l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = P.text
    l.TextSize = 11; l.Font = Enum.Font.GothamSemibold
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 12

    local track = Instance.new("Frame", f)
    track.Size = UDim2.fromOffset(34, 17); track.Position = UDim2.new(1, -44, 0.5, -8)
    track.BackgroundColor3 = P.tOff; track.BorderSizePixel = 0; track.ZIndex = 12
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.fromOffset(13, 13); knob.Position = UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(190, 190, 200); knob.BorderSizePixel = 0; knob.ZIndex = 13
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function render()
        local on = On[key]
        tw(track, {BackgroundColor3 = on and P.accent or P.tOff}, 0.18)
        tw(knob, {
            Position = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
            BackgroundColor3 = on and Color3.new(1,1,1) or Color3.fromRGB(190,190,200),
        }, 0.22, Enum.EasingStyle.Back)
    end
    regTheme(track, "BackgroundColor3", "accent", function() return On[key] end, P.tOff)

    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 14

    btn.MouseEnter:Connect(function() tw(f, {BackgroundColor3 = P.cardH}, 0.1) end)
    btn.MouseLeave:Connect(function() tw(f, {BackgroundColor3 = P.card}, 0.1) end)

    btn.MouseButton1Click:Connect(function()
        On[key] = not On[key]; render(); updateActiveCount()
        if cb then cb(On[key]) end
    end)

    render()
end

local function Slider(parent, label, min, max, default, vKey, cb)
    Val[vKey] = Val[vKey] or default

    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 48); f.BackgroundColor3 = P.card
    f.BorderSizePixel = 0; f.LayoutOrder = nxt(); f.ZIndex = 11
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -44, 0, 16); l.Position = UDim2.new(0, 10, 0, 5)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = P.text
    l.TextSize = 11; l.Font = Enum.Font.GothamSemibold
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 12

    local vl = Instance.new("TextLabel", f)
    vl.Size = UDim2.new(0, 36, 0, 16); vl.Position = UDim2.new(1, -44, 0, 5)
    vl.BackgroundTransparency = 1; vl.Text = tostring(default)
    vl.TextColor3 = P.accent; vl.TextSize = 11; vl.Font = Enum.Font.GothamBold
    vl.TextXAlignment = Enum.TextXAlignment.Right; vl.ZIndex = 12
    regTheme(vl, "TextColor3", "accent")

    local track = Instance.new("Frame", f)
    track.Size = UDim2.new(1, -20, 0, 4); track.Position = UDim2.new(0, 10, 0, 32)
    track.BackgroundColor3 = P.tOff; track.BorderSizePixel = 0; track.ZIndex = 12
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = P.accent; fill.BorderSizePixel = 0; fill.ZIndex = 13
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    regTheme(fill, "BackgroundColor3", "accent")

    local kn = Instance.new("Frame", track)
    kn.Size = UDim2.fromOffset(10, 10)
    kn.Position = UDim2.new((default-min)/(max-min), -5, 0.5, -5)
    kn.BackgroundColor3 = Color3.new(1,1,1); kn.BorderSizePixel = 0; kn.ZIndex = 14
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1, 0)

    local sliding = false
    local hit = Instance.new("TextButton", f)
    hit.Size = UDim2.new(1, 0, 0, 20); hit.Position = UDim2.new(0, 0, 0, 26)
    hit.BackgroundTransparency = 1; hit.Text = ""; hit.ZIndex = 15

    local function upd(inp)
        local r = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max-min) * r)
        fill.Size = UDim2.new(r, 0, 1, 0)
        kn.Position = UDim2.new(r, -5, 0.5, -5)
        vl.Text = tostring(v); Val[vKey] = v
        if cb then cb(v) end
    end

    hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true; upd(i) end end)
    hit.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end end)
    UIS.InputChanged:Connect(function(i) if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i) end end)
end

local function Button(parent, label, cb, col)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 32); f.BackgroundColor3 = P.card
    f.BorderSizePixel = 0; f.LayoutOrder = nxt(); f.ZIndex = 11; f.ClipsDescendants = true
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -24, 1, 0); l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = P.text
    l.TextSize = 11; l.Font = Enum.Font.GothamSemibold
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 12

    local arr = Instance.new("TextLabel", f)
    arr.Size = UDim2.fromOffset(10, 32); arr.Position = UDim2.new(1, -18, 0, 0)
    arr.BackgroundTransparency = 1; arr.Text = "›"; arr.TextColor3 = col or P.text3
    arr.TextSize = 14; arr.Font = Enum.Font.GothamBold; arr.ZIndex = 12

    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 14

    btn.MouseEnter:Connect(function() tw(f, {BackgroundColor3 = P.cardH}, 0.08); tw(arr, {TextColor3 = col or P.accent}, 0.1) end)
    btn.MouseLeave:Connect(function() tw(f, {BackgroundColor3 = P.card}, 0.08); tw(arr, {TextColor3 = col or P.text3}, 0.1) end)
    btn.MouseButton1Click:Connect(function()
        tw(f, {BackgroundColor3 = P.cardA}, 0.05)
        task.delay(0.07, function() tw(f, {BackgroundColor3 = P.card}, 0.12) end)
        if cb then cb() end
    end)
end

local function TextBox(parent, label, placeholder, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 48); f.BackgroundColor3 = P.card
    f.BorderSizePixel = 0; f.LayoutOrder = nxt(); f.ZIndex = 11
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -20, 0, 16); l.Position = UDim2.new(0, 10, 0, 4)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = P.text
    l.TextSize = 11; l.Font = Enum.Font.GothamSemibold
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 12

    local bg = Instance.new("Frame", f)
    bg.Size = UDim2.new(1, -20, 0, 20); bg.Position = UDim2.new(0, 10, 0, 23)
    bg.BackgroundColor3 = P.tOff; bg.BorderSizePixel = 0; bg.ZIndex = 12
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

    local tb = Instance.new("TextBox", bg)
    tb.Size = UDim2.new(1, -10, 1, 0); tb.Position = UDim2.new(0, 5, 0, 0)
    tb.BackgroundTransparency = 1; tb.Text = ""; tb.PlaceholderText = placeholder
    tb.TextColor3 = P.text; tb.PlaceholderColor3 = P.text3; tb.TextSize = 10
    tb.Font = Enum.Font.Gotham; tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.ZIndex = 13

    tb.FocusLost:Connect(function(enter)
        if cb then cb(tb.Text) end
    end)
end

local function Note(parent, text)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 18); f.BackgroundTransparency = 1
    f.LayoutOrder = nxt(); f.ZIndex = 11

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -8, 1, 0); l.Position = UDim2.new(0, 6, 0, 0)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = P.text3
    l.TextSize = 9; l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 12; l.TextWrapped = true
end

local function Dropdown(parent, label, options, default, vKey, cb)
    Val[vKey] = Val[vKey] or default
    local col_h = 32
    local opt_h = 24
    local exp_h = col_h + (#options * opt_h) + 6

    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, col_h); f.BackgroundColor3 = P.card
    f.BorderSizePixel = 0; f.LayoutOrder = nxt(); f.ZIndex = 11; f.ClipsDescendants = true
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.5, -10, 0, col_h); l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = P.text
    l.TextSize = 11; l.Font = Enum.Font.GothamSemibold
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 12

    local selBtn = Instance.new("TextButton", f)
    selBtn.Size = UDim2.new(0.5, -16, 0, 22); selBtn.Position = UDim2.new(0.5, 4, 0, 5)
    selBtn.BackgroundColor3 = P.tOff; selBtn.BorderSizePixel = 0
    selBtn.Text = tostring(Val[vKey]); selBtn.TextColor3 = P.accentL
    selBtn.TextSize = 10; selBtn.Font = Enum.Font.GothamBold
    selBtn.ZIndex = 13; selBtn.AutoButtonColor = false
    Instance.new("UICorner", selBtn).CornerRadius = UDim.new(0, 5)
    regTheme(selBtn, "TextColor3", "accentL")

    local arrow = Instance.new("TextLabel", selBtn)
    arrow.Size = UDim2.fromOffset(10, 22); arrow.Position = UDim2.new(1, -14, 0, 0)
    arrow.BackgroundTransparency = 1; arrow.Text = "▾"; arrow.TextColor3 = P.text3
    arrow.TextSize = 10; arrow.Font = Enum.Font.GothamBold; arrow.ZIndex = 14

    local isOpen = false
    for i, opt in ipairs(options) do
        local ob = Instance.new("TextButton", f)
        ob.Size = UDim2.new(1, -20, 0, opt_h - 2); ob.Position = UDim2.new(0, 10, 0, col_h + (i-1) * opt_h + 2)
        ob.BackgroundColor3 = P.bg2; ob.BorderSizePixel = 0
        ob.Text = opt; ob.TextColor3 = P.text2; ob.TextSize = 10
        ob.Font = Enum.Font.GothamSemibold; ob.ZIndex = 13; ob.AutoButtonColor = false
        Instance.new("UICorner", ob).CornerRadius = UDim.new(0, 5)
        ob.MouseEnter:Connect(function() tw(ob, {BackgroundColor3 = P.cardH, TextColor3 = P.text}, 0.08) end)
        ob.MouseLeave:Connect(function() tw(ob, {BackgroundColor3 = P.bg2, TextColor3 = P.text2}, 0.08) end)
        ob.MouseButton1Click:Connect(function()
            Val[vKey] = opt; selBtn.Text = opt; isOpen = false
            tw(f, {Size = UDim2.new(1, 0, 0, col_h)}, 0.15, Enum.EasingStyle.Back)
            tw(arrow, {Rotation = 0}, 0.1)
            if cb then cb(opt) end
        end)
    end

    selBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            tw(f, {Size = UDim2.new(1, 0, 0, exp_h)}, 0.2, Enum.EasingStyle.Back)
            tw(arrow, {Rotation = 180}, 0.1)
        else
            tw(f, {Size = UDim2.new(1, 0, 0, col_h)}, 0.15, Enum.EasingStyle.Back)
            tw(arrow, {Rotation = 0}, 0.1)
        end
    end)

    f.MouseEnter:Connect(function() tw(f, {BackgroundColor3 = P.cardH}, 0.1) end)
    f.MouseLeave:Connect(function() tw(f, {BackgroundColor3 = P.card}, 0.1) end)
end

----------------------------------------------------------------
-- FEATURES (all robust with nil checks)
----------------------------------------------------------------

function fNoclip(on)
    if on then
        Conn.noclip = RS.Stepped:Connect(function()
            local c = LP.Character
            if c then for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
        end)
        toast("Noclip", "Walk through walls", 2, "ok")
    else disconn("noclip"); toast("Noclip", "Disabled", 1.5) end
end

local flyBV, flyBG
function fFly(on)
    if on then
        local r = rootp(); if not r then toast("Fly", "No character", 2, "err"); On.fly = false; return end
        flyBV = Instance.new("BodyVelocity", r); flyBV.MaxForce = Vector3.one * math.huge; flyBV.Velocity = Vector3.zero
        flyBG = Instance.new("BodyGyro", r); flyBG.MaxTorque = Vector3.one * math.huge; flyBG.P = 9e4
        Conn.fly = RS.RenderStepped:Connect(function()
            if not On.fly then return end
            local curR = rootp()
            if curR then
                if not flyBV or flyBV.Parent ~= curR or not flyBG or flyBG.Parent ~= curR then
                    pcall(function() if flyBV then flyBV:Destroy() end end)
                    pcall(function() if flyBG then flyBG:Destroy() end end)
                    flyBV = Instance.new("BodyVelocity", curR); flyBV.MaxForce = Vector3.one * math.huge; flyBV.Velocity = Vector3.zero
                    flyBG = Instance.new("BodyGyro", curR); flyBG.MaxTorque = Vector3.one * math.huge; flyBG.P = 9e4
                end
                flyBG.CFrame = Cam.CFrame
                local d = Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then d += Cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then d -= Cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then d -= Cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then d += Cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d -= Vector3.yAxis end
                flyBV.Velocity = d.Magnitude > 0 and d.Unit * Val.FlySpd or Vector3.zero
            end
        end)
        toast("Fly", "WASD + Space/Shift", 2, "ok")
    else
        disconn("fly")
        if flyBV then pcall(function() flyBV:Destroy() end); flyBV = nil end
        if flyBG then pcall(function() flyBG:Destroy() end); flyBG = nil end
        toast("Fly", "Disabled", 1.5)
    end
end

function fInfJump(on)
    if on then
        Conn.infjump = UIS.JumpRequest:Connect(function()
            if On.infjump then local h = hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
        end)
        toast("Infinite Jump", "Enabled", 2, "ok")
    else disconn("infjump"); toast("Infinite Jump", "Disabled", 1.5) end
end

function fGod(on)
    if on then
        local h = hum()
        if h then
            Conn.god = h.HealthChanged:Connect(function() if On.god then h.Health = h.MaxHealth end end)
        end
        toast("God Mode", "Client-side", 2, "ok")
    else disconn("god"); toast("God Mode", "Disabled", 1.5) end
end

function fSpeedHack(on)
    if on then
        Conn.sphack = RS.RenderStepped:Connect(function()
            if not On.sphack then return end
            local h, r = hum(), rootp()
            if h and r and h.MoveDirection.Magnitude > 0 then r.CFrame = r.CFrame + h.MoveDirection * (Val.Speed / 14) end
        end)
        toast("Speed Hack", "CFrame-based", 2, "ok")
    else disconn("sphack"); toast("Speed Hack", "Disabled", 1.5) end
end

function fClickTP(on)
    if on then
        Conn.ctp = Mouse.Button1Down:Connect(function()
            if On.ctp and Mouse.Target then local r = rootp(); if r then r.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0,3,0)) end end
        end)
        toast("Click TP", "Click to teleport", 2, "ok")
    else disconn("ctp"); toast("Click TP", "Disabled", 1.5) end
end

function fAutoJump(on)
    if on then
        Conn.aj = RS.Heartbeat:Connect(function() if On.aj then local h = hum(); if h and h.FloorMaterial ~= Enum.Material.Air then h.Jump = true end end end)
        toast("Auto Jump", "Enabled", 2, "ok")
    else disconn("aj"); toast("Auto Jump", "Disabled", 1.5) end
end

function fBHop(on)
    if on then
        Conn.bh = RS.Heartbeat:Connect(function()
            if On.bh then
                local h = hum()
                if h and h.MoveDirection.Magnitude > 0 and h.FloorMaterial ~= Enum.Material.Air then
                    h.Jump = true
                    if On.bhopmult then
                        Val.BhopSpeedMul = math.clamp(Val.BhopSpeedMul + 0.03, 1, 3.5)
                        h.WalkSpeed = Val.Speed * Val.BhopSpeedMul
                    end
                elseif h and h.FloorMaterial == Enum.Material.Air then
                    -- Keep speed in air
                else
                    Val.BhopSpeedMul = 1.0
                end
            end
        end)
        toast("Bunny Hop", "Enabled", 2, "ok")
    else
        disconn("bh")
        Val.BhopSpeedMul = 1.0
        local h = hum()
        if h then h.WalkSpeed = Val.Speed end
        toast("Bunny Hop", "Disabled", 1.5)
    end
end

-- ESP
function makeESP(plr)
    if plr == LP then return end
    local function onChar(c)
        if ESPCache[plr] then
            for _, o in pairs(ESPCache[plr]) do
                pcall(function() if typeof(o) == "RBXScriptConnection" then o:Disconnect() else o:Destroy() end end)
            end
        end
        ESPCache[plr] = {}
        local head = c:WaitForChild("Head", 5)
        local h = c:WaitForChild("Humanoid", 5)
        local r = c:WaitForChild("HumanoidRootPart", 5)
        if not (head and h and r) then return end

        local hl = Instance.new("Highlight", c)
        hl.FillColor = P.accent; hl.OutlineColor = Color3.new(1,1,1)
        hl.FillTransparency = 0.7; hl.OutlineTransparency = 0.3
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        table.insert(ESPCache[plr], hl)

        local bb = Instance.new("BillboardGui", head)
        bb.Adornee = head; bb.Size = UDim2.fromOffset(150, 38)
        bb.StudsOffset = Vector3.new(0, 2.5, 0); bb.AlwaysOnTop = true
        table.insert(ESPCache[plr], bb)

        local nl = Instance.new("TextLabel", bb)
        nl.Size = UDim2.new(1,0,0,13); nl.BackgroundTransparency = 1
        nl.Text = plr.Name; nl.TextColor3 = P.text; nl.TextSize = 11
        nl.Font = Enum.Font.GothamBold; nl.TextStrokeTransparency = 0.4

        local hpBg = Instance.new("Frame", bb)
        hpBg.Size = UDim2.new(0.5,0,0,3); hpBg.Position = UDim2.new(0.25,0,0,16)
        hpBg.BackgroundColor3 = Color3.fromRGB(40,40,40); hpBg.BorderSizePixel = 0
        Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1,0)
        local hpF = Instance.new("Frame", hpBg)
        hpF.Size = UDim2.new(1,0,1,0); hpF.BackgroundColor3 = P.green; hpF.BorderSizePixel = 0
        Instance.new("UICorner", hpF).CornerRadius = UDim.new(1,0)

        local dl = Instance.new("TextLabel", bb)
        dl.Size = UDim2.new(1,0,0,11); dl.Position = UDim2.new(0,0,0,22)
        dl.BackgroundTransparency = 1; dl.TextColor3 = P.text2; dl.TextSize = 9
        dl.Font = Enum.Font.Gotham; dl.TextStrokeTransparency = 0.5

        local cn = RS.RenderStepped:Connect(function()
            if not On.esp or not c.Parent or not h.Parent then cn:Disconnect() return end
            local isTeam = plr.Team == LP.Team and LP.Team ~= nil
            if On.teamcheck and isTeam then
                hl.Enabled = false
                bb.Enabled = false
                return
            else
                hl.Enabled = true
                bb.Enabled = true
            end
            local hp = math.clamp(h.Health/h.MaxHealth, 0, 1)
            hpF.Size = UDim2.new(hp, 0, 1, 0)
            hpF.BackgroundColor3 = Color3.fromRGB(255*(1-hp), 255*hp, 50)
            local mr = rootp()
            if mr and r.Parent then dl.Text = math.floor((mr.Position - r.Position).Magnitude) .. "m" end
        end)
        table.insert(ESPCache[plr], cn)
    end
    if plr.Character then onChar(plr.Character) end
    plr.CharacterAdded:Connect(function(c) if On.esp then task.wait(0.5); onChar(c) end end)
end

function fESP(on)
    if on then
        for _, p in pairs(Players:GetPlayers()) do makeESP(p) end
        Conn.espA = Players.PlayerAdded:Connect(function(p) if On.esp then p.CharacterAdded:Wait(); task.wait(0.5); makeESP(p) end end)
        toast("ESP", "Players visible through walls", 2, "ok")
    else
        disconn("espA")
        for p, objs in pairs(ESPCache) do for _, o in pairs(objs) do pcall(function() if typeof(o)=="RBXScriptConnection" then o:Disconnect() else o:Destroy() end end) end end
        ESPCache = {}
        for _, p in pairs(Players:GetPlayers()) do if p.Character then for _, v in pairs(p.Character:GetChildren()) do if v:IsA("Highlight") then v:Destroy() end end end end
        toast("ESP", "Disabled", 1.5)
    end
end

function fTracers(on)
    if on then
        Conn.tracers = RS.RenderStepped:Connect(function()
            for _, l in pairs(TracerDraw) do pcall(function() l:Remove() end) end; TracerDraw = {}
            if not On.tracers then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    if On.teamcheck and p.Team == LP.Team and LP.Team ~= nil then continue end
                    local r = p.Character:FindFirstChild("HumanoidRootPart")
                    if r then
                        local sp, vis = Cam:WorldToViewportPoint(r.Position)
                        if vis then pcall(function()
                            local l = Drawing.new("Line"); l.From = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y)
                            l.To = Vector2.new(sp.X, sp.Y); l.Color = P.red; l.Thickness = 1; l.Visible = true
                            table.insert(TracerDraw, l)
                        end) end
                    end
                end
            end
        end)
        toast("Tracers", "Enabled", 2, "ok")
    else
        disconn("tracers")
        for _, l in pairs(TracerDraw) do pcall(function() l:Remove() end) end; TracerDraw = {}
        toast("Tracers", "Disabled", 1.5)
    end
end

local savedL = {}
function fFullbright(on)
    if on then
        savedL = {A=Lighting.Ambient, B=Lighting.Brightness, CT=Lighting.ClockTime, FE=Lighting.FogEnd, GS=Lighting.GlobalShadows, OA=Lighting.OutdoorAmbient}
        Lighting.Ambient = Color3.fromRGB(178,178,178); Lighting.Brightness = 2; Lighting.ClockTime = 14
        Lighting.FogEnd = 1e5; Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.fromRGB(178,178,178)
        for _, v in pairs(Lighting:GetChildren()) do if v:IsA("Atmosphere") then v.Density = 0 end end
        toast("Fullbright", "Maximum visibility", 2, "ok")
    else
        pcall(function() Lighting.Ambient=savedL.A; Lighting.Brightness=savedL.B; Lighting.ClockTime=savedL.CT; Lighting.FogEnd=savedL.FE; Lighting.GlobalShadows=savedL.GS; Lighting.OutdoorAmbient=savedL.OA end)
        toast("Fullbright", "Disabled", 1.5)
    end
end

local savedFog = {}
function fNoFog(on)
    if on then savedFog={Lighting.FogEnd,Lighting.FogStart}; Lighting.FogEnd=9e9; Lighting.FogStart=9e9; toast("No Fog","Removed",2,"ok")
    else pcall(function() Lighting.FogEnd=savedFog[1]; Lighting.FogStart=savedFog[2] end); toast("No Fog","Disabled",1.5) end
end

function fCrosshair(on)
    if on then
        Conn.ch = RS.RenderStepped:Connect(function()
            for _, o in pairs(CrosshairDraw) do pcall(function() o:Remove() end) end; CrosshairDraw = {}
            if not On.crosshair then return end
            local cx, cy = Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2
            for _, pts in pairs({
                {Vector2.new(cx-14,cy),Vector2.new(cx-4,cy)},{Vector2.new(cx+4,cy),Vector2.new(cx+14,cy)},
                {Vector2.new(cx,cy-14),Vector2.new(cx,cy-4)},{Vector2.new(cx,cy+4),Vector2.new(cx,cy+14)},
            }) do pcall(function()
                local l = Drawing.new("Line"); l.From=pts[1]; l.To=pts[2]; l.Color=Color3.new(1,1,1); l.Thickness=1.5; l.Visible=true
                table.insert(CrosshairDraw, l)
            end) end
            pcall(function()
                local d = Drawing.new("Circle"); d.Position=Vector2.new(cx,cy); d.Radius=2; d.Color=P.red; d.Filled=true; d.Visible=true
                table.insert(CrosshairDraw, d)
            end)
        end)
        toast("Crosshair","Enabled",2,"ok")
    else
        disconn("ch")
        for _, o in pairs(CrosshairDraw) do pcall(function() o:Remove() end) end; CrosshairDraw = {}
        toast("Crosshair","Disabled",1.5)
    end
end

function fAimbot(on)
    if on then
        Conn.aim = RS.RenderStepped:Connect(function()
            if not On.aimbot or not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
            local best, bd = nil, Val.FOV
            local cx, cy = Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    if On.teamcheck and p.Team == LP.Team and LP.Team ~= nil then continue end
                    local head = p.Character:FindFirstChild("Head"); local h = p.Character:FindFirstChildOfClass("Humanoid")
                    if head and h and h.Health > 0 then
                        local sp, vis = Cam:WorldToViewportPoint(head.Position)
                        if vis then local d = (Vector2.new(sp.X,sp.Y)-Vector2.new(cx,cy)).Magnitude; if d < bd then bd=d; best=head end end
                    end
                end
            end
            if best then Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position, best.Position), 1/Val.AimSmooth) end
        end)
        toast("Aimbot","Hold right-click",2,"ok")
    else disconn("aim"); toast("Aimbot","Disabled",1.5) end
end

function fFOVCircle(on)
    if on then
        pcall(function() FOVDraw = Drawing.new("Circle"); FOVDraw.Radius=Val.FOV; FOVDraw.Color=P.accent; FOVDraw.Thickness=1; FOVDraw.Filled=false; FOVDraw.Transparency=0.5; FOVDraw.Visible=true end)
        Conn.fovc = RS.RenderStepped:Connect(function() if FOVDraw and On.fovc then FOVDraw.Position=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y/2); FOVDraw.Radius=Val.FOV end end)
        toast("FOV Circle","Enabled",2,"ok")
    else disconn("fovc"); if FOVDraw then pcall(function() FOVDraw:Remove() end); FOVDraw=nil end; toast("FOV Circle","Disabled",1.5) end
end

function fHitbox(on)
    if on then
        Conn.hb = RS.RenderStepped:Connect(function()
            if not On.hitbox then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then local r = p.Character:FindFirstChild("HumanoidRootPart")
                if r then r.Size=Vector3.one*Val.HBSize; r.Transparency=0.7; r.Material=Enum.Material.Neon; r.CanCollide=false end end
            end
        end)
        toast("Hitbox Expander","Enabled",2,"ok")
    else
        disconn("hb")
        for _, p in pairs(Players:GetPlayers()) do if p ~= LP and p.Character then local r = p.Character:FindFirstChild("HumanoidRootPart"); if r then r.Size=Vector3.new(2,2,1); r.Transparency=1 end end end
        toast("Hitbox Expander","Disabled",1.5)
    end
end

function fBigHead(on)
    if on then
        Conn.bh2 = RS.RenderStepped:Connect(function()
            if not On.bighead then return end
            for _, p in pairs(Players:GetPlayers()) do if p ~= LP and p.Character then local h = p.Character:FindFirstChild("Head"); if h then h.Size=Vector3.new(Val.HeadMul*4,Val.HeadMul*3,Val.HeadMul*4) end end end
        end)
        toast("Big Head","Enemies enlarged",2,"ok")
    else
        disconn("bh2")
        for _, p in pairs(Players:GetPlayers()) do if p ~= LP and p.Character then local h = p.Character:FindFirstChild("Head"); if h then h.Size=Vector3.new(2,1,1) end end end
        toast("Big Head","Disabled",1.5)
    end
end

function fAntiAFK(on)
    if on then
        local vu = game:GetService("VirtualUser")
        Conn.aafk = LP.Idled:Connect(function() vu:Button2Down(Vector2.zero,Cam.CFrame); task.wait(1); vu:Button2Up(Vector2.zero,Cam.CFrame) end)
        toast("Anti-AFK","Won't be kicked",2,"ok")
    else disconn("aafk"); toast("Anti-AFK","Disabled",1.5) end
end

local grav0 = 196.2
function fLowGrav(on)
    if on then grav0=WS.Gravity; WS.Gravity=75; toast("Low Gravity","Moon physics",2,"ok")
    else WS.Gravity=grav0; toast("Low Gravity","Disabled",1.5) end
end

function fFreecam(on)
    if on then
        local h = hum(); if h then h.WalkSpeed = 0 end
        Cam.CameraType = Enum.CameraType.Scriptable
        Conn.fc = RS.RenderStepped:Connect(function(dt)
            if not On.freecam then return end
            local d = Vector3.zero; local spd = Val.FlySpd * (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 2 or 1)
            if UIS:IsKeyDown(Enum.KeyCode.W) then d += Cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then d -= Cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then d -= Cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then d += Cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.E) then d += Vector3.yAxis end
            if UIS:IsKeyDown(Enum.KeyCode.Q) then d -= Vector3.yAxis end
            if d.Magnitude > 0 then Cam.CFrame += d.Unit * spd * dt end
        end)
        toast("Freecam","WASD + Q/E + Shift",3,"ok")
    else disconn("fc"); Cam.CameraType=Enum.CameraType.Custom; local h=hum(); if h then h.WalkSpeed=Val.Speed end; toast("Freecam","Disabled",1.5) end
end

function fChatSpy(on)
    if on then
        for _, p in pairs(Players:GetPlayers()) do if p ~= LP then p.Chatted:Connect(function(m) if On.chatspy then toast(p.Name, m, 4) end end) end end
        Conn.cs = Players.PlayerAdded:Connect(function(p) p.Chatted:Connect(function(m) if On.chatspy then toast(p.Name, m, 4) end end) end)
        toast("Chat Spy","Messages shown as toasts",2,"ok")
    else disconn("cs"); toast("Chat Spy","Disabled",1.5) end
end

function fFPSBoost(on)
    if on then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        local t = WS.Terrain; t.WaterWaveSize=0; t.WaterWaveSpeed=0
        for _, v in pairs(Lighting:GetDescendants()) do if v:IsA("PostEffect") then v.Enabled = false end end
        for _, v in pairs(WS:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") then pcall(function() v.Lifetime=NumberRange.new(0) end)
            elseif v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then v.Enabled=false end
        end
        toast("FPS Boost","Graphics minimized",2,"ok")
    else settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic; toast("FPS Boost","Rejoin to restore",2,"warn") end
end

function fInvisible(on)
    local c = LP.Character; if not c then return end
    if on then
        for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.Transparency=1 elseif p:IsA("Decal") then p.Transparency=1 end end
        toast("Invisible","Client-side",2,"ok")
    else
        for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then p.Transparency=0 elseif p:IsA("Decal") then p.Transparency=0 end end
        toast("Invisible","Disabled",1.5)
    end
end

function fRainbow(on)
    if on then
        Conn.rb = RS.RenderStepped:Connect(function()
            if not On.rainbow then return end; local c = LP.Character; if not c then return end
            local col = Color3.fromHSV(tick()%5/5, 0.8, 1)
            for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then p.Color=col; p.Material=Enum.Material.Neon end end
        end)
        toast("Rainbow","Fabulous",2,"ok")
    else disconn("rb"); toast("Rainbow","Disabled",1.5) end
end

function fAntiKick(on)
    if on then pcall(function() LP.Kick = function() end end); toast("Anti-Kick","Overridden",2,"warn")
    else toast("Anti-Kick","Rejoin to restore",2,"warn") end
end

function fXRay(on)
    if on then
        for _, v in pairs(WS:GetDescendants()) do if v:IsA("BasePart") and v.Transparency < 0.5 then v.Transparency = 0.75 end end
        toast("X-Ray","Walls transparent",2,"ok")
    else toast("X-Ray","Rejoin to restore",2,"warn") end
end

local plat
function fPlatform(on)
    if on then
        Conn.plat = RS.Heartbeat:Connect(function()
            if not On.platform then return end; local r = rootp(); if not r then return end
            if not plat or not plat.Parent then
                plat = Instance.new("Part", WS); plat.Anchored=true; plat.CanCollide=true
                plat.Material=Enum.Material.SmoothPlastic; plat.Color=P.card; plat.Transparency=0.4
            end
            plat.Size=Vector3.new(Val.PlatSize, 1, Val.PlatSize)
            plat.CFrame = CFrame.new(r.Position - Vector3.new(0,3.5,0))
        end)
        toast("Platform","Ground beneath you",2,"ok")
    else disconn("plat"); if plat then plat:Destroy(); plat=nil end; toast("Platform","Disabled",1.5) end
end

function fCtrlDel(on)
    if on then
        Conn.cdel = Mouse.Button1Down:Connect(function()
            if On.ctrldel and UIS:IsKeyDown(Enum.KeyCode.LeftControl) and Mouse.Target then
                local n = Mouse.Target.Name; Mouse.Target:Destroy(); toast("Deleted", n, 1.5)
            end
        end)
        toast("Ctrl+Click","Hold Ctrl, click parts",2,"ok")
    else disconn("cdel"); toast("Ctrl+Click","Disabled",1.5) end
end

local spinV
function fSpinBot(on)
    if on then
        Conn.spinbot = RS.Heartbeat:Connect(function()
            if not On.spinbot then return end
            local r = rootp()
            if r then
                if not spinV or spinV.Parent ~= r then
                    pcall(function() if spinV then spinV:Destroy() end end)
                    spinV = Instance.new("BodyAngularVelocity", r)
                    spinV.AngularVelocity = Vector3.new(0, 25, 0)
                    spinV.MaxTorque = Vector3.new(0, math.huge, 0)
                end
            end
        end)
        toast("Spin Bot","Spinning",2,"ok")
    else
        disconn("spinbot")
        if spinV then pcall(function() spinV:Destroy() end); spinV = nil end
        toast("Spin Bot","Disabled",1.5)
    end
end

function fTimeCycle(on)
    if on then
        Conn.tc = RS.Heartbeat:Connect(function(dt) if On.timecycle then Lighting.ClockTime = (Lighting.ClockTime + dt*2) % 24 end end)
        toast("Time Cycle","Day/night cycling",2,"ok")
    else disconn("tc"); toast("Time Cycle","Disabled",1.5) end
end

function fWallHack(on)
    if on then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and not p.Character:FindFirstChild("WH") then
                local hl = Instance.new("Highlight", p.Character); hl.Name="WH"
                hl.FillColor=P.amber; hl.FillTransparency=0.85; hl.OutlineColor=P.amber
                hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            end
        end
        Conn.wh = Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function(c)
            if On.wallhack then task.wait(1); local hl=Instance.new("Highlight",c); hl.Name="WH"; hl.FillColor=P.amber; hl.FillTransparency=0.85; hl.OutlineColor=P.amber; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop end
        end) end)
        toast("Wall Hack","Highlights active",2,"ok")
    else
        disconn("wh")
        for _, p in pairs(Players:GetPlayers()) do if p.Character then local h = p.Character:FindFirstChild("WH"); if h then h:Destroy() end end end
        toast("Wall Hack","Disabled",1.5)
    end
end

function fNoFallDmg(on)
    if on then
        Conn.nfd = RS.Heartbeat:Connect(function()
            if On.nofall then local h = hum(); if h then h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end end
        end)
        toast("No Fall Damage","Enabled",2,"ok")
    else disconn("nfd"); toast("No Fall Damage","Disabled",1.5) end
end

-- ORBIT PLAYER
function fOrbit(on)
    if on then
        Conn.orbit = RS.RenderStepped:Connect(function()
            if not On.orbit then return end
            local r = rootp(); if not r then return end
            -- orbit nearest player
            local best, bd = nil, math.huge
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local pr = p.Character:FindFirstChild("HumanoidRootPart")
                    if pr then local d = (r.Position-pr.Position).Magnitude; if d < bd then bd=d; best=pr end end
                end
            end
            if best then
                local t = tick() * Val.OrbitSpd
                local offset = Vector3.new(math.cos(t)*Val.OrbitRad, 0, math.sin(t)*Val.OrbitRad)
                r.CFrame = CFrame.new(best.Position + offset, best.Position)
            end
        end)
        toast("Orbit","Orbiting nearest player",2,"ok")
    else disconn("orbit"); toast("Orbit","Disabled",1.5) end
end

-- AUTO RESPAWN
function fAutoRespawn(on)
    if on then
        Conn.aresp = LP.CharacterAdded:Connect(function()
            -- just ensures quick respawn by doing nothing extra
        end)
        -- Force respawn if dead
        Conn.aresp2 = RS.Heartbeat:Connect(function()
            if On.autorespawn then
                local h = hum()
                if h and h.Health <= 0 then
                    pcall(function()
                        LP:LoadCharacter()
                    end)
                end
            end
        end)
        toast("Auto Respawn","Instant respawn on death",2,"ok")
    else disconn("aresp"); disconn("aresp2"); toast("Auto Respawn","Disabled",1.5) end
end

----------------------------------------------------------------
-- ★ NEVER-BEFORE-SEEN: LIVE PLAYER RADAR MINIMAP ★
----------------------------------------------------------------
local RADAR_SIZE = 140

local RadarFrame = Instance.new("Frame", Gui)
RadarFrame.Size = UDim2.fromOffset(RADAR_SIZE, RADAR_SIZE)
RadarFrame.Position = UDim2.new(0, 12, 1, -RADAR_SIZE - 12)
RadarFrame.BackgroundColor3 = P.bg; RadarFrame.BorderSizePixel = 0
RadarFrame.ZIndex = 90; RadarFrame.Visible = false; RadarFrame.ClipsDescendants = true
Instance.new("UICorner", RadarFrame).CornerRadius = UDim.new(0, 10)
local rStroke = Instance.new("UIStroke", RadarFrame)
rStroke.Color = P.border; rStroke.Thickness = 1

-- radar title
local rTitle = Instance.new("TextLabel", RadarFrame)
rTitle.Size = UDim2.new(1,0,0,16); rTitle.BackgroundTransparency = 1
rTitle.Text = "RADAR"; rTitle.TextColor3 = P.text3; rTitle.TextSize = 8
rTitle.Font = Enum.Font.GothamBold; rTitle.ZIndex = 91

-- range label
local rRange = Instance.new("TextLabel", RadarFrame)
rRange.Size = UDim2.new(1,-4,0,12); rRange.Position = UDim2.new(0,0,1,-14)
rRange.BackgroundTransparency = 1; rRange.Text = "200m"; rRange.TextColor3 = P.text3
rRange.TextSize = 8; rRange.Font = Enum.Font.Gotham; rRange.ZIndex = 91

-- crosshairs
local rCross1 = Instance.new("Frame", RadarFrame)
rCross1.Size = UDim2.new(0, 1, 1, -28); rCross1.Position = UDim2.new(0.5, 0, 0, 16)
rCross1.BackgroundColor3 = P.border; rCross1.BorderSizePixel = 0; rCross1.BackgroundTransparency = 0.6; rCross1.ZIndex = 91
local rCross2 = Instance.new("Frame", RadarFrame)
rCross2.Size = UDim2.new(1, -8, 0, 1); rCross2.Position = UDim2.new(0, 4, 0.5, 0)
rCross2.BackgroundColor3 = P.border; rCross2.BorderSizePixel = 0; rCross2.BackgroundTransparency = 0.6; rCross2.ZIndex = 91

-- center dot (you)
local rCenter = Instance.new("Frame", RadarFrame)
rCenter.Size = UDim2.fromOffset(6, 6); rCenter.Position = UDim2.new(0.5, -3, 0.5, -3)
rCenter.BackgroundColor3 = P.accent; rCenter.BorderSizePixel = 0; rCenter.ZIndex = 93
Instance.new("UICorner", rCenter).CornerRadius = UDim.new(1, 0)

-- direction indicator
local rDir = Instance.new("Frame", RadarFrame)
rDir.Size = UDim2.fromOffset(2, 12); rDir.Position = UDim2.new(0.5, -1, 0.5, -14)
rDir.BackgroundColor3 = P.accent; rDir.BorderSizePixel = 0; rDir.ZIndex = 92
rDir.AnchorPoint = Vector2.new(0.5, 1); rDir.Rotation = 0
Instance.new("UICorner", rDir).CornerRadius = UDim.new(0, 1)

function fRadar(on)
    if on then
        RadarFrame.Visible = true
        Conn.radar = RS.RenderStepped:Connect(function()
            if not On.radar then return end
            local myRoot = rootp()
            if not myRoot then return end

            rRange.Text = Val.RadarRange .. "m"

            -- Update direction indicator rotation based on camera
            local camLook = Cam.CFrame.LookVector
            local angle = math.deg(math.atan2(camLook.X, camLook.Z))

            -- Clean up old dots
            for _, d in pairs(RadarDots) do pcall(function() d:Destroy() end) end
            RadarDots = {}

            local halfSize = (RADAR_SIZE - 24) / 2 -- usable radius in pixels
            local myPos = myRoot.Position

            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local pr = p.Character:FindFirstChild("HumanoidRootPart")
                    local ph = p.Character:FindFirstChildOfClass("Humanoid")
                    if pr and ph and ph.Health > 0 then
                        local diff = pr.Position - myPos
                        local dist = Vector2.new(diff.X, diff.Z).Magnitude

                        if dist <= Val.RadarRange then
                            -- Rotate relative to camera direction
                            local relAngle = math.atan2(diff.X, diff.Z) - math.rad(angle)
                            local relDist = math.min(dist / Val.RadarRange, 1) * halfSize

                            local dotX = math.sin(relAngle) * relDist
                            local dotY = -math.cos(relAngle) * relDist

                            local dot = Instance.new("Frame", RadarFrame)
                            dot.Size = UDim2.fromOffset(5, 5)
                            dot.Position = UDim2.new(0.5, dotX - 2, 0.5, dotY - 2)
                            dot.BackgroundColor3 = P.red
                            dot.BorderSizePixel = 0; dot.ZIndex = 93
                            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
                            table.insert(RadarDots, dot)

                            -- Name tooltip for close players
                            if dist < Val.RadarRange * 0.4 then
                                local nl = Instance.new("TextLabel", dot)
                                nl.Size = UDim2.fromOffset(50, 10)
                                nl.Position = UDim2.fromOffset(7, -3)
                                nl.BackgroundTransparency = 1
                                nl.Text = p.Name:sub(1, 8)
                                nl.TextColor3 = P.text2; nl.TextSize = 7
                                nl.Font = Enum.Font.Gotham; nl.ZIndex = 94
                                nl.TextXAlignment = Enum.TextXAlignment.Left
                            end
                        end
                    end
                end
            end
        end)
        toast("Radar", "Live minimap active", 3, "ok")
    else
        disconn("radar"); RadarFrame.Visible = false
        for _, d in pairs(RadarDots) do pcall(function() d:Destroy() end) end; RadarDots = {}
        toast("Radar", "Disabled", 1.5)
    end
end

----------------------------------------------------------------
-- ★ GHOST REPLAY (Record & Playback) ★
----------------------------------------------------------------
local ghostRecording = {}
local isRecording = false
local isPlaying = false

function startGhostRecord()
    ghostRecording = {}; isRecording = true
    toast("Ghost", "Recording... (10s max)", 2, "ok")
    Conn.ghostRec = RS.RenderStepped:Connect(function()
        if not isRecording then return end
        local r = rootp()
        if r then
            table.insert(ghostRecording, {cf = r.CFrame, t = tick()})
            if #ghostRecording > 600 then -- ~10 sec at 60fps
                isRecording = false; disconn("ghostRec")
                toast("Ghost", "Recording complete ("..#ghostRecording.." frames)", 3, "ok")
            end
        end
    end)
end

function stopGhostRecord()
    isRecording = false; disconn("ghostRec")
    toast("Ghost", "Stopped ("..#ghostRecording.." frames)", 2, "ok")
end

function playGhostReplay()
    if #ghostRecording == 0 then toast("Ghost", "Nothing recorded!", 2, "err"); return end
    if isPlaying then toast("Ghost", "Already playing", 2, "warn"); return end

    -- Clean old ghost
    for _, p in pairs(GhostParts) do pcall(function() p:Destroy() end) end
    GhostParts = {}

    -- Create ghost model
    local ghost = Instance.new("Model", WS)
    ghost.Name = "NovaGhost"
    table.insert(GhostParts, ghost)

    local ghostPart = Instance.new("Part", ghost)
    ghostPart.Size = Vector3.new(2, 4.5, 1)
    ghostPart.Anchored = true; ghostPart.CanCollide = false
    ghostPart.Material = Enum.Material.ForceField
    ghostPart.Color = P.accent; ghostPart.Transparency = 0.5
    ghostPart.Name = "GhostBody"
    table.insert(GhostParts, ghostPart)

    -- Ghost head
    local ghostHead = Instance.new("Part", ghost)
    ghostHead.Size = Vector3.new(1.2, 1.2, 1.2)
    ghostHead.Shape = Enum.PartType.Ball
    ghostHead.Anchored = true; ghostHead.CanCollide = false
    ghostHead.Material = Enum.Material.ForceField
    ghostHead.Color = P.accentL; ghostHead.Transparency = 0.4
    table.insert(GhostParts, ghostHead)

    -- Billboard label
    local bb = Instance.new("BillboardGui", ghostHead)
    bb.Size = UDim2.fromOffset(80, 16); bb.StudsOffset = Vector3.new(0, 1.5, 0)
    bb.AlwaysOnTop = true
    local gl = Instance.new("TextLabel", bb)
    gl.Size = UDim2.new(1,0,1,0); gl.BackgroundTransparency = 1
    gl.Text = "GHOST"; gl.TextColor3 = P.accent; gl.TextSize = 10
    gl.Font = Enum.Font.GothamBold; gl.TextStrokeTransparency = 0.4

    isPlaying = true
    toast("Ghost", "Playing replay...", 3)

    task.spawn(function()
        local startTime = ghostRecording[1].t
        for i, frame in ipairs(ghostRecording) do
            if not isPlaying then break end
            ghostPart.CFrame = frame.cf
            ghostHead.CFrame = frame.cf * CFrame.new(0, 2.8, 0)
            if i < #ghostRecording then
                local dt = ghostRecording[i+1].t - frame.t
                task.wait(math.clamp(dt, 0, 0.1))
            end
        end
        isPlaying = false
        -- Fade out ghost
        task.wait(0.5)
        for _, p in pairs(GhostParts) do pcall(function() p:Destroy() end) end
        GhostParts = {}
        toast("Ghost", "Replay finished", 2, "ok")
    end)
end

----------------------------------------------------------------
-- 15 NEW FEATURES
----------------------------------------------------------------

-- 1. Night Vision
function fNightVision(on)
    if on then
        local cc = Lighting:FindFirstChild("NovaNV")
        if not cc then
            cc = Instance.new("ColorCorrectionEffect", Lighting)
            cc.Name = "NovaNV"
        end
        cc.TintColor = Color3.fromRGB(100, 255, 100)
        cc.Brightness = 0.15; cc.Contrast = 0.3; cc.Saturation = -0.5
        Lighting.Ambient = Color3.fromRGB(120, 180, 120)
        Lighting.Brightness = 3
        toast("Night Vision", "Green tint active", 2, "ok")
    else
        local cc = Lighting:FindFirstChild("NovaNV")
        if cc then cc:Destroy() end
        pcall(function() Lighting.Ambient = savedL.A or Color3.new(0,0,0); Lighting.Brightness = savedL.B or 1 end)
        toast("Night Vision", "Disabled", 1.5)
    end
end

-- 2. Anti-Void (teleport back up if you fall below map)
function fAntiVoid(on)
    if on then
        _G.NovaLastSafe = rootp() and rootp().CFrame or CFrame.new(0,50,0)
        Conn.avoid = RS.Heartbeat:Connect(function()
            if not On.antivoid then return end
            local r = rootp(); if not r then return end
            if r.Position.Y > -50 then
                _G.NovaLastSafe = r.CFrame
            else
                r.CFrame = _G.NovaLastSafe
                toast("Anti-Void", "Saved from the void!", 2, "warn")
            end
        end)
        toast("Anti-Void", "Won't fall off the map", 2, "ok")
    else disconn("avoid"); toast("Anti-Void", "Disabled", 1.5) end
end

-- 3. Auto Click
function fAutoClick(on)
    if on then
        Conn.aclick = RS.Heartbeat:Connect(function()
            if not On.autoclick then return end
            pcall(function()
                local vu = game:GetService("VirtualInputManager")
                vu:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
                task.wait(0.01)
                vu:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
            end)
            task.wait(1 / Val.AutoClickSpd)
        end)
        toast("Auto Click", Val.AutoClickSpd .. " CPS", 2, "ok")
    else disconn("aclick"); toast("Auto Click", "Disabled", 1.5) end
end

-- 4. Teleport Behind Nearest Player
function doTPBehind()
    local r = rootp(); if not r then return end
    local best, bd = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local pr = p.Character:FindFirstChild("HumanoidRootPart")
            if pr then
                local d = (r.Position - pr.Position).Magnitude
                if d < bd then bd = d; best = pr end
            end
        end
    end
    if best then
        r.CFrame = best.CFrame * CFrame.new(0, 0, 5) -- 5 studs behind
        toast("TP Behind", "Behind nearest player", 2, "ok")
    else
        toast("TP Behind", "No players found", 2, "err")
    end
end

-- 5. Freeze Character
local frozenCF = nil
function fFreeze(on)
    if on then
        local r = rootp()
        if r then frozenCF = r.CFrame end
        Conn.freeze = RS.RenderStepped:Connect(function()
            if not On.freeze then return end
            local r = rootp()
            if r and frozenCF then r.CFrame = frozenCF end
        end)
        toast("Freeze", "Locked in place", 2, "ok")
    else disconn("freeze"); frozenCF = nil; toast("Freeze", "Disabled", 1.5) end
end

-- 6. Speed Trail (leaves a trail of particles behind you)
local trailPart, trailAttach0, trailAttach1, trailObj
function fSpeedTrail(on)
    if on then
        Conn.speedtrail = RS.Heartbeat:Connect(function()
            if not On.speedtrail then return end
            local r = rootp()
            if r then
                if not trailObj or trailObj.Parent ~= r or not trailAttach0 or trailAttach0.Parent ~= r or not trailAttach1 or trailAttach1.Parent ~= r then
                    pcall(function() if trailObj then trailObj:Destroy() end end)
                    pcall(function() if trailAttach0 then trailAttach0:Destroy() end end)
                    pcall(function() if trailAttach1 then trailAttach1:Destroy() end end)
                    
                    trailAttach0 = Instance.new("Attachment", r)
                    trailAttach0.Position = Vector3.new(0, 1, 0)
                    trailAttach1 = Instance.new("Attachment", r)
                    trailAttach1.Position = Vector3.new(0, -1, 0)
                    
                    trailObj = Instance.new("Trail", r)
                    trailObj.Attachment0 = trailAttach0
                    trailObj.Attachment1 = trailAttach1
                    trailObj.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, P.accent), ColorSequenceKeypoint.new(1, P.cyan)})
                    trailObj.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
                    trailObj.Lifetime = 1.5; trailObj.MinLength = 0.1; trailObj.LightEmission = 0.6
                end
            end
        end)
        toast("Speed Trail", "Leaving a trail behind", 2, "ok")
    else
        disconn("speedtrail")
        if trailObj then pcall(function() trailObj:Destroy() end); trailObj = nil end
        if trailAttach0 then pcall(function() trailAttach0:Destroy() end); trailAttach0 = nil end
        if trailAttach1 then pcall(function() trailAttach1:Destroy() end); trailAttach1 = nil end
        toast("Speed Trail", "Disabled", 1.5)
    end
end

-- 7. Strobe Light
function fStrobe(on)
    if on then
        Conn.strobe = RS.RenderStepped:Connect(function()
            if not On.strobe then return end
            Lighting.Ambient = Color3.fromHSV(tick()*3 % 1, 1, 1)
            Lighting.OutdoorAmbient = Color3.fromHSV((tick()*3 + 0.5) % 1, 1, 1)
            Lighting.Brightness = 2 + math.sin(tick() * 15)
        end)
        toast("Strobe", "Flashing colors!", 2, "ok")
    else
        disconn("strobe")
        pcall(function() Lighting.Ambient = savedL.A or Color3.new(0,0,0); Lighting.Brightness = savedL.B or 1; Lighting.OutdoorAmbient = savedL.OA or Color3.new(128/255,128/255,128/255) end)
        toast("Strobe", "Disabled", 1.5)
    end
end

-- 8. Nameplate Hider
function fHideName(on)
    if on then
        local c = LP.Character; if not c then return end
        local head = c:FindFirstChild("Head")
        if head then
            for _, v in pairs(head:GetChildren()) do
                if v:IsA("BillboardGui") then v.Enabled = false end
            end
        end
        local h = hum()
        if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
        toast("Nameplate", "Hidden", 2, "ok")
    else
        local h = hum()
        if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer end
        local c = LP.Character
        if c then local head = c:FindFirstChild("Head"); if head then for _, v in pairs(head:GetChildren()) do if v:IsA("BillboardGui") then v.Enabled = true end end end end
        toast("Nameplate", "Visible", 1.5)
    end
end

-- 9. Zoom Hack (hold Z to scope zoom)
local originalFOV = 70
function fZoomHack(on)
    if on then
        originalFOV = Cam.FieldOfView
        Conn.zoom = RS.RenderStepped:Connect(function()
            if not On.zoomhack then return end
            if UIS:IsKeyDown(Enum.KeyCode.Z) then
                Cam.FieldOfView = Val.ZoomFOV
            else
                Cam.FieldOfView = Val.CamFOV
            end
        end)
        toast("Zoom Hack", "Hold Z to zoom", 2, "ok")
    else
        disconn("zoom")
        Cam.FieldOfView = Val.CamFOV
        toast("Zoom Hack", "Disabled", 1.5)
    end
end

-- 10. Carpet Fly (visible platform that flies with you)
local carpetPart
function fCarpet(on)
    if on then
        Conn.carpet = RS.RenderStepped:Connect(function()
            if not On.carpet then return end
            local r = rootp(); if not r then return end
            if not carpetPart or not carpetPart.Parent then
                pcall(function() if carpetPart then carpetPart:Destroy() end end)
                carpetPart = Instance.new("Part", WS)
                carpetPart.Size = Vector3.new(6, 0.3, 6)
                carpetPart.Anchored = true; carpetPart.CanCollide = true
                carpetPart.Material = Enum.Material.Neon
                carpetPart.Color = P.accent
                carpetPart.Transparency = 0.3
                carpetPart.Name = "NovaCarpet"
                Instance.new("SpecialMesh", carpetPart).MeshType = Enum.MeshType.Brick
                regTheme(carpetPart, "Color", "accent")
            end
            carpetPart.CFrame = CFrame.new(r.Position + Vector3.new(0, -3, 0)) * CFrame.Angles(0, math.rad(tick() * 30 % 360), 0)
        end)
        toast("Carpet", "Flying carpet active", 2, "ok")
    else
        disconn("carpet")
        if carpetPart then pcall(function() carpetPart:Destroy() end); carpetPart = nil end
        toast("Carpet", "Disabled", 1.5)
    end
end

-- 11. Head Dot ESP (small dots on heads through walls using Drawing)
function fHeadDot(on)
    if on then
        Conn.hdot = RS.RenderStepped:Connect(function()
            for _, d in pairs(HeadDotDraw) do pcall(function() d:Remove() end) end; HeadDotDraw = {}
            if not On.headdot then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    if On.teamcheck and p.Team == LP.Team and LP.Team ~= nil then continue end
                    local head = p.Character:FindFirstChild("Head")
                    local h = p.Character:FindFirstChildOfClass("Humanoid")
                    if head and h and h.Health > 0 then
                        local sp, vis = Cam:WorldToViewportPoint(head.Position)
                        if vis then pcall(function()
                            local c = Drawing.new("Circle")
                            c.Position = Vector2.new(sp.X, sp.Y)
                            c.Radius = 3; c.Color = P.green; c.Filled = true; c.Visible = true; c.Thickness = 1
                            table.insert(HeadDotDraw, c)
                        end) end
                    end
                end
            end
        end)
        toast("Head Dots", "Green dots on heads", 2, "ok")
    else
        disconn("hdot")
        for _, d in pairs(HeadDotDraw) do pcall(function() d:Remove() end) end; HeadDotDraw = {}
        toast("Head Dots", "Disabled", 1.5)
    end
end

-- 12. Kill Aura (damages nearby players' heads by touching)
function fKillAura(on)
    if on then
        Conn.kaura = RS.Heartbeat:Connect(function()
            if not On.killaura then return end
            local r = rootp(); if not r then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    if On.teamcheck and p.Team == LP.Team and LP.Team ~= nil then continue end
                    local pr = p.Character:FindFirstChild("HumanoidRootPart")
                    if pr and (r.Position - pr.Position).Magnitude < 15 then
                        -- Touch all their parts with our parts to trigger touch damage
                        local c = LP.Character
                        if c then
                            for _, tool in pairs(c:GetChildren()) do
                                if tool:IsA("Tool") then
                                    local handle = tool:FindFirstChild("Handle")
                                    if handle then
                                        firetouchinterest(handle, pr, 0)
                                        task.wait()
                                        firetouchinterest(handle, pr, 1)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
        toast("Kill Aura", "Auto-attacking nearby players", 2, "ok")
    else disconn("kaura"); toast("Kill Aura", "Disabled", 1.5) end
end

-- 13. Dolphin Dive (hold Shift+Space to lunge forward)
function fDolphinDive(on)
    if on then
        Conn.dive = UIS.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if On.dolphin and inp.KeyCode == Enum.KeyCode.Space and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
                local r = rootp(); if not r then return end
                local h = hum(); if not h then return end
                local dir = h.MoveDirection
                if dir.Magnitude == 0 then dir = Cam.CFrame.LookVector end
                local bv = Instance.new("BodyVelocity", r)
                bv.MaxForce = Vector3.one * math.huge
                bv.Velocity = (dir.Unit * 80) + Vector3.new(0, 30, 0)
                task.delay(0.4, function()
                    if bv and bv.Parent then bv:Destroy() end
                end)
            end
        end)
        toast("Dolphin Dive", "Shift+Space to lunge", 2, "ok")
    else disconn("dive"); toast("Dolphin Dive", "Disabled", 1.5) end
end

-- 14. No-Clip Fly (combines noclip + fly in one toggle)
local ncfBV, ncfBG
function fNoclipFly(on)
    if on then
        local r = rootp(); if not r then toast("Noclip Fly", "No character", 2, "err"); On.ncfly = false; return end
        ncfBV = Instance.new("BodyVelocity", r); ncfBV.MaxForce = Vector3.one * math.huge; ncfBV.Velocity = Vector3.zero
        ncfBG = Instance.new("BodyGyro", r); ncfBG.MaxTorque = Vector3.one * math.huge; ncfBG.P = 9e4
        Conn.ncfly = RS.RenderStepped:Connect(function()
            if not On.ncfly then return end
            local curR = rootp()
            if curR then
                if not ncfBV or ncfBV.Parent ~= curR or not ncfBG or ncfBG.Parent ~= curR then
                    pcall(function() if ncfBV then ncfBV:Destroy() end end)
                    pcall(function() if ncfBG then ncfBG:Destroy() end end)
                    ncfBV = Instance.new("BodyVelocity", curR); ncfBV.MaxForce = Vector3.one * math.huge; ncfBV.Velocity = Vector3.zero
                    ncfBG = Instance.new("BodyGyro", curR); ncfBG.MaxTorque = Vector3.one * math.huge; ncfBG.P = 9e4
                end
                -- noclip
                local c = LP.Character
                if c then for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
                -- fly
                ncfBG.CFrame = Cam.CFrame
                local d = Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then d += Cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then d -= Cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then d -= Cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then d += Cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d -= Vector3.yAxis end
                ncfBV.Velocity = d.Magnitude > 0 and d.Unit * Val.FlySpd or Vector3.zero
            end
        end)
        toast("Noclip Fly", "Fly through everything", 2, "ok")
    else
        disconn("ncfly")
        if ncfBV then pcall(function() ncfBV:Destroy() end); ncfBV = nil end
        if ncfBG then pcall(function() ncfBG:Destroy() end); ncfBG = nil end
        toast("Noclip Fly", "Disabled", 1.5)
    end
end

-- 15. Coordinate HUD (always-visible position display)
local coordFrame = Instance.new("Frame", Gui)
coordFrame.Size = UDim2.fromOffset(180, 36)
coordFrame.Position = UDim2.new(0, 12, 1, -RADAR_SIZE - 58)
coordFrame.BackgroundColor3 = P.bg; coordFrame.BorderSizePixel = 0
coordFrame.ZIndex = 90; coordFrame.Visible = false; coordFrame.BackgroundTransparency = 0.15
Instance.new("UICorner", coordFrame).CornerRadius = UDim.new(0, 6)
local cStroke = Instance.new("UIStroke", coordFrame); cStroke.Color = P.border; cStroke.Thickness = 1; cStroke.Transparency = 0.5

local coordTitle = Instance.new("TextLabel", coordFrame)
coordTitle.Size = UDim2.new(1, -8, 0, 12); coordTitle.Position = UDim2.new(0, 6, 0, 3)
coordTitle.BackgroundTransparency = 1; coordTitle.Text = "POSITION"
coordTitle.TextColor3 = P.text3; coordTitle.TextSize = 8; coordTitle.Font = Enum.Font.GothamBold
coordTitle.TextXAlignment = Enum.TextXAlignment.Left; coordTitle.ZIndex = 91

local coordLabel = Instance.new("TextLabel", coordFrame)
coordLabel.Size = UDim2.new(1, -8, 0, 14); coordLabel.Position = UDim2.new(0, 6, 0, 17)
coordLabel.BackgroundTransparency = 1; coordLabel.Text = "0, 0, 0"
coordLabel.TextColor3 = P.text2; coordLabel.TextSize = 11; coordLabel.Font = Enum.Font.GothamSemibold
coordLabel.TextXAlignment = Enum.TextXAlignment.Left; coordLabel.ZIndex = 91

function fCoordHUD(on)
    if on then
        coordFrame.Visible = true
        Conn.coord = RS.RenderStepped:Connect(function()
            if not On.coordhud then return end
            local r = rootp()
            if r then
                local p = r.Position
                coordLabel.Text = string.format("X: %d  Y: %d  Z: %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
            end
        end)
        toast("Coordinates", "Live position HUD", 2, "ok")
    else
        disconn("coord"); coordFrame.Visible = false
        toast("Coordinates", "Disabled", 1.5)
    end
end

----------------------------------------------------------------
-- UPGRADE FEATURES
----------------------------------------------------------------

function fForceInventory(on)
    if on then
        Conn.forceBackpack = RS.Heartbeat:Connect(function()
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
        end)
        toast("Force Inventory", "Backpack enabled", 2, "ok")
    else
        disconn("forceBackpack")
        toast("Force Inventory", "Disabled", 1.5)
    end
end

function fForcePlayerList(on)
    if on then
        Conn.forcePlayerList = RS.Heartbeat:Connect(function()
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true) end)
        end)
        toast("Force Leaderboard", "Leaderboard enabled", 2, "ok")
    else
        disconn("forcePlayerList")
        toast("Force Leaderboard", "Disabled", 1.5)
    end
end

function fForceChat(on)
    if on then
        Conn.forceChat = RS.Heartbeat:Connect(function()
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) end)
        end)
        toast("Force Chat", "Chat enabled", 2, "ok")
    else
        disconn("forceChat")
        toast("Force Chat", "Disabled", 1.5)
    end
end

function fForceEmotes(on)
    if on then
        Conn.forceEmotes = RS.Heartbeat:Connect(function()
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Emotes, true) end)
        end)
        toast("Force Emotes", "Emotes menu enabled", 2, "ok")
    else
        disconn("forceEmotes")
        toast("Force Emotes", "Disabled", 1.5)
    end
end

function fForceAllCoreGuis(on)
    if on then
        Conn.forceAllGuis = RS.Heartbeat:Connect(function()
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
        end)
        toast("Force All UI", "All CoreGuis enabled", 2, "ok")
    else
        disconn("forceAllGuis")
        toast("Force All UI", "Disabled", 1.5)
    end
end

function fBypass(on)
    if on then
        local success, err = pcall(function()
            if hookmetamethod then
                local oldIdx
                oldIdx = hookmetamethod(game, "__index", function(self, key)
                    if not checkcaller() and typeof(self) == "Instance" and self:IsA("Humanoid") then
                        if key == "WalkSpeed" then return 16
                        elseif key == "JumpPower" then return 50
                        elseif key == "JumpHeight" then return 7.2
                        end
                    end
                    return oldIdx(self, key)
                end)
                local oldNidx
                oldNidx = hookmetamethod(game, "__newindex", function(self, key, val)
                    if not checkcaller() and typeof(self) == "Instance" and self:IsA("Humanoid") then
                        if key == "WalkSpeed" or key == "JumpPower" or key == "JumpHeight" then
                            return
                        end
                    end
                    return oldNidx(self, key, val)
                end)
                toast("Bypass", "Metatable spoofing active", 2, "ok")
            else
                error("No hookmetamethod support")
            end
        end)
        if not success then
            toast("Bypass", "Metatable hooking not supported on executor", 2, "warn")
        end
    else
        toast("Bypass", "Disabled (Rejoin to clear metatable hooks)", 2)
    end
end

function fAutoPickup(on)
    if on then
        Conn.autopickup = RS.Heartbeat:Connect(function()
            if not On.autopickup then return end
            local r = rootp()
            if not r then return end
            for _, v in pairs(WS:GetDescendants()) do
                if v:IsA("Tool") and v.Parent == WS then
                    local handle = v:FindFirstChild("Handle") or v:FindFirstChildOfClass("BasePart")
                    if handle then
                        pcall(function()
                            handle.CFrame = r.CFrame
                            if firetouchinterest then
                                firetouchinterest(r, handle, 0)
                                task.wait()
                                firetouchinterest(r, handle, 1)
                            end
                        end)
                    end
                end
            end
        end)
        toast("Auto Pickup", "Teleporting dropped tools to you", 2, "ok")
    else
        disconn("autopickup")
        toast("Auto Pickup", "Disabled", 1.5)
    end
end

function fLagReducer(on)
    if on then
        for _, v in pairs(WS:GetDescendants()) do
            if v:IsA("BasePart") then
                pcall(function()
                    v.Material = Enum.Material.SmoothPlastic
                    v.CastShadow = false
                end)
            elseif v:IsA("Decal") or v:IsA("Texture") then
                pcall(function() v.Transparency = 1 end)
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                pcall(function() v.Enabled = false end)
            end
        end
        Lighting.GlobalShadows = false
        toast("Lag Reducer", "Graphics minimized", 2, "ok")
    else
        toast("Lag Reducer", "Rejoin to restore graphics", 2.5, "warn")
    end
end

function fAutoRejoin(on)
    if on then
        Conn.autorejoin = game:GetService("GuiService").ErrorMessageChanged:Connect(function(msg, code)
            toast("Auto-Rejoin", "Disconnection detected! Rejoining...", 3, "warn")
            task.wait(1)
            pcall(function()
                game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
            end)
        end)
        toast("Auto-Rejoin", "Armed and ready", 2, "ok")
    else
        disconn("autorejoin")
        toast("Auto-Rejoin", "Disabled", 1.5)
    end
end

function fVehicleBoost(on)
    if on then
        Conn.vehBoost = RS.Heartbeat:Connect(function()
            if not On.vehboost then return end
            local h = hum()
            if h and h.SeatPart then
                local seat = h.SeatPart
                local move = Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then move += Cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then move -= Cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then move -= Cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then move += Cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.yAxis end
                
                if move.Magnitude > 0 then
                    seat.AssemblyLinearVelocity = move.Unit * Val.FlySpd
                else
                    seat.AssemblyLinearVelocity = Vector3.zero
                end
                seat.AssemblyAngularVelocity = Vector3.zero
            end
        end)
        toast("Vehicle Fly/Boost", "Sit in vehicle and use WASD + Space/Shift", 3, "ok")
    else
        disconn("vehBoost")
        toast("Vehicle Fly/Boost", "Disabled", 1.5)
    end
end

local origNeckC0 = nil
local origNeckPart = nil
function fAntiAim(on)
    if on then
        local c = LP.Character
        if c then
            local head = c:FindFirstChild("Head")
            local neck = c:FindFirstChild("Torso") and c.Torso:FindFirstChild("Neck") or head and head:FindFirstChild("Neck")
            if neck then
                pcall(function()
                    origNeckC0 = neck.C0
                    origNeckPart = neck
                end)
            end
        end
        Conn.antiAim = RS.Heartbeat:Connect(function()
            if not On.antiaim then return end
            local c = LP.Character
            if c then
                local head = c:FindFirstChild("Head")
                local neck = c:FindFirstChild("Torso") and c.Torso:FindFirstChild("Neck") or head and head:FindFirstChild("Neck")
                if neck then
                    if not origNeckC0 or origNeckPart ~= neck then
                        pcall(function()
                            origNeckC0 = neck.C0
                            origNeckPart = neck
                        end)
                    end
                    local rot = CFrame.Angles(math.sin(tick() * 45) * 1.2, math.cos(tick() * 45) * 1.5, 0)
                    if origNeckC0 then
                        pcall(function() neck.C0 = origNeckC0 * rot end)
                    end
                end
            end
        end)
        toast("Anti-Aim", "Head jitter active", 2, "ok")
    else
        disconn("antiAim")
        if origNeckPart and origNeckC0 then
            pcall(function() origNeckPart.C0 = origNeckC0 end)
        end
        origNeckC0 = nil
        origNeckPart = nil
        toast("Anti-Aim", "Disabled", 1.5)
    end
end

----------------------------------------------------------------
-- PHASE 2 FEATURES
----------------------------------------------------------------

function translateText(text)
    local success, result = pcall(function()
        local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q=" .. game:GetService("HttpService"):UrlEncode(text)
        local res = game:HttpGet(url)
        local translated = res:match('^%[%[%["(.-)","')
        if translated then return translated end
        return text
    end)
    if success then return result end
    return text
end

function fChatTranslator(on)
    if on then
        local function hookPlayer(p)
            if p == LP then return end
            p.Chatted:Connect(function(msg)
                if On.chattranslator then
                    task.spawn(function()
                        local translated = translateText(msg)
                        if translated:lower() ~= msg:lower() then
                            toast(p.Name .. " (Translated)", translated, 5, "ok")
                        end
                    end)
                end
            end)
        end
        for _, p in pairs(Players:GetPlayers()) do hookPlayer(p) end
        Conn.chatTrans = Players.PlayerAdded:Connect(hookPlayer)
        toast("Chat Translator", "Translating chat to English", 2, "ok")
    else
        disconn("chatTrans")
        toast("Chat Translator", "Disabled", 1.5)
    end
end

function fMeleeReach(on)
    if on then
        Conn.meleeReach = RS.Heartbeat:Connect(function()
            if not On.meleereach then return end
            local c = LP.Character
            if c then
                local tool = c:FindFirstChildOfClass("Tool")
                if tool then
                    local handle = tool:FindFirstChild("Handle")
                    if handle then
                        pcall(function()
                            handle.Size = Vector3.one * Val.MeleeRange
                            handle.CanCollide = false
                        end)
                    end
                end
            end
        end)
        toast("Melee Reach", "Expands active tool size", 2, "ok")
    else
        disconn("meleeReach")
        local c = LP.Character
        if c then
            local tool = c:FindFirstChildOfClass("Tool")
            if tool then
                local handle = tool:FindFirstChild("Handle")
                if handle then pcall(function() handle.Size = Vector3.new(1, 1, 1) end) end
            end
        end
        toast("Melee Reach", "Disabled (Unequip and re-equip to restore)", 2)
    end
end

function fFlingAura(on)
    if on then
        Conn.flingAura = RS.Stepped:Connect(function()
            if not On.flingaura then return end
            local r = rootp()
            if r then
                pcall(function()
                    r.AssemblyAngularVelocity = Vector3.new(0, 99999, 0)
                    r.AssemblyLinearVelocity = Vector3.new(99999, 99999, 99999)
                end)
                local best, bd = nil, 15
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character then
                        local pr = p.Character:FindFirstChild("HumanoidRootPart")
                        if pr then
                            local d = (r.Position - pr.Position).Magnitude
                            if d < bd then bd = d; best = pr end
                        end
                    end
                end
                if best then r.CFrame = best.CFrame * CFrame.new(0, 0, 1) end
            end
        end)
        toast("Fling Aura", "Collide with players to fling them", 3, "ok")
    else
        disconn("flingAura")
        local r = rootp()
        if r then
            pcall(function()
                r.AssemblyAngularVelocity = Vector3.zero
                r.AssemblyLinearVelocity = Vector3.zero
            end)
        end
        toast("Fling Aura", "Disabled", 1.5)
    end
end

local tkPart = nil
local tkBP = nil
local tkBG = nil
function fTelekinesis(on)
    if on then
        Conn.telekinesisInput = UIS.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.KeyCode == Enum.KeyCode.G and Mouse.Target and not Mouse.Target.Anchored then
                if tkBP then pcall(function() tkBP:Destroy() end); tkBP = nil end
                if tkBG then pcall(function() tkBG:Destroy() end); tkBG = nil end
                if tkPart then pcall(function() tkPart.CanCollide = true end); tkPart = nil end
                disconn("telekinesisLoop")
                
                tkPart = Mouse.Target; tkPart.CanCollide = false
                tkBP = Instance.new("BodyPosition", tkPart)
                tkBP.MaxForce = Vector3.new(9e9, 9e9, 9e9); tkBP.P = 1e4
                tkBG = Instance.new("BodyGyro", tkPart)
                tkBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9); tkBG.P = 1e4; tkBG.CFrame = tkPart.CFrame
                Conn.telekinesisLoop = RS.Heartbeat:Connect(function()
                    if tkPart and tkBP then
                        tkBP.Position = Mouse.Hit.Position + Vector3.new(0, 4, 0)
                    else
                        disconn("telekinesisLoop")
                    end
                end)
                toast("Telekinesis", "Grabbed: " .. tkPart.Name, 1.5, "ok")
            end
        end)
        Conn.telekinesisEnd = UIS.InputEnded:Connect(function(inp)
            if inp.KeyCode == Enum.KeyCode.G then
                disconn("telekinesisLoop")
                if tkBP then pcall(function() tkBP:Destroy() end); tkBP = nil end
                if tkBG then pcall(function() tkBG:Destroy() end); tkBG = nil end
                if tkPart then pcall(function() tkPart.CanCollide = true end); tkPart = nil end
                toast("Telekinesis", "Released", 1.2)
            end
        end)
        toast("Telekinesis", "Hold G on unanchored block to carry", 3, "ok")
    else
        disconn("telekinesisInput")
        disconn("telekinesisEnd")
        disconn("telekinesisLoop")
        if tkBP then pcall(function() tkBP:Destroy() end); tkBP = nil end
        if tkBG then pcall(function() tkBG:Destroy() end); tkBG = nil end
        if tkPart then pcall(function() tkPart.CanCollide = true end); tkPart = nil end
        toast("Telekinesis", "Disabled", 1.5)
    end
end

local airWalkPart = nil
function fAirWalk(on)
    if on then
        Conn.airWalk = RS.Heartbeat:Connect(function()
            if not On.airwalk then return end
            local r = rootp()
            if r then
                if not airWalkPart or not airWalkPart.Parent then
                    airWalkPart = Instance.new("Part", WS)
                    airWalkPart.Name = "NovaAirWalk"
                    airWalkPart.Anchored = true
                    airWalkPart.Size = Vector3.new(6, 0.5, 6)
                    airWalkPart.Transparency = 1
                    airWalkPart.CanCollide = true
                end
                airWalkPart.CFrame = CFrame.new(r.Position.X, r.Position.Y - 3.25, r.Position.Z)
            end
        end)
        toast("Air Walk", "Walk on air", 2, "ok")
    else
        disconn("airWalk")
        if airWalkPart then airWalkPart:Destroy(); airWalkPart = nil end
        toast("Air Walk", "Disabled", 1.5)
    end
end

function fSpectate(on)
    if on then
        local best, bd = nil, math.huge
        local r = rootp()
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and p.Character:FindFirstChild("Humanoid") then
                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                if pr and r then
                    local d = (r.Position - pr.Position).Magnitude
                    if d < bd then bd = d; best = p end
                end
            end
        end
        if best then
            Cam.CameraSubject = best.Character.Humanoid
            toast("Spectating", "Watching " .. best.Name, 2.5, "ok")
        else
            toast("Spectating", "No players found", 2, "err")
            On.spectate = false
        end
    else
        Cam.CameraSubject = hum() or LP.Character
        toast("Spectating", "Returned to self", 1.5)
    end
end

function fAntiPurchase(on)
    if on then
        local mp = game:GetService("MarketplaceService")
        pcall(function()
            mp.PromptPurchase = function() end
            mp.PromptProductPurchase = function() end
            mp.PromptGamePassPurchase = function() end
            mp.PromptRobloxPurchase = function() end
        end)
        toast("Anti-Purchase Scam", "Purchase prompts blocked", 2, "warn")
    else
        toast("Anti-Purchase Scam", "Rejoin to restore purchase prompts", 2)
    end
end

function universalChat(text)
    pcall(function()
        local sayMsg = game:GetService("ReplicatedStorage"):FindFirstChild("SayMessageRequest", true)
        if sayMsg and sayMsg:IsA("RemoteEvent") then sayMsg:FireServer(text, "All") end
    end)
    pcall(function()
        local textCS = game:GetService("TextChatService")
        if textCS and textCS.ChatInputBarConfiguration and textCS.ChatInputBarConfiguration.TargetTextChannel then
            textCS.ChatInputBarConfiguration.TargetTextChannel:SendAsync(text)
        end
    end)
end

function sendFakeChat(msg, col)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = msg,
            Color = col or Color3.fromRGB(255, 0, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 12
        })
    end)
end

function spawnShadowClone()
    local c = LP.Character
    if c then
        pcall(function()
            c.Archivable = true
            local clone = c:Clone()
            clone.Parent = WS
            clone:MoveTo(c.PrimaryPart.Position)
            for _, p in pairs(clone:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Anchored = true; p.CanCollide = false
                    p.Material = Enum.Material.ForceField; p.Color = P.accent; p.Transparency = 0.4
                elseif p:IsA("LocalScript") or p:IsA("Script") then
                    p:Destroy()
                end
            end
            clone.Name = "ShadowClone"
            toast("Shadow Clone", "Spawned clone", 1.5, "ok")
            task.delay(10, function() clone:Destroy() end)
        end)
    end
end

function fTempNoclip(on)
    if on then
        Conn.tempNoclip = RS.Stepped:Connect(function()
            if On.tempnoclip and UIS:IsKeyDown(Enum.KeyCode.V) then
                local c = LP.Character
                if c then for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
            end
        end)
        toast("Temp Noclip", "Hold V to clip through walls", 2, "ok")
    else
        disconn("tempNoclip")
        toast("Temp Noclip", "Disabled", 1.5)
    end
end

function fAntiStun(on)
    if on then
        Conn.antiStun = RS.Heartbeat:Connect(function()
            if not On.antistun then return end
            local h = hum()
            if h then
                pcall(function()
                    h.PlatformStand = false
                    h:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
                    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                end)
            end
        end)
        toast("Anti-Stun", "Ragdoll bypass active", 2, "ok")
    else
        disconn("antiStun")
        toast("Anti-Stun", "Disabled", 1.5)
    end
end

function fRainbowTool(on)
    if on then
        Conn.rainbowTool = RS.Heartbeat:Connect(function()
            if not On.rainbowtool then return end
            local c = LP.Character
            if c then
                local tool = c:FindFirstChildOfClass("Tool")
                if tool then
                    local col = Color3.fromHSV(tick() % 5 / 5, 0.8, 1)
                    for _, p in pairs(tool:GetDescendants()) do
                        if p:IsA("BasePart") then
                            pcall(function() p.Color = col; p.Material = Enum.Material.Neon end)
                        end
                    end
                end
            end
        end)
        toast("Rainbow Tool", "Tool cycling colors", 2, "ok")
    else
        disconn("rainbowTool")
        toast("Rainbow Tool", "Disabled", 1.5)
    end
end

local imgCrosshair = nil
function fCustomCrosshair(on)
    if on then
        if not imgCrosshair then
            imgCrosshair = Instance.new("ImageLabel", Gui)
            imgCrosshair.Size = UDim2.fromOffset(64, 64)
            imgCrosshair.Position = UDim2.new(0.5, -32, 0.5, -32)
            imgCrosshair.BackgroundTransparency = 1; imgCrosshair.ZIndex = 100
        end
        local id = Val.CrosshairDecal ~= "" and Val.CrosshairDecal or "5062635955"
        imgCrosshair.Image = "rbxassetid://" .. id
        imgCrosshair.Visible = true
        toast("Custom Crosshair", "Rendering ID: " .. id, 2, "ok")
    else
        if imgCrosshair then imgCrosshair.Visible = false end
        toast("Custom Crosshair", "Disabled", 1.5)
    end
end

function fChatBot(on)
    if on then
        Conn.chatBot = Players.PlayerAdded:Connect(function(p)
            p.Chatted:Connect(function(msg)
                if On.autochatbot and p ~= LP then
                    local m = msg:lower()
                    if m:find("hack") or m:find("cheat") or m:find("exploit") then
                        task.wait(1.5)
                        universalChat("Who is cheating?")
                    end
                end
            end)
        end)
        toast("Chat Bot", "Replying to accusations", 2, "ok")
    else
        disconn("chatBot")
        toast("Chat Bot", "Disabled", 1.5)
    end
end

function fCtrlClickTP(on)
    if on then
        Conn.cctp = Mouse.Button1Down:Connect(function()
            if On.cctrlclicktp and UIS:IsKeyDown(Enum.KeyCode.LeftControl) and Mouse.Target then
                local r = rootp()
                if r then
                    r.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
                    toast("Teleport", "Teleported to cursor", 1.2, "ok")
                end
            end
        end)
        toast("Ctrl+Click TP", "Hold Ctrl and click to teleport", 2, "ok")
    else
        disconn("cctp")
        toast("Ctrl+Click TP", "Disabled", 1.5)
    end
end

-- 1. Bullet Tracers
function fBulletTracers(on)
    if on then
        Conn.bulletTracers = Mouse.Button1Down:Connect(function()
            if not On.bullettracers then return end
            local r = rootp()
            if r then
                local startPos = r.Position + Vector3.new(0, 1, 0)
                local endPos = Mouse.Hit.Position
                local beam = Instance.new("Part")
                beam.Size = Vector3.new(0.1, 0.1, (startPos - endPos).Magnitude)
                beam.Anchored = true
                beam.CanCollide = false
                beam.Material = Enum.Material.Neon
                beam.Color = P.accent
                beam.CFrame = CFrame.new(startPos:Lerp(endPos, 0.5), endPos)
                beam.Parent = WS
                regTheme(beam, "Color", "accent")
                task.delay(0.5, function() beam:Destroy() end)
            end
        end)
        toast("Bullet Tracers", "Beams show hit points", 2, "ok")
    else
        disconn("bulletTracers")
        toast("Bullet Tracers", "Disabled", 1.5)
    end
end

-- 2. Interact Aura
function fInteractAura(on)
    if on then
        Conn.interactAura = RS.Heartbeat:Connect(function()
            if not On.interactaura then return end
            local r = rootp()
            if r then
                for _, prompt in pairs(WS:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                        local parent = prompt.Parent
                        if parent and parent:IsA("BasePart") then
                            local dist = (r.Position - parent.Position).Magnitude
                            if dist <= (Val.InteractRange or 15) then
                                pcall(function() fireproximityprompt(prompt) end)
                            end
                        end
                    end
                end
            end
        end)
        toast("Interact Aura", "Auto-triggering prompts", 2, "ok")
    else
        disconn("interactAura")
        toast("Interact Aura", "Disabled", 1.5)
    end
end

-- 3. Gravity Gun
local ggPart = nil
local ggBP = nil
local ggBG = nil
function fGravityGun(on)
    if on then
        Conn.gravInput = UIS.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                if Mouse.Target and not Mouse.Target.Anchored then
                    ggPart = Mouse.Target; ggPart.CanCollide = false
                    ggBP = Instance.new("BodyPosition", ggPart)
                    ggBP.MaxForce = Vector3.new(9e9, 9e9, 9e9); ggBP.P = 2e4
                    ggBG = Instance.new("BodyGyro", ggPart)
                    ggBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9); ggBG.P = 2e4; ggBG.CFrame = ggPart.CFrame
                    Conn.gravLoop = RS.Heartbeat:Connect(function()
                        if ggPart and ggBP then
                            local r = rootp()
                            local targetPos = r and (r.Position + Cam.CFrame.LookVector * 15) or Mouse.Hit.Position
                            ggBP.Position = targetPos
                        else
                            disconn("gravLoop")
                        end
                    end)
                end
            elseif inp.KeyCode == Enum.KeyCode.F and ggPart then
                local force = Cam.CFrame.LookVector * (Val.GravGunForce or 150)
                if ggBP then ggBP:Destroy(); ggBP = nil end
                if ggBG then ggBG:Destroy(); ggBG = nil end
                ggPart.CanCollide = true
                ggPart.AssemblyLinearVelocity = force
                ggPart = nil
                disconn("gravLoop")
                toast("Gravity Gun", "Fired part!", 1, "ok")
            end
        end)
        Conn.gravEnd = UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and ggPart then
                disconn("gravLoop")
                if ggBP then ggBP:Destroy(); ggBP = nil end
                if ggBG then ggBG:Destroy(); ggBG = nil end
                ggPart.CanCollide = true; ggPart = nil
            end
        end)
        toast("Gravity Gun", "Left Click hold, press F to fling", 3, "ok")
    else
        disconn("gravInput")
        disconn("gravEnd")
        disconn("gravLoop")
        if ggBP then ggBP:Destroy(); ggBP = nil end
        if ggBG then ggBG:Destroy(); ggBG = nil end
        if ggPart then ggPart.CanCollide = true; ggPart = nil end
        toast("Gravity Gun", "Disabled", 1.5)
    end
end

-- 4. Chat Logger HUD
local chatLogFrame = nil
local chatLabels = {}
function fChatLogger(on)
    if on then
        if not chatLogFrame then
            chatLogFrame = Instance.new("Frame", Gui)
            chatLogFrame.Size = UDim2.fromOffset(250, 100)
            chatLogFrame.Position = UDim2.new(0, 10, 0, 36)
            chatLogFrame.BackgroundColor3 = P.bg; chatLogFrame.BackgroundTransparency = 0.2
            chatLogFrame.BorderSizePixel = 0; chatLogFrame.ZIndex = 40
            Instance.new("UICorner", chatLogFrame).CornerRadius = UDim.new(0, 8)
            local s = Instance.new("UIStroke", chatLogFrame); s.Color = P.border; s.Thickness = 1; s.Transparency = 0.5
            
            local title = Instance.new("TextLabel", chatLogFrame)
            title.Size = UDim2.new(1, 0, 0, 16); title.Position = UDim2.new(0, 6, 0, 2)
            title.BackgroundTransparency = 1; title.Text = "CHAT LOG"
            title.TextColor3 = P.text3; title.TextSize = 8; title.Font = Enum.Font.GothamBold
            title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 41
            
            for i = 1, 5 do
                local lbl = Instance.new("TextLabel", chatLogFrame)
                lbl.Size = UDim2.new(1, -12, 0, 14); lbl.Position = UDim2.new(0, 6, 0, 16 + (i-1)*15)
                lbl.BackgroundTransparency = 1; lbl.Text = ""
                lbl.TextColor3 = P.text2; lbl.TextSize = 9; lbl.Font = Enum.Font.Gotham
                lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 41
                table.insert(chatLabels, lbl)
            end
        end
        chatLogFrame.Visible = true
        
        local function onChatted(p, msg)
            if not On.chatlogger then return end
            for k = 1, 4 do
                chatLabels[k].Text = chatLabels[k+1].Text
            end
            chatLabels[5].Text = string.format("[%s]: %s", p.Name, msg)
        end
        
        Conn.chatLog = Players.PlayerAdded:Connect(function(p)
            p.Chatted:Connect(function(msg) onChatted(p, msg) end)
        end)
        for _, p in pairs(Players:GetPlayers()) do
            p.Chatted:Connect(function(msg) onChatted(p, msg) end)
        end
        toast("Chat Logger", "Displaying server chats", 2, "ok")
    else
        disconn("chatLog")
        if chatLogFrame then chatLogFrame.Visible = false end
        toast("Chat Logger", "Disabled", 1.5)
    end
end

-- 5. Outline ESP (Chams)
local outlineCache = {}
function makeOutlineESP(plr)
    if plr == LP then return end
    local function onChar(c)
        pcall(function()
            if outlineCache[plr] then outlineCache[plr]:Destroy() end
            local hl = Instance.new("Highlight")
            hl.Adornee = c
            hl.FillColor = P.accent
            hl.OutlineColor = Color3.new(1, 1, 1)
            hl.FillTransparency = 0.8
            hl.OutlineTransparency = 0.1
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = c
            outlineCache[plr] = hl
            regTheme(hl, "FillColor", "accent")
        end)
    end
    if plr.Character then onChar(plr.Character) end
    plr.CharacterAdded:Connect(onChar)
end

function fOutlineESP(on)
    if on then
        for _, p in pairs(Players:GetPlayers()) do makeOutlineESP(p) end
        Conn.outlineESPA = Players.PlayerAdded:Connect(makeOutlineESP)
        toast("Outline ESP", "Chams enabled", 2, "ok")
    else
        disconn("outlineESPA")
        for p, hl in pairs(outlineCache) do pcall(function() hl:Destroy() end) end
        outlineCache = {}
        toast("Outline ESP", "Disabled", 1.5)
    end
end

-- 6. Walk On Walls
function fWallWalk(on)
    if on then
        Conn.wallWalk = RS.Heartbeat:Connect(function()
            if not On.wallwalk then return end
            local c = LP.Character
            local r = rootp()
            if c and r then
                local params = RaycastParams.new()
                params.FilterDescendantsInstances = {c}
                params.FilterType = Enum.RaycastFilterType.Exclude
                local res = WS:Raycast(r.Position, r.CFrame.LookVector * 5 - Vector3.new(0, 3, 0), params)
                if res and res.Normal and res.Normal.Y < 0.8 then
                    pcall(function()
                        r.CFrame = CFrame.new(r.Position, r.Position + res.Normal) * CFrame.Angles(math.pi/2, 0, 0)
                    end)
                end
            end
        end)
        toast("Wall Walk", "Approach walls to scale them", 2, "ok")
    else
        disconn("wallWalk")
        toast("Wall Walk", "Disabled", 1.5)
    end
end

-- 7. Explosion Aura
function fExplosionAura(on)
    if on then
        Conn.explosionAura = RS.Heartbeat:Connect(function()
            if not On.explosionaura then return end
            local r = rootp()
            if r then
                pcall(function()
                    local exp = Instance.new("Explosion")
                    exp.Position = r.Position + Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
                    exp.BlastRadius = 0
                    exp.BlastPressure = 0
                    exp.Parent = WS
                end)
                task.wait(0.25)
            end
        end)
        toast("Explosion Aura", "Explosions active", 2, "ok")
    else
        disconn("explosionAura")
        toast("Explosion Aura", "Disabled", 1.5)
    end
end

-- 8. Item ESP
local itemESPBoxes = {}
function fItemESP(on)
    if on then
        Conn.itemESP = RS.Heartbeat:Connect(function()
            if not On.itemesp then return end
            for _, b in pairs(itemESPBoxes) do pcall(function() b:Destroy() end) end
            itemESPBoxes = {}
            for _, v in pairs(WS:GetDescendants()) do
                if v:IsA("Tool") and v.Parent == WS or v.Name:lower():find("chest") or v.Name:lower():find("key") then
                    local p = v:FindFirstChild("Handle") or v:IsA("BasePart") and v
                    if p then
                        pcall(function()
                            local bg = Instance.new("BillboardGui", p)
                            bg.Adornee = p; bg.AlwaysOnTop = true; bg.Size = UDim2.fromOffset(80, 14)
                            local tl = Instance.new("TextLabel", bg)
                            tl.Size = UDim2.new(1, 0, 1, 0); tl.BackgroundTransparency = 1
                            tl.Text = v.Name; tl.TextColor3 = P.amber; tl.TextSize = 8; tl.Font = Enum.Font.GothamBold
                            table.insert(itemESPBoxes, bg)
                        end)
                    end
                end
            end
            task.wait(1.5)
        end)
        toast("Item ESP", "Highlights chests/tools", 2, "ok")
    else
        disconn("itemESP")
        for _, b in pairs(itemESPBoxes) do pcall(function() b:Destroy() end) end
        itemESPBoxes = {}
        toast("Item ESP", "Disabled", 1.5)
    end
end

-- 9. Fake Lag
function fFakeLag(on)
    if on then
        Conn.fakeLag = RS.Heartbeat:Connect(function()
            if not On.fakelag then return end
            pcall(function() settings().Network.IncomingReplicationLag = 1 end)
            task.wait(0.8)
            pcall(function() settings().Network.IncomingReplicationLag = 0 end)
            task.wait(0.8)
        end)
        toast("Fake Lag", "Desync active", 2, "warn")
    else
        disconn("fakeLag")
        pcall(function() settings().Network.IncomingReplicationLag = 0 end)
        toast("Fake Lag", "Disabled", 1.5)
    end
end

-- 10. Custom Walk Animations
function playCustomAnimations(on)
    local c = LP.Character
    local anim = c and c:FindFirstChild("Animate")
    if on and anim then
        pcall(function()
            local walk = anim:FindFirstChild("walk")
            if walk then walk:FindFirstChildOfClass("Animation").AnimationId = "rbxassetid://616168073" end
            local run = anim:FindFirstChild("run")
            if run then run:FindFirstChildOfClass("Animation").AnimationId = "rbxassetid://616168073" end
            local jump = anim:FindFirstChild("jump")
            if jump then jump:FindFirstChildOfClass("Animation").AnimationId = "rbxassetid://616161444" end
            local h = hum()
            if h then
                for _, t in pairs(h:GetPlayingAnimationTracks()) do t:Stop() end
            end
        end)
        toast("Custom Anim", "Ninja style enabled", 2, "ok")
    else
        toast("Custom Anim", "Reset character to restore original anims", 2, "warn")
    end
end

-- 11. Client-Side Map Editor
local editorPart = nil
function fMapEditor(on)
    if on then
        Conn.mapEditorStart = Mouse.Button1Down:Connect(function()
            if On.mapeditor and UIS:IsKeyDown(Enum.KeyCode.LeftAlt) and Mouse.Target then
                editorPart = Mouse.Target
                editorPart.Anchored = true
                toast("Map Editor", "Selected: " .. editorPart.Name, 1.2, "ok")
            end
        end)
        Conn.mapEditorMove = RS.Heartbeat:Connect(function()
            if On.mapeditor and editorPart and UIS:IsKeyDown(Enum.KeyCode.LeftAlt) then
                editorPart.CFrame = CFrame.new(Mouse.Hit.Position)
            end
        end)
        Conn.mapEditorEnd = Mouse.Button1Up:Connect(function()
            if editorPart then
                editorPart = nil
                toast("Map Editor", "Part placed", 1, "ok")
            end
        end)
        toast("Map Editor", "Alt + Left Click hold drag", 3, "ok")
    else
        disconn("mapEditorStart")
        disconn("mapEditorMove")
        disconn("mapEditorEnd")
        editorPart = nil
        toast("Map Editor", "Disabled", 1.5)
    end
end

-- 12. Self-Destruct
function doSelfDestruct()
    local c = LP.Character
    if c then
        pcall(function()
            for _, p in pairs(c:GetDescendants()) do
                if p:IsA("Motor6D") or p:IsA("JointInstance") then
                    p:Destroy()
                elseif p:IsA("BasePart") then
                    p.CanCollide = true
                    p.AssemblyLinearVelocity = Vector3.new(math.random(-200, 200), 200, math.random(-200, 200))
                end
            end
            toast("Self Destruct", "BOOM!", 2, "err")
        end)
    end
end

-- 13. Super Ring
function fSuperRing(on)
    if on then
        Conn.superRing = RS.Heartbeat:Connect(function()
            if not On.superring then return end
            local r = rootp()
            if not r then return end
            local parts = {}
            for _, v in pairs(WS:GetDescendants()) do
                if v:IsA("BasePart") and not v.Anchored and not v:IsDescendantOf(LP.Character) then
                    table.insert(parts, v)
                end
            end
            local t = tick() * 3
            for i, p in ipairs(parts) do
                pcall(function()
                    p.CanCollide = false
                    local angle = (i / #parts) * math.pi * 2 + t
                    local offset = Vector3.new(math.cos(angle) * 8, 1, math.sin(angle) * 8)
                    p.CFrame = CFrame.new(r.Position + offset)
                    p.AssemblyLinearVelocity = Vector3.zero
                end)
            end
        end)
        toast("Super Ring", "Shield active", 2, "ok")
    else
        disconn("superRing")
        toast("Super Ring", "Disabled", 1.5)
    end
end

-- 14. Silent Aim
function fSilentAim(on)
    if on then
        local success, err = pcall(function()
            if hookmetamethod then
                local oldIdx
                oldIdx = hookmetamethod(game, "__index", function(self, key)
                    if not checkcaller() and self == Mouse and key == "Hit" and On.silentaim then
                        local best, bd = nil, Val.FOV
                        local cx, cy = Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2
                        for _, p in pairs(Players:GetPlayers()) do
                            if p ~= LP and p.Character then
                                if On.teamcheck and p.Team == LP.Team and LP.Team ~= nil then continue end
                                local head = p.Character:FindFirstChild("Head")
                                if head then
                                    local sp, vis = Cam:WorldToViewportPoint(head.Position)
                                    if vis then
                                        local d = (Vector2.new(sp.X,sp.Y)-Vector2.new(cx,cy)).Magnitude
                                        if d < bd then bd=d; best=head end
                                    end
                                end
                            end
                        end
                        if best then return best.CFrame end
                    end
                    return oldIdx(self, key)
                end)
                toast("Silent Aim", "Snapped clicks active", 2, "ok")
            else
                error("No hookmetamethod support")
            end
        end)
        if not success then
            toast("Silent Aim", "Not supported on executor", 2, "warn")
        end
    else
        toast("Silent Aim", "Disabled (Rejoin to clear hooks)", 2)
    end
end

-- 15. Anti-Fling
function fAntiFling(on)
    if on then
        Conn.antiFling = RS.Heartbeat:Connect(function()
            if not On.antifling then return end
            local c = LP.Character
            local r = rootp()
            if c and r then
                pcall(function()
                    r.AssemblyAngularVelocity = Vector3.zero
                    r.AssemblyLinearVelocity = Vector3.zero
                end)
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character then
                        for _, part in pairs(p.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                pcall(function()
                                    local noCollide = Instance.new("NoCollisionConstraint")
                                    noCollide.Part0 = r
                                    noCollide.Part1 = part
                                    noCollide.Parent = r
                                    task.delay(0.1, function() noCollide:Destroy() end)
                                end)
                            end
                        end
                    end
                end
            end
        end)
        toast("Anti-Fling", "Spin shield active", 2, "ok")
    else
        disconn("antiFling")
        toast("Anti-Fling", "Disabled", 1.5)
    end
end

----------------------------------------------------------------
-- BUILD PAGES
----------------------------------------------------------------

-- PLAYER
rst(); local pg = tPages.player
Section(pg, "Movement")
Toggle(pg, "Noclip", "noclip", fNoclip)
Toggle(pg, "Temporary Noclip (Hold V)", "tempnoclip", fTempNoclip)
Toggle(pg, "Fly", "fly", fFly)
Toggle(pg, "Infinite Jump", "infjump", fInfJump)
Toggle(pg, "Speed Hack", "sphack", fSpeedHack)
Toggle(pg, "Auto Jump", "aj", fAutoJump)
Toggle(pg, "Bunny Hop", "bh", fBHop)
Toggle(pg, "Bhop Speed Build-Up", "bhopmult")
Toggle(pg, "Air Walk", "airwalk", fAirWalk)
Toggle(pg, "Vehicle Fly / Boost", "vehboost", fVehicleBoost)
Toggle(pg, "Walk On Walls", "wallwalk", fWallWalk)

Section(pg, "Values")
Toggle(pg, "Speed & Jump Bypass", "bypass", fBypass)
Slider(pg, "Walk Speed", 1, 500, 16, "Speed", function(v) local h=hum(); if h then h.WalkSpeed=v end end)
Slider(pg, "Jump Power", 1, 500, 50, "Jump", function(v) local h=hum(); if h then h.JumpPower=v end end)
Slider(pg, "Jump Height", 1, 300, 7, "JumpHeight", function(v) local h=hum(); if h then h.UseJumpPower=false; h.JumpHeight=v end end)
Slider(pg, "Hip Height", 0, 30, 2, "HipHeight", function(v) local h=hum(); if h then h.HipHeight=v end end)
Slider(pg, "Fly Speed", 10, 500, 60, "FlySpd")

Section(pg, "Character")
Toggle(pg, "God Mode", "god", fGod)
Toggle(pg, "Invisible", "invisible", fInvisible)
Toggle(pg, "Rainbow", "rainbow", fRainbow)
Toggle(pg, "No Fall Damage", "nofall", fNoFallDmg)
Toggle(pg, "Freeze Position", "freeze", fFreeze)
Toggle(pg, "Speed Trail", "speedtrail", fSpeedTrail)
Toggle(pg, "Dolphin Dive", "dolphin", fDolphinDive)
Toggle(pg, "Ninja Walk Animations", "customanim", playCustomAnimations)
Toggle(pg, "Fake Lag (Backtrack)", "fakelag", fFakeLag)
Button(pg, "Reset Character", function() local h=hum(); if h then h.Health=0 end end, P.red)
Button(pg, "Sit / Unsit", function() local h=hum(); if h then h.Sit=not h.Sit end end)
Button(pg, "Remove Animations", function()
    local c=LP.Character; if not c then return end
    local a=c:FindFirstChild("Animate"); if a then a:Destroy() end
    local h=hum(); if h then for _, t in pairs(h:GetPlayingAnimationTracks()) do t:Stop() end end
    toast("Animations","Stripped",2,"ok")
end)

-- VISUALS
rst(); pg = tPages.visuals
Section(pg, "Players")
Toggle(pg, "ESP", "esp", fESP)
Toggle(pg, "Team Check", "teamcheck")
Toggle(pg, "Wall Hack", "wallhack", fWallHack)
Toggle(pg, "Tracers", "tracers", fTracers)
Toggle(pg, "Outline ESP (Chams)", "outlineesp", fOutlineESP)
Toggle(pg, "Bullet Tracers", "bullettracers", fBulletTracers)
Toggle(pg, "Crosshair", "crosshair", fCrosshair)
Toggle(pg, "Custom Crosshair Image", "customcross", fCustomCrosshair)
TextBox(pg, "Crosshair Image Decal ID", "Enter Roblox Image ID...", function(txt) Val.CrosshairDecal = txt; if On.customcross then fCustomCrosshair(true) end end)
Toggle(pg, "Head Dots", "headdot", fHeadDot)
Toggle(pg, "Chat Logger HUD", "chatlogger", fChatLogger)

Section(pg, "Environment")
Toggle(pg, "Fullbright", "fullbright", fFullbright)
Toggle(pg, "No Fog", "nofog", fNoFog)
Toggle(pg, "X-Ray", "xray", fXRay)
Toggle(pg, "Time Cycle", "timecycle", fTimeCycle)
Toggle(pg, "Night Vision", "nightvision", fNightVision)
Toggle(pg, "Strobe Light", "strobe", fStrobe)
Button(pg, "Remove Skybox", function() local s=Lighting:FindFirstChildOfClass("Sky"); if s then s:Destroy() end; toast("Skybox","Removed",2,"ok") end)
Button(pg, "Day", function() Lighting.ClockTime=14 end)
Button(pg, "Night", function() Lighting.ClockTime=0 end)
Button(pg, "Sunset", function() Lighting.ClockTime=18.3 end)

Section(pg, "Performance")
Toggle(pg, "FPS Boost", "fpsboost", fFPSBoost)
Toggle(pg, "Lag Reducer (Clean Map)", "lagreducer", fLagReducer)

-- COMBAT
rst(); pg = tPages.combat
Section(pg, "Aim")
Toggle(pg, "Aimbot", "aimbot", fAimbot)
Toggle(pg, "Silent Aim", "silentaim", fSilentAim)
Toggle(pg, "FOV Circle", "fovc", fFOVCircle)
Slider(pg, "FOV Radius", 30, 600, 150, "FOV")
Slider(pg, "Smoothness", 1, 20, 5, "AimSmooth")
Section(pg, "Hitbox")
Toggle(pg, "Hitbox Expander", "hitbox", fHitbox)
Toggle(pg, "Big Head", "bighead", fBigHead)
Toggle(pg, "Melee Reach", "meleereach", fMeleeReach)
Slider(pg, "Melee Reach Size", 5, 100, 15, "MeleeRange")
Slider(pg, "Hitbox Size", 3, 50, 10, "HBSize")
Slider(pg, "Head Scale", 1, 5, 1, "HeadMul")
Section(pg, "Other")
Toggle(pg, "Click Teleport", "ctp", fClickTP)
Toggle(pg, "Spin Bot", "spinbot", fSpinBot)
Toggle(pg, "Kill Aura", "killaura", fKillAura)
Toggle(pg, "Fling Aura", "flingaura", fFlingAura)
Toggle(pg, "Anti-Aim (Jitter Head)", "antiaim", fAntiAim)
Toggle(pg, "Anti-Fling / Spin Shield", "antifling", fAntiFling)
Toggle(pg, "Auto Click", "autoclick", fAutoClick)
Slider(pg, "Click Speed (CPS)", 1, 30, 10, "AutoClickSpd")

-- WORLD
rst(); pg = tPages.world
Section(pg, "Protection")
Toggle(pg, "Anti-AFK", "antiafk", fAntiAFK)
Toggle(pg, "Anti-Kick", "antikick", fAntiKick)
Toggle(pg, "Auto-Rejoin on Kick", "autorejoin", fAutoRejoin)
Toggle(pg, "Anti-Void", "antivoid", fAntiVoid)
Toggle(pg, "Anti-Purchase Scam", "antiPurchase", fAntiPurchase)
Toggle(pg, "Anti-Stun / Ragdoll Bypass", "antistun", fAntiStun)
Toggle(pg, "Auto Respawn", "autorespawn", fAutoRespawn)
Toggle(pg, "No Fall Damage", "nofall", fNoFallDmg)
Section(pg, "Physics")
Toggle(pg, "Low Gravity", "lowgrav", fLowGrav)
Slider(pg, "Gravity", 0, 500, 196, "Grav", function(v) WS.Gravity=v end)
Toggle(pg, "Super Ring (Orbit Parts)", "superring", fSuperRing)

Section(pg, "Camera")
Toggle(pg, "Freecam", "freecam", fFreecam)
Toggle(pg, "Spectate Player Mode", "spectate", fSpectate)
Toggle(pg, "Zoom Hack", "zoomhack", fZoomHack)
Slider(pg, "Zoom Level", 5, 50, 15, "ZoomFOV")
Slider(pg, "Field of View", 20, 120, 70, "CamFOV", function(v) Cam.FieldOfView=v end)
Slider(pg, "3rd Person Distance", 0, 128, 12, "TPDist", function(v) LP.CameraMaxZoomDistance=v; LP.CameraMinZoomDistance=v end)
Button(pg, "Unlock Camera", function() Cam.CameraType=Enum.CameraType.Custom; LP.CameraMaxZoomDistance=128; toast("Camera","Unlocked",2,"ok") end)

Section(pg, "Utilities")
Toggle(pg, "Chat Spy", "chatspy", fChatSpy)
Toggle(pg, "Chat Translator (to English)", "chattranslator", fChatTranslator)
Toggle(pg, "Auto-Respond Chat Bot", "autochatbot", fChatBot)
Toggle(pg, "Ctrl+Click Delete", "ctrldel", fCtrlDel)
Toggle(pg, "Ctrl+Click TP", "cctrlclicktp", fCtrlClickTP)
Toggle(pg, "Auto-Pickup Tools", "autopickup", fAutoPickup)
Toggle(pg, "Interact Aura", "interactaura", fInteractAura)
Slider(pg, "Interact Range", 5, 50, 15, "InteractRange")
Toggle(pg, "Item ESP", "itemesp", fItemESP)
Toggle(pg, "Platform", "platform", fPlatform)
Slider(pg, "Platform Size", 4, 30, 8, "PlatSize")

Section(pg, "CoreGui Unlocks")
Toggle(pg, "Force Enable Backpack", "forceBackpack", fForceInventory)
Toggle(pg, "Force Enable Leaderboard", "forcePlayerList", fForcePlayerList)
Toggle(pg, "Force Enable Chat", "forceChat", fForceChat)
Toggle(pg, "Force Enable Emotes", "forceEmotes", fForceEmotes)
Toggle(pg, "Force Enable All CoreGuis", "forceAllGuis", fForceAllCoreGuis)

-- TELEPORT
rst(); pg = tPages.teleport
Section(pg, "Quick")
Button(pg, "Nearest Player", function()
    local r=rootp(); if not r then return end
    local best,bd=nil,math.huge
    for _,p in pairs(Players:GetPlayers()) do if p~=LP and p.Character then local pr=p.Character:FindFirstChild("HumanoidRootPart"); if pr then local d=(r.Position-pr.Position).Magnitude; if d<bd then bd=d;best=pr end end end end
    if best then r.CFrame=best.CFrame*CFrame.new(0,0,-5); toast("Teleport","Nearest player",2,"ok") end
end)
Button(pg, "TP Behind Nearest", function() doTPBehind()
end)
Button(pg, "Random Player", function()
    local r=rootp(); if not r then return end; local t={}
    for _,p in pairs(Players:GetPlayers()) do if p~=LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then table.insert(t,p) end end
    if #t>0 then local p=t[math.random(#t)]; r.CFrame=p.Character.HumanoidRootPart.CFrame*CFrame.new(0,0,-5); toast("Teleport",p.Name,2,"ok") end
end)
Button(pg, "Spawn Point", function()
    local r=rootp(); if not r then return end; local sp=WS:FindFirstChildOfClass("SpawnLocation")
    if sp then r.CFrame=sp.CFrame+Vector3.new(0,5,0); toast("Teleport","Spawn",2,"ok") else toast("Teleport","No spawn found",2,"err") end
end)
Section(pg, "Waypoints")
Button(pg, "Save Position", function() local r=rootp(); if r then _G.NW1=r.CFrame; toast("Saved","Waypoint 1",2,"ok") end end)
Button(pg, "Load Position", function() local r=rootp(); if r and _G.NW1 then r.CFrame=_G.NW1; toast("Loaded","Waypoint 1",2,"ok") else toast("Error","Not saved",2,"err") end end)
Button(pg, "Save #2", function() local r=rootp(); if r then _G.NW2=r.CFrame; toast("Saved","Waypoint 2",2,"ok") end end)
Button(pg, "Load #2", function() local r=rootp(); if r and _G.NW2 then r.CFrame=_G.NW2; toast("Loaded","Waypoint 2",2,"ok") else toast("Error","Not saved",2,"err") end end)
Section(pg, "Server")
Button(pg, "Rejoin", function() toast("Rejoin","Reconnecting...",2); task.wait(0.5); TPS:Teleport(game.PlaceId,LP) end)
Button(pg, "Server Hop", function()
    toast("Server Hop","Searching...",3)
    task.spawn(function() pcall(function()
        local d=HTTP:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/0?sortOrder=2&excludeFullGames=true&limit=100"))
        for _,s in pairs(d.data) do if s.playing and s.playing<s.maxPlayers and s.id~=game.JobId then TPS:TeleportToPlaceInstance(game.PlaceId,s.id,LP); return end end
        toast("Server Hop","No servers found",3,"err")
    end) end)
end)
Section(pg, "Players")

local pSearchFrame = Instance.new("Frame", pg)
pSearchFrame.Size = UDim2.new(1, 0, 0, 26)
pSearchFrame.BackgroundColor3 = P.card
pSearchFrame.BorderSizePixel = 0
pSearchFrame.LayoutOrder = nxt()
Instance.new("UICorner", pSearchFrame).CornerRadius = UDim.new(0, 6)
local psSt = Instance.new("UIStroke", pSearchFrame); psSt.Color = P.border; psSt.Thickness = 1; psSt.Transparency = 0.5

local psBox = Instance.new("TextBox", pSearchFrame)
psBox.Size = UDim2.new(1, -12, 1, 0); psBox.Position = UDim2.new(0, 6, 0, 0)
psBox.BackgroundTransparency = 1; psBox.Text = ""; psBox.PlaceholderText = "Search players..."
psBox.TextColor3 = P.text; psBox.PlaceholderColor3 = P.text3; psBox.TextSize = 10
psBox.Font = Enum.Font.Gotham; psBox.TextXAlignment = Enum.TextXAlignment.Left

local pListContainer = Instance.new("Frame", pg)
pListContainer.Size = UDim2.new(1, 0, 0, 0)
pListContainer.AutomaticSize = Enum.AutomaticSize.Y
pListContainer.BackgroundTransparency = 1
pListContainer.LayoutOrder = nxt()
local plcLayout = Instance.new("UIListLayout", pListContainer)
plcLayout.Padding = UDim.new(0, 2)

local function rebuildPlayerList()
    for _, child in ipairs(pListContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local query = psBox.Text:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if query == "" or p.Name:lower():find(query, 1, true) or (p.DisplayName and p.DisplayName:lower():find(query, 1, true)) then
                local btnFrame = Instance.new("Frame", pListContainer)
                btnFrame.Size = UDim2.new(1, 0, 0, 26)
                btnFrame.BackgroundColor3 = P.card
                btnFrame.BorderSizePixel = 0
                Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 6)
                
                local lbl = Instance.new("TextLabel", btnFrame)
                lbl.Size = UDim2.new(1, -50, 1, 0); lbl.Position = UDim2.new(0, 8, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = p.DisplayName and string.format("%s (@%s)", p.DisplayName, p.Name) or p.Name
                lbl.TextColor3 = P.text; lbl.TextSize = 10; lbl.Font = Enum.Font.GothamSemibold
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                
                local tpBtn = Instance.new("TextButton", btnFrame)
                tpBtn.Size = UDim2.fromOffset(40, 20); tpBtn.Position = UDim2.new(1, -46, 0.5, -10)
                tpBtn.BackgroundColor3 = P.accent; tpBtn.BorderSizePixel = 0
                tpBtn.Text = "TP"; tpBtn.TextColor3 = Color3.new(1,1,1)
                tpBtn.TextSize = 9; tpBtn.Font = Enum.Font.GothamBold
                Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 4)
                regTheme(tpBtn, "BackgroundColor3", "accent")
                
                tpBtn.MouseButton1Click:Connect(function()
                    local r = rootp()
                    if r and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        r.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
                        toast("Teleported", "Teleported to " .. p.Name, 2, "ok")
                    else
                        toast("Error", "Character not found", 2, "err")
                    end
                end)
            end
        end
    end
end

psBox:GetPropertyChangedSignal("Text"):Connect(rebuildPlayerList)
Players.PlayerAdded:Connect(rebuildPlayerList)
Players.PlayerRemoving:Connect(rebuildPlayerList)
task.spawn(rebuildPlayerList)

-- FUN
rst(); pg = tPages.fun
Section(pg, "Character")
Button(pg, "Ragdoll", function() local h=hum(); if h then h:ChangeState(Enum.HumanoidStateType.Physics) end end)
Button(pg, "Super Jump", function() local h=hum(); if h then h.JumpPower=500; h.Jump=true; task.delay(0.5,function() h.JumpPower=Val.Jump end) end end)
Button(pg, "Rocket Launch", function() local r=rootp(); if r then local bv=Instance.new("BodyVelocity",r); bv.MaxForce=Vector3.new(0,math.huge,0); bv.Velocity=Vector3.new(0,200,0); task.delay(2,function() bv:Destroy() end) end end)
Button(pg, "Shadow Clone", function() spawnShadowClone() end)
Button(pg, "Tiny", function() local h=hum(); if h then pcall(function() local d=h:GetAppliedDescription(); d.HeightScale=0.3; d.WidthScale=0.3; d.DepthScale=0.3; d.HeadScale=0.5; h:ApplyDescription(d) end) end end)
Button(pg, "Giant", function() local h=hum(); if h then pcall(function() local d=h:GetAppliedDescription(); d.HeightScale=3; d.WidthScale=3; d.DepthScale=3; d.HeadScale=2; h:ApplyDescription(d) end) end end)
Button(pg, "Long Arms", function()
    local c=LP.Character; if not c then return end
    for _,n in pairs({"Left Arm","LeftUpperArm","LeftLowerArm","LeftHand","Right Arm","RightUpperArm","RightLowerArm","RightHand"}) do
        local p=c:FindFirstChild(n); if p and p:IsA("BasePart") then p.Size=p.Size*Vector3.new(1,2.5,1) end
    end; toast("Arms","Extended",2,"ok")
end)
Toggle(pg, "Explosion Aura", "explosionaura", fExplosionAura)
Toggle(pg, "Client Map Editor (Alt+AltClick)", "mapeditor", fMapEditor)
Button(pg, "Self-Destruct (Fling Bomb)", doSelfDestruct, P.red)

Section(pg, "Tools")
Toggle(pg, "Rainbow Held Tool", "rainbowtool", fRainbowTool)
Button(pg, "BTools", function() for _,t in pairs({Enum.BinType.Hammer,Enum.BinType.Clone,Enum.BinType.Grab}) do local h=Instance.new("HopperBin"); h.BinType=t; h.Parent=LP.Backpack end; toast("BTools","Added",2,"ok") end)
Button(pg, "Speed Coil", function()
    local t=Instance.new("Tool"); t.Name="Speed Coil"; t.RequiresHandle=true; Instance.new("Part",t).Name="Handle"
    t.Equipped:Connect(function() local h=hum(); if h then h.WalkSpeed=100 end end)
    t.Unequipped:Connect(function() local h=hum(); if h then h.WalkSpeed=Val.Speed end end)
    t.Parent=LP.Backpack; toast("Speed Coil","Added",2,"ok")
end)
Button(pg, "Gravity Coil", function()
    local t=Instance.new("Tool"); t.Name="Gravity Coil"; t.RequiresHandle=true; Instance.new("Part",t).Name="Handle"
    t.Equipped:Connect(function() WS.Gravity=50 end); t.Unequipped:Connect(function() WS.Gravity=196.2 end)
    t.Parent=LP.Backpack; toast("Gravity Coil","Added",2,"ok")
end)
Toggle(pg, "Gravity Gun", "gravgun", fGravityGun)
Slider(pg, "Gravity Gun Launch Force", 50, 500, 150, "GravGunForce")
Section(pg, "Movement")
Toggle(pg, "Orbit Nearest Player", "orbit", fOrbit)
Slider(pg, "Orbit Radius", 5, 50, 15, "OrbitRad")
Slider(pg, "Orbit Speed", 1, 10, 2, "OrbitSpd")
Toggle(pg, "Carpet Fly", "carpet", fCarpet)
Toggle(pg, "Noclip Fly", "ncfly", fNoclipFly)

-- RADAR (New unique tab)
rst(); pg = tPages.radar
Section(pg, "Live Radar Minimap")
Note(pg, "Real-time minimap showing all player positions relative to you.")
Note(pg, "Dots rotate with your camera. Red = enemies. Names appear when close.")
Toggle(pg, "Enable Radar", "radar", fRadar)
Slider(pg, "Radar Range", 50, 1000, 200, "RadarRange")
Toggle(pg, "Coordinate HUD", "coordhud", fCoordHUD)

Section(pg, "Ghost Replay")
Note(pg, "Record your movement path, then replay it as a visible ghost. Unique!")
Button(pg, "Start Recording", function() startGhostRecord() end, P.green)
Button(pg, "Stop Recording", function() stopGhostRecord() end, P.amber)
Button(pg, "Play Ghost Replay", function() playGhostReplay() end, P.accent)
Button(pg, "Clear Ghost Data", function()
    ghostRecording = {}; isPlaying = false; isRecording = false; disconn("ghostRec")
    for _, p in pairs(GhostParts) do pcall(function() p:Destroy() end) end; GhostParts = {}
    toast("Ghost", "Data cleared", 2, "ok")
end, P.red)

-- MISC
rst(); pg = tPages.misc
Section(pg, "Info")
Button(pg, "Copy Place ID", function() pcall(function() setclipboard(tostring(game.PlaceId)) end); toast("Copied","Place: "..game.PlaceId,2,"ok") end)
Button(pg, "Copy Server ID", function() pcall(function() setclipboard(game.JobId) end); toast("Copied","Job ID",2,"ok") end)
Button(pg, "Server Info", function() toast("Server", string.format("%d/%d players | %dms ping", #Players:GetPlayers(), Players.MaxPlayers, math.floor(LP:GetNetworkPing()*1000)), 4) end)
Button(pg, "Player List (F9)", function()
    print("\n— Players —")
    for i,p in pairs(Players:GetPlayers()) do print(i..". "..p.Name.." (@"..p.DisplayName..") | "..p.AccountAge.."d") end
    toast("Console","Printed to F9",2)
end)

Section(pg, "External Scripts")
Button(pg, "Infinite Yield", function() toast("Loading","...",3); pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end) end)
Button(pg, "Dex Explorer", function() toast("Loading","...",3); pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))() end) end)
Button(pg, "Simple Spy", function() toast("Loading","...",3); pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/exxtremestuffs/SimpleSpySource/master/SimpleSpy.lua"))() end) end)

Section(pg, "Chat Spammer & Announcements")
TextBox(pg, "Chat Message Text", "Enter message here...", function(txt) Val.ChatSpamText = txt end)
Button(pg, "Send Chat Message", function() universalChat(Val.ChatSpamText) end)
Button(pg, "Send Fake System Alert", function() sendFakeChat(Val.ChatSpamText, P.red) end)
Button(pg, "Send Fake Admin Join", function() sendFakeChat("[System]: Administrator joined server.", Color3.fromRGB(0, 200, 255)) end)

Section(pg, "Character")
Button(pg, "Hide Nameplate", function() fHideName(true) end)
Button(pg, "Show Nameplate", function() fHideName(false) end)

Section(pg, "Theme Customization")
Button(pg, "Theme: Indigo (Default)", function() setTheme("Indigo") toast("Theme", "Switched to Indigo", 1.5, "ok") end, Themes.Indigo.accent)
Button(pg, "Theme: Emerald Green", function() setTheme("Emerald") toast("Theme", "Switched to Emerald", 1.5, "ok") end, Themes.Emerald.accent)
Button(pg, "Theme: Ruby Red", function() setTheme("Ruby") toast("Theme", "Switched to Ruby", 1.5, "ok") end, Themes.Ruby.accent)
Button(pg, "Theme: Amber Gold", function() setTheme("Amber") toast("Theme", "Switched to Amber", 1.5, "ok") end, Themes.Amber.accent)
Button(pg, "Theme: Turquoise Cyan", function() setTheme("Turquoise") toast("Theme", "Switched to Turquoise", 1.5, "ok") end, Themes.Turquoise.accent)
Button(pg, "Theme: Neon Pink", function() setTheme("Pink") toast("Theme", "Switched to Pink", 1.5, "ok") end, Themes.Pink.accent)

Section(pg, "Reset")
Button(pg, "Disable All", function()
    for k, _ in pairs(Conn) do disconn(k) end
    for _, l in pairs(TracerDraw) do pcall(function() l:Remove() end) end; TracerDraw = {}
    for _, l in pairs(CrosshairDraw) do pcall(function() l:Remove() end) end; CrosshairDraw = {}
    if FOVDraw then pcall(function() FOVDraw:Remove() end); FOVDraw=nil end
    for _, d in pairs(HeadDotDraw) do pcall(function() d:Remove() end) end; HeadDotDraw = {}
    for k in pairs(On) do On[k]=false end; updateActiveCount()
    RadarFrame.Visible = false; coordFrame.Visible = false
    toast("Reset","All features disabled",2,"ok")
end, P.amber)
Button(pg, "Destroy GUI", function()
    for k, _ in pairs(Conn) do disconn(k) end
    for _, l in pairs(TracerDraw) do pcall(function() l:Remove() end) end
    for _, l in pairs(CrosshairDraw) do pcall(function() l:Remove() end) end
    if FOVDraw then pcall(function() FOVDraw:Remove() end) end
    for _, p in pairs(GhostParts) do pcall(function() p:Destroy() end) end
    Gui:Destroy()
end, P.red)

----------------------------------------------------------------
-- WINDOW CONTROLS
----------------------------------------------------------------
local minimized = false
local visible = true

bMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tw(Win, {Size=UDim2.new(0,WW,0,38)}, 0.2, Enum.EasingStyle.Back)
        task.delay(0.05, function() Content.Visible=false; SB.Visible=false end)
    else
        Content.Visible=true; SB.Visible=true
        tw(Win, {Size=origSize}, 0.25, Enum.EasingStyle.Back)
    end
end)

bClose.MouseButton1Click:Connect(function()
    visible = false
    tw(Win, {Size=UDim2.fromOffset(WW,0), BackgroundTransparency=1}, 0.2, Enum.EasingStyle.Back)
    tw(winStroke, {Transparency=1}, 0.15)
    task.delay(0.2, function() Win.Visible = false end)
end)

UIS.InputBegan:Connect(function(inp)
    if inp.KeyCode == Enum.KeyCode.RightControl then
        visible = not visible
        if visible then
            Win.Visible=true; Win.Size=UDim2.fromOffset(0,0); Win.Position=UDim2.new(0.5,0,0.5,0)
            Win.BackgroundTransparency=0.5; winStroke.Transparency=1
            Content.Visible=true; SB.Visible=true; minimized=false
            tw(Win, {Size=origSize, Position=origPos, BackgroundTransparency=0}, 0.35, Enum.EasingStyle.Back)
            tw(winStroke, {Transparency=0}, 0.3)
        else
            tw(Win, {Size=UDim2.fromOffset(0,0), Position=UDim2.new(0.5,0,0.5,0), BackgroundTransparency=1}, 0.2, Enum.EasingStyle.Back)
            tw(winStroke, {Transparency=1}, 0.15)
            task.delay(0.2, function() Win.Visible=false end)
        end
    end
end)

----------------------------------------------------------------
-- WATERMARK
----------------------------------------------------------------
local wm = Instance.new("Frame", Gui)
wm.Size = UDim2.fromOffset(210, 22); wm.Position = UDim2.new(0, 10, 0, 8)
wm.BackgroundColor3 = P.bg; wm.BorderSizePixel = 0; wm.ZIndex = 50; wm.BackgroundTransparency = 0.15
Instance.new("UICorner", wm).CornerRadius = UDim.new(0, 5)
local wmSt = Instance.new("UIStroke", wm); wmSt.Color = P.border; wmSt.Thickness = 1; wmSt.Transparency = 0.5

local wmL = Instance.new("TextLabel", wm)
wmL.Size = UDim2.new(1,-10,1,0); wmL.Position = UDim2.new(0,6,0,0)
wmL.BackgroundTransparency = 1; wmL.Text = "Nova v5"
wmL.TextColor3 = P.text2; wmL.TextSize = 10; wmL.Font = Enum.Font.GothamSemibold
wmL.TextXAlignment = Enum.TextXAlignment.Left; wmL.ZIndex = 51

local fC, fT = 0, tick()
RS.RenderStepped:Connect(function()
    fC += 1
    if tick()-fT >= 0.5 then
        wmL.Text = string.format("Nova v5 · %d fps · %dms · %s", math.floor(fC/(tick()-fT)), math.floor(LP:GetNetworkPing()*1000), os.date("%H:%M"))
        fC=0; fT=tick()
    end
end)

----------------------------------------------------------------
-- STARTUP
----------------------------------------------------------------
Win.Size = UDim2.fromOffset(0, 0)
Win.Position = UDim2.new(0.5, 0, 0.5, 0)
Win.BackgroundTransparency = 1; winStroke.Transparency = 1
wm.Position = UDim2.new(0, -220, 0, 8)

task.delay(0.15, function()
    tw(Win, {Size=origSize, Position=origPos, BackgroundTransparency=0}, 0.4, Enum.EasingStyle.Back)
    tw(winStroke, {Transparency=0}, 0.35)
    task.delay(0.2, function() tw(wm, {Position=UDim2.new(0,10,0,8)}, 0.35, Enum.EasingStyle.Back) end)
end)

task.delay(0.35, function() goTab("player") end)

LP.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    local h = c:WaitForChild("Humanoid", 10)
    if h then
        h.WalkSpeed = Val.Speed
        if Val.JumpHeight ~= 7.2 then
            h.UseJumpPower = false
            h.JumpHeight = Val.JumpHeight
        else
            h.JumpPower = Val.Jump
        end
        h.HipHeight = Val.HipHeight
    end
end)

task.delay(1, function()
    toast("Nova v5", "95+ features loaded · RCtrl to toggle", 4, "ok")
end)
