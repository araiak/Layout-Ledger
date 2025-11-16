-- LayoutLedger Migration System
-- Handles backwards compatibility for database and import formats
-- Based on industry best practices (Django, Rails, Flyway)

LayoutLedger.Migrations = {}

--[[
MIGRATION PHILOSOPHY:

1. Sequential Migrations: Migrations run in order (0.1.0 -> 0.2.0 -> 0.3.0)
   - Easier to maintain (each migration only knows about previous version)
   - Standard in Django, Rails, and other frameworks
   - Slightly slower for very old versions, but negligible for game addons

2. Version Everything: Both database and import strings have versions
   - Database version tracked in db.global.dataVersion
   - Import string version in data.version field

3. Atomic Migrations: Each migration either fully succeeds or fully fails
   - Use pcall() to catch errors
   - Log success/failure

4. Validation: Always validate data before and after migration
   - Check required fields exist
   - Verify data types are correct
]]

-- Migration registry: Define all migrations here
-- Each migration is a function that transforms data from version N to N+1
LayoutLedger.Migrations.registry = {
    -- Example:
    -- ["0.1.0"] = function(data)
    --     -- Transform from 0.1.0 to 0.2.0
    --     -- Return: success (boolean), newVersion (string), error (string or nil)
    -- end,
}

---
-- Database Migration Helpers
---

-- Get current database version
function LayoutLedger.Migrations.GetDatabaseVersion(db)
    if not db or not db.global then
        return nil
    end
    return db.global.dataVersion or "legacy"
end

-- Set database version
function LayoutLedger.Migrations.SetDatabaseVersion(db, version)
    if not db or not db.global then
        return false
    end
    db.global.dataVersion = version
    return true
end

-- Validate database structure for a specific version
function LayoutLedger.Migrations.ValidateDatabase(db, version)
    if not db then
        return false, "Database is nil"
    end

    -- Version-specific validation
    if version == "0.1.0" or version == LayoutLedger.EXPORT_VERSION then
        -- Check required namespaces exist
        if not db.profile then
            return false, "Missing db.profile namespace"
        end
        if not db.char then
            return false, "Missing db.char namespace"
        end
        if not db.class then
            return false, "Missing db.class namespace"
        end
        if not db.global then
            return false, "Missing db.global namespace"
        end

        -- Check required fields in profile
        if not db.profile.export then
            return false, "Missing db.profile.export"
        end

        -- All checks passed
        return true, nil
    end

    -- Unknown version
    return false, "Unknown version: " .. tostring(version)
end

-- Migrate database from old version to current version
function LayoutLedger.Migrations.MigrateDatabase(db)
    local currentVersion = LayoutLedger.Migrations.GetDatabaseVersion(db)
    local targetVersion = LayoutLedger.EXPORT_VERSION

    print("LayoutLedger: Database version check:")
    print("  Current:", tostring(currentVersion))
    print("  Target:", tostring(targetVersion))

    -- Already at current version
    if currentVersion == targetVersion then
        print("LayoutLedger: Database is up to date")
        return true
    end

    -- Legacy database (no version field)
    if currentVersion == "legacy" then
        print("LayoutLedger: Migrating legacy database to v0.1.0")

        -- Legacy databases need no migration (0.1.0 is first versioned format)
        -- Just set the version
        LayoutLedger.Migrations.SetDatabaseVersion(db, "0.1.0")
        currentVersion = "0.1.0"

        print("LayoutLedger: Database migrated to v0.1.0")
    end

    -- Run sequential migrations until we reach target version
    local migrationsRan = 0
    local maxIterations = 100  -- Safety limit to prevent infinite loops

    while currentVersion ~= targetVersion and migrationsRan < maxIterations do
        -- Find migration for current version
        local migrationFunc = LayoutLedger.Migrations.registry[currentVersion]

        if not migrationFunc then
            -- No migration defined - this might be OK if we're at the latest version
            -- Check if we just need to update the version number
            if LayoutLedger.Migrations.ValidateDatabase(db, targetVersion) then
                print("LayoutLedger: No migration needed, updating version to", targetVersion)
                LayoutLedger.Migrations.SetDatabaseVersion(db, targetVersion)
                return true
            else
                print("LayoutLedger: ERROR - No migration defined from", currentVersion, "to next version")
                return false
            end
        end

        -- Run migration
        print("LayoutLedger: Running migration from", currentVersion)
        local success, newVersion, error = pcall(migrationFunc, db)

        if not success then
            print("LayoutLedger: ERROR - Migration failed:", tostring(newVersion))
            return false
        end

        if error then
            print("LayoutLedger: ERROR - Migration error:", error)
            return false
        end

        -- Validate after migration
        local valid, validationError = LayoutLedger.Migrations.ValidateDatabase(db, newVersion)
        if not valid then
            print("LayoutLedger: ERROR - Database invalid after migration:", validationError)
            return false
        end

        -- Update version
        LayoutLedger.Migrations.SetDatabaseVersion(db, newVersion)
        currentVersion = newVersion
        migrationsRan = migrationsRan + 1

        print("LayoutLedger: Migrated to", newVersion)
    end

    -- Safety check
    if migrationsRan >= maxIterations then
        print("LayoutLedger: ERROR - Too many migrations ran, possible infinite loop")
        return false
    end

    -- Final validation
    local valid, error = LayoutLedger.Migrations.ValidateDatabase(db, targetVersion)
    if not valid then
        print("LayoutLedger: ERROR - Database validation failed:", error)
        return false
    end

    print("LayoutLedger: Database migration complete!")
    print("LayoutLedger: Ran", migrationsRan, "migration(s)")

    return true
end

---
-- Import String Migration Helpers
---

-- Validate import data structure for a specific version
function LayoutLedger.Migrations.ValidateImportData(data, version)
    if not data then
        return false, "Data is nil"
    end

    -- Version-specific validation
    if version == "0.1.0" or version == LayoutLedger.EXPORT_VERSION then
        -- Check version field exists
        if not data.version then
            return false, "Missing version field"
        end

        -- Check metadata exists
        if not data.metadata then
            return false, "Missing metadata"
        end

        -- If uiLayout exists, it should be a table (not string) in v0.1.0+
        if data.uiLayout and type(data.uiLayout) ~= "table" then
            return false, "uiLayout should be table, got " .. type(data.uiLayout)
        end

        -- All checks passed
        return true, nil
    end

    -- Legacy version has no version field
    if version == "legacy" then
        -- Legacy can have anything, validation is minimal
        return true, nil
    end

    -- Unknown version
    return false, "Unknown version: " .. tostring(version)
end

-- Migrate import data from old version to current version
function LayoutLedger.Migrations.MigrateImportData(data)
    if not data then
        return nil, "Data is nil"
    end

    local currentVersion = data.version or "legacy"
    local targetVersion = LayoutLedger.EXPORT_VERSION

    print("LayoutLedger: Import data version check:")
    print("  Current:", tostring(currentVersion))
    print("  Target:", tostring(targetVersion))

    -- Already at current version
    if currentVersion == targetVersion then
        print("LayoutLedger: Import data is current version")
        return data, nil
    end

    -- Run sequential migrations
    local migrationsRan = 0
    local maxIterations = 100  -- Safety limit

    while currentVersion ~= targetVersion and migrationsRan < maxIterations do
        print("LayoutLedger: Migrating import data from", currentVersion)

        -- Apply version-specific transformations
        local newVersion, error = LayoutLedger.Migrations.MigrateImportDataVersion(data, currentVersion)

        if error then
            return nil, error
        end

        -- Validate after migration
        local valid, validationError = LayoutLedger.Migrations.ValidateImportData(data, newVersion)
        if not valid then
            return nil, "Validation failed after migration: " .. tostring(validationError)
        end

        currentVersion = newVersion
        migrationsRan = migrationsRan + 1

        print("LayoutLedger: Import data migrated to", newVersion)
    end

    -- Safety check
    if migrationsRan >= maxIterations then
        return nil, "Too many migrations, possible infinite loop"
    end

    -- Final validation
    local valid, error = LayoutLedger.Migrations.ValidateImportData(data, targetVersion)
    if not valid then
        return nil, "Final validation failed: " .. tostring(error)
    end

    print("LayoutLedger: Import migration complete! Ran", migrationsRan, "migration(s)")

    return data, nil
end

-- Apply a single version migration to import data
function LayoutLedger.Migrations.MigrateImportDataVersion(data, fromVersion)
    -- Legacy -> 0.1.0
    if fromVersion == "legacy" then
        print("LayoutLedger: Migrating from legacy to v0.1.0")

        -- Legacy format had uiLayout as a string instead of a table
        if data.uiLayout and type(data.uiLayout) == "string" then
            print("LayoutLedger: Converting legacy uiLayout string to table format")
            data.uiLayout = {
                layoutString = data.uiLayout,
                layoutName = "Imported Layout",
                layoutType = 1  -- Account type
            }
        end

        -- Add version field
        data.version = "0.1.0"
        return "0.1.0", nil
    end

    -- 0.1.0 -> 0.2.0 (future migration example)
    -- if fromVersion == "0.1.0" then
    --     print("LayoutLedger: Migrating from v0.1.0 to v0.2.0")
    --     -- Apply transformations here
    --     data.version = "0.2.0"
    --     return "0.2.0", nil
    -- end

    -- No migration path found
    return nil, "No migration path from " .. tostring(fromVersion)
end

---
-- Helper Functions
---

-- Deep copy a table (for backup before migration)
function LayoutLedger.Migrations.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[LayoutLedger.Migrations.DeepCopy(orig_key)] = LayoutLedger.Migrations.DeepCopy(orig_value)
        end
        setmetatable(copy, LayoutLedger.Migrations.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Check if a table has a specific field
function LayoutLedger.Migrations.HasField(table, field)
    return table and table[field] ~= nil
end

-- Check if a value is of expected type
function LayoutLedger.Migrations.IsType(value, expectedType)
    return type(value) == expectedType
end

-- Get version number parts (for comparison)
function LayoutLedger.Migrations.ParseVersion(version)
    if not version or version == "legacy" then
        return 0, 0, 0
    end

    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

-- Compare two versions
-- Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
function LayoutLedger.Migrations.CompareVersions(v1, v2)
    local major1, minor1, patch1 = LayoutLedger.Migrations.ParseVersion(v1)
    local major2, minor2, patch2 = LayoutLedger.Migrations.ParseVersion(v2)

    if major1 ~= major2 then
        return major1 < major2 and -1 or 1
    end
    if minor1 ~= minor2 then
        return minor1 < minor2 and -1 or 1
    end
    if patch1 ~= patch2 then
        return patch1 < patch2 and -1 or 1
    end

    return 0
end
