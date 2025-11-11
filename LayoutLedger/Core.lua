local addonName, addon = ...
local LayoutLedger = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G[addonName] = LayoutLedger

LayoutLedger.defaults = {
    profile = {
        export = {
            actionBars = true,
            keybindings = true,
            uiLayout = true,
            characterMacros = true,
            globalMacros = true,
        },
        lastSettings = nil,
    },
}

function LayoutLedger:OnInitialize()
    local success, err = pcall(function()
        self.db = LibStub("AceDB-3.0"):New("LayoutLedgerDB", self.defaults, "Default")
        self:RegisterChatCommand("layoutledger", "ChatCommand")
        self:RegisterChatCommand("ll", "ChatCommand")
        LibStub("AceConfig-3.0"):RegisterOptionsTable("LayoutLedger", LayoutLedger.options)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LayoutLedger", "Layout Ledger")
        self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
        print("LayoutLedger: OnInitialize successful")
    end)
    if not success then
        print("LayoutLedger: Error in OnInitialize: " .. err)
    end
end

function LayoutLedger:OnAddonLoaded(event, addonName)
    print("LayoutLedger: OnAddonLoaded - " .. addonName)
    if addonName == "LayoutLedger" then
        self:InitializeUI()
    end
end

function LayoutLedger:InitializeUI()
    print("LayoutLedger: InitializeUI")
    local frame = CreateFrame("Frame", "LayoutLedgerFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 500)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Show() -- Explicitly show the frame

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Layout Ledger")

    self.frame = frame
    self:UpdateRevertButton()
end

function LayoutLedger:ToggleFrame()
    print("LayoutLedger: ToggleFrame")
    if self.frame:IsShown() then
        print("LayoutLedger: Hiding frame")
        self.frame:Hide()
    else
        print("LayoutLedger: Showing frame")
        self.frame:Show()
    end
end

function LayoutLedger:ChatCommand(input)
    print("LayoutLedger: ChatCommand - " .. tostring(input))
    if not input or input == "" then
        self:ToggleFrame()
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("layoutledger", "LayoutLedger", input)
    end
end

function LayoutLedger:Export_OnClick()
    print("LayoutLedger: Export_OnClick")
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
    self.importBox:SetText(encodedData)
end

function LayoutLedger:Import_OnClick()
    print("LayoutLedger: Import_OnClick")
    local encodedData = self.importBox:GetText()
    local data = self.Serialize.Decode(encodedData)

    if not data then
        print("Layout Ledger: Invalid import string.")
        return
    end

    self:SaveCurrentSettings()

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

function LayoutLedger:Revert_OnClick()
    print("LayoutLedger: Revert_OnClick")
    local data = self.db.profile.lastSettings
    if not data then return end

    self.Import.SetActionBars(data.actionBars, "Override")
    self.Import.SetKeybindings(data.keybindings, "Override")
    self.Import.SetEditModeLayout(data.uiLayout, "Override")
    self.Import.SetMacros({ character = data.characterMacros, global = data.globalMacros }, "Override")

    self.db.profile.lastSettings = nil
    self:UpdateRevertButton()
end
