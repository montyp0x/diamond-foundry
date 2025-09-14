// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EventsOnlyFacet
/// @notice Test facet with only events and constructor, no functions
contract EventsOnlyFacet {
    /// @notice Event definition
    event TestEvent(uint256 indexed value, string message);
    
    /// @notice Constructor (should be ignored)
    constructor() {
        emit TestEvent(0, "Constructor called");
    }
    
    /// @notice Another event
    event AnotherEvent(address indexed sender, bool flag);
}
