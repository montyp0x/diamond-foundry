// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BoomB
/// @notice Test facet with collision selector
contract BoomB {
    /// @notice Function that will collide with BoomA
    function clash() external pure returns (string memory) {
        return "BoomB";
    }
}
