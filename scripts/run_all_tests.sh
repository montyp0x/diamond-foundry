#!/bin/bash

# run_all_tests.sh - Run all test suites
# Usage: ./scripts/run_all_tests.sh

set -e

echo "=== Running All Diamond Test Suites ==="
echo

# Track results
total_passed=0
total_failed=0

# Function to run a test suite
run_test_suite() {
    local suite_name="$1"
    local test_pattern="$2"
    
    echo "=========================================="
    echo "Running Test Suite: $suite_name"
    echo "Test Pattern: $test_pattern"
    echo "=========================================="
    
    if forge test --match-test "$test_pattern" -vv; then
        echo "$suite_name PASSED"
        ((total_passed++))
    else
        echo "$suite_name FAILED"
        ((total_failed++))
    fi
    
    echo
}

# Run deterministic scenarios
echo "=== DETERMINISTIC SCENARIOS ==="
./scripts/run_all_scenarios.sh
if [ $? -eq 0 ]; then
    echo "Deterministic Scenarios PASSED"
    ((total_passed++))
else
    echo "Deterministic Scenarios FAILED"
    ((total_failed++))
fi
echo

# Run advanced scenarios
echo "=== ADVANCED SCENARIOS ==="
run_test_suite "Advanced Scenarios" "test_06_math_operations|test_07_storage_manipulation|test_08_event_emission|test_09_admin_functions|test_10_complex_integration"

# Run performance tests
echo "=== PERFORMANCE TESTS ==="
run_test_suite "Performance Tests" "test_gas_|test_performance_|test_stress_"

# Run error handling tests
echo "=== ERROR HANDLING TESTS ==="
run_test_suite "Error Handling Tests" "test_access_control_|test_edge_case_|test_error_recovery_|test_boundary_conditions_"

# Run edge case tests
echo "=== EDGE CASE TESTS ==="
run_test_suite "Edge Case Tests" "test_edge_case_|test_boundary_conditions_"

# Run all tests together
echo "=== COMPREHENSIVE TEST RUN ==="
if forge test -vv; then
    echo "All Tests PASSED"
    ((total_passed++))
else
    echo "Some Tests FAILED"
    ((total_failed++))
fi

echo
echo "=========================================="
echo "FINAL RESULTS"
echo "=========================================="
echo "Test Suites Passed: $total_passed"
echo "Test Suites Failed: $total_failed"
echo "Total Test Suites: $((total_passed + total_failed))"

if [ $total_failed -eq 0 ]; then
    echo "All test suites passed!"
    exit 0
else
    echo "Some test suites failed!"
    exit 1
fi
