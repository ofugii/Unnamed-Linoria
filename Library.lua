local InputService = game:GetService('UserInputService')
local TextService = game:GetService('TextService')
local CoreGui = game:GetService('CoreGui')
local Teams = game:GetService('Teams')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')

local RenderStepped = RunService.RenderStepped
local Heartbeat = RunService.Heartbeat
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
local ScreenGui = Instance.new('ScreenGui')
ProtectGui(ScreenGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = CoreGui

local Toggles = {}
local Options = {}
getgenv().Toggles = Toggles
getgenv().Options = Options

local CORNER = UDim.new(0, 6)
local CORNER_SM = UDim.new(0, 4)
local CORNER_LG = UDim.new(0, 8)
local CORNER_FULL = UDim.new(1, 0)

local Library = {
    Registry = {},
    RegistryMap = {},
    HudRegistry = {},
    FontColor = Color3.fromRGB(225, 225, 230),
    MainColor = Color3.fromRGB(25, 25, 30),
    BackgroundColor = Color3.fromRGB(18, 18, 22),
    AccentColor = Color3.fromRGB(114, 137, 218),
    OutlineColor = Color3.fromRGB(40, 40, 50),
    RiskColor = Color3.fromRGB(240, 71, 71),
    Black = Color3.new(0, 0, 0),
    SecondaryColor = Color3.fromRGB(35, 35, 42),
    HoverColor = Color3.fromRGB(48, 48, 58),
    DimTextColor = Color3.fromRGB(140, 140, 155),
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    FontSemibold = Enum.Font.GothamSemibold,
    OpenedFrames = {},
    DependencyBoxes = {},
    Signals = {},
    ScreenGui = ScreenGui,
    MinimizeKey = Enum.KeyCode.RightShift,
}

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0
        Hue = Hue + (1 / 400)
        if Hue > 1 then Hue = 0 end
        Library.CurrentRainbowHue = Hue
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1)
    end
end))

local function GetPlayersString()
    local List = Players:GetPlayers()
    for i = 1, #List do
        List[i] = List[i].Name
    end
    table.sort(List, function(a, b) return a < b end)
    return List
end

local function GetTeamsString()
    local List = Teams:GetTeams()
    for i = 1, #List do
        List[i] = List[i].Name
    end
    table.sort(List, function(a, b) return a < b end)
    return List
end

function Library:SafeCallback(f, ...)
    if not f then return end
    if not Library.NotifyOnError then return f(...) end
    local success, event = pcall(f, ...)
    if not success then
        local _, i = event:find(":%d+: ")
        if not i then return Library:Notify(event) end
        return Library:Notify(event:sub(i + 1), 3)
    end
end

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save()
    end
end

function Library:Create(Class, Properties)
    local Inst = Class
    if type(Class) == 'string' then
        Inst = Instance.new(Class)
    end
    for Property, Value in next, Properties do
        Inst[Property] = Value
    end
    return Inst
end

function Library:AddCorner(Inst, Radius)
    return Library:Create('UICorner', {
        CornerRadius = Radius or CORNER,
        Parent = Inst,
    })
end

function Library:AddStroke(Inst, Color, Thickness, Transparency)
    return Library:Create('UIStroke', {
        Color = Color or Library.OutlineColor,
        Thickness = Thickness or 1,
        Transparency = Transparency or 0,
        Parent = Inst,
    })
end

function Library:AddPadding(Inst, Top, Bottom, Left, Right)
    return Library:Create('UIPadding', {
        PaddingTop = UDim.new(0, Top or 0),
        PaddingBottom = UDim.new(0, Bottom or 0),
        PaddingLeft = UDim.new(0, Left or 0),
        PaddingRight = UDim.new(0, Right or 0),
        Parent = Inst,
    })
end

function Library:AddShadow(Inst, Transparency)
    return Library:Create('ImageLabel', {
        Name = 'Shadow',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 30, 1, 30),
        ZIndex = Inst.ZIndex - 1,
        Image = 'rbxassetid://6014261993',
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = Transparency or 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Parent = Inst,
    })
end

function Library:Tween(Inst, Props, Duration, Style, Direction)
    return TweenService:Create(
        Inst,
        TweenInfo.new(Duration or 0.15, Style or Enum.EasingStyle.Quint, Direction or Enum.EasingDirection.Out),
        Props
    ):Play()
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0),
        Thickness = 1,
        Transparency = 0.65,
        LineJoinMode = Enum.LineJoinMode.Round,
        Parent = Inst,
    })
end

function Library:CreateLabel(Properties, IsHud)
    local Inst = Library:Create('TextLabel', {
        BackgroundTransparency = 1,
        Font = Library.Font,
        TextColor3 = Library.FontColor,
        TextSize = 13,
        TextStrokeTransparency = 1,
    })
    Library:ApplyTextStroke(Inst)
    Library:AddToRegistry(Inst, { TextColor3 = 'FontColor' }, IsHud)
    return Library:Create(Inst, Properties)
end

function Library:MakeDraggable(Inst, Cutoff)
    Inst.Active = true
    local Dragging = false
    local DragStart, StartPos

    Inst.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            local Offset = Vector2.new(Mouse.X - Inst.AbsolutePosition.X, Mouse.Y - Inst.AbsolutePosition.Y)
            if Offset.Y > (Cutoff or 40) then return end
            Dragging = true
            DragStart = Input.Position
            StartPos = Inst.Position
            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    Dragging = false
                end
            end)
        end
    end)

    InputService.InputChanged:Connect(function(Input)
        if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
            local Delta = Input.Position - DragStart
            Library:Tween(Inst, {
                Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
            }, 0.04, Enum.EasingStyle.Quad)
        end
    end)
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 12)

    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        Size = UDim2.fromOffset(X + 16, Y + 10),
        ZIndex = 100,
        Parent = Library.ScreenGui,
        Visible = false,
    })
    Library:AddCorner(Tooltip, CORNER_SM)
    Library:AddStroke(Tooltip, Library.OutlineColor)
    Library:AddShadow(Tooltip, 0.7)

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(8, 4),
        Size = UDim2.fromOffset(X, Y),
        TextSize = 12,
        Text = InfoStr,
        TextColor3 = Library.DimTextColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 101,
        Parent = Tooltip,
    })

    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor' })
    Library:AddToRegistry(Label, { TextColor3 = 'DimTextColor' })

    local Hovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        Hovering = true
        Tooltip.Visible = true
        while Hovering do
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
            Heartbeat:Wait()
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        Hovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Inst, Props, DefaultProps)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Inst]
        for Property, ColorIdx in next, Props do
            Inst[Property] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx
            end
        end
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Inst]
        for Property, ColorIdx in next, DefaultProps do
            Inst[Property] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx
            end
        end
    end)
end

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local P, S = Frame.AbsolutePosition, Frame.AbsoluteSize
        if Mouse.X >= P.X and Mouse.X <= P.X + S.X and Mouse.Y >= P.Y and Mouse.Y <= P.Y + S.Y then
            return true
        end
    end
    return false
end

function Library:IsMouseOverFrame(Frame)
    if not Frame then return false end
    local P, S = Frame.AbsolutePosition, Frame.AbsoluteSize
    return Mouse.X >= P.X and Mouse.X <= P.X + S.X and Mouse.Y >= P.Y and Mouse.Y <= P.Y + S.Y
end

function Library:UpdateDependencyBoxes()
    for _, Box in next, Library.DependencyBoxes do
        Box:Update()
    end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color)
    return Color3.fromHSV(H, S, V / 1.5)
end

Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

function Library:AddToRegistry(Inst, Properties, IsHud)
    local Data = {
        Instance = Inst,
        Properties = Properties,
        Idx = #Library.Registry + 1,
    }
    table.insert(Library.Registry, Data)
    Library.RegistryMap[Inst] = Data
    if IsHud then
        table.insert(Library.HudRegistry, Data)
    end
end

function Library:RemoveFromRegistry(Inst)
    local Data = Library.RegistryMap[Inst]
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx)
            end
        end
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx)
            end
        end
        Library.RegistryMap[Inst] = nil
    end
end

function Library:UpdateColorsUsingRegistry()
    for _, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx]
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
end

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Conn = table.remove(Library.Signals, Idx)
        if Conn then Conn:Disconnect() end
    end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy()
end

function Library:SetOnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Inst)
    if Library.RegistryMap[Inst] then
        Library:RemoveFromRegistry(Inst)
    end
end))

function Library:Notify(Text, Duration)
    Duration = Duration or 5

    local Holder = Library.ScreenGui:FindFirstChild('NotifyHolder')
    if not Holder then
        Holder = Library:Create('Frame', {
            Name = 'NotifyHolder',
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -20, 1, -20),
            Size = UDim2.new(0, 320, 1, -40),
            AnchorPoint = Vector2.new(1, 1),
            ZIndex = 200,
            Parent = Library.ScreenGui,
        })
        Library:Create('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
            Parent = Holder,
        })
    end

    local X, _ = Library:GetTextBounds(Text, Library.Font, 12, Vector2.new(280, math.huge))
    local Width = math.clamp(X + 36, 160, 320)

    local Frame = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        Size = UDim2.fromOffset(Width, 0),
        ClipsDescendants = true,
        ZIndex = 201,
        Parent = Holder,
    })
    Library:AddCorner(Frame, CORNER)
    Library:AddStroke(Frame, Library.OutlineColor)
    Library:AddShadow(Frame, 0.6)

    Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        Size = UDim2.new(0, 3, 1, 0),
        BorderSizePixel = 0,
        ZIndex = 203,
        Parent = Frame,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -24, 1, 0),
        TextSize = 12,
        Text = Text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202,
        Parent = Frame,
    })

    Library:AddToRegistry(Frame, { BackgroundColor3 = 'MainColor' })

    task.wait()
    local Height = math.max(Label.TextBounds.Y + 20, 36)
    Library:Tween(Frame, { Size = UDim2.fromOffset(Width, Height) }, 0.3)

    task.delay(Duration, function()
        Library:Tween(Frame, { Size = UDim2.fromOffset(Width, 0) }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.27)
        Frame:Destroy()
    end)
end

local BaseAddons = {}

do
    local Funcs = {}

    function Funcs:AddColorPicker(Idx, Info)
        assert(Info.Default, 'AddColorPicker: Missing default value.')

        local ColorPicker = {
            Value = Info.Default,
            Type = 'ColorPicker',
            Title = Info.Title or 'Color Picker',
            Transparency = Info.Transparency,
            Callback = Info.Callback or function() end,
        }

        if Info.Transparency then
            ColorPicker.TransparencyValue = 0
        end

        local H, S, V = Color3.toHSV(Info.Default)

        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Library.SecondaryColor,
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.new(1, -20, 0, 1),
            ZIndex = 6,
            Parent = self.TextLabel and self.TextLabel.Parent or self.Container,
        })
        Library:AddCorner(Outer, CORNER_SM)
        Library:AddStroke(Outer, Library.OutlineColor)
        Library:AddToRegistry(Outer, { BackgroundColor3 = 'SecondaryColor' })

        local Display = Library:Create('Frame', {
            BackgroundColor3 = Info.Default,
            Size = UDim2.new(1, -6, 1, -6),
            Position = UDim2.fromOffset(3, 3),
            ZIndex = 7,
            Parent = Outer,
        })
        Library:AddCorner(Display, UDim.new(0, 3))

        local PickerFrame = Library:Create('Frame', {
            Name = 'Picker_' .. Idx,
            BackgroundColor3 = Library.BackgroundColor,
            Size = UDim2.fromOffset(220, Info.Transparency and 230 or 200),
            ZIndex = 50,
            Visible = false,
            Parent = Library.ScreenGui,
        })
        Library:AddCorner(PickerFrame, CORNER)
        Library:AddStroke(PickerFrame, Library.OutlineColor)
        Library:AddShadow(PickerFrame, 0.5)
        Library:AddToRegistry(PickerFrame, { BackgroundColor3 = 'BackgroundColor' })

        local SVCanvas = Library:Create('ImageLabel', {
            BackgroundColor3 = Color3.fromHSV(H, 1, 1),
            Size = UDim2.new(1, -52, 0, 150),
            Position = UDim2.fromOffset(10, 10),
            Image = 'rbxassetid://4155801252',
            ZIndex = 51,
            Parent = PickerFrame,
        })
        Library:AddCorner(SVCanvas, CORNER_SM)

        Library:Create('ImageLabel', {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = 'rbxassetid://4155801252',
            ImageColor3 = Color3.new(0, 0, 0),
            ZIndex = 52,
            Parent = SVCanvas,
        })

        local HueBar = Library:Create('ImageLabel', {
            BackgroundColor3 = Color3.new(1, 1, 1),
            Size = UDim2.new(0, 22, 0, 150),
            Position = UDim2.new(1, -32, 0, 10),
            Image = 'rbxassetid://3641079629',
            ZIndex = 51,
            Parent = PickerFrame,
        })
        Library:AddCorner(HueBar, CORNER_SM)

        local SVCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1),
            Size = UDim2.fromOffset(8, 8),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(S, 1 - V),
            ZIndex = 54,
            Parent = SVCanvas,
        })
        Library:AddCorner(SVCursor, CORNER_FULL)
        Library:AddStroke(SVCursor, Color3.new(0, 0, 0), 1.5)

        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1),
            Size = UDim2.new(1, 4, 0, 4),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, H, 0),
            ZIndex = 53,
            Parent = HueBar,
        })
        Library:AddCorner(HueCursor, UDim.new(0, 2))
        Library:AddStroke(HueCursor, Color3.new(0, 0, 0))

        local TransparencyBar, TransparencyCursor
        if Info.Transparency then
            TransparencyBar = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1),
                Size = UDim2.new(1, -20, 0, 14),
                Position = UDim2.new(0, 10, 0, 168),
                ZIndex = 51,
                Parent = PickerFrame,
            })
            Library:AddCorner(TransparencyBar, CORNER_SM)

            Library:Create('UIGradient', {
                Color = ColorSequence.new(Info.Default, Info.Default),
                Transparency = NumberSequence.new(0, 1),
                Parent = TransparencyBar,
            })

            TransparencyCursor = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1),
                Size = UDim2.new(0, 4, 1, 4),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                ZIndex = 53,
                Parent = TransparencyBar,
            })
            Library:AddCorner(TransparencyCursor, UDim.new(0, 2))
            Library:AddStroke(TransparencyCursor, Color3.new(0, 0, 0))
        end

        local HexBox = Library:Create('TextBox', {
            BackgroundColor3 = Library.SecondaryColor,
            PlaceholderText = '#FFFFFF',
            Text = '#' .. Info.Default:ToHex(),
            TextColor3 = Library.FontColor,
            PlaceholderColor3 = Library.DimTextColor,
            Font = Library.Font,
            TextSize = 11,
            Size = UDim2.new(1, -20, 0, 24),
            Position = UDim2.new(0, 10, 1, -34),
            ZIndex = 51,
            ClearTextOnFocus = false,
            Parent = PickerFrame,
        })
        Library:AddCorner(HexBox, CORNER_SM)
        Library:AddStroke(HexBox, Library.OutlineColor)
        Library:AddPadding(HexBox, 0, 0, 6, 6)
        Library:AddToRegistry(HexBox, { BackgroundColor3 = 'SecondaryColor', TextColor3 = 'FontColor' })

        local function UpdateColor()
            ColorPicker.Value = Color3.fromHSV(H, S, V)
            Display.BackgroundColor3 = ColorPicker.Value
            SVCanvas.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
            SVCursor.Position = UDim2.fromScale(S, 1 - V)
            HueCursor.Position = UDim2.new(0.5, 0, H, 0)
            HexBox.Text = '#' .. ColorPicker.Value:ToHex()
            if Info.Transparency and TransparencyBar then
                local Grad = TransparencyBar:FindFirstChildOfClass('UIGradient')
                if Grad then
                    Grad.Color = ColorSequence.new(ColorPicker.Value, ColorPicker.Value)
                end
                TransparencyCursor.Position = UDim2.new(ColorPicker.TransparencyValue, 0, 0.5, 0)
            end
            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
        end

        local DraggingSV, DraggingHue, DraggingTransparency = false, false, false

        SVCanvas.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                DraggingSV = true
            end
        end)

        HueBar.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                DraggingHue = true
            end
        end)

        if TransparencyBar then
            TransparencyBar.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    DraggingTransparency = true
                end
            end)
        end

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                DraggingSV = false
                DraggingHue = false
                DraggingTransparency = false
                Library:AttemptSave()
            end
        end))

        Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseMovement then
                if DraggingSV then
                    S = math.clamp((Mouse.X - SVCanvas.AbsolutePosition.X) / SVCanvas.AbsoluteSize.X, 0, 1)
                    V = 1 - math.clamp((Mouse.Y - SVCanvas.AbsolutePosition.Y) / SVCanvas.AbsoluteSize.Y, 0, 1)
                    UpdateColor()
                elseif DraggingHue then
                    H = math.clamp((Mouse.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
                    UpdateColor()
                elseif DraggingTransparency and TransparencyBar then
                    ColorPicker.TransparencyValue = math.clamp((Mouse.X - TransparencyBar.AbsolutePosition.X) / TransparencyBar.AbsoluteSize.X, 0, 1)
                    UpdateColor()
                end
            end
        end))

        HexBox.FocusLost:Connect(function()
            local Hex = HexBox.Text:gsub('#', '')
            local Ok, Col = pcall(Color3.fromHex, '#' .. Hex)
            if Ok then
                H, S, V = Color3.toHSV(Col)
                UpdateColor()
            else
                HexBox.Text = '#' .. ColorPicker.Value:ToHex()
            end
        end)

        local PickerOpen = false
        Outer.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                PickerOpen = not PickerOpen
                PickerFrame.Visible = PickerOpen
                if PickerOpen then
                    PickerFrame.Position = UDim2.fromOffset(Outer.AbsolutePosition.X - 200, Outer.AbsolutePosition.Y + 24)
                    Library.OpenedFrames[PickerFrame] = true
                else
                    Library.OpenedFrames[PickerFrame] = nil
                end
            end
        end)

        function ColorPicker:SetValue(NewColor)
            H, S, V = Color3.toHSV(NewColor)
            UpdateColor()
        end

        function ColorPicker:SetValueRGB(R, G, B)
            ColorPicker:SetValue(Color3.fromRGB(R, G, B))
        end

        function ColorPicker:OnChanged(Fn)
            ColorPicker.Callback = Fn
        end

        Options[Idx] = ColorPicker
        return ColorPicker
    end

    function Funcs:AddKeyPicker(Idx, Info)
        local KeyPicker = {
            Value = Info.Default,
            Type = 'KeyPicker',
            Mode = Info.Mode or 'Toggle',
            SyncToggleState = Info.SyncToggleState or false,
            Callback = Info.Callback or function() end,
            ChangedCallback = Info.ChangedCallback or function() end,
        }

        local IsActive = false
        local Picking = false

        local KeyDisplay = Library:Create('TextButton', {
            BackgroundColor3 = Library.SecondaryColor,
            Size = UDim2.fromOffset(48, 20),
            Position = UDim2.new(1, -48, 0, 1),
            Text = '[' .. (Info.Default and Info.Default.Name or 'None') .. ']',
            TextColor3 = Library.DimTextColor,
            Font = Library.Font,
            TextSize = 11,
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = self.TextLabel and self.TextLabel.Parent or self.Container,
        })
        Library:AddCorner(KeyDisplay, CORNER_SM)
        Library:AddToRegistry(KeyDisplay, { BackgroundColor3 = 'SecondaryColor', TextColor3 = 'DimTextColor' })

        KeyDisplay.MouseButton1Click:Connect(function()
            Picking = true
            KeyDisplay.Text = '[...]'
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input, GameProcessed)
            if Picking then
                local Key
                if Input.UserInputType == Enum.UserInputType.Keyboard then
                    Key = Input.KeyCode
                elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Key = Enum.UserInputType.MouseButton1
                elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                    Key = Enum.UserInputType.MouseButton2
                end
                if Key then
                    Picking = false
                    KeyPicker.Value = Key
                    KeyDisplay.Text = '[' .. (Key.Name or tostring(Key)) .. ']'
                    Library:SafeCallback(KeyPicker.ChangedCallback, Key)
                end
                return
            end
            if not GameProcessed and KeyPicker.Value then
                local Match = false
                if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == KeyPicker.Value then
                    Match = true
                elseif Input.UserInputType == KeyPicker.Value then
                    Match = true
                end
                if Match then
                    if KeyPicker.Mode == 'Toggle' then
                        IsActive = not IsActive
                    elseif KeyPicker.Mode == 'Hold' then
                        IsActive = true
                    end
                    Library:SafeCallback(KeyPicker.Callback, IsActive)
                end
            end
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if KeyPicker.Mode == 'Hold' and KeyPicker.Value then
                local Match = false
                if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == KeyPicker.Value then
                    Match = true
                elseif Input.UserInputType == KeyPicker.Value then
                    Match = true
                end
                if Match then
                    IsActive = false
                    Library:SafeCallback(KeyPicker.Callback, IsActive)
                end
            end
        end))

        function KeyPicker:GetState()
            return IsActive
        end

        function KeyPicker:SetValue(NewKey)
            KeyPicker.Value = NewKey
            KeyDisplay.Text = '[' .. (NewKey and NewKey.Name or 'None') .. ']'
        end

        function KeyPicker:OnChanged(Fn)
            KeyPicker.ChangedCallback = Fn
        end

        Options[Idx] = KeyPicker
        return KeyPicker
    end

    BaseAddons.__index = Funcs
end

function Library:CreateWindow(Config)
    assert(Config.Title, 'CreateWindow: Title required.')

    local WinConfig = {
        Title = Config.Title,
        Center = Config.Center or false,
        AutoShow = Config.AutoShow or false,
        TabPadding = Config.TabPadding or 0,
        MenuFadeTime = Config.MenuFadeTime or 0.2,
        Size = Config.Size or UDim2.fromOffset(560, 420),
    }

    local Window = {
        Tabs = {},
        TabCount = 0,
    }

    local MainFrame = Library:Create('Frame', {
        Name = 'Window',
        BackgroundColor3 = Library.BackgroundColor,
        Size = WinConfig.Size,
        Position = WinConfig.Center and UDim2.new(0.5, -(WinConfig.Size.X.Offset / 2), 0.5, -(WinConfig.Size.Y.Offset / 2)) or UDim2.fromOffset(100, 100),
        ClipsDescendants = true,
        Parent = ScreenGui,
    })
    Library:AddCorner(MainFrame, CORNER_LG)
    Library:AddStroke(MainFrame, Library.OutlineColor)
    Library:AddShadow(MainFrame, 0.35)
    Library:AddToRegistry(MainFrame, { BackgroundColor3 = 'BackgroundColor' })
    Library:MakeDraggable(MainFrame, 38)

    local TitleBar = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        Size = UDim2.new(1, 0, 0, 38),
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = MainFrame,
    })
    Library:AddCorner(TitleBar, CORNER_LG)
    Library:AddToRegistry(TitleBar, { BackgroundColor3 = 'MainColor' })

    Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = TitleBar,
    })

    Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = TitleBar,
    })

    Library:CreateLabel({
        Text = WinConfig.Title,
        Font = Library.FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -80, 1, 0),
        ZIndex = 6,
        Parent = TitleBar,
    })

    local MinBtn = Library:Create('TextButton', {
        BackgroundTransparency = 1,
        Text = '—',
        TextColor3 = Library.DimTextColor,
        Font = Library.FontBold,
        TextSize = 16,
        Size = UDim2.fromOffset(38, 38),
        Position = UDim2.new(1, -38, 0, 0),
        ZIndex = 6,
        AutoButtonColor = false,
        Parent = TitleBar,
    })
    Library:AddToRegistry(MinBtn, { TextColor3 = 'DimTextColor' })

    local TabHolder = Library:Create('ScrollingFrame', {
        BackgroundColor3 = Library.MainColor,
        Size = UDim2.new(0, 145, 1, -40),
        Position = UDim2.fromOffset(0, 40),
        ScrollBarThickness = 0,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 4,
        Parent = MainFrame,
    })
    Library:AddToRegistry(TabHolder, { BackgroundColor3 = 'MainColor' })
    Library:AddPadding(TabHolder, 8, 8, 8, 8)

    Library:Create('UIListLayout', {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = TabHolder,
    })

    Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor,
        Size = UDim2.new(0, 1, 1, -40),
        Position = UDim2.fromOffset(145, 40),
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = MainFrame,
    })

    local ContentArea = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -145, 1, -40),
        Position = UDim2.fromOffset(145, 40),
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = MainFrame,
    })

    local Minimized = false
    local OrigSize = WinConfig.Size

    MinBtn.MouseButton1Click:Connect(function()
        Minimized = not Minimized
        if Minimized then
            Library:Tween(MainFrame, { Size = UDim2.new(OrigSize.X.Scale, OrigSize.X.Offset, 0, 38) }, 0.25)
            MinBtn.Text = '+'
        else
            Library:Tween(MainFrame, { Size = OrigSize }, 0.25)
            MinBtn.Text = '—'
        end
    end)

    local Hidden = not WinConfig.AutoShow
    MainFrame.Visible = not Hidden

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if Processed then return end
        if Input.KeyCode == Library.MinimizeKey then
            Hidden = not Hidden
            if Hidden then
                Library:Tween(MainFrame, { Size = UDim2.fromOffset(MainFrame.Size.X.Offset, 0) }, WinConfig.MenuFadeTime, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                task.delay(WinConfig.MenuFadeTime, function() MainFrame.Visible = false end)
            else
                MainFrame.Visible = true
                MainFrame.Size = UDim2.fromOffset(OrigSize.X.Offset, 0)
                Library:Tween(MainFrame, { Size = OrigSize }, WinConfig.MenuFadeTime)
            end
        end
    end))

    function Window:AddTab(Name)
        local Tab = {
            Name = Name,
            Groupboxes = {},
            GroupboxCount = 0,
        }

        Window.TabCount = Window.TabCount + 1

        local TabBtn = Library:Create('TextButton', {
            BackgroundColor3 = Library.SecondaryColor,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            Text = Name,
            TextColor3 = Library.DimTextColor,
            Font = Library.FontSemibold,
            TextSize = 12,
            AutoButtonColor = false,
            ZIndex = 5,
            LayoutOrder = Window.TabCount,
            Parent = TabHolder,
        })
        Library:AddCorner(TabBtn, CORNER_SM)
        Library:AddToRegistry(TabBtn, { TextColor3 = 'DimTextColor' })

        local TabFrame = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.AccentColor,
            Visible = false,
            ZIndex = 4,
            Parent = ContentArea,
        })
        Library:AddPadding(TabFrame, 10, 10, 10, 10)

        local LeftColumn = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -4, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = TabFrame,
        })

        Library:Create('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = LeftColumn,
        })

        local RightColumn = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -4, 0, 0),
            Position = UDim2.new(0.5, 4, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = TabFrame,
        })

        Library:Create('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = RightColumn,
        })

        local function SelectTab()
            for _, T in next, Window.Tabs do
                T.Button.BackgroundTransparency = 1
                T.Button.TextColor3 = Library.DimTextColor
                T.Frame.Visible = false
                local Reg = Library.RegistryMap[T.Button]
                if Reg then
                    Reg.Properties.TextColor3 = 'DimTextColor'
                end
            end
            TabBtn.BackgroundTransparency = 0
            TabBtn.BackgroundColor3 = Library.AccentColor
            TabBtn.TextColor3 = Library.FontColor
            TabFrame.Visible = true
            local Reg = Library.RegistryMap[TabBtn]
            if Reg then
                Reg.Properties.TextColor3 = 'FontColor'
                Reg.Properties.BackgroundColor3 = 'AccentColor'
            end
        end

        TabBtn.MouseButton1Click:Connect(SelectTab)

        Tab.Button = TabBtn
        Tab.Frame = TabFrame
        Tab.LeftColumn = LeftColumn
        Tab.RightColumn = RightColumn
        Window.Tabs[Name] = Tab

        if Window.TabCount == 1 then
            SelectTab()
        end

        function Tab:AddLeftGroupbox(Name)
            return Tab:_AddGroupbox(Name, LeftColumn)
        end

        function Tab:AddRightGroupbox(Name)
            return Tab:_AddGroupbox(Name, RightColumn)
        end

        function Tab:_AddGroupbox(Name, Column)
            Tab.GroupboxCount = Tab.GroupboxCount + 1

            local Groupbox = { Name = Name }
            setmetatable(Groupbox, BaseAddons)

            local GroupFrame = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = Tab.GroupboxCount,
                Parent = Column,
            })
            Library:AddCorner(GroupFrame, CORNER)
            Library:AddStroke(GroupFrame, Library.OutlineColor)
            Library:AddToRegistry(GroupFrame, { BackgroundColor3 = 'MainColor' })

            local AccentLine = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor,
                Size = UDim2.new(1, 0, 0, 2),
                BorderSizePixel = 0,
                ZIndex = 6,
                Parent = GroupFrame,
            })
            Library:AddCorner(AccentLine, UDim.new(0, 1))
            Library:AddToRegistry(AccentLine, { BackgroundColor3 = 'AccentColor' })

            Library:CreateLabel({
                Text = '  ' .. Name,
                Font = Library.FontBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, -16, 0, 30),
                Position = UDim2.fromOffset(8, 2),
                ZIndex = 5,
                Parent = GroupFrame,
            })

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -16, 0, 0),
                Position = UDim2.fromOffset(8, 34),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = GroupFrame,
            })

            Library:Create('UIListLayout', {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 5),
                Parent = Container,
            })

            Library:Create('UIPadding', {
                PaddingBottom = UDim.new(0, 10),
                Parent = Container,
            })

            Groupbox.Container = Container
            Groupbox.Frame = GroupFrame
            table.insert(Tab.Groupboxes, Groupbox)

            function Groupbox:AddToggle(Idx, Info)
                Info = Info or {}
                local Toggle = {
                    Value = Info.Default or false,
                    Type = 'Toggle',
                    Callback = Info.Callback or function() end,
                    Addons = {},
                }
                setmetatable(Toggle, BaseAddons)

                local Outer = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 22),
                    LayoutOrder = #Container:GetChildren(),
                    Parent = Container,
                })

                local Box = Library:Create('Frame', {
                    BackgroundColor3 = Library.SecondaryColor,
                    Size = UDim2.fromOffset(18, 18),
                    Position = UDim2.fromOffset(0, 2),
                    ZIndex = 5,
                    Parent = Outer,
                })
                Library:AddCorner(Box, CORNER_SM)
                Library:AddStroke(Box, Library.OutlineColor)
                Library:AddToRegistry(Box, { BackgroundColor3 = 'SecondaryColor' })

                local Check = Library:Create('TextLabel', {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    Text = '✓',
                    TextColor3 = Library.AccentColor,
                    Font = Library.FontBold,
                    TextSize = 14,
                    TextTransparency = (Info.Default and 0 or 1),
                    ZIndex = 6,
                    Parent = Box,
                })
                Library:AddToRegistry(Check, { TextColor3 = 'AccentColor' })

                local Label = Library:CreateLabel({
                    Text = Info.Text or Idx,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Position = UDim2.fromOffset(26, 2),
                    Size = UDim2.new(1, -70, 0, 18),
                    ZIndex = 5,
                    Parent = Outer,
                })

                Toggle.TextLabel = Label
                Toggle.Container = Outer

                local function SetState(State)
                    Toggle.Value = State
                    Library:Tween(Check, { TextTransparency = State and 0 or 1 }, 0.12)
                    Library:Tween(Box, { BackgroundColor3 = State and Library:GetDarkerColor(Library.AccentColor) or Library.SecondaryColor }, 0.12)
                    Library:SafeCallback(Toggle.Callback, State)
                end

                local Btn = Library:Create('TextButton', {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    Text = '',
                    ZIndex = 7,
                    Parent = Outer,
                })

                Btn.MouseButton1Click:Connect(function()
                    SetState(not Toggle.Value)
                    Library:AttemptSave()
                    Library:UpdateDependencyBoxes()
                end)

                if Info.Tooltip then
                    Library:AddToolTip(Info.Tooltip, Outer)
                end

                function Toggle:SetValue(Val)
                    SetState(Val)
                    Library:UpdateDependencyBoxes()
                end

                function Toggle:OnChanged(Fn)
                    Toggle.Callback = Fn
                end

                Toggles[Idx] = Toggle
                Library:UpdateDependencyBoxes()
                return Toggle
            end

            function Groupbox:AddSlider(Idx, Info)
                Info = Info or {}
                local Slider = {
                    Value = Info.Default or Info.Min or 0,
                    Min = Info.Min or 0,
                    Max = Info.Max or 100,
                    Rounding = Info.Rounding or 1,
                    Suffix = Info.Suffix or '',
                    Type = 'Slider',
                    Callback = Info.Callback or function() end,
                    Compact = Info.Compact or false,
                }

                local Outer = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, Slider.Compact and 20 or 34),
                    LayoutOrder = #Container:GetChildren(),
                    Parent = Container,
                })

                if not Slider.Compact then
                    Library:CreateLabel({
                        Text = Info.Text or Idx,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 14),
                        ZIndex = 5,
                        Parent = Outer,
                    })
                end

                local Bar = Library:Create('Frame', {
                    BackgroundColor3 = Library.SecondaryColor,
                    Size = UDim2.new(1, 0, 0, 14),
                    Position = UDim2.fromOffset(0, Slider.Compact and 3 or 18),
                    ZIndex = 5,
                    Parent = Outer,
                })
                Library:AddCorner(Bar, UDim.new(0, 7))
                Library:AddToRegistry(Bar, { BackgroundColor3 = 'SecondaryColor' })

                local Fill = Library:Create('Frame', {
                    BackgroundColor3 = Library.AccentColor,
                    Size = UDim2.fromScale(0, 1),
                    ZIndex = 6,
                    Parent = Bar,
                })
                Library:AddCorner(Fill, UDim.new(0, 7))
                Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' })

                local Knob = Library:Create('Frame', {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Size = UDim2.fromOffset(10, 10),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    ZIndex = 8,
                    Parent = Bar,
                })
                Library:AddCorner(Knob, CORNER_FULL)
                Library:AddStroke(Knob, Library.OutlineColor)

                local ValLabel = Library:CreateLabel({
                    Text = '',
                    TextSize = 10,
                    Size = UDim2.fromScale(1, 1),
                    ZIndex = 7,
                    Parent = Bar,
                })

                local function Round(Val, To)
                    if To == 0 then return Val end
                    return math.floor(Val / To + 0.5) * To
                end

                local function SetValue(Val)
                    Val = math.clamp(Round(Val, Slider.Rounding), Slider.Min, Slider.Max)
                    Slider.Value = Val
                    local Pct = (Val - Slider.Min) / (Slider.Max - Slider.Min)
                    Library:Tween(Fill, { Size = UDim2.new(Pct, 0, 1, 0) }, 0.06, Enum.EasingStyle.Quad)
                    Library:Tween(Knob, { Position = UDim2.new(Pct, 0, 0.5, 0) }, 0.06, Enum.EasingStyle.Quad)
                    ValLabel.Text = (Slider.Compact and (Info.Text or Idx) .. ': ' or '') .. tostring(Val) .. Slider.Suffix
                    Library:SafeCallback(Slider.Callback, Val)
                end

                SetValue(Slider.Value)

                local Dragging = false

                Bar.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Dragging = true
                        local Pct = math.clamp((Mouse.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                        SetValue(Slider.Min + (Slider.Max - Slider.Min) * Pct)
                    end
                end)

                Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
                    if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
                        local Pct = math.clamp((Mouse.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                        SetValue(Slider.Min + (Slider.Max - Slider.Min) * Pct)
                    end
                end))

                Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Dragging = false
                        Library:AttemptSave()
                    end
                end))

                if Info.Tooltip then
                    Library:AddToolTip(Info.Tooltip, Outer)
                end

                function Slider:SetValue(Val)
                    SetValue(Val)
                end

                function Slider:OnChanged(Fn)
                    Slider.Callback = Fn
                end

                Options[Idx] = Slider
                return Slider
            end

            function Groupbox:AddButton(Info)
                Info = Info or {}

                local BtnFrame = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 28),
                    LayoutOrder = #Container:GetChildren(),
                    Parent = Container,
                })

                local Btn = Library:Create('TextButton', {
                    BackgroundColor3 = Library.SecondaryColor,
                    Size = UDim2.fromScale(1, 1),
                    Text = Info.Text or 'Button',
                    TextColor3 = Library.FontColor,
                    Font = Library.FontSemibold,
                    TextSize = 12,
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = BtnFrame,
                })
                Library:AddCorner(Btn, CORNER_SM)
                Library:AddStroke(Btn, Library.OutlineColor)
                Library:AddToRegistry(Btn, { BackgroundColor3 = 'SecondaryColor', TextColor3 = 'FontColor' })

                Library:OnHighlight(Btn, Btn, { BackgroundColor3 = 'HoverColor' }, { BackgroundColor3 = 'SecondaryColor' })

                Btn.MouseButton1Click:Connect(function()
                    Library:Tween(Btn, { BackgroundColor3 = Library.AccentColor }, 0.08)
                    task.delay(0.12, function()
                        Library:Tween(Btn, { BackgroundColor3 = Library.SecondaryColor }, 0.12)
                    end)
                    Library:SafeCallback(Info.Func)
                end)

                if Info.DoubleClick then
                    local Last = 0
                    Btn.MouseButton1Click:Connect(function()
                        if tick() - Last < 0.35 then
                            Library:SafeCallback(Info.DoubleClickFunc or Info.Func)
                        end
                        Last = tick()
                    end)
                end

                if Info.Tooltip then
                    Library:AddToolTip(Info.Tooltip, Btn)
                end

                local BtnObj = {}

                function BtnObj:AddSubButton(SubInfo)
                    SubInfo = SubInfo or {}

                    local SubFrame = Library:Create('Frame', {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 28),
                        LayoutOrder = #Container:GetChildren(),
                        Parent = Container,
                    })

                    local SubBtn = Library:Create('TextButton', {
                        BackgroundColor3 = Library.SecondaryColor,
                        Size = UDim2.new(1, -16, 1, 0),
                        Position = UDim2.fromOffset(16, 0),
                        Text = SubInfo.Text or 'Sub Button',
                        TextColor3 = Library.FontColor,
                        Font = Library.Font,
                        TextSize = 12,
                        AutoButtonColor = false,
                        ZIndex = 5,
                        Parent = SubFrame,
                    })
                    Library:AddCorner(SubBtn, CORNER_SM)
                    Library:AddStroke(SubBtn, Library.OutlineColor)
                    Library:AddToRegistry(SubBtn, { BackgroundColor3 = 'SecondaryColor', TextColor3 = 'FontColor' })
                    Library:OnHighlight(SubBtn, SubBtn, { BackgroundColor3 = 'HoverColor' }, { BackgroundColor3 = 'SecondaryColor' })

                    SubBtn.MouseButton1Click:Connect(function()
                        Library:Tween(SubBtn, { BackgroundColor3 = Library.AccentColor }, 0.08)
                        task.delay(0.12, function()
                            Library:Tween(SubBtn, { BackgroundColor3 = Library.SecondaryColor }, 0.12)
                        end)
                        Library:SafeCallback(SubInfo.Func)
                    end)

                    return SubFrame
                end

                return BtnObj
            end

            function Groupbox:AddLabel(Text, DoesWrap)
                local Label = Library:CreateLabel({
                    Text = Text or '',
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = DoesWrap or false,
                    Size = UDim2.new(1, 0, 0, DoesWrap and 0 or 16),
                    AutomaticSize = DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
                    LayoutOrder = #Container:GetChildren(),
                    Parent = Container,
                })

                local Obj = { Label = Label }
                function Obj:SetText(NewText)
                    Label.Text = NewText
                end
                return Obj
            end

            function Groupbox:AddDivider()
                local Div = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 10),
                    LayoutOrder = #Container:GetChildren(),
                    Parent = Container,
                })
                Library:Create('Frame', {
                    BackgroundColor3 = Library.OutlineColor,
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.fromScale(0, 0.5),
                    BorderSizePixel = 0,
                    Parent = Div,
                })
                return Div
            end

            function Groupbox:AddInput(Idx, Info)
                Info = Info or {}
                local Textbox = {
                    Value = Info.Default or '',
                    Type = 'Input',
                    Callback = Info.Callback or function() end,
                }

                local Outer = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, Info.Text and 38 or 24),
                    LayoutOrder = #Container:GetChildren(),
                    Parent = Container,
                })

                if Info.Text then
                    Library:CreateLabel({
                        Text = Info.Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 14),
                        ZIndex = 5,
                        Parent = Outer,
                    })
                end

                local InputBox = Library:Create('TextBox', {
                    BackgroundColor3 = Library.SecondaryColor,
                    Size = UDim2.new(1, 0, 0, 24),
                    Position = UDim2.fromOffset(0, Info.Text and 16 or 0),
                    Text = Info.Default or '',
                    PlaceholderText = Info.Placeholder or 'Type here...',
                    TextColor3 = Library.FontColor,
                    PlaceholderColor3 = Library.DimTextColor,
                    Font = Library.Font,
                    TextSize = 12,
                    ClearTextOnFocus = false,
                    ZIndex = 5,
                    Parent = Outer,
                })
                Library:AddCorner(InputBox, CORNER_SM)
                Library:AddStroke(InputBox, Library.OutlineColor)
                Library:AddPadding(InputBox, 0, 0, 8, 8)
                Library:AddToRegistry(InputBox, { BackgroundColor3 = 'SecondaryColor', TextColor3 = 'FontColor', PlaceholderColor3 = 'DimTextColor' })

                if Info.Numeric then
                    InputBox:GetPropertyChangedSignal('Text'):Connect(function()
                        local Filtered = InputBox.Text:gsub('[^%d%.%-]', '')
                        if InputBox.Text ~= Filtered then
                            InputBox.Text = Filtered
                        end
                    end)
                end

                if Info.MaxLength then
                    InputBox:GetPropertyChangedSignal('Text'):Connect(function()
                        if #InputBox.Text > Info.MaxLength then
                            InputBox.Text = InputBox.Text:sub(1, Info.MaxLength)
                        end
                    end)
                end

                if Info.Finished then
                    InputBox.FocusLost:Connect(function(Enter)
                        if Enter or not Info.EnterOnly then
                            Textbox.Value = InputBox.Text
                            Library:SafeCallback(Textbox.Callback, InputBox.Text)
                            Library:AttemptSave()
                        end
                    end)
                else
                    InputBox:GetPropertyChangedSignal('Text'):Connect(function()
                        Textbox.Value = InputBox.Text
                        Library:SafeCallback(Textbox.Callback, InputBox.Text)
                    end)
                end

                if Info.Tooltip then
                    Library:AddToolTip(Info.Tooltip, Outer)
                end

                function Textbox:SetValue(Val)
                    InputBox.Text = Val
                    Textbox.Value = Val
                end

                function Textbox:OnChanged(Fn)
                    Textbox.Callback = Fn
                end

                Options[Idx] = Textbox
                return Textbox
            end

            function Groupbox:AddDropdown(Idx, Info)
                Info = Info or {}

                local Dropdown = {
                    Value = Info.Default or (Info.Multi and {} or nil),
                    Values = Info.Values or {},
                    Multi = Info.Multi or false,
                    Type = 'Dropdown',
                    Callback = Info.Callback or function() end,
                    SpecialType = Info.SpecialType,
                    AllowNull = Info.AllowNull or false,
                }

                local Outer = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, Info.Text and 44 or 28),
                    LayoutOrder = #Container:GetChildren(),
                    ClipsDescendants = false,
                    Parent = Container,
                })

                if Info.Text then
                    Library:CreateLabel({
                        Text = Info.Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 14),
                        ZIndex = 5,
                        Parent = Outer,
                    })
                end

                local DisplayBtn = Library:Create('TextButton', {
                    BackgroundColor3 = Library.SecondaryColor,
                    Size = UDim2.new(1, 0, 0, 26),
                    Position = UDim2.fromOffset(0, Info.Text and 16 or 0),
                    Text = '',
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = Outer,
                })
                Library:AddCorner(DisplayBtn, CORNER_SM)
                Library:AddStroke(DisplayBtn, Library.OutlineColor)
                Library:AddToRegistry(DisplayBtn, { BackgroundColor3 = 'SecondaryColor' })

                local function GetDisplayText()
                    if Dropdown.Multi then
                        local Sel = {}
                        for Val, State in next, Dropdown.Value do
                            if State then table.insert(Sel, Val) end
                        end
                        return #Sel > 0 and table.concat(Sel, ', ') or 'None'
                    else
                        return Dropdown.Value and tostring(Dropdown.Value) or 'Select...'
                    end
                end

                local DisplayLabel = Library:CreateLabel({
                    Text = GetDisplayText(),
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(8, 0),
                    Size = UDim2.new(1, -28, 1, 0),
                    ZIndex = 6,
                    Parent = DisplayBtn,
                })

                Library:CreateLabel({
                    Text = '▼',
                    TextSize = 9,
                    Size = UDim2.fromOffset(20, 26),
                    Position = UDim2.new(1, -22, 0, 0),
                    ZIndex = 6,
                    Parent = DisplayBtn,
                })

                local ListFrame = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor,
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.fromOffset(0, (Info.Text and 16 or 0) + 28),
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 50,
                    Parent = Outer,
                })
                Library:AddCorner(ListFrame, CORNER_SM)
                Library:AddStroke(ListFrame, Library.OutlineColor)
                Library:AddToRegistry(ListFrame, { BackgroundColor3 = 'MainColor' })

                local ListScroll = Library:Create('ScrollingFrame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -6, 1, -6),
                    Position = UDim2.fromOffset(3, 3),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Library.AccentColor,
                    ZIndex = 51,
                    Parent = ListFrame,
                })

                Library:Create('UIListLayout', {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 2),
                    Parent = ListScroll,
                })

                local IsOpen = false

                local function BuildList()
                    for _, Child in next, ListScroll:GetChildren() do
                        if Child:IsA('TextButton') then Child:Destroy() end
                    end

                    local Vals = Dropdown.Values
                    if Dropdown.SpecialType == 'Player' then Vals = GetPlayersString() end
                    if Dropdown.SpecialType == 'Team' then Vals = GetTeamsString() end

                    for i, Val in next, Vals do
                        local Selected = Dropdown.Multi and Dropdown.Value[Val] or Dropdown.Value == Val

                        local Opt = Library:Create('TextButton', {
                            BackgroundColor3 = Selected and Library.AccentColor or Library.SecondaryColor,
                            BackgroundTransparency = Selected and 0 or 0.4,
                            Size = UDim2.new(1, 0, 0, 22),
                            Text = tostring(Val),
                            TextColor3 = Library.FontColor,
                            Font = Library.Font,
                            TextSize = 11,
                            AutoButtonColor = false,
                            LayoutOrder = i,
                            ZIndex = 52,
                            Parent = ListScroll,
                        })
                        Library:AddCorner(Opt, UDim.new(0, 3))

                        Opt.MouseButton1Click:Connect(function()
                            if Dropdown.Multi then
                                Dropdown.Value[Val] = not Dropdown.Value[Val]
                                Opt.BackgroundColor3 = Dropdown.Value[Val] and Library.AccentColor or Library.SecondaryColor
                                Opt.BackgroundTransparency = Dropdown.Value[Val] and 0 or 0.4
                            else
                                Dropdown.Value = Val
                                for _, C in next, ListScroll:GetChildren() do
                                    if C:IsA('TextButton') then
                                        C.BackgroundColor3 = Library.SecondaryColor
                                        C.BackgroundTransparency = 0.4
                                    end
                                end
                                Opt.BackgroundColor3 = Library.AccentColor
                                Opt.BackgroundTransparency = 0
                                IsOpen = false
                                Library:Tween(ListFrame, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                                task.delay(0.15, function()
                                    ListFrame.Visible = false
                                    Library.OpenedFrames[ListFrame] = nil
                                end)
                            end
                            DisplayLabel.Text = GetDisplayText()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                            Library:AttemptSave()
                        end)

                        Library:OnHighlight(Opt, Opt, { BackgroundTransparency = 0 }, { BackgroundTransparency = (Selected and 0 or 0.4) })
                    end

                    local TotalH = math.min(#Vals * 24 + 6, 180)
                    return TotalH
                end

                DisplayBtn.MouseButton1Click:Connect(function()
                    IsOpen = not IsOpen
                    if IsOpen then
                        local H = BuildList()
                        ListFrame.Visible = true
                        Library:Tween(ListFrame, { Size = UDim2.new(1, 0, 0, H) }, 0.2)
                        Library.OpenedFrames[ListFrame] = true
                    else
                        Library:Tween(ListFrame, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                        task.delay(0.15, function()
                            ListFrame.Visible = false
                            Library.OpenedFrames[ListFrame] = nil
                        end)
                    end
                end)

                if Info.Tooltip then
                    Library:AddToolTip(Info.Tooltip, DisplayBtn)
                end

                function Dropdown:SetValues(NewVals)
                    Dropdown.Values = NewVals
                    if IsOpen then BuildList() end
                end

                function Dropdown:SetValue(Val)
                    Dropdown.Value = Val
                    DisplayLabel.Text = GetDisplayText()
                    Library:SafeCallback(Dropdown.Callback, Val)
                end

                function Dropdown:OnChanged(Fn)
                    Dropdown.Callback = Fn
                end

                Options[Idx] = Dropdown
                return Dropdown
            end

            function Groupbox:AddDependencyBox()
                local DepBox = { Dependencies = {} }

                local DepFrame = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    LayoutOrder = #Container:GetChildren(),
                    Visible = false,
                    Parent = Container,
                })

                Library:Create('UIListLayout', {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 5),
                    Parent = DepFrame,
                })

                DepBox.Container = DepFrame
                DepBox.Frame = DepFrame

                setmetatable(DepBox, {
                    __index = function(_, Key)
                        if Groupbox[Key] then
                            return function(_, ...)
                                local Orig = Groupbox.Container
                                Groupbox.Container = DepFrame
                                local Result = Groupbox[Key](Groupbox, ...)
                                Groupbox.Container = Orig
                                return Result
                            end
                        end
                    end,
                })

                function DepBox:SetupDependencies(Deps)
                    DepBox.Dependencies = Deps
                end

                function DepBox:Update()
                    local Show = true
                    for _, Dep in next, DepBox.Dependencies do
                        local T = Toggles[Dep[1]]
                        if T and T.Value ~= Dep[2] then
                            Show = false
                            break
                        end
                    end
                    DepFrame.Visible = Show
                end

                table.insert(Library.DependencyBoxes, DepBox)
                return DepBox
            end

            return Groupbox
        end

        return Tab
    end

    return Window
end

return Library
