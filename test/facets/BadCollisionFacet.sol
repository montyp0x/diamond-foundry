// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibCounterStorage} from "../../src/example/libraries/counter/LibCounterStorage.sol";

/// @title BadCollisionFacet
/// @notice This facet intentionally has a selector collision with AddFacet.increment(uint256)
/// @dev Used for testing selector collision detection
contract BadCollisionFacet {
    /// @notice This function has the same selector as AddFacet.increment(uint256)
    /// @param by The amount to increment by
    function increment(uint256 by) external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        unchecked {
            cs.value += by * 2; // Different implementation to show collision
        }
    }
}
