-- LayoutLedger Export Functions
LayoutLedger.Export = {}

function LayoutLedger.Export.GetMacros()
    local macros = {
        character = {},
        global = {}
    }

    local numCharacterMacros, numGlobalMacros = GetNumMacros()
    local totalMacros = numCharacterMacros + numGlobalMacros

    for i = 1, totalMacros do
        local name, icon, body, isAccount = GetMacroInfo(i)
        if name then
            local macroData = {name = name, icon = icon, body = body}
            if isAccount then
                table.insert(macros.global, macroData)
            else
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
            actionBars[i] = {
                type = actionType,
                id = id,
                subType = subType
            }
        end
    end
    return actionBars
end

function LayoutLedger.Export.GetEditModeLayout()
    local activeLayout = C_EditMode.GetActiveLayoutName()
    return C_EditMode.ConvertLayoutToString(activeLayout)
end

function LayoutLedger.Export.GetKeybindings()
    return C_KeyBindings.ExportKeyBindings()
end
