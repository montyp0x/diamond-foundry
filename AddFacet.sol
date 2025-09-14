// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAddFacet} from "../../src/example/interfaces/counter/IAddFacet.sol";
import {LibCounterStorage} from "../../src/example/libraries/counter/LibCounterStorage.sol";

/// @title AddFacet (Counter)
/// @notice Mutating operations for the Counter example (increment/reset).
/// @dev Uses namespaced storage via LibCounterStorage (counter.v1).
contract AddFacet is IAddFacet {
    /// @inheritdoc IAddFacet
    function increment(uint256 by) external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        unchecked {
            cs.value += by;
        }
        emit Incremented(cs.value);
    }

    /// @inheritdoc IAddFacet
    function reset() external {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        uint256 old = cs.value;
        cs.value = 0;
        emit Reset(old);
    }
}
