return {
    Name = "UI Settings",
    Icon = "settings",

    Build = function(ctx, config, tab)
        local library = ctx.Library

        local function notify(text: string, duration: number?)
            library:Notify({
                Title = "Abyssal",
                Text = text,
                Duration = duration or 4,
            })
        end

        local Themes = ctx.LoadFile("libs/Addons/themes.luau")

        if Themes == nil then
            tab:AddGroupbox({ Side = "Left", Name = "Appearance" })
                :AddLabel("themes.luau did not load.")
        else
            local appearance = tab:AddGroupbox({ Side = "Left", Name = "Appearance" })

            appearance:AddDropdown("ui.theme", {
                Text = "Theme",
                Values = Themes.Names(),
                Default = Themes.Current() or (type(config.Theme) == "table" and config.Theme.Name) or "Abyssal",
                Multi = false,
            })

            ctx.Options["ui.theme"]:OnChanged(function(name: string)
                local ok, err = Themes.Apply(library, name)

                if not ok then
                    notify(`Could not apply that theme: {err}`, 5)
                end
            end)
        end

        local box = tab:AddGroupbox({ Side = "Right", Name = "Configs" })
        local configs = ctx.Configs

        if configs == nil then
            box:AddLabel("configs.luau did not load.")
            return
        end

        local available, reason = configs:Available()

        if not available then

            box:AddLabel(`Unavailable: {reason}`)
            box:AddLabel("Run libs/unctest.lua to see what this executor supports.")
            return
        end

        local dropdown = box:AddDropdown("ui.config", {
            Text = "Saved configs",
            Values = configs:List(),
            Default = "",
            Multi = false,
        })

        box:AddInput("ui.configName", {
            Text = "Name",
            Default = "default",
            Placeholder = "default",
        })

        local function refresh()
            local names = configs:List()

            if #names == 0 then
                names = { "" }
            end

            dropdown:SetValues(names)
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

        box:AddButton({
            Text = "Save",
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
                    refresh()
                end
            end,
        })

        box:AddButton({
            Text = "Load",
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

        box:AddButton({
            Text = "Delete",
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
                    refresh()
                end
            end,
        })

        box:AddDivider()

        box:AddLabel(`Stored in Abyssal/{tostring(game.PlaceId)}/`)
    end,
}
