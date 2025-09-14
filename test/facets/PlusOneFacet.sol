// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibCounterStorage} from "src/example/libraries/counter/LibCounterStorage.sol";

/// @title PlusOneFacet
/// @notice Adds 1 to the counter value
contract PlusOneFacet {
    /// @notice Increments counter by 1 and returns the new value
    /// @return The new counter value after incrementing
    function plusOne() external returns (uint256) {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        unchecked {
            cs.value += 1;
        }
        return cs.value;
    }
}
