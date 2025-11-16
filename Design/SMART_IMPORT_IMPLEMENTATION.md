# Smart Import System - Implementation Complete

## Summary

The smart import system has been fully implemented! The addon now intelligently categorizes exported data by scope (account/character/spec) and provides a detailed import dialog that shows what can be safely imported.

## What Was Implemented

### 1. **Export Metadata** ✅
Every export now includes rich metadata:
- Character info (name, realm, level)
- Class info (name, ID)
- **Spec info** (ID, name, index) - for validating action bars
- **Keybinding scope** (account vs character) - from `GetCurrentBindingSet()`
- Export date and addon version

**File: Export.lua**
- Added `GetMetadata()` function

**File: Core.lua**
- Modified `Export_OnClick()` to include metadata in all exports

### 2. **Data Scope Categorization** ✅

| Data Type | Scope | Notes |
|-----------|-------|-------|
| **Global Macros** | Account-wide | Always applicable |
| **Character Macros** | Character-specific | Always applicable |
| **Action Bars** | Spec-specific | Only when in matching spec |
| **UI Layout** | Character-specific | Always applicable |
| **Keybindings** | Account OR Character | Depends on user's setting |

### 3. **Applicability Analysis** ✅
The addon analyzes imported data to determine:
- What's available in the import
- What's applicable to the current character/spec
- What has warnings (spec mismatch, keybinding scope mismatch)

**File: Core.lua**
- Added `AnalyzeImportApplicability(data)` function
- Added helper functions: `CountActions()`, `CountKeybindings()`

### 4. **Smart Import Dialog** ✅
Replaced simple "Override/Merge/Cancel" popup with intelligent dialog:

**Features:**
- Shows source character and spec information
- Checkboxes for each data type (pre-checked if applicable)
- Item counts (e.g., "18 macros", "72 actions")
- Scope labels (account-wide, character, spec)
- **Warning messages** for incompatible data
- Can selectively import only certain parts

**File: UI.xml**
- Added `LayoutLedgerSmartImportFrame` (new dialog frame)

**File: Core.lua**
- Added `ShowSmartImportDialog(data, applicability)` function
- Added `PopulateImportOptions(applicability)` function
- Added `SmartImport_OnClick()` function

### 5. **Import Flow** ✅
Updated import process:
1. Parse import string
2. Check if it has metadata (new format) or not (legacy)
3. If new format: analyze applicability → show smart dialog
4. If legacy format: fall back to old simple popup
5. User selects what to import
6. Import only selected items

**File: Core.lua**
- Modified `Import_OnClick()` to detect metadata
- Added `LegacyImport(data)` function for backward compatibility

## User Experience

### Example 1: Perfect Match
**Scenario:** Importing on same character, same spec
```
┌─────────────────────────────────────────────┐
│ Import Layout from Thrall @ Area 52        │
│ Elemental Shaman (Level 70)                │
├─────────────────────────────────────────────┤
│ ☑ Global Macros (18)                       │
│   account-wide                              │
│ ☑ Character Macros (12)                    │
│   character                                 │
│ ☑ Action Bars (68)                         │
│   spec                                      │
│ ☑ UI Layout                                │
│   character                                 │
│ ☑ Keybindings (45)                         │
│   account-wide                              │
│                                             │
│        [Import Selected]  [Cancel]          │
└─────────────────────────────────────────────┘
```
**Result:** Everything checked, no warnings - safe to import all

### Example 2: Spec Mismatch
**Scenario:** Importing Elemental Shaman action bars while in Restoration spec
```
┌─────────────────────────────────────────────┐
│ Import Layout from Thrall @ Area 52        │
│ Elemental Shaman (Level 70)                │
├─────────────────────────────────────────────┤
│ ☑ Global Macros (18)                       │
│   account-wide                              │
│ ☑ Character Macros (12)                    │
│   character                                 │
│ ☐ Action Bars (68)                         │
│   spec                                      │
│   ⚠ Exported from Elemental spec.          │
│   You are currently in Restoration spec.   │
│ ☑ UI Layout                                │
│   character                                 │
│ ☑ Keybindings (45)                         │
│   account-wide                              │
│                                             │
│        [Import Selected]  [Cancel]          │
└─────────────────────────────────────────────┘
```
**Result:** Action bars unchecked by default with warning - user can choose to skip

### Example 3: Keybinding Scope Mismatch
**Scenario:** Importing account-wide keybindings while using character-specific mode
```
┌─────────────────────────────────────────────┐
│ Import Layout from Thrall @ Area 52        │
│ Elemental Shaman (Level 70)                │
├─────────────────────────────────────────────┤
│ ☑ Keybindings (45)                         │
│   account                                   │
│   ⚠ Exported from account keybindings.     │
│   You are using character keybindings.     │
│                                             │
│        [Import Selected]  [Cancel]          │
└─────────────────────────────────────────────┘
```
**Result:** Keybindings checked but with warning - user is informed of scope mismatch

## Use Cases

### Use Case 1: Share UI Across Alts
```
Main Character (Warrior) → Export everything
Alt Character (Warrior) → Import
  ✓ Global macros imported (account-wide)
  ✓ Character macros imported (will create duplicates - that's OK)
  ✓ Action bars imported (same class, same spec)
  ✓ UI layout imported
  ✓ Keybindings imported
```

### Use Case 2: Export Only Action Bars
```
Character → Uncheck everything except Action Bars → Export
Other Character (same spec) → Import
  ✓ Only action bars available in import
  ✓ Dialog shows just action bars option
```

### Use Case 3: Cross-Spec Safety
```
Balance Druid → Export (includes action bars)
Switch to Feral Druid → Import
  ⚠ Dialog warns about spec mismatch
  ✓ Action bars unchecked by default
  ✓ User can still import macros/UI/keybindings safely
```

## Backward Compatibility

**Legacy Import Strings:**
- Old exports without metadata still work
- Falls back to simple "Override/Merge/Cancel" popup
- No feature loss for old exports

**Message:** "Legacy import string detected (no metadata)"

## Technical Details

### Spec Detection
```lua
local specIndex = GetSpecialization()  -- Returns 1-4
local specID, specName = GetSpecializationInfo(specIndex)
-- specID: Unique spec ID (e.g., 262 for Elemental)
-- specName: Display name (e.g., "Elemental")
```

### Keybinding Scope Detection
```lua
local bindingSet = GetCurrentBindingSet()
-- Returns: 1 (ACCOUNT_BINDINGS) or 2 (CHARACTER_BINDINGS)
local scope = (bindingSet == ACCOUNT_BINDINGS) and "account" or "character"
```

### Applicability Rules

**Global Macros:**
- Always applicable (account-wide)

**Character Macros:**
- Always applicable (character-specific, safe to import)

**Action Bars:**
- Applicable ONLY if `currentSpecIndex == exportedSpecIndex`
- Warning if spec mismatch

**UI Layout:**
- Always applicable (character-specific)

**Keybindings:**
- Always applicable
- Warning if scope mismatch (account vs character)

## Files Modified

| File | Changes |
|------|---------|
| **Export.lua** | Added `GetMetadata()` function |
| **Core.lua** | Added metadata to exports, applicability analysis, smart dialog functions |
| **UI.xml** | Added smart import dialog frame |

## Testing Recommendations

### Test 1: Same Character Export/Import
1. Export with all options checked
2. Make some changes
3. Import → should see smart dialog
4. All items should be checked, no warnings
5. Import selected → should restore settings

### Test 2: Cross-Spec Import
1. Export action bars as Spec A
2. Switch to Spec B
3. Import → should see warning about spec mismatch
4. Action bars should be unchecked by default
5. Can still import other items safely

### Test 3: Keybinding Scope
1. Check current keybinding mode (ESC → Keybindings → bottom checkbox)
2. Export keybindings
3. Toggle keybinding mode
4. Import → should see warning about scope mismatch

### Test 4: Selective Import
1. Export everything
2. Import → uncheck some items
3. Only checked items should be imported

### Test 5: Legacy Import
1. Use an old export string (from before this update)
2. Import → should see "Legacy import" message
3. Should fall back to old simple popup

## Known Limitations

1. **One spec at a time:** Can only export currently active spec's action bars (no way to access inactive spec bars via API)

2. **No merge mode yet:** Smart dialog currently only supports "Override" mode (Merge mode removed for simplicity - can be added later)

3. **Action bar counts:** Count shows number of assigned slots, not total (72 assigned out of 120 possible)

## Future Enhancements

### Multi-Spec Export Button
Add button to automatically:
1. Save current spec
2. Switch to each spec
3. Export that spec's action bars
4. Switch back to original spec
5. Combine all into one export string

### Saved Import Profiles
- Save import strings with names ("Main Tank", "PvP Build")
- Quick access to frequently used imports
- List of saved profiles in UI

### Import History
- Keep last 5-10 imports
- Easy revert to previous imports
- Timestamp and source info for each

## Summary

✅ **Export metadata** - Character, class, spec, and keybinding scope info
✅ **Applicability analysis** - Knows what's safe to import
✅ **Smart dialog** - Shows warnings and allows selective import
✅ **Spec detection** - Warns about action bar spec mismatches
✅ **Backward compatible** - Old exports still work
✅ **Flexible** - Can export/import everything or just specific parts

The smart import system is ready for testing! Users can now safely import layouts across characters and specs with full awareness of what's being applied.
