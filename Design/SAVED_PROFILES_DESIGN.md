# Saved Profiles System Design

## Overview

Allow users to save and manage named layout profiles that can be stored in the addon's database (account-wide) AND exported as strings for sharing across accounts.

## Use Cases

### Primary Use Cases
1. **Family Sharing**: Save "Dad" and "Kid" profiles, export strings to import on kid's account
2. **Multi-Spec Management**: Save "Tank Build", "DPS Build", "Healing Build" for quick switching
3. **Cross-Account Transfer**: Export from main account, import to alt account
4. **Backup & Restore**: Save current setup before major changes

### Example Workflow
```
User: Save current setup as "Main Tank Build"
→ Addon saves to database (accessible on all characters)
→ User switches to alt
→ User loads "Main Tank Build" from saved profiles
→ Smart import dialog shows with all data

User: Export "Main Tank Build" to share with friend
→ Addon generates export string from saved profile
→ Friend imports string on their account
→ Friend can save it as their own profile
```

## Database Structure

### AceDB Namespace: `global`
Profiles are saved in the **global** namespace (account-wide, not character/class-specific):

```lua
addon.defaults = {
    -- ... existing defaults ...
    global = {
        savedProfiles = {
            -- Key = profile name
            ["Dad"] = {
                name = "Dad",
                created = 1234567890,  -- timestamp
                lastModified = 1234567890,  -- timestamp
                description = "Dad's main setup",  -- optional
                data = {
                    metadata = {...},  -- Character/spec info when saved
                    actionBars = {...},
                    keybindings = {...},
                    uiLayout = "...",
                    characterMacros = {...},
                    globalMacros = {...},
                },
            },
            ["Kid"] = {...},
            ["Tank Build"] = {...},
        },
    },
}
```

### Why Global Namespace?
- **Account-wide access**: All characters can see and load profiles
- **Not class-specific**: Can share Tank builds across Warrior, Paladin, Death Knight
- **Persistent**: Survives character deletion

## UI Design

### Option A: Separate Tab/Panel (Recommended)
Add a third section to the main window:

```
┌─────────────────────────────────────────────┐
│              Layout Ledger                  │
├─────────────────────────────────────────────┤
│ [Export] [Import] [Profiles] ← Tabs        │
├─────────────────────────────────────────────┤
│                                             │
│ Saved Profiles:                             │
│                                             │
│ ┌─────────────────────────────────────┐   │
│ │ Dad                    Mar 15, 2025  │   │
│ │ Elemental Shaman                     │   │
│ │ [Load] [Export String] [Delete]      │   │
│ ├─────────────────────────────────────┤   │
│ │ Kid                    Mar 10, 2025  │   │
│ │ Balance Druid                        │   │
│ │ [Load] [Export String] [Delete]      │   │
│ ├─────────────────────────────────────┤   │
│ │ Tank Build             Mar 5, 2025   │   │
│ │ Protection Warrior                   │   │
│ │ [Load] [Export String] [Delete]      │   │
│ └─────────────────────────────────────┘   │
│                                             │
│ [Save Current As...] [Import from String]   │
│                                             │
└─────────────────────────────────────────────┘
```

### Option B: Add to Existing UI (Simpler)
Add a "Profiles" section below Import section in current window:

```
┌─────────────────────────────────────────────┐
│ Export Options                              │
│ ☑ Action Bars  ☑ Keybindings               │
│ [Export]                                    │
├─────────────────────────────────────────────┤
│ Import                                      │
│ [text box]                                  │
│ [Import] [Revert]                           │
├─────────────────────────────────────────────┤
│ Saved Profiles                              │
│ • Dad [Load] [Export] [Delete]              │
│ • Kid [Load] [Export] [Delete]              │
│ [Save As...] [Import String]                │
└─────────────────────────────────────────────┘
```

## Core Functions

### 1. Save Current Profile
```lua
function addon:SaveProfile(profileName, description)
    if not self.db or not profileName or profileName == "" then
        return false, "Invalid profile name"
    end

    -- Check if profile already exists
    if self.db.global.savedProfiles[profileName] then
        -- Show overwrite confirmation
        return false, "Profile already exists"
    end

    -- Collect current data (same as export)
    local data = {
        metadata = self.Export.GetMetadata(),
    }

    -- Collect based on what's currently enabled/checked
    if self.db.profile.export.actionBars then
        data.actionBars = self.Export.GetActionBars()
    end
    -- ... etc for all data types

    -- Save to database
    self.db.global.savedProfiles[profileName] = {
        name = profileName,
        created = time(),
        lastModified = time(),
        description = description or "",
        data = data,
    }

    print("LayoutLedger: Profile '" .. profileName .. "' saved!")
    return true
end
```

### 2. Load Profile
```lua
function addon:LoadProfile(profileName)
    if not self.db or not profileName then
        return false, "Invalid profile name"
    end

    local profile = self.db.global.savedProfiles[profileName]
    if not profile then
        return false, "Profile not found"
    end

    -- Use existing smart import system
    if profile.data.metadata then
        local applicability = self:AnalyzeImportApplicability(profile.data)
        self:ShowSmartImportDialog(profile.data, applicability)
    else
        -- Legacy profile without metadata
        self:LegacyImport(profile.data)
    end

    return true
end
```

### 3. Export Profile to String
```lua
function addon:ExportProfileToString(profileName)
    if not self.db or not profileName then
        return nil, "Invalid profile name"
    end

    local profile = self.db.global.savedProfiles[profileName]
    if not profile then
        return nil, "Profile not found"
    end

    -- Encode the profile data (same as regular export)
    local success, result = pcall(function()
        return self.Serialize.Encode(profile.data)
    end)

    if success then
        return result
    else
        return nil, "Encoding failed: " .. tostring(result)
    end
end
```

### 4. Import Profile from String
```lua
function addon:ImportProfileFromString(encodedData, profileName)
    if not encodedData or encodedData == "" then
        return false, "Empty string"
    end

    local data = self.Serialize.Decode(encodedData)
    if not data then
        return false, "Invalid import string"
    end

    -- Save as a profile
    self.db.global.savedProfiles[profileName] = {
        name = profileName,
        created = time(),
        lastModified = time(),
        description = "Imported from string",
        data = data,
    }

    print("LayoutLedger: Profile '" .. profileName .. "' imported!")
    return true
end
```

### 5. Delete Profile
```lua
function addon:DeleteProfile(profileName)
    if not self.db or not profileName then
        return false, "Invalid profile name"
    end

    if not self.db.global.savedProfiles[profileName] then
        return false, "Profile not found"
    end

    -- Show confirmation dialog
    StaticPopupDialogs["LAYOUTLEDGER_DELETE_PROFILE"] = {
        text = "Delete profile '" .. profileName .. "'?\nThis cannot be undone.",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            self.db.global.savedProfiles[profileName] = nil
            print("LayoutLedger: Profile '" .. profileName .. "' deleted.")
            self:RefreshProfileList()  -- Update UI
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("LAYOUTLEDGER_DELETE_PROFILE")

    return true
end
```

### 6. List Profiles
```lua
function addon:GetProfileList()
    if not self.db or not self.db.global.savedProfiles then
        return {}
    end

    local profiles = {}
    for name, profile in pairs(self.db.global.savedProfiles) do
        table.insert(profiles, {
            name = name,
            created = profile.created,
            lastModified = profile.lastModified,
            description = profile.description,
            spec = profile.data.metadata and profile.data.metadata.specName or "Unknown",
            class = profile.data.metadata and profile.data.metadata.className or "Unknown",
        })
    end

    -- Sort by last modified (most recent first)
    table.sort(profiles, function(a, b)
        return (a.lastModified or 0) > (b.lastModified or 0)
    end)

    return profiles
end
```

## User Workflows

### Workflow 1: Save Current Setup
1. User sets up their UI, action bars, macros, etc.
2. Opens `/ll`, goes to Profiles section
3. Clicks "Save Current As..."
4. Enter dialog pops up: "Profile Name: [____]  Description: [____]"
5. User enters "Dad" and clicks Save
6. Profile saved to database
7. Profile appears in list

### Workflow 2: Load Saved Profile
1. User opens `/ll`, goes to Profiles section
2. Sees "Dad" profile in list
3. Clicks "Load" button next to "Dad"
4. Smart import dialog appears with applicability analysis
5. User selects what to import (or accepts defaults)
6. Clicks "Import Selected"
7. Layout applied

### Workflow 3: Share Profile Cross-Account
1. **On Main Account:**
   - User opens `/ll`, goes to Profiles
   - Clicks "Export String" next to "Dad" profile
   - Export string appears in text box (auto-highlighted)
   - User copies with Ctrl+C
   - User saves to text file or Discord message

2. **On Kid's Account:**
   - User opens `/ll`, goes to Profiles
   - Clicks "Import from String"
   - Pastes the export string
   - Enters profile name: "Dad's Setup"
   - Profile saved to database
   - Can now load "Dad's Setup" profile

### Workflow 4: Delete Profile
1. User opens `/ll`, Profiles section
2. Clicks "Delete" next to unwanted profile
3. Confirmation: "Delete profile 'Old Build'? This cannot be undone."
4. User clicks "Delete"
5. Profile removed from list

## Implementation Plan

### Phase 1: Database & Core Functions
- [x] Add `global.savedProfiles` to defaults
- [ ] Implement `SaveProfile(name, description)`
- [ ] Implement `LoadProfile(name)`
- [ ] Implement `DeleteProfile(name)`
- [ ] Implement `ExportProfileToString(name)`
- [ ] Implement `ImportProfileFromString(string, name)`
- [ ] Implement `GetProfileList()`

### Phase 2: UI (Option B - Simpler)
- [ ] Add "Saved Profiles" section to main frame
- [ ] Add scrollable list of profiles
- [ ] Add buttons for each profile: Load, Export, Delete
- [ ] Add "Save As..." button with name/description dialog
- [ ] Add "Import from String" button with dialog

### Phase 3: Polish
- [ ] Add profile rename function
- [ ] Add profile update/overwrite function
- [ ] Add profile metadata display (created date, spec, class)
- [ ] Add confirmation dialogs
- [ ] Add search/filter for large profile lists

## Advanced Features (Future)

### Profile Categories/Tags
```lua
profiles = {
    ["Dad"] = {
        tags = {"family", "main"},
        ...
    },
}
```

### Profile Sharing via Addon Communication
- Share profiles directly between online players
- No need to copy/paste strings

### Cloud Sync (if Blizzard adds API)
- Sync profiles across accounts via cloud storage

### Profile Diff/Compare
- Show differences between two profiles before loading
- "This will change 15 action bars and 8 keybindings"

## Security Considerations

1. **Profile Name Validation**: Sanitize profile names to prevent issues
   - Max length: 50 characters
   - No special characters that break table keys
   - No empty names

2. **Import Validation**: Verify imported strings are valid data
   - Check for malformed data
   - Validate data structure matches expected format

3. **Storage Limits**: Warn if too many profiles
   - Recommend max 50 profiles (database size concerns)

## Summary

**Key Benefits:**
- ✅ Save multiple named layouts
- ✅ Account-wide access (all characters)
- ✅ Export to string for cross-account sharing
- ✅ Works with smart import system (applicability analysis)
- ✅ Simple UI integration
- ✅ Family-friendly ("Dad", "Kid" profiles)

**Implementation Priority:**
1. Database structure (simple)
2. Core save/load/delete functions
3. Export to string functionality
4. UI for profile management
5. Polish & UX improvements

This system will significantly improve the addon's usability for families, alt-oholics, and anyone managing multiple layouts!
