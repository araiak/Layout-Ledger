# Layout Ledger - Knowledge Graph

This document maps the codebase structure, documentation, and key concepts for easy navigation.

## 📁 Project Structure

```
Layout-Ledger/
│
├── 📄 README.md                    # Project overview and quick start
├── 📄 KNOWLEDGE_GRAPH.md           # This file - navigation guide
├── 📄 CLAUDE.md                    # AI development rules and guidelines
│
├── 📂 docs/                        # User and developer documentation
│   ├── FEATURES.md                 # Complete feature guide
│   ├── DEVELOPMENT.md              # Development setup and guidelines
│   └── CHANGELOG.md                # Version history and fixes
│
├── 📂 LayoutLedger/                # Main addon directory
│   ├── Core.lua                    # Main addon logic
│   ├── Export.lua                  # Data export functions
│   ├── Import.lua                  # Data import functions
│   ├── Serialize.lua               # Compression and encoding
│   ├── Options.lua                 # Ace3 config UI
│   ├── UI.xml                      # Main window frames
│   ├── embeds.xml                  # Library includes
│   ├── LayoutLedger.toc            # Addon manifest
│   └── Libs/                       # Ace3 + LibDeflate
│
├── 📂 scripts/                     # Development tools
│   ├── validate-xml.js             # XML validator
│   ├── install-hooks.sh            # Git hooks installer (Linux/Mac)
│   └── install-hooks.bat           # Git hooks installer (Windows)
│
└── 📂 Design/                      # Design specifications
    ├── IMPORT_DESIGN.md            # Smart import system spec
    ├── SAVED_PROFILES_DESIGN.md    # Saved profiles spec
    ├── SMART_IMPORT_IMPLEMENTATION.md  # Implementation notes
    └── UX_IMPROVEMENTS_SUMMARY.md  # Recent UX changes
```

## 🗺️ Concept Map

### Core Features

```
Layout Ledger
│
├─ Smart Import System
│  ├─ Export Metadata (character/spec/class)
│  ├─ Applicability Analysis (scope detection)
│  └─ Smart Import Dialog (selective import)
│
├─ Data Scopes
│  ├─ Account-wide (Global Macros)
│  ├─ Character-specific (Character Macros, UI Layout)
│  └─ Spec-specific (Action Bars)
│
├─ Cross-Character Support
│  ├─ Macro Name Resolution
│  └─ Graceful Skip on Missing Items
│
├─ Class Profiles
│  ├─ Class-wide Revert Data
│  └─ Shared Across Same-Class Characters
│
├─ Saved Profiles (Upcoming)
│  ├─ Account-wide Storage
│  ├─ Named Profiles
│  └─ Export to String
│
└─ Safety Features
   ├─ Export Validation
   ├─ Combat Lockdown Handling
   └─ Revert Functionality
```

## 📚 Documentation Map

### For Users
```
Start Here: README.md
    ↓
Need Features? → docs/FEATURES.md
    ├─ Smart Import System
    ├─ Cross-Character Macros
    ├─ Class Profiles
    ├─ Export Validation
    └─ Best Practices
```

### For Developers
```
Start Here: README.md
    ↓
Setup Environment → docs/DEVELOPMENT.md
    ├─ Prerequisites
    ├─ Code Quality Tools
    ├─ Testing Checklists
    ├─ WoW API Reference
    └─ Contributing Guide
    ↓
Check History → docs/CHANGELOG.md
    ├─ Recent Features
    ├─ Bug Fixes
    └─ Known Issues
```

### For AI Assistants
```
Start Here: CLAUDE.md
    ├─ Development Rules
    ├─ Code Style Guidelines
    ├─ Testing Requirements
    └─ Documentation Standards
```

## 🔍 File Purpose Quick Reference

### Core Addon Files

| File | Purpose | Key Functions |
|------|---------|---------------|
| `Core.lua` | Main addon, events, UI | `OnInitialize`, `OnEnable`, `Export_OnClick`, `Import_OnClick` |
| `Export.lua` | Collect game data | `GetMetadata`, `GetActionBars`, `GetKeybindings`, `GetMacros` |
| `Import.lua` | Apply imported data | `SetActionBars`, `SetKeybindings`, `SetMacros` |
| `Serialize.lua` | Encode/compress data | `Encode`, `Decode` |
| `Options.lua` | Ace3 config UI | Options table definition |
| `UI.xml` | Frame definitions | Main window, smart import dialog |

### Documentation Files

| File | Purpose | Audience |
|------|---------|----------|
| `README.md` | Project overview | Everyone |
| `docs/FEATURES.md` | Feature documentation | Users |
| `docs/DEVELOPMENT.md` | Development guide | Developers |
| `docs/CHANGELOG.md` | Version history | Everyone |
| `KNOWLEDGE_GRAPH.md` | Navigation guide | Everyone |
| `CLAUDE.md` | AI dev rules | AI Assistants |

### Design Documents

| File | Purpose | Status |
|------|---------|--------|
| `Design/IMPORT_DESIGN.md` | Smart import spec | Implemented |
| `Design/SAVED_PROFILES_DESIGN.md` | Saved profiles spec | Pending |
| `Design/SMART_IMPORT_IMPLEMENTATION.md` | Implementation notes | Reference |
| `Design/UX_IMPROVEMENTS_SUMMARY.md` | Recent UX changes | Implemented |

## 🔄 Data Flow

### Export Flow
```
User clicks Export
    ↓
Core.lua: Export_OnClick()
    ├─ Validate selection
    ├─ Show confirmation popup with counts
    └─ User confirms
        ↓
    Export.lua: Get functions
        ├─ GetMetadata()
        ├─ GetActionBars()
        ├─ GetKeybindings()
        ├─ GetEditModeLayout()
        └─ GetMacros()
            ↓
    Serialize.lua: Encode()
        ├─ AceSerializer
        ├─ LibDeflate Compress
        └─ EncodeForPrint
            ↓
    Core.lua: Display in EditBox
        └─ Auto-highlight for copy
```

### Import Flow
```
User pastes string and clicks Import
    ↓
Core.lua: Import_OnClick()
    ├─ Decode string
    └─ Check for metadata
        ↓
    Has metadata? (New format)
        ├─ YES → Smart Import
        │   ├─ AnalyzeImportApplicability()
        │   ├─ ShowSmartImportDialog()
        │   └─ User selects items
        │       ↓
        │   SmartImport_OnClick()
        │       ├─ SaveCurrentSettings() [for revert]
        │       └─ Call Import functions
        │           ↓
        │       Import.lua: Set functions
        │           ├─ SetActionBars()
        │           ├─ SetKeybindings()
        │           ├─ SetEditModeLayout()
        │           └─ SetMacros()
        │
        └─ NO → Legacy Import
            └─ Simple Override/Merge dialog
```

## 🎯 Feature Implementation Status

### Implemented ✅
- ✅ Smart Import System
- ✅ Export Metadata
- ✅ Cross-Character Macro Support
- ✅ Class Profiles
- ✅ Export Validation
- ✅ Combat Lockdown Handling
- ✅ Spec Mismatch Detection
- ✅ Keybinding Scope Detection
- ✅ Auto-Highlight Export
- ✅ Revert Functionality

### In Progress 🚧
- 🚧 Saved Profiles (DB structure ready)

### Planned 📋
- 📋 Saved Profiles UI
- 📋 Profile Export to String
- 📋 Multi-Spec Export
- 📋 Import History
- 📋 Profile Rename/Update
- 📋 Diff Preview

## 🔗 Key Relationships

### Database Namespaces
```
AceDB Structure
│
├─ profile (character-specific)
│  ├─ export preferences
│  ├─ useClassProfiles flag
│  └─ lastSettings (revert data)
│
├─ class (class-wide)
│  ├─ lastSettings (shared revert)
│  └─ savedLayouts (future)
│
└─ global (account-wide)
   └─ savedProfiles (future)
```

### Data Scope Hierarchy
```
Account-wide
├─ Global Macros
└─ Saved Profiles (future)

Character-specific
├─ Character Macros
├─ UI Layout
└─ Keybindings (if character mode)

Spec-specific
└─ Action Bars

Class-wide
└─ Revert Data (if class profiles enabled)
```

### Frame Hierarchy
```
LayoutLedgerFrame (Main Window)
├─ ExportSection
│  ├─ CheckBoxes (Action Bars, Keybindings, etc.)
│  └─ ExportButton
│
└─ ImportSection
   ├─ ImportScrollFrame
   │  └─ ImportBox (EditBox)
   ├─ ImportButton
   └─ RevertButton

LayoutLedgerSmartImportFrame (Import Dialog)
├─ SourceInfo (Character/Spec display)
├─ ScrollFrame
│  └─ ScrollChild (Dynamic checkboxes)
├─ ModeFrame (Override/Merge)
├─ ImportButton
└─ CancelButton
```

## 🛠️ Development Workflow

### Adding a New Feature
```
1. Design Phase
   └─ Create design doc in Design/

2. Implementation
   ├─ Update Core.lua (if UI needed)
   ├─ Update Export.lua (if export needed)
   ├─ Update Import.lua (if import needed)
   └─ Update UI.xml (if frames needed)

3. Testing
   ├─ Run XML validation
   ├─ Run luacheck
   └─ In-game testing

4. Documentation
   ├─ Update docs/FEATURES.md
   ├─ Update docs/CHANGELOG.md
   └─ Update README.md (if major feature)

5. Commit
   ├─ Quality checks run automatically via pre-commit hook
   └─ Follow git conventions (see CLAUDE.md)
```

## 🔍 Finding Information

### "Where is..."

**Where is the export button handler?**
→ `Core.lua` → `Export_OnClick()`

**Where is action bar export logic?**
→ `Export.lua` → `GetActionBars()`

**Where is macro name resolution?**
→ `Import.lua` → `SetActionBars()` → lines 70-99

**Where is spec detection?**
→ `Export.lua` → `GetMetadata()` → lines 6-11

**Where is the smart import dialog defined?**
→ `UI.xml` → `LayoutLedgerSmartImportFrame` → lines 263-386

**Where are saved profiles stored?**
→ `Core.lua` → `addon.defaults.global.savedProfiles` → line 22

**Where is class profile logic?**
→ `Core.lua` → `SaveCurrentSettings()`, `Revert_OnClick()`, `UpdateRevertButton()`

### "How do I..."

**How do I add a new export option?**
1. Add checkbox to `UI.xml`
2. Add to `addon.defaults.profile.export` in `Core.lua`
3. Add export function to `Export.lua`
4. Add import function to `Import.lua`
5. Update `Export_OnClick()` in `Core.lua`
6. Update `SmartImport_OnClick()` in `Core.lua`

**How do I test my changes?**
→ See `docs/DEVELOPMENT.md` → Testing section

**How do I validate XML?**
→ Run `node scripts/validate-xml.js`

**How do I set up Git hooks?**
→ Run `bash scripts/install-hooks.sh` (or `scripts\install-hooks.bat` on Windows)

**How do I add a new WoW API function?**
→ Add to `.luacheckrc` → `read_globals` section

## 📖 External Resources

### WoW API Documentation
- [Warcraft Wiki](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [WoWpedia](https://wowpedia.fandom.com/wiki/World_of_Warcraft_API)

### Ace3 Documentation
- [Ace3 Home](https://www.wowace.com/projects/ace3)
- [AceDB Documentation](https://www.wowace.com/projects/ace3/pages/api/ace-db-3-0)

### Development Tools
- [luacheck](https://github.com/mpeterv/luacheck)
- [fast-xml-parser](https://www.npmjs.com/package/fast-xml-parser)

### Lua Resources
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)
- [Programming in Lua](https://www.lua.org/pil/)

---

**Last Updated:** 2025-01-11
**Maintainer:** Layout Ledger Development Team
