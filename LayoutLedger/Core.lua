local addonName, addon = ...
local LayoutLedger = LibStub("AceAddon-3.0"):NewAddon("LayoutLedger", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

LayoutLedger.defaults = {
    profile = {
        export = {
            actionBars = true,
            keybindings = true,
            uiLayout = true,
            characterMacros = true,
            globalMacros = true,
        },
    },
}

function LayoutLedger:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("LayoutLedgerDB", self.defaults, "Default")
    self:RegisterChatCommand("layoutledger", "ChatCommand")
    self:RegisterChatCommand("ll", "ChatCommand")
    LibStub("AceConfig-3.0"):RegisterOptionsTable("LayoutLedger", LayoutLedger.options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LayoutLedger", "Layout Ledger")
end

function LayoutLedger:ChatCommand(input)
    if not input or input == "" then
        if LayoutLedgerFrame:IsShown() then
            LayoutLedgerFrame:Hide()
        else
            LayoutLedgerFrame:Show()
        end
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("layoutledger", "LayoutLedger", input)
    end
end

function LayoutLedger:Export_OnClick()
    local data = {}
    if self.db.profile.export.actionBars then
        data.actionBars = self.Export.GetActionBars()
    end
    if self.db.profile.export.keybindings then
        data.keybindings = self.Export.GetKeybindings()
    end
    if self.db.profile.export.uiLayout then
        data.uiLayout = self.Export.GetEditModeLayout()
    end
    if self.db.profile.export.characterMacros or self.db.profile.export.globalMacros then
        local macros = self.Export.GetMacros()
        if self.db.profile.export.characterMacros then
            data.characterMacros = macros.character
        end
        if self.db.profile.export.globalMacros then
            data.globalMacros = macros.global
        end
    end

    local encodedData = self.Serialize.Encode(data)
    LayoutLedgerFrameImportSectionImportBox:SetText(encodedData)
end

function LayoutLedger:Import_OnClick()
    local encodedData = LayoutLedgerFrameImportSectionImportBox:GetText()
    local data = self.Serialize.Decode(encodedData)

    if not data then
        print("Layout Ledger: Invalid import string.")
        return
    end

    local canMerge = data.characterMacros or data.globalMacros or data.actionBars

    StaticPopupDialogs["LAYOUTLEDGER_IMPORT_CONFIRM"] = {
        text = "How would you like to import?",
        button1 = "Override",
        button2 = "Merge",
        button3 = "Cancel",
        OnAccept = function()
            self.Import.SetActionBars(data.actionBars, "Override")
            self.Import.SetKeybindings(data.keybindings, "Override")
            self.Import.SetEditModeLayout(data.uiLayout, "Override")
            self.Import.SetMacros({ character = data.characterMacros, global = data.globalMacros }, "Override")
        end,
        OnAlt = function()
            if data.actionBars then
                self.Import.SetActionBars(data.actionBars, "Merge")
            end
            if data.characterMacros or data.globalMacros then
                self.Import.SetMacros({ character = data.characterMacros, global = data.globalMacros }, "Merge")
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
        OnShow = function(self)
            if not canMerge then
                self.button2:Disable()
            end
        end,
    }
    StaticPopup_Show("LAYOUTLEDGER_IMPORT_CONFIRM")
end
