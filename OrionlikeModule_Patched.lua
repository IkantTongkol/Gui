--[[
Orionlike Roblox UI — ModuleScript (API Orion 1:1, dropdown robust fix)
Patch addendum (2025-09-12):
- Popup overlay uses very high ZIndex + ScreenGui.DisplayOrder = 1000
- Dropdown menu position clamped ke viewport (tidak off-screen)
- Notif saat Options kosong (debug-friendly)
- Search bar tetap di atas via LayoutOrder
- Semua patch sebelumnya tetap ada
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

local Orion = {}
Orion.__index = Orion

-- THEME
local Theme = {
  Accent = Color3.fromRGB(0,170,255),
  Bg     = Color3.fromRGB(18,19,24),
  Panel  = Color3.fromRGB(26,28,34),
  Panel2 = Color3.fromRGB(23,24,30),
  Stroke = Color3.fromRGB(60,62,70),
  Text   = Color3.fromRGB(235,238,245),
  TextDim= Color3.fromRGB(170,178,190),
}

local function corner(inst, r)
  local c = Instance.new("UICorner")
  c.CornerRadius = UDim.new(0, r or 10); c.Parent = inst; return c
end
local function stroke(inst, tr, col)
  local s = Instance.new("UIStroke")
  s.Color = col or Theme.Stroke; s.Thickness = 1; s.Transparency = tr or 0.4
  s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = inst; return s
end
local function pad(inst, p)
  local pd = Instance.new("UIPadding")
  pd.PaddingTop = UDim.new(0, p or 8); pd.PaddingBottom = UDim.new(0, p or 8)
  pd.PaddingLeft = UDim.new(0, 12); pd.PaddingRight = UDim.new(0, 12)
  pd.Parent = inst; return pd
end

local function ensureGui()
  local p = Players.LocalPlayer:WaitForChild("PlayerGui")
  local gui = p:FindFirstChild("OrionlikeRoot")
  if not gui then
    gui = Instance.new("ScreenGui")
    gui.Name = "OrionlikeRoot"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000 -- TOPMOST
    gui.Parent = p
  end
  -- popup root
  local pr = gui:FindFirstChild("OrionlikePopup")
  if not pr then
    pr = Instance.new("Frame")
    pr.Name = "OrionlikePopup"
    pr.BackgroundTransparency = 1
    pr.Size = UDim2.fromScale(1,1)
    pr.ZIndex = 5000 -- very high
    pr.Parent = gui
  end
  return gui, pr
end

-- FS helpers
local function hasFS()
  return typeof(writefile)=="function" and typeof(readfile)=="function"
     and typeof(isfile)=="function" and typeof(isfolder)=="function"
     and typeof(makefolder)=="function"
end

-- FLAGS / CONFIG
local function makeFlagTable(lib) lib.Flags = lib.Flags or {}; return lib.Flags end
local function attachFlag(lib, flagName, setter, getter, initial)
  if not flagName then return end
  local flags = makeFlagTable(lib)
  if not flags[flagName] then
    flags[flagName] = { Value = initial, Set = function(v) setter(v) end, Get = function() return getter() end }
  end
end
local function encodeFlags()
  local data = {}
  for k,entry in pairs(Orion.Flags or {}) do
    local v = entry and (entry.Value ~= nil and entry.Value or entry)
    if typeof(v)=="Color3" then v = {__color3__=true, r=v.R, g=v.G, b=v.B}
    elseif typeof(v)=="EnumItem" then v = {__enum__=true, enum=v.EnumType.Name, name=v.Name} end
    data[k] = v
  end
  return HttpService:JSONEncode(data)
end
local function decodeAndApply(json)
  if not json or json=="" then return false, "empty" end
  local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
  if not ok or type(data)~="table" then return false, "decode" end
  for k,v in pairs(data) do
    if type(v)=="table" and v.__color3__ then v = Color3.new(v.r, v.g, v.b) end
    if type(v)=="table" and v.__enum__ and Enum[v.enum] and Enum[v.enum][v.name] then v = Enum[v.enum][v.name] end
    local entry = Orion.Flags and Orion.Flags[k]
    if entry and entry.Set then entry.Set(v) else Orion.Flags[k] = Orion.Flags[k] or {}; Orion.Flags[k].Value = v end
  end
  return true
end

function Orion:SetConfigName(name) self._ConfigName = tostring(name or "config") end
function Orion:SaveConfig(window)
  window = window or self._LastWindow; if not window then return false, "no-window" end
  if not window._SaveConfig then return false, "disabled" end
  local folder = tostring(window._ConfigFolder or "Orionlike")
  local fname = tostring(self._ConfigName or "config") .. ".json"
  local body = encodeFlags()
  if hasFS() then
    if not isfolder(folder) then makefolder(folder) end
    writefile(folder.."/"..fname, body); return true
  else
    local gui = window._Gui or ensureGui(); gui:SetAttribute("OrionlikeConfig", body); return true, "attribute"
  end
end
function Orion:LoadConfig(window)
  window = window or self._LastWindow; if not window then return false, "no-window" end
  local folder = tostring(window._ConfigFolder or "Orionlike")
  local fname = tostring(self._ConfigName or "config") .. ".json"
  local json
  if hasFS() and isfile(folder.."/"..fname) then json = readfile(folder.."/"..fname)
  else local gui = window._Gui or ensureGui(); json = gui:GetAttribute("OrionlikeConfig") end
  return decodeAndApply(json)
end
function Orion:EnableAutoSave(window, interval)
  window = window or self._LastWindow; interval = tonumber(interval) or 2
  if not window or window._AutoSaveConn then return end
  local last = ""
  window._AutoSaveConn = RunService.Heartbeat:Connect(function(dt)
    window._acc = (window._acc or 0) + dt
    if window._acc < interval then return end
    window._acc = 0
    local snap = encodeFlags()
    if snap ~= last then last = snap; Orion:SaveConfig(window) end
  end)
end

function Orion:MakeNotification(d)
  d = d or {}; local gui = ensureGui()
  local root = gui:FindFirstChild("ToastRoot") or (function()
    local r = Instance.new("Frame"); r.Name="ToastRoot"; r.BackgroundTransparency=1
    r.AnchorPoint=Vector2.new(1,1); r.Position=UDim2.new(1,-12,1,-12); r.Size=UDim2.fromOffset(1,1); r.Parent=gui; return r
  end)()
  local toast = Instance.new("Frame")
  toast.AnchorPoint = Vector2.new(1,1); toast.Position = UDim2.new(1, 0, 1, 0)
  toast.Size = UDim2.fromOffset(300, 40); toast.BackgroundColor3 = Theme.Panel; toast.BackgroundTransparency = 0.05
  corner(toast, 8); stroke(toast, 0.5); pad(toast, 6); toast.Parent = root
  local title = Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(8,6); title.Size=UDim2.fromOffset(284,14)
  title.Font=Enum.Font.GothamMedium; title.TextSize=12; title.TextXAlignment=Enum.TextXAlignment.Left; title.TextColor3=Theme.Text; title.Text=d.Name or "Info"; title.Parent=toast
  local body = Instance.new("TextLabel"); body.BackgroundTransparency=1; body.Position=UDim2.fromOffset(8,20); body.Size=UDim2.fromOffset(284,16)
  body.Font=Enum.Font.Gotham; body.TextSize=12; body.TextXAlignment=Enum.TextXAlignment.Left; body.TextColor3=Theme.TextDim; body.Text=d.Content or ""; body.Parent=toast
  TweenService:Create(toast, TweenInfo.new(0.18), {Position = UDim2.new(1, -12, 1, -12)}):Play()
  task.delay(d.Time or 2.0, function()
    TweenService:Create(toast, TweenInfo.new(0.18), {BackgroundTransparency = 0.3, Position = UDim2.new(1, 0, 1, 0)}):Play()
    task.delay(0.2, function() if toast then toast:Destroy() end end)
  end)
end

function Orion:Init() end
function Orion:Destroy() local gui = ensureGui(); if gui then gui:Destroy() end end

-- WINDOW
local Window = {}; Window.__index = Window

function Orion:MakeWindow(opts, extra)
  if typeof(opts) == "string" then local t = {Name = opts}; if typeof(extra)=="table" then for k,v in pairs(extra) do t[k]=v end end; opts = t
  elseif typeof(opts) ~= "table" then opts = {} end

  local gui, popupRoot = ensureGui()
  local nav, content

  local main = Instance.new("Frame"); main.Name="Main"
  main.Size = (opts and opts.Size) or UDim2.fromOffset(620, 400)
  main.Position = UDim2.new(0.5, -main.Size.X.Offset/2, 0.5, -main.Size.Y.Offset/2)
  main.BackgroundColor3 = Theme.Panel; corner(main, 12); stroke(main, 0.55); main.Parent = gui

  local header = Instance.new("Frame"); header.Size=UDim2.new(1,0,0,52); header.BackgroundColor3=Theme.Panel2; corner(header,12); header.Parent=main

  -- DRAG + MINIMIZE + CLOSE
  do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
      if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        dragging = true; dragStart = input.Position; startPos = main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
      end
    end)
    UserInputService.InputChanged:Connect(function(input)
      if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
      end
    end)

    local mini = Instance.new("ImageButton"); mini.Name="Minimize"; mini.BackgroundTransparency=1
    mini.Size=UDim2.fromOffset(20,20); mini.AnchorPoint=Vector2.new(1,0); mini.Position=UDim2.new(1,-44,0,16)
    mini.Image="rbxassetid://6035067836"; mini.Parent=header

    local close = Instance.new("ImageButton"); close.Name="Close"; close.BackgroundTransparency=1
    close.Size=UDim2.fromOffset(20,20); close.AnchorPoint=Vector2.new(1,0); close.Position=UDim2.new(1,-20,0,16)
    close.Image="rbxassetid://3926305904"; close.ImageRectOffset=Vector2.new(284,4); close.ImageRectSize=Vector2.new(24,24); close.Parent=header

    local collapsed = false
    local fullSize = main.Size
    local function setCollapsed(state)
      collapsed = state and true or false
      if collapsed then
        fullSize = main.Size
        if nav then nav.Visible = false end
        if content then content.Visible = false end
        TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
          {Size = UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, 52)}):Play()
      else
        if nav then nav.Visible = true end
        if content then content.Visible = true end
        TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
          {Size = fullSize}):Play()
      end
    end
    mini.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)
    close.MouseButton1Click:Connect(function() gui:Destroy() end)
  end

  local icon = Instance.new("ImageLabel"); icon.BackgroundTransparency=1; icon.Position=UDim2.fromOffset(12,10); icon.Size=UDim2.fromOffset(28,28)
  icon.Image = opts.Icon and (typeof(opts.Icon)=="string" and opts.Icon or ("rbxassetid://"..tostring(opts.Icon))) or ""
  icon.ImageTransparency = (opts.Icon and 0) or 1; icon.ImageColor3 = Theme.Accent; icon.Parent = header

  local title = Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(48,8); title.Size=UDim2.fromOffset(480,20)
  title.TextXAlignment=Enum.TextXAlignment.Left; title.Font=Enum.Font.GothamMedium; title.TextSize=14; title.TextColor3=Theme.Text
  title.Text=tostring(opts.Name or "Orionlike Hub"); title.Parent = header

  local sub = Instance.new("TextLabel"); sub.BackgroundTransparency=1; sub.Position=UDim2.fromOffset(48,28); sub.Size=UDim2.fromOffset(480,16)
  sub.TextXAlignment=Enum.TextXAlignment.Left; sub.Font=Enum.Font.Gotham; sub.TextSize=12; sub.TextColor3=Theme.TextDim; sub.Text=tostring(opts.IntroText or ""); sub.Parent=header

  nav = Instance.new("Frame")
  nav.Position = UDim2.fromOffset(0, 52); nav.Size = UDim2.new(0, 180, 1, -52)
  nav.BackgroundColor3 = Theme.Panel2; stroke(nav, 0.5); nav.Parent = main; pad(nav, 10)
  local navList = Instance.new("UIListLayout"); navList.Padding = UDim.new(0, 6); navList.Parent = nav

  content = Instance.new("Frame")
  content.Position = UDim2.fromOffset(180, 52); content.Size = UDim2.new(1, -180, 1, -52)
  content.BackgroundTransparency = 1; content.Parent = main

  -- resize handle
  local rh = Instance.new("Frame")
  rh.AnchorPoint = Vector2.new(1,1); rh.Position = UDim2.new(1, -6, 1, -6); rh.Size = UDim2.fromOffset(14,14)
  rh.BackgroundColor3 = Theme.Panel2; corner(rh, 3); stroke(rh, 0.5); rh.Parent = main
  local resizing = false
  rh.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = true end end)
  rh.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end end)
  UserInputService.InputChanged:Connect(function(input)
    if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
      local m = UserInputService:GetMouseLocation()
      local x = math.clamp(m.X - main.AbsolutePosition.X, 520, 1100)
      local y = math.clamp(m.Y - main.AbsolutePosition.Y, 320, 800)
      main.Size = UDim2.fromOffset(x, y)
    end
  end)

  local self = setmetatable({
    _Gui = gui, _PopupRoot = popupRoot, _Main = main, _Nav = nav, _Content = content,
    _Tabs = {}, _CurrentTab = nil,
    _SaveConfig = opts.SaveConfig, _ConfigFolder = opts.ConfigFolder,
  }, Window)

  Orion._LastWindow = self
  return self
end

-- helpers
local function makeNavButton(parent, name)
  local b = Instance.new("TextButton")
  b.Size = UDim2.new(1, -4, 0, 32); b.BackgroundColor3 = Theme.Panel; b.Text = name
  b.TextColor3 = Theme.Text; b.TextSize = 12; b.Font = Enum.Font.Gotham; b.AutoButtonColor = false
  corner(b, 8); stroke(b, 0.5); b.Parent = parent; return b
end
local function makeScroll(parent)
  local sc = Instance.new("ScrollingFrame")
  sc.Active=true; sc.CanvasSize=UDim2.new(0,0,0,0); sc.AutomaticCanvasSize=Enum.AutomaticSize.Y
  sc.ScrollBarThickness=5; sc.BorderSizePixel=0; sc.BackgroundTransparency=1
  sc.Size=UDim2.new(1, -24, 1, -24); sc.Position=UDim2.fromOffset(12, 12)
  local list = Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = sc
  return sc
end

-- TAB & CONTROLS
function Window:MakeTab(t)
  t = t or {}; local tabName = t.Name or "Tab"
  local navBtn = makeNavButton(self._Nav, tabName)

  local page = Instance.new("Frame"); page.Visible=false; page.BackgroundTransparency=1; page.Size=UDim2.fromScale(1,1); page.Parent = self._Content
  local sc = makeScroll(page); sc.Parent = page

  -- search per-tab
  local searchBar = Instance.new("Frame"); searchBar.Name="SearchBar"; searchBar.BackgroundTransparency=1; searchBar.Size=UDim2.new(1, -24, 0, 30); searchBar.Position=UDim2.fromOffset(12, 8); searchBar.LayoutOrder=1; searchBar.Parent=sc
  local box = Instance.new("TextBox"); box.PlaceholderText="Search controls..."; box.Text=""; box.Font=Enum.Font.Gotham; box.TextSize=12; box.TextColor3=Theme.Text
  box.BackgroundColor3=Theme.Panel; box.BackgroundTransparency=0.1; box.Size=UDim2.new(1,0,1,0); box.ClearTextOnFocus=false; box.Parent = searchBar
  corner(box,8); stroke(box,0.5); box.ZIndex = 3; searchBar.ZIndex = 3

  local container = Instance.new("Frame"); container.BackgroundTransparency=1; container.Size=UDim2.new(1,0,0,0); container.AutomaticSize=Enum.AutomaticSize.Y; container.Parent=sc; container.LayoutOrder=2
  local vlist = Instance.new("UIListLayout"); vlist.Padding=UDim.new(0,8); vlist.SortOrder = Enum.SortOrder.LayoutOrder; vlist.Parent=container

  local function matches(frame, q)
    q = string.lower(q)
    local function findText(obj)
      for _,d in ipairs(obj:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
          local tx = string.lower(d.Text or "")
          if string.find(tx, q, 1, true) then return true end
        end
      end
      return false
    end
    return findText(frame)
  end
  local function applyFilter()
    local q = box.Text
    for _,item in ipairs(container:GetChildren()) do
      if item:IsA("Frame") then item.Visible = (q=="" or matches(item, q)) end
    end
  end
  box:GetPropertyChangedSignal("Text"):Connect(applyFilter)

  local tab = { Button = navBtn, Page = page, Container = container }
  self._Tabs[tabName] = tab

  navBtn.MouseButton1Click:Connect(function()
    for _,tb in pairs(self._Tabs) do tb.Page.Visible=false; tb.Button.BackgroundColor3=Theme.Panel end
    page.Visible = true; navBtn.BackgroundColor3 = Theme.Accent; self._CurrentTab = tab
  end)

  if not self._CurrentTab then
    self._CurrentTab = tab
    page.Visible = true
    navBtn.BackgroundColor3 = Theme.Accent
  end

  local function card(height)
    local f = Instance.new("Frame"); f.BackgroundColor3 = Theme.Panel2; f.BackgroundTransparency=0.1; f.Size=UDim2.new(1,0,0,height or 56)
    corner(f,10); stroke(f,0.5); pad(f,8); f.Parent = container; return f
  end
  local function header(parent, title, subtitle)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency=1; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.TextYAlignment=Enum.TextYAlignment.Top; lbl.RichText=true
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.TextColor3=Theme.Text
    lbl.Text = subtitle and (title.."\n<font color='#9aa3b2'>"..subtitle.."</font>") or (title or "")
    lbl.Size=UDim2.new(1,-200,1,0); lbl.Parent=parent; return lbl
  end

  local api = {}

  function api:AddSection(d)
    local c = card(28)
    local name = (typeof(d)=="table" and d.Name) or (typeof(d)=="string" and d) or "Section"
    local t = Instance.new("TextLabel"); t.BackgroundTransparency=1; t.TextXAlignment=Enum.TextXAlignment.Left; t.Font=Enum.Font.GothamMedium; t.TextSize=12; t.TextColor3=Theme.Text; t.Text=name; t.Parent=c
  end

  function api:AddParagraph(a,b)
    local d; if typeof(a)=="table" then d=a else d={Title=a, Content=b} end
    local c = card(86)
    local tl = Instance.new("TextLabel"); tl.BackgroundTransparency=1; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Font=Enum.Font.GothamMedium; tl.TextSize=12; tl.TextColor3=Theme.Text; tl.Text=(d.Title or ""); tl.Size=UDim2.new(1,-8,0,18); tl.Parent=c
    local tx = Instance.new("TextLabel"); tx.BackgroundTransparency=1; tx.TextXAlignment=Enum.TextXAlignment.Left; tx.TextYAlignment=Enum.TextYAlignment.Top; tx.TextWrapped=true; tx.Font=Enum.Font.Gotham; tx.TextSize=12; tx.TextColor3=Theme.TextDim; tx.Text=(d.Content or ""); tx.Position=UDim2.fromOffset(0,22); tx.Size=UDim2.new(1,-8,1,-26); tx.Parent=c
    return { Set=function(dd) tl.Text=dd.Title or tl.Text; tx.Text=dd.Content or tx.Text end }
  end

  function api:AddLabel(a)
    local text = (typeof(a)=="table" and a.Name) or a or "Label"
    local c = card(32)
    local t = Instance.new("TextLabel"); t.BackgroundTransparency=1; t.TextXAlignment=Enum.TextXAlignment.Left; t.Font=Enum.Font.Gotham; t.TextSize=12; t.TextColor3=Theme.Text; t.Text=text; t.Parent=c
    return { Set=function(v) t.Text=v end }
  end

  function api:AddButton(d)
    d = d or {}
    local c = card(48); header(c, d.Name or "Button")
    local b = Instance.new("TextButton"); b.AnchorPoint=Vector2.new(1,0.5); b.Position=UDim2.new(1,-12,0.5,0); b.Size=UDim2.fromOffset(120,28)
    b.Text = d.ButtonName or "Run"; b.Font=Enum.Font.Gotham; b.TextSize=12; b.TextColor3=Theme.Text; b.BackgroundColor3=Theme.Panel; b.BackgroundTransparency=0.1; b.AutoButtonColor=false; corner(b,8); stroke(b,0.5); b.Parent=c
    b.MouseButton1Click:Connect(function() if d.Callback then pcall(d.Callback) end end)
  end

  function api:AddToggle(d)
    d = d or {}
    local c = card(56); header(c, d.Name or "Toggle", d.Info)
    local accent = d.Color or Theme.Accent
    local sw = Instance.new("TextButton"); sw.Size=UDim2.fromOffset(56,28); sw.AnchorPoint=Vector2.new(1,0.5); sw.Position=UDim2.new(1,-12,0.5,0); sw.Text=""; sw.AutoButtonColor=false
    sw.BackgroundColor3 = (d.Default and accent) or Color3.fromRGB(60,62,70); corner(sw,14); stroke(sw,0.5); sw.Parent=c
    local knob = Instance.new("Frame"); knob.Size=UDim2.fromOffset(22,22); knob.Position=(d.Default and UDim2.fromOffset(30,3)) or UDim2.fromOffset(4,3); knob.BackgroundColor3=Color3.fromRGB(240,240,240); corner(knob,11); knob.Parent=sw
    local on = d.Default or false
    local function set(v)
      on = v and true or false
      sw.BackgroundColor3 = on and accent or Color3.fromRGB(60,62,70)
      knob.Position = on and UDim2.fromOffset(30,3) or UDim2.fromOffset(4,3)
      if d.Flag then local flags=makeFlagTable(Orion); flags[d.Flag]=flags[d.Flag] or {}; flags[d.Flag].Value=on end
      if d.Callback then pcall(d.Callback, on) end
    end
    sw.MouseButton1Click:Connect(function() set(not on) end)
    attachFlag(Orion, d.Flag, set, function() return on end, on); set(on)
    return { Set = set }
  end

  function api:AddSlider(d)
    d = d or {}
    local min, max = d.Min or 0, d.Max or 100
    local inc = math.max(1, d.Increment or 1)
    local def = d.Default or min
    local c = card(68)
    local vn = d.ValueName
    header(c, d.Name or "Slider", (vn and (vn..": ") or "")..string.format("%d–%d", min, max))
    local valLbl = Instance.new("TextLabel"); valLbl.BackgroundTransparency=1; valLbl.AnchorPoint=Vector2.new(1,0); valLbl.Position=UDim2.new(1,-12,0,0); valLbl.Size=UDim2.fromOffset(100,16)
    valLbl.Font=Enum.Font.Gotham; valLbl.TextSize=12; valLbl.TextColor3=Theme.TextDim; valLbl.TextXAlignment=Enum.TextXAlignment.Right; valLbl.Parent=c
    local track = Instance.new("Frame"); track.Size=UDim2.new(1,-24,0,6); track.Position=UDim2.fromOffset(12,38); track.BackgroundColor3=Color3.fromRGB(60,62,70); corner(track,3); track.Parent=c
    local fill = Instance.new("Frame"); fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=d.Color or Theme.Accent; corner(fill,3); fill.Parent=track
    local knob = Instance.new("Frame"); knob.Size=UDim2.fromOffset(14,14); knob.AnchorPoint=Vector2.new(0.5,0.5); knob.Position=UDim2.new(0,0,0.5,0); knob.BackgroundColor3=Color3.fromRGB(240,240,240); corner(knob,7); knob.Parent=track
    local value = def
    local function roundStep(v) v = math.clamp(v, min, max); local n = math.floor((v - min)/inc + 0.5)*inc + min; return math.clamp(n, min, max) end
    local function set(v)
      value = roundStep(v); local a = (value - min)/(max - min)
      fill.Size = UDim2.new(a,0,1,0); knob.Position = UDim2.new(a,0,0.5,0); valLbl.Text = tostring(value)
      if d.Flag then local flags=makeFlagTable(Orion); flags[d.Flag]=flags[d.Flag] or {}; flags[d.Flag].Value=value end
      if d.Callback then pcall(d.Callback, value) end
    end
    local dragging = false
    track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    track.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(input)
      if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local rel = math.clamp((UserInputService:GetMouseLocation().X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
        set(min + rel*(max - min))
      end
    end)
    attachFlag(Orion, d.Flag, set, function() return value end, value); set(def)
    return { Set = set }
  end

  function api:AddDropdown(d)
    d = d or {}
    local items = {}
    for _,v in ipairs(d.Options or {"A","B"}) do table.insert(items, v) end
    local sel = d.Default or items[1]
    local c = card(56); header(c, d.Name or "Dropdown")

    local btn = Instance.new("TextButton"); btn.AnchorPoint=Vector2.new(1,0.5); btn.Position=UDim2.new(1,-12,0.5,0); btn.Size=UDim2.fromOffset(220,28)
    btn.Text = sel or ""; btn.Font=Enum.Font.Gotham; btn.TextSize=12; btn.TextColor3=Theme.Text; btn.BackgroundColor3=Theme.Panel; btn.BackgroundTransparency=0.1; btn.AutoButtonColor=false; corner(btn,8); stroke(btn,0.5); btn.Parent=c

    local popupRoot = self._PopupRoot
    local currentPopup
    local function closePopup() if currentPopup then currentPopup:Destroy(); currentPopup = nil end end

    local function rebuild(menu)
      for _,ch in ipairs(menu:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
      if #items == 0 then
        local i = Instance.new("TextLabel"); i.Size=UDim2.new(1,0,0,22); i.Text="(no options)"; i.TextColor3=Theme.TextDim; i.Font=Enum.Font.Gotham; i.TextSize=12; i.BackgroundTransparency=1; i.ZIndex=5001; i.Parent=menu
        return
      end
      for _,it in ipairs(items) do
        local i = Instance.new("TextButton"); i.Size=UDim2.new(1,0,0,22); i.Text=it; i.TextColor3=Theme.Text; i.Font=Enum.Font.Gotham; i.TextSize=12; i.BackgroundTransparency=1; i.ZIndex=5001; i.Parent=menu
        i.MouseButton1Click:Connect(function()
          sel = it; btn.Text = sel
          if d.Flag then local flags=makeFlagTable(Orion); flags[d.Flag]=flags[d.Flag] or {}; flags[d.Flag].Value=sel end
          if d.Callback then pcall(d.Callback, sel) end
          closePopup()
        end)
      end
    end

    local function clampMenuPos(x, y, w, h)
      local vs = Camera and Camera.ViewportSize or Vector2.new(1920,1080)
      local nx = math.clamp(x, 8, vs.X - w - 8)
      local ny = math.clamp(y, 8, vs.Y - h - 8)
      return nx, ny
    end

    local function openPopup()
      closePopup()
      local holder = Instance.new("Frame"); holder.Name="DropdownPopup"; holder.BackgroundTransparency=1; holder.Size=UDim2.fromScale(1,1); holder.ZIndex=5000; holder.Parent=popupRoot
      local blocker = Instance.new("TextButton"); blocker.BackgroundTransparency=1; blocker.Text=""; blocker.Size=UDim2.fromScale(1,1); blocker.ZIndex=5000; blocker.Parent=holder
      local menu = Instance.new("Frame"); menu.BackgroundColor3=Theme.Panel; menu.BackgroundTransparency=0.05; menu.ZIndex=5001
      corner(menu,8); stroke(menu,0.5); pad(menu,6); menu.Parent=holder

      local l = Instance.new("UIListLayout"); l.Padding=UDim.new(0,6); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent=menu

      local height = math.clamp(math.max(#items,1),1,8)*24 + 8
      menu.Size = UDim2.fromOffset(220, height)

      -- position under the button
      local pos = btn.AbsolutePosition; local size = btn.AbsoluteSize
      local mx = pos.X + size.X - 220
      local my = pos.Y + size.Y + 6
      mx, my = clampMenuPos(mx, my, 220, height)
      menu.Position = UDim2.fromOffset(mx, my)

      rebuild(menu)

      blocker.MouseButton1Click:Connect(closePopup)
      currentPopup = holder

      if #items == 0 then
        local ok = pcall(function()
          game:GetService("StarterGui"):SetCore("SendNotification", {Title="Dropdown", Text="Options kosong.", Duration=1})
        end)
      end
    end

    btn.MouseButton1Click:Connect(function()
      if currentPopup then closePopup() else openPopup() end
    end)

    local function set(v) sel=v; btn.Text=v; if d.Callback then pcall(d.Callback, v) end end
    attachFlag(Orion, d.Flag, set, function() return sel end, sel)

    return {
      Set = set,
      Add = function(v) table.insert(items,v) end,
      Remove = function(v)
        for k,x in ipairs(items) do if x==v then table.remove(items,k) break end end
        if sel==v then sel=items[1]; btn.Text=sel or "" end
      end
    }
  end

  function api:AddTextbox(d)
    d = d or {}
    local c = card(56); header(c, d.Name or "Textbox")
    local box = Instance.new("TextBox"); box.AnchorPoint=Vector2.new(1,0.5); box.Position=UDim2.new(1,-12,0.5,0); box.Size=UDim2.fromOffset(220,28)
    box.Text = d.Default or ""; box.PlaceholderText = d.Placeholder or (d.Default and "" or "Ketik..."); box.ClearTextOnFocus = d.TextDisappear or false
    box.Font=Enum.Font.Gotham; box.TextSize=12; box.TextColor3=Theme.Text; box.BackgroundColor3=Theme.Panel; box.BackgroundTransparency=0.1; corner(box,8); stroke(box,0.5); box.Parent=c
    local function setText(t) box.Text=t or ""; if d.Flag then local flags=makeFlagTable(Orion); flags[d.Flag]=flags[d.Flag] or {}; flags[d.Flag].Value=box.Text end end
    box.FocusLost:Connect(function() if d.Callback then pcall(d.Callback, box.Text) end if d.TextDisappear then box.Text="" end end)
    attachFlag(Orion, d.Flag, setText, function() return box.Text end, box.Text)
    return { Set = setText }
  end

  function api:AddColorpicker(d)
    d = d or {}
    local c = card(74); header(c, d.Name or "Color", d.Info)
    local swatch = Instance.new("TextButton"); swatch.AnchorPoint=Vector2.new(1,0); swatch.Position=UDim2.new(1,-12,0,0); swatch.Size=UDim2.fromOffset(160,28); swatch.Text=""; swatch.BackgroundColor3=d.Default or Theme.Accent; corner(swatch,8); stroke(swatch,0.5); swatch.Parent=c
    local row = Instance.new("Frame"); row.BackgroundTransparency=1; row.Size=UDim2.new(1,-24,0,28); row.Position=UDim2.fromOffset(12,36); row.Parent=c
    local list = Instance.new("UIListLayout"); list.FillDirection=Enum.FillDirection.Horizontal; list.Padding=UDim.new(0,6); list.Parent=row
    local presets = {Color3.fromRGB(0,170,255), Color3.fromRGB(124,58,237), Color3.fromRGB(34,197,94), Color3.fromRGB(14,165,233), Color3.fromRGB(249,115,22), Color3.fromRGB(225,29,72)}
    for _,col in ipairs(presets) do
      local p = Instance.new("TextButton"); p.Size=UDim2.fromOffset(28,28); p.Text=""; p.AutoButtonColor=false; p.BackgroundColor3=col; corner(p,6); stroke(p,0.5); p.Parent=row
      p.MouseButton1Click:Connect(function()
        swatch.BackgroundColor3 = col
        if d.Flag then local flags=makeFlagTable(Orion); flags[d.Flag]=flags[d.Flag] or {}; flags[d.Flag].Value=col end
        if d.Callback then pcall(d.Callback, col) end
      end)
    end
    local function set(col) swatch.BackgroundColor3=col; if d.Callback then pcall(d.Callback,col) end end
    attachFlag(Orion, d.Flag, set, function() return swatch.BackgroundColor3 end, swatch.BackgroundColor3)
    return { Set = set }
  end

  function api:AddBind(d)
    d = d or {}
    local c = card(56); header(c, d.Name or "Keybind")
    local box = Instance.new("TextBox"); box.AnchorPoint=Vector2.new(1,0.5); box.Position=UDim2.new(1,-12,0.5,0); box.Size=UDim2.fromOffset(220,28)
    box.Text = (d.Default and d.Default.Name) or "Klik untuk set"; box.ClearTextOnFocus=false; box.Font=Enum.Font.Gotham; box.TextSize=12; box.TextColor3=Theme.Text; box.BackgroundColor3=Theme.Panel; box.BackgroundTransparency=0.1; corner(box,8); stroke(box,0.5); box.Parent=c
    local current = d.Default or Enum.KeyCode.K; local holding=false
    local function setKey(kc)
      current = kc; box.Text = kc and kc.Name or "(none)"
      if d.Flag then local flags=makeFlagTable(Orion); flags[d.Flag]=flags[d.Flag] or {}; flags[d.Flag].Value=current end
    end
    box.Focused:Connect(function() box.Text = "Tekan tombol..." end)
    box.FocusLost:Connect(function() if current then box.Text = current.Name end end)
    UserInputService.InputBegan:Connect(function(input, gp)
      if gp then return end
      if box:IsFocused() and input.UserInputType == Enum.UserInputType.Keyboard then setKey(input.KeyCode); box:ReleaseFocus() end
      if input.KeyCode == current then if d.Hold then holding = true else if d.Callback then pcall(d.Callback) end end end
    end)
    UserInputService.InputEnded:Connect(function(input) if input.KeyCode==current and d.Hold and holding then holding=false; if d.Callback then pcall(d.Callback) end end end)
    attachFlag(Orion, d.Flag, setKey, function() return current end, current); setKey(current)
    return { Set = setKey }
  end

  return api
end

local M = setmetatable({ Flags = {} }, Orion)
return M
