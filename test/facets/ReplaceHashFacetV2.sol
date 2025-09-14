// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ReplaceHashFacetV2
/// @notice Test facet for runtime hash replacement testing (V2)
contract ReplaceHashFacetV2 {
    uint256 private value;
    
    /// @notice Get value
    function getValue() external view returns (uint256) {
        return value;
    }
    
    /// @notice Set value (modified implementation)
    function setValue(uint256 _value) external {
        value = _value + 1; // Different behavior: add 1
    }
    
    /// @notice Calculate sum (modified implementation)
    function calculate(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b + 1; // Different behavior: add 1
    }
}
