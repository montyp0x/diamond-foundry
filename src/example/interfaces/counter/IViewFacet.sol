// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IViewFacet
/// @notice Read-only API for the Counter example.
interface IViewFacet {
    /// @notice Get the current counter value.
    function get() external view returns (uint256);
}
