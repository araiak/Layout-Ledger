# Layout Ledger - Development Guide

## Development Environment Setup

### Prerequisites

- Node.js (for XML validation)
- Lua 5.1 (WoW uses Lua 5.1)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/Layout-Ledger.git
cd Layout-Ledger

# Install Node.js dependencies
npm install

# Install Git hooks (recommended)
bash scripts/install-hooks.sh
```

## Code Quality Tools

### XML Validation

We use a custom Node.js validator for WoW addon XML files.

**Run validation:**
```bash
node scripts/validate-xml.js
```

**What it checks:**
- Well-formed XML syntax
- Deprecated elements (like `<Backdrop>`)
- Frame structure issues
- Common WoW XML mistakes

**Example output:**
```
=== WoW Addon XML Validator ===

Scanning: C:\...\Layout-Ledger\LayoutLedger

Found 2 XML file(s)

✓ embeds.xml
⚠ UI.xml
  Warning: Frame without name attribute - may cause issues accessing from Lua

=== Validation Summary ===
Files checked: 2
Errors: 0
Warnings: 1

⚠ Validation passed with warnings
```

### Lua Linting (Luacheck)

We use luacheck for Lua code quality. Configuration is in `.luacheckrc`.

**Configuration highlights:**
- Lua 5.1 + WoW standard
- All WoW API functions declared as read_globals
- Max line length: 120 characters
- Max cyclomatic complexity: 15
- Excludes Libs/ directory

**Key globals configured:**
```lua
read_globals = {
    -- WoW API
    "GetActionInfo", "GetSpecialization", "GetSpecializationInfo",
    "UnitClass", "UnitName", "GetRealmName",

    -- WoW Namespaces
    "C_EditMode", "C_EncodingUtil",

    -- Constants
    "ACCOUNT_BINDINGS", "CHARACTER_BINDINGS",

    -- Ace3
    "LibStub",
}
```

**To run luacheck:**
```bash
# Check all Lua files
luacheck LayoutLedger/

# Check specific file
luacheck LayoutLedger/Core.lua

# Auto-fix simple issues
luacheck LayoutLedger/ --fix
```

### Git Hooks (Pre-Commit)

We provide Git hooks that automatically run code quality checks before each commit.

**Install hooks:**
```bash
# Linux/Mac/Git Bash
bash scripts/install-hooks.sh

# Windows (Command Prompt)
scripts\install-hooks.bat
```

**What the pre-commit hook does:**
1. Runs XML validation on all `.xml` files
2. Runs luacheck on all `.lua` files (if installed)
3. Blocks the commit if errors are found
4. Shows warnings but allows commit to proceed

**Hook output example:**
```
Running Layout Ledger code quality checks...

=== XML Validation ===
✅ XML validation passed

=== Lua Linting ===
✅ Lua linting passed

=== Pre-Commit Summary ===
✅ All checks passed - proceeding with commit
```

**Skip hook for emergency commits:**
```bash
git commit --no-verify -m "Emergency fix"
```

**Note:** Git hooks are local and not version controlled. Each contributor needs to run the install script after cloning.

### GitHub Actions (CI/CD)

The same pre-commit checks run automatically on GitHub for all pushes and pull requests.

**Workflow:** `.github/workflows/validate.yml`

**What runs in CI:**
1. **Pre-Commit Quality Checks** - Same hook that runs locally
   - XML validation
   - Luacheck linting
2. **TOC File Validation** - Addon-specific checks
   - Required fields present
   - Referenced files exist

**View results:**
- Check the "Actions" tab on GitHub
- Green checkmark ✅ = All checks passed
- Red X ❌ = Checks failed (see logs for details)

**Benefits:**
- Ensures all PRs meet quality standards
- Catches issues before merge
- Same checks locally and in CI
- No configuration drift

## Project Structure

```
Layout-Ledger/
├── LayoutLedger/              # Main addon directory
│   ├── Core.lua               # Main addon logic, frame setup
│   ├── Export.lua             # Data export functions
│   ├── Import.lua             # Data import functions
│   ├── Serialize.lua          # Encoding/compression
│   ├── Options.lua            # Ace3 options UI
│   ├── UI.xml                 # Main window XML
│   ├── embeds.xml             # Library includes
│   ├── LayoutLedger.toc       # Addon manifest
│   └── Libs/                  # Ace3 and other libraries
│
├── docs/                      # Documentation
│   ├── FEATURES.md            # Feature documentation
│   ├── DEVELOPMENT.md         # This file
│   └── CHANGELOG.md           # Historical changes
│
├── scripts/                   # Development tools
│   └── validate-xml.js        # XML validator
│
├── .luacheckrc                # Luacheck configuration
├── package.json               # Node.js dependencies
└── README.md                  # Project overview
```

## File Descriptions

### Core.lua
**Purpose:** Main addon initialization, event handling, UI management

**Key functions:**
- `OnInitialize()` - Set up database and commands
- `OnEnable()` - Initialize frames, register events
- `Export_OnClick()` - Handle export button with validation
- `Import_OnClick()` - Handle import with smart dialog
- `ShowSmartImportDialog()` - Display import options
- `AnalyzeImportApplicability()` - Check data compatibility
- `SaveProfile()` / `LoadProfile()` - Saved profiles (future)

### Export.lua
**Purpose:** Collect game data for export

**Key functions:**
- `GetMetadata()` - Collect character/spec/class info
- `GetActionBars()` - Export action bar slots 1-120
- `GetKeybindings()` - Export all keybindings
- `GetEditModeLayout()` - Export UI layout
- `GetMacros()` - Export character and global macros

### Import.lua
**Purpose:** Apply imported data to game

**Key functions:**
- `SetActionBars(data, mode)` - Import action bars (Override/Merge)
- `SetKeybindings(data, mode)` - Import keybindings
- `SetEditModeLayout(data, mode)` - Import UI layout
- `SetMacros(data, mode)` - Import macros (create/update)

**Handles gracefully:**
- Missing macros (skips with warning)
- Missing items
- Missing equipment sets
- Cross-character macro references

### Serialize.lua
**Purpose:** Encode and compress export data

**Uses:**
- AceSerializer for Lua table serialization
- LibDeflate for compression (DeflateCompress/Decompress)
- LibDeflate EncodeForPrint for safe string encoding

**Format:** `AceSerializer → LibDeflate Compress → EncodeForPrint → String`

### Options.lua
**Purpose:** Ace3 config UI integration

**Creates options table with:**
- Export options (what to include)
- Class profile toggle
- Future: Saved profiles management

## Testing

### Manual Testing Checklist

#### Basic Export/Import
- [ ] Export with all options checked
- [ ] Import on same character → verify all data applied
- [ ] Check that text auto-highlights on export

#### Validation
- [ ] Try exporting with nothing selected → verify error
- [ ] Try exporting with empty data → verify "nothing to export"
- [ ] Verify popup shows correct counts

#### Cross-Character Import
- [ ] Export from Character A
- [ ] Import on Character B (same class, same spec)
- [ ] Verify macros work if names match
- [ ] Verify skipped actions reported correctly

#### Cross-Spec Import
- [ ] Export from Spec A (e.g., Elemental)
- [ ] Switch to Spec B (e.g., Restoration)
- [ ] Import → verify warning shown
- [ ] Verify action bars unchecked by default
- [ ] Verify can still import macros/UI/keybindings

#### Class Profiles
- [ ] Enable "Use Class Profiles"
- [ ] Import settings
- [ ] `/reload`
- [ ] Verify revert button still enabled
- [ ] Switch to alt (same class)
- [ ] Verify revert button enabled with shared data

#### Combat Safety
- [ ] Open `/ll`
- [ ] Enter combat
- [ ] Verify window closes automatically
- [ ] Verify message shown

#### Macro Split
- [ ] Verify "Character Macros" and "Global Macros" are separate checkboxes
- [ ] Export with only one checked
- [ ] Verify import shows only that type

### Automated Testing

Currently, we don't have automated Lua tests. Future enhancement.

**Possible frameworks:**
- busted (Lua testing framework)
- WoW-specific test harness

## WoW API Reference

### Key APIs Used

**Specialization:**
```lua
GetSpecialization() → specIndex (1-4)
GetSpecializationInfo(specIndex) → specID, specName, description, icon, role, primaryStat
```

**Keybindings:**
```lua
GetCurrentBindingSet() → 1 (account) or 2 (character)
GetNumBindings() → count
GetBinding(index) → command, category, key1, key2
SetBinding(key, command) → success
SaveBindings(which) → saves to WTF
```

**Action Bars:**
```lua
GetActionInfo(slot) → actionType, id, subType
-- Slots 1-72: Default bars
-- Slots 73-120: Stance/form bars
```

**Unit Info:**
```lua
UnitClass("player") → className, classFilename, classID
UnitName("player") → name
GetRealmName() → realm
UnitLevel("player") → level
```

**Edit Mode:**
```lua
C_EditMode.GetLayouts() → layouts table
C_EditMode.ConvertLayoutInfoToString(layoutInfo) → string
C_EditMode.ConvertStringToLayoutInfo(string) → layoutInfo
C_EditMode.SaveLayouts(layouts) → applies changes
```

### API Documentation Sources

- **Warcraft Wiki:** https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
- **WoWpedia:** https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- **Blizzard API Docs:** In-game `/api` command

## Common Issues & Solutions

### Issue: Frame not found
**Symptoms:** `LayoutLedger: Frame not initialized`
**Cause:** XML frames not loaded yet when code runs
**Solution:** Frame initialization moved to `OnEnable()` (PLAYER_LOGIN event)

### Issue: Backdrop deprecated errors
**Symptoms:** XML parsing errors about Backdrop element
**Cause:** WoW 9.0+ deprecated `<Backdrop>` XML element
**Solution:** Use `BackdropTemplate` inheritance and set in Lua with `SetBackdrop()`

### Issue: Macro import fails cross-character
**Symptoms:** Action bars empty after import on different character
**Cause:** Macro IDs differ across characters
**Solution:** Store macro names in export, lookup by name on import

### Issue: Combat lockdown errors
**Symptoms:** Cannot import/export during combat
**Cause:** Protected UI actions blocked in combat
**Solution:** Detect combat and close windows automatically

### Issue: Export string too large
**Symptoms:** Cannot paste full export string
**Cause:** String exceeds EditBox max letters
**Solution:** LibDeflate compression + EncodeForPrint reduces size significantly

## Git Workflow

### Branch Strategy

- `main` - Stable, tested code
- `feature/*` - New features
- `fix/*` - Bug fixes

### Commit Message Format

```
<type>: <subject>

<body>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code restructure
- `docs` - Documentation
- `test` - Tests
- `chore` - Maintenance

### Pull Request Process

1. Create feature branch
2. Make changes and test thoroughly
3. Run validation tools (XML, luacheck)
4. Commit with descriptive messages
5. Push and create PR
6. Review and merge

## Release Process

1. Update version in `LayoutLedger.toc`
2. Update `CHANGELOG.md`
3. Test all features in-game
4. Create git tag: `v1.0.0`
5. Package addon (exclude dev files)
6. Upload to CurseForge/WoWInterface

### TOC File Version

```
## Version: 1.0.0
## X-Date: 2025-03-15
```

## Performance Considerations

### Database Size

- Export strings compressed with LibDeflate
- Saved profiles stored in global namespace (account-wide)
- Consider max profile limit (50-100) to avoid bloat

### Memory Usage

- Addon loads all libraries upfront (Ace3, LibDeflate)
- Smart import dialog creates frames dynamically
- Frames cleaned up when hidden

### Combat Performance

- No processing during combat (windows close)
- No combat events registered
- Import/export disabled in combat

## Debugging

### Enable Debug Mode

```lua
-- In-game console
/ll debug
```

**Shows:**
- Frame status
- ImportBox status
- RevertButton status
- Database status
- Module status (Export, Import, Serialize)

### Common Debug Commands

```lua
-- Check database
/dump LayoutLedger.db.profile
/dump LayoutLedger.db.global.savedProfiles

-- Check frame
/dump LayoutLedgerFrame:IsShown()

-- Check current spec
/dump GetSpecialization()
/dump GetSpecializationInfo(GetSpecialization())

-- Check keybinding scope
/dump GetCurrentBindingSet()
```

### Lua Errors

Enable Lua errors in WoW:
```
/console scriptErrors 1
```

Or use addon: BugGrabber + BugSack

## Contributing

See `README.md` for contribution guidelines.

**Key points:**
- Follow Lua style conventions
- Run validation tools before committing
- Write descriptive commit messages
- Test changes in-game
- Document new features

## Resources

### WoW Addon Development
- [Wowpedia Addon Guide](https://wowpedia.fandom.com/wiki/Making_a_WoW_API_AddOn)
- [Ace3 Documentation](https://www.wowace.com/projects/ace3)
- [WoW Interface](https://www.wowinterface.com/)

### Lua Resources
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)
- [Programming in Lua](https://www.lua.org/pil/contents.html)

### Tools
- [luacheck](https://github.com/mpeterv/luacheck) - Lua linter
- [VSCode Lua Extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua)
- [WoW AddOn Studio](https://github.com/Marlamin/WoWAddOnStudio)
