// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title OverloadFacet
/// @notice Test facet with function overloads
contract OverloadFacet {
    /// @notice Function with uint256 parameter
    function process(uint256 value) external pure returns (uint256) {
        return value * 2;
    }

    /// @notice Function with address parameter (same name, different signature)
    function process(address addr) external pure returns (address) {
        return addr;
    }

    /// @notice Function with string parameter (same name, different signature)
    function process(string memory str) external pure returns (string memory) {
        return str;
    }

    /// @notice Function with multiple parameters
    function process(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }

    /// @notice Function with different return type
    function process(bool flag) external pure returns (bool) {
        return !flag;
    }
}
