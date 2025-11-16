@echo off
REM Install Git hooks for Layout Ledger
REM Run this after cloning the repository

echo Installing Layout Ledger Git hooks...

REM Check if .git directory exists
if not exist ".git" (
    echo Error: .git directory not found. Are you in a git repository?
    exit /b 1
)

REM Create the pre-commit hook
(
echo #!/bin/sh
echo #
echo # Layout Ledger Pre-Commit Hook
echo # Runs code quality tools before allowing commit
echo #
echo.
echo echo "Running Layout Ledger code quality checks..."
echo.
echo # Store the exit code
echo EXIT_CODE=0
echo.
echo # 1. Run XML Validation
echo echo ""
echo echo "=== XML Validation ==="
echo if command -v node ^>/dev/null 2^>^&1; then
echo     if [ -f "scripts/validate-xml.js" ]; then
echo         node scripts/validate-xml.js
echo         XML_RESULT=$?
echo         if [ $XML_RESULT -ne 0 ]; then
echo             echo "❌ XML validation failed!"
echo             EXIT_CODE=1
echo         else
echo             echo "✅ XML validation passed"
echo         fi
echo     else
echo         echo "⚠️  Warning: scripts/validate-xml.js not found"
echo     fi
echo else
echo     echo "⚠️  Warning: Node.js not found - skipping XML validation"
echo fi
echo.
echo # 2. Run Luacheck
echo echo ""
echo echo "=== Lua Linting ==="
echo if command -v luacheck ^>/dev/null 2^>^&1; then
echo     luacheck LayoutLedger/ --exclude-files 'LayoutLedger/Libs/**'
echo     LUA_RESULT=$?
echo     if [ $LUA_RESULT -ne 0 ]; then
echo         echo "❌ Lua linting failed!"
echo         EXIT_CODE=1
echo     else
echo         echo "✅ Lua linting passed"
echo     fi
echo else
echo     echo "⚠️  Warning: luacheck not installed - skipping Lua linting"
echo     echo "   Install with: luarocks install luacheck"
echo fi
echo.
echo # Summary
echo echo ""
echo echo "=== Pre-Commit Summary ==="
echo if [ $EXIT_CODE -eq 0 ]; then
echo     echo "✅ All checks passed - proceeding with commit"
echo else
echo     echo "❌ Some checks failed - commit blocked"
echo     echo ""
echo     echo "To skip this check (not recommended), use:"
echo     echo "  git commit --no-verify"
echo fi
echo.
echo exit $EXIT_CODE
) > .git\hooks\pre-commit

echo ✅ Pre-commit hook installed successfully!
echo.
echo The following checks will run before each commit:
echo   - XML validation (via Node.js)
echo   - Lua linting (via luacheck, if installed)
echo.
echo To skip the hook for a single commit, use:
echo   git commit --no-verify
