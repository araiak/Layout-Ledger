-- LayoutLedger Core Logic
LayoutLedger = {}

function LayoutLedger.OnLoad(self)
    self:RegisterForDrag("LeftButton")
    SLASH_LAYOUTLEDGER1 = "/layoutledger"
    SLASH_LAYOUTLEDGER2 = "/ll"
    SlashCmdList["LAYOUTLEDGER"] = function()
        if LayoutLedgerFrame:IsShown() then
            LayoutLedgerFrame:Hide()
        else
            LayoutLedgerFrame:Show()
        end
    end
end

function LayoutLedger.Export_OnClick()
    local data = {}
    if LayoutLedgerFrameExportSectionActionBars:GetChecked() then
        data.actionBars = LayoutLedger.Export.GetActionBars()
    end
    if LayoutLedgerFrameExportSectionKeybindings:GetChecked() then
        data.keybindings = LayoutLedger.Export.GetKeybindings()
    end
    if LayoutLedgerFrameExportSectionUILayout:GetChecked() then
        data.uiLayout = LayoutLedger.Export.GetEditModeLayout()
    end
    if LayoutLedgerFrameExportSectionCharacterMacros:GetChecked() or LayoutLedgerFrameExportSectionGlobalMacros:GetChecked() then
        local macros = LayoutLedger.Export.GetMacros()
        if LayoutLedgerFrameExportSectionCharacterMacros:GetChecked() then
            data.characterMacros = macros.character
        end
        if LayoutLedgerFrameExportSectionGlobalMacros:GetChecked() then
            data.globalMacros = macros.global
        end
    end

    local encodedData = LayoutLedger.Serialize.Encode(data)
    LayoutLedgerFrameImportSectionImportBox:SetText(encodedData)
end

function LayoutLedger.Import_OnClick()
    local encodedData = LayoutLedgerFrameImportSectionImportBox:GetText()
    local data = LayoutLedger.Serialize.Decode(encodedData)

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
            LayoutLedger.Import.SetActionBars(data.actionBars, "Override")
            LayoutLedger.Import.SetKeybindings(data.keybindings, "Override")
            LayoutLedger.Import.SetEditModeLayout(data.uiLayout, "Override")
            LayoutLedger.Import.SetMacros({ character = data.characterMacros, global = data.globalMacros }, "Override")
        end,
        OnAlt = function()
            if data.actionBars then
                LayoutLedger.Import.SetActionBars(data.actionBars, "Merge")
            end
            if data.characterMacros or data.globalMacros then
                LayoutLedger.Import.SetMacros({ character = data.characterMacros, global = data.globalMacros }, "Merge")
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
