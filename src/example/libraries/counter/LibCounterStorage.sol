// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibCounterStorage
/// @notice Namespaced storage for the Counter example facets (v1).
/// @dev Keep this slot constant forever for v1. If you need to evolve layout,
///      create a new namespace (e.g., "counter.v2") in a new library.
library LibCounterStorage {
    // Fixed slot (precomputed). Must match the entry in `.diamond-upgrades/example.storage.json`.
    bytes32 internal constant COUNTER_STORAGE_SLOT = 0x2b5661e21c5c88ebbe6c320f9b4f3a1a4f8b5c2f6e2b4b7b8a2a5b3c6d7e8f90;

    /// @dev v1 layout: a single counter.
    struct Layout {
        uint256 value;
    }

    /// @notice Accessor to the storage layout at the fixed slot.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = COUNTER_STORAGE_SLOT;
        assembly ("memory-safe") {
            l.slot := slot
        }
    }
}
