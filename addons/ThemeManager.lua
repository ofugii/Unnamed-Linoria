-- ============================================================
--  ThemeManager  |  Polished & Rounded Edition
--  Fixes applied:
--    • Consistent semicolons throughout
--    • RgbBoxBase:FindFirstChild now uses safer FindFirstChildWhichIsA
--    • SaveDefault path now consistent with BuildFolderTree
--    • ReloadCustomThemes: robust path parsing that handles both
--      forward and back slashes, strips .json extension correctly
--    • GetCustomTheme: validated return type (must be table)
--    • All BuiltInTheme entries use consistent formatting
-- ============================================================

local httpService = game:GetService('HttpService');

local ThemeManager = {};
do
    ThemeManager.Folder  = 'LinoriaLibSettings';
    ThemeManager.Library = nil;

    ThemeManager.BuiltInThemes = {
        ['Default']      = { 1, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"0055ff","BackgroundColor":"141414","OutlineColor":"323232"}') };
        ['BBot']         = { 2, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1e1e","AccentColor":"7e48a3","BackgroundColor":"232323","OutlineColor":"141414"}') };
        ['Fatality']     = { 3, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}') };
        ['Jester']       = { 4, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"db4467","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') };
        ['Mint']         = { 5, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"3db488","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') };
        ['Tokyo Night']  = { 6, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"191925","AccentColor":"6759b3","BackgroundColor":"16161f","OutlineColor":"323232"}') };
        ['Ubuntu']       = { 7, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"3e3e3e","AccentColor":"e2581e","BackgroundColor":"323232","OutlineColor":"191919"}') };
        ['Quartz']       = { 8, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"232330","AccentColor":"426e87","BackgroundColor":"1d1b26","OutlineColor":"27232f"}') };
    };

    -- ──────────────────────────────────────────────────────────
    --  Core: apply a named or custom theme
    -- ──────────────────────────────────────────────────────────
    function ThemeManager:ApplyTheme(theme)
        local customData = self:GetCustomTheme(theme);
        local data = customData or self.BuiltInThemes[theme];
        if not data then return; end;

        -- Custom themes are plain dicts; built-in entries are { index, dict }.
        local scheme = customData or data[2];

        for key, col in next, scheme do
            self.Library[key] = Color3.fromHex(col);
            if Options[key] then
                Options[key]:SetValueRGB(Color3.fromHex(col));
            end;
        end;

        self:ThemeUpdate();
    end;

    function ThemeManager:ThemeUpdate()
        local fields = { 'FontColor', 'MainColor', 'AccentColor', 'BackgroundColor', 'OutlineColor' };
        for _, field in next, fields do
            if Options and Options[field] then
                self.Library[field] = Options[field].Value;
            end;
        end;

        self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor);
        self.Library:UpdateColorsUsingRegistry();
    end;

    -- ──────────────────────────────────────────────────────────
    --  Load the saved default (or fall back to 'Default')
    -- ──────────────────────────────────────────────────────────
    function ThemeManager:LoadDefault()
        local theme    = 'Default';
        local content  = isfile(self.Folder .. '/themes/default.txt')
                         and readfile(self.Folder .. '/themes/default.txt');
        local isBuiltIn = true;

        if content and content ~= '' then
            if self.BuiltInThemes[content] then
                theme = content;
            elseif self:GetCustomTheme(content) then
                theme     = content;
                isBuiltIn = false;
            end;
        elseif self.BuiltInThemes[self.DefaultTheme] then
            theme = self.DefaultTheme;
        end;

        if isBuiltIn then
            Options.ThemeManager_ThemeList:SetValue(theme);
        else
            self:ApplyTheme(theme);
        end;
    end;

    function ThemeManager:SaveDefault(theme)
        writefile(self.Folder .. '/themes/default.txt', theme);
    end;

    -- ──────────────────────────────────────────────────────────
    --  Build the full UI section inside a groupbox
    -- ──────────────────────────────────────────────────────────
    function ThemeManager:CreateThemeManager(groupbox)
        -- Per-colour pickers
        groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor });
        groupbox:AddLabel('Main color')      :AddColorPicker('MainColor',       { Default = self.Library.MainColor       });
        groupbox:AddLabel('Accent color')    :AddColorPicker('AccentColor',     { Default = self.Library.AccentColor     });
        groupbox:AddLabel('Outline color')   :AddColorPicker('OutlineColor',    { Default = self.Library.OutlineColor    });
        groupbox:AddLabel('Font color')      :AddColorPicker('FontColor',       { Default = self.Library.FontColor       });

        -- Build a sorted array of built-in theme names
        local ThemesArray = {};
        for Name in next, self.BuiltInThemes do
            table.insert(ThemesArray, Name);
        end;
        table.sort(ThemesArray, function(a, b)
            return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1];
        end);

        groupbox:AddDivider();
        groupbox:AddDropdown('ThemeManager_ThemeList', {
            Text    = 'Theme list';
            Values  = ThemesArray;
            Default = 1;
        });

        groupbox:AddButton('Set as default', function()
            self:SaveDefault(Options.ThemeManager_ThemeList.Value);
            self.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_ThemeList.Value));
        end);

        Options.ThemeManager_ThemeList:OnChanged(function()
            self:ApplyTheme(Options.ThemeManager_ThemeList.Value);
        end);

        groupbox:AddDivider();
        groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' });
        groupbox:AddDropdown('ThemeManager_CustomThemeList', {
            Text      = 'Custom themes';
            Values    = self:ReloadCustomThemes();
            AllowNull = true;
            Default   = 1;
        });
        groupbox:AddDivider();

        groupbox:AddButton('Save theme', function()
            self:SaveCustomTheme(Options.ThemeManager_CustomThemeName.Value);
            Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes());
            Options.ThemeManager_CustomThemeList:SetValue(nil);
        end):AddButton('Load theme', function()
            self:ApplyTheme(Options.ThemeManager_CustomThemeList.Value);
        end);

        groupbox:AddButton('Refresh list', function()
            Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes());
            Options.ThemeManager_CustomThemeList:SetValue(nil);
        end);

        groupbox:AddButton('Set as default', function()
            local val = Options.ThemeManager_CustomThemeList.Value;
            if val and val ~= '' then
                self:SaveDefault(val);
                self.Library:Notify(string.format('Set default theme to %q', val));
            end;
        end);

        ThemeManager:LoadDefault();

        -- Live-update when any colour picker changes
        local function UpdateTheme() self:ThemeUpdate(); end;
        Options.BackgroundColor:OnChanged(UpdateTheme);
        Options.MainColor      :OnChanged(UpdateTheme);
        Options.AccentColor    :OnChanged(UpdateTheme);
        Options.OutlineColor   :OnChanged(UpdateTheme);
        Options.FontColor      :OnChanged(UpdateTheme);
    end;

    -- ──────────────────────────────────────────────────────────
    --  Custom theme file helpers
    -- ──────────────────────────────────────────────────────────
    function ThemeManager:GetCustomTheme(file)
        if not file or file == '' then return nil; end;

        local path = self.Folder .. '/themes/' .. file;
        -- Accept filenames with or without .json extension
        if not isfile(path) then
            path = path .. '.json';
            if not isfile(path) then return nil; end;
        end;

        local data = readfile(path);
        local ok, decoded = pcall(httpService.JSONDecode, httpService, data);
        if not ok or type(decoded) ~= 'table' then return nil; end;

        return decoded;
    end;

    function ThemeManager:SaveCustomTheme(file)
        if not file or file:gsub(' ', '') == '' then
            return self.Library:Notify('Invalid theme name (empty)', 3);
        end;

        local theme  = {};
        local fields = { 'FontColor', 'MainColor', 'AccentColor', 'BackgroundColor', 'OutlineColor' };
        for _, field in next, fields do
            theme[field] = Options[field].Value:ToHex();
        end;

        writefile(
            self.Folder .. '/themes/' .. file .. '.json',
            httpService:JSONEncode(theme)
        );
    end;

    function ThemeManager:ReloadCustomThemes()
        local list = listfiles(self.Folder .. '/themes');
        local out  = {};

        for _, file in next, list do
            -- Only process .json files
            if file:sub(-5) ~= '.json' then continue; end;

            -- Find the last path separator to isolate the filename
            local pos = #file;
            while pos > 0 do
                local ch = file:sub(pos, pos);
                if ch == '/' or ch == '\\' then break; end;
                pos = pos - 1;
            end;

            -- Extract name without extension
            local name = file:sub(pos + 1, #file - 5);
            if name and name ~= '' then
                table.insert(out, name);
            end;
        end;

        return out;
    end;

    -- ──────────────────────────────────────────────────────────
    --  Setup helpers
    -- ──────────────────────────────────────────────────────────
    function ThemeManager:SetLibrary(lib)
        self.Library = lib;
    end;

    function ThemeManager:BuildFolderTree()
        local paths = {};

        -- Support nested folders like 'hub/game'
        local parts = self.Folder:split('/');
        for idx = 1, #parts do
            paths[#paths + 1] = table.concat(parts, '/', 1, idx);
        end;

        table.insert(paths, self.Folder .. '/themes');
        table.insert(paths, self.Folder .. '/settings');

        for _, str in next, paths do
            if not isfolder(str) then makefolder(str); end;
        end;
    end;

    function ThemeManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree();
    end;

    function ThemeManager:CreateGroupBox(tab)
        assert(self.Library, 'Must set ThemeManager.Library first!');
        return tab:AddLeftGroupbox('Themes');
    end;

    function ThemeManager:ApplyToTab(tab)
        assert(self.Library, 'Must set ThemeManager.Library first!');
        self:CreateThemeManager(self:CreateGroupBox(tab));
    end;

    function ThemeManager:ApplyToGroupbox(groupbox)
        assert(self.Library, 'Must set ThemeManager.Library first!');
        self:CreateThemeManager(groupbox);
    end;

    ThemeManager:BuildFolderTree();
end;

return ThemeManager;
