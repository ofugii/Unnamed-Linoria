local HttpService = game:GetService('HttpService')

local ThemeManager = {}

ThemeManager.Folder = 'LinoriaLibSettings'
ThemeManager.Library = nil
ThemeManager.DefaultTheme = 'Default'
ThemeManager.NotifyOnSave = true
ThemeManager.NotifyDuration = 3

ThemeManager.ColorFields = {
    'FontColor',
    'MainColor',
    'AccentColor',
    'BackgroundColor',
    'OutlineColor',
}

ThemeManager.ColorLabels = {
    FontColor       = 'Font color',
    MainColor       = 'Main color',
    AccentColor     = 'Accent color',
    BackgroundColor = 'Background color',
    OutlineColor    = 'Outline color',
}

ThemeManager.BuiltInThemes = {
    ['Default']      = { 1, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"0055ff","BackgroundColor":"141414","OutlineColor":"323232"}') },
    ['BBot']         = { 2, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1e1e","AccentColor":"7e48a3","BackgroundColor":"232323","OutlineColor":"141414"}') },
    ['Fatality']     = { 3, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}') },
    ['Jester']       = { 4, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"db4467","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
    ['Mint']         = { 5, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"3db488","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
    ['Tokyo Night']  = { 6, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"191925","AccentColor":"6759b3","BackgroundColor":"16161f","OutlineColor":"323232"}') },
    ['Ubuntu']       = { 7, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"3e3e3e","AccentColor":"e2581e","BackgroundColor":"323232","OutlineColor":"191919"}') },
    ['Quartz']       = { 8, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"232330","AccentColor":"426e87","BackgroundColor":"1d1b26","OutlineColor":"27232f"}') },
}

function ThemeManager:SetLibrary(lib)
    self.Library = lib
end

function ThemeManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function ThemeManager:SetDefaultTheme(name)
    self.DefaultTheme = name
end

function ThemeManager:SetColorFields(fields)
    self.ColorFields = fields
end

function ThemeManager:SetColorLabels(labels)
    for k, v in next, labels do
        self.ColorLabels[k] = v
    end
end

function ThemeManager:AddBuiltInTheme(name, index, data)
    self.BuiltInThemes[name] = { index, data }
end

function ThemeManager:RemoveBuiltInTheme(name)
    self.BuiltInThemes[name] = nil
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
        local str = paths[i]
        if not isfolder(str) then
            makefolder(str)
        end
    end
end

function ThemeManager:ThemeUpdate()
    for _, field in next, self.ColorFields do
        if Options and Options[field] then
            self.Library[field] = Options[field].Value
        end
    end

    self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor)
    self.Library:UpdateColorsUsingRegistry()
end

function ThemeManager:ApplyTheme(theme)
    local customThemeData = self:GetCustomTheme(theme)
    local data = customThemeData or self.BuiltInThemes[theme]

    if not data then return end

    local scheme = customThemeData or data[2]

    for idx, col in next, scheme do
        self.Library[idx] = Color3.fromHex(col)

        if Options and Options[idx] then
            Options[idx]:SetValueRGB(Color3.fromHex(col))
        end
    end

    self:ThemeUpdate()
end

function ThemeManager:GetCustomTheme(file)
    local path = self.Folder .. '/themes/' .. file
    if not isfile(path) then
        return nil
    end

    local data = readfile(path)
    local success, decoded = pcall(HttpService.JSONDecode, HttpService, data)

    if not success then
        return nil
    end

    return decoded
end

function ThemeManager:SaveCustomTheme(file)
    if file:gsub(' ', '') == '' then
        if self.NotifyOnSave then
            self.Library:Notify('Invalid file name for theme (empty)', self.NotifyDuration)
        end
        return
    end

    local theme = {}

    for _, field in next, self.ColorFields do
        if Options and Options[field] then
            theme[field] = Options[field].Value:ToHex()
        end
    end

    writefile(self.Folder .. '/themes/' .. file .. '.json', HttpService:JSONEncode(theme))

    if self.NotifyOnSave then
        self.Library:Notify(string.format('Saved theme %q', file), self.NotifyDuration)
    end
end

function ThemeManager:ReloadCustomThemes()
    local list = listfiles(self.Folder .. '/themes')
    local out = {}

    for i = 1, #list do
        local file = list[i]
        if file:sub(-5) == '.json' then
            local pos = file:find('.json', 1, true)
            local char = file:sub(pos, pos)

            while char ~= '/' and char ~= '\\' and char ~= '' do
                pos = pos - 1
                char = file:sub(pos, pos)
            end

            if char == '/' or char == '\\' then
                table.insert(out, file:sub(pos + 1))
            end
        end
    end

    return out
end

function ThemeManager:SaveDefault(theme)
    writefile(self.Folder .. '/themes/default.txt', theme)
end

function ThemeManager:LoadDefault()
    local theme = self.DefaultTheme
    local content = isfile(self.Folder .. '/themes/default.txt') and readfile(self.Folder .. '/themes/default.txt')

    local isDefault = true

    if content then
        if self.BuiltInThemes[content] then
            theme = content
        elseif self:GetCustomTheme(content) then
            theme = content
            isDefault = false
        end
    elseif self.BuiltInThemes[self.DefaultTheme] then
        theme = self.DefaultTheme
    end

    if isDefault then
        if Options and Options.ThemeManager_ThemeList then
            Options.ThemeManager_ThemeList:SetValue(theme)
        end
    else
        self:ApplyTheme(theme)
    end
end

function ThemeManager:CreateThemeManager(groupbox)
    for _, field in next, self.ColorFields do
        local label = self.ColorLabels[field] or field
        groupbox:AddLabel(label):AddColorPicker(field, { Default = self.Library[field] })
    end

    local ThemesArray = {}
    for Name in next, self.BuiltInThemes do
        table.insert(ThemesArray, Name)
    end

    table.sort(ThemesArray, function(a, b)
        return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1]
    end)

    groupbox:AddDivider()
    groupbox:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })

    groupbox:AddButton('Set as default', function()
        self:SaveDefault(Options.ThemeManager_ThemeList.Value)
        if self.NotifyOnSave then
            self.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_ThemeList.Value), self.NotifyDuration)
        end
    end)

    Options.ThemeManager_ThemeList:OnChanged(function()
        self:ApplyTheme(Options.ThemeManager_ThemeList.Value)
    end)

    groupbox:AddDivider()
    groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
    groupbox:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = self:ReloadCustomThemes(), AllowNull = true, Default = 1 })
    groupbox:AddDivider()

    groupbox:AddButton('Save theme', function()
        self:SaveCustomTheme(Options.ThemeManager_CustomThemeName.Value)
        Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
        Options.ThemeManager_CustomThemeList:SetValue(nil)
    end):AddButton('Load theme', function()
        self:ApplyTheme(Options.ThemeManager_CustomThemeList.Value)
    end)

    groupbox:AddButton('Refresh list', function()
        Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
        Options.ThemeManager_CustomThemeList:SetValue(nil)
    end)

    groupbox:AddButton('Set as default', function()
        local val = Options.ThemeManager_CustomThemeList.Value
        if val and val ~= '' then
            self:SaveDefault(val)
            if self.NotifyOnSave then
                self.Library:Notify(string.format('Set default theme to %q', val), self.NotifyDuration)
            end
        end
    end)

    self:LoadDefault()

    local function UpdateTheme()
        self:ThemeUpdate()
    end

    for _, field in next, self.ColorFields do
        if Options and Options[field] then
            Options[field]:OnChanged(UpdateTheme)
        end
    end
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

return ThemeManager
