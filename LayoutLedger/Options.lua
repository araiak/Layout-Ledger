local addonName, addon = ...
-- Options definition; Ace3 best practice is to attach to the AceAddon object (addon)
addon.options = {
    type = "group",
    name = "Layout Ledger",
    args = {
        export = {
            type = "group",
            name = "Export",
            args = {
                actionBars = {
                    type = "toggle",
                    name = "Action Bars",
                    desc = "Export action bar layouts",
                    get = function() return addon.db and addon.db.profile.export.actionBars end,
                    set = function(info, val)
                        if addon.db then addon.db.profile.export.actionBars = val end
                    end,
                },
                keybindings = {
                    type = "toggle",
                    name = "Keybindings",
                    desc = "Export keybindings",
                    get = function() return addon.db and addon.db.profile.export.keybindings end,
                    set = function(info, val)
                        if addon.db then addon.db.profile.export.keybindings = val end
                    end,
                },
                uiLayout = {
                    type = "toggle",
                    name = "UI Layout",
                    desc = "Export the UI layout",
                    get = function() return addon.db and addon.db.profile.export.uiLayout end,
                    set = function(info, val)
                        if addon.db then addon.db.profile.export.uiLayout = val end
                    end,
                },
                characterMacros = {
                    type = "toggle",
                    name = "Character Macros",
                    desc = "Export character specific macros",
                    get = function() return addon.db and addon.db.profile.export.characterMacros end,
                    set = function(info, val)
                        if addon.db then addon.db.profile.export.characterMacros = val end
                    end,
                },
                globalMacros = {
                    type = "toggle",
                    name = "Global Macros",
                    desc = "Export global macros",
                    get = function() return addon.db and addon.db.profile.export.globalMacros end,
                    set = function(info, val)
                        if addon.db then addon.db.profile.export.globalMacros = val end
                    end,
                },
            },
        },
    },
}
