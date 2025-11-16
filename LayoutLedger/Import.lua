-- LayoutLedger Import Functions
LayoutLedger.Import = {}

function LayoutLedger.Import.SetMacros(macros, mode)
    print("LayoutLedger: DEBUG Import - SetMacros called with mode:", mode)

    if not macros then
        print("LayoutLedger: No macro data to import")
        return
    end

    -- Debug: Show what we received
    local charCount = macros.character and #macros.character or 0
    local globalCount = macros.global and #macros.global or 0
    print(string.format("LayoutLedger: DEBUG Import - Received %d character macros, %d global macros",
        charCount, globalCount))

    local createdMacros = 0
    local updatedMacros = 0
    local skippedMacros = 0

    -- CreateMacro 4th parameter is "perCharacter":
    --   perCharacter = true  → Character-specific macro (slots 121-150)
    --   perCharacter = false/nil → Account-wide (global) macro (slots 1-120)
    -- EditMacro does NOT have a perCharacter parameter - you cannot change a macro's type!
    -- But DeleteMacro exists, so we can delete and recreate if type is wrong
    local function createOrUpdateMacro(macroData, perCharacter)
        local existingId = GetMacroIndexByName(macroData.name)

        if existingId then
            -- Check if the existing macro is the correct type
            -- Slots 1-120 = global, 121-150 = character (per GetMacroIndexByName docs)
            local isExistingGlobal = (existingId <= 120)
            local wantGlobal = not perCharacter

            if isExistingGlobal == wantGlobal then
                -- Same type, safe to update (EditMacro only takes 4 params, no perCharacter!)
                EditMacro(existingId, macroData.name, macroData.icon, macroData.body)
                updatedMacros = updatedMacros + 1
            else
                -- Wrong type! Delete and recreate with correct type
                DeleteMacro(existingId)
                CreateMacro(macroData.name, macroData.icon, macroData.body, perCharacter)
                createdMacros = createdMacros + 1
                print("LayoutLedger: Macro '" .. macroData.name .. "' changed from " ..
                      (isExistingGlobal and "global" or "character") .. " to " ..
                      (wantGlobal and "global" or "character"))
            end
        else
            -- Doesn't exist, create it
            local numCharacterMacros, numGlobalMacros = GetNumMacros()
            if numCharacterMacros + numGlobalMacros >= MAX_MACROS then
                print("LayoutLedger: Cannot create macro '" .. macroData.name .. "' - at max limit")
                skippedMacros = skippedMacros + 1
            else
                CreateMacro(macroData.name, macroData.icon, macroData.body, perCharacter)
                createdMacros = createdMacros + 1
            end
        end
    end

    if mode == "Override" then
        -- The WoW API does not provide a function to delete all macros.
        -- Therefore, "Override" will behave like "Merge" and overwrite any
        -- macros with the same name.
    end

    -- Import character macros (perCharacter = true)
    local numCharacter = 0
    if macros.character then
        numCharacter = #macros.character
        print("LayoutLedger: DEBUG Import - Processing", numCharacter, "character macros")
        for i, macroData in ipairs(macros.character) do
            print(string.format("  [%d] Character macro: %s", i, macroData.name))
            createOrUpdateMacro(macroData, true)
        end
    end

    -- Import global/account macros (perCharacter = false/nil)
    local numGlobal = 0
    if macros.global then
        numGlobal = #macros.global
        print("LayoutLedger: DEBUG Import - Processing", numGlobal, "global macros")
        for i, macroData in ipairs(macros.global) do
            print(string.format("  [%d] Global macro: %s", i, macroData.name))
            createOrUpdateMacro(macroData, false)  -- false = account-wide/global
        end
    end

    -- Report results
    if createdMacros > 0 or updatedMacros > 0 then
        print(string.format("LayoutLedger: Macros imported - %d created, %d updated (%d character, %d global)",
            createdMacros, updatedMacros, numCharacter, numGlobal))
    end

    if skippedMacros > 0 then
        print("LayoutLedger: " .. skippedMacros .. " macro(s) could not be imported because you have reached the maximum number of macros.")
    end
end

function LayoutLedger.Import.SetActionBars(actionBars, mode)
    if not actionBars then return end

    local skippedActions = {}

    if mode == "Override" then
        -- Clear all action bar slots
        for i = 1, 120 do
            PickupAction(i)
            ClearCursor()
        end
    end

    for i, data in pairs(actionBars) do
        local success = false

        if data.type == "spell" then
            C_Spell.PickupSpell(data.id)
            PlaceAction(i)
            success = true

        elseif data.type == "item" then
            C_Item.PickupItem(data.id)
            PlaceAction(i)
            success = true

        elseif data.type == "macro" then
            -- Look up macro by name (cross-character compatible)
            local macroId = nil

            if data.macroName then
                -- Use GetMacroIndexByName to find the macro on this character
                macroId = GetMacroIndexByName(data.macroName)

                -- GetMacroIndexByName returns 0 if not found, we need nil for our check
                if macroId == 0 then
                    macroId = nil
                end
            end

            -- Only place the macro if we found it by name
            if macroId then
                PickupMacro(macroId)
                PlaceAction(i)
                success = true
            else
                -- Macro doesn't exist on this character, or name wasn't saved
                local displayName = data.macroName or ("ID " .. tostring(data.id) .. " (no name)")
                if not data.macroName then
                    displayName = displayName .. " - re-export from source character to fix"
                else
                    displayName = "'" .. displayName .. "' - not found, create this macro first"
                end
                table.insert(skippedActions, {
                    slot = i,
                    type = "macro",
                    name = displayName
                })
            end

        elseif data.type == "companion" or data.type == "mount" then
            -- Handle mounts/pets (may not have them)
            C_Spell.PickupSpell(data.id)
            PlaceAction(i)
            -- Don't mark as success, may fail silently if don't have it

        elseif data.type == "equipmentset" then
            -- Equipment sets may not exist
            C_EquipmentSet.PickupEquipmentSet(data.id)
            PlaceAction(i)
            -- Don't mark as success, may fail silently
        end
    end

    ClearCursor()

    -- Report skipped actions
    if #skippedActions > 0 then
        print("LayoutLedger: Skipped " .. #skippedActions .. " action(s) - macros/items not found on this character:")
        for _, action in ipairs(skippedActions) do
            print("  - Slot " .. action.slot .. ": " .. action.type .. " '" .. action.name .. "'")
        end
    end
end

function LayoutLedger.Import.SetEditModeLayout(layoutData, mode)
    print("LayoutLedger: DEBUG Import - SetEditModeLayout called with mode:", mode)

    if not layoutData then
        print("LayoutLedger: DEBUG Import - No layout data provided")
        return
    end

    -- Handle both old format (string) and new format (table with metadata)
    local layoutString, layoutName, layoutType
    if type(layoutData) == "string" then
        -- Legacy format: just the layout string
        layoutString = layoutData
        layoutName = "Imported Layout"
        layoutType = 1  -- Account type
        print("LayoutLedger: DEBUG Import - Legacy string format, length:", #layoutString)
    else
        -- New format: table with layoutString, layoutName, layoutType
        layoutString = layoutData.layoutString
        layoutName = layoutData.layoutName or "Imported Layout"
        layoutType = layoutData.layoutType or 1
        print("LayoutLedger: DEBUG Import - New table format")
        print("LayoutLedger: DEBUG Import - Layout name:", layoutName)
        print("LayoutLedger: DEBUG Import - Layout type:", layoutType)
        print("LayoutLedger: DEBUG Import - String length:", layoutString and #layoutString or "nil")
    end

    if not layoutString then
        print("LayoutLedger: DEBUG Import - No layout string in data")
        return
    end

    -- Convert string back to layout info
    local layoutInfo = C_EditMode.ConvertStringToLayoutInfo(layoutString)
    print("LayoutLedger: DEBUG Import - ConvertStringToLayoutInfo returned:", tostring(layoutInfo))

    if not layoutInfo then
        print("LayoutLedger: Failed to parse layout string")
        return
    end

    -- Get current layouts
    local layouts = C_EditMode.GetLayouts()
    print("LayoutLedger: DEBUG Import - GetLayouts returned:", tostring(layouts))

    if not layouts then
        print("LayoutLedger: Failed to get current layouts")
        return
    end

    print("LayoutLedger: DEBUG Import - Current active layout:", tostring(layouts.activeLayout))
    print("LayoutLedger: DEBUG Import - Number of existing layouts:", layouts.layouts and #layouts.layouts or "nil")

    -- In Override mode, find and replace the layout BY NAME instead of replacing active layout
    -- This preserves other custom layouts (e.g., MyRaidLayout and MyDungeonLayout can coexist)
    local isNewLayout = false
    local layoutIndex

    -- Restore the layout name and type to the layoutInfo
    layoutInfo.layoutName = layoutName
    layoutInfo.layoutType = layoutType

    -- Search for existing layout with the same name
    local foundExistingLayout = false
    if mode == "Override" then
        for i, layout in ipairs(layouts.layouts) do
            -- Match by name, but skip preset layouts (layoutType 0)
            if layout.layoutName == layoutName and layout.layoutType and layout.layoutType > 0 then
                print("LayoutLedger: DEBUG Import - Found existing layout '" .. layoutName .. "' at index:", i)
                print("LayoutLedger: DEBUG Import - Replacing existing layout")
                layouts.layouts[i] = layoutInfo
                layoutIndex = i
                isNewLayout = false
                foundExistingLayout = true
                break
            end
        end
    end

    -- If no existing layout found (or Merge mode), add as new layout
    if not foundExistingLayout then
        print("LayoutLedger: DEBUG Import - No existing layout named '" .. layoutName .. "' found")
        print("LayoutLedger: DEBUG Import - Adding new layout:", layoutName)
        -- Add as new layout
        table.insert(layouts.layouts, layoutInfo)
        -- Don't modify layouts.activeLayout here - let SetActiveLayout handle it
        layoutIndex = #layouts.layouts
        isNewLayout = true
        print("LayoutLedger: DEBUG Import - New layout will be at index:", layoutIndex)
    end

    -- Save the layouts (without modifying activeLayout)
    print("LayoutLedger: DEBUG Import - Calling SaveLayouts")
    local saveSuccess = C_EditMode.SaveLayouts(layouts)
    print("LayoutLedger: DEBUG Import - SaveLayouts returned:", tostring(saveSuccess))

    -- If we added a new layout, notify the Edit Mode system
    if isNewLayout and C_EditMode.OnLayoutAdded then
        print("LayoutLedger: DEBUG Import - Calling OnLayoutAdded")
        -- OnLayoutAdded(addedLayoutIndex, activateNewLayout, isLayoutImported)
        C_EditMode.OnLayoutAdded(layoutIndex, true, true)
    end

    -- ALWAYS set the imported layout as active (whether Override or Merge)
    -- IMPORTANT: Find the layout by name AFTER SaveLayouts() because indices may change
    print("LayoutLedger: DEBUG Import - Will activate layout named:", layoutName)

    -- Use C_Timer to delay activation slightly to ensure SaveLayouts has completed
    C_Timer.After(0.1, function()
        -- Re-fetch layouts to get current indices after save
        local freshLayouts = C_EditMode.GetLayouts()
        if not freshLayouts or not freshLayouts.layouts then
            print("LayoutLedger: ERROR - Could not fetch layouts after save")
            return
        end

        -- Find the layout by name (indices may have changed after SaveLayouts)
        local targetIndex = nil
        for i, layout in ipairs(freshLayouts.layouts) do
            if layout.layoutName == layoutName then
                targetIndex = i
                print("LayoutLedger: DEBUG Import - Found layout '" .. layoutName .. "' at index:", i)
                break
            end
        end

        if not targetIndex then
            print("LayoutLedger: ERROR - Could not find layout '" .. layoutName .. "' after save")
            return
        end

        -- Now activate the layout by its current index
        local setActiveSuccess, setActiveError = pcall(function()
            C_EditMode.SetActiveLayout(targetIndex)
        end)

        if not setActiveSuccess then
            print("LayoutLedger: ERROR - SetActiveLayout failed:", tostring(setActiveError))
        else
            print("LayoutLedger: DEBUG Import - SetActiveLayout completed successfully")
        end

        -- Verify the active layout was changed
        C_Timer.After(0.1, function()
            local verifyLayouts = C_EditMode.GetLayouts()
            if verifyLayouts and verifyLayouts.activeLayout then
                print("LayoutLedger: DEBUG Import - Active layout is now:", verifyLayouts.activeLayout)
                if verifyLayouts.layouts[verifyLayouts.activeLayout] then
                    local activeName = verifyLayouts.layouts[verifyLayouts.activeLayout].layoutName
                    print("LayoutLedger: Active layout name:", tostring(activeName))

                    if activeName == layoutName then
                        print("LayoutLedger: SUCCESS - Layout '" .. layoutName .. "' is now active!")
                    else
                        print("LayoutLedger: WARNING - Expected '" .. layoutName .. "' to be active, but got '" .. tostring(activeName) .. "'")
                        print("LayoutLedger: Trying to activate again...")

                        -- Try one more time by finding the layout again
                        for i, layout in ipairs(verifyLayouts.layouts) do
                            if layout.layoutName == layoutName then
                                pcall(function()
                                    C_EditMode.SetActiveLayout(i)
                                end)
                                break
                            end
                        end
                    end
                end
            end
        end)
    end)

    print("LayoutLedger: UI Layout imported. The layout should activate shortly.")
end

function LayoutLedger.Import.SetCooldownLayout(layoutString, mode)
    print("LayoutLedger: DEBUG Import - SetCooldownLayout called with mode:", mode)
    print("LayoutLedger: DEBUG Import - Layout string:", layoutString and tostring(layoutString) or "nil")

    if not layoutString then
        print("LayoutLedger: DEBUG Import - No cooldown layout string provided")
        return
    end

    -- Check if API exists (added in retail, may not exist in classic)
    if not C_CooldownViewer or not C_CooldownViewer.SetLayoutData then
        print("LayoutLedger: WARNING - C_CooldownViewer.SetLayoutData not available on this client")
        return
    end

    -- Apply the cooldown layout
    print("LayoutLedger: DEBUG Import - Calling SetLayoutData")
    local success, result = pcall(function()
        return C_CooldownViewer.SetLayoutData(layoutString)
    end)

    if success then
        print("LayoutLedger: DEBUG Import - SetLayoutData completed successfully")
        print("LayoutLedger: Cooldown Viewer layout imported successfully")
    else
        print("LayoutLedger: ERROR - SetLayoutData failed:", tostring(result))
    end
end

function LayoutLedger.Import.SetKeybindings(keybindings, mode)
    if not keybindings then return end

    -- Clear existing bindings if in Override mode
    if mode == "Override" then
        -- Note: We don't actually clear all bindings as that would break the UI
        -- Instead we only set the bindings we have
    end

    -- Set each binding
    for command, bindingData in pairs(keybindings) do
        -- Clear existing bindings for this command
        local key1, key2 = GetBindingKey(command)
        if key1 then
            SetBinding(key1, nil)
        end
        if key2 then
            SetBinding(key2, nil)
        end

        -- Set new bindings
        if bindingData.key1 and bindingData.key1 ~= "" then
            SetBinding(bindingData.key1, command)
        end
        if bindingData.key2 and bindingData.key2 ~= "" then
            SetBinding(bindingData.key2, command)
        end
    end

    -- Save bindings
    SaveBindings(GetCurrentBindingSet())
end

function LayoutLedger.Import.SetCVars(cvars, mode)
    print("LayoutLedger: DEBUG Import - SetCVars called with mode:", mode)

    if not cvars then
        print("LayoutLedger: DEBUG Import - No CVar data provided")
        return
    end

    local appliedCount = 0

    for cvarName, value in pairs(cvars) do
        print(string.format("LayoutLedger: DEBUG Import - Setting CVar %s to %s", cvarName, tostring(value)))

        local success = pcall(function()
            SetCVar(cvarName, value)
        end)

        if success then
            appliedCount = appliedCount + 1
        else
            print(string.format("LayoutLedger: WARNING - Failed to set CVar %s", cvarName))
        end
    end

    if appliedCount > 0 then
        print(string.format("LayoutLedger: Applied %d CVar(s) successfully", appliedCount))
    end
end
