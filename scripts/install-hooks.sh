#!/bin/bash
#
# Install Git hooks for Layout Ledger
#
# This script copies pre-commit hooks to .git/hooks/
# Run this after cloning the repository
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing Layout Ledger Git hooks..."

# Check if .git directory exists
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "Error: .git directory not found. Are you in a git repository?"
    exit 1
fi

# Create the pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/sh
#
# Layout Ledger Pre-Commit Hook
# Runs code quality tools before allowing commit
#

echo "Running Layout Ledger code quality checks..."

# Store the exit code
EXIT_CODE=0

# 1. Run XML Validation
echo ""
echo "=== XML Validation ==="
if command -v node >/dev/null 2>&1; then
    if [ -f "scripts/validate-xml.js" ]; then
        node scripts/validate-xml.js
        XML_RESULT=$?
        if [ $XML_RESULT -ne 0 ]; then
            echo "❌ XML validation failed!"
            EXIT_CODE=1
        else
            echo "✅ XML validation passed"
        fi
    else
        echo "⚠️  Warning: scripts/validate-xml.js not found"
    fi
else
    echo "⚠️  Warning: Node.js not found - skipping XML validation"
fi

# 2. Run Luacheck
echo ""
echo "=== Lua Linting ==="
if command -v luacheck >/dev/null 2>&1; then
    luacheck LayoutLedger/ --exclude-files 'LayoutLedger/Libs/**'
    LUA_RESULT=$?
    if [ $LUA_RESULT -ne 0 ]; then
        echo "❌ Lua linting failed!"
        EXIT_CODE=1
    else
        echo "✅ Lua linting passed"
    fi
else
    echo "⚠️  Warning: luacheck not installed - skipping Lua linting"
    echo "   Install with: luarocks install luacheck"
fi

# Summary
echo ""
echo "=== Pre-Commit Summary ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All checks passed - proceeding with commit"
else
    echo "❌ Some checks failed - commit blocked"
    echo ""
    echo "To skip this check (not recommended), use:"
    echo "  git commit --no-verify"
fi

exit $EXIT_CODE
EOF

# Make the hook executable
chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "The following checks will run before each commit:"
echo "  - XML validation (via Node.js)"
echo "  - Lua linting (via luacheck, if installed)"
echo ""
echo "To skip the hook for a single commit, use:"
echo "  git commit --no-verify"
