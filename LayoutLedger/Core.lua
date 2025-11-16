local addonName, addon = ...
addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G[addonName] = addon

-- Export format version
-- Used for backwards compatibility when import format changes
addon.EXPORT_VERSION = "0.1.0"

--[[
EXPORT FORMAT VERSION HISTORY

Version 0.1.0 (Initial versioned format):
- Added version field to exports
- Export data structure:
  {
    version = "0.1.0",
    exportType = nil (regular export) or "classProfile",
    metadata = {
      exportDate, addonVersion, characterName, realmName, characterLevel,
      className, classID, specID, specName, specIndex, keybindingScope
    },
    actionBars = { [slot] = { type, id, subType, macroName } },
    keybindings = { [command] = { key1, key2, category } },
    uiLayout = {
      layoutString = "...",
      layoutName = "...",
      layoutType = 0-3  -- 0=Preset, 1=Account, 2=Character, 3=Override
    },
    cooldownLayout = "...",  -- String from C_CooldownViewer
    cvars = { [cvarName] = value },  -- Console variables
    characterMacros = { { name, icon, body } },
    globalMacros = { { name, icon, body } },
    classProfile = {  -- Only present if exportType == "classProfile"
      characterSettings = { keybindings, uiLayout, characterMacros, globalMacros, cvars },
      specSettings = { [specID] = { actionBars, cooldownLayout } }
    }
  }

Pre-versioning (Legacy):
- No version field
- uiLayout was a plain string (not a table with metadata)
- All other fields same as 0.1.0
]]

addon.defaults = {
    profile = {
        export = {
            actionBars = true,
            keybindings = true,
            uiLayout = true,
            cooldownLayout = true,
            characterMacros = true,
            globalMacros = true,
            cvars = true,
        },
        lastBackupProfileName = nil,  -- Name of backup profile for revert (e.g., "CharacterName-BAK")
    },
    char = {
        autoSaveSpecBars = false,  -- Character-specific: Auto-save action bars to class profile on spec change
        lastSavedSpecID = nil,  -- Track last saved spec to prevent duplicate saves on event spam
        activeProfileName = nil,  -- Name of currently active profile (for auto-applying spec bars)
        lastAppliedSpecID = nil,  -- Track last applied spec from active profile
    },
    class = {
        -- Class-wide shared settings (non-spec-specific)
        characterSettings = {
            keybindings = nil,
            uiLayout = nil,
            characterMacros = nil,
            globalMacros = nil,
        },
        -- Spec-specific settings keyed by specID
        specSettings = {},  -- [specID] = { actionBars = {...}, cooldownLayout = "..." }
        savedLayouts = {},  -- Store multiple class-specific layouts (future feature)
    },
    global = {
        dataVersion = nil,  -- Database version for migrations (set to current version on first run)
        savedProfiles = {},  -- Account-wide saved profiles (future feature)
    },
}

function addon:OnInitialize()
    local success, err = pcall(function()
        self.db = LibStub("AceDB-3.0"):New("LayoutLedgerDB", self.defaults, "Default")

        -- Run database migrations (upgrade saved data to current version)
        local migrationSuccess = self.Migrations.MigrateDatabase(self.db)
        if not migrationSuccess then
            print("LayoutLedger: WARNING - Database migration failed! Some features may not work correctly.")
        end

        -- Slash commands
        self:RegisterChatCommand("layoutledger", "ChatCommand")
        self:RegisterChatCommand("ll", "ChatCommand")

        -- Options (Options.lua attaches self.options)
        if self.options then
            LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self.options)
            LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Layout Ledger")
        else
            print("LayoutLedger: Warning - Options not loaded")
        end
    end)
    if not success then
        print("LayoutLedger: Error in OnInitialize: " .. tostring(err))
    end
end

function addon:OnEnable()
    -- Frame initialization moved here from ADDON_LOADED handler
    -- By the time OnEnable is called (PLAYER_LOGIN), all frames from UI.xml are available
    local success, err = pcall(function()
        -- Frames from UI.xml; guard in case XML changes or fails
        -- Note: child names are derived from "$parent..." in UI.xml:
        --   LayoutLedgerFrameImportSectionImportScrollFrameImportBox
        --   LayoutLedgerFrameImportSectionRevertButton
        self.frame = _G["LayoutLedgerFrame"]
        self.importBox = _G["LayoutLedgerFrameImportSectionImportScrollFrameImportBox"]
        self.revertButton = _G["LayoutLedgerFrameImportSectionRevertButton"]

        if not (self.frame and self.importBox and self.revertButton) then
            print("LayoutLedger: UI frame wiring failed (missing XML frames)")
            return
        end

        -- Set up backdrop (modern WoW API - frame inherits BackdropTemplate)
        if self.frame.SetBackdrop then
            self.frame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            })
            self.frame:SetBackdropColor(0, 0, 0, 1)
            self.frame:SetBackdropBorderColor(1, 1, 1, 1)
        end

        -- Set checkbox labels (must be done after frames exist)
        local actionBarsCheck = _G["LayoutLedgerFrameExportSectionActionBarsCheck"]
        local keybindingsCheck = _G["LayoutLedgerFrameExportSectionKeybindingsCheck"]
        local uiLayoutCheck = _G["LayoutLedgerFrameExportSectionUILayoutCheck"]
        local cooldownLayoutCheck = _G["LayoutLedgerFrameExportSectionCooldownLayoutCheck"]
        local characterMacrosCheck = _G["LayoutLedgerFrameExportSectionCharacterMacrosCheck"]
        local globalMacrosCheck = _G["LayoutLedgerFrameExportSectionGlobalMacrosCheck"]
        local cvarsCheck = _G["LayoutLedgerFrameExportSectionCVarsCheck"]

        if actionBarsCheck and actionBarsCheck.Text then
            actionBarsCheck.Text:SetText("Action Bars (Current Spec)")
        end
        if keybindingsCheck and keybindingsCheck.Text then
            keybindingsCheck.Text:SetText("Keybindings")
        end
        if uiLayoutCheck and uiLayoutCheck.Text then
            uiLayoutCheck.Text:SetText("UI Layout")
        end
        if cooldownLayoutCheck and cooldownLayoutCheck.Text then
            cooldownLayoutCheck.Text:SetText("Cooldown Viewer Layout")
        end
        if characterMacrosCheck and characterMacrosCheck.Text then
            characterMacrosCheck.Text:SetText("Character Macros")
        end
        if globalMacrosCheck and globalMacrosCheck.Text then
            globalMacrosCheck.Text:SetText("Global Macros")
        end
        if cvarsCheck and cvarsCheck.Text then
            cvarsCheck.Text:SetText("CVars (UI Scale)")
        end

        -- Enable dragging
        self.frame:SetScript("OnMouseDown", function(frame, button)
            if button == "LeftButton" and frame:IsMovable() then
                frame:StartMoving()
            end
        end)
        self.frame:SetScript("OnMouseUp", function(frame, button)
            if button == "LeftButton" then
                frame:StopMovingOrSizing()
            end
        end)

        -- Register events
        self:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")  -- Spec changed

        self:UpdateRevertButton()
        print("LayoutLedger: Loaded successfully! Type /ll to open.")
    end)
    if not success then
        print("LayoutLedger: Error in OnEnable: " .. tostring(err))
    end
end

function addon:PLAYER_REGEN_DISABLED()
    -- Close windows when entering combat (Midnight expansion will cause issues)
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        print("LayoutLedger: Window closed due to combat.")
    end

    local smartImportFrame = _G["LayoutLedgerSmartImportFrame"]
    if smartImportFrame and smartImportFrame:IsShown() then
        smartImportFrame:Hide()
    end
end

function addon:PLAYER_SPECIALIZATION_CHANGED()
    if not self.db then
        return
    end

    -- Get current spec info
    local currentSpecIndex = GetSpecialization()
    if not currentSpecIndex then
        return
    end

    local currentSpecID, currentSpecName = GetSpecializationInfo(currentSpecIndex)
    if not currentSpecID then
        return
    end

    -- AUTO-APPLY: Check if there's an active profile to apply
    local activeProfileName = self.db.char.activeProfileName
    if activeProfileName and self.db.global.savedProfiles and self.db.global.savedProfiles[activeProfileName] then
        local profileData = self.db.global.savedProfiles[activeProfileName]

        -- Only apply if:
        -- 1. It's a class profile
        -- 2. We haven't already applied this spec (debounce)
        if profileData.profileType == "classProfile" and self.db.char.lastAppliedSpecID ~= currentSpecID then
            -- Check if profile has settings for this spec
            if profileData.specSettings and profileData.specSettings[currentSpecID] then
                local specData = profileData.specSettings[currentSpecID]

                -- Apply spec-specific settings
                if self.Import and not InCombatLockdown() then
                    if specData.actionBars then
                        self.Import.SetActionBars(specData.actionBars, "Override")
                        print(string.format("LayoutLedger: Applied action bars for %s from '%s' profile", currentSpecName or "Unknown Spec", activeProfileName))
                    end

                    if specData.cooldownLayout then
                        self.Import.SetCooldownLayout(specData.cooldownLayout, "Override")
                    end

                    self.db.char.lastAppliedSpecID = currentSpecID
                end
            end
        end
    end

    -- AUTO-SAVE: Save action bars to class profile if enabled
    if not self.db.char.autoSaveSpecBars or not self.Export then
        return
    end

    -- DEBOUNCE: Check if this spec was already saved
    -- PLAYER_SPECIALIZATION_CHANGED can fire multiple times, especially when joining groups
    -- Only save if the spec has actually changed from the last saved spec
    if self.db.char.lastSavedSpecID == currentSpecID then
        -- Already saved this spec, skip to prevent duplicate saves
        return
    end

    -- Save action bars and cooldown layout for this spec to class profile
    local actionBars = self.Export.GetActionBars()
    local cooldownLayout = self.Export.GetCooldownLayout()

    if not self.db.class.specSettings then
        self.db.class.specSettings = {}
    end

    self.db.class.specSettings[currentSpecID] = {
        actionBars = actionBars,
        cooldownLayout = cooldownLayout,
    }

    -- Update the last saved spec ID to prevent duplicate saves
    self.db.char.lastSavedSpecID = currentSpecID

    local className = select(2, UnitClass("player"))
    local savedItems = {"action bars"}
    if cooldownLayout then
        table.insert(savedItems, "cooldown layout")
    end
    print(string.format("LayoutLedger: Auto-saved %s %s to %s class profile",
        currentSpecName, table.concat(savedItems, " and "), className))
end

function addon:OnDisable()
    -- Hide frame if it's showing
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end
end

function addon:UpdateRevertButton()
    if not self.revertButton or not self.db then
        return
    end

    -- Check if backup profile exists
    local backupProfileName = self.db.profile.lastBackupProfileName
    if not backupProfileName then
        -- Fallback to default name
        local characterName = UnitName("player") or "Unknown"
        backupProfileName = characterName .. "-BAK"
    end

    local hasBackup = self.db.global.savedProfiles and self.db.global.savedProfiles[backupProfileName]

    if hasBackup then
        self.revertButton:Enable()
    else
        self.revertButton:Disable()
    end
end

function addon:RefreshUI()
    -- Update checkbox states when UI is opened
    if not self.db then return end

    -- Find and update export checkboxes
    local exportSection = _G["LayoutLedgerFrameExportSection"]
    if exportSection then
        local actionBarsCheck = _G["LayoutLedgerFrameExportSectionActionBarsCheck"]
        local keybindingsCheck = _G["LayoutLedgerFrameExportSectionKeybindingsCheck"]
        local uiLayoutCheck = _G["LayoutLedgerFrameExportSectionUILayoutCheck"]
        local cooldownLayoutCheck = _G["LayoutLedgerFrameExportSectionCooldownLayoutCheck"]
        local characterMacrosCheck = _G["LayoutLedgerFrameExportSectionCharacterMacrosCheck"]
        local globalMacrosCheck = _G["LayoutLedgerFrameExportSectionGlobalMacrosCheck"]
        local cvarsCheck = _G["LayoutLedgerFrameExportSectionCVarsCheck"]

        if actionBarsCheck then
            actionBarsCheck:SetChecked(self.db.profile.export.actionBars)
        end
        if keybindingsCheck then
            keybindingsCheck:SetChecked(self.db.profile.export.keybindings)
        end
        if uiLayoutCheck then
            uiLayoutCheck:SetChecked(self.db.profile.export.uiLayout)
        end
        if cooldownLayoutCheck then
            cooldownLayoutCheck:SetChecked(self.db.profile.export.cooldownLayout)
        end
        if characterMacrosCheck then
            characterMacrosCheck:SetChecked(self.db.profile.export.characterMacros)
        end
        if globalMacrosCheck then
            globalMacrosCheck:SetChecked(self.db.profile.export.globalMacros)
        end
        if cvarsCheck then
            cvarsCheck:SetChecked(self.db.profile.export.cvars)
        end
    end

    -- Update revert button state
    self:UpdateRevertButton()
end

function addon:CountActions(actionBars)
    if not actionBars then return 0 end
    local count = 0
    for _ in pairs(actionBars) do
        count = count + 1
    end
    return count
end

function addon:CountKeybindings(keybindings)
    if not keybindings then return 0 end
    local count = 0
    for _ in pairs(keybindings) do
        count = count + 1
    end
    return count
end

function addon:AnalyzeImportApplicability(data)
    local meta = data.metadata
    if not meta then
        -- Legacy import without metadata
        return nil
    end

    local applicability = {}

    -- Global Macros (account-wide)
    applicability.globalMacros = {
        available = data.globalMacros ~= nil,
        applicable = true,
        count = data.globalMacros and #data.globalMacros or 0,
        scope = "account",
        warning = nil,
    }

    -- Character Macros (character-specific)
    applicability.characterMacros = {
        available = data.characterMacros ~= nil,
        applicable = true,
        count = data.characterMacros and #data.characterMacros or 0,
        scope = "character",
        warning = nil,
    }

    -- Action Bars (spec-specific)
    local currentSpecIndex = GetSpecialization()
    local currentSpecID, currentSpecName = nil, nil
    if currentSpecIndex then
        currentSpecID, currentSpecName = GetSpecializationInfo(currentSpecIndex)
    end

    local actionBarsApplicable = (currentSpecIndex == meta.specIndex)
    applicability.actionBars = {
        available = data.actionBars ~= nil,
        applicable = actionBarsApplicable,
        count = self:CountActions(data.actionBars),
        scope = "spec",
        warning = not actionBarsApplicable and
            ("Exported from " .. (meta.specName or "Unknown") .. " spec. " ..
             "You are currently in " .. (currentSpecName or "Unknown") .. " spec.") or nil,
        exportedSpec = meta.specName,
        currentSpec = currentSpecName,
    }

    -- UI Layout (character-specific)
    applicability.uiLayout = {
        available = data.uiLayout ~= nil,
        applicable = true,
        scope = "character",
        warning = nil,
    }

    -- Cooldown Viewer Layout (spec-specific)
    local cooldownApplicable = (currentSpecIndex == meta.specIndex)
    applicability.cooldownLayout = {
        available = data.cooldownLayout ~= nil,
        applicable = cooldownApplicable,
        scope = "spec",
        warning = not cooldownApplicable and
            ("Exported from " .. (meta.specName or "Unknown") .. " spec. " ..
             "You are currently in " .. (currentSpecName or "Unknown") .. " spec.") or nil,
        exportedSpec = meta.specName,
        currentSpec = currentSpecName,
    }

    -- Keybindings (character or account)
    local currentBindingSet = GetCurrentBindingSet()
    local currentScope = (currentBindingSet == ACCOUNT_BINDINGS) and "account" or "character"
    local scopeMatch = (currentScope == meta.keybindingScope)

    applicability.keybindings = {
        available = data.keybindings ~= nil,
        applicable = true,  -- Can always import, but warn if scope mismatch
        count = self:CountKeybindings(data.keybindings),
        scope = meta.keybindingScope,
        warning = not scopeMatch and
            ("Exported from " .. meta.keybindingScope .. " keybindings. " ..
             "You are using " .. currentScope .. " keybindings.") or nil,
    }

    -- CVars (account-wide)
    applicability.cvars = {
        available = data.cvars ~= nil,
        applicable = true,
        count = data.cvars and (function()
            local count = 0
            for _ in pairs(data.cvars) do count = count + 1 end
            return count
        end)() or 0,
        scope = "account",
        warning = nil,
    }

    return applicability
end


function addon:ToggleFrame()
    if not self.frame then
        print("LayoutLedger: Frame not initialized. Please reload your UI (/reload)")
        return
    end

    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        -- Refresh UI state when opening
        self:RefreshUI()
    end
end

function addon:ChatCommand(input)
    if not input or input == "" then
        self:ToggleFrame()
    elseif input == "debug" then
        -- Show debug menu
        self:ShowDebugFrame()
    elseif input == "testcooldown" or input == "testcd" then
        -- Test cooldown viewer data
        self:TestCooldownViewer()
    elseif input == "testeditmode" or input == "testem" then
        -- Test edit mode API structure
        self:TestEditModeAPI()
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("layoutledger", addonName, input)
    end
end

function addon:TestCooldownViewer()
    print("=== Testing Cooldown Viewer API ===")

    -- Check if API exists
    if not C_CooldownViewer then
        print("ERROR: C_CooldownViewer namespace not found (may not be available in this build)")
        return
    end

    if not C_CooldownViewer.GetLayoutData then
        print("ERROR: C_CooldownViewer.GetLayoutData function not found")
        return
    end

    -- Try to get layout data
    local success, layoutData = pcall(function()
        return C_CooldownViewer.GetLayoutData()
    end)

    if not success then
        print("ERROR calling GetLayoutData:", tostring(layoutData))
        return
    end

    if not layoutData then
        print("GetLayoutData returned nil (no cooldown viewer configuration?)")
        return
    end

    print("SUCCESS: Got cooldown viewer layout data")
    print("Data type:", type(layoutData))

    -- Try to print the structure
    if type(layoutData) == "table" then
        print("Table keys:")
        for key, value in pairs(layoutData) do
            print("  ", key, "=", type(value), tostring(value))
        end
    else
        print("Data:", tostring(layoutData))
    end

    print("=== End Test ===")
end

function addon:TestEditModeAPI()
    print("=== Testing Edit Mode API ===")

    if not C_EditMode then
        print("ERROR: C_EditMode namespace not found")
        return
    end

    if not C_EditMode.GetLayouts then
        print("ERROR: C_EditMode.GetLayouts function not found")
        return
    end

    -- Get layouts
    local success, layouts = pcall(function()
        return C_EditMode.GetLayouts()
    end)

    if not success then
        print("ERROR calling GetLayouts:", tostring(layouts))
        return
    end

    if not layouts then
        print("GetLayouts returned nil")
        return
    end

    print("SUCCESS: Got layouts structure")
    print("Type:", type(layouts))

    -- Inspect the structure
    if type(layouts) == "table" then
        print("\nTop-level keys:")
        for key, value in pairs(layouts) do
            print("  ", key, "=", type(value))
            if key == "activeLayout" then
                print("    activeLayout value:", tostring(value))
            elseif key == "layouts" and type(value) == "table" then
                print("    layouts is a table with", #value, "entries")
                for i = 1, math.min(#value, 3) do
                    print("      layouts[" .. i .. "]:", tostring(value[i]))
                    if type(value[i]) == "table" then
                        local keys = {}
                        for k, _ in pairs(value[i]) do
                            table.insert(keys, tostring(k))
                        end
                        print("        Keys:", table.concat(keys, ", "))
                    end
                end
            end
        end

        -- Try to convert a layout to string
        if layouts.layouts and #layouts.layouts > 0 then
            print("\nTrying to convert first layout to string...")
            local layoutInfo = layouts.layouts[1]
            if layoutInfo then
                local stringResult = C_EditMode.ConvertLayoutInfoToString(layoutInfo)
                print("ConvertLayoutInfoToString result:", stringResult and "SUCCESS (length: " .. #stringResult .. ")" or "FAILED (nil)")
            end
        end
    end

    print("=== End Test ===")
end

---
-- DEBUG MENU FUNCTIONS
---

function addon:ShowDebugFrame()
    local frame = _G["LayoutLedgerDebugFrame"]
    if not frame then
        print("LayoutLedger: Debug frame not found!")
        return
    end

    self:RefreshDebugUI()
    frame:Show()
end

function addon:RefreshDebugUI()
    local frame = _G["LayoutLedgerDebugFrame"]
    if not frame then
        return
    end

    -- Count current macros
    local charMacroCount = 0
    local globalMacroCount = 0

    for i = 1, 120 do
        local name = GetMacroInfo(i)
        if name then
            globalMacroCount = globalMacroCount + 1
        end
    end

    for i = 121, 150 do
        local name = GetMacroInfo(i)
        if name then
            charMacroCount = charMacroCount + 1
        end
    end

    -- Count action bars
    local actionCount = 0
    for i = 1, 120 do
        local actionType = GetActionInfo(i)
        if actionType then
            actionCount = actionCount + 1
        end
    end

    -- Update info display
    local infoText = _G["LayoutLedgerDebugFrameInfo"]
    if infoText then
        local text = string.format(
            "Current State:\n\n" ..
            "• %d Global Macros (Account-wide)\n" ..
            "• %d Character Macros\n" ..
            "• %d Action Bar Slots Filled\n\n" ..
            "WARNING: These actions cannot be undone!\n" ..
            "Make an export before clearing.",
            globalMacroCount, charMacroCount, actionCount
        )
        infoText:SetText(text)
    end
end

function addon:Debug_ClearCharacterMacros()
    if InCombatLockdown() then
        print("LayoutLedger: Cannot delete macros while in combat.")
        return
    end

    StaticPopupDialogs["LAYOUTLEDGER_DEBUG_CLEAR_CHAR_MACROS"] = {
        text = "Delete ALL character macros?\n\nThis cannot be undone!",
        button1 = "Delete All",
        button2 = "Cancel",
        OnAccept = function()
            local deleted = 0
            -- Delete backwards to avoid index shifting
            for i = 150, 121, -1 do
                local name = GetMacroInfo(i)
                if name then
                    DeleteMacro(i)
                    deleted = deleted + 1
                end
            end
            print(string.format("LayoutLedger: Deleted %d character macro(s)", deleted))
            addon:RefreshDebugUI()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_DEBUG_CLEAR_CHAR_MACROS")
end

function addon:Debug_ClearGlobalMacros()
    if InCombatLockdown() then
        print("LayoutLedger: Cannot delete macros while in combat.")
        return
    end

    StaticPopupDialogs["LAYOUTLEDGER_DEBUG_CLEAR_GLOBAL_MACROS"] = {
        text = "Delete ALL global macros?\n\nThis affects ALL characters!\nThis cannot be undone!",
        button1 = "Delete All",
        button2 = "Cancel",
        OnAccept = function()
            local deleted = 0
            -- Delete backwards to avoid index shifting
            for i = 120, 1, -1 do
                local name = GetMacroInfo(i)
                if name then
                    DeleteMacro(i)
                    deleted = deleted + 1
                end
            end
            print(string.format("LayoutLedger: Deleted %d global macro(s)", deleted))
            addon:RefreshDebugUI()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_DEBUG_CLEAR_GLOBAL_MACROS")
end

function addon:Debug_ClearActionBars()
    if InCombatLockdown() then
        print("LayoutLedger: Cannot clear action bars while in combat.")
        return
    end

    StaticPopupDialogs["LAYOUTLEDGER_DEBUG_CLEAR_ACTIONS"] = {
        text = "Clear ALL action bar slots?\n\nThis cannot be undone!",
        button1 = "Clear All",
        button2 = "Cancel",
        OnAccept = function()
            local cleared = 0
            for i = 1, 120 do
                if GetActionInfo(i) then
                    PickupAction(i)
                    ClearCursor()
                    cleared = cleared + 1
                end
            end
            print(string.format("LayoutLedger: Cleared %d action bar slot(s)", cleared))
            addon:RefreshDebugUI()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_DEBUG_CLEAR_ACTIONS")
end

function addon:Debug_ResetKeybindings()
    if InCombatLockdown() then
        print("LayoutLedger: Cannot reset keybindings while in combat.")
        return
    end

    StaticPopupDialogs["LAYOUTLEDGER_DEBUG_RESET_KEYS"] = {
        text = "Reset ALL keybindings to defaults?\n\nThis cannot be undone!",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function()
            -- Get current binding set
            local bindingSet = GetCurrentBindingSet()

            -- Reset to defaults
            LoadBindings(bindingSet)

            -- Save the reset bindings
            SaveBindings(bindingSet)

            print("LayoutLedger: Keybindings reset to defaults")
            print("A UI reload may be required for changes to take effect (/reload)")
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_DEBUG_RESET_KEYS")
end

function addon:Debug_DeleteCustomLayouts()
    if InCombatLockdown() then
        print("LayoutLedger: Cannot delete layouts while in combat.")
        return
    end

    if not C_EditMode or not C_EditMode.GetLayouts then
        print("LayoutLedger: Edit Mode API not available")
        return
    end

    StaticPopupDialogs["LAYOUTLEDGER_DEBUG_DELETE_LAYOUTS"] = {
        text = "Delete ALL custom Edit Mode layouts?\n\n(Preset layouts will be preserved)\nThis cannot be undone!",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            local layouts = C_EditMode.GetLayouts()
            if not layouts or not layouts.layouts then
                print("LayoutLedger: No layouts found")
                return
            end

            local deleted = 0
            -- Delete custom layouts (layoutType 1=Account, 2=Character)
            -- Don't delete preset layouts (layoutType 0)
            for i = #layouts.layouts, 1, -1 do
                local layout = layouts.layouts[i]
                if layout and layout.layoutType and layout.layoutType > 0 then
                    -- This is a custom layout, delete it
                    -- Note: There's no direct delete API, so we'll try to use OnLayoutDeleted event
                    -- For now, just inform the user
                    deleted = deleted + 1
                end
            end

            if deleted > 0 then
                print(string.format("LayoutLedger: Found %d custom layout(s)", deleted))
                print("LayoutLedger: Note - WoW doesn't provide an API to delete layouts")
                print("You can delete them manually in Edit Mode settings")
            else
                print("LayoutLedger: No custom layouts found")
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_DEBUG_DELETE_LAYOUTS")
end

function addon:Debug_ClearDatabase()
    if InCombatLockdown() then
        print("LayoutLedger: Cannot clear database while in combat.")
        return
    end

    StaticPopupDialogs["LAYOUTLEDGER_DEBUG_CLEAR_DB"] = {
        text = "Clear LayoutLedger saved database?\n\nThis will reset:\n• Class profiles\n• Saved settings\n• All addon data\n\nThis cannot be undone!",
        button1 = "Clear Database",
        button2 = "Cancel",
        OnAccept = function()
            if addon.db then
                addon.db:ResetDB()
                print("LayoutLedger: Database cleared and reset to defaults")
                print("A UI reload is recommended (/reload)")
            else
                print("LayoutLedger: Database not available")
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_DEBUG_CLEAR_DB")
end

---
-- SAVED PROFILES FUNCTIONS
---

function addon:ShowSavedProfilesFrame()
    local frame = _G["LayoutLedgerSavedProfilesFrame"]
    if not frame then
        print("LayoutLedger: Saved Profiles frame not found!")
        return
    end

    self:RefreshSavedProfilesUI()
    frame:Show()
end

function addon:RefreshSavedProfilesUI()
    local frame = _G["LayoutLedgerSavedProfilesFrame"]
    if not frame then
        return
    end

    -- Set backdrop if needed
    if frame.SetBackdrop and not frame.backdropSet then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        frame:SetBackdropColor(0, 0, 0, 1)
        frame:SetBackdropBorderColor(1, 1, 1, 1)
        frame.backdropSet = true
    end

    -- Update info text
    local infoText = _G["LayoutLedgerSavedProfilesFrameInfo"]
    if infoText then
        local profileCount = 0
        local backupCount = 0
        if self.db and self.db.global and self.db.global.savedProfiles then
            for name, _ in pairs(self.db.global.savedProfiles) do
                profileCount = profileCount + 1
                if name:match("%-BAK$") then
                    backupCount = backupCount + 1
                end
            end
        end
        local regularCount = profileCount - backupCount
        infoText:SetText(string.format("Account-wide saved profiles: %d total (%d regular, %d backup).\nEnter a name below to save your current settings.\n\nBackups (orange) are auto-created before imports and deleted after revert.", profileCount, regularCount, backupCount))
    end

    -- Clear and rebuild profile list
    local scrollChild = _G["LayoutLedgerSavedProfilesFrameScrollFrameScrollChild"]
    if not scrollChild then
        return
    end

    -- Clear existing children
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Build profile list
    if not self.db or not self.db.global or not self.db.global.savedProfiles then
        return
    end

    local profiles = {}
    for name, data in pairs(self.db.global.savedProfiles) do
        table.insert(profiles, {name = name, data = data})
    end

    -- Sort alphabetically
    table.sort(profiles, function(a, b) return a.name < b.name end)

    local yOffset = -10
    for _, profile in ipairs(profiles) do
        -- Create profile entry frame
        local entry = CreateFrame("Frame", nil, scrollChild)
        entry:SetSize(460, 70)
        entry:SetPoint("TOPLEFT", 5, yOffset)

        -- Check profile type and status
        local isBackup = profile.name:match("%-BAK$")
        local isActive = self.db.char.activeProfileName == profile.name
        local profileType = profile.data.profileType or "simple"

        -- Profile name
        local nameLabel = entry:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        nameLabel:SetPoint("TOPLEFT", 5, -5)

        -- Color and format profile name
        local displayName = profile.name
        if isActive then
            displayName = "|cFF00FF00★ " .. displayName .. "|r" -- Green star for active
        elseif isBackup then
            displayName = "|cFFFFAA00" .. displayName .. "|r" -- Orange for backups
        elseif profileType == "classProfile" then
            displayName = "|cFF88CCFF" .. displayName .. "|r" -- Light blue for class profiles
        end
        nameLabel:SetText(displayName)

        -- Profile details
        local detailsLabel = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        detailsLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -3)
        detailsLabel:SetWidth(450)
        detailsLabel:SetJustifyH("LEFT")

        local details = ""
        if profile.data.metadata then
            local meta = profile.data.metadata
            details = string.format("Saved: %s | %s @ %s",
                date("%Y-%m-%d %H:%M", profile.data.savedDate or 0),
                meta.characterName or "Unknown",
                meta.realmName or "Unknown")

            -- Add type indicators
            if isBackup then
                details = details .. " | |cFFFFAA00[AUTO BACKUP]|r"
            elseif profileType == "classProfile" then
                local specCount = self:CountKeys(profile.data.specSettings or {})
                details = details .. string.format(" | |cFF88CCFF[CLASS PROFILE - %d spec(s)]|r", specCount)
            end
        end
        detailsLabel:SetText(details)

        -- Buttons on the right side
        local xOffset = -5

        -- Delete button (rightmost)
        local deleteButton = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
        deleteButton:SetSize(65, 22)
        deleteButton:SetPoint("TOPRIGHT", entry, "TOPRIGHT", xOffset, -5)
        deleteButton:SetText("Delete")
        deleteButton:SetScript("OnClick", function()
            addon:DeleteProfile(profile.name)
        end)
        xOffset = xOffset - 70

        -- Set as Active button (only for class profiles, middle)
        if profileType == "classProfile" then
            local activeButton = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
            activeButton:SetSize(95, 22)
            activeButton:SetPoint("TOPRIGHT", entry, "TOPRIGHT", xOffset, -5)

            if isActive then
                activeButton:SetText("|cFF00FF00★ Active|r")
                activeButton:Disable()
            else
                activeButton:SetText("Set Active")
                activeButton:SetScript("OnClick", function()
                    addon:LoadProfile(profile.name, true)
                end)
            end
            xOffset = xOffset - 100
        end

        -- Load button (leftmost of buttons)
        local loadButton = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
        loadButton:SetSize(55, 22)
        loadButton:SetPoint("TOPRIGHT", entry, "TOPRIGHT", xOffset, -5)
        loadButton:SetText("Load")
        loadButton:SetScript("OnClick", function()
            addon:LoadProfile(profile.name, false)
        end)

        -- Separator line
        local separator = entry:CreateTexture(nil, "ARTWORK")
        separator:SetHeight(1)
        separator:SetPoint("BOTTOMLEFT", 0, 0)
        separator:SetPoint("BOTTOMRIGHT", 0, 0)
        separator:SetColorTexture(0.3, 0.3, 0.3, 0.5)

        yOffset = yOffset - 75
    end

    -- Adjust scroll child height
    scrollChild:SetHeight(math.max(280, math.abs(yOffset) + 20))
end

function addon:SaveNewProfile_OnClick(asClassProfile)
    if InCombatLockdown() then
        print("LayoutLedger: Cannot save profile while in combat.")
        return
    end

    local nameInput = _G["LayoutLedgerSavedProfilesFrameProfileNameInput"]
    if not nameInput then
        return
    end

    local profileName = nameInput:GetText()
    if not profileName or profileName == "" then
        print("LayoutLedger: Please enter a profile name.")
        return
    end

    -- Trim whitespace
    profileName = profileName:match("^%s*(.-)%s*$")

    if profileName == "" then
        print("LayoutLedger: Profile name cannot be empty.")
        return
    end

    -- Check if profile exists
    if self.db.global.savedProfiles[profileName] then
        -- Show overwrite confirmation
        StaticPopupDialogs["LAYOUTLEDGER_OVERWRITE_PROFILE"] = {
            text = string.format("A profile named '%s' already exists.\n\nOverwrite it?", profileName),
            button1 = "Overwrite",
            button2 = "Cancel",
            OnAccept = function()
                addon:SaveProfile(profileName, asClassProfile)
                nameInput:SetText("")
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
        }
        StaticPopup_Show("LAYOUTLEDGER_OVERWRITE_PROFILE")
    else
        self:SaveProfile(profileName, asClassProfile)
        nameInput:SetText("")
    end
end

function addon:SaveProfile(profileName, asClassProfile)
    if not self.db or not self.Export then
        print("LayoutLedger: Cannot save profile - addon not initialized.")
        return
    end

    local exportData = {
        version = self.EXPORT_VERSION,
        metadata = self.Export.GetMetadata(),
        savedDate = time(),
    }

    if asClassProfile then
        -- Save as full class profile (character settings + all spec settings)
        exportData.profileType = "classProfile"

        -- Get current spec info
        local currentSpecIndex = GetSpecialization()
        local currentSpecID, currentSpecName = nil, nil
        if currentSpecIndex then
            currentSpecID, currentSpecName = GetSpecializationInfo(currentSpecIndex)
        end

        -- Character settings (non-spec-specific)
        local macros = self.Export.GetMacros()
        exportData.characterSettings = {
            keybindings = self.Export.GetKeybindings(),
            uiLayout = self.Export.GetEditModeLayout(),
            characterMacros = macros.character,
            globalMacros = macros.global,
            cvars = self.Export.GetCVars(),
        }

        -- Spec settings (start with existing class profile data if any)
        exportData.specSettings = {}
        if self.db.class.specSettings then
            -- Copy existing spec settings
            for specID, specData in pairs(self.db.class.specSettings) do
                exportData.specSettings[specID] = specData
            end
        end

        -- Update current spec's data
        if currentSpecID then
            exportData.specSettings[currentSpecID] = {
                actionBars = self.Export.GetActionBars(),
                cooldownLayout = self.Export.GetCooldownLayout(),
            }
        end

        print(string.format("LayoutLedger: Class profile '%s' saved! (Includes data for %d spec(s))",
            profileName, self:CountKeys(exportData.specSettings)))
    else
        -- Save as simple profile (current settings only)
        exportData.profileType = "simple"

        exportData.actionBars = self.Export.GetActionBars()
        exportData.keybindings = self.Export.GetKeybindings()
        exportData.uiLayout = self.Export.GetEditModeLayout()
        exportData.cooldownLayout = self.Export.GetCooldownLayout()
        exportData.cvars = self.Export.GetCVars()

        local macros = self.Export.GetMacros()
        exportData.characterMacros = macros.character
        exportData.globalMacros = macros.global

        print(string.format("LayoutLedger: Profile '%s' saved!", profileName))
    end

    -- Save to database
    if not self.db.global.savedProfiles then
        self.db.global.savedProfiles = {}
    end

    self.db.global.savedProfiles[profileName] = exportData
    self:RefreshSavedProfilesUI()
end

-- Helper function to count table keys
function addon:CountKeys(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function addon:LoadProfile(profileName, setAsActive)
    if InCombatLockdown() then
        print("LayoutLedger: Cannot load profile while in combat.")
        return
    end

    if not self.db or not self.db.global or not self.db.global.savedProfiles then
        print("LayoutLedger: No saved profiles found.")
        return
    end

    local profileData = self.db.global.savedProfiles[profileName]
    if not profileData then
        print(string.format("LayoutLedger: Profile '%s' not found.", profileName))
        return
    end

    -- Save current settings for revert
    self:SaveCurrentSettings()

    local profileType = profileData.profileType or "simple"

    -- Import the profile data
    local success, err = pcall(function()
        if profileType == "classProfile" then
            -- Load class profile (character settings + current spec's action bars)
            local charSettings = profileData.characterSettings or {}

            -- Import character settings (macros first)
            if charSettings.characterMacros or charSettings.globalMacros then
                self.Import.SetMacros({
                    character = charSettings.characterMacros,
                    global = charSettings.globalMacros
                }, "Override")
            end

            if charSettings.keybindings then
                self.Import.SetKeybindings(charSettings.keybindings, "Override")
            end

            if charSettings.uiLayout then
                self.Import.SetEditModeLayout(charSettings.uiLayout, "Override")
            end

            if charSettings.cvars then
                self.Import.SetCVars(charSettings.cvars, "Override")
            end

            -- Import current spec's settings if available
            local currentSpecIndex = GetSpecialization()
            if currentSpecIndex then
                local currentSpecID = GetSpecializationInfo(currentSpecIndex)
                if currentSpecID and profileData.specSettings and profileData.specSettings[currentSpecID] then
                    local specData = profileData.specSettings[currentSpecID]

                    if specData.actionBars then
                        self.Import.SetActionBars(specData.actionBars, "Override")
                    end

                    if specData.cooldownLayout then
                        self.Import.SetCooldownLayout(specData.cooldownLayout, "Override")
                    end
                end
            end
        else
            -- Load simple profile (current settings only)
            -- Import macros FIRST so action bars can reference them
            if profileData.characterMacros or profileData.globalMacros then
                self.Import.SetMacros({
                    character = profileData.characterMacros,
                    global = profileData.globalMacros
                }, "Override")
            end

            if profileData.actionBars then
                self.Import.SetActionBars(profileData.actionBars, "Override")
            end

            if profileData.keybindings then
                self.Import.SetKeybindings(profileData.keybindings, "Override")
            end

            if profileData.uiLayout then
                self.Import.SetEditModeLayout(profileData.uiLayout, "Override")
            end

            if profileData.cooldownLayout then
                self.Import.SetCooldownLayout(profileData.cooldownLayout, "Override")
            end

            if profileData.cvars then
                self.Import.SetCVars(profileData.cvars, "Override")
            end
        end
    end)

    if success then
        -- Set as active profile if requested
        if setAsActive then
            self.db.char.activeProfileName = profileName
            local currentSpecID = select(1, GetSpecializationInfo(GetSpecialization()))
            self.db.char.lastAppliedSpecID = currentSpecID
            print(string.format("LayoutLedger: Profile '%s' loaded and set as active!", profileName))
        else
            print(string.format("LayoutLedger: Profile '%s' loaded!", profileName))
        end

        print("Some changes may require a UI reload (/reload).")
        self:UpdateRevertButton()
        self:RefreshSavedProfilesUI()
    else
        print("LayoutLedger: Failed to load profile - " .. tostring(err))
    end
end

function addon:DeleteProfile(profileName)
    if not self.db or not self.db.global or not self.db.global.savedProfiles then
        return
    end

    StaticPopupDialogs["LAYOUTLEDGER_DELETE_PROFILE"] = {
        text = string.format("Delete profile '%s'?\n\nThis cannot be undone!", profileName),
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            addon.db.global.savedProfiles[profileName] = nil
            print(string.format("LayoutLedger: Profile '%s' deleted.", profileName))
            addon:RefreshSavedProfilesUI()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_DELETE_PROFILE")
end

function addon:Export_OnClick()
    if InCombatLockdown and InCombatLockdown() then
        print("LayoutLedger: Cannot export while in combat.")
        return
    end

    if not (self.db and self.Export and self.Serialize and self.importBox) then
        print("LayoutLedger: Export failed - addon not fully initialized.")
        return
    end

    local profile = self.db.profile.export

    -- Validate that at least one item is selected
    if not (profile.actionBars or profile.keybindings or profile.uiLayout or profile.cooldownLayout or
            profile.characterMacros or profile.globalMacros or profile.cvars) then
        print("LayoutLedger: Please select at least one item to export.")
        return
    end

    -- Collect data and calculate counts
    local exportData = {
        version = self.EXPORT_VERSION,
        metadata = self.Export.GetMetadata(),
    }
    local exportSummary = {}

    if profile.actionBars then
        exportData.actionBars = self.Export.GetActionBars()
        local count = self:CountActions(exportData.actionBars)
        if count > 0 then
            table.insert(exportSummary, string.format("• %d Action Bar slots", count))
        end
    end

    if profile.keybindings then
        exportData.keybindings = self.Export.GetKeybindings()
        local count = self:CountKeybindings(exportData.keybindings)
        if count > 0 then
            table.insert(exportSummary, string.format("• %d Keybindings", count))
        end
    end

    if profile.uiLayout then
        exportData.uiLayout = self.Export.GetEditModeLayout()
        if exportData.uiLayout then
            local layoutName = type(exportData.uiLayout) == "table" and exportData.uiLayout.layoutName or "UI Layout"
            table.insert(exportSummary, "• UI Layout (" .. layoutName .. ")")
        end
    end

    if profile.cooldownLayout then
        exportData.cooldownLayout = self.Export.GetCooldownLayout()
        if exportData.cooldownLayout then
            table.insert(exportSummary, "• Cooldown Viewer Layout")
        end
    end

    if profile.cvars then
        exportData.cvars = self.Export.GetCVars()
        if exportData.cvars then
            local count = 0
            for _ in pairs(exportData.cvars) do
                count = count + 1
            end
            if count > 0 then
                table.insert(exportSummary, string.format("• %d CVar(s)", count))
            end
        end
    end

    if profile.characterMacros or profile.globalMacros then
        local macros = self.Export.GetMacros()
        print("LayoutLedger: DEBUG Export - Got macros, character count:", #macros.character, "global count:", #macros.global)

        if profile.characterMacros then
            print("LayoutLedger: DEBUG Export - Character macros checkbox is checked")
            if #macros.character > 0 then
                exportData.characterMacros = macros.character
                table.insert(exportSummary, string.format("• %d Character Macros", #macros.character))
            else
                print("LayoutLedger: DEBUG Export - No character macros to export")
            end
        end

        if profile.globalMacros then
            print("LayoutLedger: DEBUG Export - Global macros checkbox is checked")
            if #macros.global > 0 then
                exportData.globalMacros = macros.global
                table.insert(exportSummary, string.format("• %d Global Macros", #macros.global))
            else
                print("LayoutLedger: DEBUG Export - No global macros to export")
            end
        end
    end

    -- Debug: Show what's in the export data
    print("LayoutLedger: DEBUG Export - Final export data contains:")
    print("  version:", exportData.version or "nil")
    print("  metadata:", exportData.metadata and "yes" or "no")
    print("  actionBars:", exportData.actionBars and "yes" or "no")
    print("  keybindings:", exportData.keybindings and "yes" or "no")
    print("  uiLayout:", exportData.uiLayout and "yes (length: " .. #tostring(exportData.uiLayout) .. ")" or "no")
    print("  cooldownLayout:", exportData.cooldownLayout and "yes (" .. tostring(exportData.cooldownLayout) .. ")" or "no")
    print("  cvars:", exportData.cvars and "yes" or "no")
    print("  characterMacros:", exportData.characterMacros and "yes" or "no")
    print("  globalMacros:", exportData.globalMacros and "yes" or "no")

    -- Show confirmation dialog
    local summaryText = "This will export:\n\n" .. table.concat(exportSummary, "\n")
    if #exportSummary == 0 then
        print("LayoutLedger: Nothing to export. No data found for selected items.")
        return
    end

    local addon = self
    StaticPopupDialogs["LAYOUTLEDGER_EXPORT_CONFIRM"] = {
        text = summaryText,
        button1 = "Export",
        button2 = "Cancel",
        OnAccept = function()
            -- Perform the actual export
            local success, result = pcall(function()
                return addon.Serialize.Encode(exportData)
            end)

            if success then
                addon.importBox:SetText(result)
                addon.importBox:SetFocus()
                addon.importBox:HighlightText()
                print("LayoutLedger: Export complete! Text is highlighted - press Ctrl+C to copy.")
            else
                print("LayoutLedger: Export failed - " .. tostring(result))
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_EXPORT_CONFIRM")
end

function addon:ExportClassProfile_OnClick()
    if InCombatLockdown and InCombatLockdown() then
        print("LayoutLedger: Cannot export while in combat.")
        return
    end

    if not (self.db and self.Serialize and self.importBox) then
        print("LayoutLedger: Export failed - addon not fully initialized.")
        return
    end

    -- Check if there's any class profile data to export
    local classData = self.db.class
    if not classData then
        print("LayoutLedger: No class profile data found.")
        return
    end

    -- Collect class profile data
    local exportData = {
        version = self.EXPORT_VERSION,
        metadata = self.Export.GetMetadata(),
        exportType = "classProfile",
        classProfile = {
            characterSettings = classData.characterSettings or {},
            specSettings = classData.specSettings or {}
        }
    }

    -- Build summary of what's being exported
    local exportSummary = {}
    local specCount = 0
    local totalActionSlots = 0
    local cooldownSpecCount = 0

    -- Count spec-specific settings
    if classData.specSettings then
        for specID, specData in pairs(classData.specSettings) do
            if specData.actionBars then
                specCount = specCount + 1
                totalActionSlots = totalActionSlots + self:CountActions(specData.actionBars)
            end
            if specData.cooldownLayout then
                cooldownSpecCount = cooldownSpecCount + 1
            end
        end
    end

    if specCount > 0 then
        table.insert(exportSummary, string.format("• Action bars for %d spec(s) (%d slots total)",
            specCount, totalActionSlots))
    end
    if cooldownSpecCount > 0 then
        table.insert(exportSummary, string.format("• Cooldown layouts for %d spec(s)", cooldownSpecCount))
    end

    -- Count character settings
    local charSettings = classData.characterSettings
    if charSettings then
        if charSettings.keybindings then
            local count = self:CountKeybindings(charSettings.keybindings)
            if count > 0 then
                table.insert(exportSummary, string.format("• %d Keybindings", count))
            end
        end
        if charSettings.uiLayout then
            table.insert(exportSummary, "• UI Layout")
        end
        if charSettings.characterMacros and #charSettings.characterMacros > 0 then
            table.insert(exportSummary, string.format("• %d Character Macros", #charSettings.characterMacros))
        end
        if charSettings.globalMacros and #charSettings.globalMacros > 0 then
            table.insert(exportSummary, string.format("• %d Global Macros", #charSettings.globalMacros))
        end
        if charSettings.cvars then
            local count = 0
            for _ in pairs(charSettings.cvars) do
                count = count + 1
            end
            if count > 0 then
                table.insert(exportSummary, string.format("• %d CVar(s)", count))
            end
        end
    end

    if #exportSummary == 0 then
        print("LayoutLedger: No class profile data to export. Use 'Update Class Profile' first.")
        return
    end

    -- Show confirmation dialog
    local summaryText = "This will export your Class Profile:\n\n" .. table.concat(exportSummary, "\n")
    local addon = self
    StaticPopupDialogs["LAYOUTLEDGER_EXPORT_CLASS_PROFILE_CONFIRM"] = {
        text = summaryText,
        button1 = "Export",
        button2 = "Cancel",
        OnAccept = function()
            print("LayoutLedger: DEBUG Export - Starting class profile export")
            print("LayoutLedger: DEBUG Export - version:", exportData.version or "nil")
            print("LayoutLedger: DEBUG Export - exportType:", exportData.exportType)

            local success, result = pcall(function()
                return addon.Serialize.Encode(exportData)
            end)

            if success then
                print("LayoutLedger: DEBUG Export - Encode success, string length:", #result)
                addon.importBox:SetText(result)
                addon.importBox:SetFocus()
                addon.importBox:HighlightText()
                print("LayoutLedger: Class Profile export complete! Text is highlighted - press Ctrl+C to copy.")
            else
                print("LayoutLedger: Export failed - " .. tostring(result))
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_EXPORT_CLASS_PROFILE_CONFIRM")
end

function addon:Copy_OnClick()
    -- Highlight the export text for easy copying
    if not self.importBox then
        print("LayoutLedger: Import box not initialized.")
        return
    end

    local text = self.importBox:GetText()
    if text and text ~= "" then
        self.importBox:SetFocus()
        self.importBox:HighlightText()
        print("LayoutLedger: Text highlighted - press Ctrl+C to copy.")
    else
        print("LayoutLedger: Nothing to copy. Export something first!")
    end
end

function addon:Paste_OnClick()
    -- Focus the import box so user can paste
    if not self.importBox then
        print("LayoutLedger: Import box not initialized.")
        return
    end

    -- Clear the box and focus it
    self.importBox:SetText("")
    self.importBox:SetFocus()
    self.importBox:SetCursorPosition(0)
    print("LayoutLedger: Import box focused - press Ctrl+V to paste.")
end

function addon:UpdateClassProfile_OnClick()
    -- Update the class profile with current character settings and spec-specific action bars
    if InCombatLockdown and InCombatLockdown() then
        print("LayoutLedger: Cannot update class profile while in combat.")
        return
    end

    if not (self.db and self.Export) then
        print("LayoutLedger: Update failed - addon not fully initialized.")
        return
    end

    -- Get current spec info
    local currentSpecIndex = GetSpecialization()
    if not currentSpecIndex then
        print("LayoutLedger: Cannot determine current specialization.")
        return
    end

    local currentSpecID, currentSpecName = GetSpecializationInfo(currentSpecIndex)
    if not currentSpecID then
        print("LayoutLedger: Failed to get specialization info.")
        return
    end

    -- Collect current settings
    local keybindings = self.Export.GetKeybindings()
    local uiLayout = self.Export.GetEditModeLayout()
    local macros = self.Export.GetMacros()
    local actionBars = self.Export.GetActionBars()
    local cooldownLayout = self.Export.GetCooldownLayout()
    local cvars = self.Export.GetCVars()

    -- Save character settings (non-spec-specific)
    self.db.class.characterSettings = {
        keybindings = keybindings,
        uiLayout = uiLayout,
        characterMacros = macros.character,
        globalMacros = macros.global,
        cvars = cvars,
    }

    -- Save spec-specific settings for current spec
    if not self.db.class.specSettings then
        self.db.class.specSettings = {}
    end
    self.db.class.specSettings[currentSpecID] = {
        actionBars = actionBars,
        cooldownLayout = cooldownLayout,
    }

    local className = select(2, UnitClass("player"))
    print(string.format("LayoutLedger: Class profile updated for %s (%s spec)!", className, currentSpecName))
    print("All " .. className .. " characters can now import these settings.")
end

function addon:UpdateFromClassProfile_OnClick()
    -- Import settings from the class profile
    if InCombatLockdown and InCombatLockdown() then
        print("LayoutLedger: Cannot update from class profile while in combat.")
        return
    end

    if not (self.db and self.Import) then
        print("LayoutLedger: Update failed - addon not fully initialized.")
        return
    end

    -- Check if class profile has any data
    local hasCharSettings = self.db.class.characterSettings and
        (self.db.class.characterSettings.keybindings or
         self.db.class.characterSettings.uiLayout or
         self.db.class.characterSettings.characterMacros or
         self.db.class.characterSettings.globalMacros or
         self.db.class.characterSettings.cvars)

    local hasSpecSettings = false
    local currentSpecID = nil
    local currentSpecName = nil

    local currentSpecIndex = GetSpecialization()
    if currentSpecIndex then
        currentSpecID, currentSpecName = GetSpecializationInfo(currentSpecIndex)
        if currentSpecID and self.db.class.specSettings and self.db.class.specSettings[currentSpecID] then
            hasSpecSettings = true
        end
    end

    if not hasCharSettings and not hasSpecSettings then
        print("LayoutLedger: No class profile data found. Use 'Update Class Profile' first.")
        return
    end

    -- Save current settings for revert
    self:SaveCurrentSettings()

    local success, err = pcall(function()
        -- Import character settings
        if hasCharSettings then
            local settings = self.db.class.characterSettings
            if settings.keybindings then
                self.Import.SetKeybindings(settings.keybindings, "Override")
            end
            if settings.uiLayout then
                self.Import.SetEditModeLayout(settings.uiLayout, "Override")
            end
            if settings.characterMacros or settings.globalMacros then
                self.Import.SetMacros({
                    character = settings.characterMacros,
                    global = settings.globalMacros
                }, "Override")
            end
            if settings.cvars then
                self.Import.SetCVars(settings.cvars, "Override")
            end
        end

        -- Import spec-specific settings if available for current spec
        if hasSpecSettings then
            local specData = self.db.class.specSettings[currentSpecID]
            if specData.actionBars then
                self.Import.SetActionBars(specData.actionBars, "Override")
            end
            if specData.cooldownLayout then
                self.Import.SetCooldownLayout(specData.cooldownLayout, "Override")
            end
        end
    end)

    if success then
        local message = "LayoutLedger: Updated from class profile!"
        if hasSpecSettings then
            message = message .. " (Including " .. currentSpecName .. " action bars)"
        elseif currentSpecID then
            message = message .. " (No action bars saved for " .. currentSpecName .. " spec)"
        end
        print(message)
        print("Some changes may require a UI reload (/reload).")
        self:UpdateRevertButton()
    else
        print("LayoutLedger: Update from class profile failed - " .. tostring(err))
    end
end

function addon:ImportClassProfile(data)
    -- Import a class profile export directly into the class namespace
    if not data or not data.classProfile then
        print("LayoutLedger: Invalid class profile data.")
        return
    end

    -- Validate class match
    local _, currentClassName = UnitClass("player")
    local sourceClassName = data.metadata and data.metadata.className

    if sourceClassName and sourceClassName ~= currentClassName then
        print(string.format("LayoutLedger: Class mismatch! This profile is for %s, but you are %s.",
            sourceClassName, currentClassName))
        return
    end

    -- Analyze what's available in the class profile
    local classProfile = data.classProfile
    local availability = {}

    -- Check spec-specific settings (action bars and cooldown layouts)
    local specCount = 0
    local totalActionSlots = 0
    local cooldownSpecCount = 0
    if classProfile.specSettings then
        for specID, specData in pairs(classProfile.specSettings) do
            if specData.actionBars then
                specCount = specCount + 1
                totalActionSlots = totalActionSlots + self:CountActions(specData.actionBars)
            end
            if specData.cooldownLayout then
                cooldownSpecCount = cooldownSpecCount + 1
            end
        end
    end
    if specCount > 0 then
        availability.specActionBars = {
            available = true,
            count = totalActionSlots,
            specCount = specCount,
            label = string.format("Spec Action Bars (%d specs, %d slots)", specCount, totalActionSlots),
            recommendation = "Recommended: Import macros first to avoid missing references"
        }
    end
    if cooldownSpecCount > 0 then
        availability.specCooldownLayouts = {
            available = true,
            count = cooldownSpecCount,
            label = string.format("Spec Cooldown Layouts (%d specs)", cooldownSpecCount),
            recommendation = nil
        }
    end

    -- Check character settings
    local charSettings = classProfile.characterSettings or {}

    if charSettings.keybindings then
        local count = self:CountKeybindings(charSettings.keybindings)
        if count > 0 then
            availability.keybindings = {
                available = true,
                count = count,
                label = string.format("Keybindings (%d)", count),
                recommendation = nil
            }
        end
    end

    if charSettings.uiLayout then
        availability.uiLayout = {
            available = true,
            count = 1,
            label = "UI Layout",
            recommendation = nil
        }
    end

    if charSettings.characterMacros and #charSettings.characterMacros > 0 then
        availability.characterMacros = {
            available = true,
            count = #charSettings.characterMacros,
            label = string.format("Character Macros (%d)", #charSettings.characterMacros),
            recommendation = "Import before action bars"
        }
    end

    if charSettings.globalMacros and #charSettings.globalMacros > 0 then
        availability.globalMacros = {
            available = true,
            count = #charSettings.globalMacros,
            label = string.format("Global Macros (%d)", #charSettings.globalMacros),
            recommendation = "Import before action bars"
        }
    end

    if charSettings.cvars then
        local count = 0
        for _ in pairs(charSettings.cvars) do
            count = count + 1
        end
        if count > 0 then
            availability.cvars = {
                available = true,
                count = count,
                label = string.format("CVars (%d)", count),
                recommendation = nil
            }
        end
    end

    if not next(availability) then
        print("LayoutLedger: Class profile has no data to import.")
        return
    end

    -- Show selective import dialog
    self:ShowClassProfileImportDialog(data, availability)
end

function addon:ShowClassProfileImportDialog(data, availability)
    -- Store pending import data
    self.pendingClassProfileData = data
    self.pendingClassProfileSelections = {}

    -- Create a simple frame for the dialog
    local frame = CreateFrame("Frame", "LayoutLedgerClassProfileImportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(450, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")

    -- Set backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)

    -- Title
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Import Class Profile")

    -- Instruction
    local instruction = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instruction:SetPoint("TOP", title, "BOTTOM", 0, -15)
    instruction:SetText("Select what to import:")

    -- Create scroll frame for checkboxes
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(400, 280)
    scrollFrame:SetPoint("TOP", instruction, "BOTTOM", 0, -10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(380, 280)
    scrollFrame:SetScrollChild(scrollChild)

    -- Populate checkboxes
    local yOffset = -10
    local order = {"globalMacros", "characterMacros", "specActionBars", "specCooldownLayouts", "uiLayout", "keybindings", "cvars"}

    for _, key in ipairs(order) do
        local info = availability[key]
        if info and info.available then
            -- Create checkbox
            local checkbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", 10, yOffset)
            checkbox:SetChecked(true) -- Default to checked

            -- Store selection
            self.pendingClassProfileSelections[key] = true

            checkbox:SetScript("OnClick", function(cb)
                self.pendingClassProfileSelections[key] = cb:GetChecked()
            end)

            -- Create label
            local label = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
            label:SetText(info.label)

            yOffset = yOffset - 30

            -- Add recommendation if present
            if info.recommendation then
                local recLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                recLabel:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 25, -2)
                recLabel:SetText("|cFFFFCC00Note:|r " .. info.recommendation)
                recLabel:SetWidth(340)
                recLabel:SetJustifyH("LEFT")
                yOffset = yOffset - 20
            end

            yOffset = yOffset - 5
        end
    end

    -- Import button
    local importButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    importButton:SetSize(140, 30)
    importButton:SetPoint("BOTTOM", -75, 20)
    importButton:SetText("Import Selected")
    importButton:SetScript("OnClick", function()
        self:ExecuteClassProfileImport()
        frame:Hide()
    end)

    -- Cancel button
    local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelButton:SetSize(140, 30)
    cancelButton:SetPoint("LEFT", importButton, "RIGHT", 10, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 0, 0)

    -- Show frame
    frame:Show()

    -- Clean up on hide
    frame:SetScript("OnHide", function(f)
        f:SetParent(nil)
        f:Hide()
    end)
end

function addon:ExecuteClassProfileImport()
    local data = self.pendingClassProfileData
    local selections = self.pendingClassProfileSelections

    if not data or not data.classProfile then
        print("LayoutLedger: Import failed - no data")
        return
    end

    local classProfile = data.classProfile
    local imported = {}

    -- Import selected items
    if (selections.specActionBars or selections.specCooldownLayouts) and classProfile.specSettings then
        self.db.class.specSettings = classProfile.specSettings
        if selections.specActionBars then
            table.insert(imported, "spec action bars")
        end
        if selections.specCooldownLayouts then
            table.insert(imported, "spec cooldown layouts")
        end
    end

    if selections.keybindings and classProfile.characterSettings and classProfile.characterSettings.keybindings then
        if not self.db.class.characterSettings then
            self.db.class.characterSettings = {}
        end
        self.db.class.characterSettings.keybindings = classProfile.characterSettings.keybindings
        table.insert(imported, "keybindings")
    end

    if selections.uiLayout and classProfile.characterSettings and classProfile.characterSettings.uiLayout then
        if not self.db.class.characterSettings then
            self.db.class.characterSettings = {}
        end
        self.db.class.characterSettings.uiLayout = classProfile.characterSettings.uiLayout
        table.insert(imported, "UI layout")
    end

    if selections.characterMacros and classProfile.characterSettings and classProfile.characterSettings.characterMacros then
        if not self.db.class.characterSettings then
            self.db.class.characterSettings = {}
        end
        self.db.class.characterSettings.characterMacros = classProfile.characterSettings.characterMacros
        table.insert(imported, "character macros")
    end

    if selections.globalMacros and classProfile.characterSettings and classProfile.characterSettings.globalMacros then
        if not self.db.class.characterSettings then
            self.db.class.characterSettings = {}
        end
        self.db.class.characterSettings.globalMacros = classProfile.characterSettings.globalMacros
        table.insert(imported, "global macros")
    end

    if selections.cvars and classProfile.characterSettings and classProfile.characterSettings.cvars then
        if not self.db.class.characterSettings then
            self.db.class.characterSettings = {}
        end
        self.db.class.characterSettings.cvars = classProfile.characterSettings.cvars
        table.insert(imported, "CVars")
    end

    if #imported > 0 then
        print("LayoutLedger: Imported " .. table.concat(imported, ", ") .. " to class profile.")

        -- Automatically apply the imported settings to this character
        print("LayoutLedger: Applying imported settings...")

        -- Save current settings for revert
        self:SaveCurrentSettings()

        -- Get current spec for applying spec-specific settings
        local currentSpecIndex = GetSpecialization()
        local currentSpecID, currentSpecName = nil, nil
        if currentSpecIndex then
            currentSpecID, currentSpecName = GetSpecializationInfo(currentSpecIndex)
        end

        -- Apply the imported settings
        local success, err = pcall(function()
            -- Apply character settings
            if selections.keybindings and self.db.class.characterSettings.keybindings then
                self.Import.SetKeybindings(self.db.class.characterSettings.keybindings, "Override")
            end
            if selections.uiLayout and self.db.class.characterSettings.uiLayout then
                self.Import.SetEditModeLayout(self.db.class.characterSettings.uiLayout, "Override")
            end
            if (selections.characterMacros or selections.globalMacros) then
                self.Import.SetMacros({
                    character = self.db.class.characterSettings.characterMacros,
                    global = self.db.class.characterSettings.globalMacros
                }, "Override")
            end
            if selections.cvars and self.db.class.characterSettings.cvars then
                self.Import.SetCVars(self.db.class.characterSettings.cvars, "Override")
            end

            -- Apply spec-specific settings if we're in the right spec
            if currentSpecID and self.db.class.specSettings[currentSpecID] then
                local specData = self.db.class.specSettings[currentSpecID]
                if selections.specActionBars and specData.actionBars then
                    self.Import.SetActionBars(specData.actionBars, "Override")
                end
                if selections.specCooldownLayouts and specData.cooldownLayout then
                    self.Import.SetCooldownLayout(specData.cooldownLayout, "Override")
                end
            end
        end)

        if success then
            print("LayoutLedger: Class profile imported and applied successfully!")
            print("Some changes may require a UI reload (/reload).")
            self:UpdateRevertButton()
        else
            print("LayoutLedger: Import succeeded but apply failed - " .. tostring(err))
            print("You can use 'Update from Class Profile' button to try applying again.")
        end
    else
        print("LayoutLedger: Nothing selected to import.")
    end

    -- Clean up
    self.pendingClassProfileData = nil
    self.pendingClassProfileSelections = nil
end

function addon:MigrateImportData(data)
    -- Use the new migration system from Migrations.lua
    local migratedData, error = self.Migrations.MigrateImportData(data)

    if error then
        print("LayoutLedger: Migration error:", error)
        return nil
    end

    return migratedData
end

function addon:SaveCurrentSettings()
    -- Save current settings before importing new ones, for the Revert feature
    -- Saves as a visible backup profile in Saved Profiles
    if not self.db then return end

    -- Generate backup profile name: "CharacterName-BAK"
    local characterName = UnitName("player") or "Unknown"
    local backupProfileName = characterName .. "-BAK"

    -- Collect all current settings
    local exportData = {
        version = self.EXPORT_VERSION,
        metadata = nil, -- Will be set below
        savedDate = time(),
    }

    -- Only save if export functions are available
    if self.Export then
        exportData.metadata = self.Export.GetMetadata()
        exportData.actionBars = self.Export.GetActionBars()
        exportData.keybindings = self.Export.GetKeybindings()
        exportData.uiLayout = self.Export.GetEditModeLayout()
        exportData.cooldownLayout = self.Export.GetCooldownLayout()
        exportData.cvars = self.Export.GetCVars()

        local macros = self.Export.GetMacros()
        exportData.characterMacros = macros.character
        exportData.globalMacros = macros.global
    end

    -- Save to global saved profiles (overwrites previous backup)
    if not self.db.global.savedProfiles then
        self.db.global.savedProfiles = {}
    end

    self.db.global.savedProfiles[backupProfileName] = exportData

    print(string.format("LayoutLedger: Backup saved as '%s'", backupProfileName))

    -- Also keep a reference in profile for quick revert button check
    self.db.profile.lastBackupProfileName = backupProfileName
end

function addon:Import_OnClick()
    if InCombatLockdown and InCombatLockdown() then
        print("LayoutLedger: Cannot import while in combat.")
        return
    end

    if not (self.importBox and self.Serialize and self.Import) then
        print("LayoutLedger: Import failed - addon not fully initialized.")
        return
    end

    local encodedData = self.importBox:GetText()
    if not encodedData or encodedData == "" then
        print("LayoutLedger: Please paste an import string first.")
        return
    end

    local data = self.Serialize.Decode(encodedData)
    if not data then
        print("LayoutLedger: Invalid import string.")
        return
    end

    -- Migrate legacy formats to current version
    data = self:MigrateImportData(data)
    if not data then
        print("LayoutLedger: Failed to migrate import data.")
        return
    end

    -- Check if this is a class profile export
    if data.exportType == "classProfile" then
        self:ImportClassProfile(data)
        return
    end

    -- Check if this is a new format import with metadata
    if data.metadata then
        -- New smart import flow
        local applicability = self:AnalyzeImportApplicability(data)
        self:ShowSmartImportDialog(data, applicability)
    else
        -- Legacy import without metadata - fall back to old flow
        print("LayoutLedger: Legacy import string detected (no metadata).")
        self:LegacyImport(data)
    end
end

function addon:LegacyImport(data)
    -- Save current settings before importing
    self:SaveCurrentSettings()

    local canMerge = data.characterMacros or data.globalMacros or data.actionBars
    local addon = self

    StaticPopupDialogs["LAYOUTLEDGER_IMPORT_CONFIRM"] = {
        text = "How would you like to import?",
        button1 = "Override",
        button2 = "Merge",
        button3 = "Cancel",
        OnAccept = function()
            local success, err = pcall(function()
                -- Import macros FIRST so action bars can reference them
                addon.Import.SetMacros({ character = data.characterMacros, global = data.globalMacros }, "Override")
                addon.Import.SetActionBars(data.actionBars, "Override")
                addon.Import.SetKeybindings(data.keybindings, "Override")
                addon.Import.SetEditModeLayout(data.uiLayout, "Override")
                addon.Import.SetCooldownLayout(data.cooldownLayout, "Override")
                addon.Import.SetCVars(data.cvars, "Override")
            end)
            if success then
                print("LayoutLedger: Import complete! Some changes may require a UI reload (/reload).")
                addon:UpdateRevertButton()
            else
                print("LayoutLedger: Import failed - " .. tostring(err))
            end
        end,
        OnAlt = function()
            local success, err = pcall(function()
                -- Import macros FIRST so action bars can reference them
                if data.characterMacros or data.globalMacros then
                    addon.Import.SetMacros({ character = data.characterMacros, global = data.globalMacros }, "Merge")
                end
                if data.actionBars then
                    addon.Import.SetActionBars(data.actionBars, "Merge")
                end
            end)
            if success then
                print("LayoutLedger: Merge complete! Some changes may require a UI reload (/reload).")
                addon:UpdateRevertButton()
            else
                print("LayoutLedger: Merge failed - " .. tostring(err))
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

function addon:Revert_OnClick()
    if InCombatLockdown and InCombatLockdown() then
        print("LayoutLedger: Cannot revert while in combat.")
        return
    end

    if not (self.db and self.Import) then
        print("LayoutLedger: Revert failed - addon not fully initialized.")
        return
    end

    -- Get backup profile name
    local backupProfileName = self.db.profile.lastBackupProfileName
    if not backupProfileName then
        -- Fallback to default name
        local characterName = UnitName("player") or "Unknown"
        backupProfileName = characterName .. "-BAK"
    end

    -- Load backup profile
    local data = self.db.global.savedProfiles and self.db.global.savedProfiles[backupProfileName]

    if not data then
        print("LayoutLedger: No backup profile found to revert to.")
        return
    end

    local success, err = pcall(function()
        -- Import macros FIRST so action bars can reference them
        if data.characterMacros or data.globalMacros then
            self.Import.SetMacros({
                character = data.characterMacros,
                global = data.globalMacros
            }, "Override")
        end

        if data.actionBars then
            self.Import.SetActionBars(data.actionBars, "Override")
        end

        if data.keybindings then
            self.Import.SetKeybindings(data.keybindings, "Override")
        end

        if data.uiLayout then
            self.Import.SetEditModeLayout(data.uiLayout, "Override")
        end

        if data.cooldownLayout then
            self.Import.SetCooldownLayout(data.cooldownLayout, "Override")
        end

        if data.cvars then
            self.Import.SetCVars(data.cvars, "Override")
        end
    end)

    if success then
        -- Delete the backup profile after successful revert
        self.db.global.savedProfiles[backupProfileName] = nil
        self.db.profile.lastBackupProfileName = nil
        print(string.format("LayoutLedger: Reverted to backup '%s'!", backupProfileName))
        print("Some changes may require a UI reload (/reload).")
        print("Note: Backup profile has been deleted after restore.")
        self:UpdateRevertButton()
    else
        print("LayoutLedger: Revert failed - " .. tostring(err))
    end
end

function addon:ShowClassProfileFrame()
    local frame = _G["LayoutLedgerClassProfileFrame"]
    if not frame then
        print("LayoutLedger: Class Profile frame not found!")
        return
    end

    frame:Show()
end

function addon:RefreshClassProfileUI()
    local frame = _G["LayoutLedgerClassProfileFrame"]
    if not frame then
        return
    end

    -- Build info text showing current class profile status
    local infoText = ""
    local _, className = UnitClass("player")

    -- Show spec action bar status
    if self.db and self.db.class and self.db.class.specSettings then
        local specCount = 0
        local specList = {}

        local cooldownList = {}
        local cooldownCount = 0

        for specID, specData in pairs(self.db.class.specSettings) do
            local _, specName = GetSpecializationInfoByID(specID)
            if specData.actionBars then
                specCount = specCount + 1
                if specName then
                    table.insert(specList, specName)
                end
            end
            if specData.cooldownLayout then
                cooldownCount = cooldownCount + 1
                if specName then
                    table.insert(cooldownList, specName)
                end
            end
        end

        if specCount > 0 then
            table.sort(specList)
            infoText = infoText .. "Saved Action Bars:\n• " .. table.concat(specList, "\n• ") .. "\n\n"
        else
            infoText = infoText .. "No saved action bars yet.\n\n"
        end

        if cooldownCount > 0 then
            table.sort(cooldownList)
            infoText = infoText .. "Saved Cooldown Layouts:\n• " .. table.concat(cooldownList, "\n• ") .. "\n\n"
        end
    end

    -- Show other saved data
    if self.db and self.db.class and self.db.class.characterSettings then
        local settings = self.db.class.characterSettings
        local hasData = false

        if settings.keybindings then
            local count = self:CountKeybindings(settings.keybindings)
            if count > 0 then
                infoText = infoText .. "• " .. count .. " Keybindings\n"
                hasData = true
            end
        end
        if settings.uiLayout then
            infoText = infoText .. "• UI Layout\n"
            hasData = true
        end
        if settings.characterMacros and #settings.characterMacros > 0 then
            infoText = infoText .. "• " .. #settings.characterMacros .. " Character Macros\n"
            hasData = true
        end
        if settings.globalMacros and #settings.globalMacros > 0 then
            infoText = infoText .. "• " .. #settings.globalMacros .. " Global Macros\n"
            hasData = true
        end
        if settings.cvars then
            local count = 0
            for _ in pairs(settings.cvars) do
                count = count + 1
            end
            if count > 0 then
                infoText = infoText .. "• " .. count .. " CVar(s)\n"
                hasData = true
            end
        end

        if not hasData then
            infoText = infoText .. "No other settings saved."
        end
    end

    -- Update info text
    local infoLabel = _G["LayoutLedgerClassProfileFrameInfo"]
    if infoLabel then
        infoLabel:SetText(infoText)
    end

    -- Update checkbox state
    local autoSaveCheck = _G["LayoutLedgerClassProfileFrameAutoSaveCheck"]
    if autoSaveCheck and self.db then
        autoSaveCheck:SetChecked(self.db.char.autoSaveSpecBars)
        if autoSaveCheck.Text then
            autoSaveCheck.Text:SetText("Keep action bars synced on spec change")
        end
    end
end

function addon:ShowSmartImportDialog(data, applicability)
    local frame = _G["LayoutLedgerSmartImportFrame"]
    if not frame then
        print("LayoutLedger: Smart import dialog not found!")
        return
    end

    -- Store data for later use
    self.pendingImportData = data
    self.pendingImportApplicability = applicability
    self.pendingImportSelections = {}

    -- Update source info text
    local sourceInfo = _G["LayoutLedgerSmartImportFrameSourceInfo"]
    if sourceInfo and data.metadata then
        local meta = data.metadata
        local infoText = string.format("%s @ %s\n%s (Level %d)",
            meta.characterName or "Unknown",
            meta.realmName or "Unknown",
            meta.className or "Unknown",
            meta.characterLevel or 0)

        if meta.specName then
            infoText = infoText .. " - " .. meta.specName
        end

        sourceInfo:SetText(infoText)
    end

    -- Populate the scroll frame with import options
    self:PopulateImportOptions(applicability)

    -- Show the dialog
    frame:Show()
end

function addon:PopulateImportOptions(applicability)
    local scrollChild = _G["LayoutLedgerSmartImportFrameScrollFrameScrollChild"]
    if not scrollChild then
        print("LayoutLedger: Error - ScrollChild frame not found!")
        return
    end

    -- Set scroll child width to match parent scroll frame width
    local scrollFrame = scrollChild:GetParent()
    if scrollFrame then
        local scrollWidth = scrollFrame:GetWidth()
        if scrollWidth and scrollWidth > 0 then
            scrollChild:SetWidth(scrollWidth - 20) -- Account for scrollbar
        end
    end

    -- Clear existing children
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Debug: Check if applicability has data
    if not applicability then
        print("LayoutLedger: DEBUG - applicability is nil!")
        return
    end

    local yOffset = -10
    local order = {"globalMacros", "characterMacros", "actionBars", "uiLayout", "cooldownLayout", "keybindings", "cvars"}
    local labels = {
        globalMacros = "Global Macros",
        characterMacros = "Character Macros",
        actionBars = "Action Bars",
        uiLayout = "UI Layout",
        cooldownLayout = "Cooldown Viewer Layout",
        keybindings = "Keybindings",
        cvars = "CVars",
    }

    local itemCount = 0
    for _, key in ipairs(order) do
        local info = applicability[key]
        -- Debug logging
        print(string.format("LayoutLedger: DEBUG - %s: available=%s, info=%s",
            key, tostring(info and info.available), tostring(info ~= nil)))

        if info and info.available then
            itemCount = itemCount + 1
            -- Create checkbox
            local checkbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", 30, yOffset)
            checkbox:SetChecked(info.applicable)

            -- Store selection
            self.pendingImportSelections[key] = info.applicable

            checkbox:SetScript("OnClick", function(self)
                addon.pendingImportSelections[key] = self:GetChecked()
            end)

            -- Create label (auto-sizing based on text)
            local label = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
            label:SetPoint("RIGHT", scrollChild, "RIGHT", -10, 0) -- Prevent text overflow
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            local labelText = labels[key]
            if info.count and info.count > 0 then
                labelText = labelText .. string.format(" (%d)", info.count)
            end
            label:SetText(labelText)

            -- Create scope indicator
            local scopeLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            scopeLabel:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 25, -5)
            scopeLabel:SetText(info.scope .. "-wide")
            scopeLabel:SetTextColor(0.7, 0.7, 0.7)

            yOffset = yOffset - 25

            -- Create warning if present
            if info.warning then
                local warningLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                warningLabel:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", 0, -3)
                warningLabel:SetPoint("RIGHT", scrollChild, "RIGHT", -10, 0) -- Dynamic width
                warningLabel:SetJustifyH("LEFT")
                warningLabel:SetWordWrap(true) -- Allow text wrapping
                warningLabel:SetText("⚠ " .. info.warning)
                warningLabel:SetTextColor(1, 0.5, 0)

                -- Calculate actual height needed for wrapped text
                local textHeight = warningLabel:GetStringHeight()
                yOffset = yOffset - textHeight - 10
            else
                yOffset = yOffset - 10
            end
        end
    end

    -- Debug: Show if no items were found
    if itemCount == 0 then
        print("LayoutLedger: DEBUG - No available items found to import!")
        -- Show a message in the dialog
        local noItemsLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        noItemsLabel:SetPoint("TOP", 0, -20)
        noItemsLabel:SetText("No data available to import.\nThe export may be empty or corrupted.")
        noItemsLabel:SetTextColor(1, 0.3, 0.3)
    end

    -- Adjust scroll child height
    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

function addon:SmartImport_OnClick()
    if InCombatLockdown and InCombatLockdown() then
        print("LayoutLedger: Cannot import while in combat.")
        return
    end

    if not self.pendingImportData or not self.pendingImportSelections then
        print("LayoutLedger: No import data available.")
        return
    end

    local data = self.pendingImportData
    local selections = self.pendingImportSelections

    -- Save current settings before importing
    self:SaveCurrentSettings()

    -- Perform selected imports (IMPORTANT: Macros must be imported before action bars!)
    local success, err = pcall(function()
        -- Import macros FIRST so action bars can reference them by name
        if (selections.characterMacros or selections.globalMacros) then
            print("LayoutLedger: DEBUG SmartImport - Macro import requested")
            print("  selections.characterMacros:", selections.characterMacros and "yes" or "no")
            print("  selections.globalMacros:", selections.globalMacros and "yes" or "no")
            print("  data.characterMacros:", data.characterMacros and (#data.characterMacros .. " macros") or "nil")
            print("  data.globalMacros:", data.globalMacros and (#data.globalMacros .. " macros") or "nil")

            local macros = {}
            if selections.characterMacros and data.characterMacros then
                macros.character = data.characterMacros
            end
            if selections.globalMacros and data.globalMacros then
                macros.global = data.globalMacros
            end
            self.Import.SetMacros(macros, "Override")
        end

        -- Import action bars AFTER macros exist
        if selections.actionBars and data.actionBars then
            self.Import.SetActionBars(data.actionBars, "Override")
        end

        -- Import other settings (order doesn't matter)
        if selections.keybindings and data.keybindings then
            print("LayoutLedger: DEBUG SmartImport - Importing keybindings")
            self.Import.SetKeybindings(data.keybindings, "Override")
        end
        if selections.uiLayout and data.uiLayout then
            print("LayoutLedger: DEBUG SmartImport - Importing UI layout")
            print("  uiLayout string length:", #data.uiLayout)
            self.Import.SetEditModeLayout(data.uiLayout, "Override")
        end
        if selections.cooldownLayout and data.cooldownLayout then
            print("LayoutLedger: DEBUG SmartImport - Importing Cooldown Viewer layout")
            self.Import.SetCooldownLayout(data.cooldownLayout, "Override")
        end
        if selections.cvars and data.cvars then
            print("LayoutLedger: DEBUG SmartImport - Importing CVars")
            self.Import.SetCVars(data.cvars, "Override")
        end
    end)

    -- Hide the dialog
    local frame = _G["LayoutLedgerSmartImportFrame"]
    if frame then
        frame:Hide()
    end

    -- Clean up pending data
    self.pendingImportData = nil
    self.pendingImportApplicability = nil
    self.pendingImportSelections = nil

    if success then
        print("LayoutLedger: Import complete! Some changes may require a UI reload (/reload).")
        self:UpdateRevertButton()
    else
        print("LayoutLedger: Import failed - " .. tostring(err))
    end
end
