// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibCounterStorage} from "src/example/libraries/counter/LibCounterStorage.sol";

/// @title MathFacet
/// @notice Advanced math operations for testing
contract MathFacet {
    /// @notice Multiply the counter by a factor
    /// @param factor The multiplication factor
    function multiply(uint256 factor) external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        cs.value *= factor;
    }

    /// @notice Calculate the square of the current value
    function square() external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        cs.value = cs.value * cs.value;
    }

    /// @notice Add two numbers and store the result
    /// @param a First number
    /// @param b Second number
    function addNumbers(uint256 a, uint256 b) external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        cs.value = a + b;
    }

    /// @notice Get the current value squared
    /// @return The squared value
    function getSquared() external view returns (uint256) {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        return cs.value * cs.value;
    }
}
