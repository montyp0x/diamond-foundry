// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title InitTestFacet
/// @notice Test facet for init override testing
contract InitTestFacet {
    uint256 private initValue;
    bool private initialized;

    /// @notice Initialize with a value
    function init(uint256 value) external {
        require(!initialized, "Already initialized");
        initValue = value;
        initialized = true;
    }

    /// @notice Get initialization value
    function getInitValue() external view returns (uint256) {
        return initValue;
    }

    /// @notice Check if initialized
    function isInitialized() external view returns (bool) {
        return initialized;
    }
}
