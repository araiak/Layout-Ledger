-- LayoutLedger Import Functions
LayoutLedger.Import = {}

function LayoutLedger.Import.SetMacros(macros, mode)
    if not macros then return end

    local skippedMacros = 0

    local function createOrUpdateMacro(macroData, isAccount)
        local existingId, _ = GetMacroIndexByName(macroData.name)
        if existingId then
            EditMacro(existingId, macroData.name, macroData.icon, macroData.body, isAccount)
        else
            local numCharacterMacros, numGlobalMacros = GetNumMacros()
            if numCharacterMacros + numGlobalMacros >= MAX_MACROS then
                skippedMacros = skippedMacros + 1
            else
                CreateMacro(macroData.name, macroData.icon, macroData.body, isAccount)
            end
        end
    end

    if mode == "Override" then
        -- The WoW API does not provide a function to delete all macros.
        -- Therefore, "Override" will behave like "Merge" and overwrite any
        -- macros with the same name.
    end

    if macros.character then
        for _, macroData in ipairs(macros.character) do
            createOrUpdateMacro(macroData, false)
        end
    end

    if macros.global then
        for _, macroData in ipairs(macros.global) do
            createOrUpdateMacro(macroData, true)
        end
    end

    if skippedMacros > 0 then
        print("Layout Ledger: " .. skippedMacros .. " macro(s) could not be imported because you have reached the maximum number of macros.")
    end
end

function LayoutLedger.Import.SetActionBars(actionBars, mode)
    if not actionBars then return end

    if mode == "Override" then
        for i = 1, 120 do
            ClearAction(i)
        end
    end

    for i, data in pairs(actionBars) do
        if data.type == "spell" then
            PickupSpell(data.id)
            PlaceAction(i)
        elseif data.type == "item" then
            PickupItem(data.id)
            PlaceAction(i)
        elseif data.type == "macro" then
            PickupMacro(data.id)
            PlaceAction(i)
        end
    end
    ClearCursor()
end

function LayoutLedger.Import.SetEditModeLayout(layoutString, mode)
    if not layoutString then return end
    local layoutName = C_EditMode.ImportLayout(layoutString)
    if layoutName then
        C_EditMode.SetActiveLayout(layoutName)
    end
end

function LayoutLedger.Import.SetKeybindings(keybindings, mode)
    if not keybindings then return end
    C_KeyBindings.ImportKeyBindings(keybindings)
end
