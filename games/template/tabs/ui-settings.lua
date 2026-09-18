--[[
    games/template/tabs/ui-settings.lua

    The UI Settings tab: theme, and saving/loading everything else.

    Premade. A new game should not need to touch this file.

    ─── On the config prefix ─────────────────────────────────────────────────

    Save captures every option in the hub, not just this tab's, which is why
    the prefix passed to Snapshot/Apply is empty. That is deliberate: options
    live in one flat table shared by the Home tab, this tab, the universal
    script and every game tab, and no single prefix covers them all. Configs
    are already namespaced per place id by main.lua, so "everything" here means
    "everything in this game", which is what a config is for.

    Loading skips any option that no longer exists, so a config saved before a
    feature was removed still loads the rest of itself.
]]

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

        -- ── Appearance ────────────────────────────────────────────────────

        local Themes = ctx.LoadFile("libs/Addons/themes.luau")

        if Themes == nil then
            tab:AddGroupbox({ Side = "Left", Name = "Appearance" })
                :AddLabel("themes.luau did not load.")
        else
            local appearance = tab:AddGroupbox({ Side = "Left", Name = "Appearance" })

            appearance:AddDropdown("ui.theme", {
                Text = "Theme",
                Values = Themes.Names(),
                Default = Themes.Current() or config.Theme or "Abyssal",
                Multi = false,
            })

            ctx.Options["ui.theme"]:OnChanged(function(name: string)
                local ok, err = Themes.Apply(library, name)

                if not ok then
                    notify(`Could not apply that theme: {err}`, 5)
                end
            end)
        end

        -- ── Configs ───────────────────────────────────────────────────────

        local box = tab:AddGroupbox({ Side = "Right", Name = "Configs" })
        local configs = ctx.Configs

        if configs == nil then
            box:AddLabel("configs.luau did not load.")
            return
        end

        local available, reason = configs:Available()

        if not available then
            -- Say why, rather than showing a save button that silently does
            -- nothing. This is what an executor with no filesystem looks like.
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

        -- Repopulates after a save or delete, so the list is never stale.
        local function refresh()
            local names = configs:List()

            if #names == 0 then
                names = { "" }
            end

            dropdown:SetValues(names)
        end

        -- The name box wins if it has something in it; otherwise fall back to
        -- whichever config is selected, so "load the one I just picked" works
        -- without retyping it.
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
