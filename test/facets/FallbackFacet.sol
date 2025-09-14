// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FallbackFacet
/// @notice Test facet with only fallback and receive functions
contract FallbackFacet {
    /// @notice Receive function (should be ignored)
    receive() external payable {
        // This should not be counted as a function
    }
    
    /// @notice Fallback function (should be ignored)
    fallback() external payable {
        // This should not be counted as a function
    }
}
