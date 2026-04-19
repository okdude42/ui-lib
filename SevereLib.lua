local severeui = {}

function severeui:createwindow(options)
local windowObj = {}
local Connection
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local minMenuSizeX = 580
local minMenuSizeY = 360

local ConfigFolderName = options.ConfigFolder or "severeui_configs"

local Theme = {
    BgBase = Color3.fromRGB(28, 27, 31),
    PanelBg = Color3.fromRGB(43, 41, 48),
    Accent = Color3.fromRGB(208, 188, 255),
    AccentOff = Color3.fromRGB(55, 52, 62),
    TextMain = Color3.fromRGB(230, 225, 229),
    TextSub = Color3.fromRGB(150, 147, 155),
    Outline = Color3.fromRGB(0, 0, 0)
}

local function GetDefaultState()
    return {
        Visible = true, CurrentTab = options.DefaultTab, NextTab = nil, PopAlpha = 0, DropAlpha = 0, IntroAlpha = 0,
        TabAlignment = options.TabAlignment or "Center",
        ActivePopup = "None", TargetPopup = "None", PreviousPopup = nil,
        ActiveDropdown = nil, TargetDropdown = nil,
        Keybind = options.Keybind or "RightShift",
        
        UITrans = options.DefaultUITransparency or 1, ButtonTrans = options.DefaultButtonTransparency or 1, Transparent = false, LightMode = false,
        UIScale = options.DefaultScale or 1.0, PopFontPage = 1,
        AccentCol = options.DefaultAccent or Theme.Accent, MainCol = options.DefaultColor or Theme.BgBase,

        Snowfall = options.DefaultSnowfall ~= false, SnowCol = options.DefaultSnowfallColor or Color3.new(1,1,1), SnowSize = options.DefaultSnowfallSize or 2,
        SnowSpeed = options.DefaultSnowfallSpeed or 20, SnowAmount = options.DefaultSnowfallAmount or 40, SnowTrans = options.DefaultSnowfallTrans or 0.4,

        AccentColAlpha = 1, MainColAlpha = 1,

        SelectedConfig = "None", DefaultConfigName = "None",
        MenuSizeX = minMenuSizeX, MenuSizeY = minMenuSizeY,
        UIFont = tostring(options.DefaultFont or 5),
        HighPerformanceMode = false,
        AnimationsEnabled = true,
        LightAlpha = 0, PopCloseHovAlpha = 0,

        LastClickedPos = Vector2.new(0, 0),
        LastClickedSize = Vector2.new(0, 0),
        LightRippleOrigin = Vector2.new(0, 0), LightRippleAnim = 0, LightRippleActive = false,
        IsReloading = false
    }
end

local State = GetDefaultState()

local ConfigKeys = {
    "UITrans", "ButtonTrans", "Transparent", "LightMode", "AccentCol", "MainCol", "AccentColAlpha", "MainColAlpha",
    "Snowfall", "SnowCol", "SnowSize", "SnowSpeed", "SnowAmount", "SnowTrans",
    "Keybind", "MenuSizeX", "MenuSizeY", "UIScale", "HighPerformanceMode", "UIFont", "AnimationsEnabled"
}

local ColorKeys = {
    AccentCol = true, MainCol = true, SnowCol = true
}

local CustomPopups = {}
local ColorPicker = { Target = nil, Color = Color3.new(1,1,1), H = 0, S = 0, V = 1, Alpha = 1 }
local Elements = {}
local DrawCache = {}  
local TextSizes = {}
local ElementKeyDebounce = {}
local Interaction = { Active = false, Mode = "None", Target = nil, Offset = Vector2.new(0, 0), Action = nil, Bounds = nil }
local MenuPos = Vector2.new(0, 0)
local TargetMenuPos = Vector2.new(0, 0)
local MenuVelocity = Vector2.new(0, 0)
local MenuSize = Vector2.new(State.MenuSizeX, State.MenuSizeY)
local ToggleDebounce = false
local InitialCentered = false

local Focused = nil
local InputBuffers = {Hex = "", Keybind = "", ConfigName = ""}
local LastKey, RepeatTimer = "", 0
local SnowPopAnim = { Tog = 0, Col = 0, Size = 0, Speed = 0, Amt = 0, Trans = 0, DelYes = 0, DelNo = 0, PopClose = 0, ColorCancel = 0, ColorApply = 0, PerfYes = 0, PerfYesPress = nil, PerfNo = 0, PerfNoPress = nil }
local LastFont = -1
local LastTextScale = -1
local GlobalMousePos = Vector2.new(0,0)
local Separators = {}

local FontScales = {}
for i = 0, 31 do FontScales[i] = 1 end
pcall(function()
    local measureTxt = Drawing.new("Text")
    measureTxt.Text = "The quick brown fox jumps over the lazy dog 1234567890"
    measureTxt.Size = 13
    measureTxt.Font = 5
    local refBounds = measureTxt.TextBounds
    for i = 0, 31 do
        measureTxt.Font = i
        local b = measureTxt.TextBounds
        if b and b.X > 0 and b.Y > 0 then
            local ratioX = refBounds.X / b.X
            local ratioY = refBounds.Y / b.Y
            FontScales[i] = math.clamp(math.min(ratioX, ratioY), 0.3, 1.5)
        end
    end
    measureTxt:Remove()
end)

local function safeN(num, def) return (num ~= num or num == nil or num == math.huge or num == -math.huge) and (def or 0) or num end
local function safeV(vec, def) if not vec then return def or Vector2.zero end return Vector2.new(safeN(vec.X), safeN(vec.Y)) end
local function ExpLerp(a, b, dt, speed)
    if State.HighPerformanceMode then return b end
    a, b, dt = safeN(a, 0), safeN(b, 0), safeN(dt, 0.01)
    return a + (b - a) * (1 - math.exp(-speed * dt))
end
local function SafeSize(obj, size)
    if not obj then return end
    pcall(function() obj.Size = math.ceil(math.max(1, safeN(size, 13))) end)
end
local function Lerp(a, b, t) return safeN(a) + (safeN(b) - safeN(a)) * safeN(t) end
local function Lerp2(a, b, t) return Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
local function LerpColor(c1, c2, t)
    if not c1 or not c2 then return Color3.new(1, 1, 1) end
    return Color3.new(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t)
end
local function AdaptiveSeparator(bg, accent, lightA)
    local v = (bg.R + bg.G + bg.B) / 3
    local isLight = v > 0.5
    local target = isLight and Color3.new(0,0,0) or Color3.new(1,1,1)
    local baseSep = LerpColor(bg, target, 0.15)
    return LerpColor(baseSep, accent, 0.2)
end
local function vRound(v) return Vector2.new(math.floor(v.X + 0.5), math.floor(v.Y + 0.5)) end

local function ApplyCurve(t, curveType) 
    if curveType == "Linear" then return t end
    return 1 - math.pow(1 - t, 4) 
end

local function LightenColor(c, amount)
    return Color3.new(
        math.clamp(c.R + (1 - c.R) * amount, 0, 1),
        math.clamp(c.G + (1 - c.G) * amount, 0, 1),
        math.clamp(c.B + (1 - c.B) * amount, 0, 1)
    )
end
local function hitBox(pos, boxPos, boxSize) return pos.X >= boxPos.X and pos.X <= boxPos.X + boxSize.X and pos.Y >= boxPos.Y and pos.Y <= boxPos.Y + boxSize.Y end

local function toHex(c)
    if type(c) == "string" then return c end
    local r = math.clamp(math.floor((c.R or 0)*255), 0, 255)
    local g = math.clamp(math.floor((c.G or 0)*255), 0, 255)
    local b = math.clamp(math.floor((c.B or 0)*255), 0, 255)
    return string.format("#%02X%02X%02X", r, g, b)
end

local function fromHex(hex)
    if type(hex) ~= "string" then return nil end
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return nil end
    local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    if r and g and b then return Color3.fromRGB(r, g, b) end
    return nil
end

local function ApplySpring(current, target, velocity, dt, stiffness, damping)
    if State.HighPerformanceMode then return target, 0 end
    local force = -stiffness * (current - target) - damping * velocity
    local newVel = velocity + force * dt
    return current + newVel * dt, newVel
end

local ConfigDropdown
local DefaultConfigDropdown

local function GetConfigs()
    local names = {}
    pcall(function()
        if not isfolder(ConfigFolderName) then makefolder(ConfigFolderName) end
        local files = listfiles(ConfigFolderName)
        for _, f in ipairs(files) do
            local name = f:match("([^/\\]+)%.[jJ][sS][oO][nN]$")
            if name and not name:match("^default_") then
                table.insert(names, name)
            end
        end
    end)
    if #names == 0 then table.insert(names, "None") end
    table.sort(names)
    return names
end

local function GetDefaultConfigs()
    local opts = GetConfigs()
    local hasNone = false
    for _, v in ipairs(opts) do if v == "None" then hasNone = true; break end end
    if not hasNone then table.insert(opts, 1, "None") end
    return opts
end

local function SafeEncode(data)
    local s, res = pcall(function() return HttpService:JSONEncode(data) end)
    if s and res then return res end
    local s2, res2 = pcall(function() return crypt.json.encode(data) end)
    if s2 and res2 then return res2 end
    return ""
end

local function SafeDecode(str)
    local s, res = pcall(function() return HttpService:JSONDecode(str) end)
    if s and res then return res end
    local s2, res2 = pcall(function() return crypt.json.decode(str) end)
    if s2 and res2 then return res2 end
    return nil
end

local function SaveConfig(name)
    State.MenuSizeX = MenuSize.X; State.MenuSizeY = MenuSize.Y
    local saveData = {}
    for _, k in ipairs(ConfigKeys) do
        local v = State[k]
        if ColorKeys[k] then
            saveData[k] = toHex(v)
        elseif type(v) == "number" then
            saveData[k] = tostring(v)
        elseif type(v) == "boolean" then
            saveData[k] = (v and "true" or "false")
        elseif type(v) == "string" or type(v) == "table" then
            saveData[k] = v
        end
    end
    if not isfolder(ConfigFolderName) then makefolder(ConfigFolderName) end
    local encoded = SafeEncode(saveData)
    if encoded ~= "" then
        pcall(function() writefile(ConfigFolderName .. "/" .. name .. ".json", encoded) end)
        if ConfigDropdown then ConfigDropdown.Options = GetConfigs() end
        if DefaultConfigDropdown then DefaultConfigDropdown.Options = GetDefaultConfigs() end
        State.SelectedConfig = name
    end
end

local Snowflakes = {}
local function GenerateSnow()
    Snowflakes = {}
    for i = 1, State.SnowAmount do
        table.insert(Snowflakes, { X = math.random(0, 100), Y = math.random(0, 100), SpeedMult = 0.6 + math.random() * 1.5, Sine = math.random(0, 100) })
    end
end

local function LoadConfig(name, isAutoLoad)
    local path = ConfigFolderName .. "/" .. name .. ".json"
    if isfile(path) then
        local s, content = pcall(readfile, path)
        if not s then return end
        local data = SafeDecode(content)
        if type(data) == "table" then
            for _, k in ipairs(ConfigKeys) do
                local v = data[k]
                if v ~= nil then
                    if ColorKeys[k] then
                        if type(v) == "string" then
                            local col = fromHex(v) or State[k]
                            State["Target_"..k] = col; State[k] = col
                        elseif type(v) == "table" and v.R then
                            local col = Color3.new(v.R, v.G, v.B)
                            State["Target_"..k] = col; State[k] = col
                        end
                    elseif type(State[k]) == "number" then
                        State[k] = tonumber(v) or State[k]
                    elseif type(State[k]) == "boolean" then
                        State[k] = (v == true or v == "true")
                    else
                        State[k] = v
                    end
                end
            end
            local savedScale = math.clamp((State.MenuSizeX or minMenuSizeX) / minMenuSizeX, 0.65, 2.5)
            MenuSize = Vector2.new(minMenuSizeX * savedScale, minMenuSizeY * savedScale)
            if not isAutoLoad then State.SelectedConfig = name end
            GenerateSnow()
        end
    end
end

local function DeleteConfig(name)
    local path = ConfigFolderName .. "/" .. name .. ".json"
    if isfile(path) then pcall(delfile, path) end
    if State.DefaultConfigName == name then
        State.DefaultConfigName = "None"
        pcall(function() delfile(ConfigFolderName .. "/default_global.json") end)
        pcall(function() delfile(ConfigFolderName .. "/default_game_"..game.PlaceId..".json") end)
    end
    if ConfigDropdown then ConfigDropdown.Options = GetConfigs(); State.SelectedConfig = "None" end
    if DefaultConfigDropdown then DefaultConfigDropdown.Options = GetDefaultConfigs() end
end

local function CreateDrawing(class)
    local obj = Drawing.new(class)
    table.insert(DrawCache, obj)
    return obj
end

local function CreateText(text, size, center, color, zindex)
    local t = CreateDrawing("Text")
    t.Text = text; t.Size = size or 13; t.Color = color or Theme.TextMain
    t.Center = center or false; t.Font = tonumber(State.UIFont) or 5; t.Outline = false;
    t.Visible = false; t.Transparency = 1; t.ZIndex = zindex or 6
    TextSizes[t] = size or 13
    return t
end

local function CreateSquare(filled, color, transparency, zindex, rounding)
    local s = CreateDrawing("Square")
    s.Filled = filled; s.Color = color or Theme.PanelBg
    s.Transparency = transparency or 1; s.Visible = false; s.ZIndex = zindex or 5
    if rounding then s.Rounding = rounding end
    return s
end

GenerateSnow()

if _G.SevereCleanup then _G.SevereCleanup() end
_G.SevereCleanup = function()
    for _, obj in pairs(DrawCache) do pcall(function() obj:Remove() end) end
    DrawCache = {}
    if Connection then Connection:Disconnect() end
    _G.SevereCleanup = nil
end

local function SwitchTab(tab)
    if State.CurrentTab == tab then return end
    State.NextTab = tab; Focused = nil; State.TargetDropdown = nil
end

local function GetAlphaKey(target)
    if target == "AccentCol" then return "AccentColAlpha"
    elseif target == "MainCol" then return "MainColAlpha"
    elseif target == "SnowCol" then return "SnowTrans"
    end
    return nil
end

local function ResetToDefault(target)
    if not target then return end
    local def = Color3.new(1,1,1)
    if target == "MainCol" then def = Theme.BgBase
    elseif target == "AccentCol" then def = Theme.Accent
    end
    ColorPicker.Color = def
    ColorPicker.H, ColorPicker.S, ColorPicker.V = def:ToHSV()
    InputBuffers.Hex = toHex(def):gsub("#","")
end

local function UpdateColorFromHSV()
    ColorPicker.Color = Color3.fromHSV(ColorPicker.H, ColorPicker.S, ColorPicker.V)
    if ColorPicker.Target then
        State[ColorPicker.Target] = ColorPicker.Color
        local aKey = GetAlphaKey(ColorPicker.Target)
        if aKey then State[aKey] = ColorPicker.Alpha end
    end
end

local function OpenColor(target, color, alphaKey)
    State.PopAlpha = 0; State.TargetPopup = "Color"; ColorPicker.Target = target; ColorPicker.Color = color
    ColorPicker.H, ColorPicker.S, ColorPicker.V = color:ToHSV()
    ColorPicker.Alpha = alphaKey and State[alphaKey] or 0
    InputBuffers.Hex = toHex(color)
end

local function Apply()
    if Focused == "Hex" then
        local newC = fromHex(InputBuffers.Hex)
        if newC then
            ColorPicker.Color = newC
            ColorPicker.H, ColorPicker.S, ColorPicker.V = newC:ToHSV()
        end
    elseif Focused == "Red" or Focused == "Green" or Focused == "Blue" or Focused == "Alpha" then
        local val = tonumber(InputBuffers[Focused])
        if val then
            if Focused == "Alpha" then
                ColorPicker.Alpha = math.clamp(val / 100, 0, 1)
            else
                local r, g, b = ColorPicker.Color.R, ColorPicker.Color.G, ColorPicker.Color.B
                if Focused == "Red" then r = math.clamp(val/255, 0, 1)
                elseif Focused == "Green" then g = math.clamp(val/255, 0, 1)
                elseif Focused == "Blue" then b = math.clamp(val/255, 0, 1) end
                ColorPicker.Color = Color3.new(r, g, b)
                ColorPicker.H, ColorPicker.S, ColorPicker.V = ColorPicker.Color:ToHSV()
            end
            if ColorPicker.Target then
                State[ColorPicker.Target] = ColorPicker.Color
                local aKey = GetAlphaKey(ColorPicker.Target)
                if aKey then State[aKey] = ColorPicker.Alpha end
            end
        end
    elseif Focused and State[Focused] ~= nil then
        if type(State[Focused]) == "number" then
            local val = tonumber(InputBuffers[Focused]);
            if val then State[Focused] = val end
        end
    end
    Focused = nil
end

local Tabs = {}
local TabDrawings = {}

function windowObj:getvalue(name)
    return State[name]
end

function windowObj:setvalue(name, value)
    State[name] = value
end

function windowObj:createtab(name)
    for _, existingTab in ipairs(Tabs) do
        if existingTab == name then return name end
    end

    table.insert(Tabs, name)
    local b = CreateSquare(true, Theme.PanelBg, 1, 3, 16)
    local t = CreateText(name, 13, true, Theme.TextSub, 4)
    table.insert(TabDrawings, {Name = name, Box = b, Txt = t, Anim = 0})

    local sIdx = -1
    for i, tName in ipairs(Tabs) do
        if tName == "Settings" then sIdx = i; break end
    end
    if sIdx ~= -1 and sIdx < #Tabs then
        local sTab = table.remove(Tabs, sIdx)
        table.insert(Tabs, sTab)
        local sDraw = table.remove(TabDrawings, sIdx)
        table.insert(TabDrawings, sDraw)
    end

    if not State.CurrentTab then 
        State.CurrentTab = name 
    end
    return name
end

function windowObj:settaborder(orderArray)
    local newTabs = {}
    local newDrawings = {}
    
    for _, orderedName in ipairs(orderArray) do
        for i, existingName in ipairs(Tabs) do
            if existingName == orderedName then
                table.insert(newTabs, existingName)
                table.insert(newDrawings, TabDrawings[i])
                break
            end
        end
    end
    
    for i, existingName in ipairs(Tabs) do
        local found = false
        for _, newName in ipairs(newTabs) do
            if existingName == newName then found = true; break end
        end
        if not found then
            table.insert(newTabs, existingName)
            table.insert(newDrawings, TabDrawings[i])
        end
    end
    
    Tabs = newTabs
    TabDrawings = newDrawings
end

function windowObj:createpopup(name, size)
    CustomPopups[name] = size or Vector2.new(280, 300)
end

function windowObj:openpopup(name)
    State.PopAlpha = 0
    State.TargetPopup = name
end

function windowObj:closepopup()
    State.TargetPopup = "None"
end

function windowObj:createtoggle(tabName, o)
    local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
    local t = CreateText(o.Name, 13, false, Theme.TextMain, 6)
    local togBg = CreateSquare(true, Theme.AccentOff, 1, 6, 24)
    local togKnob = CreateSquare(true, Theme.TextSub, 1, 7, 16)
    if o.Default ~= nil then State[o.Name] = o.Default else State[o.Name] = false end
    
    local isConfigAdded = false
    for _, v in ipairs(ConfigKeys) do if v == o.Name then isConfigAdded = true break end end
    if not isConfigAdded then table.insert(ConfigKeys, o.Name) end

    local keyBg, keyTxt
    if o.HasKeybind then
        keyBg = CreateSquare(true, Theme.BgBase, 1, 6, 8)
        keyTxt = CreateText("[ - ]", 13, true, Theme.TextSub, 7)
        if State[o.Name .. "_Key"] == nil then State[o.Name .. "_Key"] = o.DefaultKeybind or "None" end
        local keyConfigAdded = false
        for _, v in ipairs(ConfigKeys) do if v == o.Name .. "_Key" then keyConfigAdded = true break end end
        if not keyConfigAdded then table.insert(ConfigKeys, o.Name .. "_Key") end
    end

    local el = { Bg = bg, Txt = t, TogBg = togBg, TogKnob = togKnob, Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Toggle", StateKey = o.Name, Anim = 0, SubAnim = 0, HoverAnim = 0, DisabledAnim = 0, Half = o.Half, SameRow = o.SameRow, CustomWidth = o.CustomWidth, CustomOffset = o.CustomOffset,
        HasKeybind = o.HasKeybind, KeyBg = keyBg, KeyTxt = keyTxt, KeyStateKey = o.Name .. "_Key",
        Callback = function(self)
            State[self.StateKey] = not State[self.StateKey]
            if o.Callback then o.Callback(State[self.StateKey]) end
        end }
    table.insert(Elements, el)
    return el
end

function windowObj:createslider(tabName, o)
    local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
    local fBg = CreateSquare(true, Theme.BgBase, 1, 6, 8)
    local fFill = CreateSquare(true, Theme.Accent, 1, 7, 8)
    local t = CreateText(o.Name, 13, false, Theme.TextMain, 6)
    local valBg = CreateSquare(true, Theme.BgBase, 1, 6, 12)
    if o.Default ~= nil then State[o.Name] = o.Default else State[o.Name] = o.Min or 0 end
    local valTxt = CreateText(tostring(State[o.Name]), 13, true, Theme.TextMain, 7)
    
    local isConfigAdded = false
    for _, v in ipairs(ConfigKeys) do if v == o.Name then isConfigAdded = true break end end
    if not isConfigAdded then table.insert(ConfigKeys, o.Name) end

    local el = { Bg = bg, FillBg = fBg, Fill = fFill, Txt = t, ValBg = valBg, ValTxt = valTxt, BaseText = o.Name,
        Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Slider", Min = o.Min or 0, Max = o.Max or 100, StateKey = o.Name, InputKey = o.Name, IsFloat = o.IsFloat, Anim = 0, HoverAnim = 0, DisabledAnim = 0, Half = o.Half, SameRow = o.SameRow, CustomWidth = o.CustomWidth, CustomOffset = o.CustomOffset,
        Callback = function(val) State[o.Name] = val; if o.Callback then o.Callback(val) end end }
    table.insert(Elements, el)
    return el
end

function windowObj:createbutton(tabName, o)
    local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
    local t = CreateText(o.Name, 13, true, Theme.TextMain, 6)
    
    local keyBg, keyTxt
    if o.HasKeybind then
        keyBg = CreateSquare(true, Theme.BgBase, 1, 6, 8)
        keyTxt = CreateText("[ - ]", 13, true, Theme.TextSub, 7)
        if State[o.Name .. "_Key"] == nil then State[o.Name .. "_Key"] = o.DefaultKeybind or "None" end
        local keyConfigAdded = false
        for _, v in ipairs(ConfigKeys) do if v == o.Name .. "_Key" then keyConfigAdded = true break end end
        if not keyConfigAdded then table.insert(ConfigKeys, o.Name .. "_Key") end
    end

    local el = { Bg = bg, Txt = t, Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Button", BaseText = o.Name, Callback = o.Callback, IsInput = isInput, InputKey = inputKey, HoverAnim = 0, DisabledAnim = 0, Half = o.Half, SameRow = o.SameRow, CustomWidth = o.CustomWidth, CustomOffset = o.CustomOffset, HasKeybind = o.HasKeybind, KeyBg = keyBg, KeyTxt = keyTxt, KeyStateKey = o.Name .. "_Key" }
    table.insert(Elements, el)
    return el
end

function windowObj:createdropdown(tabName, o)
    local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
    if o.Default ~= nil then State[o.Name] = o.Default else State[o.Name] = (o.Options and o.Options[1]) or "None" end
    local t = CreateText(o.Name .. ": " .. tostring(State[o.Name]), 13, false, Theme.TextMain, 6)
    local icon = CreateText("▼", 13, true, Theme.TextSub, 6)
    
    local isConfigAdded = false
    for _, v in ipairs(ConfigKeys) do if v == o.Name then isConfigAdded = true break end end
    if not isConfigAdded then table.insert(ConfigKeys, o.Name) end

    local el = { Bg = bg, Txt = t, Icon = icon, Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Dropdown", Options = o.Options or {}, StateKey = o.Name, BaseText = o.Name, HoverAnim = 0, SubAnim = 0, BtnHoverAnim = 0, DisabledAnim = 0, Callback = o.Callback, Half = o.Half, SameRow = o.SameRow, CustomWidth = o.CustomWidth, CustomOffset = o.CustomOffset }
    table.insert(Elements, el)
    return el
end

function windowObj:createcolorpicker(tabName, o)
    if o.Default ~= nil then State[o.Name] = o.Default else State[o.Name] = Color3.new(1,1,1) end
    
    local isConfigAdded = false
    for _, v in ipairs(ConfigKeys) do if v == o.Name then isConfigAdded = true break end end
    if not isConfigAdded then 
        table.insert(ConfigKeys, o.Name) 
        ColorKeys[o.Name] = true 
    end

    local el = self:createbutton(tabName, {
        Name = o.Name,
        Popup = o.Popup,
        Col = o.Col or 1,
        Half = o.Half,
        CustomWidth = o.CustomWidth,
        CustomOffset = o.CustomOffset,
        SameRow = o.SameRow,
        Callback = function(btn)
            State.PopAlpha = 0
            State.PreviousPopup = o.Popup or "None"
            State.TargetPopup = "Color"
            ColorPicker.Target = o.Name
            ColorPicker.Color = State[o.Name]
            InputBuffers.Hex = toHex(State[o.Name]) 
        end
    })
    return el
end

function windowObj:createlabel(tabName, text, col, popup)
    local bg = CreateSquare(true, Theme.BgBase, 0, 5, 0)
    local t = CreateText(text, 13, false, Theme.Accent, 6)
    local el = { Bg = bg, Txt = t, Tab = (not popup) and tabName or nil, Popup = popup, Col = col or 1, Type = "Label", BaseText = text }
    table.insert(Elements, el)
    return el
end

function windowObj:createseparator(tabName, col, popup)
    local bg = CreateSquare(true, Theme.Outline, 0.4, 5, 0)
    local el = { Bg = bg, Tab = (not popup) and tabName or nil, Popup = popup, Col = col or 1, Type = "Separator" }
    table.insert(Elements, el)
    table.insert(Separators, el)
    return el
end

function windowObj:createspacer(tabName, o)
    local el = { Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Spacer", Height = o.Height or 10 }
    table.insert(Elements, el)
    return el
end

local function CreateLabel_Internal(text, tab, col)
    local bg = CreateSquare(true, Theme.BgBase, 0, 5, 0)
    local t = CreateText(text, 13, false, Theme.Accent, 6)
    local el = { Bg = bg, Txt = t, Tab = tab, Col = col or 1, Type = "Label", BaseText = text }
    table.insert(Elements, el)
    return el
end

local function CreateSeparator_Internal(tab, col)
    local bg = CreateSquare(true, Theme.Outline, 0.4, 5, 0)
    local el = { Bg = bg, Tab = tab, Col = col or 1, Type = "Separator" }
    table.insert(Elements, el)
    table.insert(Separators, el)
    return el
end

local function CreateToggle_Internal(text, tab, col, stateKey, cb, half, sameRow)
    local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
    local t = CreateText(text, 13, false, Theme.TextMain, 6)
    local togBg = CreateSquare(true, Theme.AccentOff, 1, 6, 24)
    local togKnob = CreateSquare(true, Theme.TextSub, 1, 7, 16)
    local el = { Bg = bg, Txt = t, TogBg = togBg, TogKnob = togKnob, Tab = tab, Col = col, Type = "Toggle", StateKey = stateKey, Anim = 0, SubAnim = 0, HoverAnim = 0, DisabledAnim = 0, Half = half, SameRow = sameRow,
        Callback = function(self)
            State[self.StateKey] = not State[self.StateKey]
            if cb then cb(State[self.StateKey]) end
        end }
    table.insert(Elements, el)
    return el
end

local function CreateSlider_Internal(text, tab, col, min, max, stateKey, isFloat, half, sameRow)
    local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
    local fBg = CreateSquare(true, Theme.BgBase, 1, 6, 8)
    local fFill = CreateSquare(true, Theme.Accent, 1, 7, 8)
    local t = CreateText(text, 13, false, Theme.TextMain, 6)
    local valBg = CreateSquare(true, Theme.BgBase, 1, 6, 12)
    local valTxt = CreateText(tostring(State[stateKey]), 13, true, Theme.TextMain, 7)
    local el = { Bg = bg, FillBg = fBg, Fill = fFill, Txt = t, ValBg = valBg, ValTxt = valTxt, BaseText = text,
        Tab = tab, Col = col, Type = "Slider", Min = min, Max = max, StateKey = stateKey, InputKey = stateKey, IsFloat = isFloat, Anim = 0, HoverAnim = 0, DisabledAnim = 0, Half = half, SameRow = sameRow,
        Callback = function(val) State[stateKey] = val end }
    table.insert(Elements, el)
    return el
end

local function CreateButton_Internal(text, tab, col, callback, isInput, inputKey, half, sameRow)
    local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
    local t = CreateText(text, 13, true, Theme.TextMain, 6)
    local el = { Bg = bg, Txt = t, Tab = tab, Col = col, Type = "Button", BaseText = text, Callback = callback, IsInput = isInput, InputKey = inputKey, HoverAnim = 0, DisabledAnim = 0, Half = half, SameRow = sameRow }
    table.insert(Elements, el)
    return el
end

local function CreateDropdown_Internal(text, tab, col, dropdownOptions, stateKey)
    local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
    local t = CreateText(text .. ": " .. State[stateKey], 13, false, Theme.TextMain, 6)
    local icon = CreateText("▼", 13, true, Theme.TextSub, 6)
    local el = { Bg = bg, Txt = t, Icon = icon, Tab = tab, Col = col, Type = "Dropdown", Options = dropdownOptions, StateKey = stateKey, BaseText = text, HoverAnim = 0, SubAnim = 0, BtnHoverAnim = 0, DisabledAnim = 0 }
    table.insert(Elements, el)
    return el
end

local DropShadows = {}
local SHADOW_LAYERS = 12
for i = 1, SHADOW_LAYERS do table.insert(DropShadows, CreateSquare(true, Color3.fromRGB(0, 0, 0), 0, 0, 24)) end

local BaseBg = CreateSquare(true, Theme.BgBase, 1, 1, 24)
local TopBar = CreateSquare(true, Theme.BgBase, 1, 2, 24)
local MainTitle = CreateText(options.Title or "UI lib by ok0f", 18, false, Theme.Accent, 3)
local V2Text = CreateText(options.Version or "v1", 13, true, Theme.TextSub, 3)
local V2TextShadow = CreateText(options.Version or "v1", 13, true, Color3.new(0, 0, 0), 2)

local PopOverlay = CreateSquare(true, Color3.fromRGB(0,0,0), 0, 20, 0)
local PopBg = CreateSquare(true, Theme.PanelBg, 0, 21, 24)
local PopTitle = CreateText("Popup", 14, true, Theme.Accent, 26)
local PopCloseBtn = CreateSquare(true, Theme.BgBase, 0, 22, 16)
local PopCloseTxt = CreateText("Close", 13, true, Theme.TextMain, 23)

local DropBg = CreateSquare(true, Theme.PanelBg, 0, 15, 16)
local DropItems = {}
for i = 1, 32 do
    local bg = CreateSquare(true, Theme.PanelBg, 0, 16, 12)
    local txt = CreateText("Option", 13, false, Theme.TextMain, 17)
    table.insert(DropItems, {Bg = bg, Txt = txt, Name = "Option", HoverAnim = 0})
end

local PickerPreview = CreateSquare(true, Color3.new(1,1,1), 0, 22, 16)
local R_Bg = CreateSquare(true, Theme.BgBase, 0, 22, 12); local R_Fill = CreateSquare(true, Color3.fromRGB(255,50,50), 0, 23, 12)
local G_Bg = CreateSquare(true, Theme.BgBase, 0, 22, 12); local G_Fill = CreateSquare(true, Color3.fromRGB(50,255,50), 0, 23, 12)
local B_Bg = CreateSquare(true, Theme.BgBase, 0, 22, 12); local B_Fill = CreateSquare(true, Color3.fromRGB(50,50,255), 0, 23, 12)
local P_HexBox = CreateSquare(true, Theme.BgBase, 0, 22, 16); local P_HexTxt = CreateText("#FFFFFF", 13, true, Theme.TextMain, 23)

local SnowPop_TogBg = CreateSquare(true, Theme.AccentOff, 0, 22, 16); local SnowPop_TogKnob = CreateSquare(true, Theme.TextSub, 0, 23, 16); local SnowPop_TogTxt = CreateText("Enabled", 13, false, Theme.TextMain, 25)
local SnowPop_ColBtn = CreateSquare(true, Theme.BgBase, 0, 22, 16); local SnowPop_ColTxt = CreateText("Color:", 13, true, Theme.TextMain, 25)

local function createPopSlid(lbl)
    return {
        Bg = CreateSquare(true, Theme.PanelBg, 0, 22, 16),
        FillBg = CreateSquare(true, Theme.BgBase, 0, 23, 8),
        Fill = CreateSquare(true, Theme.Accent, 0, 24, 8),
        ValBg = CreateSquare(true, Theme.BgBase, 0, 23, 12),
        ValTxt = CreateText("0", 13, true, Theme.TextMain, 25),
        Txt = CreateText(lbl, 13, false, Theme.TextMain, 25)
    }
end

local SnowPop_Size = createPopSlid("Size")
local SnowPop_Speed = createPopSlid("Speed")
local SnowPop_Amt = createPopSlid("Amount")
local SnowPop_Trans = createPopSlid("Transparency")

local LP_Prev = CreateSquare(true, Theme.BgBase, 0, 22, 12); local LP_PrevT = CreateText("<", 13, true, Theme.TextMain, 23)
local LP_Next = CreateSquare(true, Theme.BgBase, 0, 22, 12); local LP_NextT = CreateText(">", 13, true, Theme.TextMain, 23)
local LP_PageT = CreateText("1/1", 13, true, Theme.TextMain, 23)

local DelConfTxt = CreateText("", 13, true, Theme.TextMain, 25)
local DelConf_YesBg = CreateSquare(true, Theme.PanelBg, 0, 22, 16); local DelConf_YesTxt = CreateText("Confirm", 13, true, Theme.TextMain, 25)
local DelConf_NoBg = CreateSquare(true, Theme.PanelBg, 0, 22, 16); local DelConf_NoTxt = CreateText("Cancel", 13, true, Theme.TextMain, 25)

local PerfUI_YesBg = CreateSquare(true, Theme.PanelBg, 0, 22, 16); local PerfUI_YesTxt = CreateText("Confirm", 13, true, Theme.TextMain, 25)
local PerfUI_NoBg = CreateSquare(true, Theme.PanelBg, 0, 22, 16); local PerfUI_NoTxt = CreateText("Cancel", 13, true, Theme.TextMain, 25)

local CL_Texts = {}
for i = 1, 20 do table.insert(CL_Texts, CreateText("", 13, false, Theme.TextMain, 26)) end

local function hideFontPopups()
    for i = 1, 16 do
        if DrawCache["FontPop_"..i.."_Bg"] then DrawCache["FontPop_"..i.."_Bg"].Visible = false end
        if DrawCache["FontPop_"..i.."_Txt"] then DrawCache["FontPop_"..i.."_Txt"].Visible = false end
    end
    if DrawCache["FontPg_Txt"] then DrawCache["FontPg_Txt"].Visible = false end
end

local function hideColorPopups()
    local hdn = {"Color_PrevBg", "Color_PrevCol", "ColorR_Lbl", "ColorR_Bg", "ColorR_Fill", "ColorG_Lbl", "ColorG_Bg", "ColorG_Fill", "ColorB_Lbl", "ColorB_Bg", "ColorB_Fill", "Color_HexBg", "Color_HexTxt", "Color_ApplyBg", "Color_ApplyTxt", "Color_ResetBg", "Color_ResetTxt", "Color_SVOut", "Color_HueOut", "Color_SVDot", "Color_HueDot"}
    for _, n in ipairs(hdn) do if DrawCache[n] then DrawCache[n].Visible = false end end
    for x = 0, 9 do for y = 0, 9 do if DrawCache["Color_Cell_"..x.."_"..y] then DrawCache["Color_Cell_"..x.."_"..y].Visible = false end end end
    for i = 0, 9 do if DrawCache["Color_HueCell_"..i] then DrawCache["Color_HueCell_"..i].Visible = false end end
end

local function hidePopSlid(slid)
    if not slid then return end
    slid.Bg.Visible = false; slid.FillBg.Visible = false; slid.Fill.Visible = false; slid.ValBg.Visible = false; slid.ValTxt.Visible = false; slid.Txt.Visible = false
end

-- =========================================================================
-- TYPING DETECTOR BYPASS (Bypasses Severe Sandbox & Missing CoreGui)
-- =========================================================================
local typingCache = false
local lastTypingCheck = 0
local HeuristicTyping = false
local wasSlashDown = false
local wasReturnDown = false
local wasEscDown = false

local function GetIsTyping()
    local slashDown = false
    local returnDown = false
    local escDown = false
    local leftDown = false
    
    pcall(function() slashDown = UIS:IsKeyDown(Enum.KeyCode.Slash) end)
    pcall(function() returnDown = UIS:IsKeyDown(Enum.KeyCode.Return) or UIS:IsKeyDown(Enum.KeyCode.KeypadEnter) end)
    pcall(function() escDown = UIS:IsKeyDown(Enum.KeyCode.Escape) end)
    pcall(function() if type(isleftpressed) == "function" then leftDown = isleftpressed() end end)
    
    -- Track if they manually open chat with Slash
    if slashDown and not wasSlashDown then HeuristicTyping = true end
    if (returnDown and not wasReturnDown) or (escDown and not wasEscDown) or leftDown then HeuristicTyping = false end
    
    wasSlashDown = slashDown
    wasReturnDown = returnDown
    wasEscDown = escDown

    local now = os.clock()
    if now - lastTypingCheck >= 0.2 then
        lastTypingCheck = now
        typingCache = false
        
        -- 1. Modern Roblox Chat Support
        pcall(function()
            local tcs = game:GetService("TextChatService")
            if tcs and tcs:FindFirstChild("ChatInputBarConfiguration") then
                if tcs.ChatInputBarConfiguration.IsFocused then
                    typingCache = true
                end
            end
        end)
        
        -- 2. Legacy Chat / Custom Menu Support
        if not typingCache then
            pcall(function()
                local lp = game:GetService("Players").LocalPlayer
                if lp and lp:FindFirstChild("PlayerGui") then
                    for _, v in ipairs(lp.PlayerGui:GetDescendants()) do
                        if v.ClassName == "TextBox" and v:IsFocused() then 
                            typingCache = true
                            break
                        end
                    end
                end
            end)
        end
    end
    
    return typingCache or HeuristicTyping
end
-- =========================================================================

local lastUpdate = os.clock()
Connection = RunService.Render:Connect(function()
    local ok, err = pcall(function()
        if not _G.SevereCleanup then Connection:Disconnect() return end
        Camera = workspace.CurrentCamera
        if not Camera then return end

        local now = os.clock()
        local dt = math.min(now - lastUpdate, 0.05)
        lastUpdate = now
        
        local mPos = UIS:GetMouseLocation()
        local lDown = (type(isleftpressed) == "function" and isleftpressed() and (type(isrbxactive) ~= "function" or isrbxactive())) or false 
        GlobalMousePos = mPos

        local UserIsTyping = GetIsTyping()

        State.LightAlpha = ExpLerp(State.LightAlpha or (State.LightMode and 1 or 0), State.LightMode and 1 or 0, dt, 4.5)
        local lA = State.LightAlpha

        for k, _ in pairs(ColorKeys) do
            if not State["Target_"..k] then State["Target_"..k] = State[k] end
            if State[k] ~= State["Target_"..k] then State[k] = LerpColor(State[k], State["Target_"..k], 1 - math.exp(-4.5 * dt)) end
        end

        local dynMain = LerpColor(State.MainCol, Color3.new(0.97, 0.97, 0.97), lA)
        local dynPanel, dynAccentOff
        local dynTextMain, dynTextSub

        do
            local r, g, b = State.MainCol.R, State.MainCol.G, State.MainCol.B
            local v = (r + g + b) / 3
            local isLight = v > 0.5
            local offset1 = isLight and -0.04 or 0.04
            local offset2 = isLight and -0.10 or 0.10

            local darkPanel = Color3.new(math.clamp(r + offset1, 0, 1), math.clamp(g + offset1, 0, 1), math.clamp(b + offset1, 0, 1))
            local darkAccentOff = Color3.new(math.clamp(r + offset2, 0, 1), math.clamp(g + offset2, 0, 1), math.clamp(b + offset2, 0, 1))

            local isDefault = (math.abs(r - Theme.BgBase.R) < 0.01 and math.abs(g - Theme.BgBase.G) < 0.01 and math.abs(b - Theme.BgBase.B) < 0.01)
            local luminance = 0.299 * r + 0.587 * g + 0.114 * b
            local dTM = Theme.TextMain
            local dTS = Theme.TextSub

            if not isDefault then
                if luminance > 0.5 then
                    dTM = Color3.new(0.1, 0.1, 0.1)
                    dTS = Color3.new(0.25, 0.25, 0.25)
                else
                    dTM = Theme.TextMain
                    dTS = Color3.new(0.75, 0.75, 0.75)
                end
            end

            dynPanel = LerpColor(darkPanel, Color3.new(0.91, 0.91, 0.93), lA)
            dynAccentOff = LerpColor(darkAccentOff, Color3.new(0.82, 0.82, 0.86), lA)
            dynTextMain = LerpColor(dTM, Color3.new(0.05, 0.05, 0.07), lA)
            dynTextSub = LerpColor(dTS, Color3.new(0.30, 0.30, 0.35), lA)
        end

        local dynSep = AdaptiveSeparator(dynMain, State.AccentCol, lA)
        for _, sep in ipairs(Separators) do if sep.Bg then sep.Bg.Color = dynSep end end

        local globalScale = safeN(MenuSize.X / minMenuSizeX, 1)
        local currentFont = tonumber(State.UIFont) or 5
        local fontScaleMultiplier = FontScales[currentFont] or 1
        local currentTextScale = safeN(globalScale * (State.IntroAlpha or 0) * fontScaleMultiplier, 1)

        if math.abs((LastTextScale or 0) - currentTextScale) > 0.001 or LastFont ~= currentFont then
            LastTextScale = currentTextScale
            LastFont = currentFont
            for t, baseSize in pairs(TextSizes) do
                pcall(function()
                    t.Size = math.max(1, baseSize * currentTextScale)
                    t.Font = currentFont
                end)
            end
        end

        if not InitialCentered and Camera.ViewportSize.X > 0 then
            MenuPos = Vector2.new(math.floor(Camera.ViewportSize.X/2 - MenuSize.X/2), math.floor(Camera.ViewportSize.Y/2 - MenuSize.Y/2))
            TargetMenuPos = MenuPos
            InitialCentered = true
        end

        local bindPressed = false
        pcall(function()
            if State.Keybind and State.Keybind ~= "" and State.Keybind ~= "None" then
                if UIS:IsKeyDown(Enum.KeyCode[State.Keybind]) then bindPressed = true end
            end
        end)
        if not bindPressed then
            local pressedKeys = type(getpressedkeys) == "function" and getpressedkeys() or {}
            for i = 1, #pressedKeys do
                if pressedKeys[i] == State.Keybind then bindPressed = true; break end
            end
        end

        if bindPressed and not UserIsTyping and not ToggleDebounce and Focused ~= "Keybind" and State.TargetPopup == "None" and not State.TargetDropdown then
            State.Visible = not State.Visible; ToggleDebounce = true
            task.spawn(function() task.wait(0.2) ToggleDebounce = false end)
        end

        State.IntroAlpha = ExpLerp(State.IntroAlpha or 0, State.Visible and 1 or 0, dt, State.Visible and 18 or 24)

        if not State.UIScaleAnim then State.UIScaleAnim = 0.8; State.UIVelocity = 0 end
        if not State.UIYOffset then State.UIYOffset = 0; State.UIYVelocity = 0 end

        local targetScale = State.Visible and 1 or 0.4
        local targetY = State.Visible and 0 or 0
        local stiff = State.Visible and 350 or 500
        local damp = State.Visible and 24 or 40

        State.UIScaleAnim, State.UIVelocity = ApplySpring(State.UIScaleAnim, targetScale, State.UIVelocity, dt, stiff, damp)
        State.UIYOffset, State.UIYVelocity = ApplySpring(State.UIYOffset, targetY, State.UIYVelocity, dt, stiff, damp)

        local prevMenuPos = MenuPos
        MenuPos = Vector2.new(
            MenuPos.X + (TargetMenuPos.X - MenuPos.X) * (1 - math.exp(-28 * dt)),
            MenuPos.Y + (TargetMenuPos.Y - MenuPos.Y) * (1 - math.exp(-28 * dt))
        )
        MenuVelocity = MenuPos - prevMenuPos

        State.TabAlpha = ExpLerp(State.TabAlpha, State.NextTab and 0 or 1, dt, 24)
        if State.NextTab and State.TabAlpha < 0.05 then State.CurrentTab = State.NextTab; State.NextTab = nil end
        State.PopAlpha = ExpLerp(State.PopAlpha or 0, State.TargetPopup ~= "None" and 1 or 0, dt, 14)
        State.DropAlpha = ExpLerp(State.DropAlpha or 0, State.TargetDropdown and 1 or 0, dt, 18)
        if State.TargetPopup ~= "None" then State.ActivePopup = State.TargetPopup end
        if State.TargetDropdown then State.ActiveDropdown = State.TargetDropdown
        elseif (State.DropAlpha or 0) < 0.01 then State.ActiveDropdown = nil end

        for k, _ in pairs(ColorKeys) do
            local target = State["Target_"..k]
            if target then State[k] = LerpColor(State[k] or target, target, dt, 14) end
        end
        State.AccentColAlpha = ExpLerp(State.AccentColAlpha or 1, State.Target_AccentColAlpha or State.AccentColAlpha or 1, dt, 14)
        State.MainColAlpha = ExpLerp(State.MainColAlpha or 1, State.Target_MainColAlpha or State.MainColAlpha or 1, dt, 14)

        if State.Visible and Focused then
            local lastPressed = (type(getpressedkey) == "function" and getpressedkey()) or ""
            if lastPressed ~= "" and lastPressed ~= "None" then
                local isNew = (lastPressed ~= LastKey)
                if isNew then LastKey, RepeatTimer = lastPressed, now + 0.4 end

                local char = ""
                if #lastPressed == 1 then char = lastPressed elseif lastPressed == "Space" then char = " " elseif lastPressed == "Period" then char = "."
                elseif lastPressed == "NumberSign" then char = "#" elseif lastPressed:match("^Number(%d)$") then char = lastPressed:sub(7,7) elseif lastPressed:match("^Keypad(%d)$") then char = lastPressed:sub(7,7) end
                if isNew or now > RepeatTimer then
                    if not isNew then RepeatTimer = now + 0.05 end
                    if lastPressed == "Enter" and isNew then Apply()
                    elseif (Focused == "Keybind" or (Focused and Focused:match("_Key$"))) and isNew then
                        local bindToSet = lastPressed
                        pcall(function()
                        local keys = UIS:GetKeysPressed()
                        for j = 1, #keys do
                            local k = keys[j]
                                local kn = k.KeyCode.Name
                                if kn:match("Shift") or kn:match("Control") or kn:match("Alt") then
                                    bindToSet = kn
                                end
                            end
                        end)
                        local lpLow = bindToSet:lower()
                        if not lpLow:match("mouse") and not lpLow:match("button") and bindToSet ~= "Unknown" then
                            if Focused == "Keybind" then
                                State.Keybind = bindToSet
                            else
                                if bindToSet == "Escape" or bindToSet == "Backspace" then
                                    State[Focused] = "None"
                                else
                                    State[Focused] = bindToSet
                                end
                            end
                            Focused = nil
                        end
                    elseif lastPressed == "Backspace" then InputBuffers[Focused] = string.sub(InputBuffers[Focused], 1, -2)
                    elseif char ~= "" then
                        if Focused == "Red" or Focused == "Green" or Focused == "Blue" or Focused == "Alpha" then if char:match("%d") then InputBuffers[Focused] = InputBuffers[Focused] .. char end else InputBuffers[Focused] = InputBuffers[Focused] .. char end
                    end
                end
            else LastKey = "" end
        end

        local activeKeys = {}
        if type(getpressedkeys) == "function" then
            for _, k in ipairs(getpressedkeys()) do activeKeys[k] = true end
        else
            pcall(function()
                for _, k in ipairs(UIS:GetKeysPressed()) do activeKeys[k.KeyCode.Name] = true end
            end)
        end

        for _, el in ipairs(Elements) do
            if el.HasKeybind and State[el.KeyStateKey] and State[el.KeyStateKey] ~= "None" then
                local k = State[el.KeyStateKey]
                local isPressed = false
                if not UserIsTyping then
                    pcall(function() if UIS:IsKeyDown(Enum.KeyCode[k]) then isPressed = true end end)
                    if not isPressed and activeKeys[k] then isPressed = true end
                end

                if isPressed and not ElementKeyDebounce[el.StateKey] and Focused ~= el.KeyStateKey and Focused ~= "Keybind" then
                    ElementKeyDebounce[el.StateKey] = true
                    if el.Type == "Toggle" then
                        if el.Callback then el:Callback() end
                    elseif el.Type == "Button" then
                        if el.Callback then el.Callback() end
                    end
                elseif not isPressed then
                    ElementKeyDebounce[el.StateKey] = false
                end
            end
        end

        if State.IntroAlpha > 0.001 then
            UIHidden = false

            local currentSize = MenuSize * State.UIScaleAnim
            local bgPos = MenuPos + (MenuSize / 2) - (currentSize / 2) + Vector2.new(0, State.UIYOffset)

            local uiTrans = math.clamp((not State.Transparent and 1 or State.UITrans) * State.IntroAlpha, 0, 1)
            local btnTrans = math.clamp((not State.Transparent and 1 or State.ButtonTrans) * State.IntroAlpha, 0, 1)
            local textAlpha = math.clamp((State.IntroAlpha - 0.15) * 1.176, 0, 1)

            local function sP(pos) return vRound(bgPos + (pos - MenuPos) * State.UIScaleAnim * globalScale) end
            local function sS(size) return vRound(size * State.UIScaleAnim * globalScale) end

            local function CalcPress(rawPos, rawSize, hitCheck, animVar, dt, shrinkFactor)
                local isPressed = hitCheck and lDown
                local newAnim = safeN(ExpLerp(animVar or 0, isPressed and 1 or 0, dt, 28))
                local scale = safeN(1 - ((shrinkFactor or 0.05) * ApplyCurve(newAnim, "EaseOutQuart")), 1)
                local nSize = safeV(rawSize * scale, rawSize)
                local nPos = safeV(rawPos + (rawSize - nSize) / 2, rawPos)
                return nPos, nSize, newAnim, scale
            end

            if not State.HighPerformanceMode then
                local shadowCount = #DropShadows
                local shadowRound = math.max(4, math.round(15 * globalScale))
                for i, shadow in ipairs(DropShadows) do
                    shadow.Visible = true
                    local spread = i * 1.5
                    shadow.Size = currentSize + sS(Vector2.new(spread * 2, spread * 2))
                    shadow.Position = bgPos - sS(Vector2.new(spread, spread)) + sS(Vector2.new(0, 3))
                    local layerAlpha = 0.08 * (1 - (i / shadowCount))
                    shadow.Transparency = layerAlpha * uiTrans
                    shadow.Rounding = shadowRound + math.floor(spread / 2)
                end
            else
                for _, shadow in ipairs(DropShadows) do shadow.Visible = false end
            end

            local shadowRound = math.max(4, math.round(15 * globalScale))
            BaseBg.Visible = true; TopBar.Visible = false
            BaseBg.Position, BaseBg.Size = bgPos, currentSize; BaseBg.Transparency = uiTrans; BaseBg.Color = dynMain; BaseBg.Rounding = shadowRound

            TopBar.Position, TopBar.Size = bgPos, vRound(Vector2.new(currentSize.X, 30 * State.IntroAlpha * globalScale))
            TopBar.Transparency = uiTrans; TopBar.Color = dynMain; TopBar.Rounding = shadowRound

            if State.LightRippleActive then
                State.LightRippleAnim = State.LightRippleAnim + (dt * 1.2)
                local rCurve = ApplyCurve(math.clamp(State.LightRippleAnim, 0, 1), "EaseOutQuart")
                local rippleRadius = rCurve * (MenuSize.X * 1.6)

                if rCurve < 1 then
                    if type(DrawingImmediate) ~= "nil" and type(DrawingImmediate.FilledCircle) == "function" then
                        DrawingImmediate.FilledCircle(State.LightRippleOrigin, rippleRadius, dynMain, State.IntroAlpha * uiTrans)
                    end
                else
                    State.LightRippleActive = false
                end
            end

            MainTitle.Visible = true
            MainTitle.Position = sP(Vector2.new(MenuPos.X + 15, MenuPos.Y + 6))
            MainTitle.Transparency = textAlpha
            MainTitle.Color = State.AccentCol

            V2Text.Visible = true
            V2Text.Position = sP(Vector2.new(MenuPos.X + minMenuSizeX - 15, MenuPos.Y + 8))
            V2Text.Transparency = textAlpha
            V2Text.Color = dynTextSub
            V2TextShadow.Visible = true
            V2TextShadow.Position = V2Text.Position + Vector2.new(1, 1)
            V2TextShadow.Transparency = textAlpha * 0.5

            if type(DrawingImmediate) ~= "nil" and type(DrawingImmediate.Line) == "function" then
                local br = bgPos + currentSize - sS(Vector2.new(10, 10))
                DrawingImmediate.Line(br, br - sS(Vector2.new(12, 0)), State.AccentCol, uiTrans, 2)
                DrawingImmediate.Line(br, br - sS(Vector2.new(0, 12)), State.AccentCol, uiTrans, 2)
                local br2 = br - sS(Vector2.new(4, 4))
                DrawingImmediate.Line(br2, br2 - sS(Vector2.new(6, 0)), State.AccentCol, uiTrans, 2)
                DrawingImmediate.Line(br2, br2 - sS(Vector2.new(0, 6)), State.AccentCol, uiTrans, 2)
            end

            if State.Snowfall and not State.HighPerformanceMode then
                for _, sf in ipairs(Snowflakes) do
                    sf.Y = sf.Y + (State.SnowSpeed * sf.SpeedMult * dt); sf.X = sf.X + math.sin(now + sf.Sine) * dt * 10
                    if sf.Y > 100 then sf.Y = 0; sf.X = math.random(0, 100) end
                    local drawX = bgPos.X + (sf.X / 100 * currentSize.X)
                    local drawY = bgPos.Y + (sf.Y / 100 * currentSize.Y)

                    local inPopup = false
                    if State.PopAlpha > 0.01 and State.ActivePopup ~= "None" then
                        local pW = 240
                        local pH = 255
                        if CustomPopups[State.ActivePopup] then
                            pW = CustomPopups[State.ActivePopup].X
                            pH = CustomPopups[State.ActivePopup].Y
                        elseif State.ActivePopup == "Color" then pH = 210
                        elseif State.ActivePopup == "Snowfall" then pH = 350
                        elseif State.ActivePopup == "PerfUI" then pH = 180; pW = 280
                        elseif State.ActivePopup == "UIFont" then pH = 350; pW = 320
                        end

                        local morphAlpha = ApplyCurve(State.PopAlpha, "EaseOutQuart")
                        local finalPopPos = Vector2.new(MenuPos.X + (minMenuSizeX/2) - (pW/2), MenuPos.Y + (minMenuSizeY/2) - (pH/2))

                        local popPos = sP(Lerp2(State.LastClickedPos, finalPopPos, morphAlpha))
                        local popSize = sS(Lerp2(State.LastClickedSize, Vector2.new(pW, pH), morphAlpha))

                        if drawX >= popPos.X and drawX <= popPos.X + popSize.X and drawY >= popPos.Y and drawY <= popPos.Y + popSize.Y then
                            inPopup = true
                        end
                    end

                    if not inPopup and drawY > bgPos.Y + 30 * State.IntroAlpha * globalScale and drawY < bgPos.Y + currentSize.Y - 2 and drawX > bgPos.X + 2 and drawX < bgPos.X + currentSize.X - 2 then
                        if type(DrawingImmediate) ~= "nil" and type(DrawingImmediate.FilledRectangle) == "function" then
                            local finalSnowCol = LerpColor(State.SnowCol, Color3.new(0, 0, 0), State.LightAlpha)
                            DrawingImmediate.FilledRectangle(Vector2.new(drawX, drawY), sS(Vector2.new(State.SnowSize, State.SnowSize)), finalSnowCol, uiTrans * State.SnowTrans)
                        end
                    end
                end
            end

            local totalTabWidth = 0
            for i, tab in ipairs(TabDrawings) do
                local w = 70
                totalTabWidth = totalTabWidth + w + (i < #TabDrawings and 5 or 0)
            end
            
            local tabX
            if State.TabAlignment == "Left" then
                tabX = MenuPos.X + 15
            elseif State.TabAlignment == "Right" then
                tabX = MenuPos.X + minMenuSizeX - totalTabWidth - 15
            else
                tabX = MenuPos.X + (minMenuSizeX - totalTabWidth) / 2
            end

            for _, tab in ipairs(TabDrawings) do
                tab.Box.Visible = true; tab.Txt.Visible = true

                local origPos = Vector2.new(tabX, MenuPos.Y + 40)
                local origSize = Vector2.new(70, 20)

                local rawPos, rawSize = sP(origPos), sS(origSize)
                local isActive = (State.CurrentTab == tab.Name)
                local isHovered = hitBox(mPos, rawPos, rawSize) and State.TargetPopup == "None" and not State.TargetDropdown

                local dPos, dSize, pAnim, pScale = CalcPress(rawPos, rawSize, isHovered, tab.PressAnim, dt, 0.06)
                tab.PressAnim = pAnim

                tab.Box.Size = dSize; tab.Box.Position = dPos
                tab.Box.Transparency = btnTrans
                tab.Anim = ExpLerp(tab.Anim, (isActive or isHovered) and 1 or 0, dt, 18)

                tab.Box.Color = LerpColor(dynMain, State.AccentCol, 0.15 * ApplyCurve(tab.Anim, "EaseOutQuart"))
                tab.Txt.Position = dPos + Vector2.new(dSize.X/2, dSize.Y/2 - 6.5 * currentTextScale)
                SafeSize(tab.Txt, 13 * currentTextScale * pScale)
                tab.Txt.Transparency = textAlpha; tab.Txt.Center = true
                tab.Txt.Color = LerpColor(dynTextSub, State.AccentCol, isActive and 1 or (isHovered and 0.5 or 0))
                tabX = tabX + origSize.X + 5

                if lDown and not Interaction.Active and isHovered then SwitchTab(tab.Name) end
            end

            local pW = 240
            local pH = 255
            if CustomPopups[State.ActivePopup] then
                pW = CustomPopups[State.ActivePopup].X
                pH = CustomPopups[State.ActivePopup].Y
            elseif State.ActivePopup == "Color" then pH = 205; pW = 320
            elseif State.ActivePopup == "Snowfall" then pH = 350; pW = 280
            elseif State.ActivePopup == "DeleteConfirm" then pH = 135; pW = 280
            elseif State.ActivePopup == "PerfUI" then pH = 180; pW = 340
            elseif State.ActivePopup == "UIFont" then pH = 350; pW = 320
            end

            local morphAlpha = ApplyCurve(State.PopAlpha, "EaseOutQuart")
            local finalPopPos = Vector2.new(MenuPos.X + (minMenuSizeX/2) - (pW/2), MenuPos.Y + (minMenuSizeY/2) - (pH/2))
            local popPos = sP(Lerp2(State.LastClickedPos, finalPopPos, morphAlpha))
            local popSize = sS(Lerp2(State.LastClickedSize, Vector2.new(pW, pH), morphAlpha))

            local function popP(x, y)
                local pX = (pW and pW > 0 and x) and (x / pW) or 0
                local pY = (pH and pH > 0 and y) and (y / pH) or 0
                return vRound(popPos + Vector2.new(pX * popSize.X, pY * popSize.Y))
            end
            local function popS(w, h)
                local pW_val = (pW and pW > 0 and w) and (w / pW) or 0
                local pH_val = (pH and pH > 0 and h) and (h / pH) or 0
                return vRound(Vector2.new(pW_val * popSize.X, pH_val * popSize.Y))
            end

            local startX = MenuPos.X + 15; local startY = MenuPos.Y + 70
            local eY = { [1] = { startY, startY } }
            local colW = (minMenuSizeX - 45) / 2
            
            local pStartX = 15; local pStartY = 45
            local pColW = pW - 30
            local pEY = { [1] = { pStartY, pStartY } }

            for _, el in ipairs(Elements) do
                local p = el.Page or 1
                local isVis = false
                local elFade = 1
                local pageFade = 1
                local origPos = Vector2.new(0,0)
                local currentWidth = 100
                local isPop = false

                if el.Tab and el.Tab == State.CurrentTab then
                    isVis = true
                    if not eY[p] then eY[p] = { startY, startY } end
                    local cY = eY[p][el.Col]
                    local cX = (el.Col == 1) and startX or (startX + colW + 15)
                    currentWidth = colW
                    local baseCX = cX
                    
                    if el.CustomWidth then
                        currentWidth = math.floor(colW * el.CustomWidth)
                        if el.CustomOffset then baseCX = cX + math.floor(colW * el.CustomOffset) end
                    elseif el.Half == "Left" then
                        currentWidth = math.floor((colW / 2) - 2.5)
                    elseif el.Half == "Right" then
                        currentWidth = math.floor((colW / 2) - 2.5)
                        baseCX = cX + math.floor((colW / 2) + 2.5)
                    end
                    
                    origPos = Vector2.new(baseCX, cY)
                    el.UnscaledPos = origPos 
                    
                    if not el.SameRow then
                        local h = 0
                        if el.Type == "Toggle" then h = 36 elseif el.Type == "Slider" then h = 46 elseif el.Type == "Button" or el.Type == "Dropdown" then h = 31 elseif el.Type == "Label" or el.Type == "TextLabel" then h = 18 elseif el.Type == "Separator" then h = 14 elseif el.Type == "Spacer" then h = el.Height or 10 end
                        eY[p][el.Col] = eY[p][el.Col] + h
                    end
                    
                elseif el.Popup and el.Popup == State.ActivePopup and State.PopAlpha > 0.01 then
                    isVis = true
                    isPop = true
                    elFade = math.clamp((State.PopAlpha - 0.2) * 1.25, 0, 1) 
                    if not pEY[p] then pEY[p] = { pStartY, pStartY } end
                    local cY = pEY[p][el.Col]
                    local cX = pStartX
                    currentWidth = pColW
                    local baseCX = cX
                    
                    if el.CustomWidth then
                        currentWidth = math.floor(pColW * el.CustomWidth)
                        if el.CustomOffset then baseCX = cX + math.floor(pColW * el.CustomOffset) end
                    elseif el.Half == "Left" then
                        currentWidth = math.floor((pColW / 2) - 2.5)
                    elseif el.Half == "Right" then
                        currentWidth = math.floor((pColW / 2) - 2.5)
                        baseCX = cX + math.floor((pColW / 2) + 2.5)
                    end
                    
                    local localPos = Vector2.new(baseCX, cY)
                    el.UnscaledPos = localPos 
                    origPos = localPos 
                    
                    if not el.SameRow then
                        local h = 0
                        if el.Type == "Toggle" then h = 36 elseif el.Type == "Slider" then h = 46 elseif el.Type == "Button" or el.Type == "Dropdown" then h = 31 elseif el.Type == "Label" or el.Type == "TextLabel" then h = 18 elseif el.Type == "Separator" then h = 14 elseif el.Type == "Spacer" then h = el.Height or 10 end
                        pEY[p][el.Col] = pEY[p][el.Col] + h
                    end
                end

                if not isVis then
                    if el.Bg then el.Bg.Visible = false end
                    if el.Txt then el.Txt.Visible = false end
                    if el.Type == "Toggle" then el.TogBg.Visible = false; el.TogKnob.Visible = false;
                    elseif el.Type == "Slider" then el.FillBg.Visible = false; el.Fill.Visible = false; el.ValBg.Visible = false; el.ValTxt.Visible = false
                    elseif el.Type == "Dropdown" then el.Icon.Visible = false
                    elseif el.Type == "Separator" then el.Bg.Visible = false end
                    if el.HasKeybind then el.KeyBg.Visible = false; el.KeyTxt.Visible = false end
                else
                    if el.Type == "Toggle" then el.UnscaledSize = Vector2.new(currentWidth, 30)
                    elseif el.Type == "Slider" then el.UnscaledSize = Vector2.new(currentWidth, 40)
                    elseif el.Type == "Button" or el.Type == "Dropdown" then el.UnscaledSize = Vector2.new(currentWidth, 25) 
                    elseif el.Type == "Label" or el.Type == "TextLabel" then el.UnscaledSize = Vector2.new(currentWidth, 18)
                    elseif el.Type == "Separator" then el.UnscaledSize = Vector2.new(currentWidth, 1)
                    elseif el.Type == "Spacer" then el.UnscaledSize = Vector2.new(currentWidth, el.Height or 10)
                    end

                    local rawPos, rawSize
                    local sScaleMult = 1
                    if isPop then
                        rawPos = popP(origPos.X, origPos.Y)
                        rawSize = popS(el.UnscaledSize.X, el.UnscaledSize.Y)
                        sScaleMult = morphAlpha 
                    else
                        rawPos = sP(origPos)
                        rawSize = sS(el.UnscaledSize)
                    end

                    local isTransSlider = (el.StateKey == "UITrans" or el.StateKey == "ButtonTrans")
                    local isElDisabled = (State.HighPerformanceMode and (el.BaseText == "Snowfall Settings" or isTransSlider or el.StateKey == "Transparent" or el.StateKey == "AnimationsEnabled")) or (not State.Transparent and isTransSlider)
                    el.DisabledAnim = ExpLerp(el.DisabledAnim or 0, isElDisabled and 1 or 0, dt, 12)

                    local isInteractable = (el.Type == "Toggle" or el.Type == "Slider" or el.Type == "Button" or el.Type == "Dropdown")
                    local hovered = isInteractable and hitBox(mPos, rawPos, rawSize) and (State.TargetPopup == "None" or State.TargetPopup == el.Popup) and not State.TargetDropdown and not isElDisabled
                    local dPos, dSize, pAnim, pScale = CalcPress(rawPos, rawSize, hovered, el.PressAnim, dt, 0.04)
                    el.PressAnim = pAnim

                    local function getScale(v) return isPop and popS(v.X, v.Y) or sS(v) end

                    if el.Bg then el.Bg.Visible = true; el.Bg.Transparency = State.TabAlpha * btnTrans * elFade * pageFade; el.Bg.Size = dSize; el.Bg.Position = dPos; el.Bg.ZIndex = isPop and 24 or 5 end
                    if el.Txt then el.Txt.Visible = true; el.Txt.Transparency = State.TabAlpha * textAlpha * elFade * pageFade; pcall(function() el.Txt.Size = math.max(1, safeN(13 * currentTextScale * pScale * sScaleMult)) end); el.Txt.ZIndex = isPop and 25 or 6 end

                    if el.HasKeybind then
                        el.KeyBg.Visible = true; el.KeyTxt.Visible = true
                        el.KeyBg.ZIndex = isPop and 25 or 6
                        el.KeyTxt.ZIndex = isPop and 26 or 7

                        local keyW = getScale(Vector2.new(40 * pScale, 0)).X
                        local keyH = getScale(Vector2.new(0, 18 * pScale)).Y
                        
                        local xOffset = 44 * pScale + 45 * pScale
                        if el.Type == "Button" then xOffset = 45 * pScale end
                        
                        local keyX = dPos.X + dSize.X - getScale(Vector2.new(xOffset, 0)).X
                        local keyY = dPos.Y + (dSize.Y - keyH)/2
                        
                        el.KeyBg.Size = Vector2.new(keyW, keyH)
                        el.KeyBg.Position = Vector2.new(keyX, keyY)
                        el.KeyBg.Transparency = State.TabAlpha * btnTrans * elFade * pageFade
                        
                        local actTxt = State[el.KeyStateKey] or "None"
                        local displayTxt = (Focused == el.KeyStateKey) and "[...]" or ("[" .. actTxt .. "]")
                        if displayTxt == "[None]" then displayTxt = "[ - ]" end
                        
                        el.KeyTxt.Text = displayTxt
                        pcall(function() el.KeyTxt.Size = math.max(1, safeN(13 * currentTextScale * pScale * sScaleMult)) end)
                        el.KeyTxt.Position = el.KeyBg.Position + Vector2.new(keyW/2, keyH/2 - 6.5 * currentTextScale * sScaleMult)
                        el.KeyTxt.Transparency = State.TabAlpha * textAlpha * elFade * pageFade
                        el.KeyTxt.Color = (Focused == el.KeyStateKey) and State.AccentCol or LerpColor(dynTextSub, dynMain, el.DisabledAnim)
                        
                        local kHov = hitBox(mPos, el.KeyBg.Position, el.KeyBg.Size) and not isElDisabled and (State.TargetPopup == "None" or State.TargetPopup == el.Popup) and not State.TargetDropdown
                        el.KeyBg.Color = kHov and LerpColor(dynPanel, State.AccentCol, 0.3) or dynMain
                    end

                    if el.Type == "Toggle" then
                        el.TogBg.Visible = true; el.TogKnob.Visible = true
                        el.TogBg.ZIndex = isPop and 25 or 6
                        el.TogKnob.ZIndex = isPop and 26 or 7
                        el.Anim = ExpLerp(el.Anim, State[el.StateKey] and 1 or 0, dt, 8)
                        el.SubAnim = ExpLerp(el.SubAnim or 0, 0, dt, 16)

                        el.Txt.Center = false; el.Txt.Position = dPos + getScale(Vector2.new(12 * pScale, 0)) + Vector2.new(0, dSize.Y/2 - 6.5 * currentTextScale * sScaleMult)

                        el.HoverAnim = ExpLerp(el.HoverAnim, hovered and 1 or 0, dt, 16)
                        el.Bg.Color = LerpColor(LerpColor(dynPanel, State.AccentCol, 0.15 * ApplyCurve(el.HoverAnim, "EaseOutQuart")), dynMain, el.DisabledAnim)

                        local tW, tH = 36 * pScale * globalScale, 18 * pScale * globalScale
                        el.TogBg.Size = getScale(Vector2.new(tW, tH))
                        el.TogBg.Position = dPos + Vector2.new(dSize.X - getScale(Vector2.new(44 * pScale, 0)).X, (dSize.Y - el.TogBg.Size.Y)/2)
                        el.TogBg.Transparency = State.TabAlpha * btnTrans * elFade * pageFade
                        el.TogBg.Color = LerpColor(LerpColor(dynAccentOff, LightenColor(State.AccentCol, 0.25 * ApplyCurve(el.HoverAnim, "EaseOutQuart")), el.Anim), dynMain, el.DisabledAnim)

                        local kS = 14 * pScale
                        el.TogKnob.Size = getScale(Vector2.new(kS, kS))
                        el.TogKnob.Transparency = State.TabAlpha * textAlpha * elFade * pageFade
                        local kX = Lerp(el.TogBg.Position.X + getScale(Vector2.new(2 * pScale, 0)).X, el.TogBg.Position.X + el.TogBg.Size.X - el.TogKnob.Size.X - getScale(Vector2.new(2 * pScale, 0)).X, ApplyCurve(el.Anim, "EaseOutQuart"))
                        el.TogKnob.Position = Vector2.new(kX, el.TogBg.Position.Y + getScale(Vector2.new(0, 2 * pScale)).Y)
                        el.TogKnob.Color = LerpColor(LerpColor(dynTextSub, dynMain, el.Anim), Color3.fromRGB(90, 90, 95), el.DisabledAnim)
                        el.Txt.Color = LerpColor(dynTextMain, Color3.fromRGB(90, 90, 95), el.DisabledAnim)

                    elseif el.Type == "Slider" then
                        el.FillBg.Visible = true; el.Fill.Visible = true; el.ValBg.Visible = true; el.ValTxt.Visible = true
                        el.FillBg.ZIndex = isPop and 25 or 6
                        el.Fill.ZIndex = isPop and 26 or 7
                        el.ValBg.ZIndex = isPop and 25 or 6
                        el.ValTxt.ZIndex = isPop and 26 or 7
                        el.Txt.Position = dPos + getScale(Vector2.new(12 * pScale, 5 * pScale))

                        el.FillBg.Size = getScale(Vector2.new(currentWidth - 65, 4) * pScale)
                        el.FillBg.Position = dPos + getScale(Vector2.new(12 * pScale, 28 * pScale))
                        el.FillBg.Transparency = State.TabAlpha * textAlpha * elFade * pageFade
                        el.Anim = ExpLerp(el.Anim, math.clamp((State[el.StateKey] - el.Min) / math.max(0.1, el.Max - el.Min), 0, 1), dt, 18)

                        el.Bg.Color = LerpColor(dynPanel, dynMain, el.DisabledAnim)
                        el.FillBg.Color = dynMain

                        local vRPos, vRSize
                        if isPop then
                            vRPos = popP(origPos.X + currentWidth - 45, origPos.Y + 17)
                            vRSize = popS(35, 18)
                        else
                            vRPos, vRSize = sP(origPos + Vector2.new(currentWidth - 45, 17)), sS(Vector2.new(35, 18))
                        end
                        local valHov = hitBox(mPos, vRPos, vRSize) and (State.TargetPopup == "None" or State.TargetPopup == el.Popup) and not State.TargetDropdown and not isElDisabled
                        local vdPos, vdSize, vpAnim, vpScale = CalcPress(vRPos, vRSize, valHov, el.ValPressAnim, dt, 0.06)
                        el.ValPressAnim = vpAnim

                        el.HoverAnim = ExpLerp(el.HoverAnim, valHov and 1 or 0, dt, 16)
                        el.Fill.Color = LerpColor(LightenColor(State.AccentCol, 0.25 * ApplyCurve(el.HoverAnim, "EaseOutQuart")), Color3.fromRGB(90, 90, 95), el.DisabledAnim)
                        el.Fill.Size = Vector2.new(math.max(1, el.FillBg.Size.X * ApplyCurve(el.Anim, "EaseOutQuart")), el.FillBg.Size.Y)
                        el.Fill.Position = el.FillBg.Position; el.Fill.Transparency = State.TabAlpha * textAlpha * elFade * pageFade

                        el.ValBg.Size = vdSize
                        el.ValBg.Position = dPos + Vector2.new(dSize.X - getScale(Vector2.new(45 * pScale, 0)).X + (vRSize.X - vdSize.X)/2, getScale(Vector2.new(0, 17 * pScale)).Y + (vRSize.Y - vdSize.Y)/2)
                        el.ValBg.Transparency = State.TabAlpha * btnTrans * elFade * pageFade
                        el.ValBg.Color = LerpColor(LerpColor(dynMain, State.AccentCol, 0.15 * ApplyCurve(el.HoverAnim, "EaseOutQuart")), dynMain, el.DisabledAnim)

                        local activeTxt = (Focused == el.InputKey) and InputBuffers[el.InputKey] .. "|" or tostring(State[el.StateKey])
                        if not Focused and el.IsFloat then activeTxt = string.format("%.2f", State[el.StateKey]) end

                        el.Txt.Color = LerpColor(dynTextMain, Color3.fromRGB(90, 90, 95), el.DisabledAnim)
                        el.ValTxt.Color = LerpColor(dynTextMain, Color3.fromRGB(90, 90, 95), el.DisabledAnim)
                        el.ValTxt.Text = activeTxt; pcall(function() el.ValTxt.Size = math.ceil(math.max(1, safeN(13 * currentTextScale * vpScale * sScaleMult))) end)
                        el.ValTxt.Position = el.ValBg.Position + Vector2.new(vdSize.X/2, vdSize.Y/2 - 6.5 * currentTextScale * vpScale * sScaleMult)
                        el.ValTxt.Center = true; el.ValTxt.Transparency = State.TabAlpha * textAlpha * elFade * pageFade

                    elseif el.Type == "Button" then
                        if el.Align == "Left" then el.Txt.Center = false; el.Txt.Position = dPos + getScale(Vector2.new(12 * pScale, 0)) + Vector2.new(0, dSize.Y/2 - 6.5 * currentTextScale * sScaleMult)
                        else el.Txt.Center = true; el.Txt.Position = dPos + Vector2.new(dSize.X/2, dSize.Y/2 - 6.5 * currentTextScale * sScaleMult) end

                        el.HoverAnim = ExpLerp(el.HoverAnim, hovered and 1 or 0, dt, 16)
                        local baseBgColor
                        if el.IsInput then
                            local activeTxt = ""
                            if el.InputKey == "Keybind" then activeTxt = (Focused == "Keybind") and "Press Any..." or "Keybind: " .. tostring(State.Keybind)
                            else activeTxt = (Focused == el.InputKey) and InputBuffers[el.InputKey] .. "|" or InputBuffers[el.InputKey]; if InputBuffers[el.InputKey] == "" and Focused ~= el.InputKey then activeTxt = el.BaseText or "Type..." end end
                            el.Txt.Text = activeTxt; baseBgColor = (Focused == el.InputKey) and dynAccentOff or LerpColor(dynPanel, State.AccentCol, 0.25 * ApplyCurve(el.HoverAnim, "EaseOutQuart"))
                        else baseBgColor = LerpColor(dynPanel, State.AccentCol, 0.25 * ApplyCurve(el.HoverAnim, "EaseOutQuart")) end

                        el.Bg.Color = LerpColor(baseBgColor, dynMain, el.DisabledAnim)
                        el.Txt.Color = LerpColor(dynTextMain, Color3.fromRGB(90, 90, 95), el.DisabledAnim)

                    elseif el.Type == "Dropdown" then
                        el.Icon.Visible = true; el.Icon.Transparency = State.TabAlpha * textAlpha * elFade * pageFade
                        el.Icon.ZIndex = isPop and 25 or 6
                        el.HoverAnim = ExpLerp(el.HoverAnim, hovered and 1 or 0, dt, 16)
                        el.Bg.Color = LerpColor(dynPanel, State.AccentCol, 0.15 * ApplyCurve(el.HoverAnim, "EaseOutQuart"))
                        
                        el.Txt.Position = dPos + getScale(Vector2.new(12 * pScale, 0)) + Vector2.new(0, dSize.Y/2 - 6.5 * currentTextScale * sScaleMult)
                        el.Txt.Text = el.BaseText .. ": " .. State[el.StateKey]
                        el.Txt.Color = LerpColor(dynTextMain, Color3.fromRGB(90, 90, 95), el.DisabledAnim)
                        
                        el.Icon.Position = dPos + Vector2.new(dSize.X - getScale(Vector2.new(15 * pScale, 0)).X, dSize.Y/2 - 6.5 * currentTextScale * sScaleMult)
                        pcall(function() el.Icon.Size = math.max(1, safeN(13 * currentTextScale * pScale * sScaleMult)) end); el.Icon.Color = LerpColor(dynTextSub, Color3.fromRGB(90, 90, 95), el.DisabledAnim)

                        el.DropAnim = ExpLerp(el.DropAnim or 0, (State.TargetDropdown == el) and 1 or 0, dt, (#el.Options < 4) and 14 or 18)
                        if ApplyCurve(el.DropAnim, "EaseOutQuart") > 0.005 then State.ActiveDropdown = el end
                        
                    elseif el.Type == "Label" or el.Type == "TextLabel" then
                        el.Bg.Visible = false
                        el.Txt.Position = isPop and popP(origPos.X + 5, origPos.Y + 1) or sP(origPos + Vector2.new(5, 1))
                        el.Txt.Color = (el.Type == "Label") and State.AccentCol or dynTextSub
                    elseif el.Type == "Separator" then
                        el.Bg.Visible = true; el.Bg.Transparency = State.TabAlpha * textAlpha * elFade * pageFade
                        el.Bg.Size = isPop and popS(currentWidth - 10, 1) or sS(Vector2.new(currentWidth - 10, 1))
                        el.Bg.Position = isPop and popP(origPos.X + 5, origPos.Y + 4) or sP(origPos + Vector2.new(5, 4))
                    end
                end
            end
            
        if State.DropAlpha > 0.01 and State.ActiveDropdown then
            local el = State.ActiveDropdown
            local isPop = (el.Popup ~= nil)
            local zBase = isPop and 30 or 15
            
            local dW = el.Bg.Size.X
            local itemHeight = 22 * globalScale
            local targetH = #el.Options * itemHeight + 4 * globalScale
            local dH = math.floor(Lerp(0, targetH, State.DropAlpha))
            
            DropBg.Visible = true
            DropBg.ZIndex = zBase
            DropBg.Size = Vector2.new(dW, dH * (State.IntroAlpha or 1))
            DropBg.Transparency = State.DropAlpha * (State.UITrans or 1)
            DropBg.Position = el.Bg.Position + Vector2.new(0, el.Bg.Size.Y + 2 * globalScale * (State.IntroAlpha or 1))
            DropBg.Color = dynPanel
            
            for i = 1, 32 do
                local dItem = DropItems[i]
                if el.Options[i] and (2 * globalScale + (i-1) * itemHeight) < dH - 5 * globalScale then
                    dItem.Name = el.Options[i]
                    local itemPos = DropBg.Position + Vector2.new(2 * globalScale * (State.IntroAlpha or 1), (2 * globalScale + (i-1) * itemHeight) * (State.IntroAlpha or 1))
                    local itemSize = Vector2.new(dW - 4 * globalScale * (State.IntroAlpha or 1), 20 * globalScale * (State.IntroAlpha or 1))
                    
                    local hov = hitBox(GlobalMousePos or UIS:GetMouseLocation(), itemPos, itemSize) and State.TargetDropdown == el
                    dItem.HoverAnim = ExpLerp(dItem.HoverAnim or 0, hov and 1 or 0, dt, 18)
                    
                    dItem.Bg.Visible = true
                    dItem.Bg.ZIndex = zBase + 1
                    dItem.Bg.Size = itemSize
                    dItem.Bg.Position = itemPos
                    dItem.Bg.Transparency = State.DropAlpha * (State.ButtonTrans or 1)
                    dItem.Bg.Color = dynPanel:Lerp(dynAccentOff, dItem.HoverAnim)
                    
                    dItem.Txt.Visible = true
                    dItem.Txt.ZIndex = zBase + 2
                    dItem.Txt.Position = dItem.Bg.Position + Vector2.new(10 * globalScale * (State.IntroAlpha or 1), 3 * globalScale * (State.IntroAlpha or 1))
                    dItem.Txt.Text = el.Options[i]
                    dItem.Txt.Transparency = State.DropAlpha * (State.IntroAlpha or 1)
                    dItem.Txt.Color = (tostring(el.Options[i]) == tostring(State[el.StateKey])) and State.AccentCol or dynTextMain
                    SafeSize(dItem.Txt, 13 * currentTextScale)
                else
                    if dItem then dItem.Bg.Visible = false; dItem.Txt.Visible = false end
                end
            end
        else
            if DropBg then DropBg.Visible = false end
            for _, d in ipairs(DropItems) do if d then d.Bg.Visible = false; d.Txt.Visible = false end end
        end

            local function GetDrawing(name, type, props)
                if not DrawCache[name] then
                    DrawCache[name] = Drawing.new(type)
                    if props then for k, v in pairs(props) do DrawCache[name][k] = v end end
                end
                return DrawCache[name]
            end

            if State.ActivePopup ~= "None" then
                if State.ActivePopup ~= "UIFont" then hideFontPopups() end
                if State.ActivePopup ~= "Color" then hideColorPopups() end

                local popAlpha = morphAlpha * State.IntroAlpha
                local popTextAlpha = math.clamp((State.PopAlpha - 0.2) * 1.25, 0, 1) * textAlpha
                PopOverlay.Visible, PopOverlay.Position, PopOverlay.Size, PopOverlay.Transparency = true, bgPos, currentSize, State.PopAlpha * 0.4 * State.IntroAlpha
                PopOverlay.Rounding = shadowRound; PopOverlay.ZIndex = 20
                PopBg.Visible, PopBg.Position, PopBg.Size, PopBg.Transparency = true, popPos, popSize, popAlpha; PopBg.Color = dynMain; PopBg.ZIndex = 21
                PopCloseBtn.ZIndex = 22
                PopCloseTxt.ZIndex = 23

                local isContentVisible = (popTextAlpha > 0.01)
                PopTitle.Visible = isContentVisible
                if isContentVisible then
                    PopTitle.Position = popP(pW/2, 16)
                    PopTitle.Transparency = popTextAlpha
                    PopTitle.Color = State.AccentCol
                    PopTitle.Font = (State.ActivePopup == "UIFont") and 5 or (tonumber(State.UIFont) or 5)
                    PopTitle.ZIndex = 26
                    pcall(function() PopTitle.Size = math.ceil(math.max(1, safeN(14 * currentTextScale * morphAlpha))) end)
                end

                PopCloseBtn.Visible, PopCloseTxt.Visible = false, false
                if CL_Texts then for _, t in ipairs(CL_Texts) do t.Visible = false end end
                SnowPop_TogBg.Visible, SnowPop_TogKnob.Visible, SnowPop_TogTxt.Visible, SnowPop_ColBtn.Visible, SnowPop_ColTxt.Visible = false, false, false, false, false
                hidePopSlid(SnowPop_Size); hidePopSlid(SnowPop_Speed); hidePopSlid(SnowPop_Amt); hidePopSlid(SnowPop_Trans)
                PickerPreview.Visible, R_Bg.Visible, R_Fill.Visible, G_Bg.Visible, G_Fill.Visible, B_Bg.Visible, B_Fill.Visible, P_HexBox.Visible, P_HexTxt.Visible = false, false, false, false, false, false, false, false, false
                LP_Prev.Visible, LP_PrevT.Visible, LP_Next.Visible, LP_NextT.Visible, LP_PageT.Visible = false, false, false, false, false
                DelConfTxt.Visible = false; DelConf_YesBg.Visible = false; DelConf_YesTxt.Visible = false; DelConf_NoBg.Visible = false; DelConf_NoTxt.Visible = false
                PerfUI_YesBg.Visible = false; PerfUI_YesTxt.Visible = false; PerfUI_NoBg.Visible = false; PerfUI_NoTxt.Visible = false

                if CustomPopups[State.ActivePopup] then
                    PopTitle.Text = State.ActivePopup
                elseif State.ActivePopup == "Snowfall" then
                    PopTitle.Text = "Snowfall Config"
                    local sY = 48
                    if isContentVisible then
                        local hovTog = hitBox(mPos, popP(pW - 55, sY + 2), popS(40, 20)) and State.TargetPopup == "Snowfall"
                        SnowPopAnim.Tog = ExpLerp(SnowPopAnim.Tog or 0, State.Snowfall and 1 or 0, dt, 16)

                        SnowPop_TogBg.Visible, SnowPop_TogBg.Position, SnowPop_TogBg.Size, SnowPop_TogBg.Transparency = true, popP(pW - 55, sY + 2), popS(40, 20), popTextAlpha
                        SnowPop_TogBg.Color = LerpColor(dynAccentOff, State.AccentCol, ApplyCurve(SnowPopAnim.Tog, "EaseOutQuart"))

                        SnowPop_TogTxt.Visible, SnowPop_TogTxt.Position, SnowPop_TogTxt.Transparency = true, popP(15, sY + 5), popTextAlpha
                        SnowPop_TogTxt.Text = "Enabled"; SnowPop_TogTxt.Center = false; SnowPop_TogTxt.Color = dynTextMain
                        pcall(function() SnowPop_TogTxt.Size = math.max(1, safeN(13 * currentTextScale * morphAlpha)) end)

                        SnowPop_TogKnob.Visible, SnowPop_TogKnob.Size, SnowPop_TogKnob.Transparency = true, popS(10, 10), popTextAlpha
                        SnowPop_TogKnob.Position = popP(pW - 55 + Lerp(3, 27, ApplyCurve(SnowPopAnim.Tog, "EaseOutQuart")), sY + 7)
                        SnowPop_TogKnob.Color = LerpColor(Theme.TextSub, dynMain, SnowPopAnim.Tog)

                        local hovCol = hitBox(mPos, popP(pW - 35, sY + 32), popS(20, 20)) and State.TargetPopup == "Snowfall"
                        local cpPos, cpSize, cpAnim, cpScale = CalcPress(popP(pW - 35, sY + 32), popS(20, 20), hovCol, SnowPopAnim.ColPress, dt, 0.05)
                        SnowPopAnim.ColPress = cpAnim
                        SnowPopAnim.Col = ExpLerp(SnowPopAnim.Col or 0, hovCol and 1 or 0, dt, 16)

                        SnowPop_ColBtn.Visible, SnowPop_ColBtn.Position, SnowPop_ColBtn.Size, SnowPop_ColBtn.Transparency = true, cpPos, cpSize, popTextAlpha
                        SnowPop_ColTxt.Visible, SnowPop_ColTxt.Position, SnowPop_ColTxt.Transparency = true, popP(15, sY + 35), popTextAlpha
                        SnowPop_ColTxt.Center = false; SnowPop_ColTxt.Color = dynTextMain; SnowPop_ColTxt.Text = "Color:"
                        pcall(function() SnowPop_ColTxt.Size = math.max(1, safeN(13 * currentTextScale * morphAlpha)) end)
                        SnowPop_ColBtn.Color = State.SnowCol
                        sY = sY + 65

                        local function drawPopSlider(slid, yPos, label, pct, displayVal, animKey)
                            local rP, rS = popP(15, yPos), popS(pW - 30, 40)
                            local hov = hitBox(mPos, rP, rS) and State.TargetPopup == State.ActivePopup
                            local sPos, sSize, sAnim, sScale = CalcPress(rP, rS, hov, SnowPopAnim[animKey.."Press"], dt, 0.02)
                            sPos = safeV(sPos, rP); sSize = safeV(sSize, rS); sScale = safeN(sScale, 1)

                            SnowPopAnim[animKey.."Press"] = sAnim
                            SnowPopAnim[animKey] = ExpLerp(SnowPopAnim[animKey] or 0, hov and 1 or 0, dt, 16)

                            slid.Bg.Visible, slid.Bg.Position, slid.Bg.Size, slid.Bg.Transparency = true, sPos, sSize, popTextAlpha
                            slid.Bg.Color = LerpColor(dynPanel, dynMain, 0)
                            slid.Txt.Visible, slid.Txt.Position, slid.Txt.Transparency = true, sPos + popS(12, 5), popTextAlpha
                            slid.Txt.Text = label; slid.Txt.Color = dynTextMain; slid.Txt.Center = false; SafeSize(slid.Txt, 13 * currentTextScale * morphAlpha)

                            local barW, barH = sSize.X - popS(65, 0).X, popS(0, 4).Y
                            slid.FillBg.Visible, slid.FillBg.Position, slid.FillBg.Size, slid.FillBg.Transparency = true, sPos + popS(12, 28), Vector2.new(barW, barH), popTextAlpha
                            slid.FillBg.Color = dynMain
                            slid.Fill.Visible, slid.Fill.Position, slid.Fill.Size, slid.Fill.Transparency = true, sPos + popS(12, 28), Vector2.new(math.max(1, barW * ApplyCurve(pct, "EaseOutQuart")), barH), popTextAlpha
                            slid.Fill.Color = LightenColor(State.AccentCol, 0.25 * ApplyCurve(SnowPopAnim[animKey], "EaseOutQuart"))

                            local vW, vH = popS(35, 18).X, popS(35, 18).Y
                            local vX, vY = sSize.X - popS(45, 0).X, popS(0, 17).Y
                            local valHovered = hitBox(mPos, sPos + Vector2.new(vX, vY), Vector2.new(vW, vH)) and State.TargetPopup == State.ActivePopup
                            local vpP, vpS, vpA, vpScale = CalcPress(sPos + Vector2.new(vX, vY), Vector2.new(vW, vH), valHovered, SnowPopAnim[animKey.."ValPress"], dt, 0.05)
                            vpP = safeV(vpP, sPos + Vector2.new(vX, vY)); vpS = safeV(vpS, Vector2.new(vW, vH)); vpScale = safeN(vpScale, 1)

                            SnowPopAnim[animKey.."ValPress"] = vpA
                            SnowPopAnim[animKey.."Val"] = ExpLerp(SnowPopAnim[animKey.."Val"] or 0, valHovered and 1 or 0, dt, 16)

                            slid.ValBg.Visible, slid.ValBg.Position, slid.ValBg.Size, slid.ValBg.Transparency = true, vpP, vpS, popTextAlpha
                            slid.ValBg.Color = LerpColor(dynMain, State.AccentCol, 0.15 * ApplyCurve(SnowPopAnim[animKey.."Val"], "EaseOutQuart"))
                            slid.ValTxt.Visible, slid.ValTxt.Position, slid.ValTxt.Transparency = true, vpP + Vector2.new(vpS.X/2, vpS.Y/2 - (6.5 * currentTextScale * vpScale * morphAlpha)), popTextAlpha
                            slid.ValTxt.Text = displayVal; slid.ValTxt.Color = dynTextMain; slid.ValTxt.Center = true
                            SafeSize(slid.ValTxt, 13 * currentTextScale * vpScale * morphAlpha)
                        end

                        drawPopSlider(SnowPop_Size, sY, "Size", math.clamp((State.SnowSize - 1) / math.max(0.001, 4), 0, 1), string.format("%.1f", State.SnowSize), "Size"); sY = sY + 45
                        drawPopSlider(SnowPop_Speed, sY, "Speed", math.clamp((State.SnowSpeed - 5) / math.max(0.001, 45), 0, 1), tostring(math.floor(State.SnowSpeed)), "Speed"); sY = sY + 45
                        drawPopSlider(SnowPop_Amt, sY, "Amount", math.clamp((State.SnowAmount - 10) / math.max(0.001, 90), 0, 1), tostring(math.floor(State.SnowAmount)), "Amt"); sY = sY + 45
                        drawPopSlider(SnowPop_Trans, sY, "Transparency", math.clamp(State.SnowTrans, 0, 1), string.format("%.2f", State.SnowTrans), "Trans")

                        local rawPos, rawSize = popP(10, pH - 38), popS(pW - 20, 28)
                        local closeHov = hitBox(mPos, rawPos, rawSize)
                        local cPos, cSize, cAnim, cScale = CalcPress(rawPos, rawSize, closeHov, State.PopClosePress, dt)
                        State.PopClosePress = cAnim
                        State.PopCloseHov = ExpLerp(State.PopCloseHov or 0, closeHov and 1 or 0, dt, 18)

                        PopCloseBtn.Visible, PopCloseBtn.Position, PopCloseBtn.Size, PopCloseBtn.Transparency = isContentVisible, cPos, cSize, popTextAlpha
                        PopCloseBtn.Color = LerpColor(dynPanel, State.AccentCol, ApplyCurve(State.PopCloseHov, "EaseOutQuart"))
                        PopCloseTxt.Visible, PopCloseTxt.Position, PopCloseTxt.Transparency, PopCloseTxt.Text = isContentVisible, cPos + Vector2.new(cSize.X/2, cSize.Y/2 - 6.5 * currentTextScale * morphAlpha), popTextAlpha, "Close"
                        PopCloseTxt.Color = LerpColor(dynTextMain, Color3.new(0, 0, 0), ApplyCurve(State.PopCloseHov, "EaseOutQuart"))
                        PopCloseTxt.Center = true
                        PopCloseTxt.Font = tonumber(State.UIFont) or 5
                        pcall(function() PopCloseTxt.Size = math.ceil(math.max(1, safeN(13 * currentTextScale * cScale * morphAlpha))) end)
                    end

                elseif State.ActivePopup == "Color" then
                    PopTitle.Text = "Color Mixer"
                    if isContentVisible then
                        local pvX, pvY, pvS = 15, 40, 110
                        local prevBg = GetDrawing("Color_PrevBg", "Square", {Filled=true, ZIndex=24, Rounding=16})
                        prevBg.Visible, prevBg.Position, prevBg.Size, prevBg.Transparency = true, popP(pvX, pvY), popS(pvS, pvS), popTextAlpha
                        prevBg.Color = dynPanel

                        local prevCol = GetDrawing("Color_PrevCol", "Square", {Filled=true, ZIndex=25, Rounding=16})
                        prevCol.Visible, prevCol.Position, prevCol.Size, prevCol.Transparency = true, popP(pvX+4, pvY+4), popS(pvS-8, pvS-8), popTextAlpha
                        prevCol.Color = ColorPicker.Color

                        local sX, sW = 140, 165

                        local function drawColorSlider(name, yOff, lbl, colorVal, fillCol)
                            local lblTxt = GetDrawing(name.."_Lbl", "Text", {Center=false, ZIndex=25})
                            lblTxt.Font = tonumber(State.UIFont) or 5
                            SafeSize(lblTxt, 13 * currentTextScale * morphAlpha)
                            lblTxt.Visible, lblTxt.Position, lblTxt.Transparency, lblTxt.Text, lblTxt.Color = true, popP(sX, yOff), popTextAlpha, lbl .. ": " .. math.floor(colorVal * 255), dynTextMain

                            local bg = GetDrawing(name.."_Bg", "Square", {Filled=true, ZIndex=24, Rounding=8})
                            bg.Visible, bg.Position, bg.Size, bg.Transparency, bg.Color = true, popP(sX, yOff + 18), popS(sW, 10), popTextAlpha, dynMain

                            local fill = GetDrawing(name.."_Fill", "Square", {Filled=true, ZIndex=25, Rounding=8})
                            fill.Visible, fill.Position, fill.Size, fill.Transparency, fill.Color = true, popP(sX, yOff + 18), popS(math.max(1, sW * colorVal), 10), popTextAlpha, fillCol
                        end

                        drawColorSlider("ColorR", 40, "Red", ColorPicker.Color.R, Color3.fromRGB(255, 75, 75))
                        drawColorSlider("ColorG", 80, "Green", ColorPicker.Color.G, Color3.fromRGB(75, 255, 75))
                        drawColorSlider("ColorB", 120, "Blue", ColorPicker.Color.B, Color3.fromRGB(75, 125, 255))

                        local bY = 165; local bH = 25; local smW = 50; local bigW = 165
                        local applyBg = GetDrawing("Color_ApplyBg", "Square", {Filled=true, ZIndex=24, Rounding=16})
                        local applyTxt = GetDrawing("Color_ApplyTxt", "Text", {Center=true, ZIndex=25})
                        local aRPos, aRSize = popP(15, bY), popS(smW, bH)
                        local aHov = hitBox(mPos, aRPos, aRSize) and State.TargetPopup == "Color"
                        local apPos, apSize, apAnim, apScale = CalcPress(aRPos, aRSize, aHov, SnowPopAnim.ColorApplyPress, dt, 0.05)
                        SnowPopAnim.ColorApplyPress = apAnim; SnowPopAnim.ColorApply = ExpLerp(SnowPopAnim.ColorApply or 0, aHov and 1 or 0, dt, 16)

                        applyBg.Visible, applyBg.Position, applyBg.Size, applyBg.Transparency = true, apPos, apSize, popTextAlpha
                        applyBg.Color = LerpColor(dynPanel, State.AccentCol, ApplyCurve(SnowPopAnim.ColorApply, "EaseOutQuart"))
                        applyTxt.Font = tonumber(State.UIFont) or 5
                        SafeSize(applyTxt, 13 * currentTextScale * apScale * morphAlpha)
                        applyTxt.Visible, applyTxt.Position, applyTxt.Transparency, applyTxt.Text, applyTxt.Color = true, apPos + Vector2.new(apSize.X/2, apSize.Y/2 - 6.5 * currentTextScale * apScale * morphAlpha), popTextAlpha, "Apply", LerpColor(dynTextMain, Color3.new(0,0,0), ApplyCurve(SnowPopAnim.ColorApply, "EaseOutQuart"))

                        local resetX = 15 + smW + 10
                        local resetBg = GetDrawing("Color_ResetBg", "Square", {Filled=true, ZIndex=24, Rounding=16})
                        local resetTxt = GetDrawing("Color_ResetTxt", "Text", {Center=true, ZIndex=25})
                        local rRPos, rRSize = popP(resetX, bY), popS(smW, bH)
                        local rHov = hitBox(mPos, rRPos, rRSize) and State.TargetPopup == "Color"
                        local rpPos, rpSize, rpAnim, rpScale = CalcPress(rRPos, rRSize, rHov, SnowPopAnim.ColorResetPress, dt, 0.05)
                        SnowPopAnim.ColorResetPress = rpAnim; SnowPopAnim.ColorReset = ExpLerp(SnowPopAnim.ColorReset or 0, rHov and 1 or 0, dt, 16)

                        resetBg.Visible, resetBg.Position, resetBg.Size, resetBg.Transparency = true, rpPos, rpSize, popTextAlpha
                        resetBg.Color = LerpColor(dynPanel, Color3.fromRGB(200, 70, 70), ApplyCurve(SnowPopAnim.ColorReset, "EaseOutQuart"))
                        resetTxt.Font = tonumber(State.UIFont) or 5
                        SafeSize(resetTxt, 13 * currentTextScale * rpScale * morphAlpha)
                        resetTxt.Visible, resetTxt.Position, resetTxt.Transparency, resetTxt.Text, resetTxt.Color = true, rpPos + Vector2.new(rpSize.X/2, rpSize.Y/2 - 6.5 * currentTextScale * rpScale * morphAlpha), popTextAlpha, "Reset", LerpColor(dynTextMain, Color3.new(0,0,0), ApplyCurve(SnowPopAnim.ColorReset, "EaseOutQuart"))

                        local hexBg = GetDrawing("Color_HexBg", "Square", {Filled=true, ZIndex=24, Rounding=16})
                        local hexTxt = GetDrawing("Color_HexTxt", "Text", {Center=true, ZIndex=25})
                        local hexX = 140
                        local hRPos, hRSize = popP(hexX, bY), popS(bigW, bH)
                        local hHov = hitBox(mPos, hRPos, hRSize) and State.TargetPopup == "Color"
                        local hpPos, hpSize, hpAnim, hpScale = CalcPress(hRPos, hRSize, hHov, SnowPopAnim.ColorHexPress, dt, 0.05)
                        SnowPopAnim.ColorHexPress = hpAnim; SnowPopAnim.ColorHex = ExpLerp(SnowPopAnim.ColorHex or 0, hHov and 1 or 0, dt, 16)

                        hexBg.Visible, hexBg.Position, hexBg.Size, hexBg.Transparency = true, hpPos, hpSize, popTextAlpha
                        hexBg.Color = LerpColor((Focused == "Hex") and dynAccentOff or dynPanel, State.AccentCol, 0.25 * ApplyCurve(SnowPopAnim.ColorHex, "EaseOutQuart"))
                        hexTxt.Font = tonumber(State.UIFont) or 5
                        SafeSize(hexTxt, 13 * currentTextScale * hpScale * morphAlpha)
                        local hexStr = toHex(ColorPicker.Color) or "#FFFFFF"
                        local hexDisp = (Focused == "Hex") and (InputBuffers["Hex"] .. "|") or ("#" .. hexStr:gsub("#",""):upper())
                        hexTxt.Visible, hexTxt.Position, hexTxt.Transparency, hexTxt.Text, hexTxt.Color = true, hpPos + Vector2.new(hpSize.X/2, hpSize.Y/2 - 6.5 * currentTextScale * hpScale * morphAlpha), popTextAlpha, hexDisp, dynTextMain
                    else
                        hideColorPopups()
                    end

                elseif State.ActivePopup == "DeleteConfirm" then
                    PopTitle.Text = "Confirm"
                    DelConfTxt.Visible = isContentVisible
                    if isContentVisible then
                        DelConfTxt.Position = popP(pW/2, 48)
                        DelConfTxt.Text = "Are you sure you want to delete\n'" .. tostring(State.SelectedConfig) .. "'?"
                        DelConfTxt.Transparency = popTextAlpha; DelConfTxt.Color = dynTextMain; DelConfTxt.Center = true
                        DelConfTxt.Font = tonumber(State.UIFont) or 5; SafeSize(DelConfTxt, 13 * currentTextScale * morphAlpha)

                        local gap = 15; local btnW = (pW - (gap * 3)) / 2; local btnH = 28; local btnY = pH - 45
                        local yesX = gap
                        local yesRPos, yesRSize = popP(yesX, btnY), popS(btnW, btnH)
                        local yesHov = hitBox(mPos, yesRPos, yesRSize) and State.TargetPopup == "DeleteConfirm"
                        local yPos, ySize, yAnim, yScale = CalcPress(yesRPos, yesRSize, yesHov, SnowPopAnim.DelYesPress, dt, 0.05)
                        SnowPopAnim.DelYesPress = yAnim; SnowPopAnim.DelYes = ExpLerp(SnowPopAnim.DelYes or 0, yesHov and 1 or 0, dt, 16)

                        DelConf_YesBg.Visible, DelConf_YesBg.Position, DelConf_YesBg.Size, DelConf_YesBg.Transparency = isContentVisible, yPos, ySize, popTextAlpha
                        DelConf_YesBg.Color = LerpColor(dynPanel, State.AccentCol, ApplyCurve(SnowPopAnim.DelYes, "EaseOutQuart"))
                        DelConf_YesTxt.Visible, DelConf_YesTxt.Position, DelConf_YesTxt.Transparency = isContentVisible, yPos + Vector2.new(ySize.X/2, ySize.Y/2 - 6.5 * currentTextScale * morphAlpha), popTextAlpha
                        DelConf_YesTxt.Color = LerpColor(dynTextMain, Color3.new(0, 0, 0), ApplyCurve(SnowPopAnim.DelYes, "EaseOutQuart")); DelConf_YesTxt.Text = "Confirm"; DelConf_YesTxt.Center = true
                        DelConf_YesTxt.Font = tonumber(State.UIFont) or 5; SafeSize(DelConf_YesTxt, 13 * currentTextScale * yScale * morphAlpha)

                        local noX = gap * 2 + btnW
                        local noRPos, noRSize = popP(noX, btnY), popS(btnW, btnH)
                        local noHov = hitBox(mPos, noRPos, noRSize) and State.TargetPopup == "DeleteConfirm"
                        local nPos, nSize, nAnim, nScale = CalcPress(noRPos, noRSize, noHov, SnowPopAnim.DelNoPress, dt, 0.05)
                        SnowPopAnim.DelNoPress = nAnim; SnowPopAnim.DelNo = ExpLerp(SnowPopAnim.DelNo or 0, noHov and 1 or 0, dt, 16)

                        DelConf_NoBg.Visible, DelConf_NoBg.Position, DelConf_NoBg.Size, DelConf_NoBg.Transparency = isContentVisible, nPos, nSize, popTextAlpha
                        DelConf_NoBg.Color = LerpColor(dynPanel, State.AccentCol, ApplyCurve(SnowPopAnim.DelNo, "EaseOutQuart"))
                        DelConf_NoTxt.Visible, DelConf_NoTxt.Position, DelConf_NoTxt.Transparency = isContentVisible, nPos + Vector2.new(nSize.X/2, nSize.Y/2 - 6.5 * currentTextScale * morphAlpha), popTextAlpha
                        DelConf_NoTxt.Color = LerpColor(dynTextMain, Color3.new(0, 0, 0), ApplyCurve(SnowPopAnim.DelNo, "EaseOutQuart")); DelConf_NoTxt.Text = "Cancel"; DelConf_NoTxt.Center = true
                        DelConf_NoTxt.Font = tonumber(State.UIFont) or 5; SafeSize(DelConf_NoTxt, 13 * currentTextScale * nScale * morphAlpha)
                    end

                elseif State.ActivePopup == "PerfUI" then
                    PopTitle.Text = "Warning"
                    if isContentVisible then
                        local clY = 54
                        local lines = {
                            "If you continue, the script will unload the current",
                            "UI and load a low end one which has no animations",
                            "and some customization features removed to improve",
                            "performance, this is only recommended if you have",
                            "a low end device or low performance."
                        }
                        for i, line in ipairs(lines) do
                            if CL_Texts[i] and isContentVisible then
                                CL_Texts[i].Visible = isContentVisible
                                CL_Texts[i].Center = true
                                CL_Texts[i].Position = popP(pW/2, clY - 7)
                                CL_Texts[i].Text = line
                                CL_Texts[i].Transparency = popTextAlpha
                                CL_Texts[i].Color = dynTextSub
                                CL_Texts[i].Font = tonumber(State.UIFont) or 5
                                SafeSize(CL_Texts[i], 13 * currentTextScale * morphAlpha)
                                CL_Texts[i].ZIndex = 26
                                clY = clY + 16
                            end
                        end

                        local gap = 15; local btnW = (pW - (gap * 3)) / 2; local btnH = 28; local btnY = pH - 45
                        local yesX = gap
                        local yesRPos, yesRSize = popP(yesX, btnY), popS(btnW, btnH)
                        local yesHov = hitBox(mPos, yesRPos, yesRSize) and State.TargetPopup == "PerfUI"
                        local yPos, ySize, yAnim, yScale = CalcPress(yesRPos, yesRSize, yesHov, SnowPopAnim.PerfYesPress, dt, 0.05)
                        SnowPopAnim.PerfYesPress = yAnim; SnowPopAnim.PerfYes = ExpLerp(SnowPopAnim.PerfYes or 0, yesHov and 1 or 0, dt, 16)

                        PerfUI_YesBg.Visible, PerfUI_YesBg.Position, PerfUI_YesBg.Size, PerfUI_YesBg.Transparency = isContentVisible, yPos, ySize, popTextAlpha
                        PerfUI_YesBg.Color = LerpColor(dynPanel, State.AccentCol, ApplyCurve(SnowPopAnim.PerfYes, "EaseOutQuart"))
                        PerfUI_YesTxt.Visible, PerfUI_YesTxt.Position, PerfUI_YesTxt.Transparency = isContentVisible, yPos + Vector2.new(ySize.X/2, ySize.Y/2 - 6.5 * currentTextScale * morphAlpha), popTextAlpha
                        PerfUI_YesTxt.Color = LerpColor(dynTextMain, Color3.new(0, 0, 0), ApplyCurve(SnowPopAnim.PerfYes, "EaseOutQuart")); PerfUI_YesTxt.Text = "Confirm"; PerfUI_YesTxt.Center = true
                        PerfUI_YesTxt.Font = tonumber(State.UIFont) or 5; SafeSize(PerfUI_YesTxt, 13 * currentTextScale * yScale * morphAlpha)

                        local noX = gap * 2 + btnW
                        local noRPos, noRSize = popP(noX, btnY), popS(btnW, btnH)
                        local noHov = hitBox(mPos, noRPos, noRSize) and State.TargetPopup == "PerfUI"
                        local nPos, nSize, nAnim, nScale = CalcPress(noRPos, noRSize, noHov, SnowPopAnim.PerfNoPress, dt, 0.05)
                        SnowPopAnim.PerfNoPress = nAnim; SnowPopAnim.PerfNo = ExpLerp(SnowPopAnim.PerfNo or 0, noHov and 1 or 0, dt, 16)

                        PerfUI_NoBg.Visible, PerfUI_NoBg.Position, PerfUI_NoBg.Size, PerfUI_NoBg.Transparency = isContentVisible, nPos, nSize, popTextAlpha
                        PerfUI_NoBg.Color = LerpColor(dynPanel, State.AccentCol, ApplyCurve(SnowPopAnim.PerfNo, "EaseOutQuart"))
                        PerfUI_NoTxt.Visible, PerfUI_NoTxt.Position, PerfUI_NoTxt.Transparency = isContentVisible, nPos + Vector2.new(nSize.X/2, nSize.Y/2 - 6.5 * currentTextScale * morphAlpha), popTextAlpha
                        PerfUI_NoTxt.Color = LerpColor(dynTextMain, Color3.new(0, 0, 0), ApplyCurve(SnowPopAnim.PerfNo, "EaseOutQuart")); PerfUI_NoTxt.Text = "Cancel"; PerfUI_NoTxt.Center = true
                        PerfUI_NoTxt.Font = tonumber(State.UIFont) or 5; SafeSize(PerfUI_NoTxt, 13 * currentTextScale * nScale * morphAlpha)
                    end
                elseif State.ActivePopup == "UIFont" then
                    PopTitle.Text = "Select Font"
                    if isContentVisible then
                        local startY = 45; local itemsPerPage = 16; local maxPages = 2
                        local startIdx = (State.PopFontPage - 1) * itemsPerPage

                        for i = 1, itemsPerPage do
                            local fIdx = startIdx + i
                            local fontVal = fIdx - 1
                            if fontVal <= 31 then
                                local col = (i - 1) % 2; local row = math.floor((i - 1) / 2)
                                local fBtnBtnX = 15 + (col * (pW / 2)); local fBtnBtnY = startY + (row * 28)
                                local fBtnSizeW, fBtnSizeH = (pW / 2) - 25, 24

                                local fHov = hitBox(mPos, popP(fBtnBtnX, fBtnBtnY), popS(fBtnSizeW, fBtnSizeH)) and State.TargetPopup == "UIFont"
                                local fKey = "Font_"..fIdx
                                SnowPopAnim[fKey] = ExpLerp(SnowPopAnim[fKey] or 0, fHov and 1 or 0, dt, 16)

                                local fTag = "FontPop_"..i
                                local fBg = GetDrawing(fTag.."_Bg", "Square", {Filled=true, Thickness=0, ZIndex=24}); fBg.Rounding = 12
                                local fTxt = GetDrawing(fTag.."_Txt", "Text", {Center=true, ZIndex=25}); fTxt.Font = fontVal; SafeSize(fTxt, 13 * currentTextScale * morphAlpha)

                                local fontNames = {
                                    [0]="UI", [1]="System", [2]="Plex", [3]="Monospace", [4]="SourceSans", [5]="Arial", [6]="Cartoon", [7]="Code",
                                    [8]="Highway", [9]="SciFi", [10]="Arcade", [11]="Fantasy", [12]="Gotham", [13]="Bodoni", [14]="Garamond", [15]="Nunito",
                                    [16]="Oswald", [17]="Roboto", [18]="Ubuntu", [19]="Play", [20]="Jura", [21]="Titillium", [22]="Amatic", [23]="Bebas",
                                    [24]="Lobster", [25]="Cabin", [26]="Arimo", [27]="Exo", [28]="Josefin", [29]="Orbitron", [30]="Signika", [31]="Syncopate"
                                }
                                local fName = fontNames[fontVal] or "Font "..fontVal

                                fBg.Visible, fBg.Position, fBg.Size, fBg.Transparency = isContentVisible, popP(fBtnBtnX, fBtnBtnY), popS(fBtnSizeW, fBtnSizeH), popTextAlpha
                                fBg.Color = (tostring(fontVal) == State.UIFont) and State.AccentCol or LerpColor(dynPanel, dynAccentOff, ApplyCurve(SnowPopAnim[fKey], "EaseOutQuart"))
                                fTxt.Visible, fTxt.Position, fTxt.Transparency, fTxt.Text = isContentVisible, popP(fBtnBtnX + fBtnSizeW/2, fBtnBtnY + 5), popTextAlpha, fName
                                fTxt.Color = (tostring(fontVal) == State.UIFont) and dynMain or dynTextMain
                            else
                                local fTag = "FontPop_"..i
                                if DrawCache[fTag.."_Bg"] then DrawCache[fTag.."_Bg"].Visible = false end
                                if DrawCache[fTag.."_Txt"] then DrawCache[fTag.."_Txt"].Visible = false end
                            end
                        end

                        local prevDisabled = State.PopFontPage <= 1
                        local nextDisabled = State.PopFontPage >= maxPages

                        SnowPopAnim.LPPrevDis = ExpLerp(SnowPopAnim.LPPrevDis or 0, prevDisabled and 1 or 0, dt, 12)
                        SnowPopAnim.LPNextDis = ExpLerp(SnowPopAnim.LPNextDis or 0, nextDisabled and 1 or 0, dt, 12)

                        LP_Prev.Visible, LP_Prev.Size, LP_Prev.Position, LP_Prev.Transparency = isContentVisible, popS(28, 28), popP(10, pH - 75), popTextAlpha
                        LP_PrevT.Visible, LP_PrevT.Position, LP_PrevT.Transparency = isContentVisible, popP(24, pH - 68.5), popTextAlpha; SafeSize(LP_PrevT, 13 * currentTextScale * morphAlpha)
                        LP_Next.Visible, LP_Next.Size, LP_Next.Position, LP_Next.Transparency = isContentVisible, popS(28, 28), popP(pW - 38, pH - 75), popTextAlpha
                        LP_NextT.Visible, LP_NextT.Position, LP_NextT.Transparency = isContentVisible, popP(pW - 24, pH - 68.5), popTextAlpha; SafeSize(LP_NextT, 13 * currentTextScale * morphAlpha)
                        LP_PageT.Visible, LP_PageT.Position, LP_PageT.Text, LP_PageT.Transparency = isContentVisible, popP(pW/2, pH - 68.5), State.PopFontPage .. "/" .. maxPages, popTextAlpha
                        SafeSize(LP_PageT, 13 * currentTextScale * morphAlpha); LP_PageT.Color = dynTextSub

                        local disBgCol = LerpColor(dynPanel, dynMain, 0.5)
                        local disTxtCol = Color3.fromRGB(90, 90, 95)
                        local prevRPos, prevRSize = LP_Prev.Position, LP_Prev.Size
                        local prevHov = not prevDisabled and hitBox(mPos, prevRPos, prevRSize) and State.TargetPopup == State.ActivePopup
                        local ppP, ppS, ppA, ppScale = CalcPress(prevRPos, prevRSize, prevHov, SnowPopAnim.LPPrevPress, dt, 0.05)
                        SnowPopAnim.LPPrevPress = ppA; SnowPopAnim.LPPrevFont = ExpLerp(SnowPopAnim.LPPrevFont or 0, prevHov and 1 or 0, dt, 18)
                        LP_Prev.Visible, LP_Prev.Position, LP_Prev.Size = isContentVisible, ppP, ppS
                        LP_Prev.Color = LerpColor(LerpColor(dynPanel, State.AccentCol, ApplyCurve(SnowPopAnim.LPPrevFont, "EaseOutQuart")), disBgCol, SnowPopAnim.LPPrevDis)
                        LP_PrevT.Visible, LP_PrevT.Position = isContentVisible, ppP + Vector2.new(ppS.X/2, ppS.Y/2 - 6.5 * currentTextScale * morphAlpha); SafeSize(LP_PrevT, 13 * currentTextScale * ppScale * morphAlpha)
                        LP_PrevT.Color = LerpColor(LerpColor(dynTextMain, Color3.new(0, 0, 0), ApplyCurve(SnowPopAnim.LPPrevFont, "EaseOutQuart")), disTxtCol, SnowPopAnim.LPPrevDis)

                        local nextRPos, nextRSize = LP_Next.Position, LP_Next.Size
                        local nextHov = not nextDisabled and hitBox(mPos, nextRPos, nextRSize) and State.TargetPopup == State.ActivePopup
                        local npP, npS, npA, npScale = CalcPress(nextRPos, nextRSize, nextHov, SnowPopAnim.LPNextPress, dt, 0.05)
                        SnowPopAnim.LPNextPress = npA; SnowPopAnim.LPNextFont = ExpLerp(SnowPopAnim.LPNextFont or 0, nextHov and 1 or 0, dt, 18)
                        LP_Next.Visible, LP_Next.Position, LP_Next.Size = isContentVisible, npP, npS
                        LP_Next.Color = LerpColor(LerpColor(dynPanel, State.AccentCol, ApplyCurve(SnowPopAnim.LPNextFont, "EaseOutQuart")), disBgCol, SnowPopAnim.LPNextDis)
                        LP_NextT.Visible, LP_NextT.Position = isContentVisible, npP + Vector2.new(npS.X/2, npS.Y/2 - 6.5 * currentTextScale * morphAlpha); SafeSize(LP_NextT, 13 * currentTextScale * npScale * morphAlpha)
                        LP_NextT.Color = LerpColor(LerpColor(dynTextMain, Color3.new(0, 0, 0), ApplyCurve(SnowPopAnim.LPNextFont, "EaseOutQuart")), disTxtCol, SnowPopAnim.LPNextDis)

                        local rawPos, rawSize = popP(10, pH - 38), popS(pW - 20, 28)
                        local closeHov = hitBox(mPos, rawPos, rawSize)
                        local cPos, cSize, cAnim, cScale = CalcPress(rawPos, rawSize, closeHov, State.PopClosePress, dt)
                        State.PopClosePress = cAnim; State.PopCloseHov = ExpLerp(State.PopCloseHov or 0, closeHov and 1 or 0, dt, 18)
                        PopCloseBtn.Visible, PopCloseBtn.Position, PopCloseBtn.Size, PopCloseBtn.Transparency = isContentVisible, cPos, cSize, popTextAlpha
                        PopCloseBtn.Color = LerpColor(dynPanel, State.AccentCol, ApplyCurve(State.PopCloseHov, "EaseOutQuart"))
                        PopCloseTxt.Visible, PopCloseTxt.Position, PopCloseTxt.Transparency, PopCloseTxt.Text = isContentVisible, cPos + Vector2.new(cSize.X/2, cSize.Y/2 - 6.5 * currentTextScale), popTextAlpha, "Close"
                        PopCloseTxt.Color = LerpColor(dynTextMain, Color3.new(0, 0, 0), ApplyCurve(State.PopCloseHov, "EaseOutQuart"))
                        PopCloseTxt.Center = true
                        PopCloseTxt.Font = tonumber(State.UIFont) or 5
                        pcall(function() PopCloseTxt.Size = math.ceil(math.max(1, safeN(13 * currentTextScale * cScale * morphAlpha))) end)
                    else
                        hideFontPopups()
                    end
                end
            elseif State.ActivePopup == "None" then
                PopOverlay.Visible, PopBg.Visible, PopTitle.Visible, PopCloseBtn.Visible, PopCloseTxt.Visible = false, false, false, false, false
                if CL_Texts then for _, t in ipairs(CL_Texts) do t.Visible = false end end
                PickerPreview.Visible, R_Bg.Visible, R_Fill.Visible, G_Bg.Visible, G_Fill.Visible, B_Bg.Visible, B_Fill.Visible, P_HexBox.Visible, P_HexTxt.Visible = false, false, false, false, false, false, false, false, false
                SnowPop_ColBtn.Visible, SnowPop_ColTxt.Visible = false, false
                hideColorPopups()
                hidePopSlid(SnowPop_Size); hidePopSlid(SnowPop_Speed); hidePopSlid(SnowPop_Amt); hidePopSlid(SnowPop_Trans)
                LP_Prev.Visible = false; LP_PrevT.Visible = false; LP_Next.Visible = false; LP_NextT.Visible = false; LP_PageT.Visible = false
                DelConfTxt.Visible = false; DelConf_YesBg.Visible = false; DelConf_YesTxt.Visible = false; DelConf_NoBg.Visible = false; DelConf_NoTxt.Visible = false
                PerfUI_YesBg.Visible = false; PerfUI_YesTxt.Visible = false; PerfUI_NoBg.Visible = false; PerfUI_NoTxt.Visible = false
                if State.PopAlpha <= 0.01 then State.ActivePopup = "None" end
            end

            local function ScheduleClick(bPos, bSize, action)
                Interaction.Active = true; Interaction.Mode = "PendingClick"; Interaction.Bounds = {bPos, bSize}; Interaction.Action = action
                return true
            end

            if lDown and State.TargetPopup ~= "None" and not hitBox(mPos, PopBg.Position, PopBg.Size) and not hitBox(mPos, MenuPos, Vector2.new(MenuSize.X, 30 * globalScale)) and State.PopAlpha > 0.8 and not Interaction.Active then
                ScheduleClick(Vector2.new(0, 0), Vector2.new(99999, 99999), function()
                    if State.PreviousPopup then State.PopAlpha = 0; State.TargetPopup = State.PreviousPopup; State.PreviousPopup = nil
                    else State.TargetPopup = "None"; State.PreviousPopup = nil end
                end)
            end

            if lDown then
                local hit = false
                if not Interaction.Active then
                    if hitBox(mPos, MenuPos + MenuSize - vRound(Vector2.new(20 * globalScale, 20 * globalScale)), vRound(Vector2.new(20 * globalScale, 20 * globalScale))) and State.TargetPopup == "None" and not State.TargetDropdown then
                        Interaction.Active = true; Interaction.Mode = "Resize"; hit = true
                    elseif State.TargetPopup == "Color" then
                        local rBg, gBg, bBg = DrawCache["ColorR_Bg"], DrawCache["ColorG_Bg"], DrawCache["ColorB_Bg"]
                        local hexBg, applyBg, resetBg = DrawCache["Color_HexBg"], DrawCache["Color_ApplyBg"], DrawCache["Color_ResetBg"]
                        if Focused and ((rBg and hitBox(mPos, rBg.Position - Vector2.new(0, 10), rBg.Size + Vector2.new(0, 20))) or (gBg and hitBox(mPos, gBg.Position - Vector2.new(0, 10), gBg.Size + Vector2.new(0, 20))) or (bBg and hitBox(mPos, bBg.Position - Vector2.new(0, 10), bBg.Size + Vector2.new(0, 20))) or (hexBg and hitBox(mPos, hexBg.Position, hexBg.Size)) or (applyBg and hitBox(mPos, applyBg.Position, applyBg.Size)) or (resetBg and hitBox(mPos, resetBg.Position, resetBg.Size)) or hitBox(mPos, PopBg.Position, PopBg.Size)) then Apply() end
                        if rBg and rBg.Visible and hitBox(mPos, rBg.Position - Vector2.new(0, 10), rBg.Size + Vector2.new(0, 20)) then Interaction.Active = true; Interaction.Mode = "CustomR"; hit = true
                        elseif gBg and gBg.Visible and hitBox(mPos, gBg.Position - Vector2.new(0, 10), gBg.Size + Vector2.new(0, 20)) then Interaction.Active = true; Interaction.Mode = "CustomG"; hit = true
                        elseif bBg and bBg.Visible and hitBox(mPos, bBg.Position - Vector2.new(0, 10), bBg.Size + Vector2.new(0, 20)) then Interaction.Active = true; Interaction.Mode = "CustomB"; hit = true
                        elseif hexBg and hexBg.Visible and hitBox(mPos, hexBg.Position, hexBg.Size) then hit = ScheduleClick(hexBg.Position, hexBg.Size, function() Focused = "Hex"; InputBuffers.Hex = toHex(ColorPicker.Color):gsub("#","") end)
                        elseif applyBg and applyBg.Visible and hitBox(mPos, applyBg.Position, applyBg.Size) then hit = ScheduleClick(applyBg.Position, applyBg.Size, function() State[ColorPicker.Target] = ColorPicker.Color; State["Target_"..ColorPicker.Target] = ColorPicker.Color; if State.PreviousPopup then State.TargetPopup = State.PreviousPopup; State.PopAlpha = 0; State.PreviousPopup = nil else State.TargetPopup = "None" end end)
                        elseif resetBg and resetBg.Visible and hitBox(mPos, resetBg.Position, resetBg.Size) then hit = ScheduleClick(resetBg.Position, resetBg.Size, function() ResetToDefault(ColorPicker.Target); State["Target_"..ColorPicker.Target] = ColorPicker.Color end)
                        elseif hitBox(mPos, PopBg.Position, PopBg.Size) then Interaction.Active = true; Interaction.Mode = "Shield"; hit = true end
                    elseif State.TargetPopup == "Snowfall" then
                        if hitBox(mPos, SnowPop_TogBg.Position, SnowPop_TogBg.Size) then hit = ScheduleClick(SnowPop_TogBg.Position, SnowPop_TogBg.Size, function() State.Snowfall = not State.Snowfall end)
                        elseif hitBox(mPos, SnowPop_ColBtn.Position, SnowPop_ColBtn.Size) then hit = ScheduleClick(SnowPop_ColBtn.Position, SnowPop_ColBtn.Size, function() State.PopAlpha = 0; State.PreviousPopup = "Snowfall"; State.TargetPopup = "Color"; ColorPicker.Target = "SnowCol"; ColorPicker.Color = State.SnowCol; InputBuffers.Hex = toHex(State.SnowCol) end)
                        elseif hitBox(mPos, SnowPop_Size.Bg.Position, SnowPop_Size.Bg.Size) then Interaction.Active = true; Interaction.Mode = "SnowSize"; hit = true
                        elseif hitBox(mPos, SnowPop_Speed.Bg.Position, SnowPop_Speed.Bg.Size) then Interaction.Active = true; Interaction.Mode = "SnowSpeed"; hit = true
                        elseif hitBox(mPos, SnowPop_Amt.Bg.Position, SnowPop_Amt.Bg.Size) then Interaction.Active = true; Interaction.Mode = "SnowAmt"; hit = true
                        elseif hitBox(mPos, SnowPop_Trans.Bg.Position, SnowPop_Trans.Bg.Size) then Interaction.Active = true; Interaction.Mode = "SnowTrans"; hit = true
                        elseif hitBox(mPos, PopCloseBtn.Position, PopCloseBtn.Size) then hit = ScheduleClick(PopCloseBtn.Position, PopCloseBtn.Size, function() State.TargetPopup = "None" end)
                        elseif hitBox(mPos, PopBg.Position, PopBg.Size) then Interaction.Active = true; Interaction.Mode = "Shield"; hit = true end
                    elseif State.TargetPopup == "DeleteConfirm" then
                        if hitBox(mPos, DelConf_YesBg.Position, DelConf_YesBg.Size) then hit = ScheduleClick(DelConf_YesBg.Position, DelConf_YesBg.Size, function() DeleteConfig(State.SelectedConfig); State.TargetPopup = "None" end)
                        elseif hitBox(mPos, DelConf_NoBg.Position, DelConf_NoBg.Size) then hit = ScheduleClick(DelConf_NoBg.Position, DelConf_NoBg.Size, function() State.TargetPopup = "None" end)
                        elseif hitBox(mPos, PopBg.Position, PopBg.Size) then Interaction.Active = true; Interaction.Mode = "Shield"; hit = true end
                    elseif State.TargetPopup == "PerfUI" then
                        if hitBox(mPos, PerfUI_YesBg.Position, PerfUI_YesBg.Size) then hit = ScheduleClick(PerfUI_YesBg.Position, PerfUI_YesBg.Size, function() State.HighPerformanceMode = true; State.Snowfall = false; State.TargetPopup = "None" end)
                        elseif hitBox(mPos, PerfUI_NoBg.Position, PerfUI_NoBg.Size) then hit = ScheduleClick(PerfUI_NoBg.Position, PerfUI_NoBg.Size, function() State.TargetPopup = "None" end)
                        elseif hitBox(mPos, PopBg.Position, PopBg.Size) then Interaction.Active = true; Interaction.Mode = "Shield"; hit = true end
                    elseif State.TargetPopup == "UIFont" then
                        if hitBox(mPos, PopCloseBtn.Position, PopCloseBtn.Size) then hit = ScheduleClick(PopCloseBtn.Position, PopCloseBtn.Size, function() State.TargetPopup = "None" end)
                        elseif hitBox(mPos, LP_Prev.Position, LP_Prev.Size) then hit = ScheduleClick(LP_Prev.Position, LP_Prev.Size, function() if State.PopFontPage > 1 then State.PopFontPage = State.PopFontPage - 1 end end)
                        elseif hitBox(mPos, LP_Next.Position, LP_Next.Size) then hit = ScheduleClick(LP_Next.Position, LP_Next.Size, function() if State.PopFontPage < 2 then State.PopFontPage = State.PopFontPage + 1 end end)
                        else
                            for i = 1, 16 do
                                local btn = DrawCache["FontPop_"..i.."_Bg"]
                                if btn and btn.Visible and hitBox(mPos, btn.Position, btn.Size) then
                                    hit = ScheduleClick(btn.Position, btn.Size, function() local fontVal = (State.PopFontPage - 1) * 16 + i - 1; if fontVal <= 31 then State.UIFont = tostring(fontVal) end end)
                                    break
                                end
                            end
                            if not hit and hitBox(mPos, PopBg.Position, PopBg.Size) then Interaction.Active = true; Interaction.Mode = "Shield"; hit = true end
                        end
                    elseif CustomPopups[State.TargetPopup] then
                        if not hit and hitBox(mPos, PopBg.Position, PopBg.Size) then Interaction.Active = true; Interaction.Mode = "Shield"; hit = true end
                    elseif State.TargetDropdown then
                        local hitDrop = false
                        for i, d in ipairs(DropItems) do
                            if d.Bg.Visible and hitBox(mPos, d.Bg.Position, d.Bg.Size) then
                                hit = ScheduleClick(d.Bg.Position, d.Bg.Size, function()
                                    State[State.TargetDropdown.StateKey] = d.Name
                                    if State.TargetDropdown.StateKey == "DefaultConfigName" then
                                        if d.Name == "None" or d.Name == "" then
                                            pcall(function() delfile(ConfigFolderName .. "/default_global.json") end)
                                            pcall(function() delfile(ConfigFolderName .. "/default_game_"..game.PlaceId..".json") end)
                                        else
                                            local data = { Config = d.Name, GameName = "All Games" }
                                            local encoded = SafeEncode(data)
                                            if encoded ~= "" then
                                                pcall(function() writefile(ConfigFolderName .. "/default_global.json", encoded) end)
                                                pcall(function() delfile(ConfigFolderName .. "/default_game_"..game.PlaceId..".json") end)
                                            end
                                        end
                                    end
                                    if State.TargetDropdown.Callback then State.TargetDropdown.Callback(d.Name) end
                                    State.TargetDropdown = nil
                                end)
                                hitDrop = true
                                break
                            end
                        end
                        if not hitDrop then hit = ScheduleClick(Vector2.new(0, 0), Vector2.new(99999, 99999), function() State.TargetDropdown = nil end) end
                    elseif hitBox(mPos, MenuPos, Vector2.new(MenuSize.X, 30 * globalScale)) then
                        Interaction.Active = true; Interaction.Mode = "Drag"; Interaction.Offset = MenuPos - mPos
                    else
                        local hitE = false
                        for _, el in ipairs(Elements) do
                            if el.Tab == State.CurrentTab or (el.Popup and el.Popup == State.ActivePopup) then
                                local isTransSlider = (el.StateKey == "UITrans" or el.StateKey == "ButtonTrans")
                                local isElDisabled = (State.HighPerformanceMode and (el.BaseText == "Snowfall Settings" or isTransSlider or el.StateKey == "Transparent" or el.StateKey == "AnimationsEnabled")) or (not State.Transparent and isTransSlider)

                                if not isElDisabled and el.Bg and el.Bg.Visible then
                                    if el.HasKeybind and el.KeyBg and el.KeyBg.Visible and hitBox(mPos, el.KeyBg.Position, el.KeyBg.Size) then
                                        hitE = ScheduleClick(el.KeyBg.Position, el.KeyBg.Size, function() 
                                            State.LastClickedPos = el.Bg.Position; State.LastClickedSize = el.Bg.Size;
                                            Focused = el.KeyStateKey 
                                        end)
                                        break
                                    elseif el.Type == "Toggle" then
                                        if hitBox(mPos, el.Bg.Position, el.Bg.Size) then
                                            hitE = ScheduleClick(el.Bg.Position, el.Bg.Size, function() State.LastClickedPos = el.Bg.Position; State.LastClickedSize = el.Bg.Size; el:Callback() end)
                                            break
                                        end
                                    elseif el.Type == "Slider" then
                                        if el.ValBg.Visible and hitBox(mPos, el.ValBg.Position, el.ValBg.Size) then
                                            hitE = ScheduleClick(el.ValBg.Position, el.ValBg.Size, function() State.LastClickedPos = el.Bg.Position; State.LastClickedSize = el.Bg.Size; Focused = el.InputKey; InputBuffers[el.InputKey] = tostring(State[el.StateKey]) end)
                                            break
                                        else
                                            local trackPos = el.FillBg.Position - vRound(Vector2.new(10 * globalScale, 15 * globalScale))
                                            local trackSize = el.FillBg.Size + vRound(Vector2.new(20 * globalScale, 30 * globalScale))
                                            if hitBox(mPos, trackPos, trackSize) then
                                                Interaction.Active = true; Interaction.Mode = "Slider"; Interaction.Target = el; hitE = true; break
                                            end
                                        end
                                    elseif el.Type == "Button" and hitBox(mPos, el.Bg.Position, el.Bg.Size) then
                                        hitE = ScheduleClick(el.Bg.Position, el.Bg.Size, function()
                                            State.LastClickedPos = el.Bg.Position; State.LastClickedSize = el.Bg.Size
                                            if el.IsInput then Focused = el.InputKey; InputBuffers[el.InputKey] = "" end
                                            if el.Callback then el.Callback(el) end
                                        end)
                                        break
                                    elseif el.Type == "Dropdown" then
                                        if hitBox(mPos, el.Bg.Position, el.Bg.Size) then
                                            hitE = ScheduleClick(el.Bg.Position, el.Bg.Size, function() State.LastClickedPos = el.Bg.Position; State.LastClickedSize = el.Bg.Size; State.TargetDropdown = (State.TargetDropdown == el) and nil or el end)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        if not hitE then Apply() end
                    end
                elseif Interaction.Mode == "Drag" then
                    TargetMenuPos = mPos + Interaction.Offset
                    local d = 1 - math.exp(-28 * dt)
                    MenuPos = Vector2.new(MenuPos.X + (TargetMenuPos.X - MenuPos.X) * d, MenuPos.Y + (TargetMenuPos.Y - MenuPos.Y) * d)
                elseif Interaction.Mode == "Resize" then
                    local dragX = math.max(minMenuSizeX * 0.65, mPos.X - MenuPos.X)
                    local scale = math.clamp(dragX / minMenuSizeX, 0.65, 5.0)
                    if math.abs(scale - 1.0) < 0.04 then scale = 1.0 end
                    MenuSize = Vector2.new(minMenuSizeX * scale, minMenuSizeY * scale)
                elseif Interaction.Mode == "Slider" and Interaction.Target then
                    local el = Interaction.Target; local pct = math.clamp((mPos.X - el.FillBg.Position.X) / math.max(0.001, el.FillBg.Size.X), 0, 1)
                    local val = el.Min + (el.Max - el.Min) * pct
                    if el.IsFloat then val = math.floor(val * 100) / 100 else val = math.floor(val) end
                    el.Callback(val)
                elseif Interaction.Mode == "CustomR" then
                    local bg = DrawCache["ColorR_Bg"]; if bg then ColorPicker.Color = Color3.new(math.clamp((mPos.X - bg.Position.X) / math.max(0.001, bg.Size.X), 0, 1), ColorPicker.Color.G, ColorPicker.Color.B); InputBuffers.Hex = toHex(ColorPicker.Color):gsub("#",""); end
                elseif Interaction.Mode == "CustomG" then
                    local bg = DrawCache["ColorG_Bg"]; if bg then ColorPicker.Color = Color3.new(ColorPicker.Color.R, math.clamp((mPos.X - bg.Position.X) / math.max(0.001, bg.Size.X), 0, 1), ColorPicker.Color.B); InputBuffers.Hex = toHex(ColorPicker.Color):gsub("#",""); end
                elseif Interaction.Mode == "CustomB" then
                    local bg = DrawCache["ColorB_Bg"]; if bg then ColorPicker.Color = Color3.new(ColorPicker.Color.R, ColorPicker.Color.G, math.clamp((mPos.X - bg.Position.X) / math.max(0.001, bg.Size.X), 0, 1)); InputBuffers.Hex = toHex(ColorPicker.Color):gsub("#",""); end
                elseif Interaction.Mode == "SnowSize" then State.SnowSize = 1 + math.clamp((mPos.X - SnowPop_Size.FillBg.Position.X) / math.max(0.001, SnowPop_Size.FillBg.Size.X), 0, 1) * 4
                elseif Interaction.Mode == "SnowSpeed" then State.SnowSpeed = 5 + math.clamp((mPos.X - SnowPop_Speed.FillBg.Position.X) / math.max(0.001, SnowPop_Speed.FillBg.Size.X), 0, 1) * 45
                elseif Interaction.Mode == "SnowAmt" then State.SnowAmount = math.floor(10 + math.clamp((mPos.X - SnowPop_Amt.FillBg.Position.X) / math.max(0.001, SnowPop_Amt.FillBg.Size.X), 0, 1) * 90)
                elseif Interaction.Mode == "SnowTrans" then State.SnowTrans = math.clamp((mPos.X - SnowPop_Trans.FillBg.Position.X) / math.max(0.001, SnowPop_Trans.FillBg.Size.X), 0, 1)
                end
            else
                if Interaction.Action then Interaction.Action() end
                if Interaction.Mode == "SnowAmt" then GenerateSnow() end
                Interaction.Active = false; Interaction.Mode = "None"; Interaction.Target = nil; Interaction.Action = nil; Interaction.Bounds = nil
            end
        else
            if not UIHidden then
                UIHidden = true
                for _, shadow in ipairs(DropShadows) do shadow.Visible = false end
                BaseBg.Visible = false; TopBar.Visible = false
                MainTitle.Visible = false; V2Text.Visible = false
                for _, tab in ipairs(TabDrawings) do tab.Box.Visible = false; tab.Txt.Visible = false end
                for _, el in ipairs(Elements) do
                    if el.Bg then el.Bg.Visible = false end
                    if el.Txt then el.Txt.Visible = false end
                    if el.Type == "Toggle" then el.TogBg.Visible = false; el.TogKnob.Visible = false
                    elseif el.Type == "Slider" then el.FillBg.Visible = false; el.Fill.Visible = false; el.ValBg.Visible = false; el.ValTxt.Visible = false
                    elseif el.Type == "Dropdown" then el.Icon.Visible = false
                    elseif el.Type == "Separator" then el.Bg.Visible = false end
                    if el.HasKeybind then el.KeyBg.Visible = false; el.KeyTxt.Visible = false end
                end
                DropBg.Visible = false
                for _, d in ipairs(DropItems) do d.Bg.Visible = false; d.Txt.Visible = false end
                PopOverlay.Visible = false; PopBg.Visible = false; PopTitle.Visible = false; PopCloseBtn.Visible = false; PopCloseTxt.Visible = false
                if CL_Texts then for _, t in ipairs(CL_Texts) do t.Visible = false end end
                hideColorPopups(); hidePopSlid(SnowPop_Size); hidePopSlid(SnowPop_Speed); hidePopSlid(SnowPop_Amt); hidePopSlid(SnowPop_Trans)
                LP_Prev.Visible = false; LP_PrevT.Visible = false; LP_Next.Visible = false; LP_NextT.Visible = false; LP_PageT.Visible = false
                DelConfTxt.Visible = false; DelConf_YesBg.Visible = false; DelConf_YesTxt.Visible = false; DelConf_NoBg.Visible = false; DelConf_NoTxt.Visible = false
                PerfUI_YesBg.Visible = false; PerfUI_YesTxt.Visible = false; PerfUI_NoBg.Visible = false; PerfUI_NoTxt.Visible = false
                if State.ActivePopup ~= "UIFont" then hideFontPopups() end
            end
        end 
    end) 
    if not ok then warn("Severe UI Error: " .. tostring(err)) end
end) 

task.spawn(function()
    local gameDefTxt = ConfigFolderName .. "/default_game_"..game.PlaceId..".txt"
    local globalDefTxt = ConfigFolderName .. "/default_global.txt"
    local gameDefJson = ConfigFolderName .. "/default_game_"..game.PlaceId..".json"
    local globalDefJson = ConfigFolderName .. "/default_global.json"
    local confName = nil

    if isfile(gameDefJson) then
        local s, content = pcall(readfile, gameDefJson)
        if s and content then local d = SafeDecode(content); if d and d.Config then confName = d.Config end end
    elseif isfile(globalDefJson) then
        local s, content = pcall(readfile, globalDefJson)
        if s and content then local d = SafeDecode(content); if d and d.Config then confName = d.Config end end
    elseif isfile(gameDefTxt) then
        local s, conf = pcall(readfile, gameDefTxt); if s and conf and conf ~= "" then confName = conf end
    elseif isfile(globalDefTxt) then
        local s, conf = pcall(readfile, globalDefTxt); if s and conf and conf ~= "" then confName = conf end
    end

    if confName then
        local path = ConfigFolderName .. "/" .. confName .. ".json"
        if isfile(path) then
            LoadConfig(confName, true)
            State.DefaultConfigName = confName; State.SelectedConfig = "None"
            if DefaultConfigDropdown then DefaultConfigDropdown.Txt.Text = "Default Config: " .. confName end
            if ConfigDropdown then ConfigDropdown.Txt.Text = "Select Config: None" end
        else
            pcall(function() delfile(gameDefJson) end); pcall(function() delfile(globalDefJson) end)
            pcall(function() delfile(gameDefTxt) end); pcall(function() delfile(globalDefTxt) end)
            State.DefaultConfigName = "None"
            if DefaultConfigDropdown then DefaultConfigDropdown.Txt.Text = "Default Config: None" end
        end
    end
end)

windowObj:createtab("Settings")
CreateLabel_Internal("SETTINGS", "Settings", 1)
CreateButton_Internal("Keybind: " .. State.Keybind, "Settings", 1, function(self) Focused = "Keybind" end, true, "Keybind")
local reloadBtn = CreateButton_Internal("RELOAD SCRIPT", "Settings", 1, function(self)
    if State.IsReloading then return end
    State.IsReloading = true
    if State.DefaultConfigName and State.DefaultConfigName ~= "None" then SaveConfig(State.DefaultConfigName) end
    State.Visible = false
    task.spawn(function()
        if _G.SevereCleanup then _G.SevereCleanup() end
        task.wait(0.1)
        if options.ReloadCallback then options.ReloadCallback() end
    end)
end, false, nil, "Left", true)

local unloadBtn = CreateButton_Internal("UNLOAD SCRIPT", "Settings", 1, function(self)
    if State.IsReloading then return end
    State.IsReloading = true
    State.TargetPopup = "None"; State.ActivePopup = "None"; State.PreviousPopup = nil
    State.ActiveDropdown = nil; State.TargetDropdown = nil
    Focused = nil; State.Visible = false
    task.spawn(function()
        task.wait(0.6)
        if _G.SevereCleanup then _G.SevereCleanup() end
        pcall(function() State.IsReloading = false end)
    end)
end, false, nil, "Right", false)

CreateLabel_Internal("CONFIG", "Settings", 1)
CreateButton_Internal("Config Name...", "Settings", 1, function(self) Focused = "ConfigName"; InputBuffers.ConfigName = "" end, true, "ConfigName")
CreateButton_Internal("Save Config", "Settings", 1, function(self) if InputBuffers.ConfigName and InputBuffers.ConfigName ~= "" then SaveConfig(InputBuffers.ConfigName) end end)
ConfigDropdown = CreateDropdown_Internal("Select Config", "Settings", 1, GetConfigs(), "SelectedConfig")
CreateButton_Internal("Load Config", "Settings", 1, function(self) if State.SelectedConfig ~= "None" then LoadConfig(State.SelectedConfig) end end)
CreateButton_Internal("Delete Config", "Settings", 1, function(self)
    if State.SelectedConfig ~= "None" then
        State.LastClickedPos = self.Bg.Position; State.LastClickedSize = self.Bg.Size
        if State.TargetPopup == "DeleteConfirm" then State.TargetPopup = "None" else State.PopAlpha = 0; State.TargetPopup = "DeleteConfirm" end
    end
end)
local defOpts = GetDefaultConfigs()
DefaultConfigDropdown = CreateDropdown_Internal("Default Config", "Settings", 1, defOpts, "DefaultConfigName")

CreateLabel_Internal("UI CUSTOMIZATION", "Settings", 2)
CreateSlider_Internal("UI Transparency", "Settings", 2, 0, 1, "UITrans", true, "Left", true)
CreateSlider_Internal("Btn Transparency", "Settings", 2, 0, 1, "ButtonTrans", true, "Right", false)

CreateToggle_Internal("Light Mode", "Settings", 2, "LightMode", function(state)
    State.LightRippleOrigin = GlobalMousePos
    State.LightRippleAnim = 0
    State.LightRippleActive = true
end, "Left", true)
CreateToggle_Internal("Transparent", "Settings", 2, "Transparent", nil, "Right", false)

CreateButton_Internal("Snowfall Settings", "Settings", 2, function(self)
    State.LastClickedPos = self.Bg.Position; State.LastClickedSize = self.Bg.Size
    if State.TargetPopup == "Snowfall" then State.TargetPopup = "None" else State.PopAlpha = 0; State.TargetPopup = "Snowfall" end
end, false, nil, "Left", true)

CreateButton_Internal("Change UI Font", "Settings", 2, function(self)
    State.LastClickedPos = self.Bg.Position; State.LastClickedSize = self.Bg.Size
    if State.TargetPopup == "UIFont" then State.TargetPopup = "None" else State.PopAlpha = 0; State.TargetPopup = "UIFont"; State.PopFontPage = 1 end
end, false, nil, "Right", false)

CreateButton_Internal("Edit Accent Color", "Settings", 2, function(self)
    State.LastClickedPos = self.Bg.Position; State.LastClickedSize = self.Bg.Size
    if State.TargetPopup == "Color" and ColorPicker.Target == "AccentCol" then State.TargetPopup = "None"
    else OpenColor("AccentCol", State.AccentCol, "AccentColAlpha") end
end)
CreateButton_Internal("Edit Main Color", "Settings", 2, function(self)
    State.LastClickedPos = self.Bg.Position; State.LastClickedSize = self.Bg.Size
    if State.TargetPopup == "Color" and ColorPicker.Target == "MainCol" then State.TargetPopup = "None"
    else OpenColor("MainCol", State.MainCol, "MainColAlpha") end
end)
CreateButton_Internal("Reset Settings", "Settings", 2, function(self)
    local def = GetDefaultState()
    State.UITrans = def.UITrans; State.ButtonTrans = def.ButtonTrans
    State.Transparent = def.Transparent; State.LightMode = def.LightMode
    State.UIScale = def.UIScale
    State.Target_AccentCol = def.AccentCol; State.Target_MainCol = def.MainCol
    State.Target_SnowCol = def.SnowCol
    State.Snowfall = def.Snowfall; State.SnowSize = def.SnowSize
    State.SnowSpeed = def.SnowSpeed; State.SnowAmount = def.SnowAmount; State.SnowTrans = def.SnowTrans
    State.UIFont = def.UIFont
    GenerateSnow()
end)

CreateButton_Internal("Performance UI", "Settings", 2, function(self)
    State.LastClickedPos = self.Bg.Position; State.LastClickedSize = self.Bg.Size
    if State.TargetPopup == "PerfUI" then State.TargetPopup = "None" else State.PopAlpha = 0; State.TargetPopup = "PerfUI" end
end)

return windowObj
end
return severeui