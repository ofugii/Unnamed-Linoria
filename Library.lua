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

local Library = {
    Registry = {},
    RegistryMap = {},
    HudRegistry = {},
    FontColor = Color3.fromRGB(255, 255, 255),
    MainColor = Color3.fromRGB(28, 28, 28),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    AccentColor = Color3.fromRGB(0, 85, 255),
    OutlineColor = Color3.fromRGB(50, 50, 50),
    RiskColor = Color3.fromRGB(255, 50, 50),
    Black = Color3.new(0, 0, 0),
    Font = Enum.Font.Code,
    OpenedFrames = {},
    DependencyBoxes = {},
    Signals = {},
    ScreenGui = ScreenGui,
    Round = UDim.new(0, 4),
    ToggleKey = Enum.KeyCode.RightShift,
    NotifyOnError = true,
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
        local _, i = event:find(':%d+: ')
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

function Library:CreateCorner(Parent, Radius)
    return Library:Create('UICorner', {
        CornerRadius = Radius or Library.Round,
        Parent = Parent,
    })
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0),
        Thickness = 1,
        LineJoinMode = Enum.LineJoinMode.Miter,
        Parent = Inst,
    })
end

function Library:CreateLabel(Properties, IsHud)
    local Inst = Library:Create('TextLabel', {
        BackgroundTransparency = 1,
        Font = Library.Font,
        TextColor3 = Library.FontColor,
        TextSize = 14,
        TextStrokeTransparency = 0,
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
            Inst.Position = UDim2.new(
                StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
            )
        end
    end)
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14)

    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        BorderSizePixel = 1,
        Size = UDim2.fromOffset(X + 10, Y + 6),
        ZIndex = 100,
        Parent = Library.ScreenGui,
        Visible = false,
    })
    Library:CreateCorner(Tooltip)

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(5, 2),
        Size = UDim2.fromOffset(X, Y),
        TextSize = 14,
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 101,
        Parent = Tooltip,
    })

    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor' })

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true
        Tooltip.Visible = true
        while IsHovering do
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
            Heartbeat:Wait()
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Inst, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Inst]
        for Property, ColorIdx in next, Properties do
            Inst[Property] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx
            end
        end
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Inst]
        for Property, ColorIdx in next, PropertiesDefault do
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

function Library:OnUnload(Callback)
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
            Position = UDim2.new(0, 0, 0, 40),
            Size = UDim2.new(0, 300, 1, -40),
            ZIndex = 100,
            Parent = Library.ScreenGui,
        })
        Library:Create('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
            Parent = Holder,
        })
        Library:Create('UIPadding', {
            PaddingLeft = UDim.new(0, 20),
            PaddingTop = UDim.new(0, 5),
            Parent = Holder,
        })
    end

    local X, _ = Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(280, math.huge))
    local Width = math.clamp(X + 20, 180, 300)

    local Frame = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        BorderSizePixel = 1,
        Size = UDim2.fromOffset(Width, 0),
        ClipsDescendants = true,
        ZIndex = 101,
        Parent = Holder,
    })
    Library:CreateCorner(Frame)

    local AccentBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0),
        ZIndex = 103,
        Parent = Frame,
    })

    Library:AddToRegistry(Frame, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
    Library:AddToRegistry(AccentBar, { BackgroundColor3 = 'AccentColor' })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(10, 4),
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextSize = 14,
        Text = Text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 102,
        Parent = Frame,
    })

    task.wait()
    local Height = math.max(Label.TextBounds.Y + 10, 28)

    TweenService:Create(Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(Width, Height),
    }):Play()

    task.delay(Duration, function()
        local T = TweenService:Create(Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(Width, 0),
        })
        T:Play()
        T.Completed:Wait()
        Frame:Destroy()
    end)
end

local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddColorPicker(Idx, Info)
        assert(Info.Default, 'AddColorPicker: Missing default value.')

        local ToggleLabel = self.TextLabel

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

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = Info.Default,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            Size = UDim2.fromOffset(16, 10),
            ZIndex = 6,
            Parent = ToggleLabel,
        })
        Library:CreateCorner(DisplayFrame, UDim.new(0, 3))
        Library:AddToRegistry(DisplayFrame, { BorderColor3 = 'OutlineColor' })

        if ToggleLabel then
            DisplayFrame.Position = UDim2.new(1, -16, 0, 3)
        end

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Picker_' .. Idx,
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            Size = UDim2.fromOffset(180, Info.Transparency and 200 or 170),
            ZIndex = 15,
            Visible = false,
            Parent = ScreenGui,
        })
        Library:CreateCorner(PickerFrameOuter)
        Library:AddToRegistry(PickerFrameOuter, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

        local SatVal = Library:Create('ImageLabel', {
            BackgroundColor3 = Color3.fromHSV(H, 1, 1),
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            Size = UDim2.fromOffset(128, 128),
            Position = UDim2.fromOffset(6, 6),
            Image = 'rbxassetid://4155801252',
            ZIndex = 16,
            Parent = PickerFrameOuter,
        })
        Library:CreateCorner(SatVal, UDim.new(0, 3))
        Library:AddToRegistry(SatVal, { BorderColor3 = 'OutlineColor' })

        local SatValOverlay = Library:Create('ImageLabel', {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = 'rbxassetid://4155801252',
            ImageColor3 = Color3.new(0, 0, 0),
            ZIndex = 17,
            Parent = SatVal,
        })

        local HueBar = Library:Create('ImageLabel', {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            Size = UDim2.fromOffset(18, 128),
            Position = UDim2.fromOffset(140, 6),
            Image = 'rbxassetid://3641079629',
            ZIndex = 16,
            Parent = PickerFrameOuter,
        })
        Library:CreateCorner(HueBar, UDim.new(0, 3))
        Library:AddToRegistry(HueBar, { BorderColor3 = 'OutlineColor' })

        local SVCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 1,
            Size = UDim2.fromOffset(5, 5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(S, 1 - V),
            ZIndex = 19,
            Parent = SatVal,
        })
        Library:CreateCorner(SVCursor, UDim.new(1, 0))

        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 1,
            Size = UDim2.new(1, 2, 0, 3),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, H, 0),
            ZIndex = 18,
            Parent = HueBar,
        })
        Library:CreateCorner(HueCursor, UDim.new(0, 2))

        local TransparencyBar, TransparencyCursor, TransparencyGradient
        if Info.Transparency then
            TransparencyBar = Library:Create('Frame', {
                BackgroundColor3 = Info.Default,
                BorderColor3 = Library.OutlineColor,
                BorderSizePixel = 1,
                Size = UDim2.fromOffset(152, 12),
                Position = UDim2.fromOffset(6, 140),
                ZIndex = 16,
                Parent = PickerFrameOuter,
            })
            Library:CreateCorner(TransparencyBar, UDim.new(0, 3))
            Library:AddToRegistry(TransparencyBar, { BorderColor3 = 'OutlineColor' })

            TransparencyGradient = Library:Create('UIGradient', {
                Transparency = NumberSequence.new(0, 1),
                Parent = TransparencyBar,
            })

            TransparencyCursor = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderColor3 = Color3.new(0, 0, 0),
                BorderSizePixel = 1,
                Size = UDim2.new(0, 3, 1, 2),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                ZIndex = 18,
                Parent = TransparencyBar,
            })
            Library:CreateCorner(TransparencyCursor, UDim.new(0, 2))
        end

        local HexBox = Library:Create('TextBox', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            PlaceholderText = '#FFFFFF',
            Text = '#' .. Info.Default:ToHex(),
            TextColor3 = Library.FontColor,
            Font = Library.Font,
            TextSize = 14,
            Size = UDim2.new(1, -12, 0, 20),
            Position = UDim2.new(0, 6, 1, -26),
            ZIndex = 16,
            ClearTextOnFocus = false,
            Parent = PickerFrameOuter,
        })
        Library:CreateCorner(HexBox, UDim.new(0, 3))
        Library:AddToRegistry(HexBox, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor', TextColor3 = 'FontColor' })

        local function UpdateColor()
            local NewColor = Color3.fromHSV(H, S, V)
            ColorPicker.Value = NewColor
            DisplayFrame.BackgroundColor3 = NewColor
            SatVal.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
            SVCursor.Position = UDim2.fromScale(S, 1 - V)
            HueCursor.Position = UDim2.new(0.5, 0, H, 0)
            HexBox.Text = '#' .. NewColor:ToHex()

            if Info.Transparency then
                TransparencyBar.BackgroundColor3 = NewColor
                TransparencyCursor.Position = UDim2.new(ColorPicker.TransparencyValue, 0, 0.5, 0)
            end

            Library:SafeCallback(ColorPicker.Callback, NewColor)
        end

        local DraggingSV, DraggingH, DraggingT = false, false, false

        SatVal.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                DraggingSV = true
                S = math.clamp((Mouse.X - SatVal.AbsolutePosition.X) / SatVal.AbsoluteSize.X, 0, 1)
                V = 1 - math.clamp((Mouse.Y - SatVal.AbsolutePosition.Y) / SatVal.AbsoluteSize.Y, 0, 1)
                UpdateColor()
            end
        end)

        HueBar.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                DraggingH = true
                H = math.clamp((Mouse.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
                UpdateColor()
            end
        end)

        if TransparencyBar then
            TransparencyBar.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    DraggingT = true
                    ColorPicker.TransparencyValue = math.clamp((Mouse.X - TransparencyBar.AbsolutePosition.X) / TransparencyBar.AbsoluteSize.X, 0, 1)
                    UpdateColor()
                end
            end)
        end

        Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseMovement then
                if DraggingSV then
                    S = math.clamp((Mouse.X - SatVal.AbsolutePosition.X) / SatVal.AbsoluteSize.X, 0, 1)
                    V = 1 - math.clamp((Mouse.Y - SatVal.AbsolutePosition.Y) / SatVal.AbsoluteSize.Y, 0, 1)
                    UpdateColor()
                elseif DraggingH then
                    H = math.clamp((Mouse.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
                    UpdateColor()
                elseif DraggingT and TransparencyBar then
                    ColorPicker.TransparencyValue = math.clamp((Mouse.X - TransparencyBar.AbsolutePosition.X) / TransparencyBar.AbsoluteSize.X, 0, 1)
                    UpdateColor()
                end
            end
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                DraggingSV = false
                DraggingH = false
                DraggingT = false
                Library:AttemptSave()
            end
        end))

        HexBox.FocusLost:Connect(function()
            local Hex = HexBox.Text:gsub('#', '')
            local Ok, Col = pcall(Color3.fromHex, '#' .. Hex)
            if Ok and Col then
                H, S, V = Color3.toHSV(Col)
                UpdateColor()
                Library:AttemptSave()
            else
                HexBox.Text = '#' .. ColorPicker.Value:ToHex()
            end
        end)

        local PickerOpen = false
        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                PickerOpen = not PickerOpen
                PickerFrameOuter.Visible = PickerOpen
                if PickerOpen then
                    PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X - 164, DisplayFrame.AbsolutePosition.Y + 18)
                    Library.OpenedFrames[PickerFrameOuter] = true
                else
                    Library.OpenedFrames[PickerFrameOuter] = nil
                end
            end
        end)

        function ColorPicker:SetValue(NewColor)
            H, S, V = Color3.toHSV(NewColor)
            UpdateColor()
        end

        function ColorPicker:SetValueRGB(NewColor)
            ColorPicker:SetValue(NewColor)
        end

        function ColorPicker:OnChanged(Fn)
            ColorPicker.Callback = Fn
        end

        Options[Idx] = ColorPicker
        return self
    end

    function Funcs:AddKeyPicker(Idx, Info)
        local ToggleLabel = self.TextLabel

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

        local DisplayLabel = Library:CreateLabel({
            Text = '[' .. (Info.Default and Info.Default.Name or 'None') .. ']',
            TextSize = 14,
            Position = UDim2.new(1, -24, 0, 0),
            Size = UDim2.fromOffset(24, 18),
            ZIndex = 6,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = ToggleLabel and ToggleLabel.Parent or self.Container,
        })

        local ModeDisplay = Library:CreateLabel({
            Text = '(' .. KeyPicker.Mode .. ')',
            TextSize = 14,
            Position = UDim2.new(1, -24, 0, 14),
            Size = UDim2.fromOffset(24, 14),
            ZIndex = 6,
            TextColor3 = Library:GetDarkerColor(Library.FontColor),
            TextXAlignment = Enum.TextXAlignment.Right,
            Visible = false,
            Parent = ToggleLabel and ToggleLabel.Parent or self.Container,
        })

        DisplayLabel.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Picking = true
                DisplayLabel.Text = '[...]'
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                local Modes = { 'Toggle', 'Hold', 'Always' }
                local Idx2 = table.find(Modes, KeyPicker.Mode) or 1
                Idx2 = Idx2 % #Modes + 1
                KeyPicker.Mode = Modes[Idx2]
                ModeDisplay.Text = '(' .. KeyPicker.Mode .. ')'
            end
        end)

        DisplayLabel.MouseEnter:Connect(function()
            ModeDisplay.Visible = true
        end)

        DisplayLabel.MouseLeave:Connect(function()
            ModeDisplay.Visible = false
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
                    DisplayLabel.Text = '[' .. (Key.Name or tostring(Key)) .. ']'
                    Library:SafeCallback(KeyPicker.ChangedCallback, Key)
                    Library:AttemptSave()
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
                    elseif KeyPicker.Mode == 'Always' then
                        IsActive = true
                    end

                    if KeyPicker.SyncToggleState and self.Value ~= nil then
                        self:SetValue(IsActive)
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
                    if KeyPicker.SyncToggleState and self.Value ~= nil then
                        self:SetValue(false)
                    end
                    Library:SafeCallback(KeyPicker.Callback, IsActive)
                end
            end
        end))

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then return true end
            return IsActive
        end

        function KeyPicker:SetValue(Data)
            if type(Data) == 'table' then
                KeyPicker.Value = Data[1]
                KeyPicker.Mode = Data[2] or KeyPicker.Mode
                DisplayLabel.Text = '[' .. (Data[1] and Data[1].Name or 'None') .. ']'
                ModeDisplay.Text = '(' .. KeyPicker.Mode .. ')'
            else
                KeyPicker.Value = Data
                DisplayLabel.Text = '[' .. (Data and Data.Name or 'None') .. ']'
            end
        end

        function KeyPicker:OnChanged(Fn)
            KeyPicker.ChangedCallback = Fn
        end

        Options[Idx] = KeyPicker
        return self
    end

    BaseAddons.__index = Funcs
end

function Library:CreateWindow(Config)
    assert(Config.Title, 'CreateWindow: Title required.')

    local WindowConfig = {
        Title = Config.Title,
        Center = Config.Center or false,
        AutoShow = Config.AutoShow or false,
        TabPadding = Config.TabPadding or 0,
        MenuFadeTime = Config.MenuFadeTime or 0.2,
    }

    local Window = {
        Tabs = {},
        TabCount = 0,
    }

    local Outer = Library:Create('Frame', {
        Name = 'Window',
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(550, 600),
        Position = WindowConfig.Center and UDim2.new(0.5, -275, 0.5, -300) or UDim2.fromOffset(175, 50),
        ZIndex = 1,
        Parent = ScreenGui,
    })
    Library:CreateCorner(Outer, UDim.new(0, 5))
    Library:AddToRegistry(Outer, { BackgroundColor3 = 'AccentColor' })

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -2, 1, -2),
        Position = UDim2.fromOffset(1, 1),
        ZIndex = 1,
        Parent = Outer,
    })
    Library:CreateCorner(Inner, UDim.new(0, 4))
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor' })

    Library:MakeDraggable(Outer, 25)

    local TitleBar = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 25),
        ZIndex = 2,
        Parent = Inner,
    })

    Library:CreateLabel({
        Text = WindowConfig.Title,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 2,
        Parent = TitleBar,
    })

    local AccentLine = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 25),
        ZIndex = 2,
        Parent = Inner,
    })
    Library:AddToRegistry(AccentLine, { BackgroundColor3 = 'AccentColor' })

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 24),
        Position = UDim2.fromOffset(8, 28),
        ZIndex = 2,
        Parent = Inner,
    })

    local TabListLayout = Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = TabArea,
    })

    local ContentArea = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderColor3 = Library.OutlineColor,
        BorderSizePixel = 1,
        Size = UDim2.new(1, -16, 1, -60),
        Position = UDim2.fromOffset(8, 54),
        ZIndex = 2,
        ClipsDescendants = true,
        Parent = Inner,
    })
    Library:CreateCorner(ContentArea, UDim.new(0, 4))
    Library:AddToRegistry(ContentArea, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

    local Hidden = not WindowConfig.AutoShow
    Outer.Visible = not Hidden

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if Processed then return end
        if Input.KeyCode == Library.ToggleKey then
            Hidden = not Hidden
            Outer.Visible = not Hidden
        end
    end))

    function Window:AddTab(Name)
        local Tab = {
            Name = Name,
            Groupboxes = {},
            LeftGroupboxes = 0,
            RightGroupboxes = 0,
        }

        Window.TabCount = Window.TabCount + 1

        local TabBtn = Library:Create('TextButton', {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            Size = UDim2.fromOffset(0, 22),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = '',
            AutoButtonColor = false,
            ZIndex = 3,
            LayoutOrder = Window.TabCount,
            Parent = TabArea,
        })
        Library:CreateCorner(TabBtn, UDim.new(0, 3))
        Library:AddToRegistry(TabBtn, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

        Library:Create('UIPadding', {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            Parent = TabBtn,
        })

        local TabLabel = Library:CreateLabel({
            Text = Name,
            TextSize = 14,
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 3,
            Parent = TabBtn,
        })

        local TabFrame = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            ZIndex = 2,
            Parent = ContentArea,
        })
        Library:Create('UIPadding', {
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            Parent = TabFrame,
        })

        local LeftColumn = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -4, 1, 0),
            Position = UDim2.fromOffset(0, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.AccentColor,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = TabFrame,
        })
        Library:Create('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = LeftColumn,
        })

        local RightColumn = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.5, -4, 1, 0),
            Position = UDim2.new(0.5, 4, 0, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.AccentColor,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = TabFrame,
        })
        Library:Create('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = RightColumn,
        })

        Tab.Button = TabBtn
        Tab.Frame = TabFrame
        Tab.LeftColumn = LeftColumn
        Tab.RightColumn = RightColumn

        local function SelectTab()
            for _, T in next, Window.Tabs do
                T.Frame.Visible = false
                T.Button.BackgroundColor3 = Library.BackgroundColor
                local Reg = Library.RegistryMap[T.Button]
                if Reg then
                    Reg.Properties.BackgroundColor3 = 'BackgroundColor'
                end
            end
            TabFrame.Visible = true
            TabBtn.BackgroundColor3 = Library.MainColor
            local Reg = Library.RegistryMap[TabBtn]
            if Reg then
                Reg.Properties.BackgroundColor3 = 'MainColor'
            end
        end

        TabBtn.MouseButton1Click:Connect(SelectTab)

        table.insert(Window.Tabs, Tab)

        if Window.TabCount == 1 then
            SelectTab()
        end

        local function CreateGroupbox(Name, Side)
            local Column = Side == 'Right' and RightColumn or LeftColumn

            if Side == 'Right' then
                Tab.RightGroupboxes = Tab.RightGroupboxes + 1
            else
                Tab.LeftGroupboxes = Tab.LeftGroupboxes + 1
            end

            local Groupbox = { Name = Name }
            setmetatable(Groupbox, BaseAddons)

            local GroupOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                BorderColor3 = Library.OutlineColor,
                BorderSizePixel = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = Side == 'Right' and Tab.RightGroupboxes or Tab.LeftGroupboxes,
                ZIndex = 3,
                Parent = Column,
            })
            Library:CreateCorner(GroupOuter)
            Library:AddToRegistry(GroupOuter, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

            local GroupInner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                BorderSizePixel = 0,
                Size = UDim2.new(1, -4, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Position = UDim2.fromOffset(2, 2),
                ZIndex = 3,
                Parent = GroupOuter,
            })
            Library:CreateCorner(GroupInner, UDim.new(0, 3))
            Library:AddToRegistry(GroupInner, { BackgroundColor3 = 'MainColor' })

            local GroupLabel = Library:CreateLabel({
                Text = Name,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, -12, 0, 18),
                Position = UDim2.fromOffset(6, 2),
                ZIndex = 4,
                Parent = GroupInner,
            })

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -12, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Position = UDim2.fromOffset(6, 22),
                ZIndex = 3,
                Parent = GroupInner,
            })
            Library:Create('UIListLayout', {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 2),
                Parent = Container,
            })
            Library:Create('UIPadding', {
                PaddingBottom = UDim.new(0, 8),
                Parent = Container,
            })

            Groupbox.Container = Container
            Groupbox.Frame = GroupOuter
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
                    Size = UDim2.new(1, 0, 0, 18),
                    LayoutOrder = #Container:GetChildren(),
                    ZIndex = 4,
                    Parent = Container,
                })

                local Box = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderSizePixel = 1,
                    Size = UDim2.fromOffset(13, 13),
                    Position = UDim2.fromOffset(0, 2),
                    ZIndex = 5,
                    Parent = Outer,
                })
                Library:CreateCorner(Box, UDim.new(0, 3))
                Library:AddToRegistry(Box, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

                local CheckInner = Library:Create('Frame', {
                    BackgroundColor3 = Library.AccentColor,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, -4, 1, -4),
                    Position = UDim2.fromOffset(2, 2),
                    ZIndex = 6,
                    Visible = Info.Default or false,
                    Parent = Box,
                })
                Library:CreateCorner(CheckInner, UDim.new(0, 2))
                Library:AddToRegistry(CheckInner, { BackgroundColor3 = 'AccentColor' })

                local Label = Library:CreateLabel({
                    Text = Info.Text or Idx,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Position = UDim2.fromOffset(19, 0),
                    Size = UDim2.new(1, -19, 1, 0),
                    ZIndex = 5,
                    Parent = Outer,
                })

                Toggle.TextLabel = Label
                Toggle.Container = Outer

                Library:OnHighlight(Outer, Box,
                    { BackgroundColor3 = 'AccentColor' },
                    { BackgroundColor3 = 'MainColor' }
                )

                local function SetState(State)
                    Toggle.Value = State
                    CheckInner.Visible = State
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
                    Size = UDim2.new(1, 0, 0, Slider.Compact and 20 or 32),
                    LayoutOrder = #Container:GetChildren(),
                    ZIndex = 4,
                    Parent = Container,
                })

                if not Slider.Compact then
                    Library:CreateLabel({
                        Text = Info.Text or Idx,
                        TextSize = 14,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 14),
                        ZIndex = 5,
                        Parent = Outer,
                    })
                end

                local SliderBG = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderSizePixel = 1,
                    Size = UDim2.new(1, 0, 0, 14),
                    Position = UDim2.fromOffset(0, Slider.Compact and 3 or 16),
                    ZIndex = 5,
                    Parent = Outer,
                })
                Library:CreateCorner(SliderBG, UDim.new(0, 3))
                Library:AddToRegistry(SliderBG, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

                local Fill = Library:Create('Frame', {
                    BackgroundColor3 = Library.AccentColor,
                    BorderSizePixel = 0,
                    Size = UDim2.fromScale(0, 1),
                    ZIndex = 6,
                    Parent = SliderBG,
                })
                Library:CreateCorner(Fill, UDim.new(0, 3))
                Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' })

                local ValLabel = Library:CreateLabel({
                    Text = '',
                    TextSize = 14,
                    Size = UDim2.fromScale(1, 1),
                    ZIndex = 7,
                    Parent = SliderBG,
                })

                local function Round(Val, To)
                    if To == 0 then return Val end
                    return math.floor(Val / To + 0.5) * To
                end

                local function SetValue(Val)
                    Val = math.clamp(Round(Val, Slider.Rounding), Slider.Min, Slider.Max)
                    Slider.Value = Val
                    local Pct = (Val - Slider.Min) / (Slider.Max - Slider.Min)
                    Fill.Size = UDim2.new(Pct, 0, 1, 0)
                    ValLabel.Text = (Slider.Compact and (Info.Text or Idx) .. ': ' or '') .. tostring(Val) .. Slider.Suffix
                    Library:SafeCallback(Slider.Callback, Val)
                end

                SetValue(Slider.Value)

                local Dragging = false

                SliderBG.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Dragging = true
                        local Pct = math.clamp((Mouse.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X, 0, 1)
                        SetValue(Slider.Min + (Slider.Max - Slider.Min) * Pct)
                    end
                end)

                Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
                    if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
                        local Pct = math.clamp((Mouse.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X, 0, 1)
                        SetValue(Slider.Min + (Slider.Max - Slider.Min) * Pct)
                    end
                end))

                Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Dragging = false
                        Library:AttemptSave()
                    end
                end))

                Library:OnHighlight(SliderBG, SliderBG,
                    { BorderColor3 = 'AccentColor' },
                    { BorderColor3 = 'OutlineColor' }
                )

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
                if type(Info) == 'string' then
                    local Text = Info
                    local Func = select(2, ...)
                    Info = { Text = Text, Func = Func }
                end
                Info = Info or {}

                local BtnOuter = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    LayoutOrder = #Container:GetChildren(),
                    ZIndex = 4,
                    Parent = Container,
                })

                local Btn = Library:Create('TextButton', {
                    BackgroundColor3 = Library.MainColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderSizePixel = 1,
                    Size = UDim2.fromScale(1, 1),
                    Text = '',
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = BtnOuter,
                })
                Library:CreateCorner(Btn, UDim.new(0, 3))
                Library:AddToRegistry(Btn, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

                Library:CreateLabel({
                    Text = Info.Text or 'Button',
                    TextSize = 14,
                    Size = UDim2.fromScale(1, 1),
                    ZIndex = 6,
                    Parent = Btn,
                })

                Library:OnHighlight(Btn, Btn,
                    { BackgroundColor3 = 'AccentColor' },
                    { BackgroundColor3 = 'MainColor' }
                )

                Btn.MouseButton1Click:Connect(function()
                    Library:SafeCallback(Info.Func)
                end)

                if Info.DoubleClick then
                    local Last = 0
                    local OrigFunc = Info.Func
                    Btn.MouseButton1Click:Connect(function()
                        if tick() - Last < 0.35 then
                            Library:SafeCallback(Info.DoubleClickFunc or OrigFunc)
                        end
                        Last = tick()
                    end)
                end

                if Info.Tooltip then
                    Library:AddToolTip(Info.Tooltip, Btn)
                end

                local BtnObj = {}

                function BtnObj:AddButton(SubInfo)
                    if type(SubInfo) == 'string' then
                        local Text = SubInfo
                        local Func = select(2, ...)
                        SubInfo = { Text = Text, Func = Func }
                    end
                    SubInfo = SubInfo or {}

                    Btn.Size = UDim2.new(0.5, -2, 1, 0)

                    local SubBtn = Library:Create('TextButton', {
                        BackgroundColor3 = Library.MainColor,
                        BorderColor3 = Library.OutlineColor,
                        BorderSizePixel = 1,
                        Size = UDim2.new(0.5, -2, 1, 0),
                        Position = UDim2.new(0.5, 2, 0, 0),
                        Text = '',
                        AutoButtonColor = false,
                        ZIndex = 5,
                        Parent = BtnOuter,
                    })
                    Library:CreateCorner(SubBtn, UDim.new(0, 3))
                    Library:AddToRegistry(SubBtn, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

                    Library:CreateLabel({
                        Text = SubInfo.Text or 'Button',
                        TextSize = 14,
                        Size = UDim2.fromScale(1, 1),
                        ZIndex = 6,
                        Parent = SubBtn,
                    })

                    Library:OnHighlight(SubBtn, SubBtn,
                        { BackgroundColor3 = 'AccentColor' },
                        { BackgroundColor3 = 'MainColor' }
                    )

                    SubBtn.MouseButton1Click:Connect(function()
                        Library:SafeCallback(SubInfo.Func)
                    end)

                    if SubInfo.Tooltip then
                        Library:AddToolTip(SubInfo.Tooltip, SubBtn)
                    end

                    return BtnObj
                end

                return BtnObj
            end

            function Groupbox:AddLabel(Text, DoesWrap)
                local Label = Library:CreateLabel({
                    Text = Text or '',
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = DoesWrap or false,
                    Size = UDim2.new(1, 0, 0, DoesWrap and 0 or 16),
                    AutomaticSize = DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
                    LayoutOrder = #Container:GetChildren(),
                    ZIndex = 5,
                    Parent = Container,
                })

                local Obj = { Label = Label, TextLabel = Label }
                setmetatable(Obj, BaseAddons)

                function Obj:SetText(NewText)
                    Label.Text = NewText
                end

                return Obj
            end

            function Groupbox:AddDivider()
                local Div = Library:Create('Frame', {
                    BackgroundColor3 = Library.OutlineColor,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 1),
                    LayoutOrder = #Container:GetChildren(),
                    ZIndex = 4,
                    Parent = Container,
                })
                Library:CreateCorner(Div, UDim.new(0, 0))
                Library:AddToRegistry(Div, { BackgroundColor3 = 'OutlineColor' })
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
                    Size = UDim2.new(1, 0, 0, Info.Text and 34 or 20),
                    LayoutOrder = #Container:GetChildren(),
                    ZIndex = 4,
                    Parent = Container,
                })

                if Info.Text then
                    Library:CreateLabel({
                        Text = Info.Text,
                        TextSize = 14,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 14),
                        ZIndex = 5,
                        Parent = Outer,
                    })
                end

                local InputBox = Library:Create('TextBox', {
                    BackgroundColor3 = Library.MainColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderSizePixel = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.fromOffset(0, Info.Text and 16 or 0),
                    Text = Info.Default or '',
                    PlaceholderText = Info.Placeholder or '',
                    TextColor3 = Library.FontColor,
                    PlaceholderColor3 = Library:GetDarkerColor(Library.FontColor),
                    Font = Library.Font,
                    TextSize = 14,
                    ClearTextOnFocus = false,
                    ZIndex = 5,
                    Parent = Outer,
                })
                Library:CreateCorner(InputBox, UDim.new(0, 3))
                Library:AddToRegistry(InputBox, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor', TextColor3 = 'FontColor' })

                Library:Create('UIPadding', {
                    PaddingLeft = UDim.new(0, 4),
                    PaddingRight = UDim.new(0, 4),
                    Parent = InputBox,
                })

                Library:OnHighlight(InputBox, InputBox,
                    { BorderColor3 = 'AccentColor' },
                    { BorderColor3 = 'OutlineColor' }
                )

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
                    Size = UDim2.new(1, 0, 0, Info.Text and 38 or 22),
                    LayoutOrder = #Container:GetChildren(),
                    ClipsDescendants = false,
                    ZIndex = 4,
                    Parent = Container,
                })

                if Info.Text then
                    Library:CreateLabel({
                        Text = Info.Text,
                        TextSize = 14,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 14),
                        ZIndex = 5,
                        Parent = Outer,
                    })
                end

                local DisplayBtn = Library:Create('TextButton', {
                    BackgroundColor3 = Library.MainColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderSizePixel = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.fromOffset(0, Info.Text and 16 or 0),
                    Text = '',
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = Outer,
                })
                Library:CreateCorner(DisplayBtn, UDim.new(0, 3))
                Library:AddToRegistry(DisplayBtn, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

                local function GetDisplayText()
                    if Dropdown.Multi then
                        local Sel = {}
                        for Val, State in next, Dropdown.Value do
                            if State then table.insert(Sel, tostring(Val)) end
                        end
                        return #Sel > 0 and table.concat(Sel, ', ') or 'None'
                    else
                        return Dropdown.Value and tostring(Dropdown.Value) or 'None'
                    end
                end

                local DisplayLabel = Library:CreateLabel({
                    Text = GetDisplayText(),
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(5, 0),
                    Size = UDim2.new(1, -20, 1, 0),
                    ZIndex = 6,
                    Parent = DisplayBtn,
                })

                Library:CreateLabel({
                    Text = '...',
                    TextSize = 14,
                    Size = UDim2.fromOffset(14, 20),
                    Position = UDim2.new(1, -16, 0, 0),
                    ZIndex = 6,
                    Parent = DisplayBtn,
                })

                local ListOuter = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderSizePixel = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.fromOffset(0, (Info.Text and 16 or 0) + 22),
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 20,
                    Parent = Outer,
                })
                Library:CreateCorner(ListOuter, UDim.new(0, 3))
                Library:AddToRegistry(ListOuter, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

                local ListScroll = Library:Create('ScrollingFrame', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -4, 1, -4),
                    Position = UDim2.fromOffset(2, 2),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Library.AccentColor,
                    BorderSizePixel = 0,
                    ZIndex = 21,
                    Parent = ListOuter,
                })

                Library:Create('UIListLayout', {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 1),
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

                        local OptBtn = Library:Create('TextButton', {
                            BackgroundColor3 = Selected and Library.AccentColor or Library.MainColor,
                            BorderSizePixel = 0,
                            Size = UDim2.new(1, 0, 0, 18),
                            Text = '',
                            AutoButtonColor = false,
                            LayoutOrder = i,
                            ZIndex = 22,
                            Parent = ListScroll,
                        })
                        Library:CreateCorner(OptBtn, UDim.new(0, 2))

                        local OptLabel = Library:CreateLabel({
                            Text = tostring(Val),
                            TextSize = 14,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Position = UDim2.fromOffset(5, 0),
                            Size = UDim2.new(1, -10, 1, 0),
                            ZIndex = 23,
                            Parent = OptBtn,
                        })

                        OptBtn.MouseButton1Click:Connect(function()
                            if Dropdown.Multi then
                                Dropdown.Value[Val] = not Dropdown.Value[Val]
                                OptBtn.BackgroundColor3 = Dropdown.Value[Val] and Library.AccentColor or Library.MainColor
                            else
                                Dropdown.Value = Val
                                for _, C in next, ListScroll:GetChildren() do
                                    if C:IsA('TextButton') then
                                        C.BackgroundColor3 = Library.MainColor
                                    end
                                end
                                OptBtn.BackgroundColor3 = Library.AccentColor

                                IsOpen = false
                                ListOuter.Visible = false
                                Library.OpenedFrames[ListOuter] = nil
                            end
                            DisplayLabel.Text = GetDisplayText()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                            Library:AttemptSave()
                        end)

                        Library:OnHighlight(OptBtn, OptBtn,
                            { BackgroundColor3 = 'AccentColor' },
                            { BackgroundColor3 = Selected and 'AccentColor' or 'MainColor' }
                        )
                    end

                    local TotalH = math.min(#Vals * 19 + 4, 150)
                    return TotalH
                end

                DisplayBtn.MouseButton1Click:Connect(function()
                    IsOpen = not IsOpen
                    if IsOpen then
                        local H = BuildList()
                        ListOuter.Visible = true
                        ListOuter.Size = UDim2.new(1, 0, 0, H)
                        Library.OpenedFrames[ListOuter] = true
                    else
                        ListOuter.Visible = false
                        Library.OpenedFrames[ListOuter] = nil
                    end
                end)

                Library:OnHighlight(DisplayBtn, DisplayBtn,
                    { BorderColor3 = 'AccentColor' },
                    { BorderColor3 = 'OutlineColor' }
                )

                if Info.Tooltip then
                    Library:AddToolTip(Info.Tooltip, DisplayBtn)
                end

                function Dropdown:SetValues(NewVals)
                    Dropdown.Values = NewVals
                    if IsOpen then
                        local H = BuildList()
                        ListOuter.Size = UDim2.new(1, 0, 0, H)
                    end
                end

                function Dropdown:SetValue(Val)
                    if Dropdown.Multi and type(Val) == 'table' then
                        Dropdown.Value = Val
                    elseif not Dropdown.Multi then
                        Dropdown.Value = Val
                    end
                    DisplayLabel.Text = GetDisplayText()
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
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
                    ZIndex = 4,
                    Parent = Container,
                })
                Library:Create('UIListLayout', {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 2),
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

        function Tab:AddLeftGroupbox(Name)
            return CreateGroupbox(Name, 'Left')
        end

        function Tab:AddRightGroupbox(Name)
            return CreateGroupbox(Name, 'Right')
        end

        return Tab
    end

    return Window
end

return Library
