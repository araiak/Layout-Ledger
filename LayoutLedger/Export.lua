-- LayoutLedger Export Functions
LayoutLedger.Export = {}

function LayoutLedger.Export.GetMetadata()
    local _, className, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID, specName = nil, nil

    if specIndex then
        specID, specName = GetSpecializationInfo(specIndex)
    end

    local bindingSet = GetCurrentBindingSet()
    local keybindingScope = (bindingSet == ACCOUNT_BINDINGS) and "account" or "character"

    return {
        exportDate = time(),
        addonVersion = LayoutLedger.EXPORT_VERSION,

        characterName = UnitName("player"),
        realmName = GetRealmName(),
        characterLevel = UnitLevel("player"),

        className = className,
        classID = classID,

        specID = specID,
        specName = specName,
        specIndex = specIndex,

        keybindingScope = keybindingScope,
    }
end

function LayoutLedger.Export.GetMacros()
    local macros = {
        character = {},
        global = {}
    }

    -- WoW API: GetMacroInfo only returns 3 values (name, icon, body)
    -- Macro type is determined by slot index per GetMacroIndexByName docs:
    --   Slots 1-120: Account-wide (global) macros
    --   Slots 121-150: Character-specific macros

    -- Iterate through all possible macro slots
    for i = 1, 150 do
        local name, icon, body = GetMacroInfo(i)
        if name then
            local macroData = {name = name, icon = icon, body = body}

            -- Determine type by slot index
            if i <= 120 then
                -- Account-wide macro (slots 1-120)
                table.insert(macros.global, macroData)
            else
                -- Character-specific macro (slots 121-150)
                table.insert(macros.character, macroData)
            end
        end
    end

    return macros
end

function LayoutLedger.Export.GetActionBars()
    local actionBars = {}
    for i = 1, 120 do
        local actionType, id, subType = GetActionInfo(i)
        if actionType then
            local actionData = {
                type = actionType,
                id = id,
                subType = subType
            }

            -- For macros, we need to get the macro name for cross-character compatibility
            -- GetActionInfo returns an internal action ID, not the macro slot index
            -- So we need to pick up the action and inspect the cursor to get the real macro index
            if actionType == "macro" then
                -- Pick up the action to inspect it
                PickupAction(i)
                local cursorType, cursorMacroIndex = GetCursorInfo()

                if cursorType == "macro" and cursorMacroIndex then
                    -- Now we have the actual macro slot index, get the name
                    local macroName = GetMacroInfo(cursorMacroIndex)
                    if macroName then
                        actionData.macroName = macroName
                        -- Store the real macro index instead of the internal ID
                        actionData.id = cursorMacroIndex
                    end
                end

                -- Put it back on the bar where it was
                PlaceAction(i)
                ClearCursor()
            end

            actionBars[i] = actionData
        end
    end
    return actionBars
end

function LayoutLedger.Export.GetEditModeLayout()
    -- Get all layouts (includes active layout info)
    local layouts = C_EditMode.GetLayouts()

    print("LayoutLedger: DEBUG Export - C_EditMode.GetLayouts() returned:", tostring(layouts))

    if not layouts then
        print("LayoutLedger: DEBUG Export - GetLayouts() returned nil")
        return nil
    end

    print("LayoutLedger: DEBUG Export - activeLayout index:", tostring(layouts.activeLayout))
    print("LayoutLedger: DEBUG Export - number of layouts:", layouts.layouts and #layouts.layouts or "nil")

    if not layouts.activeLayout then
        print("LayoutLedger: DEBUG Export - No active layout set")
        return nil
    end

    -- Validate that activeLayout index is within bounds
    if not layouts.layouts or #layouts.layouts == 0 then
        print("LayoutLedger: DEBUG Export - No layouts available")
        return nil
    end

    -- Check if activeLayout index is out of bounds
    if layouts.activeLayout < 1 or layouts.activeLayout > #layouts.layouts then
        print(string.format("LayoutLedger: WARNING - activeLayout index %d is out of bounds (only %d layouts exist)",
            layouts.activeLayout, #layouts.layouts))
        print("LayoutLedger: Using first layout instead")
        layouts.activeLayout = 1
    end

    -- Find the active layout
    local activeLayoutInfo = layouts.layouts[layouts.activeLayout]
    if not activeLayoutInfo then
        print("LayoutLedger: DEBUG Export - Active layout info is nil after bounds check")
        return nil
    end

    -- Debug: Show layout structure
    print("LayoutLedger: DEBUG Export - Layout name:", tostring(activeLayoutInfo.layoutName))
    print("LayoutLedger: DEBUG Export - Layout type:", tostring(activeLayoutInfo.layoutType))

    -- Skip preset layouts (Classic, Modern) - layoutType 0
    if activeLayoutInfo.layoutType == 0 then
        print("LayoutLedger: WARNING - Cannot export preset layouts (Classic/Modern)")
        print("LayoutLedger: Please activate a custom layout in Edit Mode and try again")
        return nil
    end

    -- Convert to string (this may strip the name)
    local layoutString = C_EditMode.ConvertLayoutInfoToString(activeLayoutInfo)
    print("LayoutLedger: DEBUG Export - Layout string length:", layoutString and #layoutString or "nil")

    -- Return both the string AND the layout metadata
    return {
        layoutString = layoutString,
        layoutName = activeLayoutInfo.layoutName,
        layoutType = activeLayoutInfo.layoutType
    }
end

function LayoutLedger.Export.GetCooldownLayout()
    -- Check if API exists (added in retail, may not exist in classic)
    if not C_CooldownViewer or not C_CooldownViewer.GetLayoutData then
        print("LayoutLedger: DEBUG Export - C_CooldownViewer.GetLayoutData not available")
        return nil
    end

    -- Get cooldown viewer layout data
    local layoutData = C_CooldownViewer.GetLayoutData()
    print("LayoutLedger: DEBUG Export - C_CooldownViewer.GetLayoutData() returned:", tostring(layoutData))

    if not layoutData then
        print("LayoutLedger: DEBUG Export - GetLayoutData() returned nil")
        return nil
    end

    print("LayoutLedger: DEBUG Export - Cooldown layout string:", layoutData)
    return layoutData
end

function LayoutLedger.Export.GetKeybindings()
    -- No built-in export function - we need to iterate through all bindings
    local bindings = {}
    local numBindings = GetNumBindings()

    for i = 1, numBindings do
        local command, category, key1, key2 = GetBinding(i)

        -- Skip category headers (they have category but no command)
        if command and command ~= "" then
            bindings[command] = {
                key1 = key1,
                key2 = key2,
                category = category
            }
        end
    end

    return bindings
end

function LayoutLedger.Export.GetCVars()
    -- Export console variables (CVars)
    -- Start with UI scale, expandable for other CVars in the future
    local cvars = {}

    -- List of CVars to export
    local cvarList = {
        "uiScale",
    }

    for _, cvarName in ipairs(cvarList) do
        local value = GetCVar(cvarName)
        if value then
            cvars[cvarName] = value
            print(string.format("LayoutLedger: DEBUG Export - CVar %s = %s", cvarName, value))
        end
    end

    return cvars
end
