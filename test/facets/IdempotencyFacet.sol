// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IdempotencyFacet
/// @notice Test facet for idempotency testing
contract IdempotencyFacet {
    uint256 private counter;
    
    /// @notice Get current counter value
    function getCounter() external view returns (uint256) {
        return counter;
    }
    
    /// @notice Increment counter
    function increment() external {
        counter++;
    }
    
    /// @notice Reset counter to zero
    function reset() external {
        counter = 0;
    }
}
