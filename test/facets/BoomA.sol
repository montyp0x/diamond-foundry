// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BoomA
/// @notice Test facet with collision selector
contract BoomA {
    /// @notice Function that will collide with BoomB
    function clash() external pure returns (string memory) {
        return "BoomA";
    }
}
