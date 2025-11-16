-- Luacheck configuration for Layout Ledger WoW addon
std = "lua51+wow"

-- Allow accessing these global WoW API functions
read_globals = {
    -- WoW API - Macros
    "GetNumMacros",
    "GetMacroInfo",
    "GetMacroIndexByName",
    "EditMacro",
    "CreateMacro",
    "DeleteMacro",
    "MAX_MACROS",

    -- WoW API - Actions
    "GetActionInfo",
    "PickupAction",
    "PlaceAction",
    "PickupMacro",
    "ClearCursor",
    "GetCursorInfo",

    -- WoW API - Keybindings
    "GetNumBindings",
    "GetBinding",
    "GetBindingKey",
    "SetBinding",
    "SaveBindings",
    "GetCurrentBindingSet",
    "ACCOUNT_BINDINGS",
    "CHARACTER_BINDINGS",

    -- WoW API - Specialization
    "GetSpecialization",
    "GetSpecializationInfo",
    "GetSpecializationInfoByID",

    -- WoW API - Unit Info
    "UnitClass",
    "UnitName",
    "UnitLevel",
    "GetRealmName",

    -- WoW API - Combat
    "InCombatLockdown",

    -- WoW API - UI
    "StaticPopup_Show",
    "InterfaceOptionsFrame_OpenToCategory",
    "CreateFrame",

    -- WoW Namespaces (with Edit Mode APIs)
    "C_EditMode",
    "C_EncodingUtil",
    "C_Spell",
    "C_Item",
    "C_EquipmentSet",
    "C_CooldownViewer",

    -- Frame globals
    "UIParent",
    "StaticPopupDialogs",

    -- Lua standard additions
    "time",
    "select",

    -- Ace3 libraries
    "LibStub",

    -- Our addon global
    "LayoutLedger",
}

-- Allow writing to these globals
globals = {
    "LayoutLedger",
}

-- Ignore these warnings
ignore = {
    "212", -- Unused argument (common in WoW API callbacks)
}

-- Exclude library files from checking
exclude_files = {
    "LayoutLedger/Libs/",
}

-- Maximum line length
max_line_length = 120

-- Maximum cyclomatic complexity
max_cyclomatic_complexity = 15
