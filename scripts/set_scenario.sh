
#!/bin/bash

# set_scenario.sh - Set up facets for a specific test scenario
# Usage: ./scripts/set_scenario.sh test/scenarios/01_base.txt

set -e

SCENARIO_FILE="$1"
FACETS_DIR="test/facets"
EXAMPLE_FACETS_DIR="src/example/facets"
PARKING_DIR="test/facets/_parking"

if [ -z "$SCENARIO_FILE" ]; then
    echo "Usage: $0 <scenario_file>"
    echo "Example: $0 test/scenarios/01_base.txt"
    exit 1
fi

if [ ! -f "$SCENARIO_FILE" ]; then
    echo "Error: Scenario file '$SCENARIO_FILE' not found"
    exit 1
fi

echo "Setting up scenario: $SCENARIO_FILE"

# Clean up example/facets directory
echo "Cleaning up $EXAMPLE_FACETS_DIR..."
rm -rf "$EXAMPLE_FACETS_DIR"/*

# Create the directory if it doesn't exist
mkdir -p "$EXAMPLE_FACETS_DIR"

# Read scenario file and copy facets
echo "Copying facets from scenario..."
while IFS= read -r facet_file; do
    # Skip empty lines
    if [ -z "$facet_file" ]; then
        continue
    fi
    
    # Remove leading/trailing whitespace
    facet_file=$(echo "$facet_file" | xargs)
    
    # Check if facet exists in test/facets
    if [ -f "$FACETS_DIR/$facet_file" ]; then
        echo "  Copying $facet_file"
        cp "$FACETS_DIR/$facet_file" "$EXAMPLE_FACETS_DIR/"
        
        # Fix import paths for src/example/facets location
        # Use portable sed approach that works on both macOS and Linux
        sed 's|../../src/example/|../|g' "$EXAMPLE_FACETS_DIR/$facet_file" > "$EXAMPLE_FACETS_DIR/$facet_file.tmp" && mv "$EXAMPLE_FACETS_DIR/$facet_file.tmp" "$EXAMPLE_FACETS_DIR/$facet_file"
    else
        echo "  Warning: $facet_file not found in $FACETS_DIR"
    fi
done < "$SCENARIO_FILE"

echo "Scenario setup complete!"
echo "Facets in $EXAMPLE_FACETS_DIR:"
ls -la "$EXAMPLE_FACETS_DIR"
