// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ReplaceHashFacet
/// @notice Test facet for runtime hash replacement testing
contract ReplaceHashFacet {
    uint256 private value;

    /// @notice Get value
    function getValue() external view returns (uint256) {
        return value;
    }

    /// @notice Set value (original implementation)
    function setValue(uint256 _value) external {
        value = _value;
    }

    /// @notice Calculate sum
    function calculate(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }
}
