local COLORS = {
    { key = "BackgroundColor", label = "Background" },
    { key = "MainColor", label = "Main" },
    { key = "AccentColor", label = "Accent" },
    { key = "OutlineColor", label = "Outline" },
    { key = "FontColor", label = "Font" },
}

local FONTS = {
    "BuilderSans",
    "Code",
    "Fantasy",
    "Gotham",
    "Jura",
    "Roboto",
    "RobotoMono",
    "SourceSans",
}

return {
    Name = "UI Settings",
    Icon = "settings",

    Build = function(ctx, config, tab)
        local library = ctx.Library
        local window = ctx.Window

        local function notify(text: string, duration: number?)
            library:Notify({
                Title = "Abyssal",
                Text = text,
                Duration = duration or 4,
            })
        end

        local function refresh()
            pcall(function()
                library:UpdateColorsUsingRegistry()
            end)
        end

        local themeConfig = type(config.Theme) == "table" and config.Theme or {}
        local uiConfig = type(config.UI) == "table" and config.UI or {}
        local windowConfig = type(config.Window) == "table" and config.Window or {}

        -- ── Themes ────────────────────────────────────────────────────────

        local Themes = ctx.LoadFile("libs/Addons/themes.luau")
        local themesBox = tab:AddGroupbox({ Side = "Left", Name = "Themes", IconName = "paintbrush" })

        if Themes == nil then
            themesBox:AddLabel("themes.luau did not load")
        else
            themesBox:AddDropdown("ui.theme", {
                Text = "Theme list",
                Values = Themes.Names(),
                Default = Themes.Current() or themeConfig.Name or "Abyssal",
                Multi = false,
            })

            local pickers = {}

            themesBox:AddDivider()

            for _, entry in COLORS do
                local id = `ui.color.{entry.key}`

                themesBox:AddLabel(entry.label):AddColorPicker(id, {
                    Default = library.Scheme[entry.key],
                })

                local option = library.Options[id]

                if option ~= nil then
                    pickers[entry.key] = option

                    option:OnChanged(function(color)
                        library.Scheme[entry.key] = color
                        refresh()
                    end)
                end
            end

            ctx.Options["ui.theme"]:OnChanged(function(name: string)
                local ok, err = Themes.Apply(library, name)

                if not ok then
                    notify(`Could not apply that theme: {err}`, 5)
                    return
                end

                -- Pull the new colours into the pickers so they match what is
                -- on screen instead of showing the previous theme's values.
                for key, picker in pickers do
                    local color = library.Scheme[key]

                    if color ~= nil and picker.SetValueRGB ~= nil then
                        pcall(function()
                            picker:SetValueRGB(color)
                        end)
                    end
                end
            end)

            themesBox:AddDivider()

            themesBox:AddInput("ui.customTheme", {
                Text = "Custom theme name",
                Default = "",
                Placeholder = "my theme",
            })

            local function hex(value: Color3): string
                local function part(channel: number): string
                    return string.format("%02x", math.floor(channel * 255 + 0.5))
                end

                return part(value.R) .. part(value.G) .. part(value.B)
            end

            themesBox:AddButton({
                Text = "Save current as theme",
                Tooltip = "Registers the colours on screen as a new theme.",
                Func = function()
                    local option = ctx.Options["ui.customTheme"]
                    local name = option ~= nil and option.Value or nil

                    if type(name) ~= "string" or name == "" then
                        notify("Give the theme a name first.")
                        return
                    end

                    local scheme = library.Scheme
                    local palette = {}

                    for _, entry in COLORS do
                        palette[entry.key] = hex(scheme[entry.key])
                    end

                    local ok = pcall(Themes.Register, name, palette)

                    if not ok then
                        notify("Could not register that theme.", 5)
                        return
                    end

                    local dropdown = ctx.Options["ui.theme"]

                    if dropdown ~= nil and dropdown.SetValues ~= nil then
                        dropdown:SetValues(Themes.Names())
                    end

                    notify(`Saved theme "{name}"`)
                end,
            })
        end

        -- ── Interface ─────────────────────────────────────────────────────

        local interfaceBox = tab:AddGroupbox({ Side = "Left", Name = "Interface", IconName = "sliders" })

        interfaceBox:AddSlider("ui.dpi", {
            Text = "DPI scale",
            Min = 50,
            Max = 150,
            Default = tonumber(uiConfig.DPI) or 100,
            Rounding = 0,
            Suffix = "%",
        })

        ctx.Options["ui.dpi"]:OnChanged(function(value: number)
            pcall(function()
                library:SetDPIScale(value)
            end)
        end)

        interfaceBox:AddSlider("ui.cornerRadius", {
            Text = "Corner radius",
            Min = 0,
            Max = 20,
            Default = tonumber(windowConfig.CornerRadius) or 4,
            Rounding = 0,
        })

        ctx.Options["ui.cornerRadius"]:OnChanged(function(value: number)
            pcall(function()
                window:SetCornerRadius(value)
            end)
        end)

        interfaceBox:AddDropdown("ui.notifySide", {
            Text = "Notifications",
            Values = { "Right", "Left" },
            Default = windowConfig.NotifySide or "Right",
            Multi = false,
        })

        ctx.Options["ui.notifySide"]:OnChanged(function(side: string)
            pcall(function()
                library:SetNotifySide(side)
            end)
        end)

        interfaceBox:AddDropdown("ui.font", {
            Text = "Font",
            Values = FONTS,
            Default = windowConfig.Font or "Code",
            Multi = false,
        })

        ctx.Options["ui.font"]:OnChanged(function(name: string)
            local ok, font = pcall(function()
                return Enum.Font[name]
            end)

            if ok and font ~= nil then
                pcall(function()
                    library:SetFont(font)
                end)
            end
        end)

        interfaceBox:AddToggle("ui.animations", {
            Text = "Animations",
            Tooltip = "Window, tab and widget transitions.",
            Default = windowConfig.Animations == true,
        })

        ctx.Options["ui.animations"]:OnChanged(function(enabled: boolean)
            pcall(function()
                window:SetAnimations({
                    ToggleWindow = enabled,
                    TabSwitch = enabled,
                    Groupbox = enabled,
                    Dropdown = enabled,
                    KeyPicker = enabled,
                })
            end)
        end)

        -- ── Configuration ─────────────────────────────────────────────────

        local configsBox = tab:AddGroupbox({
            Side = "Right",
            Name = "Configuration",
            IconName = "folder-cog",
        })

        local configs = ctx.Configs

        if configs == nil then
            configsBox:AddLabel("configs.luau did not load, or this executor has no filesystem.")
            return
        end

        configsBox:AddInput("ui.configName", {
            Text = "Config name",
            Default = "default",
            Placeholder = "default",
        })

        local list = configsBox:AddDropdown("ui.config", {
            Text = "Config list",
            Values = configs:List(),
            Default = "",
            Multi = false,
        })

        local function refreshList()
            local names = configs:List()

            if #names == 0 then
                names = { "" }
            end

            list:SetValues(names)
        end

        local function targetName(): string?
            local typed = ctx.Options["ui.configName"]
            local selected = ctx.Options["ui.config"]

            local name = typed ~= nil and typed.Value or nil

            if type(name) ~= "string" or name == "" then
                name = selected ~= nil and selected.Value or nil
            end

            if type(name) ~= "string" or name == "" then
                return nil
            end

            return name
        end

        configsBox:AddButton({
            Text = "Create config",
            Tooltip = "Writes every setting under this place id.",
            Func = function()
                local name = targetName()

                if name == nil then
                    notify("Give the config a name first.")
                    return
                end

                local ok, err = configs:Save(name, configs:Snapshot(""))

                notify(ok and `Saved "{name}"` or `Could not save: {err}`, 5)

                if ok then
                    refreshList()
                end
            end,
        })

        configsBox:AddDivider()

        configsBox:AddButton({
            Text = "Load config",
            Tooltip = "Applies a saved config.",
            DoubleClick = true,
            Func = function()
                local name = targetName()

                if name == nil then
                    notify("Pick a config or type a name.")
                    return
                end

                local data, err = configs:Load(name)

                if data == nil then
                    notify(`Could not load: {err}`, 5)
                    return
                end

                local applied = configs:Apply("", data)

                notify(`Loaded "{name}" ({applied} settings)`)
            end,
        })

        configsBox:AddButton({
            Text = "Delete config",
            Tooltip = "Removes the config file.",
            Risky = true,
            DoubleClick = true,
            Func = function()
                local name = targetName()

                if name == nil then
                    notify("Pick a config to delete.")
                    return
                end

                local ok, err = configs:Delete(name)

                notify(ok and `Deleted "{name}"` or `Could not delete: {err}`, 5)

                if ok then
                    refreshList()
                end
            end,
        })

        configsBox:AddDivider()

        configsBox:AddLabel(`Stored in {configs:Directory()}/`)
    end,
}
