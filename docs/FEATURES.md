# Layout Ledger - Features

## Overview

Layout Ledger is a World of Warcraft addon that allows you to export and import your UI settings across characters and specializations. It handles action bars, keybindings, UI layouts, and macros with intelligent scope detection.

## Core Features

### 1. Smart Import System

The addon intelligently categorizes exported data by scope and provides detailed feedback about what can be safely imported.

#### Data Scopes

| Data Type | Scope | Description |
|-----------|-------|-------------|
| **Global Macros** | Account-wide | Shared across all characters on your account |
| **Character Macros** | Character-specific | Unique to each character |
| **Action Bars** | Spec-specific | Different for each specialization |
| **UI Layout** | Character-specific | Per-character Edit Mode layouts |
| **Keybindings** | Account or Character | Depends on your keybinding setting |

#### Export Metadata

Every export includes:
- Character name, realm, and level
- Class name and ID
- Specialization name and ID (for action bar validation)
- Keybinding scope (account vs character)
- Export date and addon version

#### Import Dialog

When importing, you see a detailed dialog showing:
- Source character and spec information
- Checkboxes for each data type with counts
- Scope labels (account-wide, character, spec)
- **Warnings** for incompatible data

**Example:**
```
┌─────────────────────────────────────────────┐
│ Import Layout from Thrall @ Area 52        │
│ Elemental Shaman (Level 70)                │
├─────────────────────────────────────────────┤
│ ☑ Global Macros (18) - account-wide        │
│ ☑ Character Macros (12) - character        │
│ ☐ Action Bars (68) - spec                  │
│   ⚠ Exported from Elemental spec.          │
│      You are in Restoration spec.          │
│ ☑ UI Layout - character                    │
│ ☑ Keybindings (45) - account-wide          │
│                                             │
│        [Import Selected]  [Cancel]          │
└─────────────────────────────────────────────┘
```

### 2. Cross-Character Macro Support

Action bars often reference macros by ID, which differs across characters. The addon handles this intelligently.

#### How It Works

**On Export:**
- Stores macro ID **and** macro name
- Action bar exports include: `{type="macro", id=5, macroName="MyMacro"}`

**On Import:**
- Tries to find macro by **name first** (cross-character compatible)
- Falls back to ID if name lookup fails (same character)
- Gracefully skips if macro doesn't exist
- Reports skipped actions to user

**Example Output:**
```
LayoutLedger: Import complete!
LayoutLedger: Skipped 3 action(s) - macros/items not found:
  - Slot 12: macro 'HunterPet'
  - Slot 24: macro 'Aspect'
  - Slot 36: macro 'BestialWrath'
```

### 3. Class Profiles

Share revert data across all characters of the same class.

#### How to Use

1. Check "Use Class Profiles" in Export section
2. Import a layout
3. Revert data is saved for **all characters of your class**
4. Switch to another character of the same class
5. Revert button is already enabled with shared data

#### Storage

**Character-specific (default):**
```lua
LayoutLedgerDB.profiles["Character-Realm"].lastSettings
```

**Class-wide (when enabled):**
```lua
LayoutLedgerDB.class["WARRIOR"].lastSettings
```

#### Use Cases

- Share base UI layout across all Warriors (Tank, DPS, Alt)
- Maintain consistent keybindings for all Druids
- Quick setup for newly leveled characters

### 4. Saved Profiles (Coming Soon)

Save and manage multiple named layout profiles with account-wide access and string export capability.

#### Planned Features

**Profile Management:**
- Save current setup with custom name: "Dad", "Kid", "Tank Build"
- Account-wide storage (accessible on all characters)
- Load profile → Smart import dialog shows
- Delete unwanted profiles

**Cross-Account Sharing:**
- Export profile to string
- Share string via Discord/text file
- Import string on another account
- Save imported profile for future use

**Example Workflow:**
```
1. Dad saves setup as "Dad" profile
2. Exports "Dad" profile to string
3. Sends string to kid's account
4. Kid imports string, saves as "Dad's Setup"
5. Kid can load "Dad's Setup" anytime
```

**Database Structure:**
```lua
global.savedProfiles = {
    ["Dad"] = {
        name = "Dad",
        created = timestamp,
        lastModified = timestamp,
        description = "optional",
        data = {
            metadata = {...},
            actionBars = {...},
            keybindings = {...},
            ...
        },
    },
}
```

See [SAVED_PROFILES_DESIGN.md](../SAVED_PROFILES_DESIGN.md) for full specifications.

## Export Validation

Before exporting, the addon validates your selection and shows a confirmation popup.

**Validation Checks:**
- At least one item must be selected
- Shows counts for each data type
- Warns if no data found for selected items

**Example Popup:**
```
This will export:

• 68 Action Bar slots
• 45 Keybindings
• UI Layout
• 12 Character Macros
• 18 Global Macros

[Export] [Cancel]
```

## Revert Feature

Import operations automatically save your current settings before applying changes.

**How It Works:**
1. Click Import
2. Addon saves current settings to database
3. New settings are applied
4. "Revert" button becomes enabled
5. Click Revert to restore previous settings

**Persistence:**
- Revert data survives `/reload`
- Stored via AceDB (automatically saved)
- Can revert after logging out and back in

**Class Profiles:**
- When "Use Class Profiles" is enabled, revert data is shared across all characters of your class
- Reverting on one character affects the class-wide saved state

## Combat Safety

The addon automatically closes all windows when you enter combat (Midnight expansion compatibility).

**Behavior:**
- Detects `PLAYER_REGEN_DISABLED` event (entering combat)
- Closes main window and smart import dialog
- Shows message: "Window closed due to combat"
- Prevents combat lockdown errors

## UI Features

### Export Options
- ☐ Action Bars (spec-specific)
- ☐ Keybindings (account or character)
- ☐ UI Layout (character-specific)
- ☐ Character Macros (character-specific)
- ☐ Global Macros (account-wide)
- ☐ Use Class Profiles (share revert data across class)

### Auto-Highlight Export
After exporting, the text is automatically selected and highlighted. Just press `Ctrl+C` to copy.

### Selective Import
Choose exactly what to import with checkboxes in the smart import dialog. Skip incompatible or unwanted data.

## Slash Commands

```
/ll or /layoutledger    - Toggle main window
/ll debug               - Show debug information
```

## Technical Details

### Specialization Detection
```lua
local specIndex = GetSpecialization()  -- 1-4
local specID, specName = GetSpecializationInfo(specIndex)
```

**Action Bar Validation:**
- Exports include current spec ID and name
- Imports check if current spec matches exported spec
- Warns if mismatch, unchecks action bars by default

### Keybinding Scope Detection
```lua
local bindingSet = GetCurrentBindingSet()
-- ACCOUNT_BINDINGS (1) or CHARACTER_BINDINGS (2)
local scope = (bindingSet == ACCOUNT_BINDINGS) and "account" or "character"
```

**Import Behavior:**
- Always imports keybindings
- Warns if scope mismatch (account vs character)
- User is informed but can proceed

### Backward Compatibility

**Legacy Imports:**
- Old export strings without metadata still work
- Falls back to simple "Override/Merge/Cancel" dialog
- No feature loss for old exports

## Best Practices

### Exporting

1. **Full Character Export:**
   - Check all options
   - Export includes everything for complete backup

2. **Spec-Specific Export:**
   - Check only Action Bars and Keybindings
   - Export lightweight spec setup

3. **Cross-Character Export:**
   - Uncheck Action Bars if different specs
   - Export macros, UI Layout, and Keybindings

### Importing

1. **Same Character:**
   - All items should be applicable
   - No warnings expected

2. **Cross-Character (Same Class/Spec):**
   - Action bars may work if macros exist with same names
   - Check for skipped actions after import

3. **Cross-Spec Import:**
   - Uncheck Action Bars in import dialog
   - Only import macros, UI layout, and keybindings

4. **Cross-Account Import:**
   - Be aware of keybinding scope differences
   - Macros need to be recreated on new account first
   - Action bars will skip missing macros gracefully

## Limitations

1. **One Spec at a Time:** Can only export currently active spec's action bars (API limitation)

2. **Macro Dependencies:** Cross-character import requires macros with matching names to exist

3. **No Direct Multi-Spec Export:** Need to switch specs manually to export each one (future enhancement planned)

4. **No Talent Export:** Addon focuses on UI/action bars, not talent builds

## Future Enhancements

See [SAVED_PROFILES_DESIGN.md](../SAVED_PROFILES_DESIGN.md) for detailed future plans:

- Saved Profiles UI and functions
- Multi-spec export automation
- Import history (undo multiple times)
- Profile rename/update
- Profile categories/tags
- Diff preview before import
