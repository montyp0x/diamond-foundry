// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibCounterStorage} from "src/example/libraries/counter/LibCounterStorage.sol";

/// @title StorageFacet
/// @notice Storage manipulation for testing
contract StorageFacet {
    /// @notice Set a specific value
    /// @param value The value to set
    function setValue(uint256 value) external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        cs.value = value;
    }

    /// @notice Get the current value
    /// @return The current value
    function getValue() external view returns (uint256) {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        return cs.value;
    }

    /// @notice Double the current value
    function double() external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        cs.value *= 2;
    }

    /// @notice Halve the current value
    function halve() external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        cs.value /= 2;
    }
}
