// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IViewFacet} from "../../src/example/interfaces/counter/IViewFacet.sol";
import {LibCounterStorage} from "../../src/example/libraries/counter/LibCounterStorage.sol";

/// @title ViewFacet (Counter)
/// @notice Read-only operations for the Counter example.
contract ViewFacet is IViewFacet {
    /// @inheritdoc IViewFacet
    function get() external view returns (uint256) {
        LibCounterStorage.Layout storage cs = LibCounterStorage.layout();
        return cs.value;
    }
}
