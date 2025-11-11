local addonName, addon = ...

LayoutLedger.options = {
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
                    get = function() return LayoutLedger.db.profile.export.actionBars end,
                    set = function(info, val) LayoutLedger.db.profile.export.actionBars = val end,
                },
                keybindings = {
                    type = "toggle",
                    name = "Keybindings",
                    desc = "Export keybindings",
                    get = function() return LayoutLedger.db.profile.export.keybindings end,
                    set = function(info, val) LayoutLedger.db.profile.export.keybindings = val end,
                },
                uiLayout = {
                    type = "toggle",
                    name = "UI Layout",
                    desc = "Export the UI layout",
                    get = function() return LayoutLedger.db.profile.export.uiLayout end,
                    set = function(info, val) LayoutLedger.db.profile.export.uiLayout = val end,
                },
                characterMacros = {
                    type = "toggle",
                    name = "Character Macros",
                    desc = "Export character specific macros",
                    get = function() return LayoutLedger.db.profile.export.characterMacros end,
                    set = function(info, val) LayoutLedger.db.profile.export.characterMacros = val end,
                },
                globalMacros = {
                    type = "toggle",
                    name = "Global Macros",
                    desc = "Export global macros",
                    get = function() return LayoutLedger.db.profile.export.globalMacros end,
                    set = function(info, val) LayoutLedger.db.profile.export.globalMacros = val end,
                },
            },
        },
    },
}
