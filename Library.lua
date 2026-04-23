local InputService  = game:GetService('UserInputService');
local TextService   = game:GetService('TextService');
local CoreGui       = game:GetService('CoreGui');
local Teams         = game:GetService('Teams');
local Players       = game:GetService('Players');
local RunService    = game:GetService('RunService');
local TweenService  = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer   = Players.LocalPlayer;
local Mouse         = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};
getgenv().Toggles = Toggles;
getgenv().Options = Options;

local R_WINDOW  = UDim.new(0, 8);
local R_GROUP   = UDim.new(0, 6);
local R_ELEMENT = UDim.new(0, 4);
local R_SMALL   = UDim.new(0, 3);

local Library = {
    Registry    = {};
    RegistryMap = {};
    HudRegistry = {};

    FontColor       = Color3.fromRGB(255, 255, 255);
    MainColor       = Color3.fromRGB(28,  28,  28);
    BackgroundColor = Color3.fromRGB(20,  20,  20);
    AccentColor     = Color3.fromRGB(0,   85,  255);
    OutlineColor    = Color3.fromRGB(50,  50,  50);
    RiskColor       = Color3.fromRGB(255, 50,  50);

    Black = Color3.new(0, 0, 0);
    Font  = Enum.Font.Code;

    OpenedFrames   = {};
    DependencyBoxes = {};
    Signals        = {};
    ScreenGui      = ScreenGui;
};

local RainbowStep = 0;
local Hue = 0;

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta;
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0;
        Hue = Hue + (1 / 400);
        if Hue > 1 then Hue = 0; end;
        Library.CurrentRainbowHue   = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end;
end));

local function AddCorner(inst, radius)
    Instance.new('UICorner', inst).CornerRadius = radius or R_SMALL;
end;

local function GetPlayersString()
    local list = Players:GetPlayers();
    for i = 1, #list do list[i] = list[i].Name; end;
    table.sort(list, function(a, b) return a < b; end);
    return list;
end;

local function GetTeamsString()
    local list = Teams:GetTeams();
    for i = 1, #list do list[i] = list[i].Name; end;
    table.sort(list, function(a, b) return a < b; end);
    return list;
end;

function Library:SafeCallback(f, ...)
    if not f then return; end;
    if not Library.NotifyOnError then return f(...); end;
    local ok, err = pcall(f, ...);
    if not ok then
        local _, i = err:find(':%d+: ');
        return Library:Notify(i and err:sub(i + 1) or err, 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then Library.SaveManager:Save(); end;
end;

function Library:Create(Class, Properties)
    local inst = type(Class) == 'string' and Instance.new(Class) or Class;
    for k, v in next, Properties do inst[k] = v; end;
    return inst;
end;

function Library:ApplyTextStroke(inst)
    inst.TextStrokeTransparency = 1;
    Library:Create('UIStroke', {
        Color        = Color3.new(0, 0, 0);
        Thickness    = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent       = inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local lbl = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font                   = Library.Font;
        TextColor3             = Library.FontColor;
        TextSize               = 16;
        TextStrokeTransparency = 0;
    });
    Library:ApplyTextStroke(lbl);
    Library:AddToRegistry(lbl, { TextColor3 = 'FontColor' }, IsHud);
    return Library:Create(lbl, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );
            if ObjPos.Y > (Cutoff or 40) then return; end;
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0, Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0, Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                );
                RenderStepped:Wait();
            end;
        end;
    end);
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel  = 0;
        Size             = UDim2.fromOffset(X + 10, Y + 6);
        ZIndex           = 100;
        Parent           = Library.ScreenGui;
        Visible          = false;
    });
    AddCorner(Tooltip, R_SMALL);

    local Label = Library:CreateLabel({
        Position          = UDim2.fromOffset(5, 2);
        Size              = UDim2.fromOffset(X, Y);
        TextSize          = 14;
        Text              = InfoStr;
        TextColor3        = Library.FontColor;
        TextXAlignment    = Enum.TextXAlignment.Left;
        ZIndex            = Tooltip.ZIndex + 1;
        Parent            = Tooltip;
    });

    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor' });
    Library:AddToRegistry(Label,   { TextColor3 = 'FontColor' });

    local Hovering = false;
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return; end;
        Hovering = true;
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12);
        Tooltip.Visible  = true;
        while Hovering do
            RunService.Heartbeat:Wait();
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12);
        end;
    end);
    HoverInstance.MouseLeave:Connect(function()
        Hovering = false;
        Tooltip.Visible = false;
    end);
end;

function Library:OnHighlight(HoverInst, Target, Props, Defaults)
    HoverInst.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Target];
        for Prop, ColorIdx in next, Props do
            Target[Prop] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Prop] then Reg.Properties[Prop] = ColorIdx; end;
        end;
    end);
    HoverInst.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Target];
        for Prop, ColorIdx in next, Defaults do
            Target[Prop] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Prop] then Reg.Properties[Prop] = ColorIdx; end;
        end;
    end);
end;

function Library:MouseIsOverOpenedFrame()
    for Frame in next, Library.OpenedFrames do
        local ap, as = Frame.AbsolutePosition, Frame.AbsoluteSize;
        if Mouse.X >= ap.X and Mouse.X <= ap.X + as.X
        and Mouse.Y >= ap.Y and Mouse.Y <= ap.Y + as.Y then
            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local ap, as = Frame.AbsolutePosition, Frame.AbsoluteSize;
    return Mouse.X >= ap.X and Mouse.X <= ap.X + as.X
       and Mouse.Y >= ap.Y and Mouse.Y <= ap.Y + as.Y;
end;

function Library:UpdateDependencyBoxes()
    for _, db in next, Library.DependencyBoxes do db:Update(); end;
end;

function Library:MapValue(v, minA, maxA, minB, maxB)
    return (1 - ((v - minA) / (maxA - minA))) * minB + ((v - minA) / (maxA - minA)) * maxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local b = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080));
    return b.X, b.Y;
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local idx  = #Library.Registry + 1;
    local data = { Instance = Instance; Properties = Properties; Idx = idx };
    table.insert(Library.Registry, data);
    Library.RegistryMap[Instance] = data;
    if IsHud then table.insert(Library.HudRegistry, data); end;
end;

function Library:RemoveFromRegistry(Instance)
    local data = Library.RegistryMap[Instance];
    if not data then return; end;
    for i = #Library.Registry, 1, -1 do
        if Library.Registry[i] == data then table.remove(Library.Registry, i); end;
    end;
    for i = #Library.HudRegistry, 1, -1 do
        if Library.HudRegistry[i] == data then table.remove(Library.HudRegistry, i); end;
    end;
    Library.RegistryMap[Instance] = nil;
end;

function Library:UpdateColorsUsingRegistry()
    for _, obj in next, Library.Registry do
        for Prop, ColorIdx in next, obj.Properties do
            if type(ColorIdx) == 'string' then
                obj.Instance[Prop] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                obj.Instance[Prop] = ColorIdx();
            end;
        end;
    end;
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal);
end;

function Library:Unload()
    for i = #Library.Signals, 1, -1 do
        table.remove(Library.Signals, i):Disconnect();
    end;
    if Library.OnUnload then Library.OnUnload(); end;
    ScreenGui:Destroy();
end;

function Library:OnUnload(Callback)
    Library.OnUnload = Callback;
end;

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(inst)
    if Library.RegistryMap[inst] then Library:RemoveFromRegistry(inst); end;
end));

local BaseAddons = {};

do
    local Funcs = {};


    function Funcs:AddColorPicker(Idx, Info)
        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ToggleLabel = self.TextLabel;

        local ColorPicker = {
            Value        = Info.Default;
            Transparency = Info.Transparency or 0;
            Type         = 'ColorPicker';
            Title        = type(Info.Title) == 'string' and Info.Title or 'Color picker';
            Callback     = Info.Callback or function() end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);
            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;
        ColorPicker:SetHSVFromRGB(ColorPicker.Value);


        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderSizePixel  = 0;
            Size             = UDim2.new(0, 28, 0, 14);
            ZIndex           = 6;
            Parent           = ToggleLabel;
        });
        AddCorner(DisplayFrame, R_SMALL);

        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size            = UDim2.new(1, 0, 1, 0);
            ZIndex          = 5;
            Image           = 'http://www.roblox.com/asset/?id=12977615774';
            Visible         = not not Info.Transparency;
            Parent          = DisplayFrame;
        });
        AddCorner(CheckerFrame, R_SMALL);


        local PickerFrameOuter = Library:Create('Frame', {
            Name             = 'Color';
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel  = 0;
            Position         = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
            Size             = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible          = false;
            ZIndex           = 15;
            Parent           = ScreenGui;
        });
        AddCorner(PickerFrameOuter, R_GROUP);

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(
                DisplayFrame.AbsolutePosition.X,
                DisplayFrame.AbsolutePosition.Y + 18
            );
        end);

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 16;
            Parent           = PickerFrameOuter;
        });
        AddCorner(PickerFrameInner, R_GROUP);

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 0, 3);
            ZIndex           = 17;
            Parent           = PickerFrameInner;
        });
        AddCorner(Highlight, R_SMALL);

        local SatVibMapOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Position         = UDim2.new(0, 4, 0, 25);
            Size             = UDim2.new(0, 200, 0, 200);
            ZIndex           = 17;
            Parent           = PickerFrameInner;
        });
        AddCorner(SatVibMapOuter, R_SMALL);

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 18;
            Parent           = SatVibMapOuter;
        });
        AddCorner(SatVibMapInner, R_SMALL);

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size            = UDim2.new(1, 0, 1, 0);
            ZIndex          = 18;
            Image           = 'rbxassetid://4155801252';
            Parent          = SatVibMapInner;
        });
        AddCorner(SatVibMap, R_SMALL);

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint          = Vector2.new(0.5, 0.5);
            Size                 = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image                = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3          = Color3.new(0, 0, 0);
            ZIndex               = 19;
            Parent               = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size                 = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position             = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image                = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex               = 20;
            Parent               = CursorOuter;
        });

        local HueSelectorOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Position         = UDim2.new(0, 208, 0, 25);
            Size             = UDim2.new(0, 15, 0, 200);
            ZIndex           = 17;
            Parent           = PickerFrameInner;
        });
        AddCorner(HueSelectorOuter, R_SMALL);

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 18;
            Parent           = HueSelectorOuter;
        });
        AddCorner(HueSelectorInner, R_SMALL);

        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint      = Vector2.new(0, 0.5);
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 0, 2);
            ZIndex           = 18;
            Parent           = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Position         = UDim2.fromOffset(4, 228);
            Size             = UDim2.new(0.5, -6, 0, 20);
            ZIndex           = 18;
            Parent           = PickerFrameInner;
        });
        AddCorner(HueBoxOuter, R_SMALL);

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 18;
            Parent           = HueBoxOuter;
        });
        AddCorner(HueBoxInner, R_SMALL);

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212));
            });
            Rotation = 90;
            Parent   = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position               = UDim2.new(0, 5, 0, 0);
            Size                   = UDim2.new(1, -5, 1, 0);
            Font                   = Library.Font;
            PlaceholderColor3      = Color3.fromRGB(190, 190, 190);
            PlaceholderText        = 'Hex color';
            Text                   = '#FFFFFF';
            TextColor3             = Library.FontColor;
            TextSize               = 14;
            TextStrokeTransparency = 0;
            TextXAlignment         = Enum.TextXAlignment.Left;
            ZIndex                 = 20;
            Parent                 = HueBoxInner;
        });
        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228);
            Size     = UDim2.new(0.5, -6, 0, 20);
            Parent   = PickerFrameInner;
        });

        local RgbBox = Library:Create(RgbBoxBase:FindFirstChildWhichIsA('TextBox', true), {
            Text            = '255, 255, 255';
            PlaceholderText = 'RGB color';
            TextColor3      = Library.FontColor;
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        if Info.Transparency then
            TransparencyBoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderSizePixel  = 0;
                Position         = UDim2.fromOffset(4, 251);
                Size             = UDim2.new(1, -8, 0, 15);
                ZIndex           = 19;
                Parent           = PickerFrameInner;
            });
            AddCorner(TransparencyBoxOuter, R_SMALL);

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderSizePixel  = 0;
                Size             = UDim2.new(1, 0, 1, 0);
                ZIndex           = 19;
                Parent           = TransparencyBoxOuter;
            });
            AddCorner(TransparencyBoxInner, R_SMALL);
            Library:AddToRegistry(TransparencyBoxInner, {});

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size                   = UDim2.new(1, 0, 1, 0);
                Image                  = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex                 = 20;
                Parent                 = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint      = Vector2.new(0.5, 0);
                BorderSizePixel  = 0;
                Size             = UDim2.new(0, 2, 1, 0);
                ZIndex           = 21;
                Parent           = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size           = UDim2.new(1, 0, 0, 14);
            Position       = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize       = 14;
            Text           = ColorPicker.Title;
            TextWrapped    = false;
            ZIndex         = 16;
            Parent         = PickerFrameInner;
        });


        local ContextMenu = {};
        do
            ContextMenu.Options   = {};
            ContextMenu.Container = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderSizePixel  = 0;
                ZIndex           = 14;
                Visible          = false;
                Parent           = ScreenGui;
            });
            AddCorner(ContextMenu.Container, R_SMALL);

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderSizePixel  = 0;
                Size             = UDim2.fromScale(1, 1);
                ZIndex           = 15;
                Parent           = ContextMenu.Container;
            });
            AddCorner(ContextMenu.Inner, R_SMALL);

            Library:Create('UIListLayout', {
                Name            = 'Layout';
                FillDirection   = Enum.FillDirection.Vertical;
                SortOrder       = Enum.SortOrder.LayoutOrder;
                Parent          = ContextMenu.Inner;
            });
            Library:Create('UIPadding', {
                Name        = 'Padding';
                PaddingLeft = UDim.new(0, 6);
                Parent      = ContextMenu.Inner;
            });

            local function updateMenuPos()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                );
            end;
            local function updateMenuSize()
                local w = 60;
                for _, lbl in next, ContextMenu.Inner:GetChildren() do
                    if lbl:IsA('TextLabel') then w = math.max(w, lbl.TextBounds.X); end;
                end;
                ContextMenu.Container.Size = UDim2.fromOffset(
                    w + 12,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                );
            end;

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPos);
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize);
            task.spawn(updateMenuPos);
            task.spawn(updateMenuSize);

            Library:AddToRegistry(ContextMenu.Inner, { BackgroundColor3 = 'BackgroundColor' });

            function ContextMenu:Show()  self.Container.Visible = true;  end;
            function ContextMenu:Hide()  self.Container.Visible = false; end;

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then Callback = function() end; end;
                local Button = Library:CreateLabel({
                    Active         = false;
                    Size           = UDim2.new(1, 0, 0, 16);
                    TextSize       = 13;
                    Text           = Str;
                    ZIndex         = 16;
                    Parent         = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left;
                });
                Library:OnHighlight(Button, Button,
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor'   }
                );
                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Callback();
                    end;
                end);
            end;

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value;
                Library:Notify('Copied color!', 2);
            end);
            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('No color copied!', 2);
                end;
                ColorPicker:SetValueRGB(Library.ColorClipboard);
            end);
            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex());
                Library:Notify('Copied HEX!', 2);
            end);
            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({
                    math.floor(ColorPicker.Value.R * 255),
                    math.floor(ColorPicker.Value.G * 255),
                    math.floor(ColorPicker.Value.B * 255),
                }, ', '));
                Library:Notify('Copied RGB!', 2);
            end);
        end;

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor' });
        Library:AddToRegistry(Highlight,        { BackgroundColor3 = 'AccentColor'     });
        Library:AddToRegistry(SatVibMapInner,   { BackgroundColor3 = 'BackgroundColor' });
        Library:AddToRegistry(HueBoxInner,      { BackgroundColor3 = 'MainColor'       });
        Library:AddToRegistry(HueBox,           { TextColor3       = 'FontColor'       });


        local GradientPoints = {};
        for i = 0, 6 do
            GradientPoints[#GradientPoints + 1] = ColorSequenceKeypoint.new(
                i / 6, Color3.fromHSV(i / 6, 1, 1)
            );
        end;
        Library:Create('UIGradient', {
            Color    = ColorSequence.new(GradientPoints);
            Rotation = 90;
            Parent   = HueSelectorInner;
        });


        local function UpdateDisplay()
            DisplayFrame.BackgroundColor3 = ColorPicker.Value;
            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
            end;
        end;

        local function UpdateCursor()
            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position   = UDim2.new(0, 0, ColorPicker.Hue, 0);
            if TransparencyCursor then
                TransparencyCursor.Position = UDim2.new(ColorPicker.Transparency, 0, 0, 0);
            end;
        end;

        local function UpdateHex()
            HueBox.Text = '#' .. ColorPicker.Value:ToHex():upper();
            RgbBox.Text = table.concat({
                math.floor(ColorPicker.Value.R * 255),
                math.floor(ColorPicker.Value.G * 255),
                math.floor(ColorPicker.Value.B * 255),
            }, ', ');
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Value = Color;
            ColorPicker:SetHSVFromRGB(Color);
            if Transparency then ColorPicker.Transparency = Transparency; end;
            UpdateDisplay();
            UpdateCursor();
            UpdateHex();
            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed,  ColorPicker.Value);
            Library:AttemptSave();
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value);
        end;


        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return; end;
            repeat
                local rel = SatVibMap.AbsolutePosition;
                local sz  = SatVibMap.AbsoluteSize;
                ColorPicker.Sat = math.clamp((Mouse.X - rel.X) / sz.X, 0, 1);
                ColorPicker.Vib = 1 - math.clamp((Mouse.Y - rel.Y) / sz.Y, 0, 1);
                ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
                UpdateDisplay(); UpdateCursor(); UpdateHex();
                Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
                Library:SafeCallback(ColorPicker.Changed,  ColorPicker.Value);
                RenderStepped:Wait();
            until not InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1);
            Library:AttemptSave();
        end);


        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return; end;
            repeat
                local rel = HueSelectorInner.AbsolutePosition;
                local sz  = HueSelectorInner.AbsoluteSize;
                ColorPicker.Hue = math.clamp((Mouse.Y - rel.Y) / sz.Y, 0, 1);
                ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
                SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);
                UpdateDisplay(); UpdateCursor(); UpdateHex();
                Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
                Library:SafeCallback(ColorPicker.Changed,  ColorPicker.Value);
                RenderStepped:Wait();
            until not InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1);
            Library:AttemptSave();
        end);


        if TransparencyBoxInner and TransparencyCursor then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return; end;
                repeat
                    local rel = TransparencyBoxInner.AbsolutePosition;
                    local sz  = TransparencyBoxInner.AbsoluteSize;
                    ColorPicker.Transparency = math.clamp((Mouse.X - rel.X) / sz.X, 0, 1);
                    UpdateCursor();
                    Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
                    Library:SafeCallback(ColorPicker.Changed,  ColorPicker.Value);
                    RenderStepped:Wait();
                until not InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1);
                Library:AttemptSave();
            end);
        end;


        HueBox.FocusLost:Connect(function()
            local hex = HueBox.Text:gsub('#', '');
            local ok, col = pcall(Color3.fromHex, hex);
            if ok then ColorPicker:SetValueRGB(col); end;
        end);


        RgbBox.FocusLost:Connect(function()
            local parts = RgbBox.Text:split(',');
            local r, g, b = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3]);
            if r and g and b then
                ColorPicker:SetValueRGB(Color3.fromRGB(
                    math.clamp(r, 0, 255),
                    math.clamp(g, 0, 255),
                    math.clamp(b, 0, 255)
                ));
            end;
        end);


        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 then
                ContextMenu:Show();
            elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                ContextMenu:Hide();
                PickerFrameOuter.Visible = not PickerFrameOuter.Visible;
                if PickerFrameOuter.Visible then
                    Library.OpenedFrames[PickerFrameOuter] = true;
                else
                    Library.OpenedFrames[PickerFrameOuter] = nil;
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if not Library:IsMouseOverFrame(PickerFrameOuter) and PickerFrameOuter.Visible then
                    PickerFrameOuter.Visible = false;
                    Library.OpenedFrames[PickerFrameOuter] = nil;
                end;
                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide();
                end;
            end;
        end);

        UpdateDisplay();
        UpdateCursor();
        UpdateHex();

        Options[Idx] = ColorPicker;
        return ColorPicker;
    end;


    function Funcs:AddKeyPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;

        local KeyPicker = {
            Value           = Info.Default or 'None';
            Mode            = Info.Mode or 'Toggle';
            Type            = 'KeyPicker';
            Toggled         = false;
            NoUI            = Info.NoUI or false;
            SyncToggleState = Info.SyncToggleState;
            Callback        = Info.Callback or function() end;
            ChangedCallback = Info.ChangedCallback or function() end;
            ClickCallback   = nil;
        };

        local KeyLabel = Library:Create('TextButton', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(0, 40, 0, 14);
            Font             = Library.Font;
            Text             = '[' .. KeyPicker.Value .. ']';
            TextColor3       = Library.FontColor;
            TextSize         = 13;
            ZIndex           = 6;
            Parent           = ToggleLabel;
        });
        AddCorner(KeyLabel, R_SMALL);
        Library:AddToRegistry(KeyLabel, { BackgroundColor3 = 'MainColor'; TextColor3 = 'FontColor' });

        local ModeLabel = Library:CreateLabel({
            Size           = UDim2.new(0, 60, 0, 14);
            TextSize       = 13;
            Text           = KeyPicker.Mode;
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex         = 6;
            Parent         = ToggleLabel;
        });

        local Listening = false;

        function KeyPicker:Update()
            KeyLabel.Text = Listening and '[...]' or ('[' .. KeyPicker.Value .. ']');
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then return true; end;
            return KeyPicker.Toggled;
        end;

        function KeyPicker:OnClick(Func)
            KeyPicker.ClickCallback = Func;
        end;

        function KeyPicker:SetValue(Data)
            KeyPicker.Value = Data[1] or 'None';
            KeyPicker.Mode  = Data[2] or 'Toggle';
            ModeLabel.Text  = KeyPicker.Mode;
            KeyPicker:Update();
            Library:SafeCallback(KeyPicker.ChangedCallback, KeyPicker.Value);
        end;

        function KeyPicker:OnChanged(Func)
            KeyPicker.ChangedCallback = Func;
            Func(KeyPicker.Value);
        end;

        KeyLabel.MouseButton1Click:Connect(function()
            if Listening then return; end;
            Listening = true;
            KeyPicker:Update();
            local conn;
            conn = InputService.InputBegan:Connect(function(Input, Processed)
                if Processed then return; end;
                local name = Input.KeyCode.Name ~= 'Unknown'
                    and Input.KeyCode.Name
                    or  Input.UserInputType.Name;
                KeyPicker.Value = name;
                KeyPicker:Update();
                Library:SafeCallback(KeyPicker.ChangedCallback, KeyPicker.Value);
                Library:AttemptSave();
                Listening = false;
                conn:Disconnect();
            end);
        end);

        KeyLabel.MouseButton2Click:Connect(function()
            local modes = { 'Toggle', 'Hold', 'Always' };
            local cur = 1;
            for i, m in next, modes do if m == KeyPicker.Mode then cur = i; break; end; end;
            KeyPicker.Mode = modes[(cur % #modes) + 1];
            ModeLabel.Text = KeyPicker.Mode;
            Library:AttemptSave();
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
            if Processed then return; end;
            local name = Input.KeyCode.Name ~= 'Unknown'
                and Input.KeyCode.Name
                or  Input.UserInputType.Name;
            if name ~= KeyPicker.Value then return; end;

            if KeyPicker.Mode == 'Toggle' then
                KeyPicker.Toggled = not KeyPicker.Toggled;
                Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled);
                Library:SafeCallback(KeyPicker.ClickCallback);
            elseif KeyPicker.Mode == 'Hold' then
                KeyPicker.Toggled = true;
                Library:SafeCallback(KeyPicker.Callback, true);
            elseif KeyPicker.Mode == 'Always' then
                Library:SafeCallback(KeyPicker.Callback, true);
                Library:SafeCallback(KeyPicker.ClickCallback);
            end;
        end));

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            local name = Input.KeyCode.Name ~= 'Unknown'
                and Input.KeyCode.Name
                or  Input.UserInputType.Name;
            if name == KeyPicker.Value and KeyPicker.Mode == 'Hold' then
                KeyPicker.Toggled = false;
                Library:SafeCallback(KeyPicker.Callback, false);
            end;
        end));

        if Library.KeybindContainer and not KeyPicker.NoUI then
            local KBLabel = Library:CreateLabel({
                Size           = UDim2.new(1, -10, 0, 18);
                TextSize       = 13;
                Text           = (Info.Text or Idx) .. ' [' .. KeyPicker.Value .. ']';
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex         = 104;
                Parent         = Library.KeybindContainer;
            });
            function KeyPicker:UpdateKeybindLabel()
                KBLabel.Text = (Info.Text or Idx) .. ' [' .. KeyPicker.Value .. ']';
            end;
        end;

        Options[Idx] = KeyPicker;
        KeyPicker:Update();
        return KeyPicker;
    end;

    BaseAddons.__index = Funcs;
end;

local BaseGroupbox = {};
do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size                   = UDim2.new(1, 0, 0, Size);
            ZIndex                 = 1;
            Parent                 = self.Container;
        });
    end;

    function Funcs:AddDivider()
        Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, -8, 0, 1);
            ZIndex           = 5;
            Parent           = self.Container;
        });
        Library:AddToRegistry(self.Container:FindFirstChildWhichIsA('Frame'), { BackgroundColor3 = 'OutlineColor' });
        self:AddBlank(3);
        self:Resize();
    end;

    function Funcs:AddLabel(Text, CanUpdate)
        local Label = Library:CreateLabel({
            Size           = UDim2.new(1, 0, 0, 16);
            TextSize       = 14;
            Text           = Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex         = 5;
            Parent         = self.Container;
        });
        self:AddBlank(4);
        self:Resize();
        if CanUpdate then
            return setmetatable({ TextLabel = Label }, {
                __index = Funcs;
                SetText = function(_, t) Label.Text = t; end;
            });
        end;
        return setmetatable({ TextLabel = Label }, BaseAddons);
    end;

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.');

        local Textbox = {
            Value    = Info.Default or '';
            Type     = 'Input';
            Callback = Info.Callback or function() end;
        };

        Library:CreateLabel({
            Size           = UDim2.new(1, 0, 0, 10);
            TextSize       = 14;
            Text           = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextYAlignment = Enum.TextYAlignment.Bottom;
            ZIndex         = 5;
            Parent         = self.Container;
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, self.Container:GetChildren()[#self.Container:GetChildren()]);
        end;

        self:AddBlank(3);

        local BoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, -4, 0, 16);
            ZIndex           = 5;
            Parent           = self.Container;
        });
        AddCorner(BoxOuter, R_ELEMENT);

        local BoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = BoxOuter;
        });
        AddCorner(BoxInner, R_ELEMENT);
        Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'MainColor' });

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            ClearTextOnFocus       = false;
            Position               = UDim2.new(0, 4, 0, 0);
            Size                   = UDim2.new(1, -8, 1, 0);
            Font                   = Library.Font;
            PlaceholderColor3      = Color3.fromRGB(160, 160, 160);
            PlaceholderText        = Info.Placeholder or '';
            Text                   = Textbox.Value;
            TextColor3             = Library.FontColor;
            TextSize               = 14;
            TextStrokeTransparency = 0;
            TextXAlignment         = Enum.TextXAlignment.Left;
            ZIndex                 = 7;
            Parent                 = BoxInner;
        });
        Library:ApplyTextStroke(Box);
        Library:AddToRegistry(Box, { TextColor3 = 'FontColor' });

        if Info.Numeric then
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                local clean = Box.Text:gsub('[^%d%.%-]', '');
                if clean ~= Box.Text then
                    Box.Text = clean;
                end;
            end);
        end;

        if Info.MaxLength then
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                if #Box.Text > Info.MaxLength then
                    Box.Text = Box.Text:sub(1, Info.MaxLength);
                end;
            end);
        end;

        if Info.Finished then
            Box.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    Textbox.Value = Box.Text;
                    Library:SafeCallback(Textbox.Callback, Textbox.Value);
                    Library:SafeCallback(Textbox.Changed,  Textbox.Value);
                    Library:AttemptSave();
                end;
            end);
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox.Value = Box.Text;
                Library:SafeCallback(Textbox.Callback, Textbox.Value);
                Library:SafeCallback(Textbox.Changed,  Textbox.Value);
            end);
        end;

        function Textbox:SetValue(str)
            Box.Text = str;
            Textbox.Value = str;
        end;
        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        self:AddBlank(5);
        self:Resize();
        Options[Idx] = Textbox;
        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text` string.');

        local Toggle = {
            Value    = Info.Default or false;
            Type     = 'Toggle';
            Callback = Info.Callback or function() end;
            Addons   = {};
            Risky    = Info.Risky;
        };

        local Container = self.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Size             = UDim2.new(0, 14, 0, 14);
            ZIndex           = 5;
            Parent           = Container;
        });
        AddCorner(ToggleOuter, R_ELEMENT);

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = ToggleOuter;
        });
        AddCorner(ToggleInner, R_ELEMENT);
        Library:AddToRegistry(ToggleInner, { BackgroundColor3 = 'MainColor' });

        local ToggleLabel = Library:CreateLabel({
            Size           = UDim2.new(0, 216, 1, 0);
            Position       = UDim2.new(1, 6, 0, 0);
            TextSize       = 14;
            Text           = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex         = 6;
            Parent         = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding               = UDim.new(0, 4);
            FillDirection         = Enum.FillDirection.Horizontal;
            HorizontalAlignment   = Enum.HorizontalAlignment.Right;
            SortOrder             = Enum.SortOrder.LayoutOrder;
            Parent                = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size                   = UDim2.new(0, 170, 1, 0);
            ZIndex                 = 8;
            Parent                 = ToggleOuter;
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion);
        end;

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 =
                Toggle.Value and 'AccentColor' or 'MainColor';
        end;
        Toggle.UpdateColors = Toggle.Display;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Toggle.Value = not not Bool;
            Toggle:Display();
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Toggle.Value;
                    Addon:Update();
                end;
            end;
            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed,  Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1
            and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value);
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel);
            ToggleLabel.TextColor3 = Library.RiskColor;
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' });
        end;

        Toggle:Display();
        self:AddBlank(Info.BlankSize or 7);
        self:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);
        Toggles[Idx] = Toggle;
        Library:UpdateDependencyBoxes();
        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default,  'AddSlider: Missing default value.');
        assert(Info.Text,     'AddSlider: Missing slider text.');
        assert(Info.Min,      'AddSlider: Missing minimum value.');
        assert(Info.Max,      'AddSlider: Missing maximum value.');
        assert(Info.Rounding ~= nil, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value    = Info.Default;
            Min      = Info.Min;
            Max      = Info.Max;
            Rounding = Info.Rounding;
            MaxSize  = 232;
            Type     = 'Slider';
            Callback = Info.Callback or function() end;
        };

        local Container = self.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size           = UDim2.new(1, 0, 0, 10);
                TextSize       = 14;
                Text           = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex         = 5;
                Parent         = Container;
            });
            self:AddBlank(3);
        end;

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, -4, 0, 14);
            ZIndex           = 5;
            Parent           = Container;
        });
        AddCorner(SliderOuter, R_ELEMENT);

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = SliderOuter;
        });
        AddCorner(SliderInner, R_ELEMENT);
        Library:AddToRegistry(SliderInner, { BackgroundColor3 = 'MainColor' });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(0, 0, 1, 0);
            ZIndex           = 7;
            Parent           = SliderInner;
        });
        AddCorner(Fill, R_ELEMENT);
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' });

        local DisplayLabel = Library:CreateLabel({
            Size     = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text     = '';
            ZIndex   = 9;
            Parent   = SliderInner;
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter);
        end;

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';
            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix;
            elseif Info.HideMax then
                DisplayLabel.Text = Slider.Value .. Suffix;
            else
                DisplayLabel.Text = Slider.Value .. Suffix .. '/' .. Slider.Max .. Suffix;
            end;
            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(v)
            if Slider.Rounding == 0 then return math.floor(v); end;
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', v));
        end;

        function Slider:SetValue(Str)
            local Num = math.clamp(tonumber(Str) or Slider.Min, Slider.Min, Slider.Max);
            Slider.Value = Round(Num);
            Slider:Display();
            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed,  Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1
            and not Library:MouseIsOverOpenedFrame() then
                local startX = Mouse.X;
                local startOff = Fill.Size.X.Offset;
                local diff = startX - (Fill.AbsolutePosition.X + startOff);
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nX = math.clamp(startOff + (Mouse.X - startX) + diff, 0, Slider.MaxSize);
                    local nVal = Round(Library:MapValue(nX, 0, Slider.MaxSize, Slider.Min, Slider.Max));
                    local old  = Slider.Value;
                    Slider.Value = nVal;
                    Slider:Display();
                    if nVal ~= old then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed,  Slider.Value);
                    end;
                    RenderStepped:Wait();
                end;
                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        self:AddBlank(Info.BlankSize or 6);
        self:Resize();
        Options[Idx] = Slider;
        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString(); Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString(); Info.AllowNull = true;
        end;
        assert(Info.Values, 'AddDropdown: Missing value list.');
        assert(Info.AllowNull or Info.Default,
            'AddDropdown: Missing default. Use AllowNull=true if intentional.');
        if not Info.Text then Info.Compact = true; end;

        local Dropdown = {
            Values      = Info.Values;
            Value       = Info.Multi and {} or nil;
            Multi       = Info.Multi;
            Type        = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback    = Info.Callback or function() end;
        };

        local Container = self.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size           = UDim2.new(1, 0, 0, 10);
                TextSize       = 14;
                Text           = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex         = 5;
                Parent         = Container;
            });
            self:AddBlank(3);
        end;

        local BoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, -4, 0, 18);
            ZIndex           = 5;
            Parent           = Container;
        });
        AddCorner(BoxOuter, R_ELEMENT);

        local BoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = BoxOuter;
        });
        AddCorner(BoxInner, R_ELEMENT);
        Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'MainColor' });

        local ValueLabel = Library:CreateLabel({
            Position       = UDim2.new(0, 6, 0, 0);
            Size           = UDim2.new(1, -20, 1, 0);
            TextSize       = 14;
            Text           = Info.AllowNull and '' or tostring(Info.Default or '');
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTruncate   = Enum.TextTruncate.AtEnd;
            ZIndex         = 7;
            Parent         = BoxInner;
        });


        Library:CreateLabel({
            Position       = UDim2.new(1, -16, 0, 1);
            Size           = UDim2.new(0, 12, 1, 0);
            TextSize       = 14;
            Text           = '▾';
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex         = 7;
            Parent         = BoxInner;
        });


        local ListFrame = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel  = 0;
            Position         = UDim2.fromOffset(BoxOuter.AbsolutePosition.X, BoxOuter.AbsolutePosition.Y + 20);
            Size             = UDim2.fromOffset(BoxOuter.AbsoluteSize.X, 0);
            Visible          = false;
            ZIndex           = 20;
            ClipsDescendants = true;
            Parent           = ScreenGui;
        });
        AddCorner(ListFrame, R_ELEMENT);
        Library:AddToRegistry(ListFrame, { BackgroundColor3 = 'MainColor' });

        BoxOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ListFrame.Position = UDim2.fromOffset(
                BoxOuter.AbsolutePosition.X,
                BoxOuter.AbsolutePosition.Y + BoxOuter.AbsoluteSize.Y + 2
            );
        end);

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder     = Enum.SortOrder.LayoutOrder;
            Parent        = ListFrame;
        });
        Library:Create('UIPadding', {
            PaddingTop    = UDim.new(0, 2);
            PaddingBottom = UDim.new(0, 2);
            PaddingLeft   = UDim.new(0, 4);
            Parent        = ListFrame;
        });

        local function RebuildList()
            for _, c in next, ListFrame:GetChildren() do
                if not c:IsA('UIListLayout') and not c:IsA('UIPadding') then c:Destroy(); end;
            end;

            local maxW = 80;
            local allVals = {};

            if Info.AllowNull then
                table.insert(allVals, 1, nil);
            end;
            for _, v in next, Dropdown.Values do
                table.insert(allVals, v);
            end;

            for _, val in next, Dropdown.Values do
                local isSelected = Info.Multi
                    and Dropdown.Value[val]
                    or  Dropdown.Value == val;

                local entry = Library:CreateLabel({
                    Size           = UDim2.new(1, 0, 0, 18);
                    TextSize       = 14;
                    Text           = tostring(val);
                    TextXAlignment = Enum.TextXAlignment.Left;
                    TextColor3     = isSelected and Library.AccentColor or Library.FontColor;
                    ZIndex         = 21;
                    Parent         = ListFrame;
                });

                local tw = Library:GetTextBounds(tostring(val), Library.Font, 14);
                if tw + 16 > maxW then maxW = tw + 16; end;

                Library:OnHighlight(entry, entry,
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = isSelected and 'AccentColor' or 'FontColor' }
                );

                entry.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return; end;
                    if Info.Multi then
                        Dropdown.Value[val] = not Dropdown.Value[val] or nil;
                    else
                        Dropdown.Value = val;
                        ListFrame.Visible = false;
                        Library.OpenedFrames[ListFrame] = nil;
                    end;
                    ValueLabel.Text = Info.Multi
                        and table.concat((function()
                            local t = {};
                            for k in next, Dropdown.Value do table.insert(t, k); end;
                            return t;
                        end)(), ', ')
                        or  tostring(Dropdown.Value or '');
                    RebuildList();
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                    Library:SafeCallback(Dropdown.Changed,  Dropdown.Value);
                    Library:AttemptSave();
                end);
            end;

            local listLayout = ListFrame:FindFirstChildWhichIsA('UIListLayout');
            ListFrame.Size = UDim2.fromOffset(
                math.max(BoxOuter.AbsoluteSize.X, maxW),
                listLayout and listLayout.AbsoluteContentSize.Y + 4 or 0
            );
        end;

        BoxInner.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1
            or Library:MouseIsOverOpenedFrame() then return; end;
            local open = not ListFrame.Visible;
            ListFrame.Visible = open;
            Library.OpenedFrames[ListFrame] = open or nil;
            if open then
                ListFrame.Position = UDim2.fromOffset(
                    BoxOuter.AbsolutePosition.X,
                    BoxOuter.AbsolutePosition.Y + BoxOuter.AbsoluteSize.Y + 2
                );
                RebuildList();
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1
            and not Library:IsMouseOverFrame(ListFrame)
            and not Library:IsMouseOverFrame(BoxInner) then
                ListFrame.Visible = false;
                Library.OpenedFrames[ListFrame] = nil;
            end;
        end);

        function Dropdown:SetValue(val)
            if Info.Multi then
                Dropdown.Value = type(val) == 'table' and val or {};
            else
                Dropdown.Value = val;
            end;
            ValueLabel.Text = Info.Multi
                and table.concat((function()
                    local t = {};
                    for k in next, Dropdown.Value do table.insert(t, k); end;
                    return t;
                end)(), ', ')
                or  tostring(Dropdown.Value or '');
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed,  Dropdown.Value);
        end;

        function Dropdown:SetValues(vals)
            Dropdown.Values = vals;
            RebuildList();
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;


        if not Info.AllowNull then
            if Info.Multi then
                Dropdown.Value = {};
            else
                Dropdown.Value = type(Info.Default) == 'number'
                    and Dropdown.Values[Info.Default]
                    or  Info.Default;
                ValueLabel.Text = tostring(Dropdown.Value or '');
            end;
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, BoxOuter);
        end;

        self:AddBlank(Info.BlankSize or 6);
        self:Resize();
        Options[Idx] = Dropdown;
        return Dropdown;
    end;

    function Funcs:AddButton(InfoOrText, Callback)
        local Info;
        if type(InfoOrText) == 'table' then
            Info = InfoOrText;
        else
            Info = { Text = InfoOrText; Func = Callback; };
        end;

        local Button = {
            Type        = 'Button';
            Callback    = Info.Func or Info.Callback or function() end;
            DoubleClick = Info.DoubleClick or false;
        };

        local BtnOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, -4, 0, 18);
            ZIndex           = 5;
            Parent           = self.Container;
        });
        AddCorner(BtnOuter, R_ELEMENT);

        local BtnInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(1, 0, 1, 0);
            ZIndex           = 6;
            Parent           = BtnOuter;
        });
        AddCorner(BtnInner, R_ELEMENT);
        Library:AddToRegistry(BtnInner, { BackgroundColor3 = 'MainColor' });

        Library:CreateLabel({
            Size     = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text     = Info.Text or '';
            ZIndex   = 7;
            Parent   = BtnInner;
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, BtnInner);
        end;

        Library:OnHighlight(BtnInner, BtnInner,
            { BackgroundColor3 = 'AccentColor' },
            { BackgroundColor3 = 'MainColor'   }
        );

        local LastClick = 0;
        BtnInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1
            and not Library:MouseIsOverOpenedFrame() then
                if Button.DoubleClick then
                    local now = tick();
                    if (now - LastClick) <= 0.35 then
                        Library:SafeCallback(Button.Callback);
                        LastClick = 0;
                    else
                        LastClick = now;
                    end;
                else
                    Library:SafeCallback(Button.Callback);
                end;
            end;
        end);

        self:AddBlank(5);
        self:Resize();

        function Button:AddButton(Info2, Cb2)
            return Funcs.AddButton(self, Info2, Cb2);
        end;

        return Button;
    end;

    function Funcs:AddDependencyBox()
        local DepBox = {
            Type       = 'DependencyBox';
            Conditions = {};
        };

        local BoxFrame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size                   = UDim2.new(1, 0, 0, 0);
            ZIndex                 = 5;
            Visible                = false;
            Parent                 = self.Container;
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder     = Enum.SortOrder.LayoutOrder;
            Parent        = BoxFrame;
        });

        DepBox.Container = BoxFrame;
        DepBox.Parent    = self;

        function DepBox:Update()
            local allMet = true;
            for _, cond in next, DepBox.Conditions do
                if not cond() then allMet = false; break; end;
            end;

            BoxFrame.Visible = allMet;
            BoxFrame.Size = UDim2.new(1, 0, 0, allMet
                and BoxFrame:FindFirstChildWhichIsA('UIListLayout').AbsoluteContentSize.Y
                or  0
            );
            DepBox.Parent:Resize();
        end;

        function DepBox:AddCondition(Func)
            table.insert(DepBox.Conditions, Func);
            DepBox:Update();
        end;

        function DepBox:SetupDependencies(deps)
            for _, dep in next, deps do
                local toggle, expectedVal = dep[1], dep[2];
                DepBox:AddCondition(function()
                    return toggle.Value == expectedVal;
                end);
                toggle:OnChanged(function()
                    DepBox:Update();
                end);
            end;
        end;

        setmetatable(DepBox, { __index = Funcs });
        table.insert(Library.DependencyBoxes, DepBox);
        self:Resize();
        return DepBox;
    end;

    BaseGroupbox.__index = Funcs;
end;

do
    local WatermarkOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel  = 0;
        Position         = UDim2.fromOffset(10, 10);
        Size             = UDim2.fromOffset(0, 22);
        Visible          = false;
        ZIndex           = 100;
        Parent           = ScreenGui;
    });
    AddCorner(WatermarkOuter, R_SMALL);
    Library:AddToRegistry(WatermarkOuter, { BackgroundColor3 = 'MainColor' });

    local WatermarkText = Library:CreateLabel({
        Position       = UDim2.fromOffset(7, 2);
        Size           = UDim2.new(1, -14, 1, -4);
        TextSize       = 14;
        Text           = '';
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex         = 101;
        Parent         = WatermarkOuter;
    }, true);

    Library.Watermark     = WatermarkOuter;
    Library.WatermarkText = WatermarkText;
    Library:MakeDraggable(WatermarkOuter);
end;

do
    local NotifArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        AnchorPoint            = Vector2.new(0, 1);
        Position               = UDim2.new(0, 10, 1, -10);
        Size                   = UDim2.new(0, 300, 0, 400);
        ZIndex                 = 99;
        Parent                 = ScreenGui;
    });

    Library:Create('UIListLayout', {
        FillDirection         = Enum.FillDirection.Vertical;
        VerticalAlignment     = Enum.VerticalAlignment.Bottom;
        SortOrder             = Enum.SortOrder.LayoutOrder;
        Padding               = UDim.new(0, 4);
        Parent                = NotifArea;
    });

    Library.NotificationArea = NotifArea;
end;

do
    local KeybindOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel  = 0;
        Position         = UDim2.fromOffset(10, 200);
        Size             = UDim2.fromOffset(120, 20);
        ZIndex           = 103;
        Parent           = ScreenGui;
    });
    AddCorner(KeybindOuter, R_GROUP);
    Library:AddToRegistry(KeybindOuter, { BackgroundColor3 = 'MainColor' });

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel  = 0;
        Size             = UDim2.new(1, 0, 1, 0);
        ZIndex           = 104;
        Parent           = KeybindOuter;
    });
    AddCorner(KeybindInner, R_GROUP);
    Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'BackgroundColor' });

    Library:CreateLabel({
        Position       = UDim2.fromOffset(5, 2);
        Size           = UDim2.new(1, -10, 0, 16);
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize       = 13;
        Text           = 'Keybinds';
        ZIndex         = 104;
        Parent         = KeybindInner;
    }, true);

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size                   = UDim2.new(1, 0, 1, -20);
        Position               = UDim2.new(0, 0, 0, 20);
        ZIndex                 = 1;
        Parent                 = KeybindInner;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder     = Enum.SortOrder.LayoutOrder;
        Parent        = KeybindContainer;
    });
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5);
        Parent      = KeybindContainer;
    });

    Library.KeybindFrame     = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, X + 14, 0, Y + 6);
    Library:SetWatermarkVisibility(true);
    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);
    YSize = YSize + 8;

    local NotifyOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel  = 0;
        Size             = UDim2.new(0, 0, 0, YSize + 4);
        ClipsDescendants = true;
        ZIndex           = 100;
        Parent           = Library.NotificationArea;
    });
    AddCorner(NotifyOuter, R_SMALL);
    Library:AddToRegistry(NotifyOuter, { BackgroundColor3 = 'MainColor' }, true);


    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel  = 0;
        Size             = UDim2.new(0, 4, 1, 0);
        ZIndex           = 102;
        Parent           = NotifyOuter;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 3), Parent = LeftColor });
    Library:AddToRegistry(LeftColor, { BackgroundColor3 = 'AccentColor' }, true);

    local NotifyLabel = Library:CreateLabel({
        Position       = UDim2.new(0, 10, 0, 0);
        Size           = UDim2.new(1, -14, 1, 0);
        Text           = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize       = 14;
        ZIndex         = 103;
        Parent         = NotifyOuter;
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter,
        UDim2.new(0, XSize + 18, 0, YSize + 4), 'Out', 'Quad', 0.35, true);

    task.spawn(function()
        task.wait(Time or 5);
        pcall(NotifyOuter.TweenSize, NotifyOuter,
            UDim2.new(0, 0, 0, YSize + 4), 'Out', 'Quad', 0.35, true);
        task.wait(0.4);
        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... };
    local Config    = { AnchorPoint = Vector2.zero };

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title    = Arguments[1];
        Config.AutoShow = Arguments[2] or false;
    end;

    if type(Config.Title)       ~= 'string' then Config.Title       = 'No title'; end;
    if type(Config.TabPadding)  ~= 'number' then Config.TabPadding  = 0;          end;
    if type(Config.MenuFadeTime)~= 'number' then Config.MenuFadeTime = 0.2;        end;
    if typeof(Config.Position)  ~= 'UDim2'  then Config.Position    = UDim2.fromOffset(175, 50); end;
    if typeof(Config.Size)      ~= 'UDim2'  then Config.Size        = UDim2.fromOffset(550, 600); end;

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5);
        Config.Position    = UDim2.fromScale(0.5, 0.5);
    end;

    local Window = { Tabs = {} };


    local Outer = Library:Create('Frame', {
        AnchorPoint      = Config.AnchorPoint;
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel  = 0;
        Position         = Config.Position;
        Size             = Config.Size;
        Visible          = false;
        ZIndex           = 1;
        Parent           = ScreenGui;
    });
    AddCorner(Outer, R_WINDOW);
    Library:MakeDraggable(Outer, 28);


    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel  = 0;
        Size             = UDim2.new(1, 0, 1, 0);
        ZIndex           = 1;
        Parent           = Outer;
    });
    AddCorner(Inner, R_WINDOW);
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor' });


    local TopBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel  = 0;
        Size             = UDim2.new(1, 0, 0, 3);
        ZIndex           = 2;
        Parent           = Inner;
    });
    AddCorner(TopBar, UDim.new(0, 2));
    Library:AddToRegistry(TopBar, { BackgroundColor3 = 'AccentColor' });

    local WindowLabel = Library:CreateLabel({
        Position       = UDim2.new(0, 10, 0, 3);
        Size           = UDim2.new(1, -20, 0, 24);
        Text           = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize       = 15;
        ZIndex         = 2;
        Parent         = Inner;
    });


    local MainSection = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel  = 0;
        Position         = UDim2.new(0, 8, 0, 28);
        Size             = UDim2.new(1, -16, 1, -36);
        ZIndex           = 1;
        Parent           = Inner;
    });
    AddCorner(MainSection, R_GROUP);
    Library:AddToRegistry(MainSection, { BackgroundColor3 = 'BackgroundColor' });


    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position               = UDim2.new(0, 8, 0, 8);
        Size                   = UDim2.new(1, -16, 0, 22);
        ZIndex                 = 1;
        Parent                 = MainSection;
    });
    local TabListLayout = Library:Create('UIListLayout', {
        Padding       = UDim.new(0, Config.TabPadding + 2);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder     = Enum.SortOrder.LayoutOrder;
        Parent        = TabArea;
    });


    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel  = 0;
        Position         = UDim2.new(0, 8, 0, 32);
        Size             = UDim2.new(1, -16, 1, -40);
        ZIndex           = 2;
        Parent           = MainSection;
    });
    AddCorner(TabContainer, R_ELEMENT);
    Library:AddToRegistry(TabContainer, { BackgroundColor3 = 'MainColor' });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:AddTab(Name)
        local Tab = { Groupboxes = {}; Tabboxes = {} };

        local TabBtnWidth = Library:GetTextBounds(Name, Library.Font, 14);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderSizePixel  = 0;
            Size             = UDim2.new(0, TabBtnWidth + 14, 1, 0);
            ZIndex           = 2;
            Parent           = TabArea;
        });
        AddCorner(TabButton, R_SMALL);
        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor' });

        local TabButtonLabel = Library:CreateLabel({
            Size     = UDim2.new(1, 0, 1, -1);
            TextSize = 14;
            Text     = Name;
            ZIndex   = 2;
            Parent   = TabButton;
        });


        local Blocker = Library:Create('Frame', {
            BackgroundColor3   = Library.MainColor;
            BorderSizePixel    = 0;
            Position           = UDim2.new(0, 0, 1, -1);
            Size               = UDim2.new(1, 0, 0, 3);
            BackgroundTransparency = 1;
            ZIndex             = 4;
            Parent             = TabButton;
        });
        Library:AddToRegistry(Blocker, { BackgroundColor3 = 'MainColor' });

        local TabFrame = Library:Create('Frame', {
            Name                   = 'TabFrame';
            BackgroundTransparency = 1;
            Size                   = UDim2.new(1, 0, 1, 0);
            Visible                = false;
            ZIndex                 = 2;
            Parent                 = TabContainer;
        });

        local function MakeSide(xOff, wOff)
            local sf = Library:Create('ScrollingFrame', {
                BackgroundTransparency = 1;
                BorderSizePixel        = 0;
                Position               = UDim2.new(xOff, 8, 0, 8);
                Size                   = UDim2.new(wOff, -16, 1, -16);
                CanvasSize             = UDim2.new(0, 0, 0, 0);
                BottomImage            = '';
                TopImage               = '';
                ScrollBarThickness     = 0;
                ZIndex                 = 2;
                Parent                 = TabFrame;
            });
            Library:Create('UIListLayout', {
                Padding              = UDim.new(0, 8);
                FillDirection        = Enum.FillDirection.Vertical;
                SortOrder            = Enum.SortOrder.LayoutOrder;
                HorizontalAlignment  = Enum.HorizontalAlignment.Center;
                Parent               = sf;
            });
            sf:FindFirstChildWhichIsA('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                sf.CanvasSize = UDim2.fromOffset(0, sf:FindFirstChildWhichIsA('UIListLayout').AbsoluteContentSize.Y + 8);
            end);
            return sf;
        end;

        local LeftSide  = MakeSide(0,    0.5);
        local RightSide = MakeSide(0.5,  0.5);

        function Tab:ShowTab()
            for _, t in next, Window.Tabs do t:HideTab(); end;
            Blocker.BackgroundTransparency = 0;
            TabButton.BackgroundColor3 = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1;
            TabButton.BackgroundColor3 = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(pos)
            TabButton.LayoutOrder = pos;
            TabListLayout:ApplyLayout();
        end;


        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local Side = Info.Side == 1 and LeftSide or RightSide;

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderSizePixel  = 0;
                Size             = UDim2.new(1, 0, 0, 30);
                ZIndex           = 2;
                Parent           = Side;
            });
            AddCorner(BoxOuter, R_GROUP);
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor' });


            local GBHighlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel  = 0;
                Size             = UDim2.new(1, 0, 0, 3);
                ZIndex           = 3;
                Parent           = BoxOuter;
            });
            Library:Create('UICorner', {
                CornerRadius = UDim.new(0, 4);
                Parent       = GBHighlight;
            });
            Library:AddToRegistry(GBHighlight, { BackgroundColor3 = 'AccentColor' });

            local GroupboxLabel = Library:CreateLabel({
                Size           = UDim2.new(1, -8, 0, 18);
                Position       = UDim2.new(0, 6, 0, 3);
                TextSize       = 13;
                Text           = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex         = 3;
                Parent         = BoxOuter;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position               = UDim2.new(0, 6, 0, 21);
                Size                   = UDim2.new(1, -6, 1, -21);
                ZIndex                 = 1;
                Parent                 = BoxOuter;
            });
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder     = Enum.SortOrder.LayoutOrder;
                Parent        = Container;
            });

            function Groupbox:Resize()
                local sz = 0;
                for _, el in next, Groupbox.Container:GetChildren() do
                    if not el:IsA('UIListLayout') and el.Visible then
                        sz = sz + el.Size.Y.Offset;
                    end;
                end;
                BoxOuter.Size = UDim2.new(1, 0, 0, 22 + sz + 4);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);
            Groupbox:AddBlank(3);
            Groupbox:Resize();
            Tab.Groupboxes[Info.Name] = Groupbox;
            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name });
        end;
        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name });
        end;


        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {} };
            local Side = Info.Side == 1 and LeftSide or RightSide;

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderSizePixel  = 0;
                Size             = UDim2.new(1, 0, 0, 0);
                ZIndex           = 2;
                Parent           = Side;
            });
            AddCorner(BoxOuter, R_GROUP);
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor' });

            local TBHighlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel  = 0;
                Size             = UDim2.new(1, 0, 0, 3);
                ZIndex           = 10;
                Parent           = BoxOuter;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 4), Parent = TBHighlight });
            Library:AddToRegistry(TBHighlight, { BackgroundColor3 = 'AccentColor' });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position               = UDim2.new(0, 0, 0, 2);
                Size                   = UDim2.new(1, 0, 0, 20);
                ZIndex                 = 5;
                Parent                 = BoxOuter;
            });
            Library:Create('UIListLayout', {
                FillDirection       = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder           = Enum.SortOrder.LayoutOrder;
                Parent              = TabboxButtons;
            });

            function Tabbox:AddTab(Name)
                local TBTab = {};

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderSizePixel  = 0;
                    Size             = UDim2.new(0.5, 0, 1, 0);
                    ZIndex           = 6;
                    Parent           = TabboxButtons;
                });
                AddCorner(Button, R_SMALL);
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor' });

                Library:CreateLabel({
                    Size     = UDim2.new(1, 0, 1, 0);
                    TextSize = 13;
                    Text     = Name;
                    ZIndex   = 7;
                    Parent   = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel  = 0;
                    Position         = UDim2.new(0, 0, 1, -2);
                    Size             = UDim2.new(1, 0, 0, 4);
                    Visible          = false;
                    ZIndex           = 9;
                    Parent           = Button;
                });
                Library:AddToRegistry(Block, { BackgroundColor3 = 'BackgroundColor' });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position               = UDim2.new(0, 6, 0, 24);
                    Size                   = UDim2.new(1, -6, 1, -24);
                    ZIndex                 = 1;
                    Visible                = false;
                    Parent                 = BoxOuter;
                });
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder     = Enum.SortOrder.LayoutOrder;
                    Parent        = Container;
                });

                function TBTab:Show()
                    for _, t in next, Tabbox.Tabs do t:Hide(); end;
                    Container.Visible = true;
                    Block.Visible     = true;
                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';
                    TBTab:Resize();
                end;

                function TBTab:Hide()
                    Container.Visible = false;
                    Block.Visible     = false;
                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function TBTab:Resize()
                    local count = 0;
                    for _ in next, Tabbox.Tabs do count = count + 1; end;
                    for _, b in next, TabboxButtons:GetChildren() do
                        if not b:IsA('UIListLayout') then
                            b.Size = UDim2.new(1 / count, 0, 1, 0);
                        end;
                    end;
                    if not Container.Visible then return; end;
                    local sz = 0;
                    for _, el in next, TBTab.Container:GetChildren() do
                        if not el:IsA('UIListLayout') and el.Visible then
                            sz = sz + el.Size.Y.Offset;
                        end;
                    end;
                    BoxOuter.Size = UDim2.new(1, 0, 0, 26 + sz + 4);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1
                    and not Library:MouseIsOverOpenedFrame() then
                        TBTab:Show();
                    end;
                end);

                TBTab.Container = Container;
                Tabbox.Tabs[Name] = TBTab;
                setmetatable(TBTab, BaseGroupbox);
                TBTab:AddBlank(3);
                TBTab:Resize();


                if #TabboxButtons:GetChildren() == 2 then
                    TBTab:Show();
                end;

                return TBTab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;
            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1 });
        end;
        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2 });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end);


        if #TabContainer:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;


    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size                   = UDim2.new(0, 0, 0, 0);
        Text                   = '';
        Modal                  = false;
        Parent                 = ScreenGui;
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading  = false;

    function Library:Toggle()
        if Fading then return; end;
        local FadeTime = Config.MenuFadeTime;
        Fading  = true;
        Toggled = not Toggled;
        ModalElement.Modal = Toggled;

        if Toggled then
            Outer.Visible = true;

            local hasDrawing = typeof(Drawing) == 'table' and typeof(Drawing.new) == 'function';
            if hasDrawing then
                task.spawn(function()
                    local ok, Cursor, CursorOutline;
                    ok = pcall(function()
                        Cursor        = Drawing.new('Triangle');
                        CursorOutline = Drawing.new('Triangle');
                        Cursor.Thickness        = 1; Cursor.Filled    = true;  Cursor.Visible    = true;
                        CursorOutline.Thickness = 1; CursorOutline.Filled = false;
                        CursorOutline.Color     = Color3.new(0, 0, 0); CursorOutline.Visible = true;
                    end);
                    if not ok then return; end;

                    local State = InputService.MouseIconEnabled;
                    while Toggled and ScreenGui.Parent do
                        InputService.MouseIconEnabled = false;
                        local mp = InputService:GetMouseLocation();
                        Cursor.Color  = Library.AccentColor;
                        Cursor.PointA = Vector2.new(mp.X,      mp.Y);
                        Cursor.PointB = Vector2.new(mp.X + 16, mp.Y + 6);
                        Cursor.PointC = Vector2.new(mp.X + 6,  mp.Y + 16);
                        CursorOutline.PointA = Cursor.PointA;
                        CursorOutline.PointB = Cursor.PointB;
                        CursorOutline.PointC = Cursor.PointC;
                        RenderStepped:Wait();
                    end;
                    InputService.MouseIconEnabled = State;
                    pcall(function() Cursor:Remove(); CursorOutline:Remove(); end);
                end);
            end;
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Props = {};
            if     Desc:IsA('ImageLabel')  then Props = { 'ImageTransparency'; 'BackgroundTransparency' };
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then Props = { 'TextTransparency' };
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then Props = { 'BackgroundTransparency' };
            elseif Desc:IsA('UIStroke')    then Props = { 'Transparency' };
            end;

            local Cache = TransparencyCache[Desc];
            if not Cache then Cache = {}; TransparencyCache[Desc] = Cache; end;

            for _, Prop in next, Props do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop];
                end;
                if Cache[Prop] == 1 then continue; end;
                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear),
                    { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);
        Outer.Visible = Toggled;
        Fading = false;
    end;

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard
            and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle);
            end;
        elseif Input.KeyCode == Enum.KeyCode.RightControl
            or (Input.KeyCode == Enum.KeyCode.RightShift and not Processed) then
            task.spawn(Library.Toggle);
        end;
    end));

    if Config.AutoShow then
        task.defer(Library.Toggle);
    end;

    Window.Holder = Outer;
    return Window;
end;

local function OnPlayerChange()
    local list = GetPlayersString();
    for _, v in next, Options do
        if v.Type == 'Dropdown' and v.SpecialType == 'Player' then
            v:SetValues(list);
        end;
    end;
end;
Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library;
return Library;
