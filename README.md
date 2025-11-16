# Layout Ledger

[![Validate Addon](https://github.com/Araiak/Layout-Ledger/actions/workflows/validate.yml/badge.svg)](https://github.com/Araiak/Layout-Ledger/actions/workflows/validate.yml)

**Export and import your World of Warcraft UI layouts, action bars, keybindings, and macros across characters and specializations. Save named profiles with automatic spec-switching support.**

## Features

### Core Import/Export
- 🎯 **Smart Import System** - Intelligent data categorization by scope (account/character/spec)
- 🔄 **Cross-Character Support** - Import layouts across characters with macro name resolution
- 🛡️ **Spec-Aware** - Detects specialization mismatches and warns appropriately
- 💾 **Export String Versioning** - Backward-compatible format with automatic migration (v0.1.0)
- ⚔️ **Combat Safe** - Automatically closes windows when entering combat
- ✅ **Export Validation** - Confirms what you're exporting with detailed counts
- 🔙 **Automatic Backups** - Creates backup profiles before imports (auto-deleted after revert)

### Saved Profiles System
- 📁 **Named Profiles** - Save unlimited account-wide profiles with custom names
- 🎨 **Two Profile Types:**
  - **Simple Profiles** - Save current settings (all data types)
  - **Class Profiles** - Save all specs + character settings for multi-spec characters
- ⚡ **Auto-Apply on Spec Change** - Set a class profile as "Active" to automatically apply action bars when changing specs
- 🌟 **Visual Indicators** - Color-coded profiles (Active=Green★, Class=Blue, Backup=Orange)
- 🔄 **Smart Loading** - Load profiles immediately or set as active for auto-application
- 🗑️ **Profile Management** - Load, delete, and set profiles as active from one interface

### Data Coverage
- 🎮 **Action Bars** (120 slots) - Preserves spells, items, macros by name
- ⌨️ **Keybindings** - Account or character scope with smart conflict detection
- 🖼️ **Edit Mode Layouts** - Preserves custom UI layouts with names (skips Classic/Modern presets)
- 🧊 **Cooldown Viewer** - Saves cooldown frames configuration
- 🎯 **Macros** - Global (account-wide) and character-specific
- ⚙️ **CVars** - Console variables like UI Scale

## Quick Start

### Installation

1. Download the latest version from the [releases page](https://github.com/Araiak/Layout-Ledger/releases)
2. Extract the downloaded `.zip` file
3. Copy the `LayoutLedger` folder into your `World of Warcraft\_retail_\Interface\AddOns` directory
4. Restart World of Warcraft or `/reload`

### Basic Usage

#### Export/Import Strings

1. **Export your layout:**
   ```
   /ll
   → Check what to export (Action Bars, Keybindings, etc.)
   → Click "Export"
   → Confirm the export popup
   → Press Ctrl+C to copy the highlighted text
   ```

2. **Import on another character:**
   ```
   /ll
   → Paste the export string into the import box
   → Click "Import"
   → Review the smart import dialog
   → Select what to import
   → Click "Import Selected"
   ```

3. **Revert if needed:**
   ```
   /ll
   → Click "Revert" to undo the last import
   → (Automatically creates CharacterName-BAK backup before importing)
   ```

#### Saved Profiles (New!)

1. **Save a Simple Profile (current settings):**
   ```
   /ll
   → Click "Saved Profiles"
   → Enter profile name (e.g., "Billy")
   → Click "Save Simple"
   → Profile saved with all current settings
   ```

2. **Save a Class Profile (all specs):**
   ```
   /ll
   → Click "Saved Profiles"
   → Switch to each spec and configure action bars
   → Enter profile name (e.g., "Billy's Paladin")
   → Click "Save as Class"
   → Profile saved with character settings + data for all configured specs
   ```

3. **Set Active Profile (auto-apply on spec change):**
   ```
   /ll
   → Click "Saved Profiles"
   → Find your class profile
   → Click "Set Active"
   → ✅ Action bars now auto-apply when you change specs!
   ```

4. **Load a Profile:**
   ```
   /ll
   → Click "Saved Profiles"
   → Click "Load" on any profile to apply immediately
   → Or click "Set Active" on class profiles for auto-switching
   ```

## Documentation

- **[Features Guide](docs/FEATURES.md)** - Detailed feature documentation
- **[Development Guide](docs/DEVELOPMENT.md)** - For developers and contributors
- **[Changelog](docs/CHANGELOG.md)** - Version history and fixes
- **[Saved Profiles Design](Design/SAVED_PROFILES_DESIGN.md)** - Upcoming feature spec

## Data Scopes

Layout Ledger understands different data scopes and organizes profiles intelligently:

| Data Type | Scope | Simple Profile | Class Profile |
|-----------|-------|----------------|---------------|
| **Global Macros** | Account-wide | ✅ Saved | ✅ In characterSettings |
| **Character Macros** | Character | ✅ Saved | ✅ In characterSettings |
| **Action Bars** | Spec-specific | ✅ Current spec only | ✅ Per-spec in specSettings |
| **UI Layout** | Character | ✅ Saved | ✅ In characterSettings |
| **Keybindings** | Account/Char | ✅ Saved | ✅ In characterSettings |
| **Cooldown Viewer** | Spec-specific | ✅ Current spec only | ✅ Per-spec in specSettings |
| **CVars** | Character | ✅ Saved | ✅ In characterSettings |

### Profile Types Explained

**Simple Profile:**
- Snapshot of current character at one moment in time
- Includes all data types in their current state
- Use for: Quick saves, single-spec characters, sharing via export strings

**Class Profile:**
- Character settings (macros, keybindings, UI layout, CVars)
- Plus action bars + cooldown layout for each spec you've configured
- Auto-applies correct spec bars when changing specs (if set as Active)
- Use for: Multi-spec characters, family sharing, main characters

### Profile Visual Indicators

In the Saved Profiles window, profiles are color-coded:

| Color | Indicator | Type | Description |
|-------|-----------|------|-------------|
| 🟢 Green | ★ ProfileName | Active Class Profile | Currently active, auto-applies on spec change |
| 🔵 Blue | ProfileName | Class Profile | Contains multiple specs, can be set as active |
| 🟠 Orange | ProfileName-BAK | Auto Backup | Created before imports, deleted after revert |
| ⚪ White | ProfileName | Simple Profile | Standard saved profile |

## Smart Import Example

When importing, you see exactly what's compatible:

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

## Slash Commands

```
/ll or /layoutledger    - Toggle main window
/ll debug               - Show debug menu (clear macros, action bars, etc.)
```

## Use Cases

### Family Sharing (Billy & Dad Example)
Billy and his dad share an account. Each saves their profile:
1. Billy saves "Billy's Paladin" as a class profile
2. Dad imports his settings and saves "Dad's Warrior" as a class profile
3. Each sets their profile as "Active"
4. Now they can quickly swap: Just click "Set Active" on the other's profile!
5. Bonus: Spec changes auto-apply action bars for whoever's profile is active

### Multi-Spec Characters
Save a class profile with all 3 specs configured:
1. Configure Holy Paladin action bars
2. Switch to Ret, configure action bars
3. Switch to Prot, configure action bars
4. Save as "Main Paladin" class profile
5. Set as Active
6. ✅ Changing specs automatically loads the right bars!

### Alt Management
Quickly set up new alts with consistent settings:
1. Export from main character
2. Import to new alt
3. Or save as a named profile and load on any character

### Backup & Restore
Automatic before every import:
- Creates "CharacterName-BAK" profile automatically
- Visible in Saved Profiles (orange color)
- Click "Revert" to restore
- Backup auto-deleted after successful revert

### Cross-Character Macros
Import action bars across characters - addon resolves macro names automatically, even if slot numbers differ.

## Technical Details

- **Framework:** Ace3 (AceAddon, AceDB, AceConsole, AceEvent, AceConfig)
- **Compression:** LibDeflate with EncodeForPrint for efficient export strings
- **Storage:** AceDB with profile, class, and global namespaces
- **Compatibility:** WoW Retail (Dragonflight, War Within, Midnight-ready)

## Development

### Prerequisites
- Node.js (for XML validation)
- Lua 5.1

### Setup
```bash
git clone https://github.com/Araiak/Layout-Ledger.git
cd Layout-Ledger
npm install

# Install pre-commit hooks (recommended)
bash scripts/install-hooks.sh
```

### Quality Tools
```bash
# Validate XML
node scripts/validate-xml.js

# Lint Lua (requires luacheck)
luacheck LayoutLedger/

# Quality checks run automatically on commit via Git hooks
```

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for full development guide.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run quality tools
5. Submit a pull request

## Known Issues

- WoW API doesn't provide a way to delete Edit Mode layouts programmatically (can only be done manually in Edit Mode settings)
- Edit Mode layout activation requires slight delays due to WoW API timing

## Recently Completed (v0.1.0)

- ✅ Saved Profiles system (Simple + Class profiles)
- ✅ Auto-apply action bars on spec change
- ✅ Active profile tracking
- ✅ Automatic backup profiles
- ✅ Export string versioning with backward compatibility
- ✅ Migration system for database and import strings
- ✅ CVars support (UI Scale)
- ✅ Debug menu for testing
- ✅ Dynamic UI scaling for different resolutions

## Roadmap

### v0.2.0 (Future)
- [ ] Export class profiles to strings
- [ ] Import class profiles from strings
- [ ] Profile rename/update functionality
- [ ] Import history (undo multiple times)
- [ ] Diff preview before import
- [ ] Profile comparison tool
- [ ] Addon integration (WeakAuras, Details, etc.)
- [ ] Profile categories/folders

## Credits

- **Ace3** - Framework and libraries
- **LibDeflate** - Compression library
- Community feedback and testing

## License

This project is licensed under the [MIT License](LICENSE).

## Support

- **Issues:** [GitHub Issues](https://github.com/Araiak/Layout-Ledger/issues)

---

Made with ❤️ for the World of Warcraft community
