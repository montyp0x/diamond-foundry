#!/bin/bash

# run_scenario.sh - Run a complete test scenario
# Usage: ./scripts/run_scenario.sh test/scenarios/01_base.txt [test_pattern]

set -e

SCENARIO_FILE="$1"
TEST_PATTERN="$2"

if [ -z "$SCENARIO_FILE" ]; then
    echo "Usage: $0 <scenario_file> [test_pattern]"
    echo "Example: $0 test/scenarios/01_base.txt"
    echo "Example: $0 test/scenarios/01_base.txt test_01_base"
    exit 1
fi

echo "Running scenario: $SCENARIO_FILE"

# Step 1: Set up the scenario
echo "=== Step 1: Setting up scenario ==="
./scripts/set_scenario.sh "$SCENARIO_FILE"

# Step 2: Build
echo "=== Step 2: Building ==="
forge build

# Step 3: Run tests
echo "=== Step 3: Running tests ==="
if [ -n "$TEST_PATTERN" ]; then
    echo "Running tests matching pattern: $TEST_PATTERN"
    forge test --match-test "$TEST_PATTERN" -vv
else
    echo "Running all tests"
    forge test -vv
fi

echo "Scenario run complete!"
