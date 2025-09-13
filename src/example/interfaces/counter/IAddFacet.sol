// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAddFacet
/// @notice Mutating API for the Counter example (increments / resets).
interface IAddFacet {
    /// @notice Increase the counter by `by`.
    /// @param by Value to add (can be zero).
    function increment(uint256 by) external;

    /// @notice Reset the counter to zero.
    function reset() external;

    /// @dev Emitted after a successful increment.
    event Incremented(uint256 newValue);

    /// @dev Emitted after a successful reset.
    event Reset(uint256 oldValue);
}
