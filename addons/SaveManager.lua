local HttpService = game:GetService('HttpService')

local SaveManager = {}

SaveManager.Folder = 'LinoriaLibSettings'
SaveManager.Library = nil
SaveManager.Ignore = {}
SaveManager.NotifyOnSave = true
SaveManager.NotifyOnLoad = true
SaveManager.NotifyDuration = 2
SaveManager.AutoloadEnabled = true
SaveManager.GroupboxSide = 'Right'
SaveManager.GroupboxName = 'Configuration'

SaveManager.Parser = {
    Toggle = {
        Save = function(idx, object)
            return { type = 'Toggle', idx = idx, value = object.Value }
        end,
        Load = function(idx, data)
            if Toggles[idx] then
                Toggles[idx]:SetValue(data.value)
            end
        end,
    },
    Slider = {
        Save = function(idx, object)
            return { type = 'Slider', idx = idx, value = tostring(object.Value) }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValue(data.value)
            end
        end,
    },
    Dropdown = {
        Save = function(idx, object)
            return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValue(data.value)
            end
        end,
    },
    ColorPicker = {
        Save = function(idx, object)
            return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
            end
        end,
    },
    KeyPicker = {
        Save = function(idx, object)
            return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValue({ data.key, data.mode })
            end
        end,
    },
    Input = {
        Save = function(idx, object)
            return { type = 'Input', idx = idx, text = object.Value }
        end,
        Load = function(idx, data)
            if Options[idx] and type(data.text) == 'string' then
                Options[idx]:SetValue(data.text)
            end
        end,
    },
}

function SaveManager:SetLibrary(library)
    self.Library = library
end

function SaveManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager:SetGroupboxName(name)
    self.GroupboxName = name
end

function SaveManager:SetGroupboxSide(side)
    self.GroupboxSide = side
end

function SaveManager:SetNotifyOnSave(bool)
    self.NotifyOnSave = bool
end

function SaveManager:SetNotifyOnLoad(bool)
    self.NotifyOnLoad = bool
end

function SaveManager:SetNotifyDuration(duration)
    self.NotifyDuration = duration
end

function SaveManager:SetAutoloadEnabled(bool)
    self.AutoloadEnabled = bool
end

function SaveManager:AddParser(typeName, parser)
    assert(type(parser.Save) == 'function', 'Parser must have a Save function')
    assert(type(parser.Load) == 'function', 'Parser must have a Load function')
    self.Parser[typeName] = parser
end

function SaveManager:RemoveParser(typeName)
    self.Parser[typeName] = nil
end

function SaveManager:SetIgnoreIndexes(list)
    for _, key in next, list do
        self.Ignore[key] = true
    end
end

function SaveManager:ClearIgnoreIndexes()
    self.Ignore = {}
end

function SaveManager:IgnoreThemeSettings()
    self:SetIgnoreIndexes({
        'BackgroundColor', 'MainColor', 'AccentColor', 'OutlineColor', 'FontColor',
        'ThemeManager_ThemeList', 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
    })
end

function SaveManager:BuildFolderTree()
    local paths = {
        self.Folder,
        self.Folder .. '/themes',
        self.Folder .. '/settings',
    }

    for i = 1, #paths do
        local str = paths[i]
        if not isfolder(str) then
            makefolder(str)
        end
    end
end

function SaveManager:Save(name)
    if not name then
        return false, 'no config file is selected'
    end

    local fullPath = self.Folder .. '/settings/' .. name .. '.json'
    local data = { objects = {} }

    for idx, toggle in next, Toggles do
        if self.Ignore[idx] then continue end
        table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
    end

    for idx, option in next, Options do
        if not self.Parser[option.Type] then continue end
        if self.Ignore[idx] then continue end
        table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
    end

    local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not success then
        return false, 'failed to encode data'
    end

    writefile(fullPath, encoded)
    return true
end

function SaveManager:Load(name)
    if not name then
        return false, 'no config file is selected'
    end

    local file = self.Folder .. '/settings/' .. name .. '.json'
    if not isfile(file) then
        return false, 'invalid file'
    end

    local success, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
    if not success then
        return false, 'decode error'
    end

    for _, option in next, decoded.objects do
        if self.Parser[option.type] then
            task.spawn(function()
                self.Parser[option.type].Load(option.idx, option)
            end)
        end
    end

    return true
end

function SaveManager:RefreshConfigList()
    local list = listfiles(self.Folder .. '/settings')
    local out = {}

    for i = 1, #list do
        local file = list[i]
        if file:sub(-5) == '.json' then
            local pos = file:find('.json', 1, true)
            local start = pos
            local char = file:sub(pos, pos)

            while char ~= '/' and char ~= '\\' and char ~= '' do
                pos = pos - 1
                char = file:sub(pos, pos)
            end

            if char == '/' or char == '\\' then
                table.insert(out, file:sub(pos + 1, start - 1))
            end
        end
    end

    return out
end

function SaveManager:LoadAutoloadConfig()
    if not self.AutoloadEnabled then return end

    local path = self.Folder .. '/settings/autoload.txt'
    if not isfile(path) then return end

    local name = readfile(path)
    local success, err = self:Load(name)

    if not success then
        if self.Library then
            self.Library:Notify('Failed to load autoload config: ' .. err, self.NotifyDuration)
        end
        return
    end

    if self.NotifyOnLoad and self.Library then
        self.Library:Notify(string.format('Auto loaded config %q', name), self.NotifyDuration)
    end
end

function SaveManager:BuildConfigSection(tab)
    assert(self.Library, 'Must set SaveManager.Library')

    local section
    if self.GroupboxSide == 'Left' then
        section = tab:AddLeftGroupbox(self.GroupboxName)
    else
        section = tab:AddRightGroupbox(self.GroupboxName)
    end

    section:AddInput('SaveManager_ConfigName', { Text = 'Config name' })
    section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

    section:AddDivider()

    section:AddButton('Create config', function()
        local name = Options.SaveManager_ConfigName.Value

        if name:gsub(' ', '') == '' then
            self.Library:Notify('Invalid config name (empty)', self.NotifyDuration)
            return
        end

        local success, err = self:Save(name)
        if not success then
            self.Library:Notify('Failed to save config: ' .. err, self.NotifyDuration)
            return
        end

        if self.NotifyOnSave then
            self.Library:Notify(string.format('Created config %q', name), self.NotifyDuration)
        end

        Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        Options.SaveManager_ConfigList:SetValue(nil)
    end):AddButton('Load config', function()
        local name = Options.SaveManager_ConfigList.Value

        local success, err = self:Load(name)
        if not success then
            self.Library:Notify('Failed to load config: ' .. err, self.NotifyDuration)
            return
        end

        if self.NotifyOnLoad then
            self.Library:Notify(string.format('Loaded config %q', name), self.NotifyDuration)
        end
    end)

    section:AddButton('Overwrite config', function()
        local name = Options.SaveManager_ConfigList.Value

        local success, err = self:Save(name)
        if not success then
            self.Library:Notify('Failed to overwrite config: ' .. err, self.NotifyDuration)
            return
        end

        if self.NotifyOnSave then
            self.Library:Notify(string.format('Overwrote config %q', name), self.NotifyDuration)
        end
    end)

    section:AddButton('Refresh list', function()
        Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        Options.SaveManager_ConfigList:SetValue(nil)
    end)

    if self.AutoloadEnabled then
        section:AddButton('Set as autoload', function()
            local name = Options.SaveManager_ConfigList.Value
            writefile(self.Folder .. '/settings/autoload.txt', name)
            SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)

            if self.NotifyOnSave then
                self.Library:Notify(string.format('Set %q to auto load', name), self.NotifyDuration)
            end
        end)

        SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

        local autoloadPath = self.Folder .. '/settings/autoload.txt'
        if isfile(autoloadPath) then
            local name = readfile(autoloadPath)
            SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
        end
    end

    self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
end

SaveManager:BuildFolderTree()

return SaveManager
