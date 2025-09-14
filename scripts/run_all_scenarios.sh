#!/bin/bash

# run_all_scenarios.sh - Run all test scenarios in sequence
# Usage: ./scripts/run_all_scenarios.sh

set -e

echo "=== Running All Deterministic Diamond Test Scenarios ==="
echo

# Array of scenarios to run
scenarios=(
    "01_base.txt:test_01_base_deploy"
    "02_add.txt:test_02_add_facet"
    "03_replace.txt:test_03_replace_facet"
    "04_remove.txt:test_04_remove_facet"
    "05_collision.txt:test_05_collision_detection"
    "06_math.txt:test_06_math_operations"
    "07_storage.txt:test_07_storage_manipulation"
    "08_events.txt:test_08_event_emission"
    "09_admin.txt:test_09_admin_functions"
    "10_complex.txt:test_10_complex_integration"
    "11_idempotency.txt:test_11_idempotency_noop"
    "12_deterministic.txt:test_12_deterministic_ordering"
    "13_init_override.txt:test_13_init_spec_override"
    "14_init_revert.txt:test_14_init_revert_atomicity"
    "15_replace_hash.txt:test_15_replace_runtime_hash"
    "17_overloads.txt:test_17_overloads_same_names"
    "18_fallback_ignore.txt:test_18_fallback_receive_ignore"
    "19_events_ignore.txt:test_19_events_constructor_ignore"
    "20_large_batch.txt:test_20_large_batch"
)

# Track results
passed=0
failed=0

for scenario_info in "${scenarios[@]}"; do
    IFS=':' read -r scenario_file test_pattern <<< "$scenario_info"
    
    echo "=========================================="
    echo "Running Scenario: $scenario_file"
    echo "Test Pattern: $test_pattern"
    echo "=========================================="
    
    if ./scripts/run_scenario.sh "test/scenarios/$scenario_file" "$test_pattern"; then
        echo "Scenario $scenario_file PASSED"
        ((passed++))
    else
        echo "Scenario $scenario_file FAILED"
        ((failed++))
    fi
    
    echo
done

echo "=========================================="
echo "FINAL RESULTS"
echo "=========================================="
echo "Passed: $passed"
echo "Failed: $failed"
echo "Total:  $((passed + failed))"

if [ $failed -eq 0 ]; then
    echo "🎉 All scenarios passed!"
    exit 0
else
    echo "💥 Some scenarios failed!"
    exit 1
fi
