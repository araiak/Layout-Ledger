#!/usr/bin/env node

/**
 * WoW Addon XML Validator
 * Validates all .xml files in the LayoutLedger directory for:
 * - Well-formedness (basic XML syntax)
 * - Common WoW UI XML errors
 * - Missing required elements
 */

const fs = require('fs');
const path = require('path');
const { XMLParser, XMLValidator } = require('fast-xml-parser');

// ANSI color codes for terminal output
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
};

// Configuration
const addonDir = path.join(__dirname, '..', 'LayoutLedger');
const xmlFiles = [];
let totalErrors = 0;
let totalWarnings = 0;

/**
 * Find all .xml files in the addon directory
 */
function findXMLFiles(dir) {
    const files = fs.readdirSync(dir);

    files.forEach(file => {
        const filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);

        if (stat.isDirectory()) {
            // Skip Libs directory
            if (file !== 'Libs') {
                findXMLFiles(filePath);
            }
        } else if (file.endsWith('.xml')) {
            xmlFiles.push(filePath);
        }
    });
}

/**
 * Validate XML well-formedness
 */
function validateWellFormedness(filePath, content) {
    const result = XMLValidator.validate(content, {
        allowBooleanAttributes: true,
    });

    if (result !== true) {
        console.log(`${colors.red}✗ ${path.basename(filePath)}${colors.reset}`);
        console.log(`  ${colors.red}Error:${colors.reset} ${result.err.msg}`);
        console.log(`  Line: ${result.err.line}, Column: ${result.err.col}`);
        totalErrors++;
        return false;
    }

    return true;
}

/**
 * Check for common WoW UI XML issues
 */
function validateWoWUIXML(filePath, content) {
    const issues = [];
    const warnings = [];
    const fileName = path.basename(filePath);

    // Check for required xmlns declaration
    if (!content.includes('xmlns="http://www.blizzard.com/wow/ui/"')) {
        warnings.push('Missing xmlns declaration - should include xmlns="http://www.blizzard.com/wow/ui/"');
    }

    // Check for common tag mismatches
    const backdropInsets = content.match(/<BackgroundInsets>/g);
    const backdropInsetsClose = content.match(/<\/BackgroundInsets>/g);

    if (backdropInsets && backdropInsetsClose) {
        if (backdropInsets.length !== backdropInsetsClose.length) {
            issues.push('Mismatched <BackgroundInsets> tags');
        }
    }

    // Check for deprecated Backdrop element (removed in WoW 9.0+)
    if (content.includes('<Backdrop') || content.includes('</Backdrop>')) {
        issues.push('DEPRECATED: <Backdrop> element is not valid in modern WoW (9.0+). Use SetBackdrop() in Lua instead.');
    }

    // Check for BackgroundInsets without proper closing (old bug pattern)
    if (content.includes('</Backdrop>') && content.includes('<BackgroundInsets>')) {
        const backdropPos = content.indexOf('</Backdrop>');
        const insetsPos = content.indexOf('<BackgroundInsets>');

        if (insetsPos < backdropPos) {
            const nextBackdropClose = content.indexOf('</Backdrop>', insetsPos);
            const nextInsetsClose = content.indexOf('</BackgroundInsets>', insetsPos);

            if (nextInsetsClose === -1 || nextBackdropClose < nextInsetsClose) {
                issues.push('Possible incorrect closing tag: </Backdrop> should be </BackgroundInsets>');
            }
        }
    }

    // Check for self-closing tags that shouldn't be
    const problematicSelfClosing = [
        { tag: 'Frame', pattern: /<Frame[^>]*\/>/ },
        { tag: 'Button', pattern: /<Button[^>]*\/>/ },
        { tag: 'Backdrop', pattern: /<Backdrop[^>]*\/>/ },
    ];

    problematicSelfClosing.forEach(({ tag, pattern }) => {
        if (pattern.test(content)) {
            warnings.push(`Self-closing <${tag}/> tag found - may need child elements`);
        }
    });

    // Check for missing name attributes on frames
    const frameMatches = content.match(/<Frame[^>]*>/g);
    if (frameMatches) {
        frameMatches.forEach(match => {
            if (!match.includes('name=')) {
                warnings.push('Frame without name attribute - may cause issues accessing from Lua');
            }
        });
    }

    // Report issues
    if (issues.length > 0) {
        console.log(`${colors.red}✗ ${fileName}${colors.reset}`);
        issues.forEach(issue => {
            console.log(`  ${colors.red}Error:${colors.reset} ${issue}`);
        });
        totalErrors += issues.length;
        return false;
    }

    if (warnings.length > 0) {
        console.log(`${colors.yellow}⚠ ${fileName}${colors.reset}`);
        warnings.forEach(warning => {
            console.log(`  ${colors.yellow}Warning:${colors.reset} ${warning}`);
        });
        totalWarnings += warnings.length;
    }

    return true;
}

/**
 * Parse and validate XML structure
 */
function validateStructure(filePath, content) {
    try {
        const parser = new XMLParser({
            ignoreAttributes: false,
            attributeNamePrefix: '@_',
        });

        const parsed = parser.parse(content);

        // Check if root element is Ui
        if (!parsed.Ui) {
            console.log(`${colors.red}✗ ${path.basename(filePath)}${colors.reset}`);
            console.log(`  ${colors.red}Error:${colors.reset} Root element must be <Ui>`);
            totalErrors++;
            return false;
        }

        return true;
    } catch (error) {
        console.log(`${colors.red}✗ ${path.basename(filePath)}${colors.reset}`);
        console.log(`  ${colors.red}Error:${colors.reset} Failed to parse XML - ${error.message}`);
        totalErrors++;
        return false;
    }
}

/**
 * Validate a single XML file
 */
function validateFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');

    // Run all validations
    const wellFormed = validateWellFormedness(filePath, content);
    if (!wellFormed) return false;

    const validStructure = validateStructure(filePath, content);
    if (!validStructure) return false;

    const wowValid = validateWoWUIXML(filePath, content);

    // Only print success if no warnings either
    if (wowValid && totalWarnings === 0) {
        console.log(`${colors.green}✓ ${path.basename(filePath)}${colors.reset}`);
    }

    return true;
}

/**
 * Main validation process
 */
function main() {
    console.log(`${colors.cyan}=== WoW Addon XML Validator ===${colors.reset}\n`);
    console.log(`Scanning: ${addonDir}\n`);

    // Find all XML files
    if (!fs.existsSync(addonDir)) {
        console.log(`${colors.red}Error: LayoutLedger directory not found${colors.reset}`);
        process.exit(1);
    }

    findXMLFiles(addonDir);

    if (xmlFiles.length === 0) {
        console.log(`${colors.yellow}No XML files found${colors.reset}`);
        process.exit(0);
    }

    console.log(`Found ${xmlFiles.length} XML file(s)\n`);

    // Validate each file
    xmlFiles.forEach(filePath => {
        validateFile(filePath);
    });

    // Summary
    console.log(`\n${colors.cyan}=== Validation Summary ===${colors.reset}`);
    console.log(`Files checked: ${xmlFiles.length}`);
    console.log(`Errors: ${colors.red}${totalErrors}${colors.reset}`);
    console.log(`Warnings: ${colors.yellow}${totalWarnings}${colors.reset}`);

    if (totalErrors > 0) {
        console.log(`\n${colors.red}✗ Validation failed${colors.reset}`);
        process.exit(1);
    } else if (totalWarnings > 0) {
        console.log(`\n${colors.yellow}⚠ Validation passed with warnings${colors.reset}`);
        process.exit(0);
    } else {
        console.log(`\n${colors.green}✓ All XML files are valid${colors.reset}`);
        process.exit(0);
    }
}

// Run validation
main();
