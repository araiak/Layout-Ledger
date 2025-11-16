# Claude Development Rules

This document contains rules and guidelines for AI assistants (Claude, GPT, etc.) working on the Layout Ledger project.

## 📋 Core Principles

1. **Read First, Write Second** - Always read existing code before making changes
2. **Validate Everything** - Run XML validation and luacheck before committing
3. **Test In-Game** - Changes must be tested in actual WoW client when possible
4. **Document Changes** - Update relevant documentation with every feature
5. **Follow WoW Standards** - Respect WoW API limitations and conventions

## 🗺️ Navigation

**Start Here:** [KNOWLEDGE_GRAPH.md](KNOWLEDGE_GRAPH.md) - Complete project structure and concept map

**For Users:** [docs/FEATURES.md](docs/FEATURES.md) - Feature documentation
**For Developers:** [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) - Development guide
**For History:** [docs/CHANGELOG.md](docs/CHANGELOG.md) - Version history

## 💻 Code Style Guidelines

### Lua Code Style

```lua
-- Function naming: camelCase for methods, PascalCase for module functions
function addon:methodName()  -- Addon method
end

function ModuleName.FunctionName()  -- Module function
end

-- Variable naming: camelCase
local myVariable = "value"
local isEnabled = true

-- Constants: UPPER_CASE
local MAX_PROFILES = 50

-- Table constructors: spaces after commas
local data = {
    key1 = value1,
    key2 = value2,
}

-- Conditional spacing
if condition then
    -- code
elseif otherCondition then
    -- code
else
    -- code
end

-- String formatting: prefer string.format for complex strings
local message = string.format("Imported %d macros from %s", count, characterName)

-- Comments: Explain WHY, not WHAT
-- Save to class namespace if enabled (allows cross-character sharing)
if self.db.profile.useClassProfiles then
    self.db.class.lastSettings = currentData
end
```

### XML Style

```xml
<!-- Consistent indentation: 4 spaces -->
<Frame name="MyFrame" parent="UIParent">
    <Size x="400" y="300"/>
    <Anchors>
        <Anchor point="CENTER"/>
    </Anchors>
</Frame>

<!-- Attribute order: name, parent, inherits, other attributes -->
<CheckButton name="$parentMyCheck" inherits="UICheckButtonTemplate">

<!-- Self-closing tags when no children -->
<Size x="100" y="50"/>

<!-- Comments above elements -->
<!-- Main export section -->
<Frame name="$parentExportSection">
```

## ✅ Quality Checks (ALWAYS RUN)

### Automatic Pre-Commit Hooks

**Install Git hooks (one-time setup):**
```bash
bash scripts/install-hooks.sh
```

The pre-commit hook automatically runs:
- XML validation (blocks commit on errors)
- Luacheck linting (blocks commit on errors, if installed)

**Skip hook only for emergencies:**
```bash
git commit --no-verify -m "Emergency fix"
```

### Manual Quality Checks
```bash
# 1. Validate XML
node scripts/validate-xml.js

# 2. Check Lua (if luacheck installed)
luacheck LayoutLedger/

# 3. Verify no syntax errors
grep -r "syntax error" LayoutLedger/*.lua
```

### Required Validation Results
- ✅ XML: 0 errors (warnings OK if documented)
- ✅ Lua: No errors from luacheck
- ✅ Git: No unintended files staged
- ✅ Hooks: Pre-commit hook passes

### CI/CD (GitHub Actions)

**The same pre-commit hook runs automatically on GitHub.**

**Workflow:** `.github/workflows/validate.yml`

**When it runs:**
- Every push to `main` or `develop` branches
- Every pull request to `main`

**What it checks:**
1. Pre-commit quality checks (XML + Lua)
2. TOC file validation (addon-specific)

**Where to see results:**
- GitHub Actions tab: `https://github.com/Araiak/Layout-Ledger/actions`
- PR checks show ✅ or ❌ automatically
- Status badge on README shows current status

**If CI fails:**
- Review the logs in GitHub Actions
- Fix the issues locally
- Run validation tools to verify fix
- Push the fix

**Benefits:**
- Same checks locally and in CI (no configuration drift)
- Prevents bad code from being merged
- Automatic quality gate for all PRs

## 🎯 WoW-Specific Rules

### API Usage

1. **Always verify API existence** before using
   - Check [Warcraft Wiki](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
   - Never assume an API exists based on logical naming

2. **Handle API deprecation**
   - Check patch notes for deprecated APIs
   - Use modern replacements (e.g., `BackdropTemplate` not `<Backdrop>`)

3. **Add new APIs to .luacheckrc**
   ```lua
   read_globals = {
       "NewAPIFunction",  -- Add with comment about purpose
   }
   ```

### Frame Initialization

```lua
-- ❌ WRONG: Frames may not exist in OnInitialize
function addon:OnInitialize()
    self.frame = _G["LayoutLedgerFrame"]  -- May be nil!
end

-- ✅ CORRECT: Use OnEnable (PLAYER_LOGIN)
function addon:OnEnable()
    self.frame = _G["LayoutLedgerFrame"]  -- Guaranteed to exist
    if not self.frame then
        print("Error: Frame not found")
        return
    end
end
```

### Combat Lockdown

```lua
-- Always check combat before protected actions
if InCombatLockdown and InCombatLockdown() then
    print("Cannot perform action in combat")
    return
end

-- Close windows on combat start
function addon:PLAYER_REGEN_DISABLED()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end
end
```

### Database Access

```lua
-- Always check db exists
if not self.db then
    return
end

-- Use proper namespace
self.db.profile.export.actionBars  -- Character-specific
self.db.class.lastSettings          -- Class-wide
self.db.global.savedProfiles        -- Account-wide
```

## 📝 Documentation Rules

### When to Update Documentation

**Always update these files when:**

| Change Type | Update Files |
|-------------|--------------|
| New feature | `docs/FEATURES.md`, `docs/CHANGELOG.md`, `README.md` |
| Bug fix | `docs/CHANGELOG.md` |
| API change | `docs/DEVELOPMENT.md` (API Reference section) |
| Code structure change | `KNOWLEDGE_GRAPH.md` |
| New file added | `KNOWLEDGE_GRAPH.md`, `docs/DEVELOPMENT.md` |

### Documentation Style

**Features Documentation:**
```markdown
## Feature Name

### How It Works
[Explanation]

### How to Use
1. Step one
2. Step two

### Example
[Code or UI example]

### Technical Details
[Implementation notes]
```

**Changelog Format:**
```markdown
### Added
- Feature description with benefit

### Changed
- What changed and why

### Fixed
- Bug description and solution
```

## 🔧 Common Tasks

### Adding a New Export Option

**Full checklist:**
1. ✅ Add checkbox to `UI.xml` in ExportSection
2. ✅ Add label FontString to `UI.xml`
3. ✅ Add to `addon.defaults.profile.export` in `Core.lua`
4. ✅ Add Get function to `Export.lua`
5. ✅ Add Set function to `Import.lua`
6. ✅ Update `Export_OnClick()` to include new data
7. ✅ Update `SmartImport_OnClick()` to handle new data
8. ✅ Update `PopulateImportOptions()` to show new option
9. ✅ Add to `RefreshUI()` for checkbox state
10. ✅ Update `docs/FEATURES.md`
11. ✅ Update `docs/CHANGELOG.md`
12. ✅ Run validation tools
13. ✅ Test in-game

### Adding a New WoW API Function

```lua
// 1. Add to .luacheckrc
read_globals = {
    "NewFunction",  -- Brief description of what it does
}

// 2. Add to docs/DEVELOPMENT.md API Reference section
**NewFunction:**
NewFunction(param) → result
Description of what it does and when to use it

// 3. Use in code with error handling
local result = NewFunction(param)
if not result then
    -- Handle failure
end
```

### Fixing a Bug

**Process:**
1. ✅ Reproduce the bug
2. ✅ Identify root cause (document in code comment)
3. ✅ Implement fix with explanation comment
4. ✅ Test fix in-game
5. ✅ Update `docs/CHANGELOG.md`
6. ✅ Run validation tools
7. ✅ Commit with descriptive message

**Example commit:**
```
fix: action bars not importing on different spec

Root cause: Spec index comparison was using string vs number
Solution: Convert spec index to number before comparison

Fixes #123
```

## 🚫 What NOT to Do

### Never

1. ❌ **Never skip validation tools** - Always run XML and Lua checks
2. ❌ **Never assume API exists** - Always verify on Warcraft Wiki first
3. ❌ **Never hardcode values** - Use constants or database
4. ❌ **Never ignore combat lockdown** - Always check `InCombatLockdown()`
5. ❌ **Never break backward compatibility** - Support legacy imports
6. ❌ **Never commit without testing** - Test in actual WoW client
7. ❌ **Never use global variables** - Always scope properly
8. ❌ **Never modify library files** - Libraries are external dependencies

### Be Careful With

1. ⚠️ **Frame timing** - Initialize in OnEnable, not OnInitialize
2. ⚠️ **Database writes** - Always check db exists first
3. ⚠️ **String encoding** - Use LibDeflate EncodeForPrint for export strings
4. ⚠️ **Macro IDs** - Store names too, IDs differ across characters
5. ⚠️ **Spec detection** - Handle nil values (new characters may have no spec)
6. ⚠️ **XML parent references** - Use `$parent` prefix correctly

## 🧪 Testing Requirements

### Minimum Testing for Features

**Export Feature:**
- [ ] Export with option checked
- [ ] Export with option unchecked
- [ ] Verify export string is valid
- [ ] Verify counts shown in confirmation
- [ ] Test with empty data (no macros, no action bars, etc.)

**Import Feature:**
- [ ] Import on same character
- [ ] Import on different character (same class)
- [ ] Import on different character (different class)
- [ ] Import on different spec
- [ ] Verify smart dialog shows correctly
- [ ] Verify warnings appear when appropriate
- [ ] Test revert after import

**UI Changes:**
- [ ] Open/close window multiple times
- [ ] Resize window (if resizable)
- [ ] Drag window around screen
- [ ] Test in combat (should close)
- [ ] Test with different UI scales
- [ ] `/reload` and verify state persists

## 📦 Commit Message Format

```
<type>: <subject>

<body>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code restructure without behavior change
- `docs` - Documentation only
- `test` - Tests only
- `chore` - Maintenance (dependencies, build, etc.)
- `style` - Code style/formatting

**Examples:**
```
feat: add saved profiles database structure

Added global.savedProfiles namespace to AceDB defaults.
Allows account-wide storage of named layout profiles.

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

```
fix: combat lockdown closing smart import dialog

Added PLAYER_REGEN_DISABLED handler to close both main
frame and smart import dialog when entering combat.
Prevents Midnight expansion combat lockdown errors.

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

## 🎓 Learning Resources

### Required Reading Before Contributing

1. **Project Structure**
   - Read `KNOWLEDGE_GRAPH.md` completely
   - Understand data flow diagrams
   - Review feature implementation status

2. **WoW Addon Basics**
   - [WoW Addon Tutorial](https://wowpedia.fandom.com/wiki/Making_a_WoW_API_AddOn)
   - [Ace3 Documentation](https://www.wowace.com/projects/ace3)
   - [WoW API Reference](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)

3. **Code Examples**
   - Read `Core.lua` - Main addon structure
   - Read `Export.lua` - Data collection patterns
   - Read `Import.lua` - Data application patterns

### When Stuck

1. **Check the knowledge graph** - `KNOWLEDGE_GRAPH.md` has navigation
2. **Check existing code** - Likely similar code already exists
3. **Check Warcraft Wiki** - For API questions
4. **Check docs/CHANGELOG.md** - See how similar features were implemented
5. **Ask the user** - When uncertain about design decisions

## 🔄 Workflow Checklist

### For Every Code Change

- [ ] Read relevant existing code first
- [ ] Make changes following code style
- [ ] Add/update comments explaining WHY
- [ ] Run XML validation: `node scripts/validate-xml.js`
- [ ] Run luacheck (if installed): `luacheck LayoutLedger/`
- [ ] Update relevant documentation files
- [ ] Update `KNOWLEDGE_GRAPH.md` if structure changed
- [ ] Test changes in-game (if possible)
- [ ] Write descriptive commit message
- [ ] Review changes before committing

### For New Features

- [ ] Create design document in `Design/` (if complex)
- [ ] Implement feature following checklist
- [ ] Add to `docs/FEATURES.md`
- [ ] Add to `docs/CHANGELOG.md` [Unreleased] section
- [ ] Update `README.md` if major feature
- [ ] Update `KNOWLEDGE_GRAPH.md` concept map
- [ ] Create testing checklist
- [ ] Test all scenarios
- [ ] Document known limitations

### For Bug Fixes

- [ ] Reproduce bug
- [ ] Document root cause in code comment
- [ ] Implement fix with explanation
- [ ] Test fix thoroughly
- [ ] Update `docs/CHANGELOG.md`
- [ ] Update `docs/FEATURES.md` if behavior changed
- [ ] Commit with issue reference (if applicable)

## 📊 Quality Standards

### Code Quality
- Max line length: 120 characters
- Max cyclomatic complexity: 15
- No global variables (except `LayoutLedger`)
- No hardcoded strings for user-facing text
- All error cases handled

### Documentation Quality
- Every feature documented in `docs/FEATURES.md`
- All API functions documented in `docs/DEVELOPMENT.md`
- Code comments explain WHY, not WHAT
- Examples provided for complex features
- Consistent markdown formatting

### Testing Quality
- All features tested in-game
- Edge cases considered
- Cross-character testing performed
- Combat lockdown tested
- Revert functionality tested

## 🎯 Success Criteria

**A change is ready to merge when:**

1. ✅ All validation tools pass (0 errors)
2. ✅ Code follows style guidelines
3. ✅ Documentation updated appropriately
4. ✅ Testing checklist completed
5. ✅ No known bugs or limitations undocumented
6. ✅ Backward compatibility maintained
7. ✅ Commit message descriptive and formatted correctly

---

**Remember:** Quality over speed. Take time to do it right.

---

## 🔢 Export Format Versioning

### Why Sequential Migrations?

**We use sequential (chain) migrations, not direct (jump) migrations.**

**Sequential:** 0.1.0 → 0.2.0 → 0.3.0 → ... → current
**Direct:** 0.1.0 → current (jumping all intermediate versions)

**✅ Advantages of Sequential:**
- ✅ **Easier to maintain** - Each migration only knows about the previous version
- ✅ **Less code duplication** - Same transformation logic not repeated
- ✅ **Easier to test** - Test one migration at a time
- ✅ **Industry standard** - Used by Django, Rails, Flyway, and other major frameworks
- ✅ **Natural progression** - Follows development history
- ✅ **Simpler debugging** - Can pinpoint which migration fails

**❌ Disadvantages of Sequential:**
- ❌ **Slightly slower for very old versions** - Must run through all migrations

**For LayoutLedger:** The "slowness" is negligible (we're talking milliseconds), and the maintainability benefits are huge.

**⚠️ User Warning:** If a user has a very old export (e.g., from 5+ versions ago), we log how many migrations ran so they can see the process.

### Version Numbering Scheme

We use **Semantic Versioning (SemVer)** for export formats:

```
MAJOR.MINOR.PATCH (e.g., 0.1.0)
```

**When to increment:**

- **MAJOR**: Breaking changes that require complex migration or remove features
  - Example: Removing a field, changing data structure fundamentally
  - Example: Changing from table to string format for a major field

- **MINOR**: Adding new fields or features (backwards compatible)
  - Example: Adding a new export category (like CVars)
  - Example: Adding optional metadata fields

- **PATCH**: Bug fixes that don't change the format
  - Example: Fixing incorrect data being exported
  - Example: Fixing import logic without changing data structure

### Current Version Location

The current export version is defined in `Core.lua`:

```lua
addon.EXPORT_VERSION = "0.1.0"
```

**⚠️ CRITICAL RULE:** This is the **ONLY** place the version number should be set. All other code must reference this constant.

---

## 📋 Version Management Rules

### Rule 1: Never Break Backwards Compatibility Without Migration

**ALWAYS** provide a migration path for existing export strings.

✅ **GOOD:**
```lua
-- Add migration code in MigrateImportData()
if version == "0.1.0" then
    -- Migrate field X to new format
    data.newField = TransformOldField(data.oldField)
    data.version = "0.2.0"
end
```

❌ **BAD:**
```lua
-- Just changing the format without migration
exportData.myField = newFormat()  -- Old exports will break!
```

### Rule 2: Update Version Documentation Immediately

When changing `EXPORT_VERSION`, **IMMEDIATELY** update the documentation block in `Core.lua`:

```lua
--[[
EXPORT FORMAT VERSION HISTORY

Version X.Y.Z (Date: YYYY-MM-DD):
- Description of what changed
- List of added fields
- List of removed/changed fields
- Migration notes

Version 0.1.0 (Initial versioned format):
- Added version field to exports
- ...
]]
```

### Rule 3: Test Old Exports After Version Changes

Before committing a version change:

1. ✅ Export data with OLD version
2. ✅ Save export string to a file
3. ✅ Update version constant
4. ✅ Import old export → Verify migration works
5. ✅ Export with NEW version
6. ✅ Import new export → Verify it works

### Rule 4: Add Version to All Export Functions

Every export must include the version:

```lua
local exportData = {
    version = self.EXPORT_VERSION,  -- ✅ REQUIRED
    metadata = self.Export.GetMetadata(),
    -- ... rest of data
}
```

---

## 🔄 Migration Procedures

### Adding a New Field to Exports

**Procedure:**

1. **Decide if this is MINOR or MAJOR**
   - Adding optional field = MINOR (0.1.0 → 0.2.0)
   - Removing/changing existing field = MAJOR (0.1.0 → 1.0.0)

2. **Update Core.lua version constant:**
   ```lua
   addon.EXPORT_VERSION = "0.2.0"
   ```

3. **Update version history documentation:**
   ```lua
   Version 0.2.0 (Date: 2025-01-16):
   - Added: myNewField to export data
   - Field type: table
   - Scope: character-wide
   ```

4. **Add export code:**
   ```lua
   if profile.myNewFeature then
       exportData.myNewField = self.Export.GetMyNewField()
   end
   ```

5. **Add import code:**
   ```lua
   if data.myNewField then
       self.Import.SetMyNewField(data.myNewField, "Override")
   end
   ```

6. **NO MIGRATION NEEDED** if the field is purely additive
   - Old exports won't have the field (nil)
   - Import code already checks `if data.myNewField`
   - Everything works!

### Changing an Existing Field Format

**Procedure:**

1. **Bump version (MINOR or MAJOR):**
   ```lua
   addon.EXPORT_VERSION = "0.2.0"  -- or "1.0.0" if breaking
   ```

2. **Document the change:**
   ```lua
   Version 0.2.0:
   - CHANGED: uiLayout from string to table format
   - Migration: Legacy strings auto-converted to {layoutString, layoutName, layoutType}
   ```

3. **Update export to new format:**
   ```lua
   exportData.uiLayout = {
       layoutString = layoutString,
       layoutName = layoutName,
       layoutType = layoutType
   }
   ```

4. **Add migration code in `MigrateImportData()`:**
   ```lua
   if version == "0.1.0" then
       print("LayoutLedger: Migrating from v0.1.0 to v0.2.0")

       -- Transform old format to new format
       if data.uiLayout and type(data.uiLayout) == "string" then
           data.uiLayout = {
               layoutString = data.uiLayout,
               layoutName = "Imported Layout",
               layoutType = 1
           }
       end

       data.version = "0.2.0"
       print("LayoutLedger: Migration to v0.2.0 complete")
   end
   ```

5. **Update import code to handle new format:**
   ```lua
   -- Import code should now expect table format
   if data.uiLayout then
       local layoutString = data.uiLayout.layoutString
       local layoutName = data.uiLayout.layoutName
       -- ...
   end
   ```

### Removing a Field

**⚠️ This is a MAJOR version bump!**

**Procedure:**

1. **Bump MAJOR version:**
   ```lua
   addon.EXPORT_VERSION = "1.0.0"
   ```

2. **Document the removal:**
   ```lua
   Version 1.0.0:
   - REMOVED: deprecatedField (no longer supported)
   - Reason: Feature removed from game API
   ```

3. **Add migration that removes the field:**
   ```lua
   if version == "0.2.0" then
       print("LayoutLedger: Migrating from v0.2.0 to v1.0.0")

       -- Remove deprecated field
       if data.deprecatedField then
           print("LayoutLedger: WARNING - deprecatedField is no longer supported and will be ignored")
           data.deprecatedField = nil
       end

       data.version = "1.0.0"
   end
   ```

4. **Remove export code**
5. **Remove import code**

### Migration System Architecture

**We use a centralized migration system in `Migrations.lua` based on industry best practices (Django, Rails, Flyway).**

**Key Design Decisions:**

1. ✅ **Sequential Migrations** - Migrations run in order (0.1.0 → 0.2.0 → 0.3.0)
   - Industry standard (used in Django, Rails, etc.)
   - Easier to maintain (each migration only knows about previous version)
   - Slightly slower for very old versions, but negligible for game addons

2. ✅ **Version Everything** - Both database and import strings have versions
   - Database version: `db.global.dataVersion`
   - Import string version: `data.version`

3. ✅ **Automatic Migration** - Happens transparently
   - Database: Migrated on addon load (OnInitialize)
   - Import strings: Migrated when import button clicked

4. ✅ **Validation** - Data validated before and after migrations
   - Ensures data integrity
   - Catches migration bugs early

### Adding a Migration (REQUIRED for every version change)

**⚠️ CRITICAL:** When you change `EXPORT_VERSION`, you **MUST** add a migration function to `Migrations.lua`.

**File:** `LayoutLedger/Migrations.lua`

**Function:** `MigrateImportDataVersion(data, fromVersion)`

**Template:**

```lua
-- In Migrations.lua, add to MigrateImportDataVersion function:

-- X.Y.Z -> X.Y.Z+1
if fromVersion == "0.1.0" then
    print("LayoutLedger: Migrating from v0.1.0 to v0.2.0")

    -- Apply transformations here
    -- Example: Convert field format
    if data.myField and type(data.myField) == "string" then
        data.myField = {
            value = data.myField,
            newMetadata = "default"
        }
    end

    -- Update version
    data.version = "0.2.0"
    return "0.2.0", nil
end
```

### Database Migrations

**If you change the database structure**, add a migration to `Migrations.registry`:

**File:** `LayoutLedger/Migrations.lua`

**Location:** `Migrations.registry` table at the top

**Template:**

```lua
-- In Migrations.lua, add to registry table:

LayoutLedger.Migrations.registry = {
    ["0.1.0"] = function(db)
        -- Transform database from 0.1.0 to 0.2.0
        print("LayoutLedger: Migrating database from v0.1.0 to v0.2.0")

        -- Example: Add new field to all saved profiles
        if db.global and db.global.savedProfiles then
            for _, profile in pairs(db.global.savedProfiles) do
                profile.newField = "defaultValue"
            end
        end

        -- Return: success, newVersion, error
        return true, "0.2.0", nil
    end,
}
```

**⚠️ IMPORTANT:** Migrations are applied sequentially. A v0.1.0 database will go through ALL migrations (0.1.0→0.2.0→0.3.0→...) to reach current version.

### Migration Helpers

**Available in `Migrations.lua`:**

```lua
-- Validate database structure
local valid, error = Migrations.ValidateDatabase(db, version)

-- Validate import data structure
local valid, error = Migrations.ValidateImportData(data, version)

-- Deep copy a table (for backup)
local copy = Migrations.DeepCopy(originalTable)

-- Check if table has field
local hasIt = Migrations.HasField(table, "fieldName")

-- Check type
local isCorrect = Migrations.IsType(value, "table")

-- Parse version into major, minor, patch
local major, minor, patch = Migrations.ParseVersion("0.2.1")

-- Compare versions (-1, 0, 1)
local result = Migrations.CompareVersions("0.1.0", "0.2.0")  -- returns -1
```

### File Organization for Migrations

**Where migration code lives:**

| What | Where | Why |
|------|-------|-----|
| Version constant | `Core.lua` (line 7) | Single source of truth |
| Version history docs | `Core.lua` (comment block at top) | Next to version constant |
| **Import migrations** | `Migrations.lua` (`MigrateImportDataVersion()`) | Centralized migration logic |
| **Database migrations** | `Migrations.lua` (`registry` table) | Centralized migration logic |
| **Validation logic** | `Migrations.lua` (`ValidateDatabase()`, `ValidateImportData()`) | Centralized validation |
| Migration helpers | `Migrations.lua` (helper functions) | Reusable utilities |
| Migration caller (DB) | `Core.lua` (`OnInitialize()`) | Runs migrations on load |
| Migration caller (Import) | `Core.lua` (`Import_OnClick()` → `MigrateImportData()`) | Runs before import |

**⚠️ NEVER edit migration logic in Core.lua directly!** Always add migrations to `Migrations.lua`.

---

## 🧪 Testing Version Changes

### Before Committing Version Changes

**Checklist:**

- [ ] Export data with **OLD** addon version
- [ ] Save export string to a file
- [ ] Update `EXPORT_VERSION` constant
- [ ] Update version history documentation
- [ ] Add migration code (if needed)
- [ ] Reload addon
- [ ] Import OLD export string → Check console for migration messages
- [ ] Verify imported data is correct
- [ ] Export with **NEW** version
- [ ] Import new export → Verify it works
- [ ] Test all export types:
  - [ ] Regular export
  - [ ] Class profile export
  - [ ] Legacy export (if applicable)

### Test Cases for Migrations

Create test scenarios for each migration:

**Example:**

```lua
-- Test case: Legacy uiLayout string migration
-- Input: { uiLayout = "ABC123..." }
-- Expected: { uiLayout = { layoutString = "ABC123...", layoutName = "Imported Layout", layoutType = 1 } }
```

**How to test:**

1. Manually create an export with old format (edit saved variable or use old addon version)
2. Import it
3. Check console output for migration messages
4. Verify data was transformed correctly

---

## 📚 Version History Documentation Format

Use this template in `Core.lua`:

```lua
--[[
EXPORT FORMAT VERSION HISTORY

Version X.Y.Z (Date: YYYY-MM-DD):
- Added: List new fields/features
- Changed: List modified fields/behaviors
- Removed: List deprecated fields
- Migration: Describe migration logic if complex
- Breaking: YES/NO

Example:

Version 0.2.0 (Date: 2025-01-16):
- Added: cvars field (console variables like uiScale)
- Changed: uiLayout from string to table {layoutString, layoutName, layoutType}
- Migration: Legacy uiLayout strings auto-converted to table format
- Breaking: NO (fully backwards compatible)
]]
```

---

## ✅ Version Update Checklist

Use this checklist for every version change:

```markdown
## Version X.Y.Z Checklist

### Pre-Update
- [ ] Exported test data with OLD version
- [ ] Saved test export strings to files

### Code Changes
- [ ] Updated `EXPORT_VERSION` constant in Core.lua
- [ ] Updated version history documentation in Core.lua
- [ ] Added/modified export code
- [ ] Added/modified import code
- [ ] **Added migration to Migrations.lua (REQUIRED)**
  - [ ] Added to `MigrateImportDataVersion()` for import strings
  - [ ] Added to `Migrations.registry` for database (if db structure changed)
  - [ ] Added validation to `ValidateImportData()` (if needed)
  - [ ] Added validation to `ValidateDatabase()` (if needed)
- [ ] Updated UI checkboxes (if new category)
- [ ] Updated database defaults (if needed)

### Testing
- [ ] Imported OLD export (pre-version-change)
- [ ] Verified migration worked (check console)
- [ ] Exported with NEW version
- [ ] Imported NEW export
- [ ] Tested regular export
- [ ] Tested class profile export
- [ ] Verified all categories import correctly

### Documentation
- [ ] Updated CLAUDE.md (if procedure changed)
- [ ] Updated docs/CHANGELOG.md
- [ ] Updated README.md (if user-facing feature)

### Commit
- [ ] Commit message follows convention: `feat/fix: Description (vX.Y.Z)`
```

---

## 🚫 Version Management Don'ts

### NEVER

- ❌ Remove migration code for old versions (keep forever)
- ❌ Change version in multiple places (use constant)
- ❌ Skip testing old exports after version bump
- ❌ Make breaking changes in MINOR/PATCH versions
- ❌ Forget to document version changes
- ❌ Assume users will re-export everything (they won't!)
- ❌ Use hardcoded version strings anywhere except the constant

### ALWAYS

- ✅ Test migrations with real old export data
- ✅ Log migration steps to console for debugging
- ✅ Document WHY a field changed, not just WHAT changed
- ✅ Use semantic versioning correctly
- ✅ Keep migration code even after several versions
- ✅ Update version history documentation immediately
- ✅ Add backwards compatibility checks in import code

---

## 📖 Export Format Documentation

The complete export format specification is documented in `Core.lua`:

```lua
--[[
EXPORT FORMAT VERSION HISTORY

Version 0.1.0 (Initial versioned format):
- Added version field to exports
- Export data structure:
  {
    version = "0.1.0",
    exportType = nil (regular export) or "classProfile",
    metadata = {
      exportDate, addonVersion, characterName, realmName, characterLevel,
      className, classID, specID, specName, specIndex, keybindingScope
    },
    actionBars = { [slot] = { type, id, subType, macroName } },
    keybindings = { [command] = { key1, key2, category } },
    uiLayout = {
      layoutString = "...",
      layoutName = "...",
      layoutType = 0-3  -- 0=Preset, 1=Account, 2=Character, 3=Override
    },
    cooldownLayout = "...",  -- String from C_CooldownViewer
    cvars = { [cvarName] = value },  -- Console variables
    characterMacros = { { name, icon, body } },
    globalMacros = { { name, icon, body } },
    classProfile = {  -- Only present if exportType == "classProfile"
      characterSettings = { keybindings, uiLayout, characterMacros, globalMacros, cvars },
      specSettings = { [specID] = { actionBars, cooldownLayout } }
    }
  }

Pre-versioning (Legacy):
- No version field
- uiLayout was a plain string (not a table with metadata)
- All other fields same as 0.1.0
]]
```

---

**Last Updated:** 2025-01-16
**Document Version:** 2.0
**Current Export Version:** 0.1.0
