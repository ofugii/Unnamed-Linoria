local httpService = game:GetService('HttpService')

local SaveManager = {}

do
    SaveManager.Folder = 'LinoriaLibSettings'
    SaveManager.Ignore = {}
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object)
                return { type = 'Toggle', idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                if Toggles and Toggles[idx] then
                    Toggles[idx]:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = 'Slider', idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                if Options and Options[idx] then
                    Options[idx]:SetValue(tonumber(data.value))
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
            end,
            Load = function(idx, data)
                if Options and Options[idx] then
                    Options[idx]:SetValue(data.value)
                end
            end,
        },
        ColorPicker = {
            Save = function(idx, object)
                local transparency = nil
                if object.Transparency then
                    transparency = object.TransparencyValue
                end
                return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = transparency }
            end,
            Load = function(idx, data)
                if Options and Options[idx] then
                    local color = Color3.fromHex(data.value)
                    Options[idx]:SetValue(color)
                    if data.transparency and Options[idx].TransparencyValue ~= nil then
                        Options[idx].TransparencyValue = data.transparency
                    end
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, object)
                local keyName = ''
                if object.Value then
                    keyName = object.Value.Name or tostring(object.Value)
                end
                return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = keyName }
            end,
            Load = function(idx, data)
                if Options and Options[idx] then
                    local key = nil
                    if data.key and data.key ~= '' then
                        local ok, result = pcall(function()
                            return Enum.KeyCode[data.key]
                        end)
                        if not ok then
                            ok, result = pcall(function()
                                return Enum.UserInputType[data.key]
                            end)
                        end
                        if ok and result then
                            key = result
                        end
                    end
                    if key then
                        Options[idx]:SetValue(key)
                    end
                    if data.mode then
                        Options[idx].Mode = data.mode
                    end
                end
            end,
        },
        Input = {
            Save = function(idx, object)
                return { type = 'Input', idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                if Options and Options[idx] and type(data.text) == 'string' then
                    Options[idx]:SetValue(data.text)
                end
            end,
        },
    }

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    function SaveManager:Save(name)
        if not name or (type(name) == 'string' and name:gsub('%s', '') == '') then
            return false, 'no config file is selected'
        end

        local fullPath = self.Folder .. '/settings/' .. name .. '.json'

        local data = {
            objects = {}
        }

        if Toggles then
            for idx, toggle in next, Toggles do
                if self.Ignore[idx] then continue end
                if toggle.Type and self.Parser[toggle.Type] then
                    table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
                end
            end
        end

        if Options then
            for idx, option in next, Options do
                if not option.Type then continue end
                if not self.Parser[option.Type] then continue end
                if self.Ignore[idx] then continue end
                table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
            end
        end

        local success, encoded = pcall(httpService.JSONEncode, httpService, data)
        if not success then
            return false, 'failed to encode data'
        end

        local writeOk, writeErr = pcall(writefile, fullPath, encoded)
        if not writeOk then
            return false, 'failed to write file: ' .. tostring(writeErr)
        end

        return true
    end

    function SaveManager:Load(name)
        if not name or (type(name) == 'string' and name:gsub('%s', '') == '') then
            return false, 'no config file is selected'
        end

        local file = self.Folder .. '/settings/' .. name .. '.json'

        if not isfile(file) then
            return false, 'invalid file'
        end

        local readOk, content = pcall(readfile, file)
        if not readOk then
            return false, 'failed to read file'
        end

        local success, decoded = pcall(httpService.JSONDecode, httpService, content)
        if not success then
            return false, 'decode error'
        end

        if type(decoded) ~= 'table' or type(decoded.objects) ~= 'table' then
            return false, 'invalid config format'
        end

        for _, option in next, decoded.objects do
            if type(option) == 'table' and option.type and self.Parser[option.type] then
                task.spawn(function()
                    pcall(self.Parser[option.type].Load, option.idx, option)
                end)
            end
        end

        return true
    end

    function SaveManager:Delete(name)
        if not name or (type(name) == 'string' and name:gsub('%s', '') == '') then
            return false, 'no config file is selected'
        end

        local file = self.Folder .. '/settings/' .. name .. '.json'

        if not isfile(file) then
            return false, 'file does not exist'
        end

        local ok, err = pcall(delfile, file)
        if not ok then
            return false, 'failed to delete file: ' .. tostring(err)
        end

        return true
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
            local ok, _ = pcall(function()
                if not isfolder(paths[i]) then
                    makefolder(paths[i])
                end
            end)
        end
    end

    function SaveManager:RefreshConfigList()
        local ok, list = pcall(listfiles, self.Folder .. '/settings')
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
                    local configName = file:sub(pos + 1, start - 1)
                    if configName ~= 'autoload' then
                        table.insert(out, configName)
                    end
                end
            end
        end

        table.sort(out, function(a, b) return a:lower() < b:lower() end)
        return out
    end

    function SaveManager:SetLibrary(library)
        self.Library = library
    end

    function SaveManager:LoadAutoloadConfig()
        local autoFile = self.Folder .. '/settings/autoload.txt'
        if not isfile(autoFile) then return end

        local ok, name = pcall(readfile, autoFile)
        if not ok or not name or name:gsub('%s', '') == '' then return end

        local success, err = self:Load(name)
        if not success then
            if self.Library then
                return self.Library:Notify('Failed to load autoload config: ' .. tostring(err))
            end
            return
        end

        if self.Library then
            self.Library:Notify(string.format('Auto loaded config %q', name))
        end
    end

    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, 'Must set SaveManager.Library')

        local section = tab:AddRightGroupbox('Configuration')

        section:AddInput('SaveManager_ConfigName', { Text = 'Config name', Placeholder = 'Enter name...' })
        section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

        section:AddDivider()

        section:AddButton({
            Text = 'Create config',
            Func = function()
                local name = Options.SaveManager_ConfigName.Value

                if name:gsub('%s', '') == '' then
                    return self.Library:Notify('Invalid config name (empty)', 2)
                end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify('Failed to save config: ' .. tostring(err))
                end

                self.Library:Notify(string.format('Created config %q', name))
                Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                Options.SaveManager_ConfigList:SetValue(nil)
            end,
        })

        section:AddButton({
            Text = 'Load config',
            Func = function()
                local name = Options.SaveManager_ConfigList.Value

                local success, err = self:Load(name)
                if not success then
                    return self.Library:Notify('Failed to load config: ' .. tostring(err))
                end

                self.Library:Notify(string.format('Loaded config %q', name))
            end,
        })

        section:AddButton({
            Text = 'Overwrite config',
            Func = function()
                local name = Options.SaveManager_ConfigList.Value

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify('Failed to overwrite config: ' .. tostring(err))
                end

                self.Library:Notify(string.format('Overwrote config %q', name))
            end,
        })

        section:AddButton({
            Text = 'Delete config',
            Func = function()
                local name = Options.SaveManager_ConfigList.Value

                local success, err = self:Delete(name)
                if not success then
                    return self.Library:Notify('Failed to delete config: ' .. tostring(err))
                end

                self.Library:Notify(string.format('Deleted config %q', name))
                Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                Options.SaveManager_ConfigList:SetValue(nil)
            end,
        })

        section:AddButton({
            Text = 'Refresh list',
            Func = function()
                Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                Options.SaveManager_ConfigList:SetValue(nil)
            end,
        })

        section:AddButton({
            Text = 'Set as autoload',
            Func = function()
                local name = Options.SaveManager_ConfigList.Value
                if not name or (type(name) == 'string' and name:gsub('%s', '') == '') then
                    return self.Library:Notify('No config selected', 2)
                end

                local ok, err = pcall(writefile, self.Folder .. '/settings/autoload.txt', name)
                if not ok then
                    return self.Library:Notify('Failed to set autoload: ' .. tostring(err))
                end

                SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
                self.Library:Notify(string.format('Set %q to auto load', name))
            end,
        })

        SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

        local autoFile = self.Folder .. '/settings/autoload.txt'
        if isfile(autoFile) then
            local ok, name = pcall(readfile, autoFile)
            if ok and name and name:gsub('%s', '') ~= '' then
                SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
            end
        end

        SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
    end

    SaveManager:BuildFolderTree()
end

return SaveManager
