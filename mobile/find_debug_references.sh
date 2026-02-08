#!/bin/bash

# Script to find all debug button and related references in Flutter project
# Usage: ./find_debug_references.sh /path/to/your/flutter/project

PROJECT_DIR="${1:-.}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Directory $PROJECT_DIR does not exist"
    exit 1
fi

echo "=========================================="
echo "Searching for Debug References"
echo "Project Directory: $PROJECT_DIR"
echo "=========================================="
echo ""

# Function to search and display results
search_pattern() {
    local pattern="$1"
    local description="$2"
    
    echo "-------------------------------------------"
    echo "Searching for: $description"
    echo "Pattern: $pattern"
    echo "-------------------------------------------"
    
    # Search in .dart files only, exclude build/cache directories
    results=$(grep -rn --include="*.dart" \
              --exclude-dir="build" \
              --exclude-dir=".dart_tool" \
              --exclude-dir="android" \
              --exclude-dir="ios" \
              --exclude-dir="linux" \
              --exclude-dir="macos" \
              --exclude-dir="windows" \
              "$pattern" "$PROJECT_DIR" 2>/dev/null)
    
    if [ -z "$results" ]; then
        echo "✓ No matches found"
    else
        echo "$results"
        echo ""
        echo "Found $(echo "$results" | wc -l) occurrence(s)"
    fi
    echo ""
}

# Search for debug button text
search_pattern "Mock Threat" "Mock Threat Buttons"
search_pattern "Retry Initialization" "Retry Initialization Button"
search_pattern "Service Not Initialized" "Service Not Initialized Error Banner"

# Search for debug screen files
echo "-------------------------------------------"
echo "Searching for: Debug/Test Screen Files"
echo "-------------------------------------------"
find "$PROJECT_DIR" -type f -name "*.dart" \
    \( -name "*debug*" -o -name "*test_screen*" -o -name "*threat_test*" \) \
    2>/dev/null | while read file; do
    echo "Found: $file"
done
echo ""

# Search for route definitions
search_pattern "'/debug" "Debug Routes (starting with /debug)"
search_pattern "'/test" "Test Routes (starting with /test)"
search_pattern "DebugScreen" "DebugScreen Widget References"
search_pattern "ThreatTestScreen" "ThreatTestScreen Widget References"
search_pattern "MockThreatScreen" "MockThreatScreen Widget References"

# Search for evidence initialization in screens
echo "-------------------------------------------"
echo "Searching for: Evidence Init in Screen Files"
echo "-------------------------------------------"
grep -rn --include="*.dart" \
     --exclude-dir="build" \
     --exclude-dir=".dart_tool" \
     "evidenceInitNotifierProvider" "$PROJECT_DIR/lib" 2>/dev/null | \
     grep -E "(screen|page)" -i
echo ""

# Search for any TODO or DEBUG comments related to this
echo "-------------------------------------------"
echo "Searching for: Related TODO/DEBUG Comments"
echo "-------------------------------------------"
grep -rn --include="*.dart" \
     --exclude-dir="build" \
     --exclude-dir=".dart_tool" \
     -E "(TODO|DEBUG|FIXME).*[Mm]ock|[Tt]est|[Dd]ebug.*[Ee]vidence" \
     "$PROJECT_DIR/lib" 2>/dev/null
echo ""

# Summary
echo "=========================================="
echo "Search Complete"
echo "=========================================="
echo ""
echo "NEXT STEPS:"
echo "1. Review all files found above"
echo "2. Remove debug screen files entirely"
echo "3. Remove route definitions to debug screens"
echo "4. Remove navigation menu items/buttons"
echo "5. Remove any imports of debug screen files"
echo ""
echo "TIP: Use this command to remove a file:"
echo "  rm /path/to/file.dart"
echo ""
echo "TIP: To see full context around a match:"
echo "  grep -A 5 -B 5 'pattern' filename.dart"
