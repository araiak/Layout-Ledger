# Changelog

All notable changes to Layout Ledger will be documented in this file.

## [Unreleased]

### Added
- **Smart Import System** - Intelligent data categorization by scope (account/character/spec)
- **Export Metadata** - Character, class, spec, and keybinding scope info in every export
- **Export Validation Popup** - Shows counts and confirms before exporting
- **Saved Profiles Database** - Account-wide profile storage structure (UI pending)
- **Combat Lockdown Handling** - Windows automatically close when entering combat
- **Split Macro Checkboxes** - Separate "Character Macros" and "Global Macros" options

### Changed
- Main frame height increased from 500px to 530px (accommodate extra checkbox)
- Export flow now shows confirmation dialog with data counts
- Import flow routes through smart dialog for new format exports

### Fixed
- **Cross-Character Macro Import** - Stores macro names, looks up by name on import
- **Spec Mismatch Detection** - Warns when importing action bars from different spec
- **Keybinding Scope Detection** - Identifies account vs character keybindings

## [1.0.0] - Initial Development

### Major Fixes Applied

#### 1. UI Frame Not Showing (COMPLETE_FIX_SUMMARY.md)
**Problem:** `/ll` command showed "Frame not initialized" error

**Root Cause:**
- Frame initialization in ADDON_LOADED event handler
- Event already fired before addon registered for it

**Solution:**
- Moved frame initialization to `OnEnable()` function
- OnEnable fires on PLAYER_LOGIN (guaranteed frame availability)
- All XML frames properly wired: `LayoutLedgerFrame`, `importBox`, `revertButton`

**Files Changed:**
- Core.lua: Moved frame setup to OnEnable

#### 2. XML Backdrop Deprecated (BACKDROP_FIX.md)
**Problem:** "Unrecognized XML: Backdrop" errors in WoW

**Root Cause:**
- `<Backdrop>` XML element deprecated in WoW 9.0+
- Line 10 had `</Backdrop>` instead of `</BackgroundInsets>`

**Solution:**
- Removed entire Backdrop element from XML
- Added `inherits="BackdropTemplate"` to Frame
- Set backdrop programmatically in Lua using `SetBackdrop()`

**Files Changed:**
- UI.xml: Removed Backdrop, added BackdropTemplate
- Core.lua: Added backdrop setup in OnEnable

#### 3. API Function Errors (API_FIXES.md)
**Problem:** Multiple API function errors during export

**Wrong APIs Used:**
- `C_KeyBindings.ExportKeyBindings()` - doesn't exist
- `C_EditMode.GetActiveLayoutName()` - doesn't exist
- `C_EditMode.ConvertLayoutToString()` - wrong method name

**Correct APIs:**
```lua
-- Keybindings
local numBindings = GetNumBindings()
for i = 1, numBindings do
    local command, category, key1, key2 = GetBinding(i)
end

-- Edit Mode
local layouts = C_EditMode.GetLayouts()
local activeLayoutInfo = layouts.layouts[layouts.activeLayout]
local layoutString = C_EditMode.ConvertLayoutInfoToString(activeLayoutInfo)
```

**Files Changed:**
- Export.lua: Rewrote GetKeybindings and GetEditModeLayout
- Import.lua: Rewrote SetKeybindings and SetEditModeLayout

#### 4. LibDeflate Missing (LIBDEFLATE_FIX.md)
**Problem:** "attempt to call method 'Compress' (a nil value)"

**Root Causes:**
1. LibDeflate.lua not loaded in embeds.xml
2. Wrong method names (Compress vs CompressDeflate)

**Solution:**
- Added `<Script file="Libs\LibDeflate.lua"/>` to embeds.xml
- Changed to `CompressDeflate` and `DecompressDeflate`
- Switched to `EncodeForPrint` / `DecodeForPrint` for better copy-paste

**Files Changed:**
- embeds.xml: Added LibDeflate include
- Serialize.lua: Fixed method names

#### 5. Missing Export Checkboxes
**Problem:** No UI controls to select what to export

**Solution:**
- Added 4 CheckButtons to UI.xml:
  - Action Bars
  - Keybindings
  - UI Layout
  - Macros (originally "Macros (All)", later split)
- Bound to database: `self.db.profile.export.*`

**Files Changed:**
- UI.xml: Added CheckButtons and labels
- Core.lua: Added RefreshUI to load checkbox states

#### 6. Checkbox Label Alignment
**Problem:** Labels centered instead of aligned with checkboxes

**Solution:**
- Changed font to `GameFontHighlightSmall`
- Added `justifyH="LEFT"`
- Adjusted offsets from `x="5" y="0"` to `x="0" y="0"`

**Files Changed:**
- UI.xml: Updated all checkbox labels

#### 7. Import EditBox Not Accepting Input
**Problem:** Cannot paste into import text box

**Solution:**
- Added `enableMouse="true"` and `enabled="true"` attributes
- Added OnLoad script to explicitly enable EditBox
- Added OnMouseDown script for auto-focus

**Files Changed:**
- UI.xml: Enhanced EditBox configuration

#### 8. No Auto-Highlight on Export
**Problem:** Hard to select export text for copy

**Solution:**
- After export, call `SetFocus()` and `HighlightText()` on EditBox
- User just needs to press Ctrl+C to copy

**Files Changed:**
- Core.lua: Added auto-highlight to Export_OnClick

#### 9. Checkboxes Start Unchecked
**Problem:** Checkboxes reset to unchecked every time

**Solution:**
- Created `RefreshUI()` function to sync checkbox states from database
- Called when frame is shown via `ToggleFrame()`

**Files Changed:**
- Core.lua: Added RefreshUI, called from ToggleFrame

### Cross-Character Macro Import (MACRO_IMPORT_FIX.md)

**Problem:** Macros referenced by ID fail when importing to different character

**Export Enhancement:**
```lua
-- Store both ID and name
if actionType == "macro" and id then
    local macroName = GetMacroInfo(id)
    if macroName then
        actionData.macroName = macroName
    end
end
```

**Import Enhancement:**
```lua
-- Lookup by name first (cross-character)
if data.macroName then
    macroId = GetMacroIndexByName(data.macroName)
end

-- Fallback to ID (same character)
if not macroId or macroId == 0 then
    local macroName = GetMacroInfo(data.id)
    if macroName then
        macroId = data.id
    end
end

-- Skip if not found
if not macroId or macroId == 0 then
    table.insert(skippedActions, {
        slot = i,
        type = "macro",
        name = data.macroName or ("ID " .. tostring(data.id))
    })
end
```

**User Feedback:**
```
LayoutLedger: Skipped 3 action(s) - macros/items not found on this character:
  - Slot 12: macro 'HunterPet'
  - Slot 24: macro 'Aspect'
```

**Files Changed:**
- Export.lua: Added macroName storage
- Import.lua: Added name lookup logic and skip reporting

### Class Profiles (CLASS_PROFILES.md)

**Feature:** Share revert data across all characters of the same class

**Database Structure:**
```lua
addon.defaults = {
    profile = {
        useClassProfiles = false,
        lastSettings = nil,  -- Character-specific
    },
    class = {
        lastSettings = nil,  -- Class-wide
        savedLayouts = {},   -- Future: multiple layouts
    },
}
```

**Implementation:**
- Added "Use Class Profiles" checkbox to UI
- SaveCurrentSettings saves to both profile and class (if enabled)
- Revert_OnClick checks class namespace first (if enabled)
- UpdateRevertButton checks both namespaces

**Use Case:**
- Save settings on Main Warrior
- Switch to Alt Warrior
- Revert button already enabled with shared data

**Files Changed:**
- Core.lua: Added class namespace logic
- UI.xml: Added UseClassProfiles checkbox

### Smart Import System (SMART_IMPORT_IMPLEMENTATION.md)

**Feature:** Intelligent import with applicability analysis

**Metadata in Exports:**
```lua
metadata = {
    characterName = "Thrall",
    realmName = "Area 52",
    characterLevel = 70,
    className = "Shaman",
    classID = 7,
    specID = 262,
    specName = "Elemental",
    specIndex = 1,
    keybindingScope = "account",
    exportDate = time(),
    addonVersion = "1.0.0",
}
```

**Applicability Analysis:**
- Checks if current spec matches exported spec
- Checks if keybinding scope matches
- Calculates counts for each data type
- Generates warnings for mismatches

**Smart Import Dialog:**
- Shows source character and spec
- Checkboxes for each data type (pre-checked if applicable)
- Warnings for incompatible data
- Counts: "Global Macros (18)", "Action Bars (68)"
- Selective import - choose what to apply

**Files Changed:**
- Export.lua: Added GetMetadata
- Core.lua: Added AnalyzeImportApplicability, ShowSmartImportDialog, PopulateImportOptions, SmartImport_OnClick
- UI.xml: Added LayoutLedgerSmartImportFrame

### Recent UX Improvements (UX_IMPROVEMENTS_SUMMARY.md)

**1. Split Macro Checkboxes:**
- Separated "Macros (All)" into "Character Macros" and "Global Macros"
- Consistent with import UI

**2. Export Validation:**
- Confirmation popup before export
- Shows counts for each data type
- Validates at least one item selected
- Warns if no data found

**3. Combat Lockdown:**
- Registered PLAYER_REGEN_DISABLED event
- Automatically closes windows when entering combat
- Prevents Midnight expansion issues

**4. Saved Profiles (Design Phase):**
- Database structure added
- Account-wide storage
- Export profile to string for sharing
- Import string and save as profile
- Full design in SAVED_PROFILES_DESIGN.md

## Development Tools

### XML Validation (README_XML_TESTING.md)
- Custom Node.js validator: `scripts/validate-xml.js`
- Checks well-formedness, deprecated elements, common issues
- Run: `node scripts/validate-xml.js`

### Lua Linting (README_LINTING.md)
- luacheck configuration in `.luacheckrc`
- Lua 5.1 + WoW standard
- All WoW API functions declared
- Run: `luacheck LayoutLedger/`

## Known Issues

### Minor Issues
- UI.xml has 4 warnings about unnamed frames (cosmetic, doesn't affect functionality)
- Saved Profiles UI not yet implemented (core functions pending)

## Upgrade Notes

### From Legacy Format to New Format
- Old export strings still work (backward compatible)
- Falls back to simple Override/Merge/Cancel dialog
- New exports include metadata for smart import

### Database Migration
- AceDB handles migrations automatically
- New namespaces added: `global.savedProfiles`
- Existing data preserved

## Credits

- **Ace3** - Framework and libraries
- **LibDeflate** - Compression
- **Claude Code** - AI pair programming assistance

## Links

- [GitHub Repository](https://github.com/yourusername/Layout-Ledger)
- [Issue Tracker](https://github.com/yourusername/Layout-Ledger/issues)
- [CurseForge](https://www.curseforge.com/wow/addons/layout-ledger)
