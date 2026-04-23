local httpService = game:GetService('HttpService');

local SaveManager = {};
do
    SaveManager.Folder  = 'LinoriaLibSettings';
    SaveManager.Ignore  = {};
    SaveManager.Library = nil;




    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, obj)
                return { type = 'Toggle'; idx = idx; value = obj.Value };
            end;
            Load = function(idx, data)
                if Toggles[idx] then Toggles[idx]:SetValue(data.value); end;
            end;
        };

        Slider = {
            Save = function(idx, obj)
                return { type = 'Slider'; idx = idx; value = tostring(obj.Value) };
            end;
            Load = function(idx, data)
                if Options[idx] then Options[idx]:SetValue(data.value); end;
            end;
        };

        Dropdown = {
            Save = function(idx, obj)

                return { type = 'Dropdown'; idx = idx; value = obj.Value; multi = obj.Multi };
            end;
            Load = function(idx, data)
                if Options[idx] then Options[idx]:SetValue(data.value); end;
            end;
        };

        ColorPicker = {
            Save = function(idx, obj)
                return { type = 'ColorPicker'; idx = idx; value = obj.Value:ToHex(); transparency = obj.Transparency };
            end;
            Load = function(idx, data)
                if Options[idx] then
                    Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency);
                end;
            end;
        };

        KeyPicker = {
            Save = function(idx, obj)
                return { type = 'KeyPicker'; idx = idx; mode = obj.Mode; key = obj.Value };
            end;
            Load = function(idx, data)
                if Options[idx] then Options[idx]:SetValue({ data.key, data.mode }); end;
            end;
        };

        Input = {
            Save = function(idx, obj)
                return { type = 'Input'; idx = idx; text = obj.Value };
            end;
            Load = function(idx, data)
                if Options[idx] and type(data.text) == 'string' then
                    Options[idx]:SetValue(data.text);
                end;
            end;
        };
    };




    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true;
        end;
    end;

    function SaveManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree();
    end;




    function SaveManager:Save(name)
        if not name then return false, 'no config file selected'; end;

        local fullPath = self.Folder .. '/settings/' .. name .. '.json';
        local data     = { objects = {} };

        for idx, toggle in next, Toggles do
            if self.Ignore[idx] then continue; end;
            table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle));
        end;

        for idx, option in next, Options do
            if not self.Parser[option.Type] then continue; end;
            if self.Ignore[idx] then continue; end;
            table.insert(data.objects, self.Parser[option.Type].Save(idx, option));
        end;

        local ok, encoded = pcall(httpService.JSONEncode, httpService, data);
        if not ok then return false, 'failed to encode data'; end;

        writefile(fullPath, encoded);
        return true;
    end;

    function SaveManager:Load(name)
        if not name then return false, 'no config file selected'; end;

        local file = self.Folder .. '/settings/' .. name .. '.json';
        if not isfile(file) then return false, 'file not found'; end;

        local ok, decoded = pcall(httpService.JSONDecode, httpService, readfile(file));
        if not ok then return false, 'decode error'; end;

        for _, option in next, decoded.objects do
            if self.Parser[option.type] then

                task.spawn(function()
                    self.Parser[option.type].Load(option.idx, option);
                end);
            end;
        end;

        return true;
    end;




    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            'BackgroundColor'; 'MainColor'; 'AccentColor'; 'OutlineColor'; 'FontColor';
            'ThemeManager_ThemeList'; 'ThemeManager_CustomThemeList'; 'ThemeManager_CustomThemeName';
        });
    end;




    function SaveManager:BuildFolderTree()
        local paths = {
            self.Folder;
            self.Folder .. '/themes';
            self.Folder .. '/settings';
        };
        for _, str in next, paths do
            if not isfolder(str) then makefolder(str); end;
        end;
    end;




    function SaveManager:RefreshConfigList()
        local list = listfiles(self.Folder .. '/settings');
        local out  = {};

        for _, file in next, list do
            if file:sub(-5) ~= '.json' then continue; end;


            local pos = #file;
            while pos > 0 do
                local ch = file:sub(pos, pos);
                if ch == '/' or ch == '\\' then break; end;
                pos = pos - 1;
            end;


            local name = file:sub(pos + 1, #file - 5);
            if name and name ~= '' then
                table.insert(out, name);
            end;
        end;

        return out;
    end;

    function SaveManager:SetLibrary(library)
        self.Library = library;
    end;




    function SaveManager:LoadAutoloadConfig()
        local autoloadFile = self.Folder .. '/settings/autoload.txt';
        if not isfile(autoloadFile) then return; end;

        local name = readfile(autoloadFile);

        if not name or name:gsub(' ', '') == '' then return; end;

        local ok, err = self:Load(name);
        if not ok then
            return self.Library:Notify('Failed to load autoload config: ' .. err, 4);
        end;

        self.Library:Notify(string.format('Auto-loaded config %q', name), 3);
    end;




    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, 'Must set SaveManager.Library first!');

        local section = tab:AddRightGroupbox('Configuration');

        section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' });
        section:AddDropdown('SaveManager_ConfigList', {
            Text      = 'Config list';
            Values    = self:RefreshConfigList();
            AllowNull = true;
        });

        section:AddDivider();

        section:AddButton('Create config', function()
            local name = Options.SaveManager_ConfigName.Value;
            if name:gsub(' ', '') == '' then
                return self.Library:Notify('Invalid config name (empty)', 2);
            end;
            local ok, err = self:Save(name);
            if not ok then
                return self.Library:Notify('Failed to save config: ' .. err, 3);
            end;
            self.Library:Notify(string.format('Created config %q', name), 3);
            Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList());
            Options.SaveManager_ConfigList:SetValue(nil);
        end):AddButton('Load config', function()
            local name = Options.SaveManager_ConfigList.Value;
            if not name or name == '' then
                return self.Library:Notify('No config selected', 2);
            end;
            local ok, err = self:Load(name);
            if not ok then
                return self.Library:Notify('Failed to load config: ' .. err, 3);
            end;
            self.Library:Notify(string.format('Loaded config %q', name), 3);
        end);

        section:AddButton('Overwrite config', function()
            local name = Options.SaveManager_ConfigList.Value;
            if not name or name == '' then
                return self.Library:Notify('No config selected', 2);
            end;
            local ok, err = self:Save(name);
            if not ok then
                return self.Library:Notify('Failed to overwrite config: ' .. err, 3);
            end;
            self.Library:Notify(string.format('Overwrote config %q', name), 3);
        end);

        section:AddButton('Refresh list', function()
            Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList());
            Options.SaveManager_ConfigList:SetValue(nil);
        end);

        section:AddButton('Set as autoload', function()
            local name = Options.SaveManager_ConfigList.Value;
            if not name or name == '' then
                return self.Library:Notify('No config selected', 2);
            end;
            writefile(self.Folder .. '/settings/autoload.txt', name);
            SaveManager.AutoloadLabel:SetText('Autoload: ' .. name);
            self.Library:Notify(string.format('Set %q to auto-load', name), 3);
        end);


        local autoloadName = 'none';
        local autoloadFile = self.Folder .. '/settings/autoload.txt';
        if isfile(autoloadFile) then
            local n = readfile(autoloadFile);
            if n and n:gsub(' ', '') ~= '' then autoloadName = n; end;
        end;
        SaveManager.AutoloadLabel = section:AddLabel('Autoload: ' .. autoloadName, true);


        SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList'; 'SaveManager_ConfigName' });
    end;

    SaveManager:BuildFolderTree();
end;

return SaveManager;
