local severeui = {}

if _G.SevereCleanup then 
    local success, err = pcall(_G.SevereCleanup)
    if not success then warn("SevereUI: Cleanup failed:", err) end
end

function severeui:createwindow(options)
    local callerFile = _G.SevereCallerFile
    pcall(function()
        local src = debug.info(2, "s")
        if src and src:sub(1, 1) == "@" then
            local file = src:sub(2)
            file = file:gsub("\\", "/")
            file = file:gsub("^[Cc]:/[Vv]2/[Ww]orkspace/", "")
            file = file:gsub("^[Ww]orkspace/", "")
            callerFile = file
        end
    end)
    _G.SevereCallerFile = callerFile

    local sessionID = tick()
    _G.SevereSessionID = sessionID

    if _G.SevereCleanup then pcall(_G.SevereCleanup) end
    local windowObj = {}
    windowObj.CallerFile = callerFile
    local Connection
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera

    options = options or {}
    local minMenuSizeX = options.CustomResolution and options.CustomResolution.X or 580
    local minMenuSizeY = options.CustomResolution and options.CustomResolution.Y or 360

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
            Visible = true, CurrentTab = options.DefaultTab, NextTab = nil,
            TabAlpha = 1, PopAlpha = 0, DropAlpha = 0, IntroAlpha = 0,
            ActivePopup = "None", TargetPopup = "None", PreviousPopup = nil,
            ActiveDropdown = nil, TargetDropdown = nil,
            Keybind = options.Keybind or "RightShift",
            DPIScale = options.DPIScale or 1.0,

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
            IsReloading = false,
            ScrollOffsets = {},
            MaxScrollHeights = {}
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
    local CustomPopupTexts = {}
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

    local GhostPositions = {}
    for _i = 1, 5 do table.insert(GhostPositions, Vector2.new(0, 0)) end

    local Focused = nil
    local InputBuffers = {Hex = "", Keybind = "", ConfigName = "", DPIScale = ""}
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

    local function ApplyCurve(t, curveType) return t end

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
         pcall(function()
            local legacyFiles = listfiles(ConfigFolderName)
            for _, f in ipairs(legacyFiles) do
                local name = f:match("([^/\\]+)%.txt$")
                if name and not name:match("^default_") then
                    local alreadyExists = false
                    for _, val in ipairs(names) do if val == name then alreadyExists = true break end end
                    if not alreadyExists then table.insert(names, name) end
                end
            end
         end)
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
        local fallbackPath = ConfigFolderName .. "/" .. name .. ".txt"
        local finalPath = isfile(path) and path or (isfile(fallbackPath) and fallbackPath or nil)
        
        if finalPath then
            local s, content = pcall(readfile, finalPath)
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
                local savedScale = 1.0
                if State.MenuSizeX then
                    if options.CustomResolution and minMenuSizeX ~= 580 and State.MenuSizeX == 580 then
                        savedScale = 1.0
                    else
                        savedScale = math.clamp(State.MenuSizeX / minMenuSizeX, 0.65, 2.5)
                    end
                end
                MenuSize = Vector2.new(minMenuSizeX * savedScale, minMenuSizeY * savedScale)
                if not isAutoLoad then State.SelectedConfig = name end
                GenerateSnow()
            end
        end
    end

    local function DeleteConfig(name)
        local path = ConfigFolderName .. "/" .. name .. ".json"
        local fallbackPath = ConfigFolderName .. "/" .. name .. ".txt"
        if isfile(path) then pcall(delfile, path) end
        if isfile(fallbackPath) then pcall(delfile, fallbackPath) end
        if State.DefaultConfigName == name then
            State.DefaultConfigName = "None"
            pcall(function() delfile(ConfigFolderName .. "/default_global.json") end)
            pcall(function() delfile(ConfigFolderName .. "/default_game_"..game.PlaceId..".json") end)
            pcall(function() delfile(ConfigFolderName .. "/default_global.txt") end)
            pcall(function() delfile(ConfigFolderName .. "/default_game_"..game.PlaceId..".txt") end)
        end
        if ConfigDropdown then ConfigDropdown.Options = GetConfigs(); State.SelectedConfig = "None" end
        if DefaultConfigDropdown then DefaultConfigDropdown.Options = GetDefaultConfigs() end
    end

    local function CreateDrawing(class)
        local obj = Drawing.new(class)
        table.insert(DrawCache, obj)
        return obj
    end

    local function GetDrawing(name, class, props)
        if not DrawCache[name] then
            local obj = Drawing.new(class)
            DrawCache[name] = obj
            if props then for k, v in pairs(props) do obj[k] = v end end
        end
        return DrawCache[name]
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

    _G.SevereCleanup = function()
        _G.SevereCleanup = nil
        if Connection then Connection:Disconnect() end
        for _, obj in pairs(DrawCache) do pcall(function() obj:Remove() end) end
        DrawCache = {}
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
        InputBuffers.Hex = toHex(color):gsub("#","")
    end

    local function Apply()
        if Focused == "Hex" then
            local newC = fromHex(InputBuffers.Hex)
            if newC then
                ColorPicker.Color = newC
                ColorPicker.H, ColorPicker.S, ColorPicker.V = newC:ToHSV()
                if ColorPicker.Target then State[ColorPicker.Target] = ColorPicker.Color end
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
        State["Target_"..name] = value
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

    function windowObj:createpopup(name, size, texts)
        CustomPopups[name] = size or Vector2.new(280, 300)
        CustomPopupTexts[name] = texts or {}
    end

    function windowObj:openpopup(name)
        State.PopAlpha = 0
        State.TargetPopup = name
    end

    function windowObj:closepopup()
        State.TargetPopup = "None"
    end

    local function RegisterKey(name)
        local isConfigAdded = false
        for _, v in ipairs(ConfigKeys) do if v == name then isConfigAdded = true break end end
        if not isConfigAdded then table.insert(ConfigKeys, name) end
    end

    function windowObj:createtoggle(tabName, o)
        local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
        local t = CreateText(o.Name, 13, false, Theme.TextMain, 6)
        local togBg = CreateSquare(true, Theme.AccentOff, 1, 6, 24)
        local togKnob = CreateSquare(true, Theme.TextSub, 1, 7, 16)
        
        local stateKey = o.StateKey or o.Name
        if State[stateKey] == nil then
            if o.Default ~= nil then State[stateKey] = o.Default else State[stateKey] = false end
        end

        if State[stateKey] == true and o.Callback then
            task.spawn(function() o.Callback(true) end)
        end
        
        RegisterKey(stateKey)

        local setBtn, setTxt
        if o.SetIcon then
            setBtn = CreateSquare(true, Theme.PanelBg, 0, 6, 16)
            setTxt = CreateText(o.SetIcon == "Question" and "?" or "...", 14, true, Theme.TextMain, 7)
        end

        local el = { Bg = bg, Txt = t, TogBg = togBg, TogKnob = togKnob, SetBtn = setBtn, SetTxt = setTxt, Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Toggle", StateKey = stateKey, BaseText = o.Name, Anim = 0, SubAnim = 0, BtnHoverAnim = 0, HoverAnim = 0, DisabledAnim = 0, Half = o.Half, SameRow = o.SameRow, CustomWidth = o.CustomWidth, CustomOffset = o.CustomOffset,
            SetCallback = o.SetCallback, SetPopup = o.SetPopup,
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
        
        local stateKey = o.StateKey or o.Name
        if State[stateKey] == nil then
            if o.Default ~= nil then State[stateKey] = o.Default else State[stateKey] = o.Min or 0 end
        end
        local valTxt = CreateText(tostring(State[stateKey]), 13, true, Theme.TextMain, 7)
        
        RegisterKey(stateKey)

        local setBtn, setTxt
        if o.SetIcon then
            setBtn = CreateSquare(true, Theme.PanelBg, 0, 6, 16)
            setTxt = CreateText(o.SetIcon == "Question" and "?" or "...", 14, true, Theme.TextMain, 7)
        end

        local el = { Bg = bg, FillBg = fBg, Fill = fFill, Txt = t, ValBg = valBg, ValTxt = valTxt, SetBtn = setBtn, SetTxt = setTxt, BaseText = o.Name,
            Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Slider", Min = o.Min or 0, Max = o.Max or 100, Step = o.Step, StateKey = stateKey, InputKey = stateKey, IsFloat = o.IsFloat, Anim = 0, SubAnim = 0, BtnHoverAnim = 0, HoverAnim = 0, DisabledAnim = 0, Half = o.Half, SameRow = o.SameRow, CustomWidth = o.CustomWidth, CustomOffset = o.CustomOffset,
            SetCallback = o.SetCallback, SetPopup = o.SetPopup,
            Callback = function(val) State[stateKey] = val; if o.Callback then o.Callback(val) end end }
        table.insert(Elements, el)
        return el
    end

    function windowObj:createbutton(tabName, o)
        local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
        local t = CreateText(o.Name, 13, true, Theme.TextMain, 6)
        
        local el = { Bg = bg, Txt = t, Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Button", BaseText = o.Name, Callback = o.Callback, IsInput = o.IsInput, InputKey = o.InputKey, HoverAnim = 0, DisabledAnim = 0, Half = o.Half, SameRow = o.SameRow, CustomWidth = o.CustomWidth, CustomOffset = o.CustomOffset }
        table.insert(Elements, el)
        return el
    end

    function windowObj:createdropdown(tabName, o)
        local bg = CreateSquare(true, Theme.PanelBg, 1, 5, 16)
        local stateKey = o.StateKey or o.Name
        if State[stateKey] == nil then
            if o.Default ~= nil then State[stateKey] = o.Default else State[stateKey] = (o.Options and o.Options[1]) or "None" end
        end
        local t = CreateText(o.Name .. ": " .. tostring(State[stateKey]), 13, false, Theme.TextMain, 6)
        local icon = CreateText("▼", 13, true, Theme.TextSub, 6)
        
        RegisterKey(stateKey)

        local setBtn, setTxt
        if o.SetIcon then
            setBtn = CreateSquare(true, Theme.PanelBg, 0, 6, 16)
            setTxt = CreateText(o.SetIcon == "Question" and "?" or "...", 14, true, Theme.TextMain, 7)
        end

        local el = { Bg = bg, Txt = t, Icon = icon, SetBtn = setBtn, SetTxt = setTxt, Tab = (not o.Popup) and tabName or nil, Popup = o.Popup, Col = o.Col or 1, Type = "Dropdown", Options = o.Options or {}, StateKey = stateKey, BaseText = o.Name, HoverAnim = 0, SubAnim = 0, BtnHoverAnim = 0, DisabledAnim = 0, Callback = o.Callback, Half = o.Half, SameRow = o.SameRow, CustomWidth = o.CustomWidth, CustomOffset = o.CustomOffset, SetCallback = o.SetCallback, SetPopup = o.SetPopup }
        table.insert(Elements, el)
        return el
    end

    function windowObj:createcolorpicker(tabName, o)
        local stateKey = o.StateKey or o.Name
        if State[stateKey] == nil then
            if o.Default ~= nil then State[stateKey] = o.Default else State[stateKey] = Color3.new(1,1,1) end
        end
        
        local isConfigAdded = false
        for _, v in ipairs(ConfigKeys) do if v == stateKey then isConfigAdded = true break end end
        if not isConfigAdded then 
            table.insert(ConfigKeys, stateKey) 
            ColorKeys[stateKey] = true 
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
                if btn then
                    State.LastClickedPos = btn.UnscaledPos
                    State.LastClickedSize = btn.UnscaledSize
                end
                State.PopAlpha = 0
                State.PreviousPopup = o.Popup or "None"
                State.TargetPopup = "Color"
                ColorPicker.Target = stateKey
                ColorPicker.Color = State[stateKey]
                InputBuffers.Hex = toHex(State[stateKey]):gsub("#","")
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

    function windowObj:createtextlabel(tabName, text, col, popup)
        local bg = CreateSquare(true, Theme.BgBase, 0, 5, 0)
        local t = CreateText(text, 13, false, Theme.TextSub, 6)
        local el = { Bg = bg, Txt = t, Tab = (not popup) and tabName or nil, Popup = popup, Col = col or 1, Type = "TextLabel", BaseText = text }
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

    local DropShadows = {}
    local PopupShadows = {}
    local SHADOW_LAYERS = 12
    for i = 1, SHADOW_LAYERS do table.insert(DropShadows, CreateSquare(true, Color3.fromRGB(0, 0, 0), 0, 0, 24)) end
    for i = 1, SHADOW_LAYERS do table.insert(PopupShadows, CreateSquare(true, Color3.fromRGB(0, 0, 0), 0, 20, 24)) end

    local BaseBg = CreateSquare(true, Theme.BgBase, 1, 1, 24)
    local TopBar = CreateSquare(true, Theme.BgBase, 1, 2, 24)
    local ScrollTrack = CreateSquare(true, Theme.PanelBg, 0, 10, 8)
    local ScrollThumb = CreateSquare(true, Theme.Accent, 0, 11, 8)
    local MainTitle = CreateText(options.Title or "UI Lib by ok0f", 18, false, Theme.Accent, 3)
    local V2Text = CreateText(options.Version or "v1", 13, true, Theme.TextSub, 3)
    local V2TextShadow = CreateText(options.Version or "v1", 13, true, Color3.new(0, 0, 0), 2)

    local PopOverlay = CreateSquare(true, Color3.fromRGB(0,0,0), 0, 19, 0)
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
        local hdn = {"Color_PrevBg", "Color_PrevCol", "ColorR_Lbl", "ColorR_Bg", "ColorR_Fill", "ColorG_Lbl", "ColorG_Bg", "ColorG_Fill", "ColorB_Lbl", "ColorB_Bg", "ColorB_Fill", "Color_HexBg", "Color_HexTxt", "Color_ApplyBg", "Color_ApplyTxt", "Color_ResetBg", "Color_ResetTxt"}
        for _, n in ipairs(hdn) do if DrawCache[n] then DrawCache[n].Visible = false end end
    end

    local function hidePopSlid(slid)
        if not slid then return end
        slid.Bg.Visible = false; slid.FillBg.Visible = false; slid.Fill.Visible = false; slid.ValBg.Visible = false; slid.ValTxt.Visible = false; slid.Txt.Visible = false
    end

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
        
        if slashDown and not wasSlashDown then HeuristicTyping = true end
        if (returnDown and not wasReturnDown) or (escDown and not wasEscDown) then HeuristicTyping = false end
        
        wasSlashDown = slashDown
        wasReturnDown = returnDown
        wasEscDown = escDown

        local now = os.clock()
        if now - lastTypingCheck >= 0.2 then
            lastTypingCheck = now
            typingCache = false
            pcall(function()
                local tcs = game:GetService("TextChatService")
                if tcs and tcs:FindFirstChild("ChatInputBarConfiguration") then
                    if tcs.ChatInputBarConfiguration.IsFocused then typingCache = true end
                end
            end)
            if not typingCache then
                pcall(function()
                    local lp = game:GetService("Players").LocalPlayer
                    if lp and lp:FindFirstChild("PlayerGui") then
                        for _, v in ipairs(lp.PlayerGui:GetDescendants()) do
                            if v.ClassName == "TextBox" and v:IsFocused() then typingCache = true; break end
                        end
                    end
                end)
            end
        end
        return typingCache or HeuristicTyping
    end

    local lastUpdate = os.clock()
    local UIHidden = false

    Connection = RunService.Render:Connect(function()
        local ok, err = pcall(function()
            if _G.SevereSessionID ~= sessionID then
                if Connection then Connection:Disconnect() end
                for _, obj in pairs(DrawCache) do 
                pcall(function() obj:Remove() end) 
                end
                DrawCache = {}
                return
            end
            Camera = workspace.CurrentCamera
            if not Camera then return end

            local now = os.clock()
            local dt = math.min(now - lastUpdate, 0.05)
            lastUpdate = now
            
            local rawMPos = UIS:GetMouseLocation()
            local mPos = Vector2.new(rawMPos.X * State.DPIScale, rawMPos.Y * State.DPIScale)
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
                for i = 1, #GhostPositions do GhostPositions[i] = MenuPos end
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
                    if pressedKeys[i] == State.Keybind then
                        bindPressed = true
                        break
                    end
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
            MenuVelocity = Vector2.new(MenuPos.X - prevMenuPos.X, MenuPos.Y - prevMenuPos.Y)

            State.TabAlpha = ExpLerp(State.TabAlpha, State.NextTab and 0 or 1, dt, 24)
            if State.NextTab and State.TabAlpha < 0.05 then State.CurrentTab = State.NextTab; State.NextTab = nil end
            State.PopAlpha = ExpLerp(State.PopAlpha or 0, State.TargetPopup ~= "None" and 1 or 0, dt, 14)
            State.DropAlpha = ExpLerp(State.DropAlpha or 0, State.TargetDropdown and 1 or 0, dt, 18)
            if State.TargetPopup ~= "None" then State.ActivePopup = State.TargetPopup end
            if State.TargetDropdown then State.ActiveDropdown = State.TargetDropdown
            elseif (State.DropAlpha or 0) < 0.01 then State.ActiveDropdown = nil end

            if State.Visible and Focused then
                local lastPressed = (type(getpressedkey) == "function" and getpressedkey()) or ""
                if lastPressed == "" or lastPressed == "None" then
                    pcall(function()
                        local keys = UIS:GetKeysPressed()
                        if #keys > 0 then
                            lastPressed = keys[1].KeyCode.Name
                        end
                    end)
                end
                if lastPressed ~= "" and lastPressed ~= "None" then
                    local isNew = (lastPressed ~= LastKey)
                    if isNew then LastKey, RepeatTimer = lastPressed, now + 0.4 end

                    local char = ""
                    if #lastPressed == 1 then char = lastPressed 
                    elseif lastPressed == "Space" then char = " " 
                    elseif lastPressed == "Period" or lastPressed == "KeypadDot" then char = "." 
                    elseif lastPressed == "NumberSign" then char = "#" 
                    elseif lastPressed:match("^Number(%d)$") then char = lastPressed:sub(7,7) 
                    elseif lastPressed:match("^Keypad(%d)$") then char = lastPressed:sub(7,7) end
                    
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
                                if Focused == "Keybind" then State.Keybind = bindToSet
                                else if bindToSet == "Escape" or bindToSet == "Backspace" then State[Focused] = "None" else State[Focused] = bindToSet end end
                                Focused = nil
                            end
                        elseif lastPressed == "Backspace" then InputBuffers[Focused] = string.sub(InputBuffers[Focused], 1, -2)
                        elseif char ~= "" then
                            if Focused == "Red" or Focused == "Green" or Focused == "Blue" or Focused == "Alpha" then 
                                if char:match("%d") then InputBuffers[Focused] = InputBuffers[Focused] .. char end 
                            else 
                                InputBuffers[Focused] = InputBuffers[Focused] .. char 
                            end
                        end
                    end
                else LastKey = "" end
            end

            if State.IntroAlpha > 0.001 then
                UIHidden = false

                local currentSize = Vector2.new(MenuSize.X * State.UIScaleAnim, MenuSize.Y * State.UIScaleAnim)
                local bgPos = Vector2.new(
                    MenuPos.X + MenuSize.X / 2 - currentSize.X / 2,
                    MenuPos.Y + MenuSize.Y / 2 - currentSize.Y / 2 + State.UIYOffset
                )

                local uiTrans = math.clamp((not State.Transparent and 1 or State.UITrans) * State.IntroAlpha, 0, 1)
                local btnTrans = math.clamp((not State.Transparent and 1 or State.ButtonTrans) * State.IntroAlpha, 0, 1)
                local textAlpha = math.clamp((State.IntroAlpha - 0.15) * 1.176, 0, 1)

                local function sP(pos)
                    local relativeX = pos.X - MenuPos.X
                    local relativeY = pos.Y - MenuPos.Y
                    local scale = State.UIScaleAnim * globalScale
                    return vRound(Vector2.new(bgPos.X + relativeX * scale, bgPos.Y + relativeY * scale))
                end
                local function sS(size)
                    local scale = State.UIScaleAnim * globalScale
                    return vRound(Vector2.new(size.X * scale, size.Y * scale))
                end

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
                        local sSizeSpread = sS(Vector2.new(spread * 2, spread * 2))
                        shadow.Size = Vector2.new(currentSize.X + sSizeSpread.X, currentSize.Y + sSizeSpread.Y)
                        local sSpread = sS(Vector2.new(spread, spread))
                        local sOffset = sS(Vector2.new(0, 3))
                        shadow.Position = Vector2.new(bgPos.X - sSpread.X + sOffset.X, bgPos.Y - sSpread.Y + sOffset.Y)

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
                        if State.LightRippleOrigin and type(DrawingImmediate) ~= "nil" and type(DrawingImmediate.FilledCircle) == "function" then
                            DrawingImmediate.FilledCircle(State.LightRippleOrigin, rippleRadius, dynMain, State.IntroAlpha * uiTrans)
                        end
                    else
                        State.LightRippleActive = false
                    end
                end

                MainTitle.Visible = true
                MainTitle.Position = sP(Vector2.new(MenuPos.X + 15, MenuPosSorry, something went wrong. Please try your request again.
