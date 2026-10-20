-- language: Lua | executor: Synapse X / KRNL / Fluxus / Delta (PC)
-- VoidHub v4 — ESP · Invisibility · Fly (noclip)

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera       = workspace.CurrentCamera
local LocalPlayer  = Players.LocalPlayer

-- ── limpeza ───────────────────────────────────────────────────────────────────
if _G.VH_cleanup then pcall(_G.VH_cleanup) end
pcall(function()
    local old = game:GetService("CoreGui"):FindFirstChild("VoidHub")
    if old then old:Destroy() end
end)

-- ── STATE ─────────────────────────────────────────────────────────────────────
local ST  = { ESP=false, Invis=false, Fly=false }
local CFG = { ESPDist=500, FlySpeed=60 }

-- ══════════════════════════════════════════════════════════════════════════════
-- ESP
-- ══════════════════════════════════════════════════════════════════════════════
local ECFG = {
    BoxColor  = Color3.fromRGB(255,60,60),   BoxThick  = 1.5,
    SkelColor = Color3.fromRGB(215,215,215), SkelThick = 1,
    NameColor = Color3.fromRGB(255,255,255), NameSize  = 13,
}
local BONES = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local pool = {}

local function newDraw(t, p)
    local d = Drawing.new(t)
    for k,v in pairs(p) do d[k]=v end
    return d
end
local function w2s(pos)
    local sp,ok = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X,sp.Y), ok
end
local function hideEntry(e)
    if not e then return end
    e.box.Visible=false; e.name.Visible=false
    for _,l in ipairs(e.lines) do l.Visible=false end
end
local function buildEntry(player)
    if player==LocalPlayer or pool[player] then return end
    local e = {
        box   = newDraw("Square",{Visible=false,Color=ECFG.BoxColor,Thickness=ECFG.BoxThick,Filled=false}),
        name  = newDraw("Text",{Visible=false,Color=ECFG.NameColor,Size=ECFG.NameSize,
                                Center=true,Outline=true,OutlineColor=Color3.new(),
                                Font=Drawing.Fonts.UI}),
        lines = {},
    }
    for i=1,#BONES do
        e.lines[i] = newDraw("Line",{Visible=false,Color=ECFG.SkelColor,Thickness=ECFG.SkelThick})
    end
    pool[player] = e
end
local function dropEntry(player)
    local e = pool[player]; if not e then return end
    e.box:Remove(); e.name:Remove()
    for _,l in ipairs(e.lines) do l:Remove() end
    pool[player] = nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- INVISIBILITY
-- ══════════════════════════════════════════════════════════════════════════════
local function applyInvis(char, on)
    if not char then return end
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.LocalTransparencyModifier = on and 1 or 0
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- FLY + NOCLIP
-- ══════════════════════════════════════════════════════════════════════════════
local flyConn = nil

--[[
  Mecânica:
  · PlatformStand = true → humanoid solta o controle, personagem fica em idle
  · Cada Heartbeat: CanCollide = false em todos os BaseParts (noclip contínuo)
  · Direção de movimento = WASD relativo ao LookVector/RightVector da câmera
    W/S → move na direção que a câmera aponta (pitch incluído → sobe se olhar p/ cima)
    A/D → strafe horizontal puro (RightVector sem componente Y)
    Space / LCtrl → sobe / desce no eixo Y global
    LShift → dobra a velocidade
  · AssemblyLinearVelocity zerado a cada frame → anula gravidade/física residual
  · Ao desativar: CanCollide restaurado, PlatformStand = false
]]

local function setNoClip(char, on)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = not on
        end
    end
end

local function getCharParts()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return c, h, r
end

local function startFly()
    ST.Fly = true
    local char, hum, root = getCharParts()
    if not char or not hum or not root then return end
    hum.PlatformStand = true

    flyConn = RunService.Heartbeat:Connect(function(dt)
        local c, h, r = getCharParts()
        if not c or not h or not r then return end

        -- noclip contínuo (cobre partes novas após respawn ou mudança de char)
        setNoClip(c, true)
        h.PlatformStand = true

        -- vetores de câmera
        local camCF   = Camera.CFrame
        local look    = camCF.LookVector               -- direção com pitch
        local right   = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)  -- horizontal puro
        if right.Magnitude > 0 then right = right.Unit end

        local move = Vector3.new(0, 0, 0)

        if UIS:IsKeyDown(Enum.KeyCode.W) then          move = move + look         end
        if UIS:IsKeyDown(Enum.KeyCode.S) then          move = move - look         end
        if UIS:IsKeyDown(Enum.KeyCode.A) then          move = move - right        end
        if UIS:IsKeyDown(Enum.KeyCode.D) then          move = move + right        end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then      move = move + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.yAxis end

        local speed = CFG.FlySpeed
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then speed = speed * 2 end

        if move.Magnitude > 0 then
            r.CFrame = r.CFrame + move.Unit * speed * dt
        end

        -- zera física residual (gravidade, empurrões)
        pcall(function() r.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
    end)
end

local function stopFly()
    ST.Fly = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local c, h, _ = getCharParts()
    if c then setNoClip(c, false) end
    if h then h.PlatformStand = false end
end

-- re-aplica estados ao respawnar
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if ST.Invis then applyInvis(char, true) end
    if ST.Fly   then
        -- reconecta fly no novo char sem toggle manual
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        startFly()
    end
end)

-- ── RENDER — só ESP (aimbot removido) ─────────────────────────────────────────
local mainConn = RunService.RenderStepped:Connect(function()
    for player, e in pairs(pool) do
        local char = player.Character
        if not char then hideEntry(e); continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not root or not head then hideEntry(e); continue end

        if not ST.ESP or (Camera.CFrame.Position - root.Position).Magnitude > CFG.ESPDist then
            hideEntry(e)
        else
            local tW = head.Position + Vector3.new(0, head.Size.Y*.5+.1, 0)
            local bW = root.Position  - Vector3.new(0, 3.1, 0)
            local tS, okT = w2s(tW)
            local bS, _   = w2s(bW)
            if not okT then hideEntry(e) else
                local h = math.abs(tS.Y-bS.Y); local w = h*.65; local cx = (tS.X+bS.X)*.5
                e.box.Position = Vector2.new(cx-w*.5, tS.Y)
                e.box.Size     = Vector2.new(w, h)
                e.box.Visible  = true
                e.name.Text    = player.Name
                e.name.Position= Vector2.new(tS.X, tS.Y-ECFG.NameSize-2)
                e.name.Visible = true
                for i, pair in ipairs(BONES) do
                    local bA = char:FindFirstChild(pair[1])
                    local bB = char:FindFirstChild(pair[2])
                    local ln = e.lines[i]
                    if bA and bB then
                        local pA, oA = w2s(bA.Position)
                        local pB, oB = w2s(bB.Position)
                        if oA or oB then ln.From=pA; ln.To=pB; ln.Visible=true
                        else ln.Visible=false end
                    else ln.Visible=false end
                end
            end
        end
    end
end)

for _,p in ipairs(Players:GetPlayers()) do buildEntry(p) end
Players.PlayerAdded:Connect(function(p)
    buildEntry(p)
    p.CharacterRemoving:Connect(function() hideEntry(pool[p]) end)
end)
Players.PlayerRemoving:Connect(dropEntry)

-- ── CLEANUP ───────────────────────────────────────────────────────────────────
local sliderConns = {}
local function cleanup()
    mainConn:Disconnect()
    stopFly()
    for p in pairs(pool) do dropEntry(p) end
    for _,c in ipairs(sliderConns) do pcall(function() c:Disconnect() end) end
end
_G.VH_cleanup = cleanup

-- ══════════════════════════════════════════════════════════════════════════════
-- GUI — tokens de design (idênticos ao v3)
-- ══════════════════════════════════════════════════════════════════════════════
local W     = 500
local H     = 340
local BAR_H =  44

local C = {
    BG      = Color3.fromRGB(12, 12, 16),
    Sidebar = Color3.fromRGB( 8,  8, 12),
    Bar     = Color3.fromRGB( 8,  8, 12),
    Row     = Color3.fromRGB(20, 20, 26),
    RowHov  = Color3.fromRGB(28, 28, 36),
    RowAlt  = Color3.fromRGB(15, 15, 20),
    Accent  = Color3.fromRGB(35, 215, 95),
    AccDim  = Color3.fromRGB(12,  75, 36),
    AccGlow = Color3.fromRGB(20, 140, 58),
    Blue    = Color3.fromRGB(50, 155, 255),
    SliderBg= Color3.fromRGB(30,  30, 42),
    Text    = Color3.fromRGB(238, 238, 242),
    Sub     = Color3.fromRGB(110, 110, 130),
    SubDim  = Color3.fromRGB( 65,  65,  82),
    Border  = Color3.fromRGB(24,  24, 34),
    SideBdr = Color3.fromRGB(20,  20, 28),
    TogOn   = Color3.fromRGB(35, 215, 95),
    TogOff  = Color3.fromRGB(40,  40, 56),
    LEDRed  = Color3.fromRGB(255, 88, 88),
    LEDYel  = Color3.fromRGB(255,196, 58),
    LEDGrn  = Color3.fromRGB(40, 210, 90),
}

local TI  = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI2 = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r); c.Parent = p
end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = th; s.Parent = p
end

local SG = Instance.new("ScreenGui")
SG.Name="VoidHub"; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Global; SG.IgnoreGuiInset=true

local function getParent()
    if gethui then return gethui() end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    return ok and cg or LocalPlayer:WaitForChild("PlayerGui")
end
SG.Parent = getParent()
if syn and syn.protect_gui then pcall(syn.protect_gui, SG) end

local Main = Instance.new("Frame")
Main.Size=UDim2.new(0,W,0,H); Main.Position=UDim2.new(0.5,-W/2,0.5,-H/2)
Main.BackgroundColor3=C.BG; Main.BorderSizePixel=0
Main.ClipsDescendants=true; Main.BackgroundTransparency=1
corner(Main,10); stroke(Main,C.Border,1); Main.Parent=SG
task.defer(function() TweenService:Create(Main,TI2,{BackgroundTransparency=0}):Play() end)

local TopBar = Instance.new("Frame")
TopBar.Size=UDim2.new(1,0,0,BAR_H); TopBar.BackgroundColor3=C.Bar
TopBar.BorderSizePixel=0; TopBar.ZIndex=10
corner(TopBar,10); TopBar.Parent=Main

local TBFix = Instance.new("Frame")
TBFix.Size=UDim2.new(1,0,0,12); TBFix.Position=UDim2.new(0,0,1,-12)
TBFix.BackgroundColor3=C.Bar; TBFix.BorderSizePixel=0; TBFix.ZIndex=10; TBFix.Parent=TopBar

local TBSep = Instance.new("Frame")
TBSep.Size=UDim2.new(1,0,0,1); TBSep.Position=UDim2.new(0,0,1,-1)
TBSep.BackgroundColor3=C.Border; TBSep.BorderSizePixel=0; TBSep.ZIndex=10; TBSep.Parent=TopBar

local LED_D=12; local LED_GAP=8; local LED_X=14
local minimized=false
local ContentArea

local function makeLED(xOff, col)
    local Btn = Instance.new("TextButton")
    Btn.Size=UDim2.new(0,LED_D,0,LED_D); Btn.Position=UDim2.new(0,xOff,0.5,-(LED_D/2))
    Btn.BackgroundColor3=col; Btn.BorderSizePixel=0; Btn.Text=""; Btn.ZIndex=12
    corner(Btn,LED_D/2); Btn.Parent=TopBar
    local Glow=Instance.new("Frame")
    Glow.Size=UDim2.new(0,4,0,4); Glow.Position=UDim2.new(0.5,-2,0.5,-2)
    Glow.BackgroundColor3=Color3.fromRGB(255,255,255)
    Glow.BackgroundTransparency=0.82; Glow.BorderSizePixel=0
    Glow.ZIndex=13; corner(Glow,2); Glow.Parent=Btn
    Btn.MouseEnter:Connect(function() TweenService:Create(Glow,TI,{BackgroundTransparency=0.35}):Play() end)
    Btn.MouseLeave:Connect(function() TweenService:Create(Glow,TI,{BackgroundTransparency=0.82}):Play() end)
    return Btn
end

local ledRed = makeLED(LED_X,                     C.LEDRed)
local ledYel = makeLED(LED_X+LED_D+LED_GAP,       C.LEDYel)
local ledGrn = makeLED(LED_X+(LED_D+LED_GAP)*2,   C.LEDGrn)

local function makeWindowButton(text, xOffset, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size=UDim2.new(0,24,0,24); btn.Position=UDim2.new(1,xOffset,0.5,-12)
    btn.BackgroundColor3=color; btn.BorderSizePixel=0
    btn.Text=text; btn.TextColor3=C.Text; btn.TextSize=18
    btn.Font=Enum.Font.GothamMedium; btn.AutoButtonColor=true; btn.ZIndex=12
    corner(btn,6); btn.Parent=TopBar; btn.MouseButton1Click:Connect(callback)
    return btn
end

local closeButton = makeWindowButton("×", -36, C.LEDRed, function()
    TweenService:Create(Main,TI,{BackgroundTransparency=1}):Play()
    task.delay(0.14, function() pcall(cleanup); _G.VH_cleanup=nil; SG:Destroy() end)
end)
local minimizeButton = makeWindowButton("−", -66, C.RowHov, function()
    minimized = not minimized
    if minimized then
        ContentArea.Visible=false
        TweenService:Create(Main,TI2,{Size=UDim2.new(0,W,0,BAR_H)}):Play()
    else
        TweenService:Create(Main,TI2,{Size=UDim2.new(0,W,0,H)}):Play()
        ContentArea.Visible=true
    end
end)

local LOGO_X = LED_X+(LED_D+LED_GAP)*3+10

local LogoLbl=Instance.new("TextLabel")
LogoLbl.Size=UDim2.new(0,22,1,0); LogoLbl.Position=UDim2.new(0,LOGO_X,0,0)
LogoLbl.BackgroundTransparency=1; LogoLbl.Text="◈"; LogoLbl.TextColor3=C.Accent
LogoLbl.TextSize=16; LogoLbl.Font=Enum.Font.GothamBold
LogoLbl.TextXAlignment=Enum.TextXAlignment.Center; LogoLbl.ZIndex=11; LogoLbl.Parent=TopBar

local TitleLbl=Instance.new("TextLabel")
TitleLbl.Size=UDim2.new(0,72,1,0); TitleLbl.Position=UDim2.new(0,LOGO_X+24,0,0)
TitleLbl.BackgroundTransparency=1; TitleLbl.Text="VoidHub"
TitleLbl.TextColor3=C.Text; TitleLbl.TextSize=14; TitleLbl.Font=Enum.Font.GothamBold
TitleLbl.TextXAlignment=Enum.TextXAlignment.Left; TitleLbl.ZIndex=11; TitleLbl.Parent=TopBar

local VerPill=Instance.new("Frame")
VerPill.Size=UDim2.new(0,40,0,17); VerPill.Position=UDim2.new(0,LOGO_X+100,0.5,-8)
VerPill.BackgroundColor3=C.AccDim; VerPill.BorderSizePixel=0; VerPill.ZIndex=11
corner(VerPill,8); VerPill.Parent=TopBar

local VerTxt=Instance.new("TextLabel")
VerTxt.Size=UDim2.new(1,0,1,0); VerTxt.BackgroundTransparency=1
VerTxt.Text="v4.0"; VerTxt.TextColor3=C.Accent
VerTxt.TextSize=10; VerTxt.Font=Enum.Font.GothamBold
VerTxt.TextXAlignment=Enum.TextXAlignment.Center; VerTxt.ZIndex=12; VerTxt.Parent=VerPill

TopBar.Active=true
local dragging,dragStart,frameStart=false,nil,nil

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local p=input.Position
    local function hit(btn)
        local b,s=btn.AbsolutePosition,btn.AbsoluteSize
        return p.X>=b.X and p.X<=b.X+s.X and p.Y>=b.Y and p.Y<=b.Y+s.Y
    end
    if hit(ledRed) or hit(ledYel) or hit(ledGrn)
       or hit(closeButton) or hit(minimizeButton) then return end
    dragging=true; dragStart=input.Position; frameStart=Main.Position
end)
UIS.InputChanged:Connect(function(input)
    if not dragging or not dragStart then return end
    if input.UserInputType==Enum.UserInputType.MouseMovement then
        local d=input.Position-dragStart
        Main.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+d.X,
                                 frameStart.Y.Scale,frameStart.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false; dragStart=nil; frameStart=nil
    end
end)

ContentArea=Instance.new("Frame")
ContentArea.Size=UDim2.new(1,0,1,-BAR_H); ContentArea.Position=UDim2.new(0,0,0,BAR_H)
ContentArea.BackgroundTransparency=1; ContentArea.BorderSizePixel=0; ContentArea.Parent=Main

local OptionsFrame=Instance.new("ScrollingFrame")
OptionsFrame.Name="Options"; OptionsFrame.Size=UDim2.new(1,0,1,0)
OptionsFrame.BackgroundTransparency=1; OptionsFrame.BorderSizePixel=0
OptionsFrame.ScrollBarThickness=3; OptionsFrame.ScrollBarImageColor3=C.Accent
OptionsFrame.CanvasSize=UDim2.new(0,0,0,0)
OptionsFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y; OptionsFrame.Parent=ContentArea

local OptionsList=Instance.new("UIListLayout")
OptionsList.Padding=UDim.new(0,6)
OptionsList.HorizontalAlignment=Enum.HorizontalAlignment.Center
OptionsList.SortOrder=Enum.SortOrder.LayoutOrder; OptionsList.Parent=OptionsFrame

local OptionsPad=Instance.new("UIPadding")
OptionsPad.PaddingLeft=UDim.new(0,10); OptionsPad.PaddingRight=UDim.new(0,10)
OptionsPad.PaddingTop=UDim.new(0,10); OptionsPad.PaddingBottom=UDim.new(0,10)
OptionsPad.Parent=OptionsFrame

-- ══════════════════════════════════════════════════════════════════════════════
-- COMPONENTES (idênticos ao v3)
-- ══════════════════════════════════════════════════════════════════════════════
local rowOrder=0

local function makeHeader(parent, icon, text)
    rowOrder=rowOrder+1
    local Row=Instance.new("Frame")
    Row.Size=UDim2.new(1,0,0,28); Row.BackgroundTransparency=1
    Row.BorderSizePixel=0; Row.LayoutOrder=rowOrder; Row.Parent=parent
    local Ico=Instance.new("TextLabel")
    Ico.Size=UDim2.new(0,16,1,0); Ico.Position=UDim2.new(0,0,0,0)
    Ico.BackgroundTransparency=1; Ico.Text=icon; Ico.TextColor3=C.AccGlow
    Ico.TextSize=11; Ico.Font=Enum.Font.GothamBold
    Ico.TextXAlignment=Enum.TextXAlignment.Left; Ico.Parent=Row
    local Lbl=Instance.new("TextLabel")
    Lbl.Size=UDim2.new(1,-20,1,0); Lbl.Position=UDim2.new(0,18,0,0)
    Lbl.BackgroundTransparency=1; Lbl.Text=string.upper(text); Lbl.TextColor3=C.SubDim
    Lbl.TextSize=10; Lbl.Font=Enum.Font.GothamBold
    Lbl.TextXAlignment=Enum.TextXAlignment.Left; Lbl.Parent=Row
    local Line=Instance.new("Frame")
    Line.Size=UDim2.new(1,-18,0,1); Line.Position=UDim2.new(0,18,1,-1)
    Line.BackgroundColor3=C.Border; Line.BorderSizePixel=0; Line.Parent=Row
end

local function makeToggle(parent, text, descOrCb, cbOrNil)
    local desc, cb
    if type(descOrCb)=="function" then cb=descOrCb; desc=nil
    else desc=descOrCb; cb=cbOrNil end
    rowOrder=rowOrder+1
    local rowH=desc and 54 or 42
    local Row=Instance.new("Frame")
    Row.Size=UDim2.new(1,0,0,rowH); Row.BackgroundColor3=C.Row
    Row.BorderSizePixel=0; Row.LayoutOrder=rowOrder
    corner(Row,7); stroke(Row,C.Border,1); Row.Parent=parent
    local Hov=Instance.new("Frame")
    Hov.Size=UDim2.new(1,0,1,0); Hov.BackgroundColor3=Color3.fromRGB(255,255,255)
    Hov.BackgroundTransparency=1; Hov.BorderSizePixel=0; corner(Hov,7); Hov.Parent=Row
    local textY=desc and 9 or 11
    local Lbl=Instance.new("TextLabel")
    Lbl.Size=UDim2.new(1,-62,0,18); Lbl.Position=UDim2.new(0,13,0,textY)
    Lbl.BackgroundTransparency=1; Lbl.Text=text; Lbl.TextColor3=C.Text
    Lbl.TextSize=13; Lbl.Font=Enum.Font.GothamSemibold
    Lbl.TextXAlignment=Enum.TextXAlignment.Left; Lbl.Parent=Row
    if desc then
        local DL=Instance.new("TextLabel")
        DL.Size=UDim2.new(1,-62,0,13); DL.Position=UDim2.new(0,13,0,29)
        DL.BackgroundTransparency=1; DL.Text=desc; DL.TextColor3=C.Sub
        DL.TextSize=10; DL.Font=Enum.Font.Gotham
        DL.TextXAlignment=Enum.TextXAlignment.Left; DL.Parent=Row
    end
    local Pill=Instance.new("Frame")
    Pill.Size=UDim2.new(0,38,0,20); Pill.Position=UDim2.new(1,-50,0.5,-10)
    Pill.BackgroundColor3=C.TogOff; Pill.BorderSizePixel=0
    corner(Pill,10); Pill.Parent=Row
    local Dot=Instance.new("Frame")
    Dot.Size=UDim2.new(0,14,0,14); Dot.Position=UDim2.new(0,3,0.5,-7)
    Dot.BackgroundColor3=Color3.fromRGB(155,155,175)
    Dot.BorderSizePixel=0; corner(Dot,7); Dot.Parent=Pill
    local state=false
    local Btn=Instance.new("TextButton")
    Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.Text=""
    Btn.ZIndex=3; Btn.Parent=Row
    Btn.MouseEnter:Connect(function() TweenService:Create(Hov,TI,{BackgroundTransparency=0.97}):Play() end)
    Btn.MouseLeave:Connect(function() TweenService:Create(Hov,TI,{BackgroundTransparency=1}):Play() end)
    Btn.MouseButton1Click:Connect(function()
        state=not state
        TweenService:Create(Pill,TI,{BackgroundColor3=state and C.TogOn or C.TogOff}):Play()
        TweenService:Create(Dot,TI,{
            Position=state and UDim2.new(0,21,0.5,-7) or UDim2.new(0,3,0.5,-7),
            BackgroundColor3=state and Color3.fromRGB(255,255,255) or Color3.fromRGB(155,155,175),
        }):Play()
        cb(state)
    end)
end

local function makeSlider(parent, text, minV, maxV, defV, fmt, onChanged)
    rowOrder=rowOrder+1
    local Row=Instance.new("Frame")
    Row.Size=UDim2.new(1,0,0,52); Row.BackgroundColor3=C.Row
    Row.BorderSizePixel=0; Row.LayoutOrder=rowOrder
    corner(Row,7); stroke(Row,C.Border,1); Row.Parent=parent
    local Lbl=Instance.new("TextLabel")
    Lbl.Size=UDim2.new(0.58,0,0,20); Lbl.Position=UDim2.new(0,13,0,8)
    Lbl.BackgroundTransparency=1; Lbl.Text=text; Lbl.TextColor3=C.Text
    Lbl.TextSize=12; Lbl.Font=Enum.Font.GothamSemibold
    Lbl.TextXAlignment=Enum.TextXAlignment.Left; Lbl.Parent=Row
    local ValLbl=Instance.new("TextLabel")
    ValLbl.Size=UDim2.new(0.37,0,0,20); ValLbl.Position=UDim2.new(0.6,0,0,8)
    ValLbl.BackgroundTransparency=1; ValLbl.TextColor3=C.Accent
    ValLbl.TextSize=12; ValLbl.Font=Enum.Font.GothamBold
    ValLbl.TextXAlignment=Enum.TextXAlignment.Right; ValLbl.Parent=Row
    local Track=Instance.new("Frame")
    Track.Size=UDim2.new(1,-26,0,5); Track.Position=UDim2.new(0,13,1,-16)
    Track.BackgroundColor3=C.SliderBg; Track.BorderSizePixel=0; Track.Active=true
    corner(Track,3); Track.Parent=Row
    local Fill=Instance.new("Frame")
    Fill.Size=UDim2.new(0,0,1,0); Fill.BackgroundColor3=C.Blue
    Fill.BorderSizePixel=0; corner(Fill,3); Fill.Parent=Track
    local Thumb=Instance.new("Frame")
    Thumb.Size=UDim2.new(0,14,0,14); Thumb.AnchorPoint=Vector2.new(0.5,0.5)
    Thumb.Position=UDim2.new(0,0,0.5,0)
    Thumb.BackgroundColor3=Color3.fromRGB(228,228,242)
    Thumb.BorderSizePixel=0; Thumb.Active=true; corner(Thumb,7); Thumb.Parent=Track

    local enabled=true
    local function setEnabled(on)
        enabled=on
        Row.BackgroundColor3=on and C.Row or C.RowAlt
        Lbl.TextColor3=on and C.Text or C.SubDim
        ValLbl.TextColor3=on and C.Accent or C.SubDim
        Track.BackgroundColor3=on and C.SliderBg or C.Border
        Fill.BackgroundColor3=on and C.Blue or C.SubDim
        Thumb.BackgroundColor3=on and Color3.fromRGB(228,228,242) or C.SubDim
    end
    local function setValue(v)
        v=math.clamp(v,minV,maxV)
        local pct=(v-minV)/(maxV-minV)
        Fill.Size=UDim2.new(pct,0,1,0); Thumb.Position=UDim2.new(pct,0,0.5,0)
        ValLbl.Text=string.format(fmt or "%.0f",v); onChanged(v)
    end
    local draggingSlider=false
    local c1=Thumb.InputBegan:Connect(function(i)
        if enabled and i.UserInputType==Enum.UserInputType.MouseButton1 then
            draggingSlider=true
            TweenService:Create(Thumb,TI,{BackgroundColor3=Color3.fromRGB(255,255,255)}):Play()
        end
    end)
    local c2=Track.InputBegan:Connect(function(i)
        if enabled and i.UserInputType==Enum.UserInputType.MouseButton1 then
            draggingSlider=true
            local rx=math.clamp(i.Position.X-Track.AbsolutePosition.X,0,Track.AbsoluteSize.X)
            setValue(minV+(maxV-minV)*(rx/Track.AbsoluteSize.X))
        end
    end)
    local c3=UIS.InputChanged:Connect(function(i)
        if enabled and draggingSlider and i.UserInputType==Enum.UserInputType.MouseMovement then
            local rx=math.clamp(i.Position.X-Track.AbsolutePosition.X,0,Track.AbsoluteSize.X)
            setValue(minV+(maxV-minV)*(rx/Track.AbsoluteSize.X))
        end
    end)
    local c4=UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            draggingSlider=false
            TweenService:Create(Thumb,TI,{BackgroundColor3=Color3.fromRGB(228,228,242)}):Play()
        end
    end)
    table.insert(sliderConns,c1); table.insert(sliderConns,c2)
    table.insert(sliderConns,c3); table.insert(sliderConns,c4)
    task.defer(function() setValue(defV) end)
    return setEnabled
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUÇÃO
-- ══════════════════════════════════════════════════════════════════════════════
rowOrder=0

local setESPRangeEnabled, setFlySpeedEnabled

-- ── Camuflagem ────────────────────────────────────────────────────────────────
makeHeader(OptionsFrame, "●", "Camuflagem")
makeToggle(OptionsFrame, "Invisibility", "Torna o personagem invisível localmente", function(on)
    ST.Invis=on; applyInvis(LocalPlayer.Character, on)
end)

-- ── Visual ────────────────────────────────────────────────────────────────────
makeHeader(OptionsFrame, "◉", "Combate Visual")
makeToggle(OptionsFrame, "ESP", "Destaca jogadores através de paredes", function(on)
    ST.ESP=on
    if setESPRangeEnabled then setESPRangeEnabled(on) end
    if not on then for _,e in pairs(pool) do hideEntry(e) end end
end)
setESPRangeEnabled = makeSlider(OptionsFrame, "ESP Range", 100, 1000, 500, "%.0f", function(v)
    CFG.ESPDist=v
end)
setESPRangeEnabled(false)

-- ── Voo ───────────────────────────────────────────────────────────────────────
makeHeader(OptionsFrame, "◈", "Voo")
makeToggle(OptionsFrame, "Fly", "Voa livremente · atravessa paredes e chão", function(on)
    if on then startFly() else stopFly() end
    if setFlySpeedEnabled then setFlySpeedEnabled(on) end
end)

--[[
  Controles em voo:
    W / S     → frente / trás na direção da câmera (pitch incluído)
    A / D     → strafe horizontal
    Space     → sobe (eixo Y global)
    LCtrl     → desce (eixo Y global)
    LShift    → velocidade ×2
]]
setFlySpeedEnabled = makeSlider(OptionsFrame, "Fly Speed", 10, 200, 60, "%.0f", function(v)
    CFG.FlySpeed=v
end)
setFlySpeedEnabled(false)

print("[VoidHub] v4.0 carregado.")
