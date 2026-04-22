local httpService = game:GetService('HttpService')

local ThemeManager = {}

do
    ThemeManager.Folder = 'LinoriaLibSettings'
    ThemeManager.Library = nil
    ThemeManager.BuiltInThemes = {
        ['Default'] = {
            1,
            httpService:JSONDecode('{"FontColor":"e1e1e6","MainColor":"19191e","AccentColor":"7289da","BackgroundColor":"121216","OutlineColor":"28282d"}'),
        },
        ['BBot'] = {
            2,
            httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1e1e","AccentColor":"7e48a3","BackgroundColor":"232323","OutlineColor":"141414"}'),
        },
        ['Fatality'] = {
            3,
            httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}'),
        },
        ['Jester'] = {
            4,
            httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"db4467","BackgroundColor":"1c1c1c","OutlineColor":"373737"}'),
        },
        ['Mint'] = {
            5,
            httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"3db488","BackgroundColor":"1c1c1c","OutlineColor":"373737"}'),
        },
        ['Tokyo Night'] = {
            6,
            httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"191925","AccentColor":"6759b3","BackgroundColor":"16161f","OutlineColor":"323232"}'),
        },
        ['Ubuntu'] = {
            7,
            httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"3e3e3e","AccentColor":"e2581e","BackgroundColor":"323232","OutlineColor":"191919"}'),
        },
        ['Quartz'] = {
            8,
            httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"232330","AccentColor":"426e87","BackgroundColor":"1d1b26","OutlineColor":"27232f"}'),
        },
    }

    function ThemeManager:ApplyTheme(theme)
        local customThemeData = self:GetCustomTheme(theme)
        local data = customThemeData or self.BuiltInThemes[theme]

        if not data then return end

        local scheme
        if customThemeData then
            scheme = customThemeData
        else
            scheme = data[2]
        end

        if type(scheme) ~= 'table' then return end

        for idx, col in next, scheme do
            if type(col) == 'string' then
                local ok, color = pcall(Color3.fromHex, col)
                if ok and color then
                    self.Library[idx] = color
                    if Options and Options[idx] then
                        Options[idx]:SetValue(color)
                    end
                end
            end
        end

        self:ThemeUpdate()
    end

    function ThemeManager:ThemeUpdate()
        local fields = { 'FontColor', 'MainColor', 'AccentColor', 'BackgroundColor', 'OutlineColor' }

        for _, field in next, fields do
            if Options and Options[field] and Options[field].Value then
                self.Library[field] = Options[field].Value
            end
        end

        if self.Library.GetDarkerColor then
            self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor)
        end

        if self.Library.UpdateColorsUsingRegistry then
            self.Library:UpdateColorsUsingRegistry()
        end
    end

    function ThemeManager:LoadDefault()
        local theme = 'Default'
        local content = nil

        local filePath = self.Folder .. '/themes/default.txt'
        if isfile(filePath) then
            local ok, data = pcall(readfile, filePath)
            if ok and data and data:gsub('%s', '') ~= '' then
                content = data
            end
        end

        local isDefault = true

        if content then
            if self.BuiltInThemes[content] then
                theme = content
            elseif self:GetCustomTheme(content) then
                theme = content
                isDefault = false
            end
        elseif self.DefaultTheme and self.BuiltInThemes[self.DefaultTheme] then
            theme = self.DefaultTheme
        end

        if isDefault then
            if Options and Options.ThemeManager_ThemeList then
                Options.ThemeManager_ThemeList:SetValue(theme)
            else
                self:ApplyTheme(theme)
            end
        else
            self:ApplyTheme(theme)
        end
    end

    function ThemeManager:SaveDefault(theme)
        if not theme or (type(theme) == 'string' and theme:gsub('%s', '') == '') then return end
        pcall(writefile, self.Folder .. '/themes/default.txt', theme)
    end

    function ThemeManager:CreateThemeManager(groupbox)
        groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', {
            Default = self.Library.BackgroundColor,
            Title = 'Background',
            Callback = function()
                self:ThemeUpdate()
            end,
        })

        groupbox:AddLabel('Main color'):AddColorPicker('MainColor', {
            Default = self.Library.MainColor,
            Title = 'Main',
            Callback = function()
                self:ThemeUpdate()
            end,
        })

        groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', {
            Default = self.Library.AccentColor,
            Title = 'Accent',
            Callback = function()
                self:ThemeUpdate()
            end,
        })

        groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', {
            Default = self.Library.OutlineColor,
            Title = 'Outline',
            Callback = function()
                self:ThemeUpdate()
            end,
        })

        groupbox:AddLabel('Font color'):AddColorPicker('FontColor', {
            Default = self.Library.FontColor,
            Title = 'Font',
            Callback = function()
                self:ThemeUpdate()
            end,
        })

        local ThemesArray = {}
        for Name, _ in next, self.BuiltInThemes do
            table.insert(ThemesArray, Name)
        end
        table.sort(ThemesArray, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

        groupbox:AddDivider()

        groupbox:AddDropdown('ThemeManager_ThemeList', {
            Text = 'Theme list',
            Values = ThemesArray,
            Default = 'Default',
        })

        groupbox:AddButton({
            Text = 'Set as default',
            Func = function()
                local val = Options.ThemeManager_ThemeList.Value
                if not val or (type(val) == 'string' and val:gsub('%s', '') == '') then
                    return self.Library:Notify('No theme selected', 2)
                end
                self:SaveDefault(val)
                self.Library:Notify(string.format('Set default theme to %q', val))
            end,
        })

        Options.ThemeManager_ThemeList:OnChanged(function()
            local val = Options.ThemeManager_ThemeList.Value
            if val and val ~= '' then
                self:ApplyTheme(val)
            end
        end)

        groupbox:AddDivider()

        groupbox:AddInput('ThemeManager_CustomThemeName', {
            Text = 'Custom theme name',
            Placeholder = 'Enter name...',
        })

        groupbox:AddDropdown('ThemeManager_CustomThemeList', {
            Text = 'Custom themes',
            Values = self:ReloadCustomThemes(),
            AllowNull = true,
        })

        groupbox:AddDivider()

        groupbox:AddButton({
            Text = 'Save theme',
            Func = function()
                local name = Options.ThemeManager_CustomThemeName.Value
                if not name or name:gsub('%s', '') == '' then
                    return self.Library:Notify('Invalid theme name (empty)', 2)
                end
                self:SaveCustomTheme(name)
                self.Library:Notify(string.format('Saved theme %q', name))
                Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                Options.ThemeManager_CustomThemeList:SetValue(nil)
            end,
        })

        groupbox:AddButton({
            Text = 'Load theme',
            Func = function()
                local val = Options.ThemeManager_CustomThemeList.Value
                if not val or (type(val) == 'string' and val:gsub('%s', '') == '') then
                    return self.Library:Notify('No custom theme selected', 2)
                end
                self:ApplyTheme(val)
                self.Library:Notify(string.format('Loaded theme %q', val))
            end,
        })

        groupbox:AddButton({
            Text = 'Delete theme',
            Func = function()
                local val = Options.ThemeManager_CustomThemeList.Value
                if not val or (type(val) == 'string' and val:gsub('%s', '') == '') then
                    return self.Library:Notify('No custom theme selected', 2)
                end
                local path = self.Folder .. '/themes/' .. val
                if isfile(path) then
                    pcall(delfile, path)
                    self.Library:Notify(string.format('Deleted theme %q', val))
                else
                    self.Library:Notify('Theme file not found', 2)
                end
                Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                Options.ThemeManager_CustomThemeList:SetValue(nil)
            end,
        })

        groupbox:AddButton({
            Text = 'Refresh list',
            Func = function()
                Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                Options.ThemeManager_CustomThemeList:SetValue(nil)
            end,
        })

        groupbox:AddButton({
            Text = 'Set custom as default',
            Func = function()
                local val = Options.ThemeManager_CustomThemeList.Value
                if not val or (type(val) == 'string' and val:gsub('%s', '') == '') then
                    return self.Library:Notify('No custom theme selected', 2)
                end
                self:SaveDefault(val)
                self.Library:Notify(string.format('Set default theme to %q', val))
            end,
        })

        self:LoadDefault()
    end

    function ThemeManager:GetCustomTheme(file)
        if not file or (type(file) == 'string' and file:gsub('%s', '') == '') then
            return nil
        end

        local path = self.Folder .. '/themes/' .. file
        if not isfile(path) then
            path = self.Folder .. '/themes/' .. file .. '.json'
            if not isfile(path) then
                return nil
            end
        end

        local ok, data = pcall(readfile, path)
        if not ok or not data then return nil end

        local success, decoded = pcall(httpService.JSONDecode, httpService, data)
        if not success or type(decoded) ~= 'table' then return nil end

        return decoded
    end

    function ThemeManager:SaveCustomTheme(file)
        if not file or file:gsub('%s', '') == '' then
            if self.Library then
                return self.Library:Notify('Invalid file name for theme (empty)', 3)
            end
            return
        end

        local theme = {}
        local fields = { 'FontColor', 'MainColor', 'AccentColor', 'BackgroundColor', 'OutlineColor' }

        for _, field in next, fields do
            if Options and Options[field] and Options[field].Value then
                theme[field] = Options[field].Value:ToHex()
            elseif self.Library and self.Library[field] then
                theme[field] = self.Library[field]:ToHex()
            end
        end

        local ok, encoded = pcall(httpService.JSONEncode, httpService, theme)
        if not ok then
            if self.Library then
                self.Library:Notify('Failed to encode theme data', 3)
            end
            return
        end

        pcall(writefile, self.Folder .. '/themes/' .. file .. '.json', encoded)
    end

    function ThemeManager:ReloadCustomThemes()
        local ok, list = pcall(listfiles, self.Folder .. '/themes')
        if not ok or type(list) ~= 'table' then
            return {}
        end

        local out = {}
        for i = 1, #list do
            local file = list[i]
            if file:sub(-5) == '.json' then
                local pos = file:find('.json', 1, true)
                local start = pos
                local char = file:sub(pos, pos)

                while char ~= '/' and char ~= '\\' and char ~= '' and pos > 0 do
                    pos = pos - 1
                    char = file:sub(pos, pos)
                end

                if char == '/' or char == '\\' then
                    local name = file:sub(pos + 1, start - 1)
                    if name ~= '' then
                        table.insert(out, name .. '.json')
                    end
                end
            end
        end

        table.sort(out, function(a, b) return a:lower() < b:lower() end)
        return out
    end

    function ThemeManager:SetLibrary(lib)
        self.Library = lib
    end

    function ThemeManager:BuildFolderTree()
        local paths = {}

        local parts = self.Folder:split('/')
        for idx = 1, #parts do
            paths[#paths + 1] = table.concat(parts, '/', 1, idx)
        end

        table.insert(paths, self.Folder .. '/themes')
        table.insert(paths, self.Folder .. '/settings')

        for i = 1, #paths do
            pcall(function()
                if not isfolder(paths[i]) then
                    makefolder(paths[i])
                end
            end)
        end
    end

    function ThemeManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    function ThemeManager:CreateGroupBox(tab)
        assert(self.Library, 'Must set ThemeManager.Library first!')
        return tab:AddLeftGroupbox('Themes')
    end

    function ThemeManager:ApplyToTab(tab)
        assert(self.Library, 'Must set ThemeManager.Library first!')
        local groupbox = self:CreateGroupBox(tab)
        self:CreateThemeManager(groupbox)
    end

    function ThemeManager:ApplyToGroupbox(groupbox)
        assert(self.Library, 'Must set ThemeManager.Library first!')
        self:CreateThemeManager(groupbox)
    end

    ThemeManager:BuildFolderTree()
end

return ThemeManager
