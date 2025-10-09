-- =============================
-- UI Loader (Test3)
-- =============================
local Players   = game:GetService("Players")
local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local UI
do
    local ok, err = pcall(function()
        local src = game:HttpGet("https://raw.githubusercontent.com/IkantTongkol/Gui/refs/heads/main/gui2")
        UI = loadstring(src)()
        assert(type(UI) == "table" and UI.CreateWindow, "UI lib missing CreateWindow")
    end)
    if not ok then
        warn("[UI] Gagal load Test3:", err)
        local sg = Instance.new("ScreenGui")
        sg.Name = "AutoPlant_FallbackUI"
        sg.ResetOnSpawn = false
        sg.Parent = PlayerGui
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromOffset(330, 80)
        lbl.Position = UDim2.fromScale(0.03, 0.1)
        lbl.BackgroundColor3 = Color3.fromRGB(25,25,25)
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.TextWrapped = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Top
        lbl.Text = "UI gagal dimuat.\nCek koneksi/GitHub.\nScript berhenti."
        lbl.Parent = sg
        return
    end
end

-- =============================
-- Window & Tabs
-- =============================
local win      = UI:CreateWindow({ Name = "AutoPlantUI", Title = "Auto Plant (Tongkol GUI)" })
local tabPlant = win:CreateTab({ Name = "Main" })
local tabPack  = win:CreateTab({ Name = "Backpack" })
local tabCombat= win:CreateTab({ Name = "Combat" })
local tabShop  = win:CreateTab({ Name = "Shop" })
local tabUtil  = win:CreateTab({ Name = "Utility" })

local function notify(t, m, d)
    if win and win.Notify then win:Notify(t, m, d or 2.0) else print(("[UI] %s: %s"):format(t, m)) end
end

-- =============================
-- Services & Remotes
-- =============================
local RS      = game:GetService("ReplicatedStorage")
local Debris  = game:GetService("Debris")
local Plots   = workspace:WaitForChild("Plots")
local Remotes = RS:WaitForChild("Remotes")
local RunService = game:GetService("RunService")

local EquipItemRemote           = Remotes:WaitForChild("EquipItem")
local PlaceItemRemote           = Remotes:WaitForChild("PlaceItem")
local RemoveItemRemote          = Remotes:WaitForChild("RemoveItem")
local BuyItemRemote             = Remotes:WaitForChild("BuyItem")
local BuyGearRemote             = Remotes:WaitForChild("BuyGear")
local EquipBestBrainrotsRemote  = Remotes:WaitForChild("EquipBestBrainrots")
local GiftItemRemote            = Remotes:WaitForChild("GiftItem")
local AcceptGiftRemote          = Remotes:WaitForChild("AcceptGift")
local OpenEggRemote             = Remotes:WaitForChild("OpenEgg")
local FavoriteItemRemote        = Remotes:WaitForChild("FavoriteItem")
local ItemSellRemote            = Remotes:WaitForChild("ItemSell")
local UseItemRemote             = Remotes:WaitForChild("UseItem")
local WeaponAttack              = Remotes:WaitForChild("AttacksServer"):WaitForChild("WeaponAttack")

-- (opsional) rarity lookup
local Modules  = RS:FindFirstChild("Modules")
local Utility  = Modules and Modules:FindFirstChild("Utility")
local Util     = Utility and require(Utility:WaitForChild("Util"))

-- =============================
-- Helpers (shared)
-- =============================
local function shuffle(t)
    local rng = Random.new()
    for i = #t, 2, -1 do
        local j = rng:NextInteger(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

local function partCFrame(inst)
    if inst:IsA("BasePart") then return inst.CFrame end
    if inst:IsA("Model") then
        return inst.PrimaryPart and inst.PrimaryPart.CFrame or inst:GetPivot()
    end
    return CFrame.new()
end

local function setToggleState(toggle, state)
    if not toggle then return end
    pcall(function()
        if toggle.Set then toggle:Set(state)
        elseif toggle.SetState then toggle:SetState(state)
        elseif toggle.SetValue then toggle:SetValue(state)
        elseif toggle.Toggle and toggle.State ~= state then toggle:Toggle() end
    end)
end

local function updateDropdown(drop, names)
    if drop.Refresh     and pcall(function() drop:Refresh(names, true) end) then return end
    if drop.SetOptions  and pcall(function() drop:SetOptions(names) end)    then return end
    if drop.SetItems    and pcall(function() drop:SetItems(names) end)      then return end
    if drop.ClearOptions and drop.AddOption then
        local ok = pcall(function()
            drop:ClearOptions()
            for _, n in ipairs(names) do drop:AddOption(n) end
        end)
        if ok then return end
    end
    drop.Options = names
end

-- helper set dropdown current selection (aman ke berbagai lib)
local function setDropdownSelection(drop, values)
    if not drop then return end
    if drop.Set then drop:Set(values)
    elseif drop.SetValue then drop:SetValue(values)
    elseif drop.SetOption then drop:SetOption(values)
    elseif drop.Refresh then drop:Refresh(values, true)
    end
end

local function myPlayerFolder()
    local wp = workspace:FindFirstChild("Players")
    return wp and wp:FindFirstChild(LP.Name) or nil
end

local function safeName(inst)
    local raw = (typeof(inst)=="Instance" and inst.GetAttribute and inst:GetAttribute("ItemName"))
                or (typeof(inst)=="Instance" and inst.Name)
                or tostring(inst)
    return tostring(raw):gsub("^%b[]%s*", "")
end

local function equipTool(tool)
    if not tool or not tool.Parent then return false end
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local deadline = os.clock()+2
    if hum then pcall(function() hum:EquipTool(tool) end) end
    repeat
        if tool.Parent==char then return true end
        task.wait(0.05)
    until os.clock()>deadline
    return tool.Parent==char
end

local function isFavorited(inst)
    if typeof(inst) ~= "Instance" or not inst.GetAttribute then return false end
    local ok, v = pcall(inst.GetAttribute, inst, "Favorited")
    return ok and v == true
end

local function ensureFav(id, inst)
    if isFavorited(inst) then return end
    pcall(function() FavoriteItemRemote:FireServer(id) end)
end

local function ensureUnfav(id, inst)
    if not isFavorited(inst) then return end
    pcall(function() FavoriteItemRemote:FireServer(id) end)
end

local function getToolByBaseName(base)
    if not base or #base==0 then return nil end
    base = tostring(base):lower()
    local function pick(container)
        if not container then return end
        for _,t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then
                local n1 = t.Name:lower():gsub("^%b[]%s*", "")
                local n2 = safeName(t):lower()
                if n1==base or n2==base or n1:find(base,1,true) or n2:find(base,1,true) then return t end
            end
        end
    end
    local ch = LP.Character
    return pick(ch) or pick(LP:FindFirstChild("Backpack")) or pick(myPlayerFolder())
end
-- =============================
-- COMBAT / COMBO (taruh di tabCombat)
-- =============================
local function norm(s) return (tostring(s or "")):lower() end

-- Rarity & state
local ALL_RARITIES = { "Rare","Epic","Mythic","Legendary","Limited","Secret","Godly" }
local CMB_STATE = {
    -- filter rarity bersama
    allowedRarity = { godly=true, secret=true, limited=true },

    -- Toggle 1: Auto TP + Hit
    autoTP_enabled   = false,
    yOffset          = 0,
    stickYOffset     = 0,
    lockFreeze       = true,
    bufferDelay      = 0.12,
    hitInterval      = 0.20,
    autoEquipBat     = true,

    -- Toggle 2: Auto Hit Gear (single)
    gearFire_enabled = false,
    gearChoice       = "Banana Gun", -- "Frost Grenade" | "Banana Gun" | "Carrot Launcher" | "Frost Blower"

    -- Toggle 3: Combo Gear (loop)
    combo_enabled    = false,
    comboPeriod      = 2.0,
}

-- ========== brainrot rarity (model) ==========
local _brWarned = {}
local function cmbGetBRName(model)
    local keys = {"Brainrot","BrainRot","brainrot","Name","Title"}
    for _,k in ipairs(keys) do
        local v = model:GetAttribute(k)
        if type(v)=="string" and #v>0 then return v end
    end
    return model.Name
end
local function cmbGetRarityModel(model)
    if not Util or not Util.GetBrainrotEntry then return nil end
    local nm = cmbGetBRName(model)
    local ok, entry = pcall(Util.GetBrainrotEntry, Util, nm)
    if ok and entry and entry.Rarity then return entry.Rarity end
    if not _brWarned[nm] then _brWarned[nm]=true warn("[COMBO] Rarity not found:", nm) end
    return nil
end
local function cmbIsAllowed(r)
    if not r then return false end
    r = norm(r)
    return CMB_STATE.allowedRarity[r] == true
end

-- ========== TP + stick ==========
local HRP = (LP.Character or LP.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart", 15)
local Hum = (LP.Character or LP.CharacterAdded:Wait()):WaitForChild("Humanoid", 15)
LP.CharacterAdded:Connect(function(ch)
    task.defer(function()
        HRP = ch:WaitForChild("HumanoidRootPart", 15)
        Hum = ch:WaitForChild("Humanoid", 15)
    end)
end)

local stick = { cons = {}, model=nil, id=nil }
local DEFAULT_WALKSPEED, DEFAULT_JUMPPOWER, DEFAULT_JUMPHEIGHT = 16, 50, 7.2
local function cmbUnfreeze()
    if not Hum then return end
    Hum.AutoRotate = true
    Hum.PlatformStand = false
    if Hum.UseJumpPower ~= nil then Hum.JumpPower = DEFAULT_JUMPPOWER else pcall(function() Hum.JumpHeight = DEFAULT_JUMPHEIGHT end) end
    Hum.WalkSpeed = DEFAULT_WALKSPEED
end
local function cmbFreeze()
    if not Hum then return end
    Hum.AutoRotate = false
    if CMB_STATE.lockFreeze then
        if Hum.UseJumpPower ~= nil then Hum.JumpPower = 0 end
        Hum.WalkSpeed = 0
        Hum.PlatformStand = false
    end
end
local function cmbDetachStick()
    for _,o in ipairs(stick.cons) do
        if typeof(o)=="Instance" and o.Destroy then pcall(function() o:Destroy() end) end
    end
    stick.cons, stick.model, stick.id = {}, nil, nil
    cmbUnfreeze()
end
local function cmbWaitModelReady(m, t)
    t = t or 5; local t0 = os.clock()
    while os.clock()-t0 < t do
        if m and m.Parent and m:IsDescendantOf(workspace) then
            local ok = pcall(m.GetBoundingBox, m); if ok then return true end
        end
        task.wait(0.05)
    end
    return false
end
local function cmbTPAbove(m)
    if not (m and HRP) then return end
    if not cmbWaitModelReady(m, 5) then return end
    local ok, cf, size = pcall(m.GetBoundingBox, m); if not ok then return end
    local top = cf.Position + Vector3.new(0, size.Y + (CMB_STATE.yOffset or 0), 0)
    HRP.AssemblyLinearVelocity = Vector3.zero
    local cam = workspace.CurrentCamera
    local look = cam and cam.CFrame.LookVector or Vector3.new(0,0,-1)
    HRP.CFrame = CFrame.new(top, top + look)
end
local function cmbAttachStick(m, id)
    cmbDetachStick()
    if not (HRP and m and m.PrimaryPart) then return end

    local a0 = HRP:FindFirstChild("CMB_Att0") or Instance.new("Attachment")
    a0.Name, a0.Parent = "CMB_Att0", HRP

    local a1 = m.PrimaryPart:FindFirstChild("CMB_Att1") or Instance.new("Attachment")
    a1.Name, a1.Parent = "CMB_Att1", m.PrimaryPart
    a1.Position = Vector3.new(0, (CMB_STATE.stickYOffset or 0), 0)

    local ap = Instance.new("AlignPosition")
    ap.Attachment0, ap.Attachment1 = a0, a1
    ap.RigidityEnabled = true
    ap.MaxForce = math.huge
    ap.Responsiveness = 300
    ap.ApplyAtCenterOfMass = true
    ap.Parent = HRP

    local ao = Instance.new("AlignOrientation")
    ao.Attachment0, ao.Attachment1 = a0, a1
    ao.RigidityEnabled = true
    ao.MaxTorque = math.huge
    ao.Responsiveness = 300
    ao.Parent = HRP

    stick.cons, stick.model, stick.id = {a0,a1,ap,ao}, m, id
    cmbFreeze()
end

-- ========== tool helpers ==========
local function moveToolToBackpack(tool)
    if not (tool and tool:IsA("Tool")) then return end
    local bp = LP:FindFirstChild("Backpack")
    if bp and tool.Parent ~= bp then pcall(function() tool.Parent = bp end) end
end
local function findToolByPartials(partials)
    local char, bp = LP.Character, LP:FindFirstChild("Backpack")
    local function match(t)
        local n = norm(t.Name)
        for _,key in ipairs(partials) do if not n:find(key,1,true) then return false end end
        return true
    end
    if char then for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") and match(t) then return t,"Character" end end end
    if bp   then for _,t in ipairs(bp:GetChildren())   do if t:IsA("Tool") and match(t) then return t,"Backpack"  end end end
    return nil
end
local function ensureBlowerOff()
    local t = findToolByPartials({"frost","blow"})
    if t then pcall(function() UseItemRemote:FireServer({ Tool = t, Toggle = false }) end) end
end
-- EXCLUSIVE equip aman register
local function cmbStashAllExcept(char, bp, keep)
    if not char or not bp then return end
    for _,t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t ~= keep then pcall(function() t.Parent = bp end) end
    end
end
local function ensureEquippedExclusive(tool, timeout)
    if not tool then return false end
    local char = LP.Character or LP.CharacterAdded:Wait()
    local bp   = LP:FindFirstChild("Backpack")
    ensureBlowerOff()
    cmbStashAllExcept(char, bp, tool)

    if tool.Parent ~= char then
        if EquipItemRemote then
            pcall(function() EquipItemRemote:FireServer(tool) end)
            pcall(function() EquipItemRemote:FireServer(tool.Name) end)
        end
        if tool.Parent ~= char and tool.Parent ~= nil then pcall(function() tool.Parent = char end) end
    end

    local t0, lim = os.clock(), (timeout or 1.0)
    while os.clock()-t0 < lim do
        local onlyThis = (tool.Parent == char)
        if onlyThis then
            for _,t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") and t ~= tool then onlyThis=false break end
            end
        end
        if onlyThis then return true end
        cmbStashAllExcept(char, bp, tool)
        task.wait(0.05)
    end
    return (tool.Parent == char)
end

-- ========== auto-equip bat + hit ==========
local function findBatInBackpack()
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return nil end
    for _,tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") and norm(tool.Name):find("bat") then return tool end
    end
    return nil
end
local function cmbEquipBat()
    if not CMB_STATE.autoEquipBat then return end
    local tool = findBatInBackpack(); if not tool then return end
    if EquipItemRemote then
        local ok = pcall(function() EquipItemRemote:FireServer(tool) end)
        if not ok then pcall(function() EquipItemRemote:FireServer(tool.Name) end) end
    end
    local char = LP.Character
    if char and tool.Parent == LP.Backpack then pcall(function() tool.Parent = char end) end
end

local hitToken = 0
local function cmbVisualHit(model)
    if not (model and model.PrimaryPart) then return end
    local att = Instance.new("Attachment", model.PrimaryPart)
    local pe = Instance.new("ParticleEmitter")
    pe.Rate = 0; pe.Lifetime = NumberRange.new(0.2,0.35)
    pe.Speed = NumberRange.new(6,10); pe.SpreadAngle = Vector2.new(60,60)
    pe.Texture = "rbxassetid://243660364"
    pe.Parent = att; pe:Emit(14)
    Debris:AddItem(att,1)
end
local function startHitLoop()
    if not WeaponAttack then return end
    hitToken += 1; local my = hitToken
    task.spawn(function()
        while my == hitToken do
            if stick.model and stick.model.Parent then
                local id = stick.id or stick.model:GetAttribute("ID") or stick.model.Name
                pcall(function() WeaponAttack:FireServer({ tostring(id) }) end)
                cmbVisualHit(stick.model)
            end
            task.wait(CMB_STATE.hitInterval or 0.2)
        end
    end)
end
local function stopHitLoop() hitToken += 1 end

-- ========== active & selection ==========
local ACTIVE = {}  -- [id] = model
local CURRENT = { id=nil, model=nil, rarity=nil }
local preferredRarity = nil
local locked = false
local buf, bufScheduled = {}, false
local handled = {}

local function setCurrent(id, m)
    CURRENT.id, CURRENT.model = id, m
    local r = cmbGetRarityModel(m)
    CURRENT.rarity = r and norm(r) or nil
    preferredRarity = CURRENT.rarity
end
local function clearCurrent() CURRENT.id, CURRENT.model, CURRENT.rarity = nil,nil,nil end
local function markHandled(id) handled[id] = true end
local function isHandled(id) return handled[id]==true end

local function pickSameRarity(rWanted)
    if not rWanted then return nil,nil end
    local char = LP.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local bestId, bestModel, bestDist = nil,nil,math.huge
    for id,m in pairs(ACTIVE) do
        if m and m.Parent and m.PrimaryPart then
            local r = cmbGetRarityModel(m)
            if r and norm(r)==rWanted then
                local d = hrp and (m.PrimaryPart.Position-hrp.Position).Magnitude or 0
                if d < bestDist then bestId, bestModel, bestDist = id, m, d end
            end
        end
    end
    return bestId, bestModel
end

local function chooseBestFromBuf()
    local cam = workspace.CurrentCamera
    local best, bestRank, bestDist = nil, -1, 1e9
    for _,it in ipairs(buf) do
        local m = it.model
        if m and m.Parent then
            local r = cmbGetRarityModel(m)
            if cmbIsAllowed(r) then
                local rank = ({rare=1, epic=2, mythic=3, legendary=4, limited=4, secret=5, godly=6})[norm(r)] or 0
                local dist = 1e9
                local ok, cf = pcall(m.GetBoundingBox, m)
                if ok and cam then dist = (cf.Position - cam.CFrame.Position).Magnitude end
                if rank > bestRank or (rank==bestRank and dist<bestDist) then best, bestRank, bestDist = it, rank, dist end
            end
        end
    end
    return best
end

local function lockOn(pick)
    cmbEquipBat()
    cmbTPAbove(pick.model)
    cmbAttachStick(pick.model, pick.id)
    setCurrent(pick.id, pick.model)
    locked = true
    startHitLoop()
end

local function processBuf()
    bufScheduled = false
    if locked or not CMB_STATE.autoTP_enabled or #buf==0 then buf = {}; return end
    local pick = chooseBestFromBuf(); buf = {}
    if not pick or not pick.model or not pick.model.Parent then return end
    task.defer(function() lockOn(pick) end)
end

local function enqueue(m, id)
    if isHandled(id) or locked or not CMB_STATE.autoTP_enabled then return end
    markHandled(id)
    table.insert(buf, {model=m, id=id})
    if not bufScheduled then
        bufScheduled = true
        task.delay(CMB_STATE.bufferDelay or 0.12, processBuf)
    end
end

local function relockFromWorld()
    if locked or not CMB_STATE.autoTP_enabled then return end
    local sid, sm = pickSameRarity(preferredRarity)
    if sid and sm then lockOn({id=sid, model=sm}) return end
    local char = LP.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local bestId, bestM, bestD
    for id,m in pairs(ACTIVE) do
        if m and m.Parent and m.PrimaryPart then
            local r = cmbGetRarityModel(m)
            if cmbIsAllowed(r) then
                local d = hrp and (m.PrimaryPart.Position-hrp.Position).Magnitude or 0
                if not bestD or d<bestD then bestId, bestM, bestD = id, m, d end
            end
        end
    end
    if bestId and bestM then lockOn({id=bestId, model=bestM}) end
end

local function unlock(_reason)
    stopHitLoop()
    cmbDetachStick()
    locked = false
    relockFromWorld()
end

-- ========== remote hooks ==========
if SpawnBR then
    SpawnBR.OnClientEvent:Connect(function(payload)
        if not payload then return end
        local m = payload.Model or payload.model
        local id = payload.ID or payload.Id or (m and m:GetDebugId()) or ("id_"..tostring(math.random(1,1e6)))
        if not m then return end
        ACTIVE[id] = m
        local r = cmbGetRarityModel(m)
        if not locked and CMB_STATE.autoTP_enabled and preferredRarity and r and norm(r)==preferredRarity then
            local sid, sm = pickSameRarity(preferredRarity)
            if sid and sm then lockOn({id=sid, model=sm}) return end
        end
        if cmbIsAllowed(r) then enqueue(m, id) end
    end)
end
if DeleteBR then
    DeleteBR.OnClientEvent:Connect(function(id)
        if id then ACTIVE[id] = nil end
        if CURRENT.id and id == CURRENT.id then
            local lastR = preferredRarity
            stopHitLoop()
            cmbDetachStick()
            locked = false
            clearCurrent()
            if CMB_STATE.autoTP_enabled then
                local sid, sm = pickSameRarity(lastR)
                if sid and sm then lockOn({id=sid, model=sm}) end
            end
        end
    end)
end

-- seed ACTIVE dari world (jaga2)
task.spawn(function()
    local sm = workspace:FindFirstChild("ScriptedMap", 15)
    local br = sm and sm:FindFirstChild("Brainrots", 15)
    if not br then return end
    for _,m in ipairs(br:GetChildren()) do
        if m:IsA("Model") then ACTIVE[m:GetAttribute("ID") or m.Name] = m end
    end
    br.ChildAdded:Connect(function(m)
        if m:IsA("Model") then
            ACTIVE[m:GetAttribute("ID") or m.Name] = m
            local r = cmbGetRarityModel(m)
            if not locked and CMB_STATE.autoTP_enabled and preferredRarity and r and norm(r)==preferredRarity then
                local sid, sm = pickSameRarity(preferredRarity)
                if sid and sm then lockOn({id=sid, model=sm}) end
            end
        end
    end)
    br.ChildRemoved:Connect(function(m)
        local id = m:GetAttribute("ID") or m.Name
        ACTIVE[id] = nil
        if stick.model and m == stick.model then unlock("removed") end
    end)
end)

-- watchdog
RunService.Stepped:Connect(function()
    if locked then
        if not (stick.model and stick.model.Parent) then unlock("lost model") return end
        local hasAP, hasAO = false, false
        for _,o in ipairs(stick.cons) do
            if typeof(o)=="Instance" and o.Parent then
                if o:IsA("AlignPosition") then hasAP=true end
                if o:IsA("AlignOrientation") then hasAO=true end
            end
        end
        if (not hasAP) or (not hasAO) then cmbAttachStick(stick.model, stick.id) end
    else
        if CMB_STATE.autoTP_enabled then relockFromWorld() end
    end
end)

-- ========== target pos untuk gear ==========
local function chooseTargetPos()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.zero end

    local bestSame, bestSameDist
    local bestAllowed, bestAllowedDist
    local bestAny, bestAnyDist

    for _,m in pairs(ACTIVE) do
        if m and m.Parent and m.PrimaryPart then
            local pos = m.PrimaryPart.Position
            local d = (pos - hrp.Position).Magnitude
            local r = cmbGetRarityModel(m); local rn = r and norm(r) or nil
            if preferredRarity and rn == preferredRarity then
                if not bestSameDist or d<bestSameDist then bestSame, bestSameDist = pos, d end
            end
            if r and cmbIsAllowed(r) then
                if not bestAllowedDist or d<bestAllowedDist then bestAllowed, bestAllowedDist = pos, d end
            end
            if not bestAnyDist or d<bestAnyDist then bestAny, bestAnyDist = pos, d end
        end
    end
    return bestSame or bestAllowed or bestAny or hrp.Position
end

-- ========== Gear registry ==========
local REG = {
    ["Frost Grenade"]   = { keys={"frost","gren"}, time=0.50, kind="pulse" },
    ["Banana Gun"]      = { keys={"banana","gun"}, time=0.04, kind="pulse" },
    ["Carrot Launcher"] = { keys={"carrot","launc"}, time=0.23, kind="pulse" },
    ["Frost Blower"]    = { keys={"frost","blow"}, time=0.10, kind="toggle" },
}
local function returnGearByEntry(entry)
    if not entry then return end
    local t = findToolByPartials(entry.keys)
    if t and t.Parent == (LP.Character or LP.CharacterAdded:Wait()) then moveToolToBackpack(t) end
end
local function returnAllKnownTools()
    for _,entry in pairs(REG) do returnGearByEntry(entry) end
end

-- panggil UseItem aman
local lastUseAt = 0
local function safeUse(payload)
    if os.clock() - lastUseAt < 0.06 then task.wait(0.06) end
    lastUseAt = os.clock()
    local ok = pcall(function() UseItemRemote:FireServer(payload) end)
    if ok then return true end
    ok = pcall(function() UseItemRemote:FireServer(unpack({payload})) end)
    if ok then return true end
    ok = pcall(function() local a={}; a[1]=payload; UseItemRemote:FireServer(table.unpack(a)) end)
    return ok
end

-- ========== Toggle 2: Auto Hit Gear (single) ==========
local gearFireToken = 0
local function stopGearFireLoop() gearFireToken += 1 end
local function startGearFireLoop()
    gearFireToken += 1; local my = gearFireToken
    task.spawn(function()
        while CMB_STATE.gearFire_enabled and my == gearFireToken do
            local entry = REG[CMB_STATE.gearChoice]
            if entry then
                local tool = findToolByPartials(entry.keys)
                if tool and ensureEquippedExclusive(tool, 1.0) then
                    local pos = chooseTargetPos()
                    if entry.kind=="pulse" then
                        safeUse({ Toggle=true, Time=entry.time, Tool=tool, Pos=pos })
                        if CMB_STATE.gearChoice == "Frost Grenade" then
                            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                            if hum then pcall(function() hum:UnequipTools() end) end
                            cmbStashAllExcept(LP.Character, LP:FindFirstChild("Backpack"), nil)
                        end
                    else
                        safeUse({ Tool=tool, Toggle=true })
                    end
                end
            else
                task.wait(0.2)
            end
            task.wait(0.10)
        end
        if CMB_STATE.gearChoice == "Frost Blower" then
            local t = findToolByPartials(REG["Frost Blower"].keys)
            if t then safeUse({ Tool=t, Toggle=false }) end
        end
    end)
end

-- ========== Toggle 3: Combo Gear (Frost×1 → Banana×4 → Carrot×2) ==========
local comboToken = 0
local function runComboCycle()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local bp   = LP:FindFirstChild("Backpack")

    -- Frost x1
    do
        local e = REG["Frost Grenade"]
        local t = findToolByPartials(e.keys)
        if t and ensureEquippedExclusive(t, 1.0) then
            local pos = chooseTargetPos()
            safeUse({ Toggle=true, Time=e.time, Tool=t, Pos=pos })
            task.wait(0.12)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:UnequipTools() end) end
            cmbStashAllExcept(char, bp, nil)
            task.wait(0.03)
        end
    end

    -- Banana x4
    do
        local e = REG["Banana Gun"]
        local t = findToolByPartials(e.keys)
        if t and ensureEquippedExclusive(t, 1.0) then
            local pos = chooseTargetPos()
            for i=1,4 do
                safeUse({ Toggle=true, Time=e.time, Tool=t, Pos=pos })
                task.wait(0.06)
            end
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:UnequipTools() end) end
            cmbStashAllExcept(char, bp, nil)
            task.wait(0.03)
        end
    end

    -- Carrot x2
    do
        local e = REG["Carrot Launcher"]
        local t = findToolByPartials(e.keys)
        if t and ensureEquippedExclusive(t, 1.0) then
            local pos = chooseTargetPos()
            for i=1,2 do
                safeUse({ Toggle=true, Time=e.time, Tool=t, Pos=pos })
                task.wait(0.08)
            end
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:UnequipTools() end) end
            cmbStashAllExcept(char, bp, nil)
        end
    end
end

-- ========== GUI: tabCombat ==========
tabCombat:CreateSectionFold({ Title = "Rarity Filter (Shared)" })
local cmbInit = {}
for _,r in ipairs(ALL_RARITIES) do if CMB_STATE.allowedRarity[norm(r)] then cmbInit[#cmbInit+1]=r end end
local ddR = tabCombat:Dropdown({
    Name = "Allowed Rarity (multi)",
    Options = ALL_RARITIES,
    MultiSelection = true,
    CurrentOption = cmbInit,
    Placeholder = "All",
    SummaryMaxItems = 3,
    SummaryMaxChars = 26,
    Callback = function(arr)
        local set = {}
        for _,v in ipairs(arr or {}) do set[norm(v)] = true end
        CMB_STATE.allowedRarity = set
    end
})
tabCombat:Button({
    Name = "Preset: Godly + Secret (+Limited)",
    Callback = function()
        CMB_STATE.allowedRarity = { godly=true, secret=true, limited=true }
        setDropdownSelection(ddR, {"Godly","Secret","Limited"})
    end
})
tabCombat:Button({
    Name = "Allow All",
    Callback = function()
        local all = {}
        for _,r in ipairs(ALL_RARITIES) do all[norm(r)] = true end
        CMB_STATE.allowedRarity = all
        local tmpAll = {}
        for i,v in ipairs(ALL_RARITIES) do tmpAll[i]=v end
        setDropdownSelection(ddR, tmpAll)
    end
})
tabCombat:Button({
    Name = "Clear (No Filter)",
    Callback = function()
        CMB_STATE.allowedRarity = {}
        setDropdownSelection(ddR, {})
    end
})

-- Toggle 1: Auto TP+Hit
tabCombat:CreateSectionFold({ Title = "Auto Hit (TP + Lock + Freeze)" })
tabCombat:Toggle({
    Name = "Enable Auto TP + Hit (Freeze On Lock)",
    Default = (CMB_STATE.autoTP_enabled and CMB_STATE.lockFreeze and CMB_STATE.autoEquipBat) or false,
    Callback = function(on)
        CMB_STATE.autoTP_enabled = on
        CMB_STATE.lockFreeze     = on
        CMB_STATE.autoEquipBat   = on

        if not on then
            buf, bufScheduled = {}, false
            if locked then unlock("disabled") end
            stopHitLoop()
            cmbUnfreeze()
            local t = findToolByPartials(REG["Frost Blower"].keys)
            if t then safeUse({ Tool=t, Toggle=false }) end
            returnAllKnownTools()
        else
            task.defer(function() relockFromWorld() end)
        end
    end
})

-- Toggle 2: Auto Hit Gear (single) -- mutual exclusive dengan Combo
tabCombat:CreateSectionFold({ Title = "Auto Hit Gear (Single)" })
local gearList = { "Frost Grenade","Banana Gun","Carrot Launcher","Frost Blower" }
local ddGear = tabCombat:Dropdown({
    Name = "Gear",
    Options = gearList,
    MultiSelection = false,
    CurrentOption = CMB_STATE.gearChoice,
    Callback = function(v) CMB_STATE.gearChoice = type(v)=="table" and v[1] or v end
})
tabCombat:Toggle({
    Name = "Enable Auto Hit Gear",
    Default = CMB_STATE.gearFire_enabled,
    Callback = function(on)
        if on and CMB_STATE.combo_enabled then
            CMB_STATE.combo_enabled = false
            comboToken += 1 -- stop combo
        end
        CMB_STATE.gearFire_enabled = on
        if on then
            startGearFireLoop()
        else
            stopGearFireLoop()
            local t = findToolByPartials(REG["Frost Blower"].keys)
            if t then safeUse({ Tool=t, Toggle=false }) end
            returnGearByEntry(REG[CMB_STATE.gearChoice])
        end
    end
})

-- Toggle 3: Combo Gear -- mutual exclusive dengan Single
tabCombat:CreateSectionFold({ Title = "Combo Gear (Frost×1 → Banana×4 → Carrot×2)" })
tabCombat:Paragraph("Loop tiap ~2 detik. Target prioritas: rarity sama (target terakhir) → allowed → terdekat.")
tabCombat:Toggle({
    Name = "Enable Combo",
    Default = CMB_STATE.combo_enabled,
    Callback = function(on)
        if on and CMB_STATE.gearFire_enabled then
            CMB_STATE.gearFire_enabled = false
            stopGearFireLoop()
        end
        CMB_STATE.combo_enabled = on
        if on then
            comboToken += 1; local my = comboToken
            task.spawn(function()
                while my == comboToken and CMB_STATE.combo_enabled do
                    local t0 = os.clock()
                    runComboCycle()
                    local dt = os.clock()-t0
                    local rest = (CMB_STATE.comboPeriod or 2.0) - dt
                    if rest > 0 then task.wait(rest) end
                end
            end)
        else
            comboToken += 1
            returnGearByEntry(REG["Frost Grenade"])
            returnGearByEntry(REG["Banana Gun"])
            returnGearByEntry(REG["Carrot Launcher"])
            local t = findToolByPartials(REG["Frost Blower"].keys)
            if t then safeUse({ Tool=t, Toggle=false }) moveToolToBackpack(t) end
        end
    end
})

-- bootstrap kecil
task.delay(0.25, function()
    local sm = workspace:FindFirstChild("ScriptedMap")
    local br = sm and sm:FindFirstChild("Brainrots")
    if br then
        for _, m in ipairs(br:GetChildren()) do
            if m:IsA("Model") then ACTIVE[m:GetAttribute("ID") or m.Name] = m end
        end
    end
    if CMB_STATE.autoTP_enabled then relockFromWorld() end
end)

-- =============================
-- Planting
-- =============================
local DELAY_BETWEEN     = 0.10
local AUTO_BUY_INTERVAL = 0.30

local function findMyPlot()
    for _, p in ipairs(Plots:GetChildren()) do
        if p:GetAttribute("OwnerUserId") == LP.UserId then return p end
    end
    for _, p in ipairs(Plots:GetChildren()) do
        if p:GetAttribute("Owner") == LP.Name then return p end
    end
end

local function collectGrassTiles(plot)
    local tiles = {}
    if not plot then return tiles end
    local rows = plot:FindFirstChild("Rows")
    if not rows then return tiles end
    for _, row in ipairs(rows:GetChildren()) do
        local grass = row:FindFirstChild("Grass")
        if grass then
            for _, tile in ipairs(grass:GetChildren()) do
                if tile:IsA("BasePart") or tile:IsA("Model") then
                    table.insert(tiles, tile)
                end
            end
        end
    end
    return tiles
end

local function isTileFree(tile)
    if tile:GetAttribute("Occupied") == true then return false end
    if tile:FindFirstChild("Plant") or tile:FindFirstChild("Crop") then return false end
    return true
end

-- Seeds whitelist
local SeedsFolder = RS:WaitForChild("Assets"):WaitForChild("Seeds")
local function getSeedSet()
    local set = {}
    for _, inst in ipairs(SeedsFolder:GetChildren()) do
        set[inst.Name:gsub("%s+Seed$", "")] = true
    end
    return set
end
local SEED_WHITELIST = getSeedSet()

-- Scan Backpack Seeds
local function scanBackpackSeeds()
    local bag = LP:WaitForChild("Backpack")
    local byType, seen = {}, {}
    for _, inst in ipairs(bag:GetDescendants()) do
        local id = inst.GetAttribute and inst:GetAttribute("ID")
        if id and not seen[id] then
            local itemName = (inst.GetAttribute and inst:GetAttribute("ItemName")) or inst.Name
            if itemName:find("Seed") then
                local plant = itemName:gsub("^%b[]%s*", ""):gsub("%s*Seed%s*$", "")
                if SEED_WHITELIST[plant] then
                    byType[plant] = byType[plant] or { stacks = {} }
                    table.insert(byType[plant].stacks, { id = id, inst = inst })
                    seen[id] = true
                end
            end
        end
    end
    return byType
end

local function getWorkspacePlayerFolder()
    return myPlayerFolder()
end

local function waitSeedInWorkspaceByID(id, plantName, timeout)
    local pf = getWorkspacePlayerFolder()
    if not pf then return false end
    local deadline = os.clock() + (timeout or 2)
    repeat
        for _, c in ipairs(pf:GetChildren()) do
            local ok, v = pcall(c.GetAttribute, c, "ID")
            if ok and v ~= nil and tostring(v) == tostring(id) then
                return true
            end
        end
        if plantName then
            for _, t in ipairs(pf:GetChildren()) do
                if t:IsA("Tool") and t.Name:find("Seed") and t.Name:find(plantName) then
                    return true
                end
            end
        end
        task.wait(0.05)
    until os.clock() > deadline
    return false
end

local function equipSeedIntoWorkspace(stack)
    local id   = stack.id
    local inst = stack.inst
    local plantName = (inst and ((inst.GetAttribute and inst:GetAttribute("ItemName")) or inst.Name) or "")
    plantName = plantName:gsub("^%b[]%s*",""):gsub("%s*Seed%s*$","")

    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if hum and inst and inst.Parent then pcall(function() hum:EquipTool(inst) end) end

    pcall(function()
        if EquipItemRemote:IsA("RemoteEvent") then
            EquipItemRemote:FireServer({ ID = id, Instance = inst, ItemName = inst and inst.Name or nil })
        elseif EquipItemRemote:IsA("BindableEvent") then
            EquipItemRemote:Fire(inst or id)
        elseif EquipItemRemote:IsA("RemoteFunction") then
            EquipItemRemote:InvokeServer({ ID = id })
        end
    end)

    if waitSeedInWorkspaceByID(id, plantName, 2) then return true end

    local pf = getWorkspacePlayerFolder()
    if pf and inst and inst.Parent and not inst:IsDescendantOf(pf) then
        pcall(function() inst.Parent = pf end)
        if waitSeedInWorkspaceByID(id, plantName, 1) then return true end
    end
    return false
end

local function sendPlant(stack, tile, plantName)
    local payload = {
        ID     = stack.id,
        CFrame = partCFrame(tile),
        Item   = plantName,
        Floor  = tile,
    }
    local ok = pcall(function()
        PlaceItemRemote:FireServer(payload)
    end)
    if not ok then
        warn("[AutoPlant] PlaceItem:FireServer gagal")
    end
end

local function prepareAndSendPlant(stack, tile, plantName)
    equipSeedIntoWorkspace(stack)
    sendPlant(stack, tile, plantName)
end

-- Shop Seed/Gear
local function getAllSeedNamesFull()
    local list = {}
    for _, inst in ipairs(SeedsFolder:GetChildren()) do
        table.insert(list, inst.Name)
    end
    table.sort(list)
    return list
end

local function buySeedOnce(fullSeedName)
    local ok = pcall(function()
        BuyItemRemote:FireServer(fullSeedName)
    end)
    if not ok then warn("[AutoPlant] BuyItem gagal:", fullSeedName) end
    return ok
end

local function getAllGearNames()
    local list = {}
    local ok, gearStocks = pcall(function()
        return require(RS.Modules.Library.GearStocks)
    end)
    if ok and type(gearStocks) == "table" then
        for gearName in pairs(gearStocks) do
            if type(gearName) == "string" then table.insert(list, gearName) end
        end
    end
    if #list == 0 then list = { "Water Bucket", "Frost Blower", "Frost Grenade", "Carrot Launcher", "Banana Gun" } end
    table.sort(list)
    return list
end

local function buyGearOnce(gearName)
    local ok = pcall(function()
        BuyGearRemote:FireServer(gearName)
    end)
    if not ok then warn("[AutoPlant] BuyGear gagal:", gearName) end
    return ok
end

-- UI State (Planting)
local ownedSeeds = {}
local selectedSeeds = {}
local onlyFree, running = true, false

tabPlant:CreateSectionFold({ Title = "Auto Plant Seed" })
tabPlant:Paragraph(
  "Cara Menggunakan Auto Plant Seed\n" ..
  "Klik 'Refresh Seed' untuk scan seed di backpack\n" ..
  "- Habis itu pilih seed \n" ..
  "- Centang 'Only Free Tiles' untuk menanam hanya di tile kosong\n" ..
  "- Klik toggle 'Auto Plant' untuk mulai menanam"
)

local ddSeeds = tabPlant:Dropdown({
    Name = "Select Seed",
    Options = {"(Klik 'Refresh Seed')"},
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values) == "table" then
            selectedSeeds = values
        elseif typeof(values) == "string" then
            selectedSeeds = { values }
        else
            selectedSeeds = {}
        end
    end
})

local function refreshSeeds()
    ownedSeeds = scanBackpackSeeds()
    local names = {}
    for k in pairs(ownedSeeds) do table.insert(names, k) end
    table.sort(names)
    updateDropdown(ddSeeds, names)
    notify("Seed List", ("%d jenis ditemukan"):format(#names), 1.2)
end

tabPlant:Button({ Name = "Refresh Seed (sekali)", Callback = refreshSeeds })

tabPlant:Toggle({
    Name = "Only Free Tiles",
    Default = true,
    Callback = function(v) onlyFree = v end
})

local function getEmptyTiles(plot)
    local tiles = collectGrassTiles(plot)
    if onlyFree then
        local free = {}
        for _, t in ipairs(tiles) do if isTileFree(t) then table.insert(free, t) end end
        tiles = free
    end
    return tiles
end

local startToggle
local function runPlantAllMulti(seedList)
    local plot = findMyPlot()
    if not plot then notify("Error","Plot tidak ditemukan",1.6); setToggleState(startToggle,false); return 0 end
    local tiles = getEmptyTiles(plot)
    if #tiles == 0 then setToggleState(startToggle,false); return 0 end
    shuffle(tiles)

    ownedSeeds = scanBackpackSeeds()

    local order = {}
    for _, name in ipairs(seedList) do
        if ownedSeeds[name] then table.insert(order, name) end
    end
    if #order == 0 then
        notify("Error","Semua pilihan tidak ada stok",1.6)
        setToggleState(startToggle,false)
        return 0
    end

    local sIdx = {}
    for _, name in ipairs(order) do sIdx[name] = 1 end

    local planted, i, seedIdx = 0, 1, 1
    while running and i <= #tiles and #order > 0 do
        local name = order[seedIdx]
        local bucket = ownedSeeds[name]
        if (not bucket) or (#bucket.stacks == 0) then
            table.remove(order, seedIdx)
            if seedIdx > #order then seedIdx = 1 end
        else
            local idx = sIdx[name]; if idx > #bucket.stacks then idx = 1 end
            local stack = bucket.stacks[idx]
            sIdx[name] = (idx % #bucket.stacks) + 1

            local tile = tiles[i]; i = i + 1
            prepareAndSendPlant(stack, tile, name)
            planted = planted + 1

            seedIdx = seedIdx + 1
            if seedIdx > #order then seedIdx = 1 end
            task.wait(DELAY_BETWEEN)
        end
    end
    return planted
end

startToggle = tabPlant:Toggle({
    Name = "Auto Plant",
    Default = false,
    Callback = function(state)
        if state then
            if running then return end
            if (not selectedSeeds) or (#selectedSeeds == 0) or (#selectedSeeds == 1 and selectedSeeds[1] == "(Klik 'Refresh Seed')") then
                notify("Info","Pilih seed dulu (multi)",1.4); setToggleState(startToggle,false); return
            end
            running = true
            task.spawn(function()
                local ok, err = pcall(function()
                    local planted = runPlantAllMulti(selectedSeeds)
                    if planted > 0 then notify("Selesai", ("Planted %d total"):format(planted), 1.6) end
                end)
                if not ok then notify("Error", tostring(err), 2.0) end
                running = false
                setToggleState(startToggle,false)
            end)
        else
            running = false
        end
    end
})

tabPlant:CreateSectionFold({ Title = "Auto Move Plants" })

-- UI: trigger rarities + boss
local AM_TRIGGER_OPTS = { "Godly", "Secret", "Limited", "Boss" }
local amFilter = { godly=true, secret=true, limited=true, boss=true }
tabPlant:Dropdown({
    Name = "Trigger (multi)",
    Options = AM_TRIGGER_OPTS,
    MultiSelection = true,
    Search = false,
    Callback = function(values)
        local m = {}
        if typeof(values)=="table" then for _,v in ipairs(values) do m[v:lower()] = true end
        elseif typeof(values)=="string" then m[values:lower()] = true end
        amFilter = m
    end
})
local AM_MAX = 10
tabPlant:Input({
    Name = "Max Plants to Move",
    PlaceholderText = tostring(AM_MAX),
    NumbersOnly = true,
    OnEnter = false,
    RemoveTextAfterFocusLost = false,
    Callback = function(txt) local v=tonumber(txt); if v and v>=1 then AM_MAX=math.floor(v) notify("Move","Max="..AM_MAX,1.0) end end
})
local autoMove = false
tabPlant:Toggle({
    Name = "Auto Move ON/OFF",
    Default = false,
    Callback = function(v) autoMove = v end
})

-- Helpers khusus Auto Move
local function getRowModel(plot, rowNo)
    local rows = plot and plot:FindFirstChild("Rows")
    if not rows then return nil end
    local r = rows:FindFirstChild(tostring(rowNo))
    return r
end
local function getRowEmptyTilesSorted(rowModel)
    if not rowModel then return {} end
    local grass = rowModel:FindFirstChild("Grass")
    if not grass then return {} end
    local anchor = rowModel:FindFirstChild("BrainrotWalkto") or rowModel:FindFirstChild("BrainrotEnd")
    local posA = anchor and anchor.Position or rowModel:GetPivot().Position
    local out = {}
    for _,tile in ipairs(grass:GetChildren()) do
        if (tile:IsA("BasePart") or tile:IsA("Model")) and isTileFree(tile) then
            local p = (tile:IsA("BasePart") and tile.Position) or tile:GetPivot().Position
            table.insert(out, {tile=tile, dist=(p-posA).Magnitude})
        end
    end
    table.sort(out, function(a,b) return a.dist < b.dist end)
    local only = {}
    for _,it in ipairs(out) do table.insert(only, it.tile) end
    return only
end
local function getMyPlotIndex()
    local p = findMyPlot()
    return p and tonumber(p.Name) or nil
end

-- Plant readers
local function getPlantID(plantInst)
    local ok, v = pcall(plantInst.GetAttribute, plantInst, "ID"); if ok and v then return tostring(v) end
    return nil
end
local function getPlantDamage(plantInst)
    local keys = { "Damage", "DPS", "Power" }
    for _,k in ipairs(keys) do
        local ok, v = pcall(plantInst.GetAttribute, plantInst, k)
        if ok and type(v)=="number" then return v end
    end
    return 0
end
local function getPlantWorldPos(plantInst)
    local cf
    if plantInst.PrimaryPart then cf = plantInst.PrimaryPart.CFrame
    elseif plantInst:IsA("Model") then cf = plantInst:GetPivot()
    elseif plantInst:IsA("BasePart") then cf = plantInst.CFrame end
    return cf and cf.Position or nil
end
local function allPlotTiles(plot)
    local list = {}
    local rows = plot and plot:FindFirstChild("Rows")
    if not rows then return list end
    for _,row in ipairs(rows:GetChildren()) do
        local grass = row:FindFirstChild("Grass")
        if grass then for _,t in ipairs(grass:GetChildren()) do table.insert(list, t) end end
    end
    return list
end
local function nearestTileToPos(plot, pos)
    local best, bd = nil, 1/0
    for _,t in ipairs(allPlotTiles(plot)) do
        local p = t:IsA("BasePart") and t.Position or t:GetPivot().Position
        local d = (p-pos).Magnitude
        if d<bd then bd=d; best=t end
    end
    return best
end

-- Backpack waiters
local function waitToolByID(id, timeout)
    local deadline = os.clock() + (timeout or 4)
    local bag = LP:WaitForChild("Backpack")
    repeat
        for _,t in ipairs(bag:GetChildren()) do
            if t:IsA("Tool") then
                local ok, v = pcall(t.GetAttribute, t, "ID")
                if ok and v and tostring(v)==tostring(id) then return t end
            end
        end
        task.wait(0.1)
    until os.clock() > deadline
    return nil
end
local function plantNameFromTool(tool)
    local n = safeName(tool) -- ex: "[4x] Eggplant"
    n = n:gsub("^%[%s*%d+x%s*%]%s*", "") -- remove "[4x]"
    return n
end

-- Pickup & Place
local function equipShovel()
    local shovel = getToolByBaseName("Shovel [Pick Up Plants]") or getToolByBaseName("Shovel")
    if not shovel then return false end
    return equipTool(shovel)
end
local function pickupPlantByID(plantID)
    if not equipShovel() then return false, "no shovel" end
    local ok = pcall(function() RemoveItemRemote:FireServer(plantID) end)
    if not ok then return false, "remote error" end
    local tool = waitToolByID(plantID, 6)
    return tool ~= nil, tool
end
local function placePlantToolOnTile(tool, tile)
    if not tool or not tool:IsA("Tool") then return false end
    if tool.Parent ~= (LP.Character or LP.CharacterAdded:Wait()) then equipTool(tool) end
    local id = tool:GetAttribute("ID")
    local itemName = plantNameFromTool(tool)
    if not id or not itemName then return false end
    pcall(function()
        PlaceItemRemote:FireServer({
            ID     = id,
            CFrame = partCFrame(tile),
            Item   = itemName,
            Floor  = tile,
        })
    end)
    return true
end

-- Move orchestration
local activeMoves = {}  -- [BrainrotID] = { {id, origTile, origPos, itemName} ... }
local movingFlag  = false

local function startMoveForRow(brID, rowModel)
    if movingFlag then return end
    movingFlag = true
    task.spawn(function()
        local plot = findMyPlot(); if not plot then movingFlag=false; return end
        local plantsFolder = plot:FindFirstChild("Plants"); if not plantsFolder then movingFlag=false; return end

        -- target tiles (empty) dekat jalur
        local targets = getRowEmptyTilesSorted(rowModel)
        if #targets == 0 then notify("Move","Tidak ada tile kosong di row",1.0); movingFlag=false; return end

        -- kumpulkan tanaman + damage
        local list = {}
        for _,p in ipairs(plantsFolder:GetChildren()) do
            local id = getPlantID(p)
            local dmg = getPlantDamage(p)
            local pos = getPlantWorldPos(p)
            if id and pos then
                table.insert(list, {inst=p, id=id, dmg=dmg, pos=pos})
            end
        end
        table.sort(list, function(a,b) return (a.dmg or 0) > (b.dmg or 0) end)

        -- ambil top AM_MAX
        local picked = {}
        local takeN = math.min(AM_MAX, #targets, #list)
        for i=1, takeN do picked[i] = { plant=list[i], target=targets[i] } end

        if #picked == 0 then movingFlag=false; return end
        activeMoves[brID] = {}

        -- jalankan pickup -> place
        for _,it in ipairs(picked) do
            local plant, target = it.plant, it.target
            -- hitung tile asal (nearest)
            local origTile = nearestTileToPos(plot, plant.pos)
            -- pickup
            local ok, toolOrErr = pickupPlantByID(plant.id)
            local tool = ok and toolOrErr or nil
            if tool then
                local itemName = plantNameFromTool(tool)
                placePlantToolOnTile(tool, target)
                table.insert(activeMoves[brID], {
                    id       = plant.id,
                    origTile = origTile,
                    origPos  = plant.pos,
                    itemName = itemName,
                })
                task.wait(0.12)
            end
        end
        movingFlag = false
    end)
end

local function returnMovedPlants(brID)
    local batch = activeMoves[brID]; if not batch or #batch==0 then return end
    task.spawn(function()
        local plot = findMyPlot(); if not plot then activeMoves[brID]=nil; return end
        local plantsFolder = plot:FindFirstChild("Plants")
        for _,info in ipairs(batch) do
            -- pastikan jadi tool dulu
            local instInWorld = nil
            if plantsFolder then
                for _,p in ipairs(plantsFolder:GetChildren()) do
                    local id = getPlantID(p)
                    if id and tostring(id)==tostring(info.id) then instInWorld = p; break end
                end
            end
            if instInWorld then
                local ok = equipShovel()
                if ok then pcall(function() RemoveItemRemote:FireServer(info.id) end) end
                task.wait(0.25)
            end
            -- cari toolnya
            local tool = waitToolByID(info.id, 6)
            if tool and info.origTile then
                placePlantToolOnTile(tool, info.origTile)
            end
            task.wait(0.12)
        end
        activeMoves[brID] = nil
    end)
end

-- Hook spawn & delete brainrot
local SpawnBR = Remotes:FindFirstChild("SpawnBrainrot")
local DeleteBR= Remotes:FindFirstChild("DeleteBrainrot")
local myPlotIndex = getMyPlotIndex()

if SpawnBR then
    SpawnBR.OnClientEvent:Connect(function(data)
        if not autoMove then return end
        -- data expected: Model, Plot, RowNo, Mutations={IsBoss=bool, ...}
        if not data then return end
        local plotNo = tonumber(data.Plot)
        if myPlotIndex and plotNo ~= myPlotIndex then return end

        local isBoss = data.Mutations and data.Mutations.IsBoss == true
        -- ambil rarity dari Stats (mungkin muncul setelah sedikit waktu)
        local rarity = nil
        if data.Model and data.Model:IsA("Model") then
            task.wait(0.05)
            local stats = data.Model:FindFirstChild("Stats")
            if stats and stats:FindFirstChild("Rarity") and stats.Rarity:IsA("TextLabel") then
                rarity = tostring(stats.Rarity.Text)
            else
                rarity = data.Model:GetAttribute("Rarity")
            end
        end

        local triggerOK = false
        if isBoss and amFilter["boss"] then triggerOK = true end
        if rarity and amFilter[ tostring(rarity):lower() ] then triggerOK = true end
        if not triggerOK then return end

        local plot = findMyPlot(); if not plot then return end
        local rowModel = getRowModel(plot, data.RowNo)
        if not rowModel then return end

        local brID = data.ID or (data.Model and data.Model.Name) or ("br"..tostring(math.random(1,1e9)))
        startMoveForRow(brID, rowModel)
    end)
end
if DeleteBR then
    DeleteBR.OnClientEvent:Connect(function(brID, info)
        -- ketika BR ini mati -> kembalikan tanaman batch-nya
        returnMovedPlants(brID)
    end)
end

-- Shop Seed / Gear
tabShop:CreateSectionFold({ Title = "Auto Buy Seed" })
local shopSeedList = {}
tabShop:Dropdown({
    Name = "Select Seed",
    Options = getAllSeedNamesFull(),
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values) == "table" then shopSeedList = values
        elseif typeof(values) == "string" then shopSeedList = { values }
        else shopSeedList = {} end
    end
})

local autoBuyingSeed = false
tabShop:Toggle({
    Name = "Auto Buy Seed",
    Default = false,
    Callback = function(state)
        autoBuyingSeed = state
        if not autoBuyingSeed then return end
        task.spawn(function()
            local idx = 1
            while autoBuyingSeed do
                if not shopSeedList or #shopSeedList == 0 then
                    task.wait(1)
                else
                    if idx > #shopSeedList then idx = 1 end
                    buySeedOnce(shopSeedList[idx]); idx = idx + 1
                    task.wait(AUTO_BUY_INTERVAL)
                end
            end
        end)
    end
})

tabShop:CreateSectionFold({ Title = "Auto Buy Gear" })
local shopGearList = {}
tabShop:Dropdown({
    Name = "Select Gear",
    Options = getAllGearNames(),
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values) == "table" then shopGearList = values
        elseif typeof(values) == "string" then shopGearList = { values }
        else shopGearList = {} end
    end
})

local autoBuyingGear = false
tabShop:Toggle({
    Name = "Auto Buy Gear",
    Default = false,
    Callback = function(state)
        autoBuyingGear = state
        if not autoBuyingGear then return end
        task.spawn(function()
            local idx = 1
            while autoBuyingGear do
                if not shopGearList or #shopGearList == 0 then
                    task.wait(1)
                else
                    if idx > #shopGearList then idx = 1 end
                    buyGearOnce(shopGearList[idx]); idx = idx + 1
                    task.wait(AUTO_BUY_INTERVAL)
                end
            end
        end)
    end
})

tabShop:CreateSectionFold({ Title = "Auto sell" })
local sellInterval = 1.0 -- Default 1 detik
local autoSellBrainrots = false
local autoSellPlants = false

tabShop:Input({
    Name = "Sell Interval (detik)",
    PlaceholderText = tostring(sellInterval),
    NumbersOnly = true,
    Callback = function(txt)
        local v = tonumber(txt)
        if v and v >= 0.1 then
            sellInterval = v
            notify("OK", ("Sell interval diatur ke %.1fs"):format(sellInterval), 1.5)
        else
            notify("Info", "Minimal interval 0.1 detik", 1.5)
        end
    end
})

tabShop:Toggle({
    Name = "Auto Sell Brainrots",
    Default = false,
    Callback = function(state)
        autoSellBrainrots = state
        if not autoSellBrainrots then return end

        task.spawn(function()
            while autoSellBrainrots do
                pcall(function() ItemSellRemote:FireServer() end)
                task.wait(sellInterval)
            end
        end)
    end
})

tabShop:Toggle({
    Name = "Auto Sell Plants",
    Default = false,
    Callback = function(state)
        autoSellPlants = state
        if not autoSellPlants then return end

        task.spawn(function()
            while autoSellPlants do
                pcall(function() ItemSellRemote:FireServer(nil, true) end)
                task.wait(sellInterval)
            end
        end)
    end
})

-- =============================
-- Utility: Equip Best Brainrots
-- =============================
local autoEquipBR = false
local brInterval  = 5

tabUtil:CreateSectionFold({ Title = "Auto Equip Best Brainrots" })
tabUtil:Input({
    Name = "Timer",
    PlaceholderText = tostring(brInterval),
    NumbersOnly = true,
    OnEnter = false,
    RemoveTextAfterFocusLost = false,
    Callback = function(txt)
        local v = tonumber(txt)
        if v and v >= 0.5 then
            brInterval = v
            notify("OK", ("Interval set ke %.2fs"):format(brInterval), 1.0)
        else
            notify("Info", "Minimal 0.5s", 1.2)
        end
    end
})

tabUtil:Toggle({
    Name = "Auto Equip Best Brainrots",
    Default = false,
    Callback = function(state)
        autoEquipBR = state
        if not autoEquipBR then return end
        task.spawn(function()
            while autoEquipBR do
                pcall(function() EquipBestBrainrotsRemote:FireServer() end)
                task.wait(brInterval)
            end
        end)
    end
})

-- =============================
-- Watering (Auto)
-- =============================
tabUtil:CreateSectionFold({ Title = "Auto Water" })
local Countdowns = workspace:WaitForChild("ScriptedMap"):WaitForChild("Countdowns")

local waterDelay = 0.15       -- jeda per siram (detik)
local autoWater  = false

tabUtil:Input({
    Name = "Jeda Siram (s)",
    PlaceholderText = tostring(waterDelay),
    NumbersOnly = true,
    OnEnter = false,
    RemoveTextAfterFocusLost = false,
    Callback = function(txt)
        local v = tonumber(txt)
        if v and v >= 0 then
            waterDelay = v
            if win and win.Notify then win:Notify("Water", ("Delay set: %.2fs"):format(waterDelay), 1.0) end
        else
            if win and win.Notify then win:Notify("Water", "Masukkan angka ≥ 0", 1.0) end
        end
    end
})

-- cari Water Bucket tanpa hardcode nama prefix [x###]
local function getWaterBucket()
    local function isBucket(t)
        if not t:IsA("Tool") then return false end
        local n = safeName(t)
        return n:lower():find("water bucket") ~= nil
    end
    local char = LP.Character
    if char then for _, t in ipairs(char:GetChildren()) do if isBucket(t) then return t end end end
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if isBucket(t) then return t end end end
    local pf = myPlayerFolder()
    if pf then for _, t in ipairs(pf:GetChildren()) do if isBucket(t) then return t end end end
    return nil
end

local function waterAt(pos)
    local tool = getWaterBucket()
    if not tool then return false end
    -- pastikan dipegang sebelum UseItem
    if tool.Parent ~= (LP.Character or LP.CharacterAdded:Wait()) then
        equipTool(tool)
    end
    local v3 = (vector and vector.create) and vector.create(pos.X, pos.Y, pos.Z) or Vector3.new(pos.X, pos.Y, pos.Z)
    pcall(function()
        UseItemRemote:FireServer({ { Toggle = true, Tool = tool, Pos = v3 } })
    end)
    return true
end

local function runAutoWater()
    while autoWater do
        -- Equip hanya kalau ada tanaman tumbuh
        local children = Countdowns:GetChildren()
        if #children > 0 then
            local tool = getWaterBucket()
            if tool then equipTool(tool) end

            for _, inst in ipairs(children) do
                local pos =
                    (inst.CFrame and inst.CFrame.Position)
                    or (inst.GetPivot and inst:GetPivot().Position)
                    or nil
                if pos then
                    waterAt(pos)
                    task.wait(waterDelay) -- jeda per siram (input user)
                end
            end
        end
        task.wait(0.1)
    end
end

tabUtil:Toggle({
    Name = "Auto Water",
    Default = false,
    Callback = function(state)
        autoWater = state
        if autoWater then
            task.spawn(function()
                local ok, err = pcall(runAutoWater)
                if not ok then warn("[AutoWater] loop error:", err) end
            end)
        end
    end
})

-- =============================
-- Gifting (no seed)
-- =============================
local function isSeedName(name)
    if name:match("Seed%s*$") then return true end
    if SEED_WHITELIST and SEED_WHITELIST[name:gsub("%s+Seed$","")] then return true end
    return false
end

local function collectGiftables()
    local out = {}
    local function push(inst)
        if not inst:IsA("Tool") then return end
        local name = safeName(inst)
        if isSeedName(name) then return end
        out[name] = out[name] or { tools = {} }
        table.insert(out[name].tools, inst)
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do push(t) end end
    local char = LP.Character
    if char then for _, t in ipairs(char:GetChildren()) do push(t) end end
    local pf = myPlayerFolder()
    if pf then for _, t in ipairs(pf:GetChildren()) do push(t) end end
    return out
end

local function giftTool(tool, targetUsername)
    return pcall(function()
        GiftItemRemote:FireServer({ Item = tool, ToGift = targetUsername })
    end)
end

local playerLabelMap = {}
local ddPlayers      = nil
local function buildPlayerOptions()
    local opts, map = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local uname = p.Name
            local dname = p.DisplayName or uname
            local label = string.format("%s = @%s", dname, uname)
            table.insert(opts, label)
            map[label] = uname
        end
    end
    table.sort(opts)
    return opts, map
end

local giftTargetUsername = ""
local giftDelay          = 0.20
local runningGift        = false
local selectedGiftNames  = {}

tabPack:CreateSectionFold({ Title = "Gifting" })
local ddGift = tabPack:Dropdown({
    Name = "Select Items to Gift",
    Options = (function()
        local set, inv = {}, collectGiftables()
        for name in pairs(inv) do set[name] = true end
        local list = {}
        for n in pairs(set) do table.insert(list, n) end
        table.sort(list)
        return list
    end)(),
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values) == "table" then
            selectedGiftNames = values
        elseif typeof(values) == "string" then
            selectedGiftNames = { values }
        else
            selectedGiftNames = {}
        end
    end
})

local function _updateDrop(drop, opts)
    if updateDropdown then return updateDropdown(drop, opts) end
    if drop.Refresh and pcall(function() drop:Refresh(opts, true) end) then return end
    if drop.SetOptions and pcall(function() drop:SetOptions(opts) end) then return end
    if drop.SetItems   and pcall(function() drop:SetItems(opts)   end) then return end
    if drop.ClearOptions and drop.AddOption then
        pcall(function()
            drop:ClearOptions()
            for _, n in ipairs(opts) do drop:AddOption(n) end
        end)
        return
    end
    drop.Options = opts
end

tabPack:Button({
    Name = "Refresh Giftables",
    Callback = function()
        local set, inv = {}, collectGiftables()
        for name in pairs(inv) do set[name] = true end
        local list = {}
        for n in pairs(set) do table.insert(list, n) end
        table.sort(list)
        _updateDrop(ddGift, list)
        notify("Gift", "Daftar giftables di-refresh", 1.0)
    end
})

tabPack:Paragraph("Select Player")

do
    local opts, map = buildPlayerOptions()
    playerLabelMap = map
    ddPlayers = tabPack:Dropdown({
        Name = "Players Online (Recipient)",
        Options = opts,
        MultiSelection = false,
        Search = true,
        Callback = function(label)
            if type(label) == "string" and #label > 0 then
                local uname = playerLabelMap[label]
                if uname and #uname > 0 then
                    giftTargetUsername = uname
                    notify("Recipient", ("Set to: %s"):format(label), 1.0)
                end
            end
        end
    })
end

tabPack:Button({
    Name = "Refresh Players",
    Callback = function()
        local opts, map = buildPlayerOptions()
        playerLabelMap = map
        _updateDrop(ddPlayers, opts)
        notify("Players", "Daftar player di-refresh", 1.0)
    end
})

local function ensureRecipient()
    if giftTargetUsername ~= "" then return true end
    local opts, map = buildPlayerOptions()
    playerLabelMap = map
    if #opts > 0 then
        local firstLabel = opts[1]
        giftTargetUsername = playerLabelMap[firstLabel] or ""
        pcall(function() if ddPlayers and ddPlayers.SetValue then ddPlayers:SetValue(firstLabel) end end)
        notify("Recipient", "Auto set: "..firstLabel, 1.0)
        return true
    end
    notify("Recipient", "Tidak ada pemain lain online", 1.2)
    return false
end

tabPack:Button({
    Name = "Gift Only 1",
    Callback = function()
        if not ensureRecipient() then return end
        if not selectedGiftNames or #selectedGiftNames == 0 then
            notify("Info","Pilih item dulu",1.0); return
        end
        local inv = collectGiftables()
        for _, name in ipairs(selectedGiftNames) do
            local bucket = inv[name]
            if bucket and #bucket.tools > 0 then
                local tool = bucket.tools[1]
                equipTool(tool)
                giftTool(tool, giftTargetUsername)
                task.wait(giftDelay)
            end
        end
    end
})

local giftToggle
local function runAutoGift()
    while runningGift do
        if not ensureRecipient() or not selectedGiftNames or #selectedGiftNames == 0 then
            task.wait(0.6)
        else
            local inv = collectGiftables()
            local nothing = true
            for _, name in ipairs(selectedGiftNames) do
                local bucket = inv[name]
                if bucket and #bucket.tools > 0 then
                    nothing = false
                    local tool = bucket.tools[1]
                    equipTool(tool)
                    giftTool(tool, giftTargetUsername)
                    task.wait(giftDelay)
                end
            end
            if nothing then task.wait(0.6) end
        end
    end
end

giftToggle = tabPack:Toggle({
    Name = "Auto Gift",
    Default = false,
    Callback = function(state)
        runningGift = state
        if runningGift then
            task.spawn(function()
                local ok, err = pcall(runAutoGift)
                if not ok then warn("[AutoGift] error:", err) end
                setToggleState(giftToggle, false)
            end)
        end
    end
})

-- Auto Accept Gift
tabPack:Paragraph("Auto Accept Gift")
local autoAcceptGift = false
tabPack:Toggle({
    Name = "Auto Accept Gift",
    Default = autoAcceptGift,
    Callback = function(state) autoAcceptGift = state end
})

GiftItemRemote.OnClientEvent:Connect(function(payload)
    if not autoAcceptGift then return end
    if type(payload) ~= "table" or not payload.ID then return end
    pcall(function() AcceptGiftRemote:FireServer({ ID = payload.ID }) end)
    pcall(function()
        local main = LP.PlayerGui:FindFirstChild("Main")
        local openUI = Remotes:FindFirstChild("OpenUI")
        if main and main:FindFirstChild("Gifting") and openUI then
            openUI:Fire(main.Gifting, false)
        end
    end)
end)

tabPack:CreateSectionFold({ Title = "Kills → Auto-Fav" })

local autoSpy = false
local statusLbl = tabPack:Label("Status: OFF")

-- Filter rarity
local RARITY_OPTS = { "Rare","Epic","Legendary","Mythic","Godly","Secret","Limited", }
local chosenRarity = {}
local function selectAllRarity()
    chosenRarity = {}
    for _,r in ipairs(RARITY_OPTS) do chosenRarity[r:lower()] = true end
end
local function selectNoneRarity() chosenRarity = {} end
selectAllRarity()

tabPack:Dropdown({
    Name = "Rarity Filter (Multi)",
    Options = RARITY_OPTS,
    MultiSelection = true,
    Search = false,
    Callback = function(values)
        chosenRarity = {}
        if typeof(values)=="table" then
            for _,v in ipairs(values) do chosenRarity[v:lower()] = true end
        elseif typeof(values)=="string" then
            chosenRarity[values:lower()] = true
        end
    end
})

tabPack:Toggle({
    Name = "Spy Kills → Auto-Fav",
    Default = false,
    Callback = function(state)
        autoSpy = state
        if statusLbl and statusLbl.Set then statusLbl:Set("Status: "..(state and "ON" or "OFF")) end
        if notify then notify("Spy", state and "ON" or "OFF", 1.0) end
    end
})

-- ====== Util baca atribut ======
local function stripBrackets(s)
    local out = tostring(s or ""); local prev
    repeat prev = out; out = out:gsub("^%b[]%s*", "") until out==prev
    return out
end

local function getCoreNode(tool)
    if not (tool and tool:IsA("Tool")) then return nil end
    local base = stripBrackets(tool.Name)
    return tool:FindFirstChild(base) or tool:FindFirstChild(safeName(tool))
end

local function findAttrDeep(tool, key)
    local function read(inst)
        if inst and inst.GetAttribute then
            local ok,v = pcall(inst.GetAttribute, inst, key)
            if ok and v ~= nil then return v end
        end
    end
    local core = getCoreNode(tool)
    local v = read(tool) or read(core)
    if v ~= nil then return v end
    for _,d in ipairs(tool:GetDescendants()) do
        local vv = read(d); if vv ~= nil then return vv end
    end
    return nil
end

local function getID(tool)
    local v = findAttrDeep(tool, "ID"); return v and tostring(v) or nil
end
local function getRarity(tool)
    local v = findAttrDeep(tool, "Rarity"); return v and tostring(v) or nil
end

-- ====== Deteksi Brainrot ======
local BrainrotNames
local function buildBrainrotSetOnce()
    if BrainrotNames ~= nil then return end
    BrainrotNames = {}
    local ok, folder = pcall(function() return RS.Assets.Brainrots end)
    if ok and folder then
        for _,ch in ipairs(folder:GetChildren()) do BrainrotNames[ch.Name:lower()] = true end
    end
end
buildBrainrotSetOnce()

local function isBrainrotTool(tool)
    if not (tool and tool:IsA("Tool")) then return false end
    local nm = safeName(tool):lower()
    if nm:find("brainrot") then return true end
    if BrainrotNames and BrainrotNames[nm] then return true end
    local cat = findAttrDeep(tool,"Category")
    if type(cat)=="string" and cat:lower()=="brainrot" then return true end
    if findAttrDeep(tool,"Brainrot")==true then return true end
    return false
end

-- ====== Favorit aman ======
local FavCache = {}
local function isFavoritedTool(tool) return findAttrDeep(tool,"Favorited") == true end
local function favoriteByID(id, tool)
    if not id then return false end
    if FavCache[id] or isFavoritedTool(tool) then FavCache[id]=true; return true end
    if FavoriteItemRemote then
        pcall(function() FavoriteItemRemote:FireServer(id) end)
        task.wait(0.08)
        if not isFavoritedTool(tool) then
            pcall(function() FavoriteItemRemote:FireServer({ID=id}) end)
            task.wait(0.08)
        end
        if not isFavoritedTool(tool) and tool then
            pcall(function() FavoriteItemRemote:FireServer({ID=id, Instance=tool}) end)
            task.wait(0.08)
        end
    end
    if isFavoritedTool(tool) then FavCache[id]=true; return true end
    return false
end

-- ====== Kill gating (ONLY kill) — window 10s, reset tiap kill ======
local KILL_GRACE = 10.0
local killActiveUntil = 0
local function markKill()
    killActiveUntil = math.max(killActiveUntil, os.clock() + KILL_GRACE)
end

-- Server confirm kill
local DeleteBrainrotRemote = Remotes:WaitForChild("DeleteBrainrot")
DeleteBrainrotRemote.OnClientEvent:Connect(function(...)
    if autoSpy then markKill() end
end)

-- Jaga-jaga: model Brainrot mati/hilang
local BrainrotsFolder = workspace:WaitForChild("ScriptedMap"):WaitForChild("Brainrots")
local function watchBRModel(m)
    if not (m and m:IsA("Model")) then return end
    local hum = m:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if autoSpy then markKill() end
        end)
    end
    m.AncestryChanged:Connect(function(_, parent)
        if autoSpy and (not parent) then markKill() end
    end)
end
for _,m in ipairs(BrainrotsFolder:GetChildren()) do watchBRModel(m) end
BrainrotsFolder.ChildAdded:Connect(watchBRModel)

-- ====== Proses loot masuk (hanya dalam window kill aktif) ======
local function processNewContainer(node)
    if not autoSpy then return end
    if os.clock() > killActiveUntil then return end -- inti "hanya kill" (≤10s setelah kill)

    -- ambil Tool
    local tool = node
    if not (tool and tool:IsA("Tool")) then
        for _,d in ipairs(node:GetDescendants()) do if d:IsA("Tool") then tool = d; break end end
    end
    if not (tool and tool:IsA("Tool")) then return end

    -- tunggu atribut ID/Rarity muncul
    local deadline = os.clock() + 8
    local id, rarity
    repeat
        id = getID(tool)
        rarity = getRarity(tool)
        if id and rarity then break end
        task.wait(0.15)
    until os.clock() > deadline

    -- filter brainrot + rarity
    if not isBrainrotTool(tool) then return end
    if rarity and (next(chosenRarity) ~= nil) and not chosenRarity[rarity:lower()] then return end

    favoriteByID(id, tool)
end

-- Hook kontainer umum untuk loot
LP:WaitForChild("Backpack").ChildAdded:Connect(processNewContainer)
local function hookChar(c) if c then c.ChildAdded:Connect(processNewContainer) end end
hookChar(LP.Character or LP.CharacterAdded:Wait())
LP.CharacterAdded:Connect(hookChar)

-- Player folder (fallback cari beberapa kandidat umum)
local function myPlayerFolderSafe()
    local name = LP.Name
    local cand = {
        workspace:FindFirstChild(name),
        (workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(name)) or nil,
        (workspace:FindFirstChild("PlayerFolder") and workspace.PlayerFolder:FindFirstChild(name)) or nil,
    }
    for _,n in ipairs(cand) do if n then return n end end
    return nil
end
local pf = (rawget(_G,"myPlayerFolder") and _G.myPlayerFolder()) or myPlayerFolderSafe()
if pf then pf.ChildAdded:Connect(processNewContainer) end

