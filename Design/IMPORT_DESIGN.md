# Smart Import System Design

## Overview

The addon will intelligently categorize exported data by scope (account, character, spec) and show an import dialog that lets users select what to import based on applicability.

## Data Categorization

### Account-Wide Data
- **Global Macros**: Available to all characters
- **Keybindings** (if `GetCurrentBindingSet() == ACCOUNT_BINDINGS`)

### Character-Specific Data
- **Character Macros**: Per-character
- **UI Layout (Edit Mode)**: Per-character layout
- **Keybindings** (if `GetCurrentBindingSet() == CHARACTER_BINDINGS`)

### Spec-Specific Data
- **Action Bars**: Slots 1-120 are per-specialization

## Export Metadata

Every export will include metadata:

```lua
{
    metadata = {
        exportDate = time(),
        addonVersion = "1.0.0",

        -- Character Info
        characterName = "Thrall",
        realmName = "Area 52",
        characterLevel = 70,

        -- Class Info
        className = "Shaman",
        classID = 7,

        -- Spec Info (for action bars)
        specID = 262,
        specName = "Elemental",
        specIndex = 1,

        -- Keybinding Scope
        keybindingScope = "account" or "character",  -- From GetCurrentBindingSet()
    },

    -- Actual data
    globalMacros = { ... },
    characterMacros = { ... },
    actionBars = { ... },
    uiLayout = "...",
    keybindings = { ... },
}
```

## Import Flow

### Step 1: Parse Import String
```lua
local data = Serialize.Decode(importString)
if not data or not data.metadata then
    print("Invalid import string")
    return
end
```

### Step 2: Analyze Applicability

```lua
local applicability = {
    globalMacros = {
        available = data.globalMacros ~= nil,
        applicable = true,  -- Always applicable
        warning = nil,
    },
    characterMacros = {
        available = data.characterMacros ~= nil,
        applicable = true,  -- Always applicable
        warning = nil,
    },
    actionBars = {
        available = data.actionBars ~= nil,
        applicable = (GetSpecialization() == data.metadata.specIndex),
        warning = not applicable and
            ("Action bars exported from " .. data.metadata.specName .. " spec. " ..
             "You are currently in " .. currentSpecName .. " spec.") or nil,
    },
    uiLayout = {
        available = data.uiLayout ~= nil,
        applicable = true,  -- Always applicable (character-specific)
        warning = nil,
    },
    keybindings = {
        available = data.keybindings ~= nil,
        applicable = true,  -- Can always import, but may override wrong scope
        warning = (data.metadata.keybindingScope ~= currentKeybindingScope) and
            ("Keybindings exported from " .. data.metadata.keybindingScope ..
             " mode. You are in " .. currentKeybindingScope .. " mode.") or nil,
    },
}
```

### Step 3: Show Import Dialog

Replace the simple "Override/Merge/Cancel" popup with a smarter dialog:

```
┌─────────────────────────────────────────────┐
│ Import Layout from Thrall @ Area 52        │
│ Class: Elemental Shaman (Level 70)         │
├─────────────────────────────────────────────┤
│ Select what to import:                      │
│                                             │
│ ☑ Global Macros (18 macros)                │
│   Account-wide - safe to import             │
│                                             │
│ ☑ Character Macros (12 macros)             │
│   Character-specific - safe to import       │
│                                             │
│ ☐ Action Bars (72 actions)                 │
│   ⚠ Spec mismatch: Exported from           │
│   Elemental, you are in Restoration         │
│   [Switch to Elemental Spec]                │
│                                             │
│ ☑ UI Layout                                 │
│   Character-specific - safe to import       │
│                                             │
│ ☑ Keybindings (45 bindings)                │
│   Account-wide mode - safe to import        │
│                                             │
│ Import Mode: [Override ▼] [Merge]          │
│                                             │
│        [Import Selected]  [Cancel]          │
└─────────────────────────────────────────────┘
```

## Implementation Details

### Export Changes

**Export.lua additions:**
```lua
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
        addonVersion = "1.0.0",  -- TODO: Pull from TOC

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
```

**Core.lua Export_OnClick changes:**
```lua
function addon:Export_OnClick()
    -- ... existing checks ...

    local success, result = pcall(function()
        local data = {
            metadata = self.Export.GetMetadata(),  -- NEW
        }
        local profile = self.db.profile.export

        if profile.actionBars then
            data.actionBars = self.Export.GetActionBars()
        end
        -- ... rest of export ...

        return self.Serialize.Encode(data)
    end)

    -- ... existing success handling ...
end
```

### Import Changes

**Core.lua Import_OnClick complete rewrite:**
```lua
function addon:Import_OnClick()
    if InCombatLockdown and InCombatLockdown() then
        print("LayoutLedger: Cannot import while in combat.")
        return
    end

    if not (self.importBox and self.Serialize) then
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

    if not data.metadata then
        print("LayoutLedger: Legacy import string detected. Metadata missing.")
        -- Fall back to old import flow?
        return
    end

    -- Analyze applicability
    local applicability = self:AnalyzeImportApplicability(data)

    -- Show new import dialog
    self:ShowSmartImportDialog(data, applicability)
end
```

**New function: AnalyzeImportApplicability**
```lua
function addon:AnalyzeImportApplicability(data)
    local meta = data.metadata
    local applicability = {}

    -- Global Macros
    applicability.globalMacros = {
        available = data.globalMacros ~= nil,
        applicable = true,
        count = data.globalMacros and #data.globalMacros or 0,
        scope = "account",
        warning = nil,
    }

    -- Character Macros
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
        count = data.actionBars and self:CountActions(data.actionBars) or 0,
        scope = "spec",
        warning = not actionBarsApplicable and
            ("Exported from " .. (meta.specName or "Unknown") .. " spec. " ..
             "You are currently in " .. (currentSpecName or "Unknown") .. " spec.") or nil,
        exportedSpec = meta.specName,
        currentSpec = currentSpecName,
    }

    -- UI Layout
    applicability.uiLayout = {
        available = data.uiLayout ~= nil,
        applicable = true,
        scope = "character",
        warning = nil,
    }

    -- Keybindings
    local currentBindingSet = GetCurrentBindingSet()
    local currentScope = (currentBindingSet == ACCOUNT_BINDINGS) and "account" or "character"
    local scopeMatch = (currentScope == meta.keybindingScope)

    applicability.keybindings = {
        available = data.keybindings ~= nil,
        applicable = true,  -- Can always import, but warn if scope mismatch
        count = data.keybindings and self:CountKeybindings(data.keybindings) or 0,
        scope = meta.keybindingScope,
        warning = not scopeMatch and
            ("Exported from " .. meta.keybindingScope .. " keybindings. " ..
             "You are using " .. currentScope .. " keybindings.") or nil,
    }

    return applicability
end

function addon:CountActions(actionBars)
    local count = 0
    for _ in pairs(actionBars) do
        count = count + 1
    end
    return count
end

function addon:CountKeybindings(keybindings)
    local count = 0
    for _ in pairs(keybindings) do
        count = count + 1
    end
    return count
end
```

### New Import Dialog

Create a new frame in **UI.xml** for the smart import dialog:

```xml
<Frame name="LayoutLedgerSmartImportFrame" parent="UIParent" frameStrata="DIALOG"
       movable="false" enableMouse="true" hidden="true" inherits="BackdropTemplate">
    <Size x="450" y="550"/>
    <Anchors>
        <Anchor point="CENTER"/>
    </Anchors>

    <Layers>
        <Layer level="ARTWORK">
            <!-- Title -->
            <FontString name="$parentTitle" inherits="GameFontNormalLarge" text="Import Layout">
                <Anchors>
                    <Anchor point="TOP">
                        <Offset x="0" y="-20"/>
                    </Anchor>
                </Anchors>
            </FontString>

            <!-- Source Info -->
            <FontString name="$parentSourceInfo" inherits="GameFontNormal" justifyH="CENTER">
                <Anchors>
                    <Anchor point="TOP" relativeTo="$parentTitle" relativePoint="BOTTOM">
                        <Offset x="0" y="-10"/>
                    </Anchor>
                </Anchors>
            </FontString>

            <!-- Instruction -->
            <FontString name="$parentInstruction" inherits="GameFontHighlight"
                       text="Select what to import:" justifyH="LEFT">
                <Anchors>
                    <Anchor point="TOPLEFT">
                        <Offset x="20" y="-80"/>
                    </Anchor>
                </Anchors>
            </FontString>
        </Layer>
    </Layers>

    <Frames>
        <!-- ScrollFrame for import options -->
        <ScrollFrame name="$parentScrollFrame" inherits="UIPanelScrollFrameTemplate">
            <Size x="410" y="300"/>
            <Anchors>
                <Anchor point="TOP" relativeTo="$parentInstruction" relativePoint="BOTTOM">
                    <Offset x="0" y="-10"/>
                </Anchor>
            </Anchors>
            <ScrollChild>
                <Frame name="$parentScrollChild">
                    <Size x="390" y="300"/>
                    <!-- Checkboxes and labels will be created dynamically in Lua -->
                </Frame>
            </ScrollChild>
        </ScrollFrame>

        <!-- Import Mode Dropdown -->
        <!-- TODO: Add dropdown for Override/Merge -->

        <!-- Buttons -->
        <Button name="$parentImportButton" inherits="UIPanelButtonTemplate" text="Import Selected">
            <Size x="120" y="30"/>
            <Anchors>
                <Anchor point="BOTTOM">
                    <Offset x="-65" y="20"/>
                </Anchor>
            </Anchors>
        </Button>

        <Button name="$parentCancelButton" inherits="UIPanelButtonTemplate" text="Cancel">
            <Size x="120" y="30"/>
            <Anchors>
                <Anchor point="LEFT" relativeTo="$parentImportButton" relativePoint="RIGHT">
                    <Offset x="10" y="0"/>
                </Anchor>
            </Anchors>
        </Button>

        <Button name="$parentCloseButton" inherits="UIPanelCloseButton">
            <Anchors>
                <Anchor point="TOPRIGHT">
                    <Offset x="0" y="0"/>
                </Anchor>
            </Anchors>
        </Button>
    </Frames>
</Frame>
```

## User Experience Examples

### Example 1: Perfect Match
**Export:** Balance Druid with account-wide keybindings
**Import:** Same character, same spec, same keybinding mode
**Result:** All checkboxes enabled, no warnings

### Example 2: Cross-Spec Import
**Export:** Elemental Shaman with action bars
**Import:** Same character, but in Restoration spec
**Result:**
- Global macros: ✓ Available
- Character macros: ✓ Available
- Action bars: ⚠ Warning (spec mismatch), checkbox disabled by default
- UI Layout: ✓ Available
- Keybindings: ✓ Available

### Example 3: Cross-Character Import
**Export:** Main character (Warrior) with character-specific macros
**Import:** Alt character (Warrior)
**Result:**
- Global macros: ✓ Available
- Character macros: ✓ Available (will create duplicates on alt)
- Action bars: ✓ Available if same spec
- UI Layout: ✓ Available
- Keybindings: ✓ Available

### Example 4: Keybinding Scope Mismatch
**Export:** Character with account-wide keybindings
**Import:** Different character using character-specific keybindings
**Result:**
- Keybindings: ⚠ Warning (scope mismatch)
- Message: "Exported from account keybindings, you are using character keybindings. This will update your account-wide settings."

## Benefits

1. **Flexibility**: Users can export everything or just specific parts
2. **Safety**: Clear warnings prevent accidental overwrites
3. **Intelligence**: Addon knows what's applicable and what isn't
4. **Transparency**: Users see exactly what they're importing
5. **Cross-character**: Easy to share layouts between alts
6. **Cross-spec**: Can still import non-action-bar data across specs

## Future Enhancements

- **Multi-spec export**: Button to "Export All Specs" that switches specs, exports each, combines into one string
- **Import profiles**: Save import strings with names like "Main Tank", "PvP Build"
- **Partial exports**: UI to select exactly what to export before generating string
- **Import history**: Keep last 5 imports for easy revert
